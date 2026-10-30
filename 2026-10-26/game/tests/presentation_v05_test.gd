extends SceneTree
## Native component checks. Fixtures resolve through Rules, without Main or SaveStore.
const Data = preload("res://scripts/rules.gd")
const Harbor = preload("res://scenes/presentation_v05/harbor.tscn")
const Result = preload("res://scenes/presentation_v05/result.tscn")
var failed := 0
var passed := 0
var signals_seen: Array[String] = []

func check(value: bool, explanation: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + explanation)

func settle() -> void:
	for i: int in 8:
		await process_frame

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 844)
	for available: Vector2 in [Vector2(354, 720), Vector2(324, 616), Vector2(1244, 700)]:
		await harbor_case(available)
		await outcome_case(available, false, 0)
		await empty_receipt_provenance_case(available)
		await outcome_case(available, false, 14)
		await outcome_case(available, true, 12)
	print("Presentation v0.5 components: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func mounted(scene: PackedScene, available: Vector2) -> Control:
	var panel: Control = scene.instantiate()
	root.add_child(panel)
	panel.position = Vector2(18, 80)
	panel.size = available
	return panel

func check_bounds(panel: Control, primary: Button, available: Vector2) -> void:
	check(panel.size.is_equal_approx(available), "component respects the actual parent's content rectangle")
	var rect := panel.get_global_rect()
	check(rect.encloses(primary.get_global_rect()), "primary action remains in visible parent bounds")
	var css_scale := 360.0 / 390.0 if available.x == 324 else 1.0
	check(primary.size.y * css_scale >= 44 and primary.size.x * css_scale >= 44, "primary action meets 44 CSS pixels at the narrow scale")
	primary.grab_focus()
	check(primary.has_focus(), "primary action accepts keyboard focus")
	for node: Node in panel.find_children("*", "Label", true, false):
		var label: Label = node
		if not label.is_visible_in_tree(): continue
		check(label.get_global_rect().end.x <= rect.end.x + 1, "wrapped label stays inside parent width: " + str(label.name))
	for node: Node in panel.find_children("*", "Button", true, false):
		var button: Button = node
		if not button.is_visible_in_tree(): continue
		check(button.size.y * css_scale >= 44 and button.size.x * css_scale >= 44, "button keeps a usable touch area: " + str(button.name))

func harbor_case(available: Vector2) -> void:
	var state := Data.new_game()
	var snapshot := JSON.stringify(state)
	var panel := mounted(Harbor, available)
	panel.present(state, "倉庫の品は残っています。次の遠征へ向けて支度を整えられます。")
	panel.pack_requested.connect(func(uid: String): signals_seen.append("pack:" + uid))
	panel.unpack_requested.connect(func(uid: String): signals_seen.append("unpack:" + uid))
	panel.character_requested.connect(func(id: String): signals_seen.append("choose:" + id))
	panel.page_requested.connect(func(page: String): signals_seen.append("page:" + page))
	panel.basic_loadout_requested.connect(func(): signals_seen.append("basic"))
	panel.departure_requested.connect(func(): signals_seen.append("depart"))
	await settle()
	check_bounds(panel, panel.departure_button, available)
	check(panel.get_global_rect().encloses(panel.get_node("%BasicLoadout").get_global_rect()), "basic loadout is immediately visible before opening preparation")
	check(not panel.get_node("%BasicLoadout").disabled, "fresh stash offers a working basic-loadout shortcut")
	check(not panel.preparation_open, "phone starts on the scene rather than detailed inventory")
	if available.x >= 720:
		check(not panel.get_node("%OpenPreparation").is_visible_in_tree() and panel.get_node("%PreparationPane").is_visible_in_tree(), "desktop preparation is permanently visible without a false close toggle")
		check(is_equal_approx(panel.get_node("%BasicLoadout").size.x, panel.get_node("%QuickPreparation").size.x), "desktop basic loadout occupies the available footer row")
	var open_snapshot := JSON.stringify(state)
	panel.preparation_visibility_changed.connect(func(open: bool): signals_seen.append("preparation:" + str(open)))
	panel.open_preparation()
	await settle()
	check(panel.preparation_open and signals_seen.back() == "preparation:true", "opening preparation emits the host pause notification")
	check(JSON.stringify(state) == open_snapshot, "opening preparation never changes rule state")
	if available.x < 720:
		check(panel.get_node("%ClosePreparation").has_focus(), "phone preparation starts with a keyboard close action")
	check_bounds(panel, panel.departure_button, available)
	var row: Control = panel.get_node("%StashItems").get_child(0)
	var uid: String = state.profile.stash[0].uid
	row.get_node("Content/Transfer").pressed.emit()
	check(signals_seen.back() == "pack:" + uid, "packing emits the exact owned UID")
	panel.get_node("%BasicLoadout").pressed.emit()
	check(signals_seen.back() == "basic", "basic preparation routes to the host")
	panel.get_node("%Roster").get_child(3).pressed.emit()
	check(signals_seen.back() == "choose:sui", "roster selection emits the real character id")
	panel.get_node("%Jobs").pressed.emit()
	check(signals_seen.back() == "page:jobs", "mission navigation routes to existing jobs")
	panel.departure_button.pressed.emit()
	check(signals_seen.back() == "depart", "departure only requests a host action")
	check(JSON.stringify(state) == snapshot and panel.get_node("%CarryItems").get_child_count() == 1, "presentation and signals do not locally pack or change state")
	state = Data.apply_action(state, {"type":"pack", "uid":uid}).state
	panel.present(state)
	await settle()
	row = panel.get_node("%CarryItems").get_child(0)
	check(row.get_meta("item_uid") == uid, "resolved pack appears in the carry inventory")
	row.get_node("Content/Transfer").pressed.emit()
	check(signals_seen.back() == "unpack:" + uid, "unpacking routes the same actual UID")
	row.get_node("Content/Transfer").grab_focus()
	await settle()
	check(row.get_node("Content/Transfer").has_focus(), "inventory actions are keyboard reachable")
	if available.x < 720:
		check(panel.preparation_scroll.get_global_rect().encloses(row.get_node("Content/Transfer").get_global_rect()), "keyboard-focused inventory action stays inside the scroll viewport")
	var full := Data.new_game()
	full.profile.stash.clear()
	for i: int in 14:
		full.loadout.append(Data._new_item(full, "medicine"))
	check(Data.validate_state(full), "full loadout fixture preserves valid UIDs")
	panel.present(full)
	await settle()
	check(panel.departure_button.disabled and panel.get_node("%LoanHint").text.contains("1個"), "full unarmed loadout explains the actual loan slot requirement")
	check(panel.get_node("%Roster").get_child(1).disabled, "smaller-capacity crew cannot be selected with fourteen packed items")
	check(panel.get_node("%BasicLoadout").disabled, "basic preparation is unavailable without packable stash items")
	full = Data.apply_action(full, {"type":"unpack", "uid":full.loadout[0].uid}).state
	panel.present(full)
	await settle()
	check(not panel.departure_button.disabled, "free-loan retry is available as soon as a slot is free")
	# A reading-state refresh preserves both scroll and focus while ownership stays put.
	var last_tile: Control = panel.get_node("%CarryItems").get_child(panel.get_node("%CarryItems").get_child_count() - 1)
	last_tile.get_node("Content/Transfer").grab_focus()
	await settle()
	var reading: Dictionary = panel.capture_preparation_state()
	var same_state := JSON.stringify(full)
	panel.present(full)
	await settle()
	check(panel.preparation_open and panel.focused_item_uid == reading.focus_uid, "present preserves an open pane and focused real item")
	check(absi(panel.preparation_scroll.scroll_vertical - int(reading.scroll)) <= 1, "unchanged resolved inventory preserves its reading position")
	check(JSON.stringify(full) == same_state, "focus and reading restoration are UI-only")
	panel.close_preparation()
	await settle()
	check(not panel.preparation_open and signals_seen.back() == "preparation:false", "close notifies the host to release background pause")
	check(panel.get_node("%OpenPreparation").has_focus() if available.x < 720 else panel.departure_button.has_focus(), "closing returns focus to a visible action, never a hidden desktop toggle")
	panel.restore_preparation_state(reading)
	await settle()
	check(panel.preparation_open and panel.capture_preparation_state().focus_uid == reading.focus_uid, "public restoration supports Main rebuilding the component")
	var many := Data.new_game()
	many.profile.stash.clear()
	for i: int in 30:
		many.profile.stash.append(Data._new_item(many, "medicine"))
	check(Data.validate_state(many), "late transfer fixture keeps thirty real unique stash items")
	panel.present(many)
	await settle()
	var late: Button = panel.get_node("%StashItems").get_child(29).get_node("Content/Transfer")
	late.grab_focus()
	panel.preparation_scroll.ensure_control_visible(late)
	await settle()
	var late_uid: String = late.get_meta("item_uid")
	panel.preparation_scroll.scroll_vertical += 16
	await settle()
	var interior: Dictionary = panel.capture_preparation_state()
	panel.present(many)
	await settle()
	check(panel.preparation_scroll.scroll_vertical == interior.scroll, "a read-only refresh preserves a deliberate interior reading offset")
	check(panel.capture_preparation_state().focus_uid == late_uid, "the interior reading offset retains the focused late UID")
	var packed: Dictionary = Data.apply_action(many, {"type":"pack", "uid":late_uid}).state
	panel.present(packed)
	await settle()
	var moved: Button = panel.get_node("%CarryItems").get_child(0).get_node("Content/Transfer")
	check(moved.has_focus() and panel.focused_item_uid == late_uid, "late stash UID keeps focus after becoming the first carried item")
	check(panel.preparation_scroll.get_global_rect().encloses(moved.get_global_rect()), "a focused item moved between distant grids is actually visible")
	var unpacked: Dictionary = Data.apply_action(packed, {"type":"unpack", "uid":late_uid}).state
	panel.present(unpacked)
	await settle()
	var returned: Button = panel.get_node("%StashItems").get_child(29).get_node("Content/Transfer")
	check(returned.has_focus() and panel.preparation_scroll.get_global_rect().encloses(returned.get_global_rect()), "the same UID is visible and focused after returning to the distant stash")
	var stage := Control.new()
	panel.attach_stage(stage)
	await settle()
	check(stage.get_parent() == panel.stage_slot and stage.size.is_equal_approx(panel.stage_slot.size), "injected stage fills its authored slot")
	panel.queue_free()
	await settle()

func receipt_fixture(dead: bool, count: int) -> Dictionary:
	var state := Data.new_game()
	# Build a valid, uniquely owned cargo fixture, then let Rules resolve the outcome.
	state.profile.stash.clear()
	for i: int in count:
		state.loadout.append(Data._new_item(state, "knife" if i == 0 else "medicine" if i % 2 else "scrap"))
	check(Data.validate_state(state), "cargo fixture satisfies the real state schema")
	state = Data.apply_action(state, {"type":"depart", "seed":40}).state
	if dead:
		state.run.player.hp = 1
		var adjacent: Dictionary = {}
		for direction: Dictionary in Data.DIRECTIONS:
			var x: int = int(state.run.player.x) + int(direction.x)
			var y: int = int(state.run.player.y) + int(direction.y)
			if Data.World.is_walkable(state.run, x, y):
				adjacent = {"x":x, "y":y}
				break
		check(not adjacent.is_empty(), "generated landing has a valid adjacent loss-fixture cell")
		state.run.enemies = [{"id":"receipt-crab", "kind":"crab", "x":adjacent.x, "y":adjacent.y, "hp":Data.ENEMIES.crab.hp, "facing":{"x":0,"y":1}, "stunned":0}]
		Data._remember(state.run)
		check(Data.validate_state(state), "loss fixture is valid before the enemy turn")
		state = Data.apply_action(state, {"type":"wait"}).state
	else:
		state = Data.apply_action(state, {"type":"interact"}).state
	check(state.mode == "result" and Data.validate_state(state), "receipt comes from a valid resolved rule action")
	return state

func outcome_case(available: Vector2, dead: bool, count: int) -> void:
	var state := receipt_fixture(dead, count)
	if state.mode != "result": return
	var snapshot := JSON.stringify(state)
	var panel := mounted(Result, available)
	panel.present(state)
	panel.continue_requested.connect(func(): signals_seen.append("continue"))
	await settle()
	check_bounds(panel, panel.continue_button, available)
	check(panel.get_node("%Value").text == "%d pt" % state.result.value, "value is the resolved receipt value in points")
	check(panel.get_node("%Turns").text == "%d手の遠征" % state.result.turns, "actual resolved turn count is displayed")
	var items: GridContainer = panel.get_node("%Items")
	if count:
		check(panel.result_scroll.get_global_rect().intersects(items.get_child(0).get_global_rect()), "first actual cargo is visible without scrolling the initial result")
		check(items.get_child_count() == state.result.inventory.size(), "all receipt items are available immediately")
		for i: int in state.result.inventory.size():
			check(items.get_child(i).get_meta("item_uid") == state.result.inventory[i].uid, "receipt preserves exact item identity")
		panel.result_scroll.scroll_vertical = int(panel.result_scroll.get_v_scroll_bar().max_value)
		await settle()
		check(panel.get_global_rect().encloses(panel.continue_button.get_global_rect()), "long inventory never scrolls away the continue action")
	else:
		check(panel.get_node("%Outcome").text == "無事に帰港", "empty extraction is distinguished from cargo success and death")
	if dead:
		check(panel.get_node("%Cause").text.ends_with(state.result.cause), "loss displays the actual cause")
	panel.continue_button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	check(signals_seen.back() == "continue" and JSON.stringify(state) == snapshot, "continue signal does not transfer receipt items again")
	panel.get_node("%Quote").text = "潮が満ちる前に帰り道を確かめよう。".repeat(8)
	panel.get_node("%Mission").text += "\n" + "回収する品を倉庫へ持ち帰り、港で依頼を確認できます。".repeat(3)
	await settle()
	check_bounds(panel, panel.continue_button, available)
	var static_stage := Control.new()
	panel.attach_stage(static_stage)
	panel.present(state)
	await settle()
	check(static_stage.size.is_equal_approx(panel.stage_slot.size), "static outcome stage can be attached and refreshed without a missing portrait")
	panel.queue_free()
	await settle()

func empty_receipt_provenance_case(available: Vector2) -> void:
	for owned_knife: bool in [false, true]:
		var state := Data.new_game()
		var knife_uid: String = state.profile.stash[0].uid
		if owned_knife:
			state = Data.apply_action(state, {"type":"pack", "uid":knife_uid}).state
		state = Data.apply_action(state, {"type":"depart", "seed":7}).state
		check(state.run.inventory.size() == 1 and state.run.inventory[0].kind == ("knife" if owned_knife else "loanKnife"), "empty receipt provenance begins with the intended real owned or loan weapon")
		if owned_knife:
			state = Data.apply_action(state, {"type":"drop", "uid":knife_uid}).state
			check(state.run.inventory.is_empty() and Data.validate_state(state), "owned weapon is genuinely dropped through Rules before extraction")
		state = Data.apply_action(state, {"type":"interact"}).state
		check(state.mode == "result" and state.result.outcome == "extracted" and state.result.inventory.is_empty() and Data.validate_state(state), "both histories resolve to valid empty extraction receipts")
		var snapshot := JSON.stringify(state)
		var panel := mounted(Result, available)
		panel.present(state)
		await settle()
		check(panel.get_node("%Ownership").text == "持ち帰った品はありません。", "empty receipt text states only the supported fact for either weapon history")
		check(panel.get_node("%Items").get_child_count() == 0, "successful empty receipt has one explanation without a duplicate inventory label")
		check(JSON.stringify(state) == snapshot and panel.continue_button.is_visible_in_tree(), "showing either empty receipt changes no ownership and leaves continuation available")
		panel.queue_free()
		await settle()
