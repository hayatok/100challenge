extends SceneTree
## Fixed runtime poses, not through-play. Run with a native display and Dummy audio.

const OUTPUT := "res://../docs/verification/v0.6/staged-colleagues"
const Office = preload("res://scripts/office.gd")
const Colleague = preload("res://scripts/colleague.gd")
const Actor = preload("res://scripts/actor.gd")

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var report := {"kind": "fixed-time native runtime poses; not input through-play", "camera_offset": [6.4, 9.3, 8.6], "normal_contact": [2, 0, 10]}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("f2bf8c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4e5")
	env.ambient_light_energy = 0.38
	var world = WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key = DirectionalLight3D.new()
	key.light_color = Color("fff0d9")
	key.light_energy = 0.35
	key.rotation_degrees = Vector3(-52,-28,0)
	stage.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.light_color = Color("beddd9")
	fill.light_energy = 0.12
	fill.rotation_degrees = Vector3(-35,140,0)
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 46
	stage.add_child(camera)
	camera.position = Vector3(3.6,3.1,-5.5)
	camera.look_at(Vector3(0,1.55,0))
	var colleague = Colleague.new()
	stage.add_child(colleague)
	colleague.build("Coworker_00")
	colleague.set_process(false)
	await snap("closeup-sleepy")
	colleague.react(Vector3(3,0,-4),2,.05)
	colleague._process(.4)
	report["closeup_strong"] = colleague.debug_snapshot()
	await snap("closeup-startled")
	colleague.set_feedback_quality("控えめ")
	report["closeup_subdued"] = colleague.debug_snapshot()
	await snap("closeup-subdued")
	colleague.queue_free()
	await process_frame
	var office = Office.new()
	stage.add_child(office)
	office.build()
	for person in office.get("_colleagues"):
		person.set_process(false)
	var impact = Vector3(2,0,10)
	camera.position = impact+Vector3(6.4,9.3,8.6)
	camera.look_at(impact+Vector3(0,.8,-4.5))
	var actor = Actor.new()
	stage.add_child(actor)
	actor.position = impact
	actor.rotation.y = -0.7
	actor.build()
	actor.update_pose(.2,7,0,true,.2,false,false)
	await snap("normal-before")
	var events = office.try_break(impact,8)
	report["normal_result"] = office.react_to_breaks(events,impact,8)
	for person in office.get("_colleagues"):
		person._process(.4)
	report["normal_snapshot"] = office.debug_feedback_snapshot()
	await snap("normal-reaction")
	var out = FileAccess.open(OUTPUT + "/report.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "))
	quit()

func snap(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT + "/"+label+".png")
	print("Rendered ",label)
