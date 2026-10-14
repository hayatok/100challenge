extends CharacterBody3D
## Planar, swept chair movement. The root stays at floor height; art is a child.

signal impacted(speed: float, at: Vector3, normal: Vector3)
signal recovered(at: Vector3)

const MAX_SPEED := 9.0
const ACCELERATION := 7.5
const COAST_DRAG := 1.8
const TURN_RATE := 2.25
const PRESSURE_DRAIN := 25.0
const PRESSURE_RECOVERY := 50.0
const STUCK_SECONDS := 1.2
const STUCK_SPEED := 0.22
const BODY_RADIUS := 0.54
const BODY_HEIGHT := 0.85
const BODY_CENTER := Vector3(0.0, 0.65, 0.0)

var pressure: float = 100.0
var boosting: bool = false
var steering: float = 0.0
var active: bool = false
var hit_stop: float = 0.0

var _spray_requested := false
var _stuck_time := 0.0
var _impact_cooldown := 0.0
var _safe_positions: Array[Vector3] = []
var _safety_shape: CylinderShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.002
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	collider.shape = shape
	collider.position = BODY_CENTER
	add_child(collider)
	_safety_shape = CylinderShape3D.new()
	_safety_shape.radius = BODY_RADIUS + 0.12
	_safety_shape.height = BODY_HEIGHT
	_safe_positions.append(global_position)


func set_controls(turn: float, spray: bool) -> void:
	steering = clampf(turn, -1.0, 1.0)
	_spray_requested = spray


func reset_at(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	pressure = 100.0
	boosting = false
	steering = 0.0
	_spray_requested = false
	hit_stop = 0.0
	_stuck_time = 0.0
	_impact_cooldown = 0.0
	_safe_positions.clear()
	_safe_positions.append(global_position)
	reset_physics_interpolation()


func set_active(value: bool) -> void:
	active = value
	if not value:
		set_controls(0.0, false)
		boosting = false
		_stuck_time = 0.0


func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	# Empty pressure remains empty until the button is released.
	boosting = _spray_requested and pressure > 0.0
	var powered_fraction := 0.0
	if _spray_requested:
		powered_fraction = minf(1.0, pressure / (PRESSURE_DRAIN * delta))
		pressure = maxf(0.0, pressure - PRESSURE_DRAIN * delta)
	else:
		pressure = minf(100.0, pressure + PRESSURE_RECOVERY * delta)
	# Steering and the pressure clock remain responsive during impact stops.
	rotation.y -= steering * TURN_RATE * delta
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
		_stuck_time = 0.0
		return
	velocity.y = 0.0
	velocity = velocity.move_toward(Vector3.ZERO, COAST_DRAG * delta)
	if powered_fraction > 0.0:
		velocity += -global_basis.z * ACCELERATION * powered_fraction * delta
	velocity = velocity.limit_length(MAX_SPEED)
	var before := global_position
	var touching_fixed := _move_on_floor(delta)
	var actual_speed := global_position.distance_to(before) / delta
	if touching_fixed and boosting and pressure > 0.0 and actual_speed < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_restore_safe_position()
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	if not touching_fixed:
		_remember_safe_position()


func _move_on_floor(delta: float) -> bool:
	var touching_fixed := false
	var remaining := velocity * delta
	# move_and_collide sweeps the entire collider, including against thin walls.
	for _iteration in range(3):
		if remaining.length_squared() < 0.00000001:
			break
		var collision := move_and_collide(remaining)
		if collision == null:
			break
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.001:
			break
		normal = normal.normalized()
		var collider := collision.get_collider()
		if collider is StaticBody3D:
			touching_fixed = true
		var impact_speed := maxf(0.0, -velocity.dot(normal))
		if impact_speed >= 1.3:
			velocity = velocity.slide(normal) * 0.85 + normal * impact_speed * 0.24
			# An oblique hit nudges the chair; it never rotates the velocity to match.
			var side := (-global_basis.z).cross(normal).y
			rotation.y += clampf(side * impact_speed * 0.025, -0.18, 0.18)
			if _impact_cooldown <= 0.0:
				_impact_cooldown = 0.25
				impacted.emit(impact_speed, collision.get_position(), normal)
		else:
			velocity = velocity.slide(normal)
		remaining = collision.get_remainder().slide(normal)
	return touching_fixed


func _position_is_safe(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _safety_shape
	query.transform = Transform3D(Basis.IDENTITY, at + BODY_CENTER)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _remember_safe_position() -> void:
	if not _position_is_safe(global_position):
		return
	if not _safe_positions.is_empty() and global_position.distance_to(_safe_positions.back()) < 0.12:
		return
	_safe_positions.append(global_position)
	if _safe_positions.size() > 40:
		_safe_positions.pop_front()


func _restore_safe_position() -> void:
	# Only a recent, nearby previously visited floor position is eligible. A full
	# shape sweep prevents crossing walls or cutting through a corner to reach it.
	for index in range(_safe_positions.size() - 1, -1, -1):
		var target := _safe_positions[index]
		var offset := target - global_position
		if offset.length() > 1.4 or offset.length() < 0.08:
			continue
		if not _position_is_safe(target) or test_move(global_transform, offset):
			continue
		move_and_collide(offset)
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		recovered.emit(global_position)
		return
