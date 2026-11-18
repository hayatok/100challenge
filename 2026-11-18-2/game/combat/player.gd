extends CharacterBody3D
signal died
signal feedback(event: String, position: Vector3)
var hp := 100.0
var weapon := 0
var owned := [true, false, false]
var ammo := [120, 24, 10]
var camera: Camera3D
var gun_root: Node3D
var guns: Array[Node3D] = []
var muzzle: OmniLight3D
var flame: MeshInstance3D
var flash_time := 0.0
var belt_rounds: Array[Node3D] = []
var movement := Vector2.ZERO
var shooting := false
var sensitivity := 1.0
var shake := true
var flash := true
var cooldown := 0.0
var hurt_cooldown := 0.0
var recoil := 0.0
var bob := 0.0
var pitch := 0.0
var dead := false
var reload_time := 0.0
var settings_cache := {}

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.55
	camera.near = 0.04
	camera.current = true
	add_child(camera)
	gun_root = Node3D.new()
	camera.add_child(gun_root)
	for index in range(3):
		var path := "res://combat/models/weapon_%d.glb" % index
		var gun: Node3D = load(path).instantiate() if ResourceLoader.exists(path) else Node3D.new()
		gun.scale = Vector3.ONE*0.76
		gun_root.add_child(gun)
		guns.append(gun)
	muzzle = OmniLight3D.new()
	muzzle.light_energy = 0
	muzzle.light_color = Color(1.0, 0.45, 0.12)
	muzzle.omni_range = 7.0
	muzzle.position = Vector3(0.2, -0.15, -0.9)
	camera.add_child(muzzle)
	flame = MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 6
	flame_mesh.rings = 3
	flame_mesh.radius = 0.07
	flame_mesh.height = 0.18
	flame.mesh = flame_mesh
	flame.visible = false
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color(1,0.65,0.13)
	flame.material_override = flame_material
	flame.position = Vector3(0,-0.01,-1.1)
	gun_root.add_child(flame)
	for node in guns[0].find_children("belt_round*", "Node3D",true,false): belt_rounds.append(node)
	configure(settings_cache)
	set_weapon(weapon)

func configure(settings: Dictionary) -> void:
	settings_cache = settings
	sensitivity = float(settings.get("sensitivity", 1.0))
	shake = bool(settings.get("shake", true))
	flash = bool(settings.get("flash", true))
	if camera: camera.fov = float(settings.get("fov", 75.0))

func set_controls(move: Vector2, look: Vector2, fire: bool) -> void:
	movement = move.limit_length()
	shooting = fire
	if dead: return
	rotation.y -= look.x * 0.0023 * sensitivity
	pitch = clampf(pitch - look.y * 0.0023 * sensitivity, -1.35, 1.35)

func set_weapon(slot: int) -> void:
	if slot < 0 or slot > 2 or not owned[slot]: return
	weapon = slot
	for i in range(guns.size()): guns[i].visible = i == weapon
	cooldown = maxf(cooldown, 0.16)
	feedback.emit("switch", global_position)

func unlock_weapon(slot: int) -> void:
	if slot >= 0 and slot < 3:
		owned[slot] = true
		set_weapon(slot)

func refill() -> void:
	ammo = [mini(ammo[0]+90, 240), mini(ammo[1]+12,48), mini(ammo[2]+5,20)]
	feedback.emit("reload", global_position)

func give_health(amount: float) -> void:
	hp = minf(100.0, hp + amount)

func snapshot() -> Dictionary:
	return {"hp":hp, "weapon":weapon, "ammo":ammo.duplicate(), "owned":owned.duplicate()}

func restore(data: Dictionary) -> void:
	hp = clampf(float(data.get("hp",100)), 1, 100)
	var saved_ammo: Array = data.get("ammo", [120,24,10])
	var saved_owned: Array = data.get("owned", [true,false,false])
	if saved_ammo.size() == 3:
		for i in range(3): ammo[i] = clampi(int(saved_ammo[i]), 0, [240,48,20][i])
	if saved_owned.size() == 3:
		for i in range(3): owned[i] = bool(saved_owned[i])
	owned[0] = true
	dead = false
	set_weapon(clampi(int(data.get("weapon",0)),0,2))

func receive_damage(amount: float, source: Vector3 = Vector3.INF) -> void:
	if dead or hurt_cooldown > 0: return
	hurt_cooldown = 0.38
	hp = maxf(0, hp-amount)
	feedback.emit("hurt",source if source.is_finite() else global_position)
	if hp <= 0:
		dead = true
		shooting = false
		died.emit()

func _physics_process(delta: float) -> void:
	if reload_time > 0:
		reload_time = maxf(0, reload_time-delta)
		if reload_time <= 0: ammo[0] = 120
	cooldown = maxf(0,cooldown-delta)
	hurt_cooldown = maxf(0,hurt_cooldown-delta)
	recoil = move_toward(recoil,0,delta*3)
	flash_time = maxf(0,flash_time-delta)
	flame.visible = flash and flash_time > 0
	flame.position.z = [-0.84,-0.70,-0.42][weapon]
	flame.scale = Vector3.ONE * (1.0 if weapon == 0 else 1.6)
	for i in range(belt_rounds.size()):
		belt_rounds[i].rotation.x = sin(bob*2+i)*recoil*0.5
	muzzle.light_energy = (recoil * 3.5) if flash else 0.0
	if dead: return
	var desired := (transform.basis * Vector3(movement.x,0,-movement.y)) * 4.5
	velocity.x = move_toward(velocity.x,desired.x,delta*28)
	velocity.z = move_toward(velocity.z,desired.z,delta*28)
	velocity.y -= 20*delta
	move_and_slide()
	bob += delta * movement.length() * 10
	camera.rotation.x = pitch + (recoil*0.035 if shake else 0.0)
	gun_root.position = Vector3(0.31, -0.25, -0.66) + Vector3(sin(bob)*0.018,abs(cos(bob))*0.015,recoil*0.1 + (0.25*sin(reload_time*2) if reload_time > 0 else 0.0))
	gun_root.rotation = Vector3(recoil*0.11,0,sin(bob)*0.02 + (0.65*sin(reload_time*1.8) if reload_time > 0 else 0.0))
	if shooting and cooldown <= 0 and reload_time <= 0: _fire()

func _fire() -> void:
	if ammo[weapon] <= 0:
		if weapon == 0:
			reload_time = 1.7
			feedback.emit("reload",global_position)
		else:
			feedback.emit("empty",global_position)
			set_weapon(0)
		return
	ammo[weapon] -= 1
	cooldown = [0.105,0.68,0.9][weapon]
	recoil = [0.5,1.0,0.8][weapon]
	flash_time = 0.055
	feedback.emit("fire%d" % weapon,global_position)
	_eject_case()
	var count: int = 9 if weapon == 1 else 1
	for pellet in range(count):
		var spread: float = 0.055 if weapon == 1 else 0.005
		var direction := (-camera.global_basis.z + camera.global_basis.x*randf_range(-spread,spread)+camera.global_basis.y*randf_range(-spread,spread)).normalized()
		var origin := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*70,5,[get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var endpoint: Vector3 = origin + direction * 55
		if not result.is_empty():
			endpoint = result.position
			var victim: Object = result.collider
			if victim.has_method("receive_shot"):
				victim.receive_shot([18.0,11.0,65.0][weapon],endpoint,direction)
				feedback.emit("hit",endpoint)
			if weapon == 2: _flare(endpoint)
		_make_tracer(camera.global_position+camera.global_basis*Vector3(0.28,-0.2,-0.8),endpoint)

func _flare(point: Vector3) -> void:
	feedback.emit("flare",point)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance: float = enemy.global_position.distance_to(point)
		if distance < 4.5: enemy.receive_shot(70*(1-distance/6),point, (enemy.global_position-point).normalized())
		elif distance < 20 and enemy.has_method("lure"): enemy.lure(point,4.0)
	var light := OmniLight3D.new()
	get_parent().add_child(light)
	light.global_position = point+Vector3.UP*0.3
	light.light_color = Color(1,0.1,0.02)
	light.omni_range = 12
	light.light_energy = 4.0 if flash else 0.0
	var tween := light.create_tween()
	if flash:
		tween.tween_property(light,"light_energy",0.0,3.0)
	else:
		# Preserve the persistent lure marker without a sudden lighting pulse.
		tween.tween_property(light,"light_energy",0.45,0.7)
		tween.tween_property(light,"light_energy",0.0,2.3)
	tween.tween_callback(light.queue_free)

func _make_tracer(start: Vector3, end: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var line := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0.7,0.25)
	line.surface_begin(Mesh.PRIMITIVE_LINES,material)
	line.surface_add_vertex(start)
	line.surface_add_vertex(end)
	line.surface_end()
	mesh.mesh = line
	get_parent().add_child(mesh)
	get_tree().create_timer(0.045).timeout.connect(mesh.queue_free)

func _eject_case() -> void:
	if weapon == 2: return
	var casing := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = 0.006
	mesh.height = 0.045
	mesh.radial_segments = 6
	casing.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65,0.4,0.08)
	casing.material_override = material
	get_parent().add_child(casing)
	casing.global_position = camera.global_position+camera.global_basis*Vector3(0.35,-0.25,-0.5)
	var end := casing.global_position+camera.global_basis.x*randf_range(0.6,1.1)+Vector3.DOWN*0.9
	var tween := casing.create_tween().set_parallel(true)
	tween.tween_property(casing,"position",end,0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(casing,"rotation",Vector3(4,2,3),0.42)
	tween.chain().tween_callback(casing.queue_free)
