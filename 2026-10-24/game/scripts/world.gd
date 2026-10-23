extends Node3D

signal core_hit
signal core_destroyed

const COLOSSUS = preload("res://scripts/colossus.gd")
var stone: ShaderMaterial
var shadow_stone: StandardMaterial3D
var gold: StandardMaterial3D
var _bevel_mesh: ArrayMesh

func _ready() -> void:
	stone = ShaderMaterial.new()
	stone.shader = preload("res://shaders/stone.gdshader")
	shadow_stone = material(Color("435875"), 0.94)
	gold = material(Color("ecc56b"), 0.3, 0.65)
	gold.emission_enabled = true
	gold.emission = Color("b28231")
	gold.emission_energy_multiplier = 0.35
	_bevel_mesh = _make_bevel()
	_environment()
	# Broad safe introduction, a short broken crossing, then an open combat court.
	_platform(Vector3(0,-0.55,7), Vector3(10,1.1,10))
	_platform(Vector3(0,0.05,-5.5), Vector3(6,1.2,9))
	_platform(Vector3(0,0.35,-18), Vector3(16,1.3,15))
	_platform(Vector3(4,1.35,-26), Vector3(6,1.3,4))
	_floor_art()
	_anchor(Vector3(0,2.7,-2))
	_anchor(Vector3(0,3.0,-10))
	_anchor(Vector3(5,3.5,-22))
	# Camera clearance wall on the court's west side, deliberately avoid enclosing the view.
	_platform(Vector3(-7.4,2.1,-16), Vector3(0.9,3.6,7))
	for side in [-1.0, 1.0]:
		for z in [8.0, 3.0, -4.0, -9.0]:
			_column(Vector3(side * (4.3 if z > 0 else 2.5),0,z), 2.5 if z > 0 else 1.9)
	# A broken halo frames the shoulder and makes the route legible from spawn.
	_ring(Vector3(0,7,-34), 11.5, -0.22, 2.95, 21, stone, true)
	_ring(Vector3(-13,6,-29), 7.5, 0.1, 2.4, 13, shadow_stone, false)
	# Authored distant ruins remain below the navigable surfaces.
	for item in [Vector3(-23,-5,-15),Vector3(26,-8,-36),Vector3(-32,-11,-54),Vector3(17,-4,14)]:
		_platform(item,Vector3(10,2,8),false)
		_column(item + Vector3(-3,1,0),7,false)
		_column(item + Vector3(3,1,0),4,false)
	var giant: Node3D = COLOSSUS.new()
	giant.position = Vector3(1,0,-31)
	add_child(giant)
	giant.core_hit.connect(func(): core_hit.emit())
	giant.core_destroyed.connect(func(): core_destroyed.emit())

func get_spawn() -> Vector3:
	return Vector3(0,0.15,7)

func get_enemy_spawns() -> Array[Vector3]:
	return [Vector3(-2,1.1,-16),Vector3(3,1.1,-20),Vector3(-3,1.1,-22)]

func get_checkpoint(at: Vector3) -> Vector3:
	return Vector3(0,1.15,-17) if at.z < -11.0 else get_spawn()

func material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _platform(at: Vector3, size: Vector3, solid: bool = true) -> void:
	var root := StaticBody3D.new() if solid else Node3D.new()
	root.position = at
	add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _bevel_mesh
	mesh.scale = size
	mesh.material_override = stone
	root.add_child(mesh)
	# A substantial blue underside distinguishes landings from the distant cloud sea.
	var underside := MeshInstance3D.new()
	underside.mesh = _bevel_mesh
	underside.scale = size * Vector3(0.94,1.6,0.94)
	underside.position.y = -size.y * 0.9
	underside.material_override = shadow_stone
	root.add_child(underside)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		root.add_child(collision)

func _column(at: Vector3, height: float, solid: bool = true) -> void:
	_platform(at + Vector3(0,height/2,0), Vector3(0.7,height,0.7),solid)
	_platform(at + Vector3(0,height,0),Vector3(1.1,0.3,1.1),solid)

func _anchor(at: Vector3) -> void:
	var target := Node3D.new()
	target.position = at
	target.set_meta("kind","anchor")
	target.add_to_group("tether_targets")
	add_child(target)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.33
	torus.outer_radius = 0.49
	torus.rings = 12
	torus.ring_segments = 20
	ring.mesh = torus
	ring.rotation.x = PI/2
	ring.material_override = gold
	target.add_child(ring)
	var diamond := MeshInstance3D.new()
	var shape := PrismMesh.new()
	shape.size = Vector3(0.32,0.7,0.32)
	diamond.mesh = shape
	diamond.material_override = gold
	target.add_child(diamond)

func _ring(at: Vector3, radius: float, start: float, end: float, count: int, mat: Material, solid: bool) -> void:
	for i in count:
		var angle := lerpf(start,end,float(i)/float(count-1))
		var segment := MeshInstance3D.new()
		segment.mesh = _bevel_mesh
		segment.position = at + Vector3(cos(angle)*radius,sin(angle)*radius,0)
		segment.scale = Vector3(1.8,0.85,1.1)
		segment.rotation.z = angle + PI/2
		segment.material_override = mat
		add_child(segment)
		if solid:
			var body := StaticBody3D.new()
			body.transform = Transform3D(Basis.from_euler(Vector3(0,0,angle+PI/2)),segment.position)
			add_child(body)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.8,0.85,1.1)
			collision.shape = shape
			body.add_child(collision)

func _make_bevel() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var corners: Array[Vector2] = [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
	var rows: Array[Vector3] = []
	for layer in [Vector2(-0.5,0.46),Vector2(-0.42,0.5),Vector2(0.42,0.5),Vector2(0.5,0.46)]:
		for p in corners:
			rows.append(Vector3(p.x*layer.y,layer.x,p.y*layer.y))
	for row in 3:
		for i in 4:
			var a := row*4+i
			var b := row*4+(i+1)%4
			for index in [a,b,b+4,a,b+4,a+4]:
				surface.add_vertex(rows[index])
	for index in [12,13,14,12,14,15,0,2,1,0,3,2]:
		surface.add_vertex(rows[index])
	surface.generate_normals()
	return surface.commit()

func _environment() -> void:
	var web := OS.has_feature("web")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("135894")
	sky_mat.sky_horizon_color = Color("87bcd5")
	sky_mat.ground_bottom_color = Color("466f95")
	sky_mat.ground_horizon_color = Color("87bcd5")
	sky_mat.ground_curve = 0.5
	sky_mat.sky_curve = 0.6
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if web else Environment.TONE_MAPPER_FILMIC
	# Compatibility uses LDR lighting; keep its luminance budget below white clipping.
	if web:
		env.ambient_light_energy = 0.22
		env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("bedce7")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
	if not web:
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.6
		env.glow_enabled = true
		env.glow_intensity = 0.2
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-28,0)
	sun.light_color = Color("fff0d3")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	if web:
		sun.light_energy = 0.72
		sun.shadow_bias = 0.06
		sun.shadow_normal_bias = 1.2
		sun.directional_shadow_max_distance = 60
		sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 60 if web else 100
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	var cloud_mat := material(Color("c4d8e0"),1.0)
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radial_segments = 20
	cloud_mesh.rings = 12
	var clouds := MultiMesh.new()
	clouds.transform_format = MultiMesh.TRANSFORM_3D
	clouds.mesh = cloud_mesh
	clouds.instance_count = 168
	for i in 24:
		var angle := float(i)*2.39996
		var distance := 30.0+sqrt(float(i))*14.0
		var center := Vector3(sin(angle)*distance,-20-float(i%3)*3,cos(angle)*distance-22)
		for j in 7:
			var puff_angle := float(j)*2.39996+float(i)
			var offset := Vector3(cos(puff_angle)*float(j%3)*4,float(j%3)*1.4,sin(puff_angle)*float(j%3)*3)
			var puff_scale := Vector3(16-float(j%3)*2,9+float(j%3)*2,13-float(j%2)*2)
			clouds.set_instance_transform(i*7+j,Transform3D(Basis.IDENTITY.scaled(puff_scale),center+offset))
	var cloud_field := MultiMeshInstance3D.new()
	cloud_field.multimesh = clouds
	cloud_field.material_override = cloud_mat
	cloud_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud_field)

func _floor_art() -> void:
	# Inlaid blue processional routes and a circular court mark are geometry, with one shared draw.
	var inlay := material(Color("52687a"),0.72)
	var transforms: Array[Transform3D] = []
	for deck in [Vector3(0,0.008,7),Vector3(0,0.658,-5.5),Vector3(0,1.008,-18)]:
		var length := 7.6 if deck.z > -10 else 11.6
		var width := 3.5 if deck.z > -10 else 6.5
		for side in [-1.0,1.0]:
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.055,0.012,length)),deck+Vector3(side*width,0,0)))
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width*2,0.012,0.055)),deck+Vector3(0,0,side*length*0.5)))
	# The arena's broken circular engraving signals the rising route without using target gold.
	for i in 32:
		if i in [3,4,14,23]: continue
		var angle := float(i)*TAU/32
		var basis := Basis.from_euler(Vector3(0,-angle,0)).scaled(Vector3(0.5,0.012,0.065))
		transforms.append(Transform3D(basis,Vector3(cos(angle)*4.3,1.014,sin(angle)*4.3-18)))
	var marks := MultiMesh.new()
	marks.transform_format = MultiMesh.TRANSFORM_3D
	marks.mesh = _bevel_mesh
	marks.instance_count = transforms.size()
	for i in transforms.size(): marks.set_instance_transform(i,transforms[i])
	var instances := MultiMeshInstance3D.new()
	instances.multimesh = marks
	instances.material_override = inlay
	add_child(instances)
	# Broken cornice teeth give the silhouette a rhythm while leaving the floor collider generous.
	for i in 8:
		var fragment := MeshInstance3D.new()
		fragment.mesh = _bevel_mesh
		fragment.material_override = shadow_stone
		fragment.position = Vector3(-7.5 if i<4 else 7.5,-0.45,-13-float(i%4)*3)
		fragment.scale = Vector3(0.6,0.5+float(i%3)*0.35,1.1)
		fragment.rotation.z = 0.12 if i%2==0 else -0.1
		add_child(fragment)
