extends SceneTree

const RulesEngine = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world_data.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	for test: String in ["test_initial_and_traits", "test_immutable_replay", "test_invalid_actions", "test_extraction_once_and_loan", "test_death_and_restart", "test_inventory_overflow_and_drop", "test_tools", "test_enemy_timing", "test_tide_and_visibility", "test_seed_connectivity", "test_save_validation", "test_complete_goal_route", "test_combat_save_boundaries", "test_tool_save_boundaries"]:
		if call(test) != true:
			failed += 1
			push_error("%s did not finish (runtime error or failed route)" % test)
	print("Rules tests: %d passed, %d failed" % [passed, failed])
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
		func(s: Dictionary) -> void: s.version = 2,
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
