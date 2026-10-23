extends RefCounted
## Finite, combat-clock feedback. Every particle is a quad from one retained atlas.

const ATLAS := preload("res://assets/art/pixel-fx.svg")
const Grimoire := preload("res://scripts/grimoire_theme.gd")
const GOLD := Grimoire.GOLD
const BLUE := Grimoire.ECHO
const PAPER := Grimoire.TEXT
const DANGER := Grimoire.DANGER
const INK := Grimoire.NIGHT
const MAX_PARTICLES := 96
const CAMERA_LIMIT := 3.5
const CAMERA_DURATION := 0.24
const GLYPH := {"spark":0,"shard":1,"dust":2,"comet":3,"rune":4,"ring":5,"burst":6,"glint":7,"slash":8,"mote":9}

var texture: CanvasTexture
var heading: Font
var particles_drawn := 0
var _last_camera_event := -100.0
var _camera_started := -100.0
var _camera_power := 0.0
var _camera_seed := 0.0
var _last_clock := -1.0
var _chapter := -1

func _init() -> void:
	texture = CanvasTexture.new()
	texture.diffuse_texture = ATLAS
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heading = load("res://assets/fonts/ZenOldMincho-Bold.ttf")

func reset() -> void:
	_last_camera_event = -100.0
	_camera_started = -100.0
	_camera_power = 0.0
	_camera_seed = 0.0
	_last_clock = -1.0

func camera_offset(presentation, run, reduced: bool) -> Vector2:
	var clock := float(run.elapsed)
	if clock < _last_clock or str(run.state) == "title" or int(run.chapter) != _chapter:
		reset()
	_last_clock = clock
	_chapter = int(run.chapter)
	if reduced:
		# Do not reveal an old impulse when the setting is switched off again.
		_camera_started = -100.0
		return Vector2.ZERO
	for event in presentation.events:
		var kind := str(event.get("kind", ""))
		var power := 0.0
		if kind == "hit" and str(event.get("target", "enemy")) == "player":
			power = 3.0
		elif kind in ["boss_arrival", "boss_phase"]:
			power = 3.5
		elif kind == "resonance":
			power = 1.6
		var birth := clock - float(event.get("age", 0.0))
		if power > 0.0 and birth > _last_camera_event + 0.36 and float(event.get("age", 0.0)) < 0.12:
			_last_camera_event = birth
			_camera_started = birth
			_camera_power = power
			_camera_seed = float(event.get("seed", 0))
	var age := clock - _camera_started
	if age < 0.0 or age >= CAMERA_DURATION:
		return Vector2.ZERO
	var envelope := pow(1.0 - age / CAMERA_DURATION, 2.0)
	return Vector2(sin(age * 69.0 + _camera_seed), cos(age * 51.0 + _camera_seed)).limit_length(1.0) * minf(CAMERA_LIMIT, _camera_power) * envelope

func _color(event: Dictionary) -> Color:
	if bool(event.get("echo", false)):
		return BLUE
	match str(event.get("weapon", "")):
		"thorn": return Color("a6bd8b")
		"wisp": return Color("c6a8e0")
		"frost": return Color("b8dce1")
	return GOLD

func _stamp(canvas: CanvasItem, at: Vector2, glyph: String, extent: Vector2, color: Color, angle: float = 0.0) -> void:
	if particles_drawn >= MAX_PARTICLES or color.a <= 0.005 or minf(extent.x, extent.y) < 0.75:
		return
	particles_drawn += 1
	var region := Rect2(float(GLYPH[glyph]) * 64.0, 0, 64, 64)
	if absf(angle) > 0.001:
		canvas.draw_set_transform(at, angle)
		canvas.draw_texture_rect_region(texture, Rect2(-extent * 0.5, extent), region, color)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(texture, Rect2(at - extent * 0.5, extent), region, color)

func _burst(canvas: CanvasItem, at: Vector2, event: Dictionary, color: Color, count: int, distance: float, reduced: bool) -> void:
	var duration := maxf(0.01, float(event.get("duration", 0.4)))
	var p := clampf(float(event.get("age", 0.0)) / duration, 0.0, 1.0)
	var seed := fposmod(float(event.get("seed", 0)), TAU)
	var alpha := pow(1.0 - p, 1.3)
	for i in range(count if not reduced else 3):
		var angle := seed + float(i) * TAU / float(count)
		var direction := Vector2.from_angle(angle)
		var travel := 6.0 if reduced else (1.0 - pow(1.0 - p, 3.0)) * distance
		var drop := 0.0 if reduced else p * p * distance * 0.24
		var point := at + direction * travel + Vector2(0, drop)
		var length := lerpf(13.0, 5.0, p) * (0.8 + float(i % 3) * 0.18)
		_stamp(canvas, point, "shard" if i % 3 else "spark", Vector2(length, length), Color(color, alpha * 0.86), 0.0 if reduced else angle + p * 0.8)

func draw_world(canvas, presentation, run, reduced: bool) -> void:
	particles_drawn = 0
	# Important events reserve their quads before ordinary impacts or footsteps.
	var important: Array = []
	var ordinary: Array = []
	for event in presentation.events:
		if str(event.get("kind", "")) in ["resonance", "boss_arrival", "boss_phase", "evolution", "blast"]:
			important.append(event)
		else:
			ordinary.append(event)
	for event in important + ordinary:
		var at: Vector2 = canvas.world(event.get("position", run.player))
		if not canvas._on_screen(at, 200.0):
			continue
		var age := float(event.get("age", 0.0))
		var duration := maxf(0.01, float(event.get("duration", 0.4)))
		var p := clampf(age / duration, 0.0, 1.0)
		var alpha := 1.0 - p
		var color := _color(event)
		match str(event.kind):
			"cast":
				var stretch := 0.8 if reduced else lerpf(0.45, 1.08, 1.0 - pow(1.0-p, 3.0))
				_stamp(canvas, at + Vector2(0, 5), "rune", Vector2(64, 27) * stretch, Color(color, alpha * 0.58))
				_stamp(canvas, at + Vector2(float(event.get("facing", 1.0)) * 20, -29), "glint", Vector2.ONE * lerpf(25, 8, p), Color(PAPER, alpha * 0.86))
			"hit":
				var player_hit := str(event.get("target", "enemy")) == "player"
				color = DANGER if player_hit else color
				_stamp(canvas, at - Vector2(0, 18), "burst", Vector2.ONE * (42.0 if player_hit else 29.0) * (0.8 + p * 0.5), Color(PAPER, alpha * 0.82))
				_burst(canvas, at - Vector2(0, 18), event, color, 7 if player_hit else 4, 43.0 if player_hit else 27.0, reduced)
			"kill":
				var boss := bool(event.get("boss", false))
				_burst(canvas, at - Vector2(0, 20), event, color, 14 if boss else 6, 115.0 if boss else 37.0, reduced)
				_stamp(canvas, at, "ring", Vector2(70, 28) * (0.75 + p * 0.7), Color(color, alpha * 0.35))
			"resonance":
				var radius := 66.0 if reduced else lerpf(45.0, 120.0, p)
				_stamp(canvas, at + Vector2(-8, -17), "ring", Vector2.ONE * radius, Color(GOLD, alpha * 0.72))
				_stamp(canvas, at + Vector2(8, -17), "ring", Vector2.ONE * radius, Color(BLUE, alpha * 0.64))
				_stamp(canvas, at - Vector2(0, 17), "glint", Vector2(54, 17), Color(PAPER, alpha * 0.86))
				_burst(canvas, at - Vector2(0, 17), event, color, 8, 56.0, reduced)
			"footstep":
				if not reduced:
					_stamp(canvas, at + Vector2(0, 5 + p * 3), "dust", Vector2(27, 17) * (0.7 + p * 0.4), Color(color, alpha * 0.17))
			"collect":
				_stamp(canvas, at - Vector2(0, 12 if reduced else 9 + p * 15), "spark", Vector2.ONE * lerpf(12, 3, p), Color(color, alpha * 0.75))
			"boss_arrival", "boss_phase":
				var phase := str(event.kind) == "boss_phase"
				var extent := Vector2(190, 70) * (1.0 if reduced else 0.65 + p * 0.55)
				_stamp(canvas, at, "rune", extent, Color(DANGER if phase else GOLD, alpha * 0.55))
				if phase:
					_burst(canvas, at - Vector2(0, 45), event, DANGER, 12, 91, reduced)
			"evolution", "blast":
				_stamp(canvas, at, "rune", Vector2(180, 66) * (1.0 if reduced else 0.6 + p * 1.6), Color(color, alpha * 0.65))
				_burst(canvas, at - Vector2(0, 28), event, PAPER, 12, 105, reduced)
			"shield":
				_stamp(canvas, at - Vector2(0, 20), "rune", Vector2.ONE * 76, Color(BLUE, alpha * 0.6))

func draw_screen(canvas, presentation, run, reduced: bool) -> void:
	var damage_alpha := 0.0
	for event in presentation.events:
		var kind := str(event.get("kind", ""))
		var age := float(event.get("age", 0.0))
		if kind == "hit" and str(event.get("target", "enemy")) == "player":
			damage_alpha = maxf(damage_alpha, maxf(0, 1.0 - age / 0.36) * (0.08 if reduced else 0.16))
	if damage_alpha > 0.0:
		# Peripheral pressure rather than a whole-screen flash; the HUD is a sibling.
		for i in range(5):
			var width := float(5 - i) * 7.0
			var alpha := damage_alpha * float(i + 1) / 5.0
			canvas.draw_rect(Rect2(0, Grimoire.SAFE_TOP, width, canvas.screen.y - Grimoire.SAFE_TOP - Grimoire.SAFE_BOTTOM), Color(DANGER, alpha))
			canvas.draw_rect(Rect2(canvas.screen.x - width, Grimoire.SAFE_TOP, width, canvas.screen.y - Grimoire.SAFE_TOP - Grimoire.SAFE_BOTTOM), Color(DANGER, alpha))
	if str(run.state) != "playing":
		return
	var selected: Dictionary = {}
	var selected_priority := -1
	var priorities := {"chapter": 0, "boss_arrival": 1, "boss_phase": 2, "evolution": 3}
	for event in presentation.events:
		var kind := str(event.get("kind", ""))
		if not priorities.has(kind) or bool(event.get("clear", false)):
			continue
		var priority: int = priorities[kind]
		if priority > selected_priority or (priority == selected_priority and float(event.get("age", 0)) < float(selected.get("age", INF))):
			selected = event
			selected_priority = priority
	if selected.is_empty():
		return
	var kind := str(selected.kind)
	var age := float(selected.get("age", 0.0))
	var duration := maxf(0.01, float(selected.get("duration", 1.2)))
	var p := clampf(age / duration, 0, 1)
	var fade := minf(1.0, p * 8.0) * minf(1.0, (1.0 - p) * 5.0)
	var title := str(selected.get("name", ""))
	var caption := ""
	if kind == "boss_phase":
		title = "第二形態"
		caption = "魔力が満ちる"
	elif kind == "evolution":
		title = "魔法進化"
		caption = "新たな頁がひらく"
	elif kind == "chapter":
		title = str(run.chapter_info().get("name", ""))
		caption = "第%d章" % (int(run.chapter) + 1)
	else:
		caption = "章の主"
	if title.is_empty():
		return
	# The single manuscript heading fits between the boss meter and the battlefield.
	# Reveal only the ink; neither layout nor hostile telegraphs move with this effect.
	var width := minf(620.0, canvas.screen.x - 160.0)
	var center := Vector2(canvas.screen.x * 0.5, 166.0)
	var left := center.x - width * 0.5
	var right := center.x + width * 0.5
	var surface := PackedVector2Array([Vector2(left + 20, 126), Vector2(right - 20, 126), Vector2(right, 166), Vector2(right - 20, 206), Vector2(left + 20, 206), Vector2(left, 166)])
	canvas.draw_colored_polygon(surface, Color(INK, fade * 0.88))
	var accent := DANGER if kind.begins_with("boss") else BLUE if kind == "evolution" else GOLD
	var ink_width := width * (1.0 if reduced else minf(1.0, p * 7.0)) * 0.42
	for y in [128.0, 204.0]:
		canvas.draw_line(Vector2(center.x - ink_width, y), Vector2(center.x + ink_width, y), Color(GOLD, fade * 0.65), 1.0, true)
	for side in [-1.0, 1.0]:
		var seal := center + Vector2(side * (width * 0.5 - 35), 0)
		canvas.draw_arc(seal + Vector2(-3, 0), 9, 0, TAU, 24, Color(GOLD, fade * 0.7), 1, true)
		canvas.draw_arc(seal + Vector2(3, 0), 9, 0, TAU, 24, Color(accent, fade * 0.7), 1, true)
	var text_size := Grimoire.HEADING_SIZE
	var text_width := heading.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	canvas.draw_string(heading, center + Vector2(-text_width * 0.5, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(PAPER, fade))
	var caption_size := Grimoire.SMALL_SIZE
	var caption_width: float = canvas.font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	canvas.draw_string(canvas.font, center + Vector2(-caption_width * 0.5, 27), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(accent, fade))

func diagnostics() -> Dictionary:
	return {"particle_limit": MAX_PARTICLES, "particles_drawn": particles_drawn, "atlas_texture_id": texture.get_rid().get_id(), "atlas_frames": GLYPH.size()}
