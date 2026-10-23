extends Node3D

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/sound.gd")
var gameplay: Node3D
var world: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var sound: Node
var impact: Node3D
var hitstop_remaining := 0.0
var mode := "title"
var elapsed := 0.0
var settings := {"volume": 0.7, "sensitivity": 1.0, "invert_y": false, "reduced_motion": false}
var checkpoint := false
var reached_arena := false
var core_broken := false
var return_plunged := false
var seen_actions: Dictionary = {}
var samples: Array[float] = []
var _sample_clock := 0.0
var _last_frame_usec := 0
var _capture_dir := ""
var _capture_count := 0
var _web_pointer_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_web_pointer_callback = JavaScriptBridge.create_callback(_web_pointer_changed)
		JavaScriptBridge.get_interface("document").addEventListener("pointerlockchange",_web_pointer_callback)
	_configure_input()
	_load_save()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	ui = Interface.new()
	add_child(ui)
	ui.settings = settings.duplicate()
	ui.start_requested.connect(_start)
	ui.resume_requested.connect(_resume)
	ui.restart_requested.connect(func(): _start(false))
	ui.title_requested.connect(_title)
	ui.settings_changed.connect(_settings_changed)
	sound = Sound.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	_make_scene(false)
	ui.show_title(checkpoint)
	_apply_volume()
	print("TENSAI_RUNTIME ", JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"viewport":str(get_viewport().get_visible_rect().size),"engine":Engine.get_version_info().string}))

func _configure_input() -> void:
	var keys := {"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S,"jump":KEY_SPACE,"dash":KEY_SHIFT,"wire":KEY_E,"lock":KEY_Q,"pause":KEY_ESCAPE}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action,0.2)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	for action in ["attack","heavy"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,mouse)
	var buttons := {"jump":JOY_BUTTON_A,"dash":JOY_BUTTON_B,"attack":JOY_BUTTON_RIGHT_SHOULDER,"lock":JOY_BUTTON_RIGHT_STICK,"pause":JOY_BUTTON_START}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action,event)
	for binding in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["move_forward",JOY_AXIS_LEFT_Y,-1.0],["move_back",JOY_AXIS_LEFT_Y,1.0],["wire",JOY_AXIS_TRIGGER_LEFT,1.0],["heavy",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = binding[1]
		event.axis_value = binding[2]
		InputMap.action_add_event(binding[0],event)

func _make_scene(resume_save: bool) -> void:
	if is_instance_valid(gameplay):
		remove_child(gameplay)
		gameplay.free()
	gameplay = Node3D.new()
	gameplay.name = "Run"
	gameplay.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gameplay)
	world = World.new()
	world.name = "World"
	gameplay.add_child(world)
	player = Player.new()
	player.name = "Player"
	gameplay.add_child(player)
	player.reset_at(Vector3(0,1.15,-17) if resume_save else world.get_spawn())
	player.apply_settings(settings)
	player.damaged.connect(func(): sound.cue("impact"))
	player.died.connect(func(): _finish(false))
	player.action_performed.connect(_on_action)
	player.enemy_defeated.connect(func(): sound.cue("chime"))
	for at in world.get_enemy_spawns():
		var enemy := Enemy.new()
		enemy.player = player
		enemy.position = at
		gameplay.add_child(enemy)
	world.core_hit.connect(func(): sound.cue("impact"))
	world.core_destroyed.connect(func():
		core_broken = true
		sound.cue("chime")
		_log_event("core_destroyed"))
	impact = load("res://scripts/impact.gd").new()
	gameplay.add_child(impact)
	impact.reduced = bool(settings.reduced_motion)
	core_broken = false
	return_plunged = false
	reached_arena = resume_save
	seen_actions.clear()
	elapsed = 0

func _start(resume_save: bool) -> void:
	Engine.time_scale = 1.0
	hitstop_remaining = 0
	samples.clear()
	_sample_clock = 0
	_last_frame_usec = Time.get_ticks_usec()
	get_tree().paused = false
	sound.stop()
	_make_scene(resume_save)
	mode = "play"
	player.set_active(true)
	ui.show_play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sound.begin()
	_log_event("start")

func _title() -> void:
	Engine.time_scale = 1.0
	hitstop_remaining = 0
	get_tree().paused = false
	mode = "title"
	player.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.stop()
	_make_scene(false)
	ui.show_title(checkpoint)

func _pause() -> void:
	if mode != "play": return
	Engine.time_scale = 1.0
	hitstop_remaining = 0
	mode = "pause"
	player.clear_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	ui.show_pause()
	_log_event("pause")

func _resume() -> void:
	if mode != "pause": return
	_last_frame_usec = Time.get_ticks_usec()
	get_tree().paused = false
	player.clear_input()
	mode = "play"
	ui.show_play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_log_event("resume")

func _finish(success: bool) -> void:
	if mode != "play": return
	Engine.time_scale = 1.0
	hitstop_remaining = 0
	mode = "result"
	player.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	ui.show_result(success,elapsed,player.total_kills)
	_log_event("success" if success else "defeat")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "play": _pause()
		elif mode == "pause": _resume()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8 and _capture_dir != "":
		capture("manual")

func _web_pointer_changed(_arguments: Array) -> void:
	if mode == "play" and JavaScriptBridge.eval("document.pointerLockElement === null"):
		_pause.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play":
		_pause.call_deferred()

func _process(delta: float) -> void:
	var frame_now := Time.get_ticks_usec()
	var wall_ms := float(frame_now - _last_frame_usec) / 1000.0
	_last_frame_usec = frame_now
	if hitstop_remaining > 0:
		hitstop_remaining -= delta / maxf(Engine.time_scale, 0.001)
		if hitstop_remaining <= 0: Engine.time_scale = 1.0
	if not is_instance_valid(player): return
	if mode == "play":
		elapsed += delta
		if player.global_position.z < -11 and not reached_arena:
			reached_arena = true
			checkpoint = true
			_save()
			_log_event("checkpoint")
		if core_broken and return_plunged and player.is_on_floor() and player.global_position.y < 3 and player.global_position.z > -28:
			_finish(true)
		ui.update_play(player,elapsed,_hint())
		samples.append(wall_ms)
		_sample_clock += delta
		if _sample_clock > 5.0:
			_sample_clock = 0
			var sorted := samples.duplicate()
			sorted.sort()
			print("TENSAI_PERF ",JSON.stringify({"seconds":snappedf(elapsed,0.1),"fps":Engine.get_frames_per_second(),"frame_p95_ms":sorted[int((sorted.size()-1)*.95)],"frame_p99_ms":sorted[int((sorted.size()-1)*.99)],"memory_bytes":OS.get_static_memory_usage() if OS.get_static_memory_usage() > 0 else null,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"position":str(player.global_position),"state":player.state_name,"render_pixels":str(get_viewport().get_texture().get_size())}))
			samples.clear()

func _hint() -> String:
	if core_broken: return "Space → 右クリック　広場へ急降下"
	if player.global_position.y > 5: return "核を斬る　左クリック"
	if player.total_kills >= 1 and reached_arena: return "E　巨像の肩へ"
	if reached_arena and not seen_actions.has("launch"): return "右クリック　打ち上げる"
	if reached_arena and not seen_actions.has("slash"): return "左クリック　空中で追撃"
	if not seen_actions.has("wire") and player.global_position.z < 5: return "金の輪へ　E ワイヤー"
	if not seen_actions.has("slide"): return "WASD　移動　／　Shift 長押し　滑走"
	if not seen_actions.has("jump"): return "Space　ジャンプ"
	return ""

func _on_action(action: String) -> void:
	seen_actions[action] = true
	if action == "enemy_warning":
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.state_name == "windup":
				sound.warn_at(enemy.global_position)
				break
	if is_instance_valid(impact):
		var visual: Node3D = player.get("_visual")
		if action in ["slash","launch"]: impact.strike(player.global_position, visual.rotation.y)
		if action == "hit":
			impact.hit(player.global_position + Vector3.UP - visual.global_basis.z * 1.4)
			hitstop_remaining = 0.045
			Engine.time_scale = 0.12
	if action == "plunge" and core_broken: return_plunged = true
	var cue := {"slash":"slash","launch":"slash","plunge":"dash","wire":"wire","dash":"dash","hit":"impact","land":"impact"}
	if cue.has(action): sound.cue(cue[action])
	_log_event(action)

func _settings_changed(value: Dictionary) -> void:
	settings = value.duplicate()
	player.apply_settings(settings)
	impact.reduced = bool(settings.reduced_motion)
	_apply_volume()
	_save()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(settings.volume))))

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://progress.cfg") != OK: return
	checkpoint = bool(config.get_value("progress","checkpoint",false))
	for key in settings:
		var value: Variant = config.get_value("settings",key,settings[key])
		if typeof(value) == typeof(settings[key]): settings[key] = value
	settings.volume = clampf(float(settings.volume),0,1)
	settings.sensitivity = clampf(float(settings.sensitivity),0.4,2)

func _save() -> void:
	var config := ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.set_value("progress","checkpoint",checkpoint)
	var result := config.save("user://progress.cfg")
	if result != OK: ui.notice.text = "保存できません。この回はそのまま遊べます。"

func _log_event(event: String) -> void:
	print("TENSAI_EVENT ",JSON.stringify({"event":event,"seconds":snappedf(elapsed,.01),"position":str(player.global_position) if is_instance_valid(player) else "","health":player.health if is_instance_valid(player) else 0,"dashes":player.air_dashes if is_instance_valid(player) else 0}))

func capture(label: String) -> void:
	if _capture_dir == "": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_capture_count += 1
	var path := _capture_dir.path_join("%02d-%s.png" % [_capture_count,label])
	get_viewport().get_texture().get_image().save_png(path)
	print("TENSAI_CAPTURE ",path)
