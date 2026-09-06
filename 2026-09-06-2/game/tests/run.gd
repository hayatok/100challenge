extends SceneTree
const World = preload("res://core/world.gd")
const DNA = preload("res://core/genome.gd")
var failures: int = 0
var assertions: int = 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 482
	var a: Dictionary = DNA.founder(rng, 0)
	var b: Dictionary = DNA.founder(rng, 2)
	var seen: Dictionary = {}
	for i in 500:
		var child: Dictionary = DNA.cross(a, b, rng, false).genes
		check(DNA.valid(child), "valid diploid offspring")
		for key in DNA.KEYS:
			check((child[key][0] in a[key] and child[key][1] in b[key]) or (child[key][1] in a[key] and child[key][0] in b[key]), "one allele from each parent")
		seen[str(child)] = true
	check(seen.size() > 450, "crossover yields broad variety")
	for i in 300:
		a = DNA.cross(a, b, rng).genes
		check(DNA.valid(a), "mutations stay finite and viable")
	var p: Dictionary = DNA.traits(a)
	var swim: Dictionary = p.duplicate(); swim.swim = 1.0
	var land: Dictionary = p.duplicate(); land.swim = 0.0
	check(World.mobility(swim, 2) > World.mobility(land, 2), "water favors aquatic phenotype")
	check(World.upkeep(swim, 2) < World.upkeep(land, 2), "water cost follows morphology")
	var large: Dictionary = p.duplicate(); large.size = 1.0
	var small: Dictionary = p.duplicate(); small.size = 0.0
	check(World.mobility(small, 1) > World.mobility(large, 1), "small bodies navigate thickets")
	check(World.upkeep(large, 0) > World.upkeep(small, 0), "large bodies require more food")
	var world = World.new(17, 2)
	var before: Dictionary = world.snapshot()
	check(not world.breed(world.creatures[0], world.creatures[0]), "no self fertilization")
	for c in world.creatures: c.age = 30; c.cooldown = 0; c.energy = 90
	check(world.breed(world.creatures[0], world.creatures[1]), "healthy adults reproduce")
	check(world.creatures[0].energy == 68 and world.creatures[1].energy == 68, "both parents pay reproductive cost")
	check(world.creatures[2].parents == [1, 2] and world.creatures[2].generation == 1, "parent identity and generation preserved")
	check(not world.breed(world.creatures[0], world.creatures[1]), "cooldown prevents duplicate clutch")
	check(world.descendants(1) == [3], "lineage derives from actual births")
	check(world.pour_rain() and not world.pour_rain(), "rain cooldown enforced")
	world.creatures[0].energy = 0.01
	world.step()
	check(world.living(1).is_empty() and world.history["1"].died >= 0, "death retains ancestor record")
	check(world.descendants(1) == [3], "dead ancestor retains descendants")
	var copy = World.decode(JSON.parse_string(JSON.stringify(World.encode(world.snapshot()))))
	check(copy != null, "serialized world restores")
	if copy != null:
		for i in 250: world.step(); copy.step()
		check(JSON.stringify(world.snapshot(), "", true, true) == JSON.stringify(copy.snapshot(), "", true, true), "save restores RNG and identical future")
	var bad: Dictionary = before.duplicate(true)
	bad.creatures[0].genes.size[0] = "bad"
	check(World.restore(bad) == null, "invalid allele rejected")
	bad = before.duplicate(true); bad.creatures[0].target = 500
	check(World.restore(bad) == null, "unsafe plant target rejected")
	bad = before.duplicate(true); bad.history["1"].parents = [2, 2]
	check(World.restore(bad) == null, "cyclic or forward ancestry rejected")
	bad = before.duplicate(true); bad.creatures.append(bad.creatures[0])
	check(World.restore(bad) == null, "duplicate living identity rejected")
	bad = before.duplicate(true); bad.creatures[0].target = 1.5
	check(World.restore(bad) == null, "fractional array index rejected")
	bad = before.duplicate(true); bad.next_id = 1000
	check(World.restore(bad) == null, "noncontiguous history rejected")
	bad = before.duplicate(true); bad.creatures[0].genes.size[0] = 0.95
	check(World.restore(bad) == null, "phenotype and archive mismatch rejected")
	var encoded: Dictionary = World.encode(before)
	encoded.payload += "a"
	check(World.decode(encoded) == null, "damaged payload rejected before decoding")
	var outcomes: Array = []
	for seed_id in [1, 7, 19, 42, 20260906]:
		var sim = World.new(seed_id)
		var started: int = Time.get_ticks_msec()
		var maximum: int = sim.creatures.size()
		for i in 4500:
			sim.step()
			maximum = maxi(maximum, sim.creatures.size())
			if i % 500 == 0:
				check(sim.creatures.size() <= sim.capacity, "population bounded")
				for c in sim.creatures:
					check(c.x >= 0 and c.x <= World.BOUNDS.x and c.y >= 0 and c.y <= World.BOUNDS.y and is_finite(c.energy), "viable bounded state")
		var generation: int = 0
		for h in sim.history.values(): generation = maxi(generation, h.generation)
		check(sim.births > 50, "multiple generations emerge without intervention")
		check(generation >= 4, "at least four generations in fifteen simulated minutes")
		check(sim.creatures.size() >= 10, "ecosystem survives fifteen minutes")
		check(sim.next_id == 33 + sim.births and sim.creatures.size() == 32 + sim.births - sim.deaths, "birth and death accounting")
		outcomes.append({"seed": seed_id, "births": sim.births, "alive": sim.creatures.size(), "generation": generation, "maximum": maximum, "elapsed_ms": Time.get_ticks_msec() - started})
	var crowd = World.new(91, 200); crowd.capacity = 200
	var start: int = Time.get_ticks_usec()
	for i in 200: crowd.step()
	print("BENCH 200 initial organisms, mean step ms: ", (Time.get_ticks_usec() - start) / 200000.0)
	print("ECOLOGY ", JSON.stringify(outcomes))
	print("CHECKS ", assertions, " / failures ", failures)
	quit(1 if failures else 0)
