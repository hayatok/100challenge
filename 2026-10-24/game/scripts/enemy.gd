extends CharacterBody3D

signal defeated(enemy)
var player: CharacterBody3D
var health: int = 90
var state_name: String = "idle"
var _timer: float = 0.0
var _stagger: float = 0.0
var _attack_direction := Vector3.FORWARD
var _model: Node3D
var _animation: AnimationPlayer
var _dead: bool = false
var _attack_hit_applied: bool = false
var _spawn: Vector3

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	add_to_group("tether_targets")
	set_meta("kind", "enemy")
	_spawn = global_position
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	if ResourceLoader.exists("res://assets/models/sentinel.glb"):
		_model = (load("res://assets/models/sentinel.glb") as PackedScene).instantiate()
		add_child(_model)
		_animation = _find_animation(_model)
		if _animation:
			for clip in ["idle", "run", "slide", "fall"]:
				if _animation.has_animation(clip):
					_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play("idle")

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation(child)
		if found:
			return found
	return null

func _play(clip: String) -> void:
	if _animation and _animation.has_animation(clip) and _animation.current_animation != clip:
		_animation.speed_scale = 1.0
		_animation.play(clip, 0.1)

func is_available() -> bool:
	return not _dead

func receive_hit(damage: int, launch: bool, origin: Vector3) -> bool:
	if _dead:
		return false
	health = maxi(0, health - damage)
	var away := global_position - origin
	away.y = 0.0
	velocity = away.normalized() * 3.0
	velocity.y = 10.5 if launch else 2.0
	_stagger = 0.65 if launch else 0.22
	_timer = 0.0
	state_name = "hurt"
	_play("hurt")
	if health == 0:
		_dead = true
		state_name = "dead"
		collision_layer = 0
		remove_from_group("tether_targets")
		_play("death")
		defeated.emit(self)
	return true

func _visible_to_player() -> bool:
	var cam: Camera3D = player.get("camera") as Camera3D
	if not cam or cam.is_position_behind(global_position + Vector3.UP):
		return false
	if not cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(global_position + Vector3.UP)):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if _dead:
		_timer += delta
		if _timer > 1.8:
			queue_free()
		return
	if not is_instance_valid(player) or not player.get("active"):
		return
	velocity.y = maxf(-24.0, velocity.y - 24.0 * delta)
	_stagger = maxf(0.0, _stagger - delta)
	if _stagger > 0.0 or not is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)
		move_and_slide()
		_recover_from_fall()
		return
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0.0
	_timer -= delta
	match state_name:
		"windup":
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				state_name = "strike"
				_timer = 0.36
				_attack_hit_applied = false
				_play("slash_1")
				if _animation and _animation.has_animation("slash_1"):
					_animation.speed_scale = _animation.get_animation("slash_1").length / 0.36
		"strike":
			if not _attack_hit_applied and _timer <= 0.18:
				_attack_hit_applied = true
				if offset.length() < 2.5 and _attack_direction.dot(offset.normalized()) > 0.65 and absf(player.global_position.y - global_position.y) < 1.8 and _attack_line_clear():
					player.call("take_damage", 14, global_position)
			velocity.x = _attack_direction.x * 5.0
			velocity.z = _attack_direction.z * 5.0
			if _timer <= 0.0:
				state_name = "recover"
				_timer = 1.0
		"recover":
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				state_name = "idle"
		_:
			state_name = "idle"
			if offset.length() < 2.3 and _visible_to_player() and _attack_slot_available():
				state_name = "windup"
				_timer = 0.72
				_attack_direction = offset.normalized()
				_play("launch")
				player.action_performed.emit("enemy_warning")
			elif offset.length() < 12.0 and offset.length() > 2.0:
				var direction := offset.normalized()
				# Stay near the spawn platform; never chase the player into a void.
				var next := global_position + direction * 1.5
				var ray := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 0.4, next - Vector3.UP * 2.0, 1)
				if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					velocity.x = direction.x * 2.1
					velocity.z = direction.z * 2.1
				else:
					velocity.x = 0.0
					velocity.z = 0.0
				_play("run")
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_play("idle")
	if offset.length() > 0.1 and state_name == "idle":
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), delta * 7.0)
	move_and_slide()
	_recover_from_fall()

func _attack_slot_available() -> bool:
	# One committed attacker at a time; another can join once its strike recovers.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy.is_available() and enemy.state_name in ["windup", "strike"]:
			return false
	return true

func _attack_line_clear() -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _recover_from_fall() -> void:
	if global_position.y < -20.0:
		global_position = _spawn + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		_stagger = 0.0
		_timer = 0.0
		state_name = "idle"
		_attack_hit_applied = false
		reset_physics_interpolation()
