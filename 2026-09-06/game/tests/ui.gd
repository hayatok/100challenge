extends SceneTree
var errors=0
var screens=0
func _init():call_deferred("run")
func run():
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	for dimensions in [Vector2i(375,812),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size=dimensions;main.configure_viewport()
		await process_frame;await process_frame
		for screen in ["show_title","open_build","open_products","open_staff","open_residents","open_report","open_calendar","open_help","open_settings"]:
			main.call(screen)
			await process_frame;await process_frame
			screens+=1
			inspect(main,dimensions.x,screen)
	root.size=Vector2i(1440,900);main.configure_viewport();main.close_modal()
	main.on_pick("resident",0)
	await process_frame
	var favorite=find_button(main.sidebar,"来店を知らせる")
	for i in 20:main.refresh()
	if favorite==null or not is_instance_valid(favorite) or not favorite.is_inside_tree():
		errors+=1;printerr("Sidebar refresh replaced an interactive control")
	else:
		favorite.pressed.emit()
		await process_frame
		if not main.sim.s.residents[0].favorite or find_button(main.sidebar,"お気に入りを解除")==null:
			errors+=1;printerr("Favorite action did not persist")
	print("UI: ",screens," screens, ",errors," horizontal overflow failures")
	quit(1 if errors else 0)
func inspect(node:Node,width:int,screen:String):
	if node is Control and not node.is_visible_in_tree():return
	if node is Button or node is OptionButton or node is SpinBox or node is LineEdit:
		var rect=node.get_global_rect()
		if rect.position.x < -0.5 or rect.end.x>width+0.5:
			errors+=1;printerr("OVERFLOW ",screen," width ",width," ",node.get_class()," ",node.get("text")," ",rect)
	for child in node.get_children():inspect(child,width,screen)

func find_button(node:Node,text:String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var match_button=find_button(child,text)
		if match_button!=null:return match_button
	return null
