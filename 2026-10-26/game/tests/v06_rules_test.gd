extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Old = preload("res://scripts/rules_v05.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: int = 0
var failures: int = 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func act(state: Dictionary, action: Dictionary) -> Dictionary:
	return Rules.apply_action(state, action).state

func prepared() -> Dictionary:
	var state: Dictionary = Rules.new_game()
	for item: Dictionary in state.profile.stash.duplicate():
		state = act(state, {"type": "pack", "uid": item.uid})
	return act(state, {"type": "depart", "seed": 19})

func fixture() -> Dictionary:
	var state: Dictionary = prepared()
	state.run.enemies = []
	for y: int in range(1, 28):
		for x: int in range(1, 24):
			state.run.tiles[y][x].type = "floor"
			state.run.tiles[y][x].elevation = 9
	state.run.tiles[int(state.run.exit.y)][int(state.run.exit.x)].type = "exit"
	state.run.landmarks = []
	state.run.player.x = 12
	state.run.player.y = 24
	state.run.containers = [{"id": "choice", "x": 12, "y": 23, "items": [Rules._new_item(state, "core"), Rules._new_item(state, "pearl"), Rules._new_item(state, "scrap")], "searched": false}]
	state.run.seen = Rules.visible_tiles(state.run).keys()
	return state

func test_generated_state_contract() -> void:
	for character: String in Rules.CHARACTERS:
		for district: String in Rules.Campaign.DISTRICTS:
			for seed_value: int in [0, 7, 4294967295]:
				var state: Dictionary = Rules.new_game()
				state.character = character
				state.profile.completedContracts = ["beacon", "pump", "channel"]
				state.profile.lampRepaired = true
				state.profile.activeContract = "network"
				state.profile.selectedDistrict = district
				state = act(state, {"type": "depart", "seed": seed_value})
				for depth: int in range(1, 4):
					expect(Rules.validate_state(state) and Rules.migrate_state(JSON.parse_string(JSON.stringify(state))) == state, "%s/%s/%d/depth%d full resolved state roundtrip" % [character, district, seed_value, depth])
					if depth < 3:
						state.run.player.x = state.run.stairs.x
						state.run.player.y = state.run.stairs.y
						state = act(state, {"type": "advance"})

func test_inventory() -> void:
	var state: Dictionary = fixture()
	expect(Rules.validate_state(state), "full v06 fixture validates")
	var start: String = JSON.stringify(state)
	expect(Rules.container_contents(state, "choice").is_empty(), "unsearched contents never disclose items")
	expect(JSON.stringify(state) == start, "reading keeps state exact")
	expect(act(state, {"type": "take", "containerId": "choice", "uid": state.run.containers[0].items[0].uid}) == state, "unsearched take has no effect")
	state = act(state, {"type": "interact", "containerId": "choice"})
	expect(state.run.turn == 1 and state.run.inventory.size() == 8 and state.run.containers[0].items.size() == 3, "opening costs one turn and never transfers")
	expect(act(state, {"type": "interact", "containerId": "choice"}) == state, "reading open cache costs no turn")
	while state.run.inventory.size() < 13:
		state.run.inventory.append(Rules._new_item(state, "scrap"))
	var selected: String = state.run.containers[0].items[0].uid
	state = act(state, {"type": "take_all", "containerId": "choice"})
	expect(state.run.turn == 2 and state.run.inventory.size() == 14 and state.run.containers[0].items.size() == 2 and Rules._find_item(state.run.inventory, selected).kind == "core", "partial take keeps real UID and remainder")
	var owned: String = state.run.weapon
	var target: String = state.run.containers[0].items[0].uid
	state = act(state, {"type": "swap", "containerId": "choice", "uid": target, "dropUid": owned})
	expect(state.run.turn == 3 and state.run.inventory.size() == 14 and state.run.weapon == null and not Rules._find_item(state.run.containers[0].items, owned).is_empty(), "full bag swap is atomic and clears equipped UID")
	expect(Rules.validate_state(state), "ownership remains valid after partial take and swap")
	expect(act(state, {"type": "swap", "containerId": "choice", "uid": "i999999", "dropUid": owned}) == state, "bad swap leaves everything unchanged")
	state.run.player.x = 22
	state.run.player.y = 24
	expect(Rules.container_contents(state, "choice").is_empty() and act(state, {"type": "take_all", "containerId": "choice"}) == state, "remote cache cannot read or transfer")

func test_preparation() -> void:
	var state: Dictionary = Rules.new_game()
	var knife: String = state.profile.stash[0].uid
	state = act(state, {"type": "pack", "uid": knife})
	var extra: Dictionary = Rules._new_item(state, "harpoon")
	state.profile.stash.append(extra)
	state = act(state, {"type": "pack", "uid": extra.uid})
	expect(Rules.stats(state).attack == 3, "packing second weapon leaves first selection")
	state = act(state, {"type": "equip", "uid": extra.uid})
	expect(Rules.stats(state).attack == 5 and state.preparation.weapon == extra.uid, "explicit prepared weapon drives stats")
	var departed: Dictionary = act(state, {"type": "depart", "seed": 1})
	expect(departed.run.weapon == extra.uid and Rules.stats(departed).attack == 5, "departure uses selected concrete UID")
	state = act(state, {"type": "unpack_all"})
	expect(state.loadout.is_empty() and state.profile.stash.size() == 9 and state.preparation.weapon == null, "unpack all moves actual items and clears preparation")

func test_depth_and_loss() -> void:
	var state: Dictionary = prepared()
	var original: Dictionary = state.duplicate(true)
	expect(act(state, {"type": "advance"}) == state, "advance requires standing on stairs")
	for depth: int in [2, 3]:
		state.run.player.x = state.run.stairs.x
		state.run.player.y = state.run.stairs.y
		state.run.player.hp = 17
		var inventory: Array = state.run.inventory.duplicate(true)
		var turn: int = int(state.run.turn)
		state = act(state, {"type": "advance"})
		expect(state.run.depth == depth and state.run.turn == turn + 1 and state.run.inventory == inventory and state.run.player.hp == 17 and state.run.crewCharges == 3, "descent preserves resources and consumes one turn")
		expect(Rules.validate_state(state) and Rules.migrate_state(JSON.parse_string(JSON.stringify(state))) == state, "new floor full JSON reload is exact")
	expect(act(state, {"type": "advance"}) == state, "no fourth floor")
	state.run.enemies = []
	state.run.player.x = state.run.exit.x
	state.run.player.y = state.run.exit.y
	state = act(state, {"type": "interact"})
	expect(state.mode == "result" and state.profile.stash.size() == 8 and act(state, {"type": "interact"}) == state, "extraction owns each surviving UID once")
	var doomed: Dictionary = original.duplicate(true)
	doomed.profile.stash.append(Rules._new_item(doomed, "pearl"))
	doomed.run.player.hp = 1
	doomed.run.tiles[int(doomed.run.player.y)][int(doomed.run.player.x)].elevation = 0
	doomed.run.enemies = []
	doomed = act(doomed, {"type": "wait"})
	expect(doomed.mode == "result" and doomed.result.outcome == "dead" and doomed.profile.stash.size() == 1 and doomed.loadout.is_empty(), "death loses full carried bag and keeps stash")

func test_compatibility() -> void:
	var old: Dictionary = Old.apply_action(Old.new_game(), {"type": "depart", "seed": 7}).state
	var current: Dictionary = Rules.migrate_state(JSON.parse_string(JSON.stringify(old)))
	expect(current == old, "v3 in flight migration is exact")
	for action: Dictionary in [{"type": "wait"}, {"type": "move", "dx": 0, "dy": -1}, {"type": "move", "dx": 0, "dy": 1}, {"type": "interact"}]:
		var expected: Dictionary = Old.apply_action(old, action)
		var actual: Dictionary = Rules.apply_action(current, action)
		expect(actual == expected, "legacy future action/event replay exact")
		old = expected.state
		current = actual.state
	var corrupt: Dictionary = Rules.new_game()
	corrupt.profile.commissionCycle = 0.5
	expect(Rules.migrate_state(corrupt).is_empty(), "fractional counter rejected before normalization")
	corrupt = Rules.new_game()
	corrupt.preparation.weapon = "i1"
	expect(not Rules.validate_state(corrupt), "prepared UID must belong to loadout")

func test_legacy_terminal_replay() -> void:
	for version: int in [1, 2, 3]:
		for outcome: String in ["extract", "death"]:
			var source: Dictionary
			if version == 3:
				source = Old.apply_action(Old.new_game(), {"type": "depart", "seed": 2}).state
			else:
				source = Rules.Legacy.apply_action(Rules.Legacy.new_game(), {"type": "depart", "seed": 2}).state
				if version == 1:
					source.version = 1
					for field: String in ["credits", "selectedDistrict", "activeContract", "completedContracts"]:
						source.profile.erase(field)
					source.run.erase("district")
			if outcome == "death":
				source.run.player.hp = 1
				source.run.enemies = []
				source.run.tiles[int(source.run.player.y)][int(source.run.player.x)].elevation = 0
			var expected: Dictionary = Old.migrate_state(source)
			var current: Dictionary = Rules.migrate_state(JSON.parse_string(JSON.stringify(source)))
			expect(not current.is_empty() and current == expected and Rules.validate_state(current), "v%d full active run survives strict migration" % version)
			var action: Dictionary = {"type": "interact" if outcome == "extract" else "wait"}
			var frozen: Dictionary = Old.apply_action(expected, action)
			var resolved: Dictionary = Rules.apply_action(current, action)
			expect(resolved == frozen and resolved.state.mode == "result" and Rules.validate_state(resolved.state), "v%d %s terminal state/events exact" % [version, outcome])
			var returned: Dictionary = act(resolved.state, {"type": "return"})
			expect(returned.version == 4 and returned.mode == "harbor" and Rules.validate_state(returned), "v%d upgrades only after terminal result" % version)
			expect(act(returned, {"type": "depart", "seed": 10}).run.ruleset == "expedition-v06", "next departure adopts v06")

func test_schema_boundaries() -> void:
	var state: Dictionary = prepared()
	for field: String in ["depth", "stairs", "layoutName", "crewCharges", "inventory", "tiles"]:
		var bad: Dictionary = state.duplicate(true)
		bad.run.erase(field)
		expect(Rules.migrate_state(bad).is_empty(), "missing required " + field + " rejected")
	var bad: Dictionary = state.duplicate(true)
	bad.run.depth = 1.2
	expect(Rules.migrate_state(bad).is_empty(), "fractional depth rejected")
	bad = state.duplicate(true)
	bad.run.stairs.x = 24.5
	expect(Rules.migrate_state(bad).is_empty(), "fractional stairs coordinate rejected")
	bad = state.duplicate(true)
	bad.run.tiles[int(bad.run.stairs.y)][int(bad.run.stairs.x)].type = "wall"
	expect(Rules.migrate_state(bad).is_empty(), "stairs must remain walkable")
	bad = state.duplicate(true)
	bad.run.containers[0].items.append(bad.run.inventory[0].duplicate())
	expect(Rules.migrate_state(bad).is_empty(), "UID cannot be owned and in cache")
	bad = state.duplicate(true)
	bad["unknown"] = 1
	expect(Rules.migrate_state(bad).is_empty(), "unknown schema fields rejected")
	bad = Rules.new_game()
	bad.loadout = null
	bad.preparation.weapon = "i1"
	expect(Rules.migrate_state(bad).is_empty(), "invalid loadout type rejected without coercion")
	bad = state.duplicate(true)
	bad.run.enemies[0].hp = 0
	expect(Rules.migrate_state(bad).is_empty(), "dead enemies never persist in resolved state")

func test_fog_combat_and_atomicity() -> void:
	var state: Dictionary = fixture()
	state.run.containers[0].x = 14
	state.run.containers[0].y = 24
	state.run.tiles[24][13].type = "wall"
	var before: Dictionary = state.duplicate(true)
	expect(Rules.container_contents(state, "choice").is_empty() and act(state, {"type": "interact", "containerId": "choice"}) == before, "occluded cache cannot be opened")
	state = fixture()
	state = act(state, {"type": "interact", "containerId": "choice"})
	var uid: String = state.run.containers[0].items[2].uid
	state = act(state, {"type": "take", "containerId": "choice", "uid": uid})
	expect(state.run.inventory.back().uid == uid and state.run.containers[0].items.size() == 2, "single take selects requested UID rather than first item")
	expect(act(state, {"type": "take_all"}) == state, "missing container ID cannot transfer")
	var carried: Array = state.run.inventory.duplicate(true)
	state.run.enemies = [{"id": "last-hit", "kind": "crab", "hp": 1, "x": 13, "y": 24}]
	state = act(state, {"type": "move", "dx": 1, "dy": 0})
	expect(state.run.enemies.is_empty() and state.run.inventory == carried and Rules.validate_state(state), "killed enemy disappears and ownership survives combat turn")
	state.run.turn = 31
	state.run.tide = 0
	state.run.player.x = state.run.stairs.x
	state.run.player.y = state.run.stairs.y
	state = act(state, {"type": "advance"})
	expect(state.run.turn == 32 and state.run.tide == 1 and Rules.validate_state(state), "descent crosses global tide boundary once")

func test_progression_and_backup() -> void:
	var state: Dictionary = Rules.new_game()
	state.profile.completedContracts = ["beacon", "pump", "channel", "network", "isana_parcel", "ritsu_clinic", "kohaku_tools", "sui_atlas"]
	state.profile.lampRepaired = true
	state.profile.activeContract = "salvage_order"
	state.profile.credits = 100
	expect(Rules.validate_state(state), "all milestones and repeat contract validate")
	expect(Rules.Campaign.price(state, "medicine") == 8 and Rules.Campaign.price(state, "bomb") == 14 and Rules.Campaign.price(state, "flare") == 10, "milestones discount tools without buy/sell exploit")
	for cycle: int in range(6):
		var row: Dictionary = {}
		for candidate: Dictionary in Rules.contracts(state):
			if candidate.id == "salvage_order":
				row = candidate
		for requirement: Dictionary in row.requirements:
			for count: int in range(int(requirement.count)):
				state.profile.stash.append(Rules._new_item(state, requirement.kind))
		state = act(state, {"type": "claim_contract", "id": "salvage_order"})
		expect(state.profile.commissionCycle == cycle + 1 and Rules.validate_state(state), "repeat contract rotates and remains valid")
		var after: Dictionary = act(state, {"type": "claim_contract", "id": "salvage_order"})
		expect(after == state, "same consumed UIDs cannot claim again")
	expect(not Rules.campaign_summary(state).title.is_empty(), "finished story gives next useful goal")
	var atlas: Dictionary = act(state, {"type": "depart", "seed": 19})
	expect(atlas.run.seen.size() > Rules.visible_tiles(atlas.run).size() and Rules.nearby_containers(atlas).is_empty(), "atlas records room geometry but no remote cache access")
	var key: String = "v06-rules-backup"
	var path: String = "user://v06-rules-backup.json"
	var old: Dictionary = Old.new_game()
	var raw: String = JSON.stringify(old, "  ")
	Store._write_serialized(key, path, raw)
	var loaded: Dictionary = Store.load_game(key, path)
	expect(loaded.state.version == 4 and Store.read_value(key, path).raw == raw, "old harbor upgrades read only")
	DirAccess.remove_absolute(path + ".pre-v4")
	DirAccess.make_dir_absolute(path + ".pre-v4")
	expect(not Store.save_game(loaded.state, key, path).is_empty() and Store.read_value(key, path).raw == raw, "failed v4 backup blocks overwrite")
	DirAccess.remove_absolute(path + ".pre-v4")
	expect(Store.save_game(loaded.state, key, path).is_empty() and Store.read_value(key + "-pre-v4", path + ".pre-v4").raw == raw, "pre-v4 protects exact source bytes")
	for suffix: String in ["", ".bak", ".tmp", ".pre-v4", ".pre-v4.bak", ".pre-v4.tmp"]:
		DirAccess.remove_absolute(path + suffix)

func _initialize() -> void:
	test_generated_state_contract()
	test_inventory()
	test_preparation()
	test_depth_and_loss()
	test_compatibility()
	test_legacy_terminal_replay()
	test_schema_boundaries()
	test_fog_combat_and_atomicity()
	test_progression_and_backup()
	print("v0.6 rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
