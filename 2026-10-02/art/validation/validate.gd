extends SceneTree
func _initialize():
	var files = ["enemy_walker", "enemy_crawler", "enemy_beacon", "boss_relay", "relay_cabinet", "hazard_gate", "conduit_bundle"]
	var report = []
	var failures = 0
	for file in files:
		var resource = load("res://models/" + file + ".glb") as PackedScene
		if resource == null:
			push_error("FAILED_LOAD " + file)
			failures += 1
			continue
		var model = resource.instantiate() as Node3D
		root.add_child(model)
		var meshes = model.find_children("*", "MeshInstance3D", true, false)
		var surfaces = 0
		var verts = 0
		var emission_surfaces = 0
		for item in meshes:
			for surface in range(item.mesh.get_surface_count()):
				surfaces += 1
				verts += item.mesh.surface_get_array_len(surface)
				var material = item.mesh.surface_get_material(surface)
				if material is StandardMaterial3D and material.emission_enabled:
					emission_surfaces += 1
		var entry = {"asset": file, "loaded": true, "mesh_nodes": meshes.size(), "material_surfaces": surfaces, "exported_vertices": verts, "emissive_surfaces": emission_surfaces}
		report.append(entry)
		print("PASS ", JSON.stringify(entry))
		model.queue_free()
	var out = FileAccess.open("res://godot_import_report.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"engine": Engine.get_version_info(), "assets": report, "failures": failures}, "\t"))
	quit(0 if failures == 0 else 1)
