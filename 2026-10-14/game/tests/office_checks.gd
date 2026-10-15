extends RefCounted
## Exercise the generated level, rather than a replacement test room.

const Office = preload("res://scripts/office.gd")
const Player = preload("res://scripts/player.gd")
var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var office := Office.new()
	tree.root.add_child(office)
	office.build()
	await tree.physics_frame
	await tree.physics_frame
	# The first paper pair is on the playable introductory destruction route.
	var contact := Vector3(-0.9, 0.0, 32.0)
	var contact_model: Node3D
	for child in office.get_children():
		if child is Node3D and child.global_position.is_equal_approx(contact):
			contact_model = child
	_expect(office.try_break(contact, 0.0).is_empty() and office.try_break(contact, 1.0).is_empty(),
		"Idle and slow contact cannot destroy office props")
	var first := office.try_break(contact, 6.0)
	_expect(contact_model != null and not contact_model.debug_snapshot()["intact_visible"], "Impacted wagon leaves its intact pose")
	_expect(first.size() == 1, "A wagon impact begins before its delayed neighbour contacts")
	first.append_array(office.advance_destruction(0.35))
	first.append_array(office.advance_destruction(0.35))
	_expect(first.size() == 3, "A fast wagon impact must transmit to a tower and box")
	var ids := {}
	for event in first:
		_expect(not ids.has(event["id"]), "Contact chain cannot award the same prop twice")
		ids[event["id"]] = true
		_expect(int(event["base"]) > 0 and event.has("progress") and event.has("position")
			and event.has("kind") and event.has("text"), "Destruction supplies the scoring and effects contract")
		_expect(office.try_break(event["position"], 1.5).is_empty(),
			"A destroyed prop stays spent when the chair returns")
	_expect(office.try_break(contact, 6.0).is_empty(), "Repeating an impact cannot produce more damage")
	office.reset_props()
	_expect(contact_model != null and contact_model.debug_snapshot()["intact_visible"], "Retry restores the broken prop visually")
	var restored := office.try_break(contact, 6.0)
	restored.append_array(office.advance_destruction(0.35))
	restored.append_array(office.advance_destruction(0.35))
	var restored_ids := {}
	for event in restored:
		restored_ids[event["id"]] = true
	_expect(ids == restored_ids and not ids.is_empty(), "Retry restores the same finite scoring objects")
	office.reset_props()
	_expect(office.is_goal(office.goal_position + Vector3(2.5, 0, 0))
		and office.is_goal(office.goal_position + Vector3(-2.5, 0, 0)), "Both sides of the open elevator accept the chair")
	_expect(not office.is_goal(office.goal_position + Vector3(4, 0, 0))
		and not office.is_goal(office.goal_position + Vector3(0, 0, 4)), "Passing beside or in front of the elevator cannot finish")
	_expect(_has_chair_route(office), "The intact, furnished office has a chair-width route from spawn into the elevator")
	office.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _has_chair_route(office: Node3D) -> bool:
	# Search actual physics space with the player's safety clearance. This stays
	# independent of office's route data and catches a cabinet closing the course,
	# a prop becoming solid, or an elevator collider blocking its open doorway.
	var shape := CylinderShape3D.new()
	shape.radius = Player.BODY_RADIUS + 0.12
	shape.height = Player.BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	var space := office.get_world_3d().direct_space_state
	var start := Vector2i(roundi(office.spawn_position.x), roundi(office.spawn_position.z))
	var goal := Vector2i(roundi(office.goal_position.x), roundi(office.goal_position.z))
	var frontier: Array[Vector2i] = [start]
	var visited := {start: true}
	var index := 0
	while index < frontier.size():
		var point := frontier[index]
		index += 1
		query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0, point.y) + Player.BODY_CENTER)
		if not space.intersect_shape(query, 1).is_empty():
			continue
		if point == goal:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + direction
			if abs(next.x) <= 8 and next.y >= goal.y and next.y <= start.y and not visited.has(next):
				visited[next] = true
				frontier.append(next)
	return false

func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
