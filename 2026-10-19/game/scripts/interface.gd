extends Control

const Glyph = preload("res://scripts/spell_glyph.gd")
const Frame = preload("res://scripts/book_frame.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const Campaign = preload("res://scripts/campaign.gd")

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

const PAPER := Color("f5efdf")
const GOLD := Color("dbc182")
const MUTED := Color("c2bdb0")
const BLUE := Color("92d4e8")
const DANGER := Color("e78b88")
const INK := Color("101b25")
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
	book_theme.default_font_size = 22
	for type in ["Label", "Button", "CheckButton"]:
		book_theme.set_color("font_color", type, PAPER)
		book_theme.set_color("font_hover_color", type, PAPER)
		book_theme.set_color("font_focus_color", type, PAPER)
	book_theme.set_color("font_pressed_color", "Button", INK)
	book_theme.set_color("font_disabled_color", "Button", Color("8c9294"))
	book_theme.set_stylebox("panel", "PanelContainer", _box(Color("172533"), Color("8a7957"), 1, 3))
	book_theme.set_stylebox("normal", "Button", _box(Color("223340"), Color("867a61"), 1, 3))
	book_theme.set_stylebox("hover", "Button", _box(Color("344a54"), GOLD, 2, 3))
	book_theme.set_stylebox("pressed", "Button", _box(GOLD, PAPER, 2, 3))
	book_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 3, 3))
	book_theme.set_stylebox("disabled", "Button", _box(Color("1b2730"), Color("596366"), 1, 3))
	book_theme.set_stylebox("grabber_area", "HSlider", _box(Color("2d4c59"), Color("8a7957"), 1, 2))
	book_theme.set_color("font_color", "CheckBox", PAPER)

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

func _label(value: String, font_size: int = 22, color: Color = PAPER, heading: bool = false) -> Label:
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

func _text(parent: Control, value: String, x: float, y: float, width: float, height: float, font_size: int = 22, color: Color = PAPER, heading: bool = false) -> Label:
	var label := _label("", font_size, color, heading)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_at(label, x, y, width, height)
	parent.add_child(label)
	label.text = value
	_at(label, x, y, width, height)
	label.set_meta("layout_bounds", Rect2(x, y, width, height))
	return label

func _glyph(parent: Control, kind: String, x: float, y: float, width: float = 54, height: float = 54, evolved: bool = false) -> Control:
	var glyph := Glyph.new()
	glyph.kind = kind
	glyph.set("evolved", evolved)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)
	_at(glyph, x, y, width, height)
	return glyph

func _button(parent: Control, value: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 22 + (2 if large_text else 0))
	if primary:
		button.add_theme_stylebox_override("normal", _box(Color("665638"), GOLD, 2))
	parent.add_child(button)
	_at(button, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	button.pressed.connect(action)
	button.set_meta("focus_key", value)
	if _default_focus == null:
		_default_focus = button
	return button

func _focus(button: Control) -> void:
	_default_focus = button

func _panel(parent: Control, rect: Rect2, divided: bool = false, compact: bool = false) -> Control:
	var panel := Frame.new()
	panel.divided = divided
	panel.compact = compact
	var frame_style := _box(Color(0.045, 0.075, 0.11, 0.97), Color("8a8067"), 1, 3)
	frame_style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(panel)
	_at(panel, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	# Fixed logical coordinates keep text and engraved corners in the same system.
	var content := Control.new()
	panel.add_child(content)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return content

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _box(Color("111827"), Color("566078"))
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	var fill := _box(color, color, 0)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _build_hud() -> void:
	if is_instance_valid(hud):
		hud.queue_free()
	hud = Control.new()
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp := _panel(hud, Rect2(18, 16, 264, 82), false, true)
	health_label = _text(hp, "HP 100 / 100", 16, 6, 232, 32, 20)
	health_bar = _bar(Color("b67183"))
	hp.add_child(health_bar)
	_at(health_bar, 16, 47, 232, 17)
	phase_label = _text(hud, "第一章", 300, 18, 240, 36, 23, GOLD, true)
	phase_detail = _text(hud, "", 300, 57, 240, 31, 18, MUTED)
	var clock := _panel(hud, Rect2(552, 12, 176, 90), false, true)
	timer_caption = _text(clock, "章の主まで", 0, 3, 176, 30, 17, MUTED)
	timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label = _text(clock, "03:00", 0, 34, 176, 49, 34)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_label = _text(hud, "討伐 0", 754, 19, 190, 36, 23)
	level_label = _text(hud, "Lv.1", 754, 57, 190, 30, 19, MUTED)
	var objective := _text(hud, "魔物をかわし、章の主を倒す", 948, 20, 222, 74, 19, GOLD)
	objective.name = "Objective"
	for label in [phase_label, phase_detail, kill_label, level_label, objective]:
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", 2)
	_button(hud, "休止", Rect2(1180, 20, 82, 64), func() -> void: pause_requested.emit()).tooltip_text = "休止 [Esc]"
	_default_focus = null
	boss_panel = _panel(hud, Rect2(320, 112, 640, 72), false, true)
	boss_frame = boss_panel.get_parent()
	boss_label = _text(boss_panel, "", 16, 4, 608, 36, 21, DANGER)
	boss_bar = _bar(DANGER)
	boss_panel.add_child(boss_bar)
	_at(boss_bar, 16, 44, 608, 12)
	hint = _text(hud, "", 264, 198, 752, 76, 21)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", INK)
	hint.add_theme_constant_override("outline_size", 6)
	var foot := _panel(hud, Rect2(18, 618, 1244, 86), false, true)
	experience_bar = _bar(GOLD)
	foot.add_child(experience_bar)
	_at(experience_bar, 14, 10, 1216, 8)
	equipment_root = Control.new()
	foot.add_child(equipment_root)
	_at(equipment_root, 14, 24, 900, 58)
	experience_label = _text(foot, "", 904, 23, 322, 30, 17, MUTED)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	echo_label = _text(foot, "挟撃 0回", 904, 53, 322, 32, 19, BLUE)
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
		save_notice.add_theme_color_override("font_color", DANGER if profile.status in ["invalid", "blocked", "error"] else MUTED)
	hud.visible = str(run.state) == "playing"
	health_label.text = "HP %d / %d" % [ceili(run.health), int(run.maximum_health)]
	health_bar.max_value = run.maximum_health
	health_bar.value = run.health
	health_label.add_theme_color_override("font_color", DANGER if run.health <= run.maximum_health * 0.3 else PAPER)
	var chapter: Dictionary = run.chapter_info()
	var remaining := maxi(0, ceili(float(chapter.get("duration", 180)) - run.chapter_elapsed))
	clock_label.text = "%02d:%02d" % [remaining / 60, remaining % 60] if run.chapter_stage != "boss" else "BOSS"
	timer_caption.text = "章の主まで" if run.chapter_stage != "boss" else "章の主を倒す"
	kill_label.text = "討伐 %d" % run.kills
	level_label.text = "魔女 Lv.%d" % run.level
	experience_bar.max_value = run.experience_needed
	experience_bar.value = run.experience
	experience_label.text = "経験値 %d / %d" % [run.experience, run.experience_needed]
	var phase: Dictionary = run.phase_info()
	phase_label.text = "第%d章  %s" % [run.chapter + 1, chapter.get("name", "")]
	phase_detail.text = str(phase.get("name", ""))
	var boss: Dictionary = run.boss_data()
	boss_frame.visible = not boss.is_empty()
	if not boss.is_empty():
		boss_label.text = "%s   第%d形態" % [boss.get("name", "章の主"), int(boss.get("phase", 1))]
		boss_bar.max_value = float(boss.get("max_hp", 1))
		boss_bar.value = float(boss.get("hp", 0))
	echo_label.text = "%s  /  挟撃 %d回" % [run.specialization, run.resonance_hits]
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
		child.queue_free()
	var weapons: Array = equipment.get("weapons", [])
	for index in range(3):
		var x := index * 172
		if index < weapons.size():
			var item: Dictionary = weapons[index]
			_glyph(equipment_root, str(item.icon), x, 0, 44, 48, bool(item.get("evolved", false)))
			_text(equipment_root, str(item.title), x + 48, 0, 120, 30, 18, GOLD if item.get("evolved", false) else PAPER)
			_text(equipment_root, "進化済み" if item.get("evolved", false) else "Rank %d / %d" % [item.level, item.max_level], x + 48, 31, 120, 27, 16, MUTED)
		else:
			_glyph(equipment_root, "empty", x, 0, 44, 48)
			_text(equipment_root, "魔法の空き枠", x + 48, 14, 120, 28, 17, MUTED)
	_text(equipment_root, "遺物", 536, 14, 52, 32, 18, MUTED)
	var relics: Array = equipment.get("relics", [])
	for index in range(3):
		var x := 596 + index * 64
		if index < relics.size():
			var glyph := _glyph(equipment_root, str(relics[index].icon), x, 0, 48, 48)
			glyph.mouse_filter = Control.MOUSE_FILTER_PASS
			glyph.tooltip_text = "%s\n%s" % [relics[index].title, relics[index].body]
		else:
			_glyph(equipment_root, "empty", x, 0, 48, 48)

func _rebuild_overlay() -> void:
	var focus_key := ""
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and is_instance_valid(overlay) and overlay.is_ancestor_of(focused):
		focus_key = str(focused.get_meta("focus_key", ""))
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

func _modal(title: String, subtitle: String, divided: bool = false) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.065, 0.88)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := _panel(overlay, Rect2(52, 36, 1176, 648), divided)
	_text(page, title, 32, 18, 1112, 52, 34, GOLD, true)
	_text(page, subtitle, 32, 74, 1112, 34, 20, MUTED)
	return page

func _title_screen() -> void:
	# Leave the right-hand illustration unobscured by menu furniture.
	_text(overlay, "ECHO WITCH  /  THREE CHAPTERS", 64, 62, 650, 32, 18, GOLD)
	_text(overlay, "残響の魔女", 58, 102, 680, 104, 70, PAPER, true)
	_text(overlay, "2秒前の自分と、夜をほどく。", 66, 216, 630, 45, 26, GOLD, true)
	_text(overlay, "三つの章を巡り、庭園に夜明けを。\n魔法は自動。あなたは、二人の通り道を描く。", 66, 276, 630, 76, 23, PAPER)
	var starter: Dictionary = Spellbook.weapon_info(selected_starter)
	var choose := _button(overlay, "初めの魔法：%s   変更" % starter.get("title", "雷"), Rect2(66, 376, 556, 54), func() -> void: open_screen("starters"))
	choose.add_theme_font_size_override("font_size", 21 + (2 if large_text else 0))
	var start := _button(overlay, "物語をはじめる  [Enter]", Rect2(66, 448, 556, 64), func() -> void: start_requested.emit(), true)
	_focus(start)
	_button(overlay, "魔術図鑑  [C]", Rect2(66, 530, 270, 52), func() -> void: open_screen("codex"))
	_button(overlay, "設定", Rect2(352, 530, 270, 52), func() -> void: open_screen("settings"))
	var clears: int = profile.data.clears.size() if profile != null else 0
	_text(overlay, "章の踏破 %d / 3   ・   移動 WASD / 矢印   ・   休止 Esc" % clears, 66, 604, 670, 36, 18, MUTED)
	_storage_note(overlay, 66, 652, 1080)

func _storage_note(parent: Control, x: float, y: float, width: float) -> void:
	if profile == null:
		return
	var failing: bool = profile.status in ["invalid", "blocked", "error"]
	if failing:
		var button := _button(parent, "保存できません：記録を確認", Rect2(x, y, minf(width, 520), 44), func() -> void: open_screen("storage"))
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", DANGER)
	else:
		_text(parent, "記録と設定はこの端末に保存。外部への送信はありません。", x, y, width, 64 if width < 600 else 32, 17, MUTED)

func _starter_screen() -> void:
	var page := _modal("最初の一節を選ぶ", "初めの魔法だけが変わります。能力の恒久強化はありません。")
	for index in range(Spellbook.WEAPON_IDS.size()):
		var id: String = Spellbook.WEAPON_IDS[index]
		var info: Dictionary = Spellbook.weapon_info(id)
		var available: bool = profile == null or profile.has_starter(id)
		var rect := Rect2(32 + (index % 3) * 374, 132 + (index / 3) * 186, 356, 166)
		var button := _button(page, "", rect, func() -> void:
			selected_starter = id
			close_screen(), selected_starter == id)
		button.disabled = not available
		if available:
			_glyph(button, str(info.icon), 16, 16, 62, 62)
			_text(button, str(info.title), 92, 16, 248, 38, 25, GOLD, true)
			_text(button, str(info.body), 18, 91, 320, 68, 20, MUTED)
			if selected_starter == id:
				_text(button, "選択中", 92, 58, 240, 30, 18, BLUE)
		else:
			_glyph(button, "empty", 16, 16, 62, 62)
			_text(button, "未解放の魔法", 92, 22, 248, 38, 24, MUTED, true)
			var unlock := "第1章を踏破すると解放" if id in ["thorn", "wisp"] else ("第2章を踏破すると解放" if id == "frost" else "第3章を踏破すると解放")
			_text(button, unlock, 18, 97, 320, 46, 20, MUTED)
	_focus(_button(page, "戻る  [Esc]", Rect2(32, 558, 240, 54), close_screen))

func _specialization_offer() -> bool:
	return not run.choices.is_empty() and bool(run.choices[0].get("specialization", false))

func _can_reroll() -> bool:
	return str(run.state) in ["upgrade", "treasure"] and str(run.choice_phase) == "offer" and int(run.rerolls_left) > 0 and not _specialization_offer()

func _upgrade_screen() -> void:
	var replacing: bool = str(run.choice_phase) == "replace"
	var treasure: bool = str(run.state) == "treasure"
	var title := "入れ替える頁を選ぶ" if replacing else ("宝箱から、新たな一節" if treasure else "魔術書に、新しい一節")
	var subtitle := "枠がいっぱいです。手放す装備を選ぶと、新しい装備を受け取ります。" if replacing else "三つからひとつ選ぶ。選択中は、戦闘も残像も止まります。"
	var page := _modal(title, subtitle)
	var equipment: Dictionary = run.equipment_info()
	_text(page, "魔法 %d / 3枠   遺物 %d / 3枠   Lv.%d   今章はRank%dまで" % [equipment.weapons.size(), equipment.relics.size(), run.level, int(equipment.get("rank_cap", 5))], 32, 110, 1110, 34, 18, BLUE)
	for index in range(run.choices.size()):
		var choice: Dictionary = run.choices[index]
		var kind := str(choice.get("kind", ""))
		var button := _button(page, "", Rect2(32 + index * 374, 144, 356, 396), func() -> void: upgrade_requested.emit(index), kind == "evolution")
		button.set_meta("focus_key", "choice_" + str(index))
		_text(button, "[%d]  %s" % [index + 1, str(choice.get("tag", ""))], 18, 10, 318, 32, 18, GOLD)
		_glyph(button, str(choice.get("icon", "power")), 18, 50, 54, 54, kind == "evolution")
		_text(button, str(choice.get("title", "")), 86, 50, 248, 74, 25, PAPER, true)
		var before := str(choice.get("before", ""))
		var after := str(choice.get("after", ""))
		if replacing:
			if kind != "relic" and before.contains("\n"):
				before = before.substr(before.find("\n") + 1)
			if after.contains("\n"):
				after = after.substr(after.find("\n") + 1)
			_text(button, "失う：" + before, 18, 124, 318, 122, 18, MUTED)
			_text(button, "得る：" + after, 18, 256, 318, 122, 18, BLUE)
		elif kind == "relic":
			_text(button, str(choice.get("body", "")), 18, 124, 318, 150, 20, MUTED)
			var used: int = equipment.relics.size()
			_text(button, "遺物 %d / 3枠 → %d / 3枠" % [used, mini(3, used + 1)], 18, 300, 318, 40, 20, BLUE)
			_text(button, "選択後、遺物を入れ替えます。" if choice.get("full_slots", false) else "遺物の枠をひとつ使います。", 18, 346, 318, 44, 18, MUTED)
		else:
			_text(button, str(choice.get("body", "")), 18, 124, 318, 110 if kind == "specialization" else 76, 20, MUTED)
			if not before.is_empty() and not after.is_empty():
				_text(button, "前：" + before, 18, 200, 318, 64, 18, MUTED)
				_text(button, "後：" + after, 18, 264, 318, 64, 18, BLUE)
			else:
				_text(button, str(choice.get("effect", "")), 18, 244 if kind == "specialization" else 228, 318, 100, 20, BLUE)
			var requirement := str(choice.get("requirement", ""))
			if bool(choice.get("full_slots", false)):
				requirement = "選択後、魔法を入れ替えます。"
			elif not requirement.is_empty():
				requirement = requirement.replace(" / ", "\n") if requirement.begins_with("第3章") else "第3章の宝箱\n" + requirement
			_text(button, requirement, 18, 328, 318, 64, 17, GOLD if kind == "evolution" else MUTED)
		if index == 0:
			_focus(button)

	if replacing:
		_button(page, "選択へ戻る  [Esc]", Rect2(32, 548, 350, 54), func() -> void: cancel_replacement_requested.emit())
	else:
		var reroll := _button(page, "専門化は引き直せません" if _specialization_offer() else "引き直す %d回  [R]" % run.rerolls_left, Rect2(32, 548, 350, 54), func() -> void: reroll_requested.emit())
		reroll.name = "RerollButton"
		reroll.disabled = not _can_reroll()
		reroll.tooltip_text = "専門化は三つの固定された道から選びます。" if _specialization_offer() else "表示された三つを新しい候補に引き直します。"
		var skip := _button(page, "見送る %d回  [X]" % run.skips_left, Rect2(410, 548, 350, 54), func() -> void: skip_requested.emit())
		skip.disabled = int(run.skips_left) <= 0
	_text(page, "数字1〜3 / 矢印とEnter\nクリックでも選べます", 784, 548, 346, 66, 18, MUTED)

func _loadout(parent: Control, x: float, y: float, width: float) -> void:
	var equipment: Dictionary = run.equipment_info()
	_text(parent, "今夜の魔術書", x, y, width, 38, 27, GOLD, true)
	for index in range(3):
		var row_y := y + 52 + index * 68
		if index < equipment.weapons.size():
			var item: Dictionary = equipment.weapons[index]
			_glyph(parent, str(item.icon), x, row_y, 54, 54, item.get("evolved", false))
			_text(parent, str(item.title) + ("  進化済み" if item.get("evolved", false) else "  Rank %d / %d" % [item.level, item.max_level]), x + 66, row_y, width - 66, 36, 20)
			var required := str(item.get("requirement_title", ""))
			_text(parent, "進化：%s" % item.get("evolution", "") if item.get("evolved", false) else "第3章の宝箱：Rank 5 ＋ %s" % required, x + 66, row_y + 36, width - 66, 30, 17, GOLD if item.get("evolved", false) else MUTED)
		else:
			_glyph(parent, "empty", x, row_y, 54, 54)
			_text(parent, "魔法の空き枠", x + 66, row_y + 8, width - 66, 38, 21, MUTED)
	_text(parent, "遺物 %d / 3" % equipment.relics.size(), x, y + 266, width, 38, 22, GOLD)
	for index in range(equipment.relics.size()):
		var item: Dictionary = equipment.relics[index]
		_glyph(parent, str(item.icon), x, y + 314 + index * 66, 40, 40)
		_text(parent, "%s  %s" % [item.title, item.body], x + 48, y + 314 + index * 66, width - 48, 64, 18, MUTED)

func _pause_screen() -> void:
	var page := _modal("栞をはさんで、ひと休み", "戦闘・予告・残像の履歴は、すべて止まっています。")
	var reason := str(run.pause_reason)
	_text(page, reason if not reason.is_empty() else "第%d章  %s" % [run.chapter + 1, _chapter_name(int(run.chapter))], 32, 126, 476, 66, 21, MUTED)
	_focus(_button(page, "続ける  [Enter / Esc]", Rect2(32, 212, 476, 62), func() -> void: resume_requested.emit(), true))
	_button(page, "設定", Rect2(32, 292, 230, 54), func() -> void: open_screen("settings"))
	_button(page, "魔術図鑑  [C]", Rect2(278, 292, 230, 54), func() -> void: open_screen("codex"))
	_button(page, "最初から挑む  [R]", Rect2(32, 368, 476, 54), func() -> void: retry_requested.emit())
	_button(page, "タイトルへ戻る", Rect2(32, 444, 476, 54), func() -> void: title_requested.emit())
	_storage_note(page, 32, 560, 476)
	_loadout(page, 572, 126, 566)

func _chapter_screen() -> void:
	var page := _modal("第%d章、踏破" % (run.chapter + 1), "魔術書と遺物を引き継いで、次の章へ進みます。")
	for index in range(3):
		var x := 64 + index * 374
		_glyph(page, CHAPTER_SIGILS[index], x + 90, 150, 132, 132)
		_text(page, "第%d章" % (index + 1), x, 302, 312, 32, 20, MUTED)
		_text(page, _chapter_name(index), x, 344, 312, 48, 28, GOLD if index <= run.chapter else PAPER, true)
		_text(page, "踏破" if index <= run.chapter else ("次の目的地" if index == run.chapter + 1 else "その先へ"), x, 410, 312, 34, 22, BLUE if index <= run.chapter else MUTED)
	var reward := "HPを回復。魔法と遺物はそのまま。"
	if profile != null and not profile.last_unlocks.is_empty():
		var names: Array[String] = []
		for id in profile.last_unlocks:
			names.append(str(Spellbook.weapon_info(id).get("title", id)))
		reward += "  初めの魔法に %s を解放。" % "・".join(names)
	_text(page, reward, 32, 474, 1112, 55, 20, BLUE)
	_focus(_button(page, "第%d章へ進む  [Enter]" % (run.chapter + 2), Rect2(32, 558, 700, 54), func() -> void: next_chapter_requested.emit(), true))
	_button(page, "タイトルへ戻る", Rect2(756, 558, 388, 54), func() -> void: title_requested.emit())

func _result_screen() -> void:
	var won: bool = str(run.state) == "victory"
	var page := _modal("夜明けの頁を、あなたへ" if won else "今夜の頁は、ここまで", "三つの章を踏破しました。" if won else "魔女のHPがなくなりました。初めの魔法を変えて、もう一度。")
	var snap: Dictionary = run.snapshot()
	var seconds := int(run.elapsed)
	_text(page, "生存 %02d:%02d   討伐 %d   Lv.%d" % [seconds / 60, seconds % 60, run.kills, run.level], 32, 132, 1060, 42, 27, GOLD)
	_text(page, "章の踏破 %d / 3    挟撃 %d回" % [snap.get("chapter_clears", []).size(), run.resonance_hits], 32, 190, 1060, 34, 22, BLUE)
	_text(page, "与えたダメージ", 32, 250, 520, 38, 27, PAPER, true)
	var damage: Dictionary = snap.get("damage_summary", {})
	var damage_names := {"player": "本体", "echo": "残像", "resonance": "挟撃", "poison": "毒"}
	for index in range(4):
		var id: String = damage_names.keys()[index]
		_text(page, "%s  %s" % [damage_names[id], _compact(float(damage.get(id, 0)))], 32 + (index % 2) * 258, 304 + (index / 2) * 42, 248, 38, 22, MUTED)
	var received: Dictionary = snap.get("damage_received", {})
	var cause_names := {"contact": "接触", "projectile": "飛び道具", "hazard": "地形魔法"}
	var causes: Array[String] = []
	for id in cause_names:
		if float(received.get(id, 0)) > 0:
			causes.append("%s %d" % [cause_names[id], roundi(float(received[id]))])
	_text(page, "受けたダメージ %d" % roundi(float(snap.get("damage_taken", 0))) + ("\n" + " / ".join(causes) if not causes.is_empty() else ""), 572, 250, 566, 122, 22, MUTED)
	var cause := str(snap.get("last_damage_cause", ""))
	if not won and cause in Spellbook.ENEMY_IDS:
		_text(page, "最後の被弾：%s" % Spellbook.enemy_info(cause).title, 572, 376, 566, 38, 20, DANGER)
	var rewards := "発見した図鑑と踏破記録を保存します。"
	if profile != null and not profile.last_unlocks.is_empty():
		var names: Array[String] = []
		for id in profile.last_unlocks:
			names.append(str(Spellbook.weapon_info(id).get("title", id)))
		rewards = "初めの魔法に %s を解放。" % "・".join(names)
	_text(page, rewards, 32, 420, 1096, 60, 21, BLUE)
	_focus(_button(page, "もう一度挑む  [Enter / R]", Rect2(32, 504, 432, 60), func() -> void: retry_requested.emit(), true))
	_button(page, "今夜の装備", Rect2(488, 504, 326, 60), func() -> void: open_screen("loadout"))
	_button(page, "タイトルへ戻る", Rect2(838, 504, 306, 60), func() -> void: title_requested.emit())
	_storage_note(page, 32, 584, 1100)

func _loadout_screen() -> void:
	var page := _modal("今夜の魔術書", "戦いを終えたときの魔法と遺物です。戻ると、この結果を確認できます。")
	var equipment: Dictionary = run.equipment_info()
	_text(page, "魔法 %d / 3枠" % equipment.weapons.size(), 32, 128, 526, 38, 27, GOLD, true)
	_text(page, "遺物 %d / 3枠" % equipment.relics.size(), 612, 128, 526, 38, 27, GOLD, true)
	for index in range(3):
		var y := 184 + index * 116
		if index < equipment.weapons.size():
			var weapon: Dictionary = equipment.weapons[index]
			var evolved: bool = bool(weapon.get("evolved", false))
			_glyph(page, str(weapon.icon), 32, y, 54, 54, evolved)
			var title := str(weapon.get("evolution_name", weapon.title)) + "  進化済み" if evolved else "%s  Rank %d / %d" % [weapon.title, weapon.level, weapon.max_level]
			_text(page, title, 100, y, 458, 38, 22, GOLD if evolved else PAPER)
			_text(page, str(weapon.get("stats", "")), 100, y + 42, 458, 72, 18, MUTED)
		else:
			_glyph(page, "empty", 32, y, 54, 54)
			_text(page, "魔法の空き枠", 100, y + 10, 458, 38, 21, MUTED)
		if index < equipment.relics.size():
			var relic: Dictionary = equipment.relics[index]
			_glyph(page, str(relic.icon), 612, y, 54, 54)
			_text(page, str(relic.title), 680, y, 458, 38, 22)
			_text(page, str(relic.body), 680, y + 42, 458, 72, 18, MUTED)
		else:
			_glyph(page, "empty", 612, y, 54, 54)
			_text(page, "遺物の空き枠", 680, y + 10, 458, 38, 21, MUTED)
	_focus(_button(page, "結果へ戻る  [Esc]", Rect2(32, 558, 1112, 54), close_screen))

func _chapter_name(index: int) -> String:
	return str(Campaign.chapter(index).name)

func _compact(value: float) -> String:
	return "%.1f万" % (value / 10000.0) if value >= 10000 else str(roundi(value))

func _settings_screen() -> void:
	var page := _modal("設定", "変更はすぐ反映され、この端末に保存します。")
	_setting_toggle(page, "sound", "音を鳴らす", 32, 138, sound_enabled)
	_setting_toggle(page, "reduced_motion", "動きを減らす", 612, 138, reduced_motion)
	_setting_toggle(page, "large_text", "文字を大きく", 612, 226, large_text)
	_text(page, "装飾の揺れを抑えます。敵の攻撃予告は表示します。", 612, 318, 506, 76, 21, MUTED)
	var settings: Dictionary = profile.settings() if profile != null else {"music_volume": 0.65, "sfx_volume": 0.8}
	_volume_setting(page, "music_volume", "音楽", 32, 248, float(settings.music_volume))
	_volume_setting(page, "sfx_volume", "効果音", 32, 376, float(settings.sfx_volume))
	_text(page, "移動 WASD / 矢印    強化 1 / 2 / 3\n休止 Esc    選択 矢印 / Tab と Enter", 612, 410, 506, 90, 21, MUTED)
	save_notice = _text(page, "", 32, 506, 1096, 40, 18, MUTED)
	_focus(_button(page, "戻る  [Esc]", Rect2(32, 558, 360, 54), close_screen))
	_button(page, "保存記録を確認", Rect2(612, 558, 506, 54), func() -> void: open_screen("storage"))

func _setting_toggle(parent: Control, key: String, title: String, x: float, y: float, enabled: bool) -> void:
	var toggle := _button(parent, "%s   %s" % [title, "ON" if enabled else "OFF"], Rect2(x, y, 506, 62), func() -> void:
		setting_changed.emit(key, not enabled)
		last_screen = "")
	toggle.set_meta("focus_key", "setting_" + key)
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(enabled)

func _volume_setting(parent: Control, key: String, title: String, x: float, y: float, value: float) -> void:
	var caption := _text(parent, "%s  %d%%" % [title, roundi(value * 100)], x, y, 506, 40, 24, GOLD)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(value * 100)
	slider.focus_mode = Control.FOCUS_ALL
	slider.set_meta("focus_key", "setting_" + key)
	slider.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), GOLD, 3))
	parent.add_child(slider)
	_at(slider, x + 4, y + 52, 498, 48)
	slider.value_changed.connect(func(next: float) -> void:
		caption.text = "%s  %d%%" % [title, roundi(next)]
		setting_changed.emit(key, next / 100.0))

func _storage_screen() -> void:
	var page := _modal("この端末の記録", "図鑑・章の踏破・初めの魔法・設定を保存します。中断した戦闘の再開には対応していません。")
	if profile != null:
		_text(page, str(profile.message), 32, 144, 1096, 106, 25, DANGER if profile.status in ["invalid", "blocked", "error"] else BLUE)
		_text(page, "外部への送信はありません。同じブラウザーと同じサイトで開くと記録を引き継ぎます。\nブラウザーのデータを削除すると、記録も失われます。", 32, 274, 1096, 100, 22, MUTED)
		if profile.status == "invalid":
			_text(page, "下の操作は、読めない元の記録を別名で退避してから、新しい記録を作ります。", 32, 400, 1096, 70, 21, MUTED)
			_button(page, "元の記録を退避して初期化", Rect2(612, 558, 506, 54), func() -> void: storage_reset_requested.emit())
		elif profile.status in ["blocked", "error"]:
			_button(page, "保存を再確認", Rect2(612, 558, 506, 54), func() -> void: storage_retry_requested.emit())
	_focus(_button(page, "戻る  [Esc]", Rect2(32, 558, 360, 54), close_screen))

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
	var page := _modal("魔術図鑑", "出会った魔法・遺物・魔物だけが記録されます。未発見の頁は、夜の中で探してください。")
	for index in range(CATEGORIES.size()):
		var category: String = CATEGORIES[index]
		var button := _button(page, CATEGORY_TITLES[index], Rect2(32 + index * 282, 124, 266, 50), func() -> void:
			codex_category = category
			codex_index = 0
			last_screen = "", category == codex_category)
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
		var button := _button(page, title, Rect2(32 + col * 266, 194 + row * 54, 532 if ids.size() <= 6 else 250, 48), func() -> void:
			codex_index = index
			last_screen = "", index == codex_index)
		button.add_theme_font_size_override("font_size", 19 + (2 if large_text else 0))
	var current_id: String = ids[codex_index]
	var info := _codex_info(current_id)
	var known := _discovered(codex_category, current_id)
	_glyph(page, str(info.get("icon", "empty")) if known else "empty", 640, 202, 104, 104, codex_category == "evolutions" and known)
	var title := str(info.get("title", "")) if known else "まだ、白い頁"
	if codex_category == "evolutions" and known:
		title = str(info.get("evolution", title))
	_text(page, title, 768, 210, 342, 88, 30, GOLD, true)
	var description := str(info.get("body", "")) if known else _unlock_hint(codex_category, current_id)
	if codex_category == "evolutions" and known:
		description = "%s\n第3章の宝箱\n%s Rank 5 ＋ %s" % [info.get("evolution_body", ""), info.get("title", "魔法"), info.get("requirement_title", "対応する遺物")]
	_text(page, description, 640, 334, 470, 164, 23, MUTED)
	var count := 0
	for id in ids:
		if _discovered(codex_category, id):
			count += 1
	_text(page, "発見 %d / %d" % [count, ids.size()], 640, 510, 470, 34, 21, BLUE)
	_focus(_button(page, "戻る  [Esc]", Rect2(32, 558, 360, 54), close_screen))

func _unlock_hint(group: String, id: String) -> String:
	match group:
		"weapons": return "強化や宝箱で、新しい魔法を習得すると記録されます。"
		"relics": return "強化や宝箱で、遺物を手に入れると記録されます。"
		"evolutions": return "第3章の宝箱で、Rank 5の魔法と対応する遺物をそろえると進化を選べます。"
		_:
			if id.begins_with("boss_"):
				return "各章の攻勢をしのぐと、章の主が姿を現します。"
			return "先の章へ進み、新しい魔物と出会うと記録されます。"
