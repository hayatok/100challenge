extends SceneTree

const POINTS := [30.0, 85.0, 240.0, 250.0, 535.0, 830.0, 860.0]
const CANDIDATES := [
	{"id": "before", "distance": 5.9, "height": 2.65, "fov": 67.0, "gaze": 0.8, "air_follow": 0.58, "speed_distance": 0.65},
	{"id": "near_40", "distance": 4.0, "height": 1.7, "fov": 60.0, "gaze": -0.4, "air_follow": 0.75, "speed_distance": 0.0},
	{"id": "near_42", "distance": 4.2, "height": 1.85, "fov": 61.0, "gaze": -0.4, "air_follow": 0.75, "speed_distance": 0.0},
	{"id": "near_45", "distance": 4.5, "height": 2.0, "fov": 62.0, "gaze": -0.4, "air_follow": 0.75, "speed_distance": 0.0}]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../docs/verification/rework/camera-framing")
	var main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://camera-framing-fixture.json"
	root.add_child(main)
	main.set_process(false)
	main.state = "fixture"
	main.ui.set_screen("run")
	main.rider.set_active(false)
	main.rider.set_physics_process(false)
	main._set_hazards_active(false)
	main.sound.set_process(false)
	var pose = main.assets.pose_controller
	pose.set_process(false)
	var camera: Camera3D = main.camera
	camera.title_view = false
	camera.set_process(false)
	var skeleton: Skeleton3D = pose._skeleton
	var head_id: int = pose._bones.get("headtopend", pose._bones.get("head", pose._bones["neck"]))
	var feet := [int(pose._bones["leftfoot"]), int(pose._bones["rightfoot"])]
	var cases: Array = []
	for candidate in CANDIDATES:
		for s in POINTS:
			var airborne: bool = s in [250.0, 535.0, 830.0]
			var rise := 1.3 if airborne else 0.1
			var rider = main.rider
			var center: Vector3 = main.course.center_at(s)
			rider.position = center + Vector3.UP * rise
			rider.progress = s
			rider.lateral = 0.0
			rider.heading = main.course.heading_at(s)
			rider.speed = 26.0
			rider.boosting = false
			rider.carving = s == 85.0
			rider.carve_charge = 0.7 if rider.carving else 0.0
			rider.carve_amount = 0.6 if rider.carving else 0.0
			rider.steer_amount = rider.carve_amount
			rider._active = true
			rider.velocity.y = 1.0 if airborne else 0.0
			rider.get_node("Visual").rotation = Vector3(0.0, rider.heading, -rider.carve_amount * 0.30)
			rider.reset_physics_interpolation()
			pose.reset_motion()
			pose.set_motion_context(&"running")
			for i in 90:
				pose.advance_motion(1.0 / 60.0)
			main._update_hud()
			var forward := Vector3(-sin(rider.heading), 0.0, -cos(rider.heading))
			var ratio := clampf((rider.speed - 18.0) / 20.0, 0.0, 1.0)
			camera.position = rider.position - forward * (candidate.distance + ratio * candidate.speed_distance)
			camera.position.y = center.y + candidate.height + rise * candidate.air_follow
			var path_target: Vector3 = main.course.center_at(s + 19.0 + ratio * 4.0)
			var target: Vector3 = (rider.position + forward * 19.0).lerp(path_target, 0.27)
			target.y = lerpf(center.y, path_target.y, 0.72) + candidate.gaze + rise * 0.18
			camera.look_at(target)
			camera.fov = candidate.fov
			await process_frame
			await RenderingServer.frame_post_draw
			var head: Vector2 = camera.unproject_position(skeleton.to_global(skeleton.get_bone_global_pose(head_id).origin))
			var foot0: Vector2 = camera.unproject_position(skeleton.to_global(skeleton.get_bone_global_pose(feet[0]).origin))
			var foot1: Vector2 = camera.unproject_position(skeleton.to_global(skeleton.get_bone_global_pose(feet[1]).origin))
			var foot: Vector2 = foot0 if foot0.y > foot1.y else foot1
			var board: Vector2 = camera.unproject_position(rider.to_global(Vector3(0,0.05,0)))
			var hud_rect := Rect2(395,576,490,120)
			var file := "%s-%03d.png" % [candidate.id, int(s)]
			root.get_texture().get_image().save_png(output.path_join(file))
			var gap: Vector2 = main.course.next_gap_at(s)
			var landing := Vector2.ZERO
			if gap != Vector2.ZERO:
				landing = camera.unproject_position(main.course.center_at(gap.y + 5.0))
			cases.append({"candidate":candidate.id,"s":s,"airborne_fixture":airborne,
				"head_px":vec2(head),"feet_px":[vec2(foot0),vec2(foot1)],
				"head_to_foot_fraction":(foot.y-head.y)/720.0,"board_px":vec2(board),
				"board_overlaps_center_hud":hud_rect.has_point(board),
				"next_gap_landing_px":vec2(landing),"file":file})
	var report := {"evidence_kind":"Deterministic rendering fixture, not human playtesting", "viewport":[1280,720],
		"model":"Current game/assets/models/mio.glb; adoption is not assessed", "head_metric":"Skeleton HeadTop_End to lowest projected foot joint; excludes hair and sole thickness",
		"camera_sha256":FileAccess.get_sha256("res://scripts/follow_camera.gd"), "model_sha256":FileAccess.get_sha256("res://assets/models/mio.glb"), "head_bone":skeleton.get_bone_name(head_id), "candidates":CANDIDATES,"cases":cases}
	var file := FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("CAMERA_COMPARISON_READY cases=",cases.size())
	main.queue_free()
	await create_timer(0.2).timeout
	quit()

func vec2(v: Vector2) -> Array:
	return [v.x,v.y]
