extends RefCounted
## Real mesh/cue behavior, extending the existing capacity and lifetime checks.

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var fx = load("res://scripts/effects.gd").new()
	tree.root.add_child(fx)
	fx.setup()
	fx.set_volumes(0, 0)
	fx.set_process(false)
	var core: MeshInstance3D = fx.get_node("ConnectedRearJet")
	var nodes: int = fx.get_child_count()
	fx.set_exhaust(Vector3(0, 1, 0), Vector3.BACK, true, false, 0.0)
	if not core.visible:
		failures.append("Connected jet responds immediately to spray onset")
	fx._process(0.12)
	var slow: Dictionary = fx.debug_snapshot()
	var diagonal := Vector3(1, 0, 1).normalized()
	fx.set_exhaust(Vector3(0, 1, 0), diagonal, true, true, 10.0)
	fx._process(0.12)
	var fast: Dictionary = fx.debug_snapshot()
	if fast.jet_core_length <= slow.jet_core_length or fast.jet_core_length > 3.0:
		failures.append("Actual speed and rush enlarge the bounded connected core")
	if core.basis.z.normalized().distance_to(diagonal) > 0.001 or not is_equal_approx(core.basis.z.length(), fast.jet_core_length) or absf(core.basis.x.dot(core.basis.z)) > 0.001:
		failures.append("Connected core follows chair rear through steering")
	if core.mesh.get_aabb().position.z < -0.001 or core.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		failures.append("Jet mesh stays behind the nozzle without shadowing the route")
	fx.set_exhaust(Vector3(0, 1, 0), Vector3.RIGHT, false, false)
	fx._process(0.15)
	if core.visible or fx.debug_snapshot().exhaust != 0:
		failures.append("Release retracts the jet within 150 ms and clears old spray fragments")
	fx.set_exhaust(Vector3(10, 1, 0), Vector3.BACK, true, false, 10.0)
	fx.set_exhaust(Vector3(14, 1, 0), Vector3.BACK, true, false, 10.0)
	fx._process(0.1)
	var interpolated := false
	for particle: Dictionary in fx._particles:
		var point: Vector3 = particle.position
		if bool(particle.new) and int(particle.priority) == 0 and point.x > 10.2 and point.x < 13.8:
			interpolated = true
	if not interpolated:
		failures.append("Moving emissions sample the previous/current nozzle segment")
	fx.set_exhaust(Vector3(40, 1, 0), Vector3.BACK, true, false, 10.0)
	fx._process(0.1)
	for particle: Dictionary in fx._particles:
		if int(particle.priority) == 0 and (particle.position as Vector3).x < 39.5:
			failures.append("Teleport/reset cannot bridge a ghost jet from the old nozzle")
			break
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, false, false)
	fx.burst(Vector3.ZERO, 0.6, Vector3.RIGHT, "box")
	var small: Dictionary = fx.debug_snapshot()
	for particle: Dictionary in fx._particles:
		if int(particle.kind) == 3 and (particle.position as Vector3).y < 0.8:
			failures.append("Break star sits above floor clipping behind the lower actor")
		if int(particle.kind) in [1, 2] and (particle.velocity as Vector3).x <= 0.0:
			failures.append("The paper/cube fan carries forward impact momentum")
	fx.burst(Vector3.ZERO, 1.3, Vector3.LEFT, "wagon")
	var large: Dictionary = fx.debug_snapshot()
	if large.cue_star_size <= small.cue_star_size or large.cue_strength <= small.cue_strength:
		failures.append("Impact speed and prop magnitude change the visible contact size")
	if large.cue_direction != [-1.0, 0.0, 0.0] or small.cue_kind != "box" or large.cue_kind != "wagon":
		failures.append("Break cues retain actual heading and prop subtype")
	fx.burst(Vector3.ZERO, 1.0, Vector3.RIGHT, "box")
	var box: Dictionary = fx.debug_snapshot()
	fx.burst(Vector3.ZERO, 1.0, Vector3.RIGHT, "tower")
	var paper: Dictionary = fx.debug_snapshot()
	if float(box.cue_cube_count) / maxf(1.0, box.cue_paper_count) <= float(paper.cue_cube_count) / maxf(1.0, paper.cue_paper_count):
		failures.append("Boxes give a cube-heavy pop while paper towers give a paper fan")
	fx._process(0.8)
	if fx.debug_snapshot().counts.star <= 0:
		failures.append("A slow frame renders the short contact peak once")
	fx._process(0.8)
	if fx.debug_snapshot().counts.star != 0:
		failures.append("The contact peak expires after its one slow birth frame")
	fx.set_quality("控えめ")
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, true, true, 10.0)
	fx._process(0.12)
	var subdued: Dictionary = fx.debug_snapshot()
	if subdued.jet_core_length >= fast.jet_core_length * 0.65 or subdued.jet_core_width >= fast.jet_core_width * 0.65 or subdued.counts.streak != 0:
		failures.append("Subdued keeps a smaller steady jet and removes large streak motion")
	fx.burst(Vector3.ZERO, 1.3, Vector3.RIGHT, "wagon")
	if fx.debug_snapshot().counts.star <= 0 or fx.debug_snapshot().particles > 20:
		failures.append("Subdued retains contact feedback within its 20 fragment budget")
	fx.set_process(true)
	tree.paused = true
	var paused_transform := core.transform
	var paused_clock: float = fx.debug_snapshot().particle_clock
	await tree.create_timer(0.15, true, false, true).timeout
	if core.transform != paused_transform or not is_equal_approx(fx.debug_snapshot().particle_clock, paused_clock):
		failures.append("Pause freezes core pulse/retraction as well as particle clocks")
	tree.paused = false
	fx.set_process(false)
	fx.celebrate(Vector3.ZERO)
	if core.visible or fx.debug_snapshot().exhaust != 0:
		failures.append("Success immediately retires the live jet")
	if fx.get_child_count() != nodes or fx.debug_snapshot().batch_meshes != 7:
		failures.append("Interaction feedback reuses one stable core and seven batch nodes")
	fx.queue_free()
	await tree.process_frame
	return failures
