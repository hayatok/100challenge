extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const OfficeScript = preload("res://scripts/office.gd")
const ActorScript = preload("res://scripts/actor.gd")
const HudScript = preload("res://scripts/hud.gd")
const EffectsScript = preload("res://scripts/effects.gd")
const RulesScript = preload("res://scripts/rules.gd")

var player
var office
var actor
var hud
var effects
var rules = RulesScript.new()
var camera: Camera3D
var mode := "title"
var impact_amount := 0.0
var shake := 0.0
var effect_level := "派手"
var music_volume := 0.45
var sfx_volume := 0.75
var best_time := -1.0
var best_damage := 0
var best_combo := 0
var new_best := false
var save_error := false
var result: Dictionary = {}
var _hit_times: Array[float] = []
var _last_hit := -1.0
var _qa_enabled := false
var _qa_timer := 0.0
var _result_focus_paused := false
var _result_spray_held := false
var _clock_ms := 0
var _web_window: JavaScriptObject
var _web_document: JavaScriptObject
var _web_focus_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_inputs()
	_light_office()
	office = OfficeScript.new()
	office.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(office)
	office.build()
	office.set_feedback_quality(effect_level)
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.reset_at(office.spawn_position)
	player.set_active(false)
	player.impacted.connect(_on_impact)
	player.recovered.connect(func(_at: Vector3) -> void: hud.burst("椅子、復旧！", "", "impact"))
	actor = ActorScript.new()
	player.add_child(actor)
	actor.build()
	hud = HudScript.new()
	add_child(hud)
	hud.build()
	hud.start_requested.connect(start_game)
	hud.restart_requested.connect(start_game)
	hud.resume_requested.connect(resume_game)
	hud.title_requested.connect(show_title)
	hud.pause_requested.connect(pause_game)
	hud.settings_changed.connect(_settings_changed)
	_create_effects()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 46.0
	camera.far = 240.0
	camera.position = office.spawn_position + Vector3(7.0, 5.0, 7.0)
	camera.look_at(office.spawn_position + Vector3(-2.0, 1.4, 0.0), Vector3.UP)
	_load_record()
	_clock_ms = Time.get_ticks_msec()
	if OS.has_feature("web"):
		_qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"))
		_web_window = JavaScriptBridge.get_interface("window")
		_web_document = JavaScriptBridge.get_interface("document")
		_web_focus_callback = JavaScriptBridge.create_callback(_on_web_focus)
		_web_window.addEventListener("blur", _web_focus_callback)
		_web_window.addEventListener("focus", _web_focus_callback)
		_web_document.addEventListener("visibilitychange", _web_focus_callback)
	_present()

func _on_web_focus(_arguments: Array) -> void:
	_set_window_focus(not bool(_web_document.hidden) and bool(_web_document.hasFocus()))

func _set_window_focus(focused: bool) -> void:
	if mode == "playing" and not focused:
		pause_game()
	elif mode == "result":
		# The result remains usable immediately. Its short celebration resumes
		# automatically when the page regains focus; play still needs explicit resume.
		_result_focus_paused = not focused
		get_tree().paused = not focused

func _exit_tree() -> void:
	if _web_focus_callback != null:
		_web_window.removeEventListener("blur", _web_focus_callback)
		_web_window.removeEventListener("focus", _web_focus_callback)
		_web_document.removeEventListener("visibilitychange", _web_focus_callback)

func _configure_inputs() -> void:
	var bindings := {"turn_left": [KEY_LEFT, KEY_A], "turn_right": [KEY_RIGHT, KEY_D], "spray": [KEY_SPACE]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)

func _light_office() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f2bf8c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff4e5")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0d9")
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("beddd9")
	fill.light_energy = 0.12
	fill.rotation_degrees = Vector3(-35.0, 140.0, 0.0)
	add_child(fill)

func _create_effects() -> void:
	if is_instance_valid(effects):
		effects.queue_free()
	effects = EffectsScript.new()
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	effects.setup()
	effects.set_quality(effect_level)
	effects.set_volumes(music_volume, sfx_volume)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var now := Time.get_ticks_msec()
	var elapsed_delta := maxf(0.0, float(now - _clock_ms) / 1000.0)
	_clock_ms = now
	var turn := Input.get_axis("turn_left", "turn_right")
	var spraying := Input.is_action_pressed("spray")
	if mode == "playing":
		if not rules.started and (absf(turn) > 0.0 or spraying):
			rules.begin()
		rules.advance(elapsed_delta)
		player.set_controls(turn, spraying)
	else:
		player.set_controls(0.0, false)
	if mode != "paused" and not _result_focus_paused:
		impact_amount = maxf(0.0, impact_amount - delta * 2.6)
		var pose_strength := 0.35 if effect_level == "控えめ" else 1.0
		# Let any arrival heading settle into the authored victory portrait.
		# Only the visual child turns; the finished chair position/time stay fixed.
		actor.rotation.y = lerp_angle(actor.rotation.y, -player.rotation.y, 1.0 - exp(-delta * 7.0)) if mode == "result" else 0.0
		actor.update_pose(delta, player.get_speed() * pose_strength, (turn if mode == "playing" else 0.0) * pose_strength, player.boosting and mode == "playing", impact_amount * pose_strength, rules.rush_timer > 0.0 and effect_level != "控えめ", mode == "result")
		var backward: Vector3 = player.global_basis.z.normalized()
		effects.set_exhaust(actor.nozzle_position(), backward, player.boosting and mode == "playing", rules.rush_timer > 0.0, player.get_speed())
	_update_camera(delta)
	_present()
	if _qa_enabled:
		_qa_timer -= delta
		if _qa_timer <= 0.0:
			_qa_timer = 0.15
			_publish_qa()

func _physics_process(_delta: float) -> void:
	if mode != "playing" or not rules.started:
		return
	var broken: Array = office.try_break(player.global_position, player.get_speed())
	var rewards: Array = rules.register_breaks(broken)
	_present_breaks(rewards)
	if office.is_goal(player.global_position):
		finish_game()

func _present_breaks(rewards: Array) -> void:
	# Each prop keeps its contact effect, while a simultaneous batch has one
	# final combo cue and one rush-entry cue. A running rush is not a new entry.
	if not rewards.is_empty():
		var total_added := 0
		var rush_started := false
		var speed: float = player.get_speed()
		var direction: Vector3 = player.velocity
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.1 else -player.global_basis.z.normalized()
		office.react_to_breaks(rewards, player.global_position, speed)
		for item: Dictionary in rewards:
			var size := 0.8 if int(item.get("base", 0)) < 50000 else 1.2
			var strength := size * lerpf(0.75, 1.25, clampf(speed / 9.0, 0.0, 1.0))
			effects.burst(item.get("position", player.global_position), strength, direction, str(item.get("kind", "paper")))
			total_added += int(item["added"])
			rush_started = rush_started or bool(item.get("rush_started", false))
		var last: Dictionary = rewards.back()
		effects.play_combo(int(last["combo"]))
		if rush_started:
			effects.start_rush(actor.nozzle_position())
			hud.burst("定時ラッシュ！", "+¥" + _money(total_added), "rush")
		else:
			hud.burst(str(last.get("text", "書類、全提出！")), "+¥" + _money(total_added), "impact")
		_impact_reaction(player.get_speed())

func _input(event: InputEvent) -> void:
	# A held spray key must not activate the newly focused Retry button.
	# Consume its repeats and release before GUI input; fresh menu input still works.
	if mode == "result" and _result_spray_held and event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		if not event.pressed:
			_result_spray_held = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_game()
		elif mode == "paused": resume_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R and mode in ["playing", "paused", "result"]:
		start_game()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_SPACE] and mode == "title":
		start_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER and mode == "result":
		start_game()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_set_window_focus(false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_set_window_focus(true)

func start_game() -> void:
	get_tree().paused = false
	_result_focus_paused = false
	_result_spray_held = false
	mode = "playing"
	rules.reset()
	office.reset_props()
	player.reset_at(office.spawn_position)
	actor.rotation.y = 0.0
	player.set_active(true)
	impact_amount = 0.0
	shake = 0.0
	_hit_times.clear()
	_last_hit = -1.0
	new_best = false
	save_error = false
	result.clear()
	_create_effects()
	hud.reset_run()
	_clock_ms = Time.get_ticks_msec()
	_present()
	hud.burst("定時だ。飛べ。", "", "start")

func pause_game() -> void:
	if mode != "playing": return
	mode = "paused"
	player.set_controls(0.0, false)
	_release_input_state()
	get_tree().paused = true
	_present()

func resume_game() -> void:
	if mode != "paused": return
	_release_input_state()
	get_tree().paused = false
	mode = "playing"
	_clock_ms = Time.get_ticks_msec()
	_present()

func show_title() -> void:
	get_tree().paused = false
	_result_focus_paused = false
	_result_spray_held = false
	mode = "title"
	player.set_active(false)
	player.reset_at(office.spawn_position)
	actor.rotation.y = 0.0
	office.reset_props()
	rules.reset()
	_create_effects()
	_present()

func finish_game() -> void:
	if mode != "playing": return
	result = rules.finish()
	_result_spray_held = Input.is_action_pressed("spray") or Input.is_physical_key_pressed(KEY_SPACE)
	mode = "result"
	player.set_active(false)
	new_best = best_time < 0.0 or rules.elapsed < best_time
	if new_best: best_time = rules.elapsed
	best_damage = maxi(best_damage, rules.damage)
	best_combo = maxi(best_combo, rules.max_combo)
	_save_record()
	effects.celebrate(player.global_position + Vector3(0, 1, 0))
	# Enter the result screen before requesting its stamp animation.
	_present()
	hud.burst("退勤成功！", "自己ベスト！" if new_best else "おつかれさまでした！", "success")

func _on_impact(speed: float, at: Vector3, normal: Vector3) -> void:
	if mode != "playing" or speed < 1.4:
		return
	if rules.elapsed - _last_hit < 0.25:
		return
	_last_hit = rules.elapsed
	_impact_reaction(speed)
	effects.impact(at + Vector3.UP * 0.65, normal, clampf(speed / 6.0, 0.6, 1.2))
	hud.burst("壁、定時です！", "", "impact")

func _impact_reaction(speed: float) -> void:
	impact_amount = minf(1.0, speed / 6.0)
	shake = maxf(shake, impact_amount)
	while not _hit_times.is_empty() and rules.elapsed - _hit_times.front() > 1.0:
		_hit_times.pop_front()
	if speed > 3.0 and _hit_times.size() < 2:
		player.hit_stop = 0.08
		_hit_times.append(rules.elapsed)

func _update_camera(delta: float) -> void:
	if mode == "paused" or _result_focus_paused:
		return
	var target: Vector3 = player.get_global_transform_interpolated().origin
	var offset := Vector3(6.4, 9.3, 8.6)
	var look := target + Vector3(0, 0.8, -4.5)
	if mode == "title" or mode == "result":
		# Menus give the comic employee a larger place beside the paper UI.
		offset = Vector3(5.8, 4.4, 6.2)
		look = target + Vector3(-3.0, 1.1, 0.0)
	var wanted := target + offset
	camera.global_position = camera.global_position.lerp(wanted, 1.0 - exp(-delta * 4.0))
	if mode != "paused":
		shake = maxf(0.0, shake - delta * 5.0)
	if effect_level != "控えめ" and shake > 0.0:
		camera.global_position += Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), 0.0) * shake
	camera.look_at(look, Vector3.UP)

func _settings_changed(level: String, music: float, sfx: float) -> void:
	effect_level = level
	if is_instance_valid(office):
		office.set_feedback_quality(level)
	music_volume = music
	sfx_volume = sfx
	if is_instance_valid(effects):
		effects.set_quality(level)
		effects.set_volumes(music, sfx)

func _release_input_state() -> void:
	for code: int in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_SPACE]:
		var released := InputEventKey.new()
		released.keycode = code
		released.physical_keycode = code
		released.pressed = false
		Input.parse_input_event(released)
	for action: String in ["turn_left", "turn_right", "spray"]:
		Input.action_release(action)

func _present() -> void:
	if not is_instance_valid(hud): return
	var data := {"elapsed": rules.elapsed, "damage": rules.damage, "combo": rules.combo, "multiplier": mini(rules.combo, 3), "pressure": player.pressure, "distance": office.distance_to_goal(player.global_position), "max_combo": rules.max_combo, "rank": str(result.get("rank", "")), "rank_text": str(result.get("rank_text", "")), "best_time": best_time, "new_best": new_best, "save_error": save_error, "speed": player.get_speed(), "boosting": player.boosting, "rush": rules.rush_timer > 0.0, "impact": impact_amount}
	hud.present(mode, data)

func _load_record() -> void:
	if not FileAccess.file_exists("user://record.json"): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://record.json"))
	if not parsed is Dictionary: return
	var saved_time := float(parsed.get("best_time", -1.0))
	if is_finite(saved_time) and saved_time > 0.0: best_time = saved_time
	best_damage = maxi(0, int(parsed.get("best_damage", 0)))
	best_combo = maxi(0, int(parsed.get("best_combo", 0)))

func _save_record() -> void:
	var file := FileAccess.open("user://record.json", FileAccess.WRITE)
	if file == null:
		save_error = true
		return
	file.store_string(JSON.stringify({"best_time": best_time, "best_damage": best_damage, "best_combo": best_combo}))
	file.close()

func _publish_qa() -> void:
	var p: Vector3 = player.global_position
	var state := {"mode": mode, "elapsed": rules.elapsed, "pressure": player.pressure, "speed": player.get_speed(), "damage": rules.damage, "combo": rules.combo, "max_combo": rules.max_combo, "yaw": player.rotation.y, "actor_yaw": actor.global_rotation.y, "player": [p.x, p.y, p.z], "rank": result.get("rank", ""), "broken": rules.seen.size(), "best_time": best_time, "quality": effect_level, "music_volume": music_volume, "sfx_volume": sfx_volume, "rush": rules.rush_timer > 0.0, "hud": hud.debug_snapshot(), "fx": effects.debug_snapshot(), "office": office.debug_feedback_snapshot(), "fps": Engine.get_frames_per_second(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
	JavaScriptBridge.eval("window.__taikin = " + JSON.stringify(state) + ";")

static func _money(value: int) -> String:
	var text := str(value)
	var out := ""
	for i in range(text.length()):
		if i > 0 and (text.length() - i) % 3 == 0: out += ","
		out += text[i]
	return out
