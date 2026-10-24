extends Node

const MotionKeys = preload("res://animations/rider_motion_keys.gd")

@export var model: Node3D
@export var rider: CharacterBody3D
@export var reduced_motion: bool = false
@export_range(0.15, 0.36) var riding_crouch: float = 0.27
@export_range(0.0, 1.5) var motion_weight: float = 1.0

var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _global_rest: Dictionary = {}
var _up: Vector3
var _across: Vector3
var _forward: Vector3
var _travel: Vector3
var _edge_right: Vector3
var _stance_weight: float = 0.0
var _leg_length: float = 1.0
var _elapsed: float = 0.0
var _steer: float = 0.0
var _shoulder_steer: float = 0.0
var _arm_steer: float = 0.0
var _boost: float = 0.0
var _air: float = 0.0
var _gaze_weight: float = 0.0
var _carve: float = 0.0
var _context: StringName = &"idle"
var _events: Dictionary = {}
var _last_foot_error: float = 0.0
var _channels: Array[float] = []
var _has_semantic_context: bool = false


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
		_rest[i] = _skeleton.get_bone_rest(i)
		_global_rest[key] = _skeleton.get_bone_global_rest(i)
	var required: Array[String] = ["hips", "neck", "leftupleg", "leftleg", "leftfoot",
		"rightupleg", "rightleg", "rightfoot", "leftarm", "leftforearm", "lefthand",
		"rightarm", "rightforearm", "righthand"]
	for key in required:
		if not _bones.has(key):
			push_warning("Rider pose: missing bone " + key)
			_skeleton = null
			return false
	_up = (_rest_position("neck") - _rest_position("hips")).normalized()
	_across = (_rest_position("rightupleg") - _rest_position("leftupleg")).normalized()
	_across = (_across - _up * _across.dot(_up)).normalized()
	var toe_direction := Vector3.ZERO
	for side in ["left", "right"]:
		var toe_key: String = side + "toebase"
		if _bones.has(toe_key):
			toe_direction += _rest_position(toe_key) - _rest_position(side + "foot")
	_forward = toe_direction - _up * toe_direction.dot(_up)
	_forward -= _across * _forward.dot(_across)
	if _forward.length_squared() < 0.00001:
		push_warning("Rider pose: cannot derive facing direction from toe bones")
		_skeleton = null
		return false
	_forward = _forward.normalized()
	_leg_length = _rest_position("leftupleg").distance_to(_rest_position("leftleg"))
	_leg_length += _rest_position("leftleg").distance_to(_rest_position("leftfoot"))
	reset_motion()
	return true


func set_motion_context(state: StringName) -> void:
	_has_semantic_context = true
	if _context == state:
		return
	_context = state
	if state == &"idle" or state == &"recovery":
		reset_motion()
		_context = state
	elif state == &"finish":
		trigger_motion(&"finish")


func trigger_motion(event: StringName, strength: float = 1.0) -> void:
	if event == &"recovery":
		reset_motion()
		_context = &"recovery"
		return
	if event == &"finish" and _events.has(&"finish"):
		return
	if event == &"jump":
		_events.erase(&"land")
	elif event == &"land":
		_events.erase(&"jump")
	if MotionKeys.duration(event) > 0.0:
		_events[event] = {"time": 0.0, "strength": clampf(strength, 0.25, 1.35)}


func reset_motion() -> void:
	_elapsed = 0.0
	_steer = 0.0
	_shoulder_steer = 0.0
	_arm_steer = 0.0
	_boost = 0.0
	_air = 0.0
	_carve = 0.0
	_gaze_weight = 0.0
	_stance_weight = 0.0
	_events.clear()
	_context = &"idle"
	if is_instance_valid(_skeleton):
		_apply_pose()


func _process(delta: float) -> void:
	if not is_instance_valid(_skeleton) or not is_instance_valid(rider):
		return
	advance_motion(delta)


# Also used by the deterministic motion preview; pause stops this Node's _process.
func advance_motion(delta: float) -> void:
	if not is_instance_valid(_skeleton):
		return
	_elapsed += delta
	for event in _events.keys():
		_events[event]["time"] += delta
		if float(_events[event]["time"]) > MotionKeys.duration(event) and event != &"finish":
			_events.erase(event)
	var active: bool = rider.get("_active") == true
	if not _has_semantic_context:
		_context = &"running" if active else &"idle"
	var visual := rider.get_node_or_null("Visual") as Node3D
	var steer_value: Variant = rider.get("steer_amount")
	var target_steer := clampf(float(steer_value), -1, 1) if steer_value != null else (clampf(-visual.rotation.z / 0.19, -1, 1) if visual else 0.0)
	var carve_value: Variant = rider.get("carve_charge")
	var target_carve := float(carve_value) if rider.get("carving") == true and carve_value != null else 0.0
	var target_boost := 1.0 if rider.get("boosting") else 0.0
	var target_air := 1.0 if active and not rider.is_on_floor() and absf(rider.velocity.y) > 0.5 else 0.0
	# Eyes and shoulders anticipate. The pelvis follows; hands finish the turn.
	_shoulder_steer = lerpf(_shoulder_steer, target_steer, 1.0 - exp(-16.0 * delta))
	_steer = lerpf(_steer, target_steer, 1.0 - exp(-7.0 * delta))
	_arm_steer = lerpf(_arm_steer, _steer, 1.0 - exp(-5.0 * delta))
	_carve = lerpf(_carve, target_carve, 1.0 - exp(-10.0 * delta))
	_boost = lerpf(_boost, target_boost, 1.0 - exp(-7.0 * delta))
	_air = lerpf(_air, target_air, 1.0 - exp(-12.0 * delta))
	_gaze_weight = lerpf(_gaze_weight, 1.0 if _context == &"running" else 0.0, 1.0 - exp(-8.0 * delta))
	var stance_target := 1.0 if _context == &"running" else (0.65 if _context == &"countdown" else 0.0)
	_stance_weight = lerpf(_stance_weight, stance_target, 1.0 - exp(-6.0 * delta))
	_apply_pose()


func _apply_pose() -> void:
	# Every joint is restored before composition. No animation accumulates drift.
	for id in _rest:
		_skeleton.set_bone_pose(id, _rest[id])
	_channels = MotionKeys.sample(&"idle", fmod(_elapsed, 7.0))
	var idle_weight := 0.0 if reduced_motion else (1.0 if _context in [&"idle", &"countdown", &"finish"] else 0.26)
	for index in 9:
		_channels[index] *= idle_weight
	for event in _events:
		var values: Array[float] = MotionKeys.sample(event, _events[event]["time"])
		var weight: float = _events[event]["strength"] * motion_weight * (0.4 if reduced_motion else 1.0)
		for index in 9:
			_channels[index] += values[index] * weight
	# Physics heading is the board's travel axis. Body forward is perpendicular to it
	# in the sideways surf stance; anatomical knee poles still use body forward.
	_update_board_axes()
	var idle := 1.0 - _stance_weight
	var crouch := clampf(lerpf(0.028, riding_crouch, _stance_weight) + _boost * 0.085 + _carve * 0.12 + _air * 0.07 + _channels[0], 0.012, 0.58)
	var hips_origin := _rest_position("hips") - _up * crouch * _leg_length
	hips_origin += _forward * (0.008 + _stance_weight * 0.035) * _leg_length
	hips_origin += _travel * (_boost * 0.055 + _channels[1]) * _leg_length
	# Standing weight rests above the leading boot; carve weight crosses the edge.
	hips_origin += _across * (-0.045 * idle) * _leg_length
	hips_origin += _edge_right * (_steer * (0.07 + _carve * 0.055)) * _leg_length
	_set_global_origin(_bones["hips"], hips_origin)
	var forward_lean := 0.02 + _stance_weight * 0.10
	var travel_lean := _boost * 0.22 + _channels[2]
	var lean_direction := (_up + _forward * forward_lean + _travel * travel_lean + _edge_right * _steer * (0.12 + _carve * 0.13)).normalized()
	var hips_rest: Transform3D = _global_rest["hips"]
	_set_global_basis(_bones["hips"], Basis(Quaternion(_up, lean_direction)) * hips_rest.basis)
	# Split the twist through the spine instead of making the body a rigid plank.
	var facing_turn := signf(_forward.cross(_travel).dot(_up))
	var twist := facing_turn * _stance_weight * 0.18 - _shoulder_steer * 0.24 + _channels[3]
	for key in ["spine", "spine1", "spine2"]:
		if _bones.has(key):
			var spine_pose := _skeleton.get_bone_global_pose(_bones[key])
			_set_global_basis(_bones[key], Basis(_up, twist / 3.0) * spine_pose.basis)
	var travel_gaze := (_forward * 0.45 + _travel * 0.89).normalized()
	var gaze := _forward.slerp(travel_gaze, _gaze_weight).normalized()
	gaze = Basis(_up, -_shoulder_steer * 0.30 + _channels[3]) * gaze
	gaze = (gaze + _up * (-_channels[7] - _air * 0.09)).normalized()
	var neck_pose := _skeleton.get_bone_global_pose(_bones["neck"])
	var neck_rest: Transform3D = _global_rest["neck"]
	var current_facing := (neck_pose.basis * neck_rest.basis.inverse() * _forward).normalized()
	_set_global_basis(_bones["neck"], Basis(Quaternion(current_facing, gaze)) * neck_pose.basis)
	for side in ["left", "right"]:
		_solve_limb(side + "upleg", side + "leg", side + "foot", _rest_position(side + "foot"), _forward)
		var foot_rest: Transform3D = _global_rest[side + "foot"]
		_set_global_basis(_bones[side + "foot"], foot_rest.basis)
	var finish_hand := 0.0
	if _events.has(&"finish"):
		var finish_time: float = _events[&"finish"]["time"]
		finish_hand = smoothstep(0.35, 0.72, finish_time) * (1.0 - smoothstep(1.05, 1.65, finish_time))
	for side in ["left", "right"]:
		var sign_side := -1.0 if side == "left" else 1.0
		var shoulder := _pose_position(side + "arm")
		var leading: bool = side == "left"
		var spread := (0.31 if leading else 0.23) - _boost * 0.065 - _air * 0.11 + _channels[4]
		spread += absf(_arm_steer) * (0.045 if sign_side * _arm_steer > 0 else -0.02)
		var lift := (-0.27 if leading else -0.39) + _channels[5] - _air * 0.07
		var reach_forward := (0.22 if leading else -0.05) + _boost * 0.03 + _channels[6]
		reach_forward += sign_side * _arm_steer * 0.14
		var reach := _across * sign_side * maxf(0.10, spread) + _up * lift + _forward * reach_forward
		var standing_reach := _across * sign_side * (0.075 if leading else 0.06) - _up * (0.54 if leading else 0.56) + _forward * 0.035
		standing_reach += _forward * _channels[8] * 0.045 + _up * _channels[5] * 0.4
		reach = standing_reach.lerp(reach, _stance_weight)
		# Air pose draws the trailing hand towards the bent knee, a compact grab silhouette.
		if not leading:
			reach = reach.lerp(_across * 0.13 - _up * 0.48 + _forward * 0.20, _air * 0.62)
		if leading:
			reach = reach.lerp(-_across * 0.16 + _up * 0.04 + _forward * 0.29, finish_hand)
		var elbow_pole := _forward * 0.80 - _up * 0.12 + _across * sign_side * 0.22
		_solve_limb(side + "arm", side + "forearm", side + "hand", shoulder + reach * _leg_length, elbow_pole)
		_curl_fingers(side, clampf(0.12 + _boost * 0.3 + _air * 0.3 + _channels[8] + finish_hand * 0.35, 0, 0.85))
	_last_foot_error = maxf(_pose_position("leftfoot").distance_to(_rest_position("leftfoot")), _pose_position("rightfoot").distance_to(_rest_position("rightfoot"))) / _leg_length


func _update_board_axes() -> void:
	var heading_value: Variant = rider.get("heading")
	var world_travel := Vector3(-sin(float(heading_value)), 0, -cos(float(heading_value))) if heading_value != null else Vector3.FORWARD
	_travel = _skeleton.global_basis.inverse() * world_travel
	_travel = (_travel - _up * _travel.dot(_up)).normalized()
	_edge_right = _travel.cross(_up).normalized()


func _curl_fingers(side: String, amount: float) -> void:
	# The rest-to-child direction defines each hinge; imported local axes may differ.
	for finger in ["index", "middle", "ring", "pinky"]:
		for joint in range(1, 4):
			var key: String = side + "hand" + finger + str(joint)
			var next_key: String = side + "hand" + finger + str(joint + 1)
			if not _bones.has(key) or not _bones.has(next_key):
				continue
			var direction := (_pose_position(next_key) - _pose_position(key)).normalized()
			var hand_pose := _skeleton.get_bone_global_pose(_bones[side + "hand"])
			var hand_rest: Transform3D = _global_rest[side + "hand"]
			var palm_down := (hand_pose.basis * hand_rest.basis.inverse() * -_up).normalized()
			var curl_axis := direction.cross(palm_down).normalized()
			if curl_axis.length_squared() > 0.01:
				var pose := _skeleton.get_bone_global_pose(_bones[key])
				_set_global_basis(_bones[key], Basis(curl_axis, amount * 0.65) * pose.basis)


func motion_snapshot() -> Dictionary:
	return {"context": String(_context), "events": _events.duplicate(true), "time": _elapsed,
		"steer": _steer, "shoulder_steer": _shoulder_steer, "arm_steer": _arm_steer,
		"stance_weight": _stance_weight, "travel_world": _skeleton.global_basis * _travel, "edge_right_world": _skeleton.global_basis * _edge_right,
		"carve": _carve, "foot_error_leg_ratio": _last_foot_error, "channels": _channels.duplicate(),
		"bone_count": _skeleton.get_bone_count() if is_instance_valid(_skeleton) else 0}


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
