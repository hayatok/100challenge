extends SceneTree
var app
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL UI: ", message)
func _initialize(): call_deferred("run")
func run():
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for width in [375, 768, 1024, 1440]:
		root.size = Vector2i(width, 812 if width < 850 else 900)
		app.sync_window()
		app.layout()
		await process_frame
		var bounds: Rect2 = root.get_visible_rect()
		check(bounds.size.x == width, "viewport follows physical size at %d" % width)
		check(bounds.encloses(app.inspector.get_global_rect()), "inspector within viewport at %d" % width)
		check(bounds.encloses(app.view.get_global_rect()), "island within viewport at %d" % width)
		for child in app.root.get_children():
			if child is Button: check(bounds.encloses(child.get_global_rect()), "toolbar within viewport")
		for child in app.inspector.get_children():
			if child is Button or child is Label: check(app.inspector.get_global_rect().encloses(child.get_global_rect()), "inspector content stays inside panel")
		app.open_lineage()
		await process_frame
		check(bounds.encloses(app.modal.get_global_rect()), "lineage modal inside viewport")
		check(app.view.focus_mode == Control.FOCUS_NONE and app.pause_button.focus_mode == Control.FOCUS_NONE, "modal traps background focus")
		for scroll in app.modal.get_children():
			if scroll is ScrollContainer:
				for content in scroll.get_child(0).get_children():
					if content is Label: check(content.size.y >= 20 and not content.clip_text, "modal paragraphs retain readable height")
		var time: float = app.sim.time
		app._process(1.0)
		check(app.sim.time == time, "modal freezes simulation")
		app.close_modal()
		check(app.pause_button.focus_mode == Control.FOCUS_ALL, "background focus restored")
		app.open_notebook()
		await process_frame
		check(bounds.encloses(app.modal.get_global_rect()), "notebook inside viewport")
		app.close_modal()
	app.paused = true
	var time: float = app.sim.time
	app._process(1.0)
	check(app.sim.time == time, "pause freezes ecology")
	app.paused = false
	app.speed = 4
	app._process(0.2)
	check(is_equal_approx(app.sim.time - time, 0.8), "4x advances four fixed steps")
	app.select_creature(1)
	app.sim.history["1"].name = "とてもとても長い名前でも画面の外へはみ出さない生き物です"
	app.refresh()
	check(app.selected_title.clip_text, "long individual names clip safely")
	root.size = Vector2i(375, 667)
	app.sync_window()
	app.layout()
	app.sim.creatures = app.sim.creatures.filter(func(c): return c.id != 1)
	app.sim.history["1"].generation = 20000
	for bp in app.sim.history["1"].genes.anatomy:
		bp.organs = [[0, 0, 0.1, 1.0], [1, 0, 0.3, 1.0], [2, 0, 0.6, 1.0], [3, 0, 0.8, 1.0], [], []]
	app.refresh()
	await process_frame
	check(root.get_visible_rect().encloses(app.inspector.get_global_rect()), "short mobile viewport retains inspector")
	check(app.selected_detail.get_line_count() * app.selected_detail.get_line_height() <= 110, "dead ancestor and mixed organs fit mobile detail")
	check(app.selected_detail.position.y + app.selected_detail.size.y <= 154, "detail does not overlap lineage button")
	print("UI CHECKS ",checks," / failures ",failures)
	quit(1 if failures else 0)
