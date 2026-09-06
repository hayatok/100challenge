extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Life=preload("res://core/life.gd")
func _init():
	var game=Sim.new();var rain="--rain" in OS.get_cmdline_user_args();var inside="--inside" in OS.get_cmdline_user_args();var orders=0
	for minute in 7200:
		if game.s.tick%1440==480:
			for product in [0,10,20,40]:
				if game.command("order",{"product":product,"amount":6}).is_empty():orders+=1
		game.step()
		var ready=game.s.visits.any(func(v):return Life.appearance(game,v).umbrella==(1 if inside else 2) and (not inside or (v.pos.x>=0 and v.since>=(game.s.day-1)*1440))) if rain else game.s.visits.any(func(v):return v.state=="paying")
		if not ready:continue
		var file=FileAccess.open("user://qa-current.save",FileAccess.WRITE)
		file.store_var({"game":game.s,"settings":{}});file.close()
		print("LIFE QA: normal new shop tick ",game.s.tick," rain=",rain," inside=",inside," manual orders=",orders," without injected actors, stock, or time")
		quit();return
	printerr("No natural life scene found");quit(1)
