extends SceneTree
var frames := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var arena := Node3D.new()
	root.add_child(arena)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08,0.11,0.11)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55,0.65,0.65)
	env.environment.ambient_light_energy = 0.7
	arena.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = 1.8
	arena.add_child(light)
	var player = load("res://combat/player.gd").new()
	arena.add_child(player)
	player.set_physics_process(false)
	player.gun_root.position = Vector3(0.31,-0.25,-0.66)
	for i in range(4):
		var enemy = load("res://combat/enemy.gd").new()
		enemy.setup(i,player)
		arena.add_child(enemy)
		enemy.position=Vector3((i-1.5)*1.6,0,-5)
		enemy.rotation.y=PI
		enemy.set_physics_process(false)
		enemy.phase=1.2
		enemy._animate()
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	print("RENDER_METRICS draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	root.get_texture().get_image().save_png("res://../modeling/review/fps.png")
	quit()
