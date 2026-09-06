extends SceneTree
const Guide=preload("res://core/onboarding.gd")
var failures=[]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func _init():call_deferred("run")
func key(code:int,unicode_value:int=0,meta:bool=false):
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.unicode=unicode_value;event.pressed=pressed;event.meta_pressed=meta
		root.push_input(event)
func run():
	var main=load("res://main.tscn").instantiate();root.add_child(main);main.close_modal();main.paused=true
	main.active_save="user://onboarding-verification.save"
	await process_frame;await process_frame
	check(Guide.state({"day":9}).hidden,"Legacy stores were forced into the opening guide")
	main.on_pick("resident",0)
	check(Guide.stage(main.sim.s)==0,"Unmet resident falsely completed observation")
	while main.sim.s.visits.is_empty() and main.sim.s.tick<1440:main.sim.step()
	check(not main.sim.s.visits.is_empty(),"No natural first visitor")
	main.on_pick("resident",main.sim.s.visits[0].rid)
	check(Guide.stage(main.sim.s)==1,"Actual resident observation was not recorded")
	var shelf=main.sim.s.fixtures.filter(func(f):return f.product==0)[0]
	main.on_pick("fixture",shelf.id);main.open_order(0)
	check(Guide.stage(main.sim.s)==2,"Shelf observation did not lead to ordering")
	var before=main.sim.s.cash
	main.act("order",{"product":0,"amount":101})
	check(Guide.state(main.sim.s).order.is_empty() and main.sim.s.cash==before,"Rejected order advanced the guide or spent money")
	check("1〜100" in main.modal_notice.text,"Rejected order had no visible reason")
	main.act("order",{"product":0,"amount":6},func():main.open_order(0))
	var order=main.sim.s.orders[-1].duplicate(true)
	check(before-main.sim.s.cash==order.cost and "6個" in main.modal_notice.text and main.money(order.cost) in main.modal_notice.text and "14:00" in main.modal_notice.text,"Order receipt did not match actual cost, amount and arrival")
	Guide.update(main.sim)
	check(Guide.stage(main.sim.s)==3 and Guide.state(main.sim.s).stocked_tick<0,"Existing shelf stock was mistaken for delivery")
	while Guide.stage(main.sim.s)<5 and main.sim.s.tick<4320:
		main.sim.step();Guide.update(main.sim)
	var g=Guide.state(main.sim.s)
	check(Guide.stage(main.sim.s)==5 and g.stocked_tick>=order.due,"Natural delivery, restock and sale did not finish the guide")
	print("ONBOARDING actual flow: ",JSON.stringify({"order":order,"stocked_tick":g.stocked_tick,"completed_tick":main.sim.s.tick,"buyer":g.get("buyer",-1),"cash":main.sim.s.cash}))
	main.close_modal();main.paused=true;main.speed=1
	main.speed_buttons[2].grab_focus();key(KEY_SPACE)
	await process_frame
	check(not main.paused and main.speed==1,"Space activated the focused speed button instead of resuming")
	key(KEY_SPACE);await process_frame
	check(main.paused,"Second Space did not pause")
	key(KEY_R,0,true);await process_frame
	check(not main.modal.visible,"Command-R opened the game report")
	main.open_residents();await process_frame;await process_frame
	var search=find_line_edit(main.modal);search.grab_focus();key(KEY_R,114)
	await process_frame
	check(search.text=="r" and main.modal_title=="あかり町の住人","Typing in search triggered a game shortcut")
	key(KEY_ESCAPE);await process_frame
	check(not main.modal.visible,"Escape did not close the modal")
	main.open_products();await process_frame;await process_frame
	var inputs=main.modal.find_children("*","SpinBox",true,false)
	var target=inputs[1].get_line_edit();target.grab_focus();target.edit();await process_frame;target.select_all()
	key(KEY_NONE,0xFF16);await process_frame
	check(target.text=="6" and main.sim.s.targets[0]==18,"Full-width target was not normalized or committed prematurely")
	key(KEY_ENTER);await process_frame
	check(main.sim.s.targets[0]==6 and "6個" in main.modal_notice.text,"Full-width target did not reach the actual model")
	main.open_products();await process_frame;await process_frame
	inputs=main.modal.find_children("*","SpinBox",true,false)
	check(inputs[1].value==6,"Reopening discarded the submitted target")
	var budget=inputs[0].get_line_edit();budget.grab_focus();budget.edit();await process_frame;budget.select_all()
	for digit in [0xFF11,0xFF12,0xFF10,0xFF10,0xFF10]:key(KEY_NONE,digit)
	await process_frame;key(KEY_TAB);await process_frame
	check(main.sim.s.auto_limit==12000,"Full-width budget was discarded on focus change")
	main.open_order(0);await process_frame;await process_frame
	var quantity=main.modal.find_children("*","SpinBox",true,false)[0]
	quantity.get_line_edit().grab_focus();quantity.get_line_edit().edit();await process_frame;quantity.get_line_edit().select_all();key(KEY_NONE,0xFF18);await process_frame;key(KEY_ENTER);await process_frame
	check(quantity.value==8 and main.modal.find_children("*","Button",true,false).any(func(b):return "8個を発注" in b.text and main.money(8*main.sim.products[0].cost) in b.text),"Full-width quantity and order cost diverged")
	print("ONBOARDING / INPUT: ",failures.size()," failures")
	main.queue_free();await create_timer(0.3).timeout
	quit(1 if failures else 0)
func find_line_edit(node:Node):
	if node is LineEdit:return node
	for child in node.get_children():
		var result=find_line_edit(child)
		if result!=null:return result
	return null
