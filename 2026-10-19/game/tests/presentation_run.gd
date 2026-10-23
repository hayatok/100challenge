extends SceneTree
## State/event checks use production Run; only fixtures set up boundary states.

const Run = preload("res://scripts/run_model.gd")
const Presentation = preload("res://scripts/presentation.gd")
const Spellbook = preload("res://scripts/spellbook.gd")

class MinimalState:
	extends RefCounted
	var state := "playing"
	var elapsed := 0.0
	var chapter := 0
	var chapter_elapsed := 0.0
	var chapter_stage := "assault"
	var player := Vector2.ZERO
	var echo := Vector2.ZERO
	var echo_active := false
	var facing := 1.0
	var health := 100.0
	var enemies: Array[Dictionary] = []
	var effects: Array[Dictionary] = []
	var pickups: Array[Dictionary] = []
	var chests: Array[Dictionary] = []

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_minimal_fixture_and_same_clock()
	_test_actual_movement_and_echo()
	_test_separate_casts_and_hit()
	_test_health_cap_change_is_not_damage()
	_test_enemy_phases_and_direction()
	_test_effect_identity_and_collect()
	_test_death_and_bulk_clear()
	_test_chapters_retry_and_terminal_states()
	_test_caps_priorities_and_retention()
	if failures.is_empty():
		print("PRESENTATION_PASS " + JSON.stringify({"checks": checks, "repeated_clock_updates": 1050, "retry_cycles": 100, "event_limit": Presentation.MAX_EVENTS, "death_limit": Presentation.MAX_DEATHS, "gameplay_read_only": true}))
		quit(0)
	else:
		for message in failures:
			push_error("FAIL: " + message)
		quit(1)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func empty_run():
	var run = Run.new()
	run.reset(true, 731)
	run.enemies.clear()
	run.chests.clear()
	run.spawn_clock = 10000.0
	for key in Spellbook.WEAPON_IDS:
		run.cooldowns[key] = 10000.0
	return run

func enemy_fixture(run, kind: String = "hound", at: Vector2 = Vector2(160, 0)) -> Dictionary:
	var enemy: Dictionary = run.spawn_enemy(kind, at)
	enemy.phase = "seek"
	enemy.timer = 0.0
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	enemy.speed = 0.0
	enemy.cooldown = 10000.0
	enemy.contact_ready_at = 10000.0
	return enemy

func advance(run, presentation, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	for i in range(roundi(seconds * 60.0)):
		run.tick(1.0 / 60.0, movement)
		presentation.update(run)

func count_events(presentation, kind: String, actor: String = "") -> int:
	var result := 0
	for event in presentation.events:
		if str(event.kind) == kind and (actor.is_empty() or str(event.get("actor", "")) == actor):
			result += 1
	return result

func last_event(presentation, kind: String) -> Dictionary:
	for i in range(presentation.events.size() - 1, -1, -1):
		if str(presentation.events[i].kind) == kind:
			return presentation.events[i]
	return {}

func _test_minimal_fixture_and_same_clock() -> void:
	var fixture := MinimalState.new()
	var presentation = Presentation.new()
	presentation.update(fixture)
	expect(presentation.player_pose.animation == "idle" and presentation.enemy_poses.is_empty(), "Minimal renderer fixture has explicit optional-counter fallbacks")
	var stable: Dictionary = presentation.snapshot()
	for i in range(300):
		presentation.update(fixture)
	expect(presentation.snapshot() == stable, "Repeated identical elapsed values do not advance frames, events, or generations")
	fixture.effects.append({"kind": "resonance", "position": Vector2(40, 20), "age": 0.0, "duration": 0.42})
	presentation.update(fixture)
	expect(count_events(presentation, "resonance") == 1, "New age-zero effect is recognized at the same clock")
	var with_effect: Dictionary = presentation.snapshot()
	for state in ["paused", "upgrade", "treasure", "chapter_clear", "victory", "defeat"]:
		fixture.state = state
		presentation.update(fixture)
		var frozen: Dictionary = presentation.snapshot()
		for i in range(50):
			presentation.update(fixture)
		expect(presentation.snapshot() == frozen, "All visual fields freeze in " + state)
	expect(presentation.latest_serial > int(with_effect.latest_serial), "Terminal/chapter state events are observed without advancing the clock")
	expect(count_events(presentation, "victory") == 1 and count_events(presentation, "defeat") == 1, "Each same-clock terminal transition emits once")
	fixture.enemies.append({"id": 101, "kind": "hound", "position": Vector2(160, 0), "hp": 28.0})
	fixture.state = "title"
	presentation.update(fixture)
	expect(presentation.events.is_empty() and presentation.deaths.is_empty() and presentation.camera_impulse == 0.0, "Title clears event/death/camera residue")
	expect(presentation.enemy_poses.is_empty() and int(presentation.snapshot().effect_keys) == 0, "Title cannot retain hidden combat actor/effect tracking")
	presentation.update(null)
	expect(presentation.player_pose.is_empty() and presentation.enemy_poses.is_empty(), "Detached renderer releases its tracked state")

func _test_actual_movement_and_echo() -> void:
	var run = empty_run()
	var presentation = Presentation.new()
	presentation.update(run)
	advance(run, presentation, 0.1, Vector2.LEFT)
	expect(presentation.player_pose.animation == "walk" and int(presentation.player_pose.facing) == -1 and float(presentation.player_pose.gait) > 0.0, "Player gait/facing follows real displacement")
	var gait := float(presentation.player_pose.gait)
	advance(run, presentation, 0.1)
	expect(presentation.player_pose.animation == "idle" and is_equal_approx(float(presentation.player_pose.gait), gait), "Standing still stops walking and its gait")
	# A commanded move into the arena edge has zero real displacement.
	run.player = Vector2(run.arena.bounds.end.x - Run.PLAYER_RADIUS - 1.0, 0.0)
	run.timeline.reset(run.player)
	presentation.update(run)
	advance(run, presentation, 0.1, Vector2.RIGHT)
	expect(presentation.player_pose.animation == "idle" and not bool(presentation.player_pose.moving), "Blocked input cannot manufacture a walk cycle")
	var delayed = empty_run()
	var afterimage = Presentation.new()
	afterimage.update(delayed)
	advance(delayed, afterimage, 0.4, Vector2.LEFT)
	advance(delayed, afterimage, 1.8)
	expect(delayed.echo_active and afterimage.player_pose.animation == "idle" and afterimage.echo_pose.animation == "walk" and int(afterimage.echo_pose.facing) == -1, "Echo walks from its two-second-old movement while the body is idle")
	advance(delayed, afterimage, 0.5)
	expect(afterimage.echo_pose.animation == "idle", "Echo stops when the delayed position stops")
	expect(count_events(afterimage, "footstep", "echo") <= 8, "Footsteps remain a bounded visual trail")

func _test_separate_casts_and_hit() -> void:
	var run = empty_run()
	var presentation = Presentation.new()
	presentation.update(run)
	var rng_before: int = run.rng.state
	run.cast({"kind": "moon", "damage": 1.0, "count": 1, "radius": 10.0}, run.player, false)
	presentation.update(run)
	expect(presentation.player_pose.animation == "cast" and float(presentation.echo_pose.cast) == 0.0, "Player shot increments affect only the body")
	expect(last_event(presentation, "cast").weapon == "moon", "Cast event exposes its actual weapon")
	advance(run, presentation, 0.5)
	run.cast({"kind": "thorn", "damage": 1.0, "count": 1, "radius": 4.0, "range": 80.0, "pierce": 1}, run.echo, true)
	presentation.update(run)
	expect(presentation.player_pose.animation == "idle" and presentation.echo_pose.animation == "cast", "Echo increments drive an independent cast phase")
	var echo_cast := last_event(presentation, "cast")
	expect(bool(echo_cast.echo) and echo_cast.actor == "echo" and echo_cast.weapon == "thorn", "Echo event retains source and weapon")
	var before: Dictionary = run.snapshot()
	presentation.update(run)
	expect(run.snapshot() == before and run.rng.state == rng_before, "Presentation neither mutates model state nor consumes gameplay RNG")
	run.invulnerable = 0.0
	run.take_damage(8.0)
	presentation.update(run)
	expect(presentation.player_pose.animation == "hit" and float(presentation.player_pose.hit) > 0.9, "Damage starts the player's hit pose")
	expect(last_event(presentation, "hit").target == "player", "Player hit event identifies its target")
	var hit_serial := int(presentation.latest_serial)
	for i in range(100):
		presentation.update(run)
	expect(presentation.latest_serial == hit_serial and count_events(presentation, "hit", "player") == 1, "Repeated paused-age damage does not duplicate hits")

func _test_health_cap_change_is_not_damage() -> void:
	var run = empty_run()
	for reward in ["relic:blood_vial", "relic:moonstone", "relic:magnet_ring", "heal"]:
		run.state = "treasure"
		run.choices.assign([Spellbook.offer(reward, run.weapons, run.speed, run.maximum_health)])
		expect(run.choose_upgrade(0), "Health-cap regression setup applies the real reward API: " + reward)
	expect(run.health == 124.0 and run.maximum_health == 124.0, "Blood vial and healing establish the expanded health cap")
	var presentation = Presentation.new()
	presentation.update(run)
	var replacement := Spellbook.offer("relic:swift_boots", run.weapons, run.speed, run.maximum_health)
	replacement.full_slots = true
	run.state = "treasure"
	run.choices.assign([replacement])
	expect(run.choose_upgrade(0) and run.choice_phase == "replace", "Full relic slots enter the real replacement flow")
	presentation.update(run)
	var blood_slot := -1
	for i in range(run.choices.size()):
		if str(run.choices[i].get("replace_id", "")) == "blood_vial":
			blood_slot = i
	expect(blood_slot >= 0 and run.choose_upgrade(blood_slot), "The real replacement API removes blood vial")
	expect(run.health == 100.0 and run.maximum_health == 100.0 and run.damage_taken == 0.0, "Replacing blood vial clamps health without taking damage")
	presentation.update(run)
	expect(count_events(presentation, "hit", "player") == 0 and presentation.player_pose.animation == "idle" and float(presentation.player_pose.hit) == 0.0 and presentation.camera_impulse == 0.0, "A health-cap clamp cannot create a hit pose, sparks, or camera impulse")
	run.invulnerable = 0.0
	run.take_damage(8.0)
	presentation.update(run)
	expect(count_events(presentation, "hit", "player") == 1 and presentation.player_pose.animation == "hit" and is_equal_approx(float(last_event(presentation, "hit").amount), 8.0), "Real damage still emits the player hit with the recorded damage amount")
	var fixture := MinimalState.new()
	var fallback = Presentation.new()
	fallback.update(fixture)
	fixture.health -= 8.0
	fallback.update(fixture)
	expect(count_events(fallback, "hit", "player") == 1 and fallback.player_pose.animation == "hit", "An explicit fixture without damage_taken retains the health-delta fallback")

func _test_enemy_phases_and_direction() -> void:
	var run = empty_run()
	var enemy := enemy_fixture(run, "charger")
	enemy.phase = "arrival"
	enemy.timer = 0.45
	var presentation = Presentation.new()
	presentation.update(run)
	var pose: Dictionary = presentation.enemy_poses[int(enemy.id)]
	expect(pose.animation == "arrival" and is_equal_approx(float(pose.phase_progress), 0.5), "Arrival uses the actual remaining arrival timer")
	enemy.phase = "warning"
	enemy.timer = 0.475
	enemy.direction = Vector2.LEFT
	presentation.update(run)
	expect(pose.animation == "warning" and is_equal_approx(float(pose.phase_progress), 0.5), "Warning animation shares the authoritative telegraph timer")
	expect(int(pose.facing) == -1, "Stationary warnings face the locked attack direction")
	enemy.phase = "rush"
	enemy.timer = 0.335
	presentation.update(run)
	expect(pose.animation == "rush" and is_equal_approx(float(pose.phase_progress), 0.5), "Charger rush is distinct from its warning")
	enemy.phase = "recover"
	enemy.timer = 0.35
	presentation.update(run)
	expect(pose.animation == "recover" and is_equal_approx(float(pose.phase_progress), 0.5), "Charger recovery has its own phase")
	enemy.phase = "seek"
	enemy.position -= Vector2(10.0, 0.0)
	run.elapsed += 0.1
	run.chapter_elapsed += 0.1
	presentation.update(run)
	expect(pose.animation == "walk" and int(pose.facing) == -1, "Enemy facing follows actual movement, including retreat")
	enemy.flash = 0.14
	enemy.hp -= 4.0
	presentation.update(run)
	expect(pose.animation == "hit" and last_event(presentation, "hit").target == "enemy", "Enemy flash creates a target-specific hit pose and event")
	for kind in ["archer", "wisp", "sentinel", "boss_thorn", "boss_mirror", "boss_bell"]:
		var attacker := enemy_fixture(run, kind, Vector2(400, 200))
		attacker.phase = "warning"
		attacker.timer = 0.01
		presentation.update(run)
		attacker.phase = "seek"
		presentation.update(run)
		expect(presentation.enemy_poses[int(attacker.id)].animation == "cast", kind + " casts when its warning resolves")
		if bool(attacker.boss):
			attacker.phase_index = 2
			presentation.update(run)
			var phase := last_event(presentation, "boss_phase")
			expect(phase.boss_kind == kind and int(phase.phase) == 2, "Boss phase identifies the real boss and phase")
	for kind in ["hound", "bat"]:
		var contact_run = empty_run()
		var biter := enemy_fixture(contact_run, kind, Vector2.ZERO)
		biter.contact_ready_at = 0.0
		var contact_pose = Presentation.new()
		contact_pose.update(contact_run)
		advance(contact_run, contact_pose, 1.0 / 60.0)
		expect(float(contact_run.damage_received.contact) > 0.0 and contact_pose.enemy_poses[int(biter.id)].animation == "cast" and last_event(contact_pose, "cast").actor_kind == kind, kind + " bite pose is tied to actual contact damage")

func _test_effect_identity_and_collect() -> void:
	var run = empty_run()
	var presentation = Presentation.new()
	presentation.update(run)
	var effect := {"kind": "resonance", "position": Vector2(40, 20), "age": 0.0, "duration": 0.42, "echo": true, "damage": 12.0}
	run.effects.append(effect)
	run.effects.append(effect.duplicate())
	presentation.update(run)
	expect(count_events(presentation, "resonance") == 2, "Identical simultaneous effects retain occurrence multiplicity")
	var effects_before: Array = run.effects.duplicate(true)
	var serial := int(presentation.latest_serial)
	advance(run, presentation, 0.1)
	expect(presentation.latest_serial == serial, "An existing effect is not harvested again as it ages")
	expect(float(effects_before[0].age) == 0.0 and is_equal_approx(float(effect.age), 0.1), "Effect ages remain owned by the production model")
	run.effects.clear()
	advance(run, presentation, 0.5)
	expect(int(presentation.snapshot().effect_keys) == 0 and count_events(presentation, "resonance") == 0, "Expired effects release both feedback and deduplication keys")
	var pickup := {"kind": "xp", "position": run.player + Vector2(24, 0), "value": 1}
	run.pickups.append(pickup)
	presentation.update(run)
	advance(run, presentation, 0.05)
	expect(count_events(presentation, "collect") == 1 and last_event(presentation, "collect").pickup_kind == "xp", "Collection is inferred from the pickup's final near-player removal")
	var remote := {"kind": "xp", "position": Vector2(700, 500), "value": 1}
	run.pickups.append(remote)
	presentation.update(run)
	run.pickups.clear()
	var collect_serial := int(presentation.latest_serial)
	presentation.update(run)
	expect(presentation.latest_serial == collect_serial, "Remote pickup cleanup does not invent a collection")
	var resonance_experience := int(run.experience)
	run.experience = resonance_experience + 1
	presentation.update(run)
	expect(presentation.latest_serial == collect_serial, "Experience gained without a pickup is not reported as a collection")
	run.chests.append({"id": 91, "position": Vector2(0, 40), "opened": false, "elite": true})
	presentation.update(run)
	expect(count_events(presentation, "chest") == 1 and not bool(last_event(presentation, "chest").opened), "A new chest emits a spawn cue once")
	run.chests[0].opened = true
	run.state = "treasure"
	presentation.update(run)
	expect(bool(last_event(presentation, "chest").opened), "Opening a chest is recognized on the frozen treasure clock")
	run.level += 1
	run.state = "upgrade"
	presentation.update(run)
	run.weapons.moon.evolved = true
	presentation.update(run)
	expect(count_events(presentation, "level") == 1 and count_events(presentation, "evolution") == 1 and last_event(presentation, "evolution").weapon == "moon", "Level/evolution state changes are observed once without clock advance")

func _test_death_and_bulk_clear() -> void:
	var run = empty_run()
	var poisoned := enemy_fixture(run, "bat", Vector2(-250, 180))
	poisoned.hp = 1.0
	poisoned.poison_left = 1.0
	poisoned.poison_dps = 100.0
	var presentation = Presentation.new()
	presentation.update(run)
	advance(run, presentation, 1.0 / 60.0)
	expect(presentation.deaths.size() == 1 and presentation.deaths[0].kind == "bat", "Poison death preserves the removed enemy's actual species")
	expect(last_event(presentation, "kill").actor_kind == "bat" and not presentation.enemy_poses.has(int(poisoned.id)), "Poison kill releases the live tracker and preserves its kill identity")
	advance(run, presentation, 0.2)
	expect(presentation.deaths.size() == 1 and float(presentation.deaths[0].pose.phase_progress) > 0.3, "Death progresses on the same simulation clock")
	run.pause("focus")
	var frozen: Dictionary = presentation.snapshot()
	for i in range(50):
		run.tick(1.0)
		presentation.update(run)
	expect(presentation.snapshot() == frozen, "Focus-loss pause freezes death, event, and camera ages together")
	run.resume()
	advance(run, presentation, 0.4)
	expect(presentation.deaths.is_empty(), "Death records expire after their short duration")
	var wave = empty_run()
	for kind in ["hound", "bat", "wisp", "sentinel"]:
		enemy_fixture(wave, kind, Vector2(300, 200))
	var entrance = Presentation.new()
	entrance.update(wave)
	wave._start_boss()
	entrance.update(wave)
	expect(entrance.deaths.is_empty() and count_events(entrance, "kill") == 0, "Boss threshold bulk deletion never becomes phantom enemy deaths")
	expect(count_events(entrance, "boss_arrival") == 1 and last_event(entrance, "boss_arrival").boss_kind == "boss_thorn", "Boss entrance emits one named real-boss event")
	var old_generation := int(entrance.generation)
	wave.elapsed = 0.0
	wave.chapter_elapsed = 0.0
	wave.reset(true, 731)
	entrance.update(wave)
	expect(entrance.generation > old_generation and entrance.events.is_empty() and entrance.deaths.is_empty(), "Same-clock retry detects the replaced timeline history and clears feedback")

func _test_chapters_retry_and_terminal_states() -> void:
	var run = empty_run()
	var presentation = Presentation.new()
	presentation.update(run)
	for chapter in range(3):
		run._start_boss()
		presentation.update(run)
		var boss: Dictionary = run.enemies[0]
		boss.hp = 0.0
		run._cleanup_dead()
		presentation.update(run)
		expect(presentation.deaths.size() == 1 and bool(presentation.deaths[0].boss), "Chapter boss receives a real death record in chapter %d" % chapter)
		if chapter < 2:
			expect(run.state == "chapter_clear" and bool(last_event(presentation, "chapter").clear), "Chapter clear is recognized at the same elapsed value")
			var previous_generation := int(presentation.generation)
			expect(run.next_chapter(), "Production chapter transition succeeds")
			presentation.update(run)
			expect(presentation.generation == previous_generation + 1 and presentation.deaths.is_empty() and presentation.events.size() == 1 and not bool(last_event(presentation, "chapter").clear), "Next chapter clears all prior poses/effects and emits one new chapter event")
			expect(presentation.enemy_poses.size() == run.enemies.size() and float(presentation.echo_pose.cast) == 0.0 and float(presentation.player_pose.gait) == 0.0, "New chapter starts with current enemy IDs and clean actor history")
		else:
			expect(run.state == "victory" and count_events(presentation, "victory") == 1, "Third chapter's boss triggers one victory event")
	run.reset(true, 731)
	presentation.update(run)
	run.invulnerable = 0.0
	run.take_damage(1000.0)
	presentation.update(run)
	expect(presentation.player_pose.animation == "death" and float(presentation.player_pose.phase_progress) == 1.0 and count_events(presentation, "defeat") == 1, "Defeat holds the completed player death pose on the frozen terminal clock")
	run.reset(true, 731)
	presentation.update(run)
	expect(presentation.events.is_empty() and presentation.camera_impulse == 0.0 and presentation.player_pose.animation == "idle", "Retry clears terminal feedback and restores the idle actor")

func _test_caps_priorities_and_retention() -> void:
	var run = empty_run()
	var presentation = Presentation.new()
	presentation.update(run)
	var boss := enemy_fixture(run, "boss_bell")
	presentation.update(run)
	for i in range(100):
		var enemy := enemy_fixture(run, "hound", Vector2(200 + i, 100))
		presentation.update(run)
		enemy.flash = 0.14
		enemy.hp -= 2.0
		presentation.update(run)
	expect(presentation.events.size() <= Presentation.MAX_EVENTS and count_events(presentation, "hit") <= 18, "Large hit bursts obey event and per-kind caps")
	expect(count_events(presentation, "boss_arrival") == 1 and last_event(presentation, "boss_arrival").boss_kind == "boss_bell", "Ordinary hit density cannot evict a major boss cue")
	for i in range(100):
		run.effects.append({"kind": "shield", "position": Vector2(i * 5.0, 0), "age": 0.0, "duration": 0.45})
	presentation.update(run)
	expect(presentation.events.size() == Presentation.MAX_EVENTS and count_events(presentation, "boss_arrival") == 1, "Global event saturation obeys its cap and retains the major cue")
	boss.phase_index = 2
	presentation.update(run)
	for enemy in run.enemies:
		enemy.hp = 0.0
	run._cleanup_dead()
	presentation.update(run)
	expect(presentation.deaths.size() == Presentation.MAX_DEATHS and presentation.events.size() <= Presentation.MAX_EVENTS, "A mass kill obeys the death and event pool limits")
	var boss_death := false
	for death in presentation.deaths:
		boss_death = boss_death or bool(death.boss)
	expect(boss_death, "Ordinary deaths cannot evict the boss's death animation")
	expect(count_events(presentation, "boss_phase") == 1 and count_events(presentation, "boss_arrival") == 1, "Mass kills preserve major boss cues")
	var previous_serial := 0
	for event in presentation.events:
		expect(int(event.serial) > previous_serial, "Retained events remain in monotonic serial order")
		previous_serial = int(event.serial)
	var stable: Dictionary = presentation.snapshot()
	var object_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in range(300):
		presentation.update(run)
	expect(presentation.snapshot() == stable, "Hundreds of frozen mass-kill refreshes leave state and pool counts unchanged")
	expect(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= object_count + 1, "Frozen refreshes do not allocate retained Godot objects")
	for cycle in range(100):
		run.reset(true, 731 + cycle)
		run.enemies.clear()
		run.chests.clear()
		presentation.update(run)
		var diagnostics: Dictionary = presentation.snapshot()
		expect(int(diagnostics.tracked_enemy_count) == 0 and int(diagnostics.effect_keys) == 0 and int(diagnostics.pickup_refs) == 0 and int(diagnostics.chest_keys) == 0 and presentation.events.is_empty() and presentation.deaths.is_empty(), "Retry cycle %d releases all removed actor/effect/pickup/chest tracking" % cycle)
		var enemy := enemy_fixture(run, "wisp")
		presentation.update(run)
		enemy.hp = 0.0
		run._cleanup_dead()
		presentation.update(run)
		expect(presentation.deaths.size() == 1 and presentation.enemy_poses.is_empty(), "Retry cycle %d never confuses reused enemy IDs" % cycle)
