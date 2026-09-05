extends SceneTree
const Sim=preload("res://core/simulation.gd")
func _init():
	var replay=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/replay-staples.json"))
	var game=Sim.new(int(replay.seed))
	var args=OS.get_cmdline_user_args()
	var day=int(args[0]) if not args.is_empty() else 35
	var until=(day-1)*1440+600
	for action in replay.commands:
		if action.tick>until:break
		game.step(int(action.tick)-game.s.tick)
		var error=game.command(action.command,action.args)
		if not error.is_empty():printerr("Replay diverged: ",error);quit(1);return
	game.step(until-game.s.tick)
	var file=FileAccess.open("user://qa-current.save",FileAccess.WRITE)
	file.store_var({"game":game.s,"settings":{}});file.close()
	print("QA snapshot: day ",game.s.day," star ",game.s.star," normal commands only")
	quit()
