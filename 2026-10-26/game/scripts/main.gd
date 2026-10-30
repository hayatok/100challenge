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
const ExpeditionHUD = preload("res://scenes/expedition_hud.tscn")
const HarborView = preload("res://scenes/presentation_v05/harbor.tscn")
const ResultView = preload("res://scenes/presentation_v05/result.tscn")
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
var pending_crew := false
var field_hud: Control
var harbor_view: Control
var result_view: Control
var safe_insets := Vector4.ZERO
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
var inventory_container := ""
var inventory_swap_uid := ""
var inventory_origin := "bag"
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
	get_viewport().gui_focus_changed.connect(func(_focused: Control): _sync_presentation())
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
	if is_instance_valid(field_hud):
		field_hud.call_deferred("_adapt")
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
	safe_insets = insets
	var base := 8 if screen == "expedition" else 18
	var safe: MarginContainer = %SafeFrame
	safe.add_theme_constant_override("margin_left", base + ceili(insets.x))
	safe.add_theme_constant_override("margin_top", base + ceili(insets.y))
	safe.add_theme_constant_override("margin_right", base + ceili(insets.z))
	safe.add_theme_constant_override("margin_bottom", base + ceili(insets.w))
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
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var preparation: Dictionary = harbor_view.capture_preparation_state() if screen == "harbor" and is_instance_valid(harbor_view) else {}
	for tween: Tween in ui_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	ui_tweens.clear()
	crew_stages.clear()
	last_size = size
	_clear(header)
	_clear(content)
	content.add_theme_constant_override("separation", 12)
	board = null
	field_hud = null
	harbor_view = null
	result_view = null
	control_dock = null
	world_overlay = null
	header.visible = screen != "expedition"
	backdrop.visible = screen != "expedition"
	_apply_safe_area(safe_insets)
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
	shade.color = Color("173f4d") if screen == "expedition" else Color(1, 0.98, 0.85, 0.07 if screen == "title" else 0.25)
	var success: bool = state.mode == "result" and state.result.outcome == "extracted"
	scenery.configure(screen, settings.reduced, success)
	audio.set_scene("result_extracted" if success else "result_dead" if screen == "result" else screen, int(state.run.tide) if state.run is Dictionary else 0)
	match screen:
		"title": _title()
		"harbor": _harbor(preparation)
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
	harbor_view = null
	screen = state.mode
	pending_item = ""
	_render()

func _mount_presentation(scene: PackedScene) -> Control:
	# These scrollable scenes consume the allocated viewport. Their temporary
	# wrapped-label minimum must not resize the application's outer VBox.
	var slot := Control.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(slot)
	var view: Control = scene.instantiate()
	slot.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.resized.connect(func(): view.set_deferred("size", slot.size))
	view.minimum_size_changed.connect(func(): view.set_deferred("size", slot.size))
	return view

func _harbor(preparation: Dictionary = {}) -> void:
	content.add_theme_constant_override("separation", 0)
	harbor_view = _mount_presentation(HarborView)
	harbor_view.character_requested.connect(func(character: String):
		audio.play_event("click")
		_act({"type":"choose", "character":character}))
	harbor_view.conversation_requested.connect(func():
		audio.play_event("click")
		_campaign("crew"))
	harbor_view.page_requested.connect(func(page: String):
		audio.play_event("click")
		_campaign(page))
	harbor_view.pack_requested.connect(func(uid: String):
		audio.play_event("click")
		_act({"type":"pack", "uid":uid}))
	harbor_view.unpack_requested.connect(func(uid: String):
		audio.play_event("click")
		_act({"type":"unpack", "uid":uid}))
	harbor_view.equip_requested.connect(func(uid: String): _act({"type":"equip", "uid":uid}))
	harbor_view.unpack_all_requested.connect(func(): _act({"type":"unpack_all"}))
	harbor_view.basic_loadout_requested.connect(func():
		audio.play_event("click")
		_basic_loadout())
	harbor_view.repair_requested.connect(func():
		audio.play_event("click")
		_act({"type":"repair"}))
	harbor_view.departure_requested.connect(func():
		audio.play_event("click")
		_act({"type":"depart"}))
	harbor_view.preparation_visibility_changed.connect(func(_open: bool): _sync_presentation())
	harbor_view.present(state, harbor_feedback)
	# The detailed portrait stays until a new character stage passes its art gate.
	if not preparation.is_empty():
		harbor_view.restore_preparation_state(preparation)

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
		if contract.status in ["claimed", "locked"]:
			continue
		if contract.id != active:
			if not active.is_empty() or contract.id not in Data.Campaign.STORY_IDS or contract.district != state.run.district:
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
			return "依頼品確保 / 帰還か、次の層へ" if state.run.has("depth") and int(state.run.depth) < 3 else "依頼の品が揃った。港へ戻ろう"
		return "%s / %s" % [Data.current_district(state).name,contract.title]
	return "%s / 自由回収" % Data.current_district(state).name

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
	content.add_theme_constant_override("separation", 0)
	field_hud = ExpeditionHUD.instantiate()
	content.add_child(field_hud)
	field_hud.direction_requested.connect(_direction)
	field_hud.interact_requested.connect(_interact)
	field_hud.inventory_requested.connect(_inventory)
	field_hud.map_requested.connect(_map)
	field_hud.crew_requested.connect(_crew_action)
	field_hud.settings_requested.connect(_settings)
	field_hud.feedback_requested.connect(func(): audio.play_event("click"))
	field_hud.portrait.texture = UiPalette.avatar(state.character)
	hp_label = field_hud.hp_label
	hp_bar = field_hud.hp_bar
	tide_label = field_hud.tide_label
	bag_label = field_hud.bag_label
	turn_label = field_hud.turn_label
	objective_label = field_hud.objective_label
	cargo_value_label = field_hud.value_label
	log_label = field_hud.status_label
	status_label = field_hud.status_label
	interact_button = field_hud.interact_button
	control_dock = field_hud.controls
	world_overlay = field_hud.controls_panel
	board = BoardScene.instantiate()
	board.custom_minimum_size = Vector2.ZERO
	field_hud.world_slot.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.cell_selected.connect(_cell_selected)
	_update_hud([])

func _crew_action() -> void:
	if state.mode != "expedition":
		return
	pending_item = ""
	if pending_crew:
		pending_crew = false
		_update_hud([])
		return
	var info: Dictionary = Data.crew_info(state)
	var body := _open_modal(str(info.name), 250)
	body.add_child(_label(str(info.description)))
	body.add_child(_label("残り %d / %d回。この遠征の間だけ使えます。" % [info.charges, info.maxCharges], 14, UiPalette.GOLD))
	var use := _button("方向を選ぶ / 1手" if info.targeted else "使う / 1手", func():
		_close_modal()
		if bool(info.targeted):
			pending_crew = true
			_update_hud([])
		else:
			_act({"type": "crew"}), true)
	use.disabled = not bool(info.available)
	body.add_child(use)
	if not bool(info.available):
		body.add_child(_label(str(info.get("reason", "今の状況では使えません。")), 14))

func _update_hud(events: Array) -> void:
	if state.mode != "expedition":
		return
	var run: Dictionary = state.run
	var player: Dictionary = run.player
	var who: Dictionary = Data.CHARACTERS[state.character]
	hp_label.text = "%s  %d / %d" % [who.name,player.hp,player.maxHp]
	hp_bar.max_value = player.maxHp
	hp_bar.value = player.hp
	hp_label.add_theme_color_override("font_color",Color("ffb99a") if player.hp <= player.maxHp*0.3 else Color("fff6dc"))
	turn_label.text = "%d層 · %d手" % [int(run.depth), int(run.turn)] if run.has("depth") else "%03d 手" % int(run.turn)
	bag_label.text = "%d/%d" % [run.inventory.size(),Data.stats(state).capacity]
	var remaining := 32*(int(run.tide)+1)-int(run.turn)
	var tides := ["干潮","満ち始め","上げ潮","満潮"]
	tide_label.text = "%s  /  あと%d手" % [tides[int(run.tide)],remaining] if run.tide < 3 else "満潮  /  高架を帰ろう"
	tide_label.add_theme_color_override("font_color",Color("ffba99") if run.tide < 3 and remaining <= 4 else Color("c1e2d6"))
	objective_label.text = _field_objective()
	cargo_value_label.text = "%d pt" % _value(run.inventory)
	var tile: Dictionary = run.tiles[int(player.y)][int(player.x)]
	var distance := absi(int(player.x)-int(run.exit.x))+absi(int(player.y)-int(run.exit.y))
	var field_status := ""
	if not pending_item.is_empty():
		field_status = "道具を使う方向を選ぶ / Escで取り消し"
	elif pending_crew:
		field_status = "技を使う方向を選ぶ / Escで取り消し"
	elif WorldDataFile.is_flooded(run,player.x,player.y):
		field_status = "浸水中 / 一手終えると体力−1。高架へ！"
	interact_button.text = "帰還する" if int(player.x)==int(run.exit.x) and int(player.y)==int(run.exit.y) else "調べる [E]"
	interact_button.icon = UiPalette.icon("anchor" if int(player.x)==int(run.exit.x) and int(player.y)==int(run.exit.y) else "chest")
	if run.get("ruleset") == "expedition-v06" and not (player.x == run.exit.x and player.y == run.exit.y):
		if player.x == run.stairs.x and player.y == run.stairs.y and int(run.depth) < 3:
			interact_button.text = "%d層へ進む [E]" % (int(run.depth) + 1)
		elif not Data.nearby_containers(state).is_empty():
			interact_button.text = "荷箱を開く [E]"
	objective_label.tooltip_text = Data.current_district(state).objective
	var lines: Array = []
	for entry: Dictionary in events:
		if entry.text not in ["1マス進んだ。","その場で様子を見た。"] and not lines.has(entry.text):
			lines.append(entry.text)
	if not field_status.is_empty():
		field_hud.show_feedback(field_status, true)
	elif not lines.is_empty():
		field_hud.show_feedback(str(lines.back()))
	elif events.is_empty():
		field_hud.clear_feedback()
	var crew: Dictionary = Data.crew_info(state)
	field_hud.crew_button.text = "技を取り消す" if pending_crew else "%s  %d/%d" % [crew.name,crew.charges,crew.maxCharges]
	field_hud.crew_button.tooltip_text = str(crew.description)
	var previews: Dictionary = {}
	for step: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ZERO]:
		var action := {"type":"crew" if pending_crew else "wait" if step == Vector2i.ZERO else "move", "dx":step.x, "dy":step.y}
		if not pending_item.is_empty():
			action = {"type":"use", "uid":pending_item, "dx":step.x, "dy":step.y}
		previews["%d,%d" % [step.x,step.y]] = Data.preview_action(state, action)
	field_hud.show_previews(previews)
	board.present(state,events,settings.reduced)
	audio.set_scene("expedition",int(run.tide))

func _direction(dx: int, dy: int) -> void:
	if is_instance_valid(modal):
		return
	if dx == 0 and dy == 0:
		if pending_item.is_empty() and not pending_crew:
			_act({"type": "wait"})
		return
	if pending_crew:
		pending_crew = false
		_act({"type":"crew", "dx":dx, "dy":dy})
	elif not pending_item.is_empty():
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
		if event.type == "extract":
			var amount: int = int(event.amount)
			harbor_feedback = "持ち帰った品はありません。" if amount == 0 else "%d個の品を倉庫に持ち帰りました。" % amount
		else:
			harbor_feedback = event.text
	if state.mode != screen:
		_close_modal()
		_enter()
	elif screen == "expedition":
		_update_hud(events)
	elif screen == "harbor":
		_render()

func _interact() -> void:
	pending_crew = false
	if state.mode != "expedition":
		return
	pending_item = ""
	var run: Dictionary = state.run
	if int(run.player.x) == int(run.exit.x) and int(run.player.y) == int(run.exit.y):
		var owned_count := 0
		for item: Dictionary in run.inventory:
			if item.kind != "loanKnife":
				owned_count += 1
		var body := _open_modal("港へ帰還", 200)
		body.add_child(_label("%d個の品を倉庫へ持ち帰ります。探索を続けるなら、閉じて戻れます。" % owned_count))
		if owned_count < run.inventory.size():
			body.add_child(_label("貸出ナイフは帰還時に返却します。", 13, UiPalette.MUTED))
		body.add_child(_button("持ち帰って遠征を終える", func():
			_close_modal()
			_act({"type": "interact"}), true))
	elif run.get("ruleset") == "expedition-v06":
		var nearby: Array = Data.nearby_containers(state)
		var at_stairs: bool = run.player.x == run.stairs.x and run.player.y == run.stairs.y and int(run.depth) < 3
		if at_stairs and nearby.is_empty():
			_confirm_advance()
		elif nearby.size() == 1 and not at_stairs:
			_open_container(str(nearby[0].id))
		elif not nearby.is_empty() or at_stairs:
			var body := _open_modal("ここでできること", 260)
			for cache: Dictionary in nearby:
				var id: String = cache.id
				body.add_child(_button("%s / %s" % [cache.name, "開く・0手" if cache.searched else "調査・1手"], func(): _open_container(id)))
			if at_stairs:
				body.add_child(_button("次の層へ進む", _confirm_advance, true))
		else:
			field_hud.show_feedback("荷箱の隣で調べる。通路の旗から次の層へ進めます。")
	else:
		_act({"type": "interact"})

func _open_container(id: String) -> void:
	_close_modal()
	var unopened := false
	for cache: Dictionary in Data.nearby_containers(state):
		if cache.id == id:
			unopened = not cache.searched
	if unopened:
		_act({"type":"interact", "containerId":id})
	if state.mode == "expedition":
		inventory_selection = ""
		inventory_swap_uid = ""
		_inventory(id)

func _confirm_advance() -> void:
	if state.mode != "expedition":
		return
	var body := _open_modal("%d層へ進む" % (int(state.run.depth) + 1), 280)
	body.add_child(_label("持ち帰るか、もう一層探すか。", 21))
	body.add_child(_label("体力 %d/%d  /  携行 %d/%d" % [state.run.player.hp, state.run.player.maxHp, state.run.inventory.size(), Data.stats(state).capacity], 16, UiPalette.GOLD))
	body.add_child(_label("進むと1手が経過します。体力・道具・技の残り回数は引き継ぎます。この層の箱や置いた品には戻れません。次の層にも帰還地点があります。", 14))
	body.add_child(_button("荷を持って先へ進む / 1手", func():
		_close_modal()
		_act({"type":"advance"}), true))
	body.add_child(_button("この層の探索へ戻る", _close_modal))

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
		field_hud.show_feedback("隣のマスをタップして移動。離れた場所へは自動移動しません。")

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

func _inventory(container_id: String = "") -> void:
	pending_crew = false
	pending_item = ""
	if state.mode != "expedition":
		return
	inventory_container = container_id
	if container_id.is_empty():
		inventory_swap_uid = ""
		inventory_origin = "bag"
	var capacity: int = Data.stats(state).capacity
	var contents: Array = Data.container_contents(state, container_id) if not container_id.is_empty() else []
	var title := "荷箱と回収鞄" if not container_id.is_empty() else "回収鞄  %d / %d" % [state.run.inventory.size(), capacity]
	var body := _open_modal(title, 370)
	body.add_theme_constant_override("separation", 9)
	var column := modal_scroll.get_parent()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.box(UiPalette.PAPER, UiPalette.LINE, 10))
	column.add_child(panel)
	column.move_child(panel, column.get_child_count() - 2)
	inventory_detail = VBoxContainer.new()
	inventory_detail.add_theme_constant_override("separation", 6)
	panel.add_child(inventory_detail)
	var derived: Dictionary = Data.stats(state)
	var summary := "体力 %d/%d  ·  携行 %d/%d\n攻撃 %d / 防御 %d" % [state.run.player.hp, state.run.player.maxHp, state.run.inventory.size(), capacity, derived.attack, derived.defense]
	body.add_child(_label(summary, 15, UiPalette.INK))
	body.add_child(_label("読む・選ぶ操作は0手。回収・交換・装備・使用・置く操作は各1手。", 12, UiPalette.MUTED))
	inventory_slots.clear()
	if not container_id.is_empty():
		var heading := HBoxContainer.new()
		body.add_child(heading)
		heading.add_child(_label("箱に残っている品  %d" % contents.size(), 16))
		var take_all := _button("入る分を回収", func(): _cargo_action({"type":"take_all", "containerId":container_id}))
		take_all.set_meta("cargo_action", "take_all")
		take_all.size_flags_horizontal = Control.SIZE_SHRINK_END
		take_all.disabled = contents.is_empty() or state.run.inventory.size() >= capacity
		heading.add_child(take_all)
		if contents.is_empty():
			body.add_child(_label("この箱は空です。鞄の品を置くと、足元の荷箱に残ります。", 14, UiPalette.MUTED))
		else:
			_cargo_grid(body, contents, "cache")
		body.add_child(_rule())
	body.add_child(_label("自分の鞄" + (" / 交換する品を選ぶ" if not inventory_swap_uid.is_empty() else ""), 16))
	_cargo_grid(body, state.run.inventory, "bag")
	if state.run.inventory.is_empty():
		inventory_detail.add_child(_label("鞄は空です。箱から持ち帰る品を選ぼう。"))
	elif inventory_slots.has(inventory_selection):
		_select_inventory(inventory_selection, str(inventory_slots[inventory_selection].get_meta("item_origin", "bag")))
	elif not inventory_swap_uid.is_empty() and not state.run.inventory.is_empty():
		_select_inventory(str(state.run.inventory[0].uid), "bag")
	elif not contents.is_empty():
		_select_inventory(str(contents[0].uid), "cache")
	else:
		_select_inventory(str(state.run.inventory[0].uid), "bag")
	if inventory_slots.has(inventory_selection):
		inventory_slots[inventory_selection].call_deferred("grab_focus")
	_resize_layout()

func _cargo_grid(body: VBoxContainer, items: Array, origin: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3 if size.x < 760 else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	for item: Dictionary in items:
		var uid: String = item.uid
		var button := _button("", func(): _select_inventory(uid, origin))
		button.custom_minimum_size = Vector2(76, 83)
		button.tooltip_text = Data.ITEMS[item.kind].name
		button.accessibility_name = Data.ITEMS[item.kind].name + (" / 箱の品" if origin == "cache" else " / 携行品")
		button.set_meta("item_uid", uid)
		button.set_meta("item_origin", origin)
		grid.add_child(button)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_top = 4
		inner.offset_bottom = -4
		inner.add_theme_constant_override("separation", 0)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(inner)
		inner.add_child(_icon(item.kind, 32))
		var caption := _label(str(SHORT_NAMES.get(item.kind, Data.ITEMS[item.kind].name)), 12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(caption)
		var badge := "装備中" if origin == "bag" and uid in [state.run.weapon, state.run.armor] else "依頼の品" if not _item_purpose(str(item.kind)).is_empty() else "%d G" % Data.ITEMS[item.kind].value
		var note := _label(badge, 10, UiPalette.SUCCESS if badge == "装備中" else UiPalette.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(note)
		inventory_slots[uid] = button

func _item_purpose(kind: String) -> String:
	for contract: Dictionary in Data.contracts(state):
		if contract.status in ["claimed", "locked"]:
			continue
		for requirement: Dictionary in contract.requirements:
			if requirement.kind == kind:
				var carried := 0
				for item: Dictionary in state.run.inventory if state.run is Dictionary else state.loadout:
					if item.kind == kind: carried += 1
				return "%s  倉庫%d＋携行%d / 必要%d" % [contract.title, requirement.owned, carried, requirement.count]
	return ""

func _cargo_action(action: Dictionary) -> void:
	var cache := inventory_container
	var scroll_offset := modal_scroll.scroll_vertical if is_instance_valid(modal_scroll) else 0
	_act(action)
	if state.mode == "expedition":
		inventory_swap_uid = ""
		_inventory(cache)
		if is_instance_valid(modal_scroll):
			modal_scroll.set_deferred("scroll_vertical", scroll_offset)

func _result() -> void:
	content.add_theme_constant_override("separation", 0)
	result_view = _mount_presentation(ResultView)
	result_view.continue_requested.connect(func():
		audio.play_event("click")
		_act({"type":"return"}))
	result_view.present(state)
	var receipt: Dictionary = state.result
	var success: bool = receipt.outcome == "extracted"
	var stage := _crew_stage(state.character, Vector2.ZERO, "arrival" if success else "loss", success and not receipt.inventory.is_empty())
	result_view.attach_stage(stage)

func _map() -> void:
	if state.mode != "expedition":
		return
	var body := _open_modal("回収屋の地図 / %d層" % int(state.run.depth) if state.run.has("depth") else "回収屋の地図")
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
	if run.has("stairs") and int(run.depth) < 3 and seen.has("%d,%d" % [run.stairs.x, run.stairs.y]):
		image.set_pixel(run.stairs.x, run.stairs.y, Color("ac67ba"))
	image.set_pixel(run.player.x, run.player.y, Color("cc684d"))
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(280, 280)
	body.add_child(view)
	body.add_child(_label("赤い点：現在地 / 金色：帰還地点\n紫：次の層 / 青：水路・浸水\n地図は見えた範囲を記録します。", 14))
	var district: Dictionary = Data.current_district(state)
	body.add_child(_label("%s / %s" % [district.name,district.objective], 15, UiPalette.GOLD))
	if run.has("depth"):
		body.add_child(_label("遠征 #%d · 第%d層" % [state.profile.runs, run.depth], 14, UiPalette.MUTED))
		body.add_child(_label("旗の帰還地点に立って調べると港へ。数字の通路は次の層へ進みます。", 13))

func _settings() -> void:
	pending_item = ""
	pending_crew = false
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
	var old_run: bool = state.get("run") is Dictionary and state.run.get("ruleset") != "expedition-v06"
	var entries: Array = [
		["一手ずつ考える", "方向ボタン・矢印キー・WASDで1マス移動。隣の敵へ進むと攻撃します。長押しでは連続移動しません。"],
		["品を選んで持ち帰る", "荷箱の隣でEか『調べる』。調査に1手、品の回収に1手かかります。読む・選ぶ操作は0手。満杯でも箱の品と携行品1個を1手で交換できます。"],
		["帰還か、次の層か", "地形・荷箱・敵は遠征ごとに変わります。数字の旗に立って調べると次の層へ進みます。最大3層で、各層から帰還できます。前の層に残した品には戻れません。"],
		["道具と仲間の技", "持ち物はI、技はQ。救急包で回復、爆薬で敵や壁を破壊、発煙筒で敵を誘導できます。技は遠征全体で3回。取り消しや効果のない使用では手数も回数も減りません。"],
		["潮と敵を読む", "潮は32・64・96手で変化します。浸水した低い道で一手を終えると体力−1。高い道は沈みません。構えた敵の正面から横へ避けよう。"],
		["帰還で荷を確保する", "旗がある船着き場に立って調べると港へ戻れます。倒れると装備・携行品をすべて失い、倉庫と完了した依頼は残ります。武器がなくても貸出ナイフで再出発できます。"],
		["最初の依頼", "波止場の1層目を探し、金枠の荷箱から集光芯と銅の端材を持ち帰ろう。港で納品すると灯りが直り、市場への航路と次の依頼が開きます。" ]]
	if old_run:
		entries[1][1] = "この遠征は旧ルールで続きます。荷箱の隣で調べると、入る分を回収します。"
		entries[2][1] = "この遠征は更新前の地形を保っています。港へ帰って次に出発すると、毎回変わる最大3層の探索に切り替わります。"
		if state.run.get("ruleset") == "legacy-v03":
			entries[3][1] = "この遠征では仲間の技は使えません。Iで鞄を開き、救急包・爆薬・発煙筒を使えます。"
		entries[6][1] = Data.current_district(state).objective + "。港へ持ち帰り、倉庫から納品します。"
	for entry: Array in entries:
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
		elif screen == "harbor" and is_instance_valid(harbor_view) and harbor_view.preparation_open:
			harbor_view.close_preparation()
		elif not pending_item.is_empty() or pending_crew:
			pending_item = ""
			pending_crew = false
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
	elif event.keycode == KEY_Q:
		_crew_action()
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
	if _field_objective().contains("揃った") or _field_objective().contains("依頼品確保"):
		return "依頼品は確保した。帰還すれば納品できる。先へ進むなら道具と体力を確かめよう。"
	return Data.current_district(state).objective + "。荷箱は隣で調べよう。"

func _select_inventory(uid: String, origin: String = "bag") -> void:
	if not is_instance_valid(inventory_detail) or not inventory_slots.has(uid):
		return
	inventory_selection = uid
	inventory_origin = origin
	_clear(inventory_detail)
	var items: Array = state.run.inventory if origin == "bag" else Data.container_contents(state, inventory_container)
	var selected: Dictionary = Data._find_item(items, uid)
	if selected.is_empty():
		return
	for key: String in inventory_slots:
		inventory_slots[key].add_theme_stylebox_override("normal", UiPalette.box(Color("f7d990") if key == uid else UiPalette.SURFACE, UiPalette.GOLD if key == uid else UiPalette.LINE, 5))
	var info: Dictionary = Data.ITEMS[selected.kind]
	var equipped: bool = origin == "bag" and uid in [state.run.weapon, state.run.armor]
	var row := HBoxContainer.new()
	inventory_detail.add_child(row)
	row.add_child(_icon(selected.kind, 32))
	row.add_child(_label(info.name + (" / 装備中" if equipped else ""), 17))
	inventory_detail.add_child(_label(info.description, 12, UiPalette.MUTED))
	var purpose := _item_purpose(selected.kind)
	if not purpose.is_empty():
		inventory_detail.add_child(_label(purpose, 12, UiPalette.SUCCESS))
	if info.category in ["weapon", "armor"] and not equipped and inventory_swap_uid.is_empty():
		var stat_key := "attack" if info.category == "weapon" else "defense"
		var current: Dictionary = Data._find_item(state.run.inventory, state.run[info.category])
		var old_value: int = int(Data.ITEMS[current.kind].get(stat_key, 0)) if not current.is_empty() else 0
		inventory_detail.add_child(_label("%s %d → %d" % ["装備した場合の攻撃" if stat_key == "attack" else "装備した場合の防御", old_value, int(info.get(stat_key, 0))], 13, UiPalette.GOLD))
	var buttons := HBoxContainer.new()
	inventory_detail.add_child(buttons)
	if origin == "cache":
		var full: bool = state.run.inventory.size() >= int(Data.stats(state).capacity)
		var take := _button("鞄は満杯" if full else "回収 / 1手", func(): _cargo_action({"type":"take", "containerId":inventory_container, "uid":uid}), true)
		take.disabled = full
		take.set_meta("cargo_action", "take")
		buttons.add_child(take)
		buttons.add_child(_button("携行品と交換", func():
			inventory_swap_uid = uid
			inventory_selection = ""
			inventory_origin = "bag"
			_inventory(inventory_container)))
	elif not inventory_swap_uid.is_empty():
		var target: Dictionary = Data._find_item(Data.container_contents(state, inventory_container), inventory_swap_uid)
		if not target.is_empty():
			inventory_detail.add_child(_label("この品を箱へ置き、%sを回収します。%s" % [Data.ITEMS[target.kind].name, "装備も外れます。" if equipped else ""], 12))
			buttons.add_child(_button("この品と交換 / 1手", func(): _cargo_action({"type":"swap", "containerId":inventory_container, "uid":inventory_swap_uid, "dropUid":uid}), true))
		buttons.add_child(_button("交換をやめる", func():
			inventory_swap_uid = ""
			_inventory(inventory_container)))
	else:
		var kind: String = selected.kind
		if info.category == "consumable":
			var full_health: bool = kind == "medicine" and state.run.player.hp == state.run.player.maxHp
			var use_button := _button("体力は満タン" if full_health else "使う / 1手", func():
				if kind in ["bomb", "flare"]:
					_close_modal()
					pending_item = uid
					_update_hud([])
				else:
					_cargo_action({"type":"use", "uid":uid}))
			use_button.disabled = full_health
			buttons.add_child(use_button)
		elif info.category in ["weapon", "armor"]:
			var equip := _button("装備中" if equipped else "装備 / 1手", func(): _cargo_action({"type":"equip", "uid":uid}))
			equip.disabled = equipped
			buttons.add_child(equip)
		buttons.add_child(_button("置く / 1手", func(): _cargo_action({"type":"drop", "uid":uid})))
	_resize_layout()

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
	var reading_preparation: bool = screen == "harbor" and is_instance_valid(harbor_view) and harbor_view.preparation_open
	if not reading_preparation and screen == "harbor" and is_instance_valid(harbor_view):
		var focused: Control = get_viewport().gui_get_focus_owner()
		reading_preparation = is_instance_valid(focused) and harbor_view.preparation_scroll.is_ancestor_of(focused)
	var blocked: bool = focus_paused or is_instance_valid(modal)
	var paused: bool = blocked or reading_preparation
	if is_instance_valid(field_hud):
		field_hud.set_paused(paused)
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
		if tween!=null and tween.is_valid() and tween.get_loops_left() != 0:
			if focus_paused or (blocked and not tween.get_meta("overlay",false)):
				tween.pause()
			else:
				tween.play()

func _track_tween(tween: Tween, on_overlay: bool = false) -> void:
	for i: int in range(ui_tweens.size()-1,-1,-1):
		if ui_tweens[i] == null or not ui_tweens[i].is_valid() or ui_tweens[i].get_loops_left() == 0:
			ui_tweens.remove_at(i)
	tween.set_meta("overlay",on_overlay)
	ui_tweens.append(tween)
