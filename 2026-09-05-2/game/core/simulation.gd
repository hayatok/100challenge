extends RefCounted
const Geo = preload("res://core/loop_geometry.gd")
const LIMIT = 180.0
const CAP = 600
const CELL = 4.0
const INFO = {
	"burst": ["回収アンプ", "囲みの威力 +2。大きな群れも一度に回収。", "BURST"],
	"trail": ["ロングケーブル", "線が残る時間 +0.75秒。遠くまで回り込める。", "LOOP"],
	"territory": ["予備バッテリー", "陣地の寿命 +2秒。自動射撃の威力も上昇。", "STAGE"],
	"haste": ["高速シーケンサー", "自動射撃の間隔を短縮。帰り道を開ける。", "TEMPO"],
	"speed": ["軽量スニーカー", "移動速度 +8%。同じ時間でも大きく囲める。", "MOVE"],
	"repair": ["差し入れと応急修理", "HPを35回復。最大HPのときは選択候補に出ない。", "CARE"]
}
var rng = RandomNumberGenerator.new()
var state = "ready"
var clock = 0.0
var player = Vector2.ZERO
var facing = Vector2.DOWN
var hp = 100.0
var xp = 0.0
var level = 1
var kills = 0
var loops = 0
var best_loop = 0
var last_loop = 0
var total_collected = 0.0
var id_counter = 0
var enemies: Array = []
var pickups: Array = []
var trail: Array = []
var regions: Array = []
var effects: Array = []
var choices: Array = []
var upgrades = {"burst": 0, "trail": 0, "territory": 0, "haste": 0, "speed": 0, "repair": 0}
var sources = {"weapon": 0, "burst": 0, "territory": 0}
var spawn_clock = 0.0
var shot_clock = 0.0
var hurt_clock = 0.0
var grid: Dictionary = {}
var rerolls = 2
var seed_value = 1
var event_serial = 0
var notice = "線をつないで、囲もう。"

func _init(seed_number: int = 20260905) -> void:
	rng.seed = seed_number
	seed_value = seed_number

func start() -> void:
	state = "running"
	trail = [{"p": player, "t": clock}]
	# First encounter makes the return route readable; later waves use seeded spawns.
	for i in 10:
		spawn_enemy(Vector2(-4.5 + (i % 5) * 1.8, -4.0 - (i / 5) * 1.5))

func speed() -> float:
	return 6.4 * (1.0 + upgrades.speed * 0.08)

func trail_life() -> float:
	return 6.0 + upgrades.trail * 0.75

func needed_xp() -> float:
	return 8.0 + (level - 1) * 4.0

func pause() -> void:
	if state == "running":
		state = "paused"

func resume() -> void:
	if state == "paused":
		state = "running"

func spawn_enemy(at: Vector2) -> void:
	if enemies.size() >= CAP:
		return
	id_counter += 1
	enemies.append({"id": id_counter, "p": at, "hp": 2.0 + floorf(clock / 65.0), "phase": rng.randf() * TAU})

func rebuild_grid() -> void:
	grid.clear()
	for e in enemies:
		if e.hp <= 0.0:
			continue
		var key = Vector2i(floori(e.p.x / CELL), floori(e.p.y / CELL))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(e)

func candidates(poly: PackedVector2Array) -> Array:
	var box = Geo.bounds(poly)
	var result: Array = []
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for y in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
			result.append_array(grid.get(Vector2i(x, y), []))
	return result

func effect(kind: String, at: Vector2, extra: Dictionary = {}) -> void:
	var fx = {"kind": kind, "p": at, "life": 0.5, "max_life": 0.5}
	fx.merge(extra, true)
	effects.append(fx)
	if effects.size() > 160:
		effects.pop_front()

func damage(e: Dictionary, amount: float, source: String) -> bool:
	if e.hp <= 0.0:
		return false
	e.hp -= amount
	if e.hp > 0.0:
		return false
	kills += 1
	sources[source] += 1
	effect("pop", e.p)
	if source == "burst":
		xp += 1.3
		total_collected += 1.3
	else:
		pickups.append({"p": e.p, "value": 1.0})
		# Merge old drops without throwing away earned XP or creating unbounded nodes.
		if pickups.size() > 400:
			var oldest = pickups.pop_front()
			pickups[0].value += oldest.value
	return true

func collect_loop(poly: PackedVector2Array) -> void:
	loops += 1
	last_loop = 0
	for e in candidates(poly):
		if Geo.contains(e.p, poly) and damage(e, 3.0 + upgrades.burst * 2.0, "burst"):
			last_loop += 1
	for i in range(pickups.size() - 1, -1, -1):
		if Geo.contains(pickups[i].p, poly):
			xp += pickups[i].value
			total_collected += pickups[i].value
			pickups.remove_at(i)
	best_loop = maxi(best_loop, last_loop)
	var center = Vector2.ZERO
	for p in poly:
		center += p
	center /= poly.size()
	regions.append({"poly": poly, "center": center, "life": 8.0 + upgrades.territory * 2.0, "shot": 0.35})
	if regions.size() > 3:
		regions.pop_front()
	effect("loop", center, {"life": 0.8, "max_life": 0.8, "count": last_loop})
	event_serial += 1
	notice = "こはく「そこ、最前列になるよ！」" if last_loop >= 6 else "ねむ「輪、閉じた。そこ、今うちのステージ」"

func generate_choices() -> void:
	var pool: Array = []
	for key in INFO:
		if key == "repair":
			if hp < 100.0:
				pool.append(key)
		elif upgrades[key] < 4:
			pool.append(key)
	if pool.is_empty():
		pool = ["repair"]
	choices.clear()
	while not pool.is_empty() and choices.size() < 3:
		var index = rng.randi_range(0, pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)

func check_level() -> void:
	if xp >= needed_xp() and state == "running":
		xp -= needed_xp()
		level += 1
		state = "upgrade"
		generate_choices()

func choose(index: int) -> void:
	if state != "upgrade" or index < 0 or index >= choices.size():
		return
	var key = choices[index]
	upgrades[key] += 1
	if key == "repair":
		hp = minf(100.0, hp + 35.0)
	state = "running"
	check_level() # Multiple earned levels share one paused screen.

func reroll() -> void:
	if state == "upgrade" and rerolls > 0:
		rerolls -= 1
		generate_choices()

func step(dt: float, direction: Vector2) -> void:
	if state != "running":
		return
	clock += dt
	hurt_clock = maxf(0.0, hurt_clock - dt)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= dt
		if effects[i].life <= 0.0:
			effects.remove_at(i)
	if direction.length_squared() > 0.001:
		facing = direction.normalized()
		player += direction.limit_length() * speed() * dt
		player = player.clamp(Vector2(-20, -12), Vector2(20, 12))
	for e in enemies:
		var delta: Vector2 = player - e.p
		var distance = delta.length()
		if distance > 0.001:
			e.p += delta / distance * (1.25 + clock / 200.0) * dt
		if distance < 0.7 and hurt_clock <= 0.0:
			hp -= 7.0
			hurt_clock = 1.0
			effect("hurt", player)
	rebuild_grid()
	while not trail.is_empty() and clock - trail[0].t > trail_life():
		trail.pop_front()
	if trail.is_empty():
		trail.append({"p": player, "t": clock})
	elif player.distance_squared_to(trail[-1].p) >= 0.0256:
		var poly = Geo.close_loop(trail, player, clock)
		if not poly.is_empty():
			collect_loop(poly)
			trail = [{"p": player, "t": clock}]
		else:
			trail.append({"p": player, "t": clock})
	shot_clock -= dt
	if shot_clock <= 0.0:
		shot_clock = 0.9 / (1.0 + upgrades.haste * 0.3)
		var nearest: Dictionary = {}
		var best_distance = 64.0
		for e in enemies:
			var distance = player.distance_squared_to(e.p)
			if e.hp > 0.0 and distance < best_distance:
				nearest = e
				best_distance = distance
		if not nearest.is_empty():
			damage(nearest, 1.0, "weapon")
			nearest.p += (nearest.p - player).normalized() * 1.6
			effect("shot", player, {"to": nearest.p, "life": 0.15, "max_life": 0.15})
	for i in range(regions.size() - 1, -1, -1):
		var r = regions[i]
		r.life -= dt
		if r.life <= 0.0:
			regions.remove_at(i)
			continue
		r.shot -= dt
		if r.shot > 0.0:
			continue
		r.shot = 0.65
		var targets: Array = []
		for e in candidates(r.poly):
			if e.hp > 0.0 and Geo.contains(e.p, r.poly):
				targets.append(e)
		if targets.is_empty():
			# Fallback to the nearest enemy within 2m of the actual boundary.
			var nearest: Dictionary = {}
			var best_distance = 4.0
			for e in enemies:
				if e.hp <= 0.0:
					continue
				for j in r.poly.size():
					var point = Geometry2D.get_closest_point_to_segment(e.p, r.poly[j], r.poly[(j + 1) % r.poly.size()])
					var distance = point.distance_squared_to(e.p)
					if distance < best_distance:
						nearest = e
						best_distance = distance
			if not nearest.is_empty():
				targets.append(nearest)
		for j in mini(targets.size(), 2 + upgrades.territory):
			damage(targets[j], 1.0 + upgrades.territory * 0.5, "territory")
			effect("stage_shot", r.center, {"to": targets[j].p, "life": 0.15, "max_life": 0.15})
	for i in range(pickups.size() - 1, -1, -1):
		if pickups[i].p.distance_squared_to(player) < 2.25:
			xp += pickups[i].value
			total_collected += pickups[i].value
			pickups.remove_at(i)
	enemies = enemies.filter(func(e): return e.hp > 0.0)
	spawn_clock -= dt
	if spawn_clock <= 0.0 and enemies.size() < CAP:
		spawn_clock = 1.0 / (2.5 + clock / 20.0)
		var angle = rng.randf() * TAU
		var at = player + Vector2.from_angle(angle) * rng.randf_range(12.0, 18.0)
		at = at.clamp(Vector2(-21, -13), Vector2(21, 13))
		if at.distance_squared_to(player) > 25.0:
			spawn_enemy(at)
	# Death wins ties. The prototype's timed result is not the product's boss victory.
	if hp <= 0.0:
		hp = 0.0
		state = "lost"
	elif clock >= LIMIT:
		state = "won"
	else:
		check_level()
