extends Node3D

# Fixed pools: 54 wake segments, 24 sparks, 10 air streaks, and one landing ring.
const TRAIL_POINTS := 28
const SPARK_COUNT := 24
const STREAK_COUNT := 10
const CYAN := Color(0.32, 0.92, 1.0, 0.7)
const GOLD := Color(1.0, 0.74, 0.30, 0.9)

var rider: CharacterBody3D
var course: Node3D
var reduced_motion := false
var _active := false
var _wake: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _streaks: MultiMeshInstance3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _trail_positions: Array[Vector3] = []
var _trail_rights: Array[Vector3] = []
var _trail_widths: Array[float] = []
var _trail_head := 0
var _trail_count := 0
var _trail_clock := 0.0
var _spark_positions: Array[Vector3] = []
var _spark_velocities: Array[Vector3] = []
var _spark_times: Array[float] = []
var _spark_colors: Array[Color] = []
var _next_spark := 0
var _edge_clock := 0.0
var _ring_time := 0.0
var _ring_strength := 0.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_wake = _make_pool("BoardWake", (TRAIL_POINTS - 1) * 2, true)
	_sparks = _make_pool("EdgeSparks", SPARK_COUNT)
	_streaks = _make_pool("AirStreaks", STREAK_COUNT)
	for i in TRAIL_POINTS:
		_trail_positions.append(Vector3.ZERO)
		_trail_rights.append(Vector3.RIGHT)
		_trail_widths.append(0.035)
	for i in SPARK_COUNT:
		_spark_positions.append(Vector3.ZERO)
		_spark_velocities.append(Vector3.ZERO)
		_spark_times.append(0.0)
		_spark_colors.append(CYAN)
	_ring = MeshInstance3D.new()
	_ring.name = "LandingRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring_material = _material()
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	reset_effects()


func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	reset_effects()


func reset_effects() -> void:
	_trail_count = 0
	_trail_head = 0
	_trail_clock = 0.0
	_edge_clock = 0.0
	_ring_time = 0.0
	_clock = 0.0
	for i in _spark_times.size():
		_spark_times[i] = 0.0
	if is_instance_valid(_wake):
		_hide_pool(_wake)
		_hide_pool(_sparks)
		_hide_pool(_streaks)
		_ring.visible = false


func cue(kind: String, strength: float = 1.0) -> void:
	if not _active or not is_instance_valid(rider):
		return
	strength = clampf(strength, 0.15, 1.0)
	var origin := rider.global_position + Vector3.UP * 0.08
	match kind:
		"land", "clean":
			_ring_time = 0.34
			_ring_strength = strength
			_ring.global_position = origin
			_ring_material.albedo_color = CYAN
			_emit_fan(origin, 8, CYAN, 3.0 + strength * 2.0)
		"boost", "release":
			_emit_fan(origin, 7, CYAN, 4.0)
		"jump":
			_emit_fan(origin, 4, CYAN, 2.2)
		"near", "trick":
			_emit_fan(origin, 7, Color(0.85, 1.0, 0.85, 0.85), 3.8)
		"hit":
			_emit_fan(origin, 10, GOLD, 4.5)


func _process(delta: float) -> void:
	if not _active or not is_instance_valid(rider):
		return
	_clock += delta
	var position_now := rider.get_global_transform_interpolated().origin
	var heading := _number("heading")
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := forward.cross(Vector3.UP)
	var carve := _number("carve_amount")
	var charge := _number("carve_charge")
	var grounded := rider.is_on_floor()
	_trail_clock -= delta
	if grounded and _number("speed") > 4.0:
		if _trail_clock <= 0.0:
			_trail_positions[_trail_head] = position_now + Vector3.UP * 0.07
			_trail_rights[_trail_head] = right
			_trail_widths[_trail_head] = 0.035 + absf(carve) * 0.065 + charge * 0.03
			_trail_head = (_trail_head + 1) % TRAIL_POINTS
			_trail_count = mini(TRAIL_POINTS, _trail_count + 1)
			_trail_clock = 0.025
	else:
		_trail_count = 0
	_draw_wake()
	_edge_clock -= delta
	if grounded and absf(carve) > 0.22 and _edge_clock <= 0.0:
		var edge := position_now + right * signf(carve) * 0.34 + Vector3.UP * 0.12
		_emit_spark(edge, -forward * 3.0 + right * signf(carve) * 2.5 + Vector3.UP * 0.8, CYAN)
		_edge_clock = 0.11 if reduced_motion else 0.045
	_update_sparks(delta)
	_update_ring(delta)
	_update_streaks(position_now, forward, right, grounded)


func _draw_wake() -> void:
	var visible_segments := mini(_trail_count - 1, 12 if reduced_motion else TRAIL_POINTS - 1)
	for i in TRAIL_POINTS - 1:
		var a := (_trail_head - 1 - i + TRAIL_POINTS) % TRAIL_POINTS
		var b := (a - 1 + TRAIL_POINTS) % TRAIL_POINTS
		for side_index in 2:
			var slot := i * 2 + side_index
			if i >= visible_segments:
				_hide_instance(_wake, slot)
				continue
			var side := -1.0 if side_index == 0 else 1.0
			var start := _trail_positions[a] + _trail_rights[a] * side * 0.30
			var end := _trail_positions[b] + _trail_rights[b] * side * 0.30
			var length := start.distance_to(end)
			if length < 0.005 or length > 5.0:
				_hide_instance(_wake, slot)
				continue
			var life := 1.0 - float(i) / float(maxi(1, visible_segments))
			var tint := CYAN
			tint.a = life * 0.66
			_set_line(_wake, slot, start, end, _trail_widths[a] * life, tint)


func _update_sparks(delta: float) -> void:
	for i in SPARK_COUNT:
		_spark_times[i] = maxf(0.0, _spark_times[i] - delta)
		if _spark_times[i] <= 0.0:
			_hide_instance(_sparks, i)
			continue
		_spark_positions[i] += _spark_velocities[i] * delta
		_spark_velocities[i].y -= delta * 6.0
		var color := _spark_colors[i]
		color.a *= _spark_times[i] / 0.36
		var tail := _spark_positions[i] - _spark_velocities[i].normalized() * 0.16
		_set_line(_sparks, i, _spark_positions[i], tail, 0.025, color)


func _update_ring(delta: float) -> void:
	_ring_time = maxf(0.0, _ring_time - delta)
	_ring.visible = _ring_time > 0.0
	if not _ring.visible:
		return
	var life := _ring_time / 0.34
	var radius := lerpf(0.36, 1.9 + _ring_strength * 0.5, 1.0 - life)
	if reduced_motion:
		radius = 0.8
	_ring.scale = Vector3(radius, 0.35, radius)
	_ring_material.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, life * 0.8)


func _update_streaks(origin: Vector3, forward: Vector3, right: Vector3, grounded: bool) -> void:
	var fast := bool(rider.get("boosting")) or (not grounded and _number("speed") > 23.0)
	for i in STREAK_COUNT:
		if reduced_motion or not fast:
			_hide_instance(_streaks, i)
			continue
		var phase := fmod(_clock * 1.8 + float(i) * 0.137, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var lateral := side * (0.8 + float(i % 3) * 0.45)
		var start := origin + right * lateral - forward * (0.7 + phase * 5.0)
		start.y += 0.12 + float(i % 4) * 0.18
		var tint := CYAN
		tint.a = sin(phase * PI) * 0.45
		_set_line(_streaks, i, start, start - forward * (0.7 + phase), 0.018, tint)


func _emit_fan(origin: Vector3, count: int, color: Color, force: float) -> void:
	var limit := mini(count, 4) if reduced_motion else count
	for i in limit:
		var angle := TAU * float(i) / float(limit) + 0.3
		_emit_spark(origin, Vector3(cos(angle) * force, 0.7 + float(i % 3) * 0.3, sin(angle) * force), color)


func _emit_spark(origin: Vector3, velocity: Vector3, color: Color) -> void:
	_spark_positions[_next_spark] = origin
	_spark_velocities[_next_spark] = velocity
	_spark_times[_next_spark] = 0.36
	_spark_colors[_next_spark] = color
	_next_spark = (_next_spark + 1) % SPARK_COUNT


func _make_pool(pool_name: String, count: int, flat: bool = false) -> MultiMeshInstance3D:
	var pool := MultiMeshInstance3D.new()
	pool.name = pool_name
	var mesh: PrimitiveMesh
	if flat:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mesh = plane
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mesh = box
	mesh.material = _material()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	pool.multimesh = multi
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.custom_aabb = AABB(Vector3(-200.0, -50.0, -1200.0), Vector3(400.0, 150.0, 1300.0))
	add_child(pool)
	return pool


func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	return material


func _set_line(pool: MultiMeshInstance3D, index: int, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := b - a
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	basis.x *= width
	basis.y *= width
	basis.z *= direction.length()
	pool.multimesh.set_instance_transform(index, Transform3D(basis, (a + b) * 0.5))
	pool.multimesh.set_instance_color(index, color)


func _hide_instance(pool: MultiMeshInstance3D, index: int) -> void:
	pool.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


func _hide_pool(pool: MultiMeshInstance3D) -> void:
	for i in pool.multimesh.instance_count:
		_hide_instance(pool, i)


func _number(property: String) -> float:
	var value = rider.get(property)
	return float(value) if value != null else 0.0
