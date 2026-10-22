extends RefCounted
## Read-only pilot of the normal production APIs. No HP, clock, inventory, or enemy overrides.

const Run = preload("res://scripts/run_model.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const DT := 1.0 / 30.0

static func play(seed_value: int, starter: String, preferred: Array, relic_preferences: Array, specialization_id: String) -> Dictionary:
	var run = Run.new()
	run.reset(true, seed_value, starter)
	var pilot := {"id": 99, "position": Vector2.ZERO, "radius": 14.0, "nav_clock": 0.0, "nav_path": PackedVector2Array()}
	var patrol := [Vector2(0, -120), Vector2(800, -550), Vector2(820, 500), Vector2(0, 160), Vector2(-800, 520), Vector2(-820, -500)]
	var patrol_index := 0
	var decisions := 0
	var replacements := 0
	var rerolls_used := 0
	var skips_used := 0
	var last_major_time := 0.0
	var last_evolution_time := 0.0
	var decision_breakdown := {"weapon": 0, "relic": 0, "evolution": 0, "specialization": 0, "heal": 0, "replacement_offer": 0, "replacement_confirm": 0}
	var choice_log: Array[Dictionary] = []
	var chapter_times: Array[Dictionary] = []
	var boss_entries: Array[Dictionary] = []
	var last_boss_chapter := -1
	var max_enemies := 0
	var max_projectiles := 0
	var min_health := 100.0
	var steps := 0
	var last_chapter := -1
	while steps < 36000 and run.state not in ["victory", "defeat"]:
		if run.state in ["upgrade", "treasure"]:
			if run.choice_phase == "offer" and not has_productive_card(run, preferred, relic_preferences) and not run.choices[0].specialization:
				if run.reroll_choices():
					rerolls_used += 1
					continue
				if run.health >= run.maximum_health - 2.0 and run.skip_choice():
					skips_used += 1
					continue
			var choice := select_card(run, preferred, relic_preferences, specialization_id)
			var source_before: String = run.state
			var phase_before: String = run.choice_phase
			var selected: Dictionary = run.pending_item.duplicate(true) if phase_before == "replace" else run.choices[choice].duplicate(true)
			if run.choice_phase == "replace":
				replacements += 1
			if not run.choose_upgrade(choice):
				return {"error": "normal chooser rejected offered card", "seed": seed_value, "state": run.state, "phase": run.choice_phase, "choice": choice, "choices": run.choices.duplicate(true), "pending": run.pending_item.duplicate(true), "equipment": run.equipment_info(), "level": run.level}
			decisions += 1
			if phase_before == "offer" and run.choice_phase == "replace":
				decision_breakdown.replacement_offer += 1
			else:
				var kind := str(selected.kind)
				decision_breakdown[kind] = int(decision_breakdown.get(kind, 0)) + 1
				if phase_before == "replace":
					decision_breakdown.replacement_confirm += 1
				if kind != "heal":
					last_major_time = run.elapsed
				if kind == "evolution":
					last_evolution_time = run.elapsed
				choice_log.append({"at": snappedf(run.elapsed, 0.1), "chapter": run.chapter, "stage": run.chapter_stage, "chapter_elapsed": snappedf(run.chapter_elapsed, 0.1), "source": source_before, "id": selected.id, "kind": kind})
			continue
		if run.state == "chapter_clear":
			chapter_times.append({"chapter": run.chapter, "elapsed": run.elapsed, "chapter_elapsed": run.chapter_elapsed, "hp": run.health, "level": run.level, "damage_taken": run.damage_taken})
			run.next_chapter()
			continue
		if run.chapter != last_chapter:
			pilot.nav_path = PackedVector2Array()
			pilot.nav_clock = 0.0
			patrol_index = 0
			last_chapter = run.chapter
		pilot.position = run.player
		var boss: Dictionary = run.boss_data()
		if not boss.is_empty() and run.chapter != last_boss_chapter:
			boss_entries.append({"chapter": run.chapter, "at": run.elapsed, "health": run.health, "damage_taken": run.damage_taken})
			last_boss_chapter = run.chapter
		var goal: Vector2
		if not boss.is_empty():
			var radial := (run.player as Vector2) - (boss.position as Vector2)
			if radial.length_squared() < 1.0:
				radial = Vector2.RIGHT
			var orbit_sign := 1.0 if int(run.elapsed / 13.0) % 2 == 0 else -1.0
			goal = (boss.position as Vector2) + radial.normalized().rotated(0.55 * orbit_sign) * 255.0
			goal = run.arena.safe_point(goal)
			for pickup in run.pickups:
				if str(pickup.get("kind", "xp")) == "heal" and run.health < 75.0 and (run.player as Vector2).distance_to(pickup.position) < 650.0:
					goal = pickup.position
					break
		else:
			if (run.player as Vector2).distance_to(patrol[patrol_index]) < 100.0:
				patrol_index = (patrol_index + 1) % patrol.size()
			goal = patrol[patrol_index]
			var score := 0.0
			for chest in run.chests:
				if bool(chest.opened):
					continue
				var distance := (run.player as Vector2).distance_to(chest.position)
				var value := 1600.0 / (distance + 120.0)
				if value > score:
					score = value
					goal = chest.position
			for pickup in run.pickups:
				var distance := (run.player as Vector2).distance_to(pickup.position)
				if distance > 570.0:
					continue
				var role := str(pickup.get("kind", "xp"))
				var priority := float(pickup.value) * 200.0 if role == "xp" else 360.0
				if role == "heal" and run.health < 85.0:
					priority = 1800.0
				elif role == "heal":
					priority = 30.0
				var value := priority / (distance + 70.0)
				if value > score:
					score = value
					goal = pickup.position
		var route: Vector2 = run.arena.route(pilot, goal, DT)
		var movement := safe_direction(run, route, DT)
		run.tick(DT, movement)
		run.drain_audio()
		max_enemies = maxi(max_enemies, run.enemies.size())
		max_projectiles = maxi(max_projectiles, run.projectiles.size())
		min_health = minf(min_health, run.health)
		steps += 1
	if run.state == "victory":
		chapter_times.append({"chapter": run.chapter, "elapsed": run.elapsed, "chapter_elapsed": run.chapter_elapsed, "hp": run.health, "level": run.level, "damage_taken": run.damage_taken})
	return {"seed": seed_value, "starter": starter, "state": run.state, "elapsed": run.elapsed, "chapter": run.chapter, "stage": run.chapter_stage, "chapter_times": chapter_times, "boss_entries": boss_entries, "health": run.health, "minimum_health": min_health, "level": run.level, "kills": run.kills, "resonance_hits": run.resonance_hits, "damage_taken": run.damage_taken, "damage_received": run.damage_received.duplicate(), "damage_summary": run.damage_summary.duplicate(true), "equipment": run.equipment_info(), "decisions": decisions, "decision_breakdown": decision_breakdown, "last_major_time": last_major_time, "last_evolution_time": last_evolution_time, "choice_log": choice_log, "replacements": replacements, "rerolls_used": rerolls_used, "skips_used": skips_used, "max_enemies": max_enemies, "max_projectiles": max_projectiles, "history_samples": run.timeline.positions.size(), "discoveries": run.discoveries.duplicate(true)}

static func has_productive_card(run, preferred: Array, relic_preferences: Array) -> bool:
	for card in run.choices:
		if card.kind in ["evolution", "specialization"]:
			return true
		if card.kind == "weapon" and str(card.get("item_id", "")) in preferred:
			return true
		if card.kind == "relic" and str(card.get("item_id", "")) in relic_preferences:
			return true
		if card.kind == "heal" and run.health < 75.0:
			return true
	return false

static func select_card(run, preferred: Array, relic_preferences: Array, specialization_id: String) -> int:
	var best := 0
	var best_score := -100000.0
	for i in range(run.choices.size()):
		var card: Dictionary = run.choices[i]
		var score := 0.0
		if run.choice_phase == "replace":
			var old := str(card.replace_id)
			var order := relic_preferences if run.pending_item.kind == "relic" else preferred
			var priority := order.find(old)
			score = 100.0 if priority < 0 else float(priority) * 10.0
		else:
			var id := str(card.id)
			var item := str(card.get("item_id", ""))
			if id == specialization_id:
				score = 300.0
			elif card.kind == "evolution":
				score = 220.0
			elif card.kind == "weapon" and item in preferred:
				var rank := int(run.weapons[item].level)
				score = 130.0 - float(preferred.find(item)) * 10.0 + float(rank) * 3.0
				if rank == 0:
					score += 10.0 if Spellbook.equipped_ids(run.weapons).size() < 3 else -80.0
			elif card.kind == "relic" and item in relic_preferences:
				score = 145.0 - float(relic_preferences.find(item)) * 12.0
				if run.relics.size() >= 3:
					score -= 70.0
			elif id == "heal":
				score = 190.0 if run.health < 62.0 else 15.0
			elif card.kind == "weapon" and int(run.weapons[item].level) > 0:
				score = 50.0
			elif card.kind == "relic" and run.relics.size() < 3:
				score = 30.0
			else:
				score = -15.0
		if score > best_score:
			best_score = score
			best = i
	return best

static func safe_direction(run, route: Vector2, _dt: float) -> Vector2:
	var best := route
	var best_score := -1000000.0
	for i in range(17):
		var candidate := Vector2.ZERO if i == 16 else Vector2.from_angle(float(i) * TAU / 16.0)
		var prediction: Array[Vector2] = []
		var predicted: Vector2 = run.player
		for step in range(24):
			predicted = run.arena.move(predicted, candidate * run.speed * 0.03)
			if step % 6 == 5:
				prediction.append(predicted)
		var future: Vector2 = prediction[2]
		var advance: Vector2 = future - (run.player as Vector2)
		var score := candidate.dot(route) * 3.5
		if candidate.length_squared() > 0.0 and advance.length() < run.speed * 0.54 * 0.65:
			score -= 5.0
		for enemy in run.enemies:
			if float(enemy.hp) <= 0.0 or enemy.phase == "arrival":
				continue
			var radius := float(enemy.radius) + 60.0
			var distance := future.distance_to(enemy.position)
			if distance < radius + 80.0:
				score -= maxf(0.0, (radius + 80.0 - distance) / 24.0)
			if enemy.phase == "rush":
				var end: Vector2 = (enemy.position as Vector2) + (enemy.direction as Vector2) * 160.0
				score -= maxf(0.0, (60.0 - future.distance_to(Geometry2D.get_closest_point_to_segment(future, enemy.position, end))) / 7.0)
		for hazard in run.hazards:
			# Check the whole proposed journey at the actual future activation times.
			# A safe endpoint is not enough if the pilot crosses a live line to get there.
			for horizon_index in range(4):
				var horizon := 0.18 * float(horizon_index + 1)
				var at_age := float(hazard.age) + horizon
				if at_age < float(hazard.delay) or at_age >= float(hazard.delay) + float(hazard.duration):
					continue
				var at: Vector2 = prediction[horizon_index]
				var danger := 0.0
				match str(hazard.shape):
					"circle": danger = float(hazard.radius) + 28.0 - at.distance_to(hazard.position)
					"ring": danger = float(hazard.width) * 0.5 + 28.0 - absf(at.distance_to(hazard.position) - float(hazard.radius))
					"line": danger = float(hazard.width) * 0.5 + 28.0 - at.distance_to(Geometry2D.get_closest_point_to_segment(at, hazard.from, hazard.to))
				if danger > 0.0:
					score -= 10.0 + danger * 0.15
		for shot in run.projectiles:
			if shot.kind == "bolt":
				var end: Vector2 = (shot.position as Vector2) + (shot.velocity as Vector2) * 0.5
				var distance := future.distance_to(Geometry2D.get_closest_point_to_segment(future, shot.position, end))
				if distance < 50.0:
					score -= (50.0 - distance) * 0.1
		if score > best_score:
			best_score = score
			best = candidate
	return best
