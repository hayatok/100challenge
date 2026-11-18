extends CanvasLayer

signal begin(continued: bool)
signal rush_requested
signal resume_requested
signal pause_requested
signal retry_requested
signal title_requested
signal weapon_requested(slot: int)
signal options_changed(settings: Dictionary)

const Instruments := preload("res://ui/instruments.gd")
const DEFAULTS := {"sensitivity": 1.0, "fov": 75.0, "shake": true, "flash": true, "volume": 0.7}
const BINDINGS := {
	"freight_left": KEY_A, "freight_right": KEY_D, "freight_forward": KEY_W,
	"freight_back": KEY_S, "freight_pause": KEY_ESCAPE,
	"freight_weapon_1": KEY_1, "freight_weapon_2": KEY_2, "freight_weapon_3": KEY_3,
}
const INK := Color("#f5ebd5")
const MUTED := Color("#b0bab3")
const GOLD := Color("#edb76a")
const MINT := Color("#8bcab8")
const RUST := Color("#a9472f")
const STEEL := Color("#101e1d")
const BORDER := Color("#63756a")
const TOUCH_GUIDE := "左手で移動。右側をなぞって照準。\n射撃ボタンは押したまま照準を動かせる。"
const DESKTOP_GUIDE := "WASD 移動　/　マウス 照準　/　左クリック 射撃\n1–3・ホイール 武器切替　/　Esc 一時停止"

var _root: Control
var _instruments: Instruments
var _menu: Control
var _panel: PanelContainer
var _font: Font
var _title_image: Texture2D
var _rush_image: AtlasTexture
var _buttons: Array[Button] = []
var _first_setting: Control
var _content: VBoxContainer
var _guide: Label
var _menu_heading: Label
var _settings_layout: BoxContainer
var _menu_actions: BoxContainer
var _mode := "title"
var _settings_from := "title"
var _pause_reason := ""
var _settings := DEFAULTS.duplicate()
var _has_save := false
var _rush_best := 0
var _results: Dictionary = {}
var _touch := false
var _movement := {}
var _look := Vector2.ZERO
var _mouse_fire := false
var _fire_edge := false
var _capture_grace := 0.0
var _stick_finger := -1
var _look_finger := -1
var _fire_finger := -1
var _look_point := Vector2.ZERO
var _fire_point := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font_path := "res://media/jp.ttf"
	_font = load(font_path) as Font if ResourceLoader.exists(font_path) else ThemeDB.fallback_font
	if _font is FontFile:
		_font.multichannel_signed_distance_field = true
	var title_path := "res://media/title.jpg"
	if ResourceLoader.exists(title_path):
		_title_image = load(title_path) as Texture2D
	var rush_path := "res://media/rush.jpg"
	if ResourceLoader.exists(rush_path):
		_rush_image = AtlasTexture.new()
		_rush_image.atlas = load(rush_path) as Texture2D
		# Frame the arena clear of the sample HUD baked into the concept art.
		_rush_image.region = Rect2(0, 88, _rush_image.atlas.get_width(), 628)
		_rush_image.filter_clip = true
	_touch = DisplayServer.is_touchscreen_available()
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = BINDINGS[action]
			InputMap.action_add_event(action, key)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.resized.connect(_on_resize)
	_instruments = Instruments.new()
	_instruments.font = _font
	_instruments.touch = _touch
	_instruments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_instruments)
	_instruments.refresh_pixel_ratio()
	_instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_instruments.hide()
	show_title(false)

func show_title(has_save: bool, rush_best: int = 0) -> void:
	_has_save = has_save
	_rush_best = rush_best
	_show_menu("title")

func show_play() -> void:
	_reset_inputs()
	_mode = "play"
	_pause_reason = ""
	_clear_menu()
	_instruments.show()
	if not _touch:
		_capture_grace = 0.55
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _needs_landscape():
		_request_pause("rotate")

func show_pause() -> void:
	_show_menu("pause")

func show_death() -> void:
	_show_menu("death")

func show_result(stats: Dictionary) -> void:
	_results = stats.duplicate()
	_show_menu("result")

func show_rush_result(stats: Dictionary) -> void:
	_results = stats.duplicate()
	_show_menu("rush_result")

func set_options(settings: Dictionary) -> void:
	_settings = DEFAULTS.duplicate()
	_settings.merge(settings, true)
	if is_instance_valid(_instruments):
		_instruments.show_flash = bool(_settings["flash"])
		_instruments.queue_redraw()

func update_hud(state: Dictionary) -> void:
	if _instruments.state == state:
		return
	_instruments.state = state.duplicate(true)
	_instruments.queue_redraw()

func impact(event: String) -> void:
	_instruments.feedback = event
	_instruments.feedback_left = 0.30 if event == "hurt" else 0.16
	_instruments.queue_redraw()

func hurt_from(direction: Vector2) -> void:
	_instruments.damage_direction = direction
	impact("hurt")

func consume_controls() -> Dictionary:
	var move := Vector2(
		float(_movement.has("freight_right")) - float(_movement.has("freight_left")),
		float(_movement.has("freight_forward")) - float(_movement.has("freight_back"))
	)
	if _stick_finger >= 0:
		move = _instruments.finger_move * Vector2(1.0, -1.0)
	var state := {
		"move": move.limit_length(),
		"look": _look,
		"fire": _fire_edge or _mouse_fire or _fire_finger >= 0,
	}
	_look = Vector2.ZERO
	_fire_edge = false
	return state

func _process(delta: float) -> void:
	if _mode != "play":
		return
	if _instruments.feedback_left > 0.0:
		_instruments.feedback_left = maxf(0.0, _instruments.feedback_left - delta)
		_instruments.queue_redraw()
	if not _touch:
		_capture_grace = maxf(0.0, _capture_grace - delta)
		if _capture_grace == 0.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_request_pause("capture")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _mode == "play":
		_request_pause("focus")

func _on_resize() -> void:
	if is_instance_valid(_instruments):
		_instruments.refresh_pixel_ratio()
	if _mode == "play" and _needs_landscape():
		_request_pause("rotate")
	elif is_instance_valid(_panel):
		_layout_menu()
		if _mode == "pause" and not _buttons.is_empty():
			_buttons[0].disabled = _needs_landscape()
			_buttons[0].text = "画面を横向きにしてください" if _needs_landscape() else "任務に戻る"
		elif not _needs_landscape() and is_instance_valid(_content):
			var notice := _content.get_node_or_null("RotateNotice")
			if notice != null:
				notice.queue_free()

func _needs_landscape() -> bool:
	return _touch and _root.size.x < _root.size.y

func _request_pause(reason: String) -> void:
	_pause_reason = reason
	pause_requested.emit()

func _reset_inputs() -> void:
	_look = Vector2.ZERO
	_movement.clear()
	_mouse_fire = false
	_fire_edge = false
	_capture_grace = 0.0
	_stick_finger = -1
	_look_finger = -1
	_fire_finger = -1
	_instruments.finger_move = Vector2.ZERO
	_instruments.aiming_fire = false
	_instruments.feedback_left = 0.0
	_instruments.damage_direction = Vector2.ZERO
	_instruments.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION and not _touch:
		_touch = true
		_instruments.touch = true
		_instruments.queue_redraw()
		if is_instance_valid(_guide):
			_guide.text = TOUCH_GUIDE
		if _mode == "play":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_reset_inputs()
			if _needs_landscape():
				_request_pause("rotate")
				return
	if _mode != "play":
		if event.is_action_pressed("freight_pause"):
			match _mode:
				"settings":
					_show_menu(_settings_from)
				"rush_briefing":
					_show_menu("title")
				"rush_result":
					title_requested.emit()
				_:
					return
			get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventKey:
		_handle_key(event)
	elif not _touch and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_look += event.relative
		elif event is InputEventMouseButton:
			_handle_mouse_button(event)

func _handle_key(event: InputEventKey) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("freight_pause"):
		_request_pause("")
		get_viewport().set_input_as_handled()
		return
	for action in ["freight_left", "freight_right", "freight_forward", "freight_back"]:
		if event.is_action_pressed(action):
			_movement[action] = true
		elif event.is_action_released(action):
			_movement.erase(action)
	for slot in 3:
		if event.is_action_pressed("freight_weapon_%d" % (slot + 1)):
			if _owns(slot):
				weapon_requested.emit(slot)
			get_viewport().set_input_as_handled()
			break

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_mouse_fire = event.pressed
			_fire_edge = _fire_edge or event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_cycle_weapon(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_cycle_weapon(-1)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var point := event.position
	var s := _instruments.scale_factor()
	if event.pressed:
		if _instruments.pause_rect().has_point(point):
			_request_pause("")
			get_viewport().set_input_as_handled()
			return
		if _instruments.switch_rect().has_point(point) and _owned().count(true) > 1:
			_cycle_weapon(1)
		elif _stick_finger < 0 and point.distance_to(_instruments.stick_center()) <= 68 * s:
			_stick_finger = event.index
			_move_stick(point)
		elif _fire_finger < 0 and point.distance_to(_instruments.fire_center()) <= 45 * s:
			_fire_finger = event.index
			_fire_point = point
			_fire_edge = true
			_instruments.aiming_fire = true
		elif _look_finger < 0 and point.x >= _root.size.x * 0.46:
			_look_finger = event.index
			_look_point = point
	else:
		if event.index == _stick_finger:
			_stick_finger = -1
			_instruments.finger_move = Vector2.ZERO
		elif event.index == _look_finger:
			_look_finger = -1
		elif event.index == _fire_finger:
			_fire_finger = -1
			_instruments.aiming_fire = false
	_instruments.queue_redraw()
	get_viewport().set_input_as_handled()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_finger:
		_move_stick(event.position)
		_instruments.queue_redraw()
	elif event.index == _fire_finger:
		_look += _touch_aim_delta(event.position - _fire_point)
		_fire_point = event.position
	elif event.index == _look_finger:
		_look += _touch_aim_delta(event.position - _look_point)
		_look_point = event.position
	get_viewport().set_input_as_handled()

func _touch_aim_delta(distance: Vector2) -> Vector2:
	return distance * _instruments.css_scale() * 1.8

func _move_stick(point: Vector2) -> void:
	var lever := (point - _instruments.stick_center()) / (42.0 * _instruments.scale_factor())
	_instruments.finger_move = lever.normalized() * clampf((lever.length() - 0.13) / 0.87, 0.0, 1.0)

func _owned() -> Array:
	return _instruments.state.get("owned", [true, false, false])

func _owns(slot: int) -> bool:
	var weapons := _owned()
	return slot < weapons.size() and bool(weapons[slot])

func _cycle_weapon(direction: int) -> void:
	var current := int(_instruments.state.get("weapon", 0))
	for step in range(1, 3):
		var slot := posmod(current + direction * step, 3)
		if _owns(slot):
			weapon_requested.emit(slot)
			return

func _clear_menu() -> void:
	_buttons.clear()
	_first_setting = null
	_guide = null
	_menu_heading = null
	_settings_layout = null
	_menu_actions = null
	if is_instance_valid(_menu):
		_root.remove_child(_menu)
		_menu.queue_free()
		_menu = null
	_panel = null

func _show_menu(mode: String) -> void:
	_mode = mode
	_reset_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_instruments.hide()
	_clear_menu()
	_menu = Control.new()
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rush_menu := mode in ["rush_briefing", "rush_result"]
	var backdrop: Texture2D = _rush_image if rush_menu else _title_image if mode == "title" else null
	if backdrop != null:
		var artwork := TextureRect.new()
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.texture = backdrop
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_menu.add_child(artwork)
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0.023, 0.046, 0.041, 0.36 if backdrop != null else 0.78)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.theme = _make_theme()
	_panel.add_theme_stylebox_override("panel", _surface(
		Color(0.046, 0.081, 0.074, 0.96), BORDER, 1, 0, 0))
	_menu.add_child(_panel)
	_layout_menu()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_panel.add_child(column)
	var stripe := ColorRect.new()
	stripe.color = RUST if mode == "death" else GOLD
	stripe.custom_minimum_size.y = 4
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stripe)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		var padding := 10 if (mode == "title" or rush_menu) and side in ["top", "bottom"] else 20
		margin.add_theme_constant_override("margin_" + side, padding)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.add_theme_constant_override("separation", 8)
	margin.add_child(_content)
	match mode:
		"title":
			_heading("", "屍港最終便")
			_body("市場を抜け、港の最終便に乗れ。")
			if _has_save:
				_button("続きから", func(): _start(true), true)
			else:
				_button("最初から", func(): _start(false), true)
			_add_menu_actions()
			if _has_save:
				_button("最初から", func(): _start(false), false, _menu_actions)
			_button("終鈴ラッシュ", func(): _show_menu("rush_briefing"), false, _menu_actions)
			_button("設定", _open_settings, false, _menu_actions)
			_guide = _body(TOUCH_GUIDE if _touch else DESKTOP_GUIDE)
		"rush_briefing":
			_heading("", "終鈴ラッシュ")
			_body("90秒間生き延び、できるだけ多くの敵を倒そう。")
			_body("鐘を撃つと敵が集まる。\n帯電した鐘をもう一度撃つと放電。\n放電で敵をまとめて倒すとボーナスが入る。")
			_body("最高得点　%d" % _rush_best)
			_add_menu_actions()
			_button("開始", _start_rush, true, _menu_actions)
			_button("戻る", func(): _show_menu("title"), false, _menu_actions)
		"rush_result":
			_show_rush_result_content()
		"pause":
			_heading("", "一時停止")
			if _pause_reason == "focus":
				_body("画面から離れたため停止しました。")
			var resume := _button("画面を横向きにしてください" if _needs_landscape() else "任務に戻る", _resume, true)
			resume.disabled = _needs_landscape()
			_button("設定", _open_settings)
			_button("タイトルへ", func(): title_requested.emit())
		"death":
			_heading("回収不能", "任務失敗")
			_button("チェックポイントから", func(): retry_requested.emit(), true)
			_button("タイトルへ", func(): title_requested.emit())
		"result":
			_heading("任務完了", "最終便、出航")
			_result_rows()
			_button("タイトルへ", func(): title_requested.emit(), true)
		"settings":
			_heading("", "設定")
			_populate_settings()
	_layout_menu()
	if not _touch:
		if is_instance_valid(_first_setting):
			_focus_later.call_deferred(_first_setting)
			return
		for button in _buttons:
			if not button.disabled:
				_focus_later.call_deferred(button)
				break

func _focus_later(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()

func _layout_menu() -> void:
	var menu_scale := maxf(1.0, 1.0 / maxf(0.1, _instruments.css_scale()))
	var available := _root.size / menu_scale
	var pad := 12.0 if available.y < 420.0 else 24.0
	var compact_landscape := available.x >= 660.0 and available.y < 440.0
	var desired_width := 406.0
	if _mode == "settings":
		desired_width = 620.0 if compact_landscape else 426.0
	if is_instance_valid(_settings_layout):
		_settings_layout.vertical = not compact_landscape
	if is_instance_valid(_content):
		_content.add_theme_constant_override("separation", 5 if compact_landscape else 8)
	if _mode == "title" and is_instance_valid(_menu_heading):
		_menu_heading.add_theme_font_size_override("font_size", 39 if compact_landscape else 46)
	if is_instance_valid(_menu_actions):
		_menu_actions.vertical = not compact_landscape
	var width := minf(available.x - 2.0 * pad, desired_width)
	var limit := 432.0 if _mode in ["settings", "title", "rush_briefing"] else 338.0
	var height := minf(limit, available.y - 2.0 * pad)
	var has_art := _mode in ["title", "rush_briefing", "rush_result"]
	var x := clampf(available.x * 0.055, pad, 74.0) if has_art and available.x >= 680.0 else (available.x - width) / 2.0
	_panel.position = Vector2(x, (available.y - height) / 2.0) * menu_scale
	_panel.size = Vector2(width, height)
	_panel.scale = Vector2.ONE * menu_scale

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 16
	for state: StringName in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "Button", INK)
		theme.set_color(state, "CheckButton", INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("normal", "Button", _surface(STEEL, BORDER, 2))
	theme.set_stylebox("hover", "Button", _surface(Color("#27413a"), MINT, 2))
	theme.set_stylebox("pressed", "Button", _surface(Color("#314840"), GOLD, 2))
	theme.set_stylebox("disabled", "Button", _surface(Color("#172321"), BORDER, 2))
	var focus := _surface(Color.TRANSPARENT, GOLD, 3, 0, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "CheckButton", focus)
	theme.set_stylebox("slider", "HSlider", _surface(Color("#192723"), BORDER, 1, 0, 2))
	theme.set_stylebox("grabber_area", "HSlider", _surface(Color("#34574d"), MINT, 1, 0, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _surface(Color("#3a655b"), MINT, 1, 0, 2))
	return theme

func _surface(color: Color, outline: Color, thickness: int, padding_x := 13, padding_y := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding_x
	style.content_margin_right = padding_x
	style.content_margin_top = padding_y
	style.content_margin_bottom = padding_y
	return style

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _heading(kicker: String, title: String) -> void:
	if not kicker.is_empty():
		_content.add_child(_label(kicker, 14, GOLD))
	_menu_heading = _label(title, 32, INK)
	_menu_heading.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_content.add_child(_menu_heading)
	var rule := HSeparator.new()
	rule.add_theme_stylebox_override("separator", _surface(BORDER, BORDER, 0, 0, 1))
	_content.add_child(rule)

func _body(value: String) -> Label:
	var label := _label(value, 14, MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
	return label

func _add_menu_actions() -> void:
	_menu_actions = BoxContainer.new()
	_menu_actions.add_theme_constant_override("separation", 8)
	_content.add_child(_menu_actions)

func _button(value: String, action: Callable, primary := false, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 44.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		var main := _surface(RUST, Color("#e4875e"), 2)
		main.shadow_color = Color("#060e0d")
		main.shadow_size = 2
		main.shadow_offset = Vector2(2, 3)
		button.add_theme_stylebox_override("normal", main)
		button.add_theme_stylebox_override("hover", _surface(Color("#b34d34"), GOLD, 2))
		button.add_theme_stylebox_override("pressed", _surface(Color("#803721"), GOLD, 2))
	button.pressed.connect(action)
	var container := parent if parent != null else _content
	container.add_child(button)
	_buttons.append(button)
	return button

func _start(continued: bool) -> void:
	if _needs_landscape():
		_open_rotate_notice()
		return
	begin.emit(continued)

func _start_rush() -> void:
	if _needs_landscape():
		_open_rotate_notice()
		return
	rush_requested.emit()

func _open_rotate_notice() -> void:
	if is_instance_valid(_content.get_node_or_null("RotateNotice")):
		return
	var notice := _label("画面を横向きにしてください", 16, GOLD)
	notice.name = "RotateNotice"
	_content.add_child(notice)

func _resume() -> void:
	if not _needs_landscape():
		resume_requested.emit()

func _open_settings() -> void:
	_settings_from = _mode
	_show_menu("settings")

func _option(key: String, value: Variant) -> void:
	_settings[key] = value
	_instruments.show_flash = bool(_settings["flash"])
	options_changed.emit(_settings.duplicate())

func _populate_settings() -> void:
	_settings_layout = BoxContainer.new()
	_settings_layout.add_theme_constant_override("separation", 14)
	_content.add_child(_settings_layout)
	var sliders := VBoxContainer.new()
	var switches := VBoxContainer.new()
	for group in [sliders, switches]:
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 8)
		_settings_layout.add_child(group)
	_slider("照準感度", "sensitivity", 0.25, 2.5, 0.05, sliders)
	_slider("視野角", "fov", 60, 100, 1, sliders)
	_slider("音量", "volume", 0, 1, 0.05, sliders)
	_switch("画面の揺れ", "shake", switches)
	_switch("閃光", "flash", switches)
	_button("戻る", func(): _show_menu(_settings_from), true, switches)

func _slider(label: String, key: String, minimum: float, maximum: float, step: float, parent: Container) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_label := _label(label, 16, INK)
	name_label.custom_minimum_size.x = 86
	row.add_child(name_label)
	var slider := HSlider.new()
	if _first_setting == null:
		_first_setting = slider
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_settings[key])
	slider.tooltip_text = label
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 44
	row.add_child(slider)
	var number := _label(_option_text(key, slider.value), 14, GOLD)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.custom_minimum_size.x = 48
	row.add_child(number)
	slider.value_changed.connect(func(value: float):
		number.text = _option_text(key, value)
		_option(key, value)
	)

func _option_text(key: String, value: float) -> String:
	match key:
		"sensitivity":
			return "%.2f" % value
		"fov":
			return "%d°" % roundi(value)
		_:
			return "%d%%" % roundi(value * 100.0)

func _switch(label: String, key: String, parent: Container) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.custom_minimum_size.y = 44
	toggle.button_pressed = bool(_settings[key])
	toggle.toggled.connect(func(value: bool): _option(key, value))
	parent.add_child(toggle)

func _result_rows() -> void:
	if _results.has("time_seconds"):
		var seconds := maxi(0, roundi(float(_results["time_seconds"])))
		_body("所要時間　%02d:%02d" % [floori(seconds / 60.0), seconds % 60])
	if _results.has("kills"):
		_body("撃破数　%d" % int(_results["kills"]))
	if _results.has("hp"):
		_body("残り体力　%d" % int(_results["hp"]))

func _show_rush_result_content() -> void:
	_heading("生還" if _results["survived"] else "力尽きた", "終鈴ラッシュ")
	_content.add_child(_label("得点　%d" % int(_results["score"]), 27, GOLD))
	var best := "最高得点　%d（更新）" if _results["new_best"] else "最高得点　%d"
	_body(best % int(_results["best"]))
	_body("撃破　%d体　　放電で一度に最大%d体" % [int(_results["kills"]), int(_results["best_discharge"])])
	_add_menu_actions()
	_button("再挑戦", _start_rush, true, _menu_actions)
	_button("タイトルへ", func(): title_requested.emit(), false, _menu_actions)
