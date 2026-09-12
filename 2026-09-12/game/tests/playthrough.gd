extends SceneTree
var game: KaijuGame
var key_state: Dictionary = {}
var frames: int = 0
var detour: Vector3 = Vector3.ZERO
var detour_left: int = 0
var last_position: Vector3
var travelled: float = 0
var bite_down: bool = false
var chosen_mutation: int = 0
func _initialize() -> void:call_deferred("run")
func key(code: Key, down: bool) -> void:
	if key_state.get(code,false) == down:return
	key_state[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func mouse(at: Vector3, bite: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_camera_3d().unproject_position(at)
	Input.parse_input_event(event)
	if bite != bite_down:
		bite_down = bite
		var button := InputEventMouseButton.new()
		button.position = event.position
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = bite
		Input.parse_input_event(button)
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():chosen_mutation = clampi(int(OS.get_cmdline_user_args()[0]),0,2)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	game.get_node("Player").set_script(load("res://tests/driver_player.gd"))
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.start()
	last_position = game.player.position
	var checkpoint := last_position
	for frame in 24000:
		frames = frame
		await physics_frame
		if game.state == "mutation":
			game.set_mutation(chosen_mutation)
		if game.state == "result":break
		if not game.running:continue
		var player := game.player
		travelled += player.position.distance_to(last_position)
		last_position = player.position
		var target: TownProp = null
		var best := INF
		for item in get_nodes_in_group("targets"):
			var prop := item as TownProp
			if prop.consumed:continue
			var distance: float = prop.position.distance_to(player.position)
			var rank := distance
			if prop.kind == 6:
				if player.stage < 2:continue
				rank -= 8
			elif prop.edible(player.stage):rank -= 7
			elif prop.kind == 5:
				if player.stage < 2:continue
				rank += 4
			elif prop.kind == 1:rank += 10
			if rank < best:
				best = rank
				target = prop
		if target == null:break
		var offset := target.position-player.position
		offset.y = 0
		var distance := offset.length()
		var direction := offset.normalized()
		var edible := target.edible(player.stage)
		var reach := player.body_scale*1.75+(.7 if target.kind != 5 else 1.4)
		player.set("aim_vector",direction)
		player.set("drive_bite",edible and distance <= reach+.3)
		var movement := direction if distance > reach*.82 else Vector3.ZERO
		if not edible and distance < 6 and player.charges > 0:
			player.start_dash()
		if player.mutation >= 0 and player.ability_cooldown <= 0 and distance < 8:
			player.ability()
		if frame % 60 == 0:
			if player.position.distance_to(checkpoint) < .5 and distance > reach and player.dash_left <= 0:
				detour_left = 50
				detour = direction.rotated(Vector3.UP,PI/2 if frame%120 == 0 else -PI/2)
			checkpoint = player.position
		if detour_left > 0:
			movement = detour
			detour_left -= 1
		# Respond to telegraphed attacks, while retaining a charge for the next opening.
		for enemy in get_nodes_in_group("targets"):
			if enemy is TownEnemy and not enemy.exposed and enemy.phase == "aim" and enemy.timer < .48 and enemy.position.distance_to(player.position) < 23:
				var line: Vector3 = enemy.aim-enemy.position
				line.y = 0
				var rel: Vector3 = player.position-enemy.position
				var on_line: bool = rel.cross(line.normalized()).length() < player.body_scale+1.3
				if (enemy.kind == 4 and player.position.distance_to(enemy.aim)<4) or on_line:
					movement = line.normalized().rotated(Vector3.UP,PI/2)
		player.set("drive_vector",movement)
		if frame % 1200 == 0:print("frame=",frame," stage=",player.stage," xp=",game.growth," health=",game.health," position=",player.position," target=",target.name)
	print("PLAYTHROUGH state=",game.state," wins=",game.wins," stage=",game.player.stage," growth=",game.growth," health=",game.health," eaten=",game.eaten," travelled=",snappedf(travelled,.1)," time=",snappedf(game.elapsed,.1))
	quit(0 if game.state == "result" and game.health > 0 and game.player.stage == 2 else 1)
