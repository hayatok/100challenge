extends SceneTree
# Visual staging only. This tool never writes normal saves and is not campaign completion evidence.
func _init():call_deferred("open_preview")
func open_preview():
	var args=OS.get_cmdline_user_args();var season=clampi(int(args[0]) if args.size()>0 else 0,0,3);var hour=clampi(int(args[1]) if args.size()>1 else 14,0,23)
	var main=load("res://main.tscn").instantiate();root.add_child(main);main.active_save="user://art-preview.save"
	await process_frame
	if args.size()>2 and args[2]=="grown" and FileAccess.file_exists("user://qa-current.save"):
		var data=FileAccess.open("user://qa-current.save",FileAccess.READ).get_var()
		main.sim.s=data.game;main.sim.restore_spatial_state()
	main.sim.s.day=season*14+1+clampi(int(args[3]) if args.size()>3 else 0,0,13);main.sim.s.tick=(main.sim.s.day-1)*1440+posmod(hour*60-360,1440)
	main.sim.s.result="";main.sim.s.effects=[];main.sim.s.practice=false;main.sim.s.won=false
	for fixture in main.sim.s.fixtures:fixture.ready=0
	main.close_modal();main.paused=true;main.refresh();main.refresh_sidebar()
	main.notice("作画確認用：時刻と季節を設定した展示です。進行の検証には使いません。")
