extends RefCounted

# The complete result is persisted by Rules. The private LCG also makes fixtures
# independent of engine RNG updates; generation never consumes global randomness.
const WIDTH: int = 25
const HEIGHT: int = 29
const LEGACY = preload("res://scripts/world_data.gd")
const DISTRICTS: Array = ["quay", "market", "canal", "observatory"]
const ZONES: Dictionary = {
	"quay": ["荷揚げ路地", "網干し小屋", "錨の広場", "旧診療所", "修繕工房", "灯守の住居", "集光庫", "波止場の倉庫"],
	"market": ["青物の中庭", "陶器商の庭", "布売り通り", "香辛料の庭", "道具市", "薬草の庭", "揚水機室", "市場の荷捌き場"],
	"canal": ["葦の島", "石橋の島", "舟大工の島", "水門の島", "測量の島", "貝殻の島", "航路図の島", "渡し守の島"],
	"observatory": ["西の回廊", "東の回廊", "星図の環", "風向計の環", "記録の環", "鏡の回廊", "集光の環", "岬の踊り場"]}

static func _roll(rng: Dictionary, count: int) -> int:
	rng.value = (int(rng.value) * 1664525 + 1013904223) & 0xffffffff
	# Upper bits avoid the alternating low-bit patterns of an LCG.
	return (int(rng.value) >> 8) % maxi(1, count)

static func _shuffle(values: Array, rng: Dictionary) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = _roll(rng, i + 1)
		var temporary: Variant = values[i]
		values[i] = values[j]
		values[j] = temporary

static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _position(cell: Vector2i) -> Dictionary:
	return {"x": cell.x, "y": cell.y}

static func _cell(position: Dictionary) -> Vector2i:
	return Vector2i(int(position.x), int(position.y))

static func _paint(tiles: Array, cell: Vector2i, kind: String = "floor", elevation: int = 9, zone: String = "") -> void:
	if cell.x < 1 or cell.y < 1 or cell.x >= WIDTH - 1 or cell.y >= HEIGHT - 1:
		return
	var tile: Dictionary = tiles[cell.y][cell.x]
	tile.type = kind
	tile.elevation = elevation
	if not zone.is_empty():
		tile.zone = zone

static func _path(a: Vector2i, b: Vector2i, horizontal_first: bool) -> Array:
	var cells: Array = [a]
	var cell: Vector2i = a
	while cell != b:
		if (horizontal_first and cell.x != b.x) or cell.y == b.y:
			cell.x += signi(b.x - cell.x)
		else:
			cell.y += signi(b.y - cell.y)
		cells.append(cell)
	return cells

static func _corridor(tiles: Array, path: Array, wide: bool, zone: String) -> void:
	for cell: Vector2i in path:
		_paint(tiles, cell, "floor", 9, zone)
		if wide:
			_paint(tiles, cell + Vector2i.RIGHT, "floor", 9, zone)

static func _room(tiles: Array, room: Dictionary, district: String) -> void:
	var rect: Rect2i = room.rect
	var center: Vector2i = room.center
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if district == "canal" and absi(x - center.x) + absi(y - center.y) > int(rect.size.x / 2) + 1:
				continue
			var elevation: int = 9
			if district == "observatory" and absi(x - center.x) == 1 and absi(y - center.y) == 1:
				elevation = 1
			_paint(tiles, cell, "floor", elevation, room.name)
	# Courtyards and workshop partitions make local flanking choices. All four
	# center spokes and the complete perimeter remain elevated and open.
	if district in ["market", "quay"]:
		_paint(tiles, center + Vector2i(-1, -1), "water" if district == "market" else "wall", 0 if district == "market" else 9, room.name)
		if rect.size.x >= 7:
			_paint(tiles, center + Vector2i(1, 1), "water" if district == "market" else "wall", 0 if district == "market" else 9, room.name)

static func _root(parents: Array, index: int) -> int:
	while int(parents[index]) != index:
		index = int(parents[index])
	return index

static func _distances(graph: Array, start: int) -> Array:
	var distances: Array = []
	distances.resize(graph.size())
	distances.fill(-1)
	distances[start] = 0
	var queue: Array = [start]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for neighbor: int in graph[current]:
			if int(distances[neighbor]) < 0:
				distances[neighbor] = int(distances[current]) + 1
				queue.append(neighbor)
	return distances

static func _reachable(world: Dictionary) -> Dictionary:
	var start: Vector2i = _cell(world.exit)
	var seen: Dictionary = {_key(start): true}
	var queue: Array = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.y < 0 or next.x >= WIDTH or next.y >= HEIGHT or seen.has(_key(next)):
				continue
			var tile: Dictionary = world.tiles[next.y][next.x]
			if tile.type in ["wall", "water"] or int(tile.elevation) <= 3:
				continue
			seen[_key(next)] = true
			queue.append(next)
	return seen

static func _room_cell(room: Dictionary, tiles: Array, occupied: Dictionary, rng: Dictionary) -> Vector2i:
	var choices: Array = []
	var rect: Rect2i = room.rect
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if tiles[y][x].type == "floor" and int(tiles[y][x].elevation) > 3 and not occupied.has(_key(cell)):
				choices.append(cell)
	if choices.is_empty():
		return room.center
	return choices[_roll(rng, choices.size())]

static func _loot(rng: Dictionary, depth: int, room_index: int, district: String) -> Array:
	var common: Array = ["scrap", "medicine", "flare", "bomb", "pearl", "coat"]
	var cargo: Array = []
	for i: int in range(2 + depth):
		cargo.append(common[_roll(rng, common.size())])
	if room_index == 0:
		cargo[0] = "harpoon"
	if depth >= 2:
		cargo.append("pearl")
		cargo.append("harpoon" if room_index % 2 == 0 else "pumpGear")
	if depth == 3:
		cargo.append("pearl")
		cargo.append("sunLens" if room_index % 3 == 0 else "chart")
	if depth >= 2 and room_index == 1:
		var components: Array = ["core", "pumpGear", "chart", "sunLens"]
		cargo.append(components[(DISTRICTS.find(district) + depth) % components.size()])
	return cargo

static func _populate(world: Dictionary, rooms: Array, entry_index: int, stairs_index: int, goal_index: int, lanes: Array, rng: Dictionary) -> void:
	var occupied: Dictionary = {_key(_cell(world.exit)): true, _key(_cell(world.stairs)): true}
	var cargo: Dictionary = {"quay": ["core", "scrap"], "market": ["pumpGear", "pumpGear", "scrap", "scrap"], "canal": ["chart", "pearl"], "observatory": ["sunLens", "pumpGear"]}
	# Saleable caches belong beyond the protected landing. A free loan and a
	# nearby saleable supply crate would otherwise form a no-stake money loop.
	var protected: Dictionary = {}
	for y: int in range(1, HEIGHT - 1):
		for x: int in range(1, WIDTH - 1):
			if absi(x - int(world.exit.x)) + absi(y - int(world.exit.y)) < 8 or maxi(absi(x - int(world.exit.x)), absi(y - int(world.exit.y))) <= 4:
				protected[_key(Vector2i(x, y))] = true
	for i: int in range(rooms.size()):
		var forbidden: Dictionary = occupied.duplicate()
		forbidden.merge(protected)
		var cell: Vector2i = _room_cell(rooms[i], world.tiles, forbidden, rng)
		if forbidden.has(_key(cell)):
			cell = _room_cell(rooms[stairs_index], world.tiles, forbidden, rng)
		var kinds: Array = _loot(rng, int(world.depth), i, world.district)
		var id: String = "cache-%d" % i
		if i == entry_index:
			kinds = ["medicine", "bomb", "flare"]
			for j: int in range(int(world.depth) - 1):
				kinds.append("pearl")
			id = "field-supplies"
		if i == goal_index:
			kinds = cargo[world.district].duplicate() if int(world.depth) == 1 else kinds
			world.goal = _position(cell)
			id = "delivery-" + world.district if int(world.depth) == 1 else "deep-salvage"
		occupied[_key(cell)] = true
		world.containers.append(LEGACY._crate(id, [cell.x, cell.y], kinds))
	var candidates: Array = []
	var lane_cells: Dictionary = {}
	for cell: Vector2i in lanes:
		lane_cells[_key(cell)] = true
	for y: int in range(1, HEIGHT - 1):
		for x: int in range(1, WIDTH - 1):
			var cell: Vector2i = Vector2i(x, y)
			if occupied.has(_key(cell)) or maxi(absi(cell.x - int(world.exit.x)), absi(cell.y - int(world.exit.y))) <= 4 or absi(cell.x - int(world.exit.x)) + absi(cell.y - int(world.exit.y)) <= 4:
				continue
			if world.tiles[y][x].type == "floor" and int(world.tiles[y][x].elevation) > 3:
				candidates.append(cell)
	_shuffle(candidates, rng)
	var kinds: Array = ["crab", "wader", "crab", "diver", "wader", "crab"]
	if int(world.depth) >= 2:
		kinds.append_array(["diver", "wader"])
	if int(world.depth) == 3:
		kinds.append_array(["diver", "wader"])
	for i: int in range(kinds.size()):
		var kind: String = kinds[i]
		var chosen: int = -1
		# Prefer straight bridge/alley lanes for charging enemies, and a room
		# approach for slow guards. Neither blocks the only required dry route.
		for j: int in range(candidates.size()):
			var cell: Vector2i = candidates[j]
			if occupied.has(_key(cell)):
				continue
			var near_stairs: int = absi(cell.x - int(world.stairs.x)) + absi(cell.y - int(world.stairs.y))
			if (kind == "wader" and lane_cells.has(_key(cell))) or (kind == "diver" and near_stairs in range(2, 6)) or kind == "crab":
				chosen = j
				break
		if chosen < 0:
			for j: int in range(candidates.size()):
				if not occupied.has(_key(candidates[j])):
					chosen = j
					break
		if chosen < 0:
			break
		var cell: Vector2i = candidates[chosen]
		occupied[_key(cell)] = true
		var hp: int = 5 if kind == "crab" else 7 if kind == "wader" else 11
		var enemy: Dictionary = LEGACY._enemy("guard-%d" % i, kind, [cell.x, cell.y], hp)
		var direction: Vector2i = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][_roll(rng, 4)]
		enemy.facing = _position(direction)
		world.enemies.append(enemy)
	# Props are anchored to the actual collision grid, adjacent to room floors.
	var landmark_kinds: Dictionary = {"quay": "lighthouse", "market": "market", "canal": "pump", "observatory": "arch"}
	for i: int in range(rooms.size()):
		var rect: Rect2i = rooms[i].rect
		var anchors: Array = [Vector2i(rect.position.x - 1, rooms[i].center.y), Vector2i(rect.end.x, rooms[i].center.y), Vector2i(rooms[i].center.x, rect.position.y - 1)]
		for cell: Vector2i in anchors:
			if cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT and world.tiles[cell.y][cell.x].type in ["wall", "water"]:
				world.landmarks.append({"kind": landmark_kinds[world.district] if i == stairs_index else "boat" if world.district == "canal" else "arch", "x": cell.x, "y": cell.y})
				break

static func _ensure_shortcut(tiles: Array, rng: Dictionary) -> void:
	# A selected L bend can already cover the nominal tenth graph edge. Search
	# the finite grid for another missing straight connection in that case.
	var has_low: bool = false
	var has_breach: bool = false
	for row: Array in tiles:
		for tile: Dictionary in row:
			has_low = has_low or (tile.type == "floor" and int(tile.elevation) <= 3)
			has_breach = has_breach or tile.zone == "崩れた近道"
	if has_low and has_breach:
		return
	var choices: Array = []
	for y: int in range(1, HEIGHT - 1):
		for x: int in range(1, WIDTH - 1):
			if tiles[y][x].type != "floor" or int(tiles[y][x].elevation) <= 3:
				continue
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var gap: Array = []
				for distance: int in range(1, 13):
					var cell: Vector2i = Vector2i(x, y) + direction * distance
					if cell.x >= WIDTH - 1 or cell.y >= HEIGHT - 1:
						break
					var tile: Dictionary = tiles[cell.y][cell.x]
					if tile.type in ["wall", "water"]:
						gap.append(cell)
					else:
						if int(tile.elevation) > 3 and gap.size() >= 3:
							choices.append(gap)
						break
	if not choices.is_empty():
		var gap: Array = choices[_roll(rng, choices.size())]
		for cell: Vector2i in gap:
			_paint(tiles, cell, "floor", 1, "冠水する近道")
		_paint(tiles, gap[gap.size() / 2], "wall", 9, "崩れた近道")

static func create_world(seed_value: int, lamp_repaired: bool = false, district: String = "quay", depth: int = 1) -> Dictionary:
	district = district if district in DISTRICTS else "quay"
	depth = clampi(depth, 1, 3)
	var rng: Dictionary = {"value": (seed_value + depth * 104729 + DISTRICTS.find(district) * 15485863) & 0xffffffff}
	var tiles: Array = []
	for y: int in range(HEIGHT):
		var row: Array = []
		for x: int in range(WIDTH):
			row.append({"type": "water" if district == "canal" and x > 0 and x < WIDTH - 1 and y > 0 and y < HEIGHT - 1 else "wall", "elevation": 0 if district == "canal" else 9, "zone": "水路" if district == "canal" else "外壁", "variant": _roll(rng, 4)})
		tiles.append(row)
	var rooms: Array = []
	var names: Array = ZONES[district].duplicate()
	_shuffle(names, rng)
	for i: int in range(8):
		var center: Vector2i = Vector2i(6 + (i % 2) * 12 + _roll(rng, 5) - 2, [4, 11, 18, 25][i / 2] + _roll(rng, 3) - 1)
		center.y = clampi(center.y, 3, 25)
		var width: int = 5 + _roll(rng, 2) * 2
		var rect: Rect2i = Rect2i(center - Vector2i(width / 2, 2), Vector2i(width, 5))
		var room: Dictionary = {"center": center, "rect": rect, "name": names[i]}
		rooms.append(room)
		_room(tiles, room, district)
	var edges: Array = []
	for i: int in range(8):
		if i % 2 == 0:
			edges.append([i, i + 1])
		if i < 6:
			edges.append([i, i + 2])
	_shuffle(edges, rng)
	var parents: Array = [0, 1, 2, 3, 4, 5, 6, 7]
	var graph: Array = [[], [], [], [], [], [], [], []]
	var selected: Array = []
	var optional: Array = []
	for edge: Array in edges:
		var a: int = _root(parents, edge[0])
		var b: int = _root(parents, edge[1])
		if a != b:
			parents[a] = b
			selected.append(edge)
		else:
			optional.append(edge)
	# One or two extra graph edges vary the room-level loops and branch choices.
	for i: int in range(1 + _roll(rng, 2)):
		selected.append(optional.pop_back())
	var lanes: Array = []
	for edge: Array in selected:
		graph[edge[0]].append(edge[1])
		graph[edge[1]].append(edge[0])
		var path: Array = _path(rooms[edge[0]].center, rooms[edge[1]].center, _roll(rng, 2) == 0)
		_corridor(tiles, path, district != "canal", rooms[edge[0]].name)
		lanes.append_array(path)
	# The unchosen connection is a shorter, tide-sensitive route. One breakable
	# wall interrupts it without touching the elevated spanning graph.
	for edge: Array in optional:
		var path: Array = _path(rooms[edge[0]].center, rooms[edge[1]].center, _roll(rng, 2) == 0)
		var breach_candidates: Array = []
		for cell: Vector2i in path:
			if tiles[cell.y][cell.x].type in ["wall", "water"]:
				_paint(tiles, cell, "floor", 1, "冠水する近道")
				breach_candidates.append(cell)
		if not breach_candidates.is_empty():
			_paint(tiles, breach_candidates[breach_candidates.size() / 2], "wall", 9, "崩れた近道")
	_ensure_shortcut(tiles, rng)
	var entry_index: int = 6 + _roll(rng, 2)
	var distances: Array = _distances(graph, entry_index)
	var farthest: Array = []
	var maximum: int = -1
	for i: int in range(8):
		if int(distances[i]) > maximum:
			maximum = int(distances[i])
			farthest = [i]
		elif int(distances[i]) == maximum:
			farthest.append(i)
	var stairs_index: int = farthest[_roll(rng, farthest.size())]
	var goals: Array = []
	for i: int in range(8):
		if i != stairs_index and int(distances[i]) >= maxi(1, maximum - 1):
			goals.append(i)
	var goal_index: int = goals[_roll(rng, goals.size())]
	var exit_cell: Vector2i = rooms[entry_index].center
	var stairs_cell: Vector2i = rooms[stairs_index].center
	_paint(tiles, exit_cell, "exit", 9, "帰還地点")
	var world: Dictionary = {"width": WIDTH, "height": HEIGHT, "tiles": tiles, "district": district, "exit": _position(exit_cell), "goal": _position(rooms[goal_index].center), "sight": 6 if lamp_repaired else 5, "encounters": [], "landmarks": [], "containers": [], "enemies": [], "depth": depth, "stairs": _position(stairs_cell), "layoutName": "%s-%08x-%d" % [district, seed_value & 0xffffffff, depth]}
	# Constructive connectivity needs no retry loop. This bounded repair is the
	# fallback if a future room module accidentally cuts its own center off.
	var reachable: Dictionary = _reachable(world)
	for room: Dictionary in rooms:
		if not reachable.has(_key(room.center)):
			_corridor(tiles, _path(exit_cell, room.center, true), true, room.name)
	_paint(tiles, exit_cell, "exit", 9, "帰還地点")
	for i: int in range(rooms.size()):
		var rect: Rect2i = rooms[i].rect
		world.encounters.append({"id": "room-%d" % i, "name": rooms[i].name, "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y})
	_populate(world, rooms, entry_index, stairs_index, goal_index, lanes, rng)
	return world
