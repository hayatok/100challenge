extends SceneTree
## Rebuild the editor scene after changing YardLayout or this scaffold.
## godot --headless --path game --script res://course/BuildYard.gd

const Layout := preload("res://race/YardLayout.gd")
const SCENE_PATH := "res://course/Yard.tscn"
const CREAM := Color("#fff0c8")
const YELLOW := Color("#ffc164")
const OCHRE := Color("#d08b41")
const RED := Color("#bd5754")
const NAVY := Color("#273547")
const STEEL := Color("#586779")
const AQUA := Color("#8cd9c9")
const TEAL := Color("#438887")
const WOOD := Color("#b17d59")
const CONCRETE := Color("#7a8491")
const SEA_Y := -1.75

var course := Node3D.new()
var batches: Dictionary[Node3D, Array] = {}
var solids: Dictionary[Color, BoxMesh] = {}
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	rng.seed = 181118
	course.name = "SunsetContainerYard"
	course.set_script(preload("res://course/Yard.gd"))
	environment()
	raceway()
	scenery()
	bake_batches()
	var scene := PackedScene.new()
	var error := scene.pack(course)
	if error == OK:
		error = ResourceSaver.save(scene, SCENE_PATH)
	scene = null
	course.free()
	solids.clear()
	batches.clear()
	quit(int(error))


func add(parent: Node, child: Node, node_name: String) -> void:
	child.name = node_name
	parent.add_child(child)
	child.owner = course


func group(parent: Node3D, node_name: String, at := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.position = at
	add(parent, node, node_name)
	return node


func point(x: float, y: float, progress: float) -> Vector3:
	return Vector3(x, y, -progress)


func wall_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.79
	return material


func mesh_node(parent: Node3D, node_name: String, at: Vector3, mesh: Mesh,
		material: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.position = at
	node.mesh = mesh
	node.material_override = material
	add(parent, node, node_name)
	return node


func solid(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		color: Color) -> MeshInstance3D:
	if not solids.has(color):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = wall_material(color)
		solids[color] = mesh
	var node := mesh_node(parent, node_name, at, solids[color])
	node.scale = size
	return node


func detail(parent: Node3D, at: Vector3, size: Vector3, color: Color,
		basis := Basis.IDENTITY) -> void:
	if not batches.has(parent):
		batches[parent] = []
	batches[parent].append([Transform3D(basis.scaled_local(size), at), color])


func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var direction := b - a
	detail(parent, (a + b) * 0.5, Vector3(thickness, direction.length(), thickness), color,
		Basis(Quaternion(Vector3.UP, direction.normalized())))


func bake_batches() -> void:
	var painted := wall_material(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	painted.vertex_color_is_srgb = true
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	box_mesh.material = painted
	var unit_bounds := AABB(Vector3.ONE * -0.5, Vector3.ONE)
	for parent: Node3D in batches:
		var parts: Array = batches[parent]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = box_mesh
		multi.instance_count = parts.size()
		# Set the buffer directly so it also serializes with the headless renderer.
		var buffer := PackedFloat32Array()
		var bounds: AABB = parts[0][0] * unit_bounds
		for part: Array in parts:
			var transform: Transform3D = part[0]
			var color: Color = part[1]
			for row in 3:
				buffer.append_array(PackedFloat32Array([
					transform.basis.x[row], transform.basis.y[row],
					transform.basis.z[row], transform.origin[row]
				]))
			buffer.append_array(PackedFloat32Array([color.r, color.g, color.b, color.a]))
			bounds = bounds.merge(transform * unit_bounds)
		multi.buffer = buffer
		multi.custom_aabb = bounds
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		add(parent, node, "Details")


func environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://course/YardSky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var light := Environment.new()
	light.background_mode = Environment.BG_SKY
	light.sky = sky
	light.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	light.ambient_light_color = Color("#c7dcff")
	light.ambient_light_energy = 0.33
	var world := WorldEnvironment.new()
	world.environment = light
	add(course, world, "SunsetSky")

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 157, 0)
	sun.light_color = Color("#ffd5a8")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.shadow_bias = 0.11
	sun.shadow_normal_bias = 1.5
	sun.shadow_opacity = 0.73
	sun.directional_shadow_max_distance = 42.0
	sun.directional_shadow_blend_splits = true
	add(course, sun, "LowSun")

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, -10.0, 0.0)
	fill.light_color = Color("#afccff")
	fill.light_energy = 0.19
	add(course, fill, "Skylight")

	var ocean := PlaneMesh.new()
	ocean.size = Vector2(890, 890)
	var water := ShaderMaterial.new()
	water.shader = preload("res://course/YardWater.gdshader")
	water.resource_local_to_scene = true
	var roof: Dictionary = Layout.ROOFS[1]
	water.set_shader_parameter(&"roof_center", Vector2(Layout.roof_x(1, 0.0), roof.p))
	water.set_shader_parameter(&"roof_half_extent", Vector2(roof.width, roof.length) * 0.5)
	mesh_node(course, "Sea", point(0, SEA_Y, 95), ocean, water).cast_shadow = 		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func deck_material(color: Color, timber := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://course/YardDeck.gdshader")
	material.set_shader_parameter(&"base_color", color)
	material.set_shader_parameter(&"timber", timber)
	return material


func straight_deck(node_name: String, from: float, to: float, left: float,
		right: float, color: Color) -> Node3D:
	var width := right - left
	var length := to - from
	var deck := group(course, node_name, point((right + left) * 0.5, 0, (from + to) * 0.5))
	var bed := BoxMesh.new()
	bed.size = Vector3(width, 0.52, length)
	mesh_node(deck, "RunningSurface", Vector3.DOWN * 0.26, bed, deck_material(color))
	for side: float in [-1.0, 1.0]:
		var edge := side * (width * 0.5 - 0.09)
		for index in maxi(1, floori(length / 2.3)):
			var z := length * 0.5 - (index + 0.6) * 2.3
			detail(deck, Vector3(edge, 0.011, z), Vector3(0.12, 0.014, 1.40), CREAM)
		for p in range(1, floori(length), 4):
			var z := length * 0.5 - p
			detail(deck, Vector3(edge, -0.39, z), Vector3(0.3, 0.24, 1.35), NAVY)
			detail(deck, Vector3(edge - side * 0.39, -1.20, z), Vector3(0.46, 1.55, 0.47), STEEL)
	return deck


func raceway() -> void:
	var edge := Layout.DECK_EDGE
	straight_deck("EntryApron", -7.0, 39.0, -edge, edge, CONCRETE)
	straight_deck("PracticeCatch", 39.0, 77.0, -edge, edge, CONCRETE.lightened(0.06))
	straight_deck("ForkApproach", 77.0, Layout.SPLIT_START, -edge, edge, CONCRETE)
	straight_deck("InnerTakeoff", Layout.SPLIT_START, Layout.GAP_START,
		Layout.INNER_LEFT, Layout.INNER_RIGHT, CONCRETE.darkened(0.08))
	straight_deck("InnerLanding", Layout.GAP_END, Layout.SPLIT_END,
		Layout.INNER_LEFT, Layout.INNER_RIGHT, CONCRETE.darkened(0.08))
	straight_deck("MergedApron", Layout.SPLIT_END, Layout.FINISH + 8.0, -edge, edge, CONCRETE)
	outer_pier()

	belt(0, "EntryBelt")
	belt(1, "InnerBelt")
	crane(0, "PracticeCrane")
	crane(1, "ChannelCrane")
	gate("StartGate", 0.0, "START", TEAL)
	gate("FinishGate", Layout.FINISH, "FINISH", RED)

	var wayfinding := group(course, "ForkSigns", point(0, 0, Layout.SPLIT_START))
	floor_arrow(wayfinding, Vector3(-2.47, 0.013, 3.3), 0.75, YELLOW, 0.23)
	floor_arrow(wayfinding, Vector3(2.54, 0.013, 3.3), 0.75, AQUA, -0.27)
	floor_arrow(wayfinding, Vector3(-2.64, 0.013, 1.08), 0.68, YELLOW)
	floor_arrow(wayfinding, Vector3(2.92, 0.013, 1.08), 0.68, AQUA, -0.3)
	marker_post(wayfinding, Vector3(-4.45, 0, 0.85), YELLOW)
	marker_post(wayfinding, Vector3(4.49, 0, 0.85), AQUA)

	var inner_center := (Layout.INNER_LEFT + Layout.INNER_RIGHT) * 0.5
	var inner_width := Layout.INNER_RIGHT - Layout.INNER_LEFT
	var takeoff := group(course, "ChannelTakeoff", point(inner_center, 0, Layout.GAP_START))
	striped_edge(takeoff, Vector3(0, 0.025, 0.31), inner_width)
	for z: float in [2.4, 1.19]:
		floor_arrow(takeoff, Vector3(0, 0.016, z), 0.8, YELLOW)
	for x: float in [-1.97, 1.97]:
		marker_post(takeoff, Vector3(x, 0, 0.38), YELLOW)

	var landing := group(course, "ChannelLanding", point(inner_center, 0, Layout.GAP_END))
	striped_edge(landing, Vector3(0, 0.025, -0.32), inner_width)
	for x: float in [-1.97, 1.97]:
		marker_post(landing, Vector3(x, 0, -0.53), YELLOW)
	for p: float in Layout.CHECKPOINTS:
		if p == 0.0:
			continue
		var checkpoint := group(course, "Checkpoint%d" % int(p), point(0, 0, p))
		for x: float in [-4.43, 4.43]:
			marker_post(checkpoint, Vector3(x, 0, 0), CREAM)


func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex: Vector3 in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)


func outer_pier() -> void:
	var midpoint := (Layout.SPLIT_START + Layout.SPLIT_END) * 0.5
	var pier := group(course, "OuterPier", point(0, 0, midpoint))
	var half_width := Layout.OUTER_WIDTH * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := ceili((Layout.SPLIT_END - Layout.SPLIT_START) / 0.5)
	for index in count:
		var p := lerpf(Layout.SPLIT_START, Layout.SPLIT_END, float(index) / count)
		var next := lerpf(Layout.SPLIT_START, Layout.SPLIT_END, float(index + 1) / count)
		var x := Layout.outer_x(p)
		var nx := Layout.outer_x(next)
		var a := point(x - half_width, 0, p - midpoint)
		var b := point(x + half_width, 0, p - midpoint)
		var c := point(nx + half_width, 0, next - midpoint)
		var d := point(nx - half_width, 0, next - midpoint)
		var down := Vector3.DOWN * 0.36
		quad(tool, a, d, c, b)
		quad(tool, b, c, c + down, b + down)
		quad(tool, d, a, a + down, d + down)
		if index % 4 == 0:
			for side: float in [-1.0, 1.0]:
				var rail_x := x + side * (half_width - 0.065)
				detail(pier, point(rail_x, 0.16, p - midpoint), Vector3(0.10, 0.37, 0.12), AQUA.darkened(0.13))
				detail(pier, point(rail_x - side * 0.22, -1.11, p - midpoint), Vector3(0.37, 1.70, 0.36), NAVY)
		if index % 16 == 4:
			floor_arrow(pier, point(x, 0.013, p - midpoint), 0.70, AQUA, -atan(Layout.outer_slope(p)))
		for side: float in [-1.0, 1.0]:
			var offset := side * (half_width - 0.065)
			beam(pier, point(x + offset, 0.32, p - midpoint),
				point(nx + offset, 0.32, next - midpoint), 0.065, AQUA.darkened(0.19))
	tool.index()
	mesh_node(pier, "CurvedRunningSurface", Vector3.ZERO, tool.commit(), deck_material(WOOD, true))


func belt(index: int, node_name: String) -> void:
	var data: Dictionary = Layout.BELTS[index]
	var speed: float = data.speed
	var size := Vector2(data.width, data.length)
	var conveyor := group(course, node_name, point(data.x, 0, data.p))
	var plane := PlaneMesh.new()
	plane.size = size
	var rubber := ShaderMaterial.new()
	rubber.shader = preload("res://course/YardBelt.gdshader")
	rubber.resource_local_to_scene = true
	rubber.set_shader_parameter(&"speed_mps", speed)
	rubber.set_shader_parameter(&"dimensions", size)
	mesh_node(conveyor, "Tread", Vector3.UP * 0.012, plane, rubber).cast_shadow = 		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		var edge := side * (size.y * 0.5 + 0.09)
		striped_edge(conveyor, Vector3(0, 0.019, edge), size.x + 0.18)
		var end := side * (size.x * 0.5 + 0.06)
		detail(conveyor, Vector3(end, 0.019, 0), Vector3(0.11, 0.027, size.y), AQUA)
		for offset: float in [-1.0, 1.0]:
			detail(conveyor, Vector3(end + side * 0.06, 0.032, offset * (size.y * 0.5 - 0.23)),
				Vector3(0.14, 0.053, 0.30), STEEL)


func floor_arrow(parent: Node3D, center: Vector3, size: float, color: Color, angle := 0.0) -> void:
	for side: float in [-1.0, 1.0]:
		var a := Vector3(0, 0, -0.50) * size
		var b := Vector3(side * 0.39, 0, 0.04) * size
		a = center + a.rotated(Vector3.UP, angle)
		b = center + b.rotated(Vector3.UP, angle)
		var span := b - a
		detail(parent, (a + b) * 0.5, Vector3(0.13 * size, 0.013, span.length()),
			color, Basis(Vector3.UP, atan2(span.x, span.z)))
	var stem := Vector3(0, 0, 0.10 * size).rotated(Vector3.UP, angle)
	detail(parent, center + stem, Vector3(0.13 * size, 0.013, 1.10 * size),
		color, Basis(Vector3.UP, angle))


func striped_edge(parent: Node3D, at: Vector3, width: float) -> void:
	var count := maxi(2, ceili(width / 0.29))
	for index in count:
		var cell := width / count
		var x := -width * 0.5 + (index + 0.5) * cell
		var color := YELLOW if index % 2 == 0 else NAVY
		detail(parent, at + Vector3.RIGHT * x, Vector3(cell, 0.024, 0.14), color)


func marker_post(parent: Node3D, at: Vector3, color: Color) -> void:
	detail(parent, at + Vector3.UP * 0.08, Vector3(0.30, 0.16, 0.29), NAVY)
	detail(parent, at + Vector3.UP * 0.29, Vector3(0.14, 0.55, 0.15), STEEL)
	detail(parent, at + Vector3.UP * 0.56, Vector3(0.24, 0.18, 0.22), color)


func gate(node_name: String, p: float, word: String, color: Color) -> void:
	var gate_node := group(course, node_name, point(0, 0, p))
	# The chase camera passes underneath the starting banner when the field sets off.
	var header_y := 5.85 if word == "START" else 3.69
	var post_height := header_y + 0.11
	for side: float in [-1, 1]:
		var x := side * (Layout.DECK_EDGE + 0.12)
		solid(gate_node, "PostLeft" if side < 0 else "PostRight",
			Vector3(x, post_height * 0.5, -0.10), Vector3(0.35, post_height, 0.42), color)
		detail(gate_node, Vector3(x, 0.19, 0), Vector3(0.69, 0.39, 0.69), NAVY)
		detail(gate_node, Vector3(x, header_y + 0.18, 0), Vector3(0.47, 0.20, 0.42), YELLOW)
		for index in 4:
			detail(gate_node, Vector3(x, 0.57 + 0.18 * index, 0.128),
				Vector3(0.31, 0.07, 0.052), CREAM)
	solid(gate_node, "Header", Vector3(0, header_y, -0.10), Vector3(9.98, 0.68, 0.37), color)
	solid(gate_node, "Nameplate", Vector3(0, header_y, 0.115), Vector3(3.3, 0.58, 0.12), NAVY)
	label_sign(gate_node, "RaceMarker", word, Vector3(0, header_y, 0.193), 0.49)
	for row in 2:
		for column in 24:
			var width := Layout.DECK_EDGE * 2.0 / 24.0
			var x := (column + 0.5) * width - Layout.DECK_EDGE
			detail(gate_node, Vector3(x, 0.012, (row - 0.5) * 0.25),
				Vector3(width, 0.013, 0.25), CREAM if (row + column) % 2 == 0 else NAVY)


func label_sign(parent: Node3D, node_name: String, word: String, at: Vector3, height: float) -> void:
	var label := Label3D.new()
	label.position = at
	label.text = word
	label.modulate = CREAM
	label.font_size = 96
	label.pixel_size = height / 96.0
	label.outline_size = 0
	add(parent, label, node_name)


func crane(index: int, node_name: String) -> void:
	var data: Dictionary = Layout.ROOFS[index]
	var width: float = data.width
	var depth: float = data.length
	var roof_y: float = data.height
	var practice := index == 0
	var left := -6.2 if practice else -7.35
	var right := 6.1 if practice else 3.2
	var track_y := 6.1 if practice else 7.35
	var gantry := group(course, node_name, point(0, 0, data.p))
	var frame := group(gantry, "FixedRail")
	for x: float in [left, right]:
		var pier := group(frame, "WestSupport" if x < 0 else "EastSupport", Vector3(x, 0, 0))
		solid(pier, "Caisson", Vector3.DOWN * 0.94, Vector3(1.88, 1.94, 4.05), STEEL)
		for z: float in [-1.37, 1.37]:
			detail(pier, Vector3(0, 0.25, z), Vector3(0.70, 0.50, 0.66), NAVY)
			beam(pier, Vector3(0, 0.30, z), Vector3(0, track_y, z * 0.52), 0.39, OCHRE)
			detail(pier, Vector3(0, 1.02, z * 0.90), Vector3(0.405, 0.27, 0.42), YELLOW)
		beam(pier, Vector3(0, 0.57, 1.36), Vector3(0, track_y - 1.07, -0.88), 0.16, OCHRE)
		beam(pier, Vector3(0, 0.57, -1.36), Vector3(0, track_y - 1.07, 0.88), 0.16, OCHRE)
		solid(pier, "UpperBearing", Vector3(0, track_y - 0.04, 0), Vector3(0.89, 0.32, 1.79), NAVY)
	var track_length := right - left + 0.58
	for z: float in [-0.72, 0.72]:
		solid(frame, "FrontTrack" if z > 0 else "RearTrack",
			Vector3((left + right) * 0.5, track_y, z), Vector3(track_length, 0.22, 0.21), NAVY)
		detail(frame, Vector3((left + right) * 0.5, track_y + 0.83, z),
			Vector3(track_length, 0.17, 0.20), OCHRE)
		for bar in 12:
			var step := (right - left) / 12.0
			var a := Vector3(left + step * bar, track_y + 0.13, z)
			var b := Vector3(a.x + step, track_y + 0.81, z)
			beam(frame, a, b, 0.09, OCHRE)
			beam(frame, Vector3(a.x, track_y + 0.81, z), Vector3(b.x, track_y + 0.13, z), 0.065, OCHRE)
		for direction: float in [-1.0, 1.0]:
			var stop: float = data.center + direction * float(data.amplitude)
			detail(frame, Vector3(stop, track_y - 0.20, z), Vector3(0.14, 0.39, 0.26), YELLOW)
			for i in 3:
				detail(frame, Vector3(stop + (i - 1) * 0.17, track_y + 0.14, z),
					Vector3(0.079, 0.14, 0.26), CREAM)
	var cabin_x := right - 0.58
	solid(frame, "OperatorCabin", Vector3(cabin_x, track_y - 0.62, 0.73),
		Vector3(1.45, 1.12, 1.22), CREAM)
	detail(frame, Vector3(cabin_x, track_y - 0.49, 1.35), Vector3(1.24, 0.47, 0.07), TEAL)
	detail(frame, Vector3(cabin_x, track_y - 0.49, 1.40), Vector3(0.063, 0.51, 0.025), CREAM)

	var moving := group(gantry, "MovingLoad", Vector3(Layout.roof_x(index, 0.0), 0, 0))
	var trolley := group(moving, "Trolley", Vector3.UP * (track_y - 0.16))
	solid(trolley, "Crosshead", Vector3.ZERO, Vector3(1.14, 0.29, 1.69), RED)
	for x: float in [-0.48, 0.48]:
		for z: float in [-0.71, 0.71]:
			detail(trolley, Vector3(x, 0.10, z), Vector3(0.29, 0.32, 0.29), NAVY)
		detail(trolley, Vector3(x, -0.15, 0.54), Vector3(0.21, 0.13, 0.31), YELLOW)
	var container_height := roof_y - 0.17 if practice else 1.30
	var roof := group(moving, "Roof", Vector3.UP * roof_y)
	solid(roof, "RunningSurface", Vector3.DOWN * 0.055, Vector3(width, 0.11, depth), TEAL)
	solid(roof, "SuspendedBody", Vector3.DOWN * (container_height * 0.5 + 0.11),
		Vector3(width - 0.11, container_height, depth - 0.11), NAVY if practice else RED)
	for side: float in [-1.0, 1.0]:
		var x := side * (width * 0.5 - 0.047)
		detail(roof, Vector3(x, -0.055, 0), Vector3(0.094, 0.111, depth), AQUA)
		for rib in 18:
			var z := ((rib + 0.5) / 18.0 - 0.5) * depth
			detail(roof, Vector3(x, -container_height * 0.5 - 0.1, z),
				Vector3(0.081, container_height - 0.06, 0.16), TEAL.darkened(0.10) if practice else RED.darkened(0.18))
		for z: float in [-depth * 0.5 + 0.10, depth * 0.5 - 0.10]:
			var foot := Vector3(side * (width * 0.5 + 0.025), roof_y + 0.03, z)
			beam(moving, foot, Vector3(side * 0.23, track_y - 0.30, z * 0.094), 0.067, NAVY)
			detail(roof, Vector3(x, -0.101, z), Vector3(0.16, 0.25, 0.25), YELLOW)
	for z: float in [-depth * 0.5 + 0.19, depth * 0.5 - 0.19]:
		striped_edge(roof, Vector3(0, 0.014, z), width)
	for z: float in [-2.58, 0.0, 2.58]:
		floor_arrow(roof, Vector3(0, 0.013, z), 0.68, CREAM)


func scenery() -> void:
	var west := group(course, "WestFreightApron", point(-10.6, 0, 17))
	var east := group(course, "EastFreightApron", point(11.4, 0, 29))
	var sidings := group(course, "MaintenanceSiding", point(-11.8, 0, 72))
	for apron: Node3D in [west, east, sidings]:
		var apron_length := 37.0 if apron != sidings else 23.0
		solid(apron, "Quay", Vector3.DOWN * 0.55, Vector3(9.5, 1.0, apron_length),
			Color("#756f78"))
		detail(apron, Vector3(0, -0.19, apron_length * 0.5 - 0.025),
			Vector3(9.49, 0.12, 0.06), CONCRETE.lightened(0.14))
		for z in range(-floori(apron_length * 0.5) + 2, floori(apron_length * 0.5), 4):
			for x: float in [-4.22, 4.22]:
				detail(apron, Vector3(x, -1.42, z), Vector3(0.54, 1.7, 0.64), NAVY)
	for z: float in [-10.1, -2.3, 5.5, 13.2]:
		freight(west, Vector3(0.63, -0.04, z), [TEAL, RED, OCHRE, STEEL][int(absf(z)) % 4])
		freight(west, Vector3(-2.4, -0.04, z - 1.24), Color("#586d85"))
	freight(west, Vector3(-2.4, 2.55, 4.26), RED.darkened(0.12))
	freight(west, Vector3(0.63, 2.55, 13.2), Color("#bd734f"))
	for z: float in [-12.9, -5.1, 2.7, 10.5]:
		freight(east, Vector3(-1.15, -0.04, z), [STEEL, RED, TEAL, OCHRE][int(absf(z)) % 4])
		freight(east, Vector3(1.73, -0.04, z - 0.24), Color("#867587"))
	freight(east, Vector3(1.73, 2.55, -5.34), Color("#617d7d"))
	freight(east, Vector3(-1.15, 2.55, 2.7), TEAL)
	freight(sidings, Vector3(0.5, -0.04, -4.8), Color("#647888"))
	freight(sidings, Vector3(-2.7, -0.04, 2.55), OCHRE.darkened(0.13))

	for i in 3:
		var harbor_lights := group(course, "QuayLights%d" % (i + 1), point(0, 0, [15.0, 45.0, 67.0][i]))
		for x: float in [-6.62, 7.4]:
			detail(harbor_lights, Vector3(x, 1.72, 0), Vector3(0.13, 3.44, 0.13), STEEL)
			detail(harbor_lights, Vector3(x, 3.47, 0.12), Vector3(0.57, 0.12, 0.48), NAVY)
			detail(harbor_lights, Vector3(x, 3.42, 0.18), Vector3(0.41, 0.084, 0.40), CREAM)

	var freighter := group(course, "MooredFreighter", point(27.5, -1.0, 77))
	detail(freighter, Vector3(0, 0.0, 0), Vector3(12.0, 3.5, 36), NAVY)
	detail(freighter, Vector3(0, -0.84, 0), Vector3(12.25, 0.64, 36.1), RED.darkened(0.25))
	detail(freighter, Vector3(0, 0.52, 18.0), Vector3(8.9, 2.41, 7.42), NAVY,
		Basis(Vector3.UP, 0.79))
	detail(freighter, Vector3(0, 1.67, 0), Vector3(12.16, 0.16, 36.0), Color("#ad9094"))
	detail(freighter, Vector3(0, 3.54, -13.25), Vector3(8.65, 3.8, 6.02), Color("#ae9b9c"))
	detail(freighter, Vector3(0, 5.9, -13.6), Vector3(9.73, 1.7, 4.18), Color("#ae9b9c"))
	for x in range(-4, 5):
		detail(freighter, Vector3(x, 6.12, -11.48), Vector3(0.79, 0.46, 0.11), NAVY)
	detail(freighter, Vector3(2.7, 7.65, -14.3), Vector3(1.38, 2.62, 1.42), STEEL)
	detail(freighter, Vector3(2.7, 8.47, -14.3), Vector3(1.42, 0.37, 1.47), OCHRE)
	for z: float in [-5.7, 1.6, 8.9]:
		for x: float in [-3.17, 0.0, 3.17]:
			freight(freighter, Vector3(x, 1.76, z), [Color("#817480"), Color("#6c7a89"), Color("#9d7d72")][rng.randi_range(0, 2)])

	var docks := group(course, "DistantPort", point(0, -0.6, 206))
	detail(docks, Vector3(15, -0.22, -3), Vector3(127.0, 1.67, 21), Color("#766e86"))
	for index in 19:
		var x := -56.0 + index * 7.35
		var height := rng.randf_range(2.4, 8.1)
		var tint := Color("#826e85").lerp(Color("#6f748b"), rng.randf())
		detail(docks, Vector3(x, height * 0.5, rng.randf_range(-15, -1)),
			Vector3(rng.randf_range(5.2, 9.2), height, rng.randf_range(5.6, 15.8)), tint)
		if index % 3 == 0:
			detail(docks, Vector3(x, height + 0.69, -5.0), Vector3(2.23, 1.54, 4.6), tint.darkened(0.04))
	for position: Vector2 in [Vector2(-37, 11), Vector2(30, 9), Vector2(48, 14), Vector2(65, 5)]:
		skyline_crane(docks, Vector3(position.x, 0, position.y))
	for i in 7:
		var offshore := group(course, "ChannelBuoy%d" % (i + 1),
			point(-9.1 if i % 2 == 0 else 16.5, SEA_Y, 88 + i * 10.5))
		detail(offshore, Vector3.UP * 0.12, Vector3(0.68, 0.45, 0.68), RED)
		detail(offshore, Vector3.UP * 0.47, Vector3(0.39, 0.28, 0.39), CREAM)
		detail(offshore, Vector3.UP * 0.75, Vector3(0.081, 0.42, 0.08), RED)


func freight(parent: Node3D, at: Vector3, color: Color) -> void:
	var width := 2.62
	var length := 6.7
	var height := 2.59
	detail(parent, at + Vector3.UP * (height * 0.5), Vector3(width, height, length), color)
	for x: float in [-width * 0.5, width * 0.5]:
		for i in 12:
			detail(parent, at + Vector3(x, height * 0.50, ((i + 0.5) / 12.0 - 0.5) * length),
				Vector3(0.13, height - 0.28, 0.15), color.darkened(0.13))
		for y: float in [0.11, height - 0.11]:
			detail(parent, at + Vector3(x, y, 0), Vector3(0.121, 0.17, length), color.lightened(0.19))
	for x: float in [-0.88, -0.35, 0.35, 0.88]:
		detail(parent, at + Vector3(x, height * 0.5, length * 0.5 + 0.018),
			Vector3(0.063, height * 0.83, 0.081), color.lightened(0.24))
		detail(parent, at + Vector3(x - 0.08, height * 0.36, length * 0.5 + 0.05),
			Vector3(0.22, 0.08, 0.07), NAVY)
	for x: float in [-width * 0.5 + 0.07, width * 0.5 - 0.07]:
		detail(parent, at + Vector3(x, height * 0.50, length * 0.5 + 0.013),
			Vector3(0.20, height, 0.058), color.lightened(0.19))


func skyline_crane(parent: Node3D, at: Vector3) -> void:
	var frame := Color("#675d7b")
	var mast := at + Vector3(0, 12, 0)
	var tip := at + Vector3(-12, 15, 4)
	beam(parent, at + Vector3(-1.6, 0, 0), mast, 0.47, frame)
	beam(parent, at + Vector3(1.6, 0, 0), mast, 0.47, frame)
	beam(parent, mast, tip, 0.33, frame)
	beam(parent, at + Vector3(1.7, 9.5, -1.0), tip, 0.35, frame)
	beam(parent, tip, tip + Vector3.DOWN * 6.8, 0.076, frame)
	detail(parent, mast + Vector3(-0.3, -1.4, 0.2), Vector3(1.6, 1.3, 1.21), frame)
