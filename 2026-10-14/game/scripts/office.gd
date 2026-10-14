extends Node3D
## Authored miniature office. Props are deliberately non-solid: a fast chair
## scatters them, while only the furniture and room shell can stop the player.

const AssetLibrary := preload("res://scripts/asset_library.gd")

var spawn_position := Vector3(0.0, 0.0, 42.0)
var goal_position := Vector3(0.0, 0.0, -64.0)
var _built := false
var _props: Array[Dictionary] = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _mesh_count := 0
var _route: Array[Vector3] = [
	Vector3(0, 0, 42), Vector3(0, 0, 16), Vector3(4, 0, -4),
	Vector3(4, 0, -12), Vector3(-2, 0, -24), Vector3(-2, 0, -32), Vector3(0, 0, -48),
	Vector3(0, 0, -64)
]
const COLORS := {
	"cream": Color("eee1bc"), "tile": Color("e2cfa2"), "white": Color("fff6e6"),
	"mint": Color("76bbae"), "mint_light": Color("a5d4c1"), "teal": Color("318e87"),
	"ink": Color("303a48"), "blue": Color("438cc0"), "screen": Color("86d9dc"),
	"paper": Color("fffce8"), "box": Color("dcad6a"), "orange": Color("fba44e"),
	"sun": Color("ffe49c"), "pink": Color("f7ba9f"), "red": Color("e65c46"),
	"green": Color("3fd780"), "leaf": Color("67a84f"), "leaf_light": Color("a7c45b"),
	"skin": Color("f2c09d"), "hair": Color("4b342d"), "gold": Color("e5b84d")
}

func build() -> void:
	if _built:
		return
	_built = true
	_build_shell()
	_build_route()
	# Side desks leave a generous introduction and uninterrupted sightlines.
	var rows := [36.0, 20.0, 4.0, -18.0, -40.0]
	for i in range(rows.size()):
		_desk(Vector3(-6.4, 0, rows[i]), i % 2 == 0, i == 0)
		_desk(Vector3(6.4, 0, rows[i] - 3.0), i % 2 != 0, i == 2)
	# Waist-high filing islands shape two broad bends; neither spans the room.
	_filing_island(Vector3(-3.6, 0, 0.0), Vector3(6.2, 1.45, 3.5))
	_filing_island(Vector3(3.4, 0, -24.0), Vector3(6.0, 1.45, 3.5))
	for p in [Vector3(-7.6, 0, 44), Vector3(7.6, 0, 16),
		Vector3(-7.7, 0, -12), Vector3(7.5, 0, -32),
		Vector3(-5.8, 0, -58), Vector3(5.8, 0, -58)]:
		_plant(p)
	_build_props()
	_build_exit()
	# A tiny clock and cheerful workplace slogan provide visual landmarks.
	_clock(Vector3(-8.65, 4.0, 16.0))
	_label(self, "17:00", Vector3(0, 0.06, 45.0), 0.055, true, COLORS["teal"])
	_label(self, "定時だ。飛べ。", Vector3(-6.4, 3.8, 45.6), 0.019, false, COLORS["ink"])
	_batch_static_visuals()
	set_meta("mesh_count", _mesh_count)
	set_meta("prop_count", _props.size())

func reset_props() -> void:
	for prop in _props:
		prop["broken"] = false
		var node: Node3D = prop["node"]
		node.show()

func try_break(at: Vector3, speed: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if speed <= 1.0:
		return events
	var seeds: Array[int] = []
	for i in range(_props.size()):
		var prop: Dictionary = _props[i]
		if not prop["broken"] and _flat_distance(at, prop["position"]) <= float(prop["radius"]) + 0.65:
			seeds.append(i)
	var hits: Array[int] = seeds.duplicate()
	# Only one neighbouring prop per direct impact; no runaway recursive chain.
	if speed > 2.5:
		for index in seeds:
			var closest := -1
			var nearest := 2.8
			for j in range(_props.size()):
				if _props[j]["broken"] or hits.has(j):
					continue
				var distance := _flat_distance(_props[index]["position"], _props[j]["position"])
				if distance < nearest:
					closest = j
					nearest = distance
			if closest >= 0:
				hits.append(closest)
	for index in hits:
		var prop: Dictionary = _props[index]
		if prop["broken"]:
			continue
		prop["broken"] = true
		var node: Node3D = prop["node"]
		node.hide()
		events.append({"id": prop["id"], "base": prop["base"],
			"progress": prop["progress"], "position": prop["position"],
			"kind": prop["kind"], "text": prop["text"]})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["progress"] == b["progress"]:
			return a["id"] < b["id"]
		return a["progress"] < b["progress"])
	return events

func is_goal(at: Vector3) -> bool:
	return absf(at.x - goal_position.x) < 2.9 and at.z <= -62.5 and at.z >= -68.0 and absf(at.y) < 3.0

func distance_to_goal(at: Vector3) -> float:
	# Distance follows the signed, traversable course, including both bends.
	var remaining := 0.0
	var best_squared := INF
	var best_remaining := 0.0
	for i in range(_route.size() - 2, -1, -1):
		var start := _route[i]
		var end := _route[i + 1]
		var segment := end - start
		var flat_at := Vector3(at.x, 0, at.z)
		var t := clampf((flat_at - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var projected := start + segment * t
		var squared := flat_at.distance_squared_to(projected)
		if squared < best_squared:
			best_squared = squared
			best_remaining = remaining + segment.length() * (1.0 - t)
		remaining += segment.length()
	return best_remaining + sqrt(best_squared)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _build_shell() -> void:
	# The collision shell keeps its original dimensions; decorative GLBs are non-solid.
	_solid(self, Vector3(0, -0.3, -10), Vector3(18.5, 0.6, 120), "cream", false)
	for z in range(-64, 49, 8):
		for x in [-6.0, 0.0, 6.0]:
			var floor_tile := _model(self, "floor_module", Vector3(x, -0.131, z))
			floor_tile.find_child("Wayfinding", true, false).free()
			floor_tile.scale.x = 0.75
	_solid(self, Vector3(-9.3, 1.0, -10), Vector3(0.5, 2.0, 120), "mint_light", false)
	_solid(self, Vector3(9.3, 0.45, -10), Vector3(0.5, 0.9, 120), "mint_light")
	_solid(self, Vector3(0, 0.7, 49.7), Vector3(18.5, 1.4, 0.6), "mint")
	for i in range(12):
		_model(self, "window_module", Vector3(-9.0, 0, 44.0 - float(i) * 9.2), -PI * 0.5)

func _build_route() -> void:
	# Reuse the modeled strip, following the actual navigable bends rather than
	# leaving the floor module's straight arrows on every background tile.
	for i in range(_route.size() - 1):
		var start := _route[i]
		var end := _route[i + 1]
		var direction := end - start
		var steps := maxi(1, ceili(direction.length() / 8.0))
		for step in range(steps):
			var center := start.lerp(end, (float(step) + 0.5) / float(steps))
			var strip := _model(self, "floor_module", center + Vector3(0, -0.131, 0), atan2(-direction.x, -direction.z))
			strip.find_child("BaseTiles", true, false).free()
			strip.scale = Vector3(4.4 / 2.6, 1.0, direction.length() / float(steps) / 8.0)

func _desk(at: Vector3, colleague: bool, special: bool) -> void:
	var desk := Node3D.new()
	add_child(desk)
	desk.position = at
	_solid(desk, Vector3(0, 0.85, 0), Vector3(3.4, 1.7, 2.6), "mint", false)
	_model(desk, "desk", Vector3.ZERO)
	# The computer's keyboard and screen face the seated colleague at +Z.
	_model(desk, "computer", Vector3(0.35, 1.80, -0.45), PI)
	_model(desk, "cat_mug", Vector3(1.25, 1.80, 0.8), PI)
	if special:
		_model(desk, "stapler", Vector3(-0.8, 1.80, 0.35), PI)
	if colleague:
		_colleague(desk, Vector3(0.3, 0, 2.0))

func _colleague(parent: Node3D, at: Vector3) -> void:
	var chair := _model(parent, "chair", at)
	chair.scale = Vector3.ONE * 0.88
	var person := _model(chair, "colleague", Vector3(0, 1.0, -0.04))
	person.name = "SleepyColleague"

func _filing_island(at: Vector3, size: Vector3) -> void:
	_solid(self, at + Vector3(0, size.y * 0.5, 0), size, "mint", false)
	var cabinet := _model(self, "cabinet", at, PI)
	cabinet.scale = Vector3(size.x / 5.9, 1.0, size.z / 3.14)

func _plant(at: Vector3) -> void:
	_model(self, "plant", at)

func _build_props() -> void:
	# Paper trail introduces destruction without a required obstacle. Closely
	# paired props can scatter together, and the exit vista is kept quieter.
	var placements := [
		Vector3(-0.9, 0, 32), Vector3(0.95, 0, 30.4), Vector3(-1.1, 0, 25),
		Vector3(1.0, 0, 23), Vector3(-0.85, 0, 18), Vector3(1.05, 0, 16),
		Vector3(2.0, 0, 10), Vector3(3.2, 0, 8), Vector3(3.6, 0, 3),
		Vector3(5.2, 0, 1.3), Vector3(3.1, 0, -5), Vector3(4.8, 0, -7),
		Vector3(3.9, 0, -12), Vector3(2.3, 0, -14), Vector3(1.0, 0, -20),
		Vector3(-0.8, 0, -22), Vector3(-2.1, 0, -28), Vector3(-3.5, 0, -30),
		Vector3(-2.7, 0, -36), Vector3(-0.8, 0, -38),
		Vector3(-1.15, 0, -49), Vector3(0.95, 0, -51),
		Vector3(-0.95, 0, -56), Vector3(1.1, 0, -58)
	]
	for i in range(placements.size()):
		_make_prop(placements[i], i % 3, i)

func _make_prop(at: Vector3, type: int, index: int) -> void:
	var prop := Node3D.new()
	add_child(prop)
	prop.position = at
	prop.name = "Breakable_%02d" % index
	var kind := "box"
	var base := 10000
	var text := "コピー用紙、放出！"
	var radius := 0.65
	var model_name := "paper_box"
	if type == 1:
		kind = "tower"
		base = 50000
		text = "書類、全提出！"
		radius = 0.82
		model_name = "paper_tower"
	elif type == 2:
		kind = "wagon"
		base = 100000
		text = "総務、見てない！"
		radius = 1.0
		model_name = "paper_cart"
	_model(prop, model_name, Vector3.ZERO, PI + sin(float(index) * 1.7) * 0.06)
	_props.append({"id": "prop_%02d" % index, "base": base, "progress": 42.0 - at.z,
		"position": at, "kind": kind, "text": text, "radius": radius,
		"node": prop, "broken": false})

func _build_exit() -> void:
	_solid(self, Vector3(-6.4, 2.2, -67.5), Vector3(6.5, 4.4, 0.7), "mint_light")
	_solid(self, Vector3(6.4, 2.2, -67.5), Vector3(6.5, 4.4, 0.7), "mint_light")
	_solid(self, Vector3(0, 2.2, -68.8), Vector3(6.1, 4.4, 0.5), "teal", false)
	for x in [-3.15, 3.15]:
		_solid(self, Vector3(x, 2.4, -65.5), Vector3(0.35, 4.8, 6.0), "gold", false)
	_model(self, "elevator", Vector3(0, 0, -65.5))
	_label(self, "おつかれさま！", Vector3(0, 0.1, -61.2), 0.025, true, COLORS["teal"])

func _clock(at: Vector3) -> void:
	_model(self, "clock", at, -PI * 0.5)

func _model(parent: Node3D, asset_name: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var root := AssetLibrary.model(asset_name)
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	return root

func _label(parent: Node3D, content: String, at: Vector3, pixel_size: float, flat: bool, color: Color) -> void:
	var label := Label3D.new()
	parent.add_child(label)
	label.text = content
	label.position = at
	label.pixel_size = pixel_size
	label.font_size = 64
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKjp-Medium.otf"):
		label.font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	if flat:
		label.rotation.x = -PI * 0.5

func _solid(parent: Node3D, center: Vector3, size: Vector3, color: String, visible_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = center
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		_mesh(body, "rounded" if size.y > 0.8 and size.x < 8.0 else "box", Vector3.ZERO, size, color)
	return body

func _material(color: String, unshaded: bool = false) -> StandardMaterial3D:
	var key := color + ("_flat" if unshaded else "")
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = COLORS.get(color, Color.WHITE)
		material.roughness = 0.8
		if unshaded:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = material
	return _materials[key]

func _mesh(parent: Node3D, kind: String, at: Vector3, size: Vector3, color: String, unshaded: bool = false) -> MeshInstance3D:
	if not _meshes.has(kind):
		var geometry: Mesh
		match kind:
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 12
				sphere.rings = 8
				geometry = sphere
			"cylinder":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.5
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 12
				geometry = cylinder
			"torus":
				var torus := TorusMesh.new()
				torus.inner_radius = 0.3
				torus.outer_radius = 0.5
				torus.rings = 12
				torus.ring_segments = 8
				geometry = torus
			"rounded":
				geometry = _rounded_unit_mesh()
			_:
				var box := BoxMesh.new()
				box.size = Vector3.ONE
				geometry = box
		_meshes[kind] = geometry
	var instance := MeshInstance3D.new()
	parent.add_child(instance)
	instance.mesh = _meshes[kind]
	instance.material_override = _material(color, unshaded)
	instance.position = at
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_count += 1
	return instance

func _batch_static_visuals() -> void:
	# Group by material and 16m district so distant detailed toys can be culled.
	# Prop descendants retain their own
	# geometry so hiding a broken object never hides another object or a desk.
	var prop_roots := {}
	for prop in _props:
		var node: Node3D = prop["node"]
		prop_roots[node.get_instance_id()] = true
	var groups := {}
	var removed := 0
	var authored_mesh_count := find_children("*", "MeshInstance3D", true, false).size()
	for child in find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var ancestor := instance.get_parent() as Node3D
		var relative := instance.transform
		var is_prop := false
		while ancestor != self and ancestor != null:
			if prop_roots.has(ancestor.get_instance_id()):
				is_prop = true
				break
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent() as Node3D
		if is_prop:
			continue
		var material := instance.material_override
		var district := floori(relative.origin.z / 16.0)
		var key := "%s:%s:%s" % [material.get_instance_id(), instance.cast_shadow, district]
		if not groups.has(key):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"surface": builder, "normals": PackedVector3Array(),
				"material": material, "shadow": instance.cast_shadow}
		var group: Dictionary = groups[key]
		var surface: SurfaceTool = group["surface"]
		var normals: PackedVector3Array = group["normals"]
		var normal_basis := relative.basis.inverse().transposed()
		for index in range(instance.mesh.get_surface_count()):
			surface.append_from(instance.mesh, index, relative)
			var arrays := instance.mesh.surface_get_arrays(index)
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in source_normals:
				normals.append((normal_basis * normal).normalized())
		group["normals"] = normals
		instance.free()
		removed += 1
	for key in groups:
		var group: Dictionary = groups[key]
		var surface: SurfaceTool = group["surface"]
		var arrays := surface.commit_to_arrays()
		# append_from transforms normals with the vertex basis. A nonuniformly
		# stretched sphere/cylinder instead needs inverse-transpose normals to
		# match its former MeshInstance shader. Preserve the authored normals;
		# generating new ones would change the smooth primitive silhouettes.
		arrays[Mesh.ARRAY_NORMAL] = group["normals"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var batch := MeshInstance3D.new()
		batch.name = "StaticBatch_%02d" % get_child_count()
		batch.mesh = mesh
		batch.material_override = group["material"]
		batch.cast_shadow = group["shadow"]
		add_child(batch)
	_mesh_count = authored_mesh_count - removed + groups.size()
	set_meta("authored_mesh_count", authored_mesh_count)
	set_meta("static_source_mesh_count", removed)
	set_meta("static_batch_count", groups.size())

func _rounded_unit_mesh() -> ArrayMesh:
	# A low-poly rounded rectangle extrusion: soft furniture corners at 32
	# triangles, shared by all desks, cabinets, chairs and the giant stapler.
	var outline: Array[Vector2] = []
	for corner in range(4):
		var center := Vector2(0.38 if corner < 2 else -0.38, 0.38 if corner == 0 or corner == 3 else -0.38)
		var angle_start := PI * 0.5 - float(corner) * PI * 0.5
		for step in range(3):
			var angle := angle_start - float(step) * PI * 0.25
			outline.append(center + Vector2(cos(angle), sin(angle)) * 0.12)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		var top_p := Vector3(p.x, 0.5, p.y)
		var top_q := Vector3(q.x, 0.5, q.y)
		var bot_p := Vector3(p.x, -0.5, p.y)
		var bot_q := Vector3(q.x, -0.5, q.y)
		for vertex in [Vector3(0, 0.5, 0), top_p, top_q, Vector3(0, -0.5, 0), bot_q, bot_p,
			top_p, bot_p, top_q, top_q, bot_p, bot_q]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
