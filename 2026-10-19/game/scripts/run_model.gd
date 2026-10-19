extends RefCounted
## Production simulation. Rendering, wall clocks and input never mutate this history.

const Timeline = preload("res://scripts/echo_timeline.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const DURATION := 180.0
const PLAYER_RADIUS := 14.0
const MAX_ENEMIES := 145
const RESONANCE_DISTANCE := 100.0
const RESONANCE_WINDOW := 2.5
const RESONANCE_COOLDOWN := 2.5
const PHASE_NAMES := ["残像の目覚め", "獣の足音", "月下の射手", "交差する牙", "庭園の包囲", "夜明けの大群"]
const PHASE_HINTS := ["道を分け、二人で狙おう", "正面の群れに道を譲ろう", "赤い射線を横にかわそう", "突進と射線の間を抜けよう", "囲いの薄い場所を探そう", "二人の魔法で夜明けを迎えよう"]

var state := "title"
var pause_reason := ""
var elapsed := 0.0
var player := Vector2.ZERO
var echo := Vector2.ZERO
var facing := 1.0
var echo_active := false
var health := 100.0
var maximum_health := 100.0
var invulnerable := 0.0
var speed := 215.0
var pickup_radius := 172.0
var level := 1
var experience := 0
var experience_needed := 5
var kills := 0
var player_shots := 0
var echo_shots := 0
var weapons: Dictionary = {}
var cooldowns: Dictionary = {}
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var choices: Array[Dictionary] = []
var audio_events: Array[String] = []
var last_player_attack: Dictionary = {}
var last_echo_attack: Dictionary = {}
var timeline = Timeline.new()
var rng := RandomNumberGenerator.new()
var spawn_clock := 0.0
var next_enemy_id := 1
var damage_taken := 0.0
var specialization := "未選択"
var resonance_hits := 0
var resonance_kills := 0
var resonance_bonus := 12.0
var last_movement := Vector2.RIGHT
var wave_number := 0

func _init() -> void:
	reset(false)

func reset(begin_playing: bool = true, seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	state = "playing" if begin_playing else "title"
	pause_reason = ""
	elapsed = 0.0
	player = Vector2.ZERO
	echo = Vector2.ZERO
	facing = 1.0
	echo_active = false
	health = 100.0
	maximum_health = 100.0
	invulnerable = 0.0
	speed = 215.0
	pickup_radius = 172.0
	level = 1
	experience = 0
	experience_needed = 5
	kills = 0
	player_shots = 0
	echo_shots = 0
	damage_taken = 0.0
	specialization = "未選択"
	resonance_hits = 0
	resonance_kills = 0
	resonance_bonus = 12.0
	last_movement = Vector2.RIGHT
	wave_number = 0
	weapons = Spellbook.initial_weapons()
	cooldowns = {"lightning": 0.25, "moon": 0.6}
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	effects.clear()
	choices.clear()
	audio_events.clear()
	last_player_attack.clear()
	last_echo_attack.clear()
	spawn_clock = 0.8
	next_enemy_id = 1
	timeline.reset(player)
	if begin_playing:
		# Nearby, harmless arrivals make the first cast and echo visible immediately.
		for i in range(5):
			var angle := -PI * 0.5 + float(i) * TAU / 5.0
			spawn_enemy("hound", Vector2.from_angle(angle) * (260.0 + float(i % 2) * 35.0))

func pause(reason: String = "") -> void:
	if state == "playing":
		state = "paused"
		pause_reason = reason

func resume() -> void:
	if state == "paused":
		state = "playing"
		pause_reason = ""

func tick(delta: float, movement: Vector2 = Vector2.ZERO) -> void:
	if state != "playing" or delta <= 0.0:
		return
	var dt := minf(delta, DURATION - elapsed)
	elapsed += dt
	invulnerable = maxf(0.0, invulnerable - dt)
	var direction := movement.limit_length()
	player += direction * speed * dt
	if direction.length_squared() > 0.01:
		last_movement = direction.normalized()
	if absf(direction.x) > 0.01:
		facing = signf(direction.x)
	timeline.record_position(elapsed, player)
	echo_active = elapsed + 0.000001 >= Timeline.DELAY
	if echo_active:
		echo = timeline.position_at(elapsed - Timeline.DELAY)
	_update_effects(dt)
	_update_spawning(dt)
	_update_enemies(dt)
	if state != "playing":
		return
	_update_projectiles(dt)
	if state != "playing":
		return
	_update_weapons(dt)
	for payload in timeline.consume_attacks(elapsed):
		cast(payload, echo, true)
	_cleanup_dead()
	_update_pickups(dt)
	if health <= 0.0:
		_finish("defeat")
	elif elapsed >= DURATION:
		_finish("victory")

func _finish(result: String) -> void:
	state = result
	audio_events.append("victory" if result == "victory" else "defeat")

func spawn_enemy(kind: String, at: Vector2) -> Dictionary:
	var toughness := 1.0 + maxf(0.0, elapsed - 45.0) / 270.0
	var hp := 28.0
	var enemy_speed := 88.0
	var radius := 17.0
	match kind:
		"charger":
			hp = 48.0
			enemy_speed = 78.0
			radius = 22.0
		"archer":
			hp = 34.0
			enemy_speed = 72.0
			radius = 19.0
	var enemy := {
		"id": next_enemy_id, "kind": kind, "position": at,
		"hp": hp * toughness, "max_hp": hp * toughness,
		"speed": enemy_speed + minf(elapsed * 0.14, 24.0), "radius": radius,
		"phase": "arrival", "timer": 0.9, "arrival_duration": 0.9, "contact_ready_at": elapsed + 1.1, "cooldown": 1.6 + rng.randf() * 0.8,
		"direction": Vector2.DOWN, "flash": 0.0, "mark": {}, "resonance_ready_at": 0.0, "resonance_rewarded": false
	}
	next_enemy_id += 1
	enemies.append(enemy)
	return enemy

func phase_info() -> Dictionary:
	var index := mini(5, int(elapsed / 30.0))
	var local := elapsed - float(index) * 30.0
	var assault := local < 22.0 and elapsed < DURATION
	return {"index": index, "name": PHASE_NAMES[index], "subtitle": PHASE_HINTS[index] if assault else "攻勢が緩む。経験値を拾おう", "remaining": maxf(0.0, (22.0 if assault else 30.0) - local), "assault": assault}

func _update_spawning(dt: float) -> void:
	spawn_clock -= dt
	if spawn_clock > 0.0:
		return
	var phase := phase_info()
	var index := int(phase.index)
	if not phase.assault:
		spawn_clock = 3.2
		if enemies.size() < MAX_ENEMIES:
			spawn_enemy("hound", player + Vector2.from_angle(rng.randf() * TAU) * 580.0)
		return
	var intervals := [1.2, 1.10, 1.0, 0.87, 0.76, 0.64]
	spawn_clock = float(intervals[index])
	if enemies.size() >= MAX_ENEMIES:
		return
	var group := 2 + index / 2
	var pattern := wave_number % 4
	wave_number += 1
	var forward := last_movement.normalized()
	var sideways := forward.orthogonal()
	var angle := rng.randf() * TAU
	for i in range(group):
		if enemies.size() >= MAX_ENEMIES:
			break
		var kind := "hound"
		var roll := rng.randf()
		if index >= 1 and roll < 0.18:
			kind = "charger"
		elif index >= 2 and roll < 0.36:
			kind = "archer"
		var offset: Vector2
		if pattern == 0:
			# A visible row ahead asks the player to turn, not keep running forever.
			offset = forward * 500.0 + sideways * (float(i) - float(group - 1) * 0.5) * 82.0
		elif pattern == 2:
			var side := -1.0 if (wave_number / 4) % 2 == 0 else 1.0
			offset = sideways * side * 500.0 + forward * (float(i) - float(group - 1) * 0.5) * 85.0
		else:
			offset = Vector2.from_angle(angle + float(i) * 0.16) * rng.randf_range(480.0, 620.0)
		spawn_enemy(kind, player + offset)

func _update_enemies(dt: float) -> void:
	for enemy in enemies:
		if float(enemy.hp) <= 0.0:
			continue
		enemy.flash = maxf(0.0, float(enemy.flash) - dt)
		enemy.cooldown = float(enemy.cooldown) - dt
		var to_player: Vector2 = player - (enemy.position as Vector2)
		var distance := to_player.length()
		if enemy.phase == "arrival":
			enemy.timer = float(enemy.timer) - dt
			if float(enemy.timer) <= 0.0:
				enemy.phase = "seek"
			continue
		if enemy.phase == "warning":
			enemy.timer = float(enemy.timer) - dt
			if float(enemy.timer) <= 0.0:
				if enemy.kind == "charger":
					enemy.phase = "rush"
					enemy.timer = 0.67
				else:
					projectiles.append({"kind": "bolt", "position": enemy.position, "velocity": (enemy.direction as Vector2) * 240.0, "age": 0.0, "duration": 4.0, "damage": 10.0})
					enemy.phase = "seek"
					enemy.cooldown = 2.65
		elif enemy.phase == "rush":
			enemy.position += (enemy.direction as Vector2) * 440.0 * dt
			enemy.timer = float(enemy.timer) - dt
			if float(enemy.timer) <= 0.0:
				enemy.phase = "recover"
				enemy.timer = 0.7
				enemy.cooldown = 2.6
		elif enemy.phase == "recover":
			enemy.timer = float(enemy.timer) - dt
			if float(enemy.timer) <= 0.0:
				enemy.phase = "seek"
		else:
			if enemy.kind == "charger" and distance < 455.0 and float(enemy.cooldown) <= 0.0:
				enemy.phase = "warning"
				enemy.timer = 0.95
				enemy.direction = to_player.normalized()
			elif enemy.kind == "archer" and distance < 490.0 and float(enemy.cooldown) <= 0.0:
				enemy.phase = "warning"
				enemy.timer = 0.95
				enemy.direction = to_player.normalized()
			else:
				var walk := to_player.normalized()
				if enemy.kind == "archer" and distance < 340.0:
					walk = walk.rotated(PI * 0.5) * 0.6
				if enemy.kind == "archer" and distance < 205.0:
					walk = -to_player.normalized()
				enemy.position += walk * float(enemy.speed) * dt
		if elapsed >= float(enemy.get("contact_ready_at", 0.0)) and (enemy.position as Vector2).distance_to(player) < float(enemy.radius) + PLAYER_RADIUS:
			take_damage(12.0 if enemy.phase == "rush" else 8.0)
		if state != "playing":
			return
	# Far-off enemies are repositioned outside view rather than accumulating forever.
	for enemy in enemies:
		if (enemy.position as Vector2).distance_to(player) > 1150.0:
			enemy.position = player + (enemy.position as Vector2).direction_to(player).rotated(rng.randf_range(-0.7, 0.7)) * 600.0
			enemy.phase = "arrival"
			enemy.timer = 0.9
			enemy.arrival_duration = 0.9
			enemy.contact_ready_at = elapsed + 1.1

func take_damage(amount: float) -> void:
	if state != "playing" or invulnerable > 0.0:
		return
	health = maxf(0.0, health - amount)
	damage_taken += amount
	invulnerable = 0.85
	effects.append({"kind": "hurt", "position": player, "age": 0.0, "duration": 0.35})
	audio_events.append("damage")
	if health <= 0.0:
		_finish("defeat")

func _update_weapons(dt: float) -> void:
	for kind in ["lightning", "moon"]:
		if int(weapons[kind].level) <= 0:
			continue
		cooldowns[kind] = float(cooldowns[kind]) - dt
		if float(cooldowns[kind]) > 0.0:
			continue
		if kind == "lightning" and nearest_enemies(player, float(weapons[kind].range)).is_empty():
			continue
		cooldowns[kind] = float(weapons[kind].cooldown)
		var payload: Dictionary = weapons[kind].duplicate(true)
		payload.kind = kind
		payload.resonance_bonus = resonance_bonus
		cast(payload, player, false)

func nearest_enemies(origin: Vector2, reach: float) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for enemy in enemies:
		if float(enemy.hp) > 0.0 and enemy.phase != "arrival" and (enemy.position as Vector2).distance_to(origin) <= reach:
			targets.append(enemy)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.position as Vector2).distance_squared_to(origin) < (b.position as Vector2).distance_squared_to(origin))
	return targets

func cast(payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	# Echo casts never pass through record_attack, so the echo cannot record itself.
	if is_echo:
		echo_shots += 1
		last_echo_attack = payload.duplicate(true)
	else:
		player_shots += 1
		last_player_attack = payload.duplicate(true)
		timeline.record_attack(elapsed, payload)
	if payload.kind == "lightning":
		_cast_lightning(payload, origin, is_echo)
	else:
		for i in range(int(payload.count)):
			projectiles.append({"kind": "moon", "position": origin, "age": -0.18 * float(i), "duration": 0.72, "radius": float(payload.radius), "damage": float(payload.damage), "echo": is_echo, "hit_ids": [], "resonance_bonus": float(payload.get("resonance_bonus", resonance_bonus))})
	if not is_echo:
		audio_events.append(str(payload.kind))

func _cast_lightning(payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	var targets := nearest_enemies(origin, float(payload.range))
	var count := mini(int(payload.count), targets.size())
	var hit_ids: Array[int] = []
	for i in range(count):
		var direction := origin.direction_to(targets[i].position)
		var end := origin + direction * float(payload.range)
		effects.append({"kind": "lightning", "from": origin, "to": end, "age": 0.0, "duration": 0.23, "width": float(payload.width), "echo": is_echo, "seed": rng.randi() % 10000})
		for enemy in enemies:
			if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or hit_ids.has(int(enemy.id)):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position, origin, end)
			if closest.distance_to(enemy.position) <= float(payload.width) * 0.5 + float(enemy.radius):
				hit_ids.append(int(enemy.id))
				damage_enemy(enemy, float(payload.damage), direction, is_echo, origin, float(payload.get("resonance_bonus", resonance_bonus)))

func damage_enemy(enemy: Dictionary, amount: float, direction: Vector2, is_echo: bool, origin: Vector2 = Vector2.INF, bonus: float = -1.0) -> void:
	if float(enemy.hp) <= 0.0:
		return
	if origin == Vector2.INF:
		origin = echo if is_echo else player
	if bonus < 0.0:
		bonus = resonance_bonus
	var source := "echo" if is_echo else "player"
	var mark: Dictionary = enemy.get("mark", {})
	var resonance := echo_active and player.distance_to(echo) >= RESONANCE_DISTANCE
	resonance = resonance and not mark.is_empty() and str(mark.get("source", source)) != source
	resonance = resonance and elapsed <= float(mark.get("expires", -1.0)) + 0.000001
	resonance = resonance and elapsed >= float(enemy.get("resonance_ready_at", 0.0))
	enemy.hp = float(enemy.hp) - amount - (bonus if resonance else 0.0)
	enemy.flash = 0.14
	enemy.mark = {"source": source, "time": elapsed, "expires": elapsed + RESONANCE_WINDOW, "position": origin}
	if enemy.phase != "rush":
		enemy.position += direction * 12.0
	effects.append({"kind": "number", "position": enemy.position, "age": 0.0, "duration": 0.6, "text": str(int(amount)), "echo": is_echo})
	if resonance:
		resonance_hits += 1
		if float(enemy.hp) <= 0.0:
			resonance_kills += 1
		enemy.resonance_ready_at = elapsed + RESONANCE_COOLDOWN
		# The same survivor cannot be farmed for endless XP or self-trigger a chain.
		if not bool(enemy.get("resonance_rewarded", false)):
			experience += 1
			enemy.resonance_rewarded = true
		effects.append({"kind": "resonance", "position": enemy.position, "age": 0.0, "duration": 0.42, "damage": bonus, "echo": is_echo})
		audio_events.append("resonance")

func _cleanup_dead() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if float(enemy.hp) > 0.0:
			continue
		kills += 1
		var value := 1 if enemy.kind == "hound" else 2
		pickups.append({"position": enemy.position, "value": value})
		effects.append({"kind": "vanish", "position": enemy.position, "age": 0.0, "duration": 0.32})
		enemies.remove_at(i)
	while pickups.size() > 260:
		var oldest: Dictionary = pickups.pop_front()
		pickups[0].value = int(pickups[0].value) + int(oldest.value)

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		shot.age = float(shot.age) + dt
		if float(shot.age) > float(shot.duration):
			projectiles.remove_at(i)
			continue
		if shot.kind == "bolt":
			shot.position += (shot.velocity as Vector2) * dt
			if (shot.position as Vector2).distance_to(player) < PLAYER_RADIUS + 7.0:
				take_damage(float(shot.damage))
				projectiles.remove_at(i)
				if state != "playing":
					return
		elif float(shot.age) >= 0.0:
			var radius := float(shot.radius) * minf(1.0, float(shot.age) / 0.55)
			for enemy in enemies:
				if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or shot.hit_ids.has(enemy.id):
					continue
				var offset: Vector2 = (enemy.position as Vector2) - (shot.position as Vector2)
				if offset.length() <= radius + float(enemy.radius):
					shot.hit_ids.append(enemy.id)
					damage_enemy(enemy, float(shot.damage), offset.normalized(), bool(shot.echo), shot.position, float(shot.get("resonance_bonus", resonance_bonus)))

func _update_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		var distance := (pickup.position as Vector2).distance_to(player)
		if distance < pickup_radius:
			pickup.position = (pickup.position as Vector2).move_toward(player, (330.0 + (pickup_radius - distance) * 2.3) * dt)
		if (pickup.position as Vector2).distance_to(player) < 20.0:
			experience += int(pickup.value)
			pickups.remove_at(i)
			audio_events.append("pickup")
	check_level_up()

func check_level_up() -> void:
	if state != "playing" or experience < experience_needed:
		return
	experience -= experience_needed
	level += 1
	var late_level := maxi(0, level - 5)
	experience_needed = 5 + (level - 1) * 4 + 2 * late_level * late_level
	choices = Spellbook.offers(weapons, level, speed, maximum_health, rng, specialization)
	state = "upgrade"
	audio_events.append("level")

func choose_upgrade(index: int) -> bool:
	if state != "upgrade" or index < 0 or index >= choices.size():
		return false
	var id := str(choices[index].id)
	if id.begins_with("spec_"):
		if specialization != "未選択":
			return false
		specialization = Spellbook.specialize(id, weapons)
		if id == "spec_echo":
			resonance_bonus = 24.0
		if id == "spec_moon":
			cooldowns.moon = minf(float(cooldowns.moon), 0.12)
	elif id == "stride":
		speed += 18.0
		pickup_radius += 35.0
	elif id == "heal":
		maximum_health += 16.0
		health = minf(maximum_health, health + 36.0)
	else:
		Spellbook.apply(id, weapons)
		if id == "moon_unlock":
			cooldowns.moon = 0.12
	choices.clear()
	state = "playing"
	# A short grace interval prevents a stationary choice from causing an instant hit.
	invulnerable = maxf(invulnerable, 0.55)
	check_level_up()
	return true

func _update_effects(dt: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].age = float(effects[i].age) + dt
		if float(effects[i].age) >= float(effects[i].duration):
			effects.remove_at(i)
	while effects.size() > 160:
		effects.pop_front()

func drain_audio() -> Array[String]:
	var events := audio_events.duplicate()
	audio_events.clear()
	return events

func snapshot() -> Dictionary:
	var enemy_info: Array[Dictionary] = []
	for enemy in enemies:
		enemy_info.append({"id": enemy.id, "kind": enemy.kind, "x": snappedf(enemy.position.x, 0.1), "y": snappedf(enemy.position.y, 0.1), "phase": enemy.phase, "hp": snappedf(enemy.hp, 0.1), "mark_source": str(enemy.get("mark", {}).get("source", "")), "mark_expires": float(enemy.get("mark", {}).get("expires", 0.0))})
	return {
		"state": state, "elapsed": elapsed, "phase": phase_info(), "specialization": specialization, "resonance_hits": resonance_hits, "resonance_kills": resonance_kills, "resonance_bonus": resonance_bonus, "health": health, "maximum_health": maximum_health,
		"level": level, "kills": kills, "experience": experience, "experience_needed": experience_needed,
		"player": {"x": player.x, "y": player.y}, "echo": {"x": echo.x, "y": echo.y, "active": echo_active},
		"enemy_count": enemies.size(), "enemies": enemy_info, "weapons": weapons.duplicate(true),
		"player_shots": player_shots, "echo_shots": echo_shots, "projectiles": projectiles.size(),
		"pickups": pickups.size(), "effects": effects.size(), "pending_echo_attacks": timeline.attacks.size(),
		"history_samples": timeline.positions.size(), "last_player_attack": last_player_attack.duplicate(true),
		"last_echo_attack": last_echo_attack.duplicate(true), "choices": choices.duplicate(true), "damage_taken": damage_taken
	}
