extends Node3D

var camera: Camera3D
var player: CharacterBody3D
var yaw: float = 0.0
var pitch: float = -0.20
var sensitivity: float = 0.0023
var invert_y: bool = false
var locked_target: Node3D
var _mouse_motion := Vector2.ZERO
var _distance: float = 6.5
var _shape := SphereShape3D.new()

func _ready() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.near = 0.12
	camera.fov = 68.0
	add_child(camera)
	camera.current = true
	_shape.radius = 0.24

func add_mouse_motion(motion: Vector2) -> void:
	_mouse_motion += motion

func clear_input() -> void:
	_mouse_motion = Vector2.ZERO

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if player.get("active"):
		yaw -= _mouse_motion.x * sensitivity
		pitch = clampf(pitch - _mouse_motion.y * sensitivity * (-1.0 if invert_y else 1.0), -1.12, 0.72)
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.18:
			stick = stick.normalized() * inverse_lerp(0.18, 1.0, minf(stick.length(), 1.0))
			yaw -= stick.x * 2.3 * delta
			pitch = clampf(pitch - stick.y * 1.7 * delta * (-1.0 if invert_y else 1.0), -1.12, 0.72)
	_mouse_motion = Vector2.ZERO
	var focus := player.global_position + Vector3.UP * 1.3
	if is_instance_valid(locked_target):
		var offset: Vector3 = locked_target.global_position + Vector3.UP * 0.6 - focus
		if offset.length() > 0.5:
			yaw = lerp_angle(yaw, atan2(-offset.x, -offset.z), 1.0 - exp(-5.0 * delta))
	var view_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var backwards := view_basis.z
	var desired := focus + backwards * 6.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, focus)
	query.motion = desired - focus
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	var available: float = maxf(0.30, 6.5 * result[0] - 0.12)
	_distance = available if available < _distance else move_toward(_distance, available, delta * 8.0)
	global_position = focus
	camera.global_position = focus + backwards * _distance
	camera.look_at(focus, Vector3.UP)
