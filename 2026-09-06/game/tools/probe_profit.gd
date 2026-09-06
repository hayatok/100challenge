extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Policy=preload("res://tests/strategy.gd")

func adjust(game,policy,mode:String):
	var s=game.s
	if mode in ["peak_staff","both"] and s.star>=4 and not s.reports.is_empty():
		for pair in [[6,0,1],[7,2,3]]:
			var worker=s.staff[pair[0]]
			if not worker.hired:continue
			var totals=[0,0,0,0]
			for report in s.reports.slice(maxi(0,s.reports.size()-3)):
				for hour in report.hours:totals[posmod(int(hour)-6,24)/6]+=report.hours[hour]
			var peak=pair[1] if totals[pair[1]]>=totals[pair[2]] else pair[2]
			for slot in [pair[1],pair[2]]:
				if worker.shifts[slot] and slot!=peak:policy.do(game,"shift",{"id":worker.id,"slot":slot})
			if not worker.shifts[peak]:policy.do(game,"shift",{"id":worker.id,"slot":peak})
	if mode in ["value_prices","both"] and s.star>=3:
		for fixture in s.fixtures:
			var p=int(fixture.product)
			if p<0 or p%10==0 or game.stock_expiring(p)>2:continue
			if int(s.prices.get(p,1))!=2:policy.do(game,"price",{"product":p,"level":2})

func _init():
	var results=[];var args=OS.get_cmdline_user_args()
	var styles=["morning"] if args.is_empty() else Array(args[0].split(","))
	for style in styles:
		for mode in ["peak_staff","value_prices","both"]:
			var game=Sim.new();var policy=Policy.new(style)
			for day in 56:
				policy.update(game);adjust(game,policy,mode);game.step(480)
				policy.update(game);adjust(game,policy,mode);game.step(960)
				if not game.s.result.is_empty():break
			var result={"seed":game.s.seed,"style":style,"mode":mode,"day":game.s.day,"result":game.s.result,"star":game.s.star,"cash":game.s.cash,"review":game.review_metrics(),"winter":game.Campaign.metrics(game.s),"commands":policy.commands.size()}
			results.append(result);print("PROFIT ",JSON.stringify(result))
	var file=FileAccess.open("res://../docs/beta-profit-probes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"Normal-command strategy experiments; unchanged simulation rules","results":results},"\t"));file.close();quit()
