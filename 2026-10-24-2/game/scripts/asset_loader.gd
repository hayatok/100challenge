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


func attach_sentry(sentry: Node3D) -> void:
	var model := _instance("sentry", 0.9, sentry.get_node("Model"))
	if model:
		sentry.get_node("Model/BLOCKOUT").visible = false


func decorate_course(course: Node3D) -> void:
	for index in range(19):
		var s := 45.0 + index * 85.0
		var arch := _instance("arch", 11.0, self)
		if arch:
			arch.position = course.call("center_at", s)
			arch.position.x += 22.0 if index % 2 else -22.0
			arch.position.y -= 10.5
	for index in range(24):
		var s := index * 76.0
		var island := _instance("island", 13.0 + float(index % 3) * 3.0, self)
		if island:
			island.position = course.call("center_at", s)
			island.position.x += (52.0 + float(index % 4) * 14.0) * (-1.0 if index % 2 else 1.0)
			island.position.y -= 19.0 + float(index % 5) * 4.0
			island.rotation.y = index * 1.3
	var finish := _instance("arch", 22.0, self)
	if finish:
		finish.position = course.call("center_at", course.get("length"))
		finish.position.y -= 1.0
		finish.scale.x = 1.8
		var tangent: Vector3 = course.call("tangent_at", course.get("length"))
		finish.rotation.y = atan2(-tangent.x, -tangent.z)


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
