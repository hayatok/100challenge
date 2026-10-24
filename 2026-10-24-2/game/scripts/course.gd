extends Node3D

@export var length: float = 900.0
@export var base_half_width: float = 7.0

const STEP: float = 1.0
const COLLISION_CHUNK: float = 64.0
# Authored islands: each horizontal transfer asks the player to turn in, then
# unwind before the next jump. Landing platforms are straight and visible.
const KNOTS: Array[Vector2] = [Vector2(0, 0), Vector2(35, 0), Vector2(135, 34),
	Vector2(175, 34), Vector2(225, 18), Vector2(280, 18), Vector2(390, -26),
	Vector2(430, -26), Vector2(495, 8), Vector2(565, 8), Vector2(615, 8),
	Vector2(705, -32), Vector2(785, 12), Vector2(930, 12)]
const GAPS: Array[Vector2] = [Vector2(245, 257), Vector2(530, 546), Vector2(825, 849)]
const LAUNCH_LENGTH: float = 18.0
const LAUNCH_HEIGHT: float = 1.5
# Marks start inside the measured Space window at each intended approach speed.
const LAUNCH_MARK_LENGTHS: Array[float] = [10.0, 8.0, 14.0]
const CHECKPOINTS: Array[float] = [0.0, 165.0, 280.0, 430.0, 565.0, 615.0, 785.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_course()


func center_at(s: float) -> Vector3:
	var x: float = KNOTS.back().y
	if s <= KNOTS.front().x:
		x = KNOTS.front().y
	else:
		for index in range(KNOTS.size() - 1):
			var a := KNOTS[index]
			var b := KNOTS[index + 1]
			if s <= b.x:
				x = lerpf(a.y, b.y, smoothstep(a.x, b.x, s))
				break
	# Downhill terraces create an actual change in height without hiding landings.
	var y := 24.0 - s * 0.014 - 3.0 * smoothstep(280.0, 430.0, s)
	y -= 3.0 * smoothstep(615.0, 785.0, s)
	y += launch_height_at(s)
	return Vector3(x, y, -s)


func launch_height_at(s: float) -> float:
	for gap in GAPS:
		if s >= gap.x - LAUNCH_LENGTH and s < gap.x:
			return LAUNCH_HEIGHT * smoothstep(gap.x - LAUNCH_LENGTH, gap.x, s)
		if s >= gap.x and s < gap.y:
			# Camera/reference height continues over the void without a lip jump.
			return LAUNCH_HEIGHT * (1.0 - smoothstep(gap.x, gap.y, s))
	return 0.0


func tangent_at(s: float) -> Vector3:
	return (center_at(s + 0.25) - center_at(s - 0.25)).normalized()


func heading_at(s: float) -> float:
	var tangent := tangent_at(s)
	return atan2(-tangent.x, -tangent.z)


func curvature_at(s: float) -> float:
	return angle_difference(heading_at(s - 2.0), heading_at(s + 2.0)) / 4.0


func half_width_at(s: float) -> float:
	return lerpf(9.0, base_half_width, smoothstep(120.0, 300.0, s))


func surface_at(s: float, offset: float, lift: float = 0.0) -> Vector3:
	return _surface_point(s, offset, lift)


func checkpoint_at(s: float) -> float:
	var checkpoint := 0.0
	for candidate in CHECKPOINTS:
		if candidate <= s:
			checkpoint = candidate
	return checkpoint


func gap_at(s: float) -> Vector2:
	for gap in GAPS:
		if s >= gap.x and s < gap.y:
			return gap
	return Vector2.ZERO


func next_gap_at(s: float) -> Vector2:
	for gap in GAPS:
		if s < gap.y:
			return gap
	return Vector2.ZERO


func beat_at(s: float) -> Dictionary:
	if s < 165.0:
		return {"index": 0, "name": "FIRST CARVE", "hint": "A / D で向きを変え、S + A / D で風をためる"}
	if s < 280.0:
		return {"index": 1, "name": "RELEASE & FLY", "hint": "S を離して加速。切れ目の手前で Space"}
	if s < 565.0:
		return {"index": 2, "name": "LINK THE TURNS", "hint": "カーブでため、直線で解放。着地で風を回復"}
	if s < 615.0:
		return {"index": 3, "name": "CLOUD VISTA", "hint": "次は連続カーブ。遠くの着地を見よう"}
	return {"index": 4, "name": "FINAL FLIGHT", "hint": "S を離すか Shift で加速し、最後の切れ目を跳ぶ"}


func _build_course() -> void:
	var road := _new_surface()
	var guides := _new_surface()
	var launch := _new_surface()
	var collision_faces := PackedVector3Array()
	var chunk_start := -12.0
	var s := chunk_start
	var end := length + 24.0
	while s < end:
		var next := minf(s + STEP, end)
		if gap_at((s + next) * 0.5) == Vector2.ZERO:
			var left_a := -half_width_at(s)
			var right_a := half_width_at(s)
			var left_b := -half_width_at(next)
			var right_b := half_width_at(next)
			_emit_strip(road, collision_faces, s, next, left_a, right_a, left_b, right_b)
			_emit_strip(guides, PackedVector3Array(), s, next,
				left_a, left_a + 0.18, left_b, left_b + 0.18, 0.025)
			_emit_strip(guides, PackedVector3Array(), s, next,
				right_a - 0.18, right_a, right_b - 0.18, right_b, 0.025)
			# Repeated transverse launch marks reveal the takeoff zone and scale.
			for gap_index in GAPS.size():
				var gap := GAPS[gap_index]
				if s >= gap.x - LAUNCH_MARK_LENGTHS[gap_index] and s < gap.x and int(s) % 3 == 0:
					_emit_strip(launch, PackedVector3Array(), s, next, left_a, right_a, left_b, right_b, 0.035)
				if s >= gap.y and s < gap.y + 4.0:
					_emit_strip(launch, PackedVector3Array(), s, next, left_a, right_a, left_b, right_b, 0.035)
		s = next
		if s - chunk_start >= COLLISION_CHUNK or is_equal_approx(s, end):
			if not collision_faces.is_empty():
				_add_collision(collision_faces, chunk_start)
			collision_faces = PackedVector3Array()
			chunk_start = s
	_add_visual(road, "MainSurface", Color("eee8d4"))
	_add_visual(guides, "RouteGuides", Color("168b8c"))
	_add_visual(launch, "LaunchMarks", Color("e8ac46"))


func _new_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _surface_point(s: float, offset: float, rise: float = 0.0) -> Vector3:
	# Cross sections remain on z = -s so progress, gaps and checkpoints agree.
	var bank := clampf(-heading_at(s) * 0.18, -0.12, 0.12)
	return center_at(s) + Vector3(offset, offset * tan(bank) + rise, 0.0)


func _emit_strip(surface: SurfaceTool, faces: PackedVector3Array,
		s: float, next: float, left_a: float, right_a: float,
		left_b: float, right_b: float, lift: float = 0.0) -> void:
	var rise_a := lift
	var rise_b := lift
	var a := _surface_point(s, left_a, rise_a)
	var b := _surface_point(s, right_a, rise_a)
	var c := _surface_point(next, right_b, rise_b)
	var d := _surface_point(next, left_b, rise_b)
	_emit_triangle(surface, faces, a, c, b)
	_emit_triangle(surface, faces, a, d, c)


func _emit_triangle(surface: SurfaceTool, faces: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot uses clockwise front faces; this order exposes the road from above.
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
		faces.append(vertex)


func _add_collision(faces: PackedVector3Array, start: float) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = false
	var body := StaticBody3D.new()
	body.name = "RoadCollision_%04d" % int(start + 12.0)
	body.collision_layer = 2
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _add_visual(surface: SurfaceTool, node_name: String, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	if node_name == "MainSurface":
		var stone := ShaderMaterial.new()
		stone.shader = preload("res://shaders/stone_path.gdshader")
		stone.set_shader_parameter("stone_color", Color("a4a08d") if node_name == "MainSurface" else Color("918f7d"))
		instance.material_override = stone
	add_child(instance)
