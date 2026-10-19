extends Control

signal start_requested
signal resume_requested
signal retry_requested
signal title_requested
signal pause_requested
signal upgrade_requested(index: int)
signal sound_changed(enabled: bool)
signal motion_changed(reduced: bool)

const PAPER := Color("f5efdf")
const GOLD := Color("dbc182")
const MUTED := Color("c2bdb0")
const BLUE := Color("92d4e8")
const DANGER := Color("e78b88")

var run
var sound_enabled := true
var reduced_motion := false
var hud: Control
var overlay: Control
var health_label: Label
var health_bar: ProgressBar
var clock_label: Label
var kill_label: Label
var level_label: Label
var experience_bar: ProgressBar
var weapon_label: Label
var hint: Label
var last_screen := ""
var sound_buttons: Array[Button] = []
var motion_buttons: Array[Button] = []
var book_theme: Theme

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_theme()
	theme = book_theme
	_build_hud()
	refresh()

func _make_theme() -> void:
	book_theme = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf"):
		book_theme.default_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	book_theme.default_font_size = 20
	book_theme.set_color("font_color", "Label", PAPER)
	book_theme.set_color("font_color", "Button", PAPER)
	book_theme.set_color("font_hover_color", "Button", PAPER)
	book_theme.set_color("font_pressed_color", "Button", Color("161d32"))
	book_theme.set_color("font_focus_color", "Button", PAPER)
	book_theme.set_stylebox("panel", "PanelContainer", _box(Color("1e273e"), Color("968766"), 2, 8))
	book_theme.set_stylebox("normal", "Button", _box(Color("29344b"), Color("968766"), 2, 5))
	book_theme.set_stylebox("hover", "Button", _box(Color("37455d"), GOLD, 2, 5))
	book_theme.set_stylebox("pressed", "Button", _box(GOLD, PAPER, 2, 5))
	book_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 3, 5))
	book_theme.set_constant("outline_size", "Label", 0)

func _box(fill: Color, border: Color, thickness: int, corner: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.02, 0.025, 0.06, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	return style

func _label(text: String, font_size: int = 20, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _at(node: Control, x: float, y: float, width: float, height: float) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(width, height)

func _panel(parent: Control, x: float, y: float, width: float, height: float) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.12, 0.20, 0.94), Color("8a8067"), 1, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	_at(panel, x, y, width, height)
	return panel

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _box(Color("111827"), Color("566078"), 1, 3)
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	var fill := _box(color, color, 0, 3)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _build_hud() -> void:
	hud = Control.new()
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_panel := _panel(hud, 22, 20, 280, 78)
	health_label = _label("HP 100 / 100", 18)
	hp_panel.add_child(health_label)
	_at(health_label, 16, 6, 248, 30)
	health_bar = _bar(Color("b67183"))
	hp_panel.add_child(health_bar)
	_at(health_bar, 16, 45, 248, 17)
	var timer_panel := _panel(hud, 552, 16, 176, 86)
	var timer_caption := _label("夜明けまで", 15, MUTED)
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_panel.add_child(timer_caption)
	_at(timer_caption, 0, 5, 176, 24)
	clock_label = _label("03:00", 32)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_panel.add_child(clock_label)
	_at(clock_label, 0, 28, 176, 51)
	var score_panel := _panel(hud, 980, 20, 200, 78)
	kill_label = _label("討伐  0", 24)
	score_panel.add_child(kill_label)
	_at(kill_label, 16, 4, 176, 39)
	level_label = _label("魔女  Lv.1", 17, MUTED)
	score_panel.add_child(level_label)
	_at(level_label, 16, 43, 176, 28)
	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.add_theme_font_size_override("font_size", 26)
	pause_button.tooltip_text = "休止 [Esc]"
	pause_button.focus_mode = Control.FOCUS_NONE
	hud.add_child(pause_button)
	_at(pause_button, 1192, 20, 66, 78)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	var xp_panel := _panel(hud, 22, 622, 1236, 78)
	experience_bar = _bar(GOLD)
	xp_panel.add_child(experience_bar)
	_at(experience_bar, 16, 12, 1204, 10)
	weapon_label = _label("雷 Ⅰ   /   月輪 未習得", 19)
	xp_panel.add_child(weapon_label)
	_at(weapon_label, 16, 32, 610, 32)
	var controls := _label("WASD / 矢印  移動     Esc  休止", 17, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_panel.add_child(controls)
	_at(controls, 635, 33, 565, 32)
	hint = _label("", 20, PAPER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", Color("131a29"))
	hint.add_theme_constant_override("outline_size", 7)
	hud.add_child(hint)
	_at(hint, 270, 116, 740, 42)

func refresh() -> void:
	if run == null:
		return
	hud.visible = run.state != "title"
	var key := "%s:%d" % [run.state, run.level]
	if key != last_screen:
		last_screen = key
		_rebuild_overlay()
	health_label.text = "HP %d / %d" % [ceili(run.health), int(run.maximum_health)]
	health_bar.max_value = run.maximum_health
	health_bar.value = run.health
	health_label.add_theme_color_override("font_color", DANGER if run.health <= 30.0 else PAPER)
	var remaining := maxi(0, ceili(180.0 - run.elapsed))
	clock_label.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	clock_label.add_theme_color_override("font_color", GOLD if remaining <= 30 else PAPER)
	kill_label.text = "討伐  %d" % run.kills
	level_label.text = "魔女  Lv.%d" % run.level
	experience_bar.max_value = run.experience_needed
	experience_bar.value = run.experience
	var moon_text := "月輪 %d重" % int(run.weapons.moon.count) if int(run.weapons.moon.level) > 0 else "月輪 未習得"
	weapon_label.text = "雷 %d本   /   %s     経験値 %d / %d" % [int(run.weapons.lightning.count), moon_text, run.experience, run.experience_needed]
	if run.elapsed < 2.0:
		hint.text = "WASD / 矢印で移動。魔法は自動で放つ。"
	elif run.elapsed < 9.0:
		hint.text = "青い残像が2秒前の位置と攻撃を再現。"
	elif run.elapsed > 145.0 and run.elapsed < 150.0:
		hint.text = "夜明け前。二人の魔法で、群れを切りひらこう。"
	else:
		hint.text = ""

func _rebuild_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	sound_buttons.clear()
	motion_buttons.clear()
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match str(run.state):
		"title": _title_screen()
		"upgrade": _upgrade_screen()
		"paused": _pause_screen()
		"victory", "defeat": _result_screen()

func _title_screen() -> void:
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	_at(panel, 56, 58, 664, 604)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_label("AFTERIMAGE SURVIVAL", 15, GOLD))
	box.add_child(_label("残響の魔女", 56))
	box.add_child(_label("歩いた道が、もう一人の戦場になる。", 21, GOLD))
	_add_rule(box)
	box.add_child(_label("2秒前の自分が、同じ魔法を放つ。\n残像と道を分け、夜明けまで3分生き延びよう。", 20))
	box.add_child(_label("WASD / 矢印  移動    ・    攻撃は自動", 20, MUTED))
	var start := _button("庭園へ入る  [Enter]", true)
	box.add_child(start)
	start.pressed.connect(func() -> void: start_requested.emit())
	_add_settings(box)
	box.add_child(_label("強化は 1 / 2 / 3 またはクリック    ・    Esc で休止", 17, MUTED))
	start.call_deferred("grab_focus")

func _base_modal(width: float) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.05, 0.10, 0.84)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _upgrade_screen() -> void:
	var box := _base_modal(1030)
	var heading := _label("魔術書に、新しい一節を。", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var subtitle := _label("Lv.%d  ひとつ選んで、残像と強くなる。" % run.level, 20, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	for index in range(run.choices.size()):
		var choice: Dictionary = run.choices[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(316, 278)
		cards.add_child(button)
		button.pressed.connect(func() -> void: upgrade_requested.emit(index))
		var margin := MarginContainer.new()
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 19)
		margin.add_theme_constant_override("margin_right", 19)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 9)
		margin.add_child(content)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_label("[%d]   %s" % [index + 1, choice.tag], 18, GOLD))
		content.add_child(_label(str(choice.title), 25))
		var description := _label(str(choice.body), 19, MUTED)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(description)
		var effect := _label(str(choice.effect), 18, BLUE)
		content.add_child(effect)
		if index == 0:
			button.call_deferred("grab_focus")
	var footer := _label("1 / 2 / 3 またはクリックで選択  ・  選んでいる間、時間は止まる", 18, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

func _pause_screen() -> void:
	var box := _base_modal(650)
	var heading := _label("庭園は、あなたを待っている。", 30)
	box.add_child(heading)
	var reason: String = run.pause_reason
	box.add_child(_label(reason if not reason.is_empty() else "休止中  ・  残像も敵も、すべて停止しています。", 19, MUTED))
	_add_rule(box)
	var resume := _button("続ける  [Enter / Esc]", true)
	box.add_child(resume)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	var retry := _button("はじめから挑む  [R]")
	box.add_child(retry)
	retry.pressed.connect(func() -> void: retry_requested.emit())
	var title := _button("タイトルへ戻る")
	box.add_child(title)
	title.pressed.connect(func() -> void: title_requested.emit())
	_add_settings(box)
	resume.call_deferred("grab_focus")

func _result_screen() -> void:
	var won: bool = run.state == "victory"
	var box := _base_modal(700)
	box.add_child(_label("夜明けが、庭園をほどく。" if won else "今夜の頁は、ここまで。", 34, GOLD if won else PAPER))
	box.add_child(_label("3分間 生存成功" if won else "魔女のHPがなくなりました", 22, BLUE if won else DANGER))
	_add_rule(box)
	var seconds := int(run.elapsed)
	box.add_child(_label("生存  %02d:%02d    討伐  %d    Lv.%d" % [seconds / 60, seconds % 60, run.kills, run.level], 24))
	box.add_child(_label("あなたの魔法 %d回  ・  残像の魔法 %d回" % [run.player_shots, run.echo_shots], 20, MUTED))
	box.add_child(_label("次は道を変えて、二人の魔法を重ねよう。", 20, MUTED))
	var retry := _button("もう一度挑む  [Enter / R]", true)
	box.add_child(retry)
	retry.pressed.connect(func() -> void: retry_requested.emit())
	var title := _button("タイトルへ戻る")
	box.add_child(title)
	title.pressed.connect(func() -> void: title_requested.emit())
	retry.call_deferred("grab_focus")

func _button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 21)
	if primary:
		button.add_theme_stylebox_override("normal", _box(Color("6d583c"), GOLD, 2, 5))
	return button

func _add_rule(box: VBoxContainer) -> void:
	var line := HSeparator.new()
	var rule := StyleBoxFlat.new()
	rule.bg_color = Color("776e5c")
	line.add_theme_stylebox_override("separator", rule)
	line.add_theme_constant_override("separation", 2)
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

func _add_settings(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var sound := _button("音 ON" if sound_enabled else "音 OFF")
	sound.add_theme_font_size_override("font_size", 18)
	sound.custom_minimum_size.y = 46
	sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sound)
	sound_buttons.append(sound)
	sound.pressed.connect(func() -> void:
		sound_enabled = not sound_enabled
		for item in sound_buttons:
			item.text = "音 ON" if sound_enabled else "音 OFF"
		sound_changed.emit(sound_enabled))
	var motion := _button("演出軽減 ON" if reduced_motion else "演出軽減 OFF")
	motion.add_theme_font_size_override("font_size", 18)
	motion.custom_minimum_size.y = 46
	motion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(motion)
	motion_buttons.append(motion)
	motion.pressed.connect(func() -> void:
		reduced_motion = not reduced_motion
		for item in motion_buttons:
			item.text = "演出軽減 ON" if reduced_motion else "演出軽減 OFF"
		motion_changed.emit(reduced_motion))
