extends SceneTree
const Geo=preload("res://core/loop_geometry.gd")
const Sim=preload("res://core/simulation.gd")
var failures=0
var checks=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1;printerr("FAIL: ",label)
func square() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
func _initialize() -> void:
	check(is_equal_approx(Geo.area(square()),16),"square area")
	var redundant=PackedVector2Array([Vector2(-2,-2),Vector2(0,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
	check(Geo.simplify(redundant).size()==4 and is_equal_approx(Geo.area(Geo.simplify(redundant)),16),"simplification preserves shape and removes redundant points")
	check(Geo.contains(Vector2.ZERO,square()),"inside")
	check(Geo.contains(Vector2(2,0),square()),"boundary included")
	check(not Geo.contains(Vector2(2.1,0),square()),"outside")
	check(Geo.intersection(Vector2.ZERO,Vector2(4,0),Vector2(2,-2),Vector2(2,2)).point==Vector2(2,0),"segment intersection")
	check(Geo.intersection(Vector2.ZERO,Vector2(4,0),Vector2(2,0),Vector2(6,0)).is_empty(),"collinear retrace ignored")
	check(Geo.intersection(Vector2.ZERO,Vector2(1,0),Vector2(2,-1),Vector2(2,1)).is_empty(),"no extrapolation")
	var path=[{"p":Vector2(-2,0),"t":0.0},{"p":Vector2(2,0),"t":1.0},{"p":Vector2(2,4),"t":2.0},{"p":Vector2(0,4),"t":3.0}]
	var poly=Geo.close_loop(path,Vector2(0,-1),4.0)
	check(is_equal_approx(Geo.area(poly),8),"close only enclosed portion")
	check(not Geo.contains(Vector2(-1,2),poly),"old tail excluded")
	for p in path:p.t=3.95
	check(Geo.close_loop(path,Vector2(0,-1),4.0).is_empty(),"recent segments excluded")
	check(Geo.close_loop([{"p":Vector2.ZERO,"t":0}],Vector2.ONE,1).is_empty(),"short trace safe")
	var sim=Sim.new(12);sim.start();sim.enemies.clear();sim.spawn_enemy(Vector2.ZERO);sim.spawn_enemy(Vector2(8,8));sim.rebuild_grid();sim.collect_loop(square())
	check(sim.kills==1 and sim.sources.burst==1,"only inside enemy killed")
	check(is_equal_approx(sim.xp,1.3),"burst XP multiplier exactly once")
	check(sim.regions.size()==1 and is_equal_approx(sim.regions[0].life,8),"territory lifetime")
	var dead=sim.enemies[0];sim.damage(dead,99,"weapon")
	check(sim.kills==1,"simultaneous damage does not duplicate kill")
	for i in 4:sim.collect_loop(square())
	check(sim.regions.size()==3,"oldest territory replaced")
	sim.enemies.clear();sim.pause();var clock=sim.clock;var life=sim.regions[0].life;sim.step(10,Vector2.RIGHT)
	check(sim.clock==clock and sim.regions[0].life==life and sim.player==Vector2.ZERO,"pause freezes world and lifetime")
	sim.resume();sim.xp=30;sim.check_level();clock=sim.clock;sim.step(1,Vector2.RIGHT)
	check(sim.state=="upgrade" and sim.clock==clock,"upgrade freezes time")
	var level=sim.level;sim.choose(0)
	check(sim.level==level+1 and sim.state=="upgrade","queued levels share pause")
	sim.reroll();sim.reroll();sim.reroll();check(sim.rerolls==0,"bounded rerolls")
	sim.choose(-1);check(sim.state=="upgrade","invalid choice ignored")
	var weapon=Sim.new();weapon.start();weapon.enemies.clear();weapon.spawn_enemy(Vector2(8,8));weapon.damage(weapon.enemies[0],99,"weapon")
	check(weapon.xp==0 and weapon.pickups.size()==1 and weapon.pickups[0].value==1,"weapon XP drops at base rate")
	var stale=Sim.new();stale.start();stale.enemies.clear();stale.trail=[{"p":Vector2(8,8),"t":-20}];stale.step(1.0/60,Vector2.ZERO)
	check(stale.trail.size()==1 and stale.trail[0].p==stale.player,"old trace expires safely")
	var cap=Sim.new();for i in 610:cap.spawn_enemy(Vector2(i,0))
	check(cap.enemies.size()==600,"enemy cap")
	var result=Sim.new();result.start();result.clock=179.99;result.hp=0;result.step(.02,Vector2.ZERO)
	check(result.state=="lost","HP zero wins time-limit tie")
	var win=Sim.new();win.start();win.clock=179.99;win.step(.02,Vector2.ZERO)
	check(win.state=="won","rehearsal completes at 180 seconds")
	# Same inputs and seed reproduce state on this engine. No cross-platform bitwise promise.
	var a=Sim.new(42);var b=Sim.new(42);a.start();b.start()
	for i in 360:
		var direction=Vector2.from_angle(i*.02);a.step(1.0/60,direction);b.step(1.0/60,direction)
	check(a.player==b.player and a.enemies==b.enemies and a.xp==b.xp,"seeded replay")
	# Follow the displayed tutorial with real movement: the return must CROSS the old line.
	var guided=Sim.new(5);guided.start();guided.enemies.clear()
	var guide=[Vector2(-5,0),Vector2(-5,-4),Vector2(3,-4),Vector2(3,2),Vector2(-2,2),Vector2(-2,-1)]
	var waypoint=0
	for i in 600:
		if guided.state=="upgrade":guided.choose(0)
		if guided.player.distance_to(guide[waypoint])<.24:waypoint=(waypoint+1)%guide.size()
		guided.step(1.0/60,(guide[waypoint]-guided.player).normalized())
	check(guided.loops>=1,"visible tutorial path produces a real loop within ten seconds")
	var runs=[]
	for seed_number in [101,202,303]:
		var run=Sim.new(seed_number);run.start()
		var waypoints=[Vector2(-6,0),Vector2(-6,-5),Vector2(6,-5),Vector2(6,1),Vector2(-6,1)]
		var target=0;var ticks=0
		while run.state not in ["won","lost"] and ticks<12000:
			if run.state=="upgrade":
				var choice=0
				if run.hp<75 and "repair" in run.choices:choice=run.choices.find("repair")
				elif "burst" in run.choices:choice=run.choices.find("burst")
				elif "territory" in run.choices:choice=run.choices.find("territory")
				run.choose(choice)
			if run.player.distance_to(waypoints[target])<.2:target=(target+1)%waypoints.size()
			run.step(1.0/60,(waypoints[target]-run.player).normalized());ticks+=1
			if not (run.hp>=0 and run.enemies.size()<=600 and run.regions.size()<=3 and is_finite(run.player.x)):
				check(false,"long run invariants");break
		check(run.state in ["won","lost"] and run.loops>=2,"normal input run finishes with enclosures")
		runs.append({"seed":seed_number,"result":run.state,"seconds":run.clock,"loops":run.loops,"kills":run.kills,"level":run.level})
	print(JSON.stringify({"checks":checks,"failures":failures,"runs":runs}))
	quit(1 if failures else 0)
