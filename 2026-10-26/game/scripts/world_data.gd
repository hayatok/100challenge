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

static func create_world(seed_value: int, lamp_repaired: bool = false) -> Dictionary:
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
