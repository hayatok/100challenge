extends PanelContainer
## A read-only preparation view. Main owns all rule actions and persistence.
signal character_requested(character: String)
signal conversation_requested()
signal page_requested(page: String)
signal pack_requested(uid: String)
signal unpack_requested(uid: String)
signal equip_requested(uid: String)
signal unpack_all_requested()
signal basic_loadout_requested()
signal repair_requested()
signal departure_requested()
signal preparation_visibility_changed(open: bool)

const Data = preload("res://scripts/rules.gd")
const UI = preload("res://scripts/presentation_v05/presentation.gd")
const Palette = preload("res://scripts/ui_theme.gd")
@onready var stage_slot: Control = %StageSlot
@onready var departure_button: Button = %Departure
@onready var preparation_scroll: ScrollContainer = %PreparationScroll
var preparation_open := false
var focused_item_uid := ""
var _restore_ticket := 0
var _equipped_uids: Array[String] = []
var _needed_kinds: Dictionary = {}
var _inspection_uid := ""
var _owned_items: Array = []

func _ready() -> void:
	theme = UI.make_theme()
	UI.primary(departure_button)
	for button: Button in [%Conversation, %Jobs, %Routes, %Exchange, %BasicLoadout, %OpenPreparation, %ClosePreparation, %UnpackAll]:
		UI.secondary(button)
	%OpenPreparation.pressed.connect(func():
		if preparation_open: close_preparation()
		else: open_preparation())
	%ClosePreparation.pressed.connect(close_preparation)
	departure_button.call_deferred("grab_focus")
	preparation_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	%Conversation.pressed.connect(func(): conversation_requested.emit())
	%Jobs.pressed.connect(func(): page_requested.emit("jobs"))
	%Routes.pressed.connect(func(): page_requested.emit("routes"))
	%Exchange.pressed.connect(func(): page_requested.emit("exchange"))
	%BasicLoadout.pressed.connect(func(): basic_loadout_requested.emit())
	%Repair.pressed.connect(func(): repair_requested.emit())
	%UnpackAll.pressed.connect(func(): unpack_all_requested.emit())
	departure_button.pressed.connect(func(): departure_requested.emit())
	resized.connect(_adapt)
	_adapt()

func attach_stage(stage: Control) -> void:
	UI.clear(stage_slot)
	stage.custom_minimum_size = Vector2.ZERO
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_slot.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	%Portrait.visible = false

func present(state: Dictionary, feedback_text: String = "") -> void:
	var previous := capture_preparation_state()
	var who: Dictionary = Data.CHARACTERS[state.character]
	%Portrait.texture = Palette.portrait(state.character)
	%CrewName.text = who.name
	%Role.text = who.role + " / " + who.trait
	%Conversation.text = "%sと話す" % who.name
	%Conversation.tooltip_text = who.idleLine
	%Feedback.text = feedback_text
	%Feedback.visible = not feedback_text.is_empty()
	var progress: Dictionary = Data.campaign_summary(state)
	%District.text = Data.current_district(state).name
	%Progress.text = "復興 %d/%d" % [progress.completed, progress.total]
	%Exchange.tooltip_text = "港の所持金 %d G" % state.profile.credits
	%Mission.text = UI.mission(state)
	UI.clear(%Roster)
	for id: String in Data.CHARACTERS:
		var button := Button.new()
		button.text = ""
		button.accessibility_name = Data.CHARACTERS[id].name
		var portrait := TextureRect.new()
		portrait.texture = Palette.avatar(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(28, 28)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 0)
		button.add_child(inner)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_top = 3
		inner.offset_bottom = -3
		inner.add_child(portrait)
		var name_label := UI.label(Data.CHARACTERS[id].name, 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(name_label)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 31)
		button.add_theme_constant_override("h_separation", 2)
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(48, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.set_meta("character_id", id)
		button.tooltip_text = Data.CHARACTERS[id].name + " / " + Data.CHARACTERS[id].trait
		button.disabled = state.loadout.size() > (14 if id == "isana" else 12)
		if button.disabled:
			button.tooltip_text += " / 携行品を12個以下にしてから交代"
		if state.character == id:
			button.add_theme_stylebox_override("normal", Palette.box(Color("c5e1d9"), Palette.SUCCESS, 4))
			button.tooltip_text += " / 選択中"
		button.pressed.connect(func(): character_requested.emit(id))
		%Roster.add_child(button)
	var stats: Dictionary = Data.stats(state)
	%OpenPreparation.set_meta("carry_caption", "荷物 %d/%d" % [state.loadout.size(), stats.capacity])
	%CarryTitle.text = "携行品  %d / %d" % [state.loadout.size(), stats.capacity]
	%StashTitle.text = "倉庫  %d" % state.profile.stash.size()
	%Stats.text = "準備中の能力  攻撃 %d / 防御 %d / 体力 %d" % [stats.attack, stats.defense, stats.maxHp]
	_equipped_uids.clear()
	_owned_items = state.loadout + state.profile.stash
	_needed_kinds.clear()
	for job: Dictionary in Data.contracts(state):
		if job.status in ["claimed", "locked"]:
			continue
		for requirement: Dictionary in job.requirements:
			_needed_kinds[requirement.kind] = true
	for category: String in ["weapon", "armor"]:
		var equipped: Dictionary = {}
		for item: Dictionary in state.loadout:
			if Data.ITEMS[item.kind].category != category:
				continue
			if state.get("version", 3) >= 4:
				if item.uid != state.preparation[category]:
					continue
			equipped = item
			_equipped_uids.append(item.uid)
			break
		_present_equipment_slot(%WeaponSlot if category == "weapon" else %ArmorSlot, equipped)
	%CarryItems.visible = true
	%UnpackAll.disabled = state.loadout.is_empty()
	%CapacityHint.visible = state.loadout.size() >= stats.capacity
	_fill_items(%CarryItems, state.loadout, false, false)
	_fill_items(%StashItems, state.profile.stash, true, state.loadout.size() >= stats.capacity)
	_inspect_item(str(previous.get("inspection_uid", _inspection_uid)))
	var kinds: Array[String] = []
	var candidates: Array[String] = []
	for item: Dictionary in state.loadout:
		kinds.append(item.kind)
	for item: Dictionary in state.profile.stash:
		if item.kind in ["knife", "coat", "medicine", "bomb", "flare"] and item.kind not in kinds:
			kinds.append(item.kind)
			candidates.append(Data.ITEMS[item.kind].name)
	%BasicLoadout.disabled = candidates.is_empty() or state.loadout.size() >= stats.capacity
	%BasicHint.text = "空いている枠に、倉庫のナイフ・雨具・救急包・爆薬・発煙筒を各1個詰めます。すでに携行している種類は除きます。"
	if candidates.is_empty():
		%BasicHint.text = "基本の支度で追加できる品はありません。"
	%BasicLoadout.tooltip_text = %BasicHint.text
	var has_weapon := false
	for item: Dictionary in state.loadout:
		if Data.ITEMS[item.kind].category == "weapon":
			has_weapon = true
	var needs_selection: bool = has_weapon and state.get("version", 3) >= 4 and state.preparation.weapon == null
	%LoanHint.visible = not has_weapon or needs_selection
	%LoanHint.text = "武器なしで出発すると貸出ナイフを借ります。帰還時に返却します。"
	departure_button.disabled = (not has_weapon and state.loadout.size() >= stats.capacity) or needs_selection
	if needs_selection:
		%LoanHint.text = "携行中の武器が未装備です。武器の「装備」を押してください。"
	elif departure_button.disabled:
		%LoanHint.text = "貸出ナイフのために携行枠を1個空けてください。"
	%Repair.disabled = true
	%Repair.text = "灯りは修復済み" if state.profile.lampRepaired else "灯りを修理"
	for job: Dictionary in Data.contracts(state):
		if job.id == "beacon":
			%Repair.disabled = job.status != "ready"
	%Repair.tooltip_text = "倉庫の集光芯と銅の端材を1個ずつ使う。次回から視界＋1。"
	%Risk.text = "倒れると装備・携行品を失います。倉庫は残ります。" if has_weapon else "武器なし：出発時に貸出ナイフを借ります。倒れると携行品を失います。倉庫は残ります。"
	if needs_selection:
		%Risk.text = "携行中の武器を装備すると出発できます。倒れると装備・携行品を失います。倉庫は残ります。"
	elif departure_button.disabled:
		%Risk.text = "貸出ナイフ用に携行枠を1個空けてください。倒れると携行品を失います。倉庫は残ります。"
	_adapt()
	_restore_ticket += 1
	_restore_content(previous, _restore_ticket)

func _present_equipment_slot(slot: PanelContainer, item: Dictionary) -> void:
	var equipped := not item.is_empty()
	slot.set_meta("item_uid", item.get("uid", ""))
	slot.get_node("Content/Name").text = Data.ITEMS[item.kind].name if equipped else "未装備"
	slot.get_node("Content/Icon").texture = Palette.icon(item.kind) if equipped else null
	slot.get_node("Content/Icon").visible = equipped
	var box := Palette.box(Color("e2eee1") if equipped else Color("ece9db"), Color("8fa59a"), 8)
	box.set_corner_radius_all(4)
	box.set_border_width_all(1)
	box.shadow_size = 0
	slot.add_theme_stylebox_override("panel", box)

func _inspect_item(uid: String) -> void:
	_inspection_uid = ""
	%ItemDescription.visible = false
	for item: Dictionary in _owned_items:
		if item.uid != uid:
			continue
		_inspection_uid = uid
		%ItemDescription.text = "%s：%s%s" % [Data.ITEMS[item.kind].name, Data.ITEMS[item.kind].description, " 依頼の納品に使います。" if _needed_kinds.has(item.kind) else ""]
		%ItemDescription.visible = true
		return

func _fill_items(parent: Node, items: Array, packing: bool, full: bool) -> void:
	UI.clear(parent)
	if items.is_empty():
		parent.add_child(UI.label("まだ詰めていません。倉庫から選べます。" if not packing else "倉庫に品はありません。貸出ナイフで再出発できます。", 14, Palette.MUTED))
	for item: Dictionary in items:
		var equipped: bool = item.uid in _equipped_uids and not packing
		var row := UI.item_row(item, "詰める" if packing else "戻す", equipped, true)
		parent.add_child(row)
		var inspect: Button = row.get_node("Content/Inspect")
		inspect.focus_entered.connect(func(): focused_item_uid = item.uid)
		inspect.pressed.connect(func(): _inspect_item(item.uid))
		var detail: Label = row.get_node("Content/Inspect/Identity/Words/Detail")
		if _needed_kinds.has(item.kind):
			detail.text = "装備中 / 依頼品" if equipped else "依頼品 / 説明"
		var category: String = Data.ITEMS[item.kind].category
		if not packing and category in ["weapon", "armor"]:
			var equip := Button.new()
			equip.name = "Equip"
			equip.text = "装備中" if equipped else "装備"
			equip.custom_minimum_size = Vector2(52, 52)
			equip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			equip.add_theme_font_size_override("font_size", 12)
			equip.disabled = equipped
			equip.set_meta("item_uid", item.uid)
			equip.set_meta("item_action", "equip")
			equip.accessibility_name = "%sを装備する。港では0手。" % Data.ITEMS[item.kind].name
			equip.tooltip_text = "港では0手。携行品のこの%sを出発時に装備する。" % ("武器" if category == "weapon" else "防具")
			equip.focus_entered.connect(func(): focused_item_uid = item.uid)
			equip.pressed.connect(func(): equip_requested.emit(item.uid))
			row.get_node("Content").add_child(equip)
			row.get_node("Content").move_child(equip, 1)
		var button: Button = row.get_node("Content/Transfer")
		button.focus_entered.connect(func(): focused_item_uid = item.uid)
		button.disabled = packing and full
		if button.disabled:
			button.text = "満杯"
			button.tooltip_text = "携行枠が満杯です。携行品を倉庫へ戻してください。"
		button.pressed.connect(func():
			if packing: pack_requested.emit(item.uid)
			else: unpack_requested.emit(item.uid))

func open_preparation() -> void:
	if preparation_open:
		return
	preparation_open = true
	_adapt()
	preparation_visibility_changed.emit(true)
	if %ClosePreparation.visible:
		%ClosePreparation.grab_focus()
	else:
		_focus_footer_action()

func close_preparation() -> void:
	if not preparation_open:
		return
	preparation_open = false
	_adapt()
	preparation_visibility_changed.emit(false)
	if %OpenPreparation.is_visible_in_tree():
		%OpenPreparation.grab_focus()
	else:
		_focus_footer_action()

func _focus_footer_action() -> void:
	if not %BasicLoadout.disabled:
		%BasicLoadout.grab_focus()
	else:
		departure_button.grab_focus()

func capture_preparation_state() -> Dictionary:
	var focused := get_viewport().gui_get_focus_owner()
	var uid := str(focused.get_meta("item_uid", "")) if is_instance_valid(focused) else ""
	return {"open":preparation_open, "scroll":preparation_scroll.scroll_vertical, "focus_uid":uid, "focus_action":str(focused.get_meta("item_action", "transfer")) if is_instance_valid(focused) else "transfer", "inspection_uid":_inspection_uid}

func restore_preparation_state(snapshot: Dictionary) -> void:
	var changed: bool = preparation_open != bool(snapshot.get("open", false))
	preparation_open = bool(snapshot.get("open", false))
	focused_item_uid = str(snapshot.get("focus_uid", ""))
	_inspect_item(str(snapshot.get("inspection_uid", "")))
	_adapt()
	if changed:
		preparation_visibility_changed.emit(preparation_open)
	_restore_ticket += 1
	_restore_content(snapshot, _restore_ticket)

func _restore_content(snapshot: Dictionary, ticket: int) -> void:
	# Containers and focus scrolling settle before restoring UI-only reading state.
	for frame: int in 3:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if not is_inside_tree() or ticket != _restore_ticket:
		return
	preparation_scroll.scroll_vertical = int(snapshot.get("scroll", 0))
	var uid := str(snapshot.get("focus_uid", ""))
	if uid.is_empty() or not %PreparationPane.visible:
		return
	var preferred_action := str(snapshot.get("focus_action", "transfer"))
	var targets: Array[Node] = []
	for candidate: Node in %Preparation.find_children("*", "Button", true, false):
		if candidate.get_meta("item_uid", "") == uid and not candidate.disabled:
			if candidate.get_meta("item_action", "transfer") == preferred_action:
				targets.push_front(candidate)
			else:
				targets.append(candidate)
	for node: Node in targets:
		if is_instance_valid(node):
			node.grab_focus()
			focused_item_uid = uid
			# A transferred UID can move between distant grids while the old scroll survives.
			await get_tree().process_frame
			if not is_inside_tree() or ticket != _restore_ticket or not is_instance_valid(node):
				return
			preparation_scroll.scroll_vertical = int(snapshot.get("scroll", 0))
			await get_tree().process_frame
			if is_inside_tree() and ticket == _restore_ticket and is_instance_valid(node):
				if not preparation_scroll.get_global_rect().encloses(node.get_global_rect()):
					preparation_scroll.ensure_control_visible(node)
			return

func _adapt() -> void:
	if not is_node_ready():
		return
	var wide := size.x >= 720
	var hiding_focused_toggle: bool = wide and (%OpenPreparation.has_focus() or %ClosePreparation.has_focus())
	%OpenPreparation.visible = not wide
	%Cast.visible = wide or not preparation_open
	%PreparationPane.visible = wide or preparation_open
	%ClosePreparation.visible = not wide
	%Cast.custom_minimum_size.x = minf(470, size.x * 0.42) if wide else 0
	%Hero.custom_minimum_size.y = 180 if wide else 142
	%Visual.custom_minimum_size = Vector2(190, 180) if wide else Vector2(144, 140)
	%OpenPreparation.text = "支度を閉じる" if preparation_open else str(%OpenPreparation.get_meta("carry_caption", "荷物を選ぶ"))
	# Full-width rows preserve readable item names and distinct 52px actions on phones.
	%CarryItems.columns = 1
	%StashItems.columns = 1
	if hiding_focused_toggle:
		_focus_footer_action()
