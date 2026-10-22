extends Node2D
## The model owns every clock and hit shape; frozen overlays reuse draw commands.

const FloorArt := preload("res://scripts/campaign_floor.gd")
const SceneryCache := preload("res://scripts/scenery_cache.gd")
const PixelActors := preload("res://scripts/pixel_actors.gd")
const Presentation := preload("res://scripts/presentation.gd")
const PresentationFX := preload("res://scripts/presentation_fx.gd")
const WHITE_DISC := preload("res://assets/art/white-disc.svg")
const DISC_PADDING := 64.0 / 62.0
const Grimoire := preload("res://scripts/grimoire_theme.gd")
const INK := Grimoire.NIGHT
const PAPER := Grimoire.TEXT
const GOLD := Grimoire.GOLD
const BLUE := Grimoire.ECHO
const DANGER := Grimoire.DANGER
const FROST := Color("b8dce1")
const THORN := Color("a6bd8b")
const WISP := Color("c6a8e0")
const MAX_NUMBERS := 18
const MAX_EFFECTS := 86
const MIN_STAR_RADIUS := 0.5

var run
var reduced_motion := false
var textures: Dictionary = {}
var font: Font
var screen := Vector2(1280, 720)
var resonance_labels := 0
var number_labels := 0
var last_signature: Array = []
var chapter_geometry: Dictionary = {}
var scenery_cache
var pixel_actors = PixelActors.new()
var presentation = Presentation.new()
var presentation_fx = PresentationFX.new()
var camera_offset := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var paths := {
		"witch": "witch-r2.png",
		"garden_tile": "garden-r2.svg", "moon": "moon.svg", "keyart": "campaign-keyart.png"
	}
	for id in paths:
		var path := "res://assets/art/%s" % str(paths[id])
		if ResourceLoader.exists(path):
			textures[id] = load(path)
	font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf") if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf") else ThemeDB.fallback_font
	scenery_cache = SceneryCache.new()
	scenery_cache.z_index = -1
	scenery_cache.visible = false
	add_child(scenery_cache)

func refresh() -> void:
	if run == null:
		return
	var next_size := get_viewport_rect().size
	# Chapter changes can leave elapsed unchanged. Include geometry/state inputs so
	# a frozen chapter-clear screen and a restarted title never reuse another biome.
	var signature: Array = [run.elapsed, str(run.state), reduced_motion, next_size, run.chapter, run.chapter_elapsed, str(run.chapter_stage), run.player, run.health, run.echo_active, run.chests.size(), run.pickups.size()]
	if signature == last_signature:
		return
	last_signature = signature
	presentation.update(run)
	camera_offset = presentation_fx.camera_offset(presentation, run, reduced_motion)
	screen = next_size
	chapter_geometry = run.chapter_info()
	scenery_cache.visible = run.state != "title"
	if scenery_cache.visible:
		scenery_cache.select_chapter(int(run.chapter), chapter_geometry, textures)
		scenery_cache.position = -run.player + screen * Vector2(0.5, 0.52) + camera_offset
	queue_redraw()

func world(at: Vector2) -> Vector2:
	return at - run.player + screen * Vector2(0.5, 0.52) + camera_offset

func _draw() -> void:
	if run == null:
		return
	resonance_labels = 0
	number_labels = 0
	if run.state == "title":
		_draw_title_art()
		return
	FloorArt.draw_ambient(self, int(run.chapter))
	_draw_trail()
	var obstacles: Array = chapter_geometry.get("obstacles", [])
	var actors: Array[Dictionary] = []
	for i in range(obstacles.size()):
		var obstacle: Rect2 = obstacles[i]
		scenery_cache.draw_obstacle(self, i, true)
		actors.append({"type": "obstacle", "position": obstacle.end, "rect": obstacle, "index": i})
	for pickup in run.pickups:
		_draw_pickup(pickup)
	for chest in run.chests:
		actors.append({"type": "chest", "position": chest.position, "data": chest})
	for enemy in run.enemies:
		actors.append({"type": "enemy", "position": enemy.position, "data": enemy})
	for corpse in presentation.deaths:
		actors.append({"type": "death", "position": corpse.position, "data": corpse})
	if run.echo_active:
		actors.append({"type": "echo", "position": run.echo})
	actors.append({"type": "player", "position": run.player})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y)
	for actor in actors:
		match str(actor.type):
			"obstacle":
				scenery_cache.draw_obstacle(self, int(actor.index))
			"chest":
				_draw_chest(actor.data)
			"enemy":
				_draw_enemy(actor.data)
			"death":
				_draw_death(actor.data)
			_:
				_draw_witch(world(actor.position), actor.type == "echo", 82.0)
	for shot in run.projectiles:
		_draw_projectile(shot)
	# Newest feedback survives the cap. Damage numbers never blanket a boss cue.
	var start := maxi(0, run.effects.size() - MAX_EFFECTS)
	for i in range(run.effects.size() - 1, start - 1, -1):
		_draw_effect(run.effects[i])
	presentation_fx.draw_world(self, presentation, run, reduced_motion)
	_draw_wayfinding()
	# Hostile intent and its live damage area always sit above friendly spells.
	for enemy in run.enemies:
		_draw_telegraph(enemy)
	for hazard in run.hazards:
		_draw_hazard(hazard)
	_draw_vignette()
	presentation_fx.draw_screen(self, presentation, run, reduced_motion)

func _draw_title_art() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Grimoire.NIGHT)
	var portrait_scale := minf(screen.x / 1280.0, screen.y / 720.0)
	if textures.has("keyart"):
		var texture: Texture2D = textures.keyart
		var factor := maxf(screen.x / texture.get_width(), screen.y / texture.get_height())
		var image_size := texture.get_size() * factor
		draw_texture_rect(texture, Rect2((screen - image_size) * 0.5, image_size), false)
		# The ink wash supports the typography while leaving the garden illustration open.
		var wash := PackedVector2Array([Vector2.ZERO, Vector2(screen.x * 0.72, 0), Vector2(screen.x * 0.72, screen.y), Vector2(0, screen.y)])
		var wash_colors := PackedColorArray([Color(Grimoire.NIGHT, 0.97), Color(Grimoire.NIGHT, 0.02), Color(Grimoire.NIGHT, 0.02), Color(Grimoire.NIGHT, 0.97)])
		draw_polygon(wash, wash_colors)
		draw_rect(Rect2(Vector2.ZERO, screen), Color(Grimoire.NIGHT, 0.12))
	elif textures.has("moon"):
		var moon_at := Vector2(screen.x * 0.80, screen.y * 0.24)
		draw_texture_rect(textures.moon, Rect2(moon_at - Vector2.ONE * 116 * portrait_scale, Vector2.ONE * 232 * portrait_scale), false, Color(PAPER, 0.8))
	# An engraved arch and paired seals belong to the same manuscript as the UI.
	# Their positions are authored, so the illustration has a clear visual axis.
	var arch_at := screen * Vector2(0.79, 0.50)
	var arch_size := Vector2(207, 258) * portrait_scale
	_elliptic_arc(arch_at, arch_size, PI * 0.89, TAU + PI * 0.11, Color(GOLD, 0.34), 1.3)
	_elliptic_arc(arch_at, arch_size + Vector2.ONE * 10 * portrait_scale, PI * 0.89, TAU + PI * 0.11, Color(GOLD, 0.11), 1)
	var seal_at := arch_at + Vector2(0, -258) * portrait_scale
	draw_arc(seal_at + Vector2(-9, 0) * portrait_scale, 14 * portrait_scale, 0, TAU, 32, Color(GOLD, 0.75), 1, true)
	draw_arc(seal_at + Vector2(9, 0) * portrait_scale, 14 * portrait_scale, 0, TAU, 32, Color(BLUE, 0.65), 1, true)
	for side in [-1.0, 1.0]:
		var at := arch_at + Vector2(side * 207, 31) * portrait_scale
		_star(at, 5 * portrait_scale, Color(GOLD, 0.62))
		draw_line(at + Vector2(0, 14) * portrait_scale, at + Vector2(0, 110) * portrait_scale, Color(GOLD, 0.22), 1, true)
	var portrait_at := screen * Vector2(0.79, 0.94)
	_draw_witch(portrait_at + Vector2(-101, 9) * portrait_scale, true, 266 * portrait_scale)
	_draw_witch(portrait_at, false, 358 * portrait_scale)
	_elliptic_arc(portrait_at + Vector2(-30, 4) * portrait_scale, Vector2(191, 31) * portrait_scale, 0, TAU, Color(GOLD, 0.31), 1.1)

func _draw_trail() -> void:
	if not run.echo_active or run.player.distance_to(run.echo) < 35.0:
		return
	var index := 0
	for sample in run.timeline.positions:
		index += 1
		if index % 10 != 0:
			continue
		var fraction := clampf((float(sample.time) - (run.chapter_elapsed - 2.0)) / 2, 0, 1)
		var at := world(sample.position) + Vector2(0, 18)
		draw_line(at - Vector2(2, 0), at + Vector2(2, 0), Color(BLUE, 0.14 + fraction * 0.17), 1.6, true)

func _draw_witch(at: Vector2, is_echo: bool, size: float) -> void:
	var scale_factor := size / 82
	var tint := Color(0.45, 0.87, 1.10, 0.61) if is_echo else Color.WHITE
	_ellipse(at + Vector2(0, 3), Vector2(21, 7) * scale_factor, Color(0.01, 0.02, 0.04, 0.50))
	if is_echo:
		for i in range(12):
			var angle := float(i) * TAU / 12
			_elliptic_arc(at, Vector2(22, 9) * scale_factor, angle, angle + 0.27, Color(BLUE, 0.95), 1.7)
	else:
		_elliptic_arc(at, Vector2(21, 9) * scale_factor, 0, TAU, Color(PAPER, 0.95), 2)
		_star(at + Vector2(0, 11) * scale_factor, 3 * scale_factor, GOLD)
	var bob := 0.0 if reduced_motion or run.state == "title" else sin(run.elapsed * 6) * 1.2
	var tilt := 0.0 if reduced_motion or run.state == "title" else sin(run.elapsed * 5) * 0.025
	var facing := float(run.facing) if run.state != "title" else 1.0
	if is_echo and run.state != "title":
		var old_position: Vector2 = run.timeline.position_at(maxf(0, run.chapter_elapsed - 2.1))
		if absf(run.echo.x - old_position.x) > 0.1:
			facing = signf(run.echo.x - old_position.x)
	if not is_echo and run.invulnerable > 0:
		tint = Color(1.35, 0.85, 0.75) if reduced_motion else Color(1.5, 1.2, 1.1, 0.73 + sin(run.elapsed * 32) * 0.16)
	if run.state != "title" and size < 100:
		var pose: Dictionary = presentation.echo_pose if is_echo else presentation.player_pose
		pixel_actors.draw_actor(self, at, "witch", size, pose, tint, reduced_motion)
	elif textures.has("witch"):
		draw_set_transform(at + Vector2(0, bob), tilt, Vector2(facing, 1))
		draw_texture_rect(textures.witch, Rect2(Vector2(-size * 0.5, -size * 0.87), Vector2.ONE * size), false, tint)
		draw_set_transform(Vector2.ZERO)
	if is_echo and size < 100:
		draw_string_outline(font, at + Vector2(-14, -size * 0.83), "残像", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, INK)
		draw_string(font, at + Vector2(-14, -size * 0.83), "残像", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BLUE)

func _draw_enemy(enemy: Dictionary) -> void:
	var at := world(enemy.position)
	var boss := bool(enemy.get("boss", false))
	if not _on_screen(at, 240 if boss else 100):
		return
	var kind := str(enemy.kind)
	var size := 64.0
	match kind:
		"charger", "sentinel":
			size = 86
		"archer", "wisp":
			size = 76
		"bat":
			size = 53
	if boss:
		size = 210 if kind == "boss_thorn" else 198 if kind == "boss_mirror" else 224
	var elite := bool(enemy.get("elite", false))
	if elite:
		size *= 1.22
	var alpha := 1.0
	if str(enemy.get("phase", "seek")) == "arrival":
		alpha = clampf(1.0 - float(enemy.get("timer", 0)) / maxf(0.01, float(enemy.get("arrival_duration", 0.9))), 0.20, 1)
		_elliptic_arc(at + Vector2(0, 7), Vector2(size * 0.31, size * 0.12), 0, TAU, Color(DANGER, 0.40), 1.5)
	_ellipse(at + Vector2(0, 10), Vector2(size * 0.30, 9 if boss else 7), Color(0, 0.01, 0.025, 0.50 * alpha))
	var tint := Color(1, 1, 1, alpha)
	if kind == "wisp":
		tint = Color(0.75, 0.89, 1.06, alpha)
	elif kind == "sentinel":
		tint = Color(0.82, 0.88, 0.86, alpha)
	if float(enemy.get("flash", 0)) > 0 and not reduced_motion:
		tint = Color(1.65, 1.35, 1.20, alpha)
	var pose: Dictionary = presentation.enemy_poses.get(int(enemy.id), {})
	pixel_actors.draw_actor(self, at, kind, size, pose, tint, reduced_motion)
	if elite:
		_draw_elite_crown(at - Vector2(0, size * 0.70), alpha)
	if boss and int(enemy.get("phase_index", 1)) >= 2:
		for i in range(3):
			var point := at + Vector2(float(i - 1) * 19, 19)
			_star(point, 4, Color(DANGER, alpha))
	var mark: Dictionary = enemy.get("mark", {})
	if not mark.is_empty() and float(mark.get("expires", 0)) > run.elapsed:
		var color := GOLD if str(mark.get("source", "player")) == "player" else BLUE
		var radius := 27.0 if not boss else 56.0
		draw_arc(at, radius, PI * 0.2, PI * 0.8, 16, color, 2.3, true)
		draw_arc(at, radius, PI * 1.2, PI * 1.8, 16, color, 2.3, true)
	if not boss and float(enemy.hp) < float(enemy.max_hp):
		var y := -size * 0.75 - (12 if elite else 3)
		draw_line(at + Vector2(-18, y), at + Vector2(18, y), INK, 5)
		draw_line(at + Vector2(-18, y), at + Vector2(-18 + 36 * clampf(float(enemy.hp) / float(enemy.max_hp), 0, 1), y), DANGER, 3)

func _draw_death(corpse: Dictionary) -> void:
	var at := world(corpse.get("position", Vector2.ZERO))
	if not _on_screen(at, 250.0):
		return
	var pose: Dictionary = corpse.get("pose", {}).duplicate()
	pose.animation = "death"
	pose.time = float(corpse.get("age", 0.0))
	pose.phase_progress = clampf(pose.time / maxf(0.01, float(corpse.get("duration", 0.45))), 0.0, 1.0)
	var tint := Color(0.85, 0.90, 1.0, 1.0 - pose.phase_progress * 0.45)
	pixel_actors.draw_actor(self, at, str(corpse.get("kind", "hound")), float(corpse.get("size", 64.0)), pose, tint, reduced_motion)

func _pose_snapshot(kind: String, pose: Dictionary) -> Dictionary:
	var frame: Dictionary = pixel_actors.frame_info(kind, pose, reduced_motion)
	return {"kind": kind, "animation": str(pose.get("animation", "idle")), "frame": int(frame.index), "gait": float(pose.get("gait", 0.0)), "cast": float(pose.get("cast", 0.0)), "hit": float(pose.get("hit", 0.0)), "facing": int(pose.get("facing", 1)), "moving": bool(pose.get("moving", false))}

func motion_snapshot() -> Dictionary:
	var enemy_samples: Array = []
	for enemy in run.enemies:
		if enemy_samples.size() >= 11 and not bool(enemy.get("boss", false)):
			continue
		if enemy_samples.size() >= 12:
			break
		var pose: Dictionary = presentation.enemy_poses.get(int(enemy.id), {})
		var sample := _pose_snapshot(str(enemy.kind), pose)
		sample.id = int(enemy.id)
		enemy_samples.append(sample)
	var recent: Array = []
	for i in range(maxi(0, presentation.events.size() - 8), presentation.events.size()):
		var event: Dictionary = presentation.events[i]
		recent.append({"kind": str(event.kind), "serial": int(event.get("serial", 0)), "age": float(event.age), "echo": bool(event.get("echo", false))})
	return {"clock": float(run.elapsed), "generation": int(presentation.generation), "serial": int(presentation.latest_serial), "player": _pose_snapshot("witch", presentation.player_pose), "echo": _pose_snapshot("witch", presentation.echo_pose), "enemies": enemy_samples, "event_count": presentation.events.size(), "event_limit": presentation.MAX_EVENTS, "death_count": presentation.deaths.size(), "death_limit": presentation.MAX_DEATHS, "recent_events": recent, "actors": pixel_actors.diagnostics(), "fx": presentation_fx.diagnostics(), "camera": {"x": camera_offset.x, "y": camera_offset.y}}

func _draw_elite_crown(at: Vector2, alpha: float) -> void:
	var crown := PackedVector2Array([at + Vector2(-15, 6), at + Vector2(-18, -8), at + Vector2(-6, -2), at + Vector2(0, -15), at + Vector2(6, -2), at + Vector2(18, -8), at + Vector2(15, 6)])
	draw_colored_polygon(crown, Color(0.69, 0.42, 0.47, alpha))
	var border := crown.duplicate()
	border.append(crown[0])
	draw_polyline(border, Color(0.94, 0.74, 0.66, alpha), 1.4, true)
	_star(at + Vector2(0, 1), 3, Color(PAPER, alpha))

func _draw_telegraph(enemy: Dictionary) -> void:
	if enemy.get("phase", "") != "warning" or bool(enemy.get("boss", false)):
		return
	var kind := str(enemy.kind)
	if kind not in ["charger", "archer", "wisp"]:
		return
	var at := world(enemy.position)
	var direction: Vector2 = enemy.get("direction", Vector2.DOWN)
	var length := float(enemy.get("warning_length", 296 if kind == "charger" else 495))
	var end := at + direction * length
	var progress := 1.0 - float(enemy.get("timer", 0)) / float(enemy.get("warning_duration", 0.95))
	if kind == "charger":
		_capsule(at, end, float(enemy.get("warning_width", float(enemy.get("radius", 22)) * 2)), Color(DANGER, 0.10), Color(DANGER, 0.73), 1.5)
	elif kind == "wisp":
		for i in range(3):
			var ray := direction.rotated(float(i - 1) * 0.19)
			var ray_end := at + ray * length
			draw_line(at, ray_end, Color(INK, 0.8), 4.2, true)
			_dotted_line(at, ray_end, Color(DANGER, 0.80), 16, 2)
	else:
		draw_line(at, end, Color(INK, 0.8), 4.2, true)
		_dotted_line(at, end, Color(DANGER, 0.80), 16, 2)
	var normal := direction.orthogonal()
	draw_arc(at, 29, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0, 1), 48, DANGER, 2.5, true)
	draw_line(end, end - direction * 14 + normal * 8, DANGER, 2, true)
	draw_line(end, end - direction * 14 - normal * 8, DANGER, 2, true)

func _draw_hazard(hazard: Dictionary) -> void:
	var age := float(hazard.get("age", 0))
	var delay := float(hazard.get("delay", 0))
	var duration := float(hazard.get("duration", 0))
	if age >= delay + duration:
		return
	var active := age >= delay
	var progress := clampf(age / maxf(0.01, delay), 0, 1)
	var fill := Color(DANGER, 0.22 if active else 0.045 + progress * 0.055)
	var edge := Color("ffd5b3") if active else Color(DANGER, 0.85)
	var at := world(hazard.get("position", Vector2.ZERO))
	var radius := float(hazard.get("radius", 40))
	var width := float(hazard.get("width", 20))
	match str(hazard.get("shape", "circle")):
		"line":
			var start := world(hazard.get("from", hazard.get("position", Vector2.ZERO)))
			var end := world(hazard.get("to", hazard.get("position", Vector2.ZERO)))
			_capsule(start, end, width, fill, edge, 2.5 if active else 1.8)
			if active:
				var normal := (end - start).normalized().orthogonal() * width * 0.36
				for i in range(1, 9):
					var point := start.lerp(end, float(i) / 9)
					draw_line(point - normal, point + normal, Color(DANGER, 0.53), 2, true)
			else:
				_dotted_line(start, start.lerp(end, progress), Color(DANGER, 0.70), 16, 2)
		"ring":
			var outer := radius + width * 0.5
			var inner := maxf(0, radius - width * 0.5)
			if inner <= 0:
				_disc(at, outer, fill)
			else:
				draw_arc(at, radius, 0, TAU, 112, fill, width, true)
			draw_arc(at, outer, 0, TAU, 112, edge, 2.4 if active else 1.8, true)
			if inner > 0:
				draw_arc(at, inner, 0, TAU, 112, edge, 2.4 if active else 1.8, true)
			for i in range(20):
				var direction := Vector2.from_angle(float(i) * TAU / 20)
				draw_line(at + direction * (inner + 3), at + direction * (outer - 3), Color(DANGER, 0.48 if active else 0.20), 2, true)
			if not active:
				draw_arc(at, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 80, Color(DANGER, 0.72), 2, true)
		_:
			_disc(at, radius, fill)
			draw_arc(at, radius, 0, TAU, 80, edge, 2.5 if active else 1.8, true)
			if active:
				for i in range(8):
					var direction := Vector2.from_angle(float(i) * TAU / 8)
					draw_line(at + direction * maxf(10, radius - 14), at + direction * maxf(12, radius - 4), Color(DANGER, 0.85), 2, true)
			else:
				draw_arc(at, maxf(2, radius - 5), -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(DANGER, 0.48), 2, true)
	# Center warning has a different silhouette from both pickups and spell sigils.
	if str(hazard.get("shape", "circle")) != "ring":
		var sign_at := at
		if str(hazard.get("shape", "")) == "line":
			sign_at = world(hazard.get("from", Vector2.ZERO)).lerp(world(hazard.get("to", Vector2.ZERO)), 0.5)
		draw_line(sign_at + Vector2(0, -8), sign_at + Vector2(0, 1), edge, 3, true)
		_disc(sign_at + Vector2(0, 6), 1.8, edge)

func _draw_pickup(pickup: Dictionary) -> void:
	var at := world(pickup.position)
	if not _on_screen(at, 24):
		return
	var kind := str(pickup.get("kind", "xp"))
	if kind == "xp":
		var size := 5.0 + minf(int(pickup.get("value", 1)), 3)
		_disc(at, size * 1.8, Color(GOLD, 0.065))
		var diamond := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.7, 0), at + Vector2(0, size), at + Vector2(-size * 0.7, 0)])
		draw_colored_polygon(diamond, GOLD)
		draw_line(at + Vector2(0, -size + 1), at + Vector2(0, size - 1), PAPER, 1.2)
		if (pickup.position as Vector2).distance_to(run.player) < run.pickup_radius:
			draw_line(at, at.lerp(world(run.player), 0.12), Color(GOLD, 0.22), 1)
		return
	_ellipse(at + Vector2(0, 8), Vector2(13, 5), Color(0, 0.01, 0.02, 0.50))
	_disc(at, 17, Color(INK, 0.96))
	draw_arc(at, 17, 0, TAU, 40, Color(GOLD, 0.65), 1.6, true)
	match kind:
		"heal":
			var bottle := PackedVector2Array([at + Vector2(-4, -10), at + Vector2(4, -10), at + Vector2(4, -5), at + Vector2(8, -1), at + Vector2(7, 9), at + Vector2(-7, 9), at + Vector2(-8, -1), at + Vector2(-4, -5)])
			draw_colored_polygon(bottle, Color("bb8291"))
			draw_line(at + Vector2(-4, -11), at + Vector2(4, -11), GOLD, 3, true)
			draw_line(at + Vector2(0, -2), at + Vector2(0, 6), PAPER, 2, true)
			draw_line(at + Vector2(-4, 2), at + Vector2(4, 2), PAPER, 2, true)
		"magnet":
			draw_arc(at + Vector2(0, -1), 8, 0, PI, 24, BLUE, 5, true)
			draw_line(at + Vector2(-8, -7), at + Vector2(-8, 0), PAPER, 4, true)
			draw_line(at + Vector2(8, -7), at + Vector2(8, 0), GOLD, 4, true)
		"ward":
			var leaf := PackedVector2Array([at + Vector2(-7, 9), at + Vector2(-9, -2), at + Vector2(-4, -10), at + Vector2(9, -10), at + Vector2(8, 2), at + Vector2(-7, 9)])
			draw_colored_polygon(leaf, THORN)
			draw_line(at + Vector2(-6, 10), at + Vector2(5, -6), INK, 1.5, true)
		"blast":
			_star(at, 10, GOLD)
			_disc(at, 3.5, PAPER)
		_:
			_star(at, 8, GOLD)

func _draw_chest(chest: Dictionary) -> void:
	var at := world(chest.position)
	if not _on_screen(at, 50):
		return
	var opened := bool(chest.get("opened", false))
	_ellipse(at + Vector2(0, 11), Vector2(24, 8), Color(0, 0.01, 0.02, 0.55))
	if not opened:
		_elliptic_arc(at + Vector2(0, 9), Vector2(26, 11), 0, TAU, Color(GOLD, 0.60), 1.5)
		for side in [-1.0, 1.0]:
			_star(at + Vector2(side * 28, -11), 3, GOLD)
	draw_rect(Rect2(at + Vector2(-18, -9), Vector2(36, 24)), Color("493841"))
	draw_rect(Rect2(at + Vector2(-18, -9), Vector2(36, 24)), GOLD, false, 2)
	var lid_y := -26.0 if opened else -14.0
	var lid := PackedVector2Array([at + Vector2(-20, lid_y + 7), at + Vector2(-15, lid_y - 4), at + Vector2(14, lid_y - 4), at + Vector2(20, lid_y + 7), at + Vector2(-20, lid_y + 7)])
	draw_colored_polygon(lid, Color("66505b"))
	draw_polyline(lid, GOLD, 2, true)
	for x in [-11.0, 11.0]:
		draw_line(at + Vector2(x, lid_y - 2), at + Vector2(x, 13), Color(GOLD, 0.73), 2, true)
	draw_rect(Rect2(at + Vector2(-4, -5), Vector2(8, 9)), GOLD)
	if not opened:
		_star(at + Vector2(0, -1), 3, PAPER)

func _draw_wayfinding() -> void:
	# Edge pointers refer to real persistent objects, with the HUD bands excluded.
	var safe := Rect2(43, 129, maxf(1, screen.x - 86), maxf(1, screen.y - 260))
	var markers := 0
	for chest in run.chests:
		if bool(chest.get("opened", false)):
			continue
		var target := world(chest.position)
		if safe.has_point(target):
			continue
		_draw_edge_pointer(_edge_position(target, safe), target, GOLD, false)
		markers += 1
		if markers >= 2:
			break
	for enemy in run.enemies:
		if not bool(enemy.get("boss", false)):
			continue
		var target := world(enemy.position)
		if not safe.has_point(target):
			_draw_edge_pointer(_edge_position(target, safe), target, DANGER, true)
		break

func _edge_position(target: Vector2, safe: Rect2) -> Vector2:
	var origin := world(run.player)
	var direction := (target - origin).normalized()
	var distance := INF
	if absf(direction.x) > 0.0001:
		distance = minf(distance, ((safe.end.x if direction.x > 0 else safe.position.x) - origin.x) / direction.x)
	if absf(direction.y) > 0.0001:
		distance = minf(distance, ((safe.end.y if direction.y > 0 else safe.position.y) - origin.y) / direction.y)
	return origin + direction * maxf(0, distance)

func _draw_edge_pointer(at: Vector2, target: Vector2, color: Color, boss: bool) -> void:
	var direction := (target - at).normalized()
	var normal := direction.orthogonal()
	var frame := PackedVector2Array([at + Vector2(0, -19), at + Vector2(19, 0), at + Vector2(0, 19), at + Vector2(-19, 0), at + Vector2(0, -19)])
	draw_colored_polygon(frame, Color(INK, 0.95))
	draw_polyline(frame, Color(color, 0.65), 1.4, true)
	var arrow_tip := at + direction * 30
	draw_polyline(PackedVector2Array([arrow_tip - direction * 7 + normal * 5, arrow_tip, arrow_tip - direction * 7 - normal * 5]), color, 2, true)
	if boss:
		var crown := PackedVector2Array([at + Vector2(-9, 5), at + Vector2(-11, -7), at + Vector2(-4, -2), at + Vector2(0, -11), at + Vector2(4, -2), at + Vector2(11, -7), at + Vector2(9, 5)])
		draw_colored_polygon(crown, color)
	else:
		draw_rect(Rect2(at + Vector2(-9, -3), Vector2(18, 12)), Color(color, 0.20))
		draw_rect(Rect2(at + Vector2(-9, -3), Vector2(18, 12)), color, false, 1.5)
		draw_polyline(PackedVector2Array([at + Vector2(-10, -3), at + Vector2(-7, -9), at + Vector2(7, -9), at + Vector2(10, -3)]), color, 1.5, true)
		_star(at + Vector2(0, 1), 3, PAPER)

func _draw_projectile(shot: Dictionary) -> void:
	if float(shot.get("age", 0)) < 0:
		return
	var at := world(shot.position)
	var kind := str(shot.kind)
	var radius := float(shot.get("radius", 10))
	if not _on_screen(at, maxf(40, radius + 10)):
		return
	var age := float(shot.get("age", 0))
	var duration := float(shot.get("duration", 1))
	var alpha := clampf((duration - age) / minf(0.28, duration * 0.35), 0, 1)
	var is_echo := bool(shot.get("echo", false))
	var evolved := bool(shot.get("evolved", false))
	var color := BLUE if is_echo else PAPER
	match kind:
		"bolt":
			var direction: Vector2 = (shot.get("velocity", Vector2.DOWN) as Vector2).normalized()
			draw_line(at - direction * 14, at + direction * 5, Color(DANGER, 0.28), 8, true)
			draw_line(at - direction * 9, at + direction * 5, DANGER, 3, true)
			_disc(at, 3, PAPER)
		"thorn":
			_draw_thorn_projectile(at, shot, Color(BLUE if is_echo else THORN, alpha), evolved)
		"wisp":
			_draw_wisp_projectile(at, shot, Color(BLUE if is_echo else WISP, alpha), evolved)
		"bramble":
			_draw_bramble_field(at, float(shot.get("current_radius", radius)), Color(BLUE if is_echo else THORN, alpha), is_echo)
		"frost":
			_draw_frost_field(at, radius, age, Color(BLUE if is_echo else FROST, alpha), evolved, is_echo)
		"bell":
			var current_radius := float(shot.get("current_radius", radius * minf(1, age / 0.75)))
			_draw_bell_wave(at, current_radius, float(shot.get("width", 22)), Color(BLUE if is_echo else GOLD, alpha), evolved, is_echo)
		"moon":
			var current_radius := float(shot.get("current_radius", radius * minf(1, age / 0.55)))
			_draw_moon_wave(at, current_radius, age, Color(color, alpha), evolved, is_echo)

func _draw_moon_wave(at: Vector2, radius: float, age: float, color: Color, evolved: bool, is_echo: bool) -> void:
	_disc(at, radius, Color(color, color.a * 0.025))
	draw_arc(at, radius, 0, TAU, 80, Color(color, color.a * 0.12), 10, true)
	draw_arc(at, radius, 0, TAU, 80, color, 2.3, true)
	if evolved:
		draw_arc(at, maxf(0, radius - 8), 0, TAU, 80, Color(BLUE if not is_echo else GOLD, color.a * 0.63), 1.8, true)
	for i in range(8 if evolved else 5):
		var angle := float(i) * TAU / (8 if evolved else 5) + age * (0.0 if reduced_motion else 0.50)
		var point := at + Vector2.from_angle(angle) * radius
		draw_arc(point, 7 if evolved else 5, angle - PI * 0.65, angle + PI * 0.65, 16, color, 2, true)
		if evolved:
			_star(point + Vector2.from_angle(angle) * 11, 2.5, color)

func _draw_thorn_projectile(at: Vector2, shot: Dictionary, color: Color, evolved: bool) -> void:
	var direction: Vector2 = shot.get("direction", (shot.get("velocity", Vector2.RIGHT) as Vector2).normalized())
	var angle := direction.angle()
	draw_set_transform(at, angle)
	var spear := PackedVector2Array([Vector2(19, 0), Vector2(-2, -5), Vector2(-10, -3), Vector2(-20, -6), Vector2(-12, 0), Vector2(-20, 6), Vector2(-10, 3), Vector2(-2, 5)])
	draw_colored_polygon(spear, Color(color, color.a * 0.55))
	draw_line(Vector2(-21, 0), Vector2(19, 0), color, 2.2, true)
	for x in [-9.0, 0.0]:
		draw_polyline(PackedVector2Array([Vector2(x - 5, -7), Vector2(x, 0), Vector2(x - 5, 7)]), color, 1.7, true)
	if evolved:
		draw_line(Vector2(-25, -3), Vector2(13, -3), Color(PAPER, color.a), 1, true)
		draw_line(Vector2(-25, 3), Vector2(13, 3), Color(PAPER, color.a), 1, true)
	draw_set_transform(Vector2.ZERO)

func _draw_wisp_projectile(at: Vector2, shot: Dictionary, color: Color, evolved: bool) -> void:
	var velocity: Vector2 = shot.get("velocity", Vector2.UP)
	var direction := velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var normal := direction.orthogonal()
	var flame := PackedVector2Array([at + direction * 13, at + normal * 9 + direction * 2, at + normal * 5 - direction * 10, at - direction * 22, at - normal * 6 - direction * 9, at - normal * 10 + direction * 3])
	draw_colored_polygon(flame, Color(color, color.a * 0.64))
	draw_line(at - direction * 10, at + direction * 10, Color(PAPER, color.a), 3, true)
	_star(at, 6, Color(PAPER, color.a))
	if evolved:
		for side in [-1.0, 1.0]:
			var wing := PackedVector2Array([at + normal * side * 4 - direction * 3, at + normal * side * 14 + direction * 4, at + normal * side * 10 - direction * 11, at - direction * 15])
			draw_polyline(wing, Color(color, color.a * 0.85), 1.8, true)

func _draw_bramble_field(at: Vector2, radius: float, color: Color, is_echo: bool) -> void:
	_disc(at, radius, Color(color, color.a * 0.035))
	draw_arc(at, radius, 0, TAU, 64, Color(color, color.a * 0.55), 1.4, true)
	for i in range(9):
		var direction := Vector2.from_angle(float(i) * TAU / 9)
		var point := at + direction * radius * 0.76
		var tangent := direction.orthogonal()
		var root := at + direction * radius * 0.26
		draw_polyline(PackedVector2Array([root, point - tangent * 3, point + direction * 9]), Color(color, color.a * 0.60), 2.2, true)
		for side in [-1.0, 1.0]:
			var thorn := PackedVector2Array([point - direction * 12, point + tangent * side * 8, point + direction * 3, point - direction * 12])
			draw_colored_polygon(thorn, Color(color, color.a * 0.42))
		if is_echo:
			draw_arc(at, radius - 4, float(i) * TAU / 9, float(i) * TAU / 9 + 0.25, 6, Color(color, color.a * 0.50), 1, true)

func _draw_frost_field(at: Vector2, radius: float, age: float, color: Color, evolved: bool, is_echo: bool) -> void:
	_disc(at, radius, Color(color, color.a * 0.045))
	draw_arc(at, radius, 0, TAU, 72, Color(color, color.a * 0.45), 1.4, true)
	var crystal_count := 12 if evolved else 6
	for i in range(crystal_count):
		var angle := float(i) * TAU / crystal_count
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var crystal_at := at + direction * radius * 0.64
		var height := minf(18, radius * 0.22)
		var crystal := PackedVector2Array([crystal_at - direction * height, crystal_at - tangent * 5, crystal_at + direction * height * 0.9, crystal_at + tangent * 5, crystal_at - direction * height])
		draw_colored_polygon(crystal, Color(color, color.a * 0.17))
		draw_polyline(crystal, Color(color, color.a * 0.75), 1.5, true)
		draw_line(at + direction * radius * 0.19, crystal_at - direction * height, Color(color, color.a * 0.27), 1, true)
		if evolved:
			draw_line(at + direction * radius * 0.78, at + direction.rotated(TAU / crystal_count) * radius * 0.78, Color(color, color.a * 0.32), 1.5, true)
	if is_echo:
		for i in range(12):
			var a := float(i) * TAU / 12
			draw_arc(at, maxf(0, radius - 5), a, a + 0.20, 6, Color(color, color.a * 0.50), 1.2, true)
	var pulse := 0.65 if reduced_motion else 0.58 + sin(age * 6) * 0.10
	_star(at, 8 if evolved else 5, Color(color, color.a * pulse))

func _draw_bell_wave(at: Vector2, radius: float, width: float, color: Color, evolved: bool, is_echo: bool) -> void:
	if radius < width * 0.5:
		_disc(at, radius + width * 0.5, Color(color, color.a * 0.05))
	else:
		draw_arc(at, radius, 0, TAU, 88, Color(color, color.a * 0.07), width, true)
	for i in range(3 if evolved else 2):
		var r := maxf(0, radius - float(i) * (11 if evolved else 6))
		draw_arc(at, r, 0, TAU, 88, Color(color, color.a * (1.0 if i == 0 else 0.35)), 2.4 if i == 0 else 1.4, true)
	var count := 12 if evolved else 8
	for i in range(count):
		var direction := Vector2.from_angle(float(i) * TAU / count)
		var point := at + direction * radius
		draw_line(point - direction * 6, point + direction * 5, color, 1.8, true)
		if evolved:
			_star(point, 4, Color(PAPER if not is_echo else BLUE, color.a))
	_draw_lantern(at, 0.50, Color(color, color.a * 0.65), true)

func _draw_effect(effect: Dictionary) -> void:
	var duration := maxf(0.01, float(effect.get("duration", 0.5)))
	var progress := clampf(float(effect.get("age", 0)) / duration, 0, 1)
	var alpha := 1.0 - progress
	var kind := str(effect.kind)
	var evolved := bool(effect.get("evolved", false))
	var is_echo := bool(effect.get("echo", false))
	var at := world(effect.get("position", Vector2.ZERO))
	if kind != "lightning" and not _on_screen(at, float(effect.get("radius", 80))):
		return
	match kind:
		"lightning":
			var from := world(effect.from)
			var to := world(effect.to)
			var color := Color(BLUE if is_echo else GOLD, alpha)
			var normal := (to - from).normalized().orthogonal()
			var points := PackedVector2Array([from])
			for i in range(1, 12):
				var wave := sin(float(effect.get("seed", 0)) + float(i) * 5.73) * (3 if reduced_motion else 10)
				points.append(from.lerp(to, float(i) / 12) + normal * wave)
			points.append(to)
			draw_polyline(points, Color(color, alpha * 0.11), float(effect.get("width", 16)) + 5, true)
			draw_polyline(points, color, 3.0 + float(effect.get("width", 16)) * 0.07, true)
			draw_polyline(points, Color(PAPER, alpha * 0.90), 1, true)
			if evolved:
				for side in [-1.0, 1.0]:
					var branch := PackedVector2Array([from])
					for i in range(1, 8):
						branch.append(from.lerp(to, float(i) / 8) + normal * sin(float(i) * PI / 8) * side * 11)
					branch.append(to)
					draw_polyline(branch, Color(BLUE if not is_echo else GOLD, alpha * 0.75), 1.4, true)
			_star(from, 8 * alpha, color)
		"wisp":
			var radius := float(effect.get("radius", 50))
			var color := Color(BLUE if is_echo else WISP, alpha)
			draw_arc(at, radius, 0, TAU, 48, Color(color, alpha * 0.35), 1.6, true)
			for i in range(9 if evolved else 6):
				var direction := Vector2.from_angle(float(i) * TAU / (9 if evolved else 6))
				var drift := 0.62 if reduced_motion else lerpf(0.35, 0.85, progress)
				_star(at + direction * radius * drift, 7 * alpha, color)
			_star(at, 9 * alpha, Color(PAPER, alpha))
		"boss_phase":
			_draw_elite_crown(at + Vector2(0, -148), alpha)
			for side in [-1.0, 1.0]:
				draw_line(at + Vector2(side * 27, -146), at + Vector2(side * 52, -146), Color(DANGER, alpha), 2, true)
		"number":
			if number_labels >= MAX_NUMBERS:
				return
			number_labels += 1
			at -= Vector2(7, 25 + (0 if reduced_motion else progress * 22))
			var color := Color(BLUE if is_echo else PAPER, alpha)
			draw_string_outline(font, at, str(effect.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(INK, alpha))
			draw_string(font, at, str(effect.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		"vanish":
			# The retained death sprite and pixel debris carry this feedback.
			return
		"resonance":
			if resonance_labels < 3:
				resonance_labels += 1
				var label_at := at + Vector2(-36, -44 if reduced_motion else -38 - progress * 10)
				var label := "挟撃 +%d" % roundi(float(effect.get("damage", 0)))
				draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(INK, alpha))
				draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(GOLD, alpha))
		"hurt":
			draw_arc(at, 38 if reduced_motion else 24 + progress * 28, 0, TAU, 40, Color(DANGER, alpha * 0.80), 3, true)
		"blast":
			var radius := float(effect.get("radius", 420)) * (0.65 if reduced_motion else lerpf(0.10, 1.0, progress))
			draw_arc(at, radius, 0, TAU, 100, Color(GOLD, alpha * 0.65), 4, true)
			for i in range(12):
				var direction := Vector2.from_angle(float(i) * TAU / 12)
				draw_line(at + direction * radius * 0.80, at + direction * radius, Color(PAPER, alpha * 0.62), 2, true)
		"shield":
			var radius := float(effect.get("radius", 38))
			draw_arc(at, radius, 0, TAU, 56, Color(THORN, alpha * 0.75), 2, true)
			for i in range(6):
				_star(at + Vector2.from_angle(float(i) * TAU / 6) * radius, 3, Color(PAPER, alpha))

func _draw_lantern(at: Vector2, scale_factor: float, color: Color, bell_shape: bool = false) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	var silhouette := PackedVector2Array([Vector2(-10, 9), Vector2(-7, -7), Vector2(-4, -12), Vector2(4, -12), Vector2(7, -7), Vector2(10, 9), Vector2(-10, 9)]) if bell_shape else PackedVector2Array([Vector2(-8, -9), Vector2(8, -9), Vector2(10, 9), Vector2(-10, 9), Vector2(-8, -9)])
	draw_colored_polygon(silhouette, Color(INK, color.a))
	draw_polyline(silhouette, color, 2, true)
	draw_line(Vector2(-11, 12), Vector2(11, 12), color, 2, true)
	if bell_shape:
		_disc(Vector2(0, 15), 3, color)
	else:
		draw_arc(Vector2(0, -12), 5, PI, TAU, 16, color, 2, true)
	draw_set_transform(Vector2.ZERO)
	if not bell_shape:
		_star(at, 5 * scale_factor, color)

func _draw_vignette() -> void:
	draw_rect(Rect2(0, 0, screen.x, 100), Color(INK, 0.09))
	draw_rect(Rect2(0, screen.y - 105, screen.x, 105), Color(INK, 0.10))

func _capsule(from: Vector2, to: Vector2, width: float, fill: Color, border: Color, stroke: float) -> void:
	var radius := width * 0.5
	draw_line(from, to, fill, width, true)
	_disc(from, radius, fill)
	_disc(to, radius, fill)
	var angle := (to - from).angle()
	var points := PackedVector2Array()
	for i in range(17):
		points.append(to + Vector2.from_angle(angle - PI * 0.5 + float(i) * PI / 16) * radius)
	for i in range(17):
		points.append(from + Vector2.from_angle(angle + PI * 0.5 + float(i) * PI / 16) * radius)
	points.append(points[0])
	draw_polyline(points, border, stroke, true)

static func _star_points(radius: float) -> PackedVector2Array:
	# Fading effects can retain a positive, subpixel radius on their final tick.
	# Keep triangulation near the origin: screen coordinates lose the tiny area.
	if radius < MIN_STAR_RADIUS:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for i in range(8):
		points.append(Vector2.from_angle(-PI * 0.5 + float(i) * TAU / 8) * (radius if i % 2 == 0 else radius * 0.25))
	return points

func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := _star_points(radius)
	if points.is_empty():
		return
	draw_set_transform(at)
	draw_colored_polygon(points, color)
	draw_set_transform(Vector2.ZERO)

func _disc(at: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var padded_radius := radius * DISC_PADDING
	draw_texture_rect(WHITE_DISC, Rect2(at - Vector2.ONE * padded_radius, Vector2.ONE * padded_radius * 2), false, color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var padded_radius := radius * DISC_PADDING
	draw_texture_rect(WHITE_DISC, Rect2(center - padded_radius, padded_radius * 2), false, color)

func _elliptic_arc(center: Vector2, radius: Vector2, from: float, to: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var angle := lerpf(from, to, float(i) / 32)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)

func _dotted_line(from: Vector2, to: Vector2, color: Color, segments: int, width: float) -> void:
	for i in range(segments):
		var start := float(i) / segments
		var end := minf(1, start + 0.5 / segments)
		draw_line(from.lerp(to, start), from.lerp(to, end), color, width, true)

func _on_screen(at: Vector2, margin: float) -> bool:
	return Rect2(Vector2.ONE * -margin, screen + Vector2.ONE * margin * 2).has_point(at)
