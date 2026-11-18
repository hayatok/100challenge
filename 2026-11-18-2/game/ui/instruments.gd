extends Control

const INK := Color("#e8e2cf")
const MUTED := Color("#a7b2ad")
const GOLD := Color("#e5ad56")
const MINT := Color("#83c0af")
const RED := Color("#ed785e")
const METAL := Color(0.039, 0.069, 0.066, 0.90)
const EDGE := Color("#556359")
const WEAPONS := ["機関銃", "二連散弾銃", "信号砲"]

var state: Dictionary = {}
var font: Font
var touch := false
var finger_move := Vector2.ZERO
var aiming_fire := false
var feedback := ""
var feedback_left := 0.0
var damage_direction := Vector2.ZERO
var show_flash := true
var pixel_ratio := 1.0

func refresh_pixel_ratio() -> void:
	if OS.has_feature("web"):
		pixel_ratio = maxf(0.1, float(JavaScriptBridge.eval(
			"window.devicePixelRatio / (window.visualViewport?.scale || 1)")))

func css_scale() -> float:
	return get_viewport().get_stretch_transform().get_scale().x / pixel_ratio

func scale_factor() -> float:
	var s := clampf(size.y / 540.0, 0.67, 1.25)
	if touch:
		s = maxf(s, 0.84 / maxf(0.1, css_scale()))
	return s

func stick_center() -> Vector2:
	var s := scale_factor()
	return Vector2(106 * s, size.y - 129 * s)

func fire_center() -> Vector2:
	var s := scale_factor()
	return Vector2(size.x - 94 * s, size.y - 130 * s)

func switch_rect() -> Rect2:
	var s := scale_factor()
	return Rect2(size.x - 200 * s, size.y - 116 * s, 74 * s, 54 * s)

func pause_rect() -> Rect2:
	var s := scale_factor()
	return Rect2(size.x - 87 * s, 15 * s, 71 * s, 55 * s)

func _draw() -> void:
	if font == null:
		return
	var s := scale_factor()
	var pad := 16 * s
	var health := clampi(int(state.get("hp", 100)), 0, 100)
	var current := clampi(int(state.get("weapon", 0)), 0, WEAPONS.size() - 1)
	var accent := RED if health <= 25 else MINT
	var w := minf(size.x - (112 if touch else 32) * s, 555 * s)
	var objective := str(state.get("objective", ""))
	var chapter := "第%02d章" % int(state.get("chapter", 1))
	var checkpoint := str(state.get("checkpoint", ""))
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(1.0, w - 30 * s)
	paragraph.break_flags = (TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		| TextServer.BREAK_ADAPTIVE)
	var objective_size := roundi(19 * s)
	paragraph.add_string(wrap_objective(objective, paragraph.width, objective_size), font, objective_size)
	var paragraph_height := paragraph.get_size().y
	plate(Rect2(pad, pad, w, maxf(65 * s, paragraph_height + 35 * s)), GOLD)
	line_text(chapter, Vector2(31, 37) * s, 13 * s, GOLD)
	line_text(checkpoint, Vector2(103, 37) * s, 13 * s, MUTED, w - 112 * s)
	paragraph.draw(get_canvas_item(), Vector2(31, 43) * s, INK)

	var hp_rect := Rect2(pad, size.y - 68 * s, 178 * s, 52 * s)
	plate(hp_rect, accent)
	line_text("体力", hp_rect.position + Vector2(13, 24) * s, 14 * s, MUTED)
	line_text("%03d" % health, hp_rect.position + Vector2(91, 27) * s, 23 * s, accent)
	for segment in 10:
		var active := segment * 10 < health
		var bar := Rect2(hp_rect.position + Vector2(13 + 15 * segment, 37) * s, Vector2(12, 5) * s)
		draw_rect(bar, accent if active else EDGE)

	var ammo_rect := Rect2(size.x - 204 * s, size.y - 68 * s, 188 * s, 52 * s)
	var ammo := int(state.get("ammo", 0))
	plate(ammo_rect, GOLD if ammo > 0 else RED)
	line_text(WEAPONS[current], ammo_rect.position + Vector2(13, 22) * s, 15 * s, INK)
	line_text("残弾", ammo_rect.position + Vector2(13, 41) * s, 12 * s, MUTED)
	line_text("%03d" % ammo, ammo_rect.position + Vector2(103, 36) * s, 28 * s, GOLD if ammo > 0 else RED)

	var center := size / 2.0
	var aim_color := Color("#fff4cf")
	var feedback_color := RED if feedback == "hurt" else GOLD
	if feedback_left > 0.0:
		aim_color = feedback_color
		if show_flash and feedback == "hurt":
			draw_rect(Rect2(Vector2.ONE * s, size - Vector2.ONE * 2.0 * s),
				Color(RED, minf(feedback_left * 2.0, 0.46)), false, 10 * s)
		if feedback == "hurt" and damage_direction != Vector2.ZERO:
			draw_damage_arrow(center, s)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 5 * s, center + direction * 13 * s, Color("#101411"), 3.5 * s, true)
		draw_line(center + direction * 5 * s, center + direction * 12 * s, aim_color, 1.4 * s, true)
	draw_circle(center, 1.2 * s, aim_color)

	if touch:
		draw_touch(s)
	else:
		draw_weapon_slots(s)

func wrap_objective(value: String, width: float, font_size: int) -> String:
	var sentence_end := value.find("。") + 1
	if sentence_end <= 0 or sentence_end >= value.length():
		return value
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return value
	var first_sentence := value.left(sentence_end)
	if font.get_string_size(first_sentence, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return first_sentence + "\n" + value.substr(sentence_end).strip_edges()
	return value

func draw_damage_arrow(center: Vector2, s: float) -> void:
	var direction := damage_direction.normalized()
	var tip := center + direction * size * Vector2(0.40, 0.23)
	var wing := direction.orthogonal() * 10 * s
	var base := tip - direction * 14 * s
	var arrow := PackedVector2Array([base + wing, tip, base - wing])
	draw_polyline(arrow, Color("#29140f"), 7 * s, true)
	draw_polyline(arrow, RED, 3.5 * s, true)

func draw_weapon_slots(s: float) -> void:
	var left := size.x - 204 * s
	var y := size.y - 96 * s
	var owned: Array = state.get("owned", [true, false, false])
	for slot in 3:
		var available := slot < owned.size() and bool(owned[slot])
		var selected := int(state.get("weapon", 0)) == slot
		var rect := Rect2(left + slot * 63 * s, y, 60 * s, 24 * s)
		draw_rect(rect, METAL)
		draw_rect(rect, GOLD if selected else EDGE, false, s)
		line_text(str(slot + 1), rect.position + Vector2(7, 17) * s, 14 * s, INK if available else MUTED)
		if not available:
			draw_line(rect.position + Vector2(27, 12) * s, rect.position + Vector2(45, 12) * s, EDGE, s)
			continue
		draw_line(rect.position + Vector2(27, 11) * s, rect.position + Vector2(45, 11) * s, GOLD if selected else MINT, 3 * s)

func draw_touch(s: float) -> void:
	var stick := stick_center()
	var fire := fire_center()
	draw_circle(stick, 55 * s, Color(0.04, 0.07, 0.07, 0.72), true, -1.0, true)
	draw_arc(stick, 55 * s, 0, TAU, 48, Color(MINT, 0.72), 1.4 * s, true)
	draw_circle(stick + finger_move * 34 * s, 21 * s, Color(MINT, 0.32), true, -1.0, true)
	draw_arc(stick + finger_move * 34 * s, 21 * s, 0, TAU, 32, MINT, s, true)
	draw_circle(fire, 39 * s, Color(GOLD, 0.68) if aiming_fire else METAL, true, -1.0, true)
	draw_arc(fire, 39 * s, 0, TAU, 40, GOLD, 2 * s, true)
	line_text("射撃", fire + Vector2(-16, 6) * s, 16 * s, METAL if aiming_fire else INK)

	var weapon_button := switch_rect()
	var availability: Array = state.get("owned", [true, false, false])
	if availability.count(true) > 1:
		var marker := Rect2(weapon_button.position + Vector2(0, 4 * s), Vector2(64, 38) * s)
		plate(marker, MINT)
		line_text("切替", marker.position + Vector2(15, 25) * s, 16 * s, INK)
	var pause := pause_rect()
	plate(pause, MINT)
	line_text("停止", pause.position + Vector2(17, 34) * s, 18 * s, INK)

func plate(rect: Rect2, accent: Color) -> void:
	var s := scale_factor()
	draw_rect(Rect2(rect.position + Vector2(2, 3) * s, rect.size), Color(0, 0, 0, 0.45))
	draw_rect(rect, METAL)
	draw_rect(rect, EDGE, false, s)
	draw_rect(Rect2(rect.position, Vector2(3 * s, rect.size.y)), accent)
	for side in [rect.position.x + rect.size.x - 6 * s, rect.position.x + 7 * s]:
		draw_circle(Vector2(side, rect.position.y + 6 * s), 1.15 * s, EDGE)

func line_text(value: String, pos: Vector2, font_size: float, color: Color, width := -1.0) -> void:
	if value.is_empty():
		return
	var resolved_size := roundi(font_size)
	if width > 0 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, resolved_size).x > width:
		var suffix := "…"
		while not value.is_empty() and font.get_string_size(value + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, resolved_size).x > width:
			value = value.left(-1)
		value += suffix
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, resolved_size, color)
