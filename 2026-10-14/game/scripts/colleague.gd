extends Node3D
## A visual response to an accepted, nearby break. No bodies, scoring or audio.

const AssetLibrary := preload("res://scripts/asset_library.gd")
const DURATION := 1.4
const COOLDOWN := 2.8
const STAMP_CONTACT := 0.48
static var _alert_mesh: ArrayMesh
static var _stamp_upper_mesh: ArrayMesh
static var _stamp_hand_mesh: ArrayMesh
static var _paper_mesh: ArrayMesh
static var _ink_mesh: ArrayMesh

var colleague_id := ""
var role := "mug"
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
var _stamp_hand: MeshInstance3D
var _stamp_ink: MeshInstance3D
var _stamps := 0
var _stamped_this_reaction := false
var _stamp_contact := false
var _stamp_lift := 0.0
var _approval_visible := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func build(id: String, personality: String = "mug") -> void:
	colleague_id = id
	role = "stamp" if personality == "stamp" else "mug"
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
	if role == "stamp":
		# ArmMug is a merged authored sleeve, hand and mug. Hide the entire
		# assembly rather than leaving a supervisor holding the cat mug.
		_arm.hide()
		_build_stamp_gesture()
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
	_stamped_this_reaction = false
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
			_phrase = "承認！" if role == "stamp" else "！ マグ死守！"
	if _active:
		_elapsed = minf(DURATION, _elapsed + remaining)
		if role == "stamp" and _elapsed >= STAMP_CONTACT and not _stamped_this_reaction:
			_stamped_this_reaction = true
			_stamps += 1
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
	# The supervisor keeps the stamping shoulder over its desk; the head
	# notices the crash while the chair and paper stay aligned with the desk.
	rotation.y = _yaw * envelope * (0.0 if role == "stamp" else 0.62)
	var away := Basis(Vector3.UP, -rotation.y) * Vector3(sin(_yaw), 0, cos(_yaw))
	if not subdued:
		rotation.x = away.z * motion * 0.035
		rotation.z = -away.x * motion * 0.035
	_body.transform = _body_home
	var torso_motion := motion * (0.2 if role == "stamp" else 1.0)
	_body.rotation.y += _yaw * envelope * (0.06 if role == "stamp" else 0.18)
	_body.rotation.x += away.z * torso_motion * 0.13
	_body.rotation.z -= away.x * torso_motion * 0.13
	_body.position += away * torso_motion * 0.15
	_head.transform = _head_home
	_head.rotation.y += _yaw * envelope * (0.38 if role == "stamp" else 0.20)
	_head.rotation.x -= motion * 0.09
	_arm.transform = _arm_home
	_arm.position += Vector3(0.12, 0.23, 0.07) * motion
	_arm.rotation.x -= _body.rotation.x + motion * 0.12
	_arm.rotation.z -= _body.rotation.z + motion * 0.16
	_mug_lift = 0.23 * motion if role == "mug" else 0.0
	_recoil = 0.15 * torso_motion
	_neutral.visible = not _active
	_alert.visible = _active
	_callout.visible = _active and _elapsed < 0.95
	# One short callout per response; a stronger event changes only the pose.
	_callout.text = ("！" if subdued else _phrase) if _active else ""
	_callout.position.y = 3.25
	if role == "stamp":
		_update_stamp_pose(subdued)

func _update_stamp_pose(subdued: bool) -> void:
	var lift := 0.0
	if _active:
		if _elapsed < 0.22:
			lift = smoothstep(0.0, 0.22, _elapsed)
		elif _elapsed < STAMP_CONTACT:
			lift = 1.0 - smoothstep(0.22, STAMP_CONTACT, _elapsed)
		elif _elapsed >= 0.68:
			# A smaller return lift reads as withdrawing the stamp, then
			# settles to the working pose without another paper contact.
			lift = sin(clampf((_elapsed - 0.68) / 0.72, 0.0, 1.0) * PI) * 0.35
	var angle := lift * (0.22 if subdued else (0.43 if _strength >= 2 else 0.34))
	_stamp_hand.rotation.x = angle
	_stamp_lift = sin(angle) * 0.73
	_stamp_contact = _active and _elapsed >= STAMP_CONTACT and _elapsed < 0.68
	_approval_visible = _active and _elapsed >= STAMP_CONTACT and _elapsed < 1.12
	_stamp_ink.visible = _approval_visible
	_callout.visible = _approval_visible
	_callout.text = "承認！" if _approval_visible else ""
	_callout.modulate = Color("f4474b")
	# Stamp mode omits the whole-chair rock so the stamp never skates across
	# the desktop. Subdued retains the actual downstroke, face and approval.
	rotation.x = 0.0
	rotation.z = 0.0

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
	_stamps = 0
	_stamped_this_reaction = false
	_stamp_contact = false
	_stamp_lift = 0.0
	_approval_visible = false
	_callout.text = ""
	_update_pose()

func debug_snapshot() -> Dictionary:
	var visible_meshes := 0
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			visible_meshes += 1
	return {"id": colleague_id, "role": role, "position": _vector(global_position),
		"impact": _vector(_impact), "distance": _distance,
		"state": "waiting" if _pending else ("startled" if _active else "sleepy"),
		"delay": _delay, "elapsed": _elapsed, "cooldown": _cooldown,
		"strength": _strength, "target_yaw": _yaw, "chair_yaw": rotation.y,
		"mug_lift": _mug_lift, "recoil": _recoil, "starts": _starts,
		"upgrades": _upgrades, "callout": _callout.visible, "callout_text": _callout.text,
		"expression": "startled" if _alert.visible else "sleepy",
		"visible_meshes": visible_meshes + (1 if _callout.visible else 0),
		"quality": _quality, "stamps": _stamps, "stamp_contact": _stamp_contact,
		"approval_visible": _approval_visible, "stamp_lift": _stamp_lift,
		"stamp_clock": _elapsed if role == "stamp" else 0.0,
		"mug_visible": _arm.is_visible_in_tree(),
		"stamp_hand_position": _vector(_stamp_hand.global_position) if _stamp_hand != null else [],
		"stamp_base_position": _vector(_stamp_hand.to_global(Vector3(-0.02, 0.175, -0.73))) if _stamp_hand != null else [],
		"paper_position": _vector(to_global(Vector3(-0.50, 1.823, -1.18))) if role == "stamp" else [],
		"ink_visible": _stamp_ink.visible if _stamp_ink != null else false}

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _build_stamp_gesture() -> void:
	if _stamp_hand_mesh == null:
		_build_stamp_meshes()
	_add_shared_mesh("StampSleeve", _stamp_upper_mesh)
	_stamp_hand = _add_shared_mesh("StampHand", _stamp_hand_mesh)
	_stamp_hand.position = Vector3(-0.48, 1.65, -0.45)
	var paper := _add_shared_mesh("ApprovalPaper", _paper_mesh)
	paper.position = Vector3(-0.50, 1.815, -1.18)
	_stamp_ink = _add_shared_mesh("ApprovalInk", _ink_mesh)
	_stamp_ink.position = Vector3(-0.50, 1.827, -1.18)

func _add_shared_mesh(part_name: String, shared: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = shared
	instance.material_override = AssetLibrary.solid_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

static func _build_stamp_meshes() -> void:
	# Small shared, vertex-colored rigid groups follow the existing rounded
	# toy construction. This replaces the authored mug arm without a GLB fork.
	var upper := _new_surface()
	_toy_segment(upper, Vector3(-0.308, 1.47, -0.035), Vector3(-0.46, 1.65, -0.43), 0.125, Color("fffaed"))
	_toy_segment(upper, Vector3(-0.46, 1.65, -0.40), Vector3(-0.48, 1.65, -0.49), 0.133, Color("f6a6b9"))
	_stamp_upper_mesh = upper.commit()
	var hand := _new_surface()
	_toy_segment(hand, Vector3.ZERO, Vector3(-0.02, 0.41, -0.67), 0.095, Color("edb98f"))
	_toy_oval(hand, Vector3(-0.02, 0.415, -0.71), Vector3(0.125, 0.09, 0.13), Color("edb98f"))
	# Wide red rubber base, dark collar, short wooden stem and round top.
	_toy_cylinder(hand, Vector3(-0.02, 0.215, -0.73), 0.15, 0.08, Color("e93942"))
	_toy_cylinder(hand, Vector3(-0.02, 0.267, -0.73), 0.11, 0.025, Color("603226"))
	_toy_cylinder(hand, Vector3(-0.02, 0.355, -0.73), 0.055, 0.17, Color("8b4b30"))
	_toy_oval(hand, Vector3(-0.02, 0.455, -0.73), Vector3(0.10, 0.075, 0.10), Color("e93942"))
	for index in range(3):
		_toy_oval(hand, Vector3(-0.095 + index * 0.052, 0.423, -0.795), Vector3(0.036, 0.05, 0.045), Color("f5c39b"))
	_stamp_hand_mesh = hand.commit()
	var paper := _new_surface()
	_toy_box(paper, Vector3.ZERO, Vector3(0.88, 0.016, 0.75), Color("fffaed"))
	# A real document with a header and short lines, not a floating caption.
	_toy_box(paper, Vector3(0, 0.009, -0.27), Vector3(0.62, 0.002, 0.028), Color("3c5965"))
	for index in range(3):
		_toy_box(paper, Vector3(0.13, 0.009, -0.16 + index * 0.08), Vector3(0.32, 0.002, 0.012), Color("9faeaa"))
	_paper_mesh = paper.commit()
	var ink := _new_surface()
	for index in range(24):
		var start := float(index) / 24.0 * TAU
		var end := float(index + 1) / 24.0 * TAU
		_toy_segment(ink, Vector3(cos(start) * 0.15, 0, sin(start) * 0.15), Vector3(cos(end) * 0.15, 0, sin(end) * 0.15), 0.013, Color("df3540"))
	_toy_box(ink, Vector3.ZERO, Vector3(0.18, 0.008, 0.025), Color("df3540"))
	_toy_box(ink, Vector3.ZERO, Vector3(0.025, 0.008, 0.18), Color("df3540"))
	_ink_mesh = ink.commit()

static func _new_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

static func _toy_primitive(surface: SurfaceTool, primitive: PrimitiveMesh, pose: Transform3D, color: Color) -> void:
	var arrays := primitive.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var colored := ArrayMesh.new()
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.append_from(colored, 0, pose)

static func _toy_oval(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_toy_primitive(surface, sphere, Transform3D(Basis.IDENTITY.scaled(size), center), color)

static func _toy_segment(surface: SurfaceTool, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var direction := end - start
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = direction.length() + radius * 2.0
	capsule.radial_segments = 10
	capsule.rings = 4
	var axis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	_toy_primitive(surface, capsule, Transform3D(axis, (start + end) * 0.5), color)

static func _toy_cylinder(surface: SurfaceTool, center: Vector3, radius: float, height: float, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 16
	_toy_primitive(surface, cylinder, Transform3D(Basis.IDENTITY, center), color)

static func _toy_box(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	_toy_primitive(surface, box, Transform3D(Basis.IDENTITY, center), color)

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
