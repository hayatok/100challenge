extends SceneTree
## Render imported GLBs from three views. Run with a native graphics display.

const AssetLibrary := preload("res://scripts/asset_library.gd")
var output := "res://../docs/verification/v0.4/models/"
var selected := PackedStringArray()
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=").trim_suffix("/") + "/"
		else:
			selected.append(argument)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport = SubViewport.new()
	viewport.size = Vector2i(480, 480)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f5eddf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -30, 0)
	key.light_energy = 0.65
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 145, 0)
	fill.light_energy = 0.25
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 100.0
	stage.add_child(camera)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/modeling/models.json"))
	for entry in manifest["models"]:
		var asset_name: String = entry["name"]
		if not selected.is_empty() and not selected.has(asset_name):
			continue
		var model := AssetLibrary.model(asset_name)
		stage.add_child(model)
		if asset_name == "employee":
			model.find_child("EyesHappy", true, false).hide()
			model.find_child("Tears", true, false).hide()
		var bounds := _bounds(model)
		var center := bounds.get_center()
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.22
		var views := {"front": Vector3(0, 0.08, -1), "side": Vector3(1, 0.08, 0), "back": Vector3(0, 0.08, 1)}
		if asset_name == "elevator":
			views["front"] = Vector3(0, 0.08, 1)
			views["back"] = Vector3(0, 0.08, -1)
		if asset_name == "floor_module":
			views["front"] = Vector3(0, 1, -0.01)
			views["side"] = Vector3(1, 0.65, 0)
			views["back"] = Vector3(0, -1, 0.01)
		for label in views:
			camera.position = center + (views[label] as Vector3).normalized() * 20.0
			camera.look_at(center)
			await process_frame
			await RenderingServer.frame_post_draw
			var error := viewport.get_texture().get_image().save_png(output + asset_name + "-" + label + ".png")
			assert(error == OK, "Failed to save model view")
		model.free()
		print("Rendered imported GLB: ", asset_name)
	viewport.queue_free()
	await process_frame
	quit()

func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var instance := item as MeshInstance3D
		if not instance.is_visible_in_tree():
			continue
		var relative := instance.transform
		var ancestor := instance.get_parent() as Node3D
		while ancestor != model and ancestor != null:
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent() as Node3D
		var bounds: AABB = relative * instance.mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result
