extends SceneTree

const RulesEngine = preload("res://scripts/legacy_v03_rules.gd")
const World = preload("res://scripts/world_data.gd")
const Store = preload("res://scripts/save_store.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	for test: String in ["test_initial_and_traits", "test_immutable_replay", "test_invalid_actions", "test_extraction_once_and_loan", "test_death_and_restart", "test_inventory_overflow_and_drop", "test_tools", "test_enemy_timing", "test_tide_and_visibility", "test_seed_connectivity", "test_save_validation", "test_complete_goal_route", "test_combat_save_boundaries", "test_tool_save_boundaries", "test_campaign_deliveries_and_exchange", "test_campaign_ownership_boundaries", "test_legacy_migration", "test_district_topology", "test_actual_campaign_route", "test_legacy_store_backup"]:
		if call(test) != true:
			failed += 1
			push_error("%s did not finish (runtime error or failed route)" % test)
	print("Legacy v0.3 rules tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func act(state: Dictionary, action: Dictionary) -> Dictionary:
	return RulesEngine.apply_action(state, action).state

func prepared(character: String = "isana", seed_value: int = 7) -> Dictionary:
	var state: Dictionary = RulesEngine.new_game()
	state = act(state, {"type": "choose", "character": character})
	for item: Dictionary in state.profile.stash.duplicate():
		state = act(state, {"type": "pack", "uid": item.uid})
	return act(state, {"type": "depart", "seed": seed_value})

func uid(state: Dictionary, kind: String) -> String:
	for item: Dictionary in state.run.inventory:
		if item.kind == kind:
			return item.uid
	return ""

func sandbox() -> Dictionary:
	var state: Dictionary = prepared()
	state.run.enemies = []
	state.run.player.x = 12
	state.run.player.y = 20
	state.run.seen = RulesEngine.visible_tiles(state.run).keys()
	return state

func enemy(kind: String, x: int, y: int) -> Dictionary:
	return {"id": "test-" + kind, "kind": kind, "x": x, "y": y, "hp": RulesEngine.ENEMIES[kind].hp, "stunned": 0, "facing": {"x": 0, "y": 1}}

func test_initial_and_traits() -> bool:
	var state: Dictionary = RulesEngine.new_game()
	expect(RulesEngine.validate_state(state), "new game validates")
	expect(state.profile.stash.size() == 8, "starter inventory exists once")
	for character: String in RulesEngine.CHARACTERS:
		state = act(state, {"type": "choose", "character": character})
		expect(state.character == character and RulesEngine.validate_state(state), character + " unlocked")
	var a: Dictionary = prepared("isana")
	var b: Dictionary = prepared("ritsu")
	var c: Dictionary = prepared("kohaku")
	var d: Dictionary = prepared("sui")
	expect(RulesEngine.stats(a).capacity == 14, "Isana capacity")
	expect(b.run.player.hp == 28, "Ritsu HP")
	expect(RulesEngine.stats(c).attack == 4, "Kohaku melee")
	expect(d.run.sight == 6, "Sui sight")
	return true

func test_immutable_replay() -> bool:
	var state: Dictionary = prepared()
	var before: String = JSON.stringify(state)
	var moved: Dictionary = act(state, {"type": "move", "dx": 0, "dy": -1})
	expect(JSON.stringify(state) == before, "dispatch does not mutate input")
	expect(moved.run.turn == 1 and moved.run.player.y == 22, "one explicit action one turn")
	var replay: Dictionary = prepared()
	for action: Dictionary in [{"type": "move", "dx": 0, "dy": -1}, {"type": "wait"}, {"type": "move", "dx": -1, "dy": 0}]:
		state = act(state, action)
		replay = act(replay, action)
	expect(state == replay, "same seed and action replay")
	var loaded: Variant = JSON.parse_string(JSON.stringify(state))
	expect(RulesEngine.validate_state(loaded), "complete turn JSON reload validates")
	expect(act(loaded, {"type": "wait"}) == act(state, {"type": "wait"}), "reload preserves deterministic next turn")
	return true

func test_invalid_actions() -> bool:
	var state: Dictionary = prepared()
	var actions: Array = [{"type": "move", "dx": 1, "dy": 1}, {"type": "move", "dx": 0, "dy": 1}, {"type": "move", "dx": 1.5, "dy": 0}, {"type": "equip", "uid": uid(state, "medicine")}, {"type": "use", "uid": uid(state, "medicine")}, {"type": "use", "uid": uid(state, "bomb"), "dx": 0, "dy": -1}, {"type": "use", "uid": uid(state, "flare"), "dx": 1, "dy": 0}, {"type": "drop", "uid": "missing"}, {"type": "choose", "character": "sui"}, {"type": "inspect"}]
	for action: Dictionary in actions:
		expect(act(state, action) == state, "invalid action costs nothing: " + str(action.type))
	var moved: Dictionary = act(state, {"type": "move", "dx": 1, "dy": 0})
	expect(act(moved, {"type": "interact"}) == moved, "no distant crate pickup")
	expect(act(RulesEngine.new_game(), {"type": "depart", "seed": -1}).mode == "harbor", "bad seed rejected")
	return true

func test_extraction_once_and_loan() -> bool:
	var state: Dictionary = RulesEngine.new_game()
	var stash: Array = state.profile.stash.duplicate(true)
	state = act(state, {"type": "depart", "seed": 1})
	expect(state.run.inventory.size() == 1 and state.run.inventory[0].kind == "loanKnife", "loan issued without cloning stash knife")
	state = act(state, {"type": "interact"})
	expect(state.mode == "result" and state.result.outcome == "extracted", "exit interaction extracts")
	expect(state.profile.stash == stash and state.result.inventory.is_empty(), "loan returned, not farmed")
	expect(RulesEngine.validate_state(state), "empty extraction save valid")
	state = act(state, {"type": "return"})
	var again: Dictionary = act(state, {"type": "return"})
	expect(again == state and state.profile.stash == stash, "return cannot transfer twice")
	state = act(state, {"type": "pack", "uid": stash[0].uid})
	state = act(state, {"type": "depart", "seed": 1})
	state = act(state, {"type": "interact"})
	expect(state.profile.stash.size() == stash.size() and state.result.inventory.size() == 1, "owned carried item transferred exactly once")
	expect(RulesEngine.validate_state(state), "extraction receipt is not active duplicate")
	return true

func test_death_and_restart() -> bool:
	var state: Dictionary = prepared()
	state.run.player.hp = 1
	state.run.enemies = [enemy("crab", 12, 22)]
	var carried: Array = state.run.inventory.duplicate(true)
	state = act(state, {"type": "wait"})
	expect(state.mode == "result" and state.result.outcome == "dead", "enemy damage kills")
	expect(state.result.inventory == carried and state.profile.stash.is_empty(), "all carried gear and loot lost")
	expect(RulesEngine.validate_state(state), "death receipt validates")
	state = act(state, {"type": "return"})
	state = act(state, {"type": "depart", "seed": 2})
	expect(state.run.weapon != null and state.run.inventory[0].kind == "loanKnife", "restart after total loss")
	state.profile.stash.append({"uid": "i%d" % state.nextId, "kind": "pearl"})
	state.nextId += 1
	var stash: Array = state.profile.stash.duplicate(true)
	state.run.player.hp = 1
	state.run.enemies = [enemy("crab", 12, 22)]
	state = act(state, {"type": "wait"})
	expect(state.profile.stash == stash, "stash survives death")
	return true

func test_inventory_overflow_and_drop() -> bool:
	var state: Dictionary = sandbox()
	state.run.player.y = 21
	while state.run.inventory.size() < 13:
		state.run.inventory.append({"uid": "i%d" % state.nextId, "kind": "pearl"})
		state.nextId += 1
	var crate: Dictionary = state.run.containers[0]
	var original: Array = crate.items.duplicate(true)
	state = act(state, {"type": "interact"})
	expect(state.run.inventory.size() == 14 and state.run.containers[0].items.size() == 1, "overflow remains in crate")
	expect(state.run.containers[0].items[0] == original[1], "overflow identity retained")
	var dropped: String = state.run.weapon
	state = act(state, {"type": "drop", "uid": dropped})
	expect(state.run.weapon == null and state.run.turn == 2, "dropping equipment unequips and costs one turn")
	var ground: Dictionary = state.run.containers.back()
	expect(ground.x == 12 and ground.y == 21 and ground.items[0].uid == dropped, "drop preserves identity in ground crate")
	state = act(state, {"type": "interact"})
	expect(not RulesEngine._find_item(state.run.inventory, dropped).is_empty(), "same-tile crate searched before adjacent")
	state = act(state, {"type": "equip", "uid": dropped})
	expect(state.run.weapon == dropped and state.run.turn == 4, "equip costs exactly one turn")
	expect(RulesEngine.validate_state(state), "dropped/recovered ownership validates")
	return true

func test_tools() -> bool:
	var state: Dictionary = sandbox()
	state.run.player.hp = 5
	var med: String = uid(state, "medicine")
	state = act(state, {"type": "use", "uid": med})
	expect(state.run.player.hp == 15 and uid(state, "medicine") != med and state.run.turn == 1, "medicine consumed and heals ten")
	state.run.tiles[20][13].type = "wall"
	state.run.enemies = [enemy("crab", 14, 20)]
	var bomb: String = uid(state, "bomb")
	state = act(state, {"type": "use", "uid": bomb, "dx": 1, "dy": 0})
	expect(state.run.tiles[20][13].type == "floor" and state.run.enemies.is_empty(), "bomb breaks wall and damages adjacent foe")
	expect(state.run.player.hp == 15, "own bomb does not hurt player")
	var wader: Dictionary = enemy("wader", 12, 18)
	wader.intent = {"dx": 0, "dy": 1}
	state.run.enemies = [wader]
	state = act(state, {"type": "use", "uid": uid(state, "flare"), "dx": -1, "dy": 0})
	expect(not state.run.enemies[0].has("intent") and state.run.enemies[0].target.turns == 3, "flare cancels charge and uses first lure turn")
	expect(state.run.player.hp == 15, "lured foe does not attack")
	for index: int in range(3):
		state = act(state, {"type": "wait"})
	expect(not state.run.enemies[0].has("target"), "lure expires after four enemy turns")
	expect(RulesEngine.validate_state(state), "tool effects save valid")
	return true

func test_enemy_timing() -> bool:
	var state: Dictionary = sandbox()
	state.run.enemies = [enemy("wader", 12, 18)]
	state = act(state, {"type": "wait"})
	expect(state.run.enemies[0].has("intent") and state.run.player.hp == 24, "wader telegraphs before damage")
	state = act(state, {"type": "move", "dx": -1, "dy": 0})
	expect(state.run.player.hp == 24 and state.run.enemies[0].y == 21, "sidestep avoids charge")
	expect(state.run.enemies[0].stunned == 1, "charge recovery announced in state")
	state = sandbox()
	state.run.enemies = [enemy("diver", 12, 19)]
	state = act(state, {"type": "wait"})
	expect(state.run.player.hp == 24, "diver rests on odd turn")
	state = act(state, {"type": "wait"})
	expect(state.run.player.hp == 21, "diver hits on even turn, armor reduces damage")
	state = sandbox()
	state.run.enemies = [enemy("crab", 12, 19)]
	state = act(state, {"type": "move", "dx": 0, "dy": -1})
	expect(state.run.player.y == 20 and state.run.enemies[0].hp == 2 and state.run.player.hp == 23, "bump attacks instead of moving; enemy replies once")
	state = act(state, {"type": "move", "dx": 0, "dy": -1})
	expect(state.run.enemies.is_empty() and state.run.player.hp == 23, "killed enemy cannot reply")
	return true

func test_tide_and_visibility() -> bool:
	var state: Dictionary = sandbox()
	state.run.player.x = 11
	state.run.turn = 63
	state.run.tide = 1
	state = act(state, {"type": "wait"})
	expect(state.run.tide == 2 and state.run.player.hp == 23, "tide rises only on explicit turn and damage ignores armor")
	var before: String = JSON.stringify(state)
	RulesEngine.visible_tiles(state.run)
	RulesEngine.stats(state)
	expect(JSON.stringify(state) == before, "inspection neither advances nor mutates tide")
	state = act(state, {"type": "move", "dx": 1, "dy": 0})
	expect(not World.is_flooded(state.run, 12, 20) and state.run.player.hp == 23, "raised route stays dry")
	state.run.tiles[20][13].type = "wall"
	var visible: Dictionary = RulesEngine.visible_tiles(state.run)
	expect(visible.has("13,20") and not visible.has("14,20"), "wall visible, tile behind opaque")
	state.run.tiles[20][13].type = "floor"
	expect(RulesEngine.visible_tiles(state.run).has("14,20"), "destroyed wall opens sight")
	return true

func flood(world: Dictionary, dry_only: bool = false) -> Dictionary:
	var visited: Dictionary = {"12,23": true}
	var queue: Array = [{"x": 12, "y": 23}]
	var index: int = 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		index += 1
		for d: Dictionary in RulesEngine.DIRECTIONS:
			var x: int = int(cell.x) + int(d.x)
			var y: int = int(cell.y) + int(d.y)
			var k: String = "%d,%d" % [x, y]
			if not visited.has(k) and World.is_walkable(world, x, y) and (not dry_only or not World.is_flooded(world, x, y)):
				visited[k] = true
				queue.append({"x": x, "y": y})
	return visited

func test_seed_connectivity() -> bool:
	var layouts: Dictionary = {}
	for seed_value: int in range(32):
		var world: Dictionary = World.create_world(seed_value)
		world.tide = 3
		var reachable: Dictionary = flood(world)
		var dry: Dictionary = flood(world, true)
		expect(dry.has("21,3"), "dry exit-goal route seed %d" % seed_value)
		for crate: Dictionary in world.containers:
			expect(reachable.has("%d,%d" % [crate.x, crate.y]), "reachable supplies seed %d %s" % [seed_value, crate.id])
		for foe: Dictionary in world.enemies:
			expect(RulesEngine._distance(foe, world.exit) >= 10, "safe entry seed %d" % seed_value)
		layouts[JSON.stringify(world.containers) + JSON.stringify(world.enemies)] = true
		expect(world == with_tide(World.create_world(seed_value), 3), "world deterministic seed %d" % seed_value)
	expect(layouts.size() > 5, "seeds vary reachable loot and enemy positions")
	return true

func with_tide(world: Dictionary, tide: int) -> Dictionary:
	world.tide = tide
	return world

func test_save_validation() -> bool:
	var state: Dictionary = prepared()
	expect(RulesEngine.validate_state(state), "departure validates")
	for field: String in ["run", "profile", "character", "version"]:
		var bad: Dictionary = state.duplicate(true)
		bad.erase(field)
		expect(not RulesEngine.validate_state(bad), "missing field " + field)
	var mutations: Array = [
		func(s: Dictionary) -> void: s.version = 3,
		func(s: Dictionary) -> void: s.run.player.hp = 0,
		func(s: Dictionary) -> void: s.run.turn = 1.5,
		func(s: Dictionary) -> void: s.run.player.maxHp = 999,
		func(s: Dictionary) -> void: s.run.inventory.append(s.run.inventory[0].duplicate()),
		func(s: Dictionary) -> void: s.run.weapon = s.run.inventory[2].uid,
		func(s: Dictionary) -> void: s.run.containers[0].items[0].kind = "unknown",
		func(s: Dictionary) -> void: s.run.tiles[0] = [],
		func(s: Dictionary) -> void: s.run.enemies[0].intent = {"dx": 0, "dy": 0},
		func(s: Dictionary) -> void: s.run.seen = ["999,0"],
		func(s: Dictionary) -> void: s.nextId = 1,
		func(s: Dictionary) -> void: s.extra = true,
		func(s: Dictionary) -> void: s.profile.stash = "oops",
		func(s: Dictionary) -> void: s.run.player.facing = null,
		func(s: Dictionary) -> void: s.run.tide = 3,
		func(s: Dictionary) -> void: s.run.enemies[0].x = s.run.player.x; s.run.enemies[0].y = s.run.player.y]
	for index: int in range(mutations.size()):
		var bad: Dictionary = state.duplicate(true)
		mutations[index].call(bad)
		expect(not RulesEngine.validate_state(bad), "malformed save %d" % index)
	var loaded: Variant = JSON.parse_string(JSON.stringify(state))
	expect(loaded.run.player.hp is float and RulesEngine.validate_state(loaded), "integral JSON floats accepted")
	expect(act(loaded, {"type": "wait"}).run.turn is int, "action normalizes JSON numbers")
	expect(not RulesEngine.validate_state(null) and not RulesEngine.validate_state([]), "non-object saves rejected")
	return true

func travel(state: Dictionary, target_x: int, target_y: int) -> Dictionary:
	for count: int in range(120):
		if state.mode != "expedition":
			return state
		if state.run.player.x == target_x and state.run.player.y == target_y:
			return state
		if state.run.player.hp <= int(state.run.player.maxHp) - 10 and not uid(state, "medicine").is_empty():
			state = act(state, {"type": "use", "uid": uid(state, "medicine")})
			continue
		var dx: int = signi(target_x - int(state.run.player.x))
		var dy: int = signi(target_y - int(state.run.player.y)) if dx == 0 else 0
		state = act(state, {"type": "move", "dx": dx, "dy": dy})
	return state

func test_complete_goal_route() -> bool:
	for seed_value: int in [1, 7, 42, 1234, 9901]:
		var state: Dictionary = prepared("isana", seed_value)
		state = travel(state, 12, 21)
		state = act(state, {"type": "interact"})
		state = travel(state, 12, 4)
		state = travel(state, 21, 4)
		if state.mode != "expedition":
			expect(false, "goal route survives seed %d" % seed_value)
			return false
		state = act(state, {"type": "interact"})
		expect(not uid(state, "core").is_empty(), "core collected seed %d" % seed_value)
		state = travel(state, 12, 4)
		state = travel(state, 12, 23)
		if state.mode != "expedition" or state.run.player.x != 12 or state.run.player.y != 23:
			expect(false, "return route survives seed %d" % seed_value)
			return false
		state = act(state, {"type": "interact"})
		expect(state.mode == "result" and state.result.outcome == "extracted" and RulesEngine.validate_state(state), "goal extraction saved seed %d" % seed_value)
		state = act(state, {"type": "return"})
		state = act(state, {"type": "repair"})
		expect(state.profile.lampRepaired and RulesEngine.validate_state(state), "recovered materials repair lamp seed %d" % seed_value)
		state = act(state, {"type": "choose", "character": "sui"})
		state = act(state, {"type": "depart", "seed": seed_value})
		expect(state.run.sight == 7 and RulesEngine.validate_state(state), "lamp and Sui sight stack next departure")
	return true

func saved_turn(state: Dictionary, action: Dictionary, label: String) -> Dictionary:
	var response: Dictionary = RulesEngine.apply_action(state, action)
	var next: Dictionary = response.state
	if not RulesEngine.validate_state(next):
		expect(false, "%s validates before writing JSON: %s" % [label, action])
		return {}
	expect(true, label + " validates before writing JSON")
	var restored: Variant = JSON.parse_string(JSON.stringify(next))
	expect(RulesEngine.validate_state(restored), label + " validates after JSON restore")
	expect(RulesEngine._normalize(restored) == next, label + " JSON preserves complete resolved turn")
	return restored

func saved_travel(state: Dictionary, x: int, y: int, label: String) -> Dictionary:
	for count: int in range(120):
		if state.is_empty() or state.mode != "expedition":
			return {}
		if int(state.run.player.x) == x and int(state.run.player.y) == y:
			return state
		var action: Dictionary
		if int(state.run.player.hp) <= int(state.run.player.maxHp) - 10 and not uid(state, "medicine").is_empty():
			action = {"type": "use", "uid": uid(state, "medicine")}
		else:
			var dx: int = signi(x - int(state.run.player.x))
			var dy: int = signi(y - int(state.run.player.y)) if dx == 0 else 0
			action = {"type": "move", "dx": dx, "dy": dy}
		state = saved_turn(state, action, "%s step %d" % [label, count])
	return {}

func test_combat_save_boundaries() -> bool:
	# Reproduce the phone route with its basic five-item Ritsu loadout. Restore
	# every turn so telegraphs, charge recovery and killed enemies cross storage.
	for seed_value: int in [0, 1, 7, 42, 1234, 9901]:
		var state: Dictionary = RulesEngine.new_game()
		state = act(state, {"type": "choose", "character": "ritsu"})
		var picked: Dictionary = {}
		for item: Dictionary in state.profile.stash.duplicate():
			if not picked.has(item.kind):
				picked[item.kind] = true
				state = act(state, {"type": "pack", "uid": item.uid})
		state = saved_turn(state, {"type": "depart", "seed": seed_value}, "Ritsu departure %d" % seed_value)
		state = saved_travel(state, 12, 21, "supply approach %d" % seed_value)
		state = saved_travel(state, 11, 21, "supply tile %d" % seed_value)
		if state.is_empty():
			return false
		state = saved_turn(state, {"type": "interact"}, "supply search %d" % seed_value)
		state = saved_travel(state, 12, 21, "spine return %d" % seed_value)
		state = saved_travel(state, 12, 4, "spine combat %d" % seed_value)
		state = saved_travel(state, 21, 4, "lighthouse combat %d" % seed_value)
		if state.is_empty():
			return false
		state = saved_turn(state, {"type": "interact"}, "core search %d" % seed_value)
		state = saved_travel(state, 12, 4, "return combat %d" % seed_value)
		state = saved_travel(state, 12, 23, "return spine %d" % seed_value)
		if state.is_empty():
			return false
		state = saved_turn(state, {"type": "interact"}, "combat extraction %d" % seed_value)
		if state.is_empty():
			return false
		expect(state.result.outcome == "extracted", "combat route completes after per-turn restore")
	return true

func test_tool_save_boundaries() -> bool:
	var state: Dictionary = sandbox()
	var foe: Dictionary = enemy("wader", 12, 18)
	foe.erase("facing")
	foe.erase("stunned")
	state.run.enemies = [foe]
	expect(RulesEngine.validate_state(state), "enemy optional fields may be absent in valid save")
	state = saved_turn(state, {"type": "wait"}, "wader telegraph")
	if state.is_empty():
		return false
	state = saved_turn(state, {"type": "use", "uid": uid(state, "flare"), "dx": -1, "dy": 0}, "flare cancels telegraph")
	if state.is_empty():
		return false
	for count: int in range(4):
		state = saved_turn(state, {"type": "wait"}, "flare lifetime %d" % count)
		if state.is_empty():
			return false
	state = sandbox()
	foe = enemy("wader", 12, 18)
	foe.erase("stunned")
	state.run.enemies = [foe]
	state = saved_turn(state, {"type": "wait"}, "charge prepare without optional stun")
	state = saved_turn(state, {"type": "move", "dx": -1, "dy": 0}, "charge creates recovery")
	if state.is_empty():
		return false
	state = sandbox()
	foe = enemy("crab", 12, 18)
	foe.erase("facing")
	state.run.enemies = [foe]
	state = saved_turn(state, {"type": "wait"}, "pursuit creates facing")
	if state.is_empty():
		return false
	state.run.tiles[20][13].type = "wall"
	state.run.enemies.append(enemy("wader", 14, 20))
	state = saved_turn(state, {"type": "use", "uid": uid(state, "bomb"), "dx": 1, "dy": 0}, "bomb opens wall and kills foe")
	if state.is_empty():
		return false
	expect(state.run.tiles[20][13].type == "floor" and state.run.enemies.is_empty(), "bomb opens wall and removes both foes inside blast")
	return true

# Campaign tests use real item UIDs and action results; no duplicate delivery receipts.
func test_campaign_deliveries_and_exchange() -> bool:
	var state: Dictionary = RulesEngine.new_game()
	expect(act(state, {"type": "choose_district", "district": "market"}) == state, "locked district does not change selection")
	expect(act(state, {"type": "buy", "kind": "medicine"}) == state, "cannot buy without credits")
	var initial: String = JSON.stringify(state)
	RulesEngine.contracts(state)
	RulesEngine.dialogue(state, "isana")
	RulesEngine.campaign_summary(state)
	RulesEngine.shop_rows(state)
	expect(JSON.stringify(state) == initial, "campaign inspection never mutates state")
	for story: String in RulesEngine.Campaign.STORY_IDS:
		state = act(state, {"type": "accept_contract", "id": story})
		var definition: Dictionary = RulesEngine.Campaign.CONTRACTS[story]
		expect(state.profile.activeContract == story and state.profile.selectedDistrict == definition.district, "accepted job selects its real destination " + story)
		for material: String in definition.requirements:
			for n: int in range(int(definition.requirements[material])):
				state.profile.stash.append(RulesEngine._new_item(state, material))
		var before_count: int = state.profile.stash.size()
		var delivered: Array = []
		for row: Dictionary in RulesEngine.contracts(state):
			if row.id == story:
				expect(row.status == "ready", "stored materials make delivery ready")
				for requirement: Dictionary in row.requirements:
					for item: Dictionary in state.profile.stash:
						if item.kind == requirement.kind:
							delivered.append(item.uid)
		state = act(state, {"type": "claim_contract", "id": story})
		expect(story in state.profile.completedContracts and state.profile.stash.size() < before_count, "claim consumes real stash items " + story)
		for item_uid: String in delivered:
			expect(RulesEngine._find_item(state.profile.stash, item_uid).is_empty(), "delivered UID removed once")
		expect(act(state, {"type": "claim_contract", "id": story}) == state, "cannot claim job twice " + story)
		expect(RulesEngine.validate_state(JSON.parse_string(JSON.stringify(state))), "campaign delivery round-trips " + story)
	expect(RulesEngine.campaign_summary(state).completed == 4, "all four reconstruction arcs finish")
	for character: String in RulesEngine.CHARACTERS:
		var id: String = RulesEngine.Campaign.PERSONAL[character]
		var before_line: Array = RulesEngine.dialogue(state, character)
		state = act(state, {"type": "accept_contract", "id": id})
		for material: String in RulesEngine.Campaign.CONTRACTS[id].requirements:
			for n: int in range(int(RulesEngine.Campaign.CONTRACTS[id].requirements[material])):
				state.profile.stash.append(RulesEngine._new_item(state, material))
		state = act(state, {"type": "claim_contract", "id": id})
		expect(id in state.profile.completedContracts and RulesEngine.validate_state(state), "personal delivery persists " + id)
		expect(before_line != RulesEngine.dialogue(state, character), "personal completion changes actual dialogue " + character)
		for reward_kind: String in RulesEngine.Campaign.CONTRACTS[id].reward.items:
			var found: bool = false
			for item: Dictionary in state.profile.stash:
				found = found or item.kind == reward_kind
			expect(found, "personal reward is a real stored item " + reward_kind)
	var sold: Dictionary = state.profile.stash[0]
	var credits: int = state.profile.credits
	state = act(state, {"type": "sell", "uid": sold.uid})
	expect(state.profile.credits == credits + int(RulesEngine.ITEMS[sold.kind].value) and RulesEngine._find_item(state.profile.stash, sold.uid).is_empty(), "sale removes chosen UID and pays exact price")
	expect(act(state, {"type": "sell", "uid": sold.uid}) == state, "sale cannot pay the same UID twice")
	credits = state.profile.credits
	var new_id: int = state.nextId
	state = act(state, {"type": "buy", "kind": "medicine"})
	expect(state.profile.credits == credits - 10 and state.nextId == new_id + 1 and state.profile.stash.back().kind == "medicine", "purchase has real cost and fresh ownership")
	for row: Dictionary in RulesEngine.shop_rows(state):
		expect(row.affordable == (state.profile.credits >= row.price), "shop affordability matches exact credits")
	var saved: Dictionary = state.profile.duplicate(true)
	state = act(state, {"type": "depart", "seed": 4})
	state.run.player.hp = 1
	state.run.enemies = [enemy("crab", 12, 22)]
	state = act(state, {"type": "wait"})
	expect(state.result.outcome == "dead" and state.profile.stash == saved.stash and state.profile.credits == saved.credits and state.profile.completedContracts == saved.completedContracts, "death loses carried gear while retaining campaign, credits and stash")
	expect(RulesEngine.validate_state(state), "campaign death remains saveable")
	return true

func test_campaign_ownership_boundaries() -> bool:
	var state: Dictionary = RulesEngine.new_game()
	state.profile.stash.append(RulesEngine._new_item(state, "core"))
	state.profile.stash.append(RulesEngine._new_item(state, "scrap"))
	var core: String = state.profile.stash[-2].uid
	state = act(state, {"type": "pack", "uid": core})
	expect(act(state, {"type": "claim_contract", "id": "beacon"}) == state, "carried item cannot fund harbor delivery")
	expect(act(state, {"type": "sell", "uid": core}) == state, "packed item cannot be sold")
	state = act(state, {"type": "unpack", "uid": core})
	state = act(state, {"type": "repair"})
	expect(state.profile.lampRepaired and "beacon" in state.profile.completedContracts, "old repair action completes first reconstruction")
	expect(act(state, {"type": "repair"}) == state, "legacy repair cannot duplicate reward")
	state = act(state, {"type": "depart", "seed": 1})
	for action: Dictionary in [{"type": "choose_district", "district": "market"}, {"type": "accept_contract", "id": "pump"}, {"type": "sell", "uid": state.run.weapon}, {"type": "buy", "kind": "medicine"}, {"type": "claim_contract", "id": "pump"}]:
		expect(act(state, action) == state, "harbor-only action costs no expedition turn " + action.type)
	return true

func legacy_fixture(state: Dictionary) -> Dictionary:
	var old: Dictionary = state.duplicate(true)
	old.version = 1
	for field: String in ["credits", "selectedDistrict", "activeContract", "completedContracts"]:
		old.profile.erase(field)
	if old.run is Dictionary:
		old.run.erase("district")
	return JSON.parse_string(JSON.stringify(old))

func test_legacy_migration() -> bool:
	var harbor: Dictionary = RulesEngine.new_game()
	harbor = act(harbor, {"type": "pack", "uid": harbor.profile.stash[0].uid})
	var expedition: Dictionary = prepared("sui", 42)
	expedition.run.turn = 64
	expedition.run.tide = 2
	expedition.run.player.hp = 12
	expedition.run.enemies[0]["target"] = {"x": 12, "y": 20, "turns": 3}
	expedition.run.enemies[2]["intent"] = {"dx": 0, "dy": 1}
	var extracted: Dictionary = act(prepared(), {"type": "interact"})
	var dead: Dictionary = prepared()
	dead.run.player.hp = 1
	dead.run.enemies = [enemy("crab", 12, 22)]
	dead = act(dead, {"type": "wait"})
	var repaired: Dictionary = RulesEngine.new_game()
	repaired.profile.lampRepaired = true
	repaired.profile.completedContracts = ["beacon"]
	repaired.profile.activeContract = ""
	for current: Dictionary in [harbor, expedition, extracted, dead, repaired]:
		var old: Dictionary = legacy_fixture(current)
		var before: String = JSON.stringify(old)
		var migrated: Dictionary = RulesEngine.migrate_state(old)
		expect(not migrated.is_empty() and RulesEngine.validate_state(migrated), "strict legacy fixture migrates " + current.mode)
		if migrated.is_empty():
			return false
		expect(JSON.stringify(old) == before, "migration never edits original legacy object")
		expect(migrated.profile.stash == current.profile.stash and migrated.loadout == current.loadout and migrated.result == current.result and migrated.nextId == current.nextId, "migration preserves ownership and receipt")
		if current.run is Dictionary:
			expect(migrated.run == current.run, "in-flight legacy state keeps every resolved field and adds district only")
		if current.profile.lampRepaired:
			expect(migrated.profile.completedContracts == ["beacon"], "repaired legacy lamp already unlocks market without reward duplication")
		expect(RulesEngine.migrate_state(migrated) == migrated, "migration is idempotent")
	var malformed: Dictionary = legacy_fixture(expedition)
	malformed.run.player.hp = 0
	expect(RulesEngine.migrate_state(malformed).is_empty(), "migration cannot rescue invalid legacy HP")
	malformed = legacy_fixture(expedition)
	malformed.run["district"] = "quay"
	expect(RulesEngine.migrate_state(malformed).is_empty(), "legacy unknown fields remain rejected")
	malformed = legacy_fixture(harbor)
	malformed.profile.stash[0].kind = "pumpGear"
	expect(RulesEngine.migrate_state(malformed).is_empty(), "legacy does not accept newly introduced item kinds")
	for mutation: Callable in [func(s: Dictionary) -> void: s.profile.credits = -1, func(s: Dictionary) -> void: s.profile.completedContracts = ["network"], func(s: Dictionary) -> void: s.profile.completedContracts = ["beacon", "beacon"], func(s: Dictionary) -> void: s.profile.selectedDistrict = "observatory", func(s: Dictionary) -> void: s.profile.activeContract = "network", func(s: Dictionary) -> void: s.profile.lampRepaired = true]:
		var bad: Dictionary = RulesEngine.new_game()
		mutation.call(bad)
		expect(not RulesEngine.validate_state(bad), "inconsistent v2 campaign state rejected")
	return true

func test_district_topology() -> bool:
	var signatures: Dictionary = {}
	for district: String in RulesEngine.Campaign.DISTRICTS:
		var variants: Dictionary = {}
		for seed_value: int in range(32):
			var world: Dictionary = World.create_world(seed_value, true, district)
			world.tide = 3
			var reachable: Dictionary = flood(world)
			var dry: Dictionary = flood(world, true)
			var goal_key: String = "%d,%d" % [world.goal.x, world.goal.y]
			expect(dry.has(goal_key), "district has dry objective/exit route " + district + " seed " + str(seed_value))
			for crate: Dictionary in world.containers:
				expect(reachable.has("%d,%d" % [crate.x, crate.y]), "district cache reachable " + district + "/" + crate.id)
			for foe: Dictionary in world.enemies:
				expect(World.is_walkable(world, foe.x, foe.y) and RulesEngine._distance(foe, world.exit) >= 10, "district enemy has legal safe-entry spawn " + district + "/" + foe.id)
			for landmark: Dictionary in RulesEngine.Campaign.DISTRICTS[district].landmarks:
				expect(world.tiles[landmark.y][landmark.x].type in ["wall", "water"], "district art anchored to actual blocked geometry " + district)
			variants[JSON.stringify(world.containers) + JSON.stringify(world.enemies)] = true
			var geometry: String = ""
			for row: Array in world.tiles:
				for tile: Dictionary in row:
					geometry += tile.type.left(1) + str(tile.elevation)
			if seed_value == 0:
				signatures[geometry] = true
			expect(world == with_tide(World.create_world(seed_value, true, district), 3), "district seed deterministic " + district)
		expect(variants.size() > 1, "district seeds vary cache/enemy choices " + district)
	expect(signatures.size() == 4, "four districts have genuinely different collision/elevation geometry")
	return true

func first_dry_step(run: Dictionary, target: Dictionary) -> Dictionary:
	var start: String = "%d,%d" % [run.player.x, run.player.y]
	var queue: Array = [{"x": run.player.x, "y": run.player.y, "first": {}}]
	var seen: Dictionary = {start: true}
	var index: int = 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		index += 1
		for d: Dictionary in RulesEngine.DIRECTIONS:
			var x: int = cell.x + d.x
			var y: int = cell.y + d.y
			var k: String = "%d,%d" % [x, y]
			if seen.has(k) or not World.is_walkable(run, x, y) or int(run.tiles[y][x].elevation) <= 3:
				continue
			var first: Dictionary = cell.first if not cell.first.is_empty() else d
			if x == target.x and y == target.y:
				return first
			seen[k] = true
			queue.append({"x": x, "y": y, "first": first})
	return {}

func campaign_travel(state: Dictionary, target: Dictionary) -> Dictionary:
	for step: int in range(180):
		if state.mode != "expedition":
			return state
		if state.run.player.x == target.x and state.run.player.y == target.y:
			return state
		var action: Dictionary
		if state.run.player.hp <= int(state.run.player.maxHp) - 10 and not uid(state, "medicine").is_empty():
			action = {"type": "use", "uid": uid(state, "medicine")}
		else:
			var direction: Dictionary = first_dry_step(state.run, target)
			if direction.is_empty():
				expect(false, "no dry step on actual district route " + state.run.district)
				return state
			var foe: Variant = RulesEngine._enemy_at(state.run, int(state.run.player.x) + int(direction.x), int(state.run.player.y) + int(direction.y))
			if foe != null and not uid(state, "bomb").is_empty() and foe.hp > int(RulesEngine.stats(state).attack):
				action = {"type": "use", "uid": uid(state, "bomb"), "dx": direction.x, "dy": direction.y}
			else:
				action = {"type": "move", "dx": direction.x, "dy": direction.y}
		state = act(state, action)
		var loaded: Variant = JSON.parse_string(JSON.stringify(state))
		expect(RulesEngine.validate_state(loaded), "actual district route saves complete resolved turn")
		state = RulesEngine.migrate_state(loaded)
	return state

func stash_kind(state: Dictionary, kind: String) -> Dictionary:
	for item: Dictionary in state.profile.stash:
		if item.kind == kind:
			return item
	return {}

func test_actual_campaign_route() -> bool:
	for seed_value: int in [7, 42, 1234]:
		var state: Dictionary = act(RulesEngine.new_game(), {"type": "choose", "character": "ritsu"})
		for story: String in RulesEngine.Campaign.STORY_IDS:
			state = act(state, {"type": "accept_contract", "id": story})
			# Recovered treasure funds supplies; the channel delivery needs one pearl.
			var kept_pearl: bool = false
			for item: Dictionary in state.profile.stash.duplicate():
				if item.kind == "pearl":
					if story == "channel" and not kept_pearl:
						kept_pearl = true
					else:
						state = act(state, {"type": "sell", "uid": item.uid})
			for kind: String in ["knife", "coat", "medicine", "medicine", "bomb", "flare"]:
				var item: Dictionary = stash_kind(state, kind)
				if item.is_empty():
					state = act(state, {"type": "buy", "kind": kind})
					item = stash_kind(state, kind)
				if not item.is_empty():
					state = act(state, {"type": "pack", "uid": item.uid})
			state = act(state, {"type": "depart", "seed": seed_value})
			state = campaign_travel(state, {"x": 12, "y": 21})
			state = act(state, {"type": "interact"})
			state = campaign_travel(state, state.run.goal.duplicate())
			if state.mode != "expedition":
				expect(false, "actual campaign survives objective " + story + " seed " + str(seed_value))
				return false
			state = act(state, {"type": "interact"})
			state = campaign_travel(state, state.run.exit.duplicate())
			if state.mode != "expedition":
				expect(false, "actual campaign survives return " + story + " seed " + str(seed_value))
				return false
			state = act(state, {"type": "interact"})
			expect(state.mode == "result" and state.result.outcome == "extracted", "actual district completes extraction " + story)
			state = act(state, {"type": "return"})
			state = act(state, {"type": "claim_contract", "id": story})
			expect(story in state.profile.completedContracts and RulesEngine.validate_state(state), "one actual expedition funds reconstruction " + story + " seed " + str(seed_value))
		expect(RulesEngine.campaign_summary(state).completed == 4, "all four districts complete without inserted inventory " + str(seed_value))
	return true


func test_legacy_store_backup() -> bool:
	var key: String = "shiogaeri-qa-v02-migration"
	var path: String = "user://qa-v02-migration.json"
	var old: Dictionary = legacy_fixture(prepared("sui", 7))
	var raw: String = JSON.stringify(old, "  ")
	expect(Store._write_serialized(key, path, raw).is_empty(), "legacy native fixture written under isolated QA path")
	var loaded: Dictionary = Store.load_game(key, path)
	expect(loaded.found and not loaded.corrupt and loaded.error.is_empty() and loaded.state.version == 3, "store loads valid legacy into v3 without writing it")
	expect(Store.read_value(key, path).raw == raw, "load alone leaves original v1 bytes unchanged")
	# A directory at the backup destination simulates an unwritable backup.
	DirAccess.make_dir_absolute(path + ".pre-v3")
	var error: String = Store.save_game(loaded.state, key, path)
	expect(not error.is_empty() and Store.read_value(key, path).raw == raw, "failed backup visibly refuses to overwrite original legacy save")
	DirAccess.remove_absolute(path + ".pre-v3")
	expect(Store.save_game(loaded.state, key, path).is_empty(), "store retries backup and writes v3 only after backup succeeds")
	expect(Store.read_value(key + "-pre-v3", path + ".pre-v3").raw == raw, "pre-v3 backup retains exact original bytes including formatting")
	loaded = Store.load_game(key, path)
	expect(loaded.state.version == 3 and preload("res://scripts/rules.gd").validate_state(loaded.state), "migrated native save reloads with complete run")
	var malformed: String = "{broken-save"
	Store._write_serialized(key, path, malformed)
	loaded = Store.load_game(key, path)
	expect(loaded.corrupt and Store.read_value(key, path).raw == malformed, "corrupt raw source stays untouched on load")
	for suffix: String in ["", ".bak", ".tmp", ".pre-v3", ".pre-v3.bak", ".pre-v3.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return true
