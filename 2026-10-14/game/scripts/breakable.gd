extends Node3D
## One authored prop, a short deterministic collapse, then one retained floor mesh.
## The scoring origin never moves. Only visual children move; no physics or shadows.

const AssetLibrary = preload("res://scripts/asset_library.gd")
const CONTACT_SECONDS := 0.35
const SETTLE_SECONDS := 1.05
const MODELS := {"box": "paper_box", "tower": "paper_tower", "wagon": "paper_cart"}

var _kind := "box"
var _index := 0
var _quality := "派手"
var _broken := false
var _elapsed := 0.0
var _direction := Vector3.FORWARD
var _travel := Vector3.ZERO
var _local_direction := Vector3.FORWARD
var _motion: Node3D
var _rig: Node3D
var _intact: MeshInstance3D
var _settled: MeshInstance3D
var _groups: Dictionary = {}
var _starts: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)

func build(kind: String, index: int) -> void:
	if _rig != null:
		return
	assert(MODELS.has(kind), "Unknown breakable kind: " + kind)
	_kind = kind
	_index = index
	var asset_name: String = MODELS[kind]
	var yaw := PI + sin(float(index) * 1.7) * 0.06
	_intact = MeshInstance3D.new()
	_intact.name = "IntactBatch"
	_intact.mesh = AssetLibrary.particle_mesh(asset_name)
	_intact.material_override = AssetLibrary.solid_material()
	_intact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_intact.rotation.y = yaw
	add_child(_intact)
	_motion = Node3D.new()
	_motion.name = "Motion"
	add_child(_motion)
	_rig = AssetLibrary.model(asset_name)
	_rig.rotation.y = yaw
	_motion.add_child(_rig)
	var names: Array
	match kind:
		"box": names = ["CartonBody", "FlapLeft", "FlapRight", "FlapFront", "FlapBack", "PaperLow", "PaperMiddle", "PaperTop"]
		"tower": names = ["TowerBase", "TowerLow", "TowerMiddle", "TowerUpper", "TowerCrown"]
		_: names = ["CartFrame", "CasterLoose", "CastersFixed", "CargoPaper", "CargoBinders", "CargoCartons"]
	for group_name in names:
		var part := _rig.find_child(str(group_name), true, false) as Node3D
		assert(part != null, "Missing authored breakable group: " + str(group_name))
		_groups[group_name] = part
		_starts[group_name] = part.transform
	_settled = MeshInstance3D.new()
	_settled.name = "SettledBatch"
	_settled.material_override = AssetLibrary.solid_material()
	_settled.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_settled)
	reset_visual()

func begin_break(direction: Vector3, travel: Vector3 = Vector3.ZERO) -> void:
	if _broken or _rig == null or (is_inside_tree() and get_tree().paused):
		return
	_broken = true
	_elapsed = 0.0
	var local_basis := global_basis.inverse() if is_inside_tree() else basis.inverse()
	_direction = local_basis * Vector3(direction.x, 0.0, direction.z)
	_direction.y = 0.0
	_direction = _direction.normalized() if _direction.length_squared() > 0.001 else Vector3.FORWARD
	_travel = local_basis * Vector3(travel.x, 0.0, travel.z)
	_travel.y = 0.0
	_local_direction = (_rig.basis.inverse() * _direction).normalized()
	_intact.hide()
	_settled.hide()
	_motion.show()
	_apply_pose(0.0)
	set_process(true)

func reset_visual() -> void:
	_broken = false
	_elapsed = 0.0
	set_process(false)
	if _rig == null:
		return
	_motion.transform = Transform3D.IDENTITY
	for group_name in _groups:
		var part: Node3D = _groups[group_name]
		part.transform = _starts[group_name]
	_motion.hide()
	_settled.hide()
	_settled.mesh = null
	_intact.show()

func set_feedback_quality(level: String) -> void:
	_quality = level

func _process(delta: float) -> void:
	if not _broken:
		set_process(false)
		return
	_elapsed = minf(_elapsed + delta, SETTLE_SECONDS)
	# Reduced motion preserves causal contact at 0.35s, with no bounce or flight.
	var pose_time := _elapsed
	if _quality == "控えめ":
		# The wagon and tower must still reach the next object at the same
		# 0.35s contact as the propagation queue. Only the settling tail speeds up.
		if _elapsed > CONTACT_SECONDS:
			pose_time = minf(SETTLE_SECONDS, CONTACT_SECONDS + (_elapsed - CONTACT_SECONDS) * 4.0)
	_apply_pose(pose_time)
	if pose_time >= SETTLE_SECONDS or is_equal_approx(pose_time, SETTLE_SECONDS):
		_bake_settled()
		set_process(false)

func _apply_pose(time: float) -> void:
	match _kind:
		"wagon": _pose_wagon(time)
		"tower": _pose_tower(time)
		_: _pose_box(time)

func _ease(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _pose_wagon(time: float) -> void:
	var roll := _ease(time / CONTACT_SECONDS)
	var fall := _ease((time - CONTACT_SECONDS) / 0.65)
	var axis := Vector3.UP.cross(_direction).normalized()
	# Rolling reaches the contacted object before it starts its own collapse.
	var angle := 0.22 * roll + 0.78 * fall
	var caster_span := absf(_local_direction.x) * 0.535 + absf(_local_direction.z) * 0.365
	var lift := 0.19 + caster_span * sin(angle) - 0.19 * cos(angle)
	_motion.position = _travel * roll + Vector3.UP * lift
	_motion.basis = Basis(axis, angle)
	var local_side := Vector3.UP.cross(_local_direction).normalized()
	var loose: Node3D = _groups["CasterLoose"]
	var wheel_start: Transform3D = _starts["CasterLoose"]
	var wheel_initial := _rig.basis * wheel_start.origin
	var wheel_landed := _direction * 0.6 + (_rig.basis * local_side) * 0.72 + Vector3.UP * 0.19
	var wheel_at := wheel_initial.lerp(wheel_landed, fall)
	loose.position = _rig.basis.inverse() * (_motion.basis.inverse() * (wheel_at - Vector3.UP * lift))
	loose.basis = _rig.basis.inverse() * _motion.basis.inverse() * _rig.basis * Basis(Vector3.UP, 0.8 * fall) * wheel_start.basis
	# Cargo keeps its original shaped sheets, binders and little cartons.
	for i in range(3):
		var group_name: String = ["CargoPaper", "CargoBinders", "CargoCartons"][i]
		var start: Transform3D = _starts[group_name]
		var part: Node3D = _groups[group_name]
		# Work in wrapper space so cargo lands on the floor beside the tilted frame.
		var initial := _rig.basis * start.origin
		var landed := _direction * (0.75 + float(i) * 0.31) + Vector3.UP * 0.10 + (_rig.basis * local_side) * (float(i) - 1.0) * 0.46
		var world_local := initial.lerp(landed, fall)
		world_local.y += (0.48 if _quality != "控えめ" else 0.0) * sin(fall * PI)
		part.position = _rig.basis.inverse() * (_motion.basis.inverse() * (world_local - Vector3.UP * lift))
		var shrink := Vector3(1.0, lerpf(1.0, 0.32, fall), 1.0)
		part.basis = _rig.basis.inverse() * _motion.basis.inverse() * _rig.basis * Basis(Vector3.UP, (float(i) - 1.0) * 0.32 * fall) * Basis.from_scale(shrink) * start.basis

func _pose_tower(time: float) -> void:
	var bend := _ease(time / CONTACT_SECONDS)
	var scatter := _ease((time - CONTACT_SECONDS) / 0.65)
	var side := Vector3.UP.cross(_local_direction).normalized()
	var target_length := _travel.length() if _travel.length() > 0.01 else 1.4
	var maximum_lean := asin(clampf(target_length / 2.35, 0.45, 0.9))
	for i in range(4):
		var group_name: String = ["TowerLow", "TowerMiddle", "TowerUpper", "TowerCrown"][i]
		var start: Transform3D = _starts[group_name]
		var part: Node3D = _groups[group_name]
		var lean := maximum_lean * (0.62 + float(i) * 0.15) * bend
		var turn := Basis(side, lean)
		var bent := turn * start.origin + _local_direction * float(i) * 0.035 * bend
		var landed := _local_direction * (0.30 + float(i) * 0.39) + side * (0.21 if i % 2 == 0 else -0.23)
		landed.y = 0.055 + float(i % 2) * 0.035
		part.position = bent.lerp(landed, scatter)
		part.position.y += (0.28 if _quality != "控えめ" else 0.0) * sin(scatter * PI)
		part.basis = Basis(side, lean * (1.0 - scatter)) * Basis(Vector3.UP, (float(i) - 1.5) * 0.22 * scatter) * Basis.from_scale(Vector3(1.0, lerpf(1.0, 0.34, scatter), 1.0)) * start.basis

func _pose_box(time: float) -> void:
	var crush := _ease(time / 0.50)
	var spill := _ease((time - 0.10) / 0.65)
	var body: Node3D = _groups["CartonBody"]
	body.basis = Basis.from_scale(Vector3(lerpf(1.0, 1.15, crush), lerpf(1.0, 0.28, crush), lerpf(1.0, 1.08, crush)))
	body.basis.y += _local_direction * 0.20 * crush
	body.position = _local_direction * 0.12 * crush
	for group_name in ["FlapLeft", "FlapRight", "FlapFront", "FlapBack"]:
		var part: Node3D = _groups[group_name]
		var start: Transform3D = _starts[group_name]
		var outward := Vector3(start.origin.x, 0.0, start.origin.z).normalized()
		part.position = start.origin + outward * 0.20 * crush + _local_direction * 0.12 * crush
		part.position.y = lerpf(start.origin.y, 0.20, crush)
		var axis := Vector3.BACK if absf(outward.x) > 0.1 else Vector3.RIGHT
		var angle := -signf(outward.x) * 0.65 if absf(outward.x) > 0.1 else -signf(outward.z) * 0.48
		part.basis = Basis(axis, angle * crush) * start.basis
	var side := Vector3.UP.cross(_local_direction).normalized()
	for i in range(3):
		var group_name: String = ["PaperLow", "PaperMiddle", "PaperTop"][i]
		var part: Node3D = _groups[group_name]
		var start: Transform3D = _starts[group_name]
		var landed := _local_direction * (0.35 + float(i) * 0.38) + side * (float(i) - 1.0) * 0.38
		landed.y = 0.075 + float(i) * 0.025
		part.position = start.origin.lerp(landed, spill)
		part.position.y += (0.4 if _quality != "控えめ" else 0.0) * sin(spill * PI)
		part.basis = Basis(Vector3.UP, (float(i) - 1.0) * 0.40 * spill) * start.basis

func _bake_settled() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals := PackedVector3Array()
	for child in _rig.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var relative := instance.transform
		var ancestor := instance.get_parent() as Node3D
		while ancestor != self and ancestor != null:
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent() as Node3D
		var normal_basis := relative.basis.inverse().transposed()
		for index in range(instance.mesh.get_surface_count()):
			surface.append_from(instance.mesh, index, relative)
			var arrays := instance.mesh.surface_get_arrays(index)
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in source_normals:
				normals.append((normal_basis * normal).normalized())
	var arrays := surface.commit_to_arrays()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_settled.mesh = mesh
	_settled.show()
	_motion.hide()

func debug_snapshot() -> Dictionary:
	var poses: Dictionary = {}
	for group_name in _groups:
		var part: Node3D = _groups[group_name]
		poses[group_name] = {"position": _vector(part.position), "scale": _vector(part.scale), "rotation": _vector(part.rotation)}
	return {"kind": _kind, "index": _index, "broken": _broken, "elapsed": _elapsed,
		"processing": is_processing(), "quality": _quality, "origin": _vector(position),
		"travel": _vector(_travel), "motion_position": _vector(_motion.position if _motion != null else Vector3.ZERO),
		"intact_visible": _intact.visible if _intact != null else false,
		"settled_visible": _settled.visible if _settled != null else false,
		"groups": poses}

func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
