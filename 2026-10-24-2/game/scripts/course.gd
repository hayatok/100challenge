extends Node3D

@export var length: float = 1650.0
@export var base_half_width: float = 8.0

const STEP: float = 1.0
const COLLISION_CHUNK: float = 64.0
const LANE_LEFT: float = -5.5
const LANE_RIGHT: float = -2.0
const LANE_HEIGHT: float = 2.0
const OPTIONAL_SPANS: Array[Vector2] = [Vector2(340.0, 620.0), Vector2(960.0, 1240.0)]
const GAPS: Array[Vector2] = [Vector2(460.0, 468.0), Vector2(1080.0, 1088.0)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_course()


func center_at(s: float) -> Vector3:
	return Vector3(26.0 * sin(s / 140.0) + 12.0 * sin(s / 63.0),
		24.0 - 0.010 * s + 4.0 * sin(s / 170.0), -s)


func tangent_at(s: float) -> Vector3:
	return Vector3(26.0 / 140.0 * cos(s / 140.0) + 12.0 / 63.0 * cos(s / 63.0),
		-0.010 + 4.0 / 170.0 * cos(s / 170.0), -1.0).normalized()


func half_width_at(s: float) -> float:
	var vista := smoothstep(660.0, 720.0, s) * (1.0 - smoothstep(980.0, 1040.0, s))
	return maxf(base_half_width, 6.0) + 2.5 * vista


# Like center_at(), this uses the course coordinate space (world space in Main).
# Offset is an X displacement on the fixed z=-s cross section, not a tangent dot product.
func surface_at(s: float, offset: float, lift: float = 0.0) -> Vector3:
	return _surface_point(s, offset, lift)


func checkpoint_at(s: float) -> float:
	return clampf(floorf(maxf(s, 0.0) / 330.0) * 330.0 + 5.0, 0.0, maxf(0.0, length - 10.0))


func _build_course() -> void:
	var road := _new_surface()
	var upper := _new_surface()
	var guides := _new_surface()
	var collision_faces := PackedVector3Array()
	var chunk_start := -12.0
	var s := chunk_start
	var end := length + 24.0
	while s < end:
		var next := minf(s + STEP, end)
		var left_a := -half_width_at(s)
		var right_a := half_width_at(s)
		var left_b := -half_width_at(next)
		var right_b := half_width_at(next)
		_emit_strip(road, collision_faces, s, next, left_a, right_a, left_b, right_b)
		_emit_strip(guides, PackedVector3Array(), s, next,
			left_a, left_a + 0.13, left_b, left_b + 0.13, 0.018)
		_emit_strip(guides, PackedVector3Array(), s, next,
			right_a - 0.13, right_a, right_b - 0.13, right_b, 0.018)
		if _has_upper_surface(s, next):
			_emit_strip(upper, collision_faces, s, next,
				LANE_LEFT, LANE_RIGHT, LANE_LEFT, LANE_RIGHT, 0.0, true)
			_emit_strip(guides, PackedVector3Array(), s, next,
				LANE_LEFT, LANE_LEFT + 0.10, LANE_LEFT, LANE_LEFT + 0.10, 0.020, true)
			_emit_strip(guides, PackedVector3Array(), s, next,
				LANE_RIGHT - 0.10, LANE_RIGHT, LANE_RIGHT - 0.10, LANE_RIGHT, 0.020, true)
		s = next
		if s - chunk_start >= COLLISION_CHUNK or is_equal_approx(s, end):
			_add_collision(collision_faces, chunk_start)
			collision_faces = PackedVector3Array()
			chunk_start = s
	_add_visual(road, "MainSurface", Color("eee8d4"))
	_add_visual(upper, "OptionalSurface", Color("e0d8bd"))
	_add_visual(guides, "RouteGuides", Color("168b8c"))


func _new_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _surface_point(s: float, offset: float, rise: float = 0.0) -> Vector3:
	# Cross sections remain on z = -s so progress, gaps and checkpoints agree.
	var bank := 0.10 * sin(s / 100.0)
	return center_at(s) + Vector3(offset, offset * tan(bank) + rise, 0.0)


func _upper_height(s: float) -> float:
	for span in OPTIONAL_SPANS:
		if s >= span.x and s <= span.y:
			var entrance := smoothstep(span.x, span.x + 60.0, s)
			var exit := 1.0 - smoothstep(span.y - 60.0, span.y, s)
			return LANE_HEIGHT * entrance * exit
	return 0.0


func _has_upper_surface(s: float, next: float) -> bool:
	var midpoint := (s + next) * 0.5
	for gap in GAPS:
		if midpoint >= gap.x and midpoint < gap.y:
			return false
	for span in OPTIONAL_SPANS:
		if midpoint >= span.x and midpoint < span.y:
			return true
	return false


func _emit_strip(surface: SurfaceTool, faces: PackedVector3Array,
		s: float, next: float, left_a: float, right_a: float,
		left_b: float, right_b: float, lift: float = 0.0, elevated: bool = false) -> void:
	var rise_a := lift + (_upper_height(s) if elevated else 0.0)
	var rise_b := lift + (_upper_height(next) if elevated else 0.0)
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
	if node_name != "RouteGuides":
		var stone := ShaderMaterial.new()
		stone.shader = preload("res://shaders/stone_path.gdshader")
		stone.set_shader_parameter("stone_color", Color("a4a08d") if node_name == "MainSurface" else Color("918f7d"))
		instance.material_override = stone
	add_child(instance)
