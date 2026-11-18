extends Node3D

@onready var bridge: Node3D = $TiltingBridge
@onready var start_bar: Node3D = $StartBar/Sweeper
@onready var finish_bar: Node3D = $FinishBar/Sweeper
@onready var sea: ShaderMaterial = $Sea.material_override
var bar_shadows: Array[MeshInstance3D] = []


func set_mechanisms(bridge_angle: float, bar_angles: PackedFloat32Array, water_time: float) -> void:
	bridge.rotation.x = bridge_angle
	start_bar.rotation.y = bar_angles[0]
	finish_bar.rotation.y = bar_angles[1]
	sea.set_shader_parameter(&"swell_time", water_time)
	for index in bar_shadows.size():
		bar_shadows[index].rotation.y = bar_angles[index]


func set_mobile_profile() -> void:
	if not bar_shadows.is_empty():
		return
	var sun: DirectionalLight3D = $Sun
	sun.shadow_enabled = false
	# Match the authored noon exposure in the Compatibility renderer's
	# unshadowed lighting pass. The sky and sea already shade themselves.
	sun.light_energy *= 2.2
	var world: WorldEnvironment = $HarborSky
	var environment := world.environment.duplicate() as Environment
	environment.ambient_light_energy *= 2.2
	world.environment = environment
	# Preserve hazard height cues on phones without rendering the six runners
	# and the entire pier a second time into a directional shadow map.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.74, 1.0])
	gradient.colors = PackedColorArray([Color(0.13, 0.10, 0.15, 0.36),
		Color(0.13, 0.10, 0.15, 0.32), Color(0.13, 0.10, 0.15, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_SQUARE
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.render_priority = -1
	for bar: Node3D in [start_bar, finish_bar]:
		var shadow := _floor_shadow(bar.get_parent().position, Vector2(8.4, 0.71), 0.65, material)
		shadow.rotation.y = bar.rotation.y
		bar_shadows.append(shadow)
	for crate: Node3D in [$CargoBoxA, $CargoBoxB]:
		_floor_shadow(crate.position, Vector2(1.96, 2.03), 0.72, material)

	for batch: MultiMeshInstance3D in find_children("*", "MultiMeshInstance3D", true, false):
		var group_name := String(batch.get_parent().name)
		if group_name.begins_with("Span"):
			# The 7 cm bolt heads and rubber fenders each form a separate
			# batch per span. Keep deck tops and curving outlines continuous.
			match batch.name:
				&"MetalRound": batch.visibility_range_end = 25.0
				&"Round": batch.visibility_range_end = 43.0
				&"Painted": batch.visibility_range_end = 84.0
		elif group_name in ["LaunchPier", "LighthousePier", "ShortcutEntry", "ShortcutExit", "OuterPier"]:
			match batch.name:
				&"MetalRound": batch.visibility_range_end = 42.0
				&"Dome": batch.visibility_range_end = 54.0
				&"Rope": batch.visibility_range_end = 67.0


func _floor_shadow(origin: Vector3, size: Vector2, height: float, material: Material) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = material
	var shadow := MeshInstance3D.new()
	shadow.mesh = plane
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.visibility_range_end = 44.0
	var sunlight: Vector3 = -$Sun.basis.z
	shadow.position = origin + sunlight * (height / -sunlight.y)
	shadow.position.y = 0.018
	add_child(shadow)
	return shadow
