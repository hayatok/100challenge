extends RefCounted

# Batch rigid scenery by material within each stretch of the quay. Retain the
# original physics bodies. Shutters and cargo need their own moving mesh.
static func batch(harbor: Node3D) -> void:
	var rooms := {}
	for body in harbor.get_children():
		if not body is StaticBody3D or body.get_script() != null or body.has_meta("animated"):
			continue
		if body.get_child_count() == 0: continue
		var visual := body.get_child(0) as MeshInstance3D
		if visual == null or not visual.mesh is BoxMesh: continue
		var material := visual.material_override as StandardMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var room := floori(-body.position.z / 18.0)
		if not rooms.has(room): rooms[room] = {}
		var by_material: Dictionary = rooms[room]
		if not by_material.has(material): by_material[material] = []
		by_material[material].append(visual)
	for room in rooms.values():
		for material in room:
			var visuals: Array = room[material]
			if visuals.size() < 4: continue
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			for visual: MeshInstance3D in visuals:
				var body := visual.get_parent() as Node3D
				surface.append_from(visual.mesh,0,body.transform * visual.transform)
				body.remove_child(visual)
				visual.queue_free()
			var batch_mesh := MeshInstance3D.new()
			batch_mesh.mesh = surface.commit()
			harbor.add_child(batch_mesh)
