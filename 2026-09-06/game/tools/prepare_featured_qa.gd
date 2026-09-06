extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Policy=preload("res://tests/strategy.gd")

func save_scene(state:Dictionary,path:String):
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var({"game":state,"settings":{}});file.close()

func _init():
	var game=Sim.new();var policy=Policy.new("morning")
	var candidates={13:{},53:{}};var results={}
	while game.s.day<=20 and game.s.result.is_empty() and results.size()<2:
		if game.s.tick%1440 in [0,480]:
			policy.update(game)
			if game.s.star>=1:
				for pair in [[1,13],[5,53]]:
					if game.fixture(pair[0]).product!=pair[1]:policy.do(game,"assign",{"fixture":pair[0],"product":pair[1]})
					if int(game.s.targets.get(pair[1],0))!=18:policy.do(game,"target",{"product":pair[1],"amount":18})
					if game.total_stock(pair[1])<6:policy.do(game,"order",{"product":pair[1],"amount":6})
		game.step()
		for v in game.s.visits:
			for product in [13,53]:
				if results.has(product):continue
				if v.state=="browsing" and v.wanted==product and not candidates[product].has(v.id):candidates[product][v.id]=game.s.duplicate(true)
				if not v.bought or not v.get("purchase",{}).get("products",[]).has(product) or not candidates[product].has(v.id):continue
				var before=candidates[product][v.id]
				save_scene(before,"user://qa-featured-"+str(product)+"-before.save")
				save_scene(game.s,"user://qa-featured-"+str(product)+"-after.save")
				results[product]={"product":game.products[product].name,"rid":v.rid,"name":game.s.residents[v.rid].name,"visit":v.id,"before_tick":before.tick,"after_tick":game.s.tick,"receipt":game.s.residents[v.rid].history[0]}
				print("FEATURED ",JSON.stringify(results[product]))
		for product in candidates:
			for id in candidates[product].keys():
				if not game.s.visits.any(func(v):return v.id==id):candidates[product].erase(id)
	var file=FileAccess.open("res://../docs/beta-featured-qa-actions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":game.s.seed,"day":game.s.day,"scope":"Normal commands and actual purchases; no injected actors, stock or time","results":results,"commands":policy.commands},"\t"));file.close()
	quit(0 if results.size()==2 else 1)
