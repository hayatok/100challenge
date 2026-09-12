extends SceneTree
var failures: int = 0
var checks: int = 0
var game: KaijuGame
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in count:await physics_frame
func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	current_scene = game
	await ticks(3)
	check(game.get_child_count() > 45,"GUI-authored street has real saved instances")
	check(get_nodes_in_group("targets").size() >= 30,"Encounters exist before gameplay starts")
	check(game.player.position.z > 20,"Authored safe entry is south of town")
	check(not game.running,"Title does not start combat")
	game.start()
	for enemy in get_nodes_in_group("targets"):
		if enemy is TownEnemy:enemy.awareness_radius = 0
	var player := game.player
	player.start_dash()
	check(player.charges == 1,"Dash spends one defensive opportunity")
	player.dash_left = 0
	player.start_dash()
	player.dash_left = 0
	player.start_dash()
	check(player.charges == 0,"Third dash cannot bypass charge limit")
	player.recharge = player.recharge_seconds
	player._physics_process(.016)
	check(player.charges == 1,"Dash charge replenishes")
	player.invulnerable = 0
	var health := game.health
	player.hurt(15,player.position-Vector3.BACK)
	check(game.health == health-15,"Exposed player takes damage")
	player.hurt(15,player.position)
	check(game.health == health-15,"Hit recovery prevents repeated immediate damage")
	var car: TownProp = game.get_node("Car")
	var tank: TownProp = game.get_node("Tank")
	check(not car.edible(0) and car.edible(1),"Growth changes cars from weapon to food")
	check(not tank.edible(0) and tank.edible(2),"Large monster can eat former threat")
	player.position = Vector3(8,0,25)
	car.strike(Vector3.FORWARD,1)
	await ticks(60)
	check(tank.exposed,"GUI-placed car physically collides with the first tank and breaks armour")
	check(tank.exposed and tank.edible(0),"A car impact exposes a tank core to small monster")
	var previous_growth := game.growth
	tank.consume()
	tank.consume()
	check(game.growth == previous_growth+tank.reward,"Capture rewards exactly once")
	game.feed(100,0)
	check(player.stage == 1,"First threshold grows actual character")
	await ticks(65)
	check(game.state == "mutation","Growth reaches deliberate mutation choice")
	game.set_mutation(0)
	check(game.running and not paused and player.mutation == 0,"Mutation resumes gameplay")
	check(player.visual.find_children("MutationPart*", "Node3D", true, false).size() >= 1,"Mutation visibly changes model")
	player.ability_cooldown = 0
	player.ability()
	check(player.ability_cooldown > 0,"Power has an opportunity cost")
	game.feed(340,0)
	check(player.stage == 2,"Second threshold unlocks large monster")
	await ticks(65)
	game.set_mutation(0)
	check(player.evolved,"Growth upgrades selected mutation")
	var animation: AnimationPlayer = player.anim
	for clip in ["idle","walk","run","stop","bite","dash","hurt","grow","joy"]:
		check(animation.has_animation(clip),"Authored animation: "+clip)
	var boss: TownProp = game.get_node("Boss")
	boss.game = game
	var cores: int = boss.cores_left
	boss.strike(Vector3.FORWARD,3)
	check(boss.cores_left == cores,"Boss armour blocks bites outside opening")
	boss.exposed = true
	for i in 3:
		boss.hit_cooldown = 0
		boss.strike(Vector3.FORWARD,1)
	check(boss.cores_left == cores-1 and not boss.exposed,"Three bites remove one core and boss recovers")
	for opening in 2:
		boss.exposed = true
		boss.bites_this_opening = 0
		for bite in 3:
			boss.hit_cooldown = 0
			boss.strike(Vector3.FORWARD,1)
	check(game.state == "result" and not game.running,"Boss defeat completes run")
	print("CHECKS: ",checks,"; FAILURES: ",failures)
	quit(1 if failures else 0)
