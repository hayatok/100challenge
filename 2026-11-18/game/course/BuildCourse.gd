extends SceneTree
## Rebuild the authored scene with Godot 4.7 from the game project.
## godot --path . --rendering-method gl_compatibility --script res://course/BuildCourse.gd
## The Compatibility renderer populates the serialized MultiMesh buffers.

const COURSE_PATH := "res://course/Course.tscn"
const CREAM := Color("#f6e6c4")
const NAVY := Color("#1d406c")
const BLUE := Color("#2c6096")
const RED := Color("#dc4b43")
const BRASS := Color("#d5a459")
const IRON := Color("#526678")
const RUBBER := Color("#303e4d")
const ROPE := Color("#d1b98e")
const WOOD := Color("#ac6d42")
const BRIDGE_WOOD := Color("#c99451")
const OUTER_WOOD := Color("#ab744d")
const CHECKPOINT := Color("#e6ddaf")

var course := Node3D.new()
var rng := RandomNumberGenerator.new()
var batches: Dictionary[Node3D, Dictionary] = {}
var meshes: Dictionary[String, Mesh] = {}


func _initialize() -> void:
	bake_course.call_deferred()


func bake_course() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Bake the course with the Compatibility renderer to retain its instance buffers.")
		quit(1)
		return
	rng.seed = 18062026
	course.name = "Course"
	course.set_script(preload("res://course/Course.gd"))
	setup_meshes()
	setup_environment()
	build_raceway()
	build_harbor()
	bake_batches()
	root.add_child(course)
	await RenderingServer.frame_post_draw
	var scene := PackedScene.new()
	var error := scene.pack(course)
	if error == OK:
		error = ResourceSaver.save(scene, COURSE_PATH)
	scene = null
	root.remove_child(course)
	course.free()
	meshes.clear()
	batches.clear()
	await process_frame
	quit(int(error))


func add(parent: Node, child: Node, node_name: String) -> void:
	child.name = node_name
	parent.add_child(child)
	child.owner = course


func group(parent: Node, node_name: String, position := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	add(parent, node, node_name)
	node.position = position
	return node


func setup_environment() -> void:
	var environment := Environment.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://course/HarborSky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e1ecf7")
	environment.ambient_light_energy = 0.41
	var world := WorldEnvironment.new()
	world.environment = environment
	add(course, world, "HarborSky")

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -36, 0)
	sun.light_color = Color("#fff0d4")
	sun.light_energy = 0.91
	sun.shadow_enabled = true
	sun.shadow_bias = 0.14
	sun.shadow_normal_bias = 2.0
	sun.shadow_opacity = 0.88
	sun.shadow_blur = 1.35
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 48.0
	add(course, sun, "Sun")

	var water := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(1200, 1200)
	water.mesh = surface
	water.position = Vector3(0, -1.75, -79)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://course/Water.gdshader")
	water_material.resource_local_to_scene = true
	water.material_override = water_material
	add(course, water, "Sea")


func setup_meshes() -> void:
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.vertex_color_is_srgb = true
	painted.roughness = 0.66
	var metal := painted.duplicate() as StandardMaterial3D
	metal.metallic = 0.49
	metal.roughness = 0.42
	var fabric := painted.duplicate() as StandardMaterial3D
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	fabric.roughness = 0.9
	var timber := ShaderMaterial.new()
	timber.shader = preload("res://course/Timber.gdshader")

	meshes["DeckBoards"] = rounded_board(timber, 0.009)
	meshes["Timber"] = rounded_board(timber)
	meshes["Painted"] = rounded_board(painted)
	meshes["MetalBox"] = rounded_board(metal)
	meshes["Round"] = cylinder_mesh(painted, 0.5, 0.5, 16)
	meshes["Turned"] = cylinder_mesh(painted, 0.43, 0.5, 16)
	meshes["Cone"] = cylinder_mesh(painted, 0.0, 0.5, 14)
	meshes["MetalRound"] = cylinder_mesh(metal, 0.5, 0.5, 16)
	meshes["Rope"] = cylinder_mesh(painted, 0.5, 0.5, 7)
	meshes["Dome"] = sphere_mesh(painted, 16, 8)
	meshes["Rock"] = sphere_mesh(painted, 7, 4)

	var flag := SurfaceTool.new()
	flag.begin(Mesh.PRIMITIVE_TRIANGLES)
	flag.set_material(fabric)
	mesh_triangle(flag, Vector3(0, 0, 0), Vector3(0.5, -0.29, 0.15), Vector3(1, 0, 0))
	mesh_triangle(flag, Vector3(0, 0, 0), Vector3(0.5, -1, 0.035), Vector3(0.5, -0.29, 0.15))
	mesh_triangle(flag, Vector3(0.5, -0.29, 0.15), Vector3(0.5, -1, 0.035), Vector3(1, 0, 0))
	meshes["Pennants"] = flag.commit()


func rounded_board(material: Material, bevel := 0.032) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var flat := 0.5 - bevel
	var side: Array[float] = [-0.5, -flat, flat, 0.5]
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT,
			Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var tangent := Vector3.RIGHT if absf(normal.y) > 0.5 else normal.cross(Vector3.UP)
		var bitangent := normal.cross(tangent)
		for row in range(3):
			for column in range(3):
				var a := normal * 0.5 + tangent * side[column] + bitangent * side[row]
				var b := normal * 0.5 + tangent * side[column + 1] + bitangent * side[row]
				var c := normal * 0.5 + tangent * side[column + 1] + bitangent * side[row + 1]
				var d := normal * 0.5 + tangent * side[column] + bitangent * side[row + 1]
				for point: Vector3 in [a, c, b, a, d, c]:
					var core := point.clamp(Vector3.ONE * -flat, Vector3.ONE * flat)
					var unit := (point - core).normalized()
					surface.set_normal(unit)
					surface.set_uv(Vector2(point.x, point.z))
					surface.add_vertex(core + unit * bevel)
	surface.index()
	return surface.commit()


func mesh_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func cylinder_mesh(material: Material, top: float, bottom: float, sides: int) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 0
	mesh.material = material
	return mesh


func sphere_mesh(material: Material, sides: int, rings: int) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = rings
	mesh.material = material
	return mesh


func instance(parent: Node3D, family: String, transform: Transform3D, color: Color) -> void:
	if not batches.has(parent):
		batches[parent] = {}
	var parts := batches[parent] as Dictionary
	if not parts.has(family):
		parts[family] = []
	parts[family].append([transform, color])


func piece(parent: Node3D, family: String, position: Vector3, size: Vector3,
		color: Color, rotation := Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rotation).scaled_local(size)
	instance(parent, family, Transform3D(basis, position), color)


func rod(parent: Node3D, family: String, from: Vector3, to: Vector3,
		diameter: float, color: Color) -> void:
	var span := to - from
	var basis := Basis(Quaternion(Vector3.UP, span.normalized()))
	basis = basis.scaled_local(Vector3(diameter, span.length() + 0.006, diameter))
	instance(parent, family, Transform3D(basis, (from + to) * 0.5), color)


func plank(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	piece(parent, "Timber", position, size, color)


func box(parent: Node3D, position: Vector3, size: Vector3, color: Color,
		rotation := Vector3.ZERO) -> void:
	piece(parent, "Painted", position, size, color, rotation)


func bake_batches() -> void:
	for parent in batches:
		var parts := batches[parent] as Dictionary
		for family: String in parts:
			var data := parts[family] as Array
			var collection := MultiMesh.new()
			collection.transform_format = MultiMesh.TRANSFORM_3D
			collection.use_colors = true
			collection.mesh = meshes[family]
			collection.instance_count = data.size()
			for index in data.size():
				collection.set_instance_transform(index, data[index][0])
				collection.set_instance_color(index, data[index][1])
			var node := MultiMeshInstance3D.new()
			node.multimesh = collection
			if family == "DeckBoards":
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add(parent, node, family)


func build_raceway() -> void:
	fixed_pier("LaunchPier", -6.0, 52.0, -4.7, 4.7, WOOD, false)
	fixed_pier("LighthousePier", 94.0, 158.0, -4.7, 4.7, WOOD, false)
	fixed_pier("ShortcutEntry", 52.0, 59.0, -4.7, -0.2, BRIDGE_WOOD, false)
	fixed_pier("ShortcutExit", 87.0, 94.0, -4.7, -0.2, BRIDGE_WOOD, false)
	fixed_pier("OuterPier", 52.0, 94.0, 1.0, 5.0, OUTER_WOOD, true)

	var bridge := group(course, "TiltingBridge", Vector3(0, 0, -73.0))
	build_deck(bridge, -14, 14, -4.7, -0.2, BRIDGE_WOOD, false)
	for end in [-13.7, 13.7]:
		box(bridge, Vector3(-2.45, 0.01, end), Vector3(4.3, 0.035, 0.48), CREAM)
	for x in [-4.55, -0.34]:
		plank(bridge, Vector3(x, -0.33, 0), Vector3(0.19, 0.28, 27.96), BRIDGE_WOOD)
	for p in range(-12, 13, 4):
		box(bridge, Vector3(-2.45, -0.43, p), Vector3(4.42, 0.24, 0.33), BLUE)

	var fulcrum := group(course, "BridgeFulcrum", Vector3(-2.45, -0.39, -73.0))
	rod(fulcrum, "MetalRound", Vector3(-2.39, 0, 0), Vector3(2.39, 0, 0), 0.44, BRASS)
	for x in [-2.16, 2.16]:
		rod(fulcrum, "MetalRound", Vector3(x - 0.20, 0, 0), Vector3(x + 0.20, 0, 0), 0.65, IRON)
		for z in [-1.24, 1.24]:
			rod(fulcrum, "MetalBox", Vector3(x, -1.51, z), Vector3(x, -0.1, 0), 0.37, NAVY)
	box(fulcrum, Vector3(0, -1.46, 0), Vector3(5.1, 0.36, 3.02), BLUE)

	cargo_box(course, "CargoBoxA", Vector3(-1.8, 0, -14.0), 1.5, 1.25)
	cargo_box(course, "CargoBoxB", Vector3(2.0, 0, -21.0), 1.5, 1.25)
	build_sweeper("StartBar", 35.0)
	build_sweeper("FinishBar", 125.0)

	var marks := group(course, "CourseMarkings")
	for p in [27.0, 46.0, 108.0]:
		for i in range(8):
			box(marks, Vector3(-4.15 + 1.18 * i, 0.009, -p), Vector3(0.83, 0.022, 0.17), CHECKPOINT)
	checkered_band(marks, 0.0, 0.55, BLUE)
	checkered_band(marks, 150.0, 0.94, NAVY)
	for direction in [-1.0, 1.0]:
		var x: float = direction * 1.92
		var color := BRIDGE_WOOD.lightened(0.44) if direction < 0.0 else CREAM
		for line in range(2):
			var p := 49.1 + 0.81 * line
			box(marks, Vector3(x - 0.18, 0.009, -p), Vector3(0.14, 0.022, 0.57),
				color, Vector3(0, -0.89, 0))
			box(marks, Vector3(x + 0.18, 0.009, -p), Vector3(0.14, 0.022, 0.57),
				color, Vector3(0, 0.89, 0))
	build_finish()


func route_offset(p: float, outer: bool) -> float:
	return 3.5 * sin(PI * (p - 52.0) / 42.0) if outer else 0.0


func build_deck(parent: Node3D, start: float, finish: float, left: float,
		right: float, tint: Color, outer: bool) -> void:
	var board_count := ceili((finish - start) / 0.51)
	var spacing := (finish - start) / board_count
	for index in board_count:
		var p := start + (index + 0.5) * spacing
		var shift := route_offset(p, outer)
		var x := (left + right) * 0.5 + shift
		var variation := tint.lerp(Color("#805f4d"), rng.randf_range(0, 0.18))
		variation = variation.lightened(rng.randf_range(0.0, 0.12))
		var width := right - left
		if width >= 7.0 and index % 4 != 0:
			var join := [0.33, 0.56, 0.69][index % 3] as float
			var left_board := width * join
			piece(parent, "DeckBoards", Vector3(left + shift + left_board * 0.5, -0.105, -p),
				Vector3(left_board - 0.011, 0.21, spacing - 0.014), variation)
			piece(parent, "DeckBoards", Vector3(right + shift - (width - left_board) * 0.5, -0.105, -p),
				Vector3(width - left_board - 0.011, 0.21, spacing - 0.014),
				variation.darkened(rng.randf_range(0.0, 0.09)))
		else:
			piece(parent, "DeckBoards", Vector3(x, -0.105, -p),
				Vector3(width, 0.21, spacing - 0.012), variation)
		if index % 3 == 0:
			for edge: float in [left + shift + 0.23, right + shift - 0.23]:
				piece(parent, "MetalRound", Vector3(edge, 0.007, -p),
					Vector3(0.073, 0.025, 0.073), IRON.lightened(0.32))


func fixed_pier(node_name: String, start: float, finish: float, left: float,
		right: float, tint: Color, outer: bool) -> void:
	var sections := ceili((finish - start) / 15.0)
	var root := group(course, node_name)
	for section in sections:
		var parent := group(root, "Span%02d" % (section + 1))
		var a := lerpf(start, finish, float(section) / sections)
		var b := lerpf(start, finish, float(section + 1) / sections)
		build_deck(parent, a, b, left, right, tint, outer)
		var frame_count := ceili((b - a) / 1.3)
		for index in frame_count:
			var p := lerpf(a, b, float(index) / frame_count)
			var next := lerpf(a, b, float(index + 1) / frame_count)
			var shift := route_offset(p, outer)
			var next_shift := route_offset(next, outer)
			for side in [-1.0, 1.0]:
				var edge := right if side > 0 else left
				var x: float = edge - side * 0.08
				var from := Vector3(x + shift, -0.26, -p)
				var to := Vector3(x + next_shift, -0.26, -next)
				rod(parent, "Painted", from, to, 0.21, tint.darkened(0.21))
				from.y = -0.47
				to.y = -0.47
				var paint_color := CREAM if index % 3 == 1 else BLUE
				rod(parent, "Painted", from, to, 0.21, paint_color)
				from.y = -0.68
				to.y = -0.68
				rod(parent, "Painted", from, to, 0.22, NAVY)
				if outer:
					var edge_color := CREAM if index % 3 == 1 else BLUE
					var middle := (from + to) * 0.5
					middle.y = 0.003
					var angle := atan2(to.x - from.x, to.z - from.z)
					box(parent, middle, Vector3(0.13, 0.031, from.distance_to(to)), edge_color,
						Vector3(0, angle, 0))
		for index in range(2):
			var p := lerpf(a, b, (index + 0.5) / 2.0)
			var x := (left + right) * 0.5 + route_offset(p, outer)
			box(parent, Vector3(x, -1.39, -p),
				Vector3(right - left - 0.34, 1.09, 0.79), BLUE)
			box(parent, Vector3(x, -0.85, -p),
				Vector3(right - left + 0.22, 0.22, 0.96), NAVY)
			for side in [-1.0, 1.0]:
				var edge := right if side > 0 else left
				var offset := route_offset(p, outer)
				var wheel := Vector3(edge + offset + side * 0.055, -0.99, -p)
				piece(parent, "Round", wheel, Vector3(0.69, 0.24, 0.69), RUBBER,
					Vector3(0, 0, PI / 2.0))
				piece(parent, "Round", wheel + Vector3(side * 0.127, 0, 0),
					Vector3(0.38, 0.02, 0.38), NAVY, Vector3(0, 0, PI / 2.0))
	for side in [-1.0, 1.0]:
		var x := right - 0.16 if side > 0 else left + 0.16
		var leave_split_open: bool = side > 0.0 and node_name in ["LaunchPier", "LighthousePier"]
		var a := start + (2.4 if leave_split_open and start > 0.0 else 0.48)
		var b := finish - (2.4 if leave_split_open and start < 0.0 else 0.48)
		fence(root, x, a, b, outer)


func fence(parent: Node3D, x: float, start: float, finish: float, outer: bool) -> void:
	var spans := maxi(1, roundi((finish - start) / 3.7))
	var last := Vector3.ZERO
	for index in range(spans + 1):
		var p := lerpf(start, finish, float(index) / spans)
		var post := Vector3(x + route_offset(p, outer), 0, -p)
		bollard(parent, post)
		if index > 0:
			sagging_rope(parent, last + Vector3.UP * 0.68, post + Vector3.UP * 0.68, 0.23, 0.073)
		last = post


func bollard(parent: Node3D, at: Vector3) -> void:
	piece(parent, "Round", at + Vector3.UP * 0.43, Vector3(0.28, 0.87, 0.28), NAVY)
	piece(parent, "MetalRound", at + Vector3.UP * 0.023, Vector3(0.4, 0.07, 0.4), IRON)
	piece(parent, "Round", at + Vector3.UP * 0.78, Vector3(0.31, 0.09, 0.31), CREAM)
	piece(parent, "Round", at + Vector3.UP * 0.66, Vector3(0.305, 0.06, 0.305), ROPE)
	piece(parent, "Dome", at + Vector3.UP * 0.85, Vector3(0.3, 0.18, 0.3), CREAM)


func sagging_rope(parent: Node3D, start: Vector3, finish: Vector3, drop: float,
		diameter: float) -> void:
	var last := start
	for index in range(1, 7):
		var t := float(index) / 6.0
		var point := start.lerp(finish, t) - Vector3.UP * (4.0 * t * (1.0 - t) * drop)
		rod(parent, "Rope", last, point, diameter, ROPE)
		last = point


func cargo_box(parent: Node3D, node_name: String, at: Vector3, width: float,
		height: float) -> void:
	var crate := group(parent, node_name, at)
	var stile := width * 0.125
	var tint := Color("#a3663e")
	plank(crate, Vector3(0, height * 0.5, 0), Vector3(width * 0.956, height - 0.09, width * 0.956), tint)
	for sign in [-1.0, 1.0]:
		for row in range(4):
			var y := height * (row + 0.5) / 4.0
			var panel := tint.lightened(0.1 + row * 0.035)
			plank(crate, Vector3(0, y, sign * width * 0.464),
				Vector3(width * 0.92, height * 0.241, width * 0.065), panel)
			plank(crate, Vector3(sign * width * 0.464, y, 0),
				Vector3(width * 0.92, height * 0.241, width * 0.065), panel)
		for y in [0.088 * height, 0.912 * height]:
			var edge: float = sign * width * 0.471
			plank(crate, Vector3(0, y, edge), Vector3(width, stile, width * 0.05), WOOD)
			piece(crate, "Timber", Vector3(edge, y, 0),
				Vector3(width, stile, width * 0.05), WOOD, Vector3(0, PI / 2.0, 0))
		var diagonal := Vector2(width * 0.67, height * 0.67)
		box(crate, Vector3(0, height * 0.5, sign * width * 0.49),
			Vector3(diagonal.length(), width * 0.075, width * 0.02),
			WOOD.lightened(0.17), Vector3(0, 0, diagonal.angle() * sign))
		for corner in [-1.0, 1.0]:
			var x: float = sign * width * 0.428
			var z: float = corner * width * 0.428
			box(crate, Vector3(x, height * 0.51, z), Vector3(stile, height * 0.95, stile), WOOD)
			for y in [0.085 * height, 0.915 * height]:
				piece(crate, "MetalRound", Vector3(x, y, corner * width * 0.499),
					Vector3(0.068, 0.027, 0.068), IRON, Vector3(PI / 2.0, 0, 0))
	for index in range(5):
		var z := width * (index - 2) * 0.177
		plank(crate, Vector3(0, height - 0.051, z), Vector3(width * 0.87, 0.10, width * 0.168),
			WOOD.lightened(0.05 * (index % 3)))
	for z in [-0.405 * width, 0.405 * width]:
		plank(crate, Vector3(0, height - 0.055, z), Vector3(width, 0.11, width * 0.19), WOOD)


func build_sweeper(node_name: String, p: float) -> void:
	var pedestal := group(course, node_name, Vector3(0, 0, -p))
	piece(pedestal, "MetalRound", Vector3(0, 0.062, 0), Vector3(1.34, 0.12, 1.34), IRON)
	piece(pedestal, "Turned", Vector3(0, 0.23, 0), Vector3(1.12, 0.37, 1.12), NAVY)
	piece(pedestal, "Round", Vector3(0, 0.30, 0), Vector3(1.06, 0.10, 1.06), CREAM)
	piece(pedestal, "Turned", Vector3(0, 0.59, 0), Vector3(0.82, 0.49, 0.82), BLUE)
	piece(pedestal, "Round", Vector3(0, 0.79, 0), Vector3(0.87, 0.13, 0.87), CREAM)
	piece(pedestal, "Dome", Vector3(0, 0.85, 0), Vector3(0.60, 0.10, 0.60), RED)
	for index in range(8):
		var angle := TAU * index / 8.0
		piece(pedestal, "MetalRound", Vector3(0.57 * cos(angle), 0.13, 0.57 * sin(angle)),
			Vector3(0.088, 0.05, 0.088), BRASS)

	var arms := group(pedestal, "Sweeper", Vector3(0, 0.65, 0))
	for side in [-1.0, 1.0]:
		rod(arms, "MetalRound", Vector3(side * 0.31, 0, 0), Vector3(side * 0.82, 0, 0), 0.34, IRON)
		for index in range(6):
			var a := 0.72 + index * 0.53
			var b := a + 0.53
			var fabric := RED if index % 2 == 0 else CREAM
			rod(arms, "Round", Vector3(side * a, 0, 0),
				Vector3(side * b, 0, 0), 0.5, fabric)
			rod(arms, "Round", Vector3(side * (b - 0.018), 0, 0),
				Vector3(side * (b + 0.018), 0, 0), 0.505, fabric.darkened(0.14))
		piece(arms, "Dome", Vector3(side * 3.87, 0, 0), Vector3(0.46, 0.49, 0.49), CREAM)


func checkered_band(parent: Node3D, p: float, depth: float, dark: Color) -> void:
	for row in range(2):
		for column in range(16):
			var x := -4.55 + (column + 0.5) * 9.1 / 16.0
			var z := -p + (0.25 - row * 0.5) * depth
			var color := CREAM if (row + column) % 2 == 0 else dark
			box(parent, Vector3(x, 0.01, z), Vector3(9.1 / 16.0, 0.027, depth * 0.5), color)


func build_finish() -> void:
	var arch := group(course, "FinishArch", Vector3(0, 0, -150.0))
	for x in [-4.38, 4.38]:
		piece(arch, "Round", Vector3(x, 0.27, 0), Vector3(0.96, 0.54, 0.96), NAVY)
		piece(arch, "Turned", Vector3(x, 2.04, 0), Vector3(0.65, 3.18, 0.65), CREAM)
		for y in [0.61, 1.66, 2.97]:
			piece(arch, "Round", Vector3(x, y, 0), Vector3(0.64, 0.25, 0.64), BLUE)
		piece(arch, "Round", Vector3(x, 3.64, 0), Vector3(0.83, 0.16, 0.83), BRASS)
		piece(arch, "Dome", Vector3(x, 3.79, 0), Vector3(0.81, 0.58, 0.81), BLUE)
		rod(arch, "MetalRound", Vector3(x, 3.85, 0), Vector3(x, 4.58, 0), 0.09, BRASS)
		piece(arch, "Pennants", Vector3(x, 4.52, 0.07), Vector3(0.91, 0.55, 0.32), RED)
	box(arch, Vector3(0, 3.46, -0.04), Vector3(8.54, 0.20, 0.19), CREAM)
	box(arch, Vector3(0, 3.46, 0.07), Vector3(8.1, 0.074, 0.093), BLUE)
	for x in [-3.81, -2.83, -1.85, -0.87, 0.08, 1.06, 2.04, 3.02]:
		var color := RED if x < -2.0 else (BLUE if x > 1.0 else CREAM)
		piece(arch, "Pennants", Vector3(x, 3.44, 0.13), Vector3(0.81, 0.58, 0.37), color)
	ship_wheel(arch, Vector3(0, 3.79, 0.13), 0.53)
	for p in [153.9, 157.2]:
		bunting(course, Vector3(-4.47, 4.1, -p), Vector3(4.47, 4.1, -p), 0.52)
		for x in [-4.47, 4.47]:
			rod(course, "Round", Vector3(x, 0, -p), Vector3(x, 2.24, -p), 0.11, CREAM)


func ship_wheel(parent: Node3D, center: Vector3, radius: float) -> void:
	piece(parent, "MetalRound", center, Vector3(0.25, 0.20, 0.25), BRASS, Vector3(PI / 2.0, 0, 0))
	for index in range(16):
		var first := TAU * index / 16.0
		var second := TAU * (index + 1) / 16.0
		var a := Vector3(cos(first), sin(first), 0) * radius
		var b := Vector3(cos(second), sin(second), 0) * radius
		rod(parent, "Round", center + a, center + b, 0.081, BRASS)
		if index % 2 == 0:
			rod(parent, "Round", center, center + a * 1.24, 0.068, BRASS)


func bunting(parent: Node3D, start: Vector3, finish: Vector3, drop: float) -> void:
	sagging_rope(parent, start, finish, drop, 0.033)
	var count := maxi(2, floori(start.distance_to(finish) / 0.75))
	var heading := atan2(-(finish.z - start.z), finish.x - start.x)
	for index in range(count):
		var t := (index + 0.11) / count
		var base := start.lerp(finish, t) - Vector3.UP * (4.0 * t * (1.0 - t) * drop)
		var color: Color = [CREAM, BLUE, RED, BRASS][index % 4]
		piece(parent, "Pennants", base, Vector3(0.67, 0.53, 0.34), color, Vector3(0, heading, 0))


func build_harbor() -> void:
	var scenery := group(course, "HarborScenery")
	var islands := group(scenery, "CoastalIslands")
	for index in range(15):
		var x := -111.0 + index * 16.0
		var p := 225.0 + rng.randf_range(-12, 19)
		var height := rng.randf_range(3.8, 8.4)
		var width := rng.randf_range(21.0, 33.0)
		piece(islands, "Rock", Vector3(x, height * 0.12 - 2.7, -p),
			Vector3(width, height, 37.0), Color("#608b89"))
		for cluster in range(5):
			var offset := (cluster - 2) * 4.4 + rng.randf_range(-2.0, 2.0)
			var rise := rng.randf_range(0.71, 1.4)
			var hill_color := Color("#5d9f83").lerp(Color("#92aa86"), rng.randf())
			piece(islands, "Rock", Vector3(x + offset, height * 0.29,
				-p + rng.randf_range(0.0, 7.0)),
				Vector3(width * rng.randf_range(0.35, 0.61), height * rise, 32.0),
				hill_color, Vector3(0, rng.randf_range(-0.6, 0.6), 0))

	build_lighthouse(scenery)
	var near_wharf := group(scenery, "MarketPier", Vector3(-19.0, -0.12, -45.0))
	build_wharf(near_wharf, 13.0, 12.0)
	warehouse(near_wharf, Vector3(-2.0, 0, -1), 6.6, 3.9, 5.0, Color("#f0cf9d"), RED)
	cargo_box(near_wharf, "StackLeft", Vector3(4.6, 0, 2.1), 1.7, 1.3)
	cargo_box(near_wharf, "StackRight", Vector3(3.7, 0, 4.3), 1.45, 1.4)
	bunting(near_wharf, Vector3(-4.92, 2.9, 5.71), Vector3(5.92, 2.9, 5.71), 0.68)

	var cranes := group(scenery, "CraneWharf", Vector3(26.5, -0.07, -116.0))
	build_wharf(cranes, 17.0, 27.0)
	crane(cranes, "LoadingCrane", Vector3(0, 0, 4.0), 1.0)
	crane(cranes, "SecondCrane", Vector3(2.6, 0, -8.7), 0.82)
	for index in range(5):
		container(cranes, Vector3(4.4, floorf(index * 0.5) * 1.35, -7.0 + (index % 2) * 3.5),
			[Color("#588d92"), RED, BRASS, BLUE, Color("#73946d")][index])
	cargo_box(cranes, "CargoStack", Vector3(-6.7, 0, 5.5), 2.7, 1.87)

	var town := group(scenery, "HarborTown", Vector3(31.3, 0.12, -181.0))
	build_wharf(town, 51.0, 15.0)
	for index in range(6):
		var color: Color = [Color("#e5ac84"), Color("#8faeac"), CREAM, Color("#cea982"), Color("#d4a19c"),
			Color("#e8c386")][index]
		warehouse(town, Vector3(-20 + index * 8.0, 0, -0.25), 6.8,
			4.3 + rng.randf_range(-0.4, 1.35), 6.3, color, RED if index % 3 else BLUE)
	for index in range(7):
		var side := -1.0 if index % 2 else 1.0
		var x := side * (8.5 + rng.randf_range(2.2, 7.0))
		var p := 6.0 + index * 23.1
		var center := Vector3(x, -1.63, -p)
		piece(scenery, "Dome", center, Vector3(0.61, 0.46, 0.61), RED)
		piece(scenery, "Round", center + Vector3.UP * 0.02, Vector3(0.58, 0.072, 0.58), CREAM)
		piece(scenery, "Round", center + Vector3.UP * 0.28, Vector3(0.09, 0.22, 0.09), BRASS)


func build_lighthouse(parent: Node3D) -> void:
	var lighthouse := group(parent, "Lighthouse", Vector3(-14.8, 0.15, -181.6))
	for index in range(11):
		var a := TAU * index / 11.0
		var size := rng.randf_range(4.3, 6.8)
		var x := 4.5 * cos(a)
		var z := 4.7 * sin(a)
		piece(lighthouse, "Rock", Vector3(x, -1.32, z), Vector3(size, 3.4, size * 0.82),
			Color("#9d9e91").darkened(rng.randf_range(0.0, 0.2)), Vector3(0, a, 0))
	piece(lighthouse, "Rock", Vector3(0, -0.86, 0), Vector3(10.9, 4.1, 10.9), Color("#859a73"))
	piece(lighthouse, "Round", Vector3(0, 1.02, 0), Vector3(4.5, 0.74, 4.5), Color("#c4b7a2"))
	for index in range(6):
		var diameter := 3.62 - 0.30 * index
		var color := NAVY if index in [1, 3] else CREAM
		piece(lighthouse, "Turned", Vector3(0, 2.23 + index * 1.72, 0),
			Vector3(diameter, 1.75, diameter), color)
	piece(lighthouse, "Round", Vector3(0, 11.68, 0), Vector3(2.85, 0.33, 2.85), NAVY)
	piece(lighthouse, "Round", Vector3(0, 12.52, 0), Vector3(1.91, 1.6, 1.91), Color("#bdd9e8"))
	for index in range(8):
		var a := TAU * index / 8.0
		var offset := Vector3(cos(a), 0, sin(a)) * 0.972
		rod(lighthouse, "MetalRound", offset + Vector3.UP * 11.8, offset + Vector3.UP * 13.38,
			0.082, BRASS)
	piece(lighthouse, "Round", Vector3(0, 13.36, 0), Vector3(2.5, 0.21, 2.5), CREAM)
	piece(lighthouse, "Cone", Vector3(0, 14.1, 0), Vector3(2.65, 1.48, 2.65), NAVY)
	piece(lighthouse, "Dome", Vector3(0, 14.86, 0), Vector3(0.36, 0.5, 0.36), BRASS)
	box(lighthouse, Vector3(0, 2.23, 1.69), Vector3(0.76, 1.61, 0.24), NAVY)


func build_wharf(parent: Node3D, width: float, depth: float) -> void:
	box(parent, Vector3(0, -0.31, 0), Vector3(width, 0.61, depth), Color("#ab8c70"))
	for x in [-0.48 * width, 0.48 * width]:
		for z in [-0.46 * depth, 0.46 * depth]:
			piece(parent, "Round", Vector3(x, -0.91, z), Vector3(0.63, 2.15, 0.63), NAVY)
	for side in [-1.0, 1.0]:
		var z: float = side * depth * 0.5
		box(parent, Vector3(0, -0.25, z), Vector3(width, 0.24, 0.18), CREAM)
		for index in range(6):
			var x := (float(index) / 5.0 - 0.5) * (width - 0.68)
			bollard(parent, Vector3(x, 0, z * 0.96))
			if index in [0, 5]:
				harbor_lamp(parent, Vector3(x, 0, z * 0.93))


func harbor_lamp(parent: Node3D, at: Vector3) -> void:
	rod(parent, "Round", at, at + Vector3.UP * 2.62, 0.095, NAVY)
	piece(parent, "Turned", at + Vector3.UP * 2.51, Vector3(0.36, 0.14, 0.36), NAVY)
	piece(parent, "Round", at + Vector3.UP * 2.72, Vector3(0.23, 0.36, 0.23), CREAM)
	piece(parent, "Cone", at + Vector3.UP * 2.99, Vector3(0.48, 0.24, 0.48), NAVY)


func warehouse(parent: Node3D, at: Vector3, width: float, height: float, depth: float,
		color: Color, roof: Color) -> void:
	box(parent, at + Vector3.UP * (height * 0.5), Vector3(width, height, depth), color)
	box(parent, at + Vector3(0, 0.18, depth * 0.5), Vector3(width, 0.36, 0.18), CREAM)
	for side in [-1.0, 1.0]:
		box(parent, at + Vector3(side * width * 0.244, height + width * 0.067, 0),
			Vector3(width * 0.56, 0.23, depth + 0.51), roof, Vector3(0, 0, side * -0.26))
		rod(parent, "Round", at + Vector3(side * width * 0.49, 0, depth * 0.5),
			at + Vector3(side * width * 0.49, height, depth * 0.5), 0.16, CREAM)
	for x in [-0.29 * width, 0.29 * width]:
		var window := at + Vector3(x, height * 0.66, depth * 0.51)
		box(parent, window, Vector3(0.97, 1.09, 0.14), CREAM)
		box(parent, window + Vector3.BACK * 0.085, Vector3(0.73, 0.87, 0.045), BLUE)
		box(parent, window + Vector3.BACK * 0.113, Vector3(0.061, 0.88, 0.034), CREAM)
	box(parent, at + Vector3(0, 0.98, depth * 0.505), Vector3(1.49, 1.96, 0.16), roof)
	box(parent, at + Vector3(0, 1.99, depth * 0.522), Vector3(1.69, 0.22, 0.17), CREAM)


func crane(parent: Node3D, node_name: String, at: Vector3, size: float) -> void:
	var derrick := group(parent, node_name, at)
	derrick.scale = Vector3.ONE * size
	var frame := Color("#e1ae53")
	for z in [-0.73, 0.73]:
		var base := Vector3(0, 0.6, z)
		var tower := Vector3(0, 9.3, z)
		var tip := Vector3(-10.8, 13.1, z)
		var heel := Vector3(1.56, 6.8, z)
		rod(derrick, "MetalBox", base, tower, 0.31, frame)
		rod(derrick, "MetalBox", Vector3(2.3, 0.6, z), tower, 0.31, frame)
		rod(derrick, "MetalBox", tower, tip, 0.20, BLUE)
		rod(derrick, "MetalBox", heel, tip, 0.21, BLUE)
		for index in range(6):
			var t := float(index) / 6.0
			var next := float(index + 1) / 6.0
			var from := tower.lerp(tip, t) if index % 2 == 0 else heel.lerp(tip, t)
			var to := heel.lerp(tip, next) if index % 2 == 0 else tower.lerp(tip, next)
			rod(derrick, "MetalBox", from, to, 0.1, BLUE)
		for index in range(4):
			var t := float(index) / 4.0
			var next := float(index + 1) / 4.0
			var from := base.lerp(tower, t)
			var to := Vector3(2.3, 0.6, z).lerp(tower, next)
			rod(derrick, "MetalBox", from, to, 0.117, frame)
	box(derrick, Vector3(0.58, 0.33, 0), Vector3(4.6, 0.67, 3.2), NAVY)
	box(derrick, Vector3(-0.09, 7.75, 0.45), Vector3(2.32, 1.8, 1.75), CREAM)
	box(derrick, Vector3(-0.3, 8.01, 1.341), Vector3(1.74, 0.92, 0.093), BLUE)
	rod(derrick, "MetalRound", Vector3(-10.8, 13.1, 0), Vector3(-10.8, 5.9, 0), 0.043, RUBBER)
	rod(derrick, "MetalRound", Vector3(-10.8, 5.94, 0), Vector3(-10.8, 5.61, 0), 0.224, BRASS)
	for x in [-1.1, 1.1]:
		rod(derrick, "Rope", Vector3(-10.8, 5.68, 0), Vector3(-10.8 + x, 4.5, 0), 0.044, RUBBER)
	cargo_box(derrick, "HangingCrate", Vector3(-10.8, 2.93, 0), 2.24, 1.59)


func container(parent: Node3D, at: Vector3, color: Color) -> void:
	box(parent, at + Vector3.UP * 0.67, Vector3(2.8, 1.34, 3.44), color)
	for x in [-1.4, 1.4]:
		for index in range(8):
			var z := (index - 3.5) * 0.42
			box(parent, at + Vector3(x, 0.68, z), Vector3(0.10, 1.19, 0.14), color.darkened(0.12))
	for z in [-1.72, 1.72]:
		box(parent, at + Vector3(0, 1.26, z), Vector3(2.84, 0.12, 0.11), color.lightened(0.23))
