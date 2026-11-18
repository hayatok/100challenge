extends Node3D

# Short-lived painted droplets and strips of starting tape. Drawn in one batch.
const LIMIT := 88
const PALETTE := [Color("#ff6656"), Color("#ffe4a0"), Color("#45ced5"), Color("#fff9e7")]
var batch := MultiMesh.new()
var pieces: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var trail_mesh := ImmediateMesh.new()
var trail_material := StandardMaterial3D.new()
var strokes: Array[Dictionary] = []
var trail_clock := 0.0
var previous_left := Vector3.ZERO
var previous_right := Vector3.ZERO
var trail_action := ""

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = LIMIT
	batch.visible_instance_count = 0
	var display := MultiMeshInstance3D.new()
	display.multimesh = batch
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trail_display := MeshInstance3D.new()
	trail_display.mesh = trail_mesh
	trail_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_display)
	reset()

func reset() -> void:
	rng.seed = 127
	pieces.clear()
	batch.visible_instance_count = 0
	strokes.clear()
	trail_mesh.clear_surfaces()
	trail_clock = 0.0
	release_trail()

func release_trail() -> void:
	trail_action = ""

func trace(left: Vector3, right: Vector3, action: String) -> void:
	if trail_action == action:
		var dive := action == "dive"
		strokes.append({"a": previous_left, "b": left, "c": previous_right, "d": right,
			"time": trail_clock, "life": 0.20 if dive else 0.13,
			"color": Color("#c5ffff") if dive else Color("#ffe4a3"),
			"width": 0.037 if dive else 0.026})
	trail_action = action
	previous_left = left
	previous_right = right

func _paint_strokes() -> void:
	if strokes.is_empty():
		if trail_mesh.get_surface_count() > 0:
			trail_mesh.clear_surfaces()
		return
	trail_mesh.clear_surfaces()
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, trail_material)
	for stroke in strokes:
		var strength := clampf(1.0 - (trail_clock - stroke.time) / stroke.life, 0.0, 1.0)
		var width: Vector3 = Vector3(1.0, 0.25, 0.0) * stroke.width * strength
		var tint: Color = stroke.color
		tint.a = strength * 0.69
		_stroke_segment(stroke.a, stroke.b, width, tint)
		_stroke_segment(stroke.c, stroke.d, width, tint)
	trail_mesh.surface_end()

func _stroke_segment(start: Vector3, end: Vector3, width: Vector3, tint: Color) -> void:
	trail_mesh.surface_set_color(tint)
	trail_mesh.surface_add_vertex(start - width)
	trail_mesh.surface_add_vertex(start + width)
	trail_mesh.surface_add_vertex(end - width)
	trail_mesh.surface_add_vertex(start + width)
	trail_mesh.surface_add_vertex(end + width)
	trail_mesh.surface_add_vertex(end - width)

func burst(origin: Vector3, event: String) -> void:
	var amount := 7
	if event == "splash":
		amount = 14
	elif event == "finish":
		amount = 48
	for i in amount:
		if pieces.size() >= LIMIT:
			break
		var axis := rng.randf_range(0,TAU)
		var radial := rng.randf_range(0.4,1.7)
		var v := Vector3(cos(axis)*radial, rng.randf_range(0.7,1.8), sin(axis)*radial)
		var location := origin
		var life := rng.randf_range(0.19,0.34)
		var dimensions := Vector3(0.07,0.06,0.045)
		var color := Color("#f8e5c5")
		if event == "finish":
			var side := -1.0 if i % 2 == 0 else 1.0
			location += Vector3(side * rng.randf_range(0.82,1.55), rng.randf_range(0.55,1.15), rng.randf_range(0.35,1.0))
			v = Vector3(-side * rng.randf_range(0.20,0.82), rng.randf_range(2.1,3.5), rng.randf_range(-0.18,0.35))
			life += 1.15
			color = PALETTE[i%4]
			dimensions = Vector3(0.058,0.012,0.11)
		elif event == "stumble":
			v = Vector3(cos(axis)*1.45, rng.randf_range(0.7,1.6), sin(axis)*0.75)
			dimensions = Vector3(0.035,0.10,0.025)
			color = Color("#ffd260")
		elif event == "splash":
			v.y += 1.4
			life += 0.28
			color = Color("#a7f6ff") if i%2 else Color.WHITE
			dimensions *= 1.7
		elif event == "boost" or event == "slide":
			location.x += rng.randf_range(-0.24, 0.24)
			v = Vector3(cos(axis)*0.7, rng.randf_range(0.35, 0.9), rng.randf_range(1.7, 3.1))
			dimensions = Vector3(0.04, 0.022, 0.26 if event == "boost" else 0.11)
			color = Color("#fff4bc") if event == "boost" else Color("#e9cc9b")
		pieces.append({"pos":location,"v":v,"age":0.0,"life":life,"scale":dimensions,"color":color,"spin":axis})

func advance(dt: float) -> void:
	trail_clock += dt
	while not strokes.is_empty() and trail_clock - strokes[0].time >= strokes[0].life:
		strokes.pop_front()
	_paint_strokes()
	for i in range(pieces.size()-1,-1,-1):
		var item := pieces[i]
		item.age += dt
		if item.age >= item.life:
			pieces.remove_at(i)
			continue
		item.pos += item.v * dt
		item.v.y -= 6.3*dt
	for i in pieces.size():
		var item := pieces[i]
		var shrink := clampf((float(item.life)-float(item.age))*8.0,0.0,1.0)
		var basis := Basis.from_euler(Vector3(item.age*6.0,item.spin,item.spin+item.age*5.0))
		batch.set_instance_transform(i, Transform3D(basis.scaled_local(item.scale*shrink),item.pos))
		batch.set_instance_color(i,item.color)
	batch.visible_instance_count = pieces.size()
