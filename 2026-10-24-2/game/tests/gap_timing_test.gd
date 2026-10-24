extends SceneTree

var course
var rider
var checks := 0
var failures := 0
var falls := 0
var jumps := 0
var takeoff_s := -1.0

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for tick in count:
		await physics_frame

func _trial(gap: Vector2, travel_speed: float, requested_distance: float) -> Dictionary:
	Input.action_release("jump")
	rider.cruise_speed = travel_speed
	rider.downhill_speed = travel_speed
	rider.boost_speed = travel_speed
	rider.reset_to(gap.x - 20.0, 60.0)
	rider.set_active(true)
	falls = 0
	jumps = 0
	takeoff_s = -1.0
	var issued := false
	var ticks := 0
	var crossed := false
	while ticks < 220 and falls == 0:
		if requested_distance < 100.0 and not issued and rider.progress >= gap.x - requested_distance:
			Input.action_press("jump")
			issued = true
		elif issued:
			Input.action_release("jump")
		await physics_frame
		ticks += 1
		if rider.progress >= gap.y and rider.is_on_floor():
			crossed = true
			break
	Input.action_release("jump")
	var failed_surface: Vector3 = course.surface_at(gap.y if rider.progress >= gap.x and rider.progress < gap.y else rider.progress, rider.lateral)
	var feet_clearance: float = rider.position.y - failed_surface.y
	var result := {"success": crossed, "takeoff": gap.x - takeoff_s if takeoff_s >= 0.0 else -999.0,
		"falls": falls, "hidden": not rider.get_node("Visual").visible, "reason": rider.fall_reason,
		"s": rider.progress, "clearance": feet_clearance, "jumps": jumps}
	if falls > 0:
		expect(falls == 1 and not rider.get_node("Visual").visible, "failed traversal hides the rider at the first fall signal")
		if rider.fall_reason == "missed_platform":
			expect(rider.progress <= gap.y + 1.0 and feet_clearance > -0.65, "missed landing is hidden at the lip before the body protrudes through stone")
		await frames(12)
		expect(falls == 1, "failed traversal emits only one fall while waiting for recovery")
		expect(rider.position.y > course.center_at(rider.progress).y - 4.5, "failure is detected before the old fourteen-metre fall")
	rider.reset_to(gap.x - 20.0, 60.0)
	expect(rider.get_node("Visual").visible and rider.fall_reason.is_empty(), "checkpoint reset restores the visual and clears failure reason")
	return result

func _run() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 64
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	course = load("res://scripts/course.gd").new()
	root.add_child(course)
	rider = load("res://scenes/rider.tscn").instantiate()
	rider.course = course
	root.add_child(rider)
	rider.fell.connect(func(): falls += 1)
	rider.jumped.connect(func(): jumps += 1; takeoff_s = rider.progress)
	await frames(2)
	for gap in course.GAPS:
		for travel_speed in [24.0, 40.0]:
			var successes: Array[float] = []
			var row: Array[String] = []
			for distance in [-8.0, -4.0, -1.0, 0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0]:
				var result := await _trial(gap, travel_speed, distance)
				row.append("%+.0f:%s" % [distance, "OK" if result.success else "fall"])
				if result.success and result.jumps == 1:
					successes.append(float(result.takeoff))
				if distance == -8.0 and (gap.x > 800.0 or travel_speed == 24.0):
					expect(not result.success, "Space too late in the gap does not turn into an automatic jump")
			var no_jump := await _trial(gap, travel_speed, 999.0)
			print("Gap %.0f..%.0f speed=%.0f requested takeoff metres before lip: %s no_jump=%s" % [gap.x, gap.y, travel_speed, ", ".join(row), no_jump.success])
			if gap.x > 800.0:
				expect(not no_jump.success, "last gap requires an actual Space takeoff even at high speed")
				if travel_speed == 40.0:
					var window: float = successes.max() - successes.min() if successes.size() > 1 else 0.0
					expect(window >= 12.0, "final gap at burst speed offers at least 0.3 seconds of takeoff timing range")
					print("Final burst takeoff window: %.1fm / %.3fs" % [window, window / travel_speed])
			elif travel_speed == 24.0:
				expect(successes.size() >= 4, "normal-speed introductory jumps have several successful takeoff positions")
	# Side falls are hidden soon after leaving the deck, while an above-deck
	# airborne jump remains visible until an actual miss occurs.
	rider.reset_to(580.0, 60.0)
	rider.position.x += course.half_width_at(580.0) + 1.0
	rider.position.y += 0.4
	rider.set_active(true)
	falls = 0
	await frames(35)
	expect(falls == 1 and rider.fall_reason == "side_fall" and not rider.get_node("Visual").visible, "side fall hides and recovers before the avatar sinks far below the deck")
	print("Gap timing: checks=%d failures=%d" % [checks, failures])
	rider.queue_free()
	course.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
