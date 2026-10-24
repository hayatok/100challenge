extends Node3D

const RIDER_SCENE = preload("res://scenes/rider.tscn")
const SENTRY_SCRIPT = preload("res://scripts/sentry.gd")
const ASSET_SCRIPT = preload("res://scripts/asset_loader.gd")
const CLOUD_SCRIPT = preload("res://scripts/cloudscape.gd")
const RECORD_PATH := "user://cloudsea-records.json"
@export var record_path := RECORD_PATH
const GATES := [100.0, 220.0, 400.0, 610.0, 760.0, 940.0, 1160.0, 1320.0, 1510.0]
const SENTRIES := [280.0, 550.0, 880.0, 1180.0, 1440.0]

@onready var course = $Course
@onready var camera = $FollowCamera
@onready var ui = $Interface
var rider
var assets
var sound
var cloudscape
var state := "title"
var time := 0.0
var score := 0
var falls := 0
var flow := 0
var flow_left := 0.0
var countdown := 0.0
var recover_left := 0.0
var event_ids: Dictionary = {}
var failed_sections: Dictionary = {}
var notice := ""
var notice_left := 0.0
var previous_progress := 0.0
var records: Dictionary = {"best_time": 0.0, "best_score": 0}
var settings: Dictionary = {"reduced_motion": false, "master_volume": 0.65}
var _settings_origin := "title"
var _was_boosting := false
var _was_grounded := false
var _qa := false
var _auto := false
var _qa_next := 0.0
var _jump_gap := -1.0


func _ready() -> void:
	_setup_inputs()
	_setup_environment()
	_load_records()
	assets = ASSET_SCRIPT.new()
	add_child(assets)
	rider = RIDER_SCENE.instantiate()
	rider.course = course
	add_child(rider)
	rider.reset_run()
	rider.fell.connect(_on_fall)
	rider.landed.connect(_on_landed)
	rider.jumped.connect(_on_jumped)
	cloudscape = CLOUD_SCRIPT.new()
	cloudscape.follow_rider = rider
	add_child(cloudscape)
	assets.attach_rider(rider)
	assets.decorate_course(course)
	_add_gate_markers()
	for index in SENTRIES.size():
		var sentry = SENTRY_SCRIPT.new()
		sentry.course = course
		sentry.rider = rider
		sentry.s = SENTRIES[index]
		sentry.side = -1.0 if index % 2 == 0 else 1.0
		sentry.event_id = "sentry_%d" % index
		sentry.passed.connect(_on_sentry_passed)
		sentry.hit.connect(_on_hit)
		sentry.name = "Sentry%d" % index
		add_child(sentry)
		assets.attach_sentry(sentry)
	camera.rider = rider
	camera.course = course
	camera.reset_camera()
	if ResourceLoader.exists("res://scripts/soundscape.gd"):
		sound = load("res://scripts/soundscape.gd").new()
		add_child(sound)
	ui.start_requested.connect(_start_run)
	ui.retry_requested.connect(_start_run)
	ui.resume_requested.connect(_resume)
	ui.title_requested.connect(_show_title)
	ui.settings_requested.connect(_show_settings)
	ui.settings_closed.connect(_close_settings)
	ui.settings_changed.connect(_apply_settings)
	_apply_settings(settings)
	_show_title()
	_qa = OS.get_cmdline_user_args().has("--qa")
	_auto = OS.get_cmdline_user_args().has("--auto-run")
	if _auto:
		_start_run()
	print("CLOUDSEA_READY assets=%d" % assets.loaded_assets)


func _process(delta: float) -> void:
	if state == "countdown":
		countdown -= delta
		ui.set_screen("countdown", {"count": maxi(1, ceili(countdown)), "caption": "風を読んで、走り出そう"})
		if countdown <= 0.0:
			state = "run"
			ui.set_screen("run")
			rider.set_active(recover_left <= 0.0)
			_set_hazards_active(recover_left <= 0.0)
	elif state == "run":
		time += delta
		flow_left = maxf(0.0, flow_left - delta)
		if flow_left == 0.0:
			flow = 0
		notice_left = maxf(0.0, notice_left - delta)
		if notice_left == 0.0:
			notice = ""
		if recover_left > 0.0:
			recover_left -= delta
			if recover_left <= 0.0:
				var checkpoint: float = course.checkpoint_at(rider.progress)
				rider.reset_to(checkpoint, maxf(40.0, rider.wind_energy))
				previous_progress = checkpoint
				camera.reset_camera()
				rider.set_active(true)
				_set_hazards_active(true)
		else:
			_process_events()
			if rider.progress >= course.length:
				_finish()
			if sound:
				sound.set_speed(rider.speed, rider.boosting)
				if rider.boosting and not _was_boosting:
					sound.cue("boost")
				if not rider.is_on_floor() and _was_grounded and rider.velocity.y > 2.0:
					sound.cue("jump")
			_was_boosting = rider.boosting
			_was_grounded = rider.is_on_floor()
		_update_hud()
	if _qa:
		_qa_next -= delta
		if _qa_next <= 0.0:
			_write_qa()
			_qa_next = 0.25


func _unhandled_input(event: InputEvent) -> void:
	if _qa and event is InputEventKey and event.pressed and event.physical_keycode == KEY_F12:
		_capture_qa()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == "run" or state == "countdown":
			_pause()
		elif state == "pause":
			_resume()
		get_viewport().set_input_as_handled()


func _capture_qa() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://qa-%s.png" % state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and (state == "run" or state == "countdown"):
		_pause()


func _start_run() -> void:
	get_tree().paused = false
	_release_inputs()
	time = 0.0
	score = 0
	falls = 0
	flow = 0
	flow_left = 0.0
	recover_left = 0.0
	event_ids.clear()
	failed_sections.clear()
	notice = ""
	notice_left = 0.0
	previous_progress = 0.0
	_jump_gap = -1.0
	for sentry in get_tree().get_nodes_in_group("sentries"):
		sentry.reset_run()
	rider.reset_run()
	_set_hazards_active(false)
	camera.title_view = false
	camera.reset_camera()
	countdown = 3.0
	state = "countdown"
	ui.set_screen("countdown", {"count": 3})
	if sound:
		sound.cue("count")


func _show_title() -> void:
	get_tree().paused = false
	state = "title"
	_release_inputs()
	rider.reset_run()
	_set_hazards_active(false)
	camera.title_view = true
	camera.reset_camera()
	ui.set_screen("title", records)
	if sound:
		sound.set_speed(0.0, false)


func _pause() -> void:
	state = "pause"
	rider.set_active(false)
	_set_hazards_active(false)
	get_tree().paused = true
	ui.set_screen("pause")


func _resume() -> void:
	_release_inputs()
	get_tree().paused = false
	countdown = 3.0
	state = "countdown"
	ui.set_screen("countdown", {"count": 3, "caption": "続けます"})


func _show_settings() -> void:
	_settings_origin = state
	state = "settings"
	ui.set_screen("settings", settings)


func _close_settings() -> void:
	state = _settings_origin
	ui.set_screen(state, records if state == "title" else {})


func _apply_settings(values: Dictionary) -> void:
	settings.merge(values, true)
	camera.reduced_motion = bool(settings.get("reduced_motion", false))
	cloudscape.reduced_motion = camera.reduced_motion
	if is_instance_valid(assets.pose_controller):
		assets.pose_controller.reduced_motion = camera.reduced_motion
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings.get("master_volume", 0.65)))))
	_save_records()


func _process_events() -> void:
	for index in GATES.size():
		var s: float = GATES[index]
		var id := "gate_%d" % index
		if previous_progress < s and rider.progress >= s and not event_ids.has(id):
			var center: Vector3 = course.center_at(s)
			if absf(rider.lateral) <= course.half_width_at(s) and rider.global_position.y >= center.y - 0.5 and rider.global_position.y <= center.y + 5.0:
				event_ids[id] = true
				_award(100, "GATE", 20.0)
	previous_progress = rider.progress


func _on_landed() -> void:
	var jump_gap := _jump_gap
	_jump_gap = -1.0
	if state != "run":
		return
	if sound:
		sound.cue("land")
	for gap in [460.0, 1080.0]:
		var id := "landing_%d" % int(gap)
		var center: Vector3 = course.center_at(rider.progress)
		if jump_gap == gap and rider.progress >= gap + 8.0 and rider.progress <= gap + 35.0 and rider.lateral < -1.5 and rider.global_position.y - center.y > 1.5 and not event_ids.has(id):
			event_ids[id] = true
			if not failed_sections.has(_section()):
				_award(100, "CLEAN", 10.0)


func _on_jumped() -> void:
	_jump_gap = -1.0
	var center: Vector3 = course.center_at(rider.progress)
	for gap in [460.0, 1080.0]:
		if rider.progress >= gap - 22.0 and rider.progress <= gap + 2.0 and rider.lateral < -1.5 and rider.global_position.y - center.y > 1.5:
			_jump_gap = gap


func _on_sentry_passed(id: String, near: bool) -> void:
	if state != "run" or event_ids.has(id):
		return
	event_ids[id] = true
	if near and not failed_sections.has(_section()):
		_award(150, "NEAR", 10.0)


func _on_hit() -> void:
	if state != "run" or recover_left > 0.0:
		return
	flow = 0
	flow_left = 0.0
	_jump_gap = -1.0
	_show_notice("減速")
	if sound:
		sound.cue("hit")


func _on_fall() -> void:
	if state != "run" or recover_left > 0.0:
		return
	falls += 1
	time += 3.0
	flow = 0
	flow_left = 0.0
	failed_sections[_section()] = true
	recover_left = 1.0
	_jump_gap = -1.0
	_set_hazards_active(false)
	_show_notice("チェックポイントへ復帰 · 追加 +3.00秒")


func _award(base: int, label: String, energy: float) -> void:
	flow += 1
	flow_left = 6.0
	var points := int(round(base * _multiplier()))
	score += points
	rider.grant_energy(energy)
	_show_notice("%s +%d" % [label, points])
	if sound:
		sound.cue("gate")


func _show_notice(text: String) -> void:
	notice = text
	notice_left = 1.2


func _multiplier() -> float:
	return 1.0 + 0.25 * mini(maxi(0, flow - 1), 4)


func _section() -> int:
	return clampi(int(rider.progress / 330.0), 0, 4)


func _update_hud() -> void:
	ui.update_hud({"time": time, "speed": rider.speed, "energy": rider.wind_energy,
		"score": score, "flow": _multiplier(), "progress": rider.progress / course.length,
		"section": "%d / 5" % (_section() + 1), "notice": notice})


func _finish() -> void:
	state = "results"
	rider.set_active(false)
	_set_hazards_active(false)
	_release_inputs()
	var new_time := float(records.get("best_time", 0.0)) <= 0.0 or time < float(records.get("best_time", 0.0))
	var new_score := score > int(records.get("best_score", 0))
	if new_time:
		records["best_time"] = time
	if new_score:
		records["best_score"] = score
	var saved := _save_records()
	ui.set_screen("results", {"time": time, "score": score, "falls": falls,
		"best_time": records.get("best_time", 0.0), "best_score": records.get("best_score", 0),
		"new_best_time": new_time, "new_best_score": new_score, "saved": saved})
	if sound:
		sound.cue("finish")
	print("CLOUDSEA_FINISH time=%.2f score=%d falls=%d" % [time, score, falls])


func _load_records() -> void:
	if not FileAccess.file_exists(record_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	if parsed is Dictionary:
		if parsed.get("best_time") is float or parsed.get("best_time") is int:
			records["best_time"] = maxf(0.0, float(parsed["best_time"]))
		if parsed.get("best_score") is float or parsed.get("best_score") is int:
			records["best_score"] = maxi(0, int(parsed["best_score"]))
		if parsed.get("settings") is Dictionary:
			var stored: Dictionary = parsed["settings"]
			if stored.get("reduced_motion") is bool:
				settings["reduced_motion"] = stored["reduced_motion"]
			if stored.get("master_volume") is float or stored.get("master_volume") is int:
				settings["master_volume"] = clampf(float(stored["master_volume"]), 0.0, 1.0)


func _save_records() -> bool:
	var file := FileAccess.open(record_path, FileAccess.WRITE)
	if file == null:
		return false
	var data := records.duplicate()
	data["settings"] = settings
	file.store_string(JSON.stringify(data))
	return file.get_error() == OK


func _setup_inputs() -> void:
	var keys := {"steer_left": KEY_A, "steer_right": KEY_D, "brake": KEY_S,
		"jump": KEY_SPACE, "boost": KEY_SHIFT, "pause": KEY_ESCAPE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.18)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for entry in [["steer_left", JOY_AXIS_LEFT_X, -1.0], ["steer_right", JOY_AXIS_LEFT_X, 1.0],
		["brake", JOY_AXIS_TRIGGER_LEFT, 1.0], ["boost", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = entry[1]
		axis.axis_value = entry[2]
		InputMap.action_add_event(entry[0], axis)
	for entry in [["jump", JOY_BUTTON_A], ["pause", JOY_BUTTON_START]]:
		var button := InputEventJoypadButton.new()
		button.button_index = entry[1]
		InputMap.action_add_event(entry[0], button)


func _release_inputs() -> void:
	for action in ["steer_left", "steer_right", "brake", "jump", "boost"]:
		Input.action_release(action)


func _setup_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	sun.light_color = Color("fff0d3")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("428ac6")
	sky_material.sky_horizon_color = Color("aacfe1")
	sky_material.ground_horizon_color = Color("aacfe1")
	sky_material.ground_bottom_color = Color("9dcbdc")
	sky_material.sky_curve = 0.45
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7d9ec")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	environment.fog_enabled = true
	environment.fog_light_color = Color("d9e9ee")
	environment.fog_density = 0.0006
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _set_hazards_active(value: bool) -> void:
	for sentry in get_tree().get_nodes_in_group("sentries"):
		sentry.active = value


func _add_gate_markers() -> void:
	var ribbon := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("168b8c")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for index in range(65):
		var angle := TAU * float(index) / 64.0
		for inset in [-0.12, 0.12]:
			ribbon.surface_add_vertex(Vector3(cos(angle) * (7.5 + inset), sin(angle) * (3.2 + inset), 0.0))
	ribbon.surface_end()
	for s in GATES + [1650.0]:
		var marker := MeshInstance3D.new()
		marker.name = "WindGate%d" % int(s)
		marker.mesh = ribbon
		marker.position = course.center_at(s) + Vector3.UP * 2.8
		var tangent: Vector3 = course.tangent_at(s)
		marker.rotation.y = atan2(-tangent.x, -tangent.z)
		add_child(marker)


func _write_qa() -> void:
	var file := FileAccess.open("user://qa-state.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"state": state, "time": time, "score": score, "falls": falls,
			"progress": rider.progress, "lateral": rider.lateral, "speed": rider.speed,
			"energy": rider.wind_energy, "position": [rider.position.x, rider.position.y, rider.position.z],
			"assets_loaded": assets.loaded_assets, "paused": get_tree().paused,
			"fps": Engine.get_frames_per_second(),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}))
