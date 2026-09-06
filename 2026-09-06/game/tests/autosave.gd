extends SceneTree
const PATH="user://autosave-verification.save"
var failures=[]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func marker():
	var file=FileAccess.open(PATH,FileAccess.WRITE);file.store_string("paused marker");file.close()
func read_state() -> Dictionary:
	var file=FileAccess.open(PATH,FileAccess.READ)
	if file==null:return {}
	var data=file.get_var();file.close()
	return data.get("game",{}) if data is Dictionary else {}
func _init():call_deferred("run")
func run():
	var main=load("res://main.tscn").instantiate();root.add_child(main);main.active_save=PATH
	main.paused=true
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# A slow frame can pass the old three-minute saving window at 4x speed.
	main.sim.step(1444);main._process(0.6)
	check(read_state().get("tick",0)==1444,"Daily autosave missed a frame beyond the exact day boundary")
	marker()
	for frame in 8:main._process(0.6)
	check(FileAccess.get_file_as_string(PATH)=="paused marker","Paused store repeatedly rewrote the same day")
	main.save_game(false)
	check(read_state().get("day",0)==2,"Manual save stopped working after the daily save")
	main.sim.step(1440);main._process(0.6)
	check(read_state().get("day",0)==3,"The next trading day was not saved")
	# A new shop can reach the same day number as the previous shop.
	main.sim=main.Sim.new(55);main.view.sim=main.sim;main.sim.step(2884);main._process(0.6)
	check(read_state().get("seed",0)==55,"The previous shop's day marker suppressed the new shop's save")
	main.load_game(PATH);marker();main._process(0.6)
	check(FileAccess.get_file_as_string(PATH)=="paused marker","Loading a paused store immediately rewrote its save")
	main.queue_free();await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("AUTOSAVE: day transitions, slow frames, pause, manual save, new shop and reload; ",failures.size()," failures")
	quit(1 if failures else 0)
