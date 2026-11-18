extends Node3D

const Simulation := preload("res://race/RaceSimulation.gd")
const Effects := preload("res://presentation/RaceEffects.gd")
const Racer := preload("res://racers/RacerVisual.gd")
const DRAG_THRESHOLD := 9.0
const TAP_SECONDS := 0.33
const FINISH_DISTANCE := 150.0

@onready var course := $ShiokazeWharf
@onready var cam: Camera3D = $FollowCamera
@onready var chase_offset: Vector3 = $ChaseOffset.position
@onready var chase_focus: Vector3 = $ChaseLookAhead.position
@onready var hud := $Overlay/HUD
@onready var audio := $Audio

var effects := Effects.new()
var sim := Simulation.new()
var figures: Array[Node3D] = []
var shadows: Array[MeshInstance3D] = []
var mode := "title"
var before_pause := "racing"
var countdown := 0.0
var last_count := 0
var idle_time := 0.0
var finish_elapsed := 0.0
var target_x := 0.0
var jump_queued := false
var hold_direction := 0
var active_pointer := -1
var press_origin := Vector2.ZERO
var press_x := 0.0
var press_msec := 0
var dragged := false
var camera_x := 0.0
var last_state := "idle"
var foot_half := -1
var settings := ConfigFile.new()
var reduced := false
var sfx := true
var song := true
var web_pause_callback: JavaScriptObject
var web_window: JavaScriptObject

func _ready() -> void:
	add_child(effects)
	for i in 6:
		var shadow := _contact_shadow()
		$Racers.add_child(shadow)
		shadows.append(shadow)
		var figure := Racer.new()
		$Racers.add_child(figure)
		figure.setup(i)
		for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			mesh.set_layer_mask_value(2, true)
		figures.append(figure)
	settings.load("user://preferences.cfg")
	var system_reduced := false
	if OS.has_feature("web"):
		web_window = JavaScriptBridge.get_interface("window")
		system_reduced = bool(web_window.matchMedia("(prefers-reduced-motion: reduce)").matches)
		web_pause_callback = JavaScriptBridge.create_callback(_on_web_visibility)
		web_window.document.addEventListener("visibilitychange", web_pause_callback)
	reduced = settings.get_value("display", "motion", system_reduced)
	sfx = settings.get_value("audio", "sound", true)
	song = settings.get_value("audio", "music", true)
	hud.set_options(reduced, sfx, song)
	hud.start_requested.connect(start_race)
	hud.pause_requested.connect(pause_race)
	hud.resume_requested.connect(resume_race)
	hud.jump_requested.connect(func(): jump_queued = true)
	hud.steering_changed.connect(func(direction): hold_direction = direction)
	hud.option_changed.connect(_option_changed)
	_sync_figures()
	_grid_camera()
	# The title is fully illustrated. Avoid drawing a covered 3D viewport every frame.
	get_viewport().disable_3d = true

func _exit_tree() -> void:
	if web_window and web_pause_callback:
		web_window.document.removeEventListener("visibilitychange", web_pause_callback)

func _on_web_visibility(_arguments: Array) -> void:
	if web_window.document.hidden:
		pause_race()

func _contact_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var disk := PlaneMesh.new()
	disk.size = Vector2(0.92, 0.70)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.60, 1.0])
	gradient.colors = PackedColorArray([Color("#49304e77"),Color("#49304e38"),Color("#49304e00")])
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	disk.material = mat
	shadow.mesh = disk
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow

func _option_changed(option: String, value: bool) -> void:
	match option:
		"motion":
			reduced = value
			settings.set_value("display", option, value)
		"sound":
			sfx = value
			settings.set_value("audio", option, value)
		"music":
			song = value
			settings.set_value("audio", option, value)
	settings.save("user://preferences.cfg")

func _reset_input() -> void:
	active_pointer = -1
	dragged = false
	jump_queued = false
	hold_direction = 0

func start_race() -> void:
	get_viewport().disable_3d = false
	sim.reset()
	_reset_input()
	target_x = sim.runners[0].x
	camera_x = target_x
	mode = "countdown"
	countdown = 2.5
	last_count = 3
	finish_elapsed = 0.0
	idle_time = 0.0
	foot_half = -1
	last_state = "idle"
	audio.reset()
	effects.reset()
	hud.set_mode(mode)
	hud.update_race(1, 0, true)
	hud.set_count("3")
	_play("count")
	_sync_figures()
	_grid_camera()

func pause_race() -> void:
	if mode not in ["racing", "countdown"]:
		return
	before_pause = mode
	mode = "paused"
	_reset_input()
	audio.suspend(true)
	hud.set_mode(mode)

func resume_race() -> void:
	if mode != "paused":
		return
	mode = before_pause
	_reset_input()
	audio.suspend(false)
	audio.set_music_enabled(song)
	hud.set_mode(mode)
	if mode == "countdown":
		hud.set_count(str(last_count))
	else:
		hud.update_race(sim.rank_of(0), float(sim.runners[0].p)/FINISH_DISTANCE, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready():
			pause_race()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if mode == "paused":
				resume_race()
			else:
				pause_race()
			get_viewport().set_input_as_handled()
		elif mode == "racing" and (event.keycode == KEY_SPACE or event.keycode == KEY_UP):
			jump_queued = true
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "racing" or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == active_pointer:
				active_pointer = -1
			return
		_pointer(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(-2, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		_drag(-2, event.position)

func _pointer(id: int, point: Vector2, down: bool) -> void:
	if down:
		if active_pointer != -1 or hud.over_race_button(point):
			return
		active_pointer = id
		press_origin = point
		press_x = target_x
		press_msec = Time.get_ticks_msec()
		dragged = false
	elif id == active_pointer:
		_drag(id, point)
		if not dragged and Time.get_ticks_msec() - press_msec < TAP_SECONDS * 1000.0:
			jump_queued = true
		active_pointer = -1

func _drag(id: int, point: Vector2) -> void:
	if id != active_pointer:
		return
	var delta := point - press_origin
	if delta.length() >= DRAG_THRESHOLD:
		dragged = true
	if dragged:
		var distance: float = delta.x / minf(480.0, hud.size.x) * 14.5
		target_x = clampf(press_x + distance, -5.2, 9.0)

func _physics_process(dt: float) -> void:
	if mode == "title" or mode == "paused":
		return
	idle_time += dt
	effects.advance(dt)
	if mode == "countdown":
		countdown -= dt
		var tick := ceili(countdown / 0.84)
		if tick != last_count and tick > 0:
			last_count = tick
			_play("count")
			hud.set_count(str(tick))
		for i in figures.size():
			figures[i].pose("idle", idle_time, fposmod(idle_time + i*0.13, 1.0), 0.0)
		if countdown > 1.64 and not reduced:
			_grid_camera(true)
		elif countdown > 0.76:
			_grid_camera()
		if countdown <= 0.76:
			_chase_camera(dt, false)
		if countdown <= 0.0:
			mode = "racing"
			hud.set_mode(mode)
			audio.start_music(song)
			_play("go")
		return
	var player: Dictionary = sim.runners[0]
	var before_respawn: int = player.respawns
	var steer := hold_direction + int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	if mode == "racing" and steer != 0:
		# Keep the target close while steering with buttons. Releasing is an immediate stop.
		target_x = clampf(float(player.x) + signf(steer) * 0.5, -5.2, 9.0)
	sim.step(dt, target_x, jump_queued and mode == "racing")
	jump_queued = false
	if before_respawn != player.respawns:
		_reset_input()
		target_x = player.x
		camera_x = player.x
	_sync_figures()
	if mode == "result":
		finish_elapsed += dt
		_result_camera(dt)
		return
	_player_sounds(player)
	_chase_camera(dt, before_respawn != player.respawns)
	hud.set_marker(cam.unproject_position(figures[0].position + Vector3.UP * 1.65))
	hud.update_race(sim.rank_of(0), float(player.p)/FINISH_DISTANCE, reduced)
	if player.finish_time >= 0.0:
		mode = "result"
		_reset_input()
		finish_elapsed = 0.0
		audio.end_music()
		if not reduced:
			effects.burst(figures[0].position, "finish")
		_play("finish")
		hud.show_result(sim.rank_of(0), player.finish_time)

func _sync_figures() -> void:
	course.set_mechanisms(sim.bridge_angle, sim.bar_angles, sim.time)
	for i in figures.size():
		var r: Dictionary = sim.runners[i]
		figures[i].position = Vector3(r.x, r.y, -r.p)
		figures[i].rotation.y = -float(r.steer) * 0.17
		figures[i].pose(r.state, r.elapsed, r.phase, r.steer)
		var floor_y: float = sim._surface(r.x, r.p)
		var shadow := shadows[i]
		shadow.visible = r.state != "fall" and is_finite(floor_y) and floor_y > -1.5
		if shadow.visible:
			shadow.position = Vector3(r.x, floor_y + 0.025, -r.p)
			shadow.rotation.x = sim.bridge_angle if sim._on_bridge(r.x, r.p) else 0.0
			shadow.scale = Vector3.ONE * clampf(1.0 - (float(r.y) - floor_y) * 0.16, 0.6, 1.0)

func _grid_camera(wide := false) -> void:
	if wide:
		var aspect := get_viewport().get_visible_rect().size.aspect()
		var distance := maxf(5.8, 8.0 / (aspect * 1.06))
		cam.position = Vector3(0.0, 1.79, -distance)
		cam.look_at(Vector3(0, 0.9, 0))
		return
	var x := float(sim.runners[0].x)
	cam.position = Vector3(x + 1.0, 1.45, -3.4)
	cam.look_at(Vector3(x, 0.79, 0.0))

func _chase_camera(dt: float, snap: bool) -> void:
	var r: Dictionary = sim.runners[0]
	camera_x = lerpf(camera_x, r.x, 1.0-exp(-7.0*dt))
	var base := Vector3(camera_x, 0, -r.p)
	var floor_y: float = sim._surface(r.x, r.p)
	if is_finite(floor_y):
		base.y = clampf(floor_y, -0.55, 0.8)
	var follow := base + chase_offset
	var focus := base + chase_focus
	# Aim toward the visible pivot as a racer reaches the outside edge.
	var to_bar := minf(absf(35.0-float(r.p)), absf(125.0-float(r.p)))
	var show_pivot := 1.0 - smoothstep(3.5, 12.0, to_bar)
	focus.x = lerpf(camera_x, 0.0, 0.54*show_pivot)
	follow.z += 0.48*show_pivot
	if mode == "countdown" or snap:
		cam.position = follow
	else:
		cam.position = cam.position.lerp(follow, 1.0-exp(-13.0*dt))
	cam.look_at(focus)

func _result_camera(dt: float) -> void:
	var pos := figures[0].position
	var aim := pos + Vector3(0, 0.89, 0)
	var offset := Vector3(1.15, 1.60, -3.6)
	if reduced:
		cam.position = pos + offset
	else:
		var angle := PI * smoothstep(0.0, 1.0, minf(1.0, finish_elapsed/1.12))
		var radius := lerpf(4.9, 3.6, minf(1.0, finish_elapsed/1.12))
		cam.position = pos + Vector3(sin(angle)*radius + 1.15*(angle/PI), lerpf(3.45,1.60,angle/PI), cos(angle)*radius)
	cam.look_at(aim)

func _player_sounds(r: Dictionary) -> void:
	if r.state != last_state and not (r.state == "fall" and last_state == "splash"):
		match r.state:
			"jump": _play("jump")
			"land":
				_play("land")
				if not reduced:
					effects.burst(figures[0].position + Vector3.UP*0.04,"land")
			"stumble": _play("bump")
			"fall": _play("splash")
	if r.state == "fall" and float(r.y) < -0.8 and last_state != "splash":
		if not reduced:
			effects.burst(Vector3(r.x,-1.45,-r.p),"splash")
		last_state = "splash"
	elif r.state != "fall" or last_state != "splash":
		last_state = r.state
	if r.state == "run":
		var half := int(float(r.phase)*2) % 2
		if half != foot_half:
			_play("step")
		foot_half = half

func _play(cue: String) -> void:
	if sfx:
		audio.play_cue(cue)
