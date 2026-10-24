extends SceneTree

# Read-only source comparison in the actual Main environment. Only temporary
# duplicated materials and surface overrides change; source textures/mesh stay intact.

func _initialize() -> void:
	_run.call_deferred()

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze(child)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result

func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_freeze(main)
	main.ui.visible = false
	main.camera.current = false
	if main.sound:
		main.sound.set_volume(0.0)
	var rider: CharacterBody3D = main.rider
	var controller: Node = main.assets.pose_controller
	controller.reset_motion()
	controller.set_motion_context(&"idle")
	controller.reduced_motion = true
	controller._apply_pose()
	var meshes := _meshes(controller.model)
	var originals: Array = []
	var material_settings: Array = []
	for mesh in meshes:
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as BaseMaterial3D
			if not material:
				push_error("Comparison requires BaseMaterial3D")
				quit(1)
				return
			originals.append({"mesh": mesh, "surface": index, "material": material})
			material_settings.append({"mesh": mesh.name, "surface": index, "class": material.get_class(),
				"specular_mode": material.specular_mode, "metallic": material.metallic,
				"roughness": material.roughness, "normal_enabled": material.normal_enabled,
				"normal_scale": material.normal_scale, "diffuse_mode": material.diffuse_mode,
				"roughness_texture": material.roughness_texture != null, "metallic_texture": material.metallic_texture != null})
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	main.add_child(camera)
	var output := ProjectSettings.globalize_path("res://../art/source/mio-v2/previews")
	var views := ["face_threequarter", "face_left", "fullbody"]
	var cases := ["A_original", "B_matte_normal035", "C_matte_normal035_toon"]
	var sheet := Image.create(3 * 384, 3 * 384, false, Image.FORMAT_RGB8)
	for row in cases.size():
		for entry in originals:
			var material: BaseMaterial3D = entry.material
			if row > 0:
				material = material.duplicate()
				material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				material.metallic = 0.0
				material.roughness = 1.0
				material.normal_scale = 0.35
				if row == 2:
					material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			entry.mesh.set_surface_override_material(entry.surface, material)
		for column in views.size():
			var center := rider.global_position + Vector3.UP * (1.77 if column < 2 else 1.02)
			camera.size = 0.55 if column < 2 else 2.30
			var offset := Vector3(3.0, 0.03, -2.0)
			if column == 1:
				offset = Vector3(0, 0.02, -4.0)
			elif column == 2:
				offset = Vector3(3.4, 0.2, -2.4)
			camera.global_position = center + offset
			camera.look_at(center)
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(output.path_join("material_%s_%s.png" % [cases[row], views[column]]))
			image.resize(384, 384, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(image, Rect2i(0, 0, 384, 384), Vector2i(column * 384, row * 384))
	sheet.save_png(output.path_join("material-comparison-contact.png"))
	var source := ProjectSettings.globalize_path("res://assets/models/mio.glb")
	var report := {"description": "Temporary runtime material overrides in actual Main scene lighting. Distinct from unmodified raw Blender reference renders.",
		"source": source, "source_sha256": FileAccess.get_sha256(source), "viewport": [768, 768],
		"rows": cases, "columns": views, "original_material_settings": material_settings,
		"B": {"specular_mode": "SPECULAR_DISABLED", "metallic": 0, "roughness": 1, "normal_scale": 0.35, "diffuse_mode": "original"},
		"C": {"specular_mode": "SPECULAR_DISABLED", "metallic": 0, "roughness": 1, "normal_scale": 0.35, "diffuse_mode": "DIFFUSE_TOON"},
		"unchanged": ["geometry", "UVs", "source textures", "skin weights", "game scripts", "source materials"],
		"known_remaining_source_defects": ["adjacent duplicated cloud marks", "coral waist tabs", "fused hair locks", "baked color streaks"]}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../art/source/mio-v2/reports/material-comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATERIAL_COMPARISON: variants=3 views=3 complete")
	quit()
