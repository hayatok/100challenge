extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := Node3D.new()
	course.set_script(load("res://scripts/course.gd"))
	root.add_child(course)
	await physics_frame
	await physics_frame
	var space := course.get_world_3d().direct_space_state
	for s in [-5.0, 0.0, 64.0, 330.0, 700.0, 999.0, 1400.0, 1650.0]:
		_check_height(course, space, s, 0.0, 0.0)
		_check_height(course, space, s, 5.0, 0.0)
	# Upper ramps merge continuously; both openings expose the lower road.
	for s in [340.0, 370.0, 400.0, 450.0, 464.0, 475.0, 590.0, 620.0,
		960.0, 990.0, 1030.0, 1070.0, 1084.0, 1095.0, 1210.0, 1240.0]:
		var rise := 0.0
		if (s >= 340.0 and s <= 620.0) or (s >= 960.0 and s <= 1240.0):
			var span_start := 340.0 if s < 900.0 else 960.0
			rise = 2.0 * smoothstep(span_start, span_start + 60.0, s)
			rise *= 1.0 - smoothstep(span_start + 220.0, span_start + 280.0, s)
		if is_equal_approx(s, 464.0) or is_equal_approx(s, 1084.0):
			rise = 0.0
		_check_height(course, space, s, -3.75, rise)
	# One-metre sampling also catches holes at collision chunk boundaries.
	for s in range(1, 1650):
		_check_height(course, space, float(s) + 0.25, 4.0, 0.0)
	var visuals := 0
	var bodies := 0
	for child in course.get_children():
		if child is MeshInstance3D:
			visuals += 1
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			_expect(normals[0].y > 0.9, "Mesh normal must face upward: " + child.name)
		if child is StaticBody3D:
			bodies += 1
			_expect(child.collision_layer == 2 and child.collision_mask == 1, "Collision bitfields")
	_expect(visuals == 3, "Only three visual mesh batches")
	_expect(bodies == 27, "64m collision chunks including safety extensions")
	_expect(is_equal_approx(course.call("checkpoint_at", 329.0), 5.0), "First checkpoint")
	_expect(is_equal_approx(course.call("checkpoint_at", 330.0), 335.0), "Next checkpoint")
	_expect(is_equal_approx(course.call("checkpoint_at", 1800.0), 1640.0), "Checkpoint clamps")
	print("Course geometry: 1681 raycasts, %d mesh batches, %d collision chunks, %d failures" % [visuals, bodies, _failures])
	course.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check_height(course: Node3D, space: PhysicsDirectSpaceState3D,
		s: float, lateral: float, rise: float) -> void:
	var center: Vector3 = course.call("center_at", s)
	var expected := center + Vector3(lateral, lateral * tan(0.1 * sin(s / 100.0)) + rise, 0.0)
	var query := PhysicsRayQueryParameters3D.create(expected + Vector3.UP * 8.0, expected + Vector3.DOWN * 8.0, 2)
	query.hit_back_faces = false
	var hit := space.intersect_ray(query)
	_expect(not hit.is_empty(), "Road ray at s=%.2f lateral=%.2f" % [s, lateral])
	if not hit.is_empty():
		var position: Vector3 = hit["position"]
		_expect(absf(position.y - expected.y) < 0.012, "Height mismatch s=%.2f: %.4f vs %.4f" % [s, position.y, expected.y])
		var normal: Vector3 = hit["normal"]
		_expect(normal.y > 0.9, "Collision front must face upward")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
