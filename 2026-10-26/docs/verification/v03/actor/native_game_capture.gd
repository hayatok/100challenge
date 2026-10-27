extends SceneTree
const Data = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world_data.gd")
var ui: Control
var folder := "res://../.scratch/versions/v03/motion/"
func _initialize() -> void:
	call_deferred("capture")
func shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + tag + ".png")
func capture() -> void:
	root.size = Vector2i(390,844)
	root.content_scale_size = Vector2i(390,844)
	ui = load("res://scenes/main.tscn").instantiate()
	ui.qa_session = true
	root.add_child(ui)
	await process_frame
	for character: String in ["isana","ritsu","kohaku","sui"]:
		ui.state = Data.apply_action(Data.new_game(),{"type":"choose","character":character}).state
		ui.state = Data.apply_action(ui.state,{"type":"depart","seed":731}).state
		ui._enter()
		await create_timer(0.4).timeout
		await shot(character + "-native-game-start-390x844")
		for step in 2:
			ui._act({"type":"move","dx":0,"dy":-1})
			var state_text := JSON.stringify(ui.state)
			for frame in 6:
				await create_timer(0.04).timeout
				await shot(character + "-native-game-walk-%d-%02d" % [step,frame])
			assert(JSON.stringify(ui.state) == state_text,"presentation changed resolved game state")
		# Fixture places the worker adjacent to a real generated enemy, then actual rules resolve the bump attack.
		var enemy: Dictionary = ui.state.run.enemies[0]
		var attack_direction := Vector2i.ZERO
		for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP]:
			var point := Vector2i(enemy.x,enemy.y)+delta
			if World.is_walkable(ui.state.run,point.x,point.y):
				ui.state.run.player.x = point.x
				ui.state.run.player.y = point.y
				attack_direction = -delta
				break
		ui._enter()
		await create_timer(0.35).timeout
		ui._act({"type":"move","dx":attack_direction.x,"dy":attack_direction.y})
		var state_text := JSON.stringify(ui.state)
		for frame in 12:
			await create_timer(0.04).timeout
			await shot(character + "-native-game-combat-fixture-%02d" % frame)
		assert(JSON.stringify(ui.state) == state_text,"combat presentation changed resolved game state")
	for district: String in ["quay","market","canal","observatory"]:
		ui.state = Data.new_game()
		ui.state.profile.completedContracts = ["beacon","pump","channel","network"]
		ui.state.profile.selectedDistrict = district
		ui.state = Data.apply_action(ui.state,{"type":"depart","seed":731}).state
		ui._enter()
		await create_timer(0.35).timeout
		await shot(district + "-native-game-390x844")
		ui._act({"type":"move","dx":0,"dy":-1})
		await create_timer(0.12).timeout
		ui._inventory()
		await create_timer(0.15).timeout
		await shot(district + "-native-game-paused-inventory")
		ui._close_modal()
		await create_timer(0.3).timeout
	root.size = Vector2i(360,740)
	root.content_scale_size = Vector2i(390,844)
	ui._enter()
	await create_timer(0.35).timeout
	await shot("native-game-small-360x740")
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(390,844)
	ui._enter()
	await create_timer(0.35).timeout
	await shot("native-game-desktop-1280x900")
	print("Native gameplay captures: all4crew useactualruleswalking/combat; combat placement is a fixture;4district starts, modal pause,phone/small/desktop. No human playtest.")
	quit()
