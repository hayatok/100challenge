extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Policy=preload("res://tests/story_strategy.gd")
func _init():
	var args=OS.get_cmdline_user_args();var ids=range(12)
	if "--residents" in args:ids=Array(args[args.find("--residents")+1].split(",")).map(func(id):return int(id))
	var results=[];var failures=0
	for id in ids:
		var game=Sim.new();var policy=Policy.new(id);var stages=[];var previous=0
		while game.s.day<=56 and game.s.result.is_empty() and game.s.residents[id].episode<3:
			if game.s.tick%1440 in [0,480]:policy.update(game)
			game.step()
			var resident=game.s.residents[id]
			if resident.episode!=previous:
				stages.append({"stage":resident.episode,"day":game.s.day,"minute":game.minute(),"cash":game.s.cash,"history":resident.history.duplicate(true)})
				previous=resident.episode
		var r=game.s.residents[id]
		var evidence=r.get("story_evidence",{})
		for chapter in r.episode:
			var req=game.Stories.REQUESTS[id][chapter];var receipts=evidence.get(chapter,[])
			if receipts.size()!=req.get("days",1) or not receipts.all(func(receipt):return game.Stories.matches(req,receipt)):
				failures+=1;printerr("Missing actual receipt evidence for ",id,"/",chapter)
		var result={"id":id,"name":r.name,"episode":r.episode,"day":game.s.day,"star":game.s.star,"cash":game.s.cash,"result":game.s.result,"stages":stages,"evidence":evidence,"recent":r.history,"wanted":policy.wanted,"last_reason":r.last_reason,"commands":policy.commands}
		results.append(result)
		print("STORY CAMPAIGN ",JSON.stringify({"id":id,"episode":r.episode,"day":game.s.day,"cash":game.s.cash,"reason":r.last_reason,"recent":r.history}))
		if r.episode<3:failures+=1
		if "--qa" in args:
			var save=FileAccess.open("user://qa-current.save",FileAccess.WRITE);save.store_var({"game":game.s,"settings":{}});save.close()
	var path="user://story-campaign-probes.json"
	if "--output" in args:path=args[args.find("--output")+1]
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"seed":20260906,"failures":failures,"results":results},"\t"));file.close()
	print("STORY CAMPAIGN: ",results.size()," residents, ",failures," incomplete")
	quit(1 if failures else 0)
