extends SceneTree
const Main = preload("res://main.gd")
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var app := Main.new()
	app.persist_progress = false
	root.add_child(app)
	app.sound.muted = true
	for width: int in [375,600,768,1024,1440]:
		var height: int = maxi(900,int(float(width)*0.645833+610)) if width < 900 else 900
		app.size = Vector2(width,height)
		for stage: int in range(app.levels.size()):
			app._load_stage(stage)
			await process_frame
			app._layout()
			for control: Control in [app.retry,app.pause_button,app.hint_button,app.mute_button,app.menu,app.detail,app.stage_label]:
				check(control.position.x>=0 and control.get_rect().end.x<=width+1 and control.get_rect().end.y<=height+1,"Control overflow at %d stage %d %s" % [width,stage,control.name])
			for i: int in range(app.pin_buttons.size()):
				check(app.pin_buttons[i].size.x>=43.9,"Touch target too small")
				for vase: Vector2 in app.levels[stage]["vases"]:
					var art_rect := Rect2(app.board_rect.position+(vase-Vector2(18,24))*app.board.scale.x,Vector2(36,48)*app.board.scale.x)
					check(not app.pin_buttons[i].get_rect().intersects(art_rect),"Cut control hides initial ceramic at %d stage %d pin %d" % [width,stage,i])
				for j: int in range(i+1,app.pin_buttons.size()):
					check(app.pin_buttons[i].position.distance_to(app.pin_buttons[j].position)>=47.9,"Overlapping touch targets")
	app._load_stage(0)
	await physics_frame
	app._toggle_pause()
	var p: Vector2 = app.world.ceramics[0].position
	app._cut(1)
	for i: int in range(20):
		await process_frame
	check(app.world.cuts==1 and app.world.ceramics[0].position.is_equal_approx(p),"Pause moved ceramic or rejected planned cut")
	app._toggle_pause()
	for i: int in range(1200):
		await physics_frame
		if app.world.ended:
			break
	check(app.world.won and app.next_button.visible,"Actual UI did not enter success state")
	check(app.menu.get_item_text(0).begins_with("✓"),"Success missing from stage menu")
	app._next()
	check(app.stage==1 and not paused,"Next stage did not resume physics")
	app._load_stage(0)
	app._cut(0)
	for i: int in range(1000):
		await physics_frame
		if app.world.ended:
			break
	check(not app.world.won and app.world.ended and paused,"Actual UI did not pause at fracture")
	app._load_stage(0)
	check(not paused and app.world.cuts==0,"Retry did not reconstruct initial state")
	app.retry.grab_focus()
	var space_key := InputEventKey.new()
	space_key.keycode = KEY_SPACE
	space_key.pressed = true
	root.push_input(space_key,true)
	await process_frame
	await process_frame
	check(paused,"Space shortcut was consumed by focused retry control")
	app._toggle_pause()
	app._hint()
	app._hint()
	check(app.detail.text==app.levels[0]["hints"][1],"Second hint not shown")
	app.free()
	print("UI CHECKS ",checks," failures=",failures)
	quit(0 if failures==0 else 1)
