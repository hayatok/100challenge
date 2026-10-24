extends SceneTree

var rider: CharacterBody3D
var floor_course: Node3D
var failures: Array[String] = []
var _checks: int = 0
var landed_count: int = 0
var jumped_count: int = 0
var fell_count: int = 0
var release_count: int = 0
var burst_count: int = 0

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
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 64
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
	rider.connect("carve_released", func(_charge): release_count += 1)
	rider.connect("burst_started", func(_strength): burst_count += 1)
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
	check(is_equal_approx(rider.get("speed"), 17.0) and rider.get("progress") > before_brake, "braking reaches minimum speed without stopping")
	Input.action_release("brake")
	await frames(60)
	check(rider.get("speed") > 13.0, "releasing brake recovers cruise speed")
	rider.set("wind_energy", 24.0)
	Input.action_press("boost")
	await frames(22)
	check(rider.get("boosting") and is_zero_approx(rider.get("wind_energy")), "burst spends a fixed wind budget and persists after press")
	await frames(90)
	check(not rider.get("boosting") and is_zero_approx(rider.get("wind_energy")), "straight passive travel cannot refill wind")
	rider.call("grant_energy", 24.0)
	await frames(4)
	check(not rider.get("boosting"), "held boost cannot consume newly earned wind")
	Input.action_release("boost")
	await frames(3)
	Input.action_press("boost")
	await frames(3)
	check(rider.get("boosting"), "boost re-arms after release")
	Input.action_release("boost")
	await frames(100)
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
	check(accepted and not duplicate and is_equal_approx(speed_hit, maxf(17.0, speed_before * 0.7)) and is_equal_approx(rider.get("speed"), speed_hit), "hit slows 30 percent and immunity blocks repeat")
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

	# Digital steering must stop rotating promptly when the key is released,
	# while travel, visual bank and body animation remain separately inertial.
	rider.call("reset_to", 5.0, 60.0)
	rider.call("set_active", true)
	await frames(10)
	Input.action_press("brake")
	Input.action_press("steer_right")
	await frames(5)
	check(absf(rider.get("_steering_rate")) >= rider.get("carve_turn_speed") * 0.95, "new digital carve reaches its intended turn rate within 80ms")
	await frames(7)
	var heading_at_release: float = rider.get("heading")
	Input.action_release("brake")
	Input.action_release("steer_right")
	await frames(4)
	check(is_zero_approx(rider.get("_steering_rate")), "released steering stops rotating within three completed 60Hz ticks")
	await frames(4)
	var release_angle := rad_to_deg(absf(rider.get("heading") - heading_at_release))
	check(release_angle <= 1.5, "steering release adds no more than 1.5 degrees of residual heading")
	print("Steering release: residual_angle=%.3fdeg final_rate=%.4f" % [release_angle, rider.get("_steering_rate")])

	rider.call("reset_to", 5.0, 60.0)
	rider.call("set_active", true)
	await frames(10)
	Input.action_press("brake")
	Input.action_press("steer_right")
	await frames(12)
	var heading_at_reversal: float = rider.get("heading")
	var furthest_wrong_heading: float = heading_at_reversal
	Input.action_release("steer_right")
	Input.action_press("steer_left")
	for reversal_tick in 4:
		await frames(1)
		furthest_wrong_heading = minf(furthest_wrong_heading, rider.get("heading"))
	check(rider.get("_steering_rate") > 0.0, "opposite digital input reverses angular direction within three completed 60Hz ticks")
	await frames(3)
	check(rider.get("_steering_rate") >= rider.get("carve_turn_speed") * 0.95, "opposite input reaches its full new turn rate within 100ms")
	var wrong_way_angle := rad_to_deg(absf(furthest_wrong_heading - heading_at_reversal))
	check(wrong_way_angle <= 1.5, "reversal carries the old heading no more than 1.5 degrees before correcting")
	print("Steering reversal: wrong_way_angle=%.3fdeg final_rate=%.4f" % [wrong_way_angle, rider.get("_steering_rate")])
	Input.action_release("brake")
	Input.action_release("steer_left")

	# A deliberate carve trades speed for charge and release acceleration.
	rider.call("reset_to", 5.0, 60.0)
	rider.call("set_active", true)
	await frames(10)
	Input.action_press("brake")
	Input.action_press("steer_right")
	await frames(34)
	check(rider.get("carving") and rider.get("carve_charge") >= 0.22 and rider.get("speed") < 24.0, "turning carve visibly charges while spending speed")
	var saved_charge: float = rider.get("carve_charge")
	var saved_hold: float = rider.get("_carve_time")
	var saved_distance: float = rider.get("_carve_distance")
	var saved_releases := release_count
	rider.call("set_active", false)
	var charged_pause_position := rider.position
	await frames(30)
	check(is_equal_approx(rider.get("carve_charge"), saved_charge) and is_equal_approx(rider.get("_carve_time"), saved_hold) and is_equal_approx(rider.get("_carve_distance"), saved_distance) and rider.position.is_equal_approx(charged_pause_position), "pause freezes earned charge, committed hold and travel distance")
	rider.call("set_active", true)
	await frames(3)
	check(not rider.get("carving") and not rider.get("boosting") and is_equal_approx(rider.get("carve_charge"), saved_charge) and release_count == saved_releases, "held S and steering cannot re-arm the saved carve after resume")
	# Releasing S during the next paused countdown must not become an automatic
	# release when locomotion resumes. A fresh S press/release is explicit intent.
	rider.call("set_active", false)
	Input.action_release("brake")
	Input.action_release("steer_right")
	await frames(10)
	rider.call("set_active", true)
	await frames(3)
	check(is_equal_approx(rider.get("carve_charge"), saved_charge) and not rider.get("boosting") and release_count == saved_releases and rider.get("charge_requires_press"), "S released during pause preserves stored charge without an automatic burst")
	Input.action_press("brake")
	await frames(3)
	check(not rider.get("charge_requires_press") and is_equal_approx(rider.get("carve_charge"), saved_charge), "fresh S press explicitly arms the stored release without spending charge")
	Input.action_release("brake")
	Input.action_release("steer_right")
	await frames(3)
	check(rider.get("boosting") and rider.get("speed") > 29.0 and is_zero_approx(rider.get("carve_charge")) and release_count == saved_releases + 1, "fresh S press and release explicitly turns preserved charge into acceleration")
	check(absf(rider.get("heading")) > 0.3, "travel heading is controlled by input rather than reset to the road tangent")
	rider.call("reset_to", 5.0, 60.0)
	rider.call("set_active", true)
	await frames(10)

	# Two 200ms edges exceed the charge threshold in total, but reversing must
	# start the hold again instead of turning a wiggle into a valid release.
	rider.call("reset_to", 5.0, 0.0)
	rider.call("set_active", true)
	await frames(10)
	var reversal_releases := release_count
	Input.action_press("brake")
	Input.action_press("steer_right")
	await frames(12)
	Input.action_release("steer_right")
	Input.action_press("steer_left")
	await frames(12)
	var reversed_charge: float = rider.get("carve_charge")
	Input.action_release("brake")
	Input.action_release("steer_left")
	await frames(3)
	check(reversed_charge < 0.34 and release_count == reversal_releases and not rider.get("boosting"), "reversing resets charge and a 200ms edge cannot release a burst")

	# Compare identical straight-line time budgets: 100ms alternating taps must
	# neither trigger a successful release nor beat simply carrying cruise speed.
	rider.call("reset_to", 5.0, 0.0)
	rider.call("set_active", true)
	await frames(10)
	var coast_start: float = rider.get("progress")
	await frames(288)
	var coast_distance: float = rider.get("progress") - coast_start
	rider.call("reset_to", 5.0, 0.0)
	rider.call("set_active", true)
	await frames(10)
	var mash_start: float = rider.get("progress")
	var releases_before := release_count
	var bursts_before := burst_count
	for cycle in 24:
		var direction := "steer_right" if cycle % 2 == 0 else "steer_left"
		Input.action_press("brake")
		Input.action_press(direction)
		await frames(6)
		Input.action_release("brake")
		Input.action_release(direction)
		await frames(6)
	var mash_distance: float = rider.get("progress") - mash_start
	check(release_count == releases_before and burst_count == bursts_before and is_zero_approx(rider.get("wind_energy")), "100ms alternating button mash earns no burst, successful release or wind")
	check(mash_distance < coast_distance * 0.98, "button mash loses straight-line distance against cruise in the same time")
	print("Mash comparison: time=4.800s coast=%.2fm mash=%.2fm releases=%d bursts=%d wind=%.2f" % [coast_distance, mash_distance, release_count - releases_before, burst_count - bursts_before, rider.get("wind_energy")])
	rider.call("reset_to", 5.0, 60.0)
	rider.call("set_active", true)
	await frames(10)

	# A paid burst in mid-flight must survive pause/countdown without another
	# Shift payment. Use real takeoff and velocity, then resume with Shift held.
	Input.action_press("boost")
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	var airborne_burst_left: float = rider.get("burst_left")
	var airborne_energy: float = rider.get("wind_energy")
	var airborne_bursts := burst_count
	var airborne_position := rider.position
	var airborne_velocity := rider.velocity
	check(not rider.is_on_floor() and airborne_burst_left > 1.0, "pause regression begins during an actual boosted jump")
	rider.call("set_active", false)
	await frames(45)
	check(is_equal_approx(rider.get("burst_left"), airborne_burst_left) and rider.position.is_equal_approx(airborne_position) and rider.velocity.is_equal_approx(airborne_velocity) and not rider.get("boosting"), "inactive airborne burst retains its timer and complete travel vector")
	rider.call("set_active", true)
	check(rider.get("boosting") and is_equal_approx(rider.get("burst_left"), airborne_burst_left), "resume restores the active burst visual flag before physics advances")
	await frames(3)
	check(rider.get("boosting") and rider.get("burst_left") > airborne_burst_left - 0.07 and is_equal_approx(rider.get("wind_energy"), airborne_energy) and burst_count == airborne_bursts, "held Shift resumes the existing airborne burst without buying or starting another")
	Input.action_release("boost")
	rider.call("reset_to", 5.0, 60.0)
	check(is_zero_approx(rider.get("burst_left")) and is_zero_approx(rider.get("carve_charge")) and is_zero_approx(rider.get("_carve_time")) and is_zero_approx(rider.get("_carve_distance")), "checkpoint recovery explicitly clears burst and carve resources")
	rider.call("set_active", true)
	await frames(10)
	Input.action_press("brake")
	Input.action_press("steer_right")
	await frames(20)
	check(rider.get("carve_charge") > 0.2, "retry regression begins with a newly earned charge")
	Input.action_release("brake")
	Input.action_release("steer_right")
	rider.call("reset_run")
	check(is_zero_approx(rider.get("burst_left")) and is_zero_approx(rider.get("carve_charge")) and is_zero_approx(rider.get("_carve_time")) and is_zero_approx(rider.get("_carve_distance")), "retry explicitly clears stored carve and acceleration state")
	rider.call("set_active", true)
	await frames(10)

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
