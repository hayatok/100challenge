extends StaticBody3D

signal lure(point: Vector3)
signal discharge(point: Vector3, radius: float)

const RADIUS := 5.0
const CHARGE_SECONDS := 1.2
const COOL_SECONDS := 8.0
# Distinct bursts are deliberate even if one machine gun round misses the bell.
const SHOT_GAP := 0.28
const BELL_HEIGHT := 2.65
const SEGMENTS := 32

enum State { IDLE, CHARGING, READY, COOLING }
var state := State.IDLE
var state_time := 0.0
var since_hit := SHOT_GAP
var flash_enabled := true
var flash_left := 0.0
var shell: Node3D
var rail_light: StandardMaterial3D
var diode_materials: Array[StandardMaterial3D] = []
var arc: MeshInstance3D
var light: OmniLight3D

func setup(number: int, steel: Material, safety: Material) -> void:
	name = "RushBell%02d" % number
	collision_layer = 1
	collision_mask = 0
	var gold := _bronze()
	var dark := _material(Color("201e16"))
	var copper := _material(Color("816143"))
	var signal_dark := _material(Color("232f2b"), true)
	var col := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.height = 1.12
	cylinder.radius = 0.66
	col.shape = cylinder
	col.position.y = BELL_HEIGHT
	add_child(col)

	var mount_x := -1.05 if number == 1 else 1.05
	var foot := CollisionShape3D.new()
	var footing := BoxShape3D.new()
	footing.size = Vector3(0.42, 7.0, 0.46)
	foot.shape = footing
	var mount := StaticBody3D.new()
	mount.position = Vector3(mount_x, 3.5, 0)
	mount.collision_mask = 0
	mount.add_child(foot)
	add_child(mount)
	_box(self, Vector3(mount_x, 3.5, 0), Vector3(0.36, 7.0, 0.42), steel)
	_box(self, Vector3(mount_x, 0.9, 0), Vector3(0.42, 1.65, 0.46), safety)
	_box(self, Vector3(mount_x, 0.12, 0), Vector3(0.76, 0.24, 0.86), steel)
	_box(self, Vector3(mount_x * 0.5, 3.58, 0), Vector3(1.32, 0.18, 0.27), gold)
	var brace := _box(self, Vector3(mount_x * 0.7, 3.35, 0), Vector3(0.7, 0.1, 0.15), gold)
	brace.rotation.z = -signf(mount_x) * 0.63
	shell = Node3D.new()
	shell.position.y = 3.52
	add_child(shell)
	_cylinder(shell, -0.15, 0.10, 0.18, 0.29, gold)
	_cylinder(shell, -0.48, 0.23, 0.33, 0.47, gold)
	_cylinder(shell, -0.78, 0.33, 0.62, 0.13, gold)
	_cylinder(shell, -0.90, 0.62, 0.65, 0.11, gold)
	_cylinder(shell, -0.96, 0.55, 0.55, 0.027, dark)
	_cylinder(shell, -0.99, 0.10, 0.12, 0.13, copper)
	_cylinder(shell, -1.22, 0.034, 0.034, 0.48, copper)
	_cylinder(shell, -1.46, 0.06, 0.085, 0.1, copper)

	# Pairs of number plates and phase meters read from either end of the aisle.
	for side in [-1.0, 1.0]:
		_box(self, Vector3(mount_x, 2.48, side * 0.25), Vector3(0.76, 0.59, 0.10), signal_dark)
		var number_label := Label3D.new()
		number_label.text = "%02d" % number
		number_label.font_size = 45
		number_label.pixel_size = 0.01
		number_label.position = Vector3(mount_x, 2.50, side * 0.31)
		number_label.rotation.y = PI if side < 0 else 0.0
		number_label.modulate = Color("f8cb76")
		number_label.outline_size = 0
		add_child(number_label)
		for segment in range(4):
			var cell := _material(Color("303834"), true)
			diode_materials.append(cell)
			_box(self, Vector3(mount_x + (float(segment) - 1.5) * 0.157, 2.26, side * 0.318),
				Vector3(0.12, 0.05, 0.025), cell)

	rail_light = _material(Color("315e5b"), true)
	_make_ring(steel, 0.055, 0.34, 0.06, 0.044)
	_make_ring(rail_light, 0.17, 0.16, 0.087, 0.016)
	_build_arcs()
	light = OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = Color("73f4ee")
	light.light_energy = 0
	light.omni_range = RADIUS
	add_child(light)
	_refresh_indicators()

func _process(delta: float) -> void:
	state_time += delta
	since_hit += delta
	if state == State.CHARGING and state_time >= CHARGE_SECONDS:
		_change_state(State.READY)
	elif state == State.COOLING and state_time >= COOL_SECONDS:
		_change_state(State.IDLE)
	if state == State.CHARGING or state == State.COOLING:
		_refresh_indicators()
	var swing_time := state_time if state == State.CHARGING or state == State.COOLING else 1.0
	shell.rotation.z = sin(swing_time * 16) * 0.21 * maxf(0.0, 1.0 - swing_time * 1.4)
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
		arc.visible = flash_enabled and flash_left > 0
		light.light_energy = 2.2 * flash_left / 0.30 if flash_enabled else 0.0

func set_flash(enabled: bool) -> void:
	flash_enabled = enabled
	if not enabled:
		arc.visible = false
		light.light_energy = 0.0
		flash_left = 0.0

func receive_shot(_damage: float, _hit_position: Vector3, _direction: Vector3) -> void:
	var gap := since_hit
	since_hit = 0.0
	if state == State.IDLE:
		_change_state(State.CHARGING)
		lure.emit(global_position)
	elif state == State.READY and gap >= SHOT_GAP:
		_change_state(State.COOLING)
		flash_left = 0.30 if flash_enabled else 0.0
		arc.visible = flash_enabled
		discharge.emit(global_position, RADIUS)

func _change_state(next: State) -> void:
	state = next
	state_time = 0.0
	_refresh_indicators()

func _refresh_indicators() -> void:
	var indicator := Color("e6aa51")
	var cells := 1
	match state:
		State.IDLE:
			rail_light.albedo_color = Color("315e5b")
		State.CHARGING:
			var progress := state_time / CHARGE_SECONDS
			rail_light.albedo_color = Color("477b79").lerp(Color("7ee7dd"), progress)
			indicator = Color("68e6d8")
			cells = clampi(1 + int(progress * 3.0), 1, 3)
		State.READY:
			rail_light.albedo_color = Color("70fce9")
			indicator = Color("b4fff2")
			cells = 4
		State.COOLING:
			rail_light.albedo_color = Color("274443")
			indicator = Color("d69e50")
			cells = clampi(int(state_time / COOL_SECONDS * 4.0), 0, 3)
	for i in range(diode_materials.size()):
		diode_materials[i].albedo_color = indicator if i % 4 < cells else Color("303834")

func _make_ring(material: Material, gap: float, width: float, height: float, thickness: float) -> void:
	var radius := RADIUS - 0.18
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TAU * radius / SEGMENTS - gap, thickness, width)
	var segments := MultiMesh.new()
	segments.transform_format = MultiMesh.TRANSFORM_3D
	segments.mesh = mesh
	segments.instance_count = SEGMENTS
	for i in range(SEGMENTS):
		var angle := float(i) / SEGMENTS * TAU
		var offset := Vector3(sin(angle) * radius, height, cos(angle) * radius)
		segments.set_instance_transform(i, Transform3D(Basis(Vector3.UP, angle), offset))
	var fixture := MultiMeshInstance3D.new()
	fixture.multimesh = segments
	fixture.material_override = material
	fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fixture)

func _build_arcs() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ray in range(11):
		var angle := float(ray) * TAU / 11.0
		var outward := Vector3(sin(angle), 0, cos(angle))
		var across := Vector3(cos(angle), 0, -sin(angle)) * 0.026
		var point := outward * (RADIUS - 0.09) + Vector3.UP * 0.14
		for step in range(7):
			var spread := sin(float(step * 8 + ray * 4)) * 0.37
			var end := outward * (RADIUS - (step + 1) * 0.52) + across.normalized() * spread
			end.y = 0.16 + 0.32 * absf(sin(ray * 4.0 + step * 3.4))
			for vertex in [point - across, point + across, end - across, end - across, point + across, end + across]:
				mesh.surface_add_vertex(vertex)
			point = end
	mesh.surface_end()
	var material := _material(Color("94f5f2"), true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc = MeshInstance3D.new()
	arc.mesh = mesh
	arc.material_override = material
	arc.visible = false
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc)

func _bronze() -> StandardMaterial3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 417
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in range(32):
		for x in range(32):
			var color := Color("deaa52")
			var patina := rng.randf()
			if patina < 0.09:
				color = Color("62401f")
			elif patina < 0.26:
				color = Color("a77232")
			elif y % 11 == 0:
				color = Color("e1bb6e")
			image.set_pixel(x, y, color * rng.randf_range(0.89, 1.03))
	var gold := _material(Color.WHITE)
	gold.albedo_texture = ImageTexture.create_from_image(image)
	gold.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gold.uv1_triplanar = true
	gold.uv1_scale = Vector3.ONE * 0.8
	gold.metallic = 0.46
	gold.roughness = 0.38
	gold.emission_enabled = true
	gold.emission = Color("63401a")
	gold.emission_energy_multiplier = 0.55
	return gold

func _material(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _piece(parent, pos, mesh, material)

func _cylinder(parent: Node3D, y: float, top: float, bottom: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 0
	_piece(parent, Vector3(0, y, 0), mesh, material)

func _piece(parent: Node3D, pos: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = pos
	parent.add_child(piece)
	return piece
