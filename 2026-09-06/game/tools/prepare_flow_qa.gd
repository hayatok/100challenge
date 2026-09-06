extends SceneTree
const Sim=preload("res://core/simulation.gd")
func _init():
	var game=Sim.new()
	for minute in 4320:
		game.step()
		if game.s.visits.any(func(v):return v.state=="browse_queue"):
			var save=FileAccess.open("user://qa-current.save",FileAccess.WRITE)
			save.store_var({"game":game.s,"settings":{}});save.close()
			print("FLOW QA: seed ",game.s.seed," tick ",game.s.tick," normal new shop with no injected actors or commands")
			quit();return
	printerr("No shelf line found in the normal run");quit(1)
