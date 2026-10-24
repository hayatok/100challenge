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


func _pose_snapshot() -> Dictionary:
	var pose = _main.assets.pose_controller
	if not is_instance_valid(pose) or not pose.has_method("motion_snapshot"):
		return {}
	return pose.motion_snapshot()


func _has_start_motion() -> bool:
	var snapshot := _pose_snapshot()
	return snapshot.get("context", "") == "running" and snapshot.get("events", {}).has(&"start")


func _run() -> void:
	var actual_path := "user://cloudsea-records.json"
	var actual_existed := FileAccess.file_exists(actual_path)
	var actual_before := FileAccess.get_file_as_bytes(actual_path) if actual_existed else PackedByteArray()
	var carve_path := "user://cloudsea-carve-v2.json"
	var carve_existed := FileAccess.file_exists(carve_path)
	var carve_before := FileAccess.get_file_as_bytes(carve_path) if carve_existed else PackedByteArray()
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
	_expect(_main.RECORD_PATH == carve_path and _main.RECORD_PATH != actual_path, "new course uses a separate production records file")
	_expect(not _has_start_motion(), "real pose controller has no start event on the title screen")
	var first_sentry: Node3D = _main.get_node("Sentry0")
	_place(290.0)
	first_sentry.call("_physics_process", 2.0)
	_expect(not first_sentry.armed and is_zero_approx(first_sentry.elapsed), "title sentry cannot arm or consume warning time")

	_main.ui.start_requested.emit()
	_expect(_main.state == "countdown" and _hazards_active(false), "start enters a protected countdown")
	_main.call("_process", 0.4)
	var countdown_position: Vector3 = _main.rider.global_position
	await physics_frame
	await physics_frame
	_expect(is_zero_approx(_main.time) and _main.rider.global_position.is_equal_approx(countdown_position), "countdown freezes rider and run clock")
	_expect(not _has_start_motion(), "protected countdown does not trigger the start clip early")
	_main.call("_process", 0.81)
	_expect(_main.state == "run" and _hazards_active(true), "countdown completion activates running hazards")
	_expect(_has_start_motion(), "countdown completion reaches the actual rider pose start event")
	await physics_frame
	await physics_frame
	_main.call("_process", 0.5)
	_expect(is_equal_approx(_main.time, 0.5) and _main.rider.progress > 0.0, "run advances time and rider")

	_main.rider.set_physics_process(false)
	_place(290.0)
	first_sentry.call("_physics_process", 0.5)
	_expect(first_sentry.armed and is_equal_approx(first_sentry.elapsed, 0.5), "running sentry arms and advances warning timer")
	var warning_time: float = first_sentry.elapsed
	_main.assets.pose_controller.trigger_motion(&"jump")
	_main.assets.pose_controller.advance_motion(0.27)
	var pose_before_pause := _pose_snapshot()
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
	_expect(_pose_snapshot() == pose_before_pause, "pause keeps the actual pose and event progress instead of resetting to idle")
	_main.ui.resume_requested.emit()
	_expect(_main.state == "countdown" and paused and _hazards_active(false), "resume cue keeps the world paused while Main and UI remain active")
	_main.call("_process", 0.5)
	await physics_frame
	_expect(_pose_snapshot() == pose_before_pause, "resume cue preserves the exact paused pose and its event progress")
	first_sentry.call("_physics_process", 1.0)
	_expect(is_equal_approx(first_sentry.elapsed, warning_time), "resume countdown preserves sentry warning timer")
	_main.call("_process", 3.01)
	_expect(_main.state == "run" and is_equal_approx(_main.time, paused_time), "resume countdown is excluded from run clock")
	_expect(_pose_snapshot().get("events", {}).has(&"jump"), "resume continues the existing jump animation instead of replacing it with a start clip")
	first_sentry.call("_physics_process", 1.25)
	_expect(first_sentry.fired, "sentry can finish warning only after running resumes")
	_main.rider.set_physics_process(false)

	# Crossing the same gate twice must not duplicate score or event recovery.
	_main.rider.wind_energy = 20.0
	_main.previous_progress = 154.0
	_place(156.0)
	_main.call("_process_events")
	var gate_score: int = _main.score
	var gate_energy: float = _main.rider.wind_energy
	_expect(gate_score == 60 and is_equal_approx(gate_energy, 26.0), "valid gate awards score and recovery")
	_main.previous_progress = 154.0
	_main.call("_process_events")
	_expect(_main.score == gate_score and is_equal_approx(_main.rider.wind_energy, gate_energy), "gate revisits cannot duplicate rewards")
	_main.previous_progress = 274.0
	_place(276.0, 20.0)
	_main.call("_process_events")
	_expect(not _main.event_ids.has("gate_1"), "off-road progress is not a gate crossing")
	_main.previous_progress = 274.0
	_place(276.0, 0.0, -2.0)
	_main.call("_process_events")
	_expect(not _main.event_ids.has("gate_1"), "crossing below the road is not a gate crossing")

	# Exercise scoring through the rider signals, independent of jump physics.
	# The rider behavior test verifies that real jumps emit these signals once.
	_place(265.0)
	_main.rider.landed.emit()
	_expect(not _main.event_ids.has("landing_245") and _main.score == gate_score, "landing without recorded takeoff earns no flight reward")
	_place(240.0)
	_main.rider.jumped.emit()
	_place(265.0)
	_main.rider.landed.emit()
	var clean_score: int = _main.score
	_expect(_main.event_ids.has("landing_245") and clean_score > gate_score, "real gap takeoff and landing earn flight reward")
	_place(240.0)
	_main.rider.jumped.emit()
	_place(265.0)
	_main.rider.landed.emit()
	_expect(_main.score == clean_score, "checkpoint revisits cannot duplicate flight reward")
	# Motion still works on a replay, but a saved score cannot be farmed by falling.
	_place(320.0)
	_main.rider.max_progress = 320.0
	_main.rider.carve_released.emit(0.91)
	var carve_score: int = _main.score
	_expect(carve_score > clean_score, "a fresh successful carve earns a motion reward")
	_main.rider.carve_released.emit(0.91)
	_expect(_main.score == carve_score, "duplicate carve signals in one reward interval cannot rescore")
	_place(325.0)
	_main.rider.max_progress = 325.0
	_main.rider.carve_released.emit(0.91)
	_expect(_main.score == carve_score, "a second carve inside the same 20m interval cannot rescore")
	_main.rider.max_progress = 390.0
	_place(345.0)
	_main.rider.carve_released.emit(0.91)
	_main.rider.clean_landed.emit(1.0)
	_expect(_main.score == carve_score, "recovery replay below furthest travel cannot earn carve or clean score")
	_expect(not _main.event_ids.has("CARVE_17") and not _main.event_ids.has("CLEAN_17"), "replay does not mark missed intervals as newly earned")
	_place(405.0)
	_main.rider.max_progress = 405.0
	_main.rider.clean_landed.emit(1.0)
	var fresh_clean_score: int = _main.score
	_expect(fresh_clean_score > carve_score, "fresh ground beyond the old frontier can earn a clean landing reward")
	_main.rider.clean_landed.emit(1.0)
	_expect(_main.score == fresh_clean_score, "clean landing cannot repeat inside one reward interval")

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
	_expect(_main.recover_left > 0.0 and _hazards_active(false) and _main.failed_sections.has(4), "fall disables hazards and marks its section")
	_main.rider.fell.emit()
	_expect(_main.falls == 1, "duplicate fall during recovery is ignored")
	_main.call("_process", 0.2)
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
	_main.call("_process", 0.5)
	for i in 6:
		await physics_frame
	_expect(_main.rider.global_position.is_equal_approx(recovery_position) and is_equal_approx(_main.rider.progress, recovery_progress), "resumed countdown cannot move the fallen rider")
	_main.call("_process", 0.71)
	for i in 12:
		await physics_frame
	_expect(_main.state == "run" and _hazards_active(false) and not _main.rider.get("_active"), "countdown completion keeps pending recovery rider and hazards inactive")
	_expect(not _has_start_motion(), "resuming with pending recovery does not play a false start event")
	_expect(_main.rider.global_position.is_equal_approx(recovery_position) and is_equal_approx(_main.rider.progress, recovery_progress), "physics after resumed countdown cannot advance or skip recovery checkpoint")
	_expect(is_equal_approx(_main.recover_left, recovery_remaining) and is_equal_approx(_main.time, recovery_clock), "resumed countdown does not consume recovery time or run clock")
	_main.call("_process", 0.2)
	for i in 6:
		await physics_frame
	_expect(_main.recover_left > 0.0 and _hazards_active(false) and _main.rider.global_position.is_equal_approx(recovery_position), "partial remaining recovery still prevents movement and hazards")
	_main.call("_process", 0.26)
	_main.rider.set_physics_process(false)
	_expect(is_equal_approx(_main.rider.progress, 615.0) and is_equal_approx(_main.rider.speed, 24.0), "recovery returns to preceding checkpoint at cruise speed")
	_expect(is_equal_approx(_main.rider.wind_energy, 48.0) and is_equal_approx(_main.rider.max_progress, 750.0), "recovery restores minimum energy without rewinding distance history")
	_expect(is_equal_approx(_main.time, before_fall_time + 3.66) and _hazards_active(true), "recovery elapsed time is charged in addition to penalty")
	_expect(_main.event_ids.has("gate_0") and _main.event_ids.has("landing_245"), "checkpoint recovery retains consumed event IDs")
	_main.rider.set_physics_process(true)
	for i in 4:
		await physics_frame
	_expect(_main.rider.progress > 615.0 and _main.rider.get("_active") and _hazards_active(true), "completed recovery reactivates real movement from the intended checkpoint")
	_main.rider.set_physics_process(false)
	var score_after_fall: int = _main.score
	_main.call("_on_sentry_passed", "failed_section_near", true)
	_expect(_main.event_ids.has("failed_section_near") and _main.score == score_after_fall, "failed-section near event is consumed without a reward")

	# Retry clears transient history; results persist only into the test record.
	_main.ui.retry_requested.emit()
	_expect(_main.state == "countdown" and _main.score == 0 and _main.falls == 0 and is_zero_approx(_main.time), "retry clears score, falls, time and returns to countdown")
	_expect(_main.event_ids.is_empty() and _main.failed_sections.is_empty() and is_zero_approx(_main.rider.max_progress), "retry clears event and distance histories")
	_expect(_hazards_active(false) and not first_sentry.armed and not first_sentry.completed, "retry resets sentries while keeping them inactive")
	_main.call("_process", 3.01)
	_place(_main.course.length + 1.0, 24.0)
	_main.call("_process", 0.0)
	_expect(_main.state == "run", "off-road progress past the finish cannot complete a run")
	_place(_main.course.length + 1.0, 0.0, 6.0)
	_main.rider.set_physics_process(true)
	await physics_frame
	await physics_frame
	_main.rider.set_physics_process(false)
	_main.call("_process", 0.0)
	_expect(_main.state == "run" and not _main.rider.is_on_floor(), "flying past the finish over the void cannot complete a run")
	_place(_main.course.length + 1.0)
	_main.rider.velocity = Vector3.ZERO
	_main.rider.set_physics_process(true)
	for i in 16:
		await physics_frame
		if _main.rider.is_on_floor():
			break
	_main.rider.set_physics_process(false)
	_expect(_main.rider.is_on_floor(), "finish fixture reaches the real collision surface before completing")
	_main.time = 89.25
	_main.score = 875
	_main.call("_process", 0.0)
	_expect(_main.state == "results" and _hazards_active(false), "finish enters results and deactivates hazards")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(_test_record_path))
	_expect(saved is Dictionary and is_equal_approx(saved.get("best_time", 0.0), 89.25) and saved.get("best_score", 0) == 875, "results save best records to isolated path")
	_expect(saved is Dictionary and saved.get("course_revision", 0) == 2, "saved records identify the redesigned course revision")
	_main.ui.retry_requested.emit()
	_expect(is_equal_approx(_main.records.best_time, 89.25) and _main.records.best_score == 875 and _main.score == 0, "retry preserves saved bests while clearing run score")
	_expect(FileAccess.file_exists(actual_path) == actual_existed and (not actual_existed or FileAccess.get_file_as_bytes(actual_path) == actual_before), "legacy production user records remain byte-for-byte unchanged")
	_expect(FileAccess.file_exists(carve_path) == carve_existed and (not carve_existed or FileAccess.get_file_as_bytes(carve_path) == carve_before), "new-course production user records remain byte-for-byte unchanged")
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
