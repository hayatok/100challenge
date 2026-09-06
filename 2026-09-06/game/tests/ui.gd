extends SceneTree
var errors=0
var screens=0
func _init():call_deferred("run")
func run():
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	main.active_save="user://ui-verification.save"
	for dimensions in [Vector2i(375,812),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size=dimensions;main.configure_viewport()
		await process_frame;await process_frame
		for screen in ["show_title","open_build","open_products","open_staff","open_residents","open_report","open_management","open_winter","open_calendar","open_help","open_settings"]:
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

	# Empty dialogs cannot prove report navigation: generate real sales and losses.
	while main.sim.s.tick<4320:main.sim.step()
	var reports_before=JSON.stringify(main.sim.s.reports)
	for dimensions in [Vector2i(375,812),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size=dimensions;main.configure_viewport();main.open_staff()
		await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"staff plan with actual sales")
		if not contains_label(main.modal,"平均売上") or find_button(main.modal,"日報で行列・欠品・利益を見る")==null:
			errors+=1;printerr("Staff plan did not expose actual sales and the report action")
		main.open_report(2)
		await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"actual daily report")
		var first=main.sim.s.reports[0];var second=main.sim.s.reports[1]
		if not contains_label(main.modal,"前日比：売上 "+main.signed_money(second.sales-first.sales)):
			errors+=1;printerr("Report comparison did not use the selected day's predecessor")
		main.open_report(1);await process_frame;await process_frame
		var waste=find_button(main.modal,"数量・価格")
		if waste==null:errors+=1;printerr("Natural waste had no adjustment action");continue
		waste.pressed.emit();await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"report product adjustment")
		var ids=first.waste_products.keys();ids.sort_custom(func(a,b):return first.waste_products[a].cost>first.waste_products[b].cost)
		var product=int(ids[0])
		if main.modal_title!=main.sim.products[product].name+"の見直し":errors+=1;printerr("Waste action opened a different product")
		var price=find_class(main.modal,"OptionButton");price.item_selected.emit(0)
		var target=find_class(main.modal,"SpinBox");target.value=4
		if main.sim.s.prices.get(product,1)!=0 or main.sim.s.targets.get(product,0)!=4:errors+=1;printerr("Report adjustment did not change actual price and target")
		find_button(main.modal,"1日目の日報へ戻る").pressed.emit()
		await process_frame;await process_frame
		if contains_label(main.modal,"前日比："):errors+=1;printerr("Return action lost the selected first day")
		main.open_report(3);await process_frame;await process_frame
		var person=find_button(main.modal,"本人を見る")
		if person==null:errors+=1;printerr("Natural lost visit had no resident action");continue
		var expected=main.sim.s.reports[2].lost_visits[0].rid
		person.pressed.emit();await process_frame;await process_frame
		screens+=1;inspect(main,dimensions.x,"report resident")
		if main.selected_id!=expected:errors+=1;printerr("Lost-visit action opened a different resident")
		find_button(main.modal,"3日目の日報へ戻る").pressed.emit()
	if JSON.stringify(main.sim.s.reports)!=reports_before:errors+=1;printerr("Product adjustment rewrote past reports")
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

func contains_label(node:Node,prefix:String) -> bool:
	if node is Label and node.text.begins_with(prefix):return true
	for child in node.get_children():
		if contains_label(child,prefix):return true
	return false
func find_class(node:Node,kind:String):
	if node.get_class()==kind:return node
	for child in node.get_children():
		var found=find_class(child,kind)
		if found!=null:return found
	return null
