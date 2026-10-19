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

func _ready() -> void:
	for id in ["witch", "hound", "charger", "archer", "garden_tile", "moon"]:
		var path := "res://assets/art/%s.svg" % id
		if ResourceLoader.exists(path):
			textures[id] = load(path)
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf"):
		font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	else:
		font = ThemeDB.fallback_font

func refresh() -> void:
	screen = get_viewport_rect().size
	queue_redraw()

func world(at: Vector2) -> Vector2:
	return at - run.player + screen * Vector2(0.5, 0.52)

func _draw() -> void:
	if run == null:
		return
	_draw_ground()
	if run.state == "title":
		_draw_title_art()
		return
	_draw_trail()
	for pickup in run.pickups:
		_draw_pickup(pickup)
	for enemy in run.enemies:
		_draw_telegraph(enemy)
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
			_draw_witch(world(actor.position), actor.type == "echo", 64.0)
	for effect in run.effects:
		_draw_effect(effect)
	_draw_vignette()

func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color("131c2a"))
	var camera: Vector2 = run.player - screen * Vector2(0.5, 0.52)
	var tile_size := 256.0
	var start := (camera / tile_size).floor() * tile_size
	for x in range(-1, int(screen.x / tile_size) + 2):
		for y in range(-1, int(screen.y / tile_size) + 2):
			var at := start + Vector2(x, y) * tile_size - camera
			if textures.has("garden_tile"):
				draw_texture_rect(textures.garden_tile, Rect2(at, Vector2.ONE * tile_size), false, Color(0.66, 0.76, 0.8, 0.68))
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
	var moon_at := Vector2(screen.x * 0.79, 184.0)
	if textures.has("moon"):
		draw_texture_rect(textures.moon, Rect2(moon_at - Vector2.ONE * 128.0, Vector2.ONE * 256.0), false, Color(0.95, 0.9, 0.71, 0.88))
	var center := Vector2(screen.x * 0.79, 465.0)
	draw_arc(center + Vector2(0, 35), 146, 0, TAU, 90, Color(0.86, 0.75, 0.5, 0.23), 2.0, true)
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var at := center + Vector2.from_angle(angle) * 146.0 + Vector2(0, 35)
		draw_line(at - Vector2(0, 5), at + Vector2(0, 5), GOLD * Color(1, 1, 1, 0.4), 2.0)
	_draw_witch(center + Vector2(-82, 36), true, 164.0)
	_draw_witch(center + Vector2(21, -4), false, 196.0)
	draw_string(font, center + Vector2(-62, 150), "2秒前のあなたと。", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BLUE)

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
	var scale_factor := size / 64.0
	var tint := Color(BLUE, 0.73) if is_echo else PAPER
	var ring_at := at + Vector2(0, 19.0 * scale_factor)
	_ellipse(ring_at + Vector2(0, 2), Vector2(23, 9) * scale_factor, Color(0.01, 0.02, 0.04, 0.45))
	if is_echo:
		for i in range(12):
			var a := float(i) * TAU / 12.0
			_elliptic_arc(ring_at, Vector2(23, 10) * scale_factor, a, a + 0.29, Color(BLUE, 0.9), 1.8)
	else:
		_elliptic_arc(ring_at, Vector2(23, 10) * scale_factor, 0.0, TAU, Color(PAPER, 0.85), 1.8)
	var bob := 0.0
	if not reduced_motion and run.state != "title":
		bob = sin(run.elapsed * 5.0) * 1.5
	var flash: bool = not is_echo and run.invulnerable > 0.0 and not reduced_motion and sin(run.elapsed * 35.0) > 0.0
	if flash:
		tint = Color(1.5, 1.1, 1.0)
	if textures.has("witch"):
		draw_texture_rect(textures.witch, Rect2(at - Vector2(size * 0.5, size * 0.56) + Vector2(0, bob), Vector2.ONE * size), false, tint)
	if is_echo and size < 100.0:
		draw_string(font, at + Vector2(-15, -38), "残像", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLUE)

func _draw_enemy(enemy: Dictionary) -> void:
	var at := world(enemy.position)
	if at.x < -80 or at.y < -80 or at.x > screen.x + 80 or at.y > screen.y + 80:
		return
	var size := 46.0
	if enemy.kind == "charger":
		size = 58.0
	elif enemy.kind == "archer":
		size = 51.0
	var alpha := 1.0
	if enemy.phase == "arrival":
		alpha = clampf(1.0 - float(enemy.timer) / 0.55, 0.15, 1.0)
		_elliptic_arc(at + Vector2(0, 13), Vector2(24, 10), 0, TAU, Color(DANGER, 0.32), 1.0)
	_ellipse(at + Vector2(0, 16), Vector2(size * 0.34, 7), Color(0.0, 0.01, 0.025, 0.4 * alpha))
	var tint := Color(1, 1, 1, alpha)
	if float(enemy.flash) > 0.0 and not reduced_motion:
		tint = Color(1.8, 1.5, 1.2, alpha)
	if textures.has(enemy.kind):
		draw_texture_rect(textures[enemy.kind], Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, tint)
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
