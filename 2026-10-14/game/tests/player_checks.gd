extends RefCounted
## Headless runner: var failures: Array[String] = await Checks.new().run(tree)

const PlayerScript = preload("res://scripts/player.gd")

var _failures: Array[String] = []
var _impacts := 0
var _recoveries := 0
var _largest_impact := 0.0


func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var world := Node3D.new()
	tree.root.add_child(world)
	_wall(world, Vector3(0.0, -0.15, 0.0), Vector3(300.0, 0.3, 300.0))
	var player := PlayerScript.new()
	world.add_child(player)
	player.impacted.connect(_on_impact)
	player.recovered.connect(_on_recovery)
	# Align the coroutine before a physics callback. Each following signal then
	# observes exactly one completed simulation tick, even during render hitches.
	await tree.physics_frame
	player.reset_at(Vector3.ZERO)
	player.set_active(true)
	player.set_controls(0.0, true)
	_expect(player.collision_layer == 1 and player.collision_mask == 2, "Player is layer 1 and scans only fixed world layer 2")
	await _ticks(tree, 60)
	_expect(player.position.z < -2.0, "Spray must propel the chair along -Z in real physics ticks")
	_expect(player.get_speed() > 4.0 and player.get_speed() <= 9.001, "Acceleration and 9m/s speed cap")
	_expect(absf(player.pressure - 75.0) < 0.6, "One second of spray consumes 25 pressure")
	_expect(is_zero_approx(player.position.y), "Controller root remains on floor y=0")
	var velocity_before: Vector3 = player.velocity
	player.set_controls(1.0, false)
	await _ticks(tree, 10)
	_expect(player.rotation.y < -0.2, "Positive/right steering turns the chair toward +X")
	_expect(player.velocity.normalized().dot(velocity_before.normalized()) > 0.999, "Steering preserves inertial travel direction")
	_expect(player.get_speed() < velocity_before.length(), "Released spray coasts with friction")
	await _ticks(tree, 20)
	_expect(absf(player.pressure - 100.0) < 0.6, "Half a second restores the consumed 25 pressure")

	player.reset_at(Vector3.ZERO)
	player.set_controls(0.0, true)
	await _ticks(tree, 245)
	_expect(player.pressure < 0.001 and not player.boosting, "Four seconds exhaust pressure; holding spray cannot recharge")
	_expect(_recoveries == 0, "Spraying without fixed contact cannot trigger recovery")
	var before_turn := player.rotation.y
	player.set_controls(1.0, true)
	await _ticks(tree, 20)
	_expect(absf(player.rotation.y - before_turn) > 0.5, "Zero-pressure steering remains available")
	_expect(player.pressure < 0.001, "Empty held spray stays empty")
	player.set_controls(0.0, false)
	await _ticks(tree, 120)
	_expect(absf(player.pressure - 100.0) < 0.6, "Released spray refills from empty in two seconds")

	player.reset_at(Vector3.ZERO)
	player.hit_stop = 0.1
	player.set_controls(1.0, true)
	await _ticks(tree, 4)
	_expect(player.position.length() < 0.0001, "Hit stop freezes translation")
	_expect(player.pressure < 99.0 and player.rotation.y < -0.1, "Hit stop still advances pressure and steering")
	player.set_active(false)
	var paused_position: Vector3 = player.position
	var paused_pressure: float = player.pressure
	await _ticks(tree, 20)
	_expect(player.position == paused_position and player.pressure == paused_pressure, "Inactive player freezes movement and pressure")
	_expect(not player.boosting and is_zero_approx(player.steering), "Deactivation clears held controls")
	player.reset_at(Vector3(0.0, 4.0, 0.0), 0.5)
	_expect(player.position.y == 0.0 and is_equal_approx(player.rotation.y, 0.5), "Reset uses a floor root and supplied yaw")
	_expect(player.get_speed() == 0.0 and player.pressure == 100.0 and player.hit_stop == 0.0, "Reset restores velocity, pressure and hit stop")

	# A thin wall is swept at maximum speed, rather than tested only at the end.
	var wall := _wall(world, Vector3(0.0, 0.65, -1.2), Vector3(5.0, 1.3, 0.08))
	await _ticks(tree, 2)
	player.reset_at(Vector3.ZERO)
	player.set_active(true)
	player.velocity = Vector3(0.0, 0.0, -9.0)
	player.set_controls(0.0, false)
	_impacts = 0
	_largest_impact = 0.0
	await _ticks(tree, 8)
	_expect(_impacts > 0 and _largest_impact > 7.0, "Fixed-wall collision emits actual incoming impact speed")
	_expect(player.position.z > -0.65, "High-speed chair cannot tunnel through a thin fixed wall")
	_expect(player.velocity.z > 0.0, "Strong collision rebounds from the wall")

	# Touching a wall without powered spray must never trigger automatic recovery.
	player.reset_at(Vector3(0.0, 0.0, -0.62))
	_recoveries = 0
	player.set_controls(0.0, false)
	await _ticks(tree, 90)
	_expect(_recoveries == 0, "Contact without spray cannot auto-recover")
	player.pressure = 0.0
	player.set_controls(0.0, true)
	await _ticks(tree, 90)
	_expect(_recoveries == 0, "Contact with zero-pressure spray cannot auto-recover")
	player.set_controls(1.0, false)
	await _ticks(tree, 90)
	_expect(_recoveries == 0, "Steering alone cannot auto-recover")

	# Start in a safe known spot, push against the wall, then observe real recovery.
	player.reset_at(Vector3.ZERO)
	_recoveries = 0
	player.set_controls(0.0, true)
	await _ticks(tree, 75)
	_expect(_recoveries == 0, "Recovery waits for 1.2 seconds of powered low-speed contact")
	await _ticks(tree, 75)
	_expect(_recoveries > 0, "Powered, low-speed persistent fixed contact recovers after 1.2 seconds")
	_expect(player.position.z > -0.65 and player.position.z <= 0.01, "Recovery stays on the visited side of the wall without forward shortcuts")
	_expect(player.pressure < 45.0 and player.pressure > 30.0, "Recovery does not refill pressure")
	_expect(player.position.y == 0.0, "Recovery preserves floor height")
	wall.queue_free()
	world.queue_free()
	await tree.process_frame
	return _failures.duplicate()


func _ticks(tree: SceneTree, count: int) -> void:
	for _tick in range(count):
		await tree.physics_frame


func _wall(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body


func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)


func _on_impact(speed: float, _at: Vector3, _normal: Vector3) -> void:
	_impacts += 1
	_largest_impact = maxf(_largest_impact, speed)


func _on_recovery(_at: Vector3) -> void:
	_recoveries += 1
