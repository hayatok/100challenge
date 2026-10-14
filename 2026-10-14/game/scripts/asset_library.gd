extends RefCounted
## Shared vertex-colored toy models. Collisions belong to the authored level.

const MODEL_PATH := "res://assets/models/"
static var _scenes: Dictionary = {}
static var _particle_meshes: Dictionary = {}
static var _colored_meshes: Dictionary = {}
static var _solid: StandardMaterial3D
static var _particle: StandardMaterial3D

static func solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.vertex_color_is_srgb = true
		_solid.albedo_color = Color.WHITE
		_solid.roughness = 0.72
	return _solid

static func particle_material() -> StandardMaterial3D:
	if _particle == null:
		_particle = solid_material().duplicate() as StandardMaterial3D
		_particle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _particle

static func model(asset_name: String, shadows: bool = false) -> Node3D:
	if not _scenes.has(asset_name):
		_scenes[asset_name] = load(MODEL_PATH + asset_name + ".glb") as PackedScene
	var scene := _scenes[asset_name] as PackedScene
	assert(scene != null, "Missing toy-office model: " + asset_name)
	var root := scene.instantiate() as Node3D
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		mesh.mesh = _display_colors(mesh.mesh)
		mesh.material_override = solid_material()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func _display_colors(source: Mesh) -> Mesh:
	# glTF stores linear COLOR_0. Compatibility expects sRGB in ALBEDO, even
	# for vertex colors. Convert once per shared mesh; the material's sRGB flag
	# also makes the same data work with Forward+ and Mobile renderers.
	var key := source.get_instance_id()
	if not _colored_meshes.has(key):
		var converted := ArrayMesh.new()
		for index in range(source.get_surface_count()):
			var arrays := source.surface_get_arrays(index)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for vertex in range(colors.size()):
				colors[vertex] = colors[vertex].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = colors
			converted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_colored_meshes[key] = converted
	return _colored_meshes[key] as Mesh

static func particle_mesh(asset_name: String) -> Mesh:
	if not _particle_meshes.has(asset_name):
		var root := model(asset_name)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			var relative := mesh.transform
			var ancestor := mesh.get_parent() as Node3D
			while ancestor != root and ancestor != null:
				relative = ancestor.transform * relative
				ancestor = ancestor.get_parent() as Node3D
			for index in range(mesh.mesh.get_surface_count()):
				surface.append_from(mesh.mesh, index, relative)
		_particle_meshes[asset_name] = surface.commit()
		root.free()
	return _particle_meshes[asset_name] as Mesh
