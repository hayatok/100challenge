extends SceneTree

const RushDirector = preload("res://combat/rush_director.gd")
var failures := 0


func _initialize() -> void:
	if not _test_waves():
		_expect(false, "Wave test did not finish")
	if not _test_scoring():
		_expect(false, "Scoring test did not finish")
	if not _test_clock():
		_expect(false, "Clock test did not finish")
	print("Rush rules passed" if failures == 0 else "Rush rules failed: %d" % failures)
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_waves() -> bool:
	var round := RushDirector.new()
	var first := round.advance(0.0, 0)
	_expect(first == [0, 0, 1, 0] and round.wave == 1, "The first wave starts immediately")
	_expect(round.advance(1.0, 0).is_empty(), "Clearing the arena does not skip the wave interval")
	_expect(round.advance(21.0, 6).is_empty() and round.wave == 1, "A full arena does not queue waves")
	_expect(round.advance(0.0, 5).size() == 1, "A refill respects the number of available slots")
	_expect(round.advance(0.0, 0).is_empty(), "Waiting at capacity does not bank a burst of waves")

	var middle := round.advance(8.0, 6)
	_expect(round.stage == 2 and middle.size() == 3 and middle.count(1) == 2, "At 30 seconds stage 2 raises the cap and sends more runners")
	var mixed := round.advance(5.0, 5)
	_expect(mixed.has(2), "Stage 2 mixes heavies into its waves")
	_expect(round.advance(24.0, 12).is_empty() and round.stage == 2, "A full arena does not pause the clock")
	_expect(round.advance(1.0, 12).is_empty() and round.stage == 3, "At 60 seconds stage 3 begins even at full capacity")
	var last := round.advance(0.0, 11)
	_expect(last == [2], "Stage 3 sends a heavy even when only one slot is free")
	_expect(round.advance(4.0, 7).size() == 5, "Stage 3 can replenish five enemies on its shorter interval")
	return true


func _test_scoring() -> bool:
	var round := RushDirector.new()
	round.register_discharge(0)
	_expect(round.score == 0 and round.best_discharge == 0, "A missed discharge awards no points")
	for index in range(2):
		round.register_kill()
		round.register_discharge(1)
	_expect(round.score == 200 and round.kills == 2 and round.best_discharge == 1, "Separate single kills do not share a bonus")
	for index in range(3):
		round.register_kill()
	round.register_discharge(3)
	_expect(round.score == 800 and round.kills == 5 and round.best_discharge == 3, "One triple kill awards two extra-kill bonuses")
	round.register_discharge(1)
	_expect(round.score == 800 and round.best_discharge == 3, "Later single kills leave the best discharge intact")
	return true


func _test_clock() -> bool:
	var round := RushDirector.new()
	for frame in range(5399):
		round.advance(1.0 / 60.0, 12)
	_expect(not round.finished and round.time_left > 0.0, "The round is live one physics tick before 90 seconds")
	_expect(round.advance(1.0 / 60.0, 0).is_empty(), "The last tick does not spawn a wave")
	_expect(round.finished and round.time_left == 0.0, "The round ends after 90 seconds of active ticks")
	round.register_kill()
	round.register_discharge(2)
	_expect(round.score == 0 and round.kills == 0 and round.best_discharge == 0, "Scoring stops when the clock expires")
	_expect(round.advance(10.0, 0).is_empty() and round.time_left == 0.0, "Continued ticks leave the finished round unchanged")
	return true
