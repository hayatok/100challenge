extends SceneTree

const RulesData = preload("res://scripts/rules.gd")
const Store = preload("res://scripts/save_store.gd")
var passed := 0
var failed := 0
var ui: Control

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	for test: String in ["test_characters", "test_safe_area", "test_turn_input", "test_storage", "test_result_receipt", "test_inventory_uid_actions", "test_inventory_focus_and_full_health", "test_world_overlay_phone_bounds", "test_presentation_pause_and_motion", "test_empty_extraction_readability"]:
		if await call(test) != true:
			failed += 1
			push_error("FAIL: did not complete " + test)
	ui.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	print("UI/store tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func test_characters() -> bool:
	check(ui.qa_session, "QA does not overwrite real saves")
	for key: String in RulesData.CHARACTERS:
		ui.state = RulesData.apply_action(RulesData.new_game(), {"type": "choose", "character": key}).state
		ui._enter()
		await process_frame
		await process_frame
		check(ui.state.character == key, "character selection " + key)
		check(ResourceLoader.exists("res://assets/art/%s.png" % key), "real character image " + key)
		var depart: Button = find_button(ui.content, "この装備で出発する")
		check(depart != null and depart.get_global_rect().end.y <= ui.size.y + 1, "phone departure button fits " + key)
	return true

func test_safe_area() -> bool:
	ui._apply_safe_area(Vector4(0, 44, 0, 34))
	ui._render()
	await process_frame
	await process_frame
	check(ui.get_node("SafeFrame").get_theme_constant("margin_top") == 62, "notch adds top inset to frame")
	var depart: Button = find_button(ui.content, "この装備で出発する")
	check(depart != null and depart.get_global_rect().end.y <= ui.size.y - 34, "departure clears home indicator")
	ui._help()
	await process_frame
	await process_frame
	check(ui.modal_panel.get_global_rect().position.y >= 44 and ui.modal_panel.get_global_rect().end.y <= ui.size.y - 34, "modal fits nonzero safe area")
	ui._close_modal()
	ui._apply_safe_area(Vector4.ZERO)
	return true

func test_turn_input() -> bool:
	var prepared: Dictionary = RulesData.new_game()
	var medicine_uid: String = prepared.profile.stash[2].uid
	prepared = RulesData.apply_action(prepared, {"type": "pack", "uid": medicine_uid}).state
	ui.state = RulesData.apply_action(prepared, {"type": "depart", "seed": 7}).state
	ui._enter()
	await process_frame
	await process_frame
	for i: int in range(5):
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_UP
		key.physical_keycode = KEY_UP
		ui._input(key)
	check(ui.state.run.turn == 5, "five rapid deliberate presses resolve five turns")
	var snapshot: String = JSON.stringify(ui.state)
	ui._inventory()
	await process_frame
	check(ui.overlay.z_index >= 100, "inventory overlays high-z world objects")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_UP
	key.physical_keycode = KEY_UP
	ui._input(key)
	check(JSON.stringify(ui.state) == snapshot, "reading inventory cannot advance a turn")
	ui._close_modal()
	key.echo = true
	ui._input(key)
	check(JSON.stringify(ui.state) == snapshot, "held-key echo cannot advance turns")
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(JSON.stringify(ui.state) == snapshot, "focus changes cannot advance turns")
	check(ui.hp_label.text.contains("24 / 24"), "HUD reports actual hit points")
	ui._act({"type": "use", "uid": medicine_uid})
	check(JSON.stringify(ui.state) == snapshot, "invalid healing preserves turn and item")
	check(ui.log_label.text.contains("体力は満タン"), "invalid action visibly explains no effect")
	var bomb: Dictionary = {}
	for item: Dictionary in ui.state.profile.stash:
		if item.kind == "bomb":
			bomb = item
			break
	ui.state.profile.stash.erase(bomb)
	ui.state.run.inventory.append(bomb)
	snapshot = JSON.stringify(ui.state)
	ui._act({"type": "use", "uid": bomb.uid, "dx": 1, "dy": 0})
	check(JSON.stringify(ui.state) == snapshot, "invalid bomb preserves turn and item")
	check(ui.log_label.text.contains("壊せる壁や敵はいない"), "invalid bomb target is explained")
	while ui.state.run.inventory.size() < RulesData.stats(ui.state).capacity:
		ui.state.run.inventory.append({"uid": "i%d" % ui.state.nextId, "kind": "pearl"})
		ui.state.nextId += 1
	ui.state.run.player.x = 11
	ui.state.run.player.y = 21
	var explored: Dictionary = {}
	for cell: String in ui.state.run.seen:
		explored[cell] = true
	explored.merge(RulesData.visible_tiles(ui.state.run))
	ui.state.run.seen = explored.keys()
	snapshot = JSON.stringify(ui.state)
	ui._act({"type": "interact"})
	check(JSON.stringify(ui.state) == snapshot, "full bag search preserves turn and loot")
	check(ui.log_label.text.contains("携行枠がいっぱい"), "full bag failure is explained")
	return true

func test_storage() -> bool:
	var path := "user://qa-store.json"
	var data: Dictionary = ui.state.duplicate(true)
	check(Store.write_value("shiogaeri-qa", path, data).is_empty(), "native atomic store writes")
	var read: Dictionary = Store.read_value("shiogaeri-qa", path)
	var parser := JSON.new()
	check(parser.parse(read.raw) == OK and RulesData.validate_state(parser.data), "serialized state reloads and validates")
	check(parser.data.run.turn == data.run.turn and parser.data.run.player.hp == data.run.player.hp, "reload preserves resolved turn and HP")
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	return true

func test_result_receipt() -> bool:
	var state: Dictionary = RulesData.new_game()
	var uid: String = state.profile.stash[0].uid
	state = RulesData.apply_action(state, {"type": "pack", "uid": uid}).state
	state = RulesData.apply_action(state, {"type": "depart", "seed": 7}).state
	state = RulesData.apply_action(state, {"type": "interact"}).state
	ui.state = state
	ui._enter()
	await process_frame
	await process_frame
	check(ui.screen == "result", "extraction opens result screen")
	check(state.result.inventory.size() == 1 and state.profile.stash.size() == 8, "receipt is already transferred once")
	check(find_button(ui.content, "港で支度をする") != null, "result has working return path")
	return true

func find_button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func expedition_with_duplicates() -> Dictionary:
	var prepared: Dictionary = RulesData.new_game()
	for item: Dictionary in prepared.profile.stash.duplicate():
		prepared = RulesData.apply_action(prepared, {"type": "pack", "uid": item.uid}).state
	return RulesData.apply_action(prepared, {"type": "depart", "seed": 7}).state

func settle_layout() -> void:
	for frame: int in range(4):
		await process_frame

func item_uids(kind: String) -> Array[String]:
	var matches: Array[String] = []
	for item: Dictionary in ui.state.run.inventory:
		if item.kind == kind:
			matches.append(item.uid)
	return matches

func carries(uid: String) -> bool:
	for item: Dictionary in ui.state.run.inventory:
		if item.uid == uid:
			return true
	return false

func test_inventory_uid_actions() -> bool:
	ui.state = expedition_with_duplicates()
	ui.state.run.player.hp = 11
	ui._enter()
	await settle_layout()
	var medicines: Array[String] = item_uids("medicine")
	var bombs: Array[String] = item_uids("bomb")
	var flares: Array[String] = item_uids("flare")
	var snapshot: String = JSON.stringify(ui.state)
	ui._inventory()
	await settle_layout()
	check(ui.inventory_slots.size() == ui.state.run.inventory.size(), "inventory grid represents every distinct carried item")
	var second_medicine: Button = ui.inventory_slots[medicines[1]]
	second_medicine.pressed.emit()
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot, "opening and selecting a duplicate item costs no turn or inventory")
	check(second_medicine.tooltip_text == RulesData.ITEMS.medicine.name, "selected grid cell names its real item")
	var use: Button = find_button(ui.inventory_detail, "使う / 1手")
	check(use != null and not use.disabled, "injured character can use selected medicine")
	if use == null:
		return false
	use.pressed.emit()
	await settle_layout()
	check(not carries(medicines[1]) and carries(medicines[0]), "use consumes selected medicine UID and preserves its identical neighbor")
	check(ui.state.run.turn == 1 and ui.state.run.player.hp == 21, "selected medicine heals once and resolves one turn")
	check(not is_instance_valid(ui.modal) and RulesData.validate_state(ui.state), "medicine closes inventory with a saveable resolved state")
	# Direction selection belongs to the selected UID and is itself a read-only step.
	ui.state.run.tiles[23][13].type = "wall"
	ui._inventory()
	await settle_layout()
	ui.inventory_slots[bombs[1]].pressed.emit()
	await settle_layout()
	snapshot = JSON.stringify(ui.state)
	use = find_button(ui.inventory_detail, "使う / 1手")
	if use == null:
		return false
	use.pressed.emit()
	await settle_layout()
	check(ui.pending_item == bombs[1] and JSON.stringify(ui.state) == snapshot, "targeting selected bomb retains its UID without spending a turn")
	ui._direction(1, 0)
	await settle_layout()
	check(not carries(bombs[1]) and carries(bombs[0]), "directional use consumes selected bomb UID only")
	check(ui.state.run.tiles[23][13].type == "floor" and ui.state.run.turn == 2, "selected bomb action destroys target wall in exactly one turn")
	ui._inventory()
	await settle_layout()
	ui.inventory_slots[flares[1]].pressed.emit()
	await settle_layout()
	var drop: Button = find_button(ui.inventory_detail, "置く / 1手")
	if drop == null:
		return false
	drop.pressed.emit()
	await settle_layout()
	var on_ground: bool = false
	for container: Dictionary in ui.state.run.containers:
		if container.x == ui.state.run.player.x and container.y == ui.state.run.player.y:
			for item: Dictionary in container.items:
				on_ground = on_ground or item.uid == flares[1]
	check(not carries(flares[1]) and carries(flares[0]) and on_ground, "drop moves the selected duplicate UID to the ground without destroying it")
	check(ui.state.run.turn == 3 and RulesData.validate_state(ui.state), "drop resolves one saveable turn")
	return true

func key_press(code: Key, backwards: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = backwards
	ui._input(event)

func test_inventory_focus_and_full_health() -> bool:
	ui.state = expedition_with_duplicates()
	ui._enter()
	await settle_layout()
	ui._inventory()
	await settle_layout()
	var medicine: String = item_uids("medicine")[1]
	ui.inventory_slots[medicine].pressed.emit()
	await settle_layout()
	var disabled_heal: Button = find_button(ui.inventory_detail, "体力は満タン")
	check(disabled_heal != null and disabled_heal.disabled, "full-health medicine is visibly unavailable")
	var drop: Button = find_button(ui.inventory_detail, "置く / 1手")
	var close: Button = find_button(ui.modal, "閉じる")
	if drop == null or close == null or disabled_heal == null:
		return false
	var snapshot: String = JSON.stringify(ui.state)
	close.grab_focus()
	var reached: Dictionary = {}
	var focus_stayed_in_modal: bool = true
	var disabled_was_skipped: bool = true
	for step: int in range(ui.state.run.inventory.size() + 4):
		key_press(KEY_TAB)
		await process_frame
		var focused: Control = ui.get_viewport().gui_get_focus_owner()
		focus_stayed_in_modal = focus_stayed_in_modal and is_instance_valid(focused) and ui.modal.is_ancestor_of(focused)
		disabled_was_skipped = disabled_was_skipped and focused != disabled_heal
		if is_instance_valid(focused):
			reached[focused.get_instance_id()] = true
	check(reached.has(drop.get_instance_id()) and reached.has(close.get_instance_id()), "Tab reaches selected item action and modal close")
	var every_item_reachable: bool = true
	for slot: Button in ui.inventory_slots.values():
		every_item_reachable = every_item_reachable and reached.has(slot.get_instance_id())
	check(every_item_reachable, "keyboard focus reaches every carried-item grid cell")
	check(focus_stayed_in_modal and disabled_was_skipped, "modal focus stays inside and skips disabled healing")
	drop.grab_focus()
	key_press(KEY_TAB)
	key_press(KEY_TAB, true)
	check(ui.get_viewport().gui_get_focus_owner() == drop, "Shift-Tab reverses keyboard traversal to an actionable control")
	check(JSON.stringify(ui.state) == snapshot, "focus traversal and item reading never resolve a game turn")
	key_press(KEY_ESCAPE)
	await settle_layout()
	check(not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "Esc closes inventory without changing the expedition")
	return true

func effective_z(item: CanvasItem) -> int:
	var result: int = 0
	var cursor: Node = item
	while cursor != null:
		if cursor is CanvasItem:
			result += cursor.z_index
			if not cursor.z_as_relative:
				break
		cursor = cursor.get_parent()
	return result

func highest_draw_z(parent: Node) -> int:
	var highest: int = -4096
	if parent is CanvasItem and parent.is_visible_in_tree():
		highest = effective_z(parent)
	for child: Node in parent.get_children():
		highest = maxi(highest, highest_draw_z(child))
	return highest

func descendant_buttons(parent: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in parent.get_children():
		if child is Button:
			buttons.append(child)
		buttons.append_array(descendant_buttons(child))
	return buttons

func fits_visible_stage(control: Control) -> bool:
	var stage: Rect2 = ui.get_global_rect().grow(1.0)
	var rect: Rect2 = control.get_global_rect()
	return rect.size.x > 0 and rect.size.y > 0 and stage.encloses(rect)

func test_world_overlay_phone_bounds() -> bool:
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(360, 740)]:
		root.size = phone
		ui._close_modal()
		ui._apply_safe_area(Vector4.ZERO)
		ui.state = expedition_with_duplicates()
		ui._enter()
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var buttons: Array[Button] = descendant_buttons(ui.control_dock)
		check(root.size == phone and buttons.size() >= 8, "%s renders phone controls" % phone)
		var world_z: int = highest_draw_z(ui.board)
		var all_above: bool = true
		var all_inside: bool = true
		var touch_targets: bool = true
		var scale_to_phone: Vector2 = Vector2(phone) / ui.size
		for button: Button in buttons:
			all_above = all_above and effective_z(button) > world_z
			all_inside = all_inside and fits_visible_stage(button)
			var css_size: Vector2 = button.size * scale_to_phone
			touch_targets = touch_targets and css_size.x >= 44 and css_size.y >= 44
		check(all_above, "%s actionable overlay controls draw above the complete world hierarchy" % phone)
		check(all_inside and fits_visible_stage(ui.objective_label), "%s objective and all world-overlay controls remain within the viewport" % phone)
		check(touch_targets, "%s movement and action controls retain 44px touch targets" % phone)
		check(not ui.control_dock.get_global_rect().intersects(ui.objective_label.get_global_rect()), "%s control dock does not cover the objective" % phone)
		ui._inventory()
		await settle_layout()
		check(fits_visible_stage(ui.modal_panel), "%s inventory modal fits the visible stage" % phone)
		var modal_drop: Button = find_button(ui.inventory_detail, "置く / 1手")
		check(modal_drop != null and effective_z(modal_drop) > highest_draw_z(ui.world_overlay), "%s inventory action draws above field controls" % phone)
		ui._close_modal()
		await settle_layout()
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func water_motion_time() -> float:
	var water: CanvasItem = ui.board.get_node("World/Water")
	return float((water.material as ShaderMaterial).get_shader_parameter("motion_time"))

func test_presentation_pause_and_motion() -> bool:
	ui._close_modal()
	ui.settings.reduced = false
	ui.state = expedition_with_duplicates()
	ui._enter()
	await settle_layout()
	ui._direction(0, -1)
	var snapshot: String = JSON.stringify(ui.state)
	ui._settings()
	await settle_layout()
	var paused_clock: float = ui.scenery.clock
	var paused_water: float = water_motion_time()
	var paused_camera: Vector2 = ui.board.get_node("World").position
	await create_timer(0.07).timeout
	check(is_equal_approx(ui.scenery.clock, paused_clock) and is_equal_approx(water_motion_time(), paused_water), "opening a modal freezes decorative and water motion")
	check(ui.board.get_node("World").position.is_equal_approx(paused_camera), "opening a modal also freezes in-flight camera motion")
	ui._direction(1, 0)
	key_press(KEY_UP)
	check(JSON.stringify(ui.state) == snapshot, "modal presentation and blocked field input cannot advance the expedition")
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui._close_modal()
	await settle_layout()
	paused_camera = ui.board.get_node("World").position
	paused_water = water_motion_time()
	await create_timer(0.07).timeout
	check(ui.board.get_node("World").position.is_equal_approx(paused_camera) and is_equal_approx(water_motion_time(), paused_water), "closing a modal while unfocused keeps world motion paused")
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(0.07).timeout
	check(water_motion_time() > paused_water, "focused field resumes presentation after modal closes")
	check(JSON.stringify(ui.state) == snapshot, "focus loss and presentation resume preserve the resolved turn")
	ui._settings()
	await settle_layout()
	var motion: CheckButton = find_button(ui.modal, "動きを減らす") as CheckButton
	if motion == null:
		return false
	motion.button_pressed = true
	ui._close_modal()
	await settle_layout()
	paused_water = water_motion_time()
	paused_clock = ui.scenery.clock
	await create_timer(0.07).timeout
	check(ui.settings.reduced and is_equal_approx(water_motion_time(), paused_water) and is_equal_approx(ui.scenery.clock, paused_clock), "reduced-motion setting stops continuous field and scenery motion")
	check(JSON.stringify(ui.state) == snapshot and RulesData.validate_state(ui.state), "changing presentation settings preserves the entire saveable game state")
	ui._map()
	await settle_layout()
	key_press(KEY_ESCAPE)
	ui._help()
	await settle_layout()
	key_press(KEY_ESCAPE)
	check(JSON.stringify(ui.state) == snapshot, "map and help inspection preserve state with reduced motion enabled")
	return true

func find_label(parent: Node, text: String) -> Label:
	for child: Node in parent.get_children():
		if child is Label and child.text == text:
			return child
		var found: Label = find_label(child, text)
		if found != null:
			return found
	return null

func test_empty_extraction_readability() -> bool:
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(360, 740)]:
		root.size = phone
		ui._close_modal()
		ui._apply_safe_area(Vector4.ZERO)
		var state: Dictionary = RulesData.new_game()
		var stash: Array = state.profile.stash.duplicate(true)
		state = RulesData.apply_action(state, {"type": "depart", "seed": 7}).state
		check(state.run.inventory.size() == 1 and state.run.inventory[0].kind == "loanKnife", "%s empty-return route actually borrows a knife" % phone)
		state = RulesData.apply_action(state, {"type": "interact"}).state
		check(state.mode == "result" and state.result.outcome == "extracted" and state.result.inventory.is_empty() and state.profile.stash == stash, "%s actual extraction returns the loan without creating a reward" % phone)
		ui.state = state
		var snapshot: String = JSON.stringify(ui.state)
		ui._enter()
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var empty: Label = find_label(ui.content, "持ち帰った品はありません。")
		check(empty != null, "%s empty extraction explains its empty receipt" % phone)
		if empty == null:
			return false
		var available_width: float = (empty.get_parent() as Control).size.x
		check(available_width > 200 and empty.size.x >= available_width * 0.9, "%s empty-receipt message spans the available row instead of a one-character column" % phone)
		check(empty.get_line_count() <= 2 and fits_visible_stage(empty), "%s empty-receipt message remains a readable horizontal sentence" % phone)
		var retry: Button = find_button(ui.content, "港で支度をする")
		check(retry != null and fits_visible_stage(retry), "%s empty return keeps its harbor CTA inside the viewport" % phone)
		check(JSON.stringify(ui.state) == snapshot and RulesData.validate_state(ui.state), "%s showing the empty result preserves a valid resolved state" % phone)
		if retry == null:
			return false
		retry.pressed.emit()
		await settle_layout()
		check(ui.screen == "harbor" and ui.state.mode == "harbor" and ui.state.profile.stash == stash and ui.state.profile.extracts == 1 and RulesData.validate_state(ui.state), "%s empty-result CTA returns to harbor without duplicating inventory" % phone)
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true
