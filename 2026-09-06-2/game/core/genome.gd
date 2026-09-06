extends RefCounted
const Anatomy = preload("res://core/anatomy.gd")
# Diploid alleles are inherited; morphology is a deterministic phenotype, never frame noise.
const KEYS = ["size", "length", "legs", "reach", "eyes", "shell", "spines", "hue", "pattern", "sense", "social", "swim", "segments", "mouth"]
const STRUCTURAL = ["legs", "pattern", "segments"]

static func founder(rng: RandomNumberGenerator, family: int) -> Dictionary:
	var g: Dictionary = {}
	for key in KEYS:
		var center: float = rng.randf_range(0.12, 0.88)
		if key == "swim": center = [0.18, 0.48, 0.86][family % 3]
		if key == "hue": center = [0.10, 0.37, 0.54, 0.96][family % 4]
		g[key] = [clampf(center + rng.randfn(0, 0.10), 0, 1), clampf(center + rng.randfn(0, 0.10), 0, 1)]
	var p: Dictionary = base_traits(g)
	var structure_rng = RandomNumberGenerator.new()
	structure_rng.seed = structure_seed(g)
	g["anatomy"] = [Anatomy.founder(structure_rng, family, p), Anatomy.founder(structure_rng, family, p)]
	return g

static func cross(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, mutate: bool = true) -> Dictionary:
	var g: Dictionary = {}
	var changes: Array[String] = []
	for key in KEYS:
		var pair: Array = [a[key][rng.randi_range(0, 1)], b[key][rng.randi_range(0, 1)]]
		# Reversing order lets either parent's structural allele be expressed.
		if rng.randf() < 0.5: pair.reverse()
		for i in 2:
			if mutate and rng.randf() < 0.12:
				var delta: float = rng.randfn(0, 0.045)
				if rng.randf() < 0.08: delta = rng.randf_range(-0.28, 0.28)
				pair[i] = clampf(float(pair[i]) + delta, 0, 1)
				if absf(delta) > 0.12 and key not in changes: changes.append(key)
		g[key] = pair
	var structure_rng = RandomNumberGenerator.new()
	structure_rng.seed = structure_seed(g)
	var structure: Dictionary = Anatomy.cross(upgrade(a).anatomy, upgrade(b).anatomy, structure_rng, mutate)
	g["anatomy"] = structure.pair
	if structure.structural: changes.append("anatomy")
	return {"genes": g, "changes": changes}

# Do not amplify platform-level float rounding into unrelated body plans.
static func structure_seed(g: Dictionary) -> int:
	var values: Array = []
	for key in KEYS:
		for value in g[key]: values.append(roundi(float(value) * 1000000.0))
	return hash(values)

static func allele_value(g: Dictionary, key: String) -> float:
	if key in STRUCTURAL: return float(g[key][0])
	return float(g[key][0]) * 0.65 + float(g[key][1]) * 0.35

static func base_traits(g: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	for key in KEYS: p[key] = allele_value(g, key)
	p["pairs"] = 1 + mini(3, int(p.legs * 4))
	p["parts"] = 1 + mini(3, int(p.segments * 4))
	p["radius"] = 9.0 + p.size * 12.0
	p["speed"] = 12.0 + p.reach * 14.0 - p.shell * 5.0
	p["life"] = 170.0 + p.shell * 65.0 + (1.0 - p.size) * 30.0
	return p

static func upgrade(g: Dictionary) -> Dictionary:
	if g.has("anatomy"): return g
	var result: Dictionary = g.duplicate(true)
	var bp: Dictionary = Anatomy.legacy(base_traits(g))
	result["anatomy"] = [bp, bp.duplicate(true)]
	return result

static func traits(g: Dictionary) -> Dictionary:
	var p: Dictionary = base_traits(g)
	p["blueprint"] = Anatomy.express(upgrade(g).anatomy)
	p["organ_counts"] = Anatomy.counts(p.blueprint)
	p["parts"] = p.blueprint.nodes.size()
	p["pairs"] = p.organ_counts[0]
	return p

static func valid(g: Variant, allow_legacy: bool = false) -> bool:
	if not g is Dictionary: return false
	if g.size() != KEYS.size() + 1 and not (allow_legacy and g.size() == KEYS.size()): return false
	for key in KEYS:
		if not g.has(key) or not g[key] is Array or g[key].size() != 2: return false
		for v in g[key]:
			if not (v is int or v is float): return false
			if not is_finite(float(v)) or v < 0 or v > 1: return false
	if not g.has("anatomy"): return allow_legacy
	if not g.anatomy is Array or g.anatomy.size() != 2: return false
	for bp in g.anatomy:
		if not Anatomy.valid(bp): return false
	return true

static func nickname(g: Dictionary) -> String:
	var p: Dictionary = traits(g)
	var prefix: String = "まる" if p.length < 0.4 else "なが"
	if p.spines > 0.65: prefix = "とげ"
	elif p.shell > 0.7: prefix = "かた"
	if Anatomy.branching(p.blueprint): prefix = "えだ"
	var counts: Array = p.organ_counts
	var largest: int = counts.max()
	var suffix: String = ["あし", "ひれ", "うね", "はね"][counts.find(largest)] if largest > 0 else "もち"
	return prefix + suffix
