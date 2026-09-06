extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Strategy=preload("res://tests/strategy.gd")
func _init():
	var results=[];var failures=0
	var start=0
	var args=OS.get_cmdline_user_args()
	if "--seed-index" in args:start=int(args[args.find("--seed-index")+1])
	var seed_count=1 if "--quick" in args else 10
	if "--seed-count" in args:seed_count=int(args[args.find("--seed-count")+1])
	var styles=["neglect","uniform","markup","staples","morning","sweets","night","fixed_plan"]
	if "--styles" in args:styles=Array(args[args.find("--styles")+1].split(","))
	for seed_index in range(start,start+seed_count):
		for style in styles:
			var game=Sim.new(20260906+seed_index*73);var strategy=Strategy.new(style)
			for _day in 56:
				if style in ["staples","morning","sweets","fixed_plan","night"]:strategy.update(game)
				elif style!="neglect":
					if game.s.day>1:game.command("auto",{"enabled":true})
					if style=="markup":
						for p in range(0,80,10):game.command("price",{"product":p,"level":2})
				game.step(480)
				if style in ["staples","morning","sweets","fixed_plan","night"]:strategy.update(game)
				game.step(960)
				if not game.s.result.is_empty():break
			var result={"seed":game.s.seed,"style":style,"result":game.s.result,"day":game.s.day,"star":game.s.star,"cash":game.s.cash,"metrics":game.review_metrics(),"winter":game.Campaign.metrics(game.s),"commands":strategy.commands.size(),"stories":game.s.residents.slice(0,12).map(func(r):return r.episode),"event_days":game.s.reports.filter(func(r):return r.event!="normal").map(func(r):return {"day":r.day,"event":r.event,"buyers":r.buyers,"visitors":r.visitors,"needs":r.get("purpose_completed",0),"served":r.get("needs_served",0),"event_results":r.get("event_results",{}),"miss":r.miss,"unmet":r.get("unmet_needs",{})})}
			results.append(result);print("RESULT ",JSON.stringify(result))
			if style!="fixed_plan" and (style in ["staples","morning","sweets","night"])!=game.s.won:failures+=1
			if "--record-replays" in args and seed_index==0 and style in ["staples","morning","sweets"]:
				var replay=FileAccess.open("res://../docs/replay-"+style+".json",FileAccess.WRITE)
				replay.store_string(JSON.stringify({"seed":game.s.seed,"commands":strategy.commands},"\t"));replay.close()
				var state=FileAccess.open("user://qa-"+style+".save",FileAccess.WRITE);state.store_var(game.s);state.close()
	var output_path="res://../docs/balance-quick.json" if "--quick" in args else "res://../docs/balance-results.json"
	if "--seed-count" in args:output_path="res://../docs/balance-part-"+str(start)+".json"
	if "--output" in args:output_path=args[args.find("--output")+1]
	var output=FileAccess.open(output_path,FileAccess.WRITE)
	output.store_string(JSON.stringify({"runs":results.size(),"failures":failures,"results":results},"\t"));output.close()
	print("BALANCE: ",results.size()," runs, ",failures," unexpected outcomes")
	quit(1 if failures else 0)
