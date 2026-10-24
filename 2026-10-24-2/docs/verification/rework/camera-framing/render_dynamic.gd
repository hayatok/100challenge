extends SceneTree

const CASES := [
	{"id":"straight24","speed":24.0,"start":0.0,"duration":1.25,"turn":false,"air":false,"reduced":false},
	{"id":"straight40","speed":40.0,"start":0.0,"duration":0.80,"turn":false,"air":false,"reduced":false},
	{"id":"turn24","speed":24.0,"start":35.0,"duration":2.0,"turn":true,"air":false,"reduced":false},
	{"id":"turn40","speed":40.0,"start":35.0,"duration":1.35,"turn":true,"air":false,"reduced":false},
	{"id":"air24","speed":24.0,"start":239.0,"duration":1.20,"turn":false,"air":true,"reduced":false},
	{"id":"air40","speed":40.0,"start":232.0,"duration":1.20,"turn":false,"air":true,"reduced":false},
	{"id":"reduced40","speed":40.0,"start":0.0,"duration":0.80,"turn":false,"air":false,"reduced":true}]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../docs/verification/rework/camera-framing")
	var main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://camera-dynamic-fixture.json"
	root.add_child(main)
	main.set_process(false)
	main.state = "fixture"
	main.ui.set_screen("run")
	main._set_hazards_active(false)
	main.rider.set_active(false)
	main.rider.set_physics_process(false)
	main.sound.set_process(false)
	main.effects.set_active(false)
	var rider = main.rider
	var pose = main.assets.pose_controller
	pose.set_process(false)
	var skeleton: Skeleton3D = pose._skeleton
	var head: int = pose._bones.get("headtopend",pose._bones.get("head",pose._bones["neck"]))
	var feet := [int(pose._bones["leftfoot"]),int(pose._bones["rightfoot"])]
	var source := FileAccess.get_file_as_string(output.path_join("follow_camera.pre-velocity.gd.txt"))
	var before_script := GDScript.new()
	before_script.source_code = source
	assert(before_script.reload() == OK)
	var before := Camera3D.new()
	before.set_script(before_script)
	before.rider = rider
	before.course = main.course
	before.far = 1300.0
	main.add_child(before)
	main.camera.set_process(false)
	before.set_process(false)
	var rows: Array = []
	for version in ["before","after"]:
		var camera: Camera3D = before if version == "before" else main.camera
		camera.current = true
		camera.title_view = false
		for spec in CASES:
			camera.set_process(false)
			rider.reset_to(spec.start,60.0)
			rider._active = true
			rider.speed = spec.speed
			rider.boosting = spec.speed == 40.0
			rider.get_node("Visual").rotation = Vector3.ZERO
			pose.reset_motion()
			pose.set_motion_context(&"running")
			for i in 90:
				pose.advance_motion(1.0/60.0)
			rider.reset_physics_interpolation()
			await physics_frame
			await physics_frame
			camera.reduced_motion = spec.reduced
			camera.reset_camera()
			camera.set_process(true)
			var s: float = spec.start
			var start_x: float = main.course.center_at(s).x
			var ticks := int(ceil(spec.duration * 60.0))
			if spec.air:
				pose.trigger_motion(&"jump",1.0)
			for frame in ticks:
				await physics_frame
				var elapsed := float(frame + 1)/60.0
				var tangent: Vector3 = main.course.tangent_at(s)
				s += spec.speed * (-tangent.z if spec.turn else 1.0) / 60.0
				var point: Vector3 = main.course.center_at(s)
				if not spec.turn:
					point.x = start_x
				var rise := maxf(0.10,8.2 * elapsed - 10.0 * elapsed * elapsed) if spec.air else 0.10
				rider.position = point + Vector3.UP * rise
				rider.progress = s
				rider.heading = main.course.heading_at(s) if spec.turn else 0.0
				rider.steer_amount = -0.45 if spec.turn else 0.0
				rider.carving = spec.turn
				rider.carve_amount = rider.steer_amount
				rider.carve_charge = 0.65 if spec.turn else 0.0
				rider.velocity = Vector3(0.0,8.2 - 20.0 * elapsed if rise > 0.10 else 0.0,-spec.speed)
				rider.airborne_time = elapsed if rise > 0.10 else 0.0
				rider.get_node("Visual").rotation = Vector3(0.0,rider.heading,-rider.carve_amount * 0.30)
				pose.advance_motion(1.0/60.0)
				main._update_hud()
				await process_frame
				await RenderingServer.frame_post_draw
				var interpolated: Vector3 = rider.get_global_transform_interpolated().origin
				var world_head := skeleton.get_global_transform_interpolated() * skeleton.get_bone_global_pose(head).origin
				var head_px := camera.unproject_position(world_head)
				var foot_y := -1000.0
				for bone in feet:
					var foot_px := camera.unproject_position(skeleton.get_global_transform_interpolated() * skeleton.get_bone_global_pose(bone).origin)
					foot_y = maxf(foot_y,foot_px.y)
				var offset: Vector3 = camera.global_position-interpolated
				var row := {"version":version,"case":spec.id,"speed":spec.speed,"frame":frame,"time":elapsed,
					"s":s,"horizontal_camera_distance":Vector2(offset.x,offset.z).length(),
					"head_to_foot_fraction":(foot_y-head_px.y)/720.0,"head_px":[head_px.x,head_px.y],
					"foot_y":foot_y,"fov":camera.fov,"roll":camera.rotation.z}
				if frame % 12 == 11 or frame == ticks-1:
					var bounds := board_bounds(rider.get_node("Visual/Board"),camera)
					row["board_hud_intersection"] = bounds.intersects(Rect2(395,576,490,120))
					row["board_hud_margin_px"] = 576.0-bounds.end.y
				if frame == ticks-1 or (spec.air and frame==23):
					var name := "dynamic-%s-%s-%03d.png" % [version,spec.id,frame+1]
					root.get_texture().get_image().save_png(output.path_join(name))
					row["image"] = name
				rows.append(row)
			camera.set_process(false)
	var final_camera: Camera3D = main.camera
	final_camera.current = true
	final_camera.set_process(true)
	rider.reset_to(600.0,60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var reset_offset: Vector3 = final_camera.global_position-rider.global_position
	var reset_distance := Vector2(reset_offset.x,reset_offset.z).length()
	assert(absf(reset_distance-final_camera.follow_distance) < 0.01)
	var paused_transform := final_camera.global_transform
	paused = true
	for i in 3:
		await process_frame
	assert(final_camera.global_transform.is_equal_approx(paused_transform))
	paused = false
	final_camera.set_process(false)
	var record := {"evidence_kind":"Explicit moving trajectory fixture in real Main/world/UI; not player-input gameplay or a manual completion", "viewport":[1280,720],
		"interpolation":"Rider retains production physics interpolation. Driver updates the real rider on consecutive physics ticks; camera runs its normal per-render _process.",
		"reset_horizontal_distance":reset_distance,"pause_camera_unchanged":true,"cases":CASES,"camera_sha256":FileAccess.get_sha256("res://scripts/follow_camera.gd"),
		"before_sha256":FileAccess.get_sha256(output.path_join("follow_camera.pre-velocity.gd.txt")),
		"model_sha256":FileAccess.get_sha256("res://assets/models/mio.glb"),"head_bone":skeleton.get_bone_name(head),"samples":rows}
	var file := FileAccess.open(output.path_join("dynamic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"  "))
	file.close()
	print("CAMERA_DYNAMIC_READY samples=",rows.size())
	main.queue_free()
	await create_timer(0.2).timeout
	quit()

func board_bounds(board_root: Node3D,camera: Camera3D) -> Rect2:
	var result := Rect2()
	var started := false
	for child in board_root.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := camera.unproject_position(mesh.get_global_transform_interpolated()*vertex)
				if started:
					result = result.expand(point)
				else:
					result = Rect2(point,Vector2.ZERO)
					started = true
	return result
