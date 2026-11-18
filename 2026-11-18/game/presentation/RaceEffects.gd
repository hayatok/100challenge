extends Node3D

# Short-lived painted droplets and strips of starting tape. Drawn in one batch.
const LIMIT := 88
const PALETTE := [Color("#ff6656"), Color("#ffe4a0"), Color("#45ced5"), Color("#fff9e7")]
var batch := MultiMesh.new()
var pieces: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

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
	reset()

func reset() -> void:
	rng.seed = 127
	pieces.clear()
	batch.visible_instance_count = 0

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
			location += Vector3(rng.randf_range(-1.7,1.7), rng.randf_range(1.9,3.4), rng.randf_range(-0.6,1.0))
			v.y += 0.3
			life += 1.0
			color = PALETTE[i%4]
			dimensions = Vector3(0.09,0.015,0.15)
		elif event == "splash":
			v.y += 1.4
			life += 0.28
			color = Color("#a7f6ff") if i%2 else Color.WHITE
			dimensions *= 1.7
		pieces.append({"pos":location,"v":v,"age":0.0,"life":life,"scale":dimensions,"color":color,"spin":axis})

func advance(dt: float) -> void:
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
