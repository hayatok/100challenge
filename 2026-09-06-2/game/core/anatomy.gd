extends RefCounted
# Two bounded blueprints. Node parents always precede their children.
const MAX_NODES = 6
const SLOTS = 6
const NAMES = ["脚", "ヒレ", "触手", "翼"]

static func number(v: Variant, low: float, high: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v >= low and v <= high

static func integer(v: Variant, low: int, high: int) -> bool:
	return number(v, low, high) and float(v) == floorf(float(v))

static func valid(chromosome: Variant) -> bool:
	if not chromosome is Dictionary or chromosome.size() != 3: return false
	if not chromosome.get("nodes") is Array or chromosome.nodes.size() < 1 or chromosome.nodes.size() > MAX_NODES: return false
	if not chromosome.get("organs") is Array or chromosome.organs.size() != SLOTS: return false
	if not integer(chromosome.get("eyes"), 1, 3): return false
	for i in chromosome.nodes.size():
		var n: Variant = chromosome.nodes[i]
		if not n is Array or n.size() != 4: return false
		if not integer(n[0], -1 if i == 0 else 0, -1 if i == 0 else i - 1): return false
		if not number(n[1], -1, 1) or not number(n[2], 0, 1) or not number(n[3], 0, 1): return false
	for o in chromosome.organs:
		if not o is Array: return false
		if o.is_empty(): continue
		if o.size() != 4 or not integer(o[0], 0, 3) or not integer(o[1], 0, chromosome.nodes.size() - 1): return false
		if not number(o[2], 0, 1) or not number(o[3], 0, 1): return false
	return true

static func legacy(p: Dictionary) -> Dictionary:
	var nodes: Array = [[-1, 0.0, p.length, 0.65]]
	for i in range(1, int(p.parts)): nodes.append([i - 1, 0.0, p.length, 0.65 - i * 0.08])
	var organs: Array = [[], [], [], [], [], []]
	for i in int(p.pairs): organs[i] = [0, mini(i, nodes.size() - 1), 0.17 + i * 0.045, p.reach]
	return {"nodes": nodes, "organs": organs, "eyes": 2}

static func founder(rng: RandomNumberGenerator, family: int, p: Dictionary) -> Dictionary:
	var nodes: Array = [[-1, 0.0, p.length, rng.randf_range(0.25, 0.9)]]
	var count: int = rng.randi_range(1, 5)
	for i in range(1, count):
		var parent: int = rng.randi_range(0, i - 1) if rng.randf() < 0.45 else i - 1
		var bend: float = rng.randf_range(-0.85, 0.85) if parent < i - 1 else rng.randf_range(-0.16, 0.16)
		nodes.append([parent, bend, rng.randf_range(0.1, 0.9), rng.randf_range(0.15, 0.85)])
	var organs: Array = [[], [], [], [], [], []]
	for i in rng.randi_range(1, 4):
		var kind: int = family % 4 if rng.randf() < 0.7 else rng.randi_range(0, 3)
		organs[i] = organ(rng, kind, nodes.size())
	return {"nodes": nodes, "organs": organs, "eyes": rng.randi_range(1, 3)}

static func organ(rng: RandomNumberGenerator, kind: int, node_count: int) -> Array:
	var at: float = rng.randf_range(0.10, 0.42) if kind == 0 else rng.randf_range(0.60, 0.88) if kind == 3 else rng.randf()
	return [kind, rng.randi_range(0, node_count - 1), at, rng.randf_range(0.15, 0.85)]

static func express(pair: Array) -> Dictionary:
	var result: Dictionary = pair[0].duplicate(true)
	result.organs = []
	# Homologous slots can express either parent's blueprint after allele order swaps.
	for slot in SLOTS:
		var o: Array = pair[slot % 2].organs[slot].duplicate()
		if o.is_empty(): continue
		o[1] = mini(int(o[1]), result.nodes.size() - 1)
		result.organs.append(o)
	return result

static func cross(a: Array, b: Array, rng: RandomNumberGenerator, mutate: bool) -> Dictionary:
	var pair: Array = [a[rng.randi_range(0, 1)].duplicate(true), b[rng.randi_range(0, 1)].duplicate(true)]
	if rng.randf() < 0.5: pair.reverse()
	var structural: bool = false
	if mutate:
		for blueprint in pair:
			for n in blueprint.nodes:
				for k in range(1, 4):
					if rng.randf() < 0.12: n[k] = clampf(n[k] + rng.randfn(0, 0.055), -1 if k == 1 else 0, 1)
			for o in blueprint.organs:
				if o.is_empty(): continue
				if rng.randf() < 0.15: o[2] = fposmod(o[2] + rng.randfn(0, 0.065), 1.0)
				if rng.randf() < 0.15: o[3] = clampf(o[3] + rng.randfn(0, 0.06), 0, 1)
				if rng.randf() < 0.06: o[1] = rng.randi_range(0, blueprint.nodes.size() - 1)
			if rng.randf() < 0.20:
				structural = mutate_structure(blueprint, rng, rng.randi_range(0, 6)) or structural
	return {"pair": pair, "structural": structural}

static func mutate_structure(bp: Dictionary, rng: RandomNumberGenerator, operation: int) -> bool:
	var before: Dictionary = bp.duplicate(true)
	var nodes: Array = bp.nodes
	match operation:
		0: # Add a node, including a new branch on an existing body node.
			if nodes.size() < MAX_NODES: nodes.append([rng.randi_range(0, nodes.size() - 1), rng.randf_range(-0.9, 0.9), rng.randf(), rng.randf()])
		1: # Remove a leaf and move its organs to its former parent.
			if nodes.size() > 1:
				var leaves: Array = []
				for i in range(1, nodes.size()):
					var leaf: bool = true
					for n in nodes:
						if int(n[0]) == i: leaf = false
					if leaf: leaves.append(i)
				var removed: int = leaves[rng.randi_range(0, leaves.size() - 1)]
				var parent: int = int(nodes[removed][0])
				nodes.remove_at(removed)
				for n in nodes:
					if n[0] > removed: n[0] -= 1
				for o in bp.organs:
					if o.is_empty(): continue
					if int(o[1]) == removed: o[1] = parent
					elif o[1] > removed: o[1] -= 1
		2:
			if nodes.size() > 1:
				var i: int = rng.randi_range(1, nodes.size() - 1)
				nodes[i][0] = rng.randi_range(0, i - 1)
				nodes[i][1] = rng.randf_range(-0.95, 0.95)
		3:
			var slot: int = rng.randi_range(0, SLOTS - 1)
			if bp.organs[slot].is_empty(): bp.organs[slot] = organ(rng, rng.randi_range(0, 3), nodes.size())
			else: bp.organs[slot][0] = (int(bp.organs[slot][0]) + rng.randi_range(1, 3)) % 4
		4:
			var empty: Array = []
			for i in SLOTS:
				if bp.organs[i].is_empty(): empty.append(i)
			if not empty.is_empty(): bp.organs[empty[rng.randi_range(0, empty.size() - 1)]] = organ(rng, rng.randi_range(0, 3), nodes.size())
		5: bp.organs[rng.randi_range(0, SLOTS - 1)] = []
		6: bp.eyes = 1 + (int(bp.eyes) - 1 + rng.randi_range(1, 2)) % 3
	return bp != before

static func counts(bp: Dictionary) -> Array:
	var result: Array = [0, 0, 0, 0]
	for o in bp.organs: result[int(o[0])] += 1
	return result

static func branching(bp: Dictionary) -> bool:
	var parents: Dictionary = {}
	for i in range(1, bp.nodes.size()):
		var parent: int = int(bp.nodes[i][0])
		if parents.has(parent): return true
		parents[parent] = true
	return false

static func body_label(bp: Dictionary) -> String:
	return ("枝分かれ" if branching(bp) else "連なり" if bp.nodes.size() > 1 else "") + "%d節・目%d" % [bp.nodes.size(), bp.eyes]

static func organ_label(bp: Dictionary) -> String:
	var values: Array = counts(bp)
	var parts: PackedStringArray = []
	for i in 4:
		if values[i] > 0: parts.append(NAMES[i] + str(values[i]))
	return "器官なし・体を揺らして移動" if parts.is_empty() else "・".join(parts)
