extends SceneTree

const Data = preload("res://scripts/rules.gd")
const Main = preload("res://scenes/main.tscn")
var passed: int = 0
var failed: int = 0
var ui: Control

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func settle() -> void:
	for i: int in range(6):
		await process_frame

func button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found: Button = button(child, text)
		if found != null:
			return found
	return null

func label_starting(parent: Node, prefix: String) -> Label:
	for child: Node in parent.get_children():
		if child is Label and child.text.begins_with(prefix):
			return child
		var found: Label = label_starting(child, prefix)
		if found != null:
			return found
	return null

func items(state: Dictionary) -> Array:
	var result: Array = []
	for item: Dictionary in state.profile.stash + state.run.inventory:
		result.append(item.uid + ":" + item.kind)
	for cache: Dictionary in state.run.containers:
		for item: Dictionary in cache.items:
			result.append(item.uid + ":" + item.kind)
	result.sort()
	return result

func cache_by_id(id: String) -> Dictionary:
	for cache: Dictionary in ui.state.run.containers:
		if cache.id == id:
			return cache
	return {}

func fixture(full: bool = false) -> Dictionary:
	var state: Dictionary = Data.new_game()
	if full:
		while state.profile.stash.size() < int(Data.stats(state).capacity):
			state.profile.stash.append(Data._new_item(state, "scrap"))
		for item: Dictionary in state.profile.stash.duplicate():
			state = Data.apply_action(state, {"type":"pack", "uid":item.uid}).state
	state = Data.apply_action(state, {"type":"depart", "seed":9}).state
	state.run.enemies.clear()
	var cache: Dictionary = state.run.containers[0]
	state.run.player.x = cache.x
	state.run.player.y = cache.y
	Data._remember(state.run)
	check(Data.validate_state(state), "cargo fixture has real generated terrain and uniquely owned items")
	return state

func take_and_read_case() -> void:
	ui._close_modal()
	ui.state = fixture()
	ui._enter()
	await settle()
	var id: String = ui.state.run.containers[0].id
	var before: Array = items(ui.state)
	var before_inventory: Array = ui.state.run.inventory.duplicate(true)
	ui._open_container(id)
	await settle()
	check(ui.state.run.turn == 1 and cache_by_id(id).searched and ui.state.run.inventory == before_inventory, "opening cache costs exactly one turn without automatic loot")
	check(is_instance_valid(ui.modal) and ui.inventory_container == id and ui.board._overlay_paused and ui.get_global_rect().encloses(ui.modal_panel.get_global_rect()), "cache opens a fitting cargo context and pauses world presentation")
	var snapshot: String = JSON.stringify(ui.state)
	var selected: String = cache_by_id(id).items[-1].uid
	ui.inventory_slots[selected].pressed.emit()
	await settle()
	ui._direction(0, -1)
	ui._direction(0, 0)
	check(JSON.stringify(ui.state) == snapshot and ui.inventory_selection == selected, "selection, reading and attempted movement/wait in modal are free")
	var heading: Label = label_starting(ui.modal, "箱に残っている品")
	var selected_item: Dictionary = Data._find_item(cache_by_id(id).items, selected)
	var title: Label = label_starting(ui.inventory_detail, Data.ITEMS[selected_item.kind].name)
	var take_all: Button = button(ui.modal, "入る分を回収")
	check(heading != null and heading.size.x >= 80 and heading.get_line_count() <= 2 and heading.size.y <= 60, "cache heading retains readable width instead of one character per line")
	check(title != null and title.size.x >= 80 and title.get_line_count() <= 2 and title.size.y <= 60, "selected item title retains readable width within its icon row")
	check(take_all != null and take_all.size.y <= 64, "take all button keeps its compact height beside the cache heading")
	var take: Button = button(ui.inventory_detail, "回収 / 1手")
	check(take != null and not take.disabled, "selected cache item has an actionable take button")
	if take == null:
		return
	take.pressed.emit()
	await settle()
	check(ui.state.run.turn == 2 and not Data._find_item(ui.state.run.inventory, selected).is_empty() and Data._find_item(cache_by_id(id).items, selected).is_empty(), "take button transfers the selected UID exactly once in one turn")
	check(items(ui.state) == before and Data.validate_state(ui.state), "cache take conserves all actual owned UIDs")
	check(is_instance_valid(ui.modal) and ui.inventory_container == id and ui.inventory_slots.has(ui.inventory_selection), "take retains a usable selected item and the same cache context")
	snapshot = JSON.stringify(ui.state)
	ui._close_modal()
	ui._open_container(id)
	await settle()
	check(JSON.stringify(ui.state) == snapshot, "reopening an already investigated cache costs no turn")
	ui._close_modal()

func full_swap_case() -> void:
	ui.state = fixture(true)
	ui._enter()
	await settle()
	var id: String = ui.state.run.containers[0].id
	ui._open_container(id)
	await settle()
	var source: String = cache_by_id(id).items[-1].uid
	var destination: String = ui.state.run.inventory[2].uid
	var before: Array = items(ui.state)
	var snapshot: String = JSON.stringify(ui.state)
	ui.inventory_slots[source].pressed.emit()
	await settle()
	var take: Button = button(ui.inventory_detail, "鞄は満杯")
	check(take != null and take.disabled, "full bag disables take and explains its capacity")
	var exchange: Button = button(ui.inventory_detail, "携行品と交換")
	if exchange == null:
		check(false, "exchange action exists for a selected cache item")
		return
	exchange.pressed.emit()
	await settle()
	check(ui.inventory_origin == "bag" and not Data._find_item(ui.state.run.inventory, ui.inventory_selection).is_empty() and ui.inventory_slots[ui.inventory_selection].has_focus(), "starting a swap focuses a carried candidate, without transferring it")
	ui.inventory_slots[destination].pressed.emit()
	await settle()
	check(JSON.stringify(ui.state) == snapshot and ui.inventory_swap_uid == source and ui.inventory_selection == destination, "choosing both sides of a swap spends no turn")
	var confirm: Button = button(ui.inventory_detail, "この品と交換 / 1手")
	if confirm == null:
		check(false, "specific full bag exchange has an explicit confirmation action")
		return
	confirm.pressed.emit()
	await settle()
	check(ui.state.run.turn == 2 and ui.state.run.inventory.size() == int(Data.stats(ui.state).capacity), "confirmed full bag exchange resolves one turn and preserves bag size")
	check(not Data._find_item(ui.state.run.inventory, source).is_empty() and Data._find_item(ui.state.run.inventory, destination).is_empty() and not Data._find_item(cache_by_id(id).items, destination).is_empty() and Data._find_item(cache_by_id(id).items, source).is_empty(), "full bag swap moves the exact two selected UIDs in opposite directions")
	check(items(ui.state) == before and Data.validate_state(ui.state) and is_instance_valid(ui.modal) and ui.inventory_swap_uid.is_empty(), "exchange conserves ownership, clears swap mode and leaves reading usable")
	ui._close_modal()

func depth_case() -> void:
	ui.state = fixture()
	ui.state.run.player.x = ui.state.run.stairs.x
	ui.state.run.player.y = ui.state.run.stairs.y
	Data._remember(ui.state.run)
	ui._enter()
	await settle()
	var snapshot: String = JSON.stringify(ui.state)
	ui._confirm_advance()
	await settle()
	var cancel: Button = button(ui.modal, "この層の探索へ戻る")
	check(cancel != null and JSON.stringify(ui.state) == snapshot, "depth confirmation reads real state without resolving a turn")
	if cancel == null:
		return
	cancel.pressed.emit()
	await settle()
	check(not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "cancelling depth advance preserves the complete old sector")
	var inventory: Array = ui.state.run.inventory.duplicate(true)
	var hp: int = ui.state.run.player.hp
	var charges: int = ui.state.run.crewCharges
	var old_tiles: String = JSON.stringify(ui.state.run.tiles)
	var old_fog: Node = ui.board.fog.get_child(0)
	ui._confirm_advance()
	await settle()
	var confirm: Button = button(ui.modal, "荷を持って先へ進む / 1手")
	if confirm == null:
		check(false, "depth advance offers the explicit one turn button")
		return
	confirm.pressed.emit()
	await settle()
	check(ui.state.run.depth == 2 and ui.state.run.turn == 1 and ui.state.run.inventory == inventory and ui.state.run.player.hp == hp and ui.state.run.crewCharges == charges and Data.validate_state(ui.state), "actual depth button advances once and carries actual HP, items and crew charges")
	check(JSON.stringify(ui.state.run.tiles) != old_tiles and ui.board._sector == 2 and not is_instance_valid(old_fog) and ui.board.fog.get_child_count() == 25 * 29, "advancing rebuilds terrain and fog for the new generated sector")
	var matches: bool = true
	for y: int in range(ui.state.run.height):
		for x: int in range(ui.state.run.width):
			var cell: Vector2i = Vector2i(x, y)
			var tile: Dictionary = ui.state.run.tiles[y][x]
			matches = matches and (ui.board.walls.get_cell_source_id(cell) >= 0) == (tile.type == "wall")
	check(matches and ui.board._run.depth == 2 and not is_instance_valid(ui.modal), "drawn wall cells match the new sector collision grid and confirmation closes")

func finished_tween_case() -> void:
	var snapshot := JSON.stringify(ui.state)
	var completed := ui.create_tween()
	completed.tween_interval(0.001)
	ui._track_tween(completed)
	var observed: Array = []
	completed.finished.connect(func():
		check(completed.is_valid() and completed.get_loops_left() == 0, "regression observes the finished-but-still-valid frame")
		ui.board._camera_tween = completed
		ui._sync_presentation()
		ui.board._camera_tween = null
		observed.append(true))
	await completed.finished
	check(observed.size() == 1 and JSON.stringify(ui.state) == snapshot, "presentation synchronization ignores completed UI/camera tweens and changes no turn")

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	ui = Main.instantiate()
	root.add_child(ui)
	await settle()
	for viewport: Vector2i in [Vector2i(390, 844), Vector2i(360, 740), Vector2i(1280, 800)]:
		root.size = viewport
		await settle()
		await take_and_read_case()
		await full_swap_case()
		await depth_case()
	await finished_tween_case()
	ui.queue_free()
	await settle()
	print("v0.6 cargo/depth UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
