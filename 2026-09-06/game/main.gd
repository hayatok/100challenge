extends Control
const Sim=preload("res://core/simulation.gd")
const Cat=preload("res://core/catalog.gd")
const Nav=preload("res://core/navigation.gd")
const View=preload("res://store_view.gd")
const Portrait=preload("res://portrait.gd")
const ProductIcon=preload("res://product_icon.gd")
const Sound=preload("res://audio.gd")
var sim=Sim.new()
var view
var sound
var root_box:VBoxContainer
var body:HBoxContainer
var sidebar:VBoxContainer
var side_panel:PanelContainer
var header_stats:Label
var header_cash:Label
var star_label:Label
var pause_button:Button
var speed_buttons=[]
var news:Label
var tip:Label
var toast:Label
var modal:PanelContainer
var modal_content:VBoxContainer
var shade:ColorRect
var modal_title=""
var paused=true
var speed=1
var accum=0.0
var ui_clock=0.0
var selected_kind=""
var selected_id=-1
var build_kind=-1
var build_dir=0
var move_id=-1
var restore_pause=true
var category_filter=0
var resident_filter="all"
var search_text=""
var result_shown=""
var intro=true
var ui_scale=1.0
var rebind=""
var modal_notice:Label
var last_sale=-1
var last_star=0
var sidebar_key=""
var side_updates=[]
var keys={"pause":KEY_SPACE,"build":KEY_B,"products":KEY_P,"report":KEY_R}
const SAVE="user://machiakari-mart.save"
var active_save=SAVE
const INK=Color("254641")
const PAPER=Color("f3ead3")
const MUTED=Color("718176")

func _ready():
	if not OS.has_feature("web") and DisplayServer.get_name()!="headless":
		var scale=DisplayServer.screen_get_scale()
		var usable=DisplayServer.screen_get_usable_rect().size-Vector2i(80,80)
		get_window().size=Vector2i(Vector2(1440,900)*scale).min(usable)
		get_window().move_to_center()
	configure_viewport()
	get_window().size_changed.connect(func():call_deferred("configure_viewport"))
	theme=make_theme()
	sound=Sound.new();add_child(sound)
	build_ui()
	resized.connect(responsive)
	responsive()
	if OS.is_debug_build() and "--qa" in OS.get_cmdline_user_args():active_save="user://qa-current.save"
	show_title()
	if OS.is_debug_build() and "--qa" in OS.get_cmdline_user_args():
		load_game("user://qa-current.save");intro=false;restore_pause=true;close_modal()

func configure_viewport():
	var viewport_size=get_window().size
	if OS.has_feature("web"):
		viewport_size=Vector2i(int(JavaScriptBridge.eval("window.innerWidth")),int(JavaScriptBridge.eval("window.innerHeight")))
	elif DisplayServer.get_name()!="headless":viewport_size=Vector2i(Vector2(viewport_size)/DisplayServer.screen_get_scale())
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	if get_window().content_scale_size!=viewport_size:get_window().content_scale_size=viewport_size

func apply_text_scale(node:Node):
	if node is Label and node.has_meta("base_size"):node.add_theme_font_size_override("font_size",roundi(node.get_meta("base_size")*ui_scale))
	for child in node.get_children():apply_text_scale(child)
func make_theme() -> Theme:
	var t=Theme.new();t.default_font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf");t.default_font_size=roundi(14*ui_scale)
	for type in ["Label","Button","CheckBox","OptionButton","LineEdit","SpinBox"]:t.set_color("font_color",type,INK)
	t.set_color("font_hover_color","Button",INK);t.set_color("font_pressed_color","Button",PAPER)
	t.set_color("font_disabled_color","Button",Color("8d9686"))
	var panel=style(PAPER,INK,2,2)
	t.set_stylebox("panel","PanelContainer",panel)
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,style(Color("eee5cd"),Color("8caa95"),1,2,12,8))
		t.set_stylebox("hover",type,style(Color("f8e1ac"),Color("68927e"),2,2,12,8))
		t.set_stylebox("pressed",type,style(Color("396d5e"),INK,2,2,12,8))
		t.set_stylebox("focus",type,style(Color(0,0,0,0),Color("d68f51"),2,2))
		t.set_stylebox("disabled",type,style(Color("dadccb"),Color("bec5b1"),1,2,12,8))
	t.set_stylebox("normal","LineEdit",style(Color("fffae9"),Color("7d9989"),1,2,10,7))
	t.set_color("font_color","LineEdit",INK);t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_constant("separation","VBoxContainer",9);t.set_constant("separation","HBoxContainer",9)
	return t
func style(bg:Color,border:Color,width:int=1,radius:int=2,px:int=12,py:int=12) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border
	s.set_border_width_all(width);s.set_corner_radius_all(radius)
	s.content_margin_left=px;s.content_margin_right=px;s.content_margin_top=py;s.content_margin_bottom=py
	return s
func label(text:String,parent:Node,font_size:int=14,color:Color=INK) -> Label:
	var l=Label.new();l.text=text;l.set_meta("base_size",font_size);l.add_theme_font_size_override("font_size",roundi(font_size*ui_scale));l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func wrapped(text:String,parent:Node,font_size:int=14,color:Color=INK) -> Label:
	var l=label(text,parent,font_size,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return l
func button(text:String,parent:Node,action:Callable,width:int=0) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(width,40);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;parent.add_child(b)
	if text.length()>24:b.clip_text=true;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size.x=240;b.tooltip_text=text
	b.pressed.connect(func():sound.effect("click");action.call())
	return b
func row(parent:Node) -> HBoxContainer:
	var h=HBoxContainer.new();parent.add_child(h);return h
func flow(parent:Node) -> HFlowContainer:
	var h=HFlowContainer.new();h.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(h);return h
func clear(node:Node):
	for c in node.get_children():node.remove_child(c);c.queue_free()
func divider(parent:Node):
	var h=HSeparator.new();parent.add_child(h)
func money(value:int) -> String:
	var strval=str(absi(value));var out=""
	for i in strval.length():
		if i>0 and (strval.length()-i)%3==0:out+=","
		out+=strval[i]
	return ("−" if value<0 else "")+"¥"+out
func time_string(m:int) -> String:return "%02d:%02d"%[m/60,m%60]

func build_ui():
	var background=ColorRect.new();background.color=Color("1d3d3a");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	root_box=VBoxContainer.new();add_child(root_box);root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_box.offset_left=14;root_box.offset_right=-14;root_box.offset_top=12;root_box.offset_bottom=-12
	var header=PanelContainer.new();header.add_theme_stylebox_override("panel",style(PAPER,Color("152e2b"),2,2,16,10));root_box.add_child(header)
	var top=row(header)
	var brand=VBoxContainer.new();brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(brand)
	wrapped("まちあかりマート",brand,25)
	label("あの人が、今日も来た。",brand,11,MUTED)
	header_stats=label("",top,14);header_stats.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var funds=VBoxContainer.new();top.add_child(funds);label("お店の所持金",funds,10,MUTED);header_cash=label("",funds,24)
	star_label=label("",top,20,Color("b7843e"));star_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;root_box.add_child(body)
	var stage=VBoxContainer.new();stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(stage)
	var scene_panel=PanelContainer.new();scene_panel.add_theme_stylebox_override("panel",style(Color("a5bab0"),Color("102e2a"),2,2,0,0));scene_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage.add_child(scene_panel)
	view=View.new();view.sim=sim;view.custom_minimum_size=Vector2(240,220);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL;scene_panel.add_child(view)
	view.picked.connect(on_pick);view.placed.connect(on_place)
	var timebar=flow(stage)
	pause_button=button("営業をはじめる",timebar,toggle_pause,130)
	for n in [1,2,4]:
		var b=button(str(n)+"倍",timebar,func():speed=n;refresh(),48);b.toggle_mode=true;speed_buttons.append(b)
	button("−",timebar,func():view.zoom=maxf(0.65,view.zoom/1.15),36)
	button("＋",timebar,func():view.zoom=minf(2.2,view.zoom*1.15),36)
	button("中央",timebar,func():view.reset_camera(),50)
	news=label("",timebar,12,Color("e8e4ca"));news.size_flags_horizontal=Control.SIZE_EXPAND_FILL;news.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;news.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	side_panel=PanelContainer.new();side_panel.custom_minimum_size.x=290;body.add_child(side_panel)
	var side_scroll=ScrollContainer.new();side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side_panel.add_child(side_scroll)
	sidebar=VBoxContainer.new();sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;side_scroll.add_child(sidebar)
	var footer=HFlowContainer.new();root_box.add_child(footer)
	for item in [["建設",open_build],["商品",open_products],["スタッフ",open_staff],["住人",open_residents],["経営",open_report]]:
		var b=button(item[0],footer,item[1]);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("手引き",footer,open_help);button("設定",footer,open_settings)
	toast=label("",root_box,12,Color("f6dba7"));toast.custom_minimum_size.y=18;toast.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	shade=ColorRect.new();shade.color=Color(0.04,0.12,0.12,0.52);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.visible=false;add_child(shade)
	modal=PanelContainer.new();modal.visible=false;add_child(modal)
	refresh()
func responsive():
	if root_box==null:return
	var narrow=size.x<900
	side_panel.visible=not narrow
	header_stats.visible=size.x>600;star_label.visible=size.x>700
	if modal!=null:
		var width=minf(920 if modal_title=="まちあかりマート" else 1000,size.x-24);var height=minf(480 if modal_title=="まちあかりマート" else 720,size.y-24)
		modal.position=Vector2((size.x-width)/2,(size.y-height)/2);modal.size=Vector2(width,height)
func _process(delta):
	if not intro and not paused and not modal.visible and sim.s.result.is_empty():
		accum+=minf(delta,0.25)*speed*4
		while accum>=1:sim.step();accum-=1
	view.interp=accum;view.reduced=bool(view.reduced)
	sound.night=sim.minute()<360 or sim.minute()>1140
	ui_clock+=delta
	if ui_clock>0.5:
		ui_clock=0;refresh()
		if not sim.s.effects.is_empty() and sim.s.effects[-1].kind=="good" and sim.s.effects[-1].time!=last_sale:
			last_sale=sim.s.effects[-1].time;sound.effect("sale")
		if sim.s.day>1 and sim.s.tick%1440<3:save_game(false)
	if sim.s.result.is_empty():result_shown=""
	if not sim.s.result.is_empty() and result_shown!=sim.s.result:result_shown=sim.s.result;show_result()
func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:paused=true
func _input(event):
	if rebind.is_empty() or not event is InputEventKey or not event.pressed or event.echo:return
	get_viewport().set_input_as_handled()
	if not rebind.is_empty():
		if event.keycode==KEY_ESCAPE:rebind="";open_settings();return
		if event.keycode in [KEY_1,KEY_2,KEY_4,KEY_Q]:notice("このキーは速度・建設回転に使用中です。");return
		for action in keys:
			if action!=rebind and keys[action]==event.keycode:notice("ほかの操作と重複しています。");return
		keys[rebind]=event.keycode;rebind="";open_settings();notice("キーを変更しました。");return
func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return

	if event.keycode==KEY_ESCAPE:
		if modal.visible:close_modal()
		elif build_kind>=0:build_kind=-1;view.build_kind=-1;move_id=-1;view.move_id=-1;notice("建設を終了しました。");refresh()
		else:paused=true;open_settings()
	elif not modal.visible:
		if event.keycode==keys.pause:toggle_pause()
		elif event.keycode==keys.build:open_build()
		elif event.keycode==keys.products:open_products()
		elif event.keycode==keys.report:open_report()
		elif event.keycode in [KEY_1,KEY_2,KEY_4]:speed={KEY_1:1,KEY_2:2,KEY_4:4}[event.keycode]
		elif event.keycode==KEY_Q:build_dir=(build_dir+1)%4;view.build_dir=build_dir;refresh()
func toggle_pause():
	if build_kind>=0:build_kind=-1;view.build_kind=-1
	paused=not paused;sound.enabled=true;refresh()
func refresh():
	if header_stats==null:return
	var s=sim.s
	header_stats.text=Cat.SEASONS[sim.season()]+"  "+str(s.day)+"日目 ("+Cat.DAYS[(s.day-1)%7]+")\n"+time_string(sim.minute())+"   "+sim.weather_for(s.day)
	header_cash.text=money(s.cash)
	star_label.text="★".repeat(s.star)+"☆".repeat(5-s.star)
	if s.star>last_star:
		last_star=s.star;notice("祝・"+str(s.star)+"つ星！ 仕入れ先・設備・街の住人が広がりました。");sound.effect("good")
	pause_button.text="営業を再開" if paused else "一時停止"
	for i in 3:speed_buttons[i].button_pressed=speed==[1,2,4][i]
	news.text=(str(s.day)+"日 "+time_string(sim.minute())+" · " if size.x<900 else "")+sim.event_for(s.day).name+"  ·  店内 "+str(s.visits.size())+"人"
	if build_kind>=0:toast.text="建設中："+sim.equipment[build_kind].name+" / 店内をクリックして設置 · Qで回転 · Escで終了"
	update_sidebar()
func on_pick(kind:String,id:int):
	selected_kind=kind;selected_id=id;view.selected_kind=kind;view.selected_id=id;sound.effect("click")
	refresh_sidebar()
	if size.x<900 and not kind.is_empty():open_detail()
func on_place(cell:Vector2i):
	var args={"kind":build_kind,"x":cell.x,"y":cell.y,"dir":build_dir}
	if move_id>=0:args.fixture=move_id
	var result=sim.command("move" if move_id>=0 else "place",args)
	if result.is_empty():
		toast.text="設置しました。15分後に使えます。";sound.effect("good")
		if move_id>=0:build_kind=-1;view.build_kind=-1
		move_id=-1;view.move_id=-1
	else:toast.text=result;sound.effect("error")
	refresh_sidebar()
	refresh()
func notice(text:String):
	toast.text=text
	if is_instance_valid(modal_notice):modal_notice.text=text
func act(command:String,args:Dictionary={},rebuild:Callable=Callable()):
	var error=sim.command(command,args)
	var message="設定しました。" if error.is_empty() else error
	sound.effect("good" if error.is_empty() else "error")
	if rebuild.is_valid():rebuild.call()
	notice(message)
	refresh_sidebar()
	refresh()

func update_sidebar():
	var key=selected_kind+":"+str(selected_id)
	if key!=sidebar_key or sidebar.get_child_count()==0:refresh_sidebar()
	for binding in side_updates:
		if is_instance_valid(binding[0]):binding[0].text=binding[1].call()
func live_text(parent:Node,get_text:Callable,font_size:int=14,color:Color=INK) -> Label:
	var l=wrapped(get_text.call(),parent,font_size,color)
	side_updates.append([l,get_text]);return l
func live_stat(parent:Node,title:String,get_text:Callable):
	var h=row(parent);var l=label(title,h,13,MUTED);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var value=label(get_text.call(),h,16);side_updates.append([value,get_text])
func refresh_sidebar():
	sidebar_key=selected_kind+":"+str(selected_id);side_updates=[]
	clear(sidebar)
	if selected_kind=="resident" and selected_id>=0:resident_details(sidebar,selected_id);return
	if selected_kind=="fixture" and selected_id>=0:
		var f=sim.fixture(selected_id)
		if not f.is_empty():fixture_details(sidebar,f);return
	if selected_kind=="staff" and selected_id>=0:
		staff_details(sidebar,selected_id)
		return
	label("本日の営業",sidebar,11,MUTED)
	label("店長の机",sidebar,23)
	divider(sidebar)
	var s=sim.s
	live_stat(sidebar,"売上",func():return money(sim.s.today.sales));live_stat(sidebar,"お買い物",func():return str(sim.s.today.buyers)+" / "+str(sim.s.today.visitors)+"人")
	live_stat(sidebar,"常連",func():return str(sim.regulars())+"人");live_stat(sidebar,"清潔度",func():return str(roundi(sim.s.clean))+"%")
	divider(sidebar)
	label("次の目標",sidebar,11,MUTED)
	live_text(sidebar,goal_text,16)
	live_text(sidebar,tutorial_text,12,Color("7d7459"))
	divider(sidebar)
	label("街のカレンダー",sidebar,11,MUTED)
	for offset in range(1,4):
		live_text(sidebar,func():
			var d=sim.s.day+offset
			return str(d)+"日目 "+sim.weather_for(d)+" / "+sim.event_for(d).name,12)
	button("カレンダーを開く",sidebar,open_calendar)
	divider(sidebar)
	label("店先のひとこと",sidebar,11,MUTED)
	live_text(sidebar,func():return "\n\n".join(sim.s.logs.slice(0,3).map(func(entry):return entry.text)),12,Color("596e5f"))
func stat(parent:Node,title:String,value:String):
	var h=row(parent);var l=label(title,h,13,MUTED);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label(value,h,16)
func goal_text() -> String:
	if sim.s.star==4 and sim.s.review.get("status","")=="active":return "五つ星審査 "+str(sim.s.review.reports.size())+" / 14日\nこの調子で、最後まで。"
	if sim.s.star==4 and sim.s.review.get("status","")=="failed":return "審査未達。経営ノートで条件を確認し、再挑戦しよう。"
	return ["3日連続の黒字を達成\n現在 "+str(sim.s.streak)+" / 3日","常連を8人に\n現在 "+str(sim.regulars())+" / 8人","繁忙日に来客20人・購買率75%以上","増床し、2つの季節で7日計の黒字を出す","14日間の五つ星審査に挑戦","この街の、いつもの店。"][sim.s.star]
func tutorial_text() -> String:
	return ["まず営業をはじめて、お客さんを選んでみましょう。","棚を選ぶと品揃えを変えられます。『商品』で次便を発注しましょう。","注文は14時・翌6時に届きます。倉庫から棚へ運ぶのはスタッフです。","最初のレポートが届きました。売上と利益は別の数字。自動発注も使えます。","昼のレジと補充、どちらが足りない？ シフトと優先担当を見直しましょう。","店の得意分野を育てよう。常連の買い物がヒントになります。"][mini(sim.s.tutorial,5)]
func task_name(task:String) -> String:return {"idle":"店内を見回り","off":"勤務外","depot":"倉庫へ移動","stock":"棚へ補充","register":"レジ","clean":"清掃","rest":"休憩"}.get(task,task)
func staff_details(parent:Node,id:int):
	var w=sim.s.staff[id]
	label("働くひと",parent,11,MUTED);wrapped(w.name,parent,22)
	if parent==sidebar:
		live_text(parent,func():return "担当："+task_name(sim.s.staff[id].task))
		live_text(parent,func():return "レジ %.2f / 補充 %.2f\n疲労 %d%%"%[sim.s.staff[id].register,sim.s.staff[id].stock,sim.s.staff[id].fatigue])
	else:
		wrapped("担当："+task_name(w.task),parent)
		wrapped("レジ %.2f / 補充 %.2f\n疲労 %d%%"%[w.register,w.stock,w.fatigue],parent)
	button("シフトを調整",parent,open_staff)
func resident_details(parent:Node,id:int):
	var r=sim.s.residents[id]
	label("まちの住人  No.%03d"%(id+1),parent,11,MUTED)
	var identity=row(parent);var portrait=Portrait.new();portrait.look=r.look;identity.add_child(portrait)
	var words=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(words)
	wrapped(r.name,words,22)
	wrapped(str(r.age)+"歳 / "+r.gender+" / "+r.job,words,12,MUTED)
	divider(parent)
	wrapped("好き："+Cat.CATEGORIES[r.fav],parent,16)
	wrapped("価格への敏感さ："+["おおらか","ほどほど","かなり慎重"][0 if r.get("price_sensitivity",1.0)<0.95 else (1 if r.get("price_sensitivity",1.0)<1.3 else 2)],parent,12)
	wrapped("よく来る時間："+str(r.hour)+"時ごろ\n予算："+money(r.budget)+"\n待てる時間："+str(r.patience)+"分",parent,13)
	if parent==sidebar:
		live_stat(parent,"来店",func():return str(sim.s.residents[id].visits)+"回")
		live_stat(parent,"常連度",func():return str(roundi(sim.s.residents[id].loyalty))+" / 100")
		live_text(parent,func():return sim.s.residents[id].last_reason,12)
	else:
		stat(parent,"来店",str(r.visits)+"回");stat(parent,"常連度",str(roundi(r.loyalty))+" / 100")
		wrapped(r.last_reason,parent,12)
	button("お気に入りを解除" if r.favorite else "来店を知らせる",parent,func():act("favorite",{"id":id});if_modal_detail())
	if parent==sidebar:live_text(parent,func():return resident_mood(id),14,Color("a9703d"))
	else:wrapped(resident_mood(id),parent,14,Color("a9703d"))
	divider(parent);label("最近の買い物",parent,12,MUTED)
	if parent==sidebar:live_text(parent,func():return history_text(id),12)
	else:wrapped(history_text(id),parent,12)
	if id<12:
		divider(parent);label("小さな物語",parent,12,MUTED)
		if parent==sidebar:live_text(parent,func():return episode_text(id),12)
		else:wrapped(episode_text(id),parent,12)
func resident_mood(id:int) -> String:
	for v in sim.s.visits:
		if v.rid==id:return "いま："+v.mood
	return "いまは街で過ごしています。"
func history_text(id:int) -> String:
	var r=sim.s.residents[id];var lines=[]
	for h in r.history.slice(0,3):lines.append(str(h.day)+"日目  "+money(h.price)+"\n"+"・".join(h.items))
	return "まだお会計していません。" if lines.is_empty() else "\n\n".join(lines)
func episode_text(id:int) -> String:
	var r=sim.s.residents[id];var lines=[]
	for chapter in r.episode:lines.append(Cat.EPISODES[id][chapter*2]+"\n「"+Cat.EPISODES[id][chapter*2+1]+"」")
	return "顔なじみになると、お話を聞けます。" if lines.is_empty() else "\n\n".join(lines)
func if_modal_detail():
	if modal.visible and modal_title=="選択したもの":open_detail()
func fixture_details(parent:Node,f:Dictionary):
	var e=sim.equipment[f.kind]
	label("売り場  No."+str(f.id+1),parent,11,MUTED);wrapped(e.name,parent,22)
	if f.product>=0:
		var p=sim.products[f.product];var icon=ProductIcon.new();icon.product=p;parent.add_child(icon);wrapped(p.name,parent,17)
		if parent==sidebar:
			live_stat(parent,"棚の在庫",func():return str(sim.counts(f.lots))+"個")
			live_stat(parent,"倉庫",func():return str(sim.counts(sim.s.warehouse,p.id))+"個")
		else:
			stat(parent,"棚の在庫",str(sim.counts(f.lots))+"個");stat(parent,"倉庫",str(sim.counts(sim.s.warehouse,p.id))+"個")
		stat(parent,"棚の容量",str(e.capacity)+"枠")
		wrapped(p.note,parent,12,MUTED)
		button("この商品を発注",parent,func():category_filter=p.cat;open_products())
	elif e.capacity>0:wrapped("商品を決めて、売り場をつくろう。",parent)
	if e.capacity>0:button("並べる商品を変更",parent,func():open_assign(f.id))
	if e.kind=="register":
		if parent==sidebar:live_stat(parent,"レジ待ち",func():return str(f.queue.size())+"人")
		else:stat(parent,"レジ待ち",str(f.queue.size())+"人")
		wrapped("店員がレジに着くと会計できます。",parent,12)
	divider(parent)
	button("移動する",parent,func():close_modal();move_id=f.id;view.move_id=f.id;build_kind=f.kind;build_dir=f.dir;view.build_kind=build_kind;view.build_dir=build_dir;paused=true;refresh())
	button("売却 "+money(e.cost/2),parent,func():act("remove",{"fixture":f.id});selected_kind="";refresh())
func open_detail():
	open_modal("選択したもの")
	if selected_kind=="resident":resident_details(modal_content,selected_id)
	elif selected_kind=="staff":staff_details(modal_content,selected_id)
	elif selected_kind=="fixture":
		var f=sim.fixture(selected_id)
		if not f.is_empty():fixture_details(modal_content,f)

func open_modal(title:String):
	if not modal.visible:restore_pause=paused
	paused=true;modal_title=title;shade.visible=true;modal.visible=true;clear(modal)
	var outer=VBoxContainer.new();modal.add_child(outer)
	var head=row(outer);var l=wrapped(title,head,24);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("閉じる ×",head,close_modal)
	divider(outer)
	modal_notice=wrapped("",outer,13,Color("a05b38"));modal_notice.custom_minimum_size.y=20
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
	modal_content=VBoxContainer.new();modal_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(modal_content)
	responsive()
func close_modal():
	rebind=""
	modal.visible=false;shade.visible=false;paused=restore_pause;intro=false;refresh()
func show_title():
	open_modal("まちあかりマート")
	label("あの人が、今日も来た。",modal_content,28)
	wrapped("小さなコンビニから、街の『いつもの店』へ。\n品揃え、発注、棚の配置、働く人。あなたの工夫で、お店の毎日が変わります。",modal_content,17)
	divider(modal_content)
	wrapped("56日間で五つ星を目指します。売れるだけでは黒字になりません。\nお客さんを観察して、欠品・行列・廃棄の原因を見つけましょう。",modal_content,15)
	button("お店を開ける",modal_content,func():intro=false;restore_pause=false;close_modal();sound.enabled=true;sound.effect("open"),180)
	if FileAccess.file_exists(active_save):button("前のお店のつづき",modal_content,func():load_game();intro=false;restore_pause=true;close_modal())
	wrapped("Space：停止  /  1・2・4：速度  /  B：建設  /  P：商品  /  R：経営\n店内ドラッグ：移動  /  ホイール：拡大縮小\n音は開店後に流れます。設定で音量を変えられます。",modal_content,12,MUTED)
func open_build():
	open_modal("建設と増床")
	wrapped("棚の手前の黄色いマスがお客さんの立つ場所。通り道を残して配置しましょう。",modal_content,14)
	var h=row(modal_content)
	button("増床 "+(money([26000,60000][mini(sim.s.tier,1)]) if sim.s.tier<2 else "最大"),h,func():act("expand",{},open_build))
	button("向き："+["南東","南西","北西","北東"][build_dir],h,func():build_dir=(build_dir+1)%4;open_build())
	for e in sim.equipment:
		var r=row(modal_content)
		var l=wrapped(e.name+"\n"+{"shelf":"常温の売り場","cold":"飲料・スイーツにも","hot":"温かいもの","register":"お会計","clean":"清掃効率が1.7倍に","rest":"疲労回復が早くなる","decor":"待てる時間 +2分（大鉢+4分・計8分まで）"}.get(e.kind,"")+ (" / "+str(e.capacity)+"枠" if e.capacity else ""),r,14);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label(money(e.cost),r,15)
		var b=button("配置" if e.unlock<=sim.s.star else "星"+str(e.unlock),r,func():build_kind=e.id;move_id=-1;view.move_id=-1;view.build_kind=e.id;view.build_dir=build_dir;restore_pause=true;close_modal(),70)
		b.disabled=e.unlock>sim.s.star
func open_assign(fid:int):
	var f=sim.fixture(fid)
	if f.is_empty():return
	open_modal("棚に並べる商品")
	wrapped(sim.equipment[f.kind].name+" / 商品を選ぶと今の在庫は倉庫に戻ります。",modal_content)
	for p in sim.products:
		if p.unlock>sim.s.star or not sim.compatible(f,p.id):continue
		button(p.name+"  "+money(sim.selling_price(p.id)),modal_content,func():act("assign",{"fixture":fid,"product":p.id});close_modal())
func tabs(parent:Node,labels:Array,active:int,callback:Callable):
	var flow=HFlowContainer.new();parent.add_child(flow)
	for i in labels.size():
		var b=button(labels[i],flow,func():callback.call(i));b.toggle_mode=true;b.button_pressed=i==active
func open_products():
	open_modal("商品と発注")
	wrapped("次の納品は14時 / 翌6時。注文時に仕入れ代を支払います。棚への補充はスタッフが担当。",modal_content,13,MUTED)
	var h=flow(modal_content)
	button("自動発注："+("入" if sim.s.auto else "切"),h,func():act("auto",{"enabled":not sim.s.auto},open_products))
	label("倉庫 "+str(sim.volume(sim.s.warehouse))+" / "+str(sim.warehouse_capacity())+"枠",h,13)
	var budget_row=flow(modal_content);label("自動発注の日次上限",budget_row,12)
	var budget=SpinBox.new();budget.min_value=1000;budget.max_value=50000;budget.step=1000;budget.value=sim.s.auto_limit;budget.custom_minimum_size.x=130;budget_row.add_child(budget);budget.value_changed.connect(func(v):act("auto_limit",{"amount":int(v)}))
	tabs(modal_content,Cat.CATEGORIES,category_filter,func(i):category_filter=i;open_products())
	for p in sim.products:
		if p.cat!=category_filter:continue
		var card=VBoxContainer.new();modal_content.add_child(card)
		var name_row=row(card);var icon=ProductIcon.new();icon.product=p;name_row.add_child(icon);var title=wrapped(p.name,name_row,17);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label("星"+str(p.unlock)+"で解放" if p.unlock>sim.s.star else "原価 "+money(p.cost),name_row,12,MUTED)
		wrapped(p.note+"  /  期限 "+str(p.life/60)+"時間"+(" / 2枠使用" if p.size==2 else ""),card,12,MUTED)
		if p.unlock>sim.s.star:divider(modal_content);continue
		var controls=flow(card)
		label("店全体 "+str(sim.total_stock(p.id))+"個",controls,13)
		var price=OptionButton.new();controls.add_child(price)
		for level in 3:price.add_item(["安め","標準","高め"][level]+" "+money(roundi(p.price*[0.85,1.0,1.2][level])))
		price.select(int(sim.s.prices.get(p.id,1)));price.item_selected.connect(func(i):act("price",{"product":p.id,"level":i}))
		button("＋6 発注",controls,func():act("order",{"product":p.id,"amount":6},open_products))
		button("＋12 発注",controls,func():act("order",{"product":p.id,"amount":12},open_products))
		var auto_row=row(card);label("自動発注の目標",auto_row,12)
		var spin=SpinBox.new();spin.min_value=0;spin.max_value=100;spin.step=2;spin.value=sim.s.targets.get(p.id,0);spin.custom_minimum_size.x=100;auto_row.add_child(spin);spin.value_changed.connect(func(v):act("target",{"product":p.id,"amount":int(v)}))
		divider(modal_content)
	if not sim.s.orders.is_empty():
		label("納品待ち",modal_content,17)
		for o in sim.s.orders:wrapped(sim.products[o.product].name+" ×"+str(o.amount)+" / あと"+str(o.due-sim.s.tick)+"分",modal_content,12)
func open_staff():
	open_modal("働くひととシフト")
	wrapped("1人2枠まで。レジも補充も人が必要です。昼の行列と棚切れを見て担当を調整しましょう。",modal_content,13,MUTED)
	for w in sim.s.staff:
		var h=row(modal_content);var l=label(w.name,h,18);l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label("店長" if w.id==0 else money(w.wage)+" / 1枠",h,13)
		wrapped("レジ %.2f · 補充 %.2f · 接客 %.2f / %s"%[w.register,w.stock,w.service,task_name(w.task)],modal_content,12,MUTED)
		if not w.hired:button("採用する ¥2,000",modal_content,func():act("hire",{"id":w.id},open_staff));divider(modal_content);continue
		var shifts=flow(modal_content)
		for i in 4:
			var b=button(["朝 6–12","昼 12–18","夜 18–24","深夜 0–6"][i],shifts,func():act("shift",{"id":w.id,"slot":i},open_staff));b.toggle_mode=true;b.button_pressed=w.shifts[i]
		var work=flow(modal_content);label("優先担当",work,12)
		var option=OptionButton.new();work.add_child(option)
		for text in ["自動で切替","レジ優先","補充優先","清掃優先"]:option.add_item(text)
		option.select(["auto","register","stock","clean"].find(w.priority));option.item_selected.connect(func(i):act("priority",{"id":w.id,"value":["auto","register","stock","clean"][i]}))
		button("教育 "+money(1800*(w.training+1)),work,func():act("train",{"id":w.id},open_staff)).disabled=w.training>=3
		divider(modal_content)
func open_residents():
	open_modal("あかり町の住人")
	wrapped("訪問した人の好みと買い物が、品揃えのヒント。常連度35で『いつもの店』になります。",modal_content,13,MUTED)
	var filter_row=flow(modal_content)
	for entry in [["全員","all"],["訪問済み","met"],["常連","regular"],["お気に入り","favorite"]]:
		var b=button(entry[0],filter_row,func():resident_filter=entry[1];open_residents());b.toggle_mode=true;b.button_pressed=resident_filter==entry[1]
	var search=LineEdit.new();search.placeholder_text="名前で検索";search.text=search_text;modal_content.add_child(search)
	var list=VBoxContainer.new();modal_content.add_child(list)
	var populate=func():
		clear(list)
		for r in sim.s.residents:
			if not search.text.is_empty() and not r.name.contains(search.text):continue
			if resident_filter=="met" and r.visits==0:continue
			if resident_filter=="regular" and r.loyalty<35:continue
			if resident_filter=="favorite" and not r.favorite:continue
			var text=r.name+"  /  "+r.job+"  /  "+("まだ会っていない" if r.visits==0 else ("常連" if r.loyalty>=35 else "顔なじみ")+" · 来店"+str(r.visits)+"回")
			button(text,list,func():selected_kind="resident";selected_id=r.id;view.selected_kind="resident";view.selected_id=r.id;open_detail())
		if list.get_child_count()==0:wrapped("該当する住人はいません。",list)
	search.text_changed.connect(func(v):search_text=v;populate.call());populate.call()
func open_report():
	open_modal("経営ノート")
	wrapped(goal_text(),modal_content,19)
	var actions=flow(modal_content)
	button("14日先までの予定",actions,open_calendar)
	if sim.s.star>=4 and sim.s.review.get("status","") not in ["active","passed"]:button("明朝から五つ星審査",actions,func():act("review",{},open_report))
	button("救済融資 ¥20,000",actions,func():act("loan",{},open_report)).disabled=sim.s.loan
	wrapped("必要な固定費："+money(sim.fixed_cost()+sim.wages())+" / 日  ·  倉庫を含む廃棄に注意。",modal_content,13,MUTED)
	if sim.s.debt>0:wrapped(str(sim.s.due)+"日目の返済："+money(sim.s.debt),modal_content,14,Color("a85240"))
	if not sim.s.review.is_empty():
		var m=sim.review_metrics()
		wrapped("五つ星審査："+str(m.days)+" / 14日 · "+{"active":"進行中","passed":"合格","failed":"未達。原因を直して再挑戦！"}.get(sim.s.review.status,"予約中"),modal_content,17)
		for item in [["利益率5%以上","%.1f%%"%(m.margin*100),m.margin>=0.05],["廃棄率8%以下","%.1f%%"%(m.waste*100),m.waste<=0.08],["審査開始時の常連20人以上",str(m.cohort)+"人",m.cohort>=20],["対象の再訪70%以上","%.1f%%"%(m.repeat*100),m.repeat>=0.7],["繁忙日2種で購買率80%以上",str(m.events)+"種",m.events>=2],["期間来客280人以上",str(m.visitors)+"人",m.visitors>=280],["運転資金を確保",money(sim.s.cash)+" / "+money(m.reserve),sim.s.cash>=m.reserve]]:
			wrapped(("✓ " if item[2] else "○ ")+item[0]+"："+item[1],modal_content,14,Color("42775b") if item[2] else Color("a05b38"))
		wrapped("再訪：開始時点の常連が、審査期間内の別の日に2回以上購入。審査は14日すべてを集計して判定します。",modal_content,12,MUTED)
	divider(modal_content)
	if sim.s.reports.is_empty():wrapped("最初のレポートは翌朝6時に届きます。",modal_content,16)
	var recent_reports=sim.s.reports.slice(maxi(0,sim.s.reports.size()-7)).duplicate();recent_reports.reverse()
	for report in recent_reports:
		label(str(report.day)+"日目 / "+Cat.SEASONS[report.season]+" / "+sim.event_for(report.day).name,modal_content,17)
		stat(modal_content,"売上",money(report.sales));stat(modal_content,"営業利益",money(report.profit));stat(modal_content,"現金増減",money(report.cash_close-report.cash_open))
		wrapped("原価 %s · 廃棄 %s · 固定費 %s · 人件費 %s\n来店 %d人 → 会計 %d人 / 購買率 %.0f%%"%[money(report.cogs),money(report.waste),money(report.fixed),money(report.wages),report.visitors,report.buyers,report.rate*100],modal_content,13)
		var reasons=[]
		for key in report.miss:
			if not str(key).begins_with("p"):reasons.append(str(key)+" "+str(report.miss[key])+"回")
		wrapped("買い物中のつまずき（延べ回数）："+("特になし" if reasons.is_empty() else " / ".join(reasons)),modal_content,13,Color("9b6c4d"))
		var sales=[]
		for pid in report.product_sales:sales.append(sim.products[int(pid)].name+" "+str(report.product_sales[pid])+"個")
		wrapped("売れたもの："+" / ".join(sales),modal_content,12,MUTED)
		var hours=[]
		for hour in range(24):
			if report.hours.has(hour):hours.append(str(hour)+"時 "+money(report.hours[hour]))
		wrapped("時間帯別売上："+" / ".join(hours),modal_content,12,MUTED)
		divider(modal_content)
func open_calendar():
	open_modal("街のカレンダー")
	wrapped("向こう14日間の予告。イベントの前に品揃えと人数を整えましょう。期限は56日目、審査予約は42日目まで。",modal_content,14)
	for day in range(sim.s.day,sim.s.day+14):
		var event=sim.event_for(day)
		label(str(day)+"日目 · "+Cat.SEASONS[sim.season(day)]+" · "+sim.weather_for(day),modal_content,17)
		wrapped(event.name+"\n"+event.detail,modal_content,14)
		divider(modal_content)
func open_help():
	open_modal("店長の手引き")
	for item in [["01  人を見る","お客さんを選ぶと好み・予算・待てる時間が分かります。いつもの人の『買えなかった』が改善のヒント。"],["02  棚と倉庫は別","発注した商品は14時か翌6時に倉庫へ到着。スタッフが棚に補充して初めて買えます。冷たいものは冷蔵、温かいものは保温棚へ。"],["03  売上と利益は別","売上から売れた商品の原価・廃棄・固定費・人件費を引いたものが利益。発注は現金を減らします。毎朝6時のレポートで両方を見ましょう。"],["04  人も時間も有限","1人2枠までのシフト。レジを増やしても店員がいなければ動きません。補充・清掃・休憩にも人と時間が必要。"],["05  配置で変わる経営","設備を選んで移動できます。向きを変えると利用面も変化。通路を短くすれば、急いでいる人も買いやすくなります。"],["06  星を育てる","3日連続黒字→常連8人→繁忙日の購買率75%→増床と2季節の黒字→14日間の最終審査。期限は56日。"],["07  自動化は店長の方針","自動発注は目標在庫を補うだけ。季節やお客さんに合わせて目標を変えるのはあなたです。"],["08  負けからの一手","資金不足では時間が止まります。設備売却、シフト削減、一度だけの融資で再建。期限後は練習として続けられます。"]]:
		label(item[0],modal_content,18);wrapped(item[1],modal_content,15);divider(modal_content)
func open_settings():
	open_modal("設定")
	for entry in [["BGM","music_volume"],["効果音","effects_volume"],["環境音","ambient_volume"]]:
		label(entry[0],modal_content,15);var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=sound.get(entry[1]);slider.custom_minimum_size.y=30;modal_content.add_child(slider);slider.value_changed.connect(func(v):sound.set(entry[1],v))
	var reduced=CheckBox.new();reduced.text="動き・点滅・雨の演出を減らす";reduced.button_pressed=view.reduced;modal_content.add_child(reduced);reduced.toggled.connect(func(v):view.reduced=v)
	var text_row=flow(modal_content);label("文字の大きさ",text_row,15)
	for value in [1.0,1.15,1.3]:button(str(roundi(value*100))+"%",text_row,func():ui_scale=value;theme=make_theme();apply_text_scale(self);open_settings();refresh_sidebar();refresh())
	label("キーボードの割り当て",modal_content,17)
	for entry in [["停止・再開","pause"],["建設","build"],["商品","products"],["経営","report"]]:
		button(entry[0]+"："+OS.get_keycode_string(keys[entry[1]]),modal_content,func():rebind=entry[1];notice("割り当てるキーを押してください。Escで取り消し。"))
	button("ゲームを保存",modal_content,func():save_game(true))
	button("タイトルへ戻る",modal_content,func():save_game(false);intro=true;show_title())
	button("新しいお店をはじめる",modal_content,confirm_new)
	wrapped("Godot 4.7.2 / まちあかりマート\n人物画像：built-in ImageGen / 日本語フォント：Noto Sans CJK（SIL OFL）\nゲーム内の音楽・効果音はオリジナルの合成音です。",modal_content,12,MUTED)
func confirm_new():
	open_modal("新しいお店")
	wrapped("いまのお店を終えて、新しい店をはじめます。保存は次に保存した時点で置き換わります。",modal_content)
	button("新しいお店をはじめる",modal_content,func():sim=Sim.new(int(Time.get_unix_time_from_system())%1000000);view.sim=sim;selected_kind="";result_shown="";last_star=0;restore_pause=true;close_modal();intro=false)
func save_game(notify:bool):
	var file=FileAccess.open(active_save,FileAccess.WRITE)
	if file==null:notice("保存できませんでした。");return
	file.store_var({"game":sim.s,"settings":{"music":sound.music_volume,"effects":sound.effects_volume,"ambient":sound.ambient_volume,"reduced":view.reduced,"scale":ui_scale,"keys":keys}});file.close()
	if notify:notice("お店を保存しました。");sound.effect("good")
func load_game(path:String=""):
	if path.is_empty():path=active_save
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return
	var value=file.get_var();file.close()
	if typeof(value)!=TYPE_DICTIONARY or not value.has("game") or not value.game.has("residents"):toast.text="お店を読み込めませんでした。";return
	sim.s=value.game;view.sim=sim;last_star=sim.s.star
	var config=value.get("settings",{});sound.music_volume=config.get("music",0.24);sound.effects_volume=config.get("effects",0.45);sound.ambient_volume=config.get("ambient",0.16);view.reduced=config.get("reduced",false)
	ui_scale=config.get("scale",1.0);keys=config.get("keys",keys);theme=make_theme();apply_text_scale(self)
	toast.text="おかえりなさい、店長。";refresh_sidebar();refresh()
func show_result():
	paused=true
	var won=sim.s.result=="won"
	open_modal("この街の、いつもの店。" if won else ("経営を立て直そう" if sim.s.result=="debt" else "最初の一年、お疲れさま。"))
	wrapped("五つ星、おめでとう。" if won else ("所持金が足りません。" if sim.s.result=="debt" else "五つ星には、あと一歩。"),modal_content,26)
	wrapped("名前を覚えたあの人が、今日もあなたの店に来る。\n小さな工夫が、街のいつもの風景になりました。" if won else "経営ノートには、次の一手のヒントが残っています。品揃え、シフト、売り場を見直しましょう。",modal_content,17)
	stat(modal_content,"常連",str(sim.regulars())+"人");stat(modal_content,"お店の資金",money(sim.s.cash))
	button("経営ノートを見る",modal_content,open_report)
	if sim.s.result=="debt":
		button("救済融資で立て直す",modal_content,func():act("loan");result_shown="";close_modal()).disabled=sim.s.loan
		button("設備を売却する",modal_content,func():restore_pause=true;close_modal())
	else:button("この店を続ける" if won else "期限後の練習として続ける",modal_content,func():act("continue");result_shown="";restore_pause=false;close_modal())
	button("新しいお店に挑戦",modal_content,confirm_new)
