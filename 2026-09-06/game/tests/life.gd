extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Life=preload("res://core/life.gd")
const Sound=preload("res://audio.gd")
var failures=[]
func check(value:bool,message:String):
	if not value and not failures.has(message):failures.append(message);printerr(message)
func _init():call_deferred("run")
func run():
	var sound=Sound.new();root.add_child(sound);await process_frame
	sound.enabled=true;sound.effect("click");sound.effect("good");sound.effect("error")
	check(sound.played_counts.get("good",0)==1 and sound.played_counts.get("error",0)==1,"A click swallowed immediate command feedback")
	for i in 100:sound.effect("click")
	check(sound.played_counts.click==1 and sound.voices.size()==4 and sound.get_child_count()==7,"Repeated effects escaped the cooldown or voice limit")
	var game=Sim.new();sound.observe(game)
	check(game.command("order",{"product":0,"amount":6}).is_empty(),"Normal delivery order failed")
	var seen={"basket":false,"joy":false,"bag":false,"box":false,"umbrella":false}
	while game.s.tick<5800:
		game.step();sound.observe(game)
		for actor in game.s.visits:
			var look=Life.appearance(game,actor)
			check(not (not actor.bought and look.prop.begins_with("bag")),"Unpaid goods became a takeaway bag")
			if look.prop=="basket":seen.basket=true
			if actor.bought:
				if look.pose=="joy":seen.joy=true
				if game.s.tick-Life.purchased_at(game,actor)>=3:
					check(look.pose!="joy","Customer celebrated for the whole walk home");seen.bag=true
				check(Life.appearance(game,actor,false,true).pose!="joy","Reduced motion kept the short celebration")
			check(look.umbrella!=2 or actor.pos.x<0,"Umbrella stayed open inside the shop")
			if look.umbrella==2:seen.umbrella=true
			if game.weather_for(game.s.day)=="雨" and not actor.bought:
				var forgot=actor.duplicate(true);forgot.need="rain"
				check(Life.appearance(game,forgot).umbrella==0,"Umbrella-seeking customer already had an umbrella")
		for staff in game.s.staff:
			if not staff.carry.is_empty():
				check(Life.appearance(game,staff,true).prop=="box","Replenishing staff lost the carried stock");seen.box=true
		if game.s.tick%30==0:await process_frame
	for key in seen:check(seen[key],"Normal shop never demonstrated "+key)
	for kind in ["arrival","sale","delivery"]:check(sound.played_counts.get(kind,0)>0,"Actual event had no sound: "+kind)
	var before=sound.played_counts.duplicate();sound.reset_observer();sound.observe(game)
	check(sound.played_counts==before,"Loading a shop replayed historical sounds")
	print("LIFE: actual new shop through ",game.s.tick," minutes; states=",seen," sounds=",sound.played_counts," failures=",failures.size())
	sound.queue_free();await create_timer(0.3).timeout
	quit(1 if failures else 0)
