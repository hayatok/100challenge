extends Node3D

var loaded_assets := 0
var _models: Dictionary = {}
var pose_controller: Node


func _ready() -> void:
	for id in ["mio", "board", "sentry", "arch", "island"]:
		var path := "res://assets/models/%s.glb" % id
		if ResourceLoader.exists(path):
			var resource = load(path)
			if resource is PackedScene:
				_models[id] = resource
				loaded_assets += 1


func _instance(id: String, height: float, parent: Node3D) -> Node3D:
	if not _models.has(id):
		return null
	var anchor := Node3D.new()
	parent.add_child(anchor)
	var model: Node3D = _models[id].instantiate()
	anchor.add_child(model)
	var box := _bounds(model)
	if box.size.y > 0.001:
		var factor := height / box.size.y
		model.scale *= factor
		model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	return anchor


func attach_rider(rider: Node3D) -> void:
	var avatar := _instance("mio", 1.68, rider.get_node("Visual/Avatar"))
	if avatar:
		avatar.rotation.y = PI / 2.0
		avatar.position.y = 0.30
		_style_character(avatar)
		pose_controller = preload("res://scripts/rider_pose.gd").new()
		pose_controller.model = avatar
		pose_controller.rider = rider
		rider.add_child(pose_controller)
		rider.get_node("Visual/Avatar/BLOCKOUT").visible = false
	var board := _instance("board", 0.14, rider.get_node("Visual/Board"))
	if board:
		var box := _bounds(board)
		var long_edge := maxf(box.size.x, box.size.z)
		if long_edge > 0.001:
			board.scale *= 1.85 / long_edge
		if box.size.x > box.size.z:
			board.rotation.y = PI / 2.0
		board.position.y = 0.05
		rider.get_node("Visual/Board/BLOCKOUT").visible = false


func _style_character(root: Node3D) -> void:
	# The Tripo source remains unchanged. Softer normals and matte toon shading
	# keep the anime face readable without amplifying generated surface noise.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var source = node.get_active_material(surface)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				material.metallic = 0.0
				material.roughness = 1.0
				material.normal_scale = 0.35
				node.set_surface_override_material(surface, material)


func attach_sentry(sentry: Node3D) -> void:
	var model := _instance("sentry", 0.9, sentry.get_node("Model"))
	if model:
		sentry.get_node("Model/BLOCKOUT").visible = false


func decorate_course(course: Node3D) -> void:
	# Five authored beats replace the previous fixed 1650 m scenery grid.
	# Arch bounds at height 10: 8.882 wide, 4.156 deep; the lowest opening
	# is 1.868 m either side of its centre. Anchors are bottom-centred by _instance.
	var supports: Array[Vector2] = [Vector2(48, 17), Vector2(112, 21),
		Vector2(195, 19), Vector2(333, 22), Vector2(408, 17),
		Vector2(482, 20), Vector2(665, 24), Vector2(751, 18), Vector2(880, 22)]
	for index in supports.size():
		var s := supports[index].x
		var height := supports[index].y
		var arch := _instance("arch", height, self)
		if arch:
			arch.name = "AqueductSupport%d" % index
			var center: Vector3 = course.call("center_at", s)
			var tangent: Vector3 = course.call("tangent_at", s)
			var left: Vector3 = course.call("surface_at", s, -1.0)
			var right_edge: Vector3 = course.call("surface_at", s, 1.0)
			var normal := (right_edge - left).cross(tangent).normalized()
			var back := -tangent
			var right := normal.cross(back).normalized()
			# Match the bank and grade so the crown supports the road from
			# underneath rather than cutting through its low edge.
			arch.basis = Basis(right, normal, back)
			arch.position = center - normal * (height + 0.40)
			var road_width := 2.0 * float(course.call("half_width_at", s))
			arch.scale.x = (road_width + 2.0) / (height * 0.8882)
			arch.scale.z = 0.78

	# A distant entry portal and a finish portal frame two clear, straight runs.
	# Opening width includes 2 m clearance on each side of the playable road.
	for entry in [Vector2(168.0, 22.0), Vector2(float(course.get("length")) - 10.0, 20.0)]:
		var gate := _instance("arch", entry.y, self)
		if gate:
			gate.name = "EntryPortal" if entry.x < 200.0 else "FinishPortal"
			gate.position = course.call("center_at", entry.x)
			gate.position.y -= 6.0
			gate.rotation.y = float(course.call("heading_at", entry.x))
			var clear_half_width := float(course.call("half_width_at", entry.x)) + 2.0
			gate.scale.x = clear_half_width / (entry.y * 0.1868)
			gate.scale.z = 0.72
			var right := Vector3(cos(gate.rotation.y), 0.0, -sin(gate.rotation.y))
			# Island terrace area peaks at 0.70-0.75 of its normalized height.
			# Place each portal foot on that stone shelf, below the playable road.
			var foot_offset := clear_half_width * 1.69
			for side in [-1.0, 1.0]:
				var footing := _instance("island", 10.0, self)
				if footing:
					footing.name = "%sFooting%s" % [gate.name, "L" if side < 0.0 else "R"]
					footing.position = gate.position + right * side * foot_offset - Vector3.UP * 7.2
					footing.rotation.y = gate.rotation.y + side * 0.65

	# Garden fragments sit outside the route and below it, exposing why each
	# transfer is open sky. Nothing decorative is offered as a landing platform.
	var gaps: Array = course.get("GAPS")
	for index in gaps.size():
		var gap: Vector2 = gaps[index]
		var side := -1.0 if index % 2 == 0 else 1.0
		var gardens: Array[Vector4] = [
			Vector4(gap.x - 11.0, side, 15.0, 6.0),
			Vector4(gap.x - 3.0, -side, 10.0, 9.0),
			Vector4(gap.y + 9.0, -side, 17.0, 5.0),
			Vector4(gap.y + 24.0, side, 11.0, 10.0)]
		for part in gardens.size():
			var data := gardens[part]
			var island := _instance("island", data.z, self)
			if island:
				island.name = "Gap%dGarden%d" % [index + 1, part + 1]
				var heading := float(course.call("heading_at", data.x))
				var right := Vector3(cos(heading), 0.0, -sin(heading))
				var edge := float(course.call("half_width_at", data.x))
				# Height-normalized island bounds are almost square in plan.
				var lateral := edge + data.z * 0.5 + 8.0 + float(part % 2) * 5.0
				island.position = course.call("center_at", data.x)
				island.position += right * data.y * lateral
				island.position.y -= data.z + data.w
				island.rotation.y = heading + 0.55 + float(index * 4 + part) * 1.17

	# Leave the 565-615 m breather open; two distant asymmetric terraces make
	# the following descent visible without boxing the player into a corridor.
	for data in [Vector4(670.0, -65.0, 50.0, -8.0), Vector4(720.0, 92.0, 66.0, -16.0)]:
		var island := _instance("island", data.z, self)
		if island:
			island.name = "VistaTerrace%d" % int(data.x)
			island.position = course.call("center_at", data.x)
			island.position.x += data.y
			island.position.y -= data.z + data.w
			island.rotation.y = 0.8 if data.y < 0.0 else -0.6


func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var transform: Transform3D = root.global_transform.affine_inverse() * node.global_transform
			var box: AABB = transform * node.get_aabb()
			result = result.merge(box) if initialized else box
			initialized = true
		for child in node.get_children():
			stack.append(child)
	return result
