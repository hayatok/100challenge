extends SceneTree

const RulesEngine = preload("res://scripts/rules.gd")
const Legacy = preload("res://scripts/legacy_v03_rules.gd")
const World = preload("res://scripts/world_data.gd")
const Store = preload("res://scripts/save_store.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	for test: String in ["test_compact_routes", "test_prediction_and_charge", "test_crew", "test_shortcut_and_lure", "test_strict_migration_replay", "test_migration_backups", "test_ownership_and_reload", "test_schema_rejection", "test_actual_compact_campaign"]:
		if call(test) != true:
			failed += 1
			push_error("FAIL: %s aborted" % test)
	print("v0.4 tactical/migration tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func act(state: Dictionary, action: Dictionary) -> Dictionary:
	return RulesEngine.apply_action(state, action).state

func prepared(character: String = "isana", district: String = "quay", seed_value: int = 7) -> Dictionary:
	var state: Dictionary = RulesEngine.new_game()
	state.character = character
	state.profile.completedContracts = ["beacon", "pump", "channel"]
	state.profile.lampRepaired = true
	state.profile.activeContract = "network"
	state.profile.selectedDistrict = district
	for item: Dictionary in state.profile.stash.duplicate():
		state = act(state, {"type": "pack", "uid": item.uid})
	return act(state, {"type": "depart", "seed": seed_value})

func fixture(character: String = "isana") -> Dictionary:
	var state: Dictionary = prepared(character)
	for y: int in range(1, 18):
		for x: int in range(1, 16):
			state.run.tiles[y][x].type = "floor"
			state.run.tiles[y][x].elevation = 9
	state.run.tiles[17][8].type = "exit"
	state.run.landmarks = [{"kind": "arch", "x": 0, "y": 0}]
	state.run.containers = []
	state.run.enemies = []
	state.run.player.x = 8
	state.run.player.y = 14
	state.run.seen = RulesEngine.visible_tiles(state.run).keys()
	return state

func foe(kind: String, x: int, y: int, id: String = "fixture") -> Dictionary:
	return {"id": id, "kind": kind, "x": x, "y": y, "hp": int(RulesEngine.ENEMIES[kind].hp), "stunned": 0, "facing": {"x": 0, "y": 1}}

func item_uid(state: Dictionary, kind: String) -> String:
	for item: Dictionary in state.run.inventory:
		if item.kind == kind:
			return item.uid
	return ""

func distances(run: Dictionary, dry: bool = false) -> Dictionary:
	var found: Dictionary = {"%d,%d" % [run.exit.x, run.exit.y]: 0}
	var queue: Array = [run.exit]
	var index: int = 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		index += 1
		for direction: Dictionary in RulesEngine.DIRECTIONS:
			var x: int = int(cell.x) + int(direction.x)
			var y: int = int(cell.y) + int(direction.y)
			var key: String = "%d,%d" % [x, y]
			if not World.is_walkable(run, x, y) or found.has(key) or (dry and World.is_flooded(run, x, y)):
				continue
			found[key] = int(found["%d,%d" % [cell.x, cell.y]]) + 1
			queue.append({"x": x, "y": y})
	return found

func test_compact_routes() -> bool:
	var geometry: Dictionary = {}
	for district: String in RulesEngine.Campaign.DISTRICTS:
		for seed_value: int in range(32):
			var state: Dictionary = prepared("isana", district, seed_value)
			expect(RulesEngine.validate_state(state), "new compact state validates " + district + str(seed_value))
			expect(RulesEngine.validate_state(JSON.parse_string(JSON.stringify(state))), "compact full JSON round trip")
			var run: Dictionary = state.run.duplicate(true)
			expect(run.width == 17 and run.height == 19 and run.encounters.size() == 3, "bounded encounter graph")
			run.tide = 3
			var all: Dictionary = distances(run)
			var dry: Dictionary = distances(run, true)
			var key: String = "%d,%d" % [run.goal.x, run.goal.y]
			expect(dry.has(key), "dry delivery return exists " + district)
			expect(int(all.get(key, 999)) < 24 and int(run.goal.y) >= 6, "main cargo in middle area with compact return")
			for crate: Dictionary in run.containers:
				var crate_key: String = "%d,%d" % [crate.x, crate.y]
				expect(all.has(crate_key), "all optional cargo connected " + district + crate.id)
				expect(int(all.get(crate_key, 0)) >= 8 and crate.y <= 11, "no renewable landing-only cargo " + district + crate.id)
				expect(not crate.items.is_empty(), "encounter cargo is concrete")
			for enemy: Dictionary in run.enemies:
				expect(World.is_walkable(run, enemy.x, enemy.y) and RulesEngine._distance(enemy, run.exit) >= 6, "enemy placement legal beyond landing")
			var primary_kind: String = {"quay": "lighthouse", "market": "market", "canal": "clinic", "observatory": "pump"}[district]
			var primary_count: int = 0
			for anchor: Dictionary in run.landmarks:
				expect(run.tiles[anchor.y][anchor.x].type in ["wall", "water"], "landmark matches blocked map anchor")
				if anchor.kind == primary_kind:
					primary_count += 1
					expect(anchor.y < 17 and run.tiles[anchor.y][anchor.x].type in ["wall", "water"], "district primary landmark has a real field anchor " + district)
			expect(primary_count == 1, "exactly one district primary landmark exists " + district + " seed " + str(seed_value))
			expect(run.tiles[12][8].type == "wall", "breachable shortcut is visible from landing")
			if seed_value == 0:
				var signature: String = ""
				for row: Array in run.tiles:
					for tile: Dictionary in row:
						signature += tile.type.left(1) + str(tile.elevation)
				geometry[signature] = true
			expect(World.create_encounter_world(seed_value, true, district) == World.create_encounter_world(seed_value, true, district), "compact seed deterministic")
	expect(geometry.size() == 4, "district collision/elevation geometry differs")
	return true

func check_preview(state: Dictionary, action: Dictionary, label: String) -> Dictionary:
	var before: String = JSON.stringify(state)
	var prediction: Dictionary = RulesEngine.preview_action(state, action)
	var resolution: Dictionary = RulesEngine.apply_action(state, action)
	var hurt: int = 0
	for event: Dictionary in resolution.events:
		if event.type == "hurt":
			hurt += int(event.amount)
	expect(prediction.damage == hurt, "preview uses actual incoming damage " + label)
	expect(prediction.valid == (resolution.state != state), "preview validity agrees " + label)
	if resolution.state.run is Dictionary:
		expect(prediction.destination == {"x": resolution.state.run.player.x, "y": resolution.state.run.player.y}, "preview destination agrees " + label)
	expect(JSON.stringify(state) == before, "queries and resolution leave input unchanged " + label)
	expect(not prediction.has("inventory") and not prediction.has("events") and not prediction.has("loot"), "preview discloses no cache contents")
	return prediction

func test_prediction_and_charge() -> bool:
	var state: Dictionary = fixture()
	state.run.enemies = [foe("wader", 8, 11)]
	state.run.enemies[0]["intent"] = {"dx": 0, "dy": 1}
	var before: String = JSON.stringify(state)
	var prediction: Dictionary = check_preview(state, {"type": "wait"}, "announced charge")
	expect(prediction.damage == 4, "coat reduces 5 point charge to4")
	prediction = check_preview(state, {"type": "move", "dx": 1, "dy": 0}, "sidestep")
	expect(prediction.damage == 0, "leaving announced lane avoids charge")
	var threats: Array = RulesEngine.threats(state)
	expect(threats.size() == 1 and threats[0].phase == "charge" and threats[0].cells == [{"x": 8, "y": 12}, {"x": 8, "y": 13}, {"x": 8, "y": 14}], "announced cells match full clear charge lane")
	state.run.enemies.append(foe("crab", 1, 1, "hidden"))
	expect(RulesEngine.threats(state).size() == 1, "hidden foes omitted from threats")
	state.run.enemies.pop_back()
	expect(JSON.stringify(state) == before, "threat queries are pure")
	var charged: Dictionary = act(state, {"type": "wait"})
	expect(RulesEngine.validate_state(charged), "charge resolution persists full intent/stun state")
	charged = RulesEngine.migrate_state(JSON.parse_string(JSON.stringify(charged)))
	expect(act(charged, {"type": "wait"}) == act(act(state, {"type": "wait"}), {"type": "wait"}), "charge replay after JSON reload")
	return true

func test_crew() -> bool:
	var state: Dictionary = fixture("isana")
	var info: Dictionary = RulesEngine.crew_info(state)
	expect(info.charges == 3 and info.maxCharges == 3 and info.targeted and info.available, "crew exposes finite resource and targeting")
	var used: Dictionary = act(state, {"type": "crew", "dx": 0, "dy": -1})
	expect(used.run.player.y == 12 and used.run.turn == 1 and used.run.crewCharges == 2, "Isana two clear cells one turn one charge")
	state.run.tiles[12][8].type = "wall"
	var blocked: Dictionary = check_preview(state, {"type": "crew", "dx": 0, "dy": -1}, "invalid dash")
	expect(not blocked.valid and not blocked.reason.is_empty() and blocked.resourceCost == {"items": 0, "crewCharges": 0}, "invalid preview gives reason and no resource cost")
	expect(act(state, {"type": "crew", "dx": 0, "dy": -1}) == state, "blocked second cell costs neither turn nor charge")
	state.run.tiles[12][8].type = "floor"
	state.run.enemies = [foe("crab", 8, 13)]
	expect(act(state, {"type": "crew", "dx": 0, "dy": -1}) == state, "dash never bumps an enemy")
	state = fixture("ritsu")
	expect(act(state, {"type": "crew"}) == state, "ineffective brace is free")
	state.run.turn = 1
	state.run.armor = null
	state.run.enemies = [foe("diver", 8, 13), foe("crab", 7, 14, "second")]
	var prediction: Dictionary = check_preview(state, {"type": "crew"}, "brace")
	expect(prediction.damage == 1, "brace reduces each current enemy hit by3 to minimum0")
	used = act(state, {"type": "crew"})
	expect(used.run.player.hp == 27 and not used.run.has("brace") and used.run.crewCharges == 2, "brace resolves and cannot leak into later turns")
	used = act(used, {"type": "wait"})
	expect(used.run.player.hp == 25, "brace does not protect following turn")
	state = fixture("ritsu")
	state.run.turn = 31
	state.run.player.hp = 28
	state.run.tiles[14][8].elevation = 1
	state.run.enemies = [foe("crab", 8, 13)]
	used = act(state, {"type": "crew"})
	expect(used.run.player.hp == 27 and used.run.tide == 1, "brace does not reduce the independent tide wound")
	state = fixture("kohaku")
	state.run.enemies = [foe("wader", 8, 13)]
	state.run.enemies[0]["intent"] = {"dx": 0, "dy": 1}
	prediction = check_preview(state, {"type": "crew", "dx": 0, "dy": -1}, "shove")
	used = act(state, {"type": "crew", "dx": 0, "dy": -1})
	expect(used.run.enemies[0].y == 11 and used.run.enemies[0].hp == 5 and used.run.enemies[0].stunned == 1 and not used.run.enemies[0].has("intent"), "shove2 cells damage2 cancels charge and skips current phase")
	used = act(used, {"type": "wait"})
	expect(used.run.enemies[0].y == 11 and used.run.enemies[0].stunned == 0, "shove skips exactly one more phase")
	expect(RulesEngine.validate_state(used), "shoved state validates")
	state.run.tiles[12][8].type = "wall"
	used = act(state, {"type": "crew", "dx": 0, "dy": -1})
	expect(used.run.enemies[0].y == 13 and used.run.enemies[0].hp == 5, "blocked shove still damages and stuns without crossing walls")
	expect(act(state, {"type": "crew", "dx": 1, "dy": 0}) == state, "no adjacent foe means no charge spent")
	state = fixture("sui")
	for y: int in range(9, 18):
		state.run.tiles[y][9].type = "wall"
	state.run.seen = RulesEngine.visible_tiles(state.run).keys()
	expect(not RulesEngine.visible_tiles(state.run).has("10,14"), "fixture wall blocks ordinary view")
	used = act(state, {"type": "crew"})
	expect(used.run.surveyUntil == 3 and used.run.turn == 1 and RulesEngine.visible_tiles(used.run).has("10,14") and "10,14" in used.run.seen, "survey reveals radius5 through walls and remembers")
	expect(act(used, {"type": "crew"}) == used, "active survey repeated with no effect is free")
	for step: int in range(3):
		used = act(used, {"type": "wait"})
	expect(not RulesEngine.visible_tiles(used.run).has("10,14") and "10,14" in used.run.seen, "survey expires after3 resolved turns while map knowledge persists")
	expect(RulesEngine.validate_state(used), "expired survey remains saveable")
	state = fixture()
	for step: int in range(3):
		state = act(state, {"type": "crew", "dx": 0, "dy": -1})
	expect(state.run.crewCharges == 0 and not RulesEngine.crew_info(state).available and act(state, {"type": "crew", "dx": 0, "dy": -1}) == state, "finite three charges with no free fourth action")
	return true

func test_shortcut_and_lure() -> bool:
	var state: Dictionary = prepared()
	state.run.enemies = []
	state.run.player.x = 8
	state.run.player.y = 13
	state.run.seen = RulesEngine.visible_tiles(state.run).keys()
	var key: String = "%d,%d" % [state.run.goal.x, state.run.goal.y]
	var old_distance: int = distances(state.run)[key]
	var prediction: Dictionary = check_preview(state, {"type": "use", "uid": item_uid(state, "bomb"), "dx": 0, "dy": -1}, "breach")
	var breached: Dictionary = act(state, {"type": "use", "uid": item_uid(state, "bomb"), "dx": 0, "dy": -1})
	expect(breached.run.tiles[12][8].type == "floor" and int(distances(breached.run)[key]) < old_distance and prediction.resourceCost.items == 1, "spending bomb opens shorter return; alternate works without it")
	expect(RulesEngine.validate_state(breached), "opened shortcut persists")
	state.run.landmarks.append({"kind": "arch", "x": 8, "y": 12})
	breached = act(state, {"type": "use", "uid": item_uid(state, "bomb"), "dx": 0, "dy": -1})
	expect(RulesEngine.validate_state(breached) and breached.run.landmarks.size() == state.run.landmarks.size() - 1, "bomb removes decorative anchor when its wall is destroyed")
	state = fixture()
	state.run.enemies = [foe("wader", 8, 11), foe("crab", 11, 14, "flank")]
	state.run.enemies[0]["intent"] = {"dx": 0, "dy": 1}
	prediction = check_preview(state, {"type": "use", "uid": item_uid(state, "flare"), "dx": -1, "dy": 0}, "lure")
	var lured: Dictionary = act(state, {"type": "use", "uid": item_uid(state, "flare"), "dx": -1, "dy": 0})
	expect(prediction.damage == 0 and lured.run.enemies[0].target == {"x": 7, "y": 14, "turns": 3} and not lured.run.enemies[0].has("intent"), "flare spends actual item and redirects announced charge")
	expect(RulesEngine.validate_state(lured) and RulesEngine.validate_state(JSON.parse_string(JSON.stringify(lured))), "lure complete turn round trips")
	return true

func old_prepared(district: String = "quay") -> Dictionary:
	var state: Dictionary = Legacy.new_game()
	if district != "quay":
		state.profile.completedContracts = ["beacon", "pump", "channel"]
		state.profile.lampRepaired = true
		state.profile.activeContract = "network"
		state.profile.selectedDistrict = district
	for item: Dictionary in state.profile.stash.duplicate():
		state = Legacy.apply_action(state, {"type": "pack", "uid": item.uid}).state
	return Legacy.apply_action(state, {"type": "depart", "seed": 42}).state

func v1(old: Dictionary) -> Dictionary:
	var result: Dictionary = old.duplicate(true)
	result.version = 1
	for field: String in ["credits", "selectedDistrict", "activeContract", "completedContracts"]:
		result.profile.erase(field)
	if result.run is Dictionary:
		result.run.erase("district")
	return result

func legacy_shape(current: Dictionary) -> Dictionary:
	var result: Dictionary = current.duplicate(true)
	result.version = 2
	if result.run is Dictionary:
		result.run.erase("ruleset")
	return result

func test_strict_migration_replay() -> bool:
	var flight: Dictionary = old_prepared()
	flight.run.turn = 64
	flight.run.tide = 2
	flight.run.player.hp = 12
	flight.run.enemies[0]["target"] = {"x": 12, "y": 20, "turns": 3}
	flight.run.enemies[2]["intent"] = {"dx": 0, "dy": 1}
	var death: Dictionary = old_prepared()
	death.run.player.hp = 1
	death.run.enemies = [foe("crab", 12, 22)]
	death = Legacy.apply_action(death, {"type": "wait"}).state
	var extraction: Dictionary = Legacy.apply_action(old_prepared(), {"type": "interact"}).state
	for old: Dictionary in [Legacy.new_game(), flight, death, extraction]:
		for source: Dictionary in [old, v1(old)]:
			var raw: String = JSON.stringify(source)
			var migrated: Dictionary = RulesEngine.migrate_state(JSON.parse_string(raw))
			expect(not migrated.is_empty() and RulesEngine.validate_state(migrated), "strict v1/v2 mode migrates " + old.mode)
			if migrated.is_empty():
				return false
			expect(JSON.stringify(source) == raw and legacy_shape(migrated) == old, "all old fields including receipt, full map, HP, timing, items, knowledge remain equal")
			expect(RulesEngine.migrate_state(migrated) == migrated, "schema3 migration idempotent")
			var reference: Dictionary = old.duplicate(true)
			for action: Dictionary in [{"type": "crew", "dx": 0, "dy": -1}, {"type": "wait"}, {"type": "use", "uid": "i7", "dx": 0, "dy": -1}, {"type": "move", "dx": 0, "dy": -1}, {"type": "move", "dx": -1, "dy": 0}, {"type": "use", "uid": "i5", "dx": 0, "dy": -1}, {"type": "interact"}, {"type": "return"}]:
				var old_result: Dictionary = Legacy.apply_action(reference, action)
				var new_result: Dictionary = RulesEngine.apply_action(migrated, action)
				# Once a result returns to harbor both still use identical harbor actions.
				expect(legacy_shape(new_result.state) == old_result.state and new_result.events == old_result.events, "legacy exact action/effect replay " + action.type)
				reference = old_result.state
				migrated = new_result.state
				expect(RulesEngine.validate_state(JSON.parse_string(JSON.stringify(migrated))), "legacy resolved turn validates after JSON")
	var state: Dictionary = RulesEngine.migrate_state(extraction)
	state = act(act(state, {"type": "return"}), {"type": "depart", "seed": 1})
	expect(state.run.ruleset == "encounter-v04" and state.run.width == 17, "only next departure switches ruleset")
	for district: String in ["market", "canal", "observatory"]:
		var old: Dictionary = old_prepared(district)
		var migrated: Dictionary = RulesEngine.migrate_state(old)
		expect(legacy_shape(migrated) == old and RulesEngine.validate_state(migrated), "v2 non-quay full map and campaign preserved " + district)
		expect(legacy_shape(act(migrated, {"type": "wait"})) == Legacy.apply_action(old, {"type": "wait"}).state, "v2 non-quay next action identical " + district)
	var invalid: Dictionary = flight.duplicate(true)
	invalid.run["crewCharges"] = 3
	expect(RulesEngine.migrate_state(invalid).is_empty(), "v2 exact schema does not accept v3 fields")
	invalid = v1(flight)
	invalid.run.containers[0].items[0].kind = "pumpGear"
	expect(RulesEngine.migrate_state(invalid).is_empty(), "v1 exact item validator remains frozen")
	return true

func test_migration_backups() -> bool:
	var key: String = "shiogaeri-qa-v04-migration"
	var path: String = "user://qa-v04-migration.json"
	for source: Dictionary in [v1(old_prepared()), old_prepared()]:
		var raw: String = JSON.stringify(source, "  ") + "\n"
		expect(Store._write_serialized(key, path, raw).is_empty(), "old raw QA slot written")
		var loaded: Dictionary = Store.load_game(key, path)
		expect(not loaded.corrupt and loaded.state.version == 3 and Store.read_value(key, path).raw == raw, "old load is read-only")
		DirAccess.remove_absolute(path + ".pre-v3")
		DirAccess.make_dir_absolute(path + ".pre-v3")
		expect(not Store.save_game(loaded.state, key, path).is_empty() and Store.read_value(key, path).raw == raw, "backup failure blocks v1/v2 overwrite")
		DirAccess.remove_absolute(path + ".pre-v3")
		expect(Store.save_game(loaded.state, key, path).is_empty() and Store.read_value(key + "-pre-v3", path + ".pre-v3").raw == raw, "pre-v3 backup keeps exact original raw bytes")
		expect(Store.load_game(key, path).state == loaded.state, "native saved schema3 reload is exact")
	# Saving without load must also discover/protect a valid old source.
	var raw: String = JSON.stringify(old_prepared(), "\t")
	Store._write_serialized(key, path, raw)
	Store.legacy_raw_pending = ""
	expect(Store.save_game(RulesEngine.migrate_state(old_prepared()), key, path).is_empty() and Store.read_value(key + "-pre-v3", path + ".pre-v3").raw == raw, "backup does not depend on pending migration global")
	for raw_bad: String in ["{broken", '{"version":999}']:
		Store._write_serialized(key, path, raw_bad)
		var loaded: Dictionary = Store.load_game(key, path)
		expect(loaded.corrupt and Store.read_value(key, path).raw == raw_bad, "malformed/unsupported raw data untouched on load")
	for suffix: String in ["", ".bak", ".tmp", ".pre-v3", ".pre-v3.bak", ".pre-v3.tmp"]:
		DirAccess.remove_absolute(path + suffix)
	return true

func test_ownership_and_reload() -> bool:
	var state: Dictionary = fixture()
	var before: int = state.run.inventory.size()
	state.run.player.x = 8
	state.run.player.y = 17
	state = act(state, {"type": "interact"})
	expect(state.mode == "result" and state.profile.stash.size() == before and state.result.inventory.size() == before and RulesEngine.validate_state(state), "new extraction transfers owned inventory exactly once")
	var receipt: Dictionary = state.duplicate(true)
	state = act(state, {"type": "return"})
	expect(act(state, {"type": "return"}) == state and state.profile.stash.size() == before, "receipt cannot transfer again")
	expect(RulesEngine.migrate_state(JSON.parse_string(JSON.stringify(receipt))) == receipt, "extraction JSON receipt exact")
	state = fixture()
	state.run.player.hp = 1
	state.run.enemies = [foe("crab", 8, 13)]
	var carried: Array = state.run.inventory.duplicate(true)
	state = act(state, {"type": "wait"})
	expect(state.result.outcome == "dead" and state.result.inventory == carried and state.profile.stash.is_empty() and RulesEngine.validate_state(state), "new death loses full carried inventory and preserves receipt")
	expect(RulesEngine.migrate_state(JSON.parse_string(JSON.stringify(state))) == state, "death JSON receipt exact")
	state = act(act(state, {"type": "return"}), {"type": "depart", "seed": 8})
	expect(state.run.inventory.size() == 1 and state.run.inventory[0].kind == "loanKnife" and state.run.crewCharges == 3, "total loss can retry with new knife and crew resource")
	state = act(state, {"type": "interact"})
	expect(state.profile.stash.is_empty() and state.result.inventory.is_empty(), "landing departure/extraction creates no sale cargo")
	return true

func test_schema_rejection() -> bool:
	var state: Dictionary = prepared()
	for mutation: Callable in [func(s: Dictionary) -> void: s.run.ruleset = "unknown", func(s: Dictionary) -> void: s.run.crewCharges = 4, func(s: Dictionary) -> void: s.run.surveyUntil = 99, func(s: Dictionary) -> void: s.run.encounters[0]["extra"] = true, func(s: Dictionary) -> void: s.run.landmarks[0].x = 99, func(s: Dictionary) -> void: s.run.width = 25, func(s: Dictionary) -> void: s.run.player.x = 20, func(s: Dictionary) -> void: s.run.tiles = [], func(s: Dictionary) -> void: s.run.landmarks = [{"kind": "bogus", "x": 0, "y": 0}], func(s: Dictionary) -> void: s.profile.stash.append(s.run.inventory[0])]:
		var bad: Dictionary = state.duplicate(true)
		mutation.call(bad)
		expect(not RulesEngine.validate_state(bad) and RulesEngine.migrate_state(bad).is_empty(), "strict schema3 rejects malformed metadata/ownership")
	return true


func first_dry_step(run: Dictionary, target: Dictionary) -> Dictionary:
	var queue: Array = [{"x": run.player.x, "y": run.player.y, "first": {}}]
	var seen: Dictionary = {"%d,%d" % [run.player.x, run.player.y]: true}
	var index: int = 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		index += 1
		for d: Dictionary in RulesEngine.DIRECTIONS:
			var x: int = int(cell.x) + int(d.x)
			var y: int = int(cell.y) + int(d.y)
			var key: String = "%d,%d" % [x, y]
			if seen.has(key) or not World.is_walkable(run, x, y) or World.is_flooded(run, x, y):
				continue
			var first: Dictionary = cell.first if not cell.first.is_empty() else {"dx": int(d.x), "dy": int(d.y)}
			if x == int(target.x) and y == int(target.y):
				return first
			seen[key] = true
			queue.append({"x": x, "y": y, "first": first})
	return {}

func travel_to(state: Dictionary, target: Dictionary) -> Dictionary:
	for step: int in range(150):
		if state.mode != "expedition" or RulesEngine._distance(state.run.player, target) == 0:
			return state
		var medicine: String = item_uid(state, "medicine")
		if int(state.run.player.hp) <= 14 and not medicine.is_empty():
			state = act(state, {"type": "use", "uid": medicine})
			continue
		var direction: Dictionary = first_dry_step(state.run, target)
		if direction.is_empty():
			return state
		var action: Dictionary = {"type": "move", "dx": direction.dx, "dy": direction.dy}
		var enemy: Variant = RulesEngine._enemy_at(state.run, int(state.run.player.x) + int(direction.dx), int(state.run.player.y) + int(direction.dy))
		if enemy != null and int(enemy.hp) > int(RulesEngine.stats(state).attack) and not item_uid(state, "bomb").is_empty():
			action = {"type": "use", "uid": item_uid(state, "bomb"), "dx": direction.dx, "dy": direction.dy}
		state = act(state, action)
	return state

func test_actual_compact_campaign() -> bool:
	for seed_value: int in [0, 7, 31]:
		var state: Dictionary = RulesEngine.new_game()
		for story: String in RulesEngine.Campaign.STORY_IDS:
			for item: Dictionary in state.profile.stash.duplicate():
				state = act(state, {"type": "pack", "uid": item.uid})
			state = act(state, {"type": "accept_contract", "id": story})
			state = act(state, {"type": "depart", "seed": seed_value})
			var goal: Dictionary = state.run.goal.duplicate()
			state = travel_to(state, goal)
			expect(state.mode == "expedition" and RulesEngine._distance(state.run.player, goal) == 0, "actual compact delivery route reached " + story + str(seed_value))
			if state.mode != "expedition":
				return false
			var enemies_before: int = state.run.enemies.size()
			state = act(state, {"type": "interact"})
			expect(state.run.enemies.size() <= enemies_before, "delivery pickup never spawns surprise enemies")
			state = travel_to(state, state.run.exit.duplicate())
			expect(state.mode == "expedition" and RulesEngine._distance(state.run.player, state.run.exit) == 0, "actual compact loaded return survives " + story)
			if state.mode != "expedition":
				return false
			state = act(state, {"type": "interact"})
			expect(state.mode == "result" and state.result.outcome == "extracted", "actual compact cargo extracted " + story)
			state = act(act(state, {"type": "return"}), {"type": "claim_contract", "id": story})
			expect(story in state.profile.completedContracts and RulesEngine.validate_state(state), "actual compact run funds contract with real owned UIDs " + story)
		expect(RulesEngine.campaign_summary(state).completed == 4, "compact four-district delivery campaign complete without injected cargo")
	return true
