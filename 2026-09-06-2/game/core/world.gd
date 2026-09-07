extends RefCounted
const Ecology = preload("res://core/ecology.gd")
const DNA = preload("res://core/genome.gd")
const STEP = 0.2
const BOUNDS = Vector2(1100, 760)
const HISTORY_LIMIT = 20000
var rng = RandomNumberGenerator.new()
var seed_value: int = 20260906
var creatures: Array = []
var plants: Array = []
var history: Dictionary = {}
var events: Array = []
var time: float = 0.0
var rain: float = 0.0
var rain_cooldown: float = 0.0
var next_id: int = 1
var births: int = 0
var deaths: int = 0
var tick: int = 0
var capacity: int = 120
var history_full: bool = false
var spatial: Dictionary = {}
var food_visitors: Dictionary = {}
var phenotypes: Dictionary = {}
var migrated: bool = false
var census: Array = []
var notes: Array = []
var ancestor_masks: Dictionary = {}

func _init(value: int = 20260906, count: int = 32) -> void:
	seed_value = value
	rng.seed = value
	for i in 96:
		var p: Vector2 = Vector2(rng.randf_range(40, 1060), rng.randf_range(40, 720))
		plants.append({"x": p.x, "y": p.y, "food": rng.randf_range(12, 24)})
	for i in count:
		var family: int = i % 4
		var g: Dictionary = DNA.founder(rng, family)
		var c: Dictionary = spawn(g, [], family, 0, Vector2(rng.randf_range(100, 1000), rng.randf_range(100, 660)))
		c.age = rng.randf_range(14, 50)
		c.energy = rng.randf_range(70, 94)
		c.cooldown = rng.randf_range(0, 8)
	log_event("観察開始。%d匹の暮らしを見守ります。" % count, 1)
	census.append(survey())

func spawn(g: Dictionary, parents: Array, family: int, generation: int, p: Vector2) -> Dictionary:
	g = DNA.upgrade(g)
	var c: Dictionary = {"id": next_id, "genes": g, "parents": parents, "family": family, "generation": generation,
		"x": clampf(p.x, 25, BOUNDS.x - 25), "y": clampf(p.y, 25, BOUNDS.y - 25), "angle": rng.randf_range(-PI, PI),
		"age": 0.0, "energy": 43.0, "cooldown": 20.0, "target": -1, "state": "卵", "pulse": 0.0, "born": time}
	history[str(next_id)] = {"id": next_id, "genes": g.duplicate(true), "parents": parents.duplicate(), "family": family,
		"generation": generation, "born": time, "died": -1.0, "name": DNA.nickname(g) + " #%03d" % next_id}
	next_id += 1
	creatures.append(c)
	phenotypes[c.id] = DNA.traits(g)
	var inherited: int = 0
	for parent in parents: inherited |= int(ancestor_masks[parent])
	var expressed: int = Ecology.mask(g)
	ancestor_masks[c.id] = inherited | expressed
	if not parents.is_empty():
		for organ in 4:
			if (expressed & (1 << organ)) != 0 and (inherited & (1 << organ)) == 0:
				add_note({"kind": "novel", "time": time, "id": c.id, "area": habitat(p), "organ": organ})
	return c

func log_event(message: String, id: int = -1) -> void:
	events.push_front({"text": message, "id": id, "time": time})
	if events.size() > 60: events.pop_back()

static func habitat(p: Vector2) -> int:
	if ((p - Vector2(820, 360)) / Vector2(245, 280)).length_squared() < 1: return 2
	if ((p - Vector2(315, 465)) / Vector2(230, 225)).length_squared() < 1: return 1
	return 0

static func mobility(p: Dictionary, area: int) -> float:
	var organs: Array = p.organ_counts
	if area == 2: return maxf(0.2, 0.26 + p.swim * 0.92 + p.reach * 0.16 + organs[1] * 0.06 + organs[2] * 0.02 - organs[3] * 0.015)
	if area == 1: return 1.0 - p.size * 0.30 - p.spines * 0.14 + organs[2] * 0.035
	return 1.0 - p.swim * 0.12 + organs[0] * 0.015 + organs[3] * 0.025

static func upkeep(p: Dictionary, area: int) -> float:
	return 0.16 + p.size * 0.12 + p.reach * 0.05 + p.shell * 0.04 + p.spines * 0.04 + maxi(0, p.blueprint.organs.size() - 2) * 0.001 + maxi(0, p.parts - 2) * 0.001 + Ecology.cost(p, area) + (0.10 * (1.0 - p.swim) if area == 2 else 0.0)

func season_name() -> String:
	return ["芽吹き", "陽ざし", "実り", "冬ごもり"][int(time / 120) % 4]

func pour_rain() -> bool:
	if rain_cooldown > 0: return false
	rain = 14
	rain_cooldown = 35
	log_event("雨が降り、餌の芽吹きが早まりました。")
	return true

func living(id: int) -> Dictionary:
	for c in creatures:
		if c.id == id: return c
	return {}

func descendants(id: int) -> Array:
	# Chronological IDs ensure parents are visited before children.
	var related: Dictionary = {id: true}
	var found: Array = []
	for entry in history.values():
		for parent in entry.parents:
			if related.has(int(parent)):
				related[int(entry.id)] = true
				found.append(entry.id)
				break
	return found

func rebuild_grid() -> void:
	spatial.clear()
	for c in creatures:
		var cell: Vector2i = Vector2i(floori(c.x / 100), floori(c.y / 100))
		if not spatial.has(cell): spatial[cell] = []
		spatial[cell].append(c)

func neighbors(c: Dictionary) -> Array:
	var result: Array = []
	var cell: Vector2i = Vector2i(floori(c.x / 100), floori(c.y / 100))
	for y in range(-2, 3):
		for x in range(-2, 3): result.append_array(spatial.get(cell + Vector2i(x, y), []))
	return result

func breed(a: Dictionary, b: Dictionary) -> bool:
	if a.id == b.id or creatures.size() >= capacity or history.size() >= HISTORY_LIMIT: return false
	if a.age < 18 or b.age < 18 or a.energy < 64 or b.energy < 64 or a.cooldown > 0 or b.cooldown > 0: return false
	var result: Dictionary = DNA.cross(a.genes, b.genes, rng)
	var pos: Vector2 = (Vector2(a.x, a.y) + Vector2(b.x, b.y)) * 0.5 + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	var child: Dictionary = spawn(result.genes, [a.id, b.id], a.family if rng.randf() < 0.5 else b.family, maxi(a.generation, b.generation) + 1, pos)
	a.energy -= 22
	b.energy -= 22
	a.cooldown = 18
	b.cooldown = 18
	a.pulse = 3
	b.pulse = 3
	births += 1
	log_event("#%03d と #%03d に卵。%s" % [a.id, b.id, history[str(child.id)].name], child.id)
	if "anatomy" in result.changes: log_event("#%03d の体の設計に変異。親子を比べてみよう。" % child.id, child.id)
	elif not result.changes.is_empty(): log_event("#%03d に大きめの変異。親子を比べてみよう。" % child.id, child.id)
	return true

func step() -> void:
	if history_full: return
	time += STEP
	tick += 1
	rain = maxf(0, rain - STEP)
	rain_cooldown = maxf(0, rain_cooldown - STEP)
	var season: int = int(time / 120) % 4
	for plant in plants:
		var area: int = habitat(Vector2(plant.x, plant.y))
		var rate: float = [0.28, 0.19, 0.30, 0.13][season]
		if area == 2: rate = 0.23
		if rain > 0: rate *= 2.0
		plant.food = minf(26, plant.food + rate * STEP)
	rebuild_grid()
	food_visitors.clear()
	for c in creatures:
		if c.target >= 0: food_visitors[c.target] = int(food_visitors.get(c.target, 0)) + 1
	var dead: Array = []
	for c in creatures.duplicate():
		if not phenotypes.has(c.id): phenotypes[c.id] = DNA.traits(c.genes)
		var p: Dictionary = phenotypes[c.id]
		c.age += STEP
		c.cooldown = maxf(0, c.cooldown - STEP)
		c.pulse = maxf(0, c.pulse - STEP)
		if c.age < 4:
			c.state = "卵"
			continue
		var pos: Vector2 = Vector2(c.x, c.y)
		var area: int = habitat(pos)
		c.energy -= upkeep(p, area) * STEP
		if c.energy <= 0 or c.age > p.life:
			dead.append(c)
			continue
		var ready: bool = c.age >= 18 and c.energy >= 64 and c.cooldown <= 0 and creatures.size() < capacity
		var mate: Dictionary = {}
		if ready:
			var best: float = 120.0 + p.sense * 65.0
			for other in neighbors(c):
				if other.id == c.id or other.age < 18 or other.energy < 64 or other.cooldown > 0: continue
				var d: float = pos.distance_to(Vector2(other.x, other.y))
				if d < best: best = d; mate = other
		var goal: Vector2 = pos
		if not mate.is_empty():
			goal = Vector2(mate.x, mate.y)
			c.state = "求愛"
			if pos.distance_to(goal) < 30 and breed(c, mate): c.state = "産卵"
		else:
			if c.target < 0 or plants[c.target].food < 0.5 or (tick + c.id) % 25 == 0:
				var best_score: float = INF
				for i in plants.size():
					var plant: Dictionary = plants[i]
					if plant.food < 1: continue
					var place: Vector2 = Vector2(plant.x, plant.y)
					var d: float = pos.distance_to(place)
					var crowd: int = int(food_visitors.get(i, 0)) - (1 if c.target == i else 0)
					var efficiency: float = Ecology.efficiency(p, habitat(place))
					var score: float = d / mobility(p, habitat(place)) + (90.0 + crowd * 12.0) / efficiency - plant.food * 0.6 * efficiency
					if score < best_score: best_score = score; c.target = i
			if c.target >= 0:
				var plant: Dictionary = plants[c.target]
				goal = Vector2(plant.x, plant.y)
				c.state = "餌さがし"
				if pos.distance_to(goal) < 15:
					var efficiency: float = Ecology.efficiency(p, habitat(goal))
					var bite: float = minf(plant.food, minf((1.5 + p.mouth * 1.0) * STEP, (100.0 - c.energy) / efficiency))
					plant.food -= bite
					c.energy = minf(100, c.energy + bite * efficiency)
					c.state = "もぐもぐ"
					if c.energy > 95:
						c.target = rng.randi_range(0, plants.size() - 1)
		if c.state != "もぐもぐ":
			var direction: Vector2 = goal - pos
			# Close-neighbor avoidance keeps individuals visible; timid animals give adults space.
			var separation: Vector2 = Vector2.ZERO
			for other in neighbors(c):
				if other.id == c.id: continue
				var offset: Vector2 = pos - Vector2(other.x, other.y)
				if offset.length_squared() > 0.01 and offset.length_squared() < 225:
					separation += offset.normalized() * (15.0 - offset.length())
			if c.state != "求愛": direction += separation * (1.5 - p.social)
			if c.age < 18 and separation.length() > 8: c.state = "よける"
			if direction.length() > 1:
				c.angle = lerp_angle(c.angle, direction.angle(), 0.18)
				pos += direction.normalized() * p.speed * mobility(p, area) * STEP * (0.6 if c.age < 18 else 1.0)
		c.x = clampf(pos.x, 25, BOUNDS.x - 25)
		c.y = clampf(pos.y, 25, BOUNDS.y - 25)
	for c in dead:
		history[str(c.id)].died = time
		creatures.erase(c)
		phenotypes.erase(c.id)
		deaths += 1
		if c.generation > 0: log_event("%s が土へ。系譜に記録しました。" % history[str(c.id)].name, c.id)
	if tick % 150 == 0: take_census()
	if history.size() >= HISTORY_LIMIT:
		history_full = true
		log_event("観察記録が2万匹に達しました。世界を保存して、新しい島へ。")

func add_note(note: Dictionary) -> void:
	notes.append(note)
	if notes.size() > Ecology.NOTE_LIMIT: notes.pop_front()
	log_event(Ecology.sentence(note), note.id)

func survey() -> Dictionary:
	var areas: Array = []
	for area in 3: areas.append({"n": 0, "counts": [0, 0, 0, 0], "generation": 0.0, "example": -1})
	for c in creatures:
		if c.age < 4: continue
		var area: int = habitat(Vector2(c.x, c.y))
		var group: Dictionary = areas[area]
		var expressed: int = Ecology.mask(c.genes)
		group.n += 1
		group.generation += c.generation
		for kind in 4:
			if (expressed & (1 << kind)) != 0: group.counts[kind] += 1
		if group.example == -1 or (expressed & (1 << Ecology.FOCUS[area])) != 0: group.example = c.id
	for group in areas:
		if group.n > 0: group.generation /= group.n
	return {"time": time, "areas": areas}

func comparison(current: Dictionary) -> Dictionary:
	for i in range(census.size() - 1, -1, -1):
		if current.time - census[i].time >= 299.999: return census[i]
	return {}

func take_census() -> void:
	var current: Dictionary = survey()
	var before: Dictionary = comparison(current)
	if not before.is_empty():
		for area in 3:
			var old: Dictionary = before.areas[area]
			var now: Dictionary = current.areas[area]
			if old.n < 5 or now.n < 5: continue
			var recent: bool = false
			for note in notes:
				if note.kind == "trend" and note.area == area and time - note.time < 299.999: recent = true
			if recent: continue
			var best: int = -1
			var change: float = 0.19999
			for kind in 4:
				var delta: float = float(now.counts[kind]) / now.n - float(old.counts[kind]) / old.n
				if delta > change: change = delta; best = kind
			if best < 0: continue
			var example: int = -1
			for c in creatures:
				if c.age >= 4 and habitat(Vector2(c.x, c.y)) == area and (Ecology.mask(c.genes) & (1 << best)) != 0: example = c.id; break
			if example > 0: add_note({"kind": "trend", "time": time, "id": example, "area": area, "organ": best, "before": [old.counts[best], old.n], "after": [now.counts[best], now.n], "from": before.time})
	census.append(current)
	if census.size() > Ecology.SAMPLE_LIMIT: census.pop_front()

func snapshot() -> Dictionary:
	return {"version": 3, "seed": seed_value, "rng": str(rng.state), "time": time, "tick": tick, "rain": rain,
		"rain_cooldown": rain_cooldown, "next_id": next_id, "births": births, "deaths": deaths, "capacity": capacity,
		"creatures": creatures.duplicate(true), "plants": plants.duplicate(true), "history": history.duplicate(true), "events": events.duplicate(true), "census": census.duplicate(true), "notes": notes.duplicate(true)}

static func number(v: Variant, low: float, high: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v >= low and v <= high

static func integer(v: Variant, low: int, high: int) -> bool:
	return number(v, low, high) and float(v) == floorf(float(v))

static func restore(data: Variant):
	if not data is Dictionary or data.get("version") not in [1, 2, 3]: return null
	var legacy: bool = data.version == 1
	for key in ["seed", "time", "tick", "rain", "rain_cooldown", "next_id", "births", "deaths", "capacity"]:
		if not number(data.get(key), 0, 1e12): return null
	if not integer(data.capacity, 1, 200) or not integer(data.next_id, 1, HISTORY_LIMIT + 1): return null
	for key in ["seed", "tick", "births", "deaths"]:
		if not integer(data[key], 0, 1000000000000): return null
	if not data.get("rng") is String or not data.rng.is_valid_int(): return null
	if not data.get("creatures") is Array or data.creatures.size() > data.capacity: return null
	if not data.get("plants") is Array or data.plants.size() != 96: return null
	if not data.get("history") is Dictionary or data.history.size() > HISTORY_LIMIT: return null
	if not data.get("events") is Array or data.events.size() > 60: return null
	if data.next_id != data.history.size() + 1: return null
	for plant in data.plants:
		if not plant is Dictionary: return null
		if not number(plant.get("x"), 0, BOUNDS.x) or not number(plant.get("y"), 0, BOUNDS.y) or not number(plant.get("food"), 0, 26): return null
	for key in data.history:
		var h: Variant = data.history[key]
		if not h is Dictionary or not DNA.valid(h.get("genes"), legacy): return null
		if not integer(h.get("id"), 1, int(data.next_id) - 1) or str(int(h.id)) != key: return null
		if not h.get("name") is String or h.name.length() > 60: return null
		for field in ["family", "generation", "born"]:
			if not number(h.get(field), 0, 1e12): return null
		if not number(h.get("born"), 0, data.time) or not number(h.get("died"), -1, data.time): return null
		if not integer(h.family, 0, 3) or not integer(h.generation, 0, HISTORY_LIMIT): return null
		if h.died >= 0 and h.died < h.born: return null
		if not h.get("parents") is Array or h.parents.size() not in [0, 2]: return null
		for parent in h.parents:
			if not integer(parent, 1, int(h.id) - 1) or not data.history.has(str(int(parent))): return null
	var founders: int = 0
	var dead_count: int = 0
	for h in data.history.values():
		if h.died >= 0: dead_count += 1
		if h.parents.is_empty():
			founders += 1
			if h.generation != 0: return null
		else:
			if h.parents[0] == h.parents[1]: return null
			var first: Dictionary = data.history[str(int(h.parents[0]))]
			var second: Dictionary = data.history[str(int(h.parents[1]))]
			if h.generation != maxi(first.generation, second.generation) + 1 or h.born < maxf(first.born, second.born): return null
	if data.births != data.history.size() - founders or data.deaths != dead_count: return null
	if data.creatures.size() != data.history.size() - dead_count: return null
	var ids: Dictionary = {}
	for c in data.creatures:
		if not c is Dictionary or not DNA.valid(c.get("genes"), legacy): return null
		if not integer(c.get("id"), 1, int(data.next_id) - 1) or ids.has(c.id): return null
		ids[c.id] = true
		if not data.history.has(str(int(c.id))): return null
		var entry: Dictionary = data.history[str(int(c.id))]
		if c.get("parents") != entry.parents or c.genes != entry.genes or entry.died != -1: return null
		if c.get("generation") != entry.generation or c.get("family") != entry.family or c.get("born") != entry.born: return null
		for field in ["age", "energy", "cooldown", "pulse", "born", "generation", "family"]:
			if not number(c.get(field), 0, 1e12): return null
		if not number(c.get("x"), 0, BOUNDS.x) or not number(c.get("y"), 0, BOUNDS.y): return null
		if not number(c.get("angle"), -1e6, 1e6) or not integer(c.get("target"), -1, 95): return null
		if c.get("state") not in ["卵", "求愛", "産卵", "餌さがし", "もぐもぐ", "よける"]: return null
		if c.energy > 100 or c.cooldown > 20 or c.pulse > 3: return null
	for e in data.events:
		if not e is Dictionary or not e.get("text") is String or e.text.length() > 300: return null
		if not number(e.get("time"), 0, data.time) or not number(e.get("id"), -1, data.next_id - 1): return null
	if data.version == 3 and not Ecology.valid_records(data): return null
	var world = load("res://core/world.gd").new(int(data.seed), 0)
	world.creatures = data.creatures.duplicate(true)
	world.migrated = data.version < 3
	world.plants = data.plants.duplicate(true)
	for c in world.creatures:
		c.genes = DNA.upgrade(c.genes)
		world.phenotypes[c.id] = DNA.traits(c.genes)
		for field in ["id", "target", "generation", "family"]: c[field] = int(c[field])
		for i in c.parents.size(): c.parents[i] = int(c.parents[i])
	# Restore dictionary insertion order numerically for descendant traversal.
	world.history = {}
	for id in range(1, int(data.next_id)):
		if not data.history.has(str(id)): return null
		world.history[str(id)] = data.history[str(id)].duplicate(true)
	world.events = data.events.duplicate(true)
	for e in world.events: e.id = int(e.id)
	for h in world.history.values():
		h.genes = DNA.upgrade(h.genes)
		for field in ["id", "generation", "family"]: h[field] = int(h[field])
		for i in h.parents.size(): h.parents[i] = int(h.parents[i])
	world.time = data.time
	world.tick = int(data.tick)
	world.rain = data.rain
	world.rain_cooldown = data.rain_cooldown
	world.next_id = int(data.next_id)
	world.births = int(data.births)
	world.deaths = int(data.deaths)
	world.capacity = int(data.capacity)
	world.rng.state = data.rng.to_int()
	world.history_full = world.history.size() >= HISTORY_LIMIT
	world.ancestor_masks.clear()
	for entry in world.history.values():
		var inherited: int = 0
		for parent in entry.parents: inherited |= int(world.ancestor_masks[int(parent)])
		world.ancestor_masks[entry.id] = inherited | Ecology.mask(entry.genes)
	world.notes = data.notes.duplicate(true) if data.version == 3 else []
	world.census = data.census.duplicate(true) if data.version == 3 else [world.survey()]
	for note in world.notes:
		var entry: Dictionary = world.history[str(int(note.id))]
		var bit: int = 1 << int(note.organ)
		if (Ecology.mask(entry.genes) & bit) == 0: return null
		if note.kind == "novel":
			if entry.parents.is_empty(): return null
			for parent in entry.parents:
				if (int(world.ancestor_masks[int(parent)]) & bit) != 0: return null
	return world

# Lossless Variant bytes retain float bits and RNG state across JSON storage.
# Object decoding is disabled; validation still runs before accepting the world.
static func encode(data: Dictionary) -> Dictionary:
	var raw: PackedByteArray = var_to_bytes(data)
	var payload: String = Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return {"payload": payload, "sha256": payload.sha256_text(), "codec": "deflate", "raw_size": raw.size()}

static func decode(data: Variant):
	if not data is Dictionary or not data.get("payload") is String or not data.get("sha256") is String: return null
	if data.payload.length() > 44000000 or data.payload.sha256_text() != data.sha256: return null
	var raw: PackedByteArray = Marshalls.base64_to_raw(data.payload)
	if data.has("codec"):
		if data.codec != "deflate" or not integer(data.get("raw_size"), 8, 96000000): return null
		raw = raw.decompress(int(data.raw_size), FileAccess.COMPRESSION_DEFLATE)
		if raw.size() != int(data.raw_size): return null
	if raw.size() < 8 or (raw.decode_u32(0) & 0xFFFF) != TYPE_DICTIONARY: return null
	return restore(bytes_to_var(raw))
