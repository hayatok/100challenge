extends RefCounted
const Anatomy = preload("res://core/anatomy.gd")
const AREAS = ["草地", "茂み", "浅瀬"]
const FOODS = ["種", "実", "藻"]
const FOCUS = [0, 2, 1]
const SAMPLE_LIMIT = 121
const NOTE_LIMIT = 40

# Allocation, not a sum of bonuses: growing every organ dilutes specialization.
static func efficiency(p: Dictionary, area: int) -> float:
	var o: Array = p.organ_counts
	var total: float = maxf(1, o[0] + o[1] + o[2] + o[3])
	var skill: float
	match area:
		0: skill = (o[0] * 0.8 + o[3] * 0.45) / total + p.reach * 0.2
		1: skill = o[2] * 0.9 / total + p.mouth * 0.2
		_: skill = o[1] * 0.9 / total + p.swim * 0.3
	return 0.78 + skill * 0.8

static func cost(p: Dictionary, area: int) -> float:
	var o: Array = p.organ_counts
	match area:
		0: return o[1] * 0.012 + o[2] * 0.004
		1: return o[1] * 0.010 + o[3] * 0.006
		_: return o[0] * 0.006 + o[3] * 0.014

static func best_food(p: Dictionary) -> int:
	var best: int = 0
	for area in range(1, 3):
		if efficiency(p, area) > efficiency(p, best): best = area
	return best

static func mask(genes: Dictionary) -> int:
	var result: int = 0
	for slot in Anatomy.SLOTS:
		var organ: Array = genes.anatomy[slot % 2].organs[slot]
		if not organ.is_empty(): result |= 1 << int(organ[0])
	return result

static func sentence(note: Dictionary) -> String:
	if note.kind == "novel": return "#%03d の祖先にいなかった、%s持ちが誕生。" % [note.id, Anatomy.NAMES[note.organ]]
	return "%sの%s持ち：%.0f%% → %.0f%%。" % [AREAS[note.area], Anatomy.NAMES[note.organ], 100.0 * note.before[0] / note.before[1], 100.0 * note.after[0] / note.after[1]]

static func valid_records(data: Dictionary) -> bool:
	if not data.get("census") is Array or data.census.is_empty() or data.census.size() > SAMPLE_LIMIT: return false
	if not data.get("notes") is Array or data.notes.size() > NOTE_LIMIT: return false
	var previous: float = -1
	for sample in data.census:
		if not sample is Dictionary or sample.size() != 2 or not Anatomy.number(sample.get("time"), 0, data.time) or sample.time <= previous: return false
		previous = sample.time
		if not sample.get("areas") is Array or sample.areas.size() != 3: return false
		var total: int = 0
		for area in sample.areas:
			if not area is Dictionary or area.size() != 4 or not Anatomy.integer(area.get("n"), 0, 200): return false
			if not area.get("counts") is Array or area.counts.size() != 4: return false
			for count in area.counts:
				if not Anatomy.integer(count, 0, area.n): return false
			if not Anatomy.number(area.get("generation"), 0, 20000): return false
			if not valid_example(area.get("example"), data.history, sample.time, area.n == 0): return false
			if area.n == 0 and area.generation != 0: return false
			total += int(area.n)
		if total > 200: return false
	previous = -1
	var seen: Dictionary = {}
	for note in data.notes:
		if not note is Dictionary or note.get("kind") not in ["novel", "trend"]: return false
		if not Anatomy.number(note.get("time"), 0, data.time) or note.time < previous: return false
		previous = note.time
		if not Anatomy.integer(note.get("area"), 0, 2) or not Anatomy.integer(note.get("organ"), 0, 3): return false
		if not valid_example(note.get("id"), data.history, note.time, false): return false
		var key: String = "%s:%s:%s" % [note.kind, note.id if note.kind == "novel" else note.time, note.organ if note.kind == "novel" else note.area]
		if seen.has(key): return false
		seen[key] = true
		if note.kind == "novel":
			if note.size() != 5 or note.time != data.history[str(int(note.id))].born: return false
		else:
			if note.size() != 8 or not Anatomy.number(note.get("from"), 0, note.time - 299.999): return false
			for label in ["before", "after"]:
				var counts: Variant = note.get(label)
				if not counts is Array or counts.size() != 2 or not Anatomy.integer(counts[1], 5, 200) or not Anatomy.integer(counts[0], 0, counts[1]): return false
			if float(note.after[0]) / note.after[1] - float(note.before[0]) / note.before[1] < 0.19999: return false
	return true

static func valid_example(id: Variant, history: Dictionary, at: float, empty: bool) -> bool:
	if empty: return id == -1
	if not Anatomy.integer(id, 1, 20000) or not history.has(str(int(id))): return false
	var entry: Dictionary = history[str(int(id))]
	return entry.born <= at and (entry.died < 0 or entry.died >= at)
