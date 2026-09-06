extends SceneTree
const DNA = preload("res://core/genome.gd")
const Anatomy = preload("res://core/anatomy.gd")
const World = preload("res://core/world.gd")
const Art = preload("res://creature_art.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ANATOMY: ", text)

func _initialize() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 804
	var a: Dictionary = DNA.founder(rng, 0)
	var b: Dictionary = DNA.founder(rng, 3)
	var original_a: Dictionary = a.duplicate(true)
	var original_b: Dictionary = b.duplicate(true)
	var rounded: Dictionary = a.duplicate(true)
	for key in DNA.KEYS:
		for i in 2: rounded[key][i] += 0.00000000001
	check(DNA.structure_seed(a) == DNA.structure_seed(rounded), "negligible platform float rounding does not change structural seed")
	var art = Art.new()
	var kinds: Dictionary = {}
	var structures: Dictionary = {}
	var had_branch: bool = false
	for i in 500:
		var child: Dictionary = DNA.cross(a, b, rng, false).genes
		check((child.anatomy[0] in a.anatomy and child.anatomy[1] in b.anatomy) or (child.anatomy[1] in a.anatomy and child.anatomy[0] in b.anatomy), "one complete blueprint from each parent")
		var expressed: Dictionary = Anatomy.express(child.anatomy)
		check(expressed.nodes == child.anatomy[0].nodes, "body connectivity comes from inherited blueprint")
		var visible_slot: int = 0
		for slot in Anatomy.SLOTS:
			var inherited: Array = child.anatomy[slot % 2].organs[slot]
			if inherited.is_empty(): continue
			check(expressed.organs[visible_slot][0] == inherited[0] and expressed.organs[visible_slot][2] == inherited[2], "organ type and attachment inherited by slot")
			check(expressed.organs[visible_slot][1] < expressed.nodes.size(), "mixed organs attach to an existing node")
			visible_slot += 1
	check(a == original_a and b == original_b, "crossing never modifies parent genomes")
	for i in 1000:
		a = DNA.cross(a, b, rng).genes
		if i % 11 == 0: b = DNA.founder(rng, i % 4)
		check(DNA.valid(a), "a thousand generations keep bounded valid structures")
		var p: Dictionary = DNA.traits(a)
		structures[str(p.blueprint.nodes)] = true
		had_branch = had_branch or Anatomy.branching(p.blueprint)
		for o in p.blueprint.organs: kinds[o[0]] = true
		var drawing: Dictionary = art.morphology(a)
		for j in drawing.eyes.size():
			for k in range(j + 1, drawing.eyes.size()): check(drawing.eyes[j].distance_to(drawing.eyes[k]) > (drawing.eye_size + 1.6) * 2, "eye outlines never overlap")
		if i % 25 == 0:
			for size in [Vector2(90, 120), Vector2(116, 106), Vector2(306, 150)]:
				var fit: Dictionary = art.portrait_fit(a, size, true, false)
				var drawn: Rect2 = Rect2(fit.center + fit.bounds.position * fit.scale, fit.bounds.size * fit.scale)
				check(Rect2(Vector2.ZERO, size - Vector2(0, 20)).encloses(drawn), "variable body fits portrait above caption")
	check(kinds.size() == 4 and had_branch and structures.size() > 300, "all organ kinds and many branched structures emerge")
	for operation in 7:
		var changed: bool = false
		for i in 40:
			var bp: Dictionary = Anatomy.founder(rng, i % 4, DNA.base_traits(a))
			changed = Anatomy.mutate_structure(bp, rng, operation) or changed
			check(Anatomy.valid(bp), "structural operation preserves connected bounded body")
		check(changed, "each structural mutation can change the blueprint")
	for bad_kind in ["cycle", "fractional", "organ_node", "nan", "too_many", "eyes", "unknown", "missing"]:
		var bad: Dictionary = a.duplicate(true)
		match bad_kind:
			"cycle": bad.anatomy[0].nodes[0][0] = 0
			"fractional": bad.anatomy[0].organs[0] = [0.5, 0, 0.25, 0.5]
			"organ_node": bad.anatomy[0].organs[0] = [0, 99, 0.25, 0.5]
			"nan": bad.anatomy[0].nodes[0][2] = NAN
			"too_many": bad.anatomy[0].nodes.resize(7)
			"eyes": bad.anatomy[0].eyes = 0
			"unknown": bad.anatomy[0].extra = 1
			"missing": bad.erase("anatomy")
		check(not DNA.valid(bad), "malformed anatomy rejected: " + bad_kind)
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy-v1.json"))
	var old: Dictionary = bytes_to_var(Marshalls.base64_to_raw(legacy.world.payload))
	check(old.version == 1 and old.history["1"].genes.size() == 14, "fixture was produced by the real v1 serializer")
	var migrated = World.decode(legacy.world)
	check(migrated != null and migrated.migrated, "old save migrates without a reset")
	if migrated != null:
		check(migrated.history["1"].name == "むかしの親" and migrated.history["3"].parents == [1, 2] and migrated.living(1).is_empty(), "names, dead parents and descendants survive migration")
		check(str(migrated.rng.state) == old.rng and migrated.next_id == old.next_id, "migration preserves RNG and identities")
		for id in old.history:
			for key in DNA.KEYS: check(migrated.history[id].genes[key] == old.history[id].genes[key], "old alleles preserved")
			check(DNA.valid(migrated.history[id].genes), "historical bodies gain valid blueprints")
		var packet: Dictionary = World.encode(migrated.snapshot())
		check(packet.codec == "deflate" and packet.payload.length() < packet.raw_size, "structural saves are compressed")
		var restored = World.decode(JSON.parse_string(JSON.stringify(packet)))
		check(restored != null, "new compressed save restores")
		if restored != null:
			for i in 250: migrated.step(); restored.step()
			check(migrated.snapshot() == restored.snapshot(), "migration and compressed save retain identical future")
		var wrong: Dictionary = packet.duplicate(true); wrong.raw_size = 96000001
		check(World.decode(wrong) == null, "oversized decompression rejected before allocation")
		wrong = packet.duplicate(true); wrong.codec = "unknown"
		check(World.decode(wrong) == null, "unknown compression rejected")
		wrong = migrated.snapshot(); wrong.creatures[0].genes.anatomy[0].eyes = 0
		check(World.restore(wrong) == null, "world boundary rejects broken blueprint")
	var p: Dictionary = DNA.traits(a)
	var plain: Dictionary = p.duplicate(true); plain.organ_counts = [0, 0, 0, 0]
	var fin: Dictionary = plain.duplicate(true); fin.organ_counts[1] = 2
	var tentacle: Dictionary = plain.duplicate(true); tentacle.organ_counts[2] = 2
	var wing: Dictionary = plain.duplicate(true); wing.organ_counts[3] = 2
	check(World.mobility(fin, 2) > World.mobility(plain, 2), "fins help movement in water")
	check(World.mobility(tentacle, 1) > World.mobility(plain, 1), "tentacles help movement in thickets")
	check(World.mobility(wing, 0) > World.mobility(plain, 0), "wings help ground movement")
	# The richest valid blueprint still fits the bounded save envelope at history capacity.
	var biggest: Dictionary = a.duplicate(true)
	for bp in biggest.anatomy:
		bp.nodes = [[-1, 0.0, 1.0, 1.0]]
		for i in range(1, Anatomy.MAX_NODES): bp.nodes.append([i - 1, 1.0, 1.0, 1.0])
		bp.organs = []
		for i in Anatomy.SLOTS: bp.organs.append([i % 4, 5, 1.0, 1.0])
		bp.eyes = 3
	var largest_entry: Dictionary = old.history["3"].duplicate(true)
	largest_entry.genes = biggest
	largest_entry.name = "𠮷".repeat(60)
	check(var_to_bytes(largest_entry).size() * World.HISTORY_LIMIT + 2000000 < 96000000, "maximum anatomy archive fits decompression limit")
	print("ANATOMY CHECKS ", checks, " / failures ", failures, " / structures ", structures.size())
	quit(1 if failures else 0)
