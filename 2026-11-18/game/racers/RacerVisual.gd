extends Node3D

const Race := preload("res://race/RaceSimulation.gd")
const Paint := preload("res://racers/RacerPaint.gdshader")
const FLIGHT_SECONDS := 2.0 * Race.TAKEOFF_SPEED / Race.GRAVITY
const LAUNCH_SECONDS := 0.30
const FACE_KEYS := [&"Focus", &"Startle", &"Cheer", &"Blink", &"FocusBlink", &"StartleBlink"]

const FILES := [
	"res://racers/01.glb", "res://racers/02.glb", "res://racers/03.glb",
	"res://racers/04.glb", "res://racers/05.glb", "res://racers/06.glb"
]
var model: Node3D
var player: AnimationPlayer
var active_clip := ""
var bib := 0
var face: MeshInstance3D
var skeleton: Skeleton3D
var feet := PackedInt32Array()
var hands := PackedInt32Array()
var shape_indices := PackedInt32Array()
var shape_values := PackedFloat32Array()
var paint_materials: Array[ShaderMaterial] = []
var emotion := Vector3.ZERO
var celebration_start := -1.0
var held_head: Quaternion
var held_chest: Quaternion
var settling := false
var head_index := -1
var chest_index := -1
var face_forward := Vector3.FORWARD
var visibility_from_camera := 1.0
var visibility_step := 16

func setup(index: int) -> void:
	if model:
		remove_child(model)
		model.queue_free()
	bib = clampi(index, 0, FILES.size() - 1)
	var packed := load(FILES[bib]) as PackedScene
	model = packed.instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	player = null if players.is_empty() else players[0] as AnimationPlayer
	if player:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton = model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	head_index = skeleton.find_bone("Head")
	chest_index = skeleton.find_bone("Chest")
	var rest_head := skeleton.global_transform * skeleton.get_bone_global_rest(head_index)
	face_forward = rest_head.basis.inverse() * (global_transform.basis * Vector3.FORWARD)
	feet.clear()
	hands.clear()
	for side in ["L", "R"]:
		feet.append(_bone_index("Foot", side))
		hands.append(_bone_index("Hand", side))
	face = null
	shape_indices.clear()
	paint_materials.clear()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var has_face := mesh.find_blend_shape_by_name(FACE_KEYS[0]) >= 0
		if has_face:
			face = mesh
			for key in FACE_KEYS:
				shape_indices.append(mesh.find_blend_shape_by_name(key))
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = Paint
			mat.set_shader_parameter(&"painted", source.albedo_texture)
			mat.set_shader_parameter(&"facial_features", has_face)
			mesh.set_surface_override_material(surface, mat)
			paint_materials.append(mat)
	reset_performance()
	pose("idle", 0.0, 0.0, 0.0)

func _bone_index(part: String, side: String) -> int:
	var index := skeleton.find_bone(part + "_" + side)
	return index if index >= 0 else skeleton.find_bone(part + "." + side)

func trail_point(side: int, state: String) -> Vector3:
	var index := hands[side] if state == "dive" else feet[side]
	if index < 0:
		return global_position
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)

func light_for_course(sunset: bool) -> void:
	for mat in paint_materials:
		mat.set_shader_parameter(&"key_direction", Vector3(-0.70, 0.49, -0.51) if sunset else Vector3(-0.52, 0.77, -0.37))
		mat.set_shader_parameter(&"sun_tint", Vector3(1.08, 0.99, 0.94) if sunset else Vector3(1.03, 1.01, 0.99))
		mat.set_shader_parameter(&"shadow_tint", Vector3(0.72, 0.69, 0.86) if sunset else Vector3(0.74, 0.78, 0.88))
		mat.set_shader_parameter(&"rim_tint", Vector3(1.0, 0.72, 0.52) if sunset else Vector3(0.78, 0.88, 0.98))

func reset_performance() -> void:
	set_camera_visibility(1.0, 0.0)
	if face:
		face.show()
	active_clip = ""
	celebration_start = -1.0
	settling = false
	emotion = Vector3.ZERO
	shape_values.resize(FACE_KEYS.size())
	shape_values.fill(-1.0)
	_apply_face(0.0)

func set_camera_visibility(amount: float, dt: float) -> void:
	visibility_from_camera = lerpf(visibility_from_camera, amount, 1.0 - exp(-25.0 * dt)) if dt > 0.0 else amount
	var step := roundi(visibility_from_camera * 16.0)
	if step == visibility_step:
		return
	visibility_step = step
	for mat in paint_materials:
		mat.set_shader_parameter(&"visibility_from_camera", float(step) / 16.0)

func face_camera(camera_position: Vector3, clock: float) -> void:
	if not face:
		return
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(head_index)
	var forward := (head.basis * face_forward).normalized()
	var toward_camera := (camera_position - head.origin).normalized()
	# A view of the back of the head cannot see the eyes or mouth. Keep profiles and glasses.
	var should_draw := forward.dot(toward_camera) > (-0.59 if face.visible else -0.52)
	if should_draw != face.visible:
		face.visible = should_draw
		if should_draw:
			_apply_face(_blink_at(clock))

func prepare(progress: float, clock: float, dt: float) -> void:
	pose("ready", 0.0, progress, 0.0, dt)
	var intent := smoothstep(0.49, 0.88, progress)
	var smile := (0.35 if bib in [0, 1, 3] else 0.12) * (1.0 - intent)
	_face_toward(Vector3(intent * 0.80, 0.0, smile), clock, dt)

func race_pose(runner: Dictionary, race_time: float, clock: float, dt: float, won: bool) -> void:
	var state: String = runner.state
	var elapsed: float = runner.elapsed
	if state == "finish":
		if runner.speed > 0.18 or not runner.grounded:
			state = "run" if runner.grounded else "jump"
		else:
			if celebration_start < 0.0:
				celebration_start = clock
			elapsed = clock - celebration_start
			state = "finish_win" if won else "finish"
	elif state == "run" and race_time < LAUNCH_SECONDS:
		state = "launch"
		elapsed = race_time
	pose(state, elapsed, runner.phase, runner.steer, dt)
	var rest := 0.0
	if state in ["finish_win", "finish"]:
		var tail: float = player.get_animation(state).length
		rest = smoothstep(tail - 0.15, tail + 0.85, elapsed)
		if elapsed >= tail:
			_settle_after_finish(elapsed - tail)
	var target := Vector3.ZERO
	match state:
		"launch", "sprint", "dive": target.x = 0.94
		"stumble", "fall": target.y = 0.96
		"jump": target.y = 0.30 * sin(PI * clampf(elapsed / FLIGHT_SECONDS, 0, 1))
		"slide": target.x = 0.80 * (1.0 - smoothstep(0.12, Race.SLIDE_SECONDS, elapsed))
		"land": target.x = 0.42
		"finish_win": target.z = lerpf(0.98, 0.35, rest)
		"finish":
			var recovered := smoothstep(0.18, 1.35, elapsed)
			target = Vector3(0.24 * (1.0 - recovered), 0.0, lerpf(0.78, 0.22, rest) * recovered)
	_face_toward(target, clock, dt)

func _settle_after_finish(seconds: float) -> void:
	if not settling:
		held_head = skeleton.get_bone_pose_rotation(head_index)
		held_chest = skeleton.get_bone_pose_rotation(chest_index)
		settling = true
	# The feet stay on the held mark as the runners breathe and look up again.
	var fade := smoothstep(0.0, 0.85, seconds)
	var breath := sin(seconds * (2.65 + 0.10 * bib)) * fade
	var glance := sin(seconds * 0.94 + 0.88 * bib) * fade
	skeleton.set_bone_pose_rotation(chest_index, held_chest * Quaternion(Vector3.RIGHT, 0.032 * breath))
	skeleton.set_bone_pose_rotation(head_index, held_head * Quaternion(Vector3.UP, 0.072 * glance) * Quaternion(Vector3.RIGHT, -0.032 * breath))

func _face_toward(target: Vector3, clock: float, dt: float) -> void:
	if not face:
		return
	emotion = emotion.lerp(target, 1.0 - exp(-dt * 14.0)) if dt > 0.0 else target
	if face.visible:
		_apply_face(_blink_at(clock))

func _blink_at(clock: float) -> float:
	var period := 3.35 + bib * 0.19
	var t := fposmod(clock + bib * 0.73 + 0.61, period)
	return smoothstep(0.0, 0.082, t) * (1.0 - smoothstep(0.109, 0.22, t))

func _apply_face(blink: float) -> void:
	if not face:
		return
	var neutral := maxf(0.0, 1.0 - emotion.x - emotion.y - emotion.z)
	var weights := [emotion.x * (1.0 - blink), emotion.y * (1.0 - blink), emotion.z,
			neutral * blink, emotion.x * blink, emotion.y * blink]
	for index in shape_indices.size():
		var weight: float = weights[index]
		if shape_indices[index] >= 0 and absf(weight - shape_values[index]) >= 0.005:
			face.set_blend_shape_value(shape_indices[index], weight)
			shape_values[index] = weight

func pose(state: String, elapsed: float, phase: float, steer: float, dt := 0.0) -> void:
	if not player or not player.has_animation(state):
		return
	if state != active_clip:
		var blend := 0.075 if dt > 0.0 and not active_clip.is_empty() else 0.0
		active_clip = state
		# Stride and airborne phase follow the simulation. advance() clocks the transition only.
		player.play(state, blend, 0.0)
	var duration := player.get_animation(state).length
	var t: float
	match state:
		"run", "sprint":
			t = fposmod(phase, 1.0) * duration
		"ready":
			t = clampf(phase, 0.0, 1.0) * duration
		"jump":
			t = clampf(elapsed / FLIGHT_SECONDS, 0.0, 1.0) * duration
		"slide":
			t = clampf(elapsed / Race.SLIDE_SECONDS, 0.0, 1.0) * duration
		"land":
			t = clampf(elapsed / 0.14, 0.0, 1.0) * duration
		"idle":
			t = fposmod(elapsed, duration)
		_:
			# A long fall holds the last reaching pose of the dive.
			t = clampf(elapsed, 0.0, duration)
	player.seek(t, false)
	player.advance(dt)
	model.rotation.z = clampf(steer, -1.0, 1.0) * (0.075 if state in ["run", "sprint"] else 0.035)
