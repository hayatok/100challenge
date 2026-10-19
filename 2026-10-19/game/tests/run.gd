extends SceneTree

const Run = preload("res://scripts/run_model.gd")
const Timeline = preload("res://scripts/echo_timeline.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_exact_history()
	_test_production_echo_and_snapshot()
	_test_freeze_and_choices()
	_test_invulnerability_and_outcomes()
	_test_reset()
	if failures.is_empty():
		print("PASS: %d production checks (echo, immutable attacks, retarget, freeze, upgrades, reset, outcomes)" % checks)
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
	expect(hit.kills == 1 and hit.enemies.is_empty(), "Production moon rings must damage and defeat nearby enemies")

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
