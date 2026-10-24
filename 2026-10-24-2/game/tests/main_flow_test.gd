extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: Array[String] = []
var _test_record_path: String


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)


func _place(s: float, lateral: float = 0.0, height: float = 0.1) -> void:
	_main.rider.progress = s
	_main.rider.lateral = lateral
	_main.rider.global_position = _main.course.center_at(s) + Vector3(lateral, height, 0.0)


func _hazards_active(value: bool) -> bool:
	for sentry in get_nodes_in_group("sentries"):
		if sentry.active != value:
			return false
	return true


func _run() -> void:
	var actual_path := "user://cloudsea-records.json"
	var actual_existed := FileAccess.file_exists(actual_path)
	var actual_before := FileAccess.get_file_as_bytes(actual_path) if actual_existed else PackedByteArray()
	_test_record_path = "user://cloudsea-flow-test-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(_test_record_path):
		DirAccess.remove_absolute(_test_record_path)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set("record_path", _test_record_path)
	root.add_child(_main)
	# Advance the state clock explicitly; retain the real scene and signal wiring.
	_main.set_process(false)
	await physics_frame
	_expect(_main.state == "title" and _hazards_active(false), "title has inactive hazards")
	var first_sentry: Node3D = _main.get_node("Sentry0")
	_place(230.0)
	first_sentry.call("_physics_process", 2.0)
	_expect(not first_sentry.armed and is_zero_approx(first_sentry.elapsed), "title sentry cannot arm or consume warning time")

	_main.ui.start_requested.emit()
	_expect(_main.state == "countdown" and _hazards_active(false), "start enters a protected countdown")
	_main.call("_process", 1.4)
	var countdown_position: Vector3 = _main.rider.global_position
	await physics_frame
	await physics_frame
	_expect(is_zero_approx(_main.time) and _main.rider.global_position.is_equal_approx(countdown_position), "countdown freezes rider and run clock")
	_main.call("_process", 1.61)
	_expect(_main.state == "run" and _hazards_active(true), "countdown completion activates running hazards")
	await physics_frame
	await physics_frame
	_main.call("_process", 0.5)
	_expect(is_equal_approx(_main.time, 0.5) and _main.rider.progress > 0.0, "run advances time and rider")

	_main.rider.set_physics_process(false)
	_place(230.0)
	first_sentry.call("_physics_process", 0.5)
	_expect(first_sentry.armed and is_equal_approx(first_sentry.elapsed, 0.5), "running sentry arms and advances warning timer")
	var warning_time: float = first_sentry.elapsed
	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	_main.call("_unhandled_input", pause_event)
	var paused_position: Vector3 = _main.rider.global_position
	var paused_time: float = _main.time
	_main.call("_process", 0.5)
	first_sentry.call("_physics_process", 2.0)
	await physics_frame
	_expect(is_equal_approx(first_sentry.elapsed, warning_time) and not first_sentry.fired, "paused sentry cannot advance to firing")
	_expect(_main.state == "pause" and paused and _hazards_active(false), "pause input suspends tree and hazards")
	_expect(is_equal_approx(_main.time, paused_time) and _main.rider.global_position.is_equal_approx(paused_position), "pause preserves clock and position")
	_main.ui.resume_requested.emit()
	_expect(_main.state == "countdown" and not paused and _hazards_active(false), "resume requires another countdown")
	first_sentry.call("_physics_process", 1.0)
	_expect(is_equal_approx(first_sentry.elapsed, warning_time), "resume countdown preserves sentry warning timer")
	_main.call("_process", 3.01)
	_expect(_main.state == "run" and is_equal_approx(_main.time, paused_time), "resume countdown is excluded from run clock")
	first_sentry.call("_physics_process", 1.25)
	_expect(first_sentry.fired, "sentry can finish warning only after running resumes")
	_main.rider.set_physics_process(false)

	# Crossing the same gate twice must not duplicate score or event recovery.
	_main.rider.wind_energy = 20.0
	_main.previous_progress = 99.0
	_place(101.0)
	_main.call("_process_events")
	var gate_score: int = _main.score
	var gate_energy: float = _main.rider.wind_energy
	_expect(gate_score == 100 and is_equal_approx(gate_energy, 40.0), "valid gate awards score and recovery")
	_main.previous_progress = 99.0
	_main.call("_process_events")
	_expect(_main.score == gate_score and is_equal_approx(_main.rider.wind_energy, gate_energy), "gate revisits cannot duplicate rewards")
	_main.previous_progress = 219.0
	_place(221.0, 20.0)
	_main.call("_process_events")
	_expect(not _main.event_ids.has("gate_1"), "off-road progress is not a gate crossing")
	_main.previous_progress = 219.0
	_place(221.0, 0.0, -2.0)
	_main.call("_process_events")
	_expect(not _main.event_ids.has("gate_1"), "crossing below the road is not a gate crossing")

	# Exercise scoring through the rider signals, independent of jump physics.
	# The rider behavior test verifies that real jumps emit these signals once.
	_place(479.0, -3.5, 2.0)
	_main.rider.landed.emit()
	_expect(not _main.event_ids.has("landing_460") and _main.score == gate_score, "upper landing without a jump earns no clean reward")
	_place(450.0, -3.5, 0.0)
	_main.rider.jumped.emit()
	_place(479.0, -3.5, 2.0)
	_main.rider.landed.emit()
	_expect(not _main.event_ids.has("landing_460"), "lower-road jump cannot claim upper-route clean reward")
	_place(450.0, -3.5, 2.0)
	_main.rider.jumped.emit()
	_place(479.0, -3.5, 2.0)
	_main.rider.landed.emit()
	var clean_score: int = _main.score
	_expect(_main.event_ids.has("landing_460") and clean_score > gate_score, "upper takeoff and upper landing earn clean reward")
	_place(450.0, -3.5, 2.0)
	_main.rider.jumped.emit()
	_place(479.0, -3.5, 2.0)
	_main.rider.landed.emit()
	_expect(_main.score == clean_score, "repeated upper jump cannot duplicate clean reward")

	# An actual physics fall drives the connected recovery handler.
	_place(720.0, 0.0, -16.0)
	_main.rider.wind_energy = 10.0
	_main.rider.max_progress = 750.0
	_main.previous_progress = 720.0
	var before_fall_time: float = _main.time
	_main.rider.set_active(true)
	_main.rider.set_physics_process(true)
	await physics_frame
	await physics_frame
	_main.rider.set_physics_process(false)
	_expect(_main.falls == 1 and is_equal_approx(_main.time, before_fall_time + 3.0), "fall signal adds exactly one immediate 3-second penalty")
	_expect(_main.recover_left > 0.0 and _hazards_active(false) and _main.failed_sections.has(2), "fall disables hazards and marks its section")
	_main.rider.fell.emit()
	_expect(_main.falls == 1, "duplicate fall during recovery is ignored")
	_main.call("_process", 0.4)
	_expect(_main.recover_left > 0.0 and _hazards_active(false), "hazards remain inactive during recovery")
	# Pause partway through a real fall recovery. Resume's countdown must not
	# reactivate locomotion until the unconsumed recovery time has elapsed.
	var recovery_position: Vector3 = _main.rider.global_position
	var recovery_progress: float = _main.rider.progress
	var recovery_remaining: float = _main.recover_left
	var recovery_clock: float = _main.time
	_main.rider.set_physics_process(true)
	_main.call("_unhandled_input", pause_event)
	_main.call("_process", 2.0)
	for i in 4:
		await physics_frame
	_expect(_main.state == "pause" and is_equal_approx(_main.recover_left, recovery_remaining) and is_equal_approx(_main.time, recovery_clock), "pause during recovery preserves remaining recovery and clock")
	_main.ui.resume_requested.emit()
	_main.call("_process", 1.5)
	for i in 6:
		await physics_frame
	_expect(_main.rider.global_position.is_equal_approx(recovery_position) and is_equal_approx(_main.rider.progress, recovery_progress), "resumed countdown cannot move the fallen rider")
	_main.call("_process", 1.51)
	for i in 12:
		await physics_frame
	_expect(_main.state == "run" and _hazards_active(false) and not _main.rider.get("_active"), "countdown completion keeps pending recovery rider and hazards inactive")
	_expect(_main.rider.global_position.is_equal_approx(recovery_position) and is_equal_approx(_main.rider.progress, recovery_progress), "physics after resumed countdown cannot advance or skip recovery checkpoint")
	_expect(is_equal_approx(_main.recover_left, recovery_remaining) and is_equal_approx(_main.time, recovery_clock), "resumed countdown does not consume recovery time or run clock")
	_main.call("_process", 0.25)
	for i in 6:
		await physics_frame
	_expect(_main.recover_left > 0.0 and _hazards_active(false) and _main.rider.global_position.is_equal_approx(recovery_position), "partial remaining recovery still prevents movement and hazards")
	_main.call("_process", 0.36)
	_main.rider.set_physics_process(false)
	_expect(is_equal_approx(_main.rider.progress, 665.0) and is_equal_approx(_main.rider.speed, 18.0), "recovery returns to preceding checkpoint at cruise speed")
	_expect(is_equal_approx(_main.rider.wind_energy, 40.0) and is_equal_approx(_main.rider.max_progress, 750.0), "recovery restores minimum energy without rewinding distance history")
	_expect(is_equal_approx(_main.time, before_fall_time + 4.01) and _hazards_active(true), "recovery elapsed time is charged in addition to penalty")
	_expect(_main.event_ids.has("gate_0") and _main.event_ids.has("landing_460"), "checkpoint recovery retains consumed event IDs")
	_main.rider.set_physics_process(true)
	for i in 4:
		await physics_frame
	_expect(_main.rider.progress > 665.0 and _main.rider.get("_active") and _hazards_active(true), "completed recovery reactivates real movement from the intended checkpoint")
	_main.rider.set_physics_process(false)
	var score_after_fall: int = _main.score
	_main.call("_on_sentry_passed", "failed_section_near", true)
	_expect(_main.event_ids.has("failed_section_near") and _main.score == score_after_fall, "failed-section near event is consumed without a reward")
	_main.failed_sections[3] = true
	_place(1070.0, -3.5, 2.0)
	_main.rider.jumped.emit()
	_place(1099.0, -3.5, 2.0)
	_main.rider.landed.emit()
	_expect(_main.event_ids.has("landing_1080") and _main.score == score_after_fall, "failed-section clean event is consumed without a reward")

	# Retry clears transient history; results persist only into the test record.
	_main.ui.retry_requested.emit()
	_expect(_main.state == "countdown" and _main.score == 0 and _main.falls == 0 and is_zero_approx(_main.time), "retry clears score, falls, time and returns to countdown")
	_expect(_main.event_ids.is_empty() and _main.failed_sections.is_empty() and is_zero_approx(_main.rider.max_progress), "retry clears event and distance histories")
	_expect(_hazards_active(false) and not first_sentry.armed and not first_sentry.completed, "retry resets sentries while keeping them inactive")
	_main.call("_process", 3.01)
	_main.time = 89.25
	_main.score = 875
	_main.call("_finish")
	_expect(_main.state == "results" and _hazards_active(false), "finish enters results and deactivates hazards")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(_test_record_path))
	_expect(saved is Dictionary and is_equal_approx(saved.get("best_time", 0.0), 89.25) and saved.get("best_score", 0) == 875, "results save best records to isolated path")
	_main.ui.retry_requested.emit()
	_expect(is_equal_approx(_main.records.best_time, 89.25) and _main.records.best_score == 875 and _main.score == 0, "retry preserves saved bests while clearing run score")
	_expect(FileAccess.file_exists(actual_path) == actual_existed and (not actual_existed or FileAccess.get_file_as_bytes(actual_path) == actual_before), "production user records remain byte-for-byte unchanged")
	paused = false
	# Let the audio server drain queued one-shot playbacks before scene teardown.
	if is_instance_valid(_main.sound):
		_main.sound.set_process(false)
		for player in _main.sound.get_children():
			if player is AudioStreamPlayer:
				player.stop()
	await create_timer(0.25).timeout
	_main.queue_free()
	await create_timer(0.25).timeout
	DirAccess.remove_absolute(_test_record_path)
	print("Main flow: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
