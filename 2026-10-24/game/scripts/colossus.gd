extends Node3D

signal core_hit
signal core_destroyed

class CoreTarget extends Node3D:
	signal hit
	signal destroyed
	var health: int = 3
	var cooldown: float = 0.0
	var crystal: MeshInstance3D
	func _ready() -> void:
		set_meta("kind","core")
		add_to_group("tether_targets")
	func _physics_process(delta: float) -> void:
		cooldown = maxf(0.0,cooldown-delta)
		if crystal:
			crystal.rotation.y += delta*0.3
	func is_available() -> bool:
		return health > 0
	func receive_hit(_damage: int, _launch: bool, origin: Vector3) -> bool:
		if health <= 0 or cooldown > 0.0 or origin.distance_to(global_position) > 4.0:
			return false
		health -= 1
		cooldown = 0.45
		hit.emit()
		if health == 0:
			remove_from_group("tether_targets")
			crystal.hide()
			destroyed.emit()
		return true

var shoulder: AnimatableBody3D
var upper: AnimatableBody3D
var core: CoreTarget
var elapsed: float = 0.0
var stone: StandardMaterial3D
var dark: StandardMaterial3D
var gold: StandardMaterial3D

func _ready() -> void:
	stone = _material(Color("d5d7cf"),0.85)
	dark = _material(Color("24374e"),0.9)
	gold = _material(Color("e9bc61"),0.35)
	gold.metallic = 0.65
	gold.emission_enabled = true
	gold.emission = Color("c98e36")
	gold.emission_energy_multiplier = 0.8
	# Deliberately recognizable articulated test figure: crown, head, segmented arms and torso.
	_part(self,Vector3(0,1.7,0),Vector3(4,5.5,3),dark)
	_part(self,Vector3(0,4.2,0),Vector3(5.2,2.5,3.5),stone)
	_part(self,Vector3(-4,2.5,0),Vector3(2,5,2.2),stone)
	_part(self,Vector3(4,2.3,0),Vector3(1.8,4.8,2),stone)
	_part(self,Vector3(-1.3,-3,0),Vector3(1.8,6,2),stone)
	_part(self,Vector3(1.3,-3,0),Vector3(1.8,6,2),stone)
	_part(self,Vector3(0,9.3,0),Vector3(2.8,3.2,2.5),stone)
	_part(self,Vector3(0,9.6,1.28),Vector3(2.3,0.25,0.15),dark)
	for x in [-1.3,0.0,1.3]:
		_part(self,Vector3(x,11.5,-0.3),Vector3(0.4,1.8,0.7),stone)
	shoulder = _moving_floor(Vector3(4,6.0,1),Vector3(5.5,1,4.6))
	_anchor(shoulder,Vector3(0,4.8,1.2),false)
	upper = _moving_floor(Vector3(0,6.7,0),Vector3(4.5,0.7,4.8))
	core = CoreTarget.new()
	core.position = Vector3(0,8.5,1.1)
	add_child(core)
	var gem := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.85,1.6,0.85)
	gem.mesh = prism
	gem.material_override = gold
	core.add_child(gem)
	core.crystal = gem
	core.hit.connect(func(): core_hit.emit())
	core.destroyed.connect(func(): core_destroyed.emit())
	_anchor(upper,Vector3(-1.4,4.9,1),false)

func _physics_process(delta: float) -> void:
	elapsed += delta
	# Motion is physics-owned; AnimatableBody transports the rider and is paused with gameplay.
	shoulder.position.y = 6.0+sin(elapsed*0.55)*0.45
	shoulder.position.x = 4.0+sin(elapsed*0.35)*0.45

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _part(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)

func _moving_floor(at: Vector3, size: Vector3) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	add_child(body)
	_part(body,Vector3.ZERO,size,stone)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _anchor(parent: Node3D, at: Vector3, _unused: bool) -> void:
	var target := Node3D.new()
	target.position = at
	target.set_meta("kind","anchor")
	target.add_to_group("tether_targets")
	parent.add_child(target)
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.52
	torus.rings = 12
	torus.ring_segments = 20
	mesh.mesh = torus
	mesh.rotation.x = PI/2
	mesh.material_override = gold
	target.add_child(mesh)
