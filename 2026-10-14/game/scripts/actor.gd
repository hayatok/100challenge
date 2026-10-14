extends Node3D
## A rounded, hand-built office worker. The player owns motion; these pivots own acting.

const INK := Color("26323f")
const SKIN := Color("ffcc99")
const HAIR := Color("251c1a")
const MINT := Color("3eaaa0")
const RED := Color("e63b2f")

var _made := false
var _time := 0.0
var _materials: Dictionary = {}
var _sphere: SphereMesh
var _capsule: CapsuleMesh
var _box: BoxMesh
var _chair: Node3D
var _person: Node3D
var _head: Node3D
var _tie: Node3D
var _tank: Node3D
var _right_arm: Node3D
var _left_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _mouth: Node3D
var _round_mouth: MeshInstance3D
var _square_mouth: MeshInstance3D
var _teeth: MeshInstance3D
var _tongue: MeshInstance3D
var _eyelids: Array[MeshInstance3D] = []
var _pupils: Array[MeshInstance3D] = []
var _brows: Array[MeshInstance3D] = []
var _cheeks: Array[MeshInstance3D] = []
var _tears: Array[MeshInstance3D] = []
var _hair_tips: Array[Node3D] = []
var _tank_home := Vector3(0.63, 0.46, -0.18)

func build() -> void:
	if _made:
		return
	_made = true
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 28
	_sphere.rings = 16
	_capsule = CapsuleMesh.new()
	_capsule.radius = 0.5
	_capsule.height = 2.0
	_capsule.radial_segments = 20
	_capsule.rings = 8
	_box = BoxMesh.new()
	_box.size = Vector3.ONE
	_chair = _pivot(self, "Mint chair", Vector3.ZERO)
	_build_chair()
	_person = _pivot(_chair, "Employee breathing and recoil", Vector3(0, 0.91, -0.04))
	_build_person()
	_batch_rigid_parts()
	update_pose(0.0, 0.0, 0.0, false, 0.0, false, false)

func _build_chair() -> void:
	# Five distinct swept spokes with double dark rubber casters.
	_ellipsoid(_chair, "Five star hub", Vector3(0, 0.23, 0), Vector3(0.38, 0.20, 0.38), INK)
	_cylinder(_chair, "Chrome gas lift", Vector3(0, 0.46, 0), 0.075, 0.47, Color("b7c1c5"), 0.65)
	_cylinder(_chair, "Lift sleeve", Vector3(0, 0.31, 0), 0.10, 0.22, INK)
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.3
		var end := Vector3(sin(a) * 0.79, 0.18, cos(a) * 0.79)
		_segment(_chair, "Curved star leg", Vector3(0, 0.25, 0), end, 0.067, INK)
		var wheel := _pivot(_chair, "Twin caster", end + Vector3(0, -0.045, 0))
		wheel.rotation.y = a + 0.4
		for side in [-1.0, 1.0]:
			var tire := _cylinder(wheel, "Rubber wheel", Vector3(side * 0.075, 0, 0), 0.115, 0.065, Color("20252d"))
			tire.rotation.z = PI / 2
		var hub := _cylinder(wheel, "Wheel pin", Vector3.ZERO, 0.039, 0.18, Color("929da5"), 0.6)
		hub.rotation.z = PI / 2
	_ellipsoid(_chair, "Seat dark piping", Vector3(0, 0.76, -0.05), Vector3(1.53, 0.22, 1.30), Color("235d5d"))
	_ellipsoid(_chair, "Soft mint seat", Vector3(0, 0.85, -0.08), Vector3(1.44, 0.24, 1.23), MINT)
	_ellipsoid(_chair, "Seat front roll", Vector3(0, 0.84, -0.58), Vector3(1.20, 0.16, 0.20), Color("50bbb0"))
	_segment(_chair, "Back frame", Vector3(0, 0.65, 0.40), Vector3(0, 1.28, 0.57), 0.095, INK)
	_ellipsoid(_chair, "Backrest piping", Vector3(0, 1.25, 0.51), Vector3(1.35, 0.88, 0.30), Color("235d5d"))
	_ellipsoid(_chair, "Soft back cushion", Vector3(0, 1.27, 0.43), Vector3(1.24, 0.78, 0.29), MINT)
	_ellipsoid(_chair, "Back lumbar roll", Vector3(0, 1.06, 0.26), Vector3(1.07, 0.24, 0.25), Color("55bcb0"))
	for side in [-1.0, 1.0]:
		_segment(_chair, "Armrest riser", Vector3(side * 0.66, 0.74, 0.20), Vector3(side * 0.77, 1.17, 0.06), 0.055, INK)
		_ellipsoid(_chair, "Armrest cushion", Vector3(side * 0.76, 1.19, -0.11), Vector3(0.20, 0.13, 0.72), Color("263e47"))
		_ellipsoid(_chair, "Armrest mint accent", Vector3(side * 0.76, 1.24, -0.10), Vector3(0.16, 0.06, 0.62), MINT)

func _build_person() -> void:
	_ellipsoid(_person, "Navy seated trousers", Vector3(0, 0.07, -0.05), Vector3(1.04, 0.44, 0.78), INK)
	_ellipsoid(_person, "Rounded white shirt", Vector3(0, 0.54, -0.02), Vector3(0.98, 0.95, 0.74), Color("fff9ee"))
	_ellipsoid(_person, "Shirt lower fold", Vector3(0, 0.20, -0.20), Vector3(1.01, 0.15, 0.49), Color("e9e3d9"))
	_segment(_person, "Belt", Vector3(-0.41, 0.12, -0.33), Vector3(0.41, 0.12, -0.33), 0.045, Color("1e2229"))
	_cube(_person, "Belt buckle", Vector3(0, 0.12, -0.385), Vector3(0.13, 0.09, 0.028), Color("d1b275"))
	_ellipsoid(_person, "Neck", Vector3(0, 1.03, 0), Vector3(0.31, 0.31, 0.31), SKIN)
	for side in [-1.0, 1.0]:
		var collar := _cube(_person, "Folded collar", Vector3(side * 0.14, 0.95, -0.33), Vector3(0.21, 0.26, 0.08), Color("ffffff"))
		collar.rotation.z = side * -0.42
	_tie = _pivot(_person, "Loose red necktie", Vector3(0, 0.87, -0.42))
	_ellipsoid(_tie, "Tie knot", Vector3.ZERO, Vector3(0.15, 0.17, 0.10), Color("b72727"))
	var tie_tail := _cube(_tie, "Flying red tie", Vector3(0, -0.27, 0), Vector3(0.14, 0.43, 0.065), RED)
	tie_tail.rotation.z = -0.08
	var point := _cube(_tie, "Tie diamond tip", Vector3(0.017, -0.49, 0), Vector3(0.12, 0.12, 0.065), RED)
	point.rotation.z = PI / 4
	# Small work ID adds an adult office-worker cue without fragile text.
	_segment(_person, "ID lanyard", Vector3(-0.19, 0.89, -0.36), Vector3(-0.27, 0.44, -0.41), 0.018, Color("415d91"))
	_cube(_person, "Employee badge", Vector3(-0.27, 0.36, -0.43), Vector3(0.19, 0.23, 0.033), Color("f7eaca"))
	_cube(_person, "Badge photo", Vector3(-0.31, 0.38, -0.452), Vector3(0.055, 0.073, 0.015), Color("539aa6"))
	_cube(_person, "Badge line", Vector3(-0.235, 0.34, -0.453), Vector3(0.061, 0.016, 0.015), INK)
	_left_leg = _build_leg(-1.0)
	_right_leg = _build_leg(1.0)
	_left_arm = _build_arm(-1.0)
	_right_arm = _build_arm(1.0)
	_head = _pivot(_person, "Over shoulder expressive head", Vector3(0, 1.47, -0.02))
	_build_head()
	_tank = _pivot(_person, "Extinguisher trophy", _tank_home)
	_build_extinguisher()

func _build_leg(side: float) -> Node3D:
	var leg := _pivot(_person, "Raised trouser leg", Vector3(side * 0.31, 0.02, -0.23))
	_segment(leg, "Trouser thigh", Vector3(0, 0, 0), Vector3(side * 0.08, 0.02, -0.48), 0.19, INK)
	_segment(leg, "Trouser shin", Vector3(side * 0.08, 0.02, -0.48), Vector3(side * 0.10, -0.19, -0.79), 0.145, Color("303b52"))
	_ellipsoid(leg, "Bare ankle", Vector3(side * 0.10, -0.19, -0.83), Vector3(0.21, 0.19, 0.23), SKIN)
	var shoe := _ellipsoid(leg, "Polished business shoe", Vector3(side * 0.10, -0.23, -0.99), Vector3(0.34, 0.24, 0.57), Color("282326"))
	shoe.rotation.x = -0.28
	_ellipsoid(leg, "Shoe sole", Vector3(side * 0.10, -0.34, -0.99), Vector3(0.36, 0.075, 0.58), Color("141d26"))
	return leg

func _build_arm(side: float) -> Node3D:
	var arm := _pivot(_person, "Shirt sleeve and gripping hand", Vector3(side * 0.40, 0.78, -0.04))
	_segment(arm, "Short white sleeve", Vector3.ZERO, Vector3(side * 0.15, -0.18, -0.12), 0.17, Color("fff7ed"))
	_segment(arm, "Bare forearm", Vector3(side * 0.15, -0.18, -0.12), Vector3(side * 0.17, 0.06 if side > 0 else -0.27, -0.45), 0.12, SKIN)
	_ellipsoid(arm, "Mitten grip", Vector3(side * 0.16, 0.06 if side > 0 else -0.25, -0.48), Vector3(0.29, 0.27, 0.28), SKIN)
	_ellipsoid(arm, "Thumb", Vector3(side * 0.04, 0.07 if side > 0 else -0.24, -0.53), Vector3(0.115, 0.19, 0.15), Color("ffd3a6"))
	return arm

func _build_head() -> void:
	_ellipsoid(_head, "Warm rounded face", Vector3.ZERO, Vector3(1.16, 1.17, 1.02), SKIN)
	_ellipsoid(_head, "Soft chin", Vector3(0, -0.32, -0.19), Vector3(0.89, 0.57, 0.69), SKIN)
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, "Ear", Vector3(side * 0.57, -0.05, 0.025), Vector3(0.25, 0.33, 0.24), SKIN)
		_ellipsoid(_head, "Ear inner", Vector3(side * 0.623, -0.055, -0.07), Vector3(0.12, 0.17, 0.09), Color("ea9c77"))
		_ellipsoid(_head, "Large eye white", Vector3(side * 0.23, 0.115, -0.456), Vector3(0.31, 0.37, 0.13), Color("fffef4"))
		var pupil := _ellipsoid(_head, "Alert pupil", Vector3(side * 0.23 + 0.025, 0.095, -0.526), Vector3(0.105, 0.19, 0.048), INK)
		_pupils.append(pupil)
		_ellipsoid(_head, "Eye catchlight", Vector3(side * 0.23 + 0.005, 0.135, -0.554), Vector3(0.031, 0.041, 0.018), Color("ffffff"))
		var lid := _segment(_head, "Laugh eye crease", Vector3(side * 0.23 - 0.105, 0.11, -0.548), Vector3(side * 0.23 + 0.105, 0.14, -0.548), 0.027, HAIR)
		lid.visible = false
		_eyelids.append(lid)
		var brow := _segment(_head, "Expressive eyebrow", Vector3(side * 0.23 - 0.13, 0.35, -0.436), Vector3(side * 0.23 + 0.10, 0.395, -0.436), 0.033, HAIR)
		_brows.append(brow)
		var cheek := _ellipsoid(_head, "Flushed cheek", Vector3(side * 0.36, -0.125, -0.424), Vector3(0.24, 0.12, 0.045), Color("f78d7d"))
		cheek.rotation.z = side * 0.2
		_cheeks.append(cheek)
		var tear := _ellipsoid(_head, "Happy tear", Vector3(side * 0.405, -0.02, -0.433), Vector3(0.066, 0.20, 0.065), Color("80dcf4"))
		tear.rotation.z = side * -0.25
		tear.visible = false
		_tears.append(tear)
	_ellipsoid(_head, "Button nose", Vector3(0, -0.02, -0.536), Vector3(0.21, 0.18, 0.18), Color("f8b78a"))
	_mouth = _pivot(_head, "Shouting mouth", Vector3(0.025, -0.275, -0.475))
	_ellipsoid(_mouth, "Lip rim", Vector3.ZERO, Vector3(0.47, 0.44, 0.10), Color("ce6554"))
	_round_mouth = _ellipsoid(_mouth, "Dark shouting mouth", Vector3(0, 0, -0.04), Vector3(0.39, 0.36, 0.07), Color("611f24"))
	_square_mouth = _cube(_mouth, "Impact square mouth", Vector3(0, 0, -0.055), Vector3(0.37, 0.35, 0.055), Color("611f24"))
	_square_mouth.visible = false
	_teeth = _ellipsoid(_mouth, "Top teeth", Vector3(0, 0.122, -0.085), Vector3(0.30, 0.074, 0.040), Color("fffcec"))
	_tongue = _ellipsoid(_mouth, "Round pink tongue", Vector3(0, -0.109, -0.092), Vector3(0.235, 0.119, 0.046), Color("f57d79"))
	# A curved cap and layered ellipsoid locks, never voxel cubes.
	_ellipsoid(_head, "Hair round crown", Vector3(0, 0.35, 0.11), Vector3(1.18, 0.66, 0.96), HAIR)
	_ellipsoid(_head, "Hair back", Vector3(0, 0.10, 0.35), Vector3(1.12, 0.93, 0.50), HAIR)
	for i in range(7):
		var x := -0.48 + float(i) * 0.15
		var lock := _ellipsoid(_head, "Swept fringe lock", Vector3(x, 0.41 + 0.055 * sin(float(i) * 2), -0.28), Vector3(0.29, 0.35, 0.30), HAIR)
		lock.rotation.z = -0.64 + float(i) * 0.05
		lock.rotation.x = -0.33
	for side in [-1.0, 1.0]:
		_ellipsoid(_head, "Sideburn", Vector3(side * 0.49, 0.07, 0.0), Vector3(0.20, 0.52, 0.48), HAIR)
	for i in range(5):
		var tip := _pivot(_head, "Rebellious hair tuft", Vector3(-0.35 + i * 0.16, 0.59, 0.01 + 0.10 * sin(i * 1.7)))
		var hair := _ellipsoid(tip, "Soft spiky tuft", Vector3(0, 0.09, 0), Vector3(0.21, 0.37 + float(i % 2) * 0.11, 0.25), Color("33231e"))
		hair.rotation.z = -0.64 + float(i) * 0.12
		_hair_tips.append(tip)

func _build_extinguisher() -> void:
	_cylinder(_tank, "Red extinguisher cylinder", Vector3(0, -0.08, 0), 0.225, 0.72, RED, 0.15)
	_ellipsoid(_tank, "Rounded tank shoulder", Vector3(0, 0.28, 0), Vector3(0.45, 0.26, 0.45), RED)
	_ellipsoid(_tank, "Rounded tank base", Vector3(0, -0.46, 0), Vector3(0.45, 0.14, 0.45), Color("c72b26"))
	_cylinder(_tank, "Black base ring", Vector3(0, -0.46, 0), 0.238, 0.08, INK)
	_cylinder(_tank, "Brass valve", Vector3(0, 0.43, 0), 0.075, 0.16, Color("cba351"), 0.55)
	_segment(_tank, "Black carry handle", Vector3(-0.13, 0.50, 0), Vector3(0.17, 0.50, 0), 0.04, INK)
	_segment(_tank, "Squeeze lever", Vector3(-0.12, 0.57, 0), Vector3(0.16, 0.55, 0), 0.025, Color("45474b"))
	var gauge := _cylinder(_tank, "Pressure gauge rim", Vector3(0, 0.40, -0.10), 0.074, 0.038, INK)
	gauge.rotation.x = PI / 2
	_ellipsoid(_tank, "Gauge face", Vector3(0, 0.40, -0.129), Vector3(0.115, 0.115, 0.022), Color("fff9df"))
	_segment(_tank, "Gauge needle", Vector3(0, 0.40, -0.147), Vector3(0.030, 0.435, -0.147), 0.008, RED)
	_cube(_tank, "White instruction label", Vector3(0, -0.07, -0.221), Vector3(0.28, 0.40, 0.026), Color("fff9eb"))
	_cube(_tank, "Label red header", Vector3(0, 0.080, -0.238), Vector3(0.22, 0.058, 0.018), RED)
	for i in range(3):
		_cube(_tank, "Safety instruction line", Vector3(0.015, -0.015 - i * 0.062, -0.241), Vector3(0.17, 0.017, 0.012), INK)
	_segment(_tank, "Hose from valve", Vector3(0.14, 0.42, 0), Vector3(0.30, 0.25, 0.12), 0.049, INK)
	_segment(_tank, "Hose bend", Vector3(0.30, 0.25, 0.12), Vector3(0.28, 0.06, 0.42), 0.052, INK)
	_segment(_tank, "Hose to rear", Vector3(0.28, 0.06, 0.42), Vector3(0.11, 0.05, 0.76), 0.052, INK)
	_segment(_tank, "Wide rear nozzle", Vector3(0.11, 0.05, 0.76), Vector3(0.11, 0.05, 1.04), 0.075, INK)
	_segment(_tank, "Nozzle silver band", Vector3(0.11, 0.05, 0.90), Vector3(0.11, 0.05, 0.96), 0.080, Color("bdc6ca"))

func update_pose(delta: float, speed: float, turn: float, spray: bool, impact: float, rush: bool, won: bool) -> void:
	if not _made:
		build()
	_time += maxf(delta, 0.0)
	var moving := clampf(speed / 9.0, 0.0, 1.0)
	var hit := clampf(impact, 0.0, 1.0)
	var thrust := 1.0 if spray else 0.0
	var happy := 1.0 if won else 0.0
	var bounce := sin(_time * (13.0 if spray else 2.4))
	_chair.rotation = Vector3(-0.045 * thrust - hit * 0.12, 0, -turn * (0.07 + moving * 0.075) + sin(_time * 22) * hit * 0.08)
	_person.position.y = 0.91 + bounce * (0.018 + thrust * 0.012) + hit * 0.08
	_person.rotation = Vector3(thrust * -0.10 + hit * -0.16, -1.0, turn * -0.13)
	# He keeps checking the ridiculous plume over his shoulder: visible from the play camera.
	_head.rotation = Vector3(0.17 + thrust * 0.08 + hit * 0.16, -1.25 + turn * 0.10 + sin(_time * 1.9) * 0.045, -turn * 0.09 + sin(_time * 16) * hit * 0.08)
	_head.scale = Vector3(1.0 + hit * 0.20, 1.0 - hit * 0.20 + (0.04 if rush else 0.0), 1.0 + hit * 0.10)
	_tie.rotation = Vector3(-0.18 - thrust * 1.05 + sin(_time * 19) * thrust * 0.16, sin(_time * 12) * thrust * 0.16, turn * -0.35 + sin(_time * 16) * (0.04 + thrust * 0.13))
	_left_leg.rotation.x = -0.08 - thrust * 0.15 - hit * 0.24 + sin(_time * 12) * moving * 0.07
	_right_leg.rotation.x = -0.13 - thrust * 0.18 - hit * 0.38 - sin(_time * 12) * moving * 0.07
	_left_arm.rotation.z = 0.08 + hit * 0.22 - happy * 0.68
	_left_arm.rotation.x = happy * 1.0
	_right_arm.rotation.z = -0.08 - hit * 0.14 + happy * 0.42
	_right_arm.rotation.x = happy * 1.30
	_right_arm.position.y = 0.78 + happy * 0.45
	_right_arm.position.z = -0.04 - happy * 0.32
	_tank.position = _tank_home + Vector3(-0.08 * happy, 0.98 * happy, -0.55 * happy)
	_tank.rotation = Vector3(0.13 + thrust * 0.06 + sin(_time * 17) * hit * 0.06, 1.24, -0.20 - happy * 0.24)
	_mouth.scale = Vector3(0.8 + thrust * 0.25 + hit * 0.2 + happy * 0.22, 0.68 + thrust * 0.36 + hit * 0.18 + happy * 0.05, 1.0)
	_round_mouth.visible = hit < 0.28
	_square_mouth.visible = hit >= 0.28
	for i in range(2):
		_pupils[i].scale.y = (0.19 if hit < 0.25 else 0.10)
		_pupils[i].visible = not won
		_eyelids[i].visible = won
		_brows[i].rotation.z = -1.377 + (0.12 if i == 0 else -0.18) * thrust + (0.3 if i == 0 else -0.3) * hit
		_cheeks[i].scale.x = 0.24 + hit * 0.10 + thrust * (0.022 + sin(_time * 23 + i) * 0.017)
		_tears[i].visible = won
		_tears[i].position.y = -0.02 - happy * (0.03 + sin(_time * 6 + i) * 0.025)
	for i in range(_hair_tips.size()):
		_hair_tips[i].rotation.z = sin(_time * 15 + i * 1.6) * (thrust * 0.10 + hit * 0.18)

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node

func _material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + ":" + str(metal)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.74 if metal < 0.1 else 0.34
	mat.metallic = metal
	_materials[key] = mat
	return mat

func _shape(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, mesh: Mesh, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = _material(color, metal)
	parent.add_child(instance)
	instance.position = at
	instance.scale = dimensions
	# Facial details, fingers, trim and casters need color passes, not their
	# own depth passes. Keep the large silhouette and its contact shadow.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if label in ["Warm rounded face", "Soft chin", "Hair round crown", "Hair back",
		"Rounded white shirt", "Navy seated trousers", "Soft mint seat",
		"Seat dark piping", "Backrest piping", "Red extinguisher cylinder"]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

func _ellipsoid(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	return _shape(parent, label, at, dimensions, _sphere, color)

func _cube(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	return _shape(parent, label, at, dimensions, _box, color)

func _segment(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var d := b - a
	var length := maxf(d.length(), 0.005)
	var mesh := _shape(parent, label, (a + b) * 0.5, Vector3(radius * 2.0, length * 0.5 + radius, radius * 2.0), _capsule, color)
	mesh.quaternion = Quaternion(Vector3.UP, d.normalized())
	return mesh

func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 28
	return _shape(parent, label, at, Vector3.ONE, mesh, color, metal)

func _batch_rigid_parts() -> void:
	# Batches stay under their animated pivot. Static wheel pivots fold into
	# the chair; the independently swaying hair tips keep their own pivots.
	var moving_roots: Dictionary = {}
	for pivot in [_chair, _person, _head, _tie, _tank, _right_arm, _left_arm,
		_left_leg, _right_leg, _mouth]:
		moving_roots[pivot.get_instance_id()] = true
	for tip in _hair_tips:
		moving_roots[tip.get_instance_id()] = true
	var animated_meshes: Dictionary = {}
	for parts in [_eyelids, _pupils, _brows, _cheeks, _tears,
		[_round_mouth, _square_mouth, _teeth, _tongue]]:
		for part in parts:
			animated_meshes[part.get_instance_id()] = true
	var sources := find_children("*", "MeshInstance3D", true, false)
	var authored_count := sources.size()
	var groups: Dictionary = {}
	var removed := 0
	for source in sources:
		var instance := source as MeshInstance3D
		if animated_meshes.has(instance.get_instance_id()):
			continue
		var relative := instance.transform
		var rig := instance.get_parent() as Node3D
		while not moving_roots.has(rig.get_instance_id()):
			relative = rig.transform * relative
			rig = rig.get_parent() as Node3D
		var material := instance.material_override
		var key := "%s:%s:%s" % [rig.get_instance_id(), material.get_instance_id(), instance.cast_shadow]
		if not groups.has(key):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"builder": builder, "normals": PackedVector3Array(),
				"rig": rig, "material": material, "shadow": instance.cast_shadow}
		var group: Dictionary = groups[key]
		var builder: SurfaceTool = group["builder"]
		var normals: PackedVector3Array = group["normals"]
		var normal_basis := relative.basis.inverse().transposed()
		for surface_index in range(instance.mesh.get_surface_count()):
			builder.append_from(instance.mesh, surface_index, relative)
			var arrays := instance.mesh.surface_get_arrays(surface_index)
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in source_normals:
				normals.append((normal_basis * normal).normalized())
		group["normals"] = normals
		instance.free()
		removed += 1
	for key in groups:
		var group: Dictionary = groups[key]
		var builder: SurfaceTool = group["builder"]
		var arrays := builder.commit_to_arrays()
		# Stretched primitives need inverse-transpose normals, as their former
		# MeshInstance shader calculated. Preserve the authored smooth normals.
		arrays[Mesh.ARRAY_NORMAL] = group["normals"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var batch := MeshInstance3D.new()
		batch.name = "RigidMaterialBatch_%02d" % group["rig"].get_child_count()
		batch.mesh = mesh
		batch.material_override = group["material"]
		batch.cast_shadow = group["shadow"]
		group["rig"].add_child(batch)
	set_meta("authored_mesh_count", authored_count)
	set_meta("rigid_source_mesh_count", removed)
	set_meta("rigid_batch_count", groups.size())
	set_meta("render_mesh_count", authored_count - removed + groups.size())
