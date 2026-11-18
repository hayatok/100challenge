extends SceneTree

const Race = preload("res://race/RaceSimulation.gd")
const DT := 1.0 / 60.0
const WINNING_LANE := -3.9

var failures := 0
var checks := 0


func _initialize() -> void:
	for test: Callable in [
		_test_bridge_weights, _test_rival_route, _test_route_tradeoff,
		_test_safe_respawn, _test_crate_contact, _test_finish_order,
		_test_full_race_and_reset,
	]:
		_check(test.call() == true, "Test case completes: %s" % test.get_method())
	print("Race simulation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _isolated_race() -> RefCounted:
	var race := Race.new()
	for runner: Dictionary in race.runners:
		runner.state = "finish"
		runner.finish_time = 0.0
	return race


func _place(race: RefCounted, index: int, x: float, progress: float) -> Dictionary:
	var runner: Dictionary = race.runners[index]
	runner.x = x
	runner.p = progress
	runner.state = "run"
	runner.speed = Race.MAX_SPEED
	runner.finish_time = -1.0
	return runner


func _test_bridge_weights() -> bool:
	var race := _isolated_race()
	_place(race, 0, -2.4, 81.0)
	race.step(DT, -2.4, false)
	var solo_angle: float = race.bridge_angle
	_check(solo_angle < 0.0, "A runner beyond the pivot lowers the exit")

	race = _isolated_race()
	_place(race, 1, -2.4, 81.0)
	race.step(DT, 0.0, false)
	_check(is_equal_approx(race.bridge_angle, solo_angle), "Player and rival have equal weight")

	race = _isolated_race()
	_place(race, 0, -2.4, 81.0)
	_place(race, 1, -3.2, 81.0)
	race.step(DT, -2.4, false)
	_check(race.bridge_angle < solo_angle, "An additional runner lowers the shared exit farther")
	_check(race.runners[0].y < 0.0 and race.runners[1].y < 0.0, "Both feet follow the shared bridge")

	race = _isolated_race()
	_place(race, 0, -2.4, 81.0)
	_place(race, 1, -3.2, 65.0)
	race.step(DT, -2.4, false)
	_check(is_zero_approx(race.bridge_angle), "Equal loads on opposite sides balance")

	race = _isolated_race()
	var runner := _place(race, 0, -2.4, 65.0)
	runner.grounded = false
	runner.y = 1.0
	race.step(DT, -2.4, false)
	_check(is_zero_approx(race.bridge_angle), "Airborne runners do not weigh down the bridge")
	return true


func _test_rival_route() -> bool:
	var race := _isolated_race()
	var rikka := _place(race, 2, -1.2, 48.0)
	race.step(DT, 0.0, false)
	_check(rikka.route == 1, "The inside-line rival chooses a clear shortcut")

	race = _isolated_race()
	rikka = _place(race, 2, -1.2, 48.0)
	_place(race, 0, -3.7, 81.0)
	_place(race, 1, -2.7, 82.0)
	_place(race, 3, -1.7, 81.0)
	race.step(DT, -3.7, false)
	_check(rikka.route == 2, "The same rival uses the flat route when the bridge is occupied")
	return true


func _test_route_tradeoff() -> bool:
	var inner_time := _drive_split(false, true)
	var outer_time := _drive_split(true, false)
	_check(inner_time > 0.0 and outer_time > inner_time, "A clean shortcut beats the curved route")
	_check(_drive_split(false, false) < 0.0, "Skipping the jump at the lowered exit loses the shortcut")
	return true


func _drive_split(outer: bool, jump_at_exit: bool) -> float:
	var race := _isolated_race()
	var player := _place(race, 0, 3.2 if outer else WINNING_LANE, 51.0)
	player.checkpoint = 2
	for tick in 60 * 14:
		var target := WINNING_LANE
		if outer:
			var lookahead := clampf(player.p + 1.6, Race.SPLIT_START, Race.SPLIT_END)
			target = 3.2 + race._outer_shift(lookahead)
		var jump: bool = jump_at_exit and player.p >= 85.0 and player.p < 85.11
		race.step(DT, target, jump)
		if player.state == "fall":
			return -1.0
		if player.p >= Race.SPLIT_END:
			return race.time
	return -1.0


func _test_safe_respawn() -> bool:
	var race := _isolated_race()
	var player := _place(race, 0, -0.45, 53.0)
	player.checkpoint = 2
	var fell := false
	var reached_water := false
	for tick in 120:
		race.step(DT, 0.4, false)
		fell = fell or player.state == "fall"
		reached_water = reached_water or player.y <= Race.WATER_HEIGHT
		if player.respawns == 1:
			break
	_check(fell and reached_water and player.respawns == 1, "The split gap causes a fall and recovery")
	_check(player.p == 46.0 and player.y == 0.0 and player.grounded, "Recovery starts at the last safe marker")
	race.step(0.5, player.x, false)
	_check(player.p > 46.0 and player.state == "run", "Ordinary control resumes on the pier")
	return true


func _test_crate_contact() -> bool:
	var race := _isolated_race()
	var player := _place(race, 0, -1.8, 13.0)
	race.step(0.2, -1.8, false)
	_check(player.state == "stumble" and player.p < 13.25, "A crate blocks the running line")
	race.step(0.4, -1.8, false)
	race.step(DT, -1.8, true)
	race.step(1.6, -1.8, false)
	_check(player.p > 14.75 and player.respawns == 0, "Jump can clear a crate from a blocked position")
	return true


func _test_finish_order() -> bool:
	var race := Race.new()
	var player := _place(race, 0, -4.0, 149.99)
	var suzu := _place(race, 1, -3.2, 149.99)
	var rikka := _place(race, 2, -1.0, 149.965)
	player.grounded = false
	player.y = 0.8
	player.vy = 2.0
	race.step(DT, -4.0, false)
	_check(player.finish_time == suzu.finish_time, "An identical line crossing ties")
	_check(player.finish_time < rikka.finish_time, "A later crossing in one tick stays later")
	_check(race.rank_of(0) == 1 and race.rank_of(1) == 1 and race.rank_of(2) == 3, "Ranks reflect finish ties")
	var finish_time: float = player.finish_time
	race.step(1.0, -4.0, false)
	_check(player.finish_time == finish_time and player.grounded and player.y == 0.0, "An airborne finisher lands without altering their time")
	return true


func _test_full_race_and_reset() -> bool:
	var race := Race.new()
	var starting_field: Array = race.runners.duplicate(true)
	var starting_bars: PackedFloat32Array = race.bar_angles.duplicate()

	var player: Dictionary = race.runners[0]
	var hit_bar := false
	for tick in 60 * 11:
		race.step(DT, WINNING_LANE, false)
		hit_bar = hit_bar or (player.state == "stumble" and absf(player.p - Race.BARS[0]) < 5.0)
	_check(hit_bar, "Running through the first rotating bar causes a stumble")
	race.reset()

	_drive_full_race(race)
	_check(race.rank_of(0) == 1 and race.runners[0].finish_time < 42.0, "Steering and timely jumps can win the race")
	_check(race.runners[0].respawns == 0, "The winning path stays above water")
	for runner: Dictionary in race.runners:
		_check(runner.finish_time >= 0.0, "Every runner reaches the finish")
	var results: Array = race.runners.duplicate(true)
	var final_clock: float = race.time
	var final_angles: PackedFloat32Array = race.bar_angles.duplicate()

	race.step(0.0, 0.0, true)
	_check(race.runners == results and race.time == final_clock and race.bar_angles == final_angles, "A paused race does not advance")
	race.reset()
	_check(race.time == 0.0 and race.bridge_angle == 0.0, "Retry clears the clock and bridge")
	_check(race.runners == starting_field and race.bar_angles == starting_bars, "Retry restores all runners and bar phases")
	_drive_full_race(race)
	_check(race.runners == results and race.time == final_clock and race.bar_angles == final_angles, "Identical inputs reproduce the entire result")
	return true


func _drive_full_race(race: RefCounted) -> void:
	var player: Dictionary = race.runners[0]
	var jumped_bar := false
	var jumped_bridge := false
	for tick in 60 * 43:
		var jump := false
		if not jumped_bar and player.p >= 34.13:
			jumped_bar = true
			jump = true
		if not jumped_bridge and player.p >= 85.0:
			jumped_bridge = true
			jump = true
		race.step(DT, WINNING_LANE, jump)
