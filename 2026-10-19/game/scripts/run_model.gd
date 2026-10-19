extends RefCounted
## Production simulation. Rendering, wall clocks and input never mutate this history.

const Timeline = preload("res://scripts/echo_timeline.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const DURATION := 180.0
const PLAYER_RADIUS := 14.0
const MAX_ENEMIES := 145

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
	if absf(direction.x) > 0.01:
		facing = signf(direction.x)
	timeline.record_position(elapsed, player)
	echo_active = elapsed >= Timeline.DELAY
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
	var toughness := 1.0 + maxf(0.0, elapsed - 45.0) / 170.0
	var hp := 10.0
	var enemy_speed := 66.0
	var radius := 17.0
	match kind:
		"charger":
			hp = 30.0
			enemy_speed = 63.0
			radius = 22.0
		"archer":
			hp = 21.0
			enemy_speed = 57.0
			radius = 19.0
	var enemy := {
		"id": next_enemy_id, "kind": kind, "position": at,
		"hp": hp * toughness, "max_hp": hp * toughness,
		"speed": enemy_speed + minf(elapsed * 0.10, 18.0), "radius": radius,
		"phase": "arrival", "timer": 0.55, "cooldown": 1.6 + rng.randf() * 0.8,
		"direction": Vector2.DOWN, "flash": 0.0
	}
	next_enemy_id += 1
	enemies.append(enemy)
	return enemy

func _update_spawning(dt: float) -> void:
	spawn_clock -= dt
	if spawn_clock > 0.0:
		return
	var interval := lerpf(0.94, 0.18, pow(elapsed / DURATION, 0.85))
	spawn_clock += interval
	if enemies.size() >= MAX_ENEMIES:
		return
	var group := 1
	if elapsed > 90.0 and rng.randf() < 0.43:
		group = 2
	if elapsed > 145.0 and rng.randf() < 0.40:
		group = 3
	var angle := rng.randf() * TAU
	for i in range(group):
		if enemies.size() >= MAX_ENEMIES:
			break
		var kind := "hound"
		var roll := rng.randf()
		if elapsed > 24.0 and roll < 0.19:
			kind = "charger"
		elif elapsed > 48.0 and roll < 0.34:
			kind = "archer"
		var offset := Vector2.from_angle(angle + float(i) * 0.13) * rng.randf_range(655.0, 735.0)
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
					projectiles.append({"kind": "bolt", "position": enemy.position, "velocity": (enemy.direction as Vector2) * 185.0, "age": 0.0, "duration": 4.8, "damage": 11.0})
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
		if (enemy.position as Vector2).distance_to(player) < float(enemy.radius) + PLAYER_RADIUS:
			take_damage(14.0 if enemy.phase == "rush" else 10.0)
		if state != "playing":
			return
	# Far-off enemies are repositioned outside view rather than accumulating forever.
	for enemy in enemies:
		if (enemy.position as Vector2).distance_to(player) > 1350.0:
			enemy.position = player + (enemy.position as Vector2).direction_to(player).rotated(rng.randf_range(-0.7, 0.7)) * 720.0
			enemy.phase = "arrival"
			enemy.timer = 0.7

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
			projectiles.append({"kind": "moon", "position": origin, "age": -0.18 * float(i), "duration": 0.72, "radius": float(payload.radius), "damage": float(payload.damage), "echo": is_echo, "hit_ids": []})
	if not is_echo:
		audio_events.append(str(payload.kind))

func _cast_lightning(payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	var targets := nearest_enemies(origin, float(payload.range))
	var count := mini(int(payload.count), targets.size())
	for i in range(count):
		var direction := origin.direction_to(targets[i].position)
		var end := origin + direction * float(payload.range)
		effects.append({"kind": "lightning", "from": origin, "to": end, "age": 0.0, "duration": 0.23, "width": float(payload.width), "echo": is_echo, "seed": rng.randi() % 10000})
		for enemy in enemies:
			if enemy.phase == "arrival" or float(enemy.hp) <= 0.0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position, origin, end)
			if closest.distance_to(enemy.position) <= float(payload.width) * 0.5 + float(enemy.radius):
				damage_enemy(enemy, float(payload.damage), direction, is_echo)

func damage_enemy(enemy: Dictionary, amount: float, direction: Vector2, is_echo: bool) -> void:
	if float(enemy.hp) <= 0.0:
		return
	enemy.hp = float(enemy.hp) - amount
	enemy.flash = 0.14
	if enemy.phase != "rush":
		enemy.position += direction * 12.0
	effects.append({"kind": "number", "position": enemy.position, "age": 0.0, "duration": 0.6, "text": str(int(amount)), "echo": is_echo})

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
					damage_enemy(enemy, float(shot.damage), offset.normalized(), bool(shot.echo))

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
	experience_needed = 5 + (level - 1) * 4
	choices = Spellbook.offers(weapons, level, speed, maximum_health, rng)
	state = "upgrade"
	audio_events.append("level")

func choose_upgrade(index: int) -> bool:
	if state != "upgrade" or index < 0 or index >= choices.size():
		return false
	var id := str(choices[index].id)
	if id == "stride":
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
		enemy_info.append({"id": enemy.id, "kind": enemy.kind, "x": snappedf(enemy.position.x, 0.1), "y": snappedf(enemy.position.y, 0.1), "phase": enemy.phase, "hp": snappedf(enemy.hp, 0.1)})
	return {
		"state": state, "elapsed": elapsed, "health": health, "maximum_health": maximum_health,
		"level": level, "kills": kills, "experience": experience, "experience_needed": experience_needed,
		"player": {"x": player.x, "y": player.y}, "echo": {"x": echo.x, "y": echo.y, "active": echo_active},
		"enemy_count": enemies.size(), "enemies": enemy_info, "weapons": weapons.duplicate(true),
		"player_shots": player_shots, "echo_shots": echo_shots, "projectiles": projectiles.size(),
		"pickups": pickups.size(), "effects": effects.size(), "pending_echo_attacks": timeline.attacks.size(),
		"history_samples": timeline.positions.size(), "last_player_attack": last_player_attack.duplicate(true),
		"last_echo_attack": last_echo_attack.duplicate(true), "choices": choices.duplicate(true), "damage_taken": damage_taken
	}
