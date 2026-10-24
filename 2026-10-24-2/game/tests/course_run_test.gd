extends SceneTree

var checks := 0
var failures := 0
var falls := 0
var jumps := 0
var landings := 0
var bursts := 0
var clean := 0
var releases: Array[float] = []
var course
var rider

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 64
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	course = load("res://scripts/course.gd").new()
	root.add_child(course)
	rider = load("res://scenes/rider.tscn").instantiate()
	rider.course = course
	root.add_child(rider)
	rider.fell.connect(func(): falls += 1)
	rider.jumped.connect(func(): jumps += 1)
	rider.landed.connect(func(): landings += 1)
	rider.burst_started.connect(func(_value): bursts += 1)
	rider.clean_landed.connect(func(_value): clean += 1)
	rider.carve_released.connect(func(value): releases.append(value))
	await physics_frame
	rider.reset_run()
	rider.set_active(true)
	for tick in 1000:
		await physics_frame
		if falls > 0:
			break
	expect(falls == 1 and rider.progress < 150.0, "zero input cannot follow the first authored turn")
	print("Unsteered fall: progress=%.2f lateral=%.2f" % [rider.progress, rider.lateral])
	falls = 0
	# A keyboard-strength carve on the actual first corner should load within
	# one short lean, with its heading and speed measured from real physics.
	rider.reset_to(35.0, 60.0)
	rider.set_active(true)
	for settling_tick in 4:
		await physics_frame
	var start_heading: float = rider.heading
	Input.action_press("brake")
	Input.action_press("steer_right")
	for carve_tick in 24:
		await physics_frame
	var corner_charge: float = rider.carve_charge
	var corner_angle: float = rad_to_deg(absf(rider.heading - start_heading))
	var corner_speed: float = rider.speed
	var corner_lateral: float = rider.lateral
	Input.action_release("brake")
	Input.action_release("steer_right")
	for release_tick in 3:
		await physics_frame
	var release_speed: float = rider.speed
	expect(corner_charge >= 0.9 and not releases.is_empty(), "one 0.4-second committed first-corner carve reaches READY and releases")
	expect(corner_angle < 30.0 and absf(corner_lateral) < 2.5, "full corner charge fits the authored turn without leaving its natural line")
	expect(corner_speed < 22.0 and release_speed > 35.0, "carve speed cost becomes immediate release acceleration")
	print("First corner: hold=0.400s charge=%.3f angle=%.2fdeg lateral=%.2fm carve_speed=%.2f release_speed=%.2f" % [corner_charge, corner_angle, corner_lateral, corner_speed, release_speed])
	# Attempt a new edge while the release is still propelling the board.
	Input.action_press("brake")
	Input.action_press("steer_left")
	for boosted_tick in 20:
		await physics_frame
	expect(rider.boosting and is_zero_approx(rider.carve_charge), "active burst cannot charge another carve")
	Input.action_release("brake")
	Input.action_release("steer_left")
	# The same full input on a straight needs more time and a deeper heading,
	# so the high-efficiency corner line has a measurable spatial advantage.
	rider.reset_to(565.0, 60.0)
	rider.set_active(true)
	for settling_tick in 4:
		await physics_frame
	var straight_heading: float = rider.heading
	Input.action_press("brake")
	Input.action_press("steer_right")
	for straight_tick in 40:
		await physics_frame
	var straight_angle: float = rad_to_deg(absf(rider.heading - straight_heading))
	expect(rider.carve_charge >= 0.9 and straight_angle > corner_angle * 1.5, "straight charging requires a longer and deeper turn than the authored corner")
	print("Straight charge: hold=0.667s charge=%.3f angle=%.2fdeg lateral=%.2fm speed=%.2f" % [rider.carve_charge, straight_angle, rider.lateral, rider.speed])
	Input.action_release("brake")
	Input.action_release("steer_right")
	bursts = 0
	releases.clear()
	falls = 0
	rider.reset_run()
	rider.set_active(true)
	var tick := 0
	var max_lateral := 0.0
	var last_jump := -1.0
	var last_boost := -1.0
	var digital := OS.get_cmdline_user_args().has("--digital")
	var held_strength := 0.0
	while rider.progress < course.length and falls == 0 and tick < 4800:
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_release("brake")
		Input.action_release("jump")
		Input.action_release("boost")
		var look: Vector3 = course.center_at(rider.progress + 12.0) - rider.position
		var desired := atan2(-look.x, -look.z)
		var difference := angle_difference(rider.heading, desired)
		var curvature: float = course.curvature_at(rider.progress)
		var use_carve: bool = rider.is_on_floor() and absf(curvature) > 0.003 and absf(difference) > 0.035
		var rate := 1.25 if use_carve else 0.82
		var strength := clampf(-difference * 5.0 / rate, -1.0, 1.0)
		if digital:
			if tick % 6 == 0:
				held_strength = -signf(difference) if absf(difference) > 0.055 else 0.0
			strength = held_strength
		if strength < 0:
			Input.action_press("steer_left", -strength)
		else:
			Input.action_press("steer_right", strength)
		if use_carve:
			Input.action_press("brake")
		var gap: Vector2 = course.next_gap_at(rider.progress)
		if gap != Vector2.ZERO:
			var ahead: float = gap.x - rider.progress
			if gap.x > 800 and ahead < 22.0 and last_boost != gap.x:
				Input.action_press("boost")
				last_boost = gap.x
			if ahead < 3.0 and ahead >= -0.3 and last_jump != gap.x:
				Input.action_press("jump")
				last_jump = gap.x
		await physics_frame
		tick += 1
		max_lateral = maxf(max_lateral, absf(rider.lateral))
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		Input.action_release(action)
	expect(rider.progress >= course.length and falls == 0, "input-driven rider traverses the complete authored course")
	expect(jumps == 3 and landings == 3, "all three real gaps require and receive a takeoff and landing")
	expect(bursts > 1, "carve releases produce acceleration during traversal")
	expect(clean >= 1, "aligned actual landings return wind")
	expect(tick < 3300, "successful course takes under 55 simulated seconds")
	print("Course run: checks=%d failures=%d time=%.2f progress=%.2f lateral_max=%.2f jumps=%d landings=%d bursts=%d clean=%d falls=%d" % [checks, failures, tick / 60.0, rider.progress, max_lateral, jumps, landings, bursts, clean, falls])
	rider.queue_free()
	course.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
