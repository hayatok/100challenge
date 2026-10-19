extends Node2D
## All animation derives from the model clock; overlays freeze the whole garden.

const INK := Color("161d32")
const PAPER := Color("f5efdf")
const GOLD := Color("dbc182")
const BLUE := Color("92d4e8")
const DANGER := Color("ed8c87")

var run
var reduced_motion := false
var textures: Dictionary = {}
var font: Font
var screen := Vector2(1280, 720)
var resonance_labels := 0
var last_draw_time := -1.0
var last_draw_state := ""
var last_draw_motion := false
var last_draw_size := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for id in ["witch", "hound", "charger", "archer", "garden_tile", "moon"]:
		var path := "res://assets/art/%s.svg" % id
		if id in ["witch", "hound", "charger", "archer"]:
			path = "res://assets/art/%s-r2.png" % id
		elif id == "garden_tile":
			path = "res://assets/art/garden-r2.svg"
		if ResourceLoader.exists(path):
			textures[id] = load(path)
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf"):
		font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	else:
		font = ThemeDB.fallback_font

func refresh() -> void:
	var next_size := get_viewport_rect().size
	if run == null:
		return
	# Static title and frozen overlays reuse their canvas commands.
	if run.elapsed == last_draw_time and str(run.state) == last_draw_state and reduced_motion == last_draw_motion and next_size == last_draw_size:
		return
	screen = next_size
	last_draw_time = run.elapsed
	last_draw_state = str(run.state)
	last_draw_motion = reduced_motion
	last_draw_size = screen
	queue_redraw()

func world(at: Vector2) -> Vector2:
	return at - run.player + screen * Vector2(0.5, 0.52)

func _draw() -> void:
	if run == null:
		return
	resonance_labels = 0
	_draw_ground()
	if run.state == "title":
		_draw_title_art()
		return
	_draw_trail()
	for pickup in run.pickups:
		_draw_pickup(pickup)
	for shot in run.projectiles:
		_draw_projectile(shot)
	var actors: Array[Dictionary] = []
	for enemy in run.enemies:
		actors.append({"type": "enemy", "position": enemy.position, "data": enemy})
	if run.echo_active:
		actors.append({"type": "echo", "position": run.echo})
	actors.append({"type": "player", "position": run.player})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y)
	for actor in actors:
		if actor.type == "enemy":
			_draw_enemy(actor.data)
		else:
			_draw_witch(world(actor.position), actor.type == "echo", 82.0)
	for effect in run.effects:
		_draw_effect(effect)
	# Attack intent remains on top of friendly magic.
	for enemy in run.enemies:
		_draw_telegraph(enemy)
	_draw_vignette()

func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color("101b25"))
	var camera: Vector2 = run.player - screen * Vector2(0.5, 0.52)
	var tile_size := 384.0
	var start := (camera / tile_size).floor() * tile_size
	for x in range(-1, int(screen.x / tile_size) + 2):
		for y in range(-1, int(screen.y / tile_size) + 2):
			var at := start + Vector2(x, y) * tile_size - camera
			if textures.has("garden_tile"):
				draw_texture_rect(textures.garden_tile, Rect2(at, Vector2.ONE * tile_size), false, Color(0.85, 0.94, 1.0, 0.82))
	_draw_garden_details(camera)
	# The origin garden seal provides an early landmark without blocking movement.
	var center := world(Vector2.ZERO)
	draw_arc(center, 208.0, 0.0, TAU, 96, Color(0.61, 0.66, 0.62, 0.14), 3.0, true)
	draw_arc(center, 217.0, 0.0, TAU, 96, Color(0.61, 0.66, 0.62, 0.08), 1.0, true)
	for i in range(12):
		var direction := Vector2.from_angle(TAU * float(i) / 12.0)
		draw_line(center + direction * 201.0, center + direction * 225.0, Color(0.7, 0.69, 0.55, 0.18), 2.0, true)
	# Ground dust is sparse and fixed in world space, never a gameplay obstacle.
	for i in range(32):
		var px := fposmod(float(i * 179 + 67) - camera.x * 0.12, screen.x)
		var py := fposmod(float(i * 101 + 19) - camera.y * 0.12, screen.y)
		draw_circle(Vector2(px, py), 1.3, Color(0.73, 0.75, 0.58, 0.14))

func _draw_title_art() -> void:
	var center := Vector2(screen.x * 0.80, 578.0)
	var moon_at := Vector2(screen.x * 0.80, 216.0)
	for radius in [188.0, 164.0, 138.0]:
		draw_circle(moon_at, radius, Color(GOLD, 0.022))
	if textures.has("moon"):
		draw_texture_rect(textures.moon, Rect2(moon_at - Vector2.ONE * 119.0, Vector2.ONE * 238.0), false, Color(0.95, 0.94, 0.83, 0.83))
	draw_arc(moon_at, 156, 0, TAU, 90, Color(GOLD, 0.25), 1.0, true)
	for i in range(28):
		var direction := Vector2.from_angle(float(i) * TAU / 28.0)
		draw_line(moon_at + direction * 151, moon_at + direction * (162 if i % 7 == 0 else 157), Color(GOLD, 0.48), 1.0, true)
	_draw_witch(center + Vector2(-128, 16), true, 240.0)
	_draw_witch(center + Vector2(10, 0), false, 380.0)
	draw_string(font, center + Vector2(-105, 73), "2秒前のあなたと。", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, BLUE)

func _draw_garden_details(camera: Vector2) -> void:
	# Flat mosaics and flowers are landmarks, never collision obstacles.
	var cell := Vector2(680, 540)
	var start := (camera / cell).floor()
	for x in range(-1, 4):
		for y in range(-1, 4):
			var grid := start + Vector2(x, y)
			var seed_value := int(grid.x) * 47 + int(grid.y) * 83
			var at := grid * cell + Vector2(147, 185) - camera
			if not Rect2(Vector2(-170, -140), screen + Vector2(340, 280)).has_point(at):
				continue
			var tint := Color("334443")
			_ellipse(at, Vector2(112, 47), Color(0.03, 0.07, 0.10, 0.32))
			_elliptic_arc(at, Vector2(98, 40), 0, TAU, Color("455455"), 3)
			_elliptic_arc(at, Vector2(87, 33), 0, TAU, Color("263a3e"), 2)
			for i in range(9):
				var direction := Vector2.from_angle(float(i) * TAU / 9.0)
				var leaf := at + direction * Vector2(91, 39)
				_ellipse(leaf, Vector2(12, 4), tint)
				if (i + absi(seed_value)) % 3 == 0:
					for petal in range(5):
						var point := leaf + Vector2.from_angle(float(petal) * TAU / 5) * 4.0
						draw_circle(point, 2.5, Color("9b91a3"))
					draw_circle(leaf, 1.7, GOLD)
			for i in range(5):
				var angle := float(i) * TAU / 5.0
				var direction := Vector2.from_angle(angle)
				draw_line(at + direction * Vector2(10, 5), at + direction.rotated(0.8) * Vector2(64, 25), Color("697165"), 1.0, true)
	# Fireflies follow the simulation clock and stop with all overlays.
	for i in range(17):
		var phase := float(i) * 1.77
		var offset := Vector2.ZERO if reduced_motion else Vector2(sin(run.elapsed * 0.35 + phase) * 7, cos(run.elapsed * 0.3 + phase) * 5)
		var at := Vector2(fposmod(float(i * 179 + 53) - camera.x * 0.6, screen.x), fposmod(float(i * 137 + 29) - camera.y * 0.6, screen.y)) + offset
		draw_circle(at, 6, Color(GOLD, 0.035))
		draw_circle(at, 1.1, Color(GOLD, 0.42))

func _draw_trail() -> void:
	if not run.echo_active or run.player.distance_to(run.echo) < 35.0:
		return
	var index := 0
	for sample in run.timeline.positions:
		index += 1
		if index % 10 != 0:
			continue
		var fraction := clampf((float(sample.time) - (run.elapsed - 2.0)) / 2.0, 0.0, 1.0)
		var at := world(sample.position) + Vector2(0, 18)
		draw_circle(at, 2.0, Color(BLUE, 0.17 + fraction * 0.18))

func _draw_witch(at: Vector2, is_echo: bool, size: float) -> void:
	var scale_factor := size / 82.0
	var tint := Color(0.46, 0.88, 1.05, 0.62) if is_echo else Color.WHITE
	_ellipse(at + Vector2(0, 3), Vector2(21, 7) * scale_factor, Color(0.01, 0.02, 0.04, 0.50))
	if is_echo:
		for i in range(12):
			var angle := float(i) * TAU / 12.0
			_elliptic_arc(at, Vector2(22, 9) * scale_factor, angle, angle + 0.27, Color(BLUE, 0.95), 1.7)
	else:
		_elliptic_arc(at, Vector2(21, 9) * scale_factor, 0, TAU, Color(PAPER, 0.8), 1.8)
	var bob := 0.0 if reduced_motion or run.state == "title" else sin(run.elapsed * 6.0) * 1.2
	var tilt := 0.0 if reduced_motion or run.state == "title" else sin(run.elapsed * 5.0) * 0.025
	var facing := float(run.facing) if run.state != "title" else 1.0
	if is_echo and run.state != "title":
		var old_position: Vector2 = run.timeline.position_at(maxf(0.0, run.elapsed - 2.1))
		if absf(run.echo.x - old_position.x) > 0.1:
			facing = signf(run.echo.x - old_position.x)
	if not is_echo and run.invulnerable > 0.0:
		tint = Color(1.35, 0.85, 0.75) if reduced_motion else Color(1.5, 1.2, 1.1, 0.65 + sin(run.elapsed * 32) * 0.25)
	if textures.has("witch"):
		draw_set_transform(at + Vector2(0, bob), tilt, Vector2(facing, 1))
		draw_texture_rect(textures.witch, Rect2(Vector2(-size * 0.5, -size * 0.87), Vector2.ONE * size), false, tint)
		draw_set_transform(Vector2.ZERO)
	if is_echo and size < 100.0:
		draw_string_outline(font, at + Vector2(-14, -size * 0.83), "残像", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, INK)
		draw_string(font, at + Vector2(-14, -size * 0.83), "残像", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BLUE)

func _draw_enemy(enemy: Dictionary) -> void:
	var at := world(enemy.position)
	if at.x < -80 or at.y < -80 or at.x > screen.x + 80 or at.y > screen.y + 80:
		return
	var size := 64.0
	if enemy.kind == "charger":
		size = 86.0
	elif enemy.kind == "archer":
		size = 74.0
	var alpha := 1.0
	if enemy.phase == "arrival":
		alpha = clampf(1.0 - float(enemy.timer) / float(enemy.get("arrival_duration", 0.9)), 0.15, 1.0)
		_elliptic_arc(at + Vector2(0, 13), Vector2(24, 10), 0, TAU, Color(DANGER, 0.32), 1.0)
	_ellipse(at + Vector2(0, 10), Vector2(size * 0.28, 7), Color(0.0, 0.01, 0.025, 0.4 * alpha))
	var tint := Color(1, 1, 1, alpha)
	if float(enemy.flash) > 0.0 and not reduced_motion:
		tint = Color(1.8, 1.5, 1.2, alpha)
	if textures.has(enemy.kind):
		var tilt := 0.0
		var stretch := Vector2.ONE
		if not reduced_motion:
			tilt = sin(run.elapsed * 7.0 + float(enemy.id)) * 0.035
			if enemy.phase == "warning":
				stretch = Vector2(1.12, 0.88)
			elif enemy.phase == "rush":
				stretch = Vector2(1.16, 0.85)
		var flip := -1.0 if (enemy.position as Vector2).x > run.player.x else 1.0
		draw_set_transform(at, tilt, Vector2(flip, 1) * stretch)
		draw_texture_rect(textures[enemy.kind], Rect2(Vector2(-size * 0.5, -size * 0.70), Vector2.ONE * size), false, tint)
		draw_set_transform(Vector2.ZERO)
	var mark: Dictionary = enemy.get("mark", {})
	if not mark.is_empty() and float(mark.get("expires", 0.0)) > run.elapsed:
		var color := GOLD if str(mark.get("source", "player")) == "player" else BLUE
		draw_arc(at, 23.0, PI * 0.2, PI * 0.8, 16, color, 2.3, true)
		draw_arc(at, 23.0, PI * 1.2, PI * 1.8, 16, color, 2.3, true)
	if float(enemy.hp) < float(enemy.max_hp):
		draw_line(at + Vector2(-16, -27), at + Vector2(16, -27), Color("141a29"), 4.0)
		draw_line(at + Vector2(-16, -27), at + Vector2(-16 + 32 * maxf(0, float(enemy.hp) / float(enemy.max_hp)), -27), DANGER, 3.0)

func _draw_telegraph(enemy: Dictionary) -> void:
	if enemy.phase != "warning":
		return
	var at := world(enemy.position)
	var direction: Vector2 = enemy.direction
	var length := 296.0 if enemy.kind == "charger" else 495.0
	var end := at + direction * length
	draw_line(at, end, Color(INK, 0.8), 4.2, true)
	var normal := direction.orthogonal()
	if enemy.kind == "charger":
		var poly := PackedVector2Array([at + normal * 18, end + normal * 18, end - normal * 18, at - normal * 18])
		draw_colored_polygon(poly, Color(DANGER, 0.12))
		draw_line(at + normal * 18, end + normal * 18, Color(DANGER, 0.65), 1.5, true)
		draw_line(at - normal * 18, end - normal * 18, Color(DANGER, 0.65), 1.5, true)
	else:
		_dotted_line(at, end, Color(DANGER, 0.7), 11, 2.0)
	var progress := 1.0 - float(enemy.timer) / 0.95
	draw_arc(at, 29.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, DANGER, 2.5, true)
	draw_line(end, end - direction * 14 + normal * 8, DANGER, 2.0, true)
	draw_line(end, end - direction * 14 - normal * 8, DANGER, 2.0, true)

func _draw_pickup(pickup: Dictionary) -> void:
	var at := world(pickup.position)
	if not Rect2(Vector2(-15, -15), screen + Vector2(30, 30)).has_point(at):
		return
	var size := 5.0 + minf(int(pickup.value), 3)
	draw_circle(at, size * 1.9, Color(GOLD, 0.07))
	var diamond := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.7, 0), at + Vector2(0, size), at + Vector2(-size * 0.7, 0)])
	draw_colored_polygon(diamond, GOLD)
	draw_line(at + Vector2(0, -size + 1), at + Vector2(0, size - 1), PAPER, 1.2)
	if (pickup.position as Vector2).distance_to(run.player) < run.pickup_radius:
		draw_line(at, at.lerp(world(run.player), 0.12), Color(GOLD, 0.22), 1.0)

func _draw_projectile(shot: Dictionary) -> void:
	if float(shot.age) < 0.0:
		return
	var at := world(shot.position)
	if shot.kind == "bolt":
		var direction: Vector2 = (shot.velocity as Vector2).normalized()
		draw_line(at - direction * 14, at + direction * 5, Color(DANGER, 0.3), 8, true)
		draw_line(at - direction * 9, at + direction * 5, DANGER, 3, true)
		draw_circle(at, 4, PAPER)
	else:
		var radius := float(shot.radius) * minf(1.0, float(shot.age) / 0.55)
		var alpha := clampf((float(shot.duration) - float(shot.age)) / 0.25, 0.0, 1.0)
		var color := Color(BLUE if shot.echo else PAPER, alpha)
		draw_arc(at, radius, 0, TAU, 80, Color(color, alpha * 0.10), 15, true)
		draw_arc(at, radius, 0, TAU, 80, color, 2.5, true)
		draw_arc(at, maxf(radius - 6, 0.0), 0, TAU, 80, Color(color, alpha * 0.35), 1.0, true)
		for i in range(5):
			var angle := float(i) * TAU / 5.0 + float(shot.age) * (0.0 if reduced_motion else 0.5)
			var position_on_ring := at + Vector2.from_angle(angle) * radius
			draw_arc(position_on_ring, 5, -PI * 0.7, PI * 0.7, 12, color, 1.8, true)

func _draw_effect(effect: Dictionary) -> void:
	var progress := float(effect.age) / float(effect.duration)
	var alpha := 1.0 - progress
	match str(effect.kind):
		"lightning":
			var from := world(effect.from)
			var to := world(effect.to)
			var color := Color(BLUE if effect.echo else GOLD, alpha)
			var normal := (to - from).normalized().orthogonal()
			var points := PackedVector2Array([from])
			for i in range(1, 12):
				var wave := sin(float(effect.seed) + float(i) * 5.73) * (3.0 if reduced_motion else 10.0)
				points.append(from.lerp(to, float(i) / 12.0) + normal * wave)
			points.append(to)
			draw_polyline(points, Color(color, alpha * 0.12), float(effect.width) + 5, true)
			draw_polyline(points, color, 3.0 + float(effect.width) * 0.07, true)
			draw_circle(from, 8.0 * alpha, Color(color, alpha * 0.45))
			draw_polyline(points, Color(PAPER, alpha * 0.9), 1.0, true)
		"number":
			var at := world(effect.position) - Vector2(7, 25 + progress * (5.0 if reduced_motion else 24.0))
			var color := Color(BLUE if effect.echo else PAPER, alpha)
			draw_string_outline(font, at, str(effect.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 3, Color(INK, alpha))
			draw_string(font, at, str(effect.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
		"vanish":
			var at := world(effect.position)
			for i in range(5):
				var direction := Vector2.from_angle(TAU * float(i) / 5.0)
				draw_line(at + direction * (5 + progress * 13), at + direction * (9 + progress * 19), Color(GOLD, alpha * 0.8), 2.0, true)
		"resonance":
			var at := world(effect.position)
			var radius := 18.0 + progress * (12.0 if reduced_motion else 42.0)
			draw_arc(at, radius, 0, PI, 32, Color(GOLD, alpha * 0.9), 3, true)
			draw_arc(at, radius, PI, TAU, 32, Color(BLUE, alpha * 0.9), 3, true)
			for i in range(6):
				var direction := Vector2.from_angle(float(i) * TAU / 6.0)
				draw_line(at + direction * radius * 0.5, at + direction * (radius + 10), Color(PAPER, alpha * 0.65), 1.7, true)
			if resonance_labels < 4:
				resonance_labels += 1
				var label_at := at + Vector2(-36, -38 - progress * 10)
				var label := "挟撃 +%d" % roundi(float(effect.get("damage", 0.0)))
				draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(INK, alpha))
				draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(GOLD, alpha))
		"hurt":
			var at := world(effect.position)
			draw_arc(at, 24 + progress * 28, 0, TAU, 40, Color(DANGER, alpha * 0.8), 3, true)

func _draw_vignette() -> void:
	# Opaque edge bands separate the HUD from a busy garden without hiding paths.
	draw_rect(Rect2(0, 0, screen.x, 110), Color(INK, 0.12))
	draw_rect(Rect2(0, screen.y - 110, screen.x, 110), Color(INK, 0.1))

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, Vector2(1, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, color)
	draw_set_transform(Vector2.ZERO)

func _elliptic_arc(center: Vector2, radius: Vector2, from: float, to: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var angle := lerpf(from, to, float(i) / 32.0)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)

func _dotted_line(from: Vector2, to: Vector2, color: Color, segments: int, width: float) -> void:
	for i in range(segments):
		var start := float(i) / float(segments)
		var end := minf(1.0, start + 0.5 / float(segments))
		draw_line(from.lerp(to, start), from.lerp(to, end), color, width, true)
