extends SceneTree

# Scale wall-clock execution while retaining a 1/60-second simulation step.
const SIMULATION_HZ: int = 60
const ACCELERATION: int = 8
const LOWER_TICK_LIMIT: int = 7200
const UPPER_TICK_LIMIT: int = 900
const WALL_TIMEOUT_MS: int = 30000

class TickProbe extends Node:
	var minimum_delta: float = INF
	var maximum_delta: float = 0.0

	func _physics_process(delta: float) -> void:
		minimum_delta = minf(minimum_delta, delta)
		maximum_delta = maxf(maximum_delta, delta)

var _course: Node3D
var _rider: CharacterBody3D
var _probe: TickProbe
var _failures: int = 0
var _checks: int = 0
var _falls: int = 0
var _jumps: int = 0
var _departure_s: float = -1.0
var _departure_y: float = 0.0
var _landing_s: float = -1.0
var _landing_height: float = 0.0
var _landing_lateral: float = 0.0
var _maximum_y: float = 0.0
var _maximum_base_height: float = 0.0
var _deadline: int


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	var original_scale := Engine.time_scale
	var original_step_limit := Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = SIMULATION_HZ * ACCELERATION
	Engine.time_scale = float(ACCELERATION)
	Engine.max_physics_steps_per_frame = 64
	_deadline = Time.get_ticks_msec() + WALL_TIMEOUT_MS
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	_course = Node3D.new()
	_course.set_script(load("res://scripts/course.gd"))
	root.add_child(_course)
	_probe = TickProbe.new()
	root.add_child(_probe)
	_rider = load("res://scenes/rider.tscn").instantiate()
	_rider.set("course", _course)
	root.add_child(_rider)
	_rider.fell.connect(func(): _falls += 1)
	_rider.jumped.connect(_observe_departure)
	_rider.landed.connect(_observe_landing)
	await physics_frame
	await physics_frame

	# Real collision geometry, no steering, brake, boost or jump input.
	_rider.reset_run()
	_rider.wind_energy = 0.0
	_rider.set_active(true)
	var lower_ticks := 0
	var maximum_lateral := 0.0
	while _rider.progress < _course.length and _falls == 0 and lower_ticks < LOWER_TICK_LIMIT and _within_deadline():
		await physics_frame
		lower_ticks += 1
		maximum_lateral = maxf(maximum_lateral, absf(_rider.lateral))
	_rider.set_active(false)
	_expect(_rider.progress >= 1650.0, "zero-input lower route reaches the 1650m finish within 120 simulated seconds")
	_expect(_falls == 0, "zero-input lower route has no falls")
	_expect(_jumps == 0, "lower route requires no jump input")
	_expect(maximum_lateral < 1.0, "unsteered rider stays on the continuous lower route")
	print("Course lower: ticks=%d simulation_seconds=%.3f progress=%.3f max_lateral=%.4f falls=%d" % [lower_ticks, float(lower_ticks) / SIMULATION_HZ, _rider.progress, maximum_lateral, _falls])

	# Begin before the upper ramp; reach the lane using steering actions only.
	# At about 18m/s, taking off 4m before the 8m opening leaves a landing
	# about 5m beyond its far edge under the nominal 8.5m/s jump / 18m/s2 gravity.
	_falls = 0
	_jumps = 0
	_departure_s = -1.0
	_landing_s = -1.0
	_maximum_base_height = 0.0
	_rider.reset_to(315.0, 0.0)
	_rider.set_active(true)
	var upper_ticks := 0
	var jump_requested := false
	var ramp_seen := false
	var airborne_gap_ticks := 0
	while upper_ticks < UPPER_TICK_LIMIT and _falls == 0 and _within_deadline():
		_steer_to(-3.5)
		if _rider.progress >= 420.0 and _rider.progress < 450.0 and _rider.is_on_floor():
			var center: Vector3 = _course.center_at(_rider.progress)
			if _rider.global_position.y - center.y > 1.5:
				ramp_seen = true
		if not jump_requested and _rider.progress >= 455.5:
			Input.action_press("jump")
			jump_requested = true
		elif jump_requested:
			Input.action_release("jump")
		await physics_frame
		upper_ticks += 1
		if _departure_s >= 0.0 and _landing_s < 0.0:
			var center: Vector3 = _course.center_at(_rider.progress)
			_maximum_y = maxf(_maximum_y, _rider.global_position.y)
			_maximum_base_height = maxf(_maximum_base_height, _rider.global_position.y - center.y)
			if _rider.progress > 462.0 and _rider.progress < 466.0 and not _rider.is_on_floor():
				airborne_gap_ticks += 1
		if _landing_s >= 0.0 or _rider.progress > 500.0:
			break
	_rider.set_active(false)
	for action in ["steer_left", "steer_right", "jump"]:
		Input.action_release(action)
	_expect(ramp_seen, "steering reaches the elevated upper ramp before takeoff")
	_expect(_jumps == 1 and _departure_s >= 455.0 and _departure_s < 460.0, "one Space action produces a real takeoff before the opening")
	_expect(airborne_gap_ticks > 0, "rider is physically airborne over the middle of the 460..468m opening")
	_expect(_landing_s >= 468.0 and _landing_s <= 490.0, "real landing occurs beyond the opening")
	_expect(_landing_height > 1.5 and _landing_lateral < -1.5, "landing returns to the elevated lane rather than the safety road")
	_expect(_maximum_y - _departure_y > 1.5, "jump rises more than 1.5m above its actual takeoff")
	_expect(_falls == 0, "upper ramp and gap traversal has no falls")
	_expect(is_equal_approx(_probe.minimum_delta, 1.0 / SIMULATION_HZ) and is_equal_approx(_probe.maximum_delta, 1.0 / SIMULATION_HZ), "acceleration preserves the actual 1/60-second physics delta")
	_expect(_within_deadline(), "both paths finish inside the wall-clock timeout")
	print("Course upper: ticks=%d takeoff_s=%.3f landing_s=%.3f landing_height=%.3f landing_lateral=%.3f jump_rise=%.3f max_above_base=%.3f airborne_gap_ticks=%d falls=%d" % [upper_ticks, _departure_s, _landing_s, _landing_height, _landing_lateral, _maximum_y - _departure_y, _maximum_base_height, airborne_gap_ticks, _falls])
	print("Course physics delta: min=%.8f max=%.8f" % [_probe.minimum_delta, _probe.maximum_delta])
	print("Course run: %d checks, %d failures" % [_checks, _failures])
	_rider.queue_free()
	_course.queue_free()
	_probe.queue_free()
	await process_frame
	Engine.time_scale = original_scale
	Engine.physics_ticks_per_second = original_hz
	Engine.max_physics_steps_per_frame = original_step_limit
	quit(0 if _failures == 0 else 1)


func _steer_to(target: float) -> void:
	var strength := clampf((target - _rider.lateral) * 0.35, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if strength < 0.0:
		Input.action_press("steer_left", -strength)
	elif strength > 0.0:
		Input.action_press("steer_right", strength)


func _observe_departure() -> void:
	_jumps += 1
	_departure_s = _rider.progress
	_departure_y = _rider.global_position.y
	_maximum_y = _departure_y


func _observe_landing() -> void:
	if _departure_s < 0.0 or _landing_s >= 0.0:
		return
	_landing_s = _rider.progress
	_landing_height = _rider.global_position.y - _course.center_at(_rider.progress).y
	_landing_lateral = _rider.lateral


func _within_deadline() -> bool:
	return Time.get_ticks_msec() < _deadline
