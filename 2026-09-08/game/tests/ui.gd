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
	for dimensions: Vector2i in [Vector2i(375,900),Vector2i(600,1000),Vector2i(768,1110),Vector2i(1024,900),Vector2i(1440,900),Vector2i(1440,720)]:
		var width: int = dimensions.x
		var height: int = dimensions.y
		app.size = Vector2(width,height)
		for stage: int in range(app.levels.size()):
			app._load_stage(stage)
			await process_frame
			app._layout()
			if app.footer.visible:
				check(not app.footer.get_rect().intersects(app.menu.get_rect()),"Keyboard legend overlaps stage menu")
			for control: Control in [app.retry,app.pause_button,app.hint_button,app.mute_button,app.menu,app.ledger_button,app.detail,app.stage_label]:
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
	check(app.world.visuals.packing,"Success did not start packing")
	for i: int in range(100):
		await process_frame
	check(app.world.visuals.packing_age>=0.65,"Packing did not finish while physics was paused")
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
	check(not app.world.visuals.packing and app.world.visuals.bursts.is_empty(),"Retry retained visual effects")
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

	check(app.ledger_button.get_theme_color("font_focus_color")==app.ledger_button.get_theme_color("font_color"),"Focused ledger button loses its readable label")
	app._show_ledger()
	check(app.ledger.visible and paused,"Ledger does not pause simulation")
	check(app.ledger.tiles[0].completed and not app.ledger.tiles[7].completed,"Ledger disagrees with saved best results")
	var cut_key := InputEventKey.new()
	cut_key.keycode = KEY_2
	cut_key.pressed = true
	app._input(cut_key)
	check(app.world.cuts==0,"Ledger allowed a background cut")
	app._close_ledger()
	check(not paused,"Closing ledger failed to restore running state")
	app._toggle_pause()
	app._show_ledger()
	app._close_ledger()
	check(paused,"Closing ledger discarded manual pause")
	app._set_reduced(true)
	app._cut(1)
	check(app.world.visuals.bursts.is_empty(),"Reduced motion emitted cut particles")
	app.world.visuals.pack(app.world.box)
	check(app.world.visuals.packing_age>=1.0,"Reduced motion waited for packing animation")
	app._load_stage(7)
	app.world.won = true
	app.world.ended = true
	paused = true
	app._next()
	check(app.ledger.visible and app.stage==7,"Final stage failed to open ledger")
	app.ledger.tiles[5].pressed.emit()
	check(app.stage==5 and not app.ledger.visible and not paused,"Ledger selected wrong stage or left game paused")
	check(app.world.visuals.reduced,"Reduced motion preference lost on stage change")
	app._show_ledger()
	for i: int in range(app.ledger.tiles.size()):
		var tile: Button = app.ledger.tiles[i]
		check(tile.get_node(tile.focus_next) is Control,"Ledger focus target is missing")
	app._close_ledger()
	app.free()
	# Exercise the actual scene wrapper, including a short mobile viewport.
	var screen := SubViewport.new()
	screen.size = Vector2i(375,667)
	root.add_child(screen)
	var frame: ScrollContainer = load("res://main.tscn").instantiate()
	var content: Control = frame.get_node("Rescue")
	content.persist_progress = false
	screen.add_child(frame)
	content.sound.muted = true
	await process_frame
	await process_frame
	check(frame.get_v_scroll_bar().max_value>frame.get_v_scroll_bar().page,"Short mobile screen has no scroll range")
	frame.scroll_vertical = 120
	await process_frame
	check(frame.scroll_vertical==120,"Mobile scroll did not move content")
	check(content.position.y<0,"Scroll wrapper did not offset the UI")
	content._show_ledger()
	await process_frame
	check(content.ledger.size==Vector2(375,667),"Ledger does not fit actual mobile viewport")
	check(content.ledger.grid.columns==2,"Mobile ledger is not two columns")
	for tile: Button in content.ledger.tiles:
		check(tile.get_rect().end.x<=content.ledger.scroll.size.x,"Ledger tile overflows mobile width")
		for label: Label in tile.get_children():
			check(label.position.x+label.get_minimum_size().x<=tile.size.x-4,"Ledger text clips at mobile width")
	check(content.ledger.scroll.get_v_scroll_bar().max_value>content.ledger.scroll.get_v_scroll_bar().page,"Mobile ledger cannot scroll to last work")
	content._close_ledger()
	content._load_stage(0)
	await process_frame
	check(frame.scroll_vertical==0,"Retry did not return to model")
	screen.free()
	# A 750x1334 backing surface at 2x must lay out as a 375x667 display.
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(750,1334)
	root.content_scale_factor = 2.0
	var retina: ScrollContainer = load("res://main.tscn").instantiate()
	var retina_content: Control = retina.get_node("Rescue")
	retina_content.persist_progress = false
	root.add_child(retina)
	retina_content.sound.muted = true
	await process_frame
	await process_frame
	check(retina.size.is_equal_approx(Vector2(375,667)),"Retina layout uses backing pixels instead of display pixels")
	check(retina_content.small,"Retina phone selects desktop layout")
	retina_content._show_ledger()
	check(retina_content.ledger.size.is_equal_approx(Vector2(375,667)),"Retina ledger scales differently from the game")
	retina.free()
	root.content_scale_factor = 1.0
	paused = false
	print("UI CHECKS ",checks," failures=",failures)
	quit(0 if failures==0 else 1)
