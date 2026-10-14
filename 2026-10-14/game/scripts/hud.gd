extends CanvasLayer

signal start_requested
signal restart_requested
signal resume_requested
signal title_requested
signal pause_requested
signal settings_changed(effect_level: String, music_volume: float, sfx_volume: float)

const FONT = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
const INK = Color("20201e")
const PAPER = Color("fffdf8")
const RED = Color("b73529")
const GOLD = Color("ffe15c")
const GREEN = Color("245b3d")


# Procedural accents use a single CanvasItem. The center and corner HUDs stay clear.
class ComicAccents extends Control:
	var intensity := 0.0
	var rush := false
	var burst_alpha := 0.0
	var burst_scale := 1.0
	var phase := 0.0
	var quality := "派手"
	var jagged := PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for index in 40:
			var angle := TAU * float(index) / 40.0
			var radius := 1.0 if index % 2 == 0 else (0.78 + float(index % 3) * 0.025)
			jagged.append(Vector2(cos(angle) * 465.0, sin(angle) * 90.0) * radius)

	func _draw() -> void:
		if quality == "控えめ":
			return
		if intensity > 0.01:
			var count := 12 if quality == "派手" else 6
			for side in 2:
				for index in count:
					var y := 290.0 + float(index) * 510.0 / float(count)
					var pulse := 0.76 + sin(phase * 12.0 + float(index) * 2.1) * 0.24
					var length := (68.0 + float(index % 4) * 17.0) * intensity * pulse
					var start_x := 0.0 if side == 0 else 1920.0
					var end_x := length if side == 0 else 1920.0 - length
					var slant := 25.0 if y < 540.0 else -25.0
					var points := PackedVector2Array([Vector2(start_x, y - 5.0), Vector2(end_x, y + slant), Vector2(start_x, y + 5.0)])
					var color := Color(1.0, 0.83, 0.13, 0.75 * intensity)
					if rush and index % 3 == 0:
						color = Color(1.0, 0.16, 0.37, 0.75 * intensity)
					draw_colored_polygon(points, color)
					draw_line(Vector2(start_x, y - 5.0), Vector2(end_x, y + slant), Color(0.13, 0.1, 0.09, 0.35 * intensity), 2.0, true)
		if burst_alpha > 0.0:
			var shape := PackedVector2Array()
			var shadow := PackedVector2Array()
			for point in jagged:
				shape.append(Vector2(960, 205) + point * burst_scale)
				shadow.append(Vector2(968, 213) + point * burst_scale)
			draw_colored_polygon(shadow, Color(0.91, 0.11, 0.35, burst_alpha))
			draw_colored_polygon(shape, Color(1.0, 0.83, 0.15, burst_alpha))
			shape.append(shape[0])
			draw_polyline(shape, Color(0.15, 0.10, 0.08, burst_alpha), 4.0, true)

var _accents: ComicAccents
var _visual_speed := 0.0
var _visual_boosting := false
var _visual_rush := false
var _visual_impact := 0.0
var _root: Control
var _play: Control
var _menu: Control
var _title: Control
var _pause: Control
var _result: Control
var _settings: Control
var _shade: ColorRect
var _time: Label
var _damage: Label
var _combo: Label
var _pressure_text: Label
var _pressure: ProgressBar
var _distance: Label
var _notice: Label
var _bonus: Label
var _result_time: Label
var _result_rank: Label
var _result_sub: Label
var _best: Label
var _result_damage: Label
var _result_combo: Label
var _save_error: Label
var _music_value: Label
var _sfx_value: Label
var _mode := ""
var _burst_left := 0.0
var _burst_duration := 0.95
var _quality := "派手"
var _music := 0.45
var _sfx := 0.75

func build() -> void:
	if is_instance_valid(_root):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.name = "JapaneseHUD"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(1920, 1080)
	add_child(_root)
	_play = _group(_root)
	_accents = ComicAccents.new()
	_accents.size = Vector2(1920, 1080)
	_play.add_child(_accents)
	_build_play()
	_shade = ColorRect.new()
	_shade.color = Color(0.06, 0.08, 0.08, 0.20)
	_shade.size = Vector2(1920, 1080)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_menu = _group(_root)
	_title = _group(_menu)
	_pause = _group(_menu)
	_result = _group(_menu)
	_build_title()
	_build_pause()
	_build_result()
	_build_settings()
	_notice = _label(_root, "", Rect2(455, 144, 1010, 112), 72, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 13)
	_notice.rotation = -0.035
	_notice.pivot_offset = Vector2(505, 56)
	_bonus = _label(_root, "", Rect2(640, 250, 640, 70), 42, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 8)
	_notice.hide()
	_bonus.hide()
	_fit()
	present("title", {})

func _group(parent: Node) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = Vector2(1920, 1080)
	parent.add_child(node)
	return node

func _style(fill: Color, border: Color = INK, width: int = 3, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style

func _panel(parent: Node, rect: Rect2, fill: Color = PAPER, border: Color = INK, width: int = 4) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, width, 14))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, rect: Rect2, font_size: int = 32, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = Vector2(rect.size.x, maxf(rect.size.y, 66.0))
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 34 if primary else 28)
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	button.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	button.add_theme_stylebox_override("normal", _style(RED if primary else PAPER))
	button.add_theme_stylebox_override("hover", _style(Color("d14a38") if primary else Color("fff2d3")))
	button.add_theme_stylebox_override("pressed", _style(Color("99291f") if primary else Color("e7ddcc")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD, 4))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_play() -> void:
	_panel(_play, Rect2(40, 32, 398, 132), Color("20252c"), PAPER, 3)
	_label(_play, "退勤タイム", Rect2(62, 38, 335, 44), 28, PAPER)
	_time = _label(_play, "00:00.00", Rect2(60, 76, 360, 74), 62, PAPER)
	_panel(_play, Rect2(1436, 32, 444, 132))
	_label(_play, "被害総額", Rect2(1460, 40, 380, 42), 28)
	_damage = _label(_play, "¥0", Rect2(1458, 80, 392, 68), 48, RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_combo = _label(_play, "", Rect2(1430, 168, 450, 80), 50, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 10)
	_panel(_play, Rect2(40, 908, 434, 132))
	_label(_play, "消火器", Rect2(62, 910, 100, 47), 28, RED)
	_pressure_text = _label(_play, "残圧 100%", Rect2(164, 910, 285, 47), 32)
	_pressure = ProgressBar.new()
	_pressure.position = Vector2(62, 972)
	_pressure.size = Vector2(388, 30)
	_pressure.max_value = 100
	_pressure.show_percentage = false
	_pressure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pressure.add_theme_stylebox_override("background", _style(Color("dbd5ca"), INK, 2))
	_pressure.add_theme_stylebox_override("fill", _style(Color("ffbd3d"), INK, 1))
	_play.add_child(_pressure)
	_label(_play, "離すと回復", Rect2(62, 1001, 370, 31), 22, Color("5b5a54"))
	_panel(_play, Rect2(1192, 944, 688, 96), Color("20252c"), PAPER, 2)
	_label(_play, "← → / A D  旋回    SPACE  噴射", Rect2(1216, 946, 640, 47), 28, PAPER)
	_label(_play, "R  もう一度     ESC  ポーズ", Rect2(1216, 993, 640, 35), 23, Color("e2ddd4"))
	_distance = _label(_play, "EXIT  ↑  106m", Rect2(790, 36, 340, 58), 30, Color("9affb9"), HORIZONTAL_ALIGNMENT_CENTER, 6)
	_button(_play, "Ⅱ ポーズ", Rect2(1720, 840, 160, 68), func(): pause_requested.emit())

func _build_title() -> void:
	_panel(_title, Rect2(72, 142, 706, 798))
	_label(_title, "物理コメディ・タイムアタック", Rect2(112, 184, 610, 48), 28, GREEN)
	_label(_title, "全力退勤", Rect2(106, 236, 630, 152), 108, RED, HORIZONTAL_ALIGNMENT_LEFT, 3)
	_label(_title, "定時だ。飛べ。", Rect2(116, 390, 580, 72), 48)
	_label(_title, "消火器の反動で、オフィスを駆け抜けろ。", Rect2(116, 485, 610, 60), 28)
	_button(_title, "退勤する  →", Rect2(116, 578, 618, 98), func(): start_requested.emit(), true)
	_label(_title, "← → / A D   椅子の向きを変える\nSPACE   後ろへ噴射、前へ加速\n離すと残圧回復。Rで即やり直し。", Rect2(116, 700, 620, 148), 28)
	_button(_title, "設定", Rect2(116, 860, 196, 60), _toggle_settings)
	_label(_title, "仕事は置いて、帰ろう。", Rect2(336, 860, 390, 60), 24, Color("5b5a54"))
	_button(_title, "クレジット", Rect2(1526, 940, 322, 66), func():
		OS.shell_open("credits.html" if OS.has_feature("web") else "https://godotengine.org/license/")
	)

func _build_pause() -> void:
	_panel(_pause, Rect2(610, 226, 700, 650))
	_label(_pause, "ひと休み", Rect2(650, 268, 620, 96), 62, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_pause, "退勤タイムは停止中", Rect2(650, 370, 620, 54), 28, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_button(_pause, "再開する", Rect2(666, 456, 588, 86), func(): resume_requested.emit(), true)
	_button(_pause, "最初から", Rect2(666, 562, 284, 76), func(): restart_requested.emit())
	_button(_pause, "設定", Rect2(972, 562, 282, 76), _toggle_settings)
	_button(_pause, "タイトルへ", Rect2(666, 660, 588, 76), func(): title_requested.emit())
	_label(_pause, "ESCでも再開", Rect2(666, 770, 588, 46), 24, Color("5b5a54"), HORIZONTAL_ALIGNMENT_CENTER)

func _build_result() -> void:
	_panel(_result, Rect2(64, 126, 860, 832))
	var stamp := _panel(_result, Rect2(84, 76, 820, 160), PAPER, RED, 8)
	stamp.rotation = -0.055
	stamp.pivot_offset = Vector2(410, 80)
	_label(stamp, "退勤成功！", Rect2(22, 4, 770, 144), 102, RED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_result, "退勤タイム", Rect2(110, 256, 730, 52), 34)
	_result_time = _label(_result, "00:24.86", Rect2(104, 302, 754, 126), 100)
	_result_rank = _label(_result, "SSS", Rect2(108, 434, 294, 112), 92, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 10)
	_result_sub = _label(_result, "爆速帰宅", Rect2(420, 452, 430, 92), 48, RED)
	_best = _label(_result, "", Rect2(110, 552, 758, 56), 30, GREEN)
	_result_damage = _label(_result, "被害総額  ¥0", Rect2(110, 638, 758, 56), 32)
	_result_combo = _label(_result, "最大連鎖  0", Rect2(110, 700, 758, 52), 32)
	_button(_result, "もう一度", Rect2(110, 790, 474, 98), func(): restart_requested.emit(), true)
	_button(_result, "タイトルへ", Rect2(610, 790, 266, 98), func(): title_requested.emit())
	_save_error = _label(_result, "", Rect2(110, 900, 758, 42), 24, RED)
	_label(_result, "総務には内緒。", Rect2(1140, 930, 650, 80), 40, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 7)

func _build_settings() -> void:
	_settings = _group(_menu)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1920, 1080)
	backdrop.color = Color(0.03, 0.04, 0.05, 0.6)
	_settings.add_child(backdrop)
	_panel(_settings, Rect2(582, 208, 756, 680))
	_label(_settings, "設定", Rect2(628, 240, 660, 90), 54)
	_label(_settings, "演出の量", Rect2(628, 354, 260, 66), 30)
	var quality := OptionButton.new()
	quality.position = Vector2(938, 354)
	quality.size = Vector2(348, 66)
	quality.add_theme_font_override("font", FONT)
	quality.add_theme_font_size_override("font_size", 30)
	quality.add_theme_color_override("font_color", INK)
	quality.add_theme_color_override("font_hover_color", INK)
	quality.add_theme_color_override("font_pressed_color", INK)
	quality.add_theme_stylebox_override("normal", _style(PAPER))
	quality.add_theme_stylebox_override("hover", _style(Color("fff2d3")))
	quality.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), RED))
	for text in ["派手", "標準", "控えめ"]:
		quality.add_item(text)
	var popup := quality.get_popup()
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 30)
	quality.item_selected.connect(func(index: int):
		_quality = quality.get_item_text(index)
		_emit_settings()
	)
	_settings.add_child(quality)
	_label(_settings, "BGM 音量", Rect2(628, 460, 430, 56), 30)
	_music_value = _label(_settings, "45%", Rect2(1100, 460, 188, 56), 28, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_slider(_settings, Rect2(628, 524, 660, 54), _music, func(value: float):
		_music = value
		_music_value.text = "%d%%" % roundi(value * 100)
		_emit_settings()
	)
	_label(_settings, "効果音 音量", Rect2(628, 608, 430, 56), 30)
	_sfx_value = _label(_settings, "75%", Rect2(1100, 608, 188, 56), 28, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_slider(_settings, Rect2(628, 672, 660, 54), _sfx, func(value: float):
		_sfx = value
		_sfx_value.text = "%d%%" % roundi(value * 100)
		_emit_settings()
	)
	_button(_settings, "閉じる", Rect2(628, 782, 660, 70), _toggle_settings, true)
	_settings.hide()

func _slider(parent: Node, rect: Rect2, value: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.add_theme_stylebox_override("slider", _style(Color("d7d0c3"), INK, 2, 4))
	slider.add_theme_stylebox_override("grabber_area", _style(RED, INK, 2, 4))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(Color("d14a38"), INK, 2, 4))
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider

func _toggle_settings() -> void:
	_settings.visible = not _settings.visible

func _emit_settings() -> void:
	_accents.quality = _quality
	_accents.queue_redraw()
	settings_changed.emit(_quality, _music, _sfx)

func _fit() -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	_root.scale = Vector2.ONE * factor
	_root.position = (viewport_size - Vector2(1920, 1080) * factor) * 0.5

func present(mode: String, data: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	if mode != _mode:
		_mode = mode
		_settings.hide()
		_play.visible = mode == "playing"
		_menu.visible = mode != "playing"
		_title.visible = mode == "title"
		_pause.visible = mode == "paused"
		_result.visible = mode == "result"
		_shade.visible = mode != "playing"
		if mode != "playing":
			_notice.hide()
			_bonus.hide()
			_burst_left = 0.0
	_visual_speed = float(data.get("speed", 0.0))
	_visual_boosting = bool(data.get("boosting", false))
	_visual_rush = bool(data.get("rush", false))
	_visual_impact = float(data.get("impact", 0.0))
	_time.text = _format_time(float(data.get("elapsed", 0.0)))
	_damage.text = "¥" + _money(int(data.get("damage", 0)))
	var count := int(data.get("combo", 0))
	_combo.text = "%d連鎖 ×%d" % [count, int(data.get("multiplier", 1))] if count > 0 else ""
	var pressure := float(data.get("pressure", 100.0))
	_pressure.value = pressure
	_pressure_text.text = "離して回復！" if pressure <= 0.1 else "残圧 %d%%" % roundi(pressure)
	_pressure_text.add_theme_color_override("font_color", RED if pressure < 20.0 else INK)
	_distance.text = "EXIT  ↑  %dm" % ceili(float(data.get("distance", 0.0)))
	if mode == "result":
		_result_time.text = _format_time(float(data.get("elapsed", 0.0)))
		_result_rank.text = str(data.get("rank", "SSS"))
		_result_sub.text = str(data.get("rank_text", "爆速帰宅"))
		var best := float(data.get("best_time", 0.0))
		_best.text = "自己ベスト！  " + _format_time(best) if bool(data.get("new_best", false)) else ("自己ベスト  " + _format_time(best) if best > 0.0 else "おつかれさまでした！")
		_result_damage.text = "被害総額  ¥" + _money(int(data.get("damage", 0)))
		_result_combo.text = "最大連鎖  %d" % int(data.get("max_combo", 0))
		_save_error.text = "記録を保存できませんでした" if bool(data.get("save_error", false)) else ""

func burst(text: String, bonus: String = "", kind: String = "impact") -> void:
	if not is_instance_valid(_notice) or _mode != "playing":
		return
	_notice.text = text
	_notice.add_theme_color_override("font_color", GOLD if kind == "rush" else PAPER)
	_notice.add_theme_font_size_override("font_size", 72 if text.length() <= 9 else 58)
	_bonus.text = bonus
	_burst_duration = 1.2 if kind == "rush" else 0.85
	_burst_left = _burst_duration
	_notice.scale = Vector2.ONE
	_notice.modulate.a = 1.0
	_bonus.modulate.a = 1.0
	_notice.show()
	_bonus.visible = not bonus.is_empty()

func _process(delta: float) -> void:
	_fit()
	if not is_instance_valid(_accents):
		return
	if _mode != "playing":
		_accents.intensity = 0.0
		_accents.burst_alpha = 0.0
		_accents.queue_redraw()
		return
	if get_tree().paused:
		return
	_accents.quality = _quality
	_accents.rush = _visual_rush
	_accents.phase += delta
	var target := clampf(_visual_speed / 9.0, 0.0, 1.0) * 0.7 if _visual_boosting else 0.0
	if _visual_rush:
		target = 1.0
	_accents.intensity = move_toward(_accents.intensity, target, delta * 5.0)
	_accents.burst_alpha = 0.0
	if _burst_left > 0.0:
		_burst_left = maxf(0.0, _burst_left - delta)
		var age := _burst_duration - _burst_left
		var pop := 1.0 + sin(clampf(age / 0.18, 0.0, 1.0) * PI) * (0.12 if _quality != "控えめ" else 0.0)
		_notice.scale = Vector2.ONE * pop
		_notice.modulate.a = minf(1.0, _burst_left / 0.18)
		_bonus.modulate.a = _notice.modulate.a
		_accents.burst_alpha = _notice.modulate.a * 0.96
		_accents.burst_scale = 1.0 + (pop - 1.0) * 0.35
		if _burst_left <= 0.0:
			_notice.hide()
			_bonus.hide()
	_accents.queue_redraw()

func _format_time(value: float) -> String:
	var hundredths := floori(maxf(value, 0.0) * 100.0)
	return "%02d:%02d.%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]

func _money(value: int) -> String:
	var digits := str(value)
	var output := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			output += ","
		output += digits[index]
	return output
