extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var failures: Array[String] = []
var count := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	count += 1
	if not value: failures.append(label)

func _run() -> void:
	var rules = Rules.new()
	rules.advance(5.0)
	_check(rules.elapsed == 0.0, "Timer stays idle before first input")
	rules.begin()
	rules.advance(0.5)
	_check(is_equal_approx(rules.elapsed, 0.5), "Active timer advances")
	var events := [{"id": "c", "base": 50000, "progress": 3.0}, {"id": "a", "base": 10000, "progress": 1.0}, {"id": "b", "base": 10000, "progress": 2.0}]
	var rewards: Array = rules.register_breaks(events)
	_check(rewards.size() == 3 and str(rewards[0]["id"]) == "a", "Simultaneous events use course order")
	_check(rules.damage == 180000 and rules.combo == 3, "Current event receives its combo multiplier")
	_check(rules.rush_timer > 0.0, "Third combo starts rush")
	_check(rules.register_breaks(events).is_empty() and rules.damage == 180000, "Broken props never score twice")
	rules.register_breaks([{"id": "d", "base": 10000, "progress": 4.0}])
	_check(rules.combo == 4 and rules.damage == 210000, "Multiplier caps at three")
	rules.advance(2.01)
	_check(rules.combo == 0, "Combo expires after two seconds")
	rules.register_breaks([{"id": "e", "base": 10000, "progress": 2.5}])
	_check(rules.combo == 1, "Backward destruction starts a new chain")
	var end: Dictionary = rules.finish()
	var saved_damage: int = rules.damage
	rules.register_breaks([{"id": "f", "base": 100000, "progress": 5.0}])
	rules.advance(10.0)
	_check(rules.damage == saved_damage and float(end["elapsed"]) == rules.elapsed, "Goal freezes score and time")
	_check(str(Rules.ranking(24.86)["rank"]) == "SSS", "Mock result matches SSS threshold")
	_check(str(Rules.ranking(30.01)["rank"]) == "SS", "Time boundary is exact")
	rules.reset()
	_check(rules.seen.is_empty() and rules.damage == 0 and not rules.started, "Retry resets all rules")
	var asset_checks = load("res://tests/asset_checks.gd").new()
	var asset_failures: Array[String] = asset_checks.run()
	failures.append_array(asset_failures)
	var checks = load("res://tests/player_checks.gd").new()
	var player_failures: Array[String] = await checks.run(self)
	failures.append_array(player_failures)
	var office_checks = load("res://tests/office_checks.gd").new()
	var office_failures: Array[String] = await office_checks.run(self)
	failures.append_array(office_failures)
	var effects_checks = load("res://tests/effects_checks.gd").new()
	var effects_failures: Array[String] = await effects_checks.run(self)
	failures.append_array(effects_failures)
	var integration_checks = load("res://tests/integration_checks.gd").new()
	var integration_failures: Array[String] = await integration_checks.run(self)
	failures.append_array(integration_failures)
	if failures.is_empty():
		print("PASS: rules (", count, "), model colors/sharing, player real-physics, office route/destruction, bounded FX lifecycle and rush/pause/success/retry integration checks")
		call_deferred("quit", 0)
	else:
		for error: String in failures: print("FAIL: ", error)
		call_deferred("quit", 1)
