extends RefCounted
## The only gameplay clock lives here. Rendering and profile storage are read-only clients.

const Timeline = preload("res://scripts/echo_timeline.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Arena = preload("res://scripts/arena_grid.gd")
const DURATION := 180.0
const PLAYER_RADIUS := 14.0
const MAX_ENEMIES := 135
const RESONANCE_DISTANCE := 100.0
const RESONANCE_WINDOW := 2.5
const RESONANCE_COOLDOWN := 2.5

var state := "title"
var pause_reason := ""
var elapsed := 0.0
var chapter := 0
var chapter_elapsed := 0.0
var chapter_stage := "assault"
var chapter_clears: Array[int] = []
var player := Vector2.ZERO
var echo := Vector2.ZERO
var facing := 1.0
var echo_active := false
var health := 100.0
var maximum_health := 100.0
var max_health: float:
	get: return maximum_health
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
var relics: Array[String] = []
var cooldowns: Dictionary = {}
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var choices: Array[Dictionary] = []
var choice_phase := "offer"
var pending_item: Dictionary = {}
var rerolls_left := 3
var skips_left := 3
var audio_events: Array[String] = []
var last_player_attack: Dictionary = {}
var last_echo_attack: Dictionary = {}
var timeline = Timeline.new()
var arena = Arena.new()
var rng := RandomNumberGenerator.new()
var spawn_clock := 0.0
var next_enemy_id := 1
var next_chest_id := 1
var damage_taken := 0.0
var damage_received := {"contact": 0.0, "projectile": 0.0, "hazard": 0.0}
var last_damage_cause := ""
var damage_summary := {"player": 0.0, "echo": 0.0, "resonance": 0.0, "poison": 0.0, "by_weapon": {}}
var specialization := "未選択"
var resonance_hits := 0
var resonance_kills := 0
var resonance_bonus := 12.0
var last_movement := Vector2.RIGHT
var wave_number := 0
var ward_charges := 0
var ward_cooldown := 0.0
var discoveries := {"weapons": [], "relics": [], "enemies": [], "evolutions": []}
var _chapter_data: Dictionary = {}
var _chapter_started_at := 0.0
var _elite_index := 0
var _static_chest_index := 0
var _original_choices: Array[Dictionary] = []
var _experience_fraction := 0.0
var _magnet_time := 0.0
var _cast_serial := 0
var _boss_defeated := false

func _init() -> void:
	reset(false)

func reset(begin_playing: bool = true, seed_value: int = 0, starter: String = "lightning") -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	state = "playing" if begin_playing else "title"
	pause_reason = ""
	elapsed = 0.0
	chapter = 0
	chapter_elapsed = 0.0
	chapter_stage = "assault"
	chapter_clears.clear()
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
	damage_received = {"contact": 0.0, "projectile": 0.0, "hazard": 0.0}
	last_damage_cause = ""
	damage_summary = {"player": 0.0, "echo": 0.0, "resonance": 0.0, "poison": 0.0, "by_weapon": {}}
	for id in Spellbook.WEAPON_IDS:
		damage_summary.by_weapon[id] = 0.0
	damage_summary.by_weapon.blast = 0.0
	specialization = "未選択"
	resonance_hits = 0
	resonance_kills = 0
	resonance_bonus = 12.0
	last_movement = Vector2.RIGHT
	wave_number = 0
	rerolls_left = 3
	skips_left = 3
	ward_charges = 0
	ward_cooldown = 0.0
	_experience_fraction = 0.0
	_magnet_time = 0.0
	_cast_serial = 0
	relics.clear()
	weapons = Spellbook.initial_weapons(starter)
	cooldowns.clear()
	for id in Spellbook.WEAPON_IDS:
		cooldowns[id] = 0.25 + float(Spellbook.WEAPON_IDS.find(id)) * 0.1
	discoveries = {"weapons": [], "relics": [], "enemies": [], "evolutions": []}
	for id in Spellbook.equipped_ids(weapons):
		_discover("weapons", id)
	audio_events.clear()
	next_enemy_id = 1
	next_chest_id = 1
	_start_chapter(begin_playing)
	if not begin_playing:
		chests.clear()

func _start_chapter(with_enemies: bool = true) -> void:
	_chapter_data = Campaign.chapter(chapter)
	arena.configure(_chapter_data)
	chapter_elapsed = 0.0
	chapter_stage = "assault"
	_chapter_started_at = elapsed
	_elite_index = 0
	_static_chest_index = 0
	_boss_defeated = false
	player = Vector2.ZERO
	echo = Vector2.ZERO
	echo_active = false
	last_movement = Vector2.RIGHT
	wave_number = 0
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	hazards.clear()
	chests.clear()
	effects.clear()
	choices.clear()
	_original_choices.clear()
	pending_item.clear()
	choice_phase = "offer"
	last_player_attack.clear()
	last_echo_attack.clear()
	spawn_clock = 1.2
	_magnet_time = 0.0
	timeline.reset(player)
	# Timeline samples use local chapter time. An earlier chapter cannot replay here.
	if with_enemies:
		for i in range(5):
			var angle := -PI * 0.5 + float(i) * TAU / 5.0
			spawn_enemy("hound" if chapter == 0 else "bat", _spawn_point(Vector2.from_angle(angle) * (270.0 + float(i % 2) * 35.0)))

func next_chapter() -> bool:
	if state != "chapter_clear" or chapter >= Campaign.CHAPTER_COUNT - 1:
		return false
	chapter += 1
	health = minf(maximum_health, health + 22.0)
	invulnerable = 1.0
	state = "playing"
	pause_reason = ""
	_start_chapter()
	for id in Spellbook.WEAPON_IDS:
		cooldowns[id] = minf(float(cooldowns[id]), 0.35)
	audio_events.append("chapter")
	return true

func chapter_info() -> Dictionary:
	return _chapter_data.duplicate(true)

func boss_data() -> Dictionary:
	for enemy in enemies:
		if bool(enemy.get("boss", false)) and float(enemy.hp) > 0.0:
			return {"id": enemy.kind, "name": _chapter_data.boss_name, "hp": enemy.hp, "max_hp": enemy.max_hp, "phase": int(enemy.get("phase_index", 1)), "position": enemy.position}
	return {}

func pause(reason: String = "") -> void:
	if state == "playing":
		state = "paused"
		pause_reason = reason

func resume() -> void:
	if state == "paused":
		state = "playing"
		pause_reason = ""

func tick(delta: float, movement: Vector2 = Vector2.ZERO) -> void:
	if state != "playing" or delta <= 0.0 or not is_finite(delta):
		return
	var remaining := delta
	while remaining > 0.000001 and state == "playing":
		var dt := minf(remaining, 0.05)
		if chapter_stage == "assault":
			dt = minf(dt, DURATION - chapter_elapsed)
		if dt <= 0.000001:
			_start_boss()
			continue
		_step(dt, movement)
		remaining -= dt

func _step(dt: float, movement: Vector2) -> void:
	elapsed += dt
	chapter_elapsed += dt
	invulnerable = maxf(0.0, invulnerable - dt)
	_magnet_time = maxf(0.0, _magnet_time - dt)
	if "ward_leaf" in relics:
		ward_cooldown = maxf(0.0, ward_cooldown - dt)
		if ward_charges == 0 and ward_cooldown <= 0.0:
			ward_charges = 1
			ward_cooldown = 18.0
	var direction := movement.limit_length()
	player = arena.move(player, direction * speed * dt, PLAYER_RADIUS)
	if direction.length_squared() > 0.01:
		last_movement = direction.normalized()
	if absf(direction.x) > 0.01:
		facing = signf(direction.x)
	var history_time := elapsed - _chapter_started_at
	timeline.record_position(history_time, player)
	echo_active = history_time + 0.000001 >= Timeline.DELAY
	if echo_active:
		echo = timeline.position_at(history_time - Timeline.DELAY)
	_update_effects(dt)
	if chapter_stage == "assault" and chapter_elapsed + 0.000001 >= DURATION:
		_start_boss()
	_update_spawning(dt)
	_update_enemies(dt)
	if state != "playing":
		return
	_update_hazards(dt)
	if state != "playing":
		return
	_update_projectiles(dt)
	if state != "playing":
		return
	_update_weapons(dt)
	for payload in timeline.consume_attacks(history_time):
		cast(payload, echo, true)
	_cleanup_dead()
	if state != "playing":
		return
	_update_pickups(dt)
	if state == "playing":
		_update_chests()
	if health <= 0.0 and state == "playing":
		_finish("defeat")

func _finish(result: String) -> void:
	if state in ["victory", "defeat"]:
		return
	state = result
	audio_events.append(result)

func phase_info() -> Dictionary:
	if chapter_stage == "boss":
		return {"index": 6, "name": str(_chapter_data.boss_name), "subtitle": "予告をかわし、主を倒そう", "remaining": 0.0, "assault": true, "boss": true}
	var index := mini(5, int(chapter_elapsed / 30.0))
	var local := chapter_elapsed - float(index) * 30.0
	var assault := local < 22.0 and chapter_elapsed < DURATION
	return {"index": index, "name": _chapter_data.phase_names[index], "subtitle": _chapter_data.phase_hints[index] if assault else "攻勢が緩む。雫と宝箱を拾おう", "remaining": maxf(0.0, (22.0 if assault else 30.0) - local), "assault": assault, "boss": false}

func _discover(category: String, id: String) -> void:
	if id not in discoveries[category]:
		discoveries[category].append(id)

func equipment_info() -> Dictionary:
	var equipped: Array[Dictionary] = []
	for id in Spellbook.equipped_ids(weapons):
		var info := Spellbook.weapon_info(id)
		var data: Dictionary = weapons[id]
		info.level = int(data.level)
		info.evolved = bool(data.evolved)
		info.evolution_name = info.evolution
		info.stats = Spellbook.weapon_summary(_capture_payload(id, false), id)
		info.rank_cap = Spellbook.rank_cap(chapter)
		info.can_evolve = chapter == 2 and int(data.level) == Spellbook.MAX_LEVEL and not bool(data.evolved) and str(info.requirement) in relics
		equipped.append(info)
	var relic_info: Array[Dictionary] = []
	for id in relics:
		relic_info.append(Spellbook.relic_info(id))
	return {"weapons": equipped, "relics": relic_info, "weapon_slots": Spellbook.WEAPON_SLOTS, "relic_slots": Spellbook.RELIC_SLOTS, "rank_cap": Spellbook.rank_cap(chapter)}

func _refresh_relic_stats() -> void:
	speed = 215.0 * (1.15 if "swift_boots" in relics else 1.0)
	pickup_radius = 172.0 + (90.0 if "magnet_ring" in relics else 0.0)
	maximum_health = 100.0 + (24.0 if "blood_vial" in relics else 0.0)
	health = minf(health, maximum_health)
	if "ward_leaf" in relics and ward_charges == 0 and ward_cooldown <= 0.0:
		ward_charges = 1
		ward_cooldown = 18.0

func check_level_up() -> void:
	if state != "playing" or experience < experience_needed:
		return
	experience -= experience_needed
	level += 1
	var late_level := maxi(0, level - 3)
	experience_needed = 5 + (level - 1) * 4 + 10 * late_level * late_level
	_open_choices(false)
	audio_events.append("level")

func _open_choices(treasure: bool, excluded: Array = []) -> void:
	state = "treasure" if treasure else "upgrade"
	choice_phase = "offer"
	pending_item.clear()
	_original_choices.clear()
	choices = Spellbook.offers(weapons, level, speed, maximum_health, rng, specialization, relics, treasure, excluded, chapter)
	if health < maximum_health * 0.6 and not choices.is_empty() and not bool(choices[0].get("specialization", false)):
		var has_heal := false
		for card in choices:
			has_heal = has_heal or card.id == "heal"
		if not has_heal and "heal" not in excluded:
			choices[choices.size() - 1] = Spellbook.offer("heal", weapons, speed, maximum_health)
	_decorate_choices()

func _decorate_choices() -> void:
	for card in choices:
		if card.kind not in ["weapon", "evolution"]:
			continue
		var id := str(card.item_id)
		var previous: Dictionary = weapons[id]
		var next: Dictionary = Spellbook._rebuild(id, previous, Spellbook.MAX_LEVEL if card.kind == "evolution" else int(previous.level) + 1, card.kind == "evolution")
		card.before = Spellbook.weapon_summary(_capture_payload(id, false, previous), id)
		card.after = Spellbook.weapon_summary(_capture_payload(id, false, next), id)
		card.effect = card.after

func _begin_replacement(card: Dictionary) -> void:
	pending_item = card.duplicate(true)
	_original_choices = choices.duplicate(true)
	choice_phase = "replace"
	choices.clear()
	var ids: Array = relics if card.kind == "relic" else Spellbook.equipped_ids(weapons)
	for old_id in ids:
		var old_info: Dictionary = Spellbook.relic_info(old_id) if card.kind == "relic" else Spellbook.weapon_info(old_id)
		var replacement := card.duplicate(true)
		replacement.id = str(card.id) + ":replace:" + str(old_id)
		replacement.replace_id = str(old_id)
		replacement.title = "%sと交換" % old_info.title
		replacement.tag = "失う装備 → 得る装備"
		replacement.before = str(old_info.body) if card.kind == "relic" else "%s Rank %d\n%s" % [old_info.title, int(weapons[old_id].level), Spellbook.weapon_summary(_capture_payload(old_id, false), old_id)]
		replacement.after = "%s\n%s" % [card.title, card.after if not str(card.after).is_empty() else card.effect]
		replacement.body = "失う：%s\n得る：%s" % [old_info.title, card.title]
		replacement.effect = "交換すると、元の装備の強化は失われる。"
		replacement.full_slots = false
		choices.append(replacement)

func cancel_replacement() -> bool:
	if state not in ["upgrade", "treasure"] or choice_phase != "replace":
		return false
	choices = _original_choices.duplicate(true)
	_original_choices.clear()
	pending_item.clear()
	choice_phase = "offer"
	return true

func choose_upgrade(index: int) -> bool:
	if state not in ["upgrade", "treasure"] or index < 0 or index >= choices.size():
		return false
	var card: Dictionary = choices[index].duplicate(true)
	if choice_phase == "replace" and pending_item.is_empty():
		return false
	var id := str(pending_item.id) if choice_phase == "replace" else str(card.id)
	if not _reward_is_valid(id):
		return false
	if choice_phase == "offer" and bool(card.get("full_slots", false)):
		_begin_replacement(card)
		return true
	var old_id := str(card.get("replace_id", ""))
	if not old_id.is_empty():
		if pending_item.kind == "relic":
			relics.erase(old_id)
		else:
			weapons[old_id].level = 0
			weapons[old_id].evolved = false
			cooldowns[old_id] = 0.2
	var applied := false
	if id.begins_with("spec_"):
		if specialization != "未選択":
			return false
		specialization = Spellbook.specialize(id, weapons)
		if id == "spec_echo":
			resonance_bonus = 24.0
		if id == "spec_moon":
			_discover("weapons", "moon")
			cooldowns.moon = minf(float(cooldowns.moon), 0.12)
		applied = true
	elif id.begins_with("weapon:"):
		var weapon_id := id.get_slice(":", 1)
		if int(weapons[weapon_id].level) == 0 and Spellbook.equipped_ids(weapons).size() >= Spellbook.WEAPON_SLOTS:
			return false
		applied = Spellbook.rank_weapon(weapon_id, weapons, Spellbook.rank_cap(chapter))
		if applied:
			_discover("weapons", weapon_id)
			cooldowns[weapon_id] = minf(float(cooldowns[weapon_id]), 0.12)
	elif id.begins_with("relic:"):
		var relic_id := id.get_slice(":", 1)
		if relic_id in Spellbook.RELIC_IDS and relic_id not in relics and relics.size() < Spellbook.RELIC_SLOTS:
			relics.append(relic_id)
			_discover("relics", relic_id)
			_refresh_relic_stats()
			applied = true
	elif id.begins_with("evolve:"):
		var weapon_id := id.get_slice(":", 1)
		applied = Spellbook.evolve_weapon(weapon_id, weapons, relics, chapter, state == "treasure")
		if applied:
			_discover("evolutions", weapon_id)
			audio_events.append("evolution")
	elif id == "heal":
		health = minf(maximum_health, health + 28.0)
		applied = true
	if not applied:
		return false
	_finish_choice()
	return true

func _reward_is_valid(id: String) -> bool:
	if id in ["spec_lightning", "spec_moon", "spec_echo"]:
		return specialization == "未選択"
	if id.begins_with("weapon:"):
		var weapon_id := id.get_slice(":", 1)
		return weapon_id in Spellbook.WEAPON_IDS and int(weapons[weapon_id].level) < Spellbook.rank_cap(chapter)
	if id.begins_with("relic:"):
		var relic_id := id.get_slice(":", 1)
		return relic_id in Spellbook.RELIC_IDS and relic_id not in relics
	if id.begins_with("evolve:"):
		var weapon_id := id.get_slice(":", 1)
		return state == "treasure" and chapter == 2 and weapon_id in Spellbook.WEAPON_IDS and int(weapons[weapon_id].level) == 5 and not bool(weapons[weapon_id].evolved) and str(Spellbook.weapon_info(weapon_id).requirement) in relics
	return id == "heal"

func _finish_choice() -> void:
	choices.clear()
	_original_choices.clear()
	pending_item.clear()
	choice_phase = "offer"
	state = "playing"
	invulnerable = maxf(invulnerable, 0.7)
	check_level_up()

func reroll_choices() -> bool:
	if state not in ["upgrade", "treasure"] or choice_phase != "offer" or rerolls_left <= 0 or (not choices.is_empty() and bool(choices[0].get("specialization", false))):
		return false
	var excluded: Array[String] = []
	for card in choices:
		excluded.append(str(card.id))
	var treasure := state == "treasure"
	rerolls_left -= 1
	_open_choices(treasure, excluded)
	return true

func skip_choice() -> bool:
	if state not in ["upgrade", "treasure"] or choice_phase != "offer" or skips_left <= 0:
		return false
	skips_left -= 1
	_finish_choice()
	return true

func _update_chests() -> void:
	for chest in chests:
		if not bool(chest.opened) and (chest.position as Vector2).distance_to(player) <= 45.0:
			chest.opened = true
			_open_choices(true)
			audio_events.append("treasure")
			return

func _spawn_point(desired: Vector2, radius: float = 24.0) -> Vector2:
	var point := arena.safe_point(desired, radius)
	if point.distance_to(player) >= 300.0:
		return point
	var best := point
	var best_distance := point.distance_to(player)
	for i in range(16):
		var candidate := arena.safe_point(player + Vector2.from_angle(float(i) * TAU / 16.0) * 520.0, radius)
		var distance := candidate.distance_to(player)
		if distance > best_distance:
			best = candidate
			best_distance = distance
	return best

func spawn_enemy(kind: String, at: Vector2, elite: bool = false) -> Dictionary:
	var hp := 28.0
	var enemy_speed := 88.0
	var radius := 17.0
	var armor := 0.0
	match kind:
		"charger":
			hp = 48.0
			enemy_speed = 80.0
			radius = 22.0
		"archer":
			hp = 34.0
			enemy_speed = 74.0
			radius = 19.0
		"sentinel":
			hp = 105.0
			enemy_speed = 64.0
			radius = 27.0
			armor = 0.18
		"wisp":
			hp = 42.0
			enemy_speed = 91.0
			radius = 18.0
		"bat":
			hp = 20.0
			enemy_speed = 136.0
			radius = 13.0
	var boss := kind.begins_with("boss_")
	var toughness := 1.0 + float(chapter) * 0.42 + minf(chapter_elapsed, DURATION) / 500.0
	if boss:
		hp = float(_chapter_data.boss_hp)
		toughness = 1.0
		radius = 44.0
		enemy_speed = [65.0, 78.0, 70.0][chapter]
	if elite:
		hp *= 4.0
		radius += 5.0
		enemy_speed *= 0.9
	var enemy := {
		"id": next_enemy_id, "kind": kind, "position": arena.safe_point(at, radius),
		"hp": hp * toughness, "max_hp": hp * toughness, "speed": enemy_speed + (0.0 if boss else float(chapter) * 9.0), "radius": radius, "armor": armor,
		"phase": "arrival", "timer": 2.0 if boss else 0.9, "arrival_duration": 2.0 if boss else 0.9, "contact_ready_at": elapsed + (2.2 if boss else 1.1),
		"cooldown": 2.4 if boss else 1.6 + rng.randf() * 0.8, "direction": Vector2.DOWN, "flash": 0.0,
		"mark": {}, "resonance_ready_at": 0.0, "resonance_rewarded": false, "elite": elite, "boss": boss,
		"phase_index": 1, "pattern": 0, "nav_clock": 0.0, "nav_path": PackedVector2Array(),
		"poison_left": 0.0, "poison_dps": 0.0, "poison_weapon": "thorn", "poison_echo": false,
		"slow_left": 0.0, "slow_scale": 1.0, "stagger": 0.0
	}
	next_enemy_id += 1
	enemies.append(enemy)
	_discover("enemies", kind)
	return enemy

func _update_spawning(dt: float) -> void:
	if chapter_stage == "boss":
		return
	var chest_times: Array = _chapter_data.get("chest_times", [30.0, 105.0])
	while _static_chest_index < chest_times.size() and chapter_elapsed + 0.000001 >= float(chest_times[_static_chest_index]):
		chests.append({"id": next_chest_id, "position": _chapter_data.chest_positions[_static_chest_index], "opened": false, "elite": false})
		next_chest_id += 1
		_static_chest_index += 1
		audio_events.append("treasure")
	var elite_times := [55.0, 125.0]
	if _elite_index < elite_times.size() and chapter_elapsed >= float(elite_times[_elite_index]):
		var elite_kind: String = ["charger", "sentinel", "wisp"][chapter]
		spawn_enemy(elite_kind, _spawn_point(player + last_movement.orthogonal() * 480.0), true)
		_elite_index += 1
	spawn_clock -= dt
	if spawn_clock > 0.0:
		return
	var phase := phase_info()
	var index := int(phase.index)
	if not bool(phase.assault):
		spawn_clock = 3.2
		if enemies.size() < MAX_ENEMIES:
			spawn_enemy("hound" if chapter == 0 else "bat", _spawn_point(player + Vector2.from_angle(rng.randf() * TAU) * 580.0))
		return
	var intervals := [1.35, 1.23, 1.12, 1.02, 0.92, 0.82]
	spawn_clock = float(intervals[index]) * (1.0 - float(chapter) * 0.08)
	if enemies.size() >= MAX_ENEMIES:
		return
	var group := 2 + int(index / 2) + chapter
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
		if chapter == 0:
			if index >= 1 and roll < 0.18:
				kind = "charger"
			elif index >= 2 and roll < 0.34:
				kind = "archer"
			elif index >= 4 and roll > 0.91:
				kind = "sentinel"
		elif chapter == 1:
			if roll < 0.24:
				kind = "archer"
			elif roll < 0.38:
				kind = "sentinel"
			elif roll < 0.51:
				kind = "wisp"
			elif roll < 0.61:
				kind = "charger"
		else:
			if roll < 0.32:
				kind = "bat"
			elif roll < 0.48:
				kind = "wisp"
			elif roll < 0.62:
				kind = "charger"
			elif roll < 0.75:
				kind = "archer"
			elif roll < 0.84:
				kind = "sentinel"
		var offset: Vector2
		if pattern == 0:
			offset = forward * 510.0 + sideways * (float(i) - float(group - 1) * 0.5) * 82.0
		elif pattern == 2:
			var side := -1.0 if int(wave_number / 4) % 2 == 0 else 1.0
			offset = sideways * side * 510.0 + forward * (float(i) - float(group - 1) * 0.5) * 85.0
		else:
			offset = Vector2.from_angle(angle + float(i) * 0.19) * rng.randf_range(490.0, 620.0)
		spawn_enemy(kind, _spawn_point(player + offset))

func _start_boss() -> void:
	if chapter_stage == "boss":
		return
	chapter_stage = "boss"
	chapter_elapsed = DURATION
	# A clean threshold gives the boss a readable entrance rather than a lethal pile-up.
	for enemy in enemies:
		pickups.append({"kind": "xp", "position": enemy.position, "value": 1})
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	var offset := -last_movement * 470.0
	spawn_enemy(str(_chapter_data.boss_id), _spawn_point(player + offset, 44.0))
	invulnerable = maxf(invulnerable, 1.2)
	audio_events.append("boss")

func _update_enemy_status(enemy: Dictionary, dt: float) -> void:
	enemy.flash = maxf(0.0, float(enemy.flash) - dt)
	enemy.stagger = maxf(0.0, float(enemy.get("stagger", 0.0)) - dt)
	enemy.slow_left = maxf(0.0, float(enemy.get("slow_left", 0.0)) - dt)
	if float(enemy.slow_left) <= 0.0:
		enemy.slow_scale = 1.0
	var poison_dt := minf(dt, float(enemy.get("poison_left", 0.0)))
	if poison_dt > 0.0:
		enemy.poison_left = maxf(0.0, float(enemy.poison_left) - dt)
		var dealt := minf(maxf(0.0, float(enemy.hp)), float(enemy.poison_dps) * poison_dt)
		enemy.hp = float(enemy.hp) - dealt
		damage_summary.poison += dealt
		var weapon := str(enemy.get("poison_weapon", "thorn"))
		damage_summary.by_weapon[weapon] = float(damage_summary.by_weapon.get(weapon, 0.0)) + dealt

func _update_enemies(dt: float) -> void:
	for enemy in enemies:
		if float(enemy.hp) <= 0.0:
			continue
		_update_enemy_status(enemy, dt)
		if float(enemy.hp) <= 0.0:
			continue
		enemy.cooldown = float(enemy.cooldown) - dt
		if enemy.phase == "arrival":
			enemy.timer = float(enemy.timer) - dt
			if float(enemy.timer) <= 0.0:
				enemy.phase = "seek"
			continue
		if float(enemy.stagger) > 0.0:
			continue
		if bool(enemy.boss):
			_update_boss(enemy, dt)
		else:
			_update_normal_enemy(enemy, dt)
		if elapsed >= float(enemy.contact_ready_at) and (enemy.position as Vector2).distance_to(player) < float(enemy.radius) + PLAYER_RADIUS:
			var amount := 16.0 if bool(enemy.boss) else (12.0 if enemy.phase == "rush" else 8.0)
			take_damage(amount, "contact", str(enemy.kind))
		if state != "playing":
			return

func _update_normal_enemy(enemy: Dictionary, dt: float) -> void:
	var to_player: Vector2 = player - (enemy.position as Vector2)
	var distance := to_player.length()
	if enemy.phase == "warning":
		enemy.timer = float(enemy.timer) - dt
		if float(enemy.timer) <= 0.0:
			if enemy.kind == "charger":
				enemy.phase = "rush"
				enemy.timer = 0.67
			elif enemy.kind in ["archer", "wisp"]:
				var count := 3 if enemy.kind == "wisp" else 1
				for i in range(count):
					var direction: Vector2 = (enemy.direction as Vector2).rotated((float(i) - float(count - 1) * 0.5) * 0.19)
					projectiles.append({"kind": "bolt", "position": enemy.position, "velocity": direction * (205.0 if enemy.kind == "wisp" else 240.0), "age": 0.0, "duration": 4.0, "damage": 10.0, "source": str(enemy.kind), "radius": 7.0})
				enemy.phase = "seek"
				enemy.cooldown = 3.1 if enemy.kind == "wisp" else 2.8
			else:
				enemy.phase = "seek"
				enemy.cooldown = 3.6
	elif enemy.phase == "rush":
		var old: Vector2 = enemy.position
		var destination := old + (enemy.direction as Vector2) * 440.0 * dt
		if arena.is_clear(destination, float(enemy.radius)):
			enemy.position = destination
		enemy.timer = float(enemy.timer) - dt
		if float(enemy.timer) <= 0.0 or (enemy.position as Vector2).distance_to(old) < 440.0 * dt * 0.4:
			enemy.phase = "recover"
			enemy.timer = 0.7
			enemy.cooldown = 2.6
	elif enemy.phase == "recover":
		enemy.timer = float(enemy.timer) - dt
		if float(enemy.timer) <= 0.0:
			enemy.phase = "seek"
	else:
		var can_see := arena.segment_clear(enemy.position, player, 2.0)
		if enemy.kind == "charger" and distance < 455.0 and float(enemy.cooldown) <= 0.0 and can_see:
			enemy.phase = "warning"
			enemy.timer = 0.95
			enemy.direction = to_player.normalized()
			enemy.warning_length = _dash_length(enemy)
		elif enemy.kind in ["archer", "wisp"] and distance < 490.0 and float(enemy.cooldown) <= 0.0 and can_see:
			enemy.phase = "warning"
			enemy.timer = 0.95
			enemy.direction = to_player.normalized()
		elif enemy.kind == "sentinel" and distance < 108.0 and float(enemy.cooldown) <= 0.0:
			enemy.phase = "warning"
			enemy.timer = 0.8
			_add_hazard("circle", enemy.position, 70.0, 0.0, 0.8, 0.25, 12.0, str(enemy.kind))
		else:
			var walk := arena.route(enemy, player, dt)
			if enemy.kind in ["archer", "wisp"] and can_see:
				if distance < 205.0:
					walk = -to_player.normalized()
				elif distance < 340.0:
					walk = to_player.normalized().orthogonal() * (0.55 if int(enemy.id) % 2 == 0 else -0.55)
			enemy.position = arena.move(enemy.position, walk * float(enemy.speed) * float(enemy.slow_scale) * dt, float(enemy.radius))

func _dash_length(enemy: Dictionary) -> float:
	var length := 0.0
	while length + 4.0 <= 294.8:
		if not arena.is_clear((enemy.position as Vector2) + (enemy.direction as Vector2) * (length + 4.0), float(enemy.radius)):
			break
		length += 4.0
	return length

func _update_boss(enemy: Dictionary, dt: float) -> void:
	var phase := 2 if float(enemy.hp) <= float(enemy.max_hp) * 0.5 else 1
	if phase != int(enemy.phase_index):
		enemy.phase_index = phase
		enemy.cooldown = minf(float(enemy.cooldown), 1.1)
		# Crossing half health rewards a risky collection route, once per boss.
		var heal_at := arena.safe_point((enemy.position as Vector2) + (enemy.position as Vector2).direction_to(player).orthogonal() * 165.0)
		pickups.append({"kind": "heal", "position": heal_at, "value": 20})
		effects.append({"kind": "boss_phase", "position": enemy.position, "radius": 110.0, "age": 0.0, "duration": 0.8})
	if enemy.phase == "warning":
		enemy.timer = float(enemy.timer) - dt
		if float(enemy.timer) <= 0.0:
			enemy.phase = "seek"
	elif float(enemy.cooldown) <= 0.0:
		_boss_pattern(enemy)
	else:
		var distance := (enemy.position as Vector2).distance_to(player)
		if distance > 150.0 or enemy.kind == "boss_thorn":
			var direction := arena.route(enemy, player, dt)
			enemy.position = arena.move(enemy.position, direction * float(enemy.speed) * float(enemy.slow_scale) * dt, float(enemy.radius))

func _boss_pattern(enemy: Dictionary) -> void:
	var pattern := int(enemy.pattern) % 3
	var second := int(enemy.phase_index) == 2
	var origin: Vector2 = enemy.position
	var direction := origin.direction_to(player)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	enemy.direction = direction
	enemy.pattern = int(enemy.pattern) + 1
	enemy.phase = "warning"
	enemy.timer = 1.05
	enemy.cooldown = (2.7 if second else 3.3) + float(chapter) * 0.15
	match str(enemy.kind):
		"boss_thorn":
			if pattern == 0:
				_add_hazard("circle", player, 88.0, 0.0, 1.15, 0.7, 14.0, "boss_thorn")
				if second:
					_add_hazard("circle", arena.safe_point(player + direction.orthogonal() * 180.0), 75.0, 0.0, 1.4, 0.7, 14.0, "boss_thorn")
					_add_hazard("circle", arena.safe_point(player - direction.orthogonal() * 180.0), 75.0, 0.0, 1.4, 0.7, 14.0, "boss_thorn")
			elif pattern == 1:
				for i in range(3 if not second else 5):
					var ray := direction.rotated((float(i) - (1.0 if not second else 2.0)) * 0.34)
					_add_line(origin, origin + ray * 630.0, 32.0, 1.2, 0.35, 15.0, "boss_thorn")
			else:
				_add_hazard("ring", origin, 185.0, 38.0, 1.15, 0.6, 14.0, "boss_thorn")
				if enemies.size() < 12:
					for i in range(2 if second else 1):
						spawn_enemy("hound", _spawn_point(origin + Vector2.from_angle(float(i) * PI) * 220.0))
		"boss_mirror":
			if pattern == 0:
				_add_line(player - Vector2(640, 0), player + Vector2(640, 0), 42.0, 1.3, 0.35, 16.0, "boss_mirror")
				_add_line(player - Vector2(0, 600), player + Vector2(0, 600), 42.0, 1.3, 0.35, 16.0, "boss_mirror")
			elif pattern == 1:
				for i in range(4):
					_add_hazard("circle", arena.safe_point(player + Vector2.from_angle(PI * 0.25 + float(i) * PI * 0.5) * 175.0), 78.0, 0.0, 1.35, 0.65, 16.0, "boss_mirror")
				if second:
					_add_hazard("circle", echo, 65.0, 0.0, 1.5, 0.5, 14.0, "boss_mirror")
			else:
				for side in [-1.0, 1.0]:
					var start: Vector2 = origin + direction.orthogonal() * 125.0 * float(side)
					_add_line(start - direction * 200.0, start + direction * 780.0, 44.0, 1.2, 0.4, 16.0, "boss_mirror")
				if second and enemies.size() < 10:
					spawn_enemy("wisp", _spawn_point(origin + direction.orthogonal() * 260.0))
		"boss_bell":
			if pattern == 0:
				_add_hazard("ring", origin, 140.0, 42.0, 1.25, 0.6, 18.0, "boss_bell")
				_add_hazard("ring", origin, 315.0, 42.0, 1.6, 0.6, 18.0, "boss_bell")
			elif pattern == 1:
				var angle := PI * 0.25 if second else 0.0
				for i in range(2):
					var axis := Vector2.from_angle(angle + float(i) * PI * 0.5)
					_add_line(player - axis * 700.0, player + axis * 700.0, 48.0, 1.3, 0.4, 18.0, "boss_bell")
				if second:
					_add_hazard("ring", player, 195.0, 32.0, 1.45, 0.4, 16.0, "boss_bell")
			else:
				for i in range(4):
					_add_hazard("circle", arena.safe_point(origin + Vector2.from_angle(float(i) * PI * 0.5) * 235.0), 86.0, 0.0, 1.25, 0.65, 18.0, "boss_bell")
				if enemies.size() < 12:
					for i in range(3 if second else 2):
						spawn_enemy("bat", _spawn_point(origin + Vector2.from_angle(float(i) * TAU / 3.0) * 250.0))

func _add_hazard(shape: String, at: Vector2, radius: float, width: float, delay: float, duration: float, damage: float, source: String) -> void:
	hazards.append({"shape": shape, "position": at, "radius": radius, "width": width, "age": 0.0, "delay": delay, "duration": duration, "damage": damage, "source": source})

func _add_line(from: Vector2, to: Vector2, width: float, delay: float, duration: float, damage: float, source: String) -> void:
	hazards.append({"shape": "line", "position": (from + to) * 0.5, "from": from, "to": to, "radius": 0.0, "width": width, "age": 0.0, "delay": delay, "duration": duration, "damage": damage, "source": source})

func _update_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard.age = float(hazard.age) + dt
		if float(hazard.age) >= float(hazard.delay) + float(hazard.duration):
			hazards.remove_at(i)
			continue
		if float(hazard.age) < float(hazard.delay):
			continue
		var hit := false
		match str(hazard.shape):
			"circle": hit = player.distance_to(hazard.position) <= float(hazard.radius) + PLAYER_RADIUS
			"ring": hit = absf(player.distance_to(hazard.position) - float(hazard.radius)) <= float(hazard.width) * 0.5 + PLAYER_RADIUS
			"line": hit = player.distance_to(Geometry2D.get_closest_point_to_segment(player, hazard.from, hazard.to)) <= float(hazard.width) * 0.5 + PLAYER_RADIUS
		if hit:
			take_damage(float(hazard.damage), "hazard", str(hazard.source))
			if state != "playing":
				return

func take_damage(amount: float, category: String = "contact", cause: String = "hound") -> void:
	if state != "playing" or invulnerable > 0.0 or amount <= 0.0:
		return
	if ward_charges > 0:
		ward_charges -= 1
		ward_cooldown = 18.0
		invulnerable = 0.85
		effects.append({"kind": "shield", "position": player, "radius": 38.0, "age": 0.0, "duration": 0.45})
		audio_events.append("shield")
		return
	var lost := minf(health, amount)
	health -= lost
	damage_taken += lost
	damage_received[category] = float(damage_received.get(category, 0.0)) + lost
	last_damage_cause = cause
	invulnerable = 0.85
	effects.append({"kind": "hurt", "position": player, "age": 0.0, "duration": 0.35})
	audio_events.append("damage")
	if health <= 0.0:
		_finish("defeat")

func _capture_payload(kind: String, advance_serial: bool = true, override: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = weapons[kind].duplicate(true) if override.is_empty() else override.duplicate(true)
	payload.kind = kind
	payload.captured = true
	payload.damage = float(payload.get("damage", 0.0))
	payload.count = int(payload.get("count", 1))
	payload.evolved = bool(payload.get("evolved", false))
	payload.range = float(payload.get("range", 400.0))
	payload.radius = float(payload.get("radius", 118.0))
	payload.width = float(payload.get("width", 11.0))
	payload.pierce = int(payload.get("pierce", 1))
	payload.poison = float(payload.get("poison", 0.0))
	payload.poison_duration = float(payload.get("poison_duration", 0.0))
	payload.slow = float(payload.get("slow", 1.0))
	payload.slow_duration = float(payload.get("slow_duration", 0.0))
	payload.stagger = float(payload.get("stagger", 0.0))
	payload.echo_multiplier = 1.3 if "lantern_oil" in relics else 1.0
	payload.resonance_bonus = resonance_bonus + (10.0 if "echo_mirror" in relics else 0.0)
	payload.resonance_distance = 70.0 if "echo_mirror" in relics else RESONANCE_DISTANCE
	payload.resonance_stagger = 0.45 if "silver_bell" in relics else 0.0
	if "swift_boots" in relics:
		payload.damage *= 0.92
	if "hourglass" in relics:
		payload.damage *= 0.9
		payload.cooldown = float(payload.get("cooldown", 1.0)) * 0.85
	if "moonstone" in relics:
		payload.radius *= 1.22
		payload.width *= 1.22
	if "thorn_seed" in relics:
		payload.poison += 3.0
		payload.poison_duration = maxf(3.0, float(payload.poison_duration))
	if "ice_crystal" in relics:
		payload.slow = minf(0.7, float(payload.slow))
		payload.slow_duration = maxf(1.2, float(payload.slow_duration))
	if advance_serial:
		_cast_serial += 1
	payload.empowered = advance_serial and "storm_ink" in relics and _cast_serial % 4 == 0
	if bool(payload.empowered):
		payload.damage *= 1.45
	var poison_scale := float(payload.get("power_scale", 1.0))
	if "swift_boots" in relics:
		poison_scale *= 0.92
	if "hourglass" in relics:
		poison_scale *= 0.9
	if bool(payload.empowered):
		poison_scale *= 1.45
	payload.poison *= poison_scale
	return payload

func _update_weapons(dt: float) -> void:
	for kind in Spellbook.WEAPON_IDS:
		if int(weapons[kind].level) <= 0:
			continue
		cooldowns[kind] = float(cooldowns[kind]) - dt
		if float(cooldowns[kind]) > 0.0:
			continue
		if kind not in ["moon", "bell"] and nearest_enemies(player, float(weapons[kind].range)).is_empty():
			continue
		var payload := _capture_payload(kind)
		cooldowns[kind] = maxf(0.32, float(payload.cooldown))
		cast(payload, player, false)

func nearest_enemies(origin: Vector2, reach: float) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for enemy in enemies:
		if float(enemy.hp) > 0.0 and enemy.phase != "arrival" and (enemy.position as Vector2).distance_to(origin) <= reach:
			targets.append(enemy)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.position as Vector2).distance_squared_to(origin) < (b.position as Vector2).distance_squared_to(origin))
	return targets

func cast(original_payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	var kind := str(original_payload.get("kind", "lightning"))
	if kind not in Spellbook.WEAPON_IDS:
		return
	var payload := original_payload.duplicate(true) if bool(original_payload.get("captured", false)) else _capture_payload(kind, not is_echo, original_payload)
	if is_echo:
		echo_shots += 1
		last_echo_attack = payload.duplicate(true)
	else:
		player_shots += 1
		last_player_attack = payload.duplicate(true)
		timeline.record_attack(elapsed - _chapter_started_at, payload)
	match kind:
		"lightning": _cast_lightning(payload, origin, is_echo)
		"moon", "bell":
			for i in range(int(payload.count)):
				projectiles.append({"kind": kind, "position": origin, "age": -0.18 * float(i), "duration": 0.95 if kind == "bell" else 0.72, "radius": float(payload.radius), "current_radius": 0.0, "width": float(payload.width), "damage": float(payload.damage), "echo": is_echo, "evolved": bool(payload.evolved), "hit_ids": [], "payload": payload})
		"thorn": _cast_thorn(payload, origin, is_echo)
		"wisp":
			for i in range(int(payload.count)):
				var direction := Vector2.from_angle(float(i) * TAU / float(payload.count))
				projectiles.append({"kind": "wisp", "position": origin + direction * 18.0, "velocity": direction * 245.0, "radius": 14.0, "age": -0.08 * float(i), "duration": 3.6, "echo": is_echo, "evolved": bool(payload.evolved), "hit_ids": [], "jumps": 0, "payload": payload})
		"frost":
			var targets := nearest_enemies(origin, float(payload.range))
			var locations: Array[Vector2] = []
			for target in targets:
				var at: Vector2 = target.position
				var separate := true
				for prior in locations:
					if at.distance_to(prior) < float(payload.radius) * 1.25:
						separate = false
				if separate:
					locations.append(at)
				if locations.size() >= int(payload.count):
					break
			if locations.is_empty():
				locations.append(origin)
			for at in locations:
				projectiles.append({"kind": "frost", "position": at, "radius": float(payload.radius), "current_radius": float(payload.radius), "age": 0.0, "duration": 3.0 if bool(payload.evolved) else 2.1, "echo": is_echo, "evolved": bool(payload.evolved), "tick_at": 0.0, "payload": payload})
	if not is_echo:
		audio_events.append(kind)
	while projectiles.size() > 240:
		projectiles.pop_front()

func _cast_lightning(payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	var targets := nearest_enemies(origin, float(payload.range))
	var count := mini(int(payload.count), targets.size())
	var hit_ids: Array[int] = []
	var chain_origins: Array[Vector2] = []
	for i in range(count):
		var direction := origin.direction_to(targets[i].position)
		var end := origin + direction * float(payload.range)
		effects.append({"kind": "lightning", "from": origin, "to": end, "age": 0.0, "duration": 0.23, "width": float(payload.width), "echo": is_echo, "evolved": bool(payload.evolved), "seed": rng.randi() % 10000})
		for enemy in enemies:
			if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or hit_ids.has(int(enemy.id)):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position, origin, end)
			if closest.distance_to(enemy.position) <= float(payload.width) * 0.5 + float(enemy.radius):
				hit_ids.append(int(enemy.id))
				chain_origins.append(enemy.position)
				_hit(enemy, payload, direction, is_echo, origin)
	if bool(payload.evolved):
		var chains := 0
		for at in chain_origins:
			for enemy in nearest_enemies(at, 165.0):
				if int(enemy.id) in hit_ids:
					continue
				hit_ids.append(int(enemy.id))
				effects.append({"kind": "lightning", "from": at, "to": enemy.position, "age": 0.0, "duration": 0.23, "width": float(payload.width) * 0.6, "echo": is_echo, "evolved": true, "seed": rng.randi() % 10000})
				_hit(enemy, payload, at.direction_to(enemy.position), is_echo, origin, 0.65)
				chains += 1
				break
			if chains >= 4:
				break

func _cast_thorn(payload: Dictionary, origin: Vector2, is_echo: bool) -> void:
	var targets := nearest_enemies(origin, float(payload.range))
	var aim := origin.direction_to(targets[0].position) if not targets.is_empty() else last_movement
	var cast_hit_ids: Array[int] = []
	for i in range(int(payload.count)):
		var direction := aim.rotated((float(i) - float(int(payload.count) - 1) * 0.5) * 0.13)
		projectiles.append({"kind": "thorn", "position": origin, "velocity": direction * 420.0, "direction": direction, "radius": float(payload.radius), "width": float(payload.width), "age": 0.0, "duration": float(payload.range) / 420.0, "echo": is_echo, "evolved": bool(payload.evolved), "hit_ids": [], "cast_hit_ids": cast_hit_ids, "payload": payload})

func _hit(enemy: Dictionary, payload: Dictionary, direction: Vector2, is_echo: bool, origin: Vector2, multiplier: float = 1.0) -> void:
	var echo_scale := float(payload.get("echo_multiplier", 1.0)) if is_echo else 1.0
	damage_enemy(enemy, float(payload.damage) * echo_scale * multiplier, direction, is_echo, origin, float(payload.get("resonance_bonus", 12.0)), str(payload.kind), payload)
	if float(enemy.hp) <= 0.0:
		return
	if float(payload.get("poison", 0.0)) > 0.0:
		var dps := float(payload.poison) * echo_scale
		if dps >= float(enemy.get("poison_dps", 0.0)) or float(enemy.get("poison_left", 0.0)) <= 0.0:
			enemy.poison_dps = dps
			enemy.poison_weapon = str(payload.kind)
			enemy.poison_echo = is_echo
		enemy.poison_left = maxf(float(enemy.get("poison_left", 0.0)), float(payload.get("poison_duration", 0.0)))
	if float(payload.get("slow", 1.0)) < 1.0:
		enemy.slow_scale = minf(float(enemy.get("slow_scale", 1.0)), float(payload.slow))
		enemy.slow_left = maxf(float(enemy.get("slow_left", 0.0)), float(payload.get("slow_duration", 0.0)))
	if float(payload.get("stagger", 0.0)) > 0.0:
		var stagger := float(payload.stagger)
		if bool(enemy.get("boss", false)):
			stagger = minf(0.15, stagger)
		enemy.stagger = maxf(float(enemy.get("stagger", 0.0)), stagger)

func damage_enemy(enemy: Dictionary, amount: float, direction: Vector2, is_echo: bool, origin: Vector2 = Vector2.INF, bonus: float = -1.0, weapon_kind: String = "lightning", modifiers: Dictionary = {}) -> void:
	if float(enemy.hp) <= 0.0 or amount <= 0.0:
		return
	if origin == Vector2.INF:
		origin = echo if is_echo else player
	if bonus < 0.0:
		bonus = resonance_bonus
	var source := "echo" if is_echo else "player"
	var mark: Dictionary = enemy.get("mark", {})
	var distance_required := float(modifiers.get("resonance_distance", RESONANCE_DISTANCE))
	var resonance := echo_active and player.distance_to(echo) >= distance_required
	resonance = resonance and not mark.is_empty() and str(mark.get("source", source)) != source
	resonance = resonance and elapsed <= float(mark.get("expires", -1.0)) + 0.000001
	resonance = resonance and elapsed >= float(enemy.get("resonance_ready_at", 0.0))
	var normal := amount * (1.0 - float(enemy.get("armor", 0.0)))
	var normal_dealt := minf(float(enemy.hp), normal)
	enemy.hp = float(enemy.hp) - normal_dealt
	var extra := minf(maxf(0.0, float(enemy.hp)), bonus) if resonance else 0.0
	enemy.hp = float(enemy.hp) - extra
	damage_summary[source] = float(damage_summary[source]) + normal_dealt
	damage_summary.resonance += extra
	damage_summary.by_weapon[weapon_kind] = float(damage_summary.by_weapon.get(weapon_kind, 0.0)) + normal_dealt + extra
	enemy.flash = 0.14
	enemy.mark = {"source": source, "time": elapsed, "expires": elapsed + RESONANCE_WINDOW, "position": origin}
	if enemy.phase != "rush" and not bool(enemy.get("boss", false)):
		var knockback := 48.0 if weapon_kind == "bell" else 10.0
		enemy.position = arena.move(enemy.position, direction * knockback, float(enemy.radius))
	effects.append({"kind": "number", "position": enemy.position, "age": 0.0, "duration": 0.6, "text": str(roundi(normal_dealt)), "echo": is_echo})
	if resonance:
		resonance_hits += 1
		if float(enemy.hp) <= 0.0:
			resonance_kills += 1
		enemy.resonance_ready_at = elapsed + RESONANCE_COOLDOWN
		if not bool(enemy.get("resonance_rewarded", false)):
			experience += 1
			enemy.resonance_rewarded = true
		var stagger := float(modifiers.get("resonance_stagger", 0.0))
		if bool(enemy.get("boss", false)):
			stagger = minf(0.2, stagger)
		enemy.stagger = maxf(float(enemy.get("stagger", 0.0)), stagger)
		effects.append({"kind": "resonance", "position": enemy.position, "age": 0.0, "duration": 0.42, "damage": bonus, "echo": is_echo})
		audio_events.append("resonance")

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		shot.age = float(shot.age) + dt
		if float(shot.age) > float(shot.duration):
			projectiles.remove_at(i)
			continue
		if float(shot.age) < 0.0:
			continue
		if shot.kind == "bolt":
			shot.position += (shot.velocity as Vector2) * dt
			if not arena.is_clear(shot.position, 3.0):
				projectiles.remove_at(i)
			elif (shot.position as Vector2).distance_to(player) < PLAYER_RADIUS + float(shot.get("radius", 7.0)):
				take_damage(float(shot.damage), "projectile", str(shot.get("source", "archer")))
				projectiles.remove_at(i)
				if state != "playing":
					return
		elif shot.kind in ["moon", "bell"]:
			shot.current_radius = float(shot.radius) * minf(1.0, float(shot.age) / (0.75 if shot.kind == "bell" else 0.55))
			for enemy in enemies:
				if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or shot.hit_ids.has(enemy.id):
					continue
				var offset: Vector2 = (enemy.position as Vector2) - (shot.position as Vector2)
				var hit := offset.length() <= float(shot.current_radius) + float(enemy.radius)
				if shot.kind == "bell":
					hit = absf(offset.length() - float(shot.current_radius)) <= float(shot.width) * 0.5 + float(enemy.radius)
				if hit:
					shot.hit_ids.append(enemy.id)
					_hit(enemy, shot.payload, offset.normalized(), bool(shot.echo), shot.position)
		elif shot.kind == "thorn":
			var previous: Vector2 = shot.position
			shot.position += (shot.velocity as Vector2) * dt
			if not arena.is_clear(shot.position, 2.0):
				projectiles.remove_at(i)
				continue
			for enemy in enemies:
				if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or shot.hit_ids.has(enemy.id):
					continue
				if enemy.id in shot.cast_hit_ids:
					continue
				var closest := Geometry2D.get_closest_point_to_segment(enemy.position, previous, shot.position)
				if closest.distance_to(enemy.position) <= float(shot.radius) + float(enemy.radius):
					shot.hit_ids.append(enemy.id)
					shot.cast_hit_ids.append(enemy.id)
					_hit(enemy, shot.payload, shot.direction, bool(shot.echo), shot.position)
					if bool(shot.evolved):
						var patch_payload: Dictionary = shot.payload.duplicate(true)
						patch_payload.damage = float(shot.payload.damage) * (5.0 / 32.5)
						projectiles.append({"kind": "bramble", "position": enemy.position, "radius": 62.0, "current_radius": 62.0, "age": 0.0, "duration": 2.0, "echo": shot.echo, "evolved": true, "tick_at": 0.0, "payload": patch_payload})
					if shot.hit_ids.size() >= int(shot.payload.pierce):
						projectiles.remove_at(i)
						break
		elif shot.kind == "wisp":
			if _update_wisp(shot, dt):
				projectiles.remove_at(i)
		elif shot.kind in ["frost", "bramble"]:
			shot.tick_at = float(shot.tick_at) - dt
			if float(shot.tick_at) <= 0.0:
				shot.tick_at = 0.55
				for enemy in enemies:
					if enemy.phase != "arrival" and float(enemy.hp) > 0.0 and (enemy.position as Vector2).distance_to(shot.position) <= float(shot.radius) + float(enemy.radius):
						_hit(enemy, shot.payload, (shot.position as Vector2).direction_to(enemy.position), bool(shot.echo), shot.position)

func _update_wisp(shot: Dictionary, dt: float) -> bool:
	var targets := nearest_enemies(shot.position, 680.0)
	var target: Dictionary = {}
	for candidate in targets:
		if candidate.id not in shot.hit_ids:
			target = candidate
			break
	if target.is_empty():
		shot.position += (shot.velocity as Vector2) * dt
		return false
	var direction := (shot.position as Vector2).direction_to(target.position)
	var desired := direction * 275.0
	shot.velocity = (shot.velocity as Vector2).move_toward(desired, 980.0 * dt)
	var previous: Vector2 = shot.position
	shot.position += (shot.velocity as Vector2) * dt
	var closest := Geometry2D.get_closest_point_to_segment(target.position, previous, shot.position)
	if closest.distance_to(target.position) > 14.0 + float(target.radius):
		return false
	shot.hit_ids.append(target.id)
	var center: Vector2 = target.position
	effects.append({"kind": "wisp", "position": center, "radius": float(shot.payload.radius), "age": 0.0, "duration": 0.35, "echo": shot.echo, "evolved": shot.evolved})
	for enemy in nearest_enemies(center, float(shot.payload.radius) + 25.0):
		if (enemy.position as Vector2).distance_to(center) <= float(shot.payload.radius) + float(enemy.radius):
			_hit(enemy, shot.payload, center.direction_to(enemy.position), bool(shot.echo), center)
	if bool(shot.evolved) and int(shot.jumps) < 3:
		shot.jumps = int(shot.jumps) + 1
		shot.velocity = direction.orthogonal() * 200.0
		return false
	return true

func _cleanup_dead() -> void:
	var boss_killed := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if float(enemy.hp) > 0.0:
			continue
		kills += 1
		if bool(enemy.get("boss", false)):
			boss_killed = true
		else:
			var value := 1 if enemy.kind in ["hound", "bat"] else 2
			if bool(enemy.get("elite", false)):
				value = 9
				chests.append({"id": next_chest_id, "position": enemy.position, "opened": false, "elite": true})
				next_chest_id += 1
			pickups.append({"kind": "xp", "position": enemy.position, "value": value})
			if bool(enemy.get("elite", false)) or kills % 45 == 0:
				var drop_roles := ["heal", "magnet", "ward", "blast"]
				var role: String = drop_roles[int(maxi(0, kills / 45 - 1)) % drop_roles.size()]
				pickups.append({"kind": role, "position": enemy.position + Vector2(20, 0), "value": 20 if role == "heal" else 1})
			elif health < maximum_health * 0.55 and kills % 18 == 0:
				pickups.append({"kind": "heal", "position": enemy.position, "value": 20})
		if "blood_vial" in relics and kills % 12 == 0:
			health = minf(maximum_health, health + 2.0)
		effects.append({"kind": "vanish", "position": enemy.position, "age": 0.0, "duration": 0.32})
		enemies.remove_at(i)
	while pickups.size() > 320:
		var first := -1
		var second := -1
		for i in range(pickups.size()):
			if str(pickups[i].get("kind", "xp")) == "xp":
				if first < 0:
					first = i
				else:
					second = i
					break
		if second < 0:
			pickups.pop_front()
		else:
			pickups[second].value = int(pickups[second].value) + int(pickups[first].value)
			pickups.remove_at(first)
	if boss_killed and not _boss_defeated:
		_boss_defeated = true
		chapter_clears.append(chapter)
		hazards.clear()
		for i in range(projectiles.size() - 1, -1, -1):
			if projectiles[i].kind == "bolt":
				projectiles.remove_at(i)
		if chapter == Campaign.CHAPTER_COUNT - 1:
			_finish("victory")
		else:
			state = "chapter_clear"
			audio_events.append("chapter")

func _update_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		var distance := (pickup.position as Vector2).distance_to(player)
		var kind := str(pickup.get("kind", "xp"))
		var reach := pickup_radius if kind == "xp" else 56.0
		if _magnet_time > 0.0 and kind == "xp":
			reach = 4000.0
		if distance < reach:
			var velocity := 620.0 if _magnet_time > 0.0 else 330.0 + (reach - distance) * 2.3
			pickup.position = (pickup.position as Vector2).move_toward(player, velocity * dt)
		if (pickup.position as Vector2).distance_to(player) < 20.0:
			_collect_pickup(pickup)
			pickups.remove_at(i)
			if state != "playing":
				return
	check_level_up()

func _collect_pickup(pickup: Dictionary) -> void:
	var kind := str(pickup.get("kind", "xp"))
	match kind:
		"xp":
			var amount := float(pickup.value) * (1.2 if "magnet_ring" in relics else 1.0) + _experience_fraction
			var whole := floori(amount + 0.000001)
			experience += whole
			_experience_fraction = maxf(0.0, amount - float(whole))
			audio_events.append("pickup")
		"heal":
			health = minf(maximum_health, health + float(pickup.get("value", 20)))
			effects.append({"kind": "heal", "position": player, "radius": 32.0, "age": 0.0, "duration": 0.45})
			audio_events.append("heal")
		"magnet":
			_magnet_time = 4.0
			effects.append({"kind": "magnet", "position": player, "radius": 120.0, "age": 0.0, "duration": 0.6})
			audio_events.append("pickup")
		"ward":
			ward_charges = 1
			effects.append({"kind": "shield", "position": player, "radius": 38.0, "age": 0.0, "duration": 0.45})
			audio_events.append("shield")
		"blast":
			for enemy in enemies:
				if enemy.phase == "arrival" or float(enemy.hp) <= 0.0 or (enemy.position as Vector2).distance_to(player) > 420.0 + float(enemy.radius):
					continue
				var dealt := minf(float(enemy.hp), 75.0)
				enemy.hp = float(enemy.hp) - dealt
				enemy.flash = 0.2
				damage_summary.player += dealt
				damage_summary.by_weapon.blast += dealt
			for i in range(projectiles.size() - 1, -1, -1):
				if projectiles[i].kind == "bolt" and (projectiles[i].position as Vector2).distance_to(player) <= 420.0:
					projectiles.remove_at(i)
			effects.append({"kind": "blast", "position": player, "radius": 420.0, "age": 0.0, "duration": 0.6})
			audio_events.append("blast")

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

func _rect_snapshot(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}

func snapshot() -> Dictionary:
	var enemy_info: Array[Dictionary] = []
	for enemy in enemies:
		enemy_info.append({"id": enemy.id, "kind": enemy.kind, "x": snappedf(enemy.position.x, 0.1), "y": snappedf(enemy.position.y, 0.1), "radius": float(enemy.radius), "phase": enemy.phase, "timer": enemy.timer, "hp": snappedf(enemy.hp, 0.1), "max_hp": enemy.max_hp, "elite": bool(enemy.get("elite", false)), "boss": bool(enemy.get("boss", false)), "phase_index": int(enemy.get("phase_index", 1)), "mark_source": str(enemy.get("mark", {}).get("source", "")), "mark_expires": float(enemy.get("mark", {}).get("expires", 0.0))})
	var pickup_info: Array[Dictionary] = []
	for pickup in pickups:
		pickup_info.append({"x": pickup.position.x, "y": pickup.position.y, "kind": str(pickup.get("kind", "xp")), "value": int(pickup.value)})
	var chest_info: Array[Dictionary] = []
	for chest in chests:
		chest_info.append({"id": int(chest.id), "x": chest.position.x, "y": chest.position.y, "opened": bool(chest.opened), "elite": bool(chest.get("elite", false))})
	var hazard_info: Array[Dictionary] = []
	for hazard in hazards:
		var entry := {"shape": str(hazard.shape), "x": hazard.position.x, "y": hazard.position.y, "radius": float(hazard.radius), "width": float(hazard.width), "age": float(hazard.age), "delay": float(hazard.delay), "duration": float(hazard.duration), "damage": float(hazard.damage), "source": str(hazard.source)}
		if hazard.shape == "line":
			entry.from = {"x": hazard.from.x, "y": hazard.from.y}
			entry.to = {"x": hazard.to.x, "y": hazard.to.y}
		hazard_info.append(entry)
	var boss := boss_data()
	if not boss.is_empty():
		boss.x = boss.position.x
		boss.y = boss.position.y
		boss.radius = 44.0
		boss.erase("position")
	var solids: Array[Dictionary] = []
	for rect in _chapter_data.obstacles:
		solids.append(_rect_snapshot(rect))
	return {
		"state": state, "elapsed": elapsed, "chapter": chapter, "chapter_elapsed": chapter_elapsed, "chapter_stage": chapter_stage,
		"rank_cap": Spellbook.rank_cap(chapter), "chapter_name": _chapter_data.name, "chapter_clears": chapter_clears.duplicate(), "boss": boss, "phase": phase_info(),
		"specialization": specialization, "resonance_hits": resonance_hits, "resonance_kills": resonance_kills, "resonance_bonus": resonance_bonus,
		"health": health, "maximum_health": maximum_health, "max_health": maximum_health, "speed": speed, "pickup_radius": pickup_radius,
		"level": level, "kills": kills, "experience": experience, "experience_needed": experience_needed,
		"player": {"x": player.x, "y": player.y}, "echo": {"x": echo.x, "y": echo.y, "active": echo_active},
		"enemy_count": enemies.size(), "enemies": enemy_info, "weapons": weapons.duplicate(true), "equipment": equipment_info(),
		"player_shots": player_shots, "echo_shots": echo_shots, "projectiles": projectiles.size(),
		"pickup_count": pickups.size(), "pickups": pickup_info, "chests": chest_info, "hazards": hazard_info,
		"arena": {"bounded": true, "bounds": _rect_snapshot(_chapter_data.bounds), "obstacles": solids},
		"effects": effects.size(), "pending_echo_attacks": timeline.attacks.size(), "history_samples": timeline.positions.size(),
		"last_player_attack": last_player_attack.duplicate(true), "last_echo_attack": last_echo_attack.duplicate(true),
		"choices": choices.duplicate(true), "choice_phase": choice_phase, "rerolls_left": rerolls_left, "skips_left": skips_left,
		"ward_charges": ward_charges, "ward_cooldown": ward_cooldown, "damage_taken": damage_taken, "damage_received": damage_received.duplicate(),
		"last_damage_cause": last_damage_cause, "damage_summary": damage_summary.duplicate(true), "discoveries": discoveries.duplicate(true)
	}
