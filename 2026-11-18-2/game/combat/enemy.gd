extends CharacterBody3D
signal defeated(enemy: Node3D)
signal feedback(event: String, position: Vector3)
var kind := 0
var target: Node3D
var hp := 65.0
var speed := 1.6
var model: Node3D
var phase := 0.0
var attack_timer := 0.0
var stagger := 0.0
var dead := false
var lure_point := Vector3.ZERO
var lure_time := 0.0
var charge_time := 0.0
var windup := 0.0
var charge_dir := Vector3.ZERO
var charge_cooldown := 5.0
var avoidance_time := 0.0
var avoidance_direction := Vector3.ZERO
var parts := {}
var blood_material: StandardMaterial3D
var boss_state := "hunt"
var boss_timer := 2.2
var boss_phase := 1
var boss_chain := 0
var boss_arc: MeshInstance3D
var weak_light: OmniLight3D
var boss_swept := false

func setup(enemy_kind: int, player: Node3D) -> void:
	kind = clampi(enemy_kind,0,3)
	target = player
	hp = [65.0,48.0,220.0,720.0][kind]
	speed = [1.55,3.6,1.1,1.5][kind]

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 7
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38 if kind < 2 else 0.55
	shape.height = 1.8 if kind < 2 else 2.4
	collider.position.y = shape.height*0.5
	collider.shape = shape
	add_child(collider)
	var path := "res://combat/models/enemy_%d.glb" % kind
	model = load(path).instantiate() if ResourceLoader.exists(path) else Node3D.new()
	add_child(model)
	for part in ["ArmL","ArmR","LegL","LegR","Head","Torso","KneeL","KneeR"]:
		parts[part] = model.find_child(part+"*",true,false)
	phase = randf()*TAU
	charge_cooldown += randf()*3
	blood_material = StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.28,0.018,0.012)
	if kind == 3: _build_boss_tells()

func lure(point: Vector3, seconds: float) -> void:
	lure_point = point
	lure_time = seconds

func receive_shot(damage: float, hit_position: Vector3, direction: Vector3) -> void:
	if dead: return
	var headshot: bool = hit_position.y-global_position.y > (1.5 if kind < 2 else 1.95)
	var local_hit := to_local(hit_position)
	var weak_shoulder: bool = kind == 3 and absf(local_hit.x) > 0.23 and local_hit.y > 1.75
	if kind == 3:
		var exposed_hit: bool = boss_state == "exposed" and (weak_shoulder or local_hit.z > 0.15)
		hp -= damage * (4.0 if exposed_hit else 0.3)
		if exposed_hit: feedback.emit("weak_hit",hit_position)
	else:
		hp -= damage * (1.7 if headshot else 1.0)
	stagger = minf(0.3,damage*0.008)
	velocity += direction * (1.3 if kind < 2 else 0.45)
	feedback.emit("flesh",hit_position)
	_splatter(hit_position,direction)
	if hp <= 0:
		dead = true
		if boss_arc: boss_arc.visible = false
		if weak_light: weak_light.light_energy = 0
		collision_layer = 0
		remove_from_group("enemies")
		defeated.emit(self)
		feedback.emit("kill",global_position)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(model,"rotation:x",-1.5,0.45).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(model,"position:y",0.15,0.45)
		tween.chain().tween_interval(5)
		tween.tween_property(model,"position:y",-2.5,1.0)
		tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target): return
	attack_timer -= delta
	avoidance_time = maxf(0,avoidance_time-delta)
	stagger = maxf(0,stagger-delta)
	lure_time = maxf(0,lure_time-delta)
	charge_cooldown -= delta
	var destination: Vector3 = lure_point if lure_time > 0 else target.global_position
	var offset := destination-global_position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	var travel_speed := speed
	if kind == 2 and charge_cooldown <= 0 and distance > 3 and distance < 12 and windup <= 0 and charge_time <= 0:
		windup = 1.0
		charge_dir = direction
		feedback.emit("charge_warning",global_position)
	if windup > 0:
		windup -= delta
		travel_speed = 0
		if windup <= 0:
			charge_time = 1.0
			charge_cooldown = 6.5
	elif charge_time > 0:
		charge_time -= delta
		direction = charge_dir
		travel_speed = 8
		if is_on_wall(): charge_time = 0
	else:
		direction = _steer(direction)
	if kind == 3:
		var boss_motion := _boss_update(delta,distance,direction)
		direction = boss_motion.direction
		travel_speed = boss_motion.speed
	if stagger > 0 and kind != 3: travel_speed *= 0.2
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*7))
	velocity.x = move_toward(velocity.x,direction.x*travel_speed,delta*12)
	velocity.z = move_toward(velocity.z,direction.z*travel_speed,delta*12)
	velocity.y -= 20*delta
	move_and_slide()
	if kind != 3 and global_position.distance_to(target.global_position) < (1.55 if kind >= 2 else 1.15) and attack_timer <= 0:
		var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,target.global_position+Vector3.UP,1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			if target.has_method("receive_damage"): target.receive_damage([9.0,7.0,23.0,28.0][kind],global_position)
			attack_timer = 1.0
			feedback.emit("attack",global_position)
	phase += delta * travel_speed * 4
	_animate()

func _steer(direction: Vector3) -> Vector3:
	if avoidance_time > 0: return avoidance_direction
	if not _blocked(direction): return direction
	for angle in [0.9,-0.9,1.6,-1.6,2.2,-2.2]:
		var option := direction.rotated(Vector3.UP,angle)
		if not _blocked(option):
			avoidance_direction = option
			avoidance_time = 0.65
			return option
	return direction.rotated(Vector3.UP,1.57)

func _blocked(direction: Vector3) -> bool:
	var side := direction.cross(Vector3.UP).normalized() * (0.3 if kind<2 else 0.45)
	for offset in [-side,Vector3.ZERO,side]:
		var origin: Vector3 = global_position+Vector3.UP*0.25+offset
		var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*1.5,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false

func _animate() -> void:
	var stride := sin(phase)* (0.65 if kind == 1 else 0.35)
	if parts.LegL: parts.LegL.rotation.x = stride
	if parts.LegR: parts.LegR.rotation.x = -stride
	if parts.KneeL: parts.KneeL.rotation.x = -maxf(0,stride)*0.9 - (0.25 if kind==1 else 0.0)
	if parts.KneeR: parts.KneeR.rotation.x = -maxf(0,-stride)*0.9 - (0.25 if kind==1 else 0.0)
	if parts.ArmL: parts.ArmL.rotation.x = -stride - (1.0 if attack_timer > 0.65 else 0.25)
	if parts.ArmR: parts.ArmR.rotation.x = stride - (1.4 if attack_timer > 0.65 else 0.4)
	if parts.Head: parts.Head.rotation.z = sin(phase*0.5)*0.08
	if kind == 3 and boss_state in ["windup","chain_windup","phase_turn","sweep_windup"]:
		if parts.ArmR: parts.ArmR.rotation.x = -2.2
		if parts.ArmL: parts.ArmL.rotation.x = -0.8
	if kind == 3 and boss_state == "sweep":
		if parts.ArmR: parts.ArmR.rotation.z = -1.2 + boss_timer*6
	elif parts.ArmR: parts.ArmR.rotation.z = 0.0
	model.position.y = absf(sin(phase))*0.045
	model.rotation.x = (0.3 if kind == 1 else 0.06) + stagger*1.1 + (0.35 if windup > 0 else 0.0)
	model.rotation.z = sin(phase*0.5)*0.035

func _splatter(point: Vector3, direction: Vector3) -> void:
	for i in range(5):
		var fleck := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE*randf_range(0.025,0.07)
		fleck.mesh = cube
		fleck.material_override = blood_material
		get_parent().add_child(fleck)
		fleck.global_position = point
		var tween := fleck.create_tween()
		tween.tween_property(fleck,"position",point+direction*randf_range(0.2,0.65)+Vector3(randf_range(-0.3,0.3),randf_range(-0.4,0.3),randf_range(-0.3,0.3)),0.22)
		tween.tween_callback(fleck.queue_free)

func _build_boss_tells() -> void:
	boss_arc = MeshInstance3D.new()
	var arc := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0.12,0.035)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for i in range(24):
		var a := lerpf(-1.3,1.3,i/24.0)
		var b := lerpf(-1.3,1.3,(i+1)/24.0)
		var p := Vector3(sin(a)*3.8,0.045,-cos(a)*3.8)
		var q := Vector3(sin(a)*4.15,0.045,-cos(a)*4.15)
		var r := Vector3(sin(b)*4.15,0.045,-cos(b)*4.15)
		var t := Vector3(sin(b)*3.8,0.045,-cos(b)*3.8)
		for vertex in [p,q,r,p,r,t]: arc.surface_add_vertex(vertex)
	arc.surface_end()
	boss_arc.mesh = arc
	add_child(boss_arc)
	boss_arc.visible = false
	weak_light = OmniLight3D.new()
	weak_light.position = Vector3(-0.4,2.05,0)
	weak_light.light_color = Color(1,0.24,0.035)
	weak_light.omni_range = 2.0
	weak_light.light_energy = 0
	add_child(weak_light)

func _boss_enter(state: String, duration: float, event: String = "") -> void:
	boss_state = state
	boss_timer = duration
	boss_swept = false
	if event != "": feedback.emit(event,global_position)

func _boss_wall_hit() -> bool:
	for i in range(get_slide_collision_count()):
		var collider = get_slide_collision(i).get_collider()
		if collider is CollisionObject3D and collider.collision_layer & 1 and absf(get_slide_collision(i).get_normal().y) < 0.5: return true
	return false

func _boss_update(delta: float, distance: float, direction: Vector3) -> Dictionary:
	boss_timer -= delta
	if hp <= 360 and boss_phase == 1:
		boss_phase = 2
		_boss_enter("phase_turn",1.5,"boss_phase")
	boss_arc.visible = boss_state in ["windup","chain_windup","phase_turn","sweep_windup"]
	weak_light.light_energy = 3.0+sin(phase*4) if boss_state == "exposed" else 0.0
	var travel := 0.0
	match boss_state:
		"hunt":
			travel = speed
			if boss_timer <= 0 and distance < 22:
				charge_dir = direction
				boss_chain = 1 if boss_phase == 2 else 0
				_boss_enter("windup",1.3,"boss_warning")
		"windup", "chain_windup":
			direction = charge_dir
			if boss_timer <= 0: _boss_enter("charge",1.55,"boss_charge")
		"phase_turn":
			if boss_timer <= 0:
				charge_dir = direction
				boss_chain = 1
				_boss_enter("chain_windup",0.9,"boss_warning")
		"charge":
			direction = charge_dir
			travel = 8.5 if boss_phase == 1 else 10.0
			if distance < 1.9 and attack_timer <= 0:
				target.receive_damage(28,global_position)
				attack_timer = 1.0
			if _boss_wall_hit():
				_boss_enter("exposed",3.1,"boss_exposed")
			elif boss_timer <= 0:
				if boss_chain > 0:
					boss_chain -= 1
					charge_dir = (target.global_position-global_position).normalized()
					charge_dir.y = 0
					_boss_enter("chain_windup",0.7,"boss_warning")
				else: _boss_enter("sweep_windup",0.65,"boss_warning")
		"sweep_windup":
			if boss_timer <= 0: _boss_enter("sweep",0.45,"boss_sweep")
		"sweep":
			if not boss_swept:
				boss_swept = true
				if distance < 4.0:
					var sight := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,target.global_position+Vector3.UP,1)
					if get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): target.receive_damage(22,global_position)
			if boss_timer <= 0: _boss_enter("exposed",2.0,"boss_exposed")
		"exposed":
			if boss_timer <= 0: _boss_enter("hunt",1.2)
	return {"direction":direction,"speed":travel}
