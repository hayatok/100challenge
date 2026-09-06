extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Policy=preload("res://tests/strategy.gd")

func adjust(game,policy,mode:String):
	for id in range(4,8):
		var worker=game.s.staff[id]
		if not worker.hired:continue
		var slots=[0,1] if id%2==0 else [2,3]
		var wanted=slots.duplicate()
		if mode=="four" or (mode=="six" and id>=6):wanted=[]
		if mode in ["seasonal","near_till"] and game.s.day<43 and id>=6:wanted=[]
		if mode=="six_peak" and id>=6:wanted=[]
		if mode=="six_peak" and id<6:
			var sales=[0,0,0,0]
			for report in game.s.reports.slice(-3):
				for hour in report.hours:sales[posmod(int(hour)-6,24)/6]+=report.hours[hour]
			wanted=[slots[0] if sales[slots[0]]>=sales[slots[1]] else slots[1]]
		for slot in 4:
			if worker.shifts[slot]!=wanted.has(slot):policy.do(game,"shift",{"id":id,"slot":slot})

func _init():
	var args=OS.get_cmdline_user_args()
	var modes=Array(args[0].split(",")) if not args.is_empty() else ["six","six_peak","four"]
	var style=args[2] if args.size()>2 else "morning"
	var results=[]
	for mode in modes:
		var game=Sim.new();var policy=Policy.new(style);var work={}
		if mode=="near_till":policy.extra_till=Vector2i(8,8)
		while game.s.day<=56 and game.s.result.is_empty():
			if game.s.tick%1440 in [0,480]:policy.update(game);adjust(game,policy,mode)
			game.step()
			if game.s.star>=4:
				for worker in game.s.staff:
					if not game.working(worker):continue
					var key=str(worker.id)+":"+worker.task+(":walking" if not worker.path.is_empty() else "")
					work[key]=work.get(key,0)+1
		var result={"style":style,"mode":mode,"result":game.s.result,"star":game.s.star,"cash":game.s.cash,"review":game.review_metrics(),"winter":game.Campaign.metrics(game.s),"reports":game.s.reports,"work_minutes":work,"commands":policy.commands}
		results.append(result)
		print("STAFFING ",JSON.stringify({"mode":mode,"result":result.result,"star":result.star,"cash":result.cash,"review":result.review,"winter":result.winter}))
	var file=FileAccess.open(args[1] if args.size()>1 else "res://../docs/beta-staffing-probes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":20260906,"scope":"Normal-command shift experiments; production rules unchanged","results":results},"\t"));file.close();quit()
