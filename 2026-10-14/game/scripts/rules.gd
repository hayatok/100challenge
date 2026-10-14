extends RefCounted

var elapsed := 0.0
var damage := 0
var combo := 0
var max_combo := 0
var started := false
var finished := false
var rush_timer := 0.0
var seen: Dictionary = {}
var _last_break_time := -100.0
var _last_progress := -10000.0
var _last_rush_time := -100.0

func reset() -> void:
	elapsed = 0.0
	damage = 0
	combo = 0
	max_combo = 0
	started = false
	finished = false
	rush_timer = 0.0
	seen.clear()
	_last_break_time = -100.0
	_last_progress = -10000.0
	_last_rush_time = -100.0

func begin() -> void:
	if not finished:
		started = true

func advance(delta: float) -> void:
	if not started or finished:
		return
	elapsed += maxf(0.0, delta)
	rush_timer = maxf(0.0, rush_timer - delta)
	if combo > 0 and elapsed - _last_break_time > 2.0:
		combo = 0

func register_breaks(events: Array) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if finished:
		return rewards
	var sorted_events := events.duplicate()
	sorted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.get("progress", 0.0)) == float(b.get("progress", 0.0)):
			return str(a.get("id", "")) < str(b.get("id", ""))
		return float(a.get("progress", 0.0)) < float(b.get("progress", 0.0)))
	for item: Dictionary in sorted_events:
		var id := str(item.get("id", ""))
		var base := int(item.get("base", 0))
		if id.is_empty() or seen.has(id) or base <= 0:
			continue
		seen[id] = true
		var progress := float(item.get("progress", 0.0))
		if combo > 0 and elapsed - _last_break_time <= 2.0 and progress > _last_progress:
			combo += 1
		else:
			combo = 1
		max_combo = maxi(max_combo, combo)
		var multiplier := mini(combo, 3)
		var added := base * multiplier
		damage += added
		_last_progress = progress
		_last_break_time = elapsed
		var trigger_rush := combo == 3 and elapsed - _last_rush_time >= 5.0
		if trigger_rush:
			rush_timer = 1.2
			_last_rush_time = elapsed
		var reward: Dictionary = item.duplicate()
		reward.merge({"added": added, "combo": combo, "multiplier": multiplier, "rush_started": trigger_rush}, true)
		rewards.append(reward)
	return rewards

func finish() -> Dictionary:
	finished = true
	var result := ranking(elapsed)
	result.merge({"elapsed": elapsed, "damage": damage, "max_combo": max_combo}, true)
	return result

static func ranking(seconds: float) -> Dictionary:
	if seconds <= 30.0:
		return {"rank": "SSS", "rank_text": "爆速帰宅"}
	if seconds <= 45.0:
		return {"rank": "SS", "rank_text": "定時の覇者"}
	if seconds <= 60.0:
		return {"rank": "S", "rank_text": "見事な退勤"}
	if seconds <= 90.0:
		return {"rank": "A", "rank_text": "おつかれさま"}
	return {"rank": "B", "rank_text": "帰れたので勝ち"}
