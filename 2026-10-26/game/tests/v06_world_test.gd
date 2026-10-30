extends SceneTree

const Generator = preload("res://scripts/v06_world.gd")
const DATA = preload("res://scripts/rules.gd")
var passed: int = 0
var failed: int = 0

func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func dry(tile: Dictionary) -> bool:
	return tile.type not in ["wall", "water"] and int(tile.elevation) > 3

func flood(world: Dictionary, start: Dictionary) -> Dictionary:
	var seen: Dictionary = {key(start.x, start.y): 0}
	var queue: Array = [Vector2i(start.x, start.y)]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.y < 0 or next.x >= world.width or next.y >= world.height or seen.has(key(next.x, next.y)):
				continue
			if dry(world.tiles[next.y][next.x]):
				seen[key(next.x, next.y)] = int(seen[key(cell.x, cell.y)]) + 1
				queue.append(next)
	return seen

func value(world: Dictionary) -> int:
	var total: int = 0
	for crate: Dictionary in world.containers:
		for item: Dictionary in crate.items:
			total += int(DATA.ITEMS[item.kind].value)
	return total

func topology(world: Dictionary) -> String:
	var result: String = ""
	for row: Array in world.tiles:
		for tile: Dictionary in row:
			result += str(tile.type).left(1) + str(int(tile.elevation))
	return result

func normalize_json(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		return value.map(normalize_json)
	if value is Dictionary:
		var result: Dictionary = {}
		for field: String in value:
			result[field] = normalize_json(value[field])
		return result
	return value

func check_world(world: Dictionary, label: String) -> void:
	expect(world.width == 25 and world.height == 29 and world.tiles.size() == 29, label + " dimensions")
	var reachable: Dictionary = flood(world, world.exit)
	var exit_count: int = 0
	var floor_count: int = 0
	var dry_edges: int = 0
	var low_count: int = 0
	var breach_count: int = 0
	for y: int in range(world.height):
		expect(world.tiles[y].size() == world.width, label + " row bounds")
		for x: int in range(world.width):
			var tile: Dictionary = world.tiles[y][x]
			expect(tile.type in ["wall", "water", "floor", "gate", "exit"] and int(tile.elevation) in range(10) and str(tile.zone).length() <= 30, label + " tile schema")
			if tile.type == "exit":
				exit_count += 1
			if tile.type == "wall" and tile.zone == "崩れた近道":
				breach_count += 1
			if tile.type == "floor" and int(tile.elevation) <= 3:
				low_count += 1
			if dry(tile):
				floor_count += 1
				expect(reachable.has(key(x, y)), label + " dry floor connected")
				for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
					var next: Vector2i = Vector2i(x, y) + offset
					if next.x < world.width and next.y < world.height and dry(world.tiles[next.y][next.x]):
						dry_edges += 1
	expect(exit_count == 1 and world.tiles[world.exit.y][world.exit.x].type == "exit", label + " single exit")
	expect(world.exit.y >= 23 and dry(world.tiles[world.exit.y][world.exit.x]), label + " bottom safe exit")
	expect(world.tiles[world.stairs.y][world.stairs.x].type == "floor" and reachable.has(key(world.stairs.x, world.stairs.y)), label + " dry stairs")
	expect(int(reachable.get(key(world.stairs.x, world.stairs.y), 0)) >= 12, label + " distant stairs")
	expect(reachable.has(key(world.goal.x, world.goal.y)), label + " dry objective")
	expect(dry_edges >= floor_count, label + " cycle exists")
	expect(floor_count >= 200 and floor_count <= 490, label + " room space budget")
	expect(low_count > 0 and breach_count > 0, label + " tide shortcut and optional breach")
	var container_cells: Dictionary = {}
	var item_uids: Dictionary = {}
	var count: int = 0
	var goal_items: Array = []
	for crate: Dictionary in world.containers:
		var cell_key: String = key(crate.x, crate.y)
		expect(absi(crate.x - world.exit.x) + absi(crate.y - world.exit.y) >= 8 and maxi(absi(crate.x - world.exit.x), absi(crate.y - world.exit.y)) > 4, label + " saleable supplies outside protected landing")
		expect(not container_cells.has(cell_key) and reachable.has(cell_key), label + " unique reachable crate")
		container_cells[cell_key] = true
		if crate.x == world.goal.x and crate.y == world.goal.y:
			goal_items = crate.items.map(func(item: Dictionary) -> String: return item.kind)
		for item: Dictionary in crate.items:
			count += 1
			expect(DATA.ITEMS.has(item.kind) and not item_uids.has(item.uid) and str(item.uid).begins_with("world-"), label + " temporary loot UIDs")
			item_uids[item.uid] = true
	expect(world.containers.size() == 8 and count > 12, label + " cargo choice pressure")
	expect(not goal_items.is_empty(), label + " objective is actual cache")
	if int(world.depth) == 1:
		var needs: Dictionary = {"quay": ["core", "scrap"], "market": ["pumpGear", "pumpGear", "scrap", "scrap"], "canal": ["chart", "pearl"], "observatory": ["sunLens", "pumpGear"]}
		expect(goal_items == needs[world.district], label + " delivery cargo")
	var enemies: Dictionary = {}
	for enemy: Dictionary in world.enemies:
		var cell_key: String = key(enemy.x, enemy.y)
		var entry_distance: int = absi(enemy.x - world.exit.x) + absi(enemy.y - world.exit.y)
		expect(reachable.has(cell_key) and not enemies.has(cell_key) and not container_cells.has(cell_key), label + " enemy placement")
		expect(entry_distance > 4 and maxi(absi(enemy.x - world.exit.x), absi(enemy.y - world.exit.y)) > 4 and cell_key != key(world.stairs.x, world.stairs.y), label + " safe arrival and stairs")
		expect(DATA.ENEMIES.has(enemy.kind) and enemy.hp == DATA.ENEMIES[enemy.kind].hp, label + " existing enemy stats")
		enemies[cell_key] = true
	expect(world.enemies.size() == 4 + int(world.depth) * 2, label + " depth pressure")
	var names: Dictionary = {}
	for encounter: Dictionary in world.encounters:
		expect(encounter.x >= 1 and encounter.y >= 1 and encounter.x + encounter.w < world.width and encounter.y + encounter.h < world.height, label + " encounter bounds")
		names[encounter.name] = true
	expect(names.size() == 8, label + " distinct room names")
	for landmark: Dictionary in world.landmarks:
		expect(landmark.x >= 0 and landmark.y >= 0 and landmark.x < world.width and landmark.y < world.height and world.tiles[landmark.y][landmark.x].type in ["wall", "water"], label + " collision anchored landmark")
	expect(not world.landmarks.is_empty(), label + " landmarks exist")
	# The generated full map, including loot and markers, survives JSON storage.
	var restored: Dictionary = JSON.parse_string(JSON.stringify(world))
	expect(normalize_json(restored) == world, label + " complete-map persistence")

func _initialize() -> void:
	for district: String in Generator.DISTRICTS:
		var layouts: Dictionary = {}
		var objectives: Dictionary = {}
		var loot_signatures: Dictionary = {}
		var enemy_signatures: Dictionary = {}
		for seed_value: int in range(32):
			var values: Array = []
			for depth: int in range(1, 4):
				var world: Dictionary = Generator.create_world(seed_value, false, district, depth)
				var label: String = "%s seed%d depth%d" % [district, seed_value, depth]
				check_world(world, label)
				expect(world == Generator.create_world(seed_value, false, district, depth), label + " deterministic")
				values.append(value(world))
				if depth == 1:
					layouts[topology(world)] = true
					objectives[key(world.goal.x, world.goal.y)] = true
					loot_signatures[JSON.stringify(world.containers)] = true
					enemy_signatures[JSON.stringify(world.enemies)] = true
			expect(values[1] > values[0] and values[2] > values[1], district + " deeper reward increases")
		expect(layouts.size() >= 28 and objectives.size() >= 16 and loot_signatures.size() >= 28 and enemy_signatures.size() >= 28, district + " meaningful per-seed variation")
	var fallback: Dictionary = Generator.create_world(-2147483648, true, "invalid", 99)
	expect(fallback.district == "quay" and fallback.depth == 3 and fallback.sight == 6, "bounded public inputs")
	check_world(fallback, "edge input")
	print("v0.6 generated world tests: %d passed, %d failed; 32 seeds x 4 districts x 3 depths" % [passed, failed])
	quit(1 if failed > 0 else 0)
