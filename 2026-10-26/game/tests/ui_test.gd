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
	for test: String in ["test_characters", "test_safe_area", "test_turn_input", "test_storage", "test_result_receipt"]:
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
