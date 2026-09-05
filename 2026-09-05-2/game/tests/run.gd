extends SceneTree
const Geo=preload("res://core/enclosure.gd")
const Sim=preload("res://core/concert.gd")
const Records=preload("res://core/records.gd")
var failures=0
var checks=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1;printerr("FAIL ",message)

func square(x: float = 400, y: float = 300, side: float = 200) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+side,y),Vector2(x+side,y+side),Vector2(x,y+side)])

func _initialize() -> void:
	check(is_equal_approx(Geo.area(square()),40000),"pixel-space polygon area")
	check(Geo.contains(Vector2(400,400),square()),"boundary belongs to enclosure")
	check(not Geo.contains(Vector2(399,400),square()),"outside excluded")
	check(Geo.crossing(Vector2(0,0),Vector2(100,0),Vector2(50,-10),Vector2(50,10)).point==Vector2(50,0),"finite segment crossing")
	check(Geo.crossing(Vector2(0,0),Vector2(100,0),Vector2(50,0),Vector2(150,0)).is_empty(),"collinear retrace is not a loop")
	check(Geo.crossing(Vector2(0,0),Vector2(10,0),Vector2(50,-10),Vector2(50,10)).is_empty(),"no infinite line extension")
	var path=[{"p":Vector2(100,300),"t":0.0},{"p":Vector2(600,300),"t":1.0},{"p":Vector2(600,500),"t":2.0},{"p":Vector2(400,500),"t":3.0}]
	var polygon=Geo.close(path,Vector2(400,250),4)
	check(is_equal_approx(Geo.area(polygon),40000),"old tail excluded from loop")
	check(not Geo.contains(Vector2(200,400),polygon),"tail is not collected")
	for p in path: p.t=3.9
	check(Geo.close(path,Vector2(400,250),4).is_empty(),"recent segments excluded")
	check(Geo.close([],Vector2.ONE,1).is_empty(),"empty trail safe")
	var sim=Sim.new(4);sim.start();sim.enemies.clear();sim.spawn_enemy(Vector2(500,400),0);sim.spawn_enemy(Vector2(800,400),0)
	var enemy=sim.enemies[0]
	sim.collect(square())
	check(sim.kills==1 and is_equal_approx(sim.xp,1.3),"only inside enemy grants one burst reward")
	sim.hit(enemy,99,"shot")
	check(sim.kills==1 and is_equal_approx(sim.xp,1.3),"duplicate hit cannot duplicate reward")
	check(sim.stages.size()==1 and sim.stages[0].life==8,"stage lifetime")
	for i in 4: sim.collect(square())
	check(sim.stages.size()==3,"three stages maximum")
	sim.drops.append({"p":Vector2(500,400),"value":3.0});sim.collect(square());sim.collect(square())
	check(is_equal_approx(sim.xp,4.3),"enclosed dropped XP consumed exactly once")
	sim.pause();var snapshot=[sim.clock,sim.player,sim.stages[0].life];sim.step(1,Vector2.RIGHT)
	check(snapshot==[sim.clock,sim.player,sim.stages[0].life],"pause freezes movement trail and stage time")
	sim.resume();sim.xp=50;sim.check_level();var time=sim.clock;sim.step(.1,Vector2.RIGHT)
	check(sim.state=="upgrade" and sim.clock==time,"upgrade freezes all simulation time")
	var level=sim.level;sim.choose(0)
	check(sim.level==level+1 and sim.state=="upgrade","queued upgrades stay in upgrade state")
	sim.choose(-1);check(sim.level==level+1,"invalid upgrade choice ignored")
	sim.reroll();sim.reroll();sim.reroll();check(sim.rerolls==0,"rerolls bounded")
	check(sim.choices.size()==3 and sim.choices[0]!=sim.choices[1] and sim.choices[1]!=sim.choices[2],"distinct upgrade choices")
	var boss=Sim.new();boss.start();boss.spawn_boss();var hp=boss.boss.hp
	boss.damage_boss(999,"shot");check(boss.boss.hp==hp,"shielded boss rejects damage")
	boss.collect(square(422,350,80));check(boss.boss.open==10,"enclosed terminal opens shield")
	boss.damage_boss(999,"burst");check(is_equal_approx(hp-boss.boss.hp,hp*.08),"boss loop damage capped at eight percent")
	boss.boss.open=.01;boss.update_boss(.02);check(boss.boss.open==0,"shield window expires")
	boss.hp=0;boss.boss.hp=0;boss.step(.01,Vector2.ZERO);check(boss.state=="lost","HP zero takes priority over boss death")
	var win=Sim.new();win.start();win.spawn_boss();win.boss.hp=0;win.step(.01,Vector2.ZERO);check(win.state=="won","boss kill wins")
	var timeout=Sim.new();timeout.start();timeout.clock=209.99;timeout.step(.02,Vector2.ZERO);check(timeout.state=="lost","time alone never wins")
	var inv=Sim.new();inv.start();inv.hurt(10);inv.hurt(10);check(inv.hp==90,"contact invulnerability prevents double damage")
	var cap=Sim.new();for i in 320: cap.spawn_enemy(Vector2.ZERO,0)
	check(cap.enemies.size()==300,"enemy cap")
	var chain=Sim.new();chain.start();chain.enemies.clear();chain.ranks.chain=2
	chain.spawn_enemy(Vector2(500,400),0);chain.spawn_enemy(Vector2(530,400),0);chain.spawn_enemy(Vector2(900,400),0)
	chain.hit(chain.enemies[0],10,"burst")
	check(chain.kills==2 and chain.enemies[2].hp==2,"chain never reaches enemies outside radius")
	var candy=Sim.new();candy.start();candy.enemies.clear();candy.hp=50
	for i in 20: candy.spawn_enemy(Vector2(500,400),0)
	candy.collect(square());check(candy.hp==59,"group recovery capped at nine HP")
	candy.hp=0;candy.enemies.clear()
	for i in 20: candy.spawn_enemy(Vector2(500,400),0)
	candy.collect(square());check(candy.hp==0,"collection cannot revive a defeated player")
	candy.hp=30;candy.make_choices();check("heal" in candy.choices,"low HP offers a recovery choice")
	candy.hp=100;candy.make_choices();check("heal" not in candy.choices,"full HP omits recovery")
	var a=Sim.new(32);var b=Sim.new(32);a.start();b.start()
	for i in 600:
		var direction=Vector2.from_angle(i*.014);a.step(1.0/60,direction);b.step(1.0/60,direction)
	check(a.player==b.player and a.enemies==b.enemies and a.hp==b.hp,"deterministic seed and input replay")
	check(Records.clean_integer("oops")==0 and Records.clean_integer(-20)==0,"invalid record input is sanitized")
	check(Records.clean_integer(NAN)==0 and Records.clean_integer(INF)==0,"non-finite record input is sanitized")
	var guide=Sim.new(8);guide.start();var route=[Vector2(430,490),Vector2(430,310),Vector2(680,310),Vector2(680,540),Vector2(560,540),Vector2(560,450)];var target=0
	for i in 600:
		if guide.state=="upgrade": guide.choose(0)
		if guide.player.distance_to(route[target])<7: target=(target+1)%route.size()
		guide.step(1.0/60,(route[target]-guide.player).normalized())
	check(guide.loops>=1 and guide.best_loop>=1,"displayed guide creates real enclosure and kills")
	var runs=[]
	var normal_wins=0
	for seed_number in [101,202,303,20260906]:
		var run=Sim.new(seed_number);run.start();target=0;var ticks=0
		while run.state not in ["won","lost"] and ticks<13500:
			if run.state=="upgrade":
				var priority=["burst","chain","tempo","stage","magnet","trail","speed","heal"]
				if run.hp<72: priority.push_front("heal")
				for key in priority:
					if key in run.choices: run.choose(run.choices.find(key));break
			if run.player.distance_to(route[target])<7: target=(target+1)%route.size()
			run.step(1.0/60,(route[target]-run.player).normalized());ticks+=1
		check(run.state in ["won","lost"] and run.loops>=2,"normal unassisted run reaches a valid result")
		check(run.enemies.size()<=300 and run.stages.size()<=3 and run.hp>=0,"normal full-run invariants")
		if run.state=="won": normal_wins+=1
		runs.append({"seed":seed_number,"result":run.state,"seconds":run.clock,"hp":run.hp,"loops":run.loops,"kills":run.kills,"level":run.level})
	check(normal_wins>=3,"normal movement and upgrades can defeat boss in at least three fixed seeds")
	print(JSON.stringify({"checks":checks,"failures":failures,"normal_runs":runs}))
	quit(1 if failures else 0)
