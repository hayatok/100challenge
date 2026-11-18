extends SceneTree
var checks := 0
var failures := 0
func require(value: bool, label: String) -> void:
	if not value:
		push_error(label)
		failures += 1
	checks += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var player = load("res://combat/player.gd").new()
	arena.add_child(player)
	player.set_physics_process(false)
	require(player.camera != null,"camera instantiated")
	require(player.guns.size() == 3,"three weapon models")
	player.unlock_weapon(2)
	require(player.weapon == 2,"unlock selects weapon")
	var save: Dictionary = player.snapshot()
	player.restore({"hp":50,"ammo":[3,4,5],"owned":[true,true,true],"weapon":1})
	require(player.hp == 50 and player.weapon == 1 and player.ammo[2] == 5,"restore fields")
	player.restore(save)
	player.set_weapon(0)
	player.ammo[0] = 0
	player._fire()
	require(player.reload_time > 0,"empty MG starts belt swap")
	player._physics_process(2.0)
	require(player.ammo[0] == 120,"MG belt swap prevents softlock")
	player.set_weapon(2)
	player.ammo[2] = 0
	player._fire()
	require(player.weapon == 0,"special empty falls back to MG")
	for kind in range(4):
		var enemy = load("res://combat/enemy.gd").new()
		enemy.setup(kind,player)
		arena.add_child(enemy)
		enemy.position = Vector3(0,0,-5-kind*3)
		enemy.set_physics_process(false)
		require(enemy.model.get_child_count() > 0,"enemy model %d" % kind)
		require(enemy.parts.Head != null and enemy.parts.LegL != null,"animation pivots %d" % kind)
		enemy.receive_shot(5000,enemy.global_position+Vector3.UP,Vector3.FORWARD)
		require(enemy.dead and enemy.collision_layer == 0,"enemy death disables hitbox")
	var boss = load("res://combat/enemy.gd").new()
	boss.setup(3,player)
	arena.add_child(boss)
	boss.position = Vector3(20,0,-5)
	boss.set_physics_process(false)
	var boss_floor := StaticBody3D.new()
	var boss_floor_shape := CollisionShape3D.new()
	var boss_floor_box := BoxShape3D.new()
	boss_floor_box.size = Vector3(8,1,8)
	boss_floor_shape.shape = boss_floor_box
	boss_floor.add_child(boss_floor_shape)
	arena.add_child(boss_floor)
	boss_floor.position = Vector3(20,-0.5,-5)
	await physics_frame
	await physics_frame
	boss.velocity = Vector3.DOWN
	boss.move_and_slide()
	require(not boss._boss_wall_hit(),"boss ground contact is not a wall stun")
	boss._boss_enter("windup",1.3)
	var motion: Dictionary = boss._boss_update(0.5,8,Vector3.FORWARD)
	require(boss.boss_state == "windup" and motion.speed == 0 and boss.boss_arc.visible,"boss readable windup")
	boss._boss_update(0.9,8,Vector3.FORWARD)
	motion = boss._boss_update(0.1,8,Vector3.FORWARD)
	require(boss.boss_state == "charge" and motion.speed > 8,"boss warning becomes dangerous charge")
	require(boss._boss_sweep_hits(boss.global_position+Vector3(0,0,-3)),"sweep hits front inside red arc")
	require(not boss._boss_sweep_hits(boss.global_position+Vector3(0,0,3)),"same-distance rear avoids sweep")
	require(boss._boss_sweep_hits(boss.global_position+Vector3(sin(1.2)*3,0,-cos(1.2)*3)),"sweep inner angle matches tell")
	require(not boss._boss_sweep_hits(boss.global_position+Vector3(sin(1.4)*3,0,-cos(1.4)*3)),"outside red arc avoids sweep")
	boss._boss_enter("sweep_windup",0.1)
	boss._boss_update(0.2,8,Vector3.FORWARD)
	require(boss.boss_state == "sweep","boss charged sweep")
	boss._boss_update(0.6,8,Vector3.FORWARD)
	require(boss.boss_state == "exposed","boss recovery shooting window")
	var before: float = boss.hp
	boss.receive_shot(18,boss.global_position+Vector3(.4,2.05,0),Vector3.FORWARD)
	require(is_equal_approx(before-boss.hp,72),"exposed shoulder rewards accurate shot")
	boss.hp = 350
	boss._boss_update(0.1,8,Vector3.FORWARD)
	require(boss.boss_phase == 2 and boss.boss_state == "phase_turn","half health phase transition")
	boss._boss_update(1.6,8,Vector3.FORWARD)
	require(boss.boss_state == "chain_windup" and boss.boss_chain == 1,"second phase double charge")
	boss.receive_shot(5000,boss.global_position+Vector3.UP,Vector3.FORWARD)
	require(boss.dead and not boss.boss_arc.visible,"boss death removes warning")
	var target_dummy = load("res://combat/enemy.gd").new()
	target_dummy.setup(0,player)
	arena.add_child(target_dummy)
	target_dummy.position = Vector3(0,0,-5)
	target_dummy.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.ammo[0] = 120
	player._fire()
	require(target_dummy.hp < 65,"hitscan damages real physics target")
	var prior_hp: float = target_dummy.hp
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,4,0.3)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	arena.add_child(wall)
	wall.position = Vector3(0,1.5,-2.5)
	await physics_frame
	await physics_frame
	player._fire()
	require(target_dummy.hp == prior_hp,"wall stops hitscan")
	player.configure({"flash":false})
	for slot in range(3):
		player.unlock_weapon(slot)
		player.ammo[slot] = 5
		player._fire()
		player._physics_process(0.01)
		require(not player.flame.visible and player.muzzle.light_energy == 0,"flash off removes weapon %d pulse" % slot)
	player._flare(Vector3(30,2,30))
	var signal_light: OmniLight3D = arena.get_child(arena.get_child_count()-1)
	require(signal_light.light_energy == 0,"flash off flare starts dark")
	await create_timer(0.25).timeout
	require(signal_light.light_energy > 0 and signal_light.light_energy < 0.45,"flash off flare slowly builds dim marker")
	player.receive_damage(1000)
	require(player.dead,"player death")
	print("COMBAT CHECKS: ",checks, " FAILURES: ", failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
