extends Control

signal start_requested
signal pause_requested
signal resume_requested
signal jump_requested
signal steering_changed(direction: int)
signal option_changed(option: String, value: bool)

const NAVY := Color("#162941")
const INK := Color("#12253a")
const CREAM := Color("#fff6df")
const RED := Color("#bb382f")
const GOLD := Color("#ffd26e")
const FACE := preload("res://media/HarborUI.otf")
const PORTRAIT := preload("res://media/title-portrait.jpg")
const WIDE := preload("res://media/cover.jpg")
const MIN_HIT_PIXELS := 44.0

var title := Control.new()
var poster := TextureRect.new()
var title_panel := Panel.new()
var title_stack := VBoxContainer.new()
var race := Control.new()
var rank_panel := Panel.new()
var rank_label := Label.new()
var rank_caption := Label.new()
var halt := Button.new()
var left := Button.new()
var right := Button.new()
var jump := Button.new()
var course_progress := ProgressBar.new()
var count := Label.new()
var marker := Label.new()
var pause_screen := ColorRect.new()
var pause_panel := Panel.new()
var pause_stack := VBoxContainer.new()
var result_panel := Panel.new()
var result_stack := VBoxContainer.new()
var result_rank := Label.new()
var result_time := Label.new()
var result_retry := Button.new()
var go := Button.new()
var resume := Button.new()
var restart := Button.new()
var reduce := CheckButton.new()
var sound := CheckButton.new()
var music := CheckButton.new()
var last_rank := 0
var rank_tween: Tween
var left_held := false
var right_held := false
var mode := "title"
var browser: JavaScriptObject

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web"):
		browser = JavaScriptBridge.get_interface("window")
	var ui_theme := Theme.new()
	ui_theme.default_font = FACE
	ui_theme.default_font_size = 18
	theme = ui_theme
	for layer in [title, race, pause_screen]:
		add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_title()
	_build_race()
	_build_pause()
	_build_result()
	resized.connect(_layout)
	get_window().size_changed.connect(_layout)
	_layout()
	set_mode("title")

func _box(color: Color, edge: Color, radius: int, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 8
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 0)
	return style

func _panel(panel: Panel, parent: Control, color: Color, edge: Color, corner: int) -> void:
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(color, edge, corner))

func _label(label: Label, parent: Control, value: String, font_size: int, color: Color = CREAM) -> void:
	parent.add_child(label)
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

func _button(btn: Button, parent: Control, caption: String, primary: bool = false, font_size: int = 21) -> void:
	parent.add_child(btn)
	btn.text = caption
	btn.custom_minimum_size = Vector2(48, 50)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.accessibility_name = caption
	btn.add_theme_font_size_override("font_size", font_size)
	var fill := RED if primary else CREAM
	var fg := Color.WHITE if primary else INK
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var bg := fill
		if state == "hover":
			bg = fill.lightened(0.09)
		elif "pressed" in state:
			bg = fill.darkened(0.12)
		var style := _box(bg, INK, 14, 3)
		if state == "normal" or state == "hover":
			style.shadow_color = Color("#10243bd0")
			style.shadow_size = 1
			style.shadow_offset = Vector2(0, 3)
		btn.add_theme_stylebox_override(state, style)
		btn.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", fg)
	btn.add_theme_color_override("font_focus_color", fg)
	var outline := _box(Color.TRANSPARENT, GOLD, 14, 3)
	outline.draw_center = false
	outline.set_expand_margin_all(2)
	btn.add_theme_stylebox_override("focus", outline)

func _build_title() -> void:
	var backing := ColorRect.new()
	title.add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.color = NAVY
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(poster)
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(title_panel, title, CREAM, INK, 15)
	title_panel.add_child(title_stack)
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 6)
	var course_name := Label.new()
	_label(course_name, title_stack, "潮風ふ頭", 31, INK)
	var instructions := Label.new()
	_label(instructions, title_stack, "左右にドラッグ　・　タップでジャンプ", 15, INK)
	_button(go, title_stack, "レース開始　▶", true, 22)
	go.pressed.connect(func(): start_requested.emit())

func _build_race() -> void:
	_panel(rank_panel, race, NAVY, CREAM, 17)
	_label(rank_label, rank_panel, "1 / 6", 31)
	_label(rank_caption, rank_panel, "順位", 12, GOLD)
	_button(halt, race, "Ⅱ", false, 23)
	halt.accessibility_name = "ポーズ"
	halt.pressed.connect(func(): pause_requested.emit())
	_button(left, race, "◀", false, 24)
	_button(right, race, "▶", false, 24)
	for btn: Button in [left, right]:
		btn.accessibility_name = "左へ移動" if btn == left else "右へ移動"
		btn.button_down.connect(_hold.bind(btn, true))
		btn.button_up.connect(_hold.bind(btn, false))
	_button(jump, race, "ジャンプ", true, 18)
	jump.button_down.connect(func(): jump_requested.emit())
	race.add_child(course_progress)
	course_progress.show_percentage = false
	course_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	course_progress.add_theme_stylebox_override("background", _box(NAVY, CREAM, 5, 1))
	course_progress.add_theme_stylebox_override("fill", _box(GOLD, CREAM, 5, 1))
	_label(marker, race, "▼", 18, CREAM)
	_outline(marker, 5)
	_label(count, race, "", 66)
	_outline(count, 11)
	count.z_index = 4

func _hold(btn: Button, pressed: bool) -> void:
	if btn == left:
		left_held = pressed
	else:
		right_held = pressed
	steering_changed.emit(int(right_held) - int(left_held))

func _outline(label: Label, pixels: int) -> void:
	label.add_theme_constant_override("outline_size", pixels)
	label.add_theme_color_override("font_outline_color", INK)

func _build_pause() -> void:
	pause_screen.color = Color("#0c1b32aa")
	pause_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(pause_panel, pause_screen, CREAM, NAVY, 16)
	pause_panel.add_child(pause_stack)
	pause_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_stack.add_theme_constant_override("separation", 8)
	_label(Label.new(), pause_stack, "ポーズ", 28, INK)
	for option in [[reduce, "動きを減らす", "motion"], [sound, "効果音", "sound"], [music, "音楽", "music"]]:
		var toggle: CheckButton = option[0]
		pause_stack.add_child(toggle)
		toggle.text = option[1]
		toggle.custom_minimum_size.y = 44
		for color_key in ["font_color","font_focus_color","font_pressed_color","font_hover_color","font_hover_pressed_color"]:
			toggle.add_theme_color_override(color_key, INK)
		toggle.toggled.connect(_on_option.bind(option[2]))
	_button(resume, pause_stack, "再開", true)
	resume.pressed.connect(func(): resume_requested.emit())
	_button(restart, pause_stack, "最初から")
	restart.pressed.connect(func(): start_requested.emit())

func _on_option(value: bool, option: String) -> void:
	option_changed.emit(option, value)

func _build_result() -> void:
	_panel(result_panel, self, CREAM, INK, 16)
	result_panel.add_child(result_stack)
	result_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	result_stack.add_theme_constant_override("separation", 2)
	_label(result_rank, result_stack, "", 32, RED)
	_label(result_time, result_stack, "", 17, INK)
	_button(result_retry, result_stack, "もう一度　▶", true, 21)
	result_retry.pressed.connect(func(): start_requested.emit())

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)

func _layout() -> void:
	if size.x < 1 or size.y < 1:
		return
	var w := size.x
	var h := size.y
	var pixels := Vector2(get_window().size)
	var safe := Vector4.ZERO
	if browser and browser.ribbonRallyViewport:
		var metrics: JavaScriptObject = browser.ribbonRallyViewport()
		if float(metrics.width) > 0.0 and float(metrics.height) > 0.0:
			pixels = Vector2(float(metrics.width), float(metrics.height))
		safe = Vector4(float(metrics.left), float(metrics.top), float(metrics.right), float(metrics.bottom))
	elif OS.get_name() in ["Android", "iOS"]:
		var window_rect := Rect2(Vector2(get_window().position), pixels)
		var inner := window_rect.intersection(Rect2(DisplayServer.get_display_safe_area()))
		if inner.has_area():
			safe = Vector4(
				inner.position.x - window_rect.position.x, inner.position.y - window_rect.position.y,
				window_rect.end.x - inner.end.x, window_rect.end.y - inner.end.y
			)
	var units_per_pixel := maxf(w / maxf(1.0, pixels.x), h / maxf(1.0, pixels.y))
	var min_hit := ceilf(MIN_HIT_PIXELS * units_per_pixel)
	safe *= units_per_pixel
	for button: Button in [go, left, right, halt, jump, resume, restart, result_retry]:
		button.custom_minimum_size = Vector2(maxf(48.0, min_hit), maxf(50.0, min_hit))
	for toggle: CheckButton in [reduce, sound, music]:
		toggle.custom_minimum_size.y = maxf(44.0, min_hit)

	var portrait := w < h * 0.95
	var inset := 20.0
	var left_edge := inset + safe.x
	var top_edge := inset + safe.y
	var right_edge := w - inset - safe.z
	var bottom_edge := h - inset - safe.w
	var width := minf(right_edge - left_edge, 346.0)
	var centered_x := (left_edge + right_edge - width) * 0.5
	var panel_h := maxf(161.0, title_stack.get_combined_minimum_size().y + 10.0)
	if portrait:
		poster.texture = PORTRAIT
		# Keep the entire lettering and foreground face in view on narrow phones.
		var image_h := minf(h - safe.y - safe.w - panel_h + 30.0, w * 1.55)
		_place(poster, safe.x, safe.y, w - safe.x - safe.z, image_h)
		var title_top := minf(bottom_edge-panel_h, (safe.y+image_h+h-safe.w-panel_h)*0.5-8)
		_place(title_panel, centered_x, title_top, width, panel_h)
	else:
		poster.texture = WIDE
		_place(poster, 0, 0, w, h)
		_place(title_panel, right_edge-width-10, bottom_edge-panel_h-10, width, panel_h)
	_place(title_stack, 16, 5, width-32, panel_h-10)
	_place(rank_panel, left_edge, top_edge, 109, 61)
	_place(rank_caption, 0, 3, 109, 19)
	_place(rank_label, 0, 14, 109, 43)
	var halt_w := maxf(52.0, min_hit)
	_place(halt, right_edge-halt_w, top_edge, halt_w, maxf(50.0, min_hit))
	_place(course_progress, left_edge, top_edge+69, 109, 7)
	var arrow_w := maxf(60.0, min_hit)
	var arrow_h := maxf(56.0, min_hit)
	var jump_h := maxf(59.0, min_hit)
	_place(left, left_edge, bottom_edge-6-arrow_h, arrow_w, arrow_h)
	_place(right, left_edge+arrow_w+4, bottom_edge-6-arrow_h, arrow_w, arrow_h)
	_place(jump, right_edge-106, bottom_edge-6-jump_h, 106, jump_h)
	_place(count, 0, h*0.25, w, 105)
	var pause_h := maxf(366.0, pause_stack.get_combined_minimum_size().y + 16.0)
	_place(pause_panel, centered_x, (top_edge+bottom_edge-pause_h)*0.5, width, pause_h)
	_place(pause_stack, 20, 8, width-40, pause_h-16)
	var result_h := maxf(167.0, result_stack.get_combined_minimum_size().y + 9.0)
	_place(result_panel, centered_x, bottom_edge-3-result_h, width, result_h)
	_place(result_stack, 18, 4, width-36, result_h-9)

func set_mode(value: String) -> void:
	mode = value
	title.visible = mode == "title"
	race.visible = mode in ["countdown", "racing"]
	pause_screen.visible = mode == "paused"
	result_panel.visible = mode == "result"
	left.visible = mode == "racing"
	right.visible = mode == "racing"
	jump.visible = mode == "racing"
	marker.visible = mode == "racing"
	count.text = ""
	left_held = false
	right_held = false
	steering_changed.emit(0)
	if mode == "countdown":
		last_rank = 0
	if mode == "paused":
		resume.grab_focus()
	elif mode == "result":
		result_retry.grab_focus()
	elif mode == "title":
		go.grab_focus()
	elif get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()

func update_race(rank: int, progress: float, reduced: bool) -> void:
	course_progress.value = clampf(progress, 0.0, 1.0)*100.0
	if rank == last_rank:
		return
	rank_label.text = "%d / 6" % rank
	if rank_tween:
		rank_tween.kill()
	rank_panel.scale = Vector2.ONE
	if rank < last_rank and not reduced:
		rank_panel.pivot_offset = rank_panel.size * 0.5
		rank_panel.scale = Vector2.ONE * 1.12
		rank_tween = create_tween()
		rank_tween.tween_property(rank_panel, "scale", Vector2.ONE, 0.18)
	last_rank = rank

func set_count(value: String) -> void:
	count.text = value

func set_marker(screen_position: Vector2) -> void:
	marker.size = Vector2(44, 28)
	marker.position = screen_position - Vector2(22, 25)

func show_result(rank: int, seconds: float) -> void:
	set_mode("result")
	result_rank.text = "優勝！" if rank == 1 else "%d位でゴール！" % rank
	result_time.text = "%d位 / 6人　　%.2f 秒" % [rank, seconds]

func set_options(motion: bool, sfx: bool, song: bool) -> void:
	reduce.set_pressed_no_signal(motion)
	sound.set_pressed_no_signal(sfx)
	music.set_pressed_no_signal(song)

func over_race_button(point: Vector2) -> bool:
	for btn: Button in [left, right, halt, jump]:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(point):
			return true
	return false
