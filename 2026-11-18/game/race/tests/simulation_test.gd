extends SceneTree

const Race = preload("res://race/RaceSimulation.gd")
const Yard = preload("res://race/YardLayout.gd")
const DT := 1.0 / 60.0
const WINNING_LANE := -3.9

var failures := 0
var checks := 0


func _initialize() -> void:
	for test: Callable in [
		_test_bridge_weights, _test_rival_route, _test_route_tradeoff,
		_test_safe_respawn, _test_crate_contact, _test_finish_order,
		_test_full_race_and_reset, _test_boost, _test_dive, _test_transport,
		_test_yard_split, _test_yard_field_and_reset,
	]:
		_check(test.call() == true, "Test case completes: %s" % test.get_method())
	print("Race simulation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _isolated_race(course_id := "wharf") -> RefCounted:
	var race := Race.new()
	race.reset(course_id)
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
	var jumped := false
	for tick in 60 * 14:
		var target := WINNING_LANE
		if outer:
			var lookahead := clampf(player.p + 1.6, Race.SPLIT_START, Race.SPLIT_END)
			target = 3.2 + race._outer_shift(lookahead)
		var jump: bool = jump_at_exit and not jumped and player.p >= 85.0
		jumped = jumped or jump
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

	_drive_full_race(race, false)
	_check(absf(race.runners[0].finish_time - 38.51) < 0.08, "Legacy steering and jumps alone retain the wharf crossing time")
	race.reset()
	_drive_full_race(race)
	_check(race.rank_of(0) == 1 and race.runners[0].finish_time < 42.0, "Steering, boosts and timely jumps can win the race")
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


func _drive_full_race(race: RefCounted, use_boost := true) -> void:
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
		var boost: bool = use_boost and (tick == 30 or tick == 60 * 29)
		race.step(DT, WINNING_LANE, jump, boost)


func _test_boost() -> bool:
	var race := _isolated_race("yard")
	var runner := _place(race, 0, 3.0, 4.0)
	race.step(DT, 3.0, false, true)
	_check(runner.state == "sprint" and runner.boosts_left == 1, "A ground boost spends one pennant")
	var remaining: float = runner.boost_left
	race.step(0, 3.0, false, true)
	_check(remaining == runner.boost_left, "Pause freezes the boost")
	race.step(0.5, 3.0, false, true)
	_check(runner.boosts_left == 1 and is_equal_approx(runner.speed, Race.MAX_SPEED * 1.3), "An active boost cannot be stacked")
	race.step(0.4, -3.0, false)
	_check(is_equal_approx(absf(runner.vx), Race.LATERAL_SPEED * 0.7), "Sprinting sacrifices lateral speed")
	race.step(0.4, runner.x, false)
	_check(runner.state == "run" and runner.boost_left == 0.0, "A sprint expires after 1.2 seconds")
	race.step(DT, runner.x, true)
	race.step(DT, runner.x, false, true)
	_check(runner.boosts_left == 1, "Airborne boost input is ignored")
	race.step(1.0, runner.x, false)
	runner.x = -5.0
	race.step(DT, -5.0, false, true)
	_check(runner.state == "fall" and runner.boost_left == 0.0 and runner.boosts_left == 0, "Water cancels a spent boost")
	race.step(1.2, -3.0, false)
	race.step(DT, -3.0, false, true)
	_check(runner.respawns == 1 and runner.boost_left == 0.0 and runner.boosts_left == 0, "Recovery does not refill the two uses")
	return true


func _flat_jump(dive_tick: int, with_boost := false) -> Vector2:
	var race := _isolated_race("yard")
	var runner := _place(race, 0, 0.0, 3.0)
	var height := 0.0
	var max_speed := 0.0
	for tick in 90:
		race.step(DT, 0.0, tick == 0 or tick == dive_tick, tick == 0 and with_boost)
		height = maxf(height, runner.y)
		max_speed = maxf(max_speed, runner.speed)
		if runner.grounded:
			_check(max_speed <= Race.MAX_SPEED * Race.DIVE_FACTOR + 0.000001, "A boosted dive respects its speed cap")
			var expected := "land" if dive_tick < 0 else "slide"
			_check(runner.state == expected, "Landing pose follows the airborne action")
			return Vector2(runner.p - 3.0, height)
	return Vector2.ZERO


func _flat_distance(style: String) -> float:
	var race := _isolated_race("yard")
	var runner := _place(race, 0, 3.9, 1.0)
	for tick in 6 * 60:
		var action: bool = style != "run" and runner.grounded
		if style == "apex" and runner.dive_ready and runner.vy <= 0.35:
			action = true
		if style == "spam" and runner.dive_ready:
			action = true
		race.step(DT, 3.9, action)
	return runner.p - 1.0


func _land_shortcut_from_early_takeoff(dive: bool) -> bool:
	var race := _isolated_race("yard")
	var runner := _place(race, 0, Yard.roof_x(1, 0.75), 106.35)
	for tick in 90:
		race.step(DT, runner.x, tick == 0 or (dive and tick == 25))
		if runner.state == "fall":
			return false
		if runner.grounded:
			return is_equal_approx(runner.y, Yard.ROOFS[1].height)
	return false


func _test_dive() -> bool:
	var normal := _flat_jump(-1)
	var apex := _flat_jump(25)
	var early := _flat_jump(2)
	_flat_jump(25, true)
	var gain := apex.x - normal.x
	_check(gain > 0.5 and gain < 0.8, "Diving near the apex reaches another 0.5–0.8 m")
	_check(not _land_shortcut_from_early_takeoff(false) and _land_shortcut_from_early_takeoff(true), "An apex dive converts an early takeoff into a reachable shortcut roof")
	_check(early.y < normal.y * 0.4 and early.x < normal.x, "An early dive cuts both height and reach")
	var running := _flat_distance("run")
	var jumping := _flat_distance("jump")
	var timed := _flat_distance("apex")
	var spam := _flat_distance("spam")
	_check(is_equal_approx(running, jumping) and timed < running and spam < running, "Repeated flat-ground jumps and dives cannot beat running")
	var race := _isolated_race("yard")
	var runner := _place(race, 0, 4.0, 3.0)
	race.step(DT, 4.0, true)
	race.step(DT, 4.0, true)
	var landing_time := -1.0
	for tick in 90:
		race.step(DT, 4.0, true, true)
		if runner.state == "slide" and landing_time < 0.0:
			landing_time = race.time
		if landing_time >= 0.0 and runner.state != "slide":
			break
	_check(race.time - landing_time >= Race.SLIDE_SECONDS - 0.00001, "Repeated taps cannot skip grounded slide recovery")
	print("Jump %.3f m, apex dive %.3f m, early dive %.3f m. Six seconds running/jumping/apex/spam %.2f / %.2f / %.2f / %.2f m." % [normal.x, apex.x, early.x, running, jumping, timed, spam])
	return true


func _test_transport() -> bool:
	var race := _isolated_race("yard")
	var runner := _place(race, 0, 0.1, 22.0)
	var target: float = runner.x
	for tick in 30:
		race.step(DT, target, false)
		target += float(runner.transport_x)
	_check(is_equal_approx(runner.x, 0.1 + Yard.BELTS[0].speed * 0.5), "A passive rider travels with the belt")
	race.step(DT, target, true)
	_check(runner.transport_x == 0.0, "Jumping releases the belt on the launch tick")
	race = _isolated_race("yard")
	var x_from := Yard.roof_x(0, 0.0)
	runner = _place(race, 0, x_from, 58.0)
	runner.y = Yard.ROOFS[0].height
	race.step(0.45, x_from, false)
	_check(absf(runner.x - Yard.roof_x(0, race.time)) < 0.001 and runner.grounded, "A rider stays at the same roof-local position across substeps")
	_check(absf(runner.x - x_from - runner.transport_x) < 0.001, "Reported transport is cumulative for the physics step")
	var from_x: float = runner.x
	race.step(0.25, from_x + 2.0, false)
	_check(runner.x > from_x + runner.transport_x + 0.4, "Riders can actively walk on a moving roof")
	race.step(DT, runner.x, true)
	_check(runner.transport_x == 0.0 and not runner.grounded, "Jumping releases a moving roof immediately")
	race = _isolated_race("yard")
	runner = _place(race, 0, Yard.roof_x(0, 0.0), 55.95)
	target = runner.x
	race.step(DT, target, false)
	_check(runner.p < 56.0 and runner.state == "stumble", "A low approach meets the container front above the catch pier")
	for tick in 60 * 5:
		race.step(DT, target, false)
		target += float(runner.transport_x)
	_check(runner.p > 64.0 and runner.grounded and runner.y == 0.0 and runner.respawns == 0, "Missing the training roof allows recovery on the catch pier")
	return true


func _yard_split(route: String, start_time: float) -> float:
	var race := _isolated_race("yard")
	race.time = start_time
	var x := Yard.OUTER_CENTER if route == "outer" else -3.35
	var runner := _place(race, 0, x, Yard.SPLIT_START)
	runner.checkpoint = 2
	var target := x
	var recovered := false
	var landed_on_roof := false
	for tick in 2400:
		var action := false
		if route == "inner":
			target = race._yard_inner_target(runner, 2)
			if runner.grounded:
				action = (runner.p >= 107.25 and runner.p < Yard.GAP_START
					or runner.p >= 116.75 and runner.p < 117.6)
		race.step(DT, target, action)
		if route == "outer" or recovered:
			target += float(runner.transport_x)
		if not recovered and runner.respawns > 0:
			recovered = true
			target = runner.x
			_check(runner.p == Yard.CHECKPOINTS[2], "A missed shortcut returns to the approach")
		if runner.grounded and runner.p > Yard.GAP_START and runner.p < Yard.GAP_END and runner.y > 0.0:
			landed_on_roof = true
		if runner.p >= Yard.SPLIT_END:
			if route == "inner":
				_check(landed_on_roof and not recovered, "The shortcut crosses on the physical roof")
			elif route == "miss":
				_check(recovered, "Skipping the water jump requires recovery")
			else:
				_check(not recovered, "The continuous pier needs no jumps at any roof phase")
			return race.time - start_time
	return -1.0


func _test_yard_split() -> bool:
	var roof: Dictionary = Yard.ROOFS[1]
	# Set each phase at the same point in the approach for both lanes.
	for angle: float in [-PI * 0.5, 0.0, PI * 0.5]:
		var start_time := fposmod((angle - roof.phase) / roof.omega, TAU / roof.omega)
		var outer := _yard_split("outer", start_time)
		var inner := _yard_split("inner", start_time)
		var missed := _yard_split("miss", start_time)
		_check(inner > 0.0 and outer - inner >= 0.5 and outer - inner <= 1.0, "The clean crossing saves 0.5–1.0 s of curved pier")
		_check(missed > outer, "A failed crossing costs the lead to the safe route")
		print("Roof phase %+.2f: inner %.2f s, outer %.2f s, miss + recovery %.2f s." % [angle, inner, outer, missed])
	for angle: float in [-PI * 0.5, PI * 0.5]:
		var race := _isolated_race("yard")
		var rikka := _place(race, 2, -1.0, 78.0)
		var nene := _place(race, 4, 3.55, 78.0)
		race.time = fposmod((angle - roof.phase) / roof.omega - (Yard.GAP_START + 2.3 - 78.0) / Race.MAX_SPEED, TAU / roof.omega)
		race.step(DT, 0.0, false)
		_check(rikka.route == (1 if angle < 0 else 2), "Rikka estimates the crossing phase before committing")
		if angle > 0:
			_check(nene.route == 2, "Nene takes the continuous pier when her launch lane is distant")
	return true


func _yard_full_race(race: RefCounted) -> void:
	var player: Dictionary = race.runners[0]
	var target := Yard.OUTER_CENTER + 0.4
	for tick in 60 * 51:
		race.step(DT, target, false)
		target += float(player.transport_x)


func _test_yard_field_and_reset() -> bool:
	var race := Race.new()
	race.reset("yard")
	var initial: Array = race.runners.duplicate(true)
	var player: Dictionary = race.runners[0]
	var target := Yard.OUTER_CENTER + 0.4
	var sprint := false
	var dive := false
	var slide := false
	var inner := false
	var outer := false
	var rikka_boost := false
	var nene_saved := false
	for tick in 60 * 51:
		race.step(DT, target, false)
		target += float(player.transport_x)
		for i in range(1, race.runners.size()):
			var rival: Dictionary = race.runners[i]
			sprint = sprint or rival.state == "sprint"
			dive = dive or rival.state == "dive"
			slide = slide or rival.state == "slide"
			inner = inner or rival.route == 1
			outer = outer or rival.route == 2
		var rikka: Dictionary = race.runners[2]
		var nene: Dictionary = race.runners[4]
		if rikka.route == 1 and rikka.p > Yard.GAP_START and rikka.p < Yard.GAP_START + 1.0:
			rikka_boost = rikka_boost or rikka.boost_left > 0.0
		if nene.route == 2 and nene.p > Yard.SPLIT_END - 1.0:
			nene_saved = nene_saved or nene.boosts_left == 2
	_check(rikka_boost and nene_saved, "Rikka spends a boost on the crane approach while Nene holds hers through the safe route")
	_check(player.finish_time >= 40.0 and player.finish_time <= 50.0 and player.respawns == 0, "A first-time player can finish the 170 m outer route without either skill")
	_check(sprint and dive and slide and inner and outer, "Rivals use the shared action states and both routes")
	for i in range(1, race.runners.size()):
		_check(race.runners[i].finish_time >= 0.0 and race.runners[i].boosts_left == 0, "Each rival finishes with exactly two boosts spent")
	var times: Array = race.runners.map(func(r: Dictionary) -> float: return r.finish_time)
	var results: Array = race.runners.duplicate(true)
	race.reset("yard")
	_check(race.runners == initial and race.time == 0.0 and race.finish_distance == Yard.FINISH, "Yard retry restores the clock, roof phase, uses and field")
	_yard_full_race(race)
	_check(race.runners == results, "Replaying Yard with identical controls reproduces the field")
	race.reset("yard")
	player = race.runners[0]
	for tick in 60 * 50:
		var action := false
		target = -4.25
		if player.p > 72.0:
			target = race._yard_inner_target(player, 2) if player.p < 123.0 else -2.5
			action = player.grounded and (player.p > 107.25 and player.p < Yard.GAP_START
				or player.p > 116.75 and player.p < 117.6)
		var boost: bool = player.boosts_left == 2 and player.p > 2.0 or player.boosts_left == 1 and player.p > 149.0
		race.step(DT, target, action, boost)
	_check(race.rank_of(0) == 1 and player.finish_time > 0.0 and player.respawns == 0, "Competent steering, two jumps and two boosts can win Yard")
	print("170 m winning shortcut: %.2f s." % player.finish_time)
	race.reset()
	_check(race.course_id == "wharf" and race.finish_distance == Race.FINISH, "Legacy reset still selects the original wharf")
	print("170 m finish times in bib order: ", times)
	return true
