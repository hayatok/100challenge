extends Control

const Glyph = preload("res://scripts/spell_glyph.gd")
const Frame = preload("res://scripts/book_frame.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Grimoire = preload("res://scripts/grimoire_theme.gd")

signal start_requested
signal resume_requested
signal retry_requested
signal title_requested
signal pause_requested
signal upgrade_requested(index: int)
signal next_chapter_requested
signal reroll_requested
signal skip_requested
signal cancel_replacement_requested
signal setting_changed(key: String, value: Variant)
signal storage_retry_requested
signal storage_reset_requested

const CHAPTER_SIGILS := ["chapter_garden", "chapter_mirror", "chapter_bell"]
const CATEGORIES := ["weapons", "relics", "enemies", "evolutions"]
const CATEGORY_TITLES := ["魔法", "遺物", "魔物", "進化"]

var run
var profile
var sound_enabled := true
var reduced_motion := false
var large_text := false
var selected_starter := "lightning"
var local_screen := ""
var screen_history: Array[String] = []
var codex_category := "weapons"
var codex_index := 0
var hud: Control
var overlay: Control
var health_label: Label
var health_bar: ProgressBar
var clock_label: Label
var timer_caption: Label
var kill_label: Label
var level_label: Label
var experience_bar: ProgressBar
var experience_label: Label
var phase_label: Label
var phase_detail: Label
var echo_label: Label
var hint: Label
var boss_panel: Control
var boss_frame: Control
var boss_label: Label
var boss_bar: ProgressBar
var equipment_root: Control
var book_theme: Theme
var heading_font: Font
var last_screen := ""
var last_equipment := ""
var _default_focus: Control
var save_notice: Label
var _overlay_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if profile != null:
		var values: Dictionary = profile.settings()
		sound_enabled = bool(values.sound)
		reduced_motion = bool(values.reduced_motion)
		large_text = bool(values.large_text)
	_make_theme()
	theme = book_theme
	_build_hud()
	refresh()

func _make_theme() -> void:
	book_theme = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf"):
		book_theme.default_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	if ResourceLoader.exists("res://assets/fonts/ZenOldMincho-Bold.ttf"):
		heading_font = load("res://assets/fonts/ZenOldMincho-Bold.ttf")
	book_theme.default_font_size = Grimoire.BODY_SIZE
	for type in ["Label", "Button", "CheckButton"]:
		book_theme.set_color("font_color", type, Grimoire.TEXT)
		book_theme.set_color("font_hover_color", type, Grimoire.TEXT)
		book_theme.set_color("font_focus_color", type, Grimoire.TEXT)
	book_theme.set_color("font_pressed_color", "Button", Grimoire.INK)
	book_theme.set_color("font_disabled_color", "Button", Grimoire.MUTED)
	book_theme.set_stylebox("panel", "PanelContainer", _box(Grimoire.COVER, Grimoire.COVER, 0))
	book_theme.set_stylebox("normal", "Button", _box(Grimoire.COVER_LIT, Grimoire.PAPER_EDGE))
	book_theme.set_stylebox("hover", "Button", _box(Grimoire.COVER_LIT, Grimoire.GOLD, 2))
	book_theme.set_stylebox("pressed", "Button", _box(Grimoire.GOLD, Grimoire.GOLD, 2))
	book_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Grimoire.GOLD, Grimoire.FOCUS_WIDTH))
	book_theme.set_stylebox("disabled", "Button", _box(Grimoire.COVER, Grimoire.INK_SOFT))
	book_theme.set_stylebox("slider", "HSlider", _box(Grimoire.PAPER_EDGE, Grimoire.PAPER_EDGE, 0))
	book_theme.set_stylebox("grabber_area", "HSlider", _box(Grimoire.ECHO_INK, Grimoire.ECHO_INK, 0))
	book_theme.set_stylebox("grabber_area_highlight", "HSlider", _box(Grimoire.ECHO_INK, Grimoire.GOLD_INK))

func _box(fill: Color, border: Color, thickness: int = 1, corner: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(value: String, font_size: int = 20, color: Color = Grimoire.TEXT, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size + (2 if large_text and font_size <= 24 else 0))
	label.add_theme_color_override("font_color", color)
	if heading and heading_font != null:
		label.add_theme_font_override("font", heading_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _at(node: Control, x: float, y: float, width: float, height: float) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(width, height)

func _text(parent: Control, value: String, x: float, y: float, width: float, height: float, font_size: int = 20, color: Color = Grimoire.TEXT, heading: bool = false) -> Label:
	var label := _label("", font_size, color, heading)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_at(label, x, y, width, height)
	parent.add_child(label)
	label.text = value
	_at(label, x, y, width, height)
	label.set_meta("layout_bounds", Rect2(x, y, width, height))
	return label

func _paper_context(node: Node) -> bool:
	var current := node
	while current != null and current != self:
		if current.has_meta("paper_surface"):
			return bool(current.get_meta("paper_surface"))
		current = current.get_parent()
	return false

func _glyph(parent: Control, kind: String, x: float, y: float, width: float = 54, height: float = 54, evolved: bool = false) -> Control:
	var glyph := Glyph.new()
	glyph.kind = kind
	glyph.evolved = evolved
	glyph.on_paper = _paper_context(parent)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)
	_at(glyph, x, y, width, height)
	return glyph

func _surface(parent: Control, rect: Rect2, surface: String, divided: bool = false, compact: bool = false) -> Control:
	var frame := Frame.new()
	frame.surface = surface
	frame.divided = divided
	frame.compact = compact
	var empty := StyleBoxEmpty.new()
	frame.add_theme_stylebox_override("panel", empty)
	parent.add_child(frame)
	_at(frame, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	return frame

func _button(parent: Control, value: String, rect: Rect2, action: Callable, primary: bool = false, action_id: String = "", appearance: String = "") -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = maxf(44, rect.size.y)
	button.add_theme_font_size_override("font_size", 22 + (2 if large_text else 0))
	var paper := _paper_context(parent)
	if appearance == "paper":
		paper = true
	button.set_meta("paper_surface", paper)
	if paper:
		button.add_theme_color_override("font_color", Grimoire.INK)
		button.add_theme_color_override("font_hover_color", Grimoire.INK)
		button.add_theme_color_override("font_focus_color", Grimoire.INK)
		button.add_theme_color_override("font_disabled_color", Grimoire.INK_SOFT)
		button.add_theme_stylebox_override("normal", _box(Grimoire.PAPER_LIT, Grimoire.PAPER_EDGE))
		button.add_theme_stylebox_override("hover", _box(Grimoire.PAPER_LIT, Grimoire.GOLD_INK, 2))
		button.add_theme_stylebox_override("disabled", _box(Grimoire.PAPER, Grimoire.PAPER_EDGE))
		button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Grimoire.GOLD_INK, Grimoire.FOCUS_WIDTH))
	if primary:
		button.add_theme_stylebox_override("normal", _box(Grimoire.GOLD, Grimoire.GOLD_INK, 2))
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Grimoire.INK)
		button.add_theme_stylebox_override("hover", _box(Grimoire.PAPER_LIT, Grimoire.GOLD_INK, 2))
	if appearance in ["paper", "bookmark"]:
		button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
		button.add_theme_stylebox_override("hover", _box(Color(Grimoire.GOLD, 0.16), Grimoire.GOLD_INK if paper else Grimoire.GOLD, 2))
		button.add_theme_stylebox_override("pressed", _box(Color(Grimoire.GOLD, 0.28), Grimoire.GOLD_INK if paper else Grimoire.GOLD, 2))
	elif appearance == "line":
		button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	parent.add_child(button)
	_at(button, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	if appearance in ["paper", "bookmark"]:
		var face := _surface(button, Rect2(Vector2.ZERO, rect.size), appearance)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.show_behind_parent = true
		if appearance == "paper":
			var ribbon := _surface(button, Rect2(4, 0, 12, 62), "bookmark")
			ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ribbon.visible = false
			button.focus_entered.connect(func() -> void: ribbon.show())
			button.focus_exited.connect(func() -> void: ribbon.hide())
	button.pressed.connect(action)
	button.set_meta("action_id", action_id)
	button.set_meta("control_id", action_id)
	button.set_meta("focus_key", action_id)
	if _default_focus == null and not button.disabled:
		_default_focus = button
	return button

func _focus(button: Control) -> void:
	_default_focus = button

func _panel(parent: Control, rect: Rect2, divided: bool = false, compact: bool = false, surface: String = "cover") -> Control:
	var frame := _surface(parent, rect, surface, divided, compact)
	frame.set_meta("paper_surface", divided or surface == "paper")
	var content := Control.new()
	frame.add_child(content)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_meta("paper_surface", divided or surface == "paper")
	return content

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _box(Grimoire.COVER_LIT, Grimoire.COVER_LIT, 0)
	background.set_content_margin_all(0)
	var fill := _box(color, color, 0)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _line(parent: Control, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_at(line, rect.position.x, rect.position.y, rect.size.x, rect.size.y)

func _build_hud() -> void:
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
	hud = Control.new()
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp := _panel(hud, Rect2(20, 14, 280, 62), false, true)
	health_label = _text(hp, "HP 100 / 100", 16, 1, 248, 32, 20)
	health_bar = _bar(Grimoire.ROSE)
	hp.add_child(health_bar)
	_at(health_bar, 16, 40, 248, 10)
	var clock := _panel(hud, Rect2(428, 4, 424, 80), false, true)
	phase_label = _text(clock, "第一章", 18, 4, 260, 36, 22, Grimoire.GOLD, true)
	phase_detail = _text(clock, "", 18, 42, 260, 32, 18, Grimoire.MUTED)
	clock_label = _text(clock, "03:00", 280, 0, 128, 48, 32)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_caption = _text(clock, "章の主まで", 280, 48, 128, 32, 18, Grimoire.MUTED)
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var record := _panel(hud, Rect2(944, 10, 192, 68), false, true)
	kill_label = _text(record, "討伐 0", 12, 0, 168, 36, 22)
	level_label = _text(record, "魔女 Lv.1", 12, 38, 168, 30, 18, Grimoire.MUTED)
	_button(hud, "休止", Rect2(1146, 18, 114, 54), func() -> void: pause_requested.emit(), false, "hud_pause").tooltip_text = "休止 [Esc]"
	_default_focus = null
	boss_panel = _panel(hud, Rect2(340, 88, 600, 48), false, true)
	boss_frame = boss_panel.get_parent()
	boss_label = _text(boss_panel, "", 16, 0, 568, 30, 20, Grimoire.DANGER)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(Grimoire.DANGER)
	boss_panel.add_child(boss_bar)
	_at(boss_bar, 16, 34, 568, 7)
	hint = _text(hud, "", 140, 88, 1000, 38, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", Grimoire.NIGHT)
	hint.add_theme_constant_override("outline_size", 5)
	var foot := _panel(hud, Rect2(20, 638, 1240, 66), false, true)
	experience_bar = _bar(Grimoire.GOLD)
	foot.add_child(experience_bar)
	_at(experience_bar, 14, 0, 1212, 4)
	equipment_root = Control.new()
	foot.add_child(equipment_root)
	_at(equipment_root, 14, 11, 920, 52)
	experience_label = _text(foot, "", 922, 7, 302, 28, 18, Grimoire.MUTED)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	echo_label = _text(foot, "挟撃 0回", 922, 35, 302, 28, 18, Grimoire.ECHO)
	echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	last_equipment = ""

func refresh() -> void:
	if run == null:
		return
	if str(run.state) == "playing" and not local_screen.is_empty():
		local_screen = ""
		screen_history.clear()
	var choice_key := JSON.stringify(run.choices) if str(run.state) in ["upgrade", "treasure"] else ""
	var storage_key := str(profile.status) + str(profile.message) if profile != null and local_screen != "settings" else ""
	var key := "%s:%d:%d:%s:%s:%s:%s:%d" % [run.state, run.level, run.chapter, local_screen, choice_key, storage_key, codex_category, codex_index]
	if key != last_screen:
		last_screen = key
		_rebuild_overlay()
	if is_instance_valid(save_notice) and profile != null:
		save_notice.text = str(profile.message)
		save_notice.add_theme_color_override("font_color", Grimoire.DANGER_INK if profile.status in ["invalid", "blocked", "error"] else Grimoire.INK_SOFT)
	hud.visible = str(run.state) == "playing"
	health_label.text = "HP %d / %d" % [ceili(run.health), int(run.maximum_health)]
	health_bar.max_value = run.maximum_health
	health_bar.value = run.health
	health_label.add_theme_color_override("font_color", Grimoire.DANGER if run.health <= run.maximum_health * 0.3 else Grimoire.TEXT)
	var chapter: Dictionary = run.chapter_info()
	var remaining := maxi(0, ceili(float(chapter.get("duration", 180)) - run.chapter_elapsed))
	clock_label.text = "%02d:%02d" % [remaining / 60, remaining % 60] if run.chapter_stage != "boss" else "BOSS"
	timer_caption.text = "章の主まで" if run.chapter_stage != "boss" else "章の主"
	kill_label.text = "討伐 %d" % run.kills
	level_label.text = "魔女 Lv.%d" % run.level
	experience_bar.max_value = run.experience_needed
	experience_bar.value = run.experience
	experience_label.text = "経験値 %d / %d" % [run.experience, run.experience_needed]
	var phase: Dictionary = run.phase_info()
	phase_label.text = "第%d章  %s" % [run.chapter + 1, chapter.get("name", "")]
	phase_detail.text = "決戦" if run.chapter_stage == "boss" else str(phase.get("name", ""))
	var boss: Dictionary = run.boss_data()
	boss_frame.visible = not boss.is_empty()
	if not boss.is_empty():
		boss_label.text = "%s   第%d形態" % [boss.get("name", "章の主"), int(boss.get("phase", 1))]
		boss_bar.max_value = float(boss.get("max_hp", 1))
		boss_bar.value = float(boss.get("hp", 0))
	echo_label.text = ("%s  /  " % run.specialization if str(run.specialization) != "未選択" else "") + "挟撃 %d回" % run.resonance_hits
	if run.chapter_elapsed < 7.0:
		hint.text = "WASD / 矢印で移動。魔法は自動。残像は2秒後に同じ道をたどる。"
	elif run.chapter_elapsed < 14.0:
		hint.text = "残像と離れて同じ敵を攻撃すると、挟撃で追加ダメージ。"
	else:
		hint.text = ""
	var equipment: Dictionary = run.equipment_info()
	var equipment_key := JSON.stringify(equipment)
	if equipment_key != last_equipment:
		last_equipment = equipment_key
		_update_equipment(equipment)

func _update_equipment(equipment: Dictionary) -> void:
	for child in equipment_root.get_children():
		equipment_root.remove_child(child)
		child.queue_free()
	var weapons: Array = equipment.get("weapons", [])
	for index in range(3):
		var x := index * 232
		if index < weapons.size():
			var item: Dictionary = weapons[index]
			var evolved := bool(item.get("evolved", false))
			_glyph(equipment_root, str(item.icon), x, 0, 48, 48, evolved)
			_text(equipment_root, str(item.get("evolution_name", item.title)) if evolved else str(item.title), x + 56, -2, 168, 30, 18, Grimoire.GOLD if evolved else Grimoire.TEXT)
			for rank in range(int(item.get("max_level", 5))):
				_line(equipment_root, Rect2(x + 56 + rank * 22, 35, 17, 5), Grimoire.GOLD if rank < int(item.level) else Grimoire.COVER_LIT)
		else:
			_line(equipment_root, Rect2(x + 16, 24, 24, 1), Color(Grimoire.MUTED, 0.28))
	var relics: Array = equipment.get("relics", [])
	for index in range(relics.size()):
		var x := 720 + index * 58
		var glyph := _glyph(equipment_root, str(relics[index].icon), x, 1, 46, 46)
		glyph.mouse_filter = Control.MOUSE_FILTER_PASS
		glyph.tooltip_text = "%s\n%s" % [relics[index].title, relics[index].body]

func _rebuild_overlay() -> void:
	var focus_key := ""
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and is_instance_valid(overlay) and overlay.is_ancestor_of(focused):
		focus_key = str(focused.get_meta("focus_key", ""))
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	_default_focus = null
	save_notice = null
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not local_screen.is_empty():
		match local_screen:
			"settings": _settings_screen()
			"codex": _codex_screen()
			"starters": _starter_screen()
			"storage": _storage_screen()
			"loadout": _loadout_screen()
	else:
		match str(run.state):
			"title": _title_screen()
			"upgrade", "treasure": _upgrade_screen()
			"paused": _pause_screen()
			"chapter_clear": _chapter_screen()
			"victory", "defeat": _result_screen()
	if not reduced_motion and local_screen.is_empty() and str(run.state) in ["upgrade", "treasure", "chapter_clear", "victory"]:
		# Rectangles and input are final from the first frame; only ink fades in.
		overlay.modulate.a = 0.84
		_overlay_tween = create_tween()
		_overlay_tween.tween_property(overlay, "modulate:a", 1.0, Grimoire.REVEAL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not focus_key.is_empty():
		for control in overlay.find_children("*", "Control", true, false):
			if str(control.get_meta("focus_key", "")) == focus_key and control.focus_mode != Control.FOCUS_NONE:
				_default_focus = control
				break
	if is_instance_valid(_default_focus):
		call_deferred("_grab_default_focus")

func _grab_default_focus() -> void:
	if is_instance_valid(_default_focus) and _default_focus.is_inside_tree() and _default_focus.is_visible_in_tree():
		_default_focus.grab_focus()

func open_screen(screen: String) -> void:
	screen_history.append(local_screen)
	local_screen = screen
	last_screen = ""
	refresh()

func close_screen() -> void:
	local_screen = screen_history.pop_back() if not screen_history.is_empty() else ""
	last_screen = ""
	refresh()

func handle_shortcut(code: Key) -> bool:
	if not local_screen.is_empty():
		if code == KEY_ESCAPE:
			close_screen()
			return true
		return false
	if str(run.state) in ["upgrade", "treasure"]:
		if code in [KEY_1, KEY_2, KEY_3]:
			upgrade_requested.emit(int(code) - int(KEY_1))
			return true
		if code == KEY_R:
			if _can_reroll():
				reroll_requested.emit()
			return true
		if code == KEY_X:
			skip_requested.emit()
			return true
		if code == KEY_ESCAPE and str(run.choice_phase) == "replace":
			cancel_replacement_requested.emit()
			return true
	if code == KEY_C and str(run.state) in ["title", "paused"]:
		open_screen("codex")
		return true
	return false

func control_snapshot() -> Array:
	var controls: Array = []
	for node in find_children("*", "Control", true, false):
		if not node.is_visible_in_tree() or node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not (node is BaseButton or node is Slider):
			continue
		var id := str(node.get_meta("control_id", ""))
		if id.is_empty():
			continue
		var rect: Rect2 = node.get_global_rect()
		var disabled: bool = node.disabled if node is BaseButton else not node.editable
		controls.append({"id": id, "label": _control_label(node), "x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "disabled": disabled})
	return controls

func _control_label(node: Control) -> String:
	if node.has_meta("action_label"):
		return str(node.get_meta("action_label"))
	if node is Button and not node.text.is_empty():
		return node.text
	var parts: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not str(label.text).is_empty():
			parts.append(str(label.text))
	return " / ".join(parts)

func _shade() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Grimoire.NIGHT, 0.87)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP

func _modal(title: String, subtitle: String, divided: bool = false) -> Control:
	_shade()
	var choices_open: bool = local_screen.is_empty() and str(run.state) in ["upgrade", "treasure"]
	var page := _panel(overlay, Rect2(40, 12, 1200, 696) if choices_open else Rect2(40, 24, 1200, 672), divided)
	var color := Grimoire.GOLD_INK if divided else Grimoire.GOLD
	_text(page, title, 40 if divided else 32, 22, 516 if divided else 1136, 54, Grimoire.HEADING_SIZE, color, true)
	_text(page, subtitle, 40 if divided else 32, 80, 516 if divided else 1136, 76 if divided else 40, 20, Grimoire.INK_SOFT if divided else Grimoire.MUTED)
	return page

func _title_screen() -> void:
	_text(overlay, "ECHO WITCH", 66, 62, 496, 30, 18, Grimoire.GOLD)
	_text(overlay, "残響の魔女", 58, 106, 520, 108, Grimoire.TITLE_SIZE, Grimoire.TEXT, true)
	_text(overlay, "2秒前の自分と、夜をほどく。", 66, 216, 516, 46, 26, Grimoire.GOLD, true)
	_text(overlay, "三つの章を巡り、庭園に夜明けを。\n魔法は自動。二人の通り道を描こう。", 66, 278, 504, 76, 22)
	var start := _button(overlay, "", Rect2(66, 370, 496, 64), func() -> void: start_requested.emit(), true, "title_start", "bookmark")
	_text(start, "物語をはじめる", 32, 8, 330, 38, 26, Grimoire.INK, true)
	_text(start, "Enter", 380, 14, 92, 30, 18, Grimoire.GOLD_INK)
	_focus(start)
	var starter: Dictionary = Spellbook.weapon_info(selected_starter)
	var choose := _button(overlay, "", Rect2(66, 450, 496, 70), func() -> void: open_screen("starters"), false, "title_starters", "line")
	_glyph(choose, str(starter.get("icon", selected_starter)), 4, 10, 48, 48)
	_text(choose, "初めの魔法", 68, 0, 276, 30, 18, Grimoire.MUTED)
	_text(choose, str(starter.get("title", "雷")), 68, 30, 276, 36, 22, Grimoire.GOLD)
	_text(choose, "変更  ›", 380, 18, 96, 36, 20)
	_button(overlay, "魔術図鑑  [C]", Rect2(66, 532, 240, 50), func() -> void: open_screen("codex"), false, "title_codex", "line")
	_button(overlay, "設定", Rect2(322, 532, 160, 50), func() -> void: open_screen("settings"), false, "title_settings", "line")
	for index in range(3):
		var completed: bool = profile != null and profile.data.clears.has(index)
		var x := 66 + index * 146
		var sigil := _glyph(overlay, CHAPTER_SIGILS[index], x, 598, 44, 44)
		sigil.modulate.a = 1.0 if completed else 0.5
		_text(overlay, "第%d章" % (index + 1), x + 50, 598, 88, 28, 18, Grimoire.GOLD if completed else Grimoire.MUTED)
		_text(overlay, "踏破" if completed else "未踏", x + 50, 624, 88, 30, 18, Grimoire.ECHO if completed else Grimoire.MUTED)
	_storage_note(overlay, 66, 662, 900)

func _storage_note(parent: Control, x: float, y: float, width: float) -> void:
	if profile == null:
		return
	var paper := _paper_context(parent)
	var failing: bool = profile.status in ["invalid", "blocked", "error"]
	if failing:
		var button := _button(parent, "保存できません：記録を確認", Rect2(x, y, minf(width, 520), 44), func() -> void: open_screen("storage"), false, "storage_warning", "line")
		button.add_theme_font_size_override("font_size", 18 + (2 if large_text else 0))
		button.add_theme_color_override("font_color", Grimoire.DANGER_INK if paper else Grimoire.DANGER)
	else:
		_text(parent, "記録と設定はこの端末に保存。外部への送信はありません。", x, y, width, 62 if width < 600 else 30, 18, Grimoire.INK_SOFT if paper else Grimoire.MUTED)

func _starter_screen() -> void:
	var page := _modal("最初の一節を選ぶ", "初めの魔法だけが変わります。能力の恒久強化はありません。")
	for index in range(Spellbook.WEAPON_IDS.size()):
		var id: String = Spellbook.WEAPON_IDS[index]
		var info: Dictionary = Spellbook.weapon_info(id)
		var available: bool = profile == null or profile.has_starter(id)
		var rect := Rect2(24 + (index % 3) * 392, 136 + (index / 3) * 224, 368, 220)
		var button := _button(page, "", rect, func() -> void:
			selected_starter = id
			close_screen(), false, "starter_" + id, "paper")
		button.disabled = not available
		if available:
			_glyph(button, str(info.icon), 24, 12, 80, 80)
			_text(button, str(info.title), 120, 20, 224, 42, 26, Grimoire.INK, true)
			_text(button, "選択中" if selected_starter == id else "", 120, 64, 224, 30, 18, Grimoire.ECHO_INK)
			_text(button, str(info.body), 24, 108, 320, 108, 20, Grimoire.INK_SOFT)
		else:
			_glyph(button, "locked", 24, 12, 80, 80)
			_text(button, "未解放の魔法", 120, 20, 224, 42, 24, Grimoire.INK_SOFT, true)
			var unlock := "第1章を踏破すると解放" if id in ["thorn", "wisp"] else ("第2章を踏破すると解放" if id == "frost" else "第3章を踏破すると解放")
			_text(button, unlock, 24, 116, 320, 68, 20, Grimoire.INK_SOFT)
	_focus(_button(page, "戻る  [Esc]", Rect2(24, 596, 280, 56), close_screen, false, "back"))

func _specialization_offer() -> bool:
	return not run.choices.is_empty() and bool(run.choices[0].get("specialization", false))

func _can_reroll() -> bool:
	return str(run.state) in ["upgrade", "treasure"] and str(run.choice_phase) == "offer" and int(run.rerolls_left) > 0 and not _specialization_offer()

func _upgrade_screen() -> void:
	var replacing: bool = str(run.choice_phase) == "replace"
	var treasure: bool = str(run.state) == "treasure"
	var title := "入れ替える頁を選ぶ" if replacing else ("宝箱から、新たな一節" if treasure else "魔術書に、新しい一節")
	var subtitle := "枠がいっぱいです。選んだ装備の強化を失い、新しい装備を受け取ります。" if replacing else "三つからひとつ選ぶ。選択中は、戦闘も残像も止まります。"
	var page := _modal(title, subtitle)
	var equipment: Dictionary = run.equipment_info()
	_text(page, "魔法 %d / 3枠   遺物 %d / 3枠   Lv.%d   今章はRank%dまで" % [equipment.weapons.size(), equipment.relics.size(), run.level, int(equipment.get("rank_cap", 5))], 32, 112, 1136, 28, 18, Grimoire.ECHO)
	for index in range(run.choices.size()):
		var choice: Dictionary = run.choices[index]
		var kind := str(choice.get("kind", ""))
		var button := _button(page, "", Rect2(24 + index * 392, 146, 368, 480), func() -> void: upgrade_requested.emit(index), false, "choice_" + str(index), "paper")
		_text(button, "%02d  /  %s" % [index + 1, str(choice.get("tag", ""))], 24, 6, 320, 30, 18, Grimoire.GOLD_INK)
		var icon := str(choice.get("replace_id", choice.get("icon", "power"))) if replacing else str(choice.get("icon", "power"))
		_glyph(button, icon, 24, 42, 88, 88, kind == "evolution")
		_text(button, str(choice.get("title", "")), 128, 44, 216, 84, 26, Grimoire.INK, true)
		var before := str(choice.get("before", ""))
		var after := str(choice.get("after", ""))
		if replacing:
			_text(button, "手放す装備", 24, 138, 320, 28, 18, Grimoire.DANGER_INK)
			_text(button, before, 24, 166, 320, 108, 18, Grimoire.INK_SOFT)
			_text(button, "受け取る装備", 24, 280, 320, 28, 18, Grimoire.ECHO_INK)
			_text(button, after, 24, 308, 320, 124, 18, Grimoire.ECHO_INK)
		elif kind == "relic":
			_text(button, str(choice.get("body", "")), 24, 140, 320, 154, 20, Grimoire.INK)
			var used: int = equipment.relics.size()
			_text(button, "遺物 %d / 3枠 → %d / 3枠" % [used, mini(3, used + 1)], 24, 312, 320, 42, 20, Grimoire.ECHO_INK)
			_text(button, "選択後、遺物を入れ替えます。" if choice.get("full_slots", false) else "遺物の枠をひとつ使います。", 24, 374, 320, 58, 18, Grimoire.INK_SOFT)
		elif kind == "specialization":
			_text(button, str(choice.get("body", "")), 24, 140, 320, 130, 20, Grimoire.INK)
			_line(button, Rect2(24, 284, 320, 1), Grimoire.PAPER_EDGE)
			_text(button, str(choice.get("effect", "")), 24, 308, 320, 108, 22, Grimoire.ECHO_INK)
		else:
			_text(button, str(choice.get("body", "")), 24, 140, 320, 108, 20, Grimoire.INK)
			if not before.is_empty() and not after.is_empty():
				_text(button, "現在  " + before, 24, 252, 320, 64, 18, Grimoire.INK_SOFT)
				_text(button, "取得後  " + after, 24, 320, 320, 64, 18, Grimoire.ECHO_INK)
			else:
				_text(button, str(choice.get("effect", "")), 24, 250, 320, 102, 22, Grimoire.ECHO_INK)
			var requirement := str(choice.get("requirement", ""))
			if bool(choice.get("full_slots", false)):
				requirement += "\n選択後、魔法を入れ替えます。"
			_text(button, requirement, 24, 390, 320, 88, 18, Grimoire.GOLD_INK if kind == "evolution" else Grimoire.INK_SOFT)
		if index == 0:
			_focus(button)
	if replacing:
		_button(page, "選択へ戻る  [Esc]", Rect2(24, 632, 368, 56), func() -> void: cancel_replacement_requested.emit(), false, "cancel_replace")
	else:
		var reroll := _button(page, "専門化は引き直せません" if _specialization_offer() else "引き直す %d回  [R]" % run.rerolls_left, Rect2(24, 632, 368, 56), func() -> void: reroll_requested.emit(), false, "reroll")
		reroll.name = "RerollButton"
		reroll.disabled = not _can_reroll()
		reroll.tooltip_text = "専門化は三つの固定された道から選びます。" if _specialization_offer() else "表示された三つを新しい候補に引き直します。"
		var skip := _button(page, "見送る %d回  [X]" % run.skips_left, Rect2(416, 632, 368, 56), func() -> void: skip_requested.emit(), false, "skip")
		skip.disabled = int(run.skips_left) <= 0
	_text(page, "数字1〜3 / 矢印とEnter\nクリックでも選べます", 808, 630, 368, 64, 18, Grimoire.MUTED)

func _loadout(parent: Control, x: float, y: float, width: float) -> void:
	var equipment: Dictionary = run.equipment_info()
	_text(parent, "今夜の魔術書", x, y, width, 44, 28, Grimoire.GOLD_INK, true)
	for index in range(3):
		var row_y := y + 54 + index * 88
		if index < equipment.weapons.size():
			var item: Dictionary = equipment.weapons[index]
			var evolved := bool(item.get("evolved", false))
			_glyph(parent, str(item.icon), x, row_y, 54, 54, evolved)
			_text(parent, str(item.get("evolution_name", item.title)) + "  進化済み" if evolved else "%s  Rank %d / %d" % [item.title, item.level, item.max_level], x + 66, row_y, width - 66, 32, 20, Grimoire.INK)
			var required := str(item.get("requirement_title", ""))
			_text(parent, "進化：%s" % item.get("evolution", "") if evolved else "第3章の宝箱：Rank 5 ＋ %s" % required, x + 66, row_y + 34, width - 66, 52, 18, Grimoire.GOLD_INK if evolved else Grimoire.INK_SOFT)
		else:
			_glyph(parent, "empty", x, row_y, 54, 54)
			_text(parent, "魔法の空き枠", x + 66, row_y + 8, width - 66, 34, 20, Grimoire.INK_SOFT)
	_text(parent, "遺物 %d / 3" % equipment.relics.size(), x, y + 324, width, 36, 22, Grimoire.GOLD_INK, true)
	for index in range(equipment.relics.size()):
		var item: Dictionary = equipment.relics[index]
		var row_y := y + 368 + index * 76
		_glyph(parent, str(item.icon), x, row_y, 42, 42)
		_text(parent, "%s  %s" % [item.title, item.body], x + 52, row_y, width - 52, 74, 18, Grimoire.INK_SOFT)

func _pause_screen() -> void:
	var page := _modal("栞をはさんで、ひと休み", "戦闘・予告・残像の履歴は、すべて止まっています。", true)
	var reason := str(run.pause_reason)
	_text(page, reason if not reason.is_empty() else "第%d章  %s" % [run.chapter + 1, _chapter_name(int(run.chapter))], 40, 158, 516, 64, 20, Grimoire.INK_SOFT)
	_focus(_button(page, "続ける  [Enter / Esc]", Rect2(40, 240, 516, 64), func() -> void: resume_requested.emit(), true, "pause_resume"))
	_button(page, "設定", Rect2(40, 326, 250, 56), func() -> void: open_screen("settings"), false, "pause_settings")
	_button(page, "魔術図鑑  [C]", Rect2(306, 326, 250, 56), func() -> void: open_screen("codex"), false, "pause_codex")
	_button(page, "最初から挑む  [R]", Rect2(40, 406, 516, 56), func() -> void: retry_requested.emit(), false, "pause_retry")
	_button(page, "タイトルへ戻る", Rect2(40, 486, 516, 56), func() -> void: title_requested.emit(), false, "pause_title")
	_storage_note(page, 40, 586, 516)
	_loadout(page, 644, 40, 508)

func _route(parent: Control, rect: Rect2, progress: int) -> void:
	var route := _surface(parent, rect, "route")
	route.route_progress = progress
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _chapter_screen() -> void:
	_shade()
	var page := _panel(overlay, Rect2(40, 24, 1200, 672))
	_text(page, "第%d章、踏破" % (run.chapter + 1), 40, 24, 1120, 70, Grimoire.MILESTONE_SIZE, Grimoire.GOLD, true)
	_text(page, "魔術書と遺物を引き継いで、次の章へ進みます。", 40, 108, 1120, 36, 22, Grimoire.MUTED)
	_route(page, Rect2(220, 240, 760, 8), int(run.chapter))
	for index in range(3):
		var center := 220 + index * 380
		var completed: bool = index <= int(run.chapter)
		var next: bool = index == int(run.chapter) + 1
		var diameter := 144 if next else (120 if completed else 96)
		_glyph(page, CHAPTER_SIGILS[index], center - diameter * 0.5, 170 + (144 - diameter) * 0.5, diameter, diameter)
		var chapter := _text(page, "第%d章" % (index + 1), center - 170, 332, 340, 36, 20, Grimoire.MUTED)
		chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var name_label := _text(page, _chapter_name(index), center - 170, 372, 340, 44, 28, Grimoire.GOLD if completed else Grimoire.TEXT, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var status_label := _text(page, "踏破" if completed else ("次の目的地" if next else "その先へ"), center - 170, 424, 340, 34, 22, Grimoire.ECHO if completed else Grimoire.MUTED)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reward := "HPを回復。魔法と遺物はそのまま。"
	if profile != null and not profile.last_unlocks.is_empty():
		reward += "\n初めの魔法に %s を解放。" % _unlock_names()
	var reward_page := _panel(page, Rect2(40, 478, 1120, 94), false, false, "paper")
	_text(reward_page, reward, 24, 12, 1072, 78, 22, Grimoire.ECHO_INK)
	_focus(_button(page, "第%d章へ進む  [Enter]" % (run.chapter + 2), Rect2(40, 594, 720, 58), func() -> void: next_chapter_requested.emit(), true, "chapter_next"))
	_button(page, "タイトルへ戻る", Rect2(784, 594, 376, 58), func() -> void: title_requested.emit(), false, "chapter_title")

func _unlock_names() -> String:
	var names: Array[String] = []
	if profile != null:
		for id in profile.last_unlocks:
			names.append(str(Spellbook.weapon_info(id).get("title", id)))
	return "・".join(names)

func _result_screen() -> void:
	var won: bool = str(run.state) == "victory"
	_shade()
	var page := _panel(overlay, Rect2(40, 24, 1200, 672), not won, false, "cover" if won else "cold_book")
	var snap: Dictionary = run.snapshot()
	var seconds := int(run.elapsed)
	if won:
		_text(page, "THREE CHAPTERS  /  COMPLETE", 40, 22, 1120, 32, 18, Grimoire.MUTED)
		_glyph(page, "dawn", 54, 78, 192, 192)
		_text(page, "夜明けの頁を、あなたへ", 288, 72, 864, 74, Grimoire.MILESTONE_SIZE, Grimoire.GOLD, true)
		_text(page, "三つの章を踏破しました。  魔女 Lv.%d" % run.level, 292, 158, 860, 38, 22)
		_record(page, "生存", "%02d:%02d" % [seconds / 60, seconds % 60], 292, 218, 248)
		_record(page, "討伐", str(run.kills), 580, 218, 248)
		_record(page, "挟撃", "%d回" % run.resonance_hits, 868, 218, 248)
		for index in range(3):
			_glyph(page, CHAPTER_SIGILS[index], 48 + index * 96, 336, 80, 80)
		_text(page, "三章 踏破", 52, 424, 272, 34, 22, Grimoire.GOLD, true)
		_damage_records(page, snap, 376, 328, 776, false)
		var rewards := "発見した図鑑と踏破記録を保存します。"
		if profile != null and not profile.last_unlocks.is_empty():
			rewards = "初めの魔法に %s を解放。" % _unlock_names()
		var reward_page := _panel(page, Rect2(376, 472, 776, 72), false, false, "paper")
		_text(reward_page, rewards, 22, 10, 732, 60, 20, Grimoire.ECHO_INK)
		_focus(_button(page, "もう一度挑む  [Enter / R]", Rect2(40, 556, 464, 60), func() -> void: retry_requested.emit(), true, "result_retry"))
		_button(page, "今夜の装備", Rect2(528, 556, 292, 60), func() -> void: open_screen("loadout"), false, "result_loadout")
		_button(page, "タイトルへ戻る", Rect2(844, 556, 308, 60), func() -> void: title_requested.emit(), false, "result_title")
		_storage_note(page, 40, 624, 1112)
	else:
		_text(page, "今夜の頁は、ここまで", 40, 30, 516, 112, 42, Grimoire.INK, true)
		var cause := str(snap.get("last_damage_cause", ""))
		var cause_text := "魔女のHPがなくなりました。"
		if cause in Spellbook.ENEMY_IDS:
			cause_text = "最後の被弾：%s" % Spellbook.enemy_info(cause).title
		_text(page, cause_text, 40, 158, 516, 76, 26, Grimoire.DANGER_INK, true)
		_focus(_button(page, "もう一度挑む  [Enter / R]", Rect2(40, 270, 516, 64), func() -> void: retry_requested.emit(), true, "result_retry"))
		_button(page, "今夜の装備", Rect2(40, 358, 516, 56), func() -> void: open_screen("loadout"), false, "result_loadout")
		_button(page, "タイトルへ戻る", Rect2(40, 438, 516, 56), func() -> void: title_requested.emit(), false, "result_title")
		_text(page, "初めの魔法を変えて、もう一度。", 40, 526, 516, 40, 20, Grimoire.INK_SOFT)
		_storage_note(page, 40, 594, 516)
		_text(page, "今夜の記録", 644, 38, 508, 48, 30, Grimoire.GOLD_INK, true)
		_text(page, "生存 %02d:%02d   討伐 %d   Lv.%d" % [seconds / 60, seconds % 60, run.kills, run.level], 644, 120, 508, 80, 24, Grimoire.INK)
		_text(page, "章の踏破 %d / 3\n挟撃 %d回" % [snap.get("chapter_clears", []).size(), run.resonance_hits], 644, 208, 508, 80, 22, Grimoire.ECHO_INK)
		_damage_records(page, snap, 644, 314, 508, true)
		var reward := "発見した図鑑と踏破記録を保存します。"
		if profile != null and not profile.last_unlocks.is_empty():
			reward = "初めの魔法に %s を解放。" % _unlock_names()
		_text(page, reward, 644, 542, 508, 96, 20, Grimoire.ECHO_INK)

func _record(parent: Control, title: String, value: String, x: float, y: float, width: float) -> void:
	_text(parent, title, x, y, width, 30, 18, Grimoire.MUTED)
	_text(parent, value, x, y + 34, width, 54, 36, Grimoire.TEXT, true)

func _damage_records(parent: Control, snap: Dictionary, x: float, y: float, width: float, paper: bool) -> void:
	var ink := Grimoire.INK if paper else Grimoire.TEXT
	var muted := Grimoire.INK_SOFT if paper else Grimoire.MUTED
	var damage: Dictionary = snap.get("damage_summary", {})
	_text(parent, "与えたダメージ", x, y, width, 32, 20, ink, true)
	var values: Array[String] = []
	for pair in [["player", "本体"], ["echo", "残像"], ["resonance", "挟撃"], ["poison", "毒"]]:
		values.append("%s %s" % [pair[1], _compact(float(damage.get(pair[0], 0)))])
	_text(parent, "  /  ".join(values), x, y + 38, width, 68 if paper else 36, 18, muted)
	var received: Dictionary = snap.get("damage_received", {})
	var cause_names := {"contact": "接触", "projectile": "飛び道具", "hazard": "地形魔法"}
	var causes: Array[String] = []
	for id in cause_names:
		if float(received.get(id, 0)) > 0:
			causes.append("%s %d" % [cause_names[id], roundi(float(received[id]))])
	_text(parent, "受けたダメージ %d" % roundi(float(snap.get("damage_taken", 0))) + ("\n" + " / ".join(causes) if not causes.is_empty() else ""), x, y + (110 if paper else 76), width, 100 if paper else 68, 18, muted)

func _loadout_screen() -> void:
	var page := _modal("今夜の魔術書", "戦いを終えたときの魔法と遺物です。戻ると、この結果を確認できます。", true)
	var equipment: Dictionary = run.equipment_info()
	_text(page, "魔法 %d / 3枠" % equipment.weapons.size(), 40, 168, 516, 38, 26, Grimoire.GOLD_INK, true)
	_text(page, "遺物 %d / 3枠" % equipment.relics.size(), 644, 40, 508, 42, 30, Grimoire.GOLD_INK, true)
	for index in range(3):
		var y := 222 + index * 116
		if index < equipment.weapons.size():
			var weapon: Dictionary = equipment.weapons[index]
			var evolved := bool(weapon.get("evolved", false))
			_glyph(page, str(weapon.icon), 40, y, 64, 64, evolved)
			var title := str(weapon.get("evolution_name", weapon.title)) + "  進化済み" if evolved else "%s  Rank %d / %d" % [weapon.title, weapon.level, weapon.max_level]
			_text(page, title, 120, y, 436, 38, 22, Grimoire.GOLD_INK if evolved else Grimoire.INK)
			_text(page, str(weapon.get("stats", "")), 120, y + 42, 436, 72, 18, Grimoire.INK_SOFT)
		else:
			_glyph(page, "empty", 40, y, 64, 64)
			_text(page, "魔法の空き枠", 120, y + 12, 436, 38, 20, Grimoire.INK_SOFT)
		if index < equipment.relics.size():
			var relic: Dictionary = equipment.relics[index]
			var relic_y := 120 + index * 144
			_glyph(page, str(relic.icon), 644, relic_y, 64, 64)
			_text(page, str(relic.title), 724, relic_y, 428, 38, 22, Grimoire.INK)
			_text(page, str(relic.body), 724, relic_y + 42, 428, 100, 20, Grimoire.INK_SOFT)
		else:
			var relic_y := 120 + index * 144
			_glyph(page, "empty", 644, relic_y, 64, 64)
			_text(page, "遺物の空き枠", 724, relic_y + 12, 428, 38, 20, Grimoire.INK_SOFT)
	_focus(_button(page, "結果へ戻る  [Esc]", Rect2(40, 592, 516, 60), close_screen, false, "back"))

func _chapter_name(index: int) -> String:
	return str(Campaign.chapter(index).name)

func _compact(value: float) -> String:
	return "%.1f万" % (value / 10000.0) if value >= 10000 else str(roundi(value))

func _settings_screen() -> void:
	var page := _modal("設定", "変更はすぐ反映され、この端末に保存します。", true)
	_text(page, "見え方と操作", 644, 40, 508, 48, 30, Grimoire.GOLD_INK, true)
	_setting_toggle(page, "sound", "音を鳴らす", 40, 166, sound_enabled)
	_setting_toggle(page, "reduced_motion", "動きを減らす", 644, 150, reduced_motion)
	_setting_toggle(page, "large_text", "文字を大きく", 644, 240, large_text)
	_text(page, "装飾の揺れを抑えます。\n敵の攻撃予告は表示します。", 644, 330, 508, 80, 20, Grimoire.INK_SOFT)
	var settings: Dictionary = profile.settings() if profile != null else {"music_volume": 0.65, "sfx_volume": 0.8}
	_volume_setting(page, "music_volume", "音楽", 40, 264, float(settings.music_volume))
	_volume_setting(page, "sfx_volume", "効果音", 40, 392, float(settings.sfx_volume))
	_text(page, "移動 WASD / 矢印\n強化 1 / 2 / 3    休止 Esc\n選択 矢印 / Tab と Enter", 644, 442, 508, 112, 20, Grimoire.INK_SOFT)
	save_notice = _text(page, "", 40, 514, 516, 66, 18, Grimoire.INK_SOFT)
	_focus(_button(page, "戻る  [Esc]", Rect2(40, 592, 516, 60), close_screen, false, "back"))
	_button(page, "保存記録を確認", Rect2(644, 592, 508, 60), func() -> void: open_screen("storage"), false, "settings_storage")

func _setting_toggle(parent: Control, key: String, title: String, x: float, y: float, enabled: bool) -> void:
	var toggle := _button(parent, "%s   %s" % [title, "ON" if enabled else "OFF"], Rect2(x, y, 508, 62), func() -> void:
		setting_changed.emit(key, not enabled)
		last_screen = "", false, "settings_" + key)
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(enabled)

func _volume_setting(parent: Control, key: String, title: String, x: float, y: float, value: float) -> void:
	var caption := _text(parent, "%s  %d%%" % [title, roundi(value * 100)], x, y, 508, 40, 24, Grimoire.GOLD_INK)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(value * 100)
	slider.focus_mode = Control.FOCUS_ALL
	slider.set_meta("focus_key", "settings_" + key)
	slider.set_meta("action_id", "settings_" + key)
	slider.set_meta("control_id", "settings_" + key)
	slider.set_meta("action_label", title)
	slider.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Grimoire.GOLD_INK, Grimoire.FOCUS_WIDTH))
	parent.add_child(slider)
	_at(slider, x + 4, y + 48, 500, 48)
	slider.value_changed.connect(func(next: float) -> void:
		caption.text = "%s  %d%%" % [title, roundi(next)]
		setting_changed.emit(key, next / 100.0))

func _storage_screen() -> void:
	var page := _modal("この端末の記録", "図鑑・章の踏破・初めの魔法・設定を保存します。中断した戦闘の再開には対応していません。", true)
	_text(page, "保存先と引き継ぎ", 644, 40, 508, 48, 30, Grimoire.GOLD_INK, true)
	if profile != null:
		_text(page, str(profile.message), 40, 222, 516, 144, 24, Grimoire.DANGER_INK if profile.status in ["invalid", "blocked", "error"] else Grimoire.ECHO_INK)
		_text(page, "外部への送信はありません。同じブラウザーと同じサイトで開くと記録を引き継ぎます。\n\nブラウザーのデータを削除すると、記録も失われます。", 644, 150, 508, 242, 22, Grimoire.INK_SOFT)
		if profile.status == "invalid":
			_text(page, "下の操作は、読めない元の記録を別名で退避してから、新しい記録を作ります。", 644, 422, 508, 112, 20, Grimoire.INK_SOFT)
			_button(page, "元の記録を退避して初期化", Rect2(644, 592, 508, 60), func() -> void: storage_reset_requested.emit(), false, "storage_reset")
		elif profile.status in ["blocked", "error"]:
			_button(page, "保存を再確認", Rect2(644, 592, 508, 60), func() -> void: storage_retry_requested.emit(), false, "storage_retry")
	_focus(_button(page, "戻る  [Esc]", Rect2(40, 592, 516, 60), close_screen, false, "back"))

func _discovered(group: String, id: String) -> bool:
	if profile != null and profile.data.discoveries.get(group, []).has(id):
		return true
	var discoveries: Dictionary = run.snapshot().get("discoveries", {})
	return discoveries.get(group, []).has(id) if str(run.state) != "title" else false

func _codex_ids() -> Array:
	match codex_category:
		"weapons", "evolutions": return Spellbook.WEAPON_IDS
		"relics": return Spellbook.RELIC_IDS
		_: return Spellbook.ENEMY_IDS

func _codex_info(id: String) -> Dictionary:
	match codex_category:
		"weapons", "evolutions": return Spellbook.weapon_info(id)
		"relics": return Spellbook.relic_info(id)
		_: return Spellbook.enemy_info(id)

func _codex_screen() -> void:
	var page := _modal("魔術図鑑", "出会った魔法・遺物・魔物を記録します。\n未発見の頁は、夜の中で探してください。", true)
	_text(page, "記された一節", 644, 40, 508, 48, 30, Grimoire.GOLD_INK, true)
	for index in range(CATEGORIES.size()):
		var category: String = CATEGORIES[index]
		var button := _button(page, CATEGORY_TITLES[index], Rect2(40 + index * 132, 170, 120, 50), func() -> void:
			codex_category = category
			codex_index = 0
			last_screen = "", category == codex_category, "codex_category_" + category)
		button.toggle_mode = true
		button.set_pressed_no_signal(category == codex_category)
	var ids := _codex_ids()
	codex_index = clampi(codex_index, 0, ids.size() - 1)
	for index in range(ids.size()):
		var id: String = ids[index]
		var known := _discovered(codex_category, id)
		var info := _codex_info(id)
		var title := str(info.get("title", "")) if known else "未発見の頁"
		if codex_category == "evolutions" and known:
			title = str(info.get("evolution", title))
		var col := index / 6
		var row := index % 6
		var button := _button(page, title, Rect2(40 + col * 266, 238 + row * 54, 516 if ids.size() <= 6 else 250, 48), func() -> void:
			codex_index = index
			last_screen = "", index == codex_index, "codex_item_" + id)
		button.add_theme_font_size_override("font_size", 20 + (2 if large_text else 0))
	var current_id: String = ids[codex_index]
	var info := _codex_info(current_id)
	var known := _discovered(codex_category, current_id)
	_glyph(page, str(info.get("icon", "empty")) if known else "locked", 644, 140, 112, 112, codex_category == "evolutions" and known)
	var title := str(info.get("title", "")) if known else "まだ、白い頁"
	if codex_category == "evolutions" and known:
		title = str(info.get("evolution", title))
	_text(page, title, 780, 154, 372, 94, 30, Grimoire.INK, true)
	var description := str(info.get("body", "")) if known else _unlock_hint(codex_category, current_id)
	if codex_category == "evolutions" and known:
		description = "%s\n\n第3章の宝箱\n%s Rank 5 ＋ %s" % [info.get("evolution_body", ""), info.get("title", "魔法"), info.get("requirement_title", "対応する遺物")]
	_text(page, description, 644, 286, 508, 244, 22, Grimoire.INK_SOFT)
	var count := 0
	for id in ids:
		if _discovered(codex_category, id):
			count += 1
	_text(page, "発見 %d / %d" % [count, ids.size()], 644, 562, 508, 36, 20, Grimoire.ECHO_INK)
	_focus(_button(page, "戻る  [Esc]", Rect2(40, 592, 516, 60), close_screen, false, "back"))

func _unlock_hint(group: String, id: String) -> String:
	match group:
		"weapons": return "強化や宝箱で、新しい魔法を習得すると記録されます。"
		"relics": return "強化や宝箱で、遺物を手に入れると記録されます。"
		"evolutions": return "第3章の宝箱で、Rank 5の魔法と対応する遺物をそろえると進化を選べます。"
		_:
			if id.begins_with("boss_"):
				return "各章の攻勢をしのぐと、章の主が姿を現します。"
			return "先の章へ進み、新しい魔物と出会うと記録されます。"
