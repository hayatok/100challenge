class_name WorldData
extends RefCounted

static func is_walkable(run: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= int(run.width) or y >= int(run.height):
		return false
	return run.tiles[y][x].type not in ["wall", "water"]

# Deep water is always blocked; only walkable low ground takes tide damage.
static func is_flooded(run: Dictionary, x: int, y: int) -> bool:
	return is_walkable(run, x, y) and int(run.tide) >= int(run.tiles[y][x].elevation)

static func _random(rng: Dictionary, count: int) -> int:
	# Small explicit LCG: seed sequences are independent of Godot's RNG version.
	rng.value = (int(rng.value) * 1664525 + 1013904223) & 0xffffffff
	return int(rng.value) % count

static func _paint(tiles: Array, x: int, y: int, kind: String, elevation: int = 9) -> void:
	tiles[y][x].type = kind
	tiles[y][x].elevation = elevation

static func _room(tiles: Array, x1: int, y1: int, x2: int, y2: int, doors: Array) -> void:
	for y: int in range(y1, y2 + 1):
		for x: int in range(x1, x2 + 1):
			if x == x1 or x == x2 or y == y1 or y == y2:
				_paint(tiles, x, y, "wall")
	for door: Array in doors:
		_paint(tiles, door[0], door[1], "gate")

static func _crate(id: String, position: Array, kinds: Array) -> Dictionary:
	var items: Array = []
	for kind: String in kinds:
		items.append({"uid": "world-%s-%d" % [id, items.size()], "kind": kind})
	return {"id": id, "x": position[0], "y": position[1], "items": items, "searched": false}

static func _enemy(id: String, kind: String, position: Array, hp: int) -> Dictionary:
	return {"id": id, "kind": kind, "x": position[0], "y": position[1], "hp": hp,
		"facing": {"x": 0, "y": 1}, "stunned": 0}

static func _quay(seed_value: int, lamp_repaired: bool) -> Dictionary:
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	var tiles: Array = []
	for y: int in range(25):
		var row: Array = []
		for x: int in range(25):
			var zone: String = "船着き場" if y >= 18 else ("沈み市場" if x < 12 else "旧診療所") if y >= 10 else ("揚水小屋" if x < 12 else "旧灯台")
			row.append({"type": "wall" if x == 0 or y == 0 or x == 24 or y == 24 else "floor",
				"elevation": 2 if y >= 18 else 1 if y >= 10 else 3,
				"zone": zone, "variant": _random(rng, 4)})
		tiles.append(row)
	for y: int in [9, 17]:
		for x: int in range(1, 24):
			_paint(tiles, x, y, "water", 0)
	_room(tiles, 3, 11, 9, 16, [[9, 14], [6, 16]])
	_room(tiles, 16, 12, 22, 16, [[16, 14], [19, 16]])
	_room(tiles, 3, 3, 8, 7, [[8, 5], [5, 7]])
	_room(tiles, 18, 1, 23, 6, [[18, 4], [21, 6]])
	# A continuous elevated spine and lighthouse branch stay dry at maximum tide.
	for y: int in range(4, 24):
		_paint(tiles, 12, y, "floor")
	for x: int in range(12, 22):
		_paint(tiles, x, 4, "gate" if x == 18 else "floor")
	for y: int in range(3, 11):
		_paint(tiles, 21, y, "gate" if y == 6 else "floor")
	_paint(tiles, 12, 23, "exit")
	_paint(tiles, 11, 21, "floor")
	var market_positions: Array = [[5, 13], [7, 14], [6, 15]]
	var clinic_positions: Array = [[19, 13], [20, 14], [18, 15]]
	var pump_positions: Array = [[5, 5], [6, 4], [6, 6]]
	var quay_positions: Array = [[15, 20], [17, 22], [8, 19]]
	var crab_west: Array = [[7, 12], [5, 14], [8, 15]]
	var crab_east: Array = [[18, 13], [20, 15], [21, 14]]
	var wader_west: Array = [[9, 8], [10, 6], [9, 4]]
	var wader_east: Array = [[16, 7], [15, 6], [17, 8]]
	return {"width": 25, "height": 25, "tiles": tiles,
		"exit": {"x": 12, "y": 23}, "goal": {"x": 21, "y": 3}, "sight": 6 if lamp_repaired else 5,
		"containers": [
			_crate("harbor-supply", [11, 21], ["scrap", "medicine"]),
			_crate("market-cache", market_positions[_random(rng, 3)], ["pearl", "bomb", "scrap"]),
			_crate("clinic-cache", clinic_positions[_random(rng, 3)], ["medicine", "flare", "medicine"]),
			_crate("pump-cache", pump_positions[_random(rng, 3)], ["harpoon", "pearl"]),
			_crate("lighthouse-core", [21, 3], ["core", "pearl"]),
			_crate("quay-cache", quay_positions[_random(rng, 3)], ["pearl", "scrap"])],
		"enemies": [
			_enemy("crab-market", "crab", crab_west[_random(rng, 3)], 5),
			_enemy("crab-clinic", "crab", crab_east[_random(rng, 3)], 5),
			_enemy("wader-west", "wader", wader_west[_random(rng, 3)], 7),
			_enemy("wader-east", "wader", wader_east[_random(rng, 3)], 7),
			_enemy("diver-guard", "diver", [20, 3], 11)]}


static func create_world(seed_value: int, lamp_repaired: bool = false, district: String = "quay") -> Dictionary:
	var world: Dictionary
	match district:
		"market": world = _market(seed_value, lamp_repaired)
		"canal": world = _canal(seed_value, lamp_repaired)
		"observatory": world = _observatory(seed_value, lamp_repaired)
		_: world = _quay(seed_value, lamp_repaired)
	world["district"] = district if district in ["market", "canal", "observatory"] else "quay"
	return world

static func _base(seed_value: int, district: String, kind: String, elevation: int = 9) -> Dictionary:
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	var tiles: Array = []
	for y: int in range(25):
		var row: Array = []
		for x: int in range(25):
			var zone: String = "船着き場" if y >= 21 else district
			row.append({"type": "wall" if x == 0 or y == 0 or x == 24 or y == 24 else kind, "elevation": elevation, "zone": zone, "variant": _random(rng, 4)})
		tiles.append(row)
	return {"width": 25, "height": 25, "tiles": tiles, "exit": {"x": 12, "y": 23}, "goal": {"x": 12, "y": 3}, "sight": 5, "containers": [], "enemies": []}

static func _line(tiles: Array, a: Array, b: Array, elevation: int = 9) -> void:
	var x: int = int(a[0])
	var y: int = int(a[1])
	_paint(tiles, x, y, "floor", elevation)
	while x != int(b[0]) or y != int(b[1]):
		if x != int(b[0]):
			x += signi(int(b[0]) - x)
		else:
			y += signi(int(b[1]) - y)
		_paint(tiles, x, y, "floor", elevation)

static func _area(tiles: Array, x1: int, y1: int, x2: int, y2: int, elevation: int = 9) -> void:
	for y: int in range(y1, y2 + 1):
		for x: int in range(x1, x2 + 1):
			_paint(tiles, x, y, "floor", elevation)

static func _landing(world: Dictionary, lamp_repaired: bool) -> void:
	_area(world.tiles, 10, 21, 14, 23)
	_paint(world.tiles, 12, 23, "exit")
	world.sight = 6 if lamp_repaired else 5
	world.containers.append(_crate("harbor-supply", [11, 21], ["scrap", "medicine"]))

static func _market(seed_value: int, lamp_repaired: bool) -> Dictionary:
	var world: Dictionary = _base(seed_value, "中庭市場", "floor", 2)
	var t: Array = world.tiles
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	# Store fronts form an enclosed courtyard. The outer alleys flank it;
	# two low courtyard gates are shorter but expose the player to charges.
	_room(t, 6, 7, 18, 17, [[6, 12], [18, 12], [12, 17], [12, 7]])
	_room(t, 8, 2, 16, 5, [[12, 5], [8, 4], [16, 4]])
	_room(t, 1, 8, 3, 15, [[3, 11], [2, 15]])
	_room(t, 21, 8, 23, 16, [[21, 12], [22, 16]])
	for x: int in range(1, 24):
		_paint(t, x, 20, "water", 0)
	_line(t, [12, 23], [12, 18])
	_line(t, [4, 18], [20, 18])
	_line(t, [4, 18], [4, 6])
	_line(t, [20, 18], [20, 6])
	_line(t, [4, 6], [20, 6])
	_line(t, [12, 6], [12, 4])
	# Seed chooses which side door stays elevated; both keep a dry return.
	var side: int = 6 if _random(rng, 2) == 0 else 18
	_line(t, [side, 12], [4 if side == 6 else 20, 12])
	_paint(t, side, 12, "gate")
	_line(t, [12, 18], [12, 8], 1)
	_paint(t, 12, 17, "gate", 1)
	_paint(t, 12, 7, "gate", 1)
	_paint(t, 12, 18, "floor")
	world.goal = {"x": 12, "y": 4}
	world.containers = [
		_crate("market-gears", [12, 4], ["pumpGear", "pumpGear", "scrap", "scrap"]),
		_crate("courtyard-stall", [[9, 11], [15, 13], [11, 15]][_random(rng, 3)], ["pearl", "flare", "scrap"]),
		_crate("west-storeroom", [2, 12], ["bomb", "pearl"]),
		_crate("east-clinic", [22, 14], ["medicine", "medicine"])]
	world.enemies = [_enemy("market-charge", "wader", [12, 11], 7), _enemy("market-guard", "diver", [13, 4], 11), _enemy("market-west", "crab", [2, 10], 5), _enemy("market-east", "crab", [22, 12], 5), _enemy("market-alley", "wader", [20, 8 + _random(rng, 2)], 7)]
	_landing(world, lamp_repaired)
	return world

static func _canal(seed_value: int, lamp_repaired: bool) -> Dictionary:
	var world: Dictionary = _base(seed_value, "群島運河", "water", 0)
	var t: Array = world.tiles
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	# Four irregular islands joined by narrow, dry bridges. Low causeways
	# cut across the zigzag at the cost of tide damage after turn32.
	_area(t, 3, 17, 8, 21, 2)
	_area(t, 3, 10, 8, 14, 2)
	_area(t, 15, 10, 21, 14, 2)
	_area(t, 16, 2, 22, 6, 3)
	_area(t, 9, 6, 12, 9, 1)
	_line(t, [12, 23], [12, 20])
	_line(t, [12, 20], [6, 20])
	_line(t, [6, 20], [6, 12])
	_line(t, [6, 12], [18, 12])
	_line(t, [18, 12], [18, 4])
	_line(t, [18, 4], [19, 4])
	_line(t, [12, 20], [18, 20], 1)
	_line(t, [18, 20], [18, 12], 1)
	_line(t, [6, 12], [6, 8], 1)
	_line(t, [6, 8], [18, 8], 1)
	# Shared intersections belong to the bridge, never the low shortcut.
	_line(t, [12, 23], [12, 20])
	_line(t, [12, 20], [6, 20])
	_line(t, [6, 20], [6, 12])
	_line(t, [6, 12], [18, 12])
	_line(t, [18, 12], [18, 4])
	# Rubble makes the island approaches readable without closing bridges.
	for cell: Array in [[4, 18], [8, 13], [16, 10], [21, 5], [11, 6]]:
		_paint(t, cell[0], cell[1], "wall")
	world.goal = {"x": 19, "y": 4}
	world.containers = [_crate("canal-chart", [19, 4], ["chart", "pearl"]), _crate("west-island", [4, 11 + _random(rng, 2)], ["medicine", "flare"]), _crate("east-island", [20, 13], ["pearl", "bomb", "scrap"]), _crate("survey-islet", [10, 7 + _random(rng, 2)], ["pearl", "harpoon"])]
	world.enemies = [_enemy("canal-guard", "diver", [20, 4], 11), _enemy("canal-bridge", "wader", [16, 12], 7), _enemy("canal-west", "crab", [4, 13], 5), _enemy("canal-islet", "crab", [10, 9], 5), _enemy("canal-east", "wader", [20, 11 + _random(rng, 2)], 7)]
	_landing(world, lamp_repaired)
	return world

static func _observatory(seed_value: int, lamp_repaired: bool) -> Dictionary:
	var world: Dictionary = _base(seed_value, "岬の観測所", "wall")
	var t: Array = world.tiles
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	# A raised ring surrounds a flooded inner terrace. Either arm reaches
	# the north cache; inner stairs trade a shorter route for close combat.
	_area(t, 4, 5, 6, 20)
	_area(t, 18, 5, 20, 20)
	_area(t, 4, 5, 20, 7)
	_area(t, 4, 18, 20, 20)
	_area(t, 8, 9, 16, 16, 1)
	_line(t, [12, 23], [12, 19])
	_line(t, [5, 12], [19, 12], 1)
	_line(t, [12, 12], [12, 6], 1)
	_area(t, 10, 2, 14, 5)
	_line(t, [12, 6], [12, 3])
	_line(t, [5, 5], [5, 20])
	_line(t, [19, 5], [19, 20])
	# Seed leaves one inner stair dry. The outer ring is always safe from tide.
	_line(t, [5 if _random(rng, 2) == 0 else 19, 12], [12, 12])
	world.goal = {"x": 12, "y": 3}
	world.containers = [_crate("observatory-lens", [12, 3], ["sunLens", "pearl"]), _crate("west-gallery", [5, 9 + _random(rng, 2)], ["medicine", "bomb"]), _crate("east-gallery", [19, 15 + _random(rng, 2)], ["pearl", "flare"]), _crate("inner-archive", [10, 14], ["pumpGear", "scrap", "pearl"])]
	world.enemies = [_enemy("observatory-guard", "diver", [12, 4], 11), _enemy("observatory-west", "wader", [5, 8], 7), _enemy("observatory-east", "wader", [19, 9], 7), _enemy("observatory-terrace", "crab", [10, 12], 5), _enemy("observatory-archive", "crab", [13, 14], 5)]
	_landing(world, lamp_repaired)
	return world

# v0.4 keeps the shipped generator above unchanged for migrated expeditions.
# Compact maps are authored encounter graphs; seeds vary surface and optional
# guard placement, never the guaranteed dry delivery route.
static func create_encounter_world(seed_value: int, lamp_repaired: bool = false, district: String = "quay") -> Dictionary:
	var rng: Dictionary = {"value": seed_value & 0xffffffff}
	var tiles: Array = []
	var wet: bool = district == "canal"
	for y: int in range(19):
		var row: Array = []
		for x: int in range(17):
			row.append({"type": "water" if wet and x > 0 and x < 16 and y > 0 and y < 18 else "wall", "elevation": 0 if wet else 9, "zone": "船着き場" if y >= 15 else "帰路の分岐" if y >= 12 else "回収区画" if y >= 6 else "奥の保管庫", "variant": _random(rng, 4)})
		tiles.append(row)
	var goal: Array = [8, 9]
	var first_guard: Array = [4, 13]
	var charge_guard: Array = [10, 9]
	var optional_guard: Array = [12, 3]
	var optional_crab: Array = [9, 3]
	var salvage: Array = [12, 2]
	var supplies: Array = [4, 11]
	match district:
		"market":
			_area(tiles, 3, 6, 13, 11, 1)
			_area(tiles, 3, 13, 13, 15)
			_area(tiles, 2, 2, 5, 4)
			_area(tiles, 11, 2, 14, 4)
			_line(tiles, [3, 14], [3, 3])
			_line(tiles, [13, 14], [13, 3])
			_line(tiles, [3, 8], [13, 8])
			_line(tiles, [3, 5], [13, 5])
			_line(tiles, [8, 5], [8, 3])
			_area(tiles, 6, 2, 10, 4)
			goal = [8, 8]
			first_guard = [3, 13]
			charge_guard = [10, 8]
			optional_guard = [8, 3]
			optional_crab = [12, 3]
			salvage = [8, 2]
			supplies = [3, 10]
		"canal":
			_area(tiles, 2, 11, 6, 14, 2)
			_area(tiles, 9, 6, 14, 10, 1)
			_area(tiles, 3, 1, 7, 4, 3)
			_line(tiles, [8, 16], [4, 16])
			_line(tiles, [4, 16], [4, 12])
			_line(tiles, [4, 13], [11, 13])
			_line(tiles, [11, 13], [11, 3])
			_line(tiles, [11, 3], [5, 3])
			_line(tiles, [8, 15], [8, 9], 1)
			_line(tiles, [8, 9], [11, 9])
			# The low central pier has a bombable raised obstruction.
			_paint(tiles, 8, 12, "wall")
			goal = [11, 8]
			first_guard = [4, 13]
			charge_guard = [12, 8]
			optional_guard = [5, 3]
			optional_crab = [4, 2]
			salvage = [5, 2]
			supplies = [4, 11]
		"observatory":
			_area(tiles, 3, 13, 13, 15)
			_area(tiles, 6, 7, 10, 10, 1)
			_area(tiles, 6, 2, 10, 4)
			_line(tiles, [3, 14], [3, 4])
			_line(tiles, [13, 14], [13, 4])
			_line(tiles, [3, 4], [13, 4])
			_line(tiles, [3, 9], [13, 9])
			_line(tiles, [8, 13], [8, 9])
			_paint(tiles, 8, 12, "wall")
			first_guard = [3, 13]
			charge_guard = [11, 9]
			optional_guard = [8, 3]
			optional_crab = [7, 2]
			salvage = [9, 2]
			supplies = [3, 10]
		_:
			district = "quay"
			_area(tiles, 4, 13, 12, 15)
			_area(tiles, 2, 7, 12, 11)
			_area(tiles, 7, 2, 14, 5)
			_line(tiles, [4, 14], [4, 9])
			_line(tiles, [12, 9], [12, 3])
			_line(tiles, [8, 13], [8, 9])
			_paint(tiles, 8, 12, "wall")
	# A common visible breach connects the landing route to the middle area.
	# The intact elevated flank remains viable without buying a bomb.
	_area(tiles, 6, 15, 10, 17)
	_line(tiles, [8, 17], [8, 13])
	_paint(tiles, 8, 17, "exit")
	var cargo: Dictionary = {"quay": ["core", "scrap"], "market": ["pumpGear", "pumpGear", "scrap", "scrap"], "canal": ["chart", "pearl"], "observatory": ["sunLens", "pearl"]}
	var extra: Array = ["pearl", "pearl", "harpoon", "bomb"]
	if district == "observatory":
		extra = ["pearl", "pumpGear", "harpoon", "bomb"]
	var world: Dictionary = {"width": 17, "height": 19, "tiles": tiles, "district": district, "exit": {"x": 8, "y": 17}, "goal": {"x": goal[0], "y": goal[1]}, "sight": 6 if lamp_repaired else 5,
		"encounters": [{"id": "approach", "name": "帰路の分岐", "x": 2, "y": 12, "w": 13, "h": 4}, {"id": "delivery", "name": "回収区画", "x": 2, "y": 6, "w": 13, "h": 6}, {"id": "salvage", "name": "奥の保管庫", "x": 2, "y": 1, "w": 13, "h": 5}],
		"containers": [_crate("delivery-" + district, goal, cargo[district]), _crate("field-supplies", supplies, ["medicine", "flare", "scrap"]), _crate("deep-salvage", salvage, extra)],
		"enemies": [_enemy("approach-guard", "crab", first_guard, 5), _enemy("delivery-charge", "wader", charge_guard, 7), _enemy("salvage-guard", "diver", optional_guard, 11), _enemy("salvage-crab", "crab", optional_crab, 5)], "landmarks": []}
	# Vary an optional guard's facing without moving it into a guaranteed route.
	world.enemies[3].facing = {"x": -1 if _random(rng, 2) == 0 else 1, "y": 0}
	var kinds: Array = ["lighthouse", "market", "clinic", "pump"]
	var landmark_kind: String = str(kinds[["quay", "market", "canal", "observatory"].find(district)])
	world.landmarks.append({"kind": "boat" if wet else "clinic", "x": 5, "y": 17})
	world.landmarks.append({"kind": "palms" if wet else "arch", "x": 11, "y": 17})
	var primary_placed: bool = false
	for candidate: Array in [[8, 1], [15, 5], [1, 10], [15, 15]]:
		if tiles[candidate[1]][candidate[0]].type in ["wall", "water"]:
			world.landmarks.append({"kind": "arch" if primary_placed else landmark_kind, "x": candidate[0], "y": candidate[1]})
			primary_placed = true
	return world
