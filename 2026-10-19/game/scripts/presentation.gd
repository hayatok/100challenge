extends RefCounted
## Read-only visual state. Every age and pose uses the simulation clock.

const ActorArt := preload("res://scripts/pixel_actors.gd")

const MAX_DEATHS := 24
const MAX_EVENTS := 80
const DEATH_DURATION := 0.45
const CAST_DURATION := 0.36
const HIT_DURATION := 0.22
const EPSILON := 0.000001
const EVENT_LIMITS := {"hit": 18, "cast": 10, "kill": 18, "resonance": 10, "collect": 8, "footstep": 8}

var player_pose: Dictionary = {}
var echo_pose: Dictionary = {}
var enemy_poses: Dictionary = {}
var deaths: Array[Dictionary] = []
var events: Array[Dictionary] = []
var camera_impulse := 0.0
var generation := 0
var latest_serial := 0

var _initialized := false
var _run_id := 0
var _properties: Dictionary = {}
var _clock := 0.0
var _chapter_clock := 0.0
var _chapter := 0
var _state := "title"
var _history: Variant = null
var _player: Dictionary = {}
var _echo: Dictionary = {}
var _enemies: Dictionary = {}
var _effect_counts: Dictionary = {}
var _pickups: Array = []
var _chests: Dictionary = {}
var _evolved: Dictionary = {}
var _player_shots := 0
var _echo_shots := 0
var _kills := 0
var _level := 1
var _damage_taken := 0.0
var _contact_damage := 0.0
var _health := 100.0
var _next_enemy_id := 0

func update(run) -> void:
	if run == null:
		clear()
		return
	if int(run.get_instance_id()) != _run_id:
		_properties.clear()
		for entry in run.get_property_list():
			_properties[str(entry.name)] = true
	var now := float(run.elapsed)
	var chapter_now := int(run.chapter)
	var local_now := float(run.chapter_elapsed)
	var state_now := str(run.state)
	if not is_finite(now) or not is_finite(local_now):
		return
	var history_now: Variant = _position_history(run)
	var chapter_changed := _initialized and chapter_now != _chapter
	if _needs_reset(run, now, local_now, state_now, history_now):
		var show_chapter := chapter_changed and state_now != "title"
		_begin(run, history_now)
		if show_chapter:
			_emit("chapter", run.player, {"chapter": chapter_now, "clear": false}, 1.1, 3)
		return
	if state_now == "title":
		return
	var dt := maxf(0.0, now - _clock)
	_clock = now
	_chapter_clock = local_now
	_age_feedback(dt)
	var fresh_effects := _new_effects(run.effects)
	var shot_count := int(_read(run, "player_shots", 0))
	var echo_count := int(_read(run, "echo_shots", 0))
	_move_actor(_player, run.player, dt, true, false)
	if bool(run.echo_active):
		_move_actor(_echo, run.echo, dt, true, true)
	else:
		_echo.position = run.echo
		_echo.pose.moving = false
		_echo.pose.velocity = Vector2.ZERO
		_age_actor(_echo, dt)
	if shot_count > _player_shots:
		_cast(_player, run.player, false, _read(run, "last_player_attack", {}), shot_count)
	if echo_count > _echo_shots:
		_cast(_echo, run.echo, true, _read(run, "last_echo_attack", {}), echo_count)
	var damage_now := float(_read(run, "damage_taken", 0.0))
	var received: Dictionary = _read(run, "damage_received", {})
	var contact_now := float(received.get("contact", 0.0))
	var health_now := float(_read(run, "health", _health))
	# Health-cap adjustments are not damage. Only counter-less fixtures infer it.
	var player_damage := damage_now - _damage_taken if _properties.has("damage_taken") else _health - health_now
	if player_damage > EPSILON:
		_player.hit_age = 0.0
		_emit("hit", run.player, {"target": "player", "actor": "player", "amount": player_damage}, HIT_DURATION, 2)
		camera_impulse = maxf(camera_impulse, 0.8)
	var contact_id := _contact_attacker(run) if contact_now > _contact_damage + EPSILON else -1
	_update_enemies(run, dt, fresh_effects, contact_id)
	_collect_feedback(run, fresh_effects)
	_track_pickups(run)
	_track_chests(run)
	_track_evolutions(run)
	var level_now := int(_read(run, "level", 1))
	if level_now > _level:
		_emit("level", run.player, {"level": level_now}, 1.05, 3)
	if state_now != _state:
		if state_now in ["victory", "defeat"]:
			_emit(state_now, run.player, {"chapter": chapter_now}, 1.4, 4)
			camera_impulse = maxf(camera_impulse, 1.0)
		elif state_now == "chapter_clear":
			_emit("chapter", run.player, {"chapter": chapter_now, "clear": true}, 1.1, 3)
	_pose(_player, dt)
	_pose(_echo, dt)
	if state_now == "defeat":
		# The terminal screen freezes the game clock; hold the collapsed last pose.
		player_pose.animation = "death"
		player_pose.time = DEATH_DURATION
		player_pose.phase_progress = 1.0
	_state = state_now
	_player_shots = shot_count
	_echo_shots = echo_count
	_kills = int(_read(run, "kills", 0))
	_level = level_now
	_damage_taken = damage_now
	_contact_damage = contact_now
	_health = health_now
	_next_enemy_id = int(_read(run, "next_enemy_id", 0))

func clear() -> void:
	if _initialized:
		generation += 1
	latest_serial = 0
	_initialized = false
	_run_id = 0
	_clock = 0.0
	_chapter_clock = 0.0
	_chapter = 0
	_state = "title"
	_properties.clear()
	_history = null
	_player.clear()
	_echo.clear()
	_enemies.clear()
	_effect_counts.clear()
	_pickups.clear()
	_chests.clear()
	_evolved.clear()
	player_pose.clear()
	echo_pose.clear()
	enemy_poses.clear()
	deaths.clear()
	events.clear()
	camera_impulse = 0.0

func _read(run, key: String, fallback: Variant) -> Variant:
	# Renderer fixtures may omit optional counters, inventories, or the timeline.
	return run.get(key) if _properties.has(key) else fallback

func _position_history(run) -> Variant:
	var timeline: Variant = _read(run, "timeline", null)
	return timeline.positions if timeline != null else null

func _needs_reset(run, now: float, local_now: float, state_now: String, history_now: Variant) -> bool:
	if not _initialized or int(run.get_instance_id()) != _run_id or int(run.chapter) != _chapter:
		return true
	if now < _clock - EPSILON or local_now < _chapter_clock - EPSILON:
		return true
	if state_now == "title" and _state != "title":
		return true
	if _state in ["title", "victory", "defeat"] and state_now == "playing":
		return true
	if _history != null and history_now != null and not is_same(_history, history_now):
		return true
	return int(_read(run, "player_shots", 0)) < _player_shots or int(_read(run, "echo_shots", 0)) < _echo_shots or int(_read(run, "kills", 0)) < _kills or int(_read(run, "level", 1)) < _level or int(_read(run, "next_enemy_id", 0)) < _next_enemy_id

func _begin(run, history_now: Variant) -> void:
	generation += 1
	latest_serial = 0
	deaths.clear()
	events.clear()
	enemy_poses.clear()
	_enemies.clear()
	_effect_counts.clear()
	_pickups.clear()
	_chests.clear()
	_evolved.clear()
	camera_impulse = 0.0
	_initialized = true
	_run_id = int(run.get_instance_id())
	_clock = float(run.elapsed)
	_chapter_clock = float(run.chapter_elapsed)
	_chapter = int(run.chapter)
	_state = str(run.state)
	_history = history_now
	_player_shots = int(_read(run, "player_shots", 0))
	_echo_shots = int(_read(run, "echo_shots", 0))
	_kills = int(_read(run, "kills", 0))
	_level = int(_read(run, "level", 1))
	_damage_taken = float(_read(run, "damage_taken", 0.0))
	var received: Dictionary = _read(run, "damage_received", {})
	_contact_damage = float(received.get("contact", 0.0))
	_health = float(_read(run, "health", 100.0))
	_next_enemy_id = int(_read(run, "next_enemy_id", 0))
	_player = _actor("witch", run.player, float(_read(run, "facing", 1.0)))
	_echo = _actor("witch", run.echo, 1.0)
	player_pose = _player.pose
	echo_pose = _echo.pose
	if _state == "defeat":
		player_pose.animation = "death"
		player_pose.time = DEATH_DURATION
		player_pose.phase_progress = 1.0
	if _state == "title":
		return
	for enemy in run.enemies:
		var record := _enemy_record(enemy)
		_enemies[int(enemy.id)] = record
		enemy_poses[int(enemy.id)] = record.pose
		_enemy_pose(record, enemy, 0.0)
	_new_effects(run.effects)
	_pickups = _read(run, "pickups", []).duplicate()
	for chest in _read(run, "chests", []):
		_chests[int(chest.id)] = bool(chest.get("opened", false))
	var weapons: Dictionary = _read(run, "weapons", {})
	for key in weapons:
		_evolved[str(key)] = bool(weapons[key].get("evolved", false))

func _actor(kind: String, at: Vector2, direction: float) -> Dictionary:
	return {"kind": kind, "position": at, "cast_age": CAST_DURATION, "hit_age": HIT_DURATION, "step_distance": 0.0,
		"pose": {"kind": kind, "animation": "idle", "time": 0.0, "gait": 0.0, "facing": -1 if direction < 0.0 else 1, "cast": 0.0, "hit": 0.0, "phase_progress": 0.0, "moving": false, "velocity": Vector2.ZERO, "phase": "seek", "phase_index": 1}}

func _enemy_record(enemy: Dictionary) -> Dictionary:
	var record := _actor(str(enemy.kind), enemy.position, (enemy.get("direction", Vector2.RIGHT) as Vector2).x)
	record.id = int(enemy.id)
	record.hp = float(enemy.get("hp", 0.0))
	record.flash = float(enemy.get("flash", 0.0))
	record.stagger = float(enemy.get("stagger", 0.0))
	record.phase = str(enemy.get("phase", "seek"))
	record.phase_index = int(enemy.get("phase_index", 1))
	record.boss = bool(enemy.get("boss", false))
	record.elite = bool(enemy.get("elite", false))
	record.radius = float(enemy.get("radius", 17.0))
	record.speed = float(enemy.get("speed", 0.0))
	record.size = _size(str(enemy.kind)) * (1.22 if record.elite else 1.0)
	return record

func _age_actor(record: Dictionary, dt: float) -> void:
	record.cast_age = minf(CAST_DURATION, float(record.cast_age) + dt)
	record.hit_age = minf(HIT_DURATION, float(record.hit_age) + dt)

func _move_actor(record: Dictionary, at: Vector2, dt: float, steps: bool = false, is_echo: bool = false) -> void:
	_age_actor(record, dt)
	if dt > EPSILON:
		var displacement := at - (record.position as Vector2)
		var distance := displacement.length()
		var pose: Dictionary = record.pose
		pose.moving = distance > 0.001
		pose.velocity = displacement / dt
		if absf(displacement.x) > 0.001:
			pose.facing = -1 if displacement.x < 0.0 else 1
		var stride := _stride(str(record.kind))
		pose.gait = fposmod(float(pose.gait) + distance / stride, 1.0)
		if steps and bool(pose.moving):
			record.step_distance = float(record.step_distance) + distance
			if float(record.step_distance) >= stride * 0.5:
				record.step_distance = fposmod(float(record.step_distance), stride * 0.5)
				_emit("footstep", at, {"actor": "echo" if is_echo else "player", "echo": is_echo, "facing": int(pose.facing), "step": 0 if float(pose.gait) < 0.5 else 1}, 0.32, 0)
	record.position = at

func _cast(record: Dictionary, at: Vector2, is_echo: bool, attack: Dictionary, serial: int) -> void:
	record.cast_age = 0.0
	_emit("cast", at, {"actor": "echo" if is_echo else "player", "echo": is_echo, "weapon": str(attack.get("kind", "lightning")), "evolved": bool(attack.get("evolved", false)), "cast_serial": serial, "facing": int(record.pose.facing)}, CAST_DURATION, 0)

func _pose(record: Dictionary, dt: float, phase: String = "seek", timer: float = 0.0, duration: float = 1.0, flash: float = 0.0, stagger: float = 0.0) -> void:
	var pose: Dictionary = record.pose
	pose.cast = clampf(1.0 - float(record.cast_age) / CAST_DURATION, 0.0, 1.0)
	pose.hit = maxf(clampf(1.0 - float(record.hit_age) / HIT_DURATION, 0.0, 1.0), maxf(clampf(flash / 0.14, 0.0, 1.0), clampf(stagger / 0.45, 0.0, 1.0)))
	pose.phase = phase
	var animation := "walk" if bool(pose.moving) else "idle"
	var progress := 0.0
	var local_time := float(pose.time) + dt
	if phase in ["arrival", "warning", "rush", "recover"]:
		animation = phase
		local_time = maxf(0.0, duration - maxf(0.0, timer))
		progress = clampf(local_time / maxf(EPSILON, duration), 0.0, 1.0)
	elif float(pose.hit) > EPSILON:
		animation = "hit"
		local_time = float(record.hit_age)
		progress = clampf(local_time / HIT_DURATION, 0.0, 1.0)
	elif float(pose.cast) > EPSILON:
		animation = "cast"
		local_time = float(record.cast_age)
		progress = clampf(local_time / CAST_DURATION, 0.0, 1.0)
	elif animation != str(pose.animation):
		local_time = 0.0
	pose.animation = animation
	pose.time = local_time
	pose.phase_progress = progress

func _enemy_pose(record: Dictionary, enemy: Dictionary, dt: float) -> void:
	var phase := str(enemy.get("phase", "seek"))
	if phase == "warning" or float(record.cast_age) < CAST_DURATION:
		var aim: Vector2 = enemy.get("direction", Vector2.ZERO)
		if absf(aim.x) > 0.001:
			record.pose.facing = -1 if aim.x < 0.0 else 1
	var duration := 1.0
	match phase:
		"arrival": duration = float(enemy.get("arrival_duration", 2.0 if bool(record.boss) else 0.9))
		"warning": duration = float(enemy.get("warning_duration", 1.05 if bool(record.boss) else 0.8 if str(record.kind) == "sentinel" else 0.95))
		"rush": duration = 0.67
		"recover": duration = 0.7
	_pose(record, dt, phase, float(enemy.get("timer", 0.0)), duration, float(enemy.get("flash", 0.0)), float(enemy.get("stagger", 0.0)))
	record.pose.phase_index = int(enemy.get("phase_index", 1))

func _contact_attacker(run) -> int:
	var cause := str(_read(run, "last_damage_cause", ""))
	var closest := -1
	var closest_distance := INF
	for enemy in run.enemies:
		if str(enemy.kind) != cause or str(enemy.get("phase", "seek")) == "arrival":
			continue
		var distance := (enemy.position as Vector2).distance_to(run.player)
		if distance < float(enemy.get("radius", 17.0)) + 14.0 and distance < closest_distance:
			closest = int(enemy.id)
			closest_distance = distance
	return closest

func _update_enemies(run, dt: float, fresh_effects: Array[Dictionary], contact_id: int) -> void:
	var present: Dictionary = {}
	for enemy in run.enemies:
		var id := int(enemy.id)
		present[id] = true
		if not _enemies.has(id):
			var added := _enemy_record(enemy)
			_enemies[id] = added
			enemy_poses[id] = added.pose
			if bool(added.boss):
				_emit("boss_arrival", enemy.position, _boss_fields(run, enemy), 1.2, 4)
				camera_impulse = maxf(camera_impulse, 0.7)
		var record: Dictionary = _enemies[id]
		_move_actor(record, enemy.position, dt)
		var hp := float(enemy.get("hp", 0.0))
		var flash := float(enemy.get("flash", 0.0))
		var stagger := float(enemy.get("stagger", 0.0))
		if flash > float(record.flash) + EPSILON or (hp < float(record.hp) - EPSILON and flash > 0.0) or stagger > float(record.stagger) + EPSILON:
			record.hit_age = 0.0
			var mark: Dictionary = enemy.get("mark", {})
			_emit("hit", enemy.position, {"target": "enemy", "actor": "enemy", "id": id, "actor_kind": str(enemy.kind), "boss": bool(record.boss), "echo": str(mark.get("source", "")) == "echo", "amount": maxf(0.0, float(record.hp) - hp)}, HIT_DURATION, 0)
		var phase := str(enemy.get("phase", "seek"))
		if (str(record.phase) == "warning" and phase == "seek") or id == contact_id:
			record.cast_age = 0.0
			_emit("cast", enemy.position, {"actor": "enemy", "id": id, "actor_kind": str(enemy.kind), "weapon": str(enemy.kind), "boss": bool(record.boss), "facing": int(record.pose.facing)}, CAST_DURATION, 0)
		if bool(record.boss) and int(enemy.get("phase_index", 1)) > int(record.phase_index):
			_emit("boss_phase", enemy.position, _boss_fields(run, enemy), 1.05, 4)
			camera_impulse = maxf(camera_impulse, 0.8)
		_enemy_pose(record, enemy, dt)
		record.phase = phase
		record.phase_index = int(enemy.get("phase_index", 1))
		record.hp = hp
		record.flash = flash
		record.stagger = stagger
	var vanished: Array[Dictionary] = []
	for effect in fresh_effects:
		if str(effect.get("kind", "")) == "vanish":
			vanished.append(effect)
	var kill_budget := maxi(0, int(_read(run, "kills", 0)) - _kills)
	for id in _enemies.keys():
		if present.has(id):
			continue
		var record: Dictionary = _enemies[id]
		var closest := -1
		var distance := maxf(70.0, float(record.radius) + 56.0 + float(record.speed) * dt)
		if kill_budget > 0:
			for i in range(vanished.size()):
				var candidate := (record.position as Vector2).distance_to(vanished[i].position)
				if candidate <= distance:
					distance = candidate
					closest = i
		if closest >= 0:
			_add_death(record, vanished[closest].position)
			vanished.remove_at(closest)
			kill_budget -= 1
		_enemies.erase(id)
		enemy_poses.erase(id)

func _boss_fields(run, enemy: Dictionary) -> Dictionary:
	var fields := {"actor": "enemy", "id": int(enemy.id), "actor_kind": str(enemy.kind), "boss_kind": str(enemy.kind), "boss": true, "phase": int(enemy.get("phase_index", 1)), "chapter": int(run.chapter)}
	if run.has_method("chapter_info"):
		var info: Dictionary = run.chapter_info()
		if info.has("boss_name"):
			fields.name = str(info.boss_name)
	return fields

func _add_death(record: Dictionary, at: Vector2) -> void:
	var pose: Dictionary = record.pose.duplicate()
	pose.animation = "death"
	pose.time = 0.0
	pose.phase_progress = 0.0
	pose.cast = 0.0
	pose.hit = 0.0
	pose.moving = false
	pose.velocity = Vector2.ZERO
	var death := {"id": int(record.id), "kind": str(record.kind), "position": at, "size": float(record.size), "radius": float(record.radius), "boss": bool(record.boss), "elite": bool(record.elite), "facing": int(pose.facing), "age": 0.0, "duration": DEATH_DURATION, "pose": pose}
	deaths.append(death)
	while deaths.size() > MAX_DEATHS:
		var victim := 0
		for i in range(deaths.size()):
			if not bool(deaths[i].boss):
				victim = i
				break
		deaths.remove_at(victim)
	_emit("kill", at, {"actor": "enemy", "id": int(record.id), "actor_kind": str(record.kind), "boss": bool(record.boss), "elite": bool(record.elite), "facing": int(pose.facing)}, 0.55 if bool(record.boss) else DEATH_DURATION, 3 if bool(record.boss) else 1)
	if bool(record.boss):
		camera_impulse = maxf(camera_impulse, 1.0)

func _effect_key(effect: Dictionary) -> String:
	var born := roundi((_clock - float(effect.get("age", 0.0))) * 1000000.0)
	return "%s|%d|%s|%s|%s|%s|%s|%s|%s" % [str(effect.get("kind", "")), born, str(effect.get("position", Vector2.ZERO)), str(effect.get("from", Vector2.ZERO)), str(effect.get("to", Vector2.ZERO)), str(effect.get("echo", false)), str(effect.get("text", "")), str(effect.get("damage", 0.0)), str(effect.get("duration", 0.0))]

func _new_effects(source: Array) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var fresh: Array[Dictionary] = []
	for effect in source:
		var key := _effect_key(effect)
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) > int(_effect_counts.get(key, 0)):
			fresh.append(effect)
	_effect_counts = counts
	return fresh

func _collect_feedback(run, fresh: Array[Dictionary]) -> void:
	for effect in fresh:
		var kind := str(effect.get("kind", ""))
		if kind in ["resonance", "shield", "blast"]:
			var extras := {"echo": bool(effect.get("echo", false)), "radius": float(effect.get("radius", 38.0)), "damage": float(effect.get("damage", 0.0))}
			_emit(kind, effect.get("position", run.player), extras, 0.55, 2)
			if kind == "resonance":
				camera_impulse = maxf(camera_impulse, 0.25)

func _pickup_key(pickup: Dictionary) -> String:
	return "%s|%s|%s" % [str(pickup.get("kind", "xp")), str(pickup.get("position", Vector2.ZERO)), str(pickup.get("value", 1))]

func _track_pickups(run) -> void:
	var current: Array = _read(run, "pickups", [])
	var counts: Dictionary = {}
	for pickup in current:
		var key := _pickup_key(pickup)
		counts[key] = int(counts.get(key, 0)) + 1
	# References reveal the final position of a pickup removed during this tick.
	# The client never writes to them; bulk chapter/reset deletion is handled first.
	for previous in _pickups:
		var key := _pickup_key(previous)
		if int(counts.get(key, 0)) > 0:
			counts[key] = int(counts[key]) - 1
		elif (previous.get("position", Vector2.INF) as Vector2).distance_to(run.player) < 20.0:
			_emit("collect", run.player, {"pickup_kind": str(previous.get("kind", "xp")), "value": int(previous.get("value", 1))}, 0.38, 0)
	_pickups = current.duplicate()

func _track_chests(run) -> void:
	var current: Dictionary = {}
	for chest in _read(run, "chests", []):
		var id := int(chest.id)
		var opened := bool(chest.get("opened", false))
		if not _chests.has(id) or opened != bool(_chests[id]):
			_emit("chest", chest.position, {"id": id, "opened": opened, "elite": bool(chest.get("elite", false))}, 0.9, 3 if opened else 1)
		current[id] = opened
	_chests = current

func _track_evolutions(run) -> void:
	var weapons: Dictionary = _read(run, "weapons", {})
	var current: Dictionary = {}
	for key in weapons:
		var evolved := bool(weapons[key].get("evolved", false))
		if evolved and not bool(_evolved.get(str(key), false)):
			_emit("evolution", run.player, {"weapon": str(key)}, 1.2, 4)
		current[str(key)] = evolved
	_evolved = current

func _age_feedback(dt: float) -> void:
	if dt <= 0.0:
		return
	for i in range(events.size() - 1, -1, -1):
		events[i].age = float(events[i].age) + dt
		if float(events[i].age) >= float(events[i].duration):
			events.remove_at(i)
	for i in range(deaths.size() - 1, -1, -1):
		var death: Dictionary = deaths[i]
		death.age = float(death.age) + dt
		if float(death.age) >= float(death.duration):
			deaths.remove_at(i)
		else:
			death.pose.time = death.age
			death.pose.phase_progress = clampf(float(death.age) / float(death.duration), 0.0, 1.0)
	camera_impulse *= exp(-dt * 12.0)
	if camera_impulse < 0.00001:
		camera_impulse = 0.0

func _emit(kind: String, at: Vector2, extras: Dictionary, duration: float, priority: int) -> void:
	latest_serial += 1
	var record := {"kind": kind, "position": at, "age": 0.0, "duration": duration, "echo": false, "seed": int(("%s|%d|%s|%s" % [kind, roundi(_clock * 1000000.0), str(at), str(extras.get("id", extras.get("cast_serial", 0)))]).hash()) & 0x7fffffff, "priority": priority}
	record.merge(extras, true)
	record.serial = latest_serial
	# Ordinary feedback replaces its actor's very recent burst.
	if priority <= 1:
		for i in range(events.size() - 1, -1, -1):
			var old: Dictionary = events[i]
			if str(old.kind) == kind and str(old.get("actor", "")) == str(record.get("actor", "")) and int(old.get("id", 0)) == int(record.get("id", 0)) and bool(old.echo) == bool(record.echo) and float(old.age) < 0.055:
				events.remove_at(i)
				events.append(record)
				return
	var same_kind: Array[int] = []
	for i in range(events.size()):
		if str(events[i].kind) == kind and int(events[i].priority) <= priority:
			same_kind.append(i)
	if same_kind.size() >= int(EVENT_LIMITS.get(kind, MAX_EVENTS)):
		events.remove_at(same_kind[0])
	if events.size() >= MAX_EVENTS:
		var victim := -1
		var lowest := priority
		for i in range(events.size()):
			if int(events[i].priority) <= lowest:
				if victim < 0 or int(events[i].priority) < lowest:
					victim = i
					lowest = int(events[i].priority)
		if victim < 0:
			return
		events.remove_at(victim)
	events.append(record)

func _stride(kind: String) -> float:
	match kind:
		"witch": return 44.0
		"sentinel": return 68.0
		"bat", "wisp": return 40.0
		"boss_thorn", "boss_mirror", "boss_bell": return 96.0
		_: return 50.0

func _size(kind: String) -> float:
	return ActorArt.display_size(kind)

func snapshot() -> Dictionary:
	return {"clock": _clock, "chapter": _chapter, "generation": generation, "latest_serial": latest_serial, "player_pose": player_pose.duplicate(true), "echo_pose": echo_pose.duplicate(true), "enemy_poses": enemy_poses.duplicate(true), "deaths": deaths.duplicate(true), "events": events.duplicate(true), "camera_impulse": camera_impulse, "tracked_enemy_count": _enemies.size(), "effect_keys": _effect_counts.size(), "pickup_refs": _pickups.size(), "chest_keys": _chests.size(), "evolution_keys": _evolved.size(), "event_limit": MAX_EVENTS, "death_limit": MAX_DEATHS}
