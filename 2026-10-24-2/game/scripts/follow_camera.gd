extends Camera3D

@export var rider: CharacterBody3D
@export var course: Node3D
@export var reduced_motion: bool = false
var title_view := false
@export_group("Framing")
@export var follow_distance: float = 5.5
@export var follow_height: float = 2.8
@export var look_ahead: float = 17.0
@export var position_response: float = 7.0
@export var look_response: float = 6.0

var _look_target: Vector3 = Vector3.ZERO
var _previous_rider_position: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Read the rider's interpolated transform once per rendered frame.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 48.0 if title_view else 64.0
	reset_camera()


func reset_camera() -> void:
	if not is_instance_valid(rider) or not is_instance_valid(course):
		_initialized = false
		return
	var framing := _framing(rider.global_position)
	global_position = framing[0]
	_look_target = framing[1]
	look_at(_look_target, Vector3.UP)
	rotation.z = 0.0
	fov = 48.0 if title_view else 64.0
	_previous_rider_position = rider.global_position
	_initialized = true
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if not is_instance_valid(rider) or not is_instance_valid(course):
		return
	if title_view:
		reset_camera()
		return
	if not _initialized or rider.global_position.distance_to(_previous_rider_position) > 20.0:
		reset_camera()
	_previous_rider_position = rider.global_position
	var rider_position := rider.get_global_transform_interpolated().origin
	var framing := _framing(rider_position)
	global_position = global_position.lerp(framing[0], 1.0 - exp(-position_response * delta))
	_look_target = _look_target.lerp(framing[1], 1.0 - exp(-look_response * delta))
	look_at(_look_target, Vector3.UP)
	rotation.z = 0.0
	var target_fov := 70.0 if rider.get("boosting") and not reduced_motion else 64.0
	fov = 64.0 if reduced_motion else lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta))


func _framing(rider_position: Vector3) -> Array[Vector3]:
	if title_view:
		var offset := Vector3(2.7, 1.7, 2.6)
		var camera_right := Vector3(-offset.x, 0.0, -offset.z).normalized().cross(Vector3.UP)
		return [rider_position + offset, rider_position + Vector3.UP - camera_right * 1.2]
	var s := maxf(0.0, -rider_position.z)
	var center: Vector3 = course.call("center_at", s)
	var tangent: Vector3 = course.call("tangent_at", s + 5.0)
	var forward := Vector3(tangent.x, 0.0, tangent.z).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var offset := (rider_position - center).dot(right)
	var position_target := rider_position - forward * follow_distance
	var jump_height := maxf(0.0, rider_position.y - center.y)
	position_target.y = center.y + follow_height + jump_height * (0.15 if reduced_motion else 0.35)
	var target: Vector3 = course.call("center_at", s + look_ahead)
	target += right * offset * 0.45
	target.y += 1.0
	return [position_target, target]
