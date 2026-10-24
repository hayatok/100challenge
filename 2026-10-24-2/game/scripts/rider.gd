extends CharacterBody3D

signal fell
signal landed
signal jumped
signal carve_released(charge: float)
signal burst_started(strength: float)
signal clean_landed(strength: float)

@export var course: Node3D
@export_group("Motion")
@export var cruise_speed: float = 24.0
@export var downhill_speed: float = 29.0
@export var boost_speed: float = 40.0
@export var brake_speed: float = 17.0
@export var jump_speed: float = 8.2
@export var gravity: float = 20.0
@export var turn_speed: float = 0.82
@export var carve_turn_speed: float = 1.08
@export var turn_acceleration: float = 18.0
@export var turn_release_acceleration: float = 32.0
@export var carve_charge_rate: float = 1.5
@export var aligned_charge_rate: float = 2.6
@export var minimum_carve_time: float = 0.25
@export var minimum_carve_distance: float = 4.0
@export_range(0.0, 1.0) var air_control: float = 0.35
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var fall_depth: float = 4.0

var heading: float = 0.0
var steer_amount: float = 0.0
var carve_amount: float = 0.0
var carving: bool = false
var carve_charge: float = 0.0
var charge_rate: float = 0.0
var charge_requires_press: bool:
	get:
		return carve_charge > 0.0 and not _carve_release_armed
var burst_left: float = 0.0
var airborne_time: float = 0.0
var landing_strength: float = 0.0
var _carve_direction: float = 0.0
var _carve_time: float = 0.0
var _carve_distance: float = 0.0
var _burst_strength: float = 0.0
var _steering_rate: float = 0.0

var progress: float = 0.0
var lateral: float = 0.0
var speed: float = 24.0
var wind_energy: float = 60.0
var boosting: bool = false
var max_progress: float = 0.0

var _active: bool = false
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_ready: bool = false
var _boost_ready: bool = false
var _steer_ready: bool = false
var _brake_ready: bool = false
var _carve_release_armed: bool = false
var _hit_immunity: float = 0.0
var _air_time: float = 0.0
var _suppress_landing: bool = true
var _fell_pending: bool = false
var _fall_reason: String = ""
var fall_reason: String:
	get:
		return _fall_reason

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	floor_snap_length = 0.9
	floor_constant_speed = true
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(55.0)


func set_active(value: bool) -> void:
	_active = value
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	# Pause/countdown hide active effects, but preserve earned or paid-for wind.
	boosting = value and burst_left > 0.0
	carving = false
	carve_amount = 0.0
	charge_rate = 0.0
	steer_amount = 0.0
	_steering_rate = 0.0
	_carve_release_armed = false
	# Held actions must be released and pressed again after a countdown/pause.
	_jump_ready = value and not Input.is_action_pressed("jump")
	_boost_ready = value and not Input.is_action_pressed("boost")
	_steer_ready = value and absf(Input.get_axis("steer_left", "steer_right")) < 0.1
	_brake_ready = value and not Input.is_action_pressed("brake")


func _reset_travel_resources() -> void:
	boosting = false
	carving = false
	carve_amount = 0.0
	carve_charge = 0.0
	_carve_time = 0.0
	_carve_distance = 0.0
	_carve_direction = 0.0
	_carve_release_armed = false
	charge_rate = 0.0
	burst_left = 0.0
	_burst_strength = 0.0


func reset_run() -> void:
	max_progress = 0.0
	reset_to(0.0, 60.0)


func reset_to(s: float, energy: float) -> void:
	progress = maxf(s, 0.0)
	var center := _center_at(progress)
	global_position = center + Vector3.UP * 0.10
	lateral = 0.0
	speed = cruise_speed
	heading = _heading_at(progress)
	airborne_time = 0.0
	landing_strength = 0.0
	wind_energy = clampf(energy, 0.0, 100.0)
	velocity = Vector3.ZERO
	_hit_immunity = 1.5
	_air_time = 0.0
	_suppress_landing = true
	_fell_pending = false
	_fall_reason = ""
	_reset_travel_resources()
	set_active(false)
	if is_instance_valid(_visual):
		_visual.visible = true
		_visual.rotation = Vector3(0.0, _heading_at(progress), 0.0)
	reset_physics_interpolation()


func take_hit() -> bool:
	if not _active or _hit_immunity > 0.0:
		return false
	burst_left = 0.0
	boosting = false
	carve_charge = 0.0
	_carve_time = 0.0
	_carve_distance = 0.0
	var old_speed := speed
	speed = maxf(brake_speed, speed * 0.70)
	var retention := speed / maxf(old_speed, 0.01)
	# Keep the travel vector, including the player's chosen lateral line.
	velocity.x *= retention
	velocity.z *= retention
	_hit_immunity = 1.5
	return true


func grant_energy(amount: float) -> void:
	if not boosting and amount > 0.0:
		wind_energy = minf(100.0, wind_energy + amount)


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(course):
		return
	_hit_immunity = maxf(0.0, _hit_immunity - delta)
	progress = maxf(0.0, -global_position.z)
	var grounded := is_on_floor()
	var tangent := _tangent_at(progress)
	var steer_input := Input.get_axis("steer_left", "steer_right")
	if absf(steer_input) < 0.1:
		_steer_ready = true
	steer_amount = steer_input if _steer_ready else 0.0
	_update_buttons(delta, grounded)
	_update_carve(delta, grounded)
	_update_speed(delta, tangent, grounded)

	var turn_rate := carve_turn_speed if carving else turn_speed
	var control := 1.0 if grounded else air_control
	var target_turn_rate := -steer_amount * turn_rate * control
	var stopping_or_reversing := is_zero_approx(target_turn_rate) or _steering_rate * target_turn_rate < 0.0
	var turn_response := turn_release_acceleration if stopping_or_reversing else turn_acceleration
	_steering_rate = move_toward(_steering_rate, target_turn_rate, turn_response * delta)
	heading = clampf(heading + _steering_rate * delta, -1.15, 1.15)
	# Steering rotates the actual travel direction. The course never steers us.
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	# Ground contact owns the slope-following rise. Do not carry that rise
	# into a free ballistic launch before Space reaches the visible lip.
	velocity.y = -gravity * delta if grounded else velocity.y - gravity * delta
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_speed
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_suppress_landing = false
		jumped.emit()

	move_and_slide()
	progress = maxf(0.0, -global_position.z)
	lateral = global_position.x - _center_at(progress).x
	_update_progress()
	_update_landing(delta, grounded)
	_update_visual(delta, tangent, steer_amount)
	_detect_missed_surface()


func _detect_missed_surface() -> void:
	if _fell_pending or is_on_floor():
		return
	var width := float(course.call("half_width_at", progress))
	var on_platform := true
	var sample_s := progress
	if course.has_method("gap_at"):
		var gap: Vector2 = course.call("gap_at", sample_s)
		on_platform = gap == Vector2.ZERO
		if not on_platform:
			var landing: Vector3 = course.call("surface_at", gap.y, clampf(lateral, -width, width))
			# Once descending feet are below the destination and coyote time is
			# over, no remaining input can turn this flight into a valid landing.
			if velocity.y <= 0.0 and _coyote_left <= 0.0 and global_position.y < landing.y - 0.18:
				_fail_fall("missed_platform")
				return
			# Catch the capsule reaching the landing lip before its head clips stone.
			if course.call("gap_at", progress + 0.4) == Vector2.ZERO:
				sample_s = progress + 0.4
				on_platform = true
	var surface := _center_at(sample_s)
	if course.has_method("surface_at"):
		surface = course.call("surface_at", sample_s, clampf(lateral, -width, width))
	if on_platform and absf(lateral) <= width + 0.15 and global_position.y < surface.y - 0.18:
		_fail_fall("missed_platform")
	elif absf(lateral) > width + 0.5 and velocity.y <= 0.0 and global_position.y < surface.y - 1.0:
		_fail_fall("side_fall")
	elif global_position.y < _center_at(progress).y - fall_depth:
		_fail_fall("below_course")


func _fail_fall(reason: String) -> void:
	if _fell_pending:
		return
	_fell_pending = true
	_fall_reason = reason
	_visual.visible = false
	set_active(false)
	fell.emit()


func _update_buttons(delta: float, grounded: bool) -> void:
	_coyote_left = coyote_time if grounded else maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if not Input.is_action_pressed("jump"):
		_jump_ready = true
	if _jump_ready and Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
		_jump_ready = false

	if not Input.is_action_pressed("brake"):
		_brake_ready = true
	elif _brake_ready:
		_carve_release_armed = true
	if not Input.is_action_pressed("boost"):
		_boost_ready = true
	if _boost_ready and Input.is_action_just_pressed("boost") and wind_energy >= 24.0:
		wind_energy -= 24.0
		_start_burst(0.85)
		_boost_ready = false
	burst_left = maxf(0.0, burst_left - delta)
	boosting = burst_left > 0.0


func _update_carve(delta: float, grounded: bool) -> void:
	carving = grounded and _brake_ready and Input.is_action_pressed("brake") and absf(steer_amount) > 0.18 and speed > 12.0
	carve_amount = steer_amount if carving else 0.0
	charge_rate = 0.0
	if carving and not boosting:
		if carve_charge > 0.0 and signf(steer_amount) != _carve_direction:
			# Changing edges discards the previous load, so wiggling cannot stack it.
			carve_charge = 0.0
			_carve_time = 0.0
			_carve_distance = 0.0
		_carve_direction = signf(steer_amount)
		_carve_time += delta
		_carve_distance += maxf(0.0, -velocity.z) * delta
		var curvature := 0.0
		if course.has_method("curvature_at"):
			curvature = float(course.call("curvature_at", progress))
		var aligned := curvature * -steer_amount > 0.001
		charge_rate = (aligned_charge_rate if aligned else carve_charge_rate) * absf(steer_amount)
		if absf(lateral) > float(course.call("half_width_at", progress)):
			charge_rate = 0.0
		var gained := minf(1.0 - carve_charge, charge_rate * delta)
		carve_charge += gained
	elif _carve_release_armed and not Input.is_action_pressed("brake") and carve_charge > 0.0:
		var released := carve_charge
		var held_edge := _carve_time >= minimum_carve_time and _carve_distance >= minimum_carve_distance
		carve_charge = 0.0
		_carve_release_armed = false
		_carve_time = 0.0
		_carve_distance = 0.0
		if held_edge and released >= 0.22:
			# Reward the committed release once, never partial taps or reversals.
			grant_energy(released * 12.0)
			carve_released.emit(released)
			_start_burst(released)
	elif carve_charge > 0.0 and not grounded:
		carve_charge = maxf(0.0, carve_charge - 0.15 * delta)


func _start_burst(strength: float) -> void:
	_burst_strength = clampf(strength, 0.0, 1.0)
	burst_left = maxf(burst_left, 0.55 + _burst_strength * 1.1)
	boosting = true
	# The release should be felt now, rather than several seconds later.
	speed = maxf(speed, lerpf(29.0, 36.0, _burst_strength))
	burst_started.emit(_burst_strength)


func _update_speed(delta: float, tangent: Vector3, grounded: bool) -> void:
	var target := cruise_speed
	var acceleration := 7.0
	if grounded:
		target = minf(downhill_speed, cruise_speed + maxf(0.0, -tangent.y) * 35.0)
	if boosting:
		target = boost_speed
		acceleration = 20.0
	if carving:
		target = 20.0
		acceleration = 13.0
	elif grounded and _brake_ready and Input.is_action_pressed("brake"):
		target = brake_speed
		acceleration = 18.0
	speed = move_toward(speed, target, acceleration * delta)


func _update_progress() -> void:
	max_progress = maxf(max_progress, progress)


func _update_landing(delta: float, was_grounded: bool) -> void:
	if not is_on_floor():
		_air_time += delta
		airborne_time = _air_time
		return
	if not was_grounded and not _suppress_landing and _air_time >= 0.10:
		landing_strength = clampf(_air_time / 0.85, 0.0, 1.0)
		landed.emit()
		if absf(angle_difference(heading, _heading_at(progress))) < 0.22 and _air_time >= 0.30:
			grant_energy(14.0)
			clean_landed.emit(landing_strength)
	_air_time = 0.0
	airborne_time = 0.0
	_suppress_landing = false


func _update_visual(delta: float, tangent: Vector3, steer: float) -> void:
	var visual_heading := heading - carve_amount * 0.15
	_visual.rotation.y = lerp_angle(_visual.rotation.y, visual_heading, 1.0 - exp(-8.0 * delta))
	_visual.rotation.z = lerpf(_visual.rotation.z, -steer * (0.42 if carving else 0.24), 1.0 - exp(-9.0 * delta))
	var pitch := atan2(tangent.y, Vector2(tangent.x, tangent.z).length()) if is_on_floor() else 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, pitch, 1.0 - exp(-7.0 * delta))


func _center_at(s: float) -> Vector3:
	if is_instance_valid(course):
		return course.call("center_at", s)
	return Vector3(0.0, 0.0, -s)


func _tangent_at(s: float) -> Vector3:
	var tangent: Vector3 = course.call("tangent_at", s)
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.FORWARD


func _heading_at(s: float) -> float:
	if not is_instance_valid(course):
		return 0.0
	var tangent := _tangent_at(s)
	return atan2(-tangent.x, -tangent.z)
