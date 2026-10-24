extends CharacterBody3D

signal fell
signal landed
signal jumped

@export var course: Node3D
@export_group("Motion")
@export var cruise_speed: float = 18.0
@export var downhill_speed: float = 28.0
@export var boost_speed: float = 34.0
@export var brake_speed: float = 8.0
@export var jump_speed: float = 8.5
@export var gravity: float = 18.0
@export var steering_speed: float = 7.5
@export var steering_acceleration: float = 28.0
@export_range(0.0, 1.0) var air_control: float = 0.35
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var fall_depth: float = 14.0

var progress: float = 0.0
var lateral: float = 0.0
var speed: float = 18.0
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
var _spent_boost_this_tick: bool = false
var _lateral_speed: float = 0.0
var _recovery_distance: float = 0.0
var _hit_immunity: float = 0.0
var _air_time: float = 0.0
var _suppress_landing: bool = true
var _fell_pending: bool = false

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
	boosting = false
	# A held button during a countdown or pause must not carry into play.
	_jump_ready = value and not Input.is_action_pressed("jump")
	_boost_ready = value and not Input.is_action_pressed("boost")
	_steer_ready = value and absf(Input.get_axis("steer_left", "steer_right")) < 0.1
	_brake_ready = value and not Input.is_action_pressed("brake")


func reset_run() -> void:
	max_progress = 0.0
	_recovery_distance = 0.0
	reset_to(0.0, 60.0)


func reset_to(s: float, energy: float) -> void:
	progress = maxf(s, 0.0)
	var center := _center_at(progress)
	global_position = center + Vector3.UP * 0.10
	lateral = 0.0
	speed = cruise_speed
	wind_energy = clampf(energy, 0.0, 100.0)
	velocity = Vector3.ZERO
	_lateral_speed = 0.0
	_hit_immunity = 1.5
	_air_time = 0.0
	_suppress_landing = true
	_fell_pending = false
	set_active(false)
	if is_instance_valid(_visual):
		_visual.rotation = Vector3(0.0, _heading_at(progress), 0.0)
	reset_physics_interpolation()


func take_hit() -> bool:
	if not _active or _hit_immunity > 0.0:
		return false
	var old_speed := speed
	speed = maxf(brake_speed, speed * 0.70)
	var retention := speed / maxf(old_speed, 0.01)
	# Keep the travel vector, including the player's chosen lateral line.
	velocity.x *= retention
	velocity.z *= retention
	_lateral_speed *= retention
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
	var forward := Vector3(tangent.x, 0.0, tangent.z).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var steer_input := Input.get_axis("steer_left", "steer_right")
	if absf(steer_input) < 0.1:
		_steer_ready = true
	var steer := steer_input if _steer_ready else 0.0
	_update_buttons(delta, grounded)
	_update_speed(delta, tangent, grounded)

	var control := 1.0 if grounded else air_control
	var target_lateral := steer * steering_speed * control
	_lateral_speed = move_toward(_lateral_speed, target_lateral, steering_acceleration * control * delta)
	var horizontal := forward * speed + right * _lateral_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= gravity * delta
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_speed
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_suppress_landing = false
		jumped.emit()

	move_and_slide()
	progress = maxf(0.0, -global_position.z)
	lateral = (global_position - _center_at(progress)).dot(right)
	_update_distance_energy()
	_update_landing(delta, grounded)
	_update_visual(delta, tangent, steer)
	if not _fell_pending and global_position.y < _center_at(progress).y - fall_depth:
		_fell_pending = true
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
	if not Input.is_action_pressed("boost"):
		_boost_ready = true
		boosting = false
	elif _boost_ready and wind_energy > 0.0:
		boosting = true
	_spent_boost_this_tick = boosting
	if boosting:
		wind_energy = maxf(0.0, wind_energy - 40.0 * delta)
		if wind_energy <= 0.0:
			boosting = false
			_boost_ready = false


func _update_speed(delta: float, tangent: Vector3, grounded: bool) -> void:
	var target := cruise_speed
	var acceleration := 6.0
	if grounded:
		target = minf(downhill_speed, cruise_speed + maxf(0.0, -tangent.y) * 40.0)
	if boosting:
		target = boost_speed
		acceleration = 14.0
	if _brake_ready and Input.is_action_pressed("brake"):
		target = brake_speed
		acceleration = 18.0
	speed = move_toward(speed, target, acceleration * delta)


func _update_distance_energy() -> void:
	var new_distance := maxf(0.0, progress - max_progress)
	max_progress = maxf(max_progress, progress)
	if _spent_boost_this_tick:
		return
	_recovery_distance += new_distance
	if _recovery_distance >= 6.0:
		var units := floorf(_recovery_distance / 6.0)
		_recovery_distance -= units * 6.0
		grant_energy(units)


func _update_landing(delta: float, was_grounded: bool) -> void:
	if not is_on_floor():
		_air_time += delta
		return
	if not was_grounded and not _suppress_landing and _air_time >= 0.10:
		landed.emit()
	_air_time = 0.0
	_suppress_landing = false


func _update_visual(delta: float, tangent: Vector3, steer: float) -> void:
	var heading := atan2(-tangent.x, -tangent.z) - _lateral_speed * 0.018
	_visual.rotation.y = lerp_angle(_visual.rotation.y, heading, 1.0 - exp(-8.0 * delta))
	_visual.rotation.z = lerpf(_visual.rotation.z, -steer * 0.19, 1.0 - exp(-9.0 * delta))
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
