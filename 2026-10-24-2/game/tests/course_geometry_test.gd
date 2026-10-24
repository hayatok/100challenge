extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _run() -> void:
	var course = load("res://scripts/course.gd").new()
	root.add_child(course)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = course.get_world_3d().direct_space_state
	for meter in range(-5, 901):
		var s := float(meter) + 0.25
		for offset in [-5.0, 0.0, 5.0]:
			var expected: Vector3 = course.surface_at(s, offset)
			var query := PhysicsRayQueryParameters3D.create(expected + Vector3.UP * 3.0, expected + Vector3.DOWN * 3.0, 2)
			query.hit_back_faces = false
			var hit := space.intersect_ray(query)
			if course.gap_at(s) != Vector2.ZERO:
				expect(hit.is_empty(), "real full-width gap has no hidden safety floor at %.2f" % s)
			else:
				expect(not hit.is_empty(), "road exists at %.2f" % s)
				if not hit.is_empty():
					expect(absf(hit.position.y - expected.y) < 0.025, "rendered road and collision heights agree")
					expect(hit.normal.y > 0.9, "road front faces upward")
	for gap in course.GAPS:
		expect(is_zero_approx(course.launch_height_at(gap.x - 18.0)), "launch ramp begins flush with the approach deck")
		expect(absf(course.launch_height_at(gap.x) - 1.5) < 0.001, "launch lip rises 1.5m on the actual road coordinate")
		expect(is_zero_approx(course.launch_height_at(gap.y)), "virtual gap reference rejoins the landing deck")
		for boundary in [gap.x - 18.0, gap.x, gap.y]:
			var before: Vector3 = course.center_at(boundary - 0.01)
			var after: Vector3 = course.center_at(boundary + 0.01)
			expect(absf(after.y - before.y) < 0.002, "camera reference height remains continuous at ramp and landing boundaries")
	for checkpoint in course.CHECKPOINTS:
		expect(course.gap_at(checkpoint) == Vector2.ZERO, "checkpoint is on solid surface")
		expect(is_equal_approx(course.checkpoint_at(checkpoint + 1.0), checkpoint), "recovery selects preceding authored checkpoint")
	expect(is_equal_approx(course.checkpoint_at(900.0), 785.0), "final recovery gives room to accelerate and jump")
	print("Course geometry: checks=%d failures=%d" % [checks, failures])
	course.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
