extends SceneTree
const Actor = preload("res://scenes/actor.tscn")
var folder := "res://../.scratch/versions/v03/motion/"
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + name + ".png")
func capture() -> void:
	root.size = Vector2i(900,820)
	root.content_scale_size = Vector2i(900,820)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("dfeee4")
	bg.size = Vector2(900,820)
	canvas.add_child(bg)
	var header := Label.new()
	header.text = "v0.3 native actor clips / automated fixture / 150-unit crew\nDown, Up, Right, Left. Full directional poses and anchored salvage tool."
	header.position = Vector2(20,10)
	header.add_theme_color_override("font_color",Color("183e52"))
	canvas.add_child(header)
	var actors: Array = []
	for row in 4:
		for col in 4:
			var actor = Actor.instantiate()
			canvas.add_child(actor)
			actor.configure(null,["isana","ritsu","kohaku","sui"][row],true,false)
			actor.set_stage_scale(1.6)
			actor.position = Vector2(110+col*220,222+row*190-19*1.6)
			actor.face([Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT][col])
			actors.append(actor)
	await create_timer(0.4).timeout
	await shot("native-directions-all-crew")
	for actor in actors:
		actor.play_reaction("step")
	for frame in 6:
		await create_timer(0.04).timeout
		await shot("native-step-first-%02d" % frame)
	for actor in actors:
		actor.play_reaction("step")
	for frame in 6:
		await create_timer(0.04).timeout
		await shot("native-step-second-%02d" % frame)
	for actor in actors:
		actor.play_reaction("attack")
	for frame in 10:
		await create_timer(0.04).timeout
		await shot("native-attack-%02d" % frame)
	for actor in actors:
		actor.play_reaction("hurt",Vector2.LEFT)
	for frame in 8:
		await create_timer(0.04).timeout
		await shot("native-recoil-%02d" % frame)
	for i in actors.size():
		if i%4 == 0:
			actors[i].play_arrival(true)
		elif i%4 == 1:
			actors[i].play_arrival(false)
		else:
			actors[i].play_loss()
	for frame in 15:
		await create_timer(0.05).timeout
		await shot("native-arrival-quiet-loss-%02d" % frame)
	print("Captured native actor sequence: grounded directional contacts, anticipation/contact/recovery, recoil, arrival/quiet arrival/loss. This fixture is not human playtesting.")
	quit()
