extends SceneTree
## Component actions keep concrete item UIDs; only resolved rules own inventory.
const Data = preload("res://scripts/rules.gd")
const Harbor = preload("res://scenes/presentation_v05/harbor.tscn")
var failures := 0
var checks := 0
var emitted: Array[String] = []

func check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + explanation)

func settle() -> void:
	for frame: int in 8:
		await process_frame

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 844)
	for available: Vector2 in [Vector2(324, 616), Vector2(354, 720), Vector2(1244, 700)]:
		await preparation_case(available)
	print("Preparation v0.6: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)

func preparation_case(available: Vector2) -> void:
	var state: Dictionary = Data.new_game()
	state.profile.stash.clear()
	for kind: String in ["knife", "harpoon", "coat", "medicine"]:
		state.loadout.append(Data._new_item(state, kind))
	state.profile.stash.append(Data._new_item(state, "core"))
	state.preparation.weapon = state.loadout[1].uid
	state.preparation.armor = state.loadout[2].uid
	check(Data.validate_state(state), "preparation fixture owns valid item UIDs")
	var snapshot := JSON.stringify(state)
	var view: Control = Harbor.instantiate()
	root.add_child(view)
	view.position = Vector2(18, 80)
	view.size = available
	view.present(state)
	view.equip_requested.connect(func(uid: String): emitted.append("equip:" + uid))
	view.pack_requested.connect(func(uid: String): emitted.append("pack:" + uid))
	view.unpack_requested.connect(func(uid: String): emitted.append("unpack:" + uid))
	view.unpack_all_requested.connect(func(): emitted.append("unpack_all"))
	view.open_preparation()
	await settle()
	var carry: GridContainer = view.get_node("%CarryItems")
	var first: Control = carry.get_child(0)
	var selected: Control = carry.get_child(1)
	check(view.get_node("%WeaponSlot").get_meta("item_uid") == state.loadout[1].uid, "weapon slot references the explicitly selected second weapon")
	check(view.get_node("%WeaponSlot/Content/Name").text == Data.ITEMS.harpoon.name, "weapon slot shows the real item name")
	check(not first.get_node("Content/Equip").disabled and selected.get_node("Content/Equip").disabled, "exact selected UID has the equipped badge; other weapon remains selectable")
	first.get_node("Content/Equip").pressed.emit()
	check(emitted.back() == "equip:" + state.loadout[0].uid and JSON.stringify(state) == snapshot, "equip requests exact UID without changing ownership locally")
	first.get_node("Content/Transfer").pressed.emit()
	check(emitted.back() == "unpack:" + state.loadout[0].uid, "return action remains distinct from equip")
	var before_inspect := emitted.size()
	var stash: Control = view.get_node("%StashItems").get_child(0)
	stash.get_node("Content/Inspect").pressed.emit()
	await settle()
	check(emitted.size() == before_inspect and JSON.stringify(state) == snapshot, "reading a name changes neither item ownership nor rule actions")
	check(view.get_node("%ItemDescription").visible and view.get_node("%ItemDescription").text.contains(Data.ITEMS.core.description), "touch inspection displays the actual description")
	check(stash.get_node("Content/Inspect/Identity/Words/Detail").text.contains("依頼品"), "outstanding contract material has a visible badge")
	view.get_node("%UnpackAll").pressed.emit()
	check(emitted.back() == "unpack_all" and JSON.stringify(state) == snapshot, "return all only asks the host to resolve the complete loadout")
	check(view.get_global_rect().encloses(view.departure_button.get_global_rect()), "departure remains within the available phone or desktop rectangle")
	for node: Node in view.find_children("*", "Button", true, false):
		var button: Button = node
		if not button.is_visible_in_tree():
			continue
		var scale := 360.0 / 390.0 if available.x == 324 else 1.0
		check(button.size.x * scale >= 44 and button.size.y * scale >= 44, "every visible preparation action meets the 44 CSS pixel target")
		check(button.get_global_rect().end.x <= view.get_global_rect().end.x + 1, "preparation action stays within the available width")
	state.preparation.weapon = null
	view.present(state)
	await settle()
	check(view.departure_button.disabled and view.get_node("%LoanHint").text.contains("未装備"), "a carried but unselected weapon requires an explicit choice")
	check(view.get_node("%WeaponSlot").get_meta("item_uid") == "", "empty reference slot never silently selects another carried weapon")
	# Frozen old-run presentation retains the historical first-carried convention.
	state.version = 3
	view.present(state)
	await settle()
	check(view.get_node("%WeaponSlot").get_meta("item_uid") == state.loadout[0].uid, "legacy v3 presentation preserves its first-carried equipment rule")
	view.queue_free()
	await settle()
