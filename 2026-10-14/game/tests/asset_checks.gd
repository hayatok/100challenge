extends RefCounted
## Catch glTF linear colors becoming dark in Compatibility and shared meshes
## being duplicated for every office instance.

const AssetLibrary := preload("res://scripts/asset_library.gd")
const DisplayFont := preload("res://assets/fonts/TaikinComic-Black.otf")

func run() -> Array[String]:
	var failures: Array[String] = []
	for character in "全力退勤定時だ飛べ書類全提出壁成功自己ベスト被害総額最大連鎖消火器残圧設定再開派手標準控えめ¥0123456789×↑→！":
		if not DisplayFont.has_char(character.unicode_at(0)):
			failures.append("Display font lacks required game character: " + character)
	var employee := AssetLibrary.model("employee")
	var head := employee.find_child("Head_Geometry", true, false) as MeshInstance3D
	var has_skin := false
	var expected := Color("ffc58f")
	var colors: PackedColorArray = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for color in colors:
		if absf(color.r - expected.r) < 0.01 and absf(color.g - expected.g) < 0.01 and absf(color.b - expected.b) < 0.01:
			has_skin = true
			break
	if not has_skin:
		failures.append("Imported employee keeps the reference sRGB skin color, without double gamma conversion")
	var material := head.material_override as StandardMaterial3D
	if not material.vertex_color_use_as_albedo or not material.vertex_color_is_srgb or material.albedo_color != Color.WHITE:
		failures.append("Toy vertex colors use a white sRGB-aware material")
	var other := AssetLibrary.model("employee")
	var other_head := other.find_child("Head_Geometry", true, false) as MeshInstance3D
	if head.mesh != other_head.mesh or head.material_override != other_head.material_override:
		failures.append("Repeated toy instances share converted meshes and material")
	var paper := AssetLibrary.particle_mesh("fx_paper")
	if paper != AssetLibrary.particle_mesh("fx_paper") or paper.get_surface_count() != 1:
		failures.append("Curled paper particles reuse one baked surface")
	if AssetLibrary.particle_material().shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		failures.append("Particle reference colors remain visible without lighting")
	employee.free()
	other.free()
	return failures
