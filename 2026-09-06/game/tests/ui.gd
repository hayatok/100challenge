extends SceneTree
var errors=0
var screens=0
func _init():call_deferred("run")
func run():
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	for dimensions in [Vector2i(375,812),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size=dimensions;main.configure_viewport()
		await process_frame;await process_frame
		for screen in ["show_title","open_build","open_products","open_staff","open_residents","open_report","open_winter","open_calendar","open_help","open_settings"]:
			main.call(screen)
			await process_frame;await process_frame
			screens+=1
			inspect(main,dimensions.x,screen)
		main.resident_filter="story";main.open_residents()
		await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"story residents");inspect_story_labels(main.modal)
		main.resident_filter="all"
		main.open_order(40)
		await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"direct order")
		main.act("order",{"product":40,"amount":6},func():main.open_order(40))
		await process_frame;await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"order confirmation")
		if main.modal.get_global_rect().end.x>dimensions.x:
			errors+=1;printerr("Order confirmation expanded its modal at ",dimensions)
		main.close_modal()
		var g=main.Guide.state(main.sim.s);g.hidden=false;g.resident=0;g.shelf=0
		g.order={"product":0,"due":480,"expires":1440};g.stocked_tick=-1
		main.refresh()
		await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"opening guide")
		if main.toast.get_global_rect().end.y>dimensions.y+0.5:errors+=1;printerr("Guide pushed controls below the window at ",dimensions)
		g.hidden=true

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
	main.build_kind=0;main.refresh()
	main.on_place(Vector2i(3,7))
	var rejection=main.toast.text
	for i in 20:main.refresh()
	if not "レジ" in rejection or main.toast.text!=rejection:
		errors+=1;printerr("Placement rejection was overwritten by a refresh")
	main.build_kind=-1;main.sim.s.result="deadline";main.show_result();main.open_report();main.close_modal();main.refresh()
	if main.pause_button.text!="結果を見る":errors+=1;printerr("Ending lost its return action")
	main.pause_button.pressed.emit()
	if not main.modal.visible or find_button(main.modal,"期限後の練習として続ける")==null:errors+=1;printerr("Cannot return from report to ending")
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
func inspect_story_labels(node:Node):
	if node is Button and node.text.contains("物語 ") and node.text.ends_with("/3"):
		var font=node.get_theme_font("font");var font_size=node.get_theme_font_size("font_size")
		var style=node.get_theme_stylebox("normal")
		var available=node.size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT)
		if font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>available:
			errors+=1;printerr("Story progress is clipped: ",node.text)
	for child in node.get_children():inspect_story_labels(child)
