extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Strategy=preload("res://tests/strategy.gd")
func _init():
	var args=OS.get_cmdline_user_args()
	if "--profile" in args:profile_crowd();return
	if "--crowd" in args:inspect_crowd();return
	var seed_value=int(args[0]) if args.size()>0 else 20260979
	var style=args[1] if args.size()>1 else "morning"
	var game=Sim.new(seed_value);var strategy=Strategy.new(style)
	while game.s.day<43 and game.s.result.is_empty():
		strategy.update(game);game.step(480);strategy.update(game);game.step(960)
	var still={};var previous={};var stalls=[];var days=[];var peak=-1;var peak_state={}
	while game.s.day<=56 and game.s.result.is_empty():
		var day=game.s.day;var max_active=0;var max_age=0;var states={};var blocked_people=[]
		for minute in 1440:
			if minute in [0,480]:strategy.update(game)
			game.step()
			var active=game.s.visits.filter(func(v):return v.state!="leaving").size()
			max_active=maxi(max_active,active)
			if day==49 and active>peak:
				peak=active;peak_state=game.s.duplicate(true)
			var current={}
			for v in game.s.visits:
				var mark=[v.pos,v.state,v.target]
				still[v.id]=still.get(v.id,0)+1 if previous.get(v.id,[])==mark else 0
				current[v.id]=mark
				max_age=maxi(max_age,game.s.tick-v.since)
				if still[v.id]==60:
					var sample={"day":day,"tick":game.s.tick,"id":v.id,"rid":v.rid,"state":v.state,"pos":str(v.pos),"target":v.target,"wanted":v.wanted,"need":v.need,"age":game.s.tick-v.since,"path":str(v.path),"basket":v.basket.map(func(l):return l.product)}
					stalls.append(sample);blocked_people.append(sample)
					print("STALLED ",JSON.stringify(sample))
			previous=current
			if active==max_active:
				states={}
				for v in game.s.visits:states[v.state]=states.get(v.state,0)+1
		days.append({"day":day,"peak_active":max_active,"oldest_visit":max_age,"peak_states":states,"stalls":blocked_people})
		print("DAY ",day," active=",max_active," oldest=",max_age," states=",states)
	var result={"seed":seed_value,"style":style,"result":game.s.result,"day":game.s.day,"star":game.s.star,"cash":game.s.cash,"winter":game.Campaign.metrics(game.s),"days":days,"stalls":stalls,"commands":strategy.commands.size(),"reports":game.s.reports.filter(func(r):return r.day>=43).map(func(r):return {"day":r.day,"buyers":r.buyers,"visitors":r.visitors,"miss":r.miss,"unmet":r.get("unmet_needs",{})})}
	var output=FileAccess.open("res://../docs/beta-flow-audit-"+str(seed_value)+"-"+style+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"));output.close()
	if "--qa" in args and not peak_state.is_empty():
		var save=FileAccess.open("user://qa-current.save",FileAccess.WRITE);save.store_var({"game":peak_state,"settings":{}});save.close()
		print("QA peak: day ",peak_state.day," minute ",peak_state.tick%1440," active ",peak)
	print("AUDIT ",JSON.stringify(result.winter));quit()

func inspect_crowd():
	var file=FileAccess.open("user://qa-current.save",FileAccess.READ)
	var game=Sim.new();game.s=file.get_var().game;game.rng.state=game.s.rng;file.close();game.restore_spatial_state()
	var previous={};var still={};var buys=game.s.today.buyers
	for minute in 360:
		game.step()
		for v in game.s.visits:
			still[v.id]=still.get(v.id,0)+1 if previous.get(v.id,Vector2i(-99,-99))==v.pos else 0
			previous[v.id]=v.pos
			if still[v.id]==30:
				print("CROWD STALL ",JSON.stringify({"id":v.id,"state":v.state,"pos":str(v.pos),"path":str(v.path),"wait_spot":str(v.get("wait_spot","")),"people":game.s.visits.filter(func(o):return Vector2(o.pos-v.pos).length()<3).map(func(o):return {"id":o.id,"pos":str(o.pos),"state":o.state,"path":str(o.path)}),"staff":game.s.staff.map(func(w):return {"id":w.id,"pos":str(w.pos),"task":w.task,"path":str(w.path)})}))
	print("CROWD purchases=",game.s.today.buyers-buys," remaining=",game.s.visits.size());quit()

func profile_crowd():
	var file=FileAccess.open("user://qa-current.save",FileAccess.READ)
	var game=Sim.new();game.s=file.get_var().game;game.rng.state=game.s.rng;file.close();game.restore_spatial_state()
	var start=game.s.tick;var durations=[]
	for minute in 240:
		var before=Time.get_ticks_usec();game.step();durations.append((Time.get_ticks_usec()-before)/1000.0)
	durations.sort()
	var result={"seed":game.s.seed,"start_tick":start,"minutes":240,"mean_ms":durations.reduce(func(a,b):return a+b,0.0)/240,"p95_ms":durations[227],"max_ms":durations[-1],"scope":"Headless simulation cost from an actual QA save; not rendering FPS"}
	file=FileAccess.open("res://../docs/beta-crowd-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("PROFILE ",JSON.stringify(result));quit()
