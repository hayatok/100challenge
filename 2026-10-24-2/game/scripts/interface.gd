extends CanvasLayer
## Persistent, data-driven screen layer. The run and saved records belong to Main.

signal start_requested
signal resume_requested
signal retry_requested
signal title_requested
signal settings_requested
signal settings_closed
signal settings_changed(values: Dictionary)

const INK := Color("142c3e")
const WHITE := Color("fffdf8")
const MUTED := Color("c8d7dd")
const TEAL := Color("087f8c")
const CYAN := Color("58d9e3")
const CORAL := Color("f08a7b")
const AMBER := Color("f1b449")

class CutPanel extends PanelContainer:
	var fill := Color("142c3e")
	var line := Color("70a7b5")

	func _ready() -> void:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 20
		empty.content_margin_right = 20
		empty.content_margin_top = 16
		empty.content_margin_bottom = 16
		add_theme_stylebox_override("panel", empty)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([Vector2(10, 1), Vector2(w - 1, 1), Vector2(w - 1, h - 10), Vector2(w - 10, h - 1), Vector2(1, h - 1), Vector2(1, 10), Vector2(10, 1)])
		draw_colored_polygon(points, fill)
		draw_polyline(points, line, 1.5, true)
		draw_line(Vector2(5, 20), Vector2(20, 5), Color("58d9e3"), 3, true)

class WindButton extends Button:
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Draw underneath the native button text; a chevron repeats the focus cue.
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([Vector2(10, 3), Vector2(w - 3, 3), Vector2(w - 3, h - 12), Vector2(w - 12, h - 3), Vector2(3, h - 3), Vector2(3, 12), Vector2(10, 3)])
		var selected := has_focus() or is_hovered()
		draw_colored_polygon(points, Color("087f8c") if selected else Color("17384b"))
		draw_polyline(points, Color("f08a7b") if has_focus() else Color("80b6c2"), 3 if has_focus() else 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(w - 29, h / 2 - 7), Vector2(w - 22, h / 2), Vector2(w - 29, h / 2 + 7)]), Color("fffdf8"), 2, true)
		if has_focus():
			draw_colored_polygon(PackedVector2Array([Vector2(14, h / 2 - 5), Vector2(20, h / 2), Vector2(14, h / 2 + 5)]), Color("f08a7b"))
		var font := get_theme_font("font")
		var font_size := get_theme_font_size("font_size")
		var baseline := (h + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(30 if has_focus() else 20, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, w - 74, font_size, Color("fffdf8"))

var _root: Control
var _screens: Dictionary = {}
var _first_focus: Dictionary = {}
var _screen := ""
var _hud: Control
var _time: Label
var _score: Label
var _flow: Label
var _speed: Label
var _energy: Label
var _energy_bar: ProgressBar
var _progress: ProgressBar
var _section: Label
var _notice: Label
var _legend: Label
var _title_controls: Label
var _title_controls_extra: Label
var _settings_controls: Label
var _count: Label
var _count_caption: Label
var _result_time: Label
var _result_score: Label
var _result_falls: Label
var _best_time: Label
var _best_score: Label
var _save_status: Label
var _error_message: Label
var _motion: CheckButton
var _volume: HSlider
var _volume_value: Label
var _confirmation: Control
var _confirm_label: Label
var _confirm_action := ""
var _pause_first: Button
var _pause_content: Control
var _results_frame: Control
var _setting_values := {"reduced_motion": false, "master_volume": 0.75}
var _syncing_settings := false
var _using_pad := false
var _body_font: Font
var _number_font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_body_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	_number_font = load("res://assets/fonts/DejaVuSansMono.ttf")
	_root = Control.new()
	_root.name = "Screens"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var ui_theme := Theme.new()
	ui_theme.default_font = _body_font
	ui_theme.default_font_size = 20
	ui_theme.set_color("font_color", "Label", WHITE)
	_root.theme = ui_theme
	_build_hud()
	_build_title()
	_build_countdown()
	_build_pause()
	_build_results()
	_build_settings()
	_build_error()
	_root.resized.connect(_refresh_layout)
	_refresh_layout()
	set_screen("title")


func set_screen(name: String, data: Dictionary = {}) -> void:
	if not _screens.has(name):
		push_warning("Unknown UI screen: " + name)
		return
	_screen = name
	for key: String in _screens:
		(_screens[key] as Control).visible = key == name
	_hud.visible = name in ["run", "countdown", "pause"]
	_confirmation.hide()
	_pause_content.show()
	_confirm_action = ""
	if name == "countdown":
		_count.text = str(data.get("count", data.get("countdown", 3)))
		_count_caption.text = str(data.get("caption", "風を読んで、走り出そう"))
	elif name == "results":
		_show_results(data)
	elif name == "settings":
		_sync_settings(data)
	elif name == "error":
		_error_message.text = str(data.get("message", "コースを読み込めませんでした"))
	if _first_focus.has(name):
		(_first_focus[name] as Control).grab_focus.call_deferred()
	else:
		var focused := _root.get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
	if name == "run":
		_notice.text = ""
	if not data.is_empty() and name in ["run", "countdown"]:
		update_hud(data)


func update_hud(data: Dictionary) -> void:
	if data.has("time"):
		_time.text = _format_time(float(data.time))
	if data.has("score"):
		_score.text = _format_score(int(data.score))
		_score.add_theme_font_size_override("font_size", 28 if _score.text.length() > 9 else 36)
	if data.has("flow"):
		_flow.text = "FLOW  ×%.2f" % float(data.flow)
	if data.has("speed"):
		_speed.text = "%04.1f" % maxf(0.0, float(data.speed))
	if data.has("energy"):
		var energy := clampf(float(data.energy), 0, 100)
		_energy.text = "%d / 100" % roundi(energy)
		_energy_bar.value = energy
	if data.has("progress"):
		_progress.value = clampf(float(data.progress), 0, 1) * 100.0
	if data.has("section"):
		_section.text = "白環の通学路 · " + str(data.section)
	if data.has("notice"):
		_notice.text = str(data.notice)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		if not _using_pad:
			_using_pad = true
			_refresh_legend()
	elif event is InputEventKey or event is InputEventMouseButton:
		if _using_pad:
			_using_pad = false
			_refresh_legend()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _confirmation.visible:
		_close_confirmation()
	elif _screen == "settings":
		settings_closed.emit()
	elif _screen == "pause":
		resume_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _new_screen(name: String) -> Control:
	var screen := Control.new()
	screen.name = name.to_pascal_case()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(screen)
	_screens[name] = screen
	return screen


func _rect(node: Control, parent: Node, anchors: Vector4, offsets: Vector4) -> void:
	parent.add_child(node)
	node.anchor_left = anchors.x
	node.anchor_top = anchors.y
	node.anchor_right = anchors.z
	node.anchor_bottom = anchors.w
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w


func _panel(parent: Node, anchors: Vector4, offsets: Vector4) -> VBoxContainer:
	var frame := CutPanel.new()
	_rect(frame, parent, anchors, offsets)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	return box


func _label(parent: Node, text: String, font_size := 20, color := WHITE, numeric := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if numeric:
		label.add_theme_font_override("font", _number_font)
	parent.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := WindButton.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxEmpty.new()
		style.content_margin_left = 20
		style.content_margin_right = 44
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _link_buttons(buttons: Array[Control]) -> void:
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])


func _bar(parent: Node, accent := CYAN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("294b5b")
	bg.corner_radius_top_left = 2
	bg.corner_radius_bottom_right = 2
	var fill := bg.duplicate() as StyleBoxFlat
	fill.bg_color = accent
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _build_title() -> void:
	var screen := _new_screen("title")
	var box := _panel(screen, Vector4(0, 0.5, 0, 0.5), Vector4(40, -222, 520, 222))
	_label(box, "C L O U D S E A  S U R F E R", 16, CYAN)
	_label(box, "雲海サーファー", 46)
	_label(box, "白環の通学路 · 90秒の試作", 20, MUTED)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	box.add_child(spacer)
	var start := _button(box, "走る", func(): start_requested.emit())
	var settings := _button(box, "設定", func(): settings_requested.emit())
	_link_buttons([start, settings])
	_first_focus.title = start
	_title_controls = _label(box, "A / D 旋回  ·  Space ジャンプ", 16, MUTED)
	_title_controls_extra = _label(box, "S ブレーキ  ·  Shift ブースト", 16, MUTED)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "HUD"
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var left := _panel(_hud, Vector4.ZERO, Vector4(24, 24, 350, 150))
	left.add_theme_constant_override("separation", 4)
	_section = _label(left, "白環の通学路", 18)
	_section.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_time = _label(left, "00:00.00", 36, WHITE, true)
	_progress = _bar(left)
	var right := _panel(_hud, Vector4(1, 0, 1, 0), Vector4(-302, 24, -24, 150))
	right.add_theme_constant_override("separation", 0)
	_score = _label(right, "0", 36, WHITE, true)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var score_caption := _label(right, "SCORE", 16, MUTED)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flow = _label(right, "FLOW  ×1.00", 20, CYAN)
	_flow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var speed_box := _panel(_hud, Vector4(0, 1, 0, 1), Vector4(24, -120, 238, -24))
	speed_box.add_theme_constant_override("separation", 0)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	speed_box.add_child(speed_row)
	_speed = _label(speed_row, "00.0", 36, WHITE, true)
	var unit := _label(speed_row, "m/s", 18, MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	_label(speed_box, "SPEED", 16, MUTED)
	var energy_box := _panel(_hud, Vector4(1, 1, 1, 1), Vector4(-304, -120, -24, -24))
	energy_box.add_theme_constant_override("separation", 4)
	var energy_row := HBoxContainer.new()
	energy_box.add_child(energy_row)
	_label(energy_row, "風力", 20)
	_energy = _label(energy_row, "60 / 100", 24, WHITE, true)
	_energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_energy_bar = _bar(energy_box)
	_energy_bar.custom_minimum_size.y = 14
	_energy_bar.value = 60
	_notice = Label.new()
	_rect(_notice, _hud, Vector4.ZERO, Vector4(28, 164, 420, 238))
	_notice.add_theme_font_size_override("font_size", 20)
	_notice.add_theme_color_override("font_color", WHITE)
	_notice.add_theme_color_override("font_shadow_color", INK)
	_notice.add_theme_constant_override("shadow_outline_size", 8)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend = Label.new()
	_rect(_legend, _hud, Vector4(0.5, 1, 0.5, 1), Vector4(-330, -80, 330, -24))
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_legend.add_theme_font_size_override("font_size", 16)
	_legend.add_theme_color_override("font_color", WHITE)
	_legend.add_theme_color_override("font_shadow_color", INK)
	_legend.add_theme_constant_override("shadow_outline_size", 6)
	_refresh_legend()
	_screens.run = Control.new()
	_root.add_child(_screens.run)


func _build_countdown() -> void:
	var screen := _new_screen("countdown")
	var box := _panel(screen, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-190, -115, 190, 115))
	_count = _label(box, "3", 88, WHITE, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_caption = _label(box, "風を読んで、走り出そう", 20, MUTED)
	_count_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _shade(screen: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.08, 0.12, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(shade)


func _build_pause() -> void:
	var screen := _new_screen("pause")
	_shade(screen)
	var box := _panel(screen, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-228, -222, 228, 222))
	_pause_content = box.get_parent()
	_label(box, "P A U S E", 32)
	_label(box, "ひと息ついて、次の風へ。", 16, MUTED)
	_pause_first = _button(box, "続ける", func(): resume_requested.emit())
	var retry := _button(box, "最初から再挑戦", func(): _ask_discard("retry"))
	var settings := _button(box, "設定", func(): settings_requested.emit())
	var title := _button(box, "タイトルへ戻る", func(): _ask_discard("title"))
	_link_buttons([_pause_first, retry, settings, title])
	_first_focus.pause = _pause_first
	_confirmation = Control.new()
	_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(_confirmation)
	_shade(_confirmation)
	var confirm_box := _panel(_confirmation, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-256, -150, 256, 150))
	_confirm_label = _label(confirm_box, "現在の走行を終了しますか", 24)
	_label(confirm_box, "未完走の記録は保存されません。", 18, MUTED)
	var cancel := _button(confirm_box, "戻る", _close_confirmation)
	var accept := _button(confirm_box, "終了する", _accept_discard)
	_link_buttons([cancel, accept])
	_confirmation.set_meta("first_focus", cancel)


func _build_results() -> void:
	var screen := _new_screen("results")
	var box := _panel(screen, Vector4(0, 0.5, 0, 0.5), Vector4(40, -316, 540, 316))
	_results_frame = box.get_parent()
	box.add_theme_constant_override("separation", 8)
	_label(box, "F I N I S H", 40)
	_label(box, "白環の通学路", 24)
	_result_time = _result_row(box, "TIME")
	_best_time = _label(box, "記録なし", 16, CYAN)
	_result_score = _result_row(box, "SCORE")
	_best_score = _label(box, "記録なし", 16, CYAN)
	_result_falls = _result_row(box, "FALLS")
	_save_status = _label(box, "", 18, MUTED)
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry := _button(box, "再挑戦", func(): retry_requested.emit())
	var title := _button(box, "タイトルへ戻る", func(): title_requested.emit())
	_link_buttons([retry, title])
	_first_focus.results = retry


func _result_row(parent: Node, caption: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, caption, 18, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return _label(row, "—", 34, WHITE, true)


func _build_settings() -> void:
	var screen := _new_screen("settings")
	_shade(screen)
	var box := _panel(screen, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-270, -240, 270, 240))
	_label(box, "設 定", 32)
	_motion = CheckButton.new()
	_motion.text = "動きを減らす"
	_motion.custom_minimum_size.y = 64
	_motion.add_theme_font_size_override("font_size", 20)
	_motion.add_theme_color_override("font_color", WHITE)
	_motion.add_theme_color_override("font_hover_color", CYAN)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = CORAL
	focus.set_border_width_all(3)
	_motion.add_theme_stylebox_override("focus", focus)
	box.add_child(_motion)
	_motion.toggled.connect(_on_motion_changed)
	_label(box, "画面の揺れと視野角の変化を抑えます。", 16, MUTED)
	var volume_row := HBoxContainer.new()
	box.add_child(volume_row)
	var volume_label := _label(volume_row, "全体の音量", 20)
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_value = _label(volume_row, "75%", 20, CYAN, true)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 1
	_volume.step = 0.05
	_volume.value = 0.75
	_volume.custom_minimum_size.y = 64
	_volume.add_theme_stylebox_override("focus", focus)
	box.add_child(_volume)
	_volume.value_changed.connect(_on_volume_changed)
	_settings_controls = _label(box, "A / D 旋回   S ブレーキ   Space ジャンプ\nShift ブースト   Esc ポーズ", 16, MUTED)
	var close := _button(box, "戻る", func(): settings_closed.emit())
	_link_buttons([_motion, _volume, close])
	_first_focus.settings = _motion


func _build_error() -> void:
	var screen := _new_screen("error")
	_shade(screen)
	var box := _panel(screen, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-290, -190, 290, 190))
	_label(box, "準備できませんでした", 28, AMBER)
	_error_message = _label(box, "コースを読み込めませんでした", 20)
	_error_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_message.custom_minimum_size.y = 80
	var retry := _button(box, "再試行", func(): retry_requested.emit())
	var title := _button(box, "タイトルへ戻る", func(): title_requested.emit())
	_link_buttons([retry, title])
	_first_focus.error = retry


func _show_results(data: Dictionary) -> void:
	_result_time.text = _format_time(float(data.get("time", 0))) if data.has("time") else "—"
	_result_score.text = _format_score(int(data.score)) if data.has("score") else "—"
	_result_falls.text = str(data.falls) if data.has("falls") else "—"
	var best_time := float(data.get("best_time", -1))
	var best_score := int(data.get("best_score", -1))
	_best_time.text = "自己ベスト  " + _format_time(best_time) if best_time > 0 else "自己ベスト  記録なし"
	_best_score.text = "自己ベスト  " + _format_score(best_score) if best_score >= 0 else "自己ベスト  記録なし"
	if bool(data.get("saved", false)):
		if bool(data.get("new_best_time", false)) and best_time > 0:
			_best_time.text = "自己ベスト更新  " + _format_time(best_time)
		if bool(data.get("new_best_score", false)) and best_score >= 0:
			_best_score.text = "自己ベスト更新  " + _format_score(best_score)
	if data.has("saved"):
		_save_status.text = "記録を保存しました" if bool(data.saved) else "記録を保存できませんでした"
		_save_status.add_theme_color_override("font_color", MUTED if bool(data.saved) else AMBER)
	else:
		_save_status.text = "記録の保存状態を確認できません"


func _sync_settings(data: Dictionary) -> void:
	_syncing_settings = true
	_setting_values.reduced_motion = bool(data.get("reduced_motion", _setting_values.reduced_motion))
	_setting_values.master_volume = clampf(float(data.get("master_volume", _setting_values.master_volume)), 0, 1)
	_motion.button_pressed = _setting_values.reduced_motion
	_volume.value = _setting_values.master_volume
	_volume_value.text = "%d%%" % roundi(_volume.value * 100)
	_syncing_settings = false


func _on_motion_changed(value: bool) -> void:
	_setting_values.reduced_motion = value
	if not _syncing_settings:
		settings_changed.emit(_setting_values.duplicate())


func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value * 100)
	_setting_values.master_volume = value
	if not _syncing_settings:
		settings_changed.emit(_setting_values.duplicate())


func _ask_discard(action: String) -> void:
	_confirm_action = action
	_confirm_label.text = "最初から走り直しますか" if action == "retry" else "現在の走行を終了しますか"
	_pause_content.hide()
	_confirmation.show()
	(_confirmation.get_meta("first_focus") as Control).grab_focus()


func _close_confirmation() -> void:
	_confirmation.hide()
	_confirm_action = ""
	_pause_content.show()
	_pause_first.grab_focus()


func _accept_discard() -> void:
	var action := _confirm_action
	_confirmation.hide()
	_confirm_action = ""
	if action == "retry":
		retry_requested.emit()
	elif action == "title":
		title_requested.emit()


func _refresh_legend() -> void:
	if _legend == null:
		return
	var compact := _root.size.x < 1100
	if _using_pad:
		_legend.text = "左スティック 旋回 · A ジャンプ · RT ブースト" if compact else "左スティック 旋回  ·  LT ブレーキ  ·  A ジャンプ  ·  RT ブースト"
		if _title_controls != null:
			_title_controls.text = "左スティック 旋回  ·  A ジャンプ"
			_title_controls_extra.text = "LT ブレーキ  ·  RT ブースト"
		if _settings_controls != null:
			_settings_controls.text = "左スティック 旋回   LT ブレーキ   A ジャンプ\nRT ブースト   Menu ポーズ"
	else:
		_legend.text = "A / D 旋回 · Space ジャンプ · Shift ブースト" if compact else "A / D 旋回  ·  S ブレーキ  ·  Space ジャンプ  ·  Shift ブースト"
		if _title_controls != null:
			_title_controls.text = "A / D 旋回  ·  Space ジャンプ"
			_title_controls_extra.text = "S ブレーキ  ·  Shift ブースト"
		if _settings_controls != null:
			_settings_controls.text = "A / D 旋回   S ブレーキ   Space ジャンプ\nShift ブースト   Esc ポーズ"
	_legend.offset_top = -149 if compact else -84
	_legend.offset_bottom = -125 if compact else -28


func _refresh_layout() -> void:
	_refresh_legend()
	if _results_frame != null:
		var height := minf(540.0, _root.size.y - 16.0)
		_results_frame.offset_top = -height / 2.0
		_results_frame.offset_bottom = height / 2.0


func _format_time(seconds: float) -> String:
	var centiseconds := maxi(0, int(floor(seconds * 100.0)))
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]


func _format_score(value: int) -> String:
	var digits := str(maxi(0, value))
	var result := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result
