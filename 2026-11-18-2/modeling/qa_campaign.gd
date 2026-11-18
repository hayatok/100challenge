extends SceneTree
# Automated observer/driver. Writes ONLY bridge-consumed input, never combat/world state.
# Test save path is set before the production main enters the tree.
var voyage
var tick := 0
var status := ""
var output := "/tmp/dead-freight-run"
var gpu := false
var last_progress := 0
var last_kills := 0
var failures := 0
var limit := 0
var rally_route := 0
var rally_previous := false
var route_key := ""
var route_index := 0
var capture_boss := false
var last_boss_tick := -10000
var observed_boss_state := ""
var input_mode := "bridge"
var host: Viewport
var chapter_clips := false
var chapter_start := {}
var last_observed_position := Vector3.INF
var retry_allowed := false
var deaths := 0
var events: FileAccess
func _initialize() -> void:
	seed(918)
	retry_allowed = "--retry" in OS.get_cmdline_user_args()
	gpu = "--capture" in OS.get_cmdline_user_args()
	capture_boss = "--capture-boss" in OS.get_cmdline_user_args()
	chapter_clips = "--capture-chapters" in OS.get_cmdline_user_args()
	if capture_boss or chapter_clips: gpu = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input_mode = arg.trim_prefix("--input=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--limit="): limit = int(arg.trim_prefix("--limit="))
	if gpu: RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960,540)
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(output)
	events = FileAccess.open(output+"/events.jsonl",FileAccess.WRITE)
	call_deferred("start")
func start() -> void:
	voyage = load("res://voyage.gd").new()
	voyage.storage = "user://qa_campaign.cfg"
	host = root
	if DisplayServer.get_name() == "headless":
		var test_viewport := SubViewport.new()
		test_viewport.size = Vector2i(960,540)
		root.add_child(test_viewport)
		host = test_viewport
	host.add_child(voyage)
	await process_frame
	if gpu or input_mode == "touch":
		voyage.bridge._touch = true
		voyage.bridge._instruments.touch = true
	voyage.bridge.begin.emit(false)
	if input_mode == "pc": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	note({"input_path":input_mode,"capture":gpu,"automated":true,"mouse_mode":Input.mouse_mode,"touch":voyage.bridge._touch,"window_size":str(root.size),"panel_size":str(voyage.bridge._instruments.size),"paused":paused})
	physics_frame.connect(drive)
func note(data: Dictionary) -> void:
	data["sim_seconds"] = tick/60.0
	events.store_line(JSON.stringify(data))
	events.flush()
	print(JSON.stringify(data))
func drive() -> void:
	tick += 1
	if limit>0 and tick>limit:
		note({"result":"partial_capture_limit","stage":status})
		finish(0)
		return
	if voyage.mode == "won":
		note({"result":"won","kills":voyage.kills,"elapsed":voyage.elapsed,"deaths":deaths})
		finish(0)
		return
	if voyage.mode == "dead":
		deaths += 1
		note({"result":"death","chapter":voyage.chapter,"checkpoint":voyage.checkpoint,"kills":voyage.kills,"attempt":deaths})
		if retry_allowed and deaths<=3:
			voyage.bridge.retry_requested.emit()
			last_progress = tick
			status = ""
			note({"action":"normal_checkpoint_retry"})
			return
		finish(2)
		return
	if voyage.mode == "paused":
		# Focus changes are irrelevant to this isolated automated run.
		voyage.bridge.resume_requested.emit()
	if voyage.mode != "play": return
	var player = voyage.player
	if not chapter_start.has(voyage.chapter): chapter_start[voyage.chapter] = tick
	if not last_observed_position.is_finite() or last_observed_position.distance_to(player.position)>0.1:
		last_progress = tick
		last_observed_position = player.position
	var key := "%d/%d/%d" % [voyage.chapter,voyage.checkpoint,voyage.world.wave]
	if key != status:
		status = key
		note({"stage":key,"hp":player.hp,"kills":voyage.kills,"position":str(player.position)})
	if tick % 600 == 0:
		note({"heartbeat":status,"hp":player.hp,"kills":voyage.kills,"remaining":voyage.remaining,"position":str(player.position)})
	if voyage.kills != last_kills:
		last_kills = voyage.kills
		last_progress = tick
	if tick > 60*1200 or (tick-last_progress > 60*90):
		note({"result":"stuck","stage":status,"position":str(player.position),"remaining":voyage.remaining})
		for enemy in get_nodes_in_group("enemies"): note({"enemy":enemy.kind,"hp":enemy.hp,"position":str(enemy.position)})
		finish(3)
		return
	var enemies := get_nodes_in_group("enemies")
	var target: Node3D
	var best := INF
	for enemy in enemies:
		if enemy.kind == 3:
			last_boss_tick = tick
			if enemy.boss_state != observed_boss_state:
				observed_boss_state = enemy.boss_state
				note({"boss_state":observed_boss_state,"boss_hp":enemy.hp,"boss_phase":enemy.boss_phase,"position":str(enemy.position)})
		var distance: float = player.position.distance_to(enemy.position)
		if distance < best:
			best = distance
			target = enemy
	var destination := Vector3(0,0,-116)
	var rally: bool = voyage.world.get("rally_active") == true
	if rally != rally_previous:
		note({"rally_active":rally,"chapter":voyage.chapter,"position":str(player.position),"target":str(voyage.world.navigation_goal())})
	if rally and not rally_previous: rally_route = 0
	rally_previous = rally
	if rally:
		destination = voyage.world.navigation_goal()
		if voyage.chapter == 1:
			var waypoints := [Vector3(-5,0,-38),Vector3(-11,0,-38),Vector3(-11,0,-40),Vector3(-11,3,-52),destination]
			var waypoint: Vector3 = waypoints[mini(rally_route,4)]
			var flat: Vector2 = Vector2(player.position.x-waypoint.x,player.position.z-waypoint.z)
			if flat.length()<1.3: rally_route = mini(4,rally_route+1)
			destination = waypoints[rally_route]
	if voyage.world.has_method("navigation_route") and rally:
		var route: Array = voyage.world.navigation_route()
		var key_route := str(route)
		if key_route != route_key:
			route_key = key_route
			route_index = 0
		if not route.is_empty():
			var goal: Vector3 = route[mini(route_index,route.size()-1)]
			if player.position.distance_to(goal)<1.3: route_index = mini(route_index+1,route.size()-1)
			destination = route[route_index]
	var direction := Vector3.FORWARD
	var fire := false
	if target:
		var aim := target.global_position+Vector3.UP*(1.68 if target.kind<2 else 2.08)
		direction = (aim-player.camera.global_position).normalized()
		fire = true
		# Keep distance while engaging through the same bridge path used by mouse/WASD.
		if best < 7:
			destination = player.position + (player.position-target.position).normalized()*4
			destination.x = clampf(destination.x,-5,5)
			destination.z = minf(destination.z,-voyage.checkpoint*36.0-3.0)
			if absf(player.position.x)>14:
				destination.x = clampf(destination.x,16,36) if player.position.x>0 else clampf(destination.x,-36,-16)
				destination.z = clampf(destination.z,-69,-43)
		elif best > 24:
			destination = Vector3(0,0, -voyage.checkpoint*36.0-12)
		else: destination = player.position
		var sight := PhysicsRayQueryParameters3D.create(player.camera.global_position,aim,1)
		if not player.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			destination = target.position
			fire = false
	else:
		direction = (destination-player.position).normalized()
	var desired_yaw := atan2(-direction.x,-direction.z)
	var desired_pitch := asin(direction.y)
	var yaw_error := wrapf(desired_yaw-player.rotation.y,-PI,PI)
	var pitch_error: float = desired_pitch-player.pitch
	var look_delta := Vector2(-yaw_error,pitch_error*-1)/0.0023
	# MG sustained fire baseline; special weapons are selected through the public UI signal.
	if player.weapon != 0:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_1
		key_event.pressed = true
		voyage.bridge._input(key_event)
	var delta: Vector3 = destination-player.position
	delta.y = 0
	var travel := delta.normalized() if delta.length()>0.5 else Vector3.ZERO
	if travel.length()>0 and not (rally and voyage.chapter==1 and (destination.y>1.0 or player.position.y>0.5)):
		var origin: Vector3 = player.global_position+Vector3.UP*0.08
		var query := PhysicsRayQueryParameters3D.create(origin,origin+travel*2.0,1)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			for angle in [1.0,-1.0,1.57,-1.57]:
				var alternate := travel.rotated(Vector3.UP,angle)
				query.to = origin+alternate*2.5
				if player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					travel = alternate
					break
	var local_move: Vector3 = player.global_basis.inverse()*travel
	_submit_controls(local_move,look_delta,fire)
	if gpu and tick % 10 == 0:
		if chapter_clips:
			if tick-int(chapter_start[voyage.chapter])<900: call_deferred("capture",tick,"chapter_%d" % voyage.chapter)
			elif capture_boss and tick-last_boss_tick<180: call_deferred("capture",tick,"boss")
		elif not capture_boss or tick-last_boss_tick<180: call_deferred("capture",tick,"")
func capture(index: int, section: String = "") -> void:
	RenderingServer.force_draw(false,1.0/6.0)
	var directory := output if section == "" else output+"/"+section
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+"/frame_%06d.png" % index)
func finish(code: int) -> void:
	physics_frame.disconnect(drive)
	events.close()
	voyage.get_parent().remove_child(voyage)
	voyage.queue_free()
	await process_frame
	await process_frame
	quit(code)

func _submit_controls(move: Vector3, look: Vector2, fire: bool) -> void:
	if input_mode == "bridge":
		voyage.bridge._movement.clear()
		if move.x > .3: voyage.bridge._movement["freight_right"] = true
		if move.x < -.3: voyage.bridge._movement["freight_left"] = true
		if move.z < -.3: voyage.bridge._movement["freight_forward"] = true
		if move.z > .3: voyage.bridge._movement["freight_back"] = true
		voyage.bridge._look = look
		voyage.bridge._mouse_fire = fire
	elif input_mode == "pc":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		for binding in [[KEY_D,move.x>.3],[KEY_A,move.x<-.3],[KEY_W,move.z<-.3],[KEY_S,move.z>.3]]:
			var event := InputEventKey.new()
			event.physical_keycode = binding[0]
			event.pressed = binding[1]
			voyage.bridge._input(event)
		var motion := InputEventMouseMotion.new()
		motion.relative = look.clamp(Vector2(-70,-70),Vector2(70,70))
		voyage.bridge._input(motion)
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = fire
		voyage.bridge._input(button)
	elif input_mode == "touch":
		var panel = voyage.bridge._instruments
		var stick: Vector2 = panel.stick_center()
		if voyage.bridge._stick_finger<0: _touch(0,stick,true)
		var stick_drag := InputEventScreenDrag.new()
		stick_drag.index = 0
		stick_drag.position = stick+Vector2(move.x,move.z)*42*panel.scale_factor()
		voyage.bridge._input(stick_drag)
		var aim: Vector2 = Vector2(panel.size.x*.65,panel.size.y*.4)
		_touch(1,aim,true)
		var aim_drag := InputEventScreenDrag.new()
		aim_drag.index = 1
		aim_drag.position = aim+look.clamp(Vector2(-70,-70),Vector2(70,70))/(panel.css_scale()*1.8)
		voyage.bridge._input(aim_drag)
		_touch(1,aim_drag.position,false)
		if fire and voyage.bridge._fire_finger<0: _touch(2,panel.fire_center(),true)
		elif not fire and voyage.bridge._fire_finger>=0: _touch(2,panel.fire_center(),false)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	voyage.bridge._input(event)
