extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	# A result test must not overwrite a developer's local personal record.
	var record_exists := FileAccess.file_exists("user://record.json")
	var previous_record := FileAccess.get_file_as_bytes("user://record.json") if record_exists else PackedByteArray()
	var scene = load("res://main.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	scene.start_game()
	scene.rules.begin()
	var events := [{"id":"fx-a","base":10000,"progress":1.0}, {"id":"fx-b","base":10000,"progress":2.0}, {"id":"fx-c","base":50000,"progress":3.0}]
	scene._present_breaks(scene.rules.register_breaks(events))
	scene._present()
	var first: Dictionary = scene.effects.debug_snapshot()
	if first.combo_cues != 1 or first.last_combo != 3:
		failures.append("Simultaneous destruction must play one final combo cue")
	if first.rush_starts != 1 or scene.hud.debug_snapshot().rush_starts != 1:
		failures.append("Third chain must start world and HUD rush exactly once")
	scene._present_breaks(scene.rules.register_breaks([{"id":"fx-d","base":10000,"progress":4.0}]))
	if scene.effects.debug_snapshot().rush_starts != 1 or scene.hud.debug_snapshot().rush_starts != 1:
		failures.append("Further destruction during rush must not replay its entrance")
	if scene.effects.debug_snapshot().last_combo != 4 or scene.effects.debug_snapshot().combo_cues != 2:
		failures.append("Continuing rush still acknowledges the new final combo")
	scene.player.pressure = 43.0
	scene.player.velocity = Vector3(0, 0, -3)
	await tree.process_frame
	scene.pause_game()
	var at: Vector3 = scene.player.global_position
	var pressure: float = scene.player.pressure
	var elapsed: float = scene.rules.elapsed
	var hud_paused: Dictionary = scene.hud.debug_snapshot()
	var fx_paused: Dictionary = scene.effects.debug_snapshot()
	await tree.create_timer(0.2, true, false, true).timeout
	if not is_equal_approx(scene.player.pressure, pressure):
		failures.append("Pause must stop pressure recovery and consumption")
	if not scene.player.global_position.is_equal_approx(at):
		failures.append("Pause must stop chair movement")
	if not is_equal_approx(scene.rules.elapsed, elapsed):
		failures.append("Pause must stop the official timer")
	var hud_still: Dictionary = scene.hud.debug_snapshot()
	for key in ["animation_clock", "phase", "burst_left", "rush_guard", "counter_age", "damage_age"]:
		if not is_equal_approx(float(hud_paused[key]), float(hud_still[key])):
			failures.append("Pause must freeze HUD " + key)
	var fx_still: Dictionary = scene.effects.debug_snapshot()
	if not is_equal_approx(fx_paused.particle_clock, fx_still.particle_clock) or not is_equal_approx(fx_paused.life_total, fx_still.life_total):
		failures.append("Pause must freeze world particle movement and lifetimes")
	scene.resume_game()
	if tree.paused or scene.mode != "playing":
		failures.append("UI can resume a paused game")
	scene.start_game()
	if not is_equal_approx(scene.player.pressure, 100.0) or scene.rules.damage != 0 or scene.rules.started:
		failures.append("Restart restores pressure, score and an unstarted timer")
	if scene.effects.debug_snapshot().particles != 0 or scene.effects.debug_snapshot().rush_starts != 0 or scene.hud.debug_snapshot().rush_starts != 0:
		failures.append("Retry clears previous particles and rush presentation")
	scene.rules.begin()
	scene.rules.elapsed = 24.86
	scene.best_time = -1.0
	scene.finish_game()
	var won: Dictionary = scene.hud.debug_snapshot()
	if scene.mode != "result" or won.success_starts != 1 or won.burst_kind != "success" or not won.best_stamp_visible:
		failures.append("Actual result transition starts a single success stamp and real best badge")
	if scene.effects.debug_snapshot().counts.ribbon <= 0:
		failures.append("Success creates world celebration alongside the result stamp")
	scene.finish_game()
	scene._present()
	if scene.hud.debug_snapshot().success_starts != 1 or scene.hud.debug_snapshot().stamp_age != won.stamp_age:
		failures.append("Repeated presentation must not replay the success entrance")
	if not FileAccess.file_exists("user://record.json"):
		failures.append("Successful run saves its record")
	scene._set_window_focus(false)
	var success_stopped: Dictionary = scene.hud.debug_snapshot()
	var confetti_stopped: Dictionary = scene.effects.debug_snapshot()
	await tree.create_timer(0.15, true, false, true).timeout
	if scene.mode != "result" or not is_equal_approx(scene.hud.debug_snapshot().stamp_age, success_stopped.stamp_age) or not is_equal_approx(scene.effects.debug_snapshot().particle_clock, confetti_stopped.particle_clock):
		failures.append("Unfocused result freezes both stamp and world celebration without leaving result")
	scene._set_window_focus(true)
	if tree.paused:
		failures.append("Result celebration resumes on focus without requiring a play-pause action")
	scene.start_game()
	if scene.hud.debug_snapshot().success_starts != 0 or scene.effects.debug_snapshot().particles != 0:
		failures.append("Retry after success removes its stamp clock and confetti")
	scene.show_title()
	if scene.player.active or scene.mode != "title":
		failures.append("Title returns the chair to an inactive state")
	scene.queue_free()
	await tree.process_frame
	# The audio mixer releases stopped playbacks asynchronously, including with
	# the headless Dummy driver. Let that release finish before the runner quits.
	await tree.create_timer(0.15, true, false, true).timeout
	if record_exists:
		var record := FileAccess.open("user://record.json", FileAccess.WRITE)
		record.store_buffer(previous_record)
		record.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record.json"))
	return failures
