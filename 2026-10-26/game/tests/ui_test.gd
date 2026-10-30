extends SceneTree

const RulesData = preload("res://scripts/rules.gd")
const Legacy = preload("res://scripts/legacy_v03_rules.gd")
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
	for test: String in ["test_v06_generated_departure_and_reload", "test_v04_field_allocation", "test_v04_crew_controls", "test_v04_visibility", "test_v04_objective_continuity", "test_v04_objective_layout_roundtrip", "test_v05_harbor_entry_and_basic_loadout", "test_v05_preparation_transfer_and_reload", "test_v05_preparation_reading_pause", "test_v05_immediate_result", "test_v05_extract_feedback", "test_v05_storage_notice_and_corrupt", "test_characters", "test_safe_area", "test_turn_input", "test_storage", "test_result_receipt", "test_inventory_uid_actions", "test_inventory_focus_and_full_health", "test_world_overlay_phone_bounds", "test_presentation_pause_and_motion", "test_empty_extraction_readability", "test_campaign_phone_navigation", "test_campaign_routes_and_follow", "test_campaign_delivery", "test_campaign_exchange", "test_campaign_crew_and_reload", "test_campaign_modal_during_screen_entry", "test_v03_portraits_and_crew_navigation", "test_v03_truthful_result_stages", "test_v03_stage_pause_and_reduced_motion", "test_v03_live_reduced_motion_toggle"]:
		if await call(test) != true:
			failed += 1
			push_error("FAIL: did not complete " + test)
	ui.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	print("UI/store tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

# These existing UI cases intentionally exercise the shipped 25x25 run. Only
# departure uses the frozen generator; every later action uses v3 dispatch.
func apply_ui_action(state: Dictionary, action: Dictionary) -> Dictionary:
	if action.get("type") != "depart":
		return RulesData.apply_action(state, action)
	check(RulesData.validate_state(state) and state.mode == "harbor", "legacy UI departure starts with a valid harbor")
	var old: Dictionary = Legacy.new_game()
	for field: String in ["character", "profile", "loadout", "nextId"]:
		old[field] = state[field].duplicate(true) if state[field] is Dictionary or state[field] is Array else state[field]
	old.profile.erase("commissionCycle")
	var resolved: Dictionary = Legacy.apply_action(old, action)
	resolved.state = RulesData.migrate_state(resolved.state)
	check(not resolved.state.is_empty() and RulesData.validate_state(resolved.state) and resolved.state.run.ruleset == "legacy-v03", "legacy UI fixture passes frozen rules and strict v3 migration")
	return resolved

func test_v06_generated_departure_and_reload() -> bool:
	ui._close_modal()
	ui.state = RulesData.new_game()
	ui._enter()
	await settle_layout()
	var depart: Button = find_button(ui.content, "この装備で出発する")
	if depart == null:
		return false
	var owned: Array = ui.state.profile.stash.duplicate(true)
	depart.pressed.emit()
	await settle_layout()
	check(ui.state.version == 4 and ui.state.run.ruleset == "expedition-v06" and ui.state.run.width == 25 and ui.state.run.height == 29 and RulesData.validate_state(ui.state), "actual harbor departure starts the valid generated v4 ruleset")
	check(ui.state.run.crewCharges == 3 and ui.state.run.inventory.size() == 1 and ui.state.run.inventory[0].kind == "loanKnife", "fresh UI departure shows finite techniques and the retry loan")
	var path := "user://qa-v04-ui.json"
	var snapshot: String = JSON.stringify(ui.state)
	check(Store.save_game(ui.state, "shiogaeri-qa-v04-ui", path).is_empty(), "compact UI state saves through production store into the QA slot")
	var loaded: Dictionary = Store.load_game("shiogaeri-qa-v04-ui", path)
	check(loaded.found and not loaded.corrupt and JSON.stringify(loaded.state) == snapshot and loaded.state.version == 4, "generated UI reload preserves the entire v4 state")
	ui.state = loaded.state
	ui._enter()
	await settle_layout()
	ui.interact_button.pressed.emit()
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot and is_instance_valid(ui.modal), "actual return button opens read-only confirmation at the landing")
	var confirm: Button = find_button(ui.modal, "持ち帰って遠征を終える")
	if confirm == null:
		return false
	confirm.pressed.emit()
	await settle_layout()
	check(ui.state.mode == "result" and ui.state.result.inventory.is_empty() and ui.state.profile.stash == owned and ui.state.profile.extracts == 1 and RulesData.validate_state(ui.state), "compact UI return resolves the loan and concrete ownership once")
	var retry: Button = find_button(ui.content, "港で支度をする")
	if retry == null:
		return false
	retry.pressed.emit()
	await settle_layout()
	check(ui.state.mode == "harbor" and ui.state.version == 4 and ui.state.profile.stash == owned and ui.state.profile.extracts == 1, "generated result returns to the v4 harbor without another transfer")
	check(Store.save_game(ui.state, "shiogaeri-qa-v04-ui", path).is_empty() and Store.load_game("shiogaeri-qa-v04-ui", path).state == ui.state, "completed compact return remains saveable and reloadable")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	var old: Dictionary = apply_ui_action(RulesData.new_game(), {"type": "depart", "seed": 7}).state
	ui.state = old
	ui._enter()
	await settle_layout()
	ui._direction(0, -1)
	check(ui.state.run.width == 25 and ui.state.run.ruleset == "legacy-v03" and ui.state.run.player.y == old.run.player.y - 1 and ui.state.run.turn == 1 and RulesData.validate_state(ui.state), "migrated legacy UI continues its own 25x25 map through the real dispatcher")
	check(ui.field_hud.crew_button.disabled or ui.field_hud.crew_button.text.contains("0/0"), "legacy UI does not advertise available v4 technique charges")
	return true

func test_v04_field_allocation() -> bool:
	for viewport: Vector2i in [Vector2i(390, 844), Vector2i(360, 740), Vector2i(1280, 800)]:
		root.size = viewport
		ui._close_modal()
		ui._apply_safe_area(Vector4.ZERO)
		ui.state = RulesData.apply_action(RulesData.new_game(), {"type": "depart", "seed": 7}).state
		ui._enter()
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var world: Rect2 = ui.field_hud.world_slot.get_global_rect()
		var controls: Rect2 = ui.field_hud.controls_panel.get_global_rect()
		var css: Vector2 = Vector2(viewport) / ui.size
		var minimum: float = 500.0 if viewport.x == 390 else 430.0 if viewport.x == 360 else 700.0
		print("Field allocation: %s world CSS=%s controls CSS=%s" % [viewport, world.size * css, controls.size * css])
		check(world.size.y * css.y >= minimum and fits_visible_stage(ui.field_hud.world_slot), "%s actual unobscured world meets %.0f CSS pixel height" % [viewport, minimum])
		check(not world.intersects(controls) and ui.board.get_global_rect().is_equal_approx(world), "%s field and controls have separate rectangles and the board fills its field" % viewport)
		check(not ui.header.is_visible_in_tree() and not ui.backdrop.is_visible_in_tree(), "%s field removes the permanent harbor brand and backdrop" % viewport)
		var targets: bool = true
		var visible_count: int = 0
		for button: Button in descendant_buttons(ui.field_hud):
			if button.is_visible_in_tree():
				visible_count += 1
				var touch: Vector2 = button.size * css
				var fits: bool = touch.x >= 44 and touch.y >= 44 and fits_visible_stage(button) and not button.get_global_rect().intersects(world)
				if not fits:
					print("Field target diagnostic: %s %s CSS=%s logical=%s rect=%s world=%s" % [viewport, button.name, touch, button.size, button.get_global_rect(), world])
				targets = targets and fits
		check(targets and visible_count >= (4 if viewport.x >= 760 else 10), "%s all visible field buttons fit outside the board with 44 CSS pixel targets" % viewport)
		if viewport.x >= 760:
			var sidebar: Control = ui.field_hud.get_node("%Sidebar")
			print("Desktop sidebar: logical=%s CSS=%s" % [sidebar.size, sidebar.size * css])
			check(sidebar.is_visible_in_tree() and sidebar.size.x >= 260 and sidebar.size.x <= 280 and controls.end.x <= world.position.x, "desktop uses the compact 260 logical pixel sidebar beside the field")
			var toggle: Button = ui.field_hud.get_node("%TouchToggle")
			var snapshot: String = JSON.stringify(ui.state)
			toggle.pressed.emit()
			await settle_layout()
			var opened_world: Rect2 = ui.field_hud.world_slot.get_global_rect()
			var opened_controls: Rect2 = ui.field_hud.controls_panel.get_global_rect()
			check(ui.field_hud.get_node("%Pad").is_visible_in_tree() and JSON.stringify(ui.state) == snapshot and not opened_controls.intersects(opened_world) and opened_world.is_equal_approx(world) and sidebar.size.x <= 280, "desktop optional touch controls open without advancing a turn or shrinking the field")
			var pad_targets: bool = true
			for button: Button in descendant_buttons(ui.field_hud.get_node("%Pad")):
				var touch: Vector2 = button.size * css
				pad_targets = pad_targets and button.is_visible_in_tree() and touch.x >= 44 and touch.y >= 44 and fits_visible_stage(button) and not button.get_global_rect().intersects(opened_world)
			check(pad_targets, "desktop opened touch pad keeps every direction reachable at 44 CSS pixels")
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func test_v04_crew_controls() -> bool:
	ui._close_modal()
	ui.state = RulesData.migrate_state(RulesData.V05.apply_action(RulesData.V05.new_game(), {"type": "depart", "seed": 7}).state)
	ui._enter()
	await settle_layout()
	var snapshot: String = JSON.stringify(ui.state)
	for menu: String in ["_inventory", "_map", "_settings"]:
		ui.call(menu)
		await settle_layout()
		key_press(KEY_UP)
		check(JSON.stringify(ui.state) == snapshot and ui.state.run.crewCharges == 3, "%s modal reading and attempted movement spend no turn or technique" % menu)
		key_press(KEY_ESCAPE)
		await settle_layout()
	key_press(KEY_Q)
	await settle_layout()
	check(is_instance_valid(ui.modal) and label_contains(ui.modal, RulesData.crew_info(ui.state).description) and JSON.stringify(ui.state) == snapshot, "Q opens truthful read-only crew details")
	var target: Button = find_button(ui.modal, "方向を選ぶ / 1手")
	if target == null:
		return false
	target.pressed.emit()
	await settle_layout()
	check(ui.pending_crew and not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "targeted technique requires explicit direction without charging for selection")
	key_press(KEY_ESCAPE)
	await settle_layout()
	check(not ui.pending_crew and not ui.field_hud.status_label.visible and ui.field_hud.get_node("%GoalRow").visible and JSON.stringify(ui.state) == snapshot, "Escape cancels a targeted technique, clears its direction prompt and restores the objective without spending a turn or charge")
	ui._crew_action()
	await settle_layout()
	target = find_button(ui.modal, "方向を選ぶ / 1手")
	if target == null:
		return false
	target.pressed.emit()
	await settle_layout()
	var down: Button = ui.field_hud.get_node("%Down")
	check(down.disabled and not down.tooltip_text.is_empty(), "invalid technique direction visibly explains its unavailable target")
	ui._direction(0, 1)
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot and ui.log_label.is_visible_in_tree() and not ui.log_label.text.is_empty(), "invalid directed technique explains failure and spends neither turn nor charge")
	ui._crew_action()
	await settle_layout()
	target = find_button(ui.modal, "方向を選ぶ / 1手")
	if target == null:
		return false
	target.pressed.emit()
	await settle_layout()
	var origin: Vector2i = Vector2i(ui.state.run.player.x, ui.state.run.player.y)
	var preview: Dictionary = RulesData.preview_action(ui.state, {"type": "crew", "dx": 0, "dy": -1})
	var up: Button = ui.field_hud.get_node("%Up")
	check(preview.valid and not up.disabled and up.tooltip_text.contains(str(preview.damage)), "valid technique direction displays the shared exact damage prediction")
	up.pressed.emit()
	await settle_layout()
	check(ui.state.run.turn == 1 and ui.state.run.crewCharges == 2 and ui.state.run.player.x == origin.x and ui.state.run.player.y == origin.y - 2 and not ui.pending_crew and RulesData.validate_state(ui.state), "actual direction button resolves Isana two-cell technique exactly once")
	check(ui.field_hud.crew_button.text.contains("2/3") and ui.hp_bar.value == ui.state.run.player.hp, "resolved technique HUD shows remaining real charges and health")
	return true

func test_v04_visibility() -> bool:
	ui._close_modal()
	ui.state = RulesData.migrate_state(RulesData.V05.apply_action(RulesData.V05.new_game(), {"type": "depart", "seed": 7}).state)
	# Put one existing enemy in a genuinely visible, legal cell; the distant
	# enemies keep their authored positions behind the current fog.
	ui.state.run.enemies[0].x = 8
	ui.state.run.enemies[0].y = 16
	ui.state.run.seen = RulesData.visible_tiles(ui.state.run).keys()
	check(RulesData.validate_state(ui.state), "compact fog fixture preserves valid map, enemies and ownership")
	ui._enter()
	await settle_layout()
	var snapshot: String = JSON.stringify(ui.state)
	var visible: Dictionary = RulesData.visible_tiles(ui.state.run)
	check(ui.board.get_visible_tiles() == visible, "board visibility uses exactly the rule-owned current sight")
	var visible_count: int = 0
	var hidden_count: int = 0
	var truthful: bool = true
	var hidden: Dictionary = {}
	for enemy: Dictionary in ui.state.run.enemies:
		var expected: bool = visible.has("%d,%d" % [enemy.x, enemy.y])
		var actor: Node2D = ui.board._actor_nodes.get(enemy.id)
		truthful = truthful and actor != null and actor.visible == expected
		if expected:
			visible_count += 1
		else:
			hidden_count += 1
			hidden = enemy
	check(truthful and visible_count > 0 and hidden_count > 0, "compact actors display visible enemies while hiding distant enemies")
	var wait_preview: Dictionary = RulesData.preview_action(ui.state, {"type": "wait"})
	var wait_button: Button = ui.field_hud.get_node("%Wait")
	check(wait_preview.valid and wait_preview.damage > 0 and wait_button.text.contains("−%d" % wait_preview.damage), "direction pad displays the actual positive incoming damage before a threatened wait")
	for threat: Dictionary in RulesData.threats(ui.state):
		var source: Dictionary = {}
		for enemy: Dictionary in ui.state.run.enemies:
			if enemy.id == threat.enemyId:
				source = enemy
		check(not source.is_empty() and visible.has("%d,%d" % [source.x, source.y]), "announced threat belongs to an actually visible enemy")
	if hidden.is_empty():
		return false
	ui._cell_selected(hidden.x, hidden.y)
	await settle_layout()
	check(not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "tapping a hidden enemy cannot inspect or act on concealed data")
	var distant_floor := Vector2i(-1, -1)
	for cell: String in visible:
		var xy: PackedStringArray = cell.split(",")
		var candidate := Vector2i(int(xy[0]), int(xy[1]))
		var distance: int = absi(candidate.x - int(ui.state.run.player.x)) + absi(candidate.y - int(ui.state.run.player.y))
		if distance <= 1 or ui.state.run.tiles[candidate.y][candidate.x].type != "floor":
			continue
		var occupied: bool = false
		for enemy: Dictionary in ui.state.run.enemies:
			occupied = occupied or (int(enemy.x) == candidate.x and int(enemy.y) == candidate.y)
		if not occupied:
			distant_floor = candidate
			break
	check(distant_floor.x >= 0, "distant-tap fixture selects an actually visible non-enemy floor beyond one step")
	if distant_floor.x < 0:
		return false
	ui.field_hud.clear_feedback()
	check(not ui.field_hud.status_label.visible, "distant-tap regression begins with the temporary feedback hidden")
	var turn: int = ui.state.run.turn
	ui._cell_selected(distant_floor.x, distant_floor.y)
	await settle_layout()
	check(ui.field_hud.status_label.visible and ui.field_hud.status_label.text.contains("自動移動") and not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot and ui.state.run.turn == turn, "tapping a distant visible floor reveals the manual-movement explanation without resolving a turn")
	return true

func test_v04_objective_continuity() -> bool:
	ui._close_modal()
	var harbor: Dictionary = progress_through(["beacon"])
	check(harbor.profile.activeContract.is_empty() and "beacon" in harbor.profile.completedContracts and RulesData.validate_state(harbor), "objective continuity starts after the real beacon claim cleared explicit tracking")
	var market: Dictionary = RulesData.apply_action(harbor, {"type": "choose_district", "district": "market"}).state
	market = RulesData.apply_action(market, {"type": "depart", "seed": 7}).state
	check(market.run.ruleset == "expedition-v06" and market.run.district == "market" and market.profile.activeContract.is_empty() and RulesData.validate_state(market), "new compact market departure retains the intentionally empty tracking field")
	ui.state = market
	var snapshot: String = JSON.stringify(ui.state)
	ui._enter()
	await settle_layout()
	check(ui.objective_label.text.contains(RulesData.Campaign.CONTRACTS.pump.title) and JSON.stringify(ui.state) == snapshot and ui.state.run.turn == 0, "market HUD displays its unlocked unfinished story objective without writing tracking or resolving time")
	var personal: Dictionary = RulesData.apply_action(harbor, {"type": "accept_contract", "id": "isana_parcel"}).state
	personal = RulesData.apply_action(personal, {"type": "choose_district", "district": "market"}).state
	personal = RulesData.apply_action(personal, {"type": "depart", "seed": 7}).state
	check(personal.profile.activeContract == "isana_parcel" and personal.run.district == "market" and RulesData.validate_state(personal), "personal objective fixture explicitly tracks a real available job before compact market departure")
	ui.state = personal
	snapshot = JSON.stringify(ui.state)
	ui._enter()
	await settle_layout()
	check(ui.objective_label.text.contains(RulesData.Campaign.CONTRACTS.isana_parcel.title) and not ui.objective_label.text.contains(RulesData.Campaign.CONTRACTS.pump.title) and JSON.stringify(ui.state) == snapshot and ui.state.run.turn == 0, "explicit personal tracking takes priority over the current district story fallback without changing state")
	return true

func test_v04_objective_layout_roundtrip() -> bool:
	ui._close_modal()
	var prepared: Dictionary = supply_contract(RulesData.new_game(), "beacon")
	for item: Dictionary in prepared.profile.stash.duplicate():
		if item.kind in ["core", "scrap"]:
			prepared = RulesData.apply_action(prepared, {"type": "pack", "uid": item.uid}).state
	ui.state = RulesData.apply_action(prepared, {"type": "depart", "seed": 7}).state
	check(RulesData.validate_state(ui.state) and ui.state.run.ruleset == "expedition-v06", "long objective fixture carries the actual ready delivery in a valid compact run")
	root.size = Vector2i(1280, 800)
	ui._enter()
	await settle_layout()
	var hud: Control = ui.field_hud
	var snapshot: String = JSON.stringify(ui.state)
	var expected_objective: String = ui._field_objective()
	var objective: Label = hud.objective_label
	var turn: Label = hud.turn_label
	var value: Label = hud.value_label
	var expected_turn: String = turn.text
	var expected_value: String = value.text
	var goal_row: Control = hud.get_node("%GoalRow")
	var summary: Control = hud.get_node("%DesktopSummary")
	var timer: Timer = hud.get_node("%FeedbackTimer")
	var original_wait: float = timer.wait_time
	for viewport: Vector2i in [Vector2i(1280, 800), Vector2i(360, 740), Vector2i(1280, 800), Vector2i(390, 844)]:
		root.size = viewport
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var wide: bool = viewport.x >= 760
		check(ui.field_hud == hud and objective.text == expected_objective and JSON.stringify(ui.state) == snapshot, "%s resize keeps the existing HUD and real long objective without changing state" % viewport)
		if wide:
			var sidebar: Control = hud.get_node("%Sidebar")
			check(turn.get_parent() == summary and value.get_parent() == summary and summary.is_visible_in_tree(), "%s desktop puts the real turn and cargo value on the separate summary row" % viewport)
			print("Objective allocation: text=%s lines=%d visible=%d size=%s minimum=%s goal=%s sidebar=%s" % [objective.text, objective.get_line_count(), objective.get_visible_line_count(), objective.size, objective.get_minimum_size(), goal_row.size, sidebar.size])
			check(objective.autowrap_mode != TextServer.AUTOWRAP_OFF and objective.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and objective.get_line_count() >= 1 and objective.get_visible_line_count() == objective.get_line_count() and objective.size.y >= objective.get_minimum_size().y and objective.size.x >= goal_row.size.x - 1 and inside_clipping_ancestors(objective) and sidebar.size.x >= 260 and sidebar.size.x <= 280, "%s long return instruction wraps in the full sidebar width with every line allocated and no sidebar growth" % viewport)
			objective.text = expected_objective.repeat(2)
			await settle_layout()
			check(objective.get_line_count() >= 2 and objective.get_visible_line_count() == objective.get_line_count() and objective.size.y >= objective.get_minimum_size().y and objective.size.x >= goal_row.size.x - 1 and inside_clipping_ancestors(objective) and sidebar.size.x <= 280 and JSON.stringify(ui.state) == snapshot, "%s a longer copy of the actual instruction wraps every line without growing the sidebar or changing state" % viewport)
			objective.text = expected_objective
			await settle_layout()
			check(objective.text == ui._field_objective() and turn.is_visible_in_tree() and value.is_visible_in_tree(), "%s the real objective and summary return after the long-text allocation stress check" % viewport)
		else:
			check(turn.get_parent() == goal_row and value.get_parent() == goal_row and not summary.is_visible_in_tree() and objective.autowrap_mode == TextServer.AUTOWRAP_OFF and objective.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s returning to phone restores the compact inline objective and summary" % viewport)
		check(turn.is_visible_in_tree() and value.is_visible_in_tree() and turn.text == expected_turn and value.text == expected_value and inside_clipping_ancestors(turn) and inside_clipping_ancestors(value), "%s the actual turn and cargo value remain visible and readable" % viewport)
		hud.show_feedback("Temporary field feedback", true)
		await settle_layout()
		check(hud.status_label.is_visible_in_tree() and not objective.is_visible_in_tree() and not turn.is_visible_in_tree() and not value.is_visible_in_tree() and not summary.is_visible_in_tree(), "%s temporary feedback hides the objective and both summary values" % viewport)
		hud.clear_feedback()
		await settle_layout()
		check(not hud.status_label.visible and objective.is_visible_in_tree() and turn.is_visible_in_tree() and value.is_visible_in_tree() and summary.visible == wide, "%s clearing feedback restores the correct phone or desktop summary" % viewport)
		timer.wait_time = 0.02
		hud.show_feedback("Timed field feedback")
		await create_timer(0.06).timeout
		await settle_layout()
		check(timer.is_stopped() and not hud.status_label.visible and objective.is_visible_in_tree() and turn.is_visible_in_tree() and value.is_visible_in_tree() and summary.visible == wide and JSON.stringify(ui.state) == snapshot, "%s the real feedback timeout restores the objective and summary without changing the game" % viewport)
	timer.wait_time = original_wait
	return true

func test_v05_harbor_entry_and_basic_loadout() -> bool:
	for viewport: Vector2i in [Vector2i(390, 844), Vector2i(360, 740), Vector2i(1280, 800)]:
		root.size = viewport
		ui._close_modal()
		ui._apply_safe_area(Vector4.ZERO)
		ui.state = RulesData.new_game()
		ui.harbor_feedback = ""
		ui._enter()
		await settle_layout()
		var view: Control = ui.harbor_view
		var basic: Button = view.get_node("%BasicLoadout")
		var prepare: Button = view.get_node("%OpenPreparation")
		var css: Vector2 = Vector2(viewport) / ui.size
		check(view.get_script().resource_path.ends_with("presentation_v05/harbor.gd") and not view.preparation_open and view.get_node("%PreparationPane").is_visible_in_tree() == (viewport.x >= 760), "%s Main starts in the new harbor with preparation explicitly closed" % viewport)
		check(view.stage_slot.get_child_count() == 0 and view.get_node("%Portrait").is_visible_in_tree() and texture_base_path(view.get_node("%Portrait").texture) == "res://assets/art/v03/portraits/isana.png", "%s actual harbor retains the detailed worker portrait until a new stage is adopted" % viewport)
		var pinned: bool = true
		for button: Button in ([basic, prepare, view.departure_button] if viewport.x < 760 else [basic, view.departure_button]):
			var touch: Vector2 = button.size * css
			pinned = pinned and button.is_visible_in_tree() and inside_clipping_ancestors(button) and touch.x >= 44 and touch.y >= 44
		check(pinned and not basic.disabled, "%s basic loadout and departure plus the phone preparation entry are immediately visible and usable" % viewport)
		if viewport.x >= 760:
			check(not prepare.is_visible_in_tree() and view.get_node("%PreparationPane").is_visible_in_tree() and is_equal_approx(basic.size.x, view.get_node("%QuickPreparation").size.x), "desktop exposes the full-width basic action without pretending the permanent preparation can close")
		var roster: Button = meta_button(view, "character_id", "sui")
		check(roster != null and roster.text.is_empty() and roster.accessibility_name == RulesData.CHARACTERS.sui.name and find_label(roster, RulesData.CHARACTERS.sui.name) != null, "%s portrait roster exposes the actual character through metadata and accessible inner text" % viewport)
		if roster == null:
			return false
		var expected: Dictionary = RulesData.apply_action(ui.state, {"type": "choose", "character": "sui"}).state
		roster.pressed.emit()
		await settle_layout()
		check(ui.state == expected and ui.state.character == "sui", "%s actual roster signal changes only the chosen worker through Rules" % viewport)
		var source: Dictionary = ui.state.duplicate(true)
		basic = ui.harbor_view.get_node("%BasicLoadout")
		basic.pressed.emit()
		await settle_layout()
		await settle_layout()
		var kinds: Array[String] = []
		var exact_uids: bool = true
		for item: Dictionary in ui.state.loadout:
			kinds.append(item.kind)
			exact_uids = exact_uids and item in source.profile.stash
		kinds.sort()
		check(kinds == ["bomb", "coat", "flare", "knife", "medicine"] and exact_uids and ui.state.profile.runs == 0 and ui.state.run == null and RulesData.validate_state(ui.state), "%s pinned basic preparation transfers one real UID of each eligible type without departing" % viewport)
		print("BASIC bounds diagnostic viewport=%s root=%s view=%s basic=%s departure=%s" % [viewport,ui.get_global_rect(),ui.harbor_view.get_global_rect(),ui.harbor_view.get_node("%BasicLoadout").get_global_rect(),ui.harbor_view.departure_button.get_global_rect()])
		check(not ui.harbor_view.preparation_open and inside_clipping_ancestors(ui.harbor_view.get_node("%BasicLoadout")), "%s quick preparation leaves the harbor showcase and shortcut available" % viewport)
		var snapshot: String = JSON.stringify(ui.state)
		if viewport.x < 760:
			ui.harbor_view.get_node("%OpenPreparation").pressed.emit()
			await settle_layout()
			check(ui.harbor_view.preparation_open and ui.harbor_view.get_node("%PreparationPane").is_visible_in_tree() and JSON.stringify(ui.state) == snapshot, "%s opening preparation shows real cargo without changing ownership or time" % viewport)
			key_press(KEY_ESCAPE)
			await settle_layout()
			check(not ui.harbor_view.preparation_open and not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "%s Escape closes the preparation pane before settings and does not resolve a rule action" % viewport)
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func test_v05_preparation_transfer_and_reload() -> bool:
	for viewport: Vector2i in [Vector2i(390, 844), Vector2i(360, 740), Vector2i(1280, 800)]:
		root.size = viewport
		ui._close_modal()
		var prepared: Dictionary = RulesData.new_game()
		for index: int in range(24):
			prepared.profile.stash.append(RulesData._new_item(prepared, "scrap"))
		check(RulesData.validate_state(prepared), "%s long preparation fixture has actual unique owned item IDs" % viewport)
		ui.state = prepared
		ui.harbor_feedback = ""
		ui._enter()
		await settle_layout()
		if viewport.x < 760:
			ui.harbor_view.get_node("%OpenPreparation").pressed.emit()
		await settle_layout()
		var uid: String = ui.state.profile.stash[-3].uid
		var transfer: Button = meta_button(ui.harbor_view.get_node("%StashItems"), "item_uid", uid)
		if transfer == null:
			return false
		transfer.grab_focus()
		await settle_layout()
		var before: Dictionary = ui.harbor_view.capture_preparation_state()
		check(before.open == (viewport.x < 760) and before.scroll > 0 and before.focus_uid == uid and inside_clipping_ancestors(transfer), "%s a late stash item can be focused and scrolled into the open preparation pane" % viewport)
		var expected: Dictionary = RulesData.apply_action(ui.state, {"type": "pack", "uid": uid}).state
		transfer.pressed.emit()
		await settle_layout()
		await settle_layout()
		var carry: Button = meta_button(ui.harbor_view.get_node("%CarryItems"), "item_uid", uid)
		var after: Dictionary = ui.harbor_view.capture_preparation_state()
		print("PACK focus diagnostic viewport=%s before=%s after=%s focused=%s carryfocus=%s carryrect=%s scrollrect=%s" % [viewport,before,after,ui.get_viewport().gui_get_focus_owner(),carry.has_focus() if carry != null else false,carry.get_global_rect() if carry != null else Rect2(),ui.harbor_view.preparation_scroll.get_global_rect()])
		check(ui.state == expected and ui.harbor_view.preparation_open == (viewport.x < 760) and ui.state.loadout[-1].uid == uid and not stash_has(uid) and RulesData.validate_state(ui.state), "%s actual pack callback moves the selected UID once and keeps preparation open" % viewport)
		check(carry != null and carry.has_focus() and after.focus_uid == uid and inside_clipping_ancestors(carry), "%s reconstructed preparation follows keyboard focus to that exact UID in the carry bag" % viewport)
		if carry == null:
			return false
		expected = RulesData.apply_action(ui.state, {"type": "unpack", "uid": uid}).state
		carry.pressed.emit()
		await settle_layout()
		await settle_layout()
		transfer = meta_button(ui.harbor_view.get_node("%StashItems"), "item_uid", uid)
		after = ui.harbor_view.capture_preparation_state()
		print("UNPACK focus diagnostic viewport=%s after=%s transferfocus=%s transferrect=%s scrollrect=%s" % [viewport,after,transfer.has_focus() if transfer != null else false,transfer.get_global_rect() if transfer != null else Rect2(),ui.harbor_view.preparation_scroll.get_global_rect()])
		check(ui.state == expected and ui.harbor_view.preparation_open == (viewport.x < 760) and stash_has(uid) and ui.state.loadout.is_empty(), "%s actual unpack returns the same UID to stash without a second transfer or closing preparation" % viewport)
		check(transfer != null and transfer.has_focus() and after.focus_uid == uid and after.scroll > 0 and inside_clipping_ancestors(transfer), "%s unpack restores the selected stash UID and its scroll visibility after rebuilding" % viewport)
		var snapshot: String = JSON.stringify(ui.state)
		var retained_scroll: int = ui.harbor_view.preparation_scroll.scroll_vertical
		ui._render()
		await settle_layout()
		await settle_layout()
		after = ui.harbor_view.capture_preparation_state()
		print("READONLY scroll diagnostic viewport=%s retained=%d after=%s" % [viewport,retained_scroll,after])
		check(ui.harbor_view.preparation_open == (viewport.x < 760) and after.focus_uid == uid and absi(int(after.scroll) - retained_scroll) <= 1 and JSON.stringify(ui.state) == snapshot, "%s a read-only harbor rebuild preserves open state, scroll and focused item UID exactly" % viewport)
		var path := "user://qa-v05-preparation.json"
		check(Store.save_game(ui.state, "shiogaeri-qa-v05-preparation", path).is_empty(), "%s preparation state saves only the real game data into a QA slot" % viewport)
		var loaded: Dictionary = Store.load_game("shiogaeri-qa-v05-preparation", path)
		check(loaded.found and not loaded.corrupt and JSON.stringify(loaded.state) == snapshot, "%s transferred ownership and selected worker survive the real store reload" % viewport)
		ui.state = loaded.state
		ui._enter()
		await settle_layout()
		check(not ui.harbor_view.preparation_open and ui.state.profile.stash[-1].uid == uid and JSON.stringify(ui.state) == snapshot, "%s reload opens a clean harbor while preserving every real owned item" % viewport)
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func test_v05_preparation_reading_pause() -> bool:
	ui._close_modal()
	ui.state = RulesData.new_game()
	var previous_reduced: bool = ui.settings.reduced
	ui.settings.reduced = false
	ui._enter()
	await settle_layout()
	var snapshot: String = JSON.stringify(ui.state)
	ui.harbor_view.open_preparation()
	await settle_layout()
	var clock: float = ui.scenery.clock
	await create_timer(0.07).timeout
	check(is_equal_approx(ui.scenery.clock, clock) and JSON.stringify(ui.state) == snapshot, "preparation reading pauses the actual harbor background without changing the save")
	ui._settings()
	await settle_layout()
	key_press(KEY_ESCAPE)
	await settle_layout()
	await create_timer(0.06).timeout
	check(ui.harbor_view.preparation_open and is_equal_approx(ui.scenery.clock, clock) and JSON.stringify(ui.state) == snapshot, "closing settings preserves preparation reading and keeps the background paused")
	key_press(KEY_ESCAPE)
	await settle_layout()
	await create_timer(0.06).timeout
	check(not ui.harbor_view.preparation_open and ui.scenery.clock > clock and JSON.stringify(ui.state) == snapshot, "closing preparation resumes only presentation and never advances harbor time")
	root.size = Vector2i(1280, 800)
	ui._enter()
	await settle_layout()
	var transfer: Button = meta_button(ui.harbor_view.get_node("%StashItems"), "item_uid", ui.state.profile.stash[0].uid)
	if transfer == null:
		return false
	transfer.grab_focus()
	await settle_layout()
	clock = ui.scenery.clock
	await create_timer(0.06).timeout
	check(not ui.harbor_view.preparation_open and ui.harbor_view.get_node("%PreparationPane").is_visible_in_tree() and is_equal_approx(ui.scenery.clock, clock) and JSON.stringify(ui.state) == snapshot, "focusing the always-visible desktop preparation pauses the background even without opening a phone pane")
	ui.harbor_view.departure_button.grab_focus()
	await settle_layout()
	await create_timer(0.06).timeout
	check(ui.scenery.clock > clock and JSON.stringify(ui.state) == snapshot, "leaving desktop preparation focus resumes presentation without changing the game")
	root.size = Vector2i(390, 844)
	ui._render()
	await settle_layout()
	ui.harbor_view.get_node("%OpenPreparation").pressed.emit()
	await settle_layout()
	var reading_uid: String = ui.state.profile.stash[-1].uid
	meta_button(ui.harbor_view.get_node("%StashItems"), "item_uid", reading_uid).grab_focus()
	await settle_layout()
	for viewport: Vector2i in [Vector2i(1280, 800), Vector2i(390, 844)]:
		root.size = viewport
		await create_timer(0.24).timeout
		await settle_layout()
		var reading: Dictionary = ui.harbor_view.capture_preparation_state()
		var focused_item: Button = meta_button(ui.harbor_view.get_node("%StashItems"), "item_uid", reading_uid)
		check(reading.open and reading.focus_uid == reading_uid and focused_item.has_focus() and inside_clipping_ancestors(focused_item) and JSON.stringify(ui.state) == snapshot, "%s phone-wide-phone resize preserves the open reading context and visible exact UID" % viewport)
		check(ui.harbor_view.get_node("%OpenPreparation").is_visible_in_tree() == (viewport.x < 760), "%s only phone layout offers a preparation toggle" % viewport)
		clock = ui.scenery.clock
		await create_timer(0.06).timeout
		check(is_equal_approx(ui.scenery.clock, clock), "%s resizing while reading keeps the background paused" % viewport)
	key_press(KEY_ESCAPE)
	await settle_layout()
	check(not ui.harbor_view.preparation_open and ui.harbor_view.get_node("%OpenPreparation").has_focus() and JSON.stringify(ui.state) == snapshot, "returning to phone preserves Escape closure and restores visible entry focus")
	ui.settings.reduced = previous_reduced
	ui._render()
	await settle_layout()
	return true

func test_v05_immediate_result() -> bool:
	ui._close_modal()
	var previous_reduced: bool = ui.settings.reduced
	for outcome: String in ["extracted", "empty", "dead"]:
		ui.state = staged_receipt("isana", outcome)
		var snapshot: String = JSON.stringify(ui.state)
		render_receipt_with_motion(false)
		var view: Control = ui.result_view
		var receipt: Dictionary = ui.state.result
		check(view != null and view.get_script().resource_path.ends_with("presentation_v05/result.gd") and view.get_node("%Value").text == "%d pt" % receipt.value and view.get_node("%Count").text.begins_with(str(receipt.inventory.size())) and view.get_node("%Turns").text == "%d手の遠征" % receipt.turns and view.continue_button != null and not view.continue_button.disabled, "%s new result exposes exact value, count, turn and next action before any animation frame" % outcome)
		var stage: Control = receipt_stage()
		check(stage != null and stage.get_parent() == view.stage_slot and stage.phase == ("loss" if outcome == "dead" else "arrival") and stage.celebrate == (outcome == "extracted"), "%s Main attaches the real outcome stage to the new result component" % outcome)
		await settle_layout()
		check(JSON.stringify(ui.state) == snapshot and inside_clipping_ancestors(view.continue_button), "%s result animation preserves the already-resolved receipt and pinned return action" % outcome)
	ui.settings.reduced = previous_reduced
	ui._render()
	await settle_layout()
	return true

func test_v05_storage_notice_and_corrupt() -> bool:
	ui._close_modal()
	root.size = Vector2i(360, 740)
	ui.state = RulesData.new_game()
	ui._enter()
	await settle_layout()
	var snapshot: String = JSON.stringify(ui.state)
	var blocked := "user://qa-v05-blocked-store"
	DirAccess.make_dir_absolute(blocked)
	var error: String = Store.save_game(ui.state, "shiogaeri-qa-v05-blocked-store", blocked)
	ui._set_notice(error)
	await settle_layout()
	check(not error.is_empty() and ui.notice.is_visible_in_tree() and ui.notice.text == error and fits_visible_stage(ui.notice) and fits_visible_stage(ui.harbor_view.departure_button) and JSON.stringify(ui.state) == snapshot, "new harbor keeps the actual storage failure and primary action visible at the small phone size")
	ui._set_notice("")
	DirAccess.remove_absolute(blocked)
	ui.corrupt = true
	ui.screen = "title"
	ui._render()
	ui._begin()
	await settle_layout()
	check(ui.corrupt and is_instance_valid(ui.modal) and find_button(ui.modal, "新しく始める") != null and fits_visible_stage(ui.modal_panel) and JSON.stringify(ui.state) == snapshot, "corrupt-save entry still requires the existing visible replacement decision without writing state")
	key_press(KEY_ESCAPE)
	await settle_layout()
	check(ui.corrupt and not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot, "cancelling corrupt-save confirmation preserves the original refusal to overwrite")
	ui.corrupt = false
	ui._enter()
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func test_characters() -> bool:
	check(ui.qa_session, "QA does not overwrite real saves")
	for key: String in RulesData.CHARACTERS:
		ui.state = apply_ui_action(RulesData.new_game(), {"type": "choose", "character": key}).state
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
	prepared = apply_ui_action(prepared, {"type": "pack", "uid": medicine_uid}).state
	ui.state = apply_ui_action(prepared, {"type": "depart", "seed": 7}).state
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
	state = apply_ui_action(state, {"type": "pack", "uid": uid}).state
	state = apply_ui_action(state, {"type": "depart", "seed": 7}).state
	state = apply_ui_action(state, {"type": "interact"}).state
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
		if child is Button and (child.text == text or child.accessibility_name == text or (child.text.is_empty() and find_label(child, text) != null)):
			return child
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func expedition_with_duplicates() -> Dictionary:
	var prepared: Dictionary = RulesData.new_game()
	for item: Dictionary in prepared.profile.stash.duplicate():
		prepared = apply_ui_action(prepared, {"type": "pack", "uid": item.uid}).state
	return apply_ui_action(prepared, {"type": "depart", "seed": 7}).state

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
	check(is_instance_valid(ui.modal) and RulesData.validate_state(ui.state), "medicine keeps inventory open with a saveable resolved state")
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
		var world_rect: Rect2 = ui.field_hud.world_slot.get_global_rect()
		var all_separate: bool = true
		var all_inside: bool = true
		var touch_targets: bool = true
		var scale_to_phone: Vector2 = Vector2(phone) / ui.size
		for button: Button in buttons:
			all_separate = all_separate and not button.get_global_rect().intersects(world_rect)
			all_inside = all_inside and fits_visible_stage(button)
			var css_size: Vector2 = button.size * scale_to_phone
			touch_targets = touch_targets and css_size.x >= 44 and css_size.y >= 44
		check(all_separate, "%s actionable field controls occupy space outside the world" % phone)
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
		state = apply_ui_action(state, {"type": "depart", "seed": 7}).state
		check(state.run.inventory.size() == 1 and state.run.inventory[0].kind == "loanKnife", "%s empty-return route actually borrows a knife" % phone)
		state = apply_ui_action(state, {"type": "interact"}).state
		check(state.mode == "result" and state.result.outcome == "extracted" and state.result.inventory.is_empty() and state.profile.stash == stash, "%s actual extraction returns the loan without creating a reward" % phone)
		ui.state = state
		var snapshot: String = JSON.stringify(ui.state)
		ui._enter()
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var empty: Label = ui.result_view.get_node("%Ownership")
		check(empty != null and empty.text == "持ち帰った品はありません。", "%s empty extraction explains its empty receipt" % phone)
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

func meta_button(parent: Node, key: String, value: String) -> Button:
	for button: Button in descendant_buttons(parent):
		if str(button.get_meta(key, "")) == value and (key != "item_uid" or button.get_meta("item_action", "transfer") == "transfer"):
			return button
	return null

func label_contains(parent: Node, fragment: String) -> bool:
	for child: Node in parent.get_children():
		if child is Label and child.text.contains(fragment):
			return true
		if label_contains(child, fragment):
			return true
	return false

func inside_clipping_ancestors(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().grow(1).encloses(rect):
			return false
		ancestor = ancestor.get_parent()
	return fits_visible_stage(control)

func stash_has(uid: String) -> bool:
	for item: Dictionary in ui.state.profile.stash:
		if item.uid == uid:
			return true
	return false

# Progression fixtures add concrete resources with fresh UIDs. They are validated
# before use; all completion, packing, extraction and trading still use Rules.
func supply_contract(state: Dictionary, id: String) -> Dictionary:
	var prepared: Dictionary = state.duplicate(true)
	for kind: String in RulesData.Campaign.CONTRACTS[id].requirements:
		var required: int = RulesData.Campaign.CONTRACTS[id].requirements[kind]
		var owned: int = 0
		for item: Dictionary in prepared.profile.stash:
			if item.kind == kind:
				owned += 1
		for count: int in range(maxi(0, required - owned)):
			prepared.profile.stash.append({"uid": "i%d" % prepared.nextId, "kind": kind})
			prepared.nextId += 1
	check(RulesData.validate_state(prepared), "resource fixture for %s remains a valid owned-item state" % id)
	return prepared

func progress_through(ids: Array) -> Dictionary:
	var prepared: Dictionary = RulesData.new_game()
	for id: String in ids:
		prepared = supply_contract(prepared, id)
		prepared = apply_ui_action(prepared, {"type": "claim_contract", "id": id}).state
	check(RulesData.validate_state(prepared), "campaign fixture resolves real claims into a valid harbor")
	return prepared

func test_campaign_phone_navigation() -> bool:
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(360, 740)]:
		root.size = phone
		ui._close_modal()
		ui.state = RulesData.new_game()
		ui.harbor_feedback = ""
		ui._enter()
		await settle_layout()
		ui._resize_layout()
		await settle_layout()
		var snapshot: String = JSON.stringify(ui.state)
		for entry: Array in [["依頼帳", "jobs"], ["航路", "routes"], ["物資交換", "exchange"], ["イサナと話す", "crew"]]:
			var opener: Button = find_button(ui.content, entry[0])
			check(opener != null, "%s harbor exposes %s" % [phone, entry[1]])
			if opener == null:
				return false
			opener.grab_focus()
			await settle_layout()
			var scale_to_phone: Vector2 = Vector2(phone) / ui.size
			var opener_css: Vector2 = opener.size * scale_to_phone
			check(inside_clipping_ancestors(opener) and opener.size.x >= 52 and opener.size.y >= 52 and opener_css.x >= 44 and opener_css.y >= 44, "%s %s harbor action is reachable at a usable touch size" % [phone, entry[1]])
			opener.pressed.emit()
			await settle_layout()
			check(is_instance_valid(ui.modal_panel) and fits_visible_stage(ui.modal_panel), "%s %s panel fits the phone" % [phone, entry[1]])
			var buttons: Array[Button] = descendant_buttons(ui.modal)
			var targets_fit: bool = true
			var enabled_count: int = 0
			var reached: Dictionary = {}
			for button: Button in buttons:
				var css: Vector2 = button.size * scale_to_phone
				targets_fit = targets_fit and button.size.x >= 52 and button.size.y >= 52 and css.x >= 44 and css.y >= 44
				if not button.disabled:
					enabled_count += 1
			var reachable: bool = true
			for step: int in range(enabled_count):
				key_press(KEY_TAB)
				await settle_layout()
				var focused: Control = ui.get_viewport().gui_get_focus_owner()
				reachable = reachable and is_instance_valid(focused) and ui.modal.is_ancestor_of(focused) and inside_clipping_ancestors(focused)
				if is_instance_valid(focused):
					reached[focused.get_instance_id()] = true
			check(targets_fit, "%s %s actions retain 52 logical and 44 CSS pixel targets" % [phone, entry[1]])
			check(reachable and reached.size() == enabled_count, "%s Tab reaches and scrolls every enabled %s action into view" % [phone, entry[1]])
			key_press(KEY_ESCAPE)
			await settle_layout()
			check(JSON.stringify(ui.state) == snapshot, "%s reading and focusing %s does not alter state or time" % [phone, entry[1]])
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func test_campaign_routes_and_follow() -> bool:
	ui.state = RulesData.new_game()
	ui._enter()
	ui._campaign("routes")
	await settle_layout()
	for id: String in RulesData.Campaign.DISTRICTS:
		var route: Button = meta_button(ui.modal, "district_id", id)
		check(route != null and route.disabled, "initial %s route is selected or locked" % id)
		var expected: String = "灯台の波止場 / 選択中" if id == "quay" else RulesData.Campaign.DISTRICTS[id].lockReason
		check(label_contains(ui.modal, expected), "route page explains the actual %s selection or lock" % id)
	ui._close_modal()
	ui.state = progress_through(["beacon", "pump", "channel"])
	ui._enter()
	for id: String in ["market", "canal", "observatory", "quay"]:
		ui._campaign("routes")
		await settle_layout()
		var route: Button = meta_button(ui.modal, "district_id", id)
		check(route != null and not route.disabled, "unlocked %s route can be selected" % id)
		if route == null:
			return false
		route.pressed.emit()
		await settle_layout()
		check(ui.state.profile.selectedDistrict == id and label_contains(ui.modal, RulesData.Campaign.DISTRICTS[id].name + " / 選択中"), "%s route callback selects and displays its own district ID" % id)
	ui._campaign("jobs")
	await settle_layout()
	var follow: Button = meta_button(ui.modal, "contract_id", "network")
	check(follow != null and not follow.disabled, "unlocked final job can be tracked")
	if follow == null:
		return false
	follow.pressed.emit()
	await settle_layout()
	check(ui.state.profile.activeContract == "network" and ui.state.profile.selectedDistrict == "observatory" and RulesData.validate_state(ui.state), "following a job dispatches its actual ID and chooses its destination")
	ui._close_modal()
	ui.state = apply_ui_action(ui.state, {"type": "depart", "seed": 7}).state
	ui._enter()
	await settle_layout()
	var snapshot: String = JSON.stringify(ui.state)
	for page: String in ["jobs", "routes", "exchange", "crew"]:
		ui._campaign(page)
	check(not is_instance_valid(ui.modal) and JSON.stringify(ui.state) == snapshot and ui.state.run.turn == 0, "harbor campaign pages cannot open or change an active expedition turn")
	return true

func test_campaign_delivery() -> bool:
	var prepared: Dictionary = supply_contract(RulesData.new_game(), "beacon")
	var material_uids: Array[String] = []
	for item: Dictionary in prepared.profile.stash.duplicate():
		if item.kind in ["core", "scrap"]:
			material_uids.append(item.uid)
			prepared = apply_ui_action(prepared, {"type": "pack", "uid": item.uid}).state
	prepared = apply_ui_action(prepared, {"type": "depart", "seed": 7}).state
	prepared = apply_ui_action(prepared, {"type": "interact"}).state
	check(prepared.result.inventory.size() == 2 and RulesData.validate_state(prepared), "delivery fixture extracts concrete materials into an already-owned receipt")
	ui.state = prepared
	ui._enter()
	await settle_layout()
	var return_to_harbor: Button = find_button(ui.content, "港で支度をする")
	if return_to_harbor == null:
		return false
	return_to_harbor.pressed.emit()
	await settle_layout()
	ui._campaign("jobs")
	await settle_layout()
	var deliver: Button = meta_button(ui.modal, "delivery_id", "beacon")
	check(deliver != null and not deliver.disabled and label_contains(ui.modal, "灯台の集光芯   1 / 1"), "returned real stash materials enable the matching delivery")
	if deliver == null:
		return false
	var snapshot: String = JSON.stringify(ui.state)
	deliver.pressed.emit()
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot and label_contains(ui.modal, "灯台の集光芯 × 1"), "delivery opens a concrete, read-only requirements confirmation")
	var confirm: Button = find_button(ui.modal, "品を渡して依頼を完了する")
	if confirm == null:
		return false
	confirm.pressed.emit()
	await settle_layout()
	var consumed: bool = true
	for uid: String in material_uids:
		consumed = consumed and not stash_has(uid)
	check(consumed and ui.state.profile.credits == 20 and ui.state.profile.completedContracts == ["beacon"] and ui.state.profile.lampRepaired, "confirmed delivery consumes actual material UIDs once and awards the real harbor progress")
	check(RulesData.Campaign.unlocked(ui.state, "market") and meta_button(ui.modal, "delivery_id", "beacon") == null and RulesData.validate_state(ui.state), "claimed job becomes complete and opens the market without stale receipt ownership")
	check(label_contains(ui.modal, "灯台の集光芯 × 1 / 納品済み"), "claimed delivery describes consumed requirements as delivered")
	snapshot = JSON.stringify(ui.state)
	ui._campaign_action({"type": "claim_contract", "id": "beacon"}, "jobs")
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot, "a repeated delivery callback cannot consume or reward twice")
	ui._close_modal()
	return true

func test_campaign_modal_during_screen_entry() -> bool:
	ui._close_modal()
	ui.state = RulesData.new_game()
	ui._enter()
	await settle_layout()
	var previous_reduced: bool = ui.settings.reduced
	check(ui.qa_session, "entry-animation regression starts with player-save protection enabled")
	var snapshot: String = JSON.stringify(ui.state)
	for page: String in ["jobs", "routes", "exchange", "crew"]:
		ui._close_modal()
		# Only construct controls while QA is off, so the real fade starts. No
		# action, settings callback, or persistence call may run in this section.
		ui.qa_session = false
		ui.settings.reduced = false
		ui._render()
		var fade_started: bool = is_zero_approx(ui.content.modulate.a)
		ui._campaign(page)
		ui.qa_session = true
		ui.settings.reduced = previous_reduced
		check(fade_started and is_equal_approx(ui.content.modulate.a, 1.0), "%s opened during real screen entry keeps the rebuilt harbor visible immediately" % page)
		await create_timer(0.34).timeout
		await settle_layout()
		check(is_equal_approx(ui.content.modulate.a, 1.0) and is_instance_valid(ui.modal_panel) and is_equal_approx(ui.modal_panel.modulate.a, 1.0), "%s overlay finishes appearing while the paused harbor remains visible" % page)
		check(JSON.stringify(ui.state) == snapshot and RulesData.validate_state(ui.state) and ui.qa_session, "%s entry and modal animation leave state unchanged with QA protection restored" % page)
	ui._close_modal()
	ui.settings.reduced = previous_reduced
	ui._render()
	await settle_layout()
	return true

func test_campaign_exchange() -> bool:
	ui.state = RulesData.new_game()
	ui._enter()
	ui._campaign("exchange")
	await settle_layout()
	var all_unaffordable: bool = true
	for kind: String in RulesData.Campaign.SHOP:
		var buy: Button = meta_button(ui.modal, "buy_kind", kind)
		all_unaffordable = all_unaffordable and buy != null and buy.disabled and buy.text.contains(str(RulesData.Campaign.SHOP[kind]))
	check(all_unaffordable and label_contains(ui.modal, "港の所持金  0 G"), "zero real credits disable every purchase at its recorded price")
	var second_uid: String = ui.state.profile.stash[3].uid
	var first_uid: String = ui.state.profile.stash[2].uid
	var sell: Button = meta_button(ui.modal, "sell_uid", second_uid)
	if sell == null:
		return false
	var snapshot: String = JSON.stringify(ui.state)
	sell.pressed.emit()
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot and label_contains(ui.modal, "リツの救護棚") and label_contains(ui.modal, "救急包を8 Gで売ります。"), "selling a quest supply warns with its actual job and price before changing ownership")
	var cancel: Button = find_button(ui.modal, "売らずに戻る")
	if cancel == null:
		return false
	cancel.pressed.emit()
	await settle_layout()
	check(JSON.stringify(ui.state) == snapshot, "cancelling a sale keeps both duplicate supplies and credits")
	sell = meta_button(ui.modal, "sell_uid", second_uid)
	sell.pressed.emit()
	await settle_layout()
	var confirm: Button = find_button(ui.modal, "この品を売る")
	if confirm == null:
		return false
	confirm.pressed.emit()
	await settle_layout()
	check(not stash_has(second_uid) and stash_has(first_uid) and ui.state.profile.credits == 8, "sale callback removes only the chosen duplicate UID and credits its real value")
	var knife_uid: String = ui.state.profile.stash[0].uid
	sell = meta_button(ui.modal, "sell_uid", knife_uid)
	if sell == null:
		return false
	sell.pressed.emit()
	await settle_layout()
	check(not stash_has(knife_uid) and ui.state.profile.credits == 20, "nonquest sale immediately trades the actual knife for 12 credits")
	var buy_medicine: Button = meta_button(ui.modal, "buy_kind", "medicine")
	var expensive: Button = meta_button(ui.modal, "buy_kind", "coat")
	check(buy_medicine != null and not buy_medicine.disabled and expensive != null and expensive.disabled, "purchase affordances update against the actual 20 credits")
	if buy_medicine == null:
		return false
	var next_uid: String = "i%d" % ui.state.nextId
	var stash_count: int = ui.state.profile.stash.size()
	buy_medicine.pressed.emit()
	await settle_layout()
	check(ui.state.profile.credits == 10 and ui.state.profile.stash.size() == stash_count + 1 and stash_has(next_uid) and ui.state.profile.stash[-1].kind == "medicine" and RulesData.validate_state(ui.state), "purchase spends 10 real credits and stores exactly one newly owned medicine UID")
	ui._close_modal()
	return true

func test_campaign_crew_and_reload() -> bool:
	ui.state = progress_through(["beacon", "pump", "channel"])
	ui.state = apply_ui_action(ui.state, {"type": "choose_district", "district": "observatory"}).state
	for character: String in RulesData.CHARACTERS:
		ui.state = apply_ui_action(ui.state, {"type": "choose", "character": character}).state
		ui._enter()
		ui._campaign("crew")
		await settle_layout()
		var all_lines: bool = find_label(ui.modal, RulesData.CHARACTERS[character].name) != null and find_label(ui.modal, RulesData.CHARACTERS[character].role) != null
		for line: String in RulesData.dialogue(ui.state, character):
			all_lines = all_lines and label_contains(ui.modal, line)
		check(all_lines, "crew page displays the selected %s and current campaign dialogue" % character)
		ui._close_modal()
	ui.state = supply_contract(ui.state, "sui_atlas")
	ui.state = apply_ui_action(ui.state, {"type": "claim_contract", "id": "sui_atlas"}).state
	ui._enter()
	ui._campaign("crew")
	await settle_layout()
	check(label_contains(ui.modal, "この依頼は完了しました。") and label_contains(ui.modal, "航路帳ができた。") and find_button(ui.modal, "依頼帳を開く") == null, "actual companion delivery changes the selected crew conversation and completion affordance")
	ui._close_modal()
	var path := "user://qa-campaign-ui.json"
	var snapshot: String = JSON.stringify(ui.state)
	check(Store.save_game(ui.state, "shiogaeri-qa-campaign-ui", path).is_empty(), "campaign UI state saves through the real store")
	var loaded: Dictionary = Store.load_game("shiogaeri-qa-campaign-ui", path)
	check(loaded.found and not loaded.corrupt and JSON.stringify(loaded.state) == snapshot, "campaign selection, jobs, credits and owned UIDs survive the store roundtrip")
	ui.state = loaded.state
	ui._enter()
	ui._campaign("routes")
	await settle_layout()
	check(label_contains(ui.modal, "岬の観測所 / 選択中") and ui.state.character == "sui", "reloaded UI renders the persisted destination and companion")
	ui._close_modal()
	# A late v1 result must migrate without losing the already-transferred item.
	var legacy: Dictionary = RulesData.new_game()
	legacy = apply_ui_action(legacy, {"type": "pack", "uid": legacy.profile.stash[0].uid}).state
	legacy = apply_ui_action(legacy, {"type": "depart", "seed": 7}).state
	legacy = apply_ui_action(legacy, {"type": "wait"}).state
	legacy = apply_ui_action(legacy, {"type": "interact"}).state
	legacy.version = 1
	legacy.erase("preparation")
	legacy.profile.erase("commissionCycle")
	for key: String in ["credits", "selectedDistrict", "activeContract", "completedContracts"]:
		legacy.profile.erase(key)
	check(Store.write_value("shiogaeri-qa-campaign-ui", path, legacy).is_empty(), "late legacy result is written only to the QA file")
	loaded = Store.load_game("shiogaeri-qa-campaign-ui", path)
	check(not loaded.corrupt and loaded.state.version == 4 and loaded.state.result.turns == 1 and loaded.state.result.inventory == legacy.result.inventory and loaded.state.profile.stash == legacy.profile.stash, "late v1 result migrates its resolved turn, receipt and real ownership unchanged")
	ui.state = loaded.state
	ui._enter()
	await settle_layout()
	check(ui.screen == "result" and find_button(ui.content, "港で支度をする") != null and RulesData.validate_state(ui.state), "migrated late result has a usable valid UI")
	legacy.result.inventory[0].kind = "medicine"
	Store.write_value("shiogaeri-qa-campaign-ui", path, legacy)
	loaded = Store.load_game("shiogaeri-qa-campaign-ui", path)
	ui._set_notice(loaded.error)
	await settle_layout()
	check(loaded.corrupt and loaded.found and not loaded.error.is_empty() and ui.notice.visible and ui.notice.text == loaded.error, "invalid legacy receipt is rejected and its store error is readable in the actual notice")
	ui._set_notice("")
	for suffix: String in ["", ".bak", ".tmp", ".pre-v2", ".pre-v2.bak", ".pre-v3", ".pre-v3.bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return true

func texture_base_path(texture: Texture2D) -> String:
	return texture_base_path(texture.atlas) if texture is AtlasTexture else texture.resource_path

func matching_textures(parent: Node, path: String) -> Array[TextureRect]:
	var matches: Array[TextureRect] = []
	for child: Node in parent.get_children():
		if child is TextureRect and child.texture != null and texture_base_path(child.texture) == path:
			matches.append(child)
		matches.append_array(matching_textures(child, path))
	return matches

func test_v03_portraits_and_crew_navigation() -> bool:
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(360, 740)]:
		root.size = phone
		for character: String in RulesData.CHARACTERS:
			ui._close_modal()
			ui.state = apply_ui_action(RulesData.new_game(), {"type": "choose", "character": character}).state
			ui._enter()
			await settle_layout()
			var snapshot: String = JSON.stringify(ui.state)
			var all_avatars_new: bool = true
			for other: String in RulesData.CHARACTERS:
				var path: String = "res://assets/art/v03/portraits/%s.png" % other
				var textures: Array[TextureRect] = matching_textures(ui.content, path)
				all_avatars_new = all_avatars_new and textures.size() >= (2 if other == character else 1)
			check(all_avatars_new, "%s %s harbor portrait and all four avatars use the new portrait assets" % [phone, character])
			ui._campaign("crew")
			await settle_layout()
			var portraits: Array[TextureRect] = matching_textures(ui.modal, "res://assets/art/v03/portraits/%s.png" % character)
			check(portraits.size() == 1 and portraits[0].get_meta("crew_portrait", "") == character and portraits[0].size.x >= 124 and portraits[0].size.y >= 192, "%s %s conversation shows its actual new large portrait" % [phone, character])
			var truthful: bool = find_label(ui.modal, RulesData.CHARACTERS[character].name) != null and find_label(ui.modal, RulesData.CHARACTERS[character].role) != null
			for line: String in RulesData.dialogue(ui.state, character):
				truthful = truthful and label_contains(ui.modal, line)
			check(truthful and fits_visible_stage(ui.modal_panel), "%s %s identity and every dialogue line remain present in a fitting crew panel" % [phone, character])
			var close: Button = find_button(ui.modal, "閉じる")
			var jobs: Button = find_button(ui.modal, "依頼帳を開く")
			if close == null or jobs == null:
				return false
			close.grab_focus()
			key_press(KEY_TAB)
			await settle_layout()
			var css: Vector2 = jobs.size * Vector2(phone) / ui.size
			check(ui.get_viewport().gui_get_focus_owner() == jobs and inside_clipping_ancestors(jobs) and css.x >= 44 and css.y >= 44, "%s %s crew job action scrolls into view through keyboard navigation" % [phone, character])
			# A companion can now have a personal job and a repeat salvage order.
			# Traverse every real action before wrapping to the fixed close button.
			var returned_to_close: bool = false
			var actions_fit: bool = true
			for step: int in range(descendant_buttons(ui.modal).size()):
				key_press(KEY_TAB)
				await settle_layout()
				var focused: Control = ui.get_viewport().gui_get_focus_owner()
				actions_fit = actions_fit and is_instance_valid(focused) and ui.modal.is_ancestor_of(focused) and inside_clipping_ancestors(focused)
				if focused == close:
					returned_to_close = true
					break
			check(returned_to_close and actions_fit, "%s %s crew close stays reachable after all scrolled job actions" % [phone, character])
			check(JSON.stringify(ui.state) == snapshot, "%s %s portrait reading and scrolling preserve the entire state" % [phone, character])
			jobs.pressed.emit()
			await settle_layout()
			check(label_contains(ui.modal, "港の復興") and JSON.stringify(ui.state) == snapshot, "%s %s crew job action opens the actual jobs page without resolving time" % [phone, character])
			key_press(KEY_ESCAPE)
			await settle_layout()
			check(not is_instance_valid(ui.modal), "%s %s crew-to-jobs path closes through Escape" % [phone, character])
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func staged_receipt(character: String, outcome: String) -> Dictionary:
	var prepared: Dictionary = apply_ui_action(RulesData.new_game(), {"type": "choose", "character": character}).state
	if outcome != "empty":
		for item: Dictionary in prepared.profile.stash.duplicate():
			if item.kind in ["knife", "medicine"]:
				prepared = apply_ui_action(prepared, {"type": "pack", "uid": item.uid}).state
	prepared = apply_ui_action(prepared, {"type": "depart", "seed": 7}).state
	if outcome == "dead":
		prepared.run.player.hp = 1
		var crab: Dictionary = prepared.run.enemies[0].duplicate(true)
		crab.kind = "crab"
		crab.hp = RulesData.ENEMIES.crab.hp
		crab.x = 12
		crab.y = 22
		prepared.run.enemies = [crab]
		check(RulesData.validate_state(prepared), "death staging fixture has valid equipment, enemy and ownership")
		prepared = apply_ui_action(prepared, {"type": "wait"}).state
	else:
		prepared = apply_ui_action(prepared, {"type": "interact"}).state
	check(prepared.mode == "result" and prepared.result.outcome == ("dead" if outcome == "dead" else "extracted") and RulesData.validate_state(prepared), "%s %s result fixture resolves through the real rules" % [character, outcome])
	return prepared

func receipt_stage() -> Control:
	for stage: Control in ui.crew_stages:
		if stage.get_meta("receipt_character", "") == ui.state.character:
			return stage
	return null

func test_v03_truthful_result_stages() -> bool:
	var previous_reduced: bool = ui.settings.reduced
	ui.settings.reduced = true
	for phone: Vector2i in [Vector2i(390, 844), Vector2i(360, 740)]:
		root.size = phone
		for character: String in RulesData.CHARACTERS:
			for outcome: String in ["extracted", "empty", "dead"]:
				ui._close_modal()
				ui.state = staged_receipt(character, outcome)
				var snapshot: String = JSON.stringify(ui.state)
				var owned: Array = ui.state.profile.stash.duplicate(true)
				var receipt: Dictionary = ui.state.result.duplicate(true)
				ui._enter()
				await settle_layout()
				var stage: Control = receipt_stage()
				check(stage != null and stage.character == character and stage.phase == ("loss" if outcome == "dead" else "arrival") and stage.celebrate == (outcome == "extracted"), "%s %s %s native receipt stage uses the actual character and truthful outcome" % [phone, character, outcome])
				if stage == null:
					return false
				var actor: Node2D = stage.get_node("Actor")
				var player: AnimationPlayer = actor.get_node("AnimationPlayer")
				check(actor.kind == character and actor.is_player and not player.is_playing() and stage.reduced_motion and inside_clipping_ancestors(stage), "%s %s %s native actor is visible, static and correctly identified" % [phone, character, outcome])
				var count_text: String = "%d個を%s" % [receipt.inventory.size(), "失いました" if outcome == "dead" else "倉庫へ"]
				var result: Control = ui.result_view
				var truthful: bool = result.get_node("%Count").text == count_text and result.get_node("%Turns").text == "%d手の遠征" % receipt.turns and result.get_node("%Value").text == "%d pt" % receipt.value and result.get_node("%Outcome").text == ("回収失敗" if outcome == "dead" else "無事に帰港" if outcome == "empty" else "帰還成功")
				var rows: Node = result.get_node("%Items")
				var row_uids: Array[String] = []
				for row: Node in rows.get_children():
					if row.has_meta("item_uid"):
						row_uids.append(str(row.get_meta("item_uid")))
				truthful = truthful and row_uids.size() == receipt.inventory.size()
				for item: Dictionary in receipt.inventory:
					truthful = truthful and row_uids.count(item.uid) == 1 and find_label(rows, RulesData.ITEMS[item.kind].name) != null
				check(truthful and JSON.stringify(ui.state) == snapshot, "%s %s %s staging preserves and displays the actual receipt items, count and value" % [phone, character, outcome])
				var retry: Button = find_button(ui.content, "港で支度をする")
				check(retry != null and not retry.disabled and inside_clipping_ancestors(retry), "%s %s %s result permits immediate harbor return" % [phone, character, outcome])
				if retry == null:
					return false
				retry.pressed.emit()
				await settle_layout()
				check(ui.qa_session and ui.state.mode == "harbor" and ui.state.profile.stash == owned and ui.state.result == null and not is_instance_valid(stage) and RulesData.validate_state(ui.state), "%s %s %s immediate return frees the decorative actor and preserves actual ownership" % [phone, character, outcome])
	ui.settings.reduced = previous_reduced
	root.size = Vector2i(390, 844)
	await settle_layout()
	return true

func render_receipt_with_motion(reduced: bool) -> void:
	# State and screen are already resolved. Only pure UI construction runs with
	# QA off, which allows the production actor's animation path to be exercised.
	ui.settings.reduced = reduced
	ui.screen = ui.state.mode
	ui.qa_session = false
	ui._render()
	ui.qa_session = true

func actor_visual_state(actor: Node2D) -> Array:
	var body: Node2D = actor.get_node("Facing/BodyPivot")
	return [body.position, body.rotation, body.scale, body.modulate, actor.get_node("Facing/BodyPivot/ToolSocket/WeaponPivot").rotation]

func test_v03_stage_pause_and_reduced_motion() -> bool:
	ui._close_modal()
	var previous_reduced: bool = ui.settings.reduced
	ui.state = staged_receipt("isana", "extracted")
	var snapshot: String = JSON.stringify(ui.state)
	render_receipt_with_motion(false)
	var stage: Control = receipt_stage()
	if stage == null:
		return false
	var actor: Node2D = stage.get_node("Actor")
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	check(ui.qa_session and not stage.reduced_motion and player.is_playing(), "production receipt animation starts with QA restored before any action or wait")
	await create_timer(0.05).timeout
	ui._settings()
	await settle_layout()
	var clock: float = player.current_animation_position
	var pose: Array = actor_visual_state(actor)
	await create_timer(0.06).timeout
	check(is_equal_approx(player.current_animation_position, clock) and actor_visual_state(actor) == pose, "a settings overlay freezes both the receipt clip clock and the visible actor pose")
	ui._close_modal()
	await create_timer(0.05).timeout
	check(player.current_animation_position > clock, "closing the overlay resumes the receipt clip instead of restarting it")
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	clock = player.current_animation_position
	pose = actor_visual_state(actor)
	await create_timer(0.06).timeout
	check(is_equal_approx(player.current_animation_position, clock) and actor_visual_state(actor) == pose, "focus loss freezes the receipt clip and native actor pose")
	ui._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(0.05).timeout
	check(player.current_animation_position > clock and JSON.stringify(ui.state) == snapshot, "focus return continues receipt animation while preserving the full resolved state")
	var static_poses: Dictionary = {}
	for outcome: String in ["extracted", "empty", "dead"]:
		ui.state = staged_receipt("isana", outcome)
		snapshot = JSON.stringify(ui.state)
		render_receipt_with_motion(true)
		await settle_layout()
		stage = receipt_stage()
		if stage == null:
			return false
		actor = stage.get_node("Actor")
		player = actor.get_node("AnimationPlayer")
		pose = actor_visual_state(actor)
		await create_timer(0.06).timeout
		static_poses[outcome] = pose
		check(ui.qa_session and stage.reduced_motion and not player.is_playing() and actor_visual_state(actor) == pose and JSON.stringify(ui.state) == snapshot, "%s reduced-motion receipt chooses a stable pose without changing the result" % outcome)
	check(static_poses.dead != static_poses.extracted and static_poses.empty == static_poses.extracted, "reduced motion distinguishes loss from a quiet or successful arrival")
	ui.state = staged_receipt("ritsu", "extracted")
	var owned: Array = ui.state.profile.stash.duplicate(true)
	render_receipt_with_motion(false)
	stage = receipt_stage()
	await create_timer(0.04).timeout
	var retry: Button = find_button(ui.content, "港で支度をする")
	check(stage != null and stage.get_node("Actor/AnimationPlayer").is_playing() and retry != null and not retry.disabled and ui.qa_session, "harbor return is available while the production arrival clip is still playing")
	if retry == null:
		return false
	retry.pressed.emit()
	await settle_layout()
	check(ui.state.mode == "harbor" and ui.state.profile.stash == owned and not is_instance_valid(stage) and RulesData.validate_state(ui.state), "return during the arrival clip frees its stage without changing already-transferred items")
	ui.settings.reduced = previous_reduced
	ui._render()
	await settle_layout()
	return true

func test_v03_live_reduced_motion_toggle() -> bool:
	ui._close_modal()
	var previous_reduced: bool = ui.settings.reduced
	for outcome: String in ["extracted", "empty", "dead"]:
		ui.state = staged_receipt("kohaku", outcome)
		var snapshot: String = JSON.stringify(ui.state)
		# Obtain the displayed reduced pose independently, then start the same
		# resolved receipt with production motion to exercise its live setting.
		render_receipt_with_motion(true)
		await settle_layout()
		var static_stage: Control = receipt_stage()
		if static_stage == null:
			return false
		var expected_pose: Array = actor_visual_state(static_stage.get_node("Actor"))
		render_receipt_with_motion(false)
		var stage: Control = receipt_stage()
		if stage == null:
			return false
		var actor: Node2D = stage.get_node("Actor")
		var player: AnimationPlayer = actor.get_node("AnimationPlayer")
		await create_timer(0.05).timeout
		check(ui.qa_session and player.is_playing() and player.current_animation_position > 0.0, "%s live setting fixture starts partway through the production outcome clip with QA restored" % outcome)
		ui._settings()
		await settle_layout()
		var motion: CheckButton = find_button(ui.modal, "動きを減らす") as CheckButton
		if motion == null:
			return false
		check(not motion.button_pressed and not stage.reduced_motion, "%s settings reflect the existing animated receipt before changing preference" % outcome)
		motion.button_pressed = true
		check(ui.settings.reduced and stage.reduced_motion and actor.reduced_motion and receipt_stage() == stage, "%s actual settings toggle updates the existing receipt stage and actor" % outcome)
		ui._close_modal()
		await settle_layout()
		var pose: Array = actor_visual_state(actor)
		var held_clip: StringName = player.current_animation
		await create_timer(0.08).timeout
		check(not player.is_playing() and actor_visual_state(actor) == expected_pose and actor_visual_state(actor) == pose and player.current_animation == held_clip, "%s enabling reduced motion mid-clip holds the appropriate static outcome after closing settings" % outcome)
		check(JSON.stringify(ui.state) == snapshot and RulesData.validate_state(ui.state), "%s live reduction leaves the resolved receipt and concrete ownership unchanged" % outcome)
		ui._settings()
		await settle_layout()
		motion = find_button(ui.modal, "動きを減らす") as CheckButton
		if motion == null:
			return false
		check(motion.button_pressed, "%s reopened settings retain the reduced-motion preference" % outcome)
		motion.button_pressed = false
		ui._close_modal()
		await settle_layout()
		held_clip = player.current_animation
		await create_timer(0.08).timeout
		check(not ui.settings.reduced and not stage.reduced_motion and not actor.reduced_motion and not player.is_playing() and actor_visual_state(actor) == pose and player.current_animation == held_clip, "%s restoring full motion holds the resolved outcome instead of replaying its clip" % outcome)
		check(ui.qa_session and JSON.stringify(ui.state) == snapshot and RulesData.validate_state(ui.state), "%s toggling motion off and on cannot replay receipt ownership or rewards" % outcome)
	ui.settings.reduced = previous_reduced
	ui._render()
	await settle_layout()
	return true

func test_v05_extract_feedback() -> bool:
	ui._close_modal()
	root.size = Vector2i(390, 844)
	for legacy: bool in [false, true]:
		for history: String in ["loan-only", "owned-drop", "owned-return"]:
			ui.state = RulesData.new_game()
			ui.harbor_feedback = ""
			ui._enter()
			await settle_layout()
			var uid: String = ui.state.profile.stash[0].uid
			if history != "loan-only":
				ui._act({"type":"pack", "uid":uid})
				await settle_layout()
			if legacy:
				ui.state = apply_ui_action(ui.state, {"type":"depart", "seed":7}).state
				ui._enter()
			else:
				ui._act({"type":"depart", "seed":7})
			await settle_layout()
			check(ui.state.run.inventory.size() == 1 and ui.state.run.inventory[0].kind == ("loanKnife" if history == "loan-only" else "knife"), "%s %s feedback fixture departs with the actual intended weapon" % [legacy, history])
			if history == "owned-drop":
				ui._act({"type":"drop", "uid":uid})
				await settle_layout()
				check(ui.state.run.inventory.is_empty() and RulesData.validate_state(ui.state), "%s own-knife history genuinely drops its UID through Main" % legacy)
			var before: String = JSON.stringify(ui.state)
			var expected: Dictionary = RulesData.apply_action(ui.state, {"type":"interact"})
			var extract: Dictionary = {}
			for event: Dictionary in expected.events:
				if event.type == "extract":
					extract = event
			var count: int = 1 if history == "owned-return" else 0
			check(not extract.is_empty() and extract.amount == count and extract.text == "%d個の品を倉庫に持ち帰った。貸出品は返却した。" % count, "%s %s original Rules event is unchanged and contains the confirmed count" % [legacy, history])
			ui._interact()
			await settle_layout()
			check(JSON.stringify(ui.state) == before, "%s %s return confirmation does not change game data" % [legacy, history])
			var confirm: Button = find_button(ui.modal, "持ち帰って遠征を終える")
			if confirm == null:
				return false
			confirm.pressed.emit()
			await settle_layout()
			var message: String = "持ち帰った品はありません。" if count == 0 else "%d個の品を倉庫に持ち帰りました。" % count
			check(ui.state == expected.state and ui.state.result.inventory.size() == count and ui.harbor_feedback == message and RulesData.validate_state(ui.state), "%s %s Main adapts only the extract message while preserving the complete Rules result" % [legacy, history])
			var expected_return: Dictionary = RulesData.apply_action(ui.state, {"type":"return"}).state
			ui.result_view.continue_button.pressed.emit()
			await settle_layout()
			var feedback: Label = ui.harbor_view.get_node("%Feedback")
			check(ui.state == expected_return and ui.screen == "harbor" and feedback.is_visible_in_tree() and feedback.text == message and inside_clipping_ancestors(feedback), "%s %s actual result-to-harbor flow shows only supported count facts and preserves ownership" % [legacy, history])
	return true
