extends SceneTree
var rows=[]
var draws=0
var failures=[]
func _init():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":printerr("Render profiling requires a real rendering window.");quit(1);return
	var args=OS.get_cmdline_user_args()
	var path=args[args.find("--output")+1] if "--output" in args else "user://render-profile.json"
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	main.intro=false;main.close_modal();main.paused=true;main.sound.enabled=false
	main.view.world.draw.connect(func():draws+=1)
	for phase in ["paused","playing","paused_after_play"]:
		main.paused=phase!="playing";main.speed=4
		for second in 8:
			var before=draws
			await create_timer(1).timeout
			var row={"phase":phase,"second":second+1,"tick":main.sim.s.tick,"world_redraws":draws-before,"fps":Performance.get_monitor(Performance.TIME_FPS),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"textures":main.view.world.People.cache.size()}
			rows.append(row);print(JSON.stringify(row))
			if "--check" in args and phase!="playing" and second>1 and row.world_redraws!=0:failures.append("Paused scene rebuilt its draw commands")
	if "--check" in args:
		var world=main.view.world;var before=draws
		var shelf=main.sim.s.fixtures.filter(func(f):return f.product>=0)[0]
		main.act("assign",{"fixture":shelf.id,"product":shelf.product})
		await process_frame;await process_frame;await process_frame
		if draws<=before or not shelf.lots.is_empty():failures.append("Paused assortment change was not rendered")
		var old_origin=world.origin
		world.pan+=Vector2(8,0)
		await process_frame;await process_frame;await process_frame
		if world.origin==old_origin:failures.append("Paused camera did not move")
		before=draws;main.on_pick("fixture",shelf.id)
		await process_frame;await process_frame;await process_frame
		if draws<=before or world.selected_id!=shelf.id:failures.append("Paused fixture selection was not rendered")
		var previous=main.view.viewport.size;main.view.zoom_step(1)
		await process_frame;await process_frame;await process_frame
		if main.view.viewport.size==previous:failures.append("Paused zoom did not resize the world")
		if not rows.any(func(row):return row.phase=="playing" and row.tick>0 and row.world_redraws>0):failures.append("Live game failed to animate")
		print("RENDER CHECK: ",failures)
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	quit(1 if failures else 0)
