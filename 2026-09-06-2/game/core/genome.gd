extends RefCounted
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
	return {"genes": g, "changes": changes}

static func allele_value(g: Dictionary, key: String) -> float:
	if key in STRUCTURAL: return float(g[key][0])
	return float(g[key][0]) * 0.65 + float(g[key][1]) * 0.35

static func traits(g: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	for key in KEYS: p[key] = allele_value(g, key)
	p["pairs"] = 1 + mini(3, int(p.legs * 4))
	p["parts"] = 1 + mini(3, int(p.segments * 4))
	p["radius"] = 9.0 + p.size * 12.0
	p["speed"] = 12.0 + p.reach * 14.0 - p.shell * 5.0
	p["life"] = 170.0 + p.shell * 65.0 + (1.0 - p.size) * 30.0
	return p

static func valid(g: Variant) -> bool:
	if not g is Dictionary or g.size() != KEYS.size(): return false
	for key in KEYS:
		if not g.has(key) or not g[key] is Array or g[key].size() != 2: return false
		for v in g[key]:
			if not (v is int or v is float): return false
			if not is_finite(float(v)) or v < 0 or v > 1: return false
	return true

static func nickname(g: Dictionary) -> String:
	var p: Dictionary = traits(g)
	var prefix: String = "まる" if p.length < 0.4 else "なが"
	if p.spines > 0.65: prefix = "とげ"
	elif p.shell > 0.7: prefix = "かた"
	return prefix + ("あし" if p.reach > 0.6 else "ひれ" if p.swim > 0.65 else "もち" if p.size > 0.55 else "ちび")
