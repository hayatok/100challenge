extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var scene = load("res://main.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	scene.start_game()
	scene.rules.begin()
	scene.player.pressure = 43.0
	scene.player.velocity = Vector3(0, 0, -3)
	scene.pause_game()
	var at: Vector3 = scene.player.global_position
	var pressure: float = scene.player.pressure
	var elapsed: float = scene.rules.elapsed
	await tree.create_timer(0.2, true, false, true).timeout
	if not is_equal_approx(scene.player.pressure, pressure):
		failures.append("Pause must stop pressure recovery and consumption")
	if not scene.player.global_position.is_equal_approx(at):
		failures.append("Pause must stop chair movement")
	if not is_equal_approx(scene.rules.elapsed, elapsed):
		failures.append("Pause must stop the official timer")
	scene.resume_game()
	if tree.paused or scene.mode != "playing":
		failures.append("UI can resume a paused game")
	scene.start_game()
	if not is_equal_approx(scene.player.pressure, 100.0) or scene.rules.damage != 0 or scene.rules.started:
		failures.append("Restart restores pressure, score and an unstarted timer")
	scene.show_title()
	if scene.player.active or scene.mode != "title":
		failures.append("Title returns the chair to an inactive state")
	scene.queue_free()
	await tree.process_frame
	# The audio mixer releases stopped playbacks asynchronously, including with
	# the headless Dummy driver. Let that release finish before the runner quits.
	await tree.create_timer(0.15, true, false, true).timeout
	return failures
