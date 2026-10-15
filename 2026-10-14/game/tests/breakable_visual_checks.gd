extends RefCounted
## Authored collapse geometry/lifecycle checks; this does not replace a playthrough.
const Breakable := preload("res://scripts/breakable.gd")
var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var stage := Node3D.new()
	tree.root.add_child(stage)
	for kind in ["box", "tower", "wagon"]:
		var prop := Breakable.new()
		stage.add_child(prop)
		prop.position = Vector3(3, 0, -5)
		prop.build(kind, 3)
		_expect(not prop.is_processing() and prop._intact.visible and not prop._motion.visible,
			"Intact " + kind + " shows one shared batch with no ticking clock")
		_expect(prop._intact.mesh.get_surface_count() == 1, "Intact art is one surface")
		_expect(prop.find_children("*", "CollisionObject3D", true, false).is_empty(), "Collapse adds no collision bodies")
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			_expect(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Collapse adds no shadows")
		var origin := prop.position
		var travel := Vector3(1.2, 0, -1.6)
		prop.begin_break(travel.normalized(), travel)
		prop._process(0.35)
		prop.set_process(false)
		_expect(prop.position == origin and not prop._intact.visible and prop._motion.visible,
			"At contact " + kind + " moves visual children and keeps the scoring origin")
		if kind == "wagon":
			var at := prop._motion.position
			_expect(Vector2(at.x, at.z).distance_to(Vector2(travel.x, travel.z)) < 0.001,
				"Wagon visibly arrives at its next contact at exactly 0.35s")
		elif kind == "tower":
			_expect(absf(prop._groups["TowerCrown"].rotation.x) + absf(prop._groups["TowerCrown"].rotation.z) > 0.4,
				"Tower crown visibly bends before falling")
		else:
			_expect(prop._groups["CartonBody"].scale.y < 0.5, "Carton visibly crumples")
		var before := prop.debug_snapshot()
		prop.begin_break(Vector3.RIGHT, Vector3.RIGHT * 10.0)
		_expect(before == prop.debug_snapshot(), "Repeated hit never restarts collapse or changes destination")
		prop.set_process(true)
		tree.paused = true
		before = prop.debug_snapshot()
		await tree.process_frame
		await tree.process_frame
		_expect(before == prop.debug_snapshot(), "Pause freezes actual prop animation clock and geometry")
		tree.paused = false
		prop.set_process(false)
		prop._process(1.0)
		_expect(prop._settled.visible and prop._settled.mesh != null and not prop._motion.visible,
			"Settled " + kind + " retains recognizable authored floor remnants")
		_expect(prop._settled.mesh.get_surface_count() == 1 and not prop.is_processing(), "Resting art returns to one surface without ticking")
		var arrays := prop._settled.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			_expect(vertex.is_finite() and vertex.y > -0.12, "Settled art remains finite and on the floor")
		prop.reset_visual()
		_expect(prop.position == origin and prop._intact.visible and not prop._motion.visible and not prop._settled.visible
			and prop._settled.mesh == null and not prop.is_processing(), "Retry resets all geometry in the same frame")
		for group_name in prop._groups:
			_expect(prop._groups[group_name].transform == prop._starts[group_name], "Retry restores every authored group transform immediately")
		prop.set_feedback_quality("控えめ")
		prop.begin_break(Vector3.FORWARD, Vector3.FORWARD * 2.0)
		prop._process(0.1)
		if kind == "wagon":
			_expect(absf(prop._motion.position.z) < 1.0, "Reduced wagon cannot reach its target before the scheduled contact")
		prop._process(0.25)
		if kind == "wagon":
			_expect(is_equal_approx(prop._motion.position.z, -2.0), "Reduced wagon arrives at the same 0.35s contact")
		prop._process(0.18)
		_expect(prop._settled.visible and not prop.is_processing(), "Reduced motion retains a settled changed shape and floor trace")
		prop.free()
	stage.free()
	return _failures.duplicate()

func _expect(value: bool, description: String) -> void:
	if not value and not _failures.has(description):
		_failures.append(description)
