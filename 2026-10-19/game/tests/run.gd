extends SceneTree

const Run = preload("res://scripts/run_model.gd")
const Timeline = preload("res://scripts/echo_timeline.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_exact_history()
	_test_production_echo_and_snapshot()
	_test_freeze_and_choices()
	_test_invulnerability_and_outcomes()
	_test_reset()
	_test_resonance()
	_test_resonance_restrictions()
	_test_phase_spawning_and_arrival()
	_test_specializations_and_caps()
	_test_lightning_shared_hits()
	_test_experience_pacing()
	if failures.is_empty():
		print("PASS: %d production checks (echo, immutable attacks, retarget, freeze, upgrades, reset, outcomes, resonance, phases, specialization)" % checks)
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func empty_run():
	var run = Run.new()
	run.reset(true, 731)
	run.enemies.clear()
	run.spawn_clock = 10000.0
	run.cooldowns.lightning = 10000.0
	return run

func advance(run, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	var steps := int(round(seconds * 60.0))
	for i in range(steps):
		run.tick(1.0 / 60.0, movement)

func _test_exact_history() -> void:
	var history = Timeline.new()
	history.reset(Vector2.ZERO)
	history.record_position(1.0, Vector2(100, 20))
	history.record_position(2.0, Vector2(200, 40))
	expect(history.position_at(0.5).is_equal_approx(Vector2(50, 10)), "Position history must interpolate between real samples")
	var payload := {"kind": "lightning", "damage": 12.0, "count": 1, "nested": {"value": 4}}
	history.record_attack(0.5, payload)
	payload.damage = 99
	payload.nested.value = 99
	expect(history.consume_attacks(2.499).is_empty(), "Echo must not fire before two seconds")
	var ready: Array = history.consume_attacks(2.5)
	expect(ready.size() == 1, "Echo must fire exactly once at the two-second boundary")
	expect(ready[0].damage == 12.0 and ready[0].nested.value == 4, "Attack snapshots must be deep copies")
	expect(history.consume_attacks(9.0).is_empty(), "Consumed attacks must never repeat")

func _test_production_echo_and_snapshot() -> void:
	var moving = empty_run()
	advance(moving, 3.0, Vector2.RIGHT)
	expect(moving.echo_active, "Production echo must activate after two seconds")
	expect(absf(moving.player.x - 645.0) < 0.02, "Production movement must use simulation time")
	expect(absf(moving.echo.x - 215.0) < 0.02, "Production echo must use the position from exactly two seconds ago")
	expect(moving.timeline.positions.size() < 135, "Position history must be bounded")
	var run = empty_run()
	var original: Dictionary = run.spawn_enemy("hound", Vector2(180, 0))
	original.phase = "seek"
	original.hp = 100.0
	original.max_hp = 100.0
	var payload := {"kind": "lightning", "damage": 7.0, "count": 1, "range": 510.0, "width": 11.0, "cooldown": 0.72, "level": 1}
	run.cast(payload, run.player, false)
	expect(is_equal_approx(original.hp, 93.0), "Production lightning must hit the aimed enemy")
	payload.damage = 90.0
	payload.count = 4
	run.weapons.lightning.damage = 90.0
	run.weapons.lightning.count = 4
	run.enemies.clear()
	var replacement: Dictionary = run.spawn_enemy("hound", Vector2(-200, 0))
	replacement.phase = "seek"
	replacement.hp = 100.0
	replacement.max_hp = 100.0
	replacement.speed = 0.0
	advance(run, 1.9)
	expect(run.echo_shots == 0, "Production echo must wait the full delay")
	advance(run, 0.2)
	expect(run.echo_shots == 1 and run.player_shots == 1, "Echo must fire once without recursively recording itself")
	expect(is_equal_approx(replacement.hp, 93.0), "Echo must retarget a live enemy using the original seven damage")
	expect(run.last_echo_attack.count == 1 and run.last_echo_attack.damage == 7.0, "Echo must preserve pre-upgrade attack count and power")
	expect(run.timeline.attacks.is_empty(), "Echo casts must not create another pending echo")

func _test_freeze_and_choices() -> void:
	var run = empty_run()
	run.weapons.moon.level = 1
	run.cooldowns.moon = 1000.0
	var enemy: Dictionary = run.spawn_enemy("charger", Vector2(350, 0))
	enemy.phase = "warning"
	enemy.timer = 0.72
	run.projectiles.append({"kind": "bolt", "position": Vector2(300, 0), "velocity": Vector2.LEFT * 185.0, "age": 0.0, "duration": 4.0, "damage": 11.0})
	run.effects.append({"kind": "hurt", "position": Vector2.ZERO, "age": 0.0, "duration": 0.35})
	run.timeline.record_attack(run.elapsed, {"kind": "moon", "damage": 13.0, "count": 1, "radius": 118.0})
	run.pause("focus lost")
	var before := JSON.stringify(run.snapshot())
	var warning_before: float = enemy.timer
	var projectile_before: Vector2 = run.projectiles[0].position
	advance(run, 3.0, Vector2.RIGHT)
	expect(JSON.stringify(run.snapshot()) == before, "Paused tick must freeze simulation and attack history")
	expect(enemy.timer == warning_before and run.projectiles[0].position == projectile_before and run.effects[0].age == 0.0, "Warning, projectile and effect clocks must freeze together")
	expect(run.state == "paused", "Focus return must not resume the run automatically")
	run.resume()
	run.tick(1.0 / 60.0)
	expect(run.elapsed > 0.0 and float(enemy.timer) < warning_before, "Explicit resume must advance every gameplay clock again")
	var upgrades = empty_run()
	upgrades.experience = upgrades.experience_needed
	upgrades.check_level_up()
	expect(upgrades.state == "upgrade" and upgrades.level == 2 and upgrades.choices.size() == 3, "Level-up must offer three actual choices")
	expect(upgrades.choices[0].id == "moon_unlock", "The first level-up must offer the second weapon")
	var upgrade_before := JSON.stringify(upgrades.snapshot())
	advance(upgrades, 3.0)
	expect(JSON.stringify(upgrades.snapshot()) == upgrade_before, "Upgrade selection must stop all gameplay time")
	expect(not upgrades.choose_upgrade(4), "Invalid upgrade indices must not alter the run")
	expect(upgrades.choose_upgrade(0) and upgrades.weapons.moon.level == 1 and upgrades.state == "playing", "Choosing the first card must unlock production moon rings")
	advance(upgrades, 0.2)
	expect(upgrades.player_shots == 1 and upgrades.projectiles.size() == 1, "Unlocked moon weapon must actually cast")

func _test_invulnerability_and_outcomes() -> void:
	var run = empty_run()
	run.take_damage(10)
	run.take_damage(10)
	expect(run.health == 90.0, "Multiple contacts in one invulnerability window must only damage once")
	advance(run, 0.9)
	run.take_damage(10)
	expect(run.health == 80.0, "Damage must become possible after the grace interval")
	var lost = empty_run()
	lost.take_damage(100)
	expect(lost.state == "defeat" and lost.health == 0.0, "Zero HP must end the run in defeat")
	var loss_time: float = lost.elapsed
	advance(lost, 1.0)
	expect(lost.elapsed == loss_time, "Defeat must freeze the run")
	var won = empty_run()
	won.elapsed = 179.9
	advance(won, 0.2)
	expect(won.state == "victory" and is_equal_approx(won.elapsed, 180.0), "Surviving exactly 180 seconds must win without clock overshoot")
	var hit = empty_run()
	hit.weapons.moon.level = 1
	hit.cooldowns.moon = 0.01
	var target: Dictionary = hit.spawn_enemy("hound", Vector2(85, 0))
	target.phase = "seek"
	target.speed = 0.0
	advance(hit, 0.6)
	expect(hit.kills == 0 and hit.enemies.size() == 1 and is_equal_approx(target.hp, 15.0), "One production moon ring must damage a tougher enemy exactly once")

func _test_reset() -> void:
	var run = empty_run()
	advance(run, 3.0, Vector2.RIGHT)
	run.weapons.lightning.count = 4
	run.weapons.moon.level = 1
	run.experience = 20
	run.pickups.append({"position": Vector2.ONE, "value": 4})
	run.effects.append({"kind": "hurt", "position": Vector2.ONE, "age": 0.0, "duration": 4.0})
	run.projectiles.append({"kind": "bolt", "position": Vector2.ONE, "age": 0.0, "duration": 4.0})
	run.timeline.record_attack(3.0, {"kind": "moon"})
	run.reset(false, 731)
	expect(run.state == "title" and run.elapsed == 0.0 and run.player == Vector2.ZERO, "Return to title must reset time and position")
	expect(run.enemies.is_empty() and run.projectiles.is_empty() and run.pickups.is_empty() and run.effects.is_empty(), "Return to title must remove enemies, bullets, pickups and effects")
	expect(run.timeline.attacks.is_empty() and run.timeline.positions.size() == 1 and not run.echo_active, "Reset must clear echo attacks and prior position history")
	expect(run.level == 1 and run.experience == 0 and run.weapons.lightning.count == 1 and run.weapons.moon.level == 0, "Reset must remove every run upgrade")
	run.reset(true, 731)
	expect(run.state == "playing" and run.enemies.size() == 5 and run.health == 100.0, "Retry must start immediately with a fresh playable run")

func resonance_run():
	var run = empty_run()
	run.elapsed = 5.0
	run.player = Vector2(150, 0)
	run.echo = Vector2(-150, 0)
	run.echo_active = true
	return run

func still_target(run, hp: float = 200.0, at: Vector2 = Vector2(0, 150)) -> Dictionary:
	var target: Dictionary = run.spawn_enemy("hound", at)
	target.phase = "seek"
	target.hp = hp
	target.max_hp = hp
	target.speed = 0.0
	target.contact_ready_at = 10000.0
	return target

func _test_resonance() -> void:
	var run = resonance_run()
	var target := still_target(run, 36.0)
	run.damage_enemy(target, 12.0, Vector2.ZERO, false)
	expect(run.resonance_hits == 0 and run.experience == 0, "A first hit must only mark the enemy")
	expect(target.mark.source == "player" and is_equal_approx(target.mark.expires, 7.5), "The mark must expose its real source and simulation expiry")
	run.elapsed = 7.0
	run.damage_enemy(target, 12.0, Vector2.ZERO, true)
	expect(run.resonance_hits == 1 and is_equal_approx(target.hp, 0.0), "Separated player and echo hits within 2.5 seconds must add twelve bonus damage")
	expect(run.resonance_kills == 1 and run.experience == 1, "A lethal resonance must count and grant one immediate XP")
	expect(run.audio_events.has("resonance") and run.effects.back().kind == "resonance", "Resonance must publish actual audio and visual feedback events")
	expect(run.timeline.attacks.is_empty(), "Resonance damage must never record an additional attack")
	run._cleanup_dead()
	expect(run.kills == 1 and run.pickups.size() == 1 and run.pickups[0].value == 1, "Resonance XP must supplement, not duplicate or replace, the normal death pickup")
	var frozen = resonance_run()
	var survivor := still_target(frozen)
	frozen.damage_enemy(survivor, 1.0, Vector2.ZERO, false)
	frozen.pause()
	var mark_before: Dictionary = survivor.mark.duplicate(true)
	advance(frozen, 4.0)
	expect(survivor.mark == mark_before and frozen.elapsed == 5.0, "Pausing must freeze resonance mark expiry")
	frozen.resume()
	frozen.damage_enemy(survivor, 1.0, Vector2.ZERO, true)
	var effect_before: Dictionary = frozen.effects.back().duplicate(true)
	frozen.pause()
	advance(frozen, 4.0)
	expect(frozen.effects.back() == effect_before, "Pausing must freeze resonance feedback animation")
	var snapshot: Dictionary = frozen.snapshot()
	expect(snapshot.resonance_hits == 1 and snapshot.resonance_kills == 0 and snapshot.specialization == "未選択" and snapshot.phase.index == 0, "The read-only snapshot must expose actual resonance, phase and build state")
	frozen.reset(false, 731)
	expect(frozen.resonance_hits == 0 and frozen.resonance_kills == 0 and frozen.specialization == "未選択" and frozen.resonance_bonus == 12.0 and frozen.wave_number == 0, "Retry/title reset must clear resonance, specialization and wave state")

func _test_resonance_restrictions() -> void:
	var same = resonance_run()
	var a := still_target(same)
	same.damage_enemy(a, 1.0, Vector2.ZERO, false)
	same.damage_enemy(a, 1.0, Vector2.ZERO, false)
	expect(same.resonance_hits == 0, "Repeated hits from one source must never resonate")
	var overlap = resonance_run()
	overlap.echo = overlap.player
	var b := still_target(overlap)
	overlap.damage_enemy(b, 1.0, Vector2.ZERO, false)
	overlap.damage_enemy(b, 1.0, Vector2.ZERO, true)
	expect(overlap.resonance_hits == 0, "A stationary overlapping echo must not enable resonance")
	var close_origins = resonance_run()
	var c := still_target(close_origins)
	close_origins.damage_enemy(c, 1.0, Vector2.ZERO, false, Vector2.ZERO)
	close_origins.damage_enemy(c, 1.0, Vector2.ZERO, true, Vector2(30, 0))
	expect(close_origins.resonance_hits == 1, "A real delayed replay may share the historical origin when the two current actors are clearly separated")
	var stale = resonance_run()
	var d := still_target(stale)
	stale.damage_enemy(d, 1.0, Vector2.ZERO, false)
	stale.elapsed += 2.51
	stale.damage_enemy(d, 1.0, Vector2.ZERO, true)
	expect(stale.resonance_hits == 0, "Expired marks must not trigger resonance")
	var cooldown = resonance_run()
	var e := still_target(cooldown)
	cooldown.damage_enemy(e, 1.0, Vector2.ZERO, false)
	cooldown.elapsed = 5.2
	cooldown.damage_enemy(e, 1.0, Vector2.ZERO, true)
	cooldown.elapsed = 5.3
	cooldown.damage_enemy(e, 1.0, Vector2.ZERO, false)
	expect(cooldown.resonance_hits == 1 and cooldown.experience == 1, "A second opposite hit inside the cooldown must not trigger again")
	cooldown.elapsed = 7.8
	cooldown.damage_enemy(e, 1.0, Vector2.ZERO, false)
	cooldown.elapsed = 7.9
	cooldown.damage_enemy(e, 1.0, Vector2.ZERO, true)
	expect(cooldown.resonance_hits == 2 and cooldown.experience == 1, "A surviving enemy can resonate again after cooldown but cannot supply infinite XP")
	var snapshot_bonus = resonance_run()
	var f := still_target(snapshot_bonus)
	snapshot_bonus.damage_enemy(f, 1.0, Vector2.ZERO, false)
	snapshot_bonus.resonance_bonus = 20.0
	snapshot_bonus.damage_enemy(f, 1.0, Vector2.ZERO, true, snapshot_bonus.echo, 10.0)
	expect(is_equal_approx(f.hp, 188.0), "A delayed spell's recorded resonance bonus must survive specialization changes")

func _test_phase_spawning_and_arrival() -> void:
	var run = empty_run()
	for index in range(6):
		run.elapsed = float(index) * 30.0
		var info: Dictionary = run.phase_info()
		expect(info.index == index and info.assault and is_equal_approx(info.remaining, 22.0) and not str(info.name).is_empty(), "Every phase must begin with its own named 22-second assault")
		run.elapsed += 22.0
		info = run.phase_info()
		expect(info.index == index and not info.assault and is_equal_approx(info.remaining, 8.0), "Every phase must end in an eight-second collection interval")
	run.elapsed = 180.0
	expect(run.phase_info().index == 5 and not run.phase_info().assault and run.phase_info().remaining == 0.0, "At 180 seconds phase information must clamp to the final phase")
	var assault = empty_run()
	assault.spawn_clock = 0.0
	assault._update_spawning(0.01)
	expect(assault.enemies.size() == 2 and assault.wave_number == 1 and assault.spawn_clock == 1.2, "The first attack wave must be a visible two-enemy formation")
	var positions_valid := true
	for enemy in assault.enemies:
		var distance: float = enemy.position.distance_to(assault.player)
		positions_valid = positions_valid and distance >= 480.0 and distance <= 620.0 and enemy.phase == "arrival" and enemy.position.x > 400.0
	expect(positions_valid, "The forward row must arrive at a safe, visible distance with arrival warnings")
	var recovery = empty_run()
	recovery.elapsed = 23.0
	recovery.spawn_clock = 0.0
	recovery._update_spawning(0.01)
	expect(recovery.enemies.size() == 1 and recovery.spawn_clock >= 3.0, "Collection time must materially reduce new enemy pressure")
	recovery.pause()
	var phase_before := JSON.stringify(recovery.phase_info())
	advance(recovery, 9.0)
	expect(JSON.stringify(recovery.phase_info()) == phase_before, "A paused phase must not advance toward the next assault")
	var arrival = empty_run()
	var target: Dictionary = arrival.spawn_enemy("hound", Vector2.ZERO)
	target.speed = 0.0
	advance(arrival, 0.95)
	expect(arrival.health == 100.0, "Finishing an arrival on the player must not cause an unannounced contact hit")
	advance(arrival, 0.2)
	expect(arrival.health == 92.0, "An arrived enemy must become dangerous after its visible contact grace")

func specialization_run():
	var run = empty_run()
	run.level = 3
	run.experience = run.experience_needed
	run.check_level_up()
	return run

func _test_specializations_and_caps() -> void:
	var delayed = empty_run()
	var original_target := still_target(delayed, 200.0, Vector2(180, 0))
	delayed.cooldowns.lightning = 0.0
	delayed._update_weapons(1.0 / 60.0)
	expect(delayed.timeline.attacks.size() == 1 and delayed.timeline.attacks[0].payload.resonance_bonus == 12.0, "Production firing must snapshot the resonance bonus with the spell")
	delayed.level = 3
	delayed.experience = delayed.experience_needed
	delayed.check_level_up()
	delayed.choose_upgrade(2)
	delayed.cooldowns.lightning = 1000.0
	advance(delayed, 2.1, Vector2.RIGHT)
	expect(delayed.last_echo_attack.damage == 12.0 and delayed.last_echo_attack.resonance_bonus == 12.0 and delayed.resonance_bonus == 24.0, "Specialization must not rewrite a real queued attack's normal or resonance power")
	expect(is_equal_approx(original_target.hp, 164.0), "The actual delayed cast must apply pre-specialization normal and resonance damage")
	var lightning = specialization_run()
	expect(lightning.level == 4 and lightning.choices.size() == 3 and lightning.choices[0].get("specialization", false), "Level four must offer the three exclusive specializations")
	expect(lightning.choose_upgrade(0) and lightning.specialization == "雷の魔女", "The first specialization must select the lightning build")
	expect(is_equal_approx(lightning.weapons.lightning.damage, 16.8) and is_equal_approx(lightning.weapons.lightning.range, 460.0) and is_equal_approx(lightning.weapons.moon.damage, 9.1), "Lightning specialization must increase power/reach and really weaken moon damage")
	Spellbook.apply("power", lightning.weapons)
	expect(is_equal_approx(lightning.weapons.lightning.damage, 21.0) and is_equal_approx(lightning.weapons.moon.damage, 11.2), "Future power upgrades must preserve the specialization's relative strength and weakness")
	lightning.experience = lightning.experience_needed
	lightning.check_level_up()
	var no_second_specialization := true
	for choice in lightning.choices:
		no_second_specialization = no_second_specialization and not bool(choice.get("specialization", false))
	expect(no_second_specialization, "Later levels must return to normal upgrades instead of stacking specializations")
	var moon = specialization_run()
	expect(moon.choose_upgrade(1) and moon.specialization == "月の魔女" and moon.weapons.moon.level == 1, "Moon specialization must also work when moon was not previously unlocked")
	expect(is_equal_approx(moon.weapons.moon.radius, 165.2) and moon.weapons.moon.cooldown < 2.15 and is_equal_approx(moon.weapons.lightning.range, 300.0), "Moon specialization must trade actual lightning range for a larger, faster moon")
	var echo_build = specialization_run()
	expect(echo_build.choose_upgrade(2) and echo_build.specialization == "残響の魔女", "The third specialization must select the resonance build")
	expect(echo_build.resonance_bonus == 24.0 and is_equal_approx(echo_build.weapons.lightning.damage, 10.2) and is_equal_approx(echo_build.weapons.moon.damage, 11.05), "Resonance specialization must double its bonus and really weaken normal spells")
	echo_build.state = "upgrade"
	echo_build.choices = Spellbook.offers(echo_build.weapons, 4, echo_build.speed, echo_build.maximum_health, echo_build.rng)
	expect(not echo_build.choose_upgrade(0) and echo_build.specialization == "残響の魔女", "The production chooser must reject a second specialization even if a stale card is supplied")
	var capped = Spellbook.initial_weapons()
	for i in range(20):
		for id in ["lightning_fork", "moon_double", "lightning_haste", "moon_haste"]:
			Spellbook.apply(id, capped)
	expect(capped.lightning.count == 3 and capped.moon.count == 2 and is_equal_approx(capped.lightning.cooldown, 0.44) and is_equal_approx(capped.moon.cooldown, 1.1), "Repeated upgrades must respect projectile and casting-speed caps")
	capped.moon.level = 1
	var valid_offers := true
	for i in range(20):
		for choice in Spellbook.offers(capped, 8, 269.0, 100.0, lightning.rng, "雷の魔女"):
			valid_offers = valid_offers and choice.id not in ["lightning_fork", "moon_double", "lightning_haste", "moon_haste", "stride"]
	expect(valid_offers, "Capped upgrades must stop appearing as choices")

func _test_lightning_shared_hits() -> void:
	var run = empty_run()
	var a := still_target(run, 200.0, Vector2(120, 0))
	var b := still_target(run, 200.0, Vector2(240, 0))
	var payload: Dictionary = run.weapons.lightning.duplicate(true)
	payload.kind = "lightning"
	payload.count = 2
	run.cast(payload, Vector2.ZERO, false)
	expect(is_equal_approx(a.hp, 188.0) and is_equal_approx(b.hp, 188.0), "Branching rays must share hit IDs so one cast cannot multiply damage on the same enemy")

func _test_experience_pacing() -> void:
	var early = empty_run()
	var early_costs: Array[int] = []
	for i in range(4):
		early_costs.append(early.experience_needed)
		early.experience = early.experience_needed
		early.check_level_up()
		early.choose_upgrade(0)
	expect(early_costs == [5, 9, 13, 17] and early.level == 5 and early.experience_needed == 21, "Late XP pacing must preserve the first four level-up timings")
	var late = empty_run()
	late.experience = 360
	late.check_level_up()
	var selections := 0
	while late.state == "upgrade" and selections < 20:
		late.choose_upgrade(0)
		selections += 1
	expect(selections >= 8 and selections <= 10 and late.state == "playing", "A representative 360-XP run must require only eight to ten upgrade decisions")
	expect(late.experience_needed > 100 and late.level == 11, "Late-game XP requirements must grow enough to prevent rapid consecutive interruptions")
