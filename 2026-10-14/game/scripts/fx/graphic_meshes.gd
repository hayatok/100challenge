extends RefCounted
## Original small comic shapes, shared by all instances. Local XY faces camera.

const NAVY := Color("223443")
const GOLD := Color("ffd45b")
const PINK := Color("f36a99")
const IVORY := Color("fff4dc")

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.set_normal(Vector3.FORWARD)
	for vertex in [a, b, c]:
		tool.add_vertex(vertex)

static func _polygon(tool: SurfaceTool, points: PackedVector2Array, color: Color, z: float, offset := Vector2.ZERO) -> void:
	for index in points.size():
		var a := points[index] + offset
		var b := points[(index + 1) % points.size()] + offset
		_triangle(tool, Vector3(offset.x, offset.y, z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), color)

static func star() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector2Array()
	for index in 20:
		var angle := TAU * index / 20.0
		var radius := (1.0 + 0.14 * sin(index * 2.4)) if index % 2 == 0 else 0.50
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_polygon(tool, points, PINK, -0.035, Vector2(-0.13, -0.09))
	_polygon(tool, points, NAVY, -0.02)
	var inset := PackedVector2Array()
	for point in points:
		inset.append(point * 0.87)
	_polygon(tool, inset, GOLD, 0.0)
	var core := PackedVector2Array()
	for point in points:
		core.append(point * 0.41)
	_polygon(tool, core, IVORY, 0.012)
	return tool.commit()

static func jet_core() -> Mesh:
	# Closed connected scallops in local +Z: tiny nozzle, widening cloudy tail.
	# Built once. Runtime changes only this mesh instance's transform.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := PackedVector2Array([Vector2(0.0, 0.025), Vector2(0.12, 0.065), Vector2(0.25, 0.13), Vector2(0.36, 0.18), Vector2(0.43, 0.15), Vector2(0.53, 0.28), Vector2(0.60, 0.24), Vector2(0.70, 0.38), Vector2(0.77, 0.32), Vector2(0.80, 0.46), Vector2(0.86, 0.44), Vector2(0.92, 0.37), Vector2(0.965, 0.25), Vector2(0.99, 0.12), Vector2(1.0, 0.02)])
	var spokes := 12
	for ring_index in profile.size() - 1:
		for spoke in spokes:
			var vertices: Array[Vector3] = []
			for corner in [Vector2i(ring_index, spoke), Vector2i(ring_index, (spoke + 1) % spokes), Vector2i(ring_index + 1, spoke), Vector2i(ring_index + 1, (spoke + 1) % spokes)]:
				var angle: float = TAU * corner.y / spokes
				var sample: Vector2 = profile[corner.x]
				var radius := sample.y * (1.0 + 0.10 * sin(angle * 3.0 + sample.x * 8.0))
				vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius, sample.x))
			_jet_triangle(tool, vertices[0], vertices[2], vertices[1])
			_jet_triangle(tool, vertices[1], vertices[2], vertices[3])
	for spoke in spokes:
		var angle := TAU * spoke / spokes
		var next := TAU * (spoke + 1) / spokes
		_jet_triangle(tool, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * profile[0].y, Vector3(cos(next), sin(next), 0) * profile[0].y)
		_jet_triangle(tool, Vector3(0, 0, 1), Vector3(cos(next) * 0.02, sin(next) * 0.02, 1), Vector3(cos(angle) * 0.02, sin(angle) * 0.02, 1))
	return tool.commit()

static func _jet_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.set_color(Color.WHITE)
	tool.set_normal((c - a).cross(b - a).normalized())
	for vertex in [a, b, c]:
		tool.add_vertex(vertex)

static func ring() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 48:
		var angle := TAU * index / 48.0
		var next := TAU * (index + 1) / 48.0
		var a := Vector3(cos(angle), sin(angle), 0)
		var b := Vector3(cos(next), sin(next), 0)
		_triangle(tool, a, b, b * 0.96, Color.WHITE)
		_triangle(tool, a, b * 0.96, a * 0.96, Color.WHITE)
	return tool.commit()

static func streak() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangle(tool, Vector3(-0.065, 0, 0), Vector3(0.065, 0, 0), Vector3(0, 1, 0), Color("159b9c"))
	_triangle(tool, Vector3(-0.024, 0.02, 0.009), Vector3(0.024, 0.02, 0.009), Vector3(0, 0.92, 0.009), Color("c4faff"))
	return tool.commit()

static func ribbon() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 6:
		var y := float(index) / 6.0 - 0.5
		var next := float(index + 1) / 6.0 - 0.5
		var x := sin(y * 8) * 0.09
		var nx := sin(next * 8) * 0.09
		var z := cos(y * 7) * 0.075
		var nz := cos(next * 7) * 0.075
		_triangle(tool, Vector3(x - 0.07, y, z), Vector3(x + 0.07, y, z), Vector3(nx + 0.07, next, nz), Color.WHITE)
		_triangle(tool, Vector3(x - 0.07, y, z), Vector3(nx + 0.07, next, nz), Vector3(nx - 0.07, next, nz), Color.WHITE)
	return tool.commit()

static func outlined_paper(source: Mesh) -> Mesh:
	# Outline only the sheet silhouette: extruding every modeled stamp/line would
	# cover the imported colored print with a dark patch.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in source.get_surface_count():
		tool.append_from(source, surface, Transform3D.IDENTITY)
	tool.deindex()
	var contour := PackedVector2Array([Vector2(-0.142, -0.190), Vector2(0.142, -0.190), Vector2(0.142, 0.190), Vector2(-0.063, 0.190), Vector2(-0.142, 0.115)])
	for index in contour.size():
		var a := contour[index]
		var b := contour[(index + 1) % contour.size()]
		var ia := a * 0.87
		var ib := b * 0.87
		var za := 0.012 * (pow(2.0 * a.y / 0.35, 2.0) - 0.5)
		var zb := 0.012 * (pow(2.0 * b.y / 0.35, 2.0) - 0.5)
		_triangle(tool, Vector3(a.x, a.y, za), Vector3(b.x, b.y, zb), Vector3(ib.x, ib.y, zb), NAVY)
		_triangle(tool, Vector3(a.x, a.y, za), Vector3(ib.x, ib.y, zb), Vector3(ia.x, ia.y, za), NAVY)
	return tool.commit()
