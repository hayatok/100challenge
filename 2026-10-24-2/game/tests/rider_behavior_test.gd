extends SceneTree

var rider: CharacterBody3D
var floor_course: Node3D
var failures: Array[String] = []
var _checks: int = 0
var landed_count: int = 0
var jumped_count: int = 0
var fell_count: int = 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		failures.append(label)
	print("CHECK ", label, ": ", condition)

func _run() -> void:
	for name in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
	floor_course = Node3D.new()
	var script := GDScript.new()
	script.source_code = "extends Node3D\nfunc center_at(s: float) -> Vector3:\n\treturn Vector3(0,0,-s)\nfunc tangent_at(_s: float) -> Vector3:\n\treturn Vector3.FORWARD\nfunc half_width_at(_s: float) -> float:\n\treturn 8.0\n"
	script.reload()
	floor_course.set_script(script)
	root.add_child(floor_course)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 1
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(16.0, 1.0, 2000.0)
	floor_shape.shape = shape
	floor_body.position = Vector3(0, -0.5, -900)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	rider = load("res://scenes/rider.tscn").instantiate()
	rider.set("course", floor_course)
	root.add_child(rider)
	rider.connect("landed", func(): landed_count += 1)
	rider.connect("jumped", func(): jumped_count += 1)
	rider.connect("fell", func(): fell_count += 1)
	rider.call("reset_run")
	rider.call("set_active", true)
	await frames(65)
	check(rider.is_on_floor(), "grounded after 1 second")
	check(rider.get("progress") > 18.0, "automatic forward progress")
	check(absf(rider.get("lateral")) < 0.05, "no central drift on straight")
	Input.action_press("jump")
	await frames(20)
	check(rider.position.y > 1.4, "jump reaches expected height")
	await frames(55)
	check(rider.is_on_floor() and landed_count == 1 and jumped_count == 1, "one held jump produces one landing")
	Input.action_release("jump")
	var before_brake: float = rider.get("progress")
	Input.action_press("brake")
	await frames(60)
	check(is_equal_approx(rider.get("speed"), 8.0) and rider.get("progress") > before_brake, "braking reaches minimum speed without stopping")
	Input.action_release("brake")
	await frames(60)
	check(rider.get("speed") > 13.0, "releasing brake recovers cruise speed")
	rider.set("wind_energy", 10.0)
	Input.action_press("boost")
	await frames(22)
	check(not rider.get("boosting"), "boost exhausts")
	await frames(60)
	check(rider.get("wind_energy") > 0.0 and not rider.get("boosting"), "held boost stays off after distance recharge")
	Input.action_release("boost")
	await frames(1)
	Input.action_press("boost")
	await frames(1)
	check(rider.get("boosting"), "boost re-arms after release")
	Input.action_release("boost")
	await frames(2)
	var furthest: float = rider.get("max_progress")
	rider.call("reset_to", 0.0, 40.0)
	rider.call("set_active", true)
	await frames(60)
	check(is_equal_approx(rider.get("max_progress"), furthest), "checkpoint preserves highest progress")
	check(is_equal_approx(rider.get("wind_energy"), 40.0), "repeated distance grants no energy")
	await frames(40)
	var speed_before: float = rider.get("speed")
	var accepted: bool = rider.call("take_hit")
	var speed_hit: float = rider.get("speed")
	var duplicate: bool = rider.call("take_hit")
	check(accepted and not duplicate and is_equal_approx(speed_hit, speed_before * 0.7) and is_equal_approx(rider.get("speed"), speed_hit), "hit slows 30 percent and immunity blocks repeat")
	await frames(60)
	check(not rider.call("take_hit"), "hit immunity lasts beyond one second")
	await frames(35)
	check(rider.call("take_hit"), "hit immunity expires after 1.5 seconds")
	rider.call("reset_run")
	check(not rider.call("take_hit"), "inactive rider rejects hits")
	check(is_zero_approx(rider.get("max_progress")) and is_equal_approx(rider.get("wind_energy"), 60.0), "new run clears recovery history")
	# Pause-like deactivation must freeze travel and discard held actions.
	rider.call("set_active", false)
	var stopped_position := rider.position
	Input.action_press("jump")
	Input.action_press("boost")
	await frames(5)
	check(rider.position.is_equal_approx(stopped_position), "inactive rider does not travel")
	rider.call("set_active", true)
	await frames(4)
	check(not rider.get("boosting") and jumped_count == 1, "reactivation ignores held jump and boost")
	Input.action_release("jump")
	Input.action_release("boost")
	await frames(3)
	Input.action_press("boost")
	await frames(2)
	var energy_before: float = rider.get("wind_energy")
	rider.call("grant_energy", 20.0)
	check(is_equal_approx(rider.get("wind_energy"), energy_before), "event recovery is rejected while boosting")
	Input.action_release("boost")
	await frames(2)

	# Press before contact, then observe an actual jump without a second press.
	rider.call("reset_to", 5.0, 60.0)
	rider.position.y = 2.0
	rider.velocity.y = -6.0
	rider.call("set_active", true)
	await frames(4)
	var wait_frames := 0
	while rider.position.y > 0.32 and not rider.is_on_floor() and wait_frames < 30:
		await frames(1)
		wait_frames += 1
	check(not rider.is_on_floor(), "buffer input is issued before contact")
	var jumps_before := jumped_count
	Input.action_press("jump")
	await frames(6)
	check(jumped_count == jumps_before + 1 and rider.velocity.y > 0.0, "prelanding input buffer produces one jump")
	Input.action_release("jump")
	await frames(75)

	# Remove support, wait within coyote time, then jump from the air.
	check(rider.is_on_floor(), "grounded before coyote check")
	floor_body.collision_layer = 0
	await frames(3)
	check(not rider.is_on_floor(), "support has actually been lost")
	jumps_before = jumped_count
	Input.action_press("jump")
	await frames(2)
	check(jumped_count == jumps_before + 1 and rider.velocity.y > 0.0, "coyote jump works after support loss")
	Input.action_release("jump")
	await frames(180)
	check(fell_count == 1, "fall emits once and deactivates movement")
	await frames(15)
	check(fell_count == 1, "fall notification is not repeated")
	print("Rider behavior: %d checks, %d failures" % [_checks, failures.size()])
	rider.queue_free()
	floor_body.queue_free()
	floor_course.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
