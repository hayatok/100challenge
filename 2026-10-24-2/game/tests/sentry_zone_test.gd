extends SceneTree

const SENTRIES: Array[float] = [340.0, 690.0]
var _course: Node3D
var _rider: CharacterBody3D
var _checks: int = 0
var _failures: int = 0
var _hit_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 64
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	_course = Node3D.new()
	_course.set_script(load("res://scripts/course.gd"))
	root.add_child(_course)
	_rider = load("res://scenes/rider.tscn").instantiate()
	_rider.course = _course
	root.add_child(_rider)
	# Hold a real collision body still while testing positions, not its locomotion.
	_rider.cruise_speed = 0.0
	_rider.downhill_speed = 0.0
	_rider.reset_run()
	_rider.set_active(true)
	await _frames(100)
	for index in SENTRIES.size():
		var sentry := Node3D.new()
		sentry.set_script(load("res://scripts/sentry.gd"))
		sentry.course = _course
		sentry.rider = _rider
		sentry.s = SENTRIES[index]
		sentry.side = -1.0 if index % 2 == 0 else 1.0
		sentry.event_id = "zone_test_%d" % index
		root.add_child(sentry)
		sentry.set_physics_process(false)
		sentry.hit.connect(func(): _hit_count += 1)
		var warning: MeshInstance3D = sentry.get("_warn")
		var arrays: Array = warning.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		_expect(vertices.size() >= 102, "sentry %d warning follows tessellated road" % index)
		var space := _course.get_world_3d().direct_space_state
		# Check actual road collision under every warning vertex. Move just inside
		# the road edge to avoid ray/triangle edge ambiguity in the physics engine.
		for local_vertex in vertices:
			var world_vertex: Vector3 = warning.global_transform * local_vertex
			var progress := -world_vertex.z
			var center: Vector3 = _course.center_at(progress)
			var inset_x := move_toward(world_vertex.x, center.x, 0.02)
			var ray_origin := Vector3(inset_x, world_vertex.y + 0.3, world_vertex.z)
			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + Vector3.DOWN * 0.6, 2)
			query.hit_back_faces = false
			var hit := space.intersect_ray(query)
			_expect(not hit.is_empty(), "sentry %d warning vertex has road underneath" % index)
			if not hit.is_empty():
				var clearance: float = world_vertex.y - hit.position.y
				_expect(clearance > 0.04 and clearance < 0.07, "sentry %d warning follows curved/banked road height" % index)
		# Compare rendered triangles to the real predicate at all cross sections,
		# including centers, both sides of the inner edge and the changing outer edge.
		for ds in [-8.6, -8.25, -4.0, 0.0, 4.0, 8.25, 8.6]:
			var progress: float = sentry.s + ds
			var width: float = _course.half_width_at(progress)
			for offset in [0.0, -0.3, 0.3, sentry.side * -0.81, sentry.side * -0.79, sentry.side * (width - 0.05), sentry.side * (width + 0.05)]:
				var point: Vector3 = _course.surface_at(progress, offset)
				var expected: bool = absf(ds) < 8.5 and sentry.side * offset > -0.8 and sentry.side * offset <= width
				var physical: bool = sentry.is_position_in_zone(point)
				var visible := _mesh_contains(warning, vertices, point)
				_expect(physical == expected, "sentry %d world position agrees with endangered cross section" % index)
				_expect(visible == physical, "sentry %d visible stripe and physical zone agree at s=%.3f x=%.3f" % [index, progress, offset])
		# Use real grounded CharacterBody positions, including the former center
		# ambiguity and both dangerous edges, and observe the actual hit signal.
		for offset in [0.0, -0.3, 0.3, sentry.side * -0.6, sentry.side * (_course.half_width_at(sentry.s) - 0.1)]:
			_rider.reset_to(sentry.s, 60.0)
			_rider.set_active(true)
			_rider.global_position = _course.surface_at(sentry.s, offset) + Vector3.UP * 0.05
			_rider.velocity = Vector3.ZERO
			await _frames(95)
			_expect(_rider.is_on_floor(), "sentry %d physical sample is really grounded" % index)
			sentry.reset_run()
			sentry.active = true
			sentry.armed = true
			sentry.elapsed = 1.69
			var hits_before := _hit_count
			sentry.call("_physics_process", 0.0)
			_expect(_hit_count == hits_before, "sentry %d cannot hit before 1.7-second telegraph" % index)
			sentry.call("_physics_process", 0.02)
			var should_hit: bool = sentry.side * offset > -0.8
			_expect((_hit_count == hits_before + 1) == should_hit, "sentry %d grounded collision matches visible side at offset %.3f" % [index, offset])
			sentry.active = false
		print("Sentry zone %d: s=%.0f side=%+.0f vertices=%d center and inner/outer-edge checks complete" % [index, sentry.s, sentry.side, vertices.size()])
		sentry.queue_free()
		await process_frame
	_rider.set_active(false)
	_rider.queue_free()
	_course.queue_free()
	await process_frame
	print("Sentry zones: %d checks, %d failures, %d accepted physical hits" % [_checks, _failures, _hit_count])
	quit(0 if _failures == 0 else 1)


func _mesh_contains(warning: MeshInstance3D, vertices: PackedVector3Array, point: Vector3) -> bool:
	var projected := Vector2(point.x, point.z)
	for index in range(0, vertices.size(), 3):
		var triangle := PackedVector2Array()
		for corner in 3:
			var vertex: Vector3 = warning.global_transform * vertices[index + corner]
			triangle.append(Vector2(vertex.x, vertex.z))
		if Geometry2D.is_point_in_polygon(projected, triangle):
			return true
	return false
