extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("506b7c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4dfef")
	environment.ambient_light_energy = 0.8
	var sky := WorldEnvironment.new()
	sky.environment = environment
	world.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.0
	world.add_child(sun)
	var rider: CharacterBody3D = load("res://scenes/rider.tscn").instantiate()
	world.add_child(rider)
	rider.set_physics_process(false)
	var loader: Node3D = load("res://scripts/asset_loader.gd").new()
	world.add_child(loader)
	loader.attach_rider(rider)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("/Users/hayatok/Downloads/cloudsea-mio-v2-rigged-source.glb", state)
	if error != OK:
		push_error("Raw model load failed: " + str(error))
		quit(1)
		return
	var raw_model := document.generate_scene(state)
	var anchor := Node3D.new()
	rider.get_node("Visual/Avatar").add_child(anchor)
	anchor.add_child(raw_model)
	var box: AABB = loader._bounds(raw_model)
	var factor := 1.68 / box.size.y
	raw_model.scale *= factor
	raw_model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	anchor.rotation.y = PI / 2.0
	anchor.position.y = 0.30
	var controller: Node = loader.pose_controller
	var old_anchor: Node3D = controller.model
	controller.setup(anchor, rider)
	old_anchor.queue_free()
	controller.set_process(false)
	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(2.7, 1.8, 2.9)
	camera.fov = 40
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.97, 0))
	var output := ProjectSettings.globalize_path("res://../art/source/mio-v2/previews")
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute("/tmp/cloudsea-new-motion-frames")
	var samples: Array = []
	var clips := ["idle", "start", "boost_start", "jump", "land", "hit", "finish", "carve"]
	var timings := [0.0, 0.08, 0.16, 0.28, 0.44, 0.70]
	var contact := Image.create(6 * 320, clips.size() * 320, false, Image.FORMAT_RGB8)
	var max_error := 0.0
	for row in clips.size():
		var clip: String = clips[row]
		for column in 6:
			controller.reset_motion()
			controller.set_motion_context(&"idle" if clip == "idle" else &"running")
			controller._stance_weight = 0.0 if clip == "idle" else 1.0
			var sample_time: float = timings[column]
			if clip == "idle":
				sample_time = column * 1.15
				controller._elapsed = sample_time
			elif clip == "carve":
				var edge: float = [-1, -0.6, 0.0, 0.6, 1, 0][column]
				controller._steer = edge
				controller._shoulder_steer = edge
				controller._arm_steer = edge * 0.8
				controller._carve = absf(edge)
				controller._gaze_weight = 1.0
			else:
				if clip == "jump":
					sample_time = [0, 0.09, 0.27, 0.52, 0.76, 1.0][column]
					controller._air = 1.0 if column > 0 else 0.0
				elif clip == "finish":
					sample_time = column * 0.34
				controller.trigger_motion(StringName(clip))
				controller._events[StringName(clip)]["time"] = sample_time
				controller._gaze_weight = 1.0
				if clip == "boost_start":
					controller._boost = minf(1, sample_time * 4.0)
			controller._apply_pose()
			var snapshot: Dictionary = controller.motion_snapshot()
			max_error = maxf(max_error, snapshot.foot_error_leg_ratio)
			for key in ["leftleg", "rightleg", "leftforearm", "rightforearm"]:
				var position: Vector3 = controller._pose_position(key)
				if not position.is_finite():
					failures.append(clip + " nonfinite " + key)
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png("/tmp/cloudsea-new-motion-frames/%s_%02d.png" % [clip, column])
			image.resize(320, 320, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			contact.blit_rect(image, Rect2i(0, 0, 320, 320), Vector2i(column * 320, row * 320))
			samples.append({"clip": clip, "time": sample_time, "snapshot": snapshot})
	contact.save_png(output.path_join("new-motion-contact-sheet.png"))
	# A separate multi-view fixture exposes elbow/knee direction and garment overlap.
	var views := [Vector3(3.8, 1.4, 0), Vector3(0, 1.4, 3.8), Vector3(-3.8, 1.4, 0), Vector3(0, 1.4, -3.8)]
	var cases := ["idle", "run", "boost", "carve_left", "carve_right", "jump_tuck", "land_compress", "finish_hand"]
	var multiview := Image.create(4 * 384, cases.size() * 384, false, Image.FORMAT_RGB8)
	for row in cases.size():
		controller.reset_motion()
		controller.set_motion_context(&"idle" if row == 0 else &"running")
		controller._stance_weight = 0.0 if row == 0 else 1.0
		controller._gaze_weight = 0.0 if row == 0 else 1.0
		if row == 2:
			controller._boost = 1.0
		elif row == 3 or row == 4:
			var steer := -1.0 if row == 3 else 1.0
			controller._steer = steer
			controller._shoulder_steer = steer
			controller._arm_steer = steer
			controller._carve = 1.0
		elif row >= 5:
			var event: StringName = [&"jump", &"land", &"finish"][row - 5]
			controller.trigger_motion(event)
			controller._events[event]["time"] = [0.35, 0.075, 0.7][row - 5]
			controller._air = 1.0 if row == 5 else 0.0
		controller._apply_pose()
		max_error = maxf(max_error, controller._last_foot_error)
		for key in ["leftleg", "rightleg", "leftforearm", "rightforearm"]:
			if not controller._pose_position(key).is_finite():
				failures.append(cases[row] + " nonfinite " + key)
		for column in views.size():
			camera.position = views[column]
			camera.look_at(Vector3(0, 1.0, 0))
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(384, 384, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			multiview.blit_rect(image, Rect2i(0, 0, 384, 384), Vector2i(column * 384, row * 384))
	multiview.save_png(output.path_join("new-motion-multiview.png"))
	var axes: Array = []
	var visual: Node3D = rider.get_node("Visual")
	for heading in [-0.8, 0.0, 0.8]:
		rider.set("heading", heading)
		visual.rotation = Vector3(0, heading, 0)
		controller._update_board_axes()
		var travel: Vector3 = (controller._skeleton.global_basis * controller._travel).normalized()
		var edge: Vector3 = (controller._skeleton.global_basis * controller._edge_right).normalized()
		var expected := Vector3(-sin(heading), 0, -cos(heading))
		var alignment := travel.dot(expected)
		var edge_alignment := edge.dot(expected.cross(Vector3.UP))
		controller.reset_motion()
		controller._stance_weight = 1.0
		controller._apply_pose()
		var neutral_hip: Vector3 = controller._pose_position("hips")
		controller._boost = 1.0
		controller._apply_pose()
		var boost_shift: Vector3 = controller._skeleton.global_basis * (controller._pose_position("hips") - neutral_hip)
		var boost_projection := boost_shift.dot(expected)
		var carve_projections: Array = []
		controller._boost = 0.0
		controller._carve = 1.0
		controller._apply_pose()
		var carve_neutral: Vector3 = controller._pose_position("hips")
		for steer in [-1.0, 1.0]:
			controller._steer = steer
			controller._apply_pose()
			var shift: Vector3 = controller._skeleton.global_basis * (controller._pose_position("hips") - carve_neutral)
			var edge_projection: float = shift.dot(expected.cross(Vector3.UP)) * steer
			carve_projections.append(edge_projection)
			if edge_projection <= 0.01:
				failures.append("carve weight did not move into turning edge")
		axes.append({"heading": heading, "travel_alignment": alignment, "right_edge_alignment": edge_alignment,
			"boost_hip_shift_along_travel": boost_projection, "carve_hip_shift_into_edge": carve_projections})
		if alignment < 0.98 or edge_alignment < 0.98 or boost_projection <= 0.01:
			failures.append("board axes or boost weight disagree with physics heading")
	rider.set("heading", 0.0)
	visual.rotation = Vector3.ZERO
	controller.reset_motion()
	controller.trigger_motion(&"hit")
	controller.advance_motion(0.12)
	controller.reset_motion()
	var reset_snapshot: Dictionary = controller.motion_snapshot()
	if not reset_snapshot.events.is_empty() or reset_snapshot.time != 0.0:
		failures.append("reset leaves motion history")
	controller.set_motion_context(&"running")
	controller.trigger_motion(&"jump")
	controller.advance_motion(0.09)
	controller.trigger_motion(&"land")
	if controller._events.has(&"jump") or not controller._events.has(&"land"):
		failures.append("landing did not replace airborne clip")
	controller.advance_motion(0.075)
	if controller._channels[0] < 0.19:
		failures.append("landing compression missing")
	controller.set_process(true)
	paused = true
	var paused_time: float = controller._elapsed
	for frame in 4:
		await process_frame
	if controller._elapsed != paused_time:
		failures.append("pause advanced motion clock")
	paused = false
	controller.set_process(false)
	controller.reset_motion()
	controller.reduced_motion = true
	controller.set_motion_context(&"idle")
	controller._elapsed = 4.4
	controller._apply_pose()
	if absf(controller._channels[3]) > 0.0001:
		failures.append("reduced motion leaves idle look-around")
	if max_error > 0.002:
		failures.append("feet lost board anchors")
	var report := {"description": "Deterministic raw GLB rig preview, not gameplay approval", "source_sha256": FileAccess.get_sha256("/Users/hayatok/Downloads/cloudsea-mio-v2-rigged-source.glb"), "row_order": clips, "columns": 6,
		"max_foot_error_leg_ratio": max_error, "failures": failures, "samples": samples,
		"reset_snapshot": reset_snapshot, "multiview_rows": cases, "axis_alignment_cases": axes, "rig_has_cloth_or_hair_bones": false, "rig_has_face_morphs": false}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../art/source/mio-v2/reports/new-motion-metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOTION_PREVIEW: samples=", samples.size(), " max_foot_error=", max_error, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
