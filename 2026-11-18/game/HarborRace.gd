extends Node3D

const Simulation := preload("res://race/RaceSimulation.gd")
const Courses := preload("res://Courses.gd")
const Yard := preload("res://race/YardLayout.gd")
const Effects := preload("res://presentation/RaceEffects.gd")
const Racer := preload("res://racers/RacerVisual.gd")
const DRAG_THRESHOLD := 9.0
const TAP_SECONDS := 0.33
const COUNTDOWN_SECONDS := 2.5
const CHASE_FOV := 62.0
# The apron is eight metres deep. Rivals slow into the nearest free mark behind the portrait.
const FINISH_SPOTS := [
	Vector2(-3.40, 1.1), Vector2(-1.70, 1.6), Vector2(0.0, 1.1), Vector2(1.70, 1.6), Vector2(3.40, 1.1),
	Vector2(-3.0, 2.55), Vector2(-0.90, 2.75), Vector2(0.95, 2.75), Vector2(3.0, 2.55)
]
# Keep Retina interface pixels sharp while limiting the cost of shading the 3D race.
const MOBILE_RENDER_PIXELS := 820000.0
const MOBILE_WHARF_RENDER_PIXELS := 590000.0
var course: Node3D
var selected_course := ""
@onready var cam: Camera3D = $FollowCamera
@onready var chase_offset: Vector3 = $ChaseOffset.position
@onready var chase_focus: Vector3 = $ChaseLookAhead.position
@onready var portrait_offset: Vector3 = $PortraitOffset.position
@onready var hud := $Overlay/HUD
@onready var audio := $Audio
@onready var portrait_fill: DirectionalLight3D = $PortraitFill
@onready var wharf_fill_energy := portrait_fill.light_energy
@onready var wharf_fill_color := portrait_fill.light_color

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
var finish_marks := {}
var result_cheered := false
var target_x := 0.0
var jump_queued := false
var boost_queued := false
var hold_direction := 0
var digital_steering := false
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
var web_canvas: JavaScriptObject

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
		if int(web_window.navigator.maxTouchPoints) > 0:
			web_canvas = web_window.document.getElementById("canvas")
			get_viewport().size_changed.connect(_size_mobile_render)
			_size_mobile_render()
		system_reduced = bool(web_window.matchMedia("(prefers-reduced-motion: reduce)").matches)
		web_pause_callback = JavaScriptBridge.create_callback(_on_web_visibility)
		web_window.document.addEventListener("visibilitychange", web_pause_callback)
	reduced = settings.get_value("display", "motion", system_reduced)
	sfx = settings.get_value("audio", "sound", true)
	song = settings.get_value("audio", "music", true)
	hud.set_options(reduced, sfx, song)
	hud.course_requested.connect(_choose_course)
	hud.course_menu_requested.connect(_show_course_menu)
	hud.start_requested.connect(start_race)
	hud.pause_requested.connect(pause_race)
	hud.resume_requested.connect(resume_race)
	hud.jump_requested.connect(func(): jump_queued = mode == "racing")
	hud.boost_requested.connect(func(): boost_queued = mode == "racing")
	hud.steering_changed.connect(func(direction): hold_direction = direction)
	hud.option_changed.connect(_option_changed)
	# The title is fully illustrated. Avoid drawing a covered 3D viewport every frame.
	get_viewport().disable_3d = true

func _exit_tree() -> void:
	if web_window and web_pause_callback:
		web_window.document.removeEventListener("visibilitychange", web_pause_callback)

func _size_mobile_render() -> void:
	if web_canvas:
		var pixels := maxf(1.0, float(web_canvas.width) * float(web_canvas.height))
		var budget := MOBILE_WHARF_RENDER_PIXELS if selected_course == Courses.WHARF else MOBILE_RENDER_PIXELS
		get_viewport().scaling_3d_scale = clampf(sqrt(budget / pixels), 0.35, 1.0)

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
			if reduced:
				effects.reset()
			settings.set_value("display", option, value)
		"sound":
			sfx = value
			settings.set_value("audio", option, value)
		"music":
			song = value
			settings.set_value("audio", option, value)
	settings.save("user://preferences.cfg")

func _reset_input() -> void:
	_stop_digital_steering()
	active_pointer = -1
	dragged = false
	jump_queued = false
	boost_queued = false
	hold_direction = 0

func _choose_course(id: String) -> void:
	if not Courses.DATA.has(id):
		return
	if selected_course != id:
		var next_scene := load(Courses.DATA[id].scene) as PackedScene
		if next_scene == null:
			return
		if course:
			$Course.remove_child(course)
			course.free()
		course = next_scene.instantiate()
		$Course.add_child(course)
		if web_canvas:
			if id == Courses.WHARF:
				course.set_mobile_profile()
			# Keep Nagi's near-camera mesh intact when the rivals fill the starting grid.
			for rival in figures.slice(1):
				for mesh: MeshInstance3D in rival.find_children("*", "MeshInstance3D", true, false):
					mesh.lod_bias = 0.3 if id == Courses.WHARF else 1.0
		selected_course = id
		_size_mobile_render()
		for figure in figures:
			figure.light_for_course(id == Courses.YARD)
		portrait_fill.light_energy = 0.10 if id == Courses.YARD else wharf_fill_energy
		portrait_fill.light_color = Color("#c1d8ff") if id == Courses.YARD else wharf_fill_color
	start_race()

func _show_course_menu() -> void:
	mode = "title"
	_reset_input()
	audio.reset()
	effects.reset()
	hud.set_mode(mode)
	get_viewport().disable_3d = true

func start_race() -> void:
	get_viewport().disable_3d = false
	portrait_fill.show()
	sim.reset(selected_course)
	_reset_input()
	target_x = sim.runners[0].x
	camera_x = target_x
	mode = "countdown"
	countdown = COUNTDOWN_SECONDS
	last_count = 3
	finish_elapsed = 0.0
	finish_marks.clear()
	result_cheered = false
	idle_time = 0.0
	foot_half = -1
	last_state = "idle"
	audio.reset()
	effects.reset()
	for figure in figures:
		figure.reset_performance()
	hud.set_mode(mode)
	hud.update_race(1, 0, true)
	hud.set_actions(sim.runners[0])
	hud.set_count("3")
	_play("count")
	_sync_figures()
	_grid_camera(0.0)

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
		hud.update_race(sim.rank_of(0), float(sim.runners[0].p)/sim.finish_distance, true)
		hud.set_actions(sim.runners[0])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready():
			pause_race()

func _input(event: InputEvent) -> void:
	if _capture_course_pointer(event):
		get_viewport().set_input_as_handled()
		return
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
		elif mode == "racing" and event.keycode == KEY_SHIFT:
			boost_queued = true
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "racing" or active_pointer != -1 or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_begin_course_pointer(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_course_pointer(-2, event.position)

func _begin_course_pointer(id: int, point: Vector2) -> void:
	if hud.over_race_button(point):
		return
	active_pointer = id
	press_origin = point
	press_x = target_x
	press_msec = Time.get_ticks_msec()
	dragged = false

func _capture_course_pointer(event: InputEvent) -> bool:
	if mode != "racing" or active_pointer == -1 or event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	# A gesture that began on the course keeps its motion and release over the HUD.
	if event is InputEventScreenTouch and event.index == active_pointer:
		if event.canceled:
			active_pointer = -1
			return true
		if not event.pressed:
			_end_course_pointer(event.position)
			return true
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_drag(event.position)
		return true
	elif active_pointer == -2:
		if event is InputEventMouseMotion:
			_drag(event.position)
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_course_pointer(event.position)
			return true
	return false

func _end_course_pointer(point: Vector2) -> void:
	_drag(point)
	if not dragged and Time.get_ticks_msec() - press_msec < TAP_SECONDS * 1000.0:
		jump_queued = true
	active_pointer = -1

func _drag(point: Vector2) -> void:
	var delta := point - press_origin
	if delta.length() >= DRAG_THRESHOLD:
		dragged = true
	if dragged:
		var distance: float = delta.x / minf(480.0, hud.size.x) * 14.5
		target_x = _clamp_lane(press_x + distance)

func _clamp_lane(x: float) -> float:
	if selected_course == Courses.YARD:
		return clampf(x, -5.2, Yard.OUTER_CENTER + Yard.OUTER_BOW + Yard.OUTER_WIDTH * 0.5 + 0.7)
	return clampf(x, -5.2, 9.0)

func _stop_digital_steering() -> void:
	if not digital_steering:
		return
	digital_steering = false
	var player: Dictionary = sim.runners[0]
	player.vx = 0.0
	if active_pointer == -1 or not dragged:
		target_x = player.x

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
		var progress := clampf(1.0 - countdown / COUNTDOWN_SECONDS, 0.0, 1.0)
		for figure in figures:
			figure.prepare(progress, idle_time, dt)
		if countdown > 0.61:
			_grid_camera(progress)
		else:
			_chase_camera(dt, false)
		if countdown <= 0.0:
			mode = "racing"
			portrait_fill.hide()
			hud.set_mode(mode)
			audio.start_music(song)
			_play("go")
		return
	var player: Dictionary = sim.runners[0]
	var before_respawn: int = player.respawns
	var before_boosts: int = player.boosts_left
	var steer := hold_direction + int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var step_target: float
	if mode == "racing" and steer != 0:
		digital_steering = true
		step_target = _clamp_lane(float(player.x) + signf(steer) * 0.5)
	else:
		_stop_digital_steering()
		step_target = target_x
	sim.step(dt, step_target, jump_queued and mode == "racing", boost_queued and mode == "racing")
	jump_queued = false
	boost_queued = false
	if player.transport_x != 0.0:
		target_x = _clamp_lane(target_x + player.transport_x)
		press_x += player.transport_x
	if before_respawn != player.respawns:
		_reset_input()
		target_x = player.x
		camera_x = player.x
	_sync_figures(dt)
	if mode == "result":
		finish_elapsed += dt
		_result_camera(dt)
		if not result_cheered and figures[0].celebration_start >= 0.0:
			result_cheered = true
			if not reduced:
				effects.burst(figures[0].position, "finish")
		return
	_player_sounds(player)
	if not reduced and player.state in ["sprint", "dive"]:
		effects.trace(figures[0].trail_point(0, player.state), figures[0].trail_point(1, player.state), player.state)
	else:
		effects.release_trail()
	if player.boosts_left < before_boosts:
		_play("boost")
		if not reduced:
			effects.burst(figures[0].position + Vector3.UP * 0.20, "boost")
	_chase_camera(dt, before_respawn != player.respawns)
	hud.set_marker(cam.unproject_position(figures[0].position + Vector3.UP * 1.65))
	hud.update_race(sim.rank_of(0), float(player.p)/sim.finish_distance, reduced)
	hud.set_actions(player)
	if player.finish_time >= 0.0:
		mode = "result"
		portrait_fill.show()
		_reset_input()
		finish_elapsed = 0.0
		audio.end_music()
		effects.release_trail()
		_play("finish")
		hud.show_result(sim.rank_of(0), player.finish_time, Courses.DATA[selected_course].name)

func _finish_position(index: int, runner: Dictionary) -> Vector3:
	var progress := 1.0 - pow(1.0 - clampf(float(runner.elapsed) / 1.0, 0.0, 1.0), 2.0)
	var line := float(sim.finish_distance)
	var mark := Vector2(clampf(runner.x, -3.6, 3.6), 3.65)
	if index > 0:
		if not finish_marks.has(index):
			var best := -1
			var shortest := INF
			var used := finish_marks.values()
			for place in FINISH_SPOTS.size():
				var spot: Vector2 = FINISH_SPOTS[place]
				var distance := spot.distance_squared_to(Vector2(runner.x, 1.60))
				if not used.has(place) and distance < shortest:
					shortest = distance
					best = place
			finish_marks[index] = best
		mark = FINISH_SPOTS[finish_marks[index]]
	return Vector3(lerpf(runner.x, mark.x, progress), runner.y,
		-lerpf(runner.p, line + mark.y, progress))

func _sync_figures(dt := 0.0) -> void:
	course.set_mechanisms(sim.bridge_angle, sim.bar_angles, sim.time)
	for i in figures.size():
		var r: Dictionary = sim.runners[i]
		var finished: bool = r.finish_time >= 0.0
		figures[i].position = _finish_position(i, r) if finished else Vector3(r.x, r.y, -r.p)
		var bend := 0.0
		if selected_course == Courses.YARD and Yard.on_outer(r.x, r.p):
			bend = atan(Yard.outer_slope(r.p))
		figures[i].rotation.y = -bend - float(r.steer) * 0.17
		if mode == "countdown":
			figures[i].prepare(0.0, idle_time, dt)
		else:
			figures[i].race_pose(r, sim.time, idle_time, dt, finished and sim.rank_of(i) == 1)
		var floor_y: float = sim._surface(r.x, r.p)
		var shadow := shadows[i]
		shadow.visible = r.state != "fall" and is_finite(floor_y) and floor_y > -1.5
		if shadow.visible:
			shadow.position = Vector3(figures[i].position.x, floor_y + 0.025, figures[i].position.z)
			shadow.rotation.x = sim.bridge_angle if sim._on_bridge(r.x, r.p) else 0.0
			shadow.scale = Vector3.ONE * clampf(1.0 - (float(r.y) - floor_y) * 0.16, 0.6, 1.0)

func _grid_camera(progress: float) -> void:
	if progress < 0.20 and not reduced:
		var aspect := get_viewport().get_visible_rect().size.aspect()
		var distance := maxf(5.8, 8.0 / (aspect * 1.06))
		cam.fov = 63.0
		cam.position = Vector3(0.0, 1.79, -distance)
		cam.look_at(Vector3(0, 0.9, 0))
		return
	var x := float(sim.runners[0].x)
	var travel := 0.0 if reduced else smoothstep(0.20, 0.76, progress)
	cam.fov = 52.0
	cam.position = Vector3(x, 0.0, 0.0) + portrait_offset + Vector3(0.22 * (1.0 - travel), 0.03, -0.15 * (1.0 - travel))
	cam.look_at(Vector3(x - 0.08, 0.82, 0.0))

func _chase_camera(dt: float, snap: bool) -> void:
	var r: Dictionary = sim.runners[0]
	camera_x = lerpf(camera_x, r.x, 1.0-exp(-7.0*dt))
	var base := Vector3(camera_x, 0, -r.p)
	var floor_y: float = sim._surface(r.x, r.p)
	if is_finite(floor_y):
		base.y = clampf(floor_y, -0.55, 0.8)
	var follow := base + chase_offset
	var focus := base + chase_focus
	var wanted_fov := CHASE_FOV
	if not reduced:
		if r.state == "sprint":
			wanted_fov += 4.0
		elif r.state == "dive":
			wanted_fov += 2.0
		follow.x -= float(r.steer) * 0.20
	cam.fov = wanted_fov if snap or mode == "countdown" else lerpf(cam.fov, wanted_fov, 1.0 - exp(-8.0 * dt))
	if selected_course == Courses.WHARF:
		var to_bar := INF
		for p: float in Simulation.BARS:
			to_bar = minf(to_bar, absf(p - float(r.p)))
		var show_pivot := 1.0 - smoothstep(3.5, 12.0, to_bar)
		focus.x = lerpf(camera_x, 0.0, 0.54*show_pivot)
		follow.z += 0.48*show_pivot
	else:
		var p := float(r.p)
		var fork := smoothstep(Yard.SPLIT_START-15, Yard.SPLIT_START, p) * (1.0-smoothstep(Yard.SPLIT_START, Yard.SPLIT_START+16, p))
		focus.x = lerpf(camera_x, 0.8, fork * 0.46)
		if Yard.on_outer(r.x, p):
			focus.x += Yard.outer_x(p-chase_focus.z) - Yard.outer_x(p)
		if not reduced:
			follow.y += fork * 0.65
			follow.z += fork * 0.48
	if mode == "countdown" or snap:
		cam.position = follow
	else:
		cam.position = cam.position.lerp(follow, 1.0-exp(-13.0*dt))
	cam.look_at(focus)
	if mode == "racing":
		_clear_chase_view(dt)
	for figure in figures:
		figure.face_camera(cam.position, idle_time)

func _clear_chase_view(dt: float) -> void:
	# At a shared landing, another racer's head can fill the camera directly in front of Nagi.
	var player_aim := figures[0].position + Vector3.UP * 0.76
	var ray := player_aim - cam.position
	var depth := ray.length()
	var direction := ray / depth
	for index in range(1, figures.size()):
		var figure := figures[index]
		var offset: Vector3 = figure.position + Vector3.UP * 0.76 - cam.position
		var along := offset.dot(direction)
		var visibility := 1.0
		if along > 0.0 and along < depth + 0.20:
			var across := (offset - direction * along).length()
			visibility = lerpf(0.065, 1.0, smoothstep(0.20, 0.83, across))
		figure.set_camera_visibility(visibility, dt)

func _result_camera(dt: float) -> void:
	for index in range(1, figures.size()):
		figures[index].set_camera_visibility(1.0, dt)
	var pos := figures[0].position
	var aim := pos + Vector3(0, 0.66, 0)
	# Turn across the open centre so the outside gatepost cannot pass in front of the winner.
	var side := -1.0 if pos.x > 0.0 else 1.0
	var offset := Vector3(side * 0.92, 1.29, -2.56)
	if reduced:
		cam.position = pos + offset
		cam.fov = 53.0
	else:
		var turn := smoothstep(0.0, 1.0, finish_elapsed / 1.18)
		var angle := PI * turn
		var radius := lerpf(chase_offset.z, -offset.z, turn)
		cam.fov = lerpf(CHASE_FOV, 53.0, turn)
		cam.position = pos + Vector3(side * sin(angle) * radius * 0.65 + offset.x * turn,
			lerpf(chase_offset.y, offset.y, turn), cos(angle) * radius)
	cam.look_at(aim)
	for figure in figures:
		figure.face_camera(cam.position, idle_time)

func _player_sounds(r: Dictionary) -> void:
	if r.state != last_state and not (r.state == "fall" and last_state == "splash"):
		match r.state:
			"jump": _play("jump")
			"dive": _play("dive")
			"slide":
				_play("slide")
				if not reduced:
					effects.burst(figures[0].position, "slide")
			"land":
				_play("land")
				if not reduced:
					effects.burst(figures[0].position + Vector3.UP*0.04,"land")
			"stumble":
				_play("bump")
				if not reduced:
					effects.burst(figures[0].position + Vector3.UP * 1.12, "stumble")
			"fall": _play("splash")
	if r.state == "fall" and float(r.y) < -0.8 and last_state != "splash":
		if not reduced:
			effects.burst(Vector3(r.x,-1.45,-r.p),"splash")
		last_state = "splash"
	elif r.state != "fall" or last_state != "splash":
		last_state = r.state
	if r.state in ["run", "sprint"]:
		var half := int(float(r.phase)*2) % 2
		if half != foot_half:
			_play("step")
		foot_half = half

func _play(cue: String) -> void:
	if sfx:
		audio.play_cue(cue)
