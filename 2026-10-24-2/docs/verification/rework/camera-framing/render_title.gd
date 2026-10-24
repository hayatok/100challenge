extends SceneTree
const VIEWS := [
	{"id":"previous","offset":Vector3(2.7,1.7,2.6)},
	{"id":"front25","offset":Vector3(3.4,1.5,1.6)},
	{"id":"front18","offset":Vector3(3.6,1.65,1.2)}]
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../docs/verification/rework/camera-framing")
	var main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://camera-title-fixture.json"
	root.add_child(main)
	main.set_process(false)
	main.state = "fixture"
	main.ui.set_screen("title",{})
	main.rider.reset_run()
	main.rider.set_physics_process(false)
	main._set_hazards_active(false)
	var pose = main.assets.pose_controller
	pose.set_process(false)
	main.camera.set_process(false)
	main.sound.set_process(false)
	pose.reset_motion()
	pose.set_motion_context(&"idle")
	var camera: Camera3D = main.camera
	camera.fov = 48.0
	var rows: Array = []
	for view in VIEWS:
		for seconds in [0.0,2.0]:
			pose.reset_motion()
			pose.set_motion_context(&"idle")
			for i in int(seconds*60):
				pose.advance_motion(1.0/60.0)
			var offset: Vector3 = view.offset
			var right := Vector3(-offset.x,0.0,-offset.z).normalized().cross(Vector3.UP)
			camera.position = main.rider.position + offset
			camera.look_at(main.rider.position + Vector3.UP - right * 1.2)
			await process_frame
			await RenderingServer.frame_post_draw
			var name := "title-%s-idle%d.png" % [view.id,int(seconds)]
			root.get_texture().get_image().save_png(output.path_join(name))
			rows.append({"view":view.id,"idle_seconds":seconds,"offset":[offset.x,offset.y,offset.z],"fov":48,"file":name})
	var file := FileAccess.open(output.path_join("title-comparison.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_kind":"Real Main title UI and new character, deterministic idle samples, not gameplay", "model_sha256":FileAccess.get_sha256("res://assets/models/mio.glb"),"body_forward":"world +X","views":rows},"  "))
	file.close()
	print("TITLE_COMPARISON_READY")
	main.queue_free()
	await create_timer(0.2).timeout
	quit()
