extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Strategy=preload("res://tests/strategy.gd")
func _init():
	var args=OS.get_cmdline_user_args()
	var target=int(args[0]) if not args.is_empty() else 9
	var game=Sim.new();var strategy=Strategy.new(args[1] if args.size()>1 else "staples")
	while game.s.day<target and game.s.result.is_empty():
		strategy.update(game);game.step(480);strategy.update(game);game.step(960)
	var save=FileAccess.open("user://qa-current.save",FileAccess.WRITE)
	save.store_var({"game":game.s,"settings":{}});save.close()
	var log=FileAccess.open("res://../docs/beta-qa-actions-"+str(target)+"-"+strategy.style+".json",FileAccess.WRITE)
	log.store_string(JSON.stringify({"seed":game.s.seed,"day":game.s.day,"commands":strategy.commands},"\t"));log.close()
	print("CITY QA: day ",game.s.day," star ",game.s.star," cash ",game.s.cash,"; normal simulation and commands")
	quit()
