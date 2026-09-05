extends SceneTree
const Sim=preload("res://core/simulation.gd")
func _initialize():
	var runs=[]
	for seed_number in [1,2,20260905]:
		var s=Sim.new(seed_number);s.start()
		var route=[Vector2(-5,0),Vector2(-5,-4),Vector2(3,-4),Vector2(3,2),Vector2(-2,2),Vector2(-2,-1)]
		var index=0;var ticks=0
		while s.state not in ["won","lost"] and ticks<12000:
			if s.state=="upgrade":
				var choice=0
				if s.hp<75 and "repair" in s.choices:choice=s.choices.find("repair")
				elif "burst" in s.choices:choice=s.choices.find("burst")
				elif "territory" in s.choices:choice=s.choices.find("territory")
				s.choose(choice)
			if s.player.distance_to(route[index])<.24:index=(index+1)%route.size()
			s.step(1.0/60,(route[index]-s.player).normalized());ticks+=1
		runs.append({"seed":seed_number,"state":s.state,"seconds":s.clock,"kills":s.kills,"loops":s.loops,"hp":s.hp})
	print(JSON.stringify(runs));quit()
