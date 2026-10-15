extends RefCounted
## Exercise real effect capacity, priority and render lifetime, without audio.

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var fx = load("res://scripts/effects.gd").new()
	tree.root.add_child(fx)
	fx.setup()
	fx.set_volumes(0, 0)
	fx.set_process(false)
	var initial_nodes: int = fx.get_child_count()
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, true, true)
	for frame in 120:
		fx._process(1.0 / 60.0)
	var before: Dictionary = fx.debug_snapshot()
	if before.particles > before.limit or before.exhaust > before.limit - before.reserved:
		failures.append("Sustained exhaust must leave reserved capacity for events")
	fx.burst(Vector3.ZERO, 1.5)
	var born: Dictionary = fx.debug_snapshot()
	if born.counts.star <= 0 or born.counts.paper <= 0:
		failures.append("Impact star and paper fan remain visible under full exhaust")
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, false, false)
	fx._process(0.8)
	if fx.debug_snapshot().counts.star <= 0:
		failures.append("A slow birth frame must still show the short impact peak")
	fx._process(1.3)
	if fx.debug_snapshot().particles != 0:
		failures.append("Released exhaust and impact particles must expire")
	for event in 20:
		fx.burst(Vector3(event, 0, 0), 1.5)
		fx.celebrate(Vector3.ZERO)
	var busy: Dictionary = fx.debug_snapshot()
	if busy.particles > 80 or busy.counts.ribbon <= 0:
		failures.append("Repeated events remain bounded and success can replace old effects")
	if fx.get_child_count() != initial_nodes or busy.batch_meshes != 7:
		failures.append("Repeated particles reuse seven batches without allocating scene nodes")
	fx.set_quality("標準")
	if fx.debug_snapshot().particles > 52:
		failures.append("Standard quality immediately clamps active effects")
	fx.set_quality("控えめ")
	if fx.debug_snapshot().particles > 20:
		failures.append("Subdued quality immediately clamps active effects")
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, true, true)
	for frame in 30:
		fx._process(1.0 / 60.0)
	if fx.debug_snapshot().counts.streak != 0:
		failures.append("Subdued quality disables directional streaks")
	fx.impact(Vector3.ZERO, Vector3.RIGHT, 1.0)
	if fx.debug_snapshot().counts.star <= 0:
		failures.append("Subdued quality keeps clear contact feedback")
	fx.set_exhaust(Vector3.ZERO, Vector3.BACK, false, false)
	fx.set_process(true)
	tree.paused = true
	var stopped: Dictionary = fx.debug_snapshot()
	await tree.create_timer(0.15, true, false, true).timeout
	var still: Dictionary = fx.debug_snapshot()
	if stopped.particles != still.particles or not is_equal_approx(stopped.life_total, still.life_total) or not is_equal_approx(stopped.particle_clock, still.particle_clock):
		failures.append("Pause freezes event positions, age and lifetimes")
	tree.paused = false
	fx.set_process(false)
	fx._process(0.01)
	fx._process(1.5)
	if fx.debug_snapshot().particles != 0:
		failures.append("Celebration and contact leave no persistent particles")
	if fx.debug_snapshot().audio_enabled:
		failures.append("Headless checks must not start audio playback")
	fx.queue_free()
	await tree.process_frame
	return failures
