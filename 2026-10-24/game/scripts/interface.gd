extends CanvasLayer

signal start_requested(resume: bool)
signal resume_requested
signal restart_requested
signal title_requested
signal settings_changed(values: Dictionary)

const PAPER := Color("f6eddc")
const INK := Color("123443")
const GOLD := Color("d9ba7b")
const RED := Color("d64f34")
var root: Control
var menu: Control
var hud: Control
var health_label: Label
var health_bar: ProgressBar
var dash_label: Label
var hint: Label
var location_label: Label
var clock_label: Label
var reticle: Label
var settings: Dictionary = {}
var can_continue := false
var menu_kind := "title"
var result_text := ""
var result_success := true
var focus_button: Button
var notice: Label
var danger_marks: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	theme.default_font_size = 20
	root.theme = theme
	_build_hud()

func _label(text: String, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = RED if primary else Color(0.07, 0.18, 0.22, 0.85)
		if state == "hover": style.bg_color = style.bg_color.lightened(0.13)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.border_width_left = 3
		style.border_color = GOLD if state == "focus" else (PAPER if primary else Color(0.85, 0.75, 0.52, 0.3))
		if state == "focus":
			style.set_border_width_all(3)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.pressed.connect(action)
	if focus_button == null: focus_button = button
	return button

func _menu_frame(kind: String, title: String, centered: bool = false) -> VBoxContainer:
	if is_instance_valid(menu): menu.queue_free()
	focus_button = null
	menu_kind = kind
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025, 0.10, 0.14, 0.97), Color(0.025, 0.10, 0.14, 0.80), Color(0.025, 0.10, 0.14, 0.0)])
	gradient.offsets = PackedFloat32Array([0, 0.32, 0.85])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	shade.texture = texture
	menu.add_child(shade)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 64)
	outer.add_theme_constant_override("margin_right", 40)
	outer.add_theme_constant_override("margin_top", 38)
	outer.add_theme_constant_override("margin_bottom", 32)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(outer)
	var row := HBoxContainer.new()
	outer.add_child(row)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	if title != "": column.add_child(_label(title, 52))
	hud.visible = false
	return column

func _focus() -> void:
	if is_instance_valid(focus_button): focus_button.grab_focus.call_deferred()

func show_title(has_save: bool) -> void:
	can_continue = has_save
	var column := _menu_frame("title", "")
	var eyebrow := _label("TENSAI", 22, GOLD)
	eyebrow.add_theme_constant_override("outline_size", 0)
	column.add_child(eyebrow)
	column.add_child(_label("天砕", 116))
	column.add_child(_label("風の参道", 24))
	var space := Control.new()
	space.custom_minimum_size.y = 24
	column.add_child(space)
	if has_save: column.add_child(_button("つづける", func(): start_requested.emit(true), true))
	column.add_child(_button("はじめる", func(): start_requested.emit(false), not has_save))
	column.add_child(_button("設定", func(): show_settings("title")))
	_focus()

func show_play() -> void:
	if is_instance_valid(menu): menu.queue_free()
	menu = null
	menu_kind = "play"
	hud.visible = true

func show_pause() -> void:
	var column := _menu_frame("pause", "休止")
	column.add_child(_button("つづける", func(): resume_requested.emit(), true))
	column.add_child(_button("やり直す", func(): restart_requested.emit()))
	column.add_child(_button("設定", func(): show_settings("pause")))
	column.add_child(_button("タイトルへ", func(): title_requested.emit()))
	column.add_child(_label("WASD  移動    マウス  視点\nSpace  ジャンプ    Shift  ダッシュ・長押しで滑走\nE  ワイヤー    Q  ロック    ホイール  対象変更\n左クリック  斬る    右クリック  打ち上げ・急降下", 17, Color("c8d5d4")))
	_focus()

func show_result(success: bool, time_value: float, kills: int) -> void:
	result_success = success
	result_text = "%02d:%05.2f    撃破 %d" % [int(time_value) / 60, fmod(time_value, 60.0), kills]
	var column := _menu_frame("result", "帰還" if success else "再起")
	column.add_child(_label("風の参道", 24, GOLD))
	column.add_child(_label(result_text, 28))
	column.add_child(_button("再挑戦", func(): restart_requested.emit(), true))
	column.add_child(_button("タイトルへ", func(): title_requested.emit()))
	_focus()

func show_settings(back: String) -> void:
	var column := _menu_frame("settings", "設定")
	_add_slider(column, "音量", "volume", 0.0, 1.0, 0.05)
	_add_slider(column, "視点の感度", "sensitivity", 0.4, 2.0, 0.1)
	for option in [["上下を反転", "invert_y"], ["衝撃の演出を抑える", "reduced_motion"]]:
		var toggle := CheckButton.new()
		toggle.text = option[0]
		toggle.custom_minimum_size.y = 48
		toggle.button_pressed = bool(settings.get(option[1], false))
		toggle.add_theme_color_override("font_color", PAPER)
		var key: String = option[1]
		toggle.toggled.connect(func(value: bool): settings[key] = value; settings_changed.emit(settings.duplicate()))
		column.add_child(toggle)
	column.add_child(_label("パッド：左スティック 移動／右スティック 視点\nA ジャンプ／B ダッシュ／LT ワイヤー\nRB 斬る／RT 強攻撃／R3 ロック", 17, Color("c8d5d4")))
	column.add_child(_button("戻る", func():
		if back == "title": show_title(can_continue)
		else: show_pause(), true))
	_focus()

func _add_slider(column: VBoxContainer, text: String, key: String, low: float, high: float, step: float) -> void:
	column.add_child(_label(text, 20))
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(340, 42)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(settings.get(key, 1.0))
	slider.value_changed.connect(func(value: float): settings[key] = value; settings_changed.emit(settings.duplicate()))
	column.add_child(slider)

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	backdrop.position = Vector2(24,-128)
	backdrop.size = Vector2(298,112)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04,0.12,0.17,0.72)
	panel.border_width_left = 2
	panel.border_color = GOLD
	backdrop.add_theme_stylebox_override("panel",panel)
	hud.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	margin.position = Vector2(40, -112)
	margin.size = Vector2(260, 80)
	hud.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	health_label = _label("体力", 17)
	column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(240, 8)
	health_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.12, 0.17, 0.75)
	health_bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = PAPER
	health_bar.add_theme_stylebox_override("fill", fg)
	column.add_child(health_bar)
	dash_label = _label("◆  ◆", 24, GOLD)
	column.add_child(dash_label)
	location_label = _label("風の参道", 22)
	location_label.add_theme_constant_override("outline_size",4)
	location_label.add_theme_color_override("font_outline_color",INK)
	location_label.position = Vector2(40, 26)
	hud.add_child(location_label)
	clock_label = _label("", 18)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.position = Vector2(-180, 28)
	clock_label.add_theme_constant_override("outline_size",4)
	clock_label.add_theme_color_override("font_outline_color",INK)
	clock_label.size.x = 140
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(clock_label)
	hint = _label("", 20)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-330, -72)
	hint.size = Vector2(660, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_color_override("font_outline_color", Color(0.03,0.1,0.15,0.9))
	hud.add_child(hint)
	reticle = _label("◇", 32, GOLD)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_theme_color_override("font_outline_color", INK)
	reticle.add_theme_constant_override("outline_size", 3)
	hud.add_child(reticle)
	notice = _label("", 18, GOLD)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.position = Vector2(-320, 64)
	notice.size.x = 640
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(notice)
	for i in range(3):
		var danger := _label("!",36,Color("ff8064"))
		danger.add_theme_constant_override("outline_size",6)
		danger.add_theme_color_override("font_outline_color",INK)
		danger.visible = false
		hud.add_child(danger)
		danger_marks.append(danger)
	hud.visible = false

func update_play(player: Node3D, elapsed: float, prompt: String) -> void:
	health_bar.value = player.health
	health_label.text = "体力  %d" % player.health
	dash_label.text = "  ".join(["◆" if player.air_dashes > 0 else "◇", "◆" if player.air_dashes > 1 else "◇"])
	clock_label.text = "%02d:%02d" % [int(elapsed)/60, int(elapsed)%60]
	hint.text = prompt
	reticle.visible = is_instance_valid(player.current_target) and is_instance_valid(player.camera)
	if reticle.visible:
		var point: Vector3 = player.current_target.global_position
		if player.current_target.has_method("get_aim_position"): point = player.current_target.get_aim_position()
		reticle.visible = not player.camera.is_position_behind(point)
		reticle.position = player.camera.unproject_position(point) - Vector2(17, 23)

	var index := 0
	var size: Vector2 = root.size
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.state_name not in ["windup","strike"] or index >= danger_marks.size(): continue
		var at: Vector3 = enemy.global_position + Vector3.UP * 2.5
		var screen: Vector2 = player.camera.unproject_position(at)
		if player.camera.is_position_behind(at):
			var side: float = player.camera.global_basis.x.dot(at-player.camera.global_position)
			screen = Vector2(size.x-45 if side >= 0 else 25,size.y*0.5)
		danger_marks[index].position = Vector2(clampf(screen.x-10,25,size.x-45),clampf(screen.y-28,90,size.y-140))
		danger_marks[index].visible = true
		index += 1
	for i in range(index,danger_marks.size()): danger_marks[i].visible = false
