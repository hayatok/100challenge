extends Node3D
## A visual response to an accepted, nearby break. No bodies, scoring or audio.

const AssetLibrary := preload("res://scripts/asset_library.gd")
const DURATION := 1.4
const COOLDOWN := 2.8
static var _alert_mesh: ArrayMesh

var colleague_id := ""
var _body: Node3D
var _head: Node3D
var _arm: Node3D
var _neutral: Node3D
var _alert: MeshInstance3D
var _callout: Label3D
var _body_home := Transform3D.IDENTITY
var _head_home := Transform3D.IDENTITY
var _arm_home := Transform3D.IDENTITY
var _quality := "派手"
var _pending := false
var _active := false
var _delay := 0.0
var _elapsed := 0.0
var _cooldown := 0.0
var _strength := 0
var _impact := Vector3.ZERO
var _distance := 0.0
var _yaw := 0.0
var _starts := 0
var _upgrades := 0
var _mug_lift := 0.0
var _recoil := 0.0
var _phrase := ""

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func build(id: String) -> void:
	colleague_id = id
	name = id
	# Coworker chairs do not need the player's seat pivot. Bake the two rigid
	# chair surfaces once into a shared mesh, retaining the exact reference art.
	var chair := MeshInstance3D.new()
	chair.name = "SharedChair"
	chair.mesh = AssetLibrary.particle_mesh("chair")
	chair.material_override = AssetLibrary.solid_material()
	chair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chair)
	chair.scale = Vector3.ONE * 0.88
	var person := AssetLibrary.model("colleague")
	chair.add_child(person)
	person.position = Vector3(0, 1.0, -0.04)
	_body = person.find_child("Body", true, false) as Node3D
	_head = person.find_child("Head", true, false) as Node3D
	_arm = person.find_child("ArmMug", true, false) as Node3D
	_neutral = person.find_child("FaceNeutral", true, false) as Node3D
	assert(_body != null and _head != null and _arm != null and _neutral != null,
		"Colleague requires the four authored motion groups")
	_body_home = _body.transform
	_head_home = _head.transform
	_arm_home = _arm.transform
	_alert = MeshInstance3D.new()
	_alert.name = "StartledFace"
	_alert.mesh = _startled_face()
	_alert.material_override = AssetLibrary.particle_material()
	_alert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_alert)
	_callout = Label3D.new()
	_callout.name = "SpatialCallout"
	_callout.position = Vector3(0, 3.25, 0)
	_callout.font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	_callout.font_size = 64
	_callout.pixel_size = 0.0085
	_callout.modulate = Color("ffd45b")
	_callout.outline_modulate = Color("223443")
	_callout.outline_size = 12
	_callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_callout.no_depth_test = false
	add_child(_callout)
	reset_reaction()

func set_feedback_quality(level: String) -> void:
	_quality = level
	if _callout != null:
		_update_pose()

func react(at: Vector3, strength: int, delay: float) -> String:
	if _pending or _active:
		if strength <= _strength:
			return "suppressed"
		# Upgrade the existing response in place: no new onset, clock or callout.
		_strength = strength
		_upgrades += 1
		_set_impact(at)
		_update_pose()
		return "upgraded"
	if _cooldown > 0.0:
		return "suppressed"
	_set_impact(at)
	_strength = strength
	_delay = clampf(delay, 0.05, 0.26)
	_elapsed = 0.0
	_cooldown = COOLDOWN
	_pending = true
	return "accepted"

func is_reacting() -> bool:
	return _pending or _active

func _set_impact(at: Vector3) -> void:
	_impact = at
	var direction := at - global_position
	_distance = Vector2(direction.x, direction.z).length()
	# Parent desks have no rotation. Convert nevertheless so later art changes
	# keep gaze aimed at the actual world-space destruction position.
	direction = (get_parent() as Node3D).global_basis.inverse() * direction
	_yaw = atan2(-direction.x, -direction.z)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var remaining := delta
	if _pending:
		var consumed := minf(remaining, _delay)
		_delay -= consumed
		remaining -= consumed
		if _delay <= 0.00001:
			_pending = false
			_active = true
			_starts += 1
			_phrase = ("！ マグ死守！" if int(colleague_id.right(2)) % 2 == 0 else "！ えっ！？")
	if _active:
		_elapsed = minf(DURATION, _elapsed + remaining)
		if _elapsed >= DURATION:
			_active = false
	_update_pose()

func _update_pose() -> void:
	var envelope := 0.0
	if _active:
		if _elapsed < 0.12:
			envelope = smoothstep(0.0, 0.12, _elapsed)
		elif _elapsed < 0.52:
			envelope = 1.0
		else:
			envelope = 1.0 - smoothstep(0.52, DURATION, _elapsed)
	var subdued := _quality == "控えめ"
	var amount := envelope * (1.25 if _strength >= 2 else 0.8)
	var motion := amount * (0.18 if subdued else 1.0)
	# Chair swivels first; torso and head complete the gaze. No spinning,
	# ragdoll or extra collider is involved, and distant coworkers remain still.
	rotation = Vector3.ZERO
	rotation.y = _yaw * envelope * 0.62
	var away := Basis(Vector3.UP, -rotation.y) * Vector3(sin(_yaw), 0, cos(_yaw))
	if not subdued:
		rotation.x = away.z * motion * 0.035
		rotation.z = -away.x * motion * 0.035
	_body.transform = _body_home
	_body.rotation.y += _yaw * envelope * 0.18
	_body.rotation.x += away.z * motion * 0.13
	_body.rotation.z -= away.x * motion * 0.13
	_body.position += away * motion * 0.15
	_head.transform = _head_home
	_head.rotation.y += _yaw * envelope * 0.20
	_head.rotation.x -= motion * 0.09
	_arm.transform = _arm_home
	_arm.position += Vector3(0.12, 0.23, 0.07) * motion
	_arm.rotation.x -= _body.rotation.x + motion * 0.12
	_arm.rotation.z -= _body.rotation.z + motion * 0.16
	_mug_lift = 0.23 * motion
	_recoil = 0.15 * motion
	_neutral.visible = not _active
	_alert.visible = _active
	_callout.visible = _active and _elapsed < 0.95
	# One short callout per response; a stronger event changes only the pose.
	_callout.text = ("！" if subdued else _phrase) if _active else ""
	_callout.position.y = 3.25

func reset_reaction() -> void:
	_pending = false
	_active = false
	_delay = 0.0
	_elapsed = 0.0
	_cooldown = 0.0
	_strength = 0
	_impact = Vector3.ZERO
	_distance = 0.0
	_yaw = 0.0
	_starts = 0
	_upgrades = 0
	_phrase = ""
	_callout.text = ""
	_update_pose()

func debug_snapshot() -> Dictionary:
	var visible_meshes := 0
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			visible_meshes += 1
	return {"id": colleague_id, "position": _vector(global_position),
		"impact": _vector(_impact), "distance": _distance,
		"state": "waiting" if _pending else ("startled" if _active else "sleepy"),
		"delay": _delay, "elapsed": _elapsed, "cooldown": _cooldown,
		"strength": _strength, "target_yaw": _yaw, "chair_yaw": rotation.y,
		"mug_lift": _mug_lift, "recoil": _recoil, "starts": _starts,
		"upgrades": _upgrades, "callout": _callout.visible, "callout_text": _callout.text,
		"expression": "startled" if _alert.visible else "sleepy",
		"visible_meshes": visible_meshes + (1 if _callout.visible else 0),
		"quality": _quality}

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _startled_face() -> ArrayMesh:
	if _alert_mesh != null:
		return _alert_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		var center := Vector3(float(side) * 0.198, 1.34 - 0.885, -0.49)
		_face_oval(surface, center, Vector2(0.176, 0.172), Color("223443"))
		_face_oval(surface, center + Vector3(0, 0, -0.003), Vector2(0.151, 0.15), Color("fffaed"))
		_face_oval(surface, center + Vector3(-side * 0.025, -0.01, -0.006), Vector2(0.041, 0.069), Color("223443"))
		_face_oval(surface, center + Vector3(-side * 0.025 - 0.009, 0.018, -0.009), Vector2(0.013, 0.02), Color.WHITE)
	_face_oval(surface, Vector3(0, 1.123 - 0.885, -0.48), Vector2(0.115, 0.12), Color("223443"))
	_face_oval(surface, Vector3(0, 1.103 - 0.885, -0.483), Vector2(0.083, 0.075), Color("a63146"))
	_face_oval(surface, Vector3(0, 1.055 - 0.885, -0.486), Vector2(0.055, 0.024), Color("f783a2"))
	_alert_mesh = surface.commit()
	return _alert_mesh

static func _face_oval(surface: SurfaceTool, center: Vector3, size: Vector2, color: Color) -> void:
	for i in range(20):
		var first := float(i) / 20.0 * TAU
		var second := float(i + 1) / 20.0 * TAU
		for point in [center, center + Vector3(cos(first) * size.x, sin(first) * size.y, 0),
			center + Vector3(cos(second) * size.x, sin(second) * size.y, 0)]:
			surface.set_color(color)
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(point)
