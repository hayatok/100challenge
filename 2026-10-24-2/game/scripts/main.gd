extends Node3D

const RIDER_SCENE = preload("res://scenes/rider.tscn")
const SENTRY_SCRIPT = preload("res://scripts/sentry.gd")
const ASSET_SCRIPT = preload("res://scripts/asset_loader.gd")
const CLOUD_SCRIPT = preload("res://scripts/cloudscape.gd")
const RECORD_PATH := "user://cloudsea-carve-v2.json"
const LEGACY_RECORD_PATH := "user://cloudsea-records.json"
@export var record_path := RECORD_PATH
const GATES := [155.0, 275.0, 420.0, 560.0, 610.0, 795.0, 890.0]
const SENTRIES := [340.0, 690.0]

@onready var course = $Course
@onready var camera = $FollowCamera
@onready var ui = $Interface
var rider
var assets
var sound
var effects
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
var _countdown_caption := "風を読んで、走り出そう"
var _resuming := false


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
	rider.carve_released.connect(_on_carve_released)
	rider.burst_started.connect(_on_burst_started)
	rider.clean_landed.connect(_on_clean_landed)
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
	effects = preload("res://scripts/effects.gd").new()
	effects.rider = rider
	effects.course = course
	add_child(effects)
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
		ui.set_screen("countdown", {"count": "READY" if countdown > 0.35 else "GO", "caption": _countdown_caption})
		if countdown <= 0.0:
			get_tree().paused = false
			state = "run"
			_pose_context("running" if recover_left <= 0.0 else "recovery")
			if recover_left <= 0.0 and not _resuming:
				_pose_event("start", 1.0)
			ui.set_screen("run")
			rider.set_active(recover_left <= 0.0)
			_set_hazards_active(recover_left <= 0.0)
			_resuming = false
		_update_hud()
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
				rider.reset_to(checkpoint, maxf(48.0, rider.wind_energy))
				_pose_context("running")
				previous_progress = checkpoint
				camera.reset_camera()
				_reset_feedback()
				rider.set_active(true)
				_set_hazards_active(true)
		else:
			_process_events()
			if rider.progress >= course.length and rider.is_on_floor() and absf(rider.lateral) <= course.half_width_at(rider.progress):
				_finish()
			if sound:
				sound.set_speed(rider.speed, rider.boosting)
				sound.set_motion(rider.carve_amount, rider.carve_charge, not rider.is_on_floor())
				if not rider.boosting and _was_boosting:
					_pose_event("boost_end", 1.0)

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
	_resuming = false
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
	_reset_feedback()
	_set_hazards_active(false)
	camera.title_view = false
	camera.reset_camera()
	countdown = 1.2
	_countdown_caption = "風を読んで、走り出そう"
	_pose_reset()
	_pose_context("countdown")
	state = "countdown"
	ui.set_screen("countdown", {"count": "READY"})
	if sound:
		sound.cue("count")


func _show_title() -> void:
	_resuming = false
	get_tree().paused = false
	state = "title"
	_release_inputs()
	rider.reset_run()
	_reset_feedback()
	_set_hazards_active(false)
	_pose_context("idle")
	camera.title_view = true
	camera.reset_camera()
	ui.set_screen("title", records)
	if sound:
		sound.set_speed(0.0, false)


func _pause() -> void:
	state = "pause"
	rider.set_active(false)
	_set_hazards_active(false, true)
	get_tree().paused = true
	ui.set_screen("pause")


func _resume() -> void:
	_release_inputs()
	_resuming = true
	# Main and UI process ALWAYS; keep the exact airborne pose, audio and world
	# frozen until the resume cue finishes.
	get_tree().paused = true
	countdown = 1.2
	_countdown_caption = "進路を見て、もう一度。"
	state = "countdown"
	ui.set_screen("countdown", {"count": "READY", "caption": _countdown_caption})


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
	if effects:
		effects.reduced_motion = camera.reduced_motion
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
			if absf(rider.lateral) <= course.half_width_at(s) - 0.3 and rider.global_position.y >= center.y - 0.5 and rider.global_position.y <= center.y + 5.0:
				event_ids[id] = true
				_award(60, "LINE", 6.0)
	previous_progress = rider.progress


func _on_landed() -> void:
	if state != "run":
		return
	_pose_event("land", rider.landing_strength)
	_feedback_cue("land", rider.landing_strength)
	if _jump_gap >= 0.0:
		var gap: Vector2 = course.gap_at(_jump_gap + 0.1)
		var id := "landing_%d" % int(_jump_gap)
		if rider.progress >= gap.y and rider.progress < gap.y + 38.0 and not event_ids.has(id):
			event_ids[id] = true
			_award(140, "FLIGHT", 10.0)
	_jump_gap = -1.0


func _on_jumped() -> void:
	_jump_gap = -1.0
	var gap: Vector2 = course.next_gap_at(rider.progress)
	if gap != Vector2.ZERO and rider.progress >= gap.x - 22.0:
		_jump_gap = gap.x
	_pose_event("jump", 1.0)
	_feedback_cue("jump", 1.0)


func _on_carve_released(charge: float) -> void:
	if state == "run" and charge >= 0.22:
		_feedback_cue("release", charge)
		_award_motion(int(40.0 + charge * 60.0), "CARVE")


func _on_burst_started(strength: float) -> void:
	_pose_event("boost_start", strength)
	_feedback_cue("boost", strength)


func _on_clean_landed(strength: float) -> void:
	if state == "run":
		_feedback_cue("clean", strength)
		_award_motion(int(70.0 + strength * 50.0), "CLEAN")


func _on_sentry_passed(id: String, near: bool) -> void:
	if state != "run" or event_ids.has(id):
		return
	event_ids[id] = true
	if near and not failed_sections.has(_section()):
		_feedback_cue("near", 1.0)
		_award(150, "NEAR", 10.0)


func _on_hit() -> void:
	if state != "run" or recover_left > 0.0:
		return
	flow = 0
	flow_left = 0.0
	_jump_gap = -1.0
	_pose_event("hit", 1.0)
	_show_notice("HIT · 風をつなぎ直そう")
	_feedback_cue("hit", 1.0)


func _on_fall() -> void:
	if state != "run" or recover_left > 0.0:
		return
	falls += 1
	time += 3.0
	flow = 0
	flow_left = 0.0
	failed_sections[_section()] = true
	recover_left = 0.65
	_pose_context("recovery")
	_jump_gap = -1.0
	_set_hazards_active(false)
	var cause := "着地に届かなかった" if rider.fall_reason == &"missed_platform" else "風路を外れた"
	_show_notice("%s · 復帰 +3.00秒" % cause)
	if sound:
		sound.cue("hit")


func _award_motion(base: int, label: String) -> void:
	# A recovery keeps physical rewards but cannot rescore already travelled ground.
	if rider.progress < rider.max_progress - 0.1:
		return
	var id := "%s_%d" % [label, floori(rider.progress / 20.0)]
	if event_ids.has(id):
		return
	event_ids[id] = true
	_award(base, label, 0.0)


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
	return int(course.beat_at(rider.progress).index)


func _update_hud() -> void:
	var beat: Dictionary = course.beat_at(rider.progress)
	var gap: Vector2 = course.next_gap_at(rider.progress)
	ui.update_hud({"time": time, "speed": rider.speed, "energy": rider.wind_energy,
		"score": score, "flow": _multiplier(), "progress": rider.progress / course.length,
		"section": "%d / 5" % (_section() + 1), "notice": notice,
		"carving": rider.carving, "carve_charge": rider.carve_charge, "charge_rate": rider.charge_rate,
		"charge_requires_press": rider.charge_requires_press,
		"burst_left": rider.burst_left, "beat": beat.name, "hint": beat.hint,
		"gap_ahead": gap.x - rider.progress if gap != Vector2.ZERO else -1.0})


func _finish() -> void:
	state = "results"
	_pose_context("finish")
	_pose_event("finish", 1.0)
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
	var source_path: String = record_path
	var same_course := true
	if not FileAccess.file_exists(source_path):
		if record_path == RECORD_PATH and FileAccess.file_exists(LEGACY_RECORD_PATH):
			source_path = LEGACY_RECORD_PATH
			same_course = false
		else:
			return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if parsed is Dictionary:
		if same_course and (parsed.get("best_time") is float or parsed.get("best_time") is int):
			records["best_time"] = maxf(0.0, float(parsed["best_time"]))
		if same_course and (parsed.get("best_score") is float or parsed.get("best_score") is int):
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
	data["course_revision"] = 2
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


func _set_hazards_active(value: bool, preserve_feedback: bool = false) -> void:
	if effects and not preserve_feedback:
		effects.set_active(value)
	if not value and sound and not preserve_feedback:
		sound.set_speed(0.0, false)
		sound.set_motion(0.0, 0.0, false)
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
	for s in GATES + [course.length]:
		var marker := MeshInstance3D.new()
		marker.name = "WindGate%d" % int(s)
		marker.mesh = ribbon
		marker.scale.x = course.half_width_at(s) / 7.5
		marker.position = course.center_at(s) + Vector3.UP * 2.8
		var tangent: Vector3 = course.tangent_at(s)
		marker.rotation.y = atan2(-tangent.x, -tangent.z)
		add_child(marker)


func _write_qa() -> void:
	var file := FileAccess.open("user://qa-state.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"state": state, "time": time, "score": score, "falls": falls,
			"progress": rider.progress, "lateral": rider.lateral, "speed": rider.speed,
			"heading": rider.heading, "carving": rider.carving, "charge": rider.carve_charge,
			"burst_left": rider.burst_left, "airborne_time": rider.airborne_time,
			"energy": rider.wind_energy, "position": [rider.position.x, rider.position.y, rider.position.z],
			"assets_loaded": assets.loaded_assets, "paused": get_tree().paused,
			"fps": Engine.get_frames_per_second(),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}))


func _pose_context(context: String) -> void:
	if assets and is_instance_valid(assets.pose_controller) and assets.pose_controller.has_method("set_motion_context"):
		assets.pose_controller.set_motion_context(context)


func _pose_event(event: String, strength: float) -> void:
	if assets and is_instance_valid(assets.pose_controller) and assets.pose_controller.has_method("trigger_motion"):
		assets.pose_controller.trigger_motion(event, strength)


func _pose_reset() -> void:
	if assets and is_instance_valid(assets.pose_controller) and assets.pose_controller.has_method("reset_motion"):
		assets.pose_controller.reset_motion()


func _feedback_cue(kind: String, strength: float = 1.0) -> void:
	if sound:
		sound.cue(kind)
	if effects:
		effects.cue(kind, strength)
	if camera.has_method("cue"):
		camera.cue(kind, strength)


func _reset_feedback() -> void:
	_was_boosting = false
	_was_grounded = false
	if effects:
		effects.reset_effects()
	if sound:
		sound.reset_audio()
