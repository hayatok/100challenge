extends Node3D
## Art direction lives separately from the deterministic combat simulation.
var camera: Camera3D
var player: Node3D
var enemy_mesh: Mesh
var enemy_basis: Transform3D
var parts: Dictionary = {}
var gait = 0.0
var zoom = 1.0
var last_position = Vector2.ZERO
var camera_target = Vector3.ZERO
var environment: Environment

func model(name: String) -> Node3D:
	var version = "v3" if name == "kohaku" else "v2"
	var node = load("res://assets/models/%s/%s.glb" % [version,name]).instantiate()
	add_child(node)
	return node

func first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh = first_mesh(child)
		if mesh != null:
			return mesh
	return null

func build() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("142339")
	sky_material.sky_horizon_color = Color("76828e")
	sky_material.ground_bottom_color = Color("101923")
	sky_material.ground_horizon_color = Color("46515c")
	sky_material.sky_energy_multiplier = 0.65
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4afab")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.12
	# Effects supported by native Forward+, with the same art on Compatibility/Web.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = 1.4
		environment.ssao_intensity = 1.45
		environment.ssr_enabled = true
		environment.glow_enabled = true
		environment.glow_intensity = 0.65
		environment.glow_bloom = 0.08
	var world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-28,0)
	moon.light_color = Color("b8c3d0")
	moon.light_energy = 0.65
	moon.shadow_blur = 2.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(moon)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,155,0)
	fill.light_color = Color("ffe0c2")
	fill.light_energy = 0.38
	add_child(fill)
	apply_architecture_materials(model("street"))
	# Ground texture is an authored ImageGen bitmap; roughness and normals are computed
	# in material space so no reflected buildings or illumination are baked into albedo.
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(43,27)
	var ground = MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.position.y = 0.002
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/wet_ground.gdshader")
	material.set_shader_parameter("asphalt",preload("res://assets/textures/wet-asphalt.png"))
	ground.material_override = material
	add_child(ground)
	for x in [-18,-12,-6,0,6,12,18]:
		lamp(Vector3(x,2.4,-13.5),Color("ffb06c") if int(x)%12==0 else Color("77cbc8"),1.6,5.4)
	for location in [Vector3(-19.35,5.7,8),Vector3(19.35,5.7,-7),Vector3(-19.35,5.7,-7),Vector3(19.35,5.7,8)]:
		lamp(location,Color("e8c391"),2.0,8.5)
	lamp(Vector3(0,2.6,13),Color("ed839b"),2.5,7.0)
	player = model("kohaku")
	player.scale = Vector3.ONE * 1.55
	apply_character_materials(player)
	for name in ["body","head","arm_L","arm_R","leg_L","leg_R","pony_L","pony_R"]:
		parts[name] = player.find_child(name+"_export",true,false)
	var enemy = model("call_bit")
	var mesh = first_mesh(enemy)
	enemy_mesh = mesh.mesh
	enemy_basis = mesh.global_transform
	enemy.queue_free()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.near = 0.15
	camera.far = 160
	add_child(camera)
	camera.position = Vector3(0,18,17)
	camera.look_at(Vector3(0,0.7,0))
	camera.current = true

func lamp(at: Vector3, color: Color, energy: float, distance: float) -> void:
	var light = OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.3
	# Architecture casts the directional shadow; point lights illuminate storefronts.
	add_child(light)

func update_actor(dt: float, position_2d: Vector2, facing: Vector2, moving: bool, reduced: bool) -> void:
	var speed = position_2d.distance_to(last_position) / maxf(dt,0.001)
	last_position = position_2d
	var active = moving and speed > 0.1 and not reduced
	if active:
		gait += dt * minf(speed,10.0) * 2.5
	var wave = sin(gait) if active else 0.0
	for name in ["leg_L","leg_R"]:
		if parts[name] != null:
			parts[name].rotation.x = lerpf(parts[name].rotation.x,wave*0.55*(1 if name=="leg_L" else -1),minf(dt*18,1))
	for name in ["arm_L","arm_R"]:
		if parts[name] != null:
			parts[name].rotation.x = lerpf(parts[name].rotation.x,wave*0.32*(-1 if name=="arm_L" else 1),minf(dt*18,1))
	for name in ["pony_L","pony_R"]:
		if parts[name] != null:
			parts[name].rotation.x = wave*0.12
	if parts.body != null:
		parts.body.rotation.z = wave*0.025
	player.position = Vector3(position_2d.x,absf(wave)*0.07,position_2d.y)
	var desired = atan2(facing.x,facing.y)
	player.rotation.y = lerp_angle(player.rotation.y,desired,minf(dt*13,1))
	# Closer follow framing gives clothing, floor materials and storefronts readable scale.
	var desired_target = Vector3(clampf(position_2d.x,-12,12),0,clampf(position_2d.y,-6,6))
	camera_target = camera_target.lerp(desired_target,1.0-exp(-dt*3.5))
	camera.position = camera_target + Vector3(0,18,17) * zoom
	camera.look_at(camera_target+Vector3(0,0.7,0))

func zoom_by(amount: float) -> void:
	zoom = clampf(zoom+amount,0.65,1.4)

func apply_architecture_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.mesh.surface_get_material(i)
			if original is StandardMaterial3D and original.resource_name in ["brick","wall","plaster"]:
				var masonry = ShaderMaterial.new()
				masonry.shader = preload("res://shaders/masonry.gdshader")
				masonry.set_shader_parameter("base_color",original.albedo_color)
				masonry.set_shader_parameter("course_height",0.22 if original.resource_name=="brick" else 0.5)
				masonry.set_shader_parameter("block_width",0.5 if original.resource_name=="brick" else 1.0)
				node.set_surface_override_material(i,masonry)
	for child in node.get_children():
		apply_architecture_materials(child)

func apply_character_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var toon = ShaderMaterial.new()
				toon.shader = preload("res://shaders/character_toon.gdshader")
				toon.set_shader_parameter("base_color",source.albedo_color)
				toon.set_shader_parameter("face_material",source.resource_name in ["face_painted","skin"])
				if source.albedo_texture != null:
					toon.set_shader_parameter("has_texture",true)
					toon.set_shader_parameter("albedo_texture",source.albedo_texture)
				# An inverted hull is suitable for closed skin surfaces. On thin
				# double-sided lapels/hair cards it can cover the front with black.
				if source.resource_name in ["face_painted","skin"]:
					var outline = ShaderMaterial.new()
					outline.shader = preload("res://shaders/character_outline.gdshader")
					toon.next_pass = outline
				node.set_surface_override_material(i,toon)
	for child in node.get_children():
		apply_character_materials(child)
