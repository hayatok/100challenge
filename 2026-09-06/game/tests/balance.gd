extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Strategy=preload("res://tests/strategy.gd")
func _init():
	var results=[];var failures=0
	var start=0
	var args=OS.get_cmdline_user_args()
	if "--seed-index" in args:start=int(args[args.find("--seed-index")+1])
	var seed_count=1 if "--quick" in OS.get_cmdline_user_args() else 10
	for seed_index in range(start,start+seed_count):
		for style in ["neglect","uniform","markup","staples","morning","sweets"]:
			var game=Sim.new(20260906+seed_index*73);var strategy=Strategy.new(style)
			for _day in 56:
				if style in ["staples","morning","sweets"]:strategy.update(game)
				elif style!="neglect":
					if game.s.day>1:game.command("auto",{"enabled":true})
					if style=="markup":
						for p in range(0,80,10):game.command("price",{"product":p,"level":2})
				game.step(480)
				if style in ["staples","morning","sweets"]:strategy.update(game)
				game.step(960)
				if not game.s.result.is_empty():break
			var result={"seed":game.s.seed,"style":style,"result":game.s.result,"day":game.s.day,"star":game.s.star,"cash":game.s.cash,"metrics":game.review_metrics(),"commands":strategy.commands.size()}
			results.append(result);print("RESULT ",JSON.stringify(result))
			if (style in ["staples","morning","sweets"])!=game.s.won:failures+=1
			if seed_index==0 and style in ["staples","morning","sweets"]:
				var replay=FileAccess.open("res://../docs/replay-"+style+".json",FileAccess.WRITE)
				replay.store_string(JSON.stringify({"seed":game.s.seed,"commands":strategy.commands},"\t"));replay.close()
				var state=FileAccess.open("user://qa-"+style+".save",FileAccess.WRITE);state.store_var(game.s);state.close()
	var output=FileAccess.open("res://../docs/balance-quick.json" if seed_count==1 else "res://../docs/balance-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"runs":results.size(),"failures":failures,"results":results},"\t"));output.close()
	print("BALANCE: ",results.size()," runs, ",failures," unexpected outcomes")
	quit(1 if failures else 0)
