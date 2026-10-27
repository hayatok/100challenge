extends Control

const Data = preload("res://scripts/rules.gd")
const WorldDataFile = preload("res://scripts/world_data.gd")
const UiPalette = preload("res://scripts/ui_theme.gd")
const Store = preload("res://scripts/save_store.gd")
const Sound = preload("res://scripts/sound.gd")
const BoardScene = preload("res://scenes/board.tscn")
const Scenery = preload("res://scripts/ui_scenery.gd")
const Motif = preload("res://scripts/ui_motif.gd")
const CampaignView = preload("res://scripts/campaign_ui.gd")
const CrewStage = preload("res://scripts/crew_stage.gd")
const SHORT_NAMES := {"knife":"ナイフ", "loanKnife":"貸出ナイフ", "coat":"雨具", "harpoon":"銛", "medicine":"救急包", "bomb":"爆薬", "flare":"発煙筒", "scrap":"銅の端材", "core":"集光芯", "pearl":"潮真珠", "pumpGear":"揚水歯車", "chart":"航路図", "sunLens":"太陽レンズ"}
const NAMES := {"isana": "ISANA", "ritsu": "RITSU", "kohaku": "KOHAKU", "sui": "SUI"}
const SYMBOLS := {"knife": "╱", "loanKnife": "╱", "harpoon": "↟", "coat": "衣", "medicine": "＋", "bomb": "●", "flare": "灯", "scrap": "銅", "core": "芯", "pearl": "○"}

@onready var content: VBoxContainer = %Content
@onready var header: HBoxContainer = %Header
@onready var backdrop: TextureRect = %Backdrop
@onready var shade: ColorRect = %Shade
@onready var overlay: Control = %Overlay
@onready var notice: Label = %SaveNotice
var state: Dictionary
var settings: Dictionary
var screen := "title"
var corrupt := false
var stored := false
var audio: Node
var board: Control
var modal: Control
var modal_panel: PanelContainer
var modal_scroll: ScrollContainer
var modal_body_height := 540.0
var pending_item := ""
var status_label: Label
var hp_label: Label
var tide_label: Label
var turn_label: Label
var bag_label: Label
var log_label: Label
var hp_bar: ProgressBar
var interact_button: Button
var harbor_feedback := ""
var qa_session := OS.get_cmdline_user_args().has("--qa")
var last_size := Vector2.ZERO
var resize_timer: Timer
var scenery: Control
var objective_label: Label
var cargo_value_label: Label
var tide_meter: ProgressBar
var control_dock: HBoxContainer
var world_overlay: Control
var inventory_detail: VBoxContainer
var inventory_selection := ""
var inventory_slots: Dictionary = {}
var ui_tweens: Array[Tween] = []
var crew_stages: Array[Control] = []
var focus_paused := false

func _ready() -> void:
	theme = UiPalette.make_theme()
	var loaded: Dictionary = {"state": Data.new_game(), "corrupt": false, "found": false, "error": ""} if qa_session else Store.load_game()
	state = loaded.state
	corrupt = loaded.corrupt
	stored = loaded.found
	settings = {"sound": true, "reduced": false} if qa_session else Store.load_settings()
	if OS.has_feature("web"):
		var motion_preference: Variant = JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'reduce' : 'full'")
		if str(motion_preference) == "reduce":
			settings.reduced = true
	audio = Sound.new()
	add_child(audio)
	audio.set_enabled(settings.sound and not qa_session)
	backdrop.texture = load("res://assets/art/r2/harbor-day.png")
	scenery = Scenery.new()
	add_child(scenery)
	move_child(scenery, 2)
	_set_notice(loaded.error)
	resize_timer = Timer.new()
	resize_timer.one_shot = true
	resize_timer.wait_time = 0.18
	add_child(resize_timer)
	resize_timer.timeout.connect(_resize_layout)
	resized.connect(func(): resize_timer.start())
	_read_safe_area()
	_render()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.title='潮還り / SHIOGAERI'")

func _resize_layout() -> void:
	_read_safe_area()
	if is_instance_valid(modal_panel):
		modal_panel.custom_minimum_size.x = minf(540, overlay.size.x - 28)
		modal_scroll.custom_minimum_size.y = minf(overlay.size.y - (405 if is_instance_valid(inventory_detail) else 205), modal_body_height)
	if is_instance_valid(control_dock):
		control_dock.custom_minimum_size.x = minf(size.x - 56, 520)
	var crossed_breakpoint := (size.x > 760.0) != (last_size.x > 760.0)
	if (crossed_breakpoint or absf(size.x - last_size.x) > 80.0) and screen != "expedition" and not is_instance_valid(modal):
		_render()

func _read_safe_area() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("(function(){var e=document.getElementById('safe-area-probe');if(!e)return '';var s=getComputedStyle(e);return JSON.stringify([parseFloat(s.paddingLeft)||0,parseFloat(s.paddingTop)||0,parseFloat(s.paddingRight)||0,parseFloat(s.paddingBottom)||0,innerWidth,innerHeight]);})()")
	var parser := JSON.new()
	if raw == null or parser.parse(str(raw)) != OK or not parser.data is Array or parser.data.size() != 6:
		return
	var data: Array = parser.data
	var scale_x: float = size.x / maxf(1, float(data[4]))
	var scale_y: float = size.y / maxf(1, float(data[5]))
	_apply_safe_area(Vector4(float(data[0]) * scale_x, float(data[1]) * scale_y, float(data[2]) * scale_x, float(data[3]) * scale_y))

func _apply_safe_area(insets: Vector4) -> void:
	var safe: MarginContainer = %SafeFrame
	safe.add_theme_constant_override("margin_left", 18 + ceili(insets.x))
	safe.add_theme_constant_override("margin_top", 18 + ceili(insets.y))
	safe.add_theme_constant_override("margin_right", 18 + ceili(insets.z))
	safe.add_theme_constant_override("margin_bottom", 18 + ceili(insets.w))
	overlay.offset_left = insets.x
	overlay.offset_top = insets.y
	overlay.offset_right = -insets.z
	overlay.offset_bottom = -insets.w

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int = 16, color: Color = UiPalette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Seed text measurement before its container supplies the final width.
	label.size.x = 280
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func():
		audio.play_event("click")
		_pulse(button)
		action.call())
	if primary:
		button.add_theme_stylebox_override("normal", UiPalette.box(UiPalette.PRIMARY, Color("ad7635")))
		button.add_theme_stylebox_override("hover", UiPalette.box(Color("ffd883"), Color("a96a20")))
		var pressed := UiPalette.box(Color("dfab52"), UiPalette.GOLD)
		pressed.shadow_size = 0
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_color_override("font_color", UiPalette.INK)
	return button

func _panel(parent: Node, margin: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiPalette.box(UiPalette.SURFACE, UiPalette.LINE, margin))
	parent.add_child(panel)
	var ornament := Motif.new()
	ornament.variant = "frame"
	panel.add_child(ornament)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _portrait(character: String, minimum: Vector2, close_up: bool = false) -> TextureRect:
	var image := TextureRect.new()
	image.texture = UiPalette.portrait(character)
	if close_up and not ResourceLoader.exists("res://assets/art/v03/portraits/%s.png" % character):
		var crop := AtlasTexture.new()
		crop.atlas = image.texture
		crop.region = Rect2(image.texture.get_width()*0.16, 0, image.texture.get_width()*0.75, image.texture.get_height()*0.68)
		image.texture = crop
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = minimum
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _crew_stage(character: String, minimum: Vector2, phase: String, celebrate: bool) -> Control:
	var stage := CrewStage.new()
	stage.character = character
	stage.phase = phase
	stage.celebrate = celebrate
	stage.reduced_motion = settings.reduced or qa_session
	stage.custom_minimum_size = minimum
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.set_meta("receipt_character", character)
	crew_stages.append(stage)
	return stage

func _render() -> void:
	for tween: Tween in ui_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	ui_tweens.clear()
	crew_stages.clear()
	last_size = size
	_clear(header)
	_clear(content)
	board = null
	control_dock = null
	world_overlay = null
	var brand := HBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(_icon("anchor", 27))
	var brand_label := _label("潮還り  /  v%s" % ProjectSettings.get_setting("application/config/version","0.2.0"), 14)
	brand_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_label.add_theme_color_override("font_outline_color", Color("fff8e5"))
	brand_label.add_theme_constant_override("outline_size", 5)
	brand.add_child(brand_label)
	var help := _button("設定", _settings)
	help.icon = UiPalette.icon("gear")
	help.expand_icon = true
	help.add_theme_constant_override("icon_max_width", 20)
	help.size_flags_horizontal = Control.SIZE_SHRINK_END
	help.custom_minimum_size.x = 84
	header.add_child(help)
	shade.color = Color(1, 0.98, 0.85, 0.07 if screen == "title" else 0.25)
	var success: bool = state.mode == "result" and state.result.outcome == "extracted"
	scenery.configure(screen, settings.reduced, success)
	audio.set_scene("result_extracted" if success else "result_dead" if screen == "result" else screen, int(state.run.tide) if state.run is Dictionary else 0)
	match screen:
		"title": _title()
		"harbor": _harbor()
		"expedition": _expedition()
		"result": _result()
	_animate_in(content)
	_sync_presentation()

func _title() -> void:
	_spacer(content)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 300 if size.x < 760 else 410
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 14)
	row.add_child(column)
	var title_card := _panel(column, 20)
	title_card.add_child(_label("TIDELANDS ADVENTURE", 12, UiPalette.GOLD))
	var logo := _label("潮還り", 74, UiPalette.INK)
	logo.add_theme_color_override("font_outline_color", Color("fffdf1"))
	logo.add_theme_constant_override("outline_size", 7)
	title_card.add_child(logo)
	title_card.add_child(_rule())
	title_card.add_child(_label("潮の街で、宝物と帰り道を。", 18))
	title_card.add_child(_label("4人の回収屋と、一手ずつ進む冒険。\n拾った宝は、持ち帰ってこそ。", 14, UiPalette.MUTED))
	var crew := HBoxContainer.new()
	crew.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.add_child(crew)
	for key: String in Data.CHARACTERS:
		crew.add_child(_avatar(key,42))
	var begin := _button("続きから" if stored and not corrupt else "港へ向かう", _begin, true)
	begin.icon = UiPalette.icon("compass")
	begin.expand_icon = true
	begin.add_theme_constant_override("icon_max_width", 30)
	column.add_child(begin)
	var help := _button("回収屋の心得", _help)
	help.icon = UiPalette.icon("map")
	help.expand_icon = true
	help.add_theme_constant_override("icon_max_width", 24)
	column.add_child(help)
	var warning := _label("倒れると装備・携行品をすべて失います。", 12)
	warning.add_theme_color_override("font_outline_color", UiPalette.SURFACE)
	warning.add_theme_constant_override("outline_size", 5)
	column.add_child(warning)
	begin.grab_focus()
	_spacer(content)
	var caption := _panel(content, 10)
	caption.add_child(_label("港の復興  /  %s" % Data.campaign_summary(state).title, 13))

func _begin() -> void:
	audio.start_ambience()
	if corrupt:
		var body := _open_modal("保存データの確認", 180)
		body.add_child(_label("保存データを読み込めませんでした。新しく始めると、元のデータを置き換えます。"))
		body.add_child(_button("新しく始める", func():
			corrupt = false
			state = Data.new_game()
			_close_modal()
			_enter()
			_persist(), true))
		return
	_enter()

func _enter() -> void:
	screen = state.mode
	pending_item = ""
	_render()

func _harbor() -> void:
	var profile: Dictionary = state.profile
	var who: Dictionary = Data.CHARACTERS[state.character]
	var heading := _panel(content, 10)
	var top := HBoxContainer.new()
	heading.add_child(top)
	top.add_child(_icon("anchor", 25))
	var name_label := _label("回収組合の港", 23)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var record := _label("生還 %d / %d" % [int(profile.extracts), int(profile.runs)], 12, UiPalette.MUTED)
	record.autowrap_mode = TextServer.AUTOWRAP_OFF
	record.custom_minimum_size.x = 80
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(record)
	if not harbor_feedback.is_empty():
		heading.add_child(_label(harbor_feedback, 13, UiPalette.SUCCESS))
	var progress: Dictionary = Data.campaign_summary(state)
	var district: Dictionary = Data.current_district(state)
	heading.add_child(_label("復興 %d/%d  /  %s  /  %d G" % [progress.completed,progress.total,district.name,state.profile.credits],13,UiPalette.GOLD))
	var services := HBoxContainer.new()
	heading.add_child(services)
	for entry: Array in [["依頼帳","jobs"],["航路","routes"],["物資交換","exchange"]]:
		var page: String = entry[1]
		services.add_child(_button(entry[0],func(): _campaign(page)))
	var outer := ScrollContainer.new()
	outer.follow_focus = true
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(outer)
	var area: BoxContainer = HBoxContainer.new() if size.x > 760 else VBoxContainer.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 16)
	outer.add_child(area)
	var cast := VBoxContainer.new()
	cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(cast)
	var hero_panel := PanelContainer.new()
	hero_panel.add_theme_stylebox_override("panel", UiPalette.box(Color("fff4d9"), Color("9dc8bf"), 8))
	cast.add_child(hero_panel)
	var hero := HBoxContainer.new()
	hero.custom_minimum_size.y = 220 if size.x < 760 else 350
	hero_panel.add_child(hero)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(145, 215 if size.x < 760 else 340)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_child(stage)
	var motif := Motif.new()
	motif.accent = UiPalette.crew_accent(state.character)
	motif.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(motif)
	var portrait := _portrait(state.character, Vector2.ZERO, size.x < 760)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(portrait)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 130
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(info)
	info.add_child(_label(NAMES[state.character], 12, UiPalette.GOLD))
	info.add_child(_label(who.name, 30))
	info.add_child(_label(who.role, 14, UiPalette.MUTED))
	info.add_child(_rule())
	info.add_child(_label(who.trait, 15, UiPalette.SUCCESS))
	info.add_child(_label("「%s」" % who.idleLine, 13))
	info.add_child(_button("%sと話す" % who.name,func(): _campaign("crew")))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 7)
	cast.add_child(choices)
	for key: String in Data.CHARACTERS:
		var char_id := key
		var button := _button("", func(): _act({"type":"choose", "character":char_id}), state.character == key)
		button.custom_minimum_size.y = 77
		button.set_meta("character_id", key)
		button.tooltip_text = Data.CHARACTERS[key].name + " / " + Data.CHARACTERS[key].trait
		choices.add_child(button)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_top = 4
		inner.offset_bottom = -4
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 0)
		button.add_child(inner)
		inner.add_child(_avatar(key, 43))
		var label := _label(Data.CHARACTERS[key].name, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(label)
	var cargo := _panel(area, 12)
	cargo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo.add_child(_section("遠征の支度", "bag"))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo.add_child(columns)
	_harbor_items(columns, "倉庫  %d" % profile.stash.size(), profile.stash, "pack")
	_harbor_items(columns, "携行 %d/%d" % [state.loadout.size(), Data.stats(state).capacity], state.loadout, "unpack")
	var preparation := HBoxContainer.new()
	cargo.add_child(preparation)
	preparation.add_child(_button("基本の支度", _basic_loadout))
	var repair := _button("灯りを修理" if not profile.lampRepaired else "修復済み", func(): _act({"type":"repair"}))
	repair.disabled = profile.lampRepaired or not _has_kind(profile.stash,"core") or not _has_kind(profile.stash,"scrap")
	repair.tooltip_text = "集光芯と銅の端材を1個ずつ使う。次回から視界＋1。"
	preparation.add_child(repair)
	var stats: Dictionary = Data.stats(state)
	cargo.add_child(_label("攻撃 %d   防御 %d   体力 %d" % [stats.attack,stats.defense,stats.maxHp], 13, UiPalette.MUTED))
	var footer := _panel(content, 10)
	footer.add_child(_label("倒れると、装備を含む携行品をすべて失います。倉庫の品は残ります。", 12, UiPalette.INK))
	var depart := _button("この装備で出発する", func(): _act({"type":"depart"}), true)
	depart.icon = UiPalette.icon("compass")
	depart.expand_icon = true
	depart.add_theme_constant_override("icon_max_width", 27)
	footer.add_child(depart)
	depart.grab_focus()

func _has_kind(items: Array, kind: String) -> bool:
	for item: Dictionary in items:
		if item.kind == kind:
			return true
	return false

func _campaign(page: String = "jobs") -> void:
	if state.mode != "harbor":
		return
	var titles := {"jobs":"港と仲間の依頼帳", "routes":"次の遠征の航路", "exchange":"港の物資交換", "crew":"回収屋の休憩室"}
	var body := _open_modal(titles.get(page,"港の依頼帳"),560 if page == "crew" else 460)
	CampaignView.build(body,state,page,self)
	_resize_layout()

func _campaign_action(action: Dictionary, page: String) -> void:
	_close_modal()
	_act(action)
	if state.mode == "harbor":
		_campaign(page)

func _confirm_delivery(contract: Dictionary) -> void:
	var body := _open_modal("%sへ品を届ける" % Data.CHARACTERS[contract.character].name,340)
	body.add_child(_label(contract.title,20))
	for requirement: Dictionary in contract.requirements:
		body.add_child(_label("%s × %d" % [Data.ITEMS[requirement.kind].name,requirement.count],15))
	body.add_child(_label("上の品を倉庫から渡します。お礼は倉庫と港の所持金へ受け取ります。",14,UiPalette.MUTED))
	body.add_child(_button("品を渡して依頼を完了する",func(): _campaign_action({"type":"claim_contract","id":contract.id},"jobs"),true))
	body.add_child(_button("依頼帳へ戻る",func(): _campaign("jobs")))

func _confirm_sale(item: Dictionary) -> void:
	var needed: Array[String] = []
	for contract: Dictionary in Data.contracts(state):
		if contract.status == "claimed":
			continue
		for requirement: Dictionary in contract.requirements:
			if requirement.kind == item.kind:
				needed.append(contract.title)
	if needed.is_empty():
		_campaign_action({"type":"sell","uid":item.uid},"exchange")
		return
	var body := _open_modal("依頼にも使う品です",300)
	body.add_child(_label("%sを%d Gで売ります。" % [Data.ITEMS[item.kind].name,Data.ITEMS[item.kind].value],17))
	body.add_child(_label("使う依頼：" + " / ".join(needed),14,UiPalette.GOLD))
	body.add_child(_button("この品を売る",func(): _campaign_action({"type":"sell","uid":item.uid},"exchange"),true))
	body.add_child(_button("売らずに戻る",func(): _campaign("exchange")))

func _field_objective() -> String:
	var active: String = str(state.profile.activeContract)
	for contract: Dictionary in Data.contracts(state):
		if contract.id != active or contract.status == "claimed":
			continue
		var gathered := true
		for requirement: Dictionary in contract.requirements:
			var held: int = int(requirement.owned)
			for item: Dictionary in state.run.inventory:
				if item.kind == requirement.kind:
					held += 1
			if held < int(requirement.count):
				gathered = false
		if gathered:
			return "依頼の品が揃った。港へ戻ろう"
		return "%s / %s" % [Data.current_district(state).name,contract.title]
	return "%s / 自由回収" % Data.current_district(state).name

func _harbor_items(parent: Node, title: String, items: Array, action: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_label(title, 14, UiPalette.GOLD))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 145
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if items.is_empty():
		list.add_child(_label("ここに持ち出す品を。" if action == "unpack" else "品はありません。", 12, UiPalette.MUTED))
	for item: Dictionary in items:
		var uid: String = item.uid
		var button := _button(str(SHORT_NAMES[item.kind]), func(): _act({"type":action,"uid":uid}))
		button.icon = UiPalette.icon(item.kind)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		button.add_theme_font_size_override("font_size", 13)
		button.clip_text = true
		button.tooltip_text = Data.ITEMS[item.kind].name + " / " + Data.ITEMS[item.kind].description
		list.add_child(button)

func _basic_loadout() -> void:
	var picked: Array = []
	for item: Dictionary in state.profile.stash:
		if item.kind in ["knife", "coat", "medicine", "bomb", "flare"] and not picked.has(item.kind) and not _has_kind(state.loadout, item.kind):
			picked.append(item.kind)
			var response: Dictionary = Data.apply_action(state, {"type": "pack", "uid": item.uid})
			state = response.state
	_persist()
	_render()

func _expedition() -> void:
	content.add_theme_constant_override("separation", 7)
	var top := _panel(content, 9)
	var hud := HBoxContainer.new()
	top.add_child(hud)
	hud.add_child(_avatar(state.character, 48))
	var health := VBoxContainer.new()
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.add_theme_constant_override("separation", 3)
	hud.add_child(health)
	hp_label = _label("", 15)
	health.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 11
	hp_bar.show_percentage = false
	health.add_child(hp_bar)
	var counters := VBoxContainer.new()
	counters.custom_minimum_size.x = 82
	hud.add_child(counters)
	turn_label = _label("", 12, UiPalette.MUTED)
	bag_label = _label("", 13, UiPalette.GOLD)
	counters.add_child(turn_label)
	counters.add_child(bag_label)
	var tide_row := HBoxContainer.new()
	top.add_child(tide_row)
	tide_row.add_child(_icon("wave", 24))
	tide_label = _label("", 12, UiPalette.INK)
	tide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tide_row.add_child(tide_label)
	tide_meter = ProgressBar.new()
	tide_meter.custom_minimum_size = Vector2(68,8)
	tide_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tide_meter.max_value = 32
	tide_meter.show_percentage = false
	tide_row.add_child(tide_meter)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiPalette.box(Color("8ecfce"), Color("4b8d98"), 0))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(frame)
	board = BoardScene.instantiate()
	board.custom_minimum_size = Vector2(0,320)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(board)
	board.cell_selected.connect(_cell_selected)
	world_overlay = Control.new()
	world_overlay.z_index = 40
	world_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(world_overlay)
	var objective := PanelContainer.new()
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective.offset_left = 9
	objective.offset_right = -9
	objective.offset_top = 9
	objective.add_theme_stylebox_override("panel", UiPalette.box(Color(1,0.98,0.89,0.95), UiPalette.LINE, 7))
	world_overlay.add_child(objective)
	var goal_row := HBoxContainer.new()
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective.add_child(goal_row)
	goal_row.add_child(_icon("compass",22))
	objective_label = _label("",12)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_row.add_child(objective_label)
	cargo_value_label = _label("",12,UiPalette.GOLD)
	cargo_value_label.custom_minimum_size.x = 55
	cargo_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_row.add_child(cargo_value_label)
	var dock := CenterContainer.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -178
	dock.offset_bottom = -9
	world_overlay.add_child(dock)
	var controls := HBoxContainer.new()
	control_dock = controls
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.custom_minimum_size.x = minf(size.x-56,520)
	controls.add_theme_constant_override("separation",10)
	dock.add_child(controls)
	var pad := GridContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.columns = 3
	pad.add_theme_constant_override("h_separation",4)
	pad.add_theme_constant_override("v_separation",4)
	controls.add_child(pad)
	for entry: Array in [["",0,0],["↑",0,-1],["",0,0],["←",-1,0],["待つ",0,0],["→",1,0],["",0,0],["↓",0,1],["",0,0]]:
		if entry[0] == "":
			var blank := Control.new()
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blank.custom_minimum_size = Vector2(52,52)
			pad.add_child(blank)
		else:
			var dx: int = entry[1]
			var dy: int = entry[2]
			var button := _button(entry[0],func(): _direction(dx,dy))
			button.custom_minimum_size = Vector2(52,52)
			button.add_theme_font_size_override("font_size",12 if entry[0] == "待つ" else 24)
			button.tooltip_text = "一手待つ" if dx == 0 and dy == 0 else "一マス移動。隣の敵がいれば攻撃。"
			pad.add_child(button)
	var actions := VBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(actions)
	interact_button = _button("調べる",_interact,true)
	interact_button.icon = UiPalette.icon("chest")
	interact_button.expand_icon = true
	interact_button.add_theme_constant_override("icon_max_width",25)
	actions.add_child(interact_button)
	var bag := _button("持ち物 [I]",_inventory)
	bag.icon = UiPalette.icon("bag")
	bag.expand_icon = true
	bag.add_theme_constant_override("icon_max_width",24)
	actions.add_child(bag)
	var map_button := _button("地図 [M]",_map)
	map_button.icon = UiPalette.icon("map")
	map_button.expand_icon = true
	map_button.add_theme_constant_override("icon_max_width",24)
	actions.add_child(map_button)
	var radio := _panel(content,8)
	var radio_row := HBoxContainer.new()
	radio.add_child(radio_row)
	radio_row.add_child(_avatar(state.character,40))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",2)
	radio_row.add_child(words)
	status_label = _label("",11,UiPalette.GOLD)
	words.add_child(status_label)
	log_label = _label("",13)
	log_label.custom_minimum_size.y = 40
	words.add_child(log_label)
	_update_hud([])

func _update_hud(events: Array) -> void:
	if state.mode != "expedition":
		return
	var run: Dictionary = state.run
	var player: Dictionary = run.player
	var who: Dictionary = Data.CHARACTERS[state.character]
	hp_label.text = "%s  %d / %d" % [who.name,player.hp,player.maxHp]
	hp_bar.max_value = player.maxHp
	hp_bar.value = player.hp
	hp_label.add_theme_color_override("font_color",UiPalette.DANGER if player.hp <= player.maxHp*0.3 else UiPalette.INK)
	turn_label.text = "%03d 手" % int(run.turn)
	bag_label.text = "携行 %d/%d" % [run.inventory.size(),Data.stats(state).capacity]
	var remaining := 32*(int(run.tide)+1)-int(run.turn)
	var tides := ["干潮","満ち始め","上げ潮","満潮"]
	tide_label.text = "%s  /  あと%d手" % [tides[int(run.tide)],remaining] if run.tide < 3 else "満潮  /  高架を帰ろう"
	tide_meter.value = int(run.turn)%32 if run.tide < 3 else 32
	tide_label.add_theme_color_override("font_color",UiPalette.DANGER if run.tide < 3 and remaining <= 4 else UiPalette.INK)
	objective_label.text = _field_objective()
	cargo_value_label.text = "%d pt" % _value(run.inventory)
	var tile: Dictionary = run.tiles[int(player.y)][int(player.x)]
	var distance := absi(int(player.x)-int(run.exit.x))+absi(int(player.y)-int(run.exit.y))
	status_label.text = "%s / 帰還まで目安%dマス" % [tile.zone,distance]
	if not pending_item.is_empty():
		status_label.text = "使う方向を選ぶ / 設定・Escで取り消し"
	elif WorldDataFile.is_flooded(run,player.x,player.y):
		status_label.text = "浸水中 / 一手終えると体力−1。高架へ！"
	interact_button.text = "帰還する" if int(player.x)==int(run.exit.x) and int(player.y)==int(run.exit.y) else "調べる [E]"
	interact_button.icon = UiPalette.icon("anchor" if int(player.x)==int(run.exit.x) and int(player.y)==int(run.exit.y) else "chest")
	var lines: Array = []
	for entry: Dictionary in events:
		if entry.text not in ["1マス進んだ。","その場で様子を見た。"] and not lines.has(entry.text):
			lines.append(entry.text)
	if lines.is_empty():
		lines.append(_field_hint())
	if lines.size()>2:
		lines=lines.slice(lines.size()-2)
	log_label.text="\n".join(lines)
	board.present(state,events,settings.reduced)
	audio.set_scene("expedition",int(run.tide))

func _direction(dx: int, dy: int) -> void:
	if is_instance_valid(modal):
		return
	if dx == 0 and dy == 0:
		if pending_item.is_empty():
			_act({"type": "wait"})
		return
	if not pending_item.is_empty():
		var uid := pending_item
		pending_item = ""
		_act({"type": "use", "uid": uid, "dx": dx, "dy": dy})
	else:
		_act({"type": "move", "dx": dx, "dy": dy})

func _act(action: Dictionary) -> void:
	var response: Dictionary = Data.apply_action(state, action)
	state = response.state
	var events: Array = response.events
	_persist()
	for event: Dictionary in events:
		audio.play_event(event.type)
		harbor_feedback = event.text
	if state.mode != screen:
		_close_modal()
		_enter()
	elif screen == "expedition":
		_update_hud(events)
	elif screen == "harbor":
		_render()

func _interact() -> void:
	if state.mode != "expedition":
		return
	pending_item = ""
	var run: Dictionary = state.run
	if int(run.player.x) == int(run.exit.x) and int(run.player.y) == int(run.exit.y):
		var owned_count := 0
		for item: Dictionary in run.inventory:
			if item.kind != "loanKnife":
				owned_count += 1
		var body := _open_modal("港へ帰還", 180)
		body.add_child(_label("%d個の品を倉庫へ持ち帰ります。もう少し探すなら、戻って探索を続けられます。" % owned_count))
		if owned_count < run.inventory.size():
			body.add_child(_label("貸出ナイフは帰還時に返却します。", 13, UiPalette.MUTED))
		body.add_child(_button("持ち帰って遠征を終える", func():
			_close_modal()
			_act({"type": "interact"}), true))
	else:
		_act({"type": "interact"})

func _cell_selected(x: int, y: int) -> void:
	if state.mode != "expedition" or is_instance_valid(modal):
		return
	var run: Dictionary = state.run
	var visible: Dictionary = Data.visible_tiles(run)
	if not visible.has("%d,%d" % [x, y]):
		return
	var dx := x - int(run.player.x)
	var dy := y - int(run.player.y)
	if absi(dx) + absi(dy) == 1:
		_direction(dx, dy)
	elif dx == 0 and dy == 0:
		_interact()
	else:
		for enemy: Dictionary in run.enemies:
			if int(enemy.x) == x and int(enemy.y) == y:
				var body := _open_modal(Data.ENEMIES[enemy.kind].name, 160)
				body.add_child(_label(Data.ENEMIES[enemy.kind].description))
				body.add_child(_label("体力 %d  /  攻撃 %d" % [enemy.hp, Data.ENEMIES[enemy.kind].attack], 14, UiPalette.GOLD))
				return
		status_label.text = "隣のマスをタップして移動。離れた場所へは自動移動しません。"

func _open_modal(title: String, content_height: float = 540) -> VBoxContainer:
	_close_modal()
	# A freshly rebuilt screen must remain visible when its overlay pauses motion.
	for tween: Tween in ui_tweens:
		if tween != null and tween.is_valid() and tween.get_meta("screen_entry",false):
			tween.kill()
	content.modulate.a = 1.0
	inventory_detail = null
	inventory_slots.clear()
	modal_body_height = content_height
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(modal)
	var dark := ColorRect.new()
	dark.color = Color(0.09, 0.25, 0.29, 0.47)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dark)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	modal_panel = panel
	panel.custom_minimum_size.x = minf(540, overlay.size.x - 28)
	panel.add_theme_stylebox_override("panel", UiPalette.box(UiPalette.SURFACE, Color("629fa3"), 16))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(_section(title, "compass"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	modal_scroll = scroll
	scroll.custom_minimum_size = Vector2(0, minf(overlay.size.y - 205, modal_body_height))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var close := _button("閉じる", _close_modal)
	column.add_child(close)
	close.grab_focus()
	_sync_presentation()
	_animate_in(panel)
	return body

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
		modal_panel = null
		modal_scroll = null
		inventory_detail = null
		inventory_slots.clear()
	_sync_presentation()

func _inventory() -> void:
	if state.mode != "expedition":
		return
	var columns := 3 if size.x < 760 else 4
	var rows := ceili(float(state.run.inventory.size()) / columns)
	var body := _open_modal("回収鞄  %d / %d" % [state.run.inventory.size(),Data.stats(state).capacity],minf(300,32 + maxi(1,rows) * 92))
	var column := modal_scroll.get_parent()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",UiPalette.box(UiPalette.PAPER,UiPalette.LINE,10))
	column.add_child(panel)
	column.move_child(panel,1)
	inventory_detail = VBoxContainer.new()
	panel.add_child(inventory_detail)
	body.add_child(_label("読む間は手数が進みません。道具を選んで使おう。",12,UiPalette.MUTED))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	inventory_slots.clear()
	for item: Dictionary in state.run.inventory:
		var uid: String = item.uid
		var button := _button("",func(): _select_inventory(uid))
		button.custom_minimum_size=Vector2(83,86)
		button.tooltip_text=Data.ITEMS[item.kind].name
		button.set_meta("item_uid",uid)
		grid.add_child(button)
		var inner:=VBoxContainer.new()
		inner.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_top=6
		inner.offset_bottom=-5
		inner.add_theme_constant_override("separation",1)
		inner.alignment=BoxContainer.ALIGNMENT_CENTER
		button.add_child(inner)
		inner.add_child(_icon(item.kind,39))
		var name_label:=_label(str(SHORT_NAMES[item.kind]),12)
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(name_label)
		if uid==state.run.weapon or uid==state.run.armor:
			var equipped:=_label("装備中",10,UiPalette.SUCCESS)
			equipped.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(equipped)
		inventory_slots[uid]=button
	if state.run.inventory.is_empty():
		inventory_detail.add_child(_label("鞄は空です。荷箱を探してみよう。"))
	else:
		if not inventory_slots.has(inventory_selection):
			inventory_selection=state.run.inventory[0].uid
		_select_inventory(inventory_selection)
	_resize_layout()

func _result() -> void:
	var receipt: Dictionary=state.result
	var success: bool=receipt.outcome=="extracted"
	var who: Dictionary=Data.CHARACTERS[state.character]
	var hero_panel:=_panel(content,12)
	var hero:=HBoxContainer.new()
	hero.custom_minimum_size.y=180 if size.x<760 else 240
	hero_panel.add_child(hero)
	var stage := _crew_stage(state.character,Vector2(112 if size.x<760 else 180,180),"arrival" if success else "loss",success and not receipt.inventory.is_empty())
	hero.add_child(stage)
	var words:=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	hero.add_child(words)
	words.add_child(_label("WELCOME HOME" if success else "EXPEDITION LOST",11,UiPalette.SUCCESS if success else UiPalette.DANGER))
	words.add_child(_label("帰還成功" if success else "回収失敗",30,UiPalette.INK if success else UiPalette.DANGER))
	words.add_child(_label("%d手の遠征 / %d個を%s" % [receipt.turns,receipt.inventory.size(),"倉庫へ" if success else "失いました"],13))
	var result_line: String=who.lossLine if not success else who.emptyLine if receipt.inventory.is_empty() else who.returnLine
	words.add_child(_label("「%s」" % result_line,14))
	if not success:
		words.add_child(_label("原因：%s" % receipt.cause,13,UiPalette.DANGER))
	var paper:=_panel(content,12)
	(paper.get_parent() as Control).size_flags_vertical=Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var reward_row:=HBoxContainer.new()
	paper.add_child(reward_row)
	reward_row.add_child(_icon("star" if success else "bag",35))
	var heading:=_label("持ち帰った戦利品" if success else "失った携行品",20)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	reward_row.add_child(heading)
	var points:=_label("%d pt" % receipt.value,22,UiPalette.GOLD if success else UiPalette.DANGER)
	points.custom_minimum_size.x=80
	points.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	reward_row.add_child(points)
	paper.add_child(_rule())
	var scroll:=ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y=120
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=3 if size.x<760 else 6
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var index:=0
	for item: Dictionary in receipt.inventory:
		var tile:=_panel(grid,7)
		tile.add_child(_icon(item.kind,33))
		var label:=_label(str(SHORT_NAMES[item.kind]),12,UiPalette.INK if success else UiPalette.DANGER)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(label)
		_animate_in(tile,minf(index*0.06,0.65))
		index+=1
	if receipt.inventory.is_empty():
		grid.columns = 1
		var empty := _label("持ち帰った品はありません。" if success else "携行品はありませんでした。",14,UiPalette.MUTED)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(empty)
	var message: String="倉庫の品は残っています。次の支度を整えよう。" if not success else "港に戻りました。次の支度を整えよう。" if receipt.inventory.is_empty() else "戦利品を倉庫へ保管しました。次の遠征に持ち出せます。"
	paper.add_child(_label(message,13,UiPalette.MUTED))
	var retry:=_button("港で支度をする",func(): _act({"type":"return"}),true)
	content.add_child(retry)
	retry.grab_focus()
	if success and not settings.reduced:
		var value_tween:=create_tween()
		_track_tween(value_tween)
		value_tween.tween_method(func(value:float): points.text="%d pt" % roundi(value),0.0,float(receipt.value),0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _map() -> void:
	if state.mode != "expedition":
		return
	var body := _open_modal("回収屋の地図")
	var run: Dictionary = state.run
	var image := Image.create(run.width, run.height, false, Image.FORMAT_RGB8)
	var seen: Dictionary = {}
	for key: String in run.seen:
		seen[key] = true
	for y: int in run.height:
		for x: int in run.width:
			var color := Color("d3e3cf")
			if seen.has("%d,%d" % [x, y]):
				var tile: Dictionary = run.tiles[y][x]
				color = Color("fff1cc") if tile.type != "wall" else Color("8cb3a7")
				if tile.type == "water" or WorldDataFile.is_flooded(run, x, y):
					color = Color("48afb9")
				if tile.type == "exit":
					color = Color("e4b36b")
			image.set_pixel(x, y, color)
	image.set_pixel(run.player.x, run.player.y, Color("cc684d"))
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(280, 280)
	body.add_child(view)
	body.add_child(_label("赤い点：現在地 / 金色：帰還地点\n青：水路・浸水 / 地図は見えた範囲を記録します。", 14))
	var district: Dictionary = Data.current_district(state)
	body.add_child(_label("%s / %s" % [district.name,district.objective], 15, UiPalette.GOLD))

func _settings() -> void:
	pending_item = ""
	if screen == "expedition" and is_instance_valid(board):
		_update_hud([])
	var body := _open_modal("設定と中断",360)
	var sound := CheckButton.new()
	sound.text = "音を鳴らす"
	sound.custom_minimum_size.y = 52
	sound.button_pressed = settings.sound
	body.add_child(sound)
	sound.toggled.connect(func(value: bool):
		settings.sound = value
		audio.set_enabled(value)
		_set_notice(Store.save_settings(settings)) if not qa_session else _set_notice(""))
	var motion := CheckButton.new()
	motion.text = "動きを減らす"
	motion.custom_minimum_size.y = 52
	motion.button_pressed = settings.reduced
	body.add_child(motion)
	motion.toggled.connect(func(value: bool):
		settings.reduced = value
		if is_instance_valid(board):
			board.present(state, [], value)
		for stage: Control in crew_stages:
			if is_instance_valid(stage):
				stage.set_reduced_motion(value)
		scenery.configure(screen, value)
		_sync_presentation()
		_set_notice(Store.save_settings(settings)) if not qa_session else _set_notice(""))
	body.add_child(_label("一手が終わるたびに、このブラウザへ保存します。画面を閉じても、その手から再開できます。保存に失敗した場合は画面下に表示します。", 14, UiPalette.MUTED))
	body.add_child(_button("遊び方", _help))
	body.add_child(_button("タイトルへ戻る", func():
		_close_modal()
		screen = "title"
		_render()))

func _help() -> void:
	var body := _open_modal("回収屋の心得")
	for entry: Array in [["一手ずつ、考える", "矢印ボタン、矢印キー、WASDで一マス移動。隣の敵に向かって進むと攻撃します。長押しで連続移動しません。"], ["調べる・拾う", "荷箱の隣か上で「調べる」。Eキーでも操作できます。鞄に入りきらない品は、その場に残ります。"], ["道具で切り抜ける", "持ち物はIキー。救急包で回復し、爆薬で敵や壁を破壊し、発煙筒で敵を誘導できます。使用と装備変更は一手です。"], ["潮と敵を読む", "潮は32・64・96手で変わります。低い道は浸水すると一手ごとに体力を1失います。木の高架は沈みません。構えた鳥の正面からは横へ避けよう。"], ["持ち帰って初めて、自分の物", "南の船着き場で「帰還」。倒れると装備と携行品をすべて失います。倉庫の品は残り、武器がなくても貸出ナイフで再出発できます。"], ["最初の仕事", "北東の旧灯台で集光芯を見つけ、銅の端材と一緒に持ち帰ろう。港の灯りを修理すると、次回から視界が1マス広がります。"]]:
		body.add_child(_label(entry[0], 18, UiPalette.GOLD))
		body.add_child(_label(entry[1], 15))

func _persist() -> void:
	if qa_session or corrupt:
		return
	var error: String = Store.save_game(state)
	if error.is_empty():
		stored = true
	_set_notice(error)

func _set_notice(text: String) -> void:
	notice.text = text
	notice.visible = not text.is_empty()
	notice.add_theme_color_override("font_color", UiPalette.DANGER)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			_close_modal()
		elif not pending_item.is_empty():
			pending_item = ""
			_update_hud([])
		else:
			_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(modal):
		if event.keycode == KEY_TAB:
			var controls: Array = []
			_collect_focus(modal, controls)
			if not controls.is_empty():
				var index: int = controls.find(get_viewport().gui_get_focus_owner())
				controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
			get_viewport().set_input_as_handled()
		return
	if screen != "expedition":
		return
	if event.is_action_pressed("step_north"):
		_direction(0, -1)
	elif event.is_action_pressed("step_south"):
		_direction(0, 1)
	elif event.is_action_pressed("step_west"):
		_direction(-1, 0)
	elif event.is_action_pressed("step_east"):
		_direction(1, 0)
	elif event.is_action_pressed("wait_turn"):
		_direction(0, 0)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("inventory"):
		_inventory()
	elif event.is_action_pressed("area_map"):
		_map()
	else:
		return
	get_viewport().set_input_as_handled()

func _collect_focus(parent: Node, result: Array) -> void:
	for child: Node in parent.get_children():
		if child is BaseButton and child.visible and not child.disabled:
			result.append(child)
		_collect_focus(child, result)

func _notification(what: int) -> void:
	if not is_instance_valid(audio):
		return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_paused=true
		_sync_presentation()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_paused=false
		_sync_presentation()

func _icon(kind:String, pixels:int=32) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=UiPalette.icon(kind)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(pixels,pixels)
	image.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return image

func _avatar(character:String,pixels:int=48) -> PanelContainer:
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(pixels,pixels)
	panel.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=UiPalette.box(Color("d2e7d8"),Color("5e9298"),1)
	style.set_corner_radius_all(14)
	style.shadow_size=0
	panel.add_theme_stylebox_override("panel",style)
	var image:=TextureRect.new()
	image.texture=UiPalette.avatar(character)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)
	return panel

func _section(text:String,icon_id:String) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.add_child(_icon(icon_id,26))
	var label := _label(text,20)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

func _rule() -> Control:
	var motif:=Motif.new()
	motif.variant="rule"
	motif.custom_minimum_size.y=10
	return motif

func _value(items:Array) -> int:
	var total:=0
	for item:Dictionary in items:
		total+=int(Data.ITEMS[item.kind].value)
	return total

func _field_hint() -> String:
	var run:Dictionary=state.run
	if not pending_item.is_empty():
		return "矢印で投げる方向を選ぼう。取り消しはEsc・設定。"
	if run.player.hp<=run.player.maxHp*0.3:
		return "体力が少ない。救急包を使うか、高架で港へ戻ろう。"
	var visible:Dictionary=Data.visible_tiles(run)
	for enemy:Dictionary in run.enemies:
		if visible.has("%d,%d" % [enemy.x,enemy.y]) and enemy.has("intent"):
			return "鳥が構えている！正面から横へ一歩、避けよう。"
	if _field_objective().contains("揃った"):
		return "必要な品は確保したよ。帰りの道具を残して港へ戻ろう。"
	return Data.current_district(state).objective + "。荷箱は隣で調べられるよ。"

func _select_inventory(uid:String) -> void:
	if not is_instance_valid(inventory_detail) or not inventory_slots.has(uid):
		return
	inventory_selection=uid
	_clear(inventory_detail)
	var selected:Dictionary={}
	for item:Dictionary in state.run.inventory:
		if item.uid==uid:
			selected=item
	if selected.is_empty():
		return
	for key:String in inventory_slots:
		inventory_slots[key].add_theme_stylebox_override("normal",UiPalette.box(Color("f7d990") if key==uid else UiPalette.SURFACE,UiPalette.GOLD if key==uid else UiPalette.LINE,5))
	var info:Dictionary=Data.ITEMS[selected.kind]
	var equipped:bool=uid==state.run.weapon or uid==state.run.armor
	var row:=HBoxContainer.new()
	inventory_detail.add_child(row)
	row.add_child(_icon(selected.kind,42))
	var title:=_label(info.name+(" / 装備中" if equipped else ""),18)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	inventory_detail.add_child(_label(info.description,13,UiPalette.MUTED))
	var buttons:=HBoxContainer.new()
	inventory_detail.add_child(buttons)
	var kind:String=selected.kind
	if info.category=="consumable":
		var full_health: bool = kind == "medicine" and state.run.player.hp == state.run.player.maxHp
		var use_button := _button("体力は満タン" if full_health else "使う / 1手",func():
			_close_modal()
			if kind in ["bomb","flare"]:
				pending_item=uid
				_update_hud([])
			else:
				_act({"type":"use","uid":uid}))
		use_button.disabled = full_health
		buttons.add_child(use_button)
	elif info.category in ["weapon","armor"]:
		var equip:=_button("装備中" if equipped else "装備 / 1手",func():
			_close_modal()
			_act({"type":"equip","uid":uid}))
		equip.disabled=equipped
		buttons.add_child(equip)
	buttons.add_child(_button("置く / 1手",func():
		_close_modal()
		_act({"type":"drop","uid":uid})))

func _animate_in(control:Control,delay:float=0.0) -> void:
	if settings.reduced or qa_session:
		return
	control.modulate.a=0
	var tween:=control.create_tween()
	tween.set_meta("screen_entry",control == content)
	_track_tween(tween, is_instance_valid(modal) and modal.is_ancestor_of(control))
	if delay>0:
		tween.tween_interval(delay)
	tween.tween_property(control,"modulate:a",1.0,0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pulse(control:Control) -> void:
	if settings.reduced or qa_session:
		return
	control.pivot_offset=control.size*0.5
	var tween:=control.create_tween()
	_track_tween(tween, is_instance_valid(modal) and modal.is_ancestor_of(control))
	tween.tween_property(control,"scale",Vector2(0.97,0.97),0.045)
	tween.tween_property(control,"scale",Vector2.ONE,0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _sync_presentation() -> void:
	var paused:=focus_paused or is_instance_valid(modal)
	for stage: Control in crew_stages:
		if is_instance_valid(stage):
			stage.set_presentation_paused(paused)
	if is_instance_valid(scenery):
		scenery.set_presentation_paused(paused)
	if is_instance_valid(board) and board.has_method("set_presentation_paused"):
		board.set_presentation_paused(paused)
	if is_instance_valid(audio):
		audio.set_active(not paused)
	for tween:Tween in ui_tweens:
		if tween!=null and tween.is_valid():
			if focus_paused or (paused and not tween.get_meta("overlay",false)):
				tween.pause()
			else:
				tween.play()

func _track_tween(tween: Tween, on_overlay: bool = false) -> void:
	for i: int in range(ui_tweens.size()-1,-1,-1):
		if ui_tweens[i] == null or not ui_tweens[i].is_valid():
			ui_tweens.remove_at(i)
	tween.set_meta("overlay",on_overlay)
	ui_tweens.append(tween)
