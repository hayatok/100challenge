extends CharacterBody3D

signal damaged
signal died
signal action_performed(action: String)
signal enemy_defeated
const CameraRig = preload("res://scripts/camera_rig.gd")
const RUN_SPEED := 7.5
const GRAVITY := 25.0
var health: int = 100
var air_dashes: int = 2
var active: bool = false
var current_target: Node3D
var camera: Camera3D
var state_name: String = "idle"
var combo: int = 0
var total_kills: int = 0
var _rig: Node3D
var _visual: Node3D
var _animation: AnimationPlayer
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _attack_buffer: float = 0.0
var _action_time: float = 0.0
var _action_length: float = 0.0
var _invulnerable: float = 0.0
var _dash_cooldown: float = 0.0
var _combo_window: float = 0.0
var _hit_applied: bool = false
var _was_grounded: bool = false
var _air_combo: int = 0
var _dash_direction := Vector3.FORWARD
var _wire_target: Node3D
var _wire_history: Dictionary = {}
var _locked: Node3D
var _blocked_until_release: bool = false
var _safe_position := Vector3(0.0, 0.15, 7.0)
var _wire_mesh: MeshInstance3D
var _wire_material := StandardMaterial3D.new()
var _wire_geometry := ImmediateMesh.new()
var _target_cycle: int = 0
var _wire_request_pending: bool = false
var _wire_input_target: Node3D
var _wire_was_pressed: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(48.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	_visual = Node3D.new()
	add_child(_visual)
	if ResourceLoader.exists("res://assets/models/hero.glb"):
		var model := (load("res://assets/models/hero.glb") as PackedScene).instantiate()
		_visual.add_child(model)
		_animation = _find_animation(model)
		if _animation:
			for clip in ["idle", "run", "slide", "fall"]:
				if _animation.has_animation(clip):
					_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_rig = CameraRig.new()
	_rig.player = self
	add_child(_rig)
	camera = _rig.camera
	_wire_mesh = MeshInstance3D.new()
	_wire_mesh.top_level = true
	add_child(_wire_mesh)
	_wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wire_material.albedo_color = Color("f9d783")
	_wire_mesh.material_override = _wire_material
	_wire_mesh.mesh = _wire_geometry
	_safe_position = global_position

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation(child)
		if found:
			return found
	return null

func play_animation(clip: String) -> void:
	if not _animation or not _animation.has_animation(clip):
		return
	var attacking := clip.begins_with("slash_") or clip == "launch"
	_animation.speed_scale = _animation.get_animation(clip).length / _action_length if attacking and _action_length > 0.0 else 1.0
	if _animation.current_animation != clip:
		_animation.play(clip, 0.035 if attacking else 0.08)

func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("wire") and not event.is_echo():
		_wire_request_pending = true
		_wire_input_target = current_target
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rig.add_mouse_motion(event.relative)
	if active and event is InputEventMouseButton and event.pressed and is_instance_valid(_locked):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_cycle -= 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_cycle += 1

func apply_settings(settings: Dictionary) -> void:
	_rig.sensitivity = float(settings.get("sensitivity", 1.0)) * 0.0023
	_rig.invert_y = bool(settings.get("invert_y", false))

func set_active(value: bool) -> void:
	active = value
	if not value:
		clear_input()

func clear_input() -> void:
	# Pause discards input intent while preserving the suspended physical action.
	_jump_buffer = 0.0
	_attack_buffer = 0.0
	_target_cycle = 0
	_wire_request_pending = false
	_wire_input_target = null
	_wire_was_pressed = Input.is_action_pressed("wire")
	_blocked_until_release = true
	if _rig:
		_rig.clear_input()

func reset_at(pos: Vector3) -> void:
	global_position = pos
	_safe_position = pos
	health = 100
	air_dashes = 2
	total_kills = 0
	_invulnerable = 0.0
	_dash_cooldown = 0.0
	_wire_history.clear()
	_locked = null
	current_target = null
	_wire_target = null
	_action_time = 0.0
	_action_length = 0.0
	_combo_window = 0.0
	_coyote = 0.0
	combo = 0
	_air_combo = 0
	_hit_applied = false
	_was_grounded = false
	state_name = "idle"
	velocity = Vector3.ZERO
	if _rig:
		_rig.locked_target = null
	if _wire_mesh:
		_wire_mesh.visible = false
	if _animation:
		_animation.stop()
	clear_input()
	reset_physics_interpolation()

func take_damage(amount: int, origin: Vector3) -> void:
	if not active or health <= 0 or _invulnerable > 0.0:
		return
	health = maxi(0, health - amount)
	_invulnerable = 0.8
	_wire_target = null
	state_name = "hurt"
	_action_time = 0.25
	velocity = (global_position - origin).normalized() * 5.0 + Vector3.UP * 3.0
	play_animation("hurt")
	damaged.emit()
	if health == 0:
		active = false
		state_name = "dead"
		play_animation("death")
		died.emit()

func _movement_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (_rig.right() * input.x - _rig.forward() * input.y).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if not active:
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_combo_window = maxf(0.0, _combo_window - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	var grounded := is_on_floor()
	if grounded:
		_coyote = 0.10
		air_dashes = 2
		_wire_history.clear()
		_air_combo = 0
		if not _was_grounded:
			action_performed.emit("land")
			if state_name == "plunge":
				_strike(42, false, 3.6, true)
				_action_time = 0.20
				state_name = "landing"
		if velocity.length() < 10.0:
			_safe_position = global_position
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_was_grounded = grounded
	# Input binds to the reticle shown before this physics tick, even if it just became invalid.
	var wire_pressed := Input.is_action_pressed("wire")
	var wire_requested := _wire_request_pending or (wire_pressed and not _wire_was_pressed)
	var wire_snapshot: Node3D = _wire_input_target if _wire_request_pending else current_target
	_wire_request_pending = false
	_wire_input_target = null
	_wire_was_pressed = wire_pressed
	_update_target()
	if _target_cycle != 0:
		_cycle_locked_target(_target_cycle)
		_target_cycle = 0
	var direction := _movement_direction()
	if _blocked_until_release:
		_blocked_until_release = Input.is_action_pressed("attack") or Input.is_action_pressed("heavy") or Input.is_action_pressed("wire") or Input.is_action_pressed("dash") or Input.is_action_pressed("jump")
	else:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = 0.13
		if Input.is_action_just_pressed("attack"):
			_attack_buffer = 0.14
		if Input.is_action_just_pressed("lock"):
			_locked = null if is_instance_valid(_locked) else current_target
		if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and (grounded or air_dashes > 0):
			_start_dash(direction, grounded)
		elif wire_requested and _can_cancel():
			_start_wire(wire_snapshot)
		elif Input.is_action_just_pressed("heavy") and _can_cancel():
			_start_attack(true)
	if _jump_buffer > 0.0 and _coyote > 0.0 and state_name not in ["wire", "plunge", "hurt"]:
		velocity.y = 10.5
		_jump_buffer = 0.0
		_coyote = 0.0
		_action_time = 0.0
		state_name = "jump"
		action_performed.emit("jump")
	if _attack_buffer > 0.0 and _can_cancel() and (_air_combo < 3 or grounded):
		_start_attack(false)
	_action_time = maxf(0.0, _action_time - delta)
	match state_name:
		"wire":
			_step_wire(delta)
		"dash":
			velocity = _dash_direction * 23.0
			if not grounded:
				velocity.y = 0.7
			if _action_time <= 0.0:
				state_name = "slide" if grounded and Input.is_action_pressed("dash") else "idle"
				if state_name == "slide":
					action_performed.emit("slide")
		"slide":
			_dash_direction = _dash_direction.lerp(direction, delta * 2.5).normalized() if direction.length() > 0.1 else _dash_direction
			velocity.x = _dash_direction.x * 12.0
			velocity.z = _dash_direction.z * 12.0
			velocity.y -= GRAVITY * delta
			if _blocked_until_release or not Input.is_action_pressed("dash") or not grounded:
				state_name = "idle"
		"slash", "launch":
			_step_attack(delta)
		"plunge":
			velocity.y = -28.0
			velocity.x = move_toward(velocity.x, direction.x * 4.0, delta * 12.0)
			velocity.z = move_toward(velocity.z, direction.z * 4.0, delta * 12.0)
		"hurt", "landing":
			velocity.y -= GRAVITY * delta
			velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
			if _action_time <= 0.0:
				state_name = "idle"
		_:
			velocity.x = move_toward(velocity.x, direction.x * RUN_SPEED, delta * (45.0 if grounded else 20.0))
			velocity.z = move_toward(velocity.z, direction.z * RUN_SPEED, delta * (45.0 if grounded else 20.0))
			velocity.y = -0.5 if grounded and velocity.y <= 0.0 else maxf(-30.0, velocity.y - GRAVITY * delta)
			state_name = "run" if grounded and direction.length() > 0.1 else ("idle" if grounded else ("jump" if velocity.y > 0.0 else "fall"))
	if direction.length() > 0.1 and state_name not in ["wire", "slash", "launch", "hurt"]:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-18.0 * delta))
	move_and_slide()
	if state_name == "wire" and is_on_wall():
		_end_wire()
	if global_position.y < -17.0:
		global_position = _safe_position + Vector3.UP * 0.25
		velocity = Vector3.ZERO
		_wire_history.clear()
		_wire_target = null
		state_name = "idle"
		take_damage(10, global_position - Vector3.UP)
		reset_physics_interpolation()
	play_animation("slash_%d" % combo if state_name == "slash" else state_name)
	_draw_wire()

func _can_cancel() -> bool:
	return state_name not in ["hurt", "landing", "plunge"] and (state_name not in ["slash", "launch"] or _action_time < _action_length * 0.40)

func _start_dash(direction: Vector3, grounded: bool) -> void:
	if not grounded:
		air_dashes -= 1
	_dash_direction = direction.normalized() if direction.length() > 0.1 else -_visual.global_basis.z
	_dash_direction.y = 0.0
	state_name = "dash"
	_action_time = 0.16
	_dash_cooldown = 0.23
	_invulnerable = maxf(_invulnerable, 0.13)
	_wire_target = null
	action_performed.emit("dash")

func _start_attack(heavy: bool) -> void:
	_attack_buffer = 0.0
	_wire_target = null
	_hit_applied = false
	if heavy:
		state_name = "launch" if is_on_floor() else "plunge"
		_action_length = 0.48
	else:
		combo = combo % 3 + 1 if _combo_window > 0.0 else 1
		if not is_on_floor():
			_air_combo += 1
		state_name = "slash"
		_action_length = 0.34 if combo < 3 else 0.48
		_combo_window = 0.72
	_action_time = _action_length
	if is_instance_valid(current_target):
		var aim := current_target.global_position - global_position
		aim.y = 0.0
		if aim.length() < 4.0 and aim.length() > 0.1:
			_visual.rotation.y = atan2(-aim.x, -aim.z)
	action_performed.emit("slash" if not heavy else state_name)
	# Restart identical one-shots when the same action follows a cancelled action.
	if _animation:
		_animation.stop()
	play_animation("slash_%d" % combo if state_name == "slash" else state_name)

func _step_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 25.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 25.0)
	velocity.y -= GRAVITY * delta * (0.25 if not is_on_floor() and _air_combo < 3 else 1.0)
	if not _hit_applied and _action_time <= _action_length * 0.50:
		_hit_applied = true
		_strike(26 if state_name == "slash" else 18, state_name == "launch", 2.8)
		if state_name == "launch":
			velocity.y = 9.5
		if not is_on_floor() and state_name == "slash" and _air_combo < 3:
			velocity.y = 2.5
	if _action_time <= 0.0:
		state_name = "idle"

func _strike(damage: int, launch: bool, reach: float, radial: bool = false) -> void:
	for candidate in get_tree().get_nodes_in_group("tether_targets"):
		if not candidate is Node3D or not candidate.has_method("receive_hit"):
			continue
		var offset: Vector3 = candidate.global_position - global_position
		if offset.length() > reach or absf(offset.y) > 2.6:
			continue
		var flat := Vector3(offset.x, 0.0, offset.z)
		if not radial and flat.length() > 0.3 and (-_visual.global_basis.z).dot(flat.normalized()) < 0.1:
			continue
		if not _line_clear(global_position + Vector3.UP, candidate.global_position + Vector3.UP * (0.8 if candidate.get_meta("kind", "") == "enemy" else 0.0)):
			continue
		var was_alive: bool = candidate.has_method("is_available") and candidate.call("is_available")
		var accepted: bool = candidate.call("receive_hit", damage, launch, global_position)
		if accepted:
			action_performed.emit("hit")
		if was_alive and candidate.get_meta("kind", "") == "enemy" and not candidate.call("is_available"):
			total_kills += 1
			air_dashes = mini(2, air_dashes + 1)
			enemy_defeated.emit()

func _line_clear(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _eligible(target: Node3D) -> bool:
	if not is_instance_valid(target) or (target.has_method("is_available") and not target.call("is_available")):
		return false
	var point := target.global_position
	if global_position.distance_to(point) > 18.0 or camera.is_position_behind(point):
		return false
	if not camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(point)):
		return false
	if not is_on_floor() and target.get_meta("kind", "") == "enemy" and _wire_history.has(target.get_instance_id()):
		return false
	return _line_clear(global_position + Vector3.UP * 1.0, point + Vector3.UP * 0.15) and _wire_path_clear(target)

func _arrival_point(target: Node3D) -> Vector3:
	var arrival := target.global_position
	if target.get_meta("kind", "") == "enemy":
		var away := global_position - arrival
		away.y = 0.0
		arrival += away.normalized() * 1.25 + Vector3.UP * 0.7
	else:
		arrival -= Vector3.UP * 1.15
	return arrival

func _wire_path_clear(target: Node3D) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.78
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.91)
	query.motion = _arrival_point(target) - global_position
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var sweep: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	return sweep[0] > 0.97

func _update_target() -> void:
	if is_instance_valid(_locked) and _eligible(_locked):
		current_target = _locked
	else:
		_locked = null
		current_target = null
		var best: float = INF
		var center := camera.get_viewport().get_visible_rect().size * 0.5
		for node in get_tree().get_nodes_in_group("tether_targets"):
			if node is Node3D and _eligible(node):
				var score: float = camera.unproject_position(node.global_position).distance_to(center) + global_position.distance_to(node.global_position) * 2.0
				if score < best:
					best = score
					current_target = node
	_rig.locked_target = _locked

func _cycle_locked_target(step: int) -> void:
	if not is_instance_valid(_locked):
		return
	var candidates: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("tether_targets"):
		if node is Node3D and _eligible(node):
			candidates.append(node)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return camera.unproject_position(a.global_position).x < camera.unproject_position(b.global_position).x)
	if candidates.is_empty():
		return
	var index := candidates.find(_locked)
	index = posmod(index + step, candidates.size())
	_locked = candidates[index]
	current_target = _locked
	_rig.locked_target = _locked
	# An in-flight wire keeps its original _wire_target snapshot.

func _start_wire(target: Node3D) -> void:
	if not is_instance_valid(target) or not _eligible(target):
		return
	_wire_target = target
	if _wire_target.get_meta("kind", "") == "enemy":
		_wire_history[_wire_target.get_instance_id()] = true
	state_name = "wire"
	_action_time = 1.2
	velocity = Vector3.ZERO
	action_performed.emit("wire")

func _step_wire(delta: float) -> void:
	if not is_instance_valid(_wire_target) or (_wire_target.has_method("is_available") and not _wire_target.call("is_available")) or _action_time <= 0.0:
		_end_wire()
		return
	var arrival := _arrival_point(_wire_target)
	var offset := arrival - global_position
	if offset.length() < 0.65:
		_end_wire()
		return
	# CharacterBody sweeps the complete capsule on every motion; never teleport through geometry.
	velocity = offset.normalized() * minf(24.0, offset.length() / delta)
	_visual.rotation.y = atan2(-offset.x, -offset.z)

func _end_wire() -> void:
	state_name = "fall"
	_wire_target = null
	velocity *= 0.25
	velocity.y = maxf(velocity.y, 3.0)

func _draw_wire() -> void:
	_wire_mesh.visible = state_name == "wire" and is_instance_valid(_wire_target)
	if not _wire_mesh.visible:
		return
	_wire_geometry.clear_surfaces()
	_wire_geometry.surface_begin(Mesh.PRIMITIVE_LINES, _wire_material)
	_wire_geometry.surface_add_vertex(global_position + Vector3.UP * 1.2)
	_wire_geometry.surface_add_vertex(_wire_target.global_position)
	_wire_geometry.surface_end()
	_wire_mesh.global_transform = Transform3D.IDENTITY
