extends Node

@export var model: Node3D
@export var rider: CharacterBody3D
@export var reduced_motion: bool = false

var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _global_rest: Dictionary = {}
var _up: Vector3
var _across: Vector3
var _forward: Vector3
var _leg_length: float = 1.0
var _elapsed: float = 0.0
var _steer: float = 0.0
var _boost: float = 0.0
var _air: float = 0.0
var _gaze_weight: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(model) and is_instance_valid(rider):
		setup(model, rider)


func setup(character_model: Node3D, character_rider: CharacterBody3D) -> bool:
	model = character_model
	rider = character_rider
	_skeleton = _find_skeleton(model)
	if not is_instance_valid(_skeleton):
		push_warning("Rider pose: character has no Skeleton3D")
		return false
	_bones.clear()
	_rest.clear()
	_global_rest.clear()
	for i in _skeleton.get_bone_count():
		var key := _skeleton.get_bone_name(i).to_lower().replace("mixamorig", "").replace(":", "").replace("_", "")
		_bones[key] = i
	var required: Array[String] = ["hips", "neck", "leftupleg", "leftleg", "leftfoot",
		"rightupleg", "rightleg", "rightfoot", "leftarm", "leftforearm", "lefthand",
		"rightarm", "rightforearm", "righthand"]
	for key in required:
		if not _bones.has(key):
			push_warning("Rider pose: missing bone " + key)
			_skeleton = null
			return false
		var id: int = _bones[key]
		_rest[id] = _skeleton.get_bone_rest(id)
		_global_rest[key] = _skeleton.get_bone_global_rest(id)
	_up = (_rest_position("neck") - _rest_position("hips")).normalized()
	_across = (_rest_position("rightupleg") - _rest_position("leftupleg")).normalized()
	_across = (_across - _up * _across.dot(_up)).normalized()
	var toe_direction := Vector3.ZERO
	for side in ["left", "right"]:
		var toe_key: String = side + "toebase"
		if _bones.has(toe_key):
			var toe: Transform3D = _skeleton.get_bone_global_rest(_bones[toe_key])
			toe_direction += toe.origin - _rest_position(side + "foot")
	_forward = toe_direction - _up * toe_direction.dot(_up)
	_forward -= _across * _forward.dot(_across)
	if _forward.length_squared() < 0.00001:
		push_warning("Rider pose: cannot derive facing direction from toe bones")
		_skeleton = null
		return false
	_forward = _forward.normalized()
	_leg_length = _rest_position("leftupleg").distance_to(_rest_position("leftleg"))
	_leg_length += _rest_position("leftleg").distance_to(_rest_position("leftfoot"))
	_elapsed = 0.0
	_steer = 0.0
	_boost = 0.0
	_air = 0.0
	_gaze_weight = 0.0
	_apply_pose()
	return true


func _process(delta: float) -> void:
	if not is_instance_valid(_skeleton) or not is_instance_valid(rider):
		return
	if not reduced_motion:
		_elapsed += delta
	var visual := rider.get_node_or_null("Visual") as Node3D
	var target_steer := clampf(-visual.rotation.z / 0.19, -1.0, 1.0) if visual else 0.0
	var target_boost := 1.0 if rider.get("boosting") else 0.0
	var active: bool = rider.get("_active") == true
	var target_air := 1.0 if active and not rider.is_on_floor() and absf(rider.velocity.y) > 0.5 else 0.0
	var response := 1.0 - exp(-8.0 * delta)
	_steer = lerpf(_steer, target_steer, response)
	_boost = lerpf(_boost, target_boost, response)
	_air = lerpf(_air, target_air, response)
	_gaze_weight = lerpf(_gaze_weight, 1.0 if active else 0.0, response)
	_apply_pose()


func _apply_pose() -> void:
	# All targets are in the imported skeleton's coordinates, derived from its rest pose.
	# No bone's local X/Y/Z axis is assumed to be an anatomical hinge.
	for id in _rest:
		_skeleton.set_bone_pose(id, _rest[id])
	var sway := 0.0 if reduced_motion else sin(_elapsed * 1.7) * 0.006
	var crouch := (0.17 + _boost * 0.08 + _air * 0.045) * _leg_length
	var hips_origin := _rest_position("hips") - _up * crouch
	hips_origin += _forward * (0.025 + _boost * 0.025) * _leg_length
	hips_origin += _across * (sway + _steer * 0.018) * _leg_length
	_set_global_origin(_bones["hips"], hips_origin)
	var lean_direction := (_up + _forward * (0.10 + _boost * 0.12)).normalized()
	var hips_rest: Transform3D = _global_rest["hips"]
	_set_global_basis(_bones["hips"], Basis(Quaternion(_up, lean_direction)) * hips_rest.basis)
	# The body is sideways on the board; turn the gaze towards the leading foot.
	var travel_gaze := (_forward * 0.77 - _across * 0.64).normalized()
	var gaze := _forward.slerp(travel_gaze, _gaze_weight).normalized()
	var neck_pose := _skeleton.get_bone_global_pose(_bones["neck"])
	_set_global_basis(_bones["neck"], Basis(Quaternion(_forward, gaze)) * neck_pose.basis)
	for side in ["left", "right"]:
		_solve_limb(side + "upleg", side + "leg", side + "foot",
			_rest_position(side + "foot"), _forward)
		var foot_rest: Transform3D = _global_rest[side + "foot"]
		_set_global_basis(_bones[side + "foot"], foot_rest.basis)
	for side in ["left", "right"]:
		var sign_side := -1.0 if side == "left" else 1.0
		var shoulder := _pose_position(side + "arm")
		var leading: bool = side == "left"
		var reach := _across * sign_side * ((0.40 if leading else 0.25) - _boost * 0.045)
		reach += _up * ((-0.19 if leading else -0.36) + _air * 0.055)
		reach += _forward * ((0.19 if leading else -0.10) + _boost * 0.06 + sign_side * _steer * 0.035)
		var elbow_pole := _forward * 0.80 - _up * 0.15 + _across * sign_side * 0.15
		_solve_limb(side + "arm", side + "forearm", side + "hand",
			shoulder + reach * _leg_length, elbow_pole)


func _solve_limb(root_key: String, middle_key: String, end_key: String,
		target: Vector3, pole: Vector3) -> void:
	var origin := _pose_position(root_key)
	var upper_length := _rest_position(root_key).distance_to(_rest_position(middle_key))
	var lower_length := _rest_position(middle_key).distance_to(_rest_position(end_key))
	var direction := target - origin
	var distance := clampf(direction.length(), absf(upper_length - lower_length) + 0.0001,
		upper_length + lower_length - 0.0001)
	direction = direction.normalized()
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.00001:
		return
	bend = bend.normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var joint := origin + direction * along + bend * height
	_aim_bone(_bones[root_key], _bones[middle_key], joint)
	_aim_bone(_bones[middle_key], _bones[end_key], origin + direction * distance)


func _aim_bone(id: int, child_id: int, target: Vector3) -> void:
	var transform := _skeleton.get_bone_global_pose(id)
	var current := _skeleton.get_bone_global_pose(child_id).origin - transform.origin
	var desired := target - transform.origin
	if current.length_squared() < 0.000001 or desired.length_squared() < 0.000001:
		return
	_set_global_basis(id, Basis(Quaternion(current.normalized(), desired.normalized())) * transform.basis)


func _set_global_basis(id: int, basis: Basis) -> void:
	var parent := _skeleton.get_bone_parent(id)
	var local_basis := basis
	if parent >= 0:
		local_basis = _skeleton.get_bone_global_pose(parent).basis.inverse() * basis
	_skeleton.set_bone_pose_rotation(id, local_basis.orthonormalized().get_rotation_quaternion())


func _set_global_origin(id: int, origin: Vector3) -> void:
	var parent := _skeleton.get_bone_parent(id)
	var local_origin := origin
	if parent >= 0:
		local_origin = _skeleton.get_bone_global_pose(parent).affine_inverse() * origin
	_skeleton.set_bone_pose_position(id, local_origin)


func _rest_position(key: String) -> Vector3:
	var transform: Transform3D = _global_rest[key]
	return transform.origin


func _pose_position(key: String) -> Vector3:
	return _skeleton.get_bone_global_pose(_bones[key]).origin


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null
