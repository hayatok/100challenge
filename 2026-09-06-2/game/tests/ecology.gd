extends SceneTree
const W = preload("res://core/world.gd")
const DNA = preload("res://core/genome.gd")
const E = preload("res://core/ecology.gd")
var checks: int = 0
var failures: int = 0
const PLACES = [Vector2(150, 140), Vector2(315, 465), Vector2(820, 360)]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ECOLOGY: ", message)

func genome(kinds: Array) -> Dictionary:
	var rng = RandomNumberGenerator.new(); rng.seed = 84
	var genes: Dictionary = DNA.founder(rng, 0)
	for key in DNA.KEYS: genes[key] = [0.5, 0.5]
	for bp in genes.anatomy:
		bp.nodes = [[-1, 0.0, 0.5, 0.5]]
		bp.organs = [[], [], [], [], [], []]
		for i in kinds.size(): bp.organs[i] = [kinds[i], 0, 0.25, 0.5]
	return genes

func resident(genes: Dictionary, area: int, count: int = 1):
	var world = W.new(31, 0)
	world.capacity = count
	for plant in world.plants:
		plant.x = PLACES[area].x; plant.y = PLACES[area].y; plant.food = 26.0
	for i in count:
		var c: Dictionary = world.spawn(genes.duplicate(true), [], 0, 0, PLACES[area] + Vector2(i * 2, 0))
		c.age = 30; c.energy = 40; c.cooldown = 0; c.target = 0
	world.census = [world.survey()]
	return world

func run() -> void:
	var all: Dictionary = DNA.traits(genome([0, 1, 2, 3]))
	var control: Array = []
	for area in 3:
		var kind: int = E.FOCUS[area]
		var specialist: Dictionary = genome([kind, kind])
		var other: Dictionary = genome([E.FOCUS[(area + 1) % 3], E.FOCUS[(area + 1) % 3]])
		var p: Dictionary = DNA.traits(specialist)
		check(E.efficiency(p, area) > E.efficiency(all, area), "all-organ body is not universally optimal")
		check(E.best_food(p) == area, "specialist has a matching food preference")
		var efficient = resident(specialist, area)
		var inefficient = resident(other, area)
		for i in 75: efficient.step(); inefficient.step()
		check(efficient.creatures[0].energy > inefficient.creatures[0].energy + 8, "actual feeding gives matching anatomy more net energy")
		check(efficient.plants[0].food >= 0 and efficient.creatures[0].energy <= 100, "feeding respects finite food and energy caps")
		var fit = resident(specialist, area, 8); fit.capacity = 120
		var unfit = resident(other, area, 8); unfit.capacity = 120
		var first_fit: float = INF
		var first_unfit: float = INF
		for i in 300:
			fit.step(); unfit.step()
			if fit.births > 0: first_fit = minf(first_fit, fit.time)
			if unfit.births > 0: first_unfit = minf(first_unfit, unfit.time)
		check(first_fit < first_unfit, "matching organs reach a successful birth earlier in the same environment")
		control.append({"area": area, "matched_births": fit.births, "other_births": unfit.births, "first_matched": first_fit, "first_other": first_unfit})
	var fin: Dictionary = DNA.traits(genome([1, 1]))
	check(E.cost(fin, 0) > E.cost(fin, 2), "fins have a cost outside water")
	for kind in [0, 1]:
		var world = resident(genome([kind, kind]), 0)
		for plant in world.plants: plant.food = 0
		world.plants[0] = {"x": 530.0, "y": 350.0, "food": 20.0}
		world.plants[1] = {"x": 580.0, "y": 350.0, "food": 20.0}
		world.creatures[0].x = 550; world.creatures[0].y = 350; world.creatures[0].target = -1
		world.step()
		check(world.creatures[0].target == kind, "food choice follows leg/fin anatomy at a habitat boundary")
	var world = resident(genome([0]), 0, 5)
	var previous: Dictionary = world.survey()
	world.time = 300; world.tick = 1500
	for c in world.creatures:
		c.genes = genome([1]); world.history[str(c.id)].genes = c.genes.duplicate(true)
		world.phenotypes[c.id] = DNA.traits(c.genes)
	world.census = [previous]
	world.take_census()
	check(world.notes.size() == 1 and world.notes[0].before == [0, 5] and world.notes[0].after == [5, 5], "trend records actual counts and denominators")
	world.time += 30; world.take_census()
	check(world.notes.size() == 1, "one area does not spam repeated trend notes")
	world.creatures.resize(4); world.time = 600; world.take_census()
	check(world.notes.size() == 1, "tiny populations do not trigger trend conclusions")
	var family = resident(genome([0]), 0, 2); family.capacity = 120
	var child: Dictionary = family.spawn(genome([2]), [1, 2], 0, 1, PLACES[0]); family.births += 1
	check(family.notes.size() == 1 and family.notes[0].organ == 2, "first expressed organ in an ancestry is recorded")
	var plain_child: Dictionary = family.spawn(genome([0]), [child.id, 2], 0, 2, PLACES[0]); family.births += 1
	family.spawn(genome([2]), [plain_child.id, 1], 0, 3, PLACES[0]); family.births += 1
	check(family.notes.size() == 1, "an organ seen in a grandparent is not falsely called new")
	var loaded = W.decode(W.encode(family.snapshot()))
	check(loaded != null, "discovery records restore")
	if loaded != null:
		for i in 1700: family.step(); loaded.step()
		check(family.snapshot() == loaded.snapshot(), "census and discoveries retain identical future after save")
	var original_packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy-v2.json"))
	var old: Dictionary = bytes_to_var(Marshalls.base64_to_raw(original_packet.payload).decompress(int(original_packet.raw_size), FileAccess.COMPRESSION_DEFLATE))
	var migrated = W.decode(original_packet)
	check(old.version == 2 and migrated != null and migrated.migrated, "real v2 fixture migrates")
	if migrated != null:
		check(migrated.census.size() == 1 and migrated.census[0].time == old.time and migrated.notes.is_empty(), "migration starts measurements now without fabricated history")
		check(migrated.history == old.history and migrated.plants == old.plants and str(migrated.rng.state) == old.rng, "old bodies, names, ancestry, food and RNG survive")
		check(migrated.comparison(migrated.survey()).is_empty(), "new observation has no pretend five-minute comparison")
	var valid = W.new(19)
	for i in 1800: valid.step()
	check(W.restore(valid.snapshot()) != null, "normal six-minute observation archive validates")
	for bad_kind in ["counts", "nan", "future", "missing", "example", "limit", "note"]:
		var bad: Dictionary = valid.snapshot()
		match bad_kind:
			"counts": bad.census[0].areas[0].counts[0] = 1000
			"nan": bad.census[0].areas[0].generation = NAN
			"future": bad.census[-1].time = bad.time + 1
			"missing": bad.erase("census")
			"example": bad.census[-1].areas[0].example = 99999
			"limit": bad.census.resize(E.SAMPLE_LIMIT + 1)
			"note": bad.notes.append({"kind": "novel", "time": bad.time, "id": 1, "area": 0, "organ": 0})
		check(W.restore(bad) == null, "reject invalid record: " + bad_kind)
	print("CONTROLLED HABITATS ", JSON.stringify(control))
	print("HABITAT CHECKS ", checks, " / failures ", failures)
	quit(1 if failures else 0)

func _initialize() -> void: run()
