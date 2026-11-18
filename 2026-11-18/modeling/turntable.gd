extends SceneTree
## Import the chosen release's game with --headless --editor --import, then run:
## godot --path GAME --script /absolute/path/to/turntable.gd -- /absolute/output 01
## Omit racer IDs after the output directory to capture the full cast.

const Racer := preload("res://racers/RacerVisual.gd")
const Wharf := preload("res://course/Course.tscn")
const HarborRace := preload("res://HarborRace.tscn")
const TILE := Vector2i(256, 320)
const GRID := 4
const TARGET := Vector3(0.0, 0.80, 0.0)
const CLOCK := 1.38
const RUN_PHASE := 0.19

var stage: SubViewport
var camera: Camera3D


func _initialize() -> void:
	capture.call_deferred()


func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path() or DisplayServer.get_name() == "headless":
		fail("Use a graphical Godot instance and supply an absolute output directory.")
		return
	var output: String = args[0]
	var racers := args.slice(1) if args.size() > 1 else PackedStringArray(["01", "02", "03", "04", "05", "06"])
	for racer_id in racers:
		if not racer_id.is_valid_int() or not racer_id.to_int() in range(1, 7):
			fail("Racer IDs must be between 01 and 06.")
			return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create output directory: " + output)
		return

	stage = SubViewport.new()
	stage.size = TILE * 2
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	if not add_wharf_lighting():
		return
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 1.86
	camera.far = 16.0
	stage.add_child(camera)
	camera.make_current()

	# Dynamic dispatch preserves the v0.2 pose API and each release's material setup.
	var figure: Node3D = Racer.new()
	stage.add_child(figure)
	for racer_id in racers:
		var index := racer_id.to_int() - 1
		figure.call("setup", index)
		for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			mesh.set_layer_mask_value(2, true)
		if figure.has_method("light_for_course"):
			figure.call("light_for_course", false)
		for pose_name in ["idle", "run"]:
			sample_pose(figure, pose_name)
			for view in ["level", "high"]:
				var file := output.path_join("%02d-%s-%s.webp" % [index + 1, pose_name, view])
				if not await capture_orbit(figure, file, 0.0 if view == "level" else 28.0):
					return
	quit()


func add_wharf_lighting() -> bool:
	var world := WorldEnvironment.new()
	if not add_light(Wharf, &"HarborSky", world):
		return false
	# Keep the game's sky radiance for lighting, with no scenery behind the model.
	world.environment = world.environment.duplicate()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0, 0, 0, 0)
	return (add_light(Wharf, &"Sun", DirectionalLight3D.new())
		and add_light(HarborRace, &"PortraitFill", DirectionalLight3D.new()))


func add_light(scene: PackedScene, node_name: StringName, light: Node) -> bool:
	# Read the authored lighting without creating the course, HUD, or race effects.
	var state := scene.get_state()
	for index in state.get_node_count():
		if state.get_node_name(index) != node_name:
			continue
		for prop in state.get_node_property_count(index):
			light.set(state.get_node_property_name(index, prop), state.get_node_property_value(index, prop))
		stage.add_child(light)
		return true
	light.free()
	fail("Missing lighting node %s in %s" % [node_name, scene.resource_path])
	return false


func sample_pose(figure: Node3D, pose_name: String) -> void:
	if figure.has_method("reset_performance"):
		figure.call("reset_performance")
	if figure.has_method("race_pose"):
		var runner := {"state": pose_name, "phase": RUN_PHASE, "elapsed": 0.0, "steer": 0.0}
		figure.call("race_pose", runner, CLOCK, CLOCK, 0.0, false)
	else:
		figure.call("pose", pose_name, 0.0, RUN_PHASE, 0.0)


func capture_orbit(figure: Node3D, file: String, elevation_degrees: float) -> bool:
	var sheet := Image.create_empty(TILE.x * GRID, TILE.y * GRID, false, Image.FORMAT_RGBA8)
	var rect := Rect2i(Vector2i.ZERO, TILE)
	var elevation := deg_to_rad(elevation_degrees)
	for frame in GRID * GRID:
		# The character faces -Z. Viewed from +X at frame 4, its right side faces the camera.
		var azimuth := TAU * float(frame) / float(GRID * GRID)
		var direction := Vector3(cos(elevation) * sin(azimuth), sin(elevation), -cos(elevation) * cos(azimuth))
		camera.position = TARGET + 4.0 * direction
		camera.look_at(TARGET)
		if figure.has_method("face_camera"):
			figure.call("face_camera", camera.position, CLOCK)
		for draw in 2:
			await RenderingServer.frame_post_draw
		var tile := stage.get_texture().get_image()
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		var bounds := tile.get_used_rect()
		if not bounds.has_area() or not rect.grow(-2).encloses(bounds):
			fail("Empty or clipped image at frame %d of %s: %s" % [frame, file, bounds])
			return false
		@warning_ignore("integer_division")
		var cell := Vector2i(frame % GRID, frame / GRID)
		sheet.blit_rect(tile, rect, cell * TILE)
	if sheet.save_webp(file, true, 0.82) != OK:
		fail("Cannot save " + file)
		return false
	print(file)
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)
