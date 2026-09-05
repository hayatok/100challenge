extends Node2D
const Concert=preload("res://core/concert.gd")
const Records=preload("res://core/records.gd")
const Art=preload("res://art.gd")
const Stage=preload("res://stage_view.gd")
const INK=Color("111d2b")
const PAPER=Color("fff1d5")
const MINT=Color("93e3d1")
const CORAL=Color("ed7a83")
var font: Font=preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
var art=Art.new()
var sim=Concert.new()
var record=Records.load_record()
var view
var hud: Control
var menu: Control
var health: ProgressBar
var experience: ProgressBar
var boss_health: ProgressBar
var hp_text: Label
var level_text: Label
var time_text: Label
var score_text: Label
var hint: Label
var boss_text: Label
var banner: Label
var menu_stamp=""
var mouse_goal=Vector2(-1,-1)
var toast_time=0.0
var save_ok=true
var qa=""
var qa_index=0
var log_clock=0.0
var tone_cache: Dictionary={}
var sfx: AudioStreamPlayer
var tone_cooldown=0.0
var capture_path=""
var capture_after=2.0
var wall_clock=0.0
var captured=false
var qa_route=[Vector2(430,490),Vector2(430,310),Vector2(680,310),Vector2(680,540),Vector2(560,540),Vector2(560,450)]

func _ready() -> void:
	setup_input()
	view=Stage.new();view.sim=sim;view.art=art;view.reduced=record.reduced;add_child(view)
	var layer=CanvasLayer.new();add_child(layer)
	hud=Control.new();hud.size=Vector2(1280,720);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
	menu=Control.new();menu.size=Vector2(1280,720);menu.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(menu)
	setup_hud()
	sfx=AudioStreamPlayer.new();sfx.volume_db=-19;add_child(sfx)
	get_window().focus_exited.connect(func():
		mouse_goal=Vector2(-1,-1)
		if capture_path.is_empty(): sim.pause())
	for arg in OS.get_cmdline_user_args():
		if OS.is_debug_build() and arg.begins_with("--qa="): qa=arg.trim_prefix("--qa=")
		if arg.begins_with("--capture="): capture_path=arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-after="): capture_after=float(arg.trim_prefix("--capture-after="))
	if OS.is_debug_build():
		if OS.has_feature("web"):
			var value=JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''")
			if value!=null: qa=str(value)
		if not qa.is_empty(): fixture()
	refresh_menu()
	print("LOOP EATER 2D / ",RenderingServer.get_current_rendering_method())

func setup_input() -> void:
	var keys={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN]}
	var axes={"left":[JOY_AXIS_LEFT_X,-1.0],"right":[JOY_AXIS_LEFT_X,1.0],"up":[JOY_AXIS_LEFT_Y,-1.0],"down":[JOY_AXIS_LEFT_Y,1.0]}
	for key in keys:
		var action="walk_"+key
		InputMap.add_action(action,0.22)
		for code in keys[key]:
			var e=InputEventKey.new();e.physical_keycode=code;InputMap.action_add_event(action,e)
		var joy=InputEventJoypadMotion.new();joy.axis=axes[key][0];joy.axis_value=axes[key][1];InputMap.action_add_event(action,joy)

func flat(color: Color, border: Color = Color.TRANSPARENT, margin: int = 12) -> StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=color;box.border_color=border;box.set_border_width_all(1 if border.a>0 else 0);box.set_content_margin_all(margin)
	box.corner_radius_top_left=6;box.corner_radius_top_right=6;box.corner_radius_bottom_left=6;box.corner_radius_bottom_right=6
	return box

func panel(parent: Control, rect: Rect2, color: Color) -> Panel:
	var p=Panel.new();p.position=rect.position;p.size=rect.size;p.add_theme_stylebox_override("panel",flat(color));p.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(p);return p

func label(parent: Control, text: String, rect: Rect2, size_px: int = 20, color: Color = PAPER, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l=Label.new();l.text=text;l.position=rect.position;l.size=rect.size;l.add_theme_font_override("font",font);l.add_theme_font_size_override("font_size",size_px);l.add_theme_color_override("font_color",color)
	l.horizontal_alignment=alignment;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l

func button(parent: Control, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var b=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_focus_color",INK if primary else PAPER);b.add_theme_color_override("font_color",INK if primary else PAPER);b.add_theme_color_override("font_hover_color",INK if primary else PAPER);b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_stylebox_override("normal",flat(MINT if primary else Color("223546"),MINT if primary else Color("506371")))
	b.add_theme_stylebox_override("hover",flat(Color("bcf5e4") if primary else Color("354b5e"),PAPER))
	b.add_theme_stylebox_override("pressed",flat(CORAL,PAPER))
	b.add_theme_stylebox_override("focus",flat(Color(0,0,0,0),CORAL))
	b.pressed.connect(action);parent.add_child(b);return b

func texture(parent: Control, key: String, rect: Rect2, region: Rect2 = Rect2()) -> TextureRect:
	var t=TextureRect.new();t.position=rect.position;t.size=rect.size;t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;t.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if region.has_area(): t.texture=art.atlas(key,region);t.material=art.key_material
	else: t.texture=art.textures.get(key)
	parent.add_child(t);return t

func icon(parent: Control, index: int, rect: Rect2) -> void:
	texture(parent,"fx",rect,Rect2((index%4)*384,(index/4)*341,384,341))

func bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var b=ProgressBar.new();b.add_theme_font_size_override("font_size",1);b.position=rect.position;b.size=rect.size;b.show_percentage=false;b.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background",flat(Color("26394b"),Color.TRANSPARENT,0));b.add_theme_stylebox_override("fill",flat(color,Color.TRANSPARENT,0));parent.add_child(b);b.size=rect.size;return b

func setup_hud() -> void:
	panel(hud,Rect2(18,16,1244,77),Color(.05,.10,.16,.95))
	icon(hud,0,Rect2(32,25,49,49))
	level_text=label(hud,"KOHAKU  /  Lv.1",Rect2(92,23,250,25),18)
	health=bar(hud,Rect2(93,56,196,11),CORAL)
	hp_text=label(hud,"100 / 100",Rect2(299,49,99,22),15)
	time_text=label(hud,"00:00",Rect2(530,21,220,39),31,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	label(hud,"雨灯横丁 / LIVE",Rect2(524,60,232,19),13,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	score_text=label(hud,"0  回収",Rect2(860,28,190,46),20,PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	button(hud,"Ⅱ 停止",Rect2(1123,31,121,45),func():sim.pause(),false)
	experience=bar(hud,Rect2(28,88,1224,4),MINT)
	boss_health=bar(hud,Rect2(403,119,474,9),CORAL)
	boss_text=label(hud,"",Rect2(335,94,610,27),17,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	boss_text.add_theme_stylebox_override("normal",flat(Color(.04,.08,.13,.94),Color.TRANSPARENT,0))
	panel(hud,Rect2(235,673,810,33),Color(.04,.08,.13,.91))
	hint=label(hud,"移動 WASD / 矢印 / クリック・ドラッグ　｜　自分の線を横切って囲む",Rect2(250,677,780,24),16,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	banner=label(hud,"",Rect2(235,140,810,46),25,MINT,HORIZONTAL_ALIGNMENT_CENTER)

func _physics_process(dt: float) -> void:
	wall_clock+=dt;tone_cooldown=maxf(0,tone_cooldown-dt)
	var direction=Input.get_vector("walk_left","walk_right","walk_up","walk_down")
	if direction.length()>0.1: mouse_goal=Vector2(-1,-1)
	elif mouse_goal.x>=0:
		if sim.player.distance_to(mouse_goal)>7: direction=(mouse_goal-sim.player).normalized()
		else: mouse_goal=Vector2(-1,-1)
	if qa=="loop" and sim.state=="running":
		if sim.player.distance_to(qa_route[qa_index])<7: qa_index=(qa_index+1)%qa_route.size()
		direction=(qa_route[qa_index]-sim.player).normalized()
	sim.step(dt,direction)
	for e in sim.events:
		view.add_event(e)
		match e.kind:
			"loop":
				toast("%d体、最前列へ！"%e.count if e.count>0 else "ステージ・ループ！",1.6)
				play_tone(620,.11)
			"upgrade": play_tone(880,.16)
			"hurt": play_tone(140,.09)
			"unlock": toast("シールド解除！ 看板制御機を狙おう",2.8);play_tone(1100,.15)
			"boss": toast("看板制御機が出現！ 光る端子を囲もう",3.5);play_tone(200,.25)
			"evolution": toast("進化！ "+str(e.name),3.5);play_tone(1320,.22)
	sim.events.clear()
	view.pointer=mouse_goal;view.update_view(dt)
	if sim.state=="running": toast_time=maxf(0,toast_time-dt)
	banner.visible=toast_time>0
	hud.visible=sim.state not in ["title","briefing","won","lost"]
	health.value=sim.hp;hp_text.text="%d / 100"%int(sim.hp);experience.max_value=sim.threshold();experience.value=sim.xp
	level_text.text="KOHAKU  /  Lv.%d"%sim.level
	time_text.text="%02d:%02d"%[int(sim.clock)/60,int(sim.clock)%60]
	score_text.text="%d 回収  /  %d pt"%[sim.kills,sim.score]
	boss_health.visible=not sim.boss.is_empty();boss_text.visible=boss_health.visible
	banner.position.y=611 if boss_health.visible else 140
	if not sim.boss.is_empty():
		boss_health.max_value=sim.boss.max_hp;boss_health.value=sim.boss.hp
		boss_text.text="看板制御機  /  端子を囲んでシールド解除" if sim.boss.open<=0 else "シールド解除中！ 残り %.1f秒"%sim.boss.open
	refresh_menu()
	if not qa.is_empty():
		log_clock+=dt
		if log_clock>2:
			log_clock=0
			print("CONCERT_QA ",JSON.stringify({"mode":qa,"state":sim.state,"seconds":sim.clock,"hp":sim.hp,"loops":sim.loops,"kills":sim.kills,"level":sim.level,"enemies":sim.enemies.size()}))
	if not capture_path.is_empty() and not captured and wall_clock>=capture_after:
		captured=true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image()
	var err=image.save_png(capture_path)
	print("SCREENSHOT ",capture_path," ",err)

func toast(text: String, seconds: float) -> void:
	banner.text=text;toast_time=seconds

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if sim.state=="paused": sim.resume()
			else: sim.pause()
			mouse_goal=Vector2(-1,-1)
		elif event.keycode in [KEY_1,KEY_2,KEY_3] and sim.state=="upgrade": sim.choose(event.keycode-KEY_1)
		elif event.keycode==KEY_ENTER:
			if sim.state=="title": sim.state="briefing"
			elif sim.state=="briefing": sim.start()
			elif sim.state in ["won","lost"]: restart()
	if sim.state!="running": return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		mouse_goal=get_global_mouse_position().clamp(Concert.BOUNDS.position,Concert.BOUNDS.end)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		mouse_goal=get_global_mouse_position().clamp(Concert.BOUNDS.position,Concert.BOUNDS.end)
	elif event is InputEventScreenTouch and event.pressed:
		mouse_goal=event.position.clamp(Concert.BOUNDS.position,Concert.BOUNDS.end)
	elif event is InputEventScreenDrag:
		mouse_goal=event.position.clamp(Concert.BOUNDS.position,Concert.BOUNDS.end)

func refresh_menu() -> void:
	var stamp=sim.state+str(sim.level)+str(sim.choices)+str(sim.rerolls)
	if stamp==menu_stamp: return
	var old=menu_stamp
	menu_stamp=stamp
	for child in menu.get_children(): menu.remove_child(child);child.queue_free()
	if sim.state=="running":
		if not qa.is_empty(): label(menu,"検証モード / 記録保存なし / "+qa,Rect2(18,695,700,22),14,CORAL)
		return
	if sim.state in ["won","lost"] and not old.begins_with(sim.state): record_result()
	match sim.state:
		"title": title_menu()
		"briefing": briefing_menu()
		"upgrade": upgrade_menu()
		"paused": pause_menu()
		"won","lost": result_menu()
	if not qa.is_empty(): label(menu,"検証モード / 記録保存なし / "+qa,Rect2(18,695,700,22),14,CORAL)

func title_menu() -> void:
	if art.textures.has("hero"):
		var pic=texture(menu,"hero",Rect2(0,0,1280,720));pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel(menu,Rect2(0,0,547,720),Color(.035,.068,.106,.94))
	label(menu,"YOFUKASHI SIGNAL / CHAPTER 01",Rect2(54,43,472,34),15,MINT)
	label(menu,"LOOP\nEATER",Rect2(48,97,487,223),91,PAPER)
	label(menu,"オフライン・アンコール",Rect2(55,342,470,35),26,CORAL)
	label(menu,"逃げ道を、わたしたちのステージに。",Rect2(55,408,478,33),22,PAPER)
	label(menu,"線をつなぐ。群れを回収。横丁を取り戻す。",Rect2(56,452,466,34),17,Color("adbfcb"))
	var b=button(menu,"雨灯横丁、開演します  →",Rect2(55,531,434,61),func():sim.state="briefing",true)
	b.grab_focus()
	label(menu,"移動だけで戦う  /  1ラン 約3分半",Rect2(56,612,452,26),17,MINT)
	label(menu,"最高同時回収 %d  /  ベスト %d pt"%[record.best,record.score],Rect2(56,655,457,25),15,Color("a1b2c0"))

func briefing_menu() -> void:
	panel(menu,Rect2(0,0,1280,720),Color(.025,.055,.09,.86))
	texture(menu,"player",Rect2(40,60,400,620),Art.PLAYER_RECTS[0])
	label(menu,"01 / 雨灯横丁、開演します",Rect2(458,76,700,48),31,PAPER)
	label(menu,"こはく",Rect2(460,157,680,34),22,CORAL)
	label(menu,"「無観客でも、ここなら歌える。\n　まずは、この通りの明かりを取り戻そう！」",Rect2(460,201,725,87),23)
	label(menu,"りつ  /  帰り道まで、振付です。",Rect2(460,317,720,36),21,MINT)
	label(menu,"移動すると線が残ります。自分の線を横切って、\n敵を囲みましょう。攻撃は自動です。",Rect2(460,367,720,77),22)
	label(menu,"ねむ  /  輪が閉じたら、そこがうちのステージ。",Rect2(460,468,720,34),19,Color("cfdf9d"))
	var b=button(menu,"ライブを始める  →",Rect2(460,552,675,64),func():sim.start(),true);b.grab_focus()
	label(menu,"WASD・矢印・左スティック / クリック・ドラッグでも移動",Rect2(462,636,750,26),16,Color("adbfcb"))

func upgrade_menu() -> void:
	panel(menu,Rect2(0,0,1280,720),Color(.025,.055,.09,.92))
	label(menu,"LEVEL UP / 次のフレーズを選ぼう",Rect2(100,105,1080,50),35,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	label(menu,"時間は止まっています。今の囲み方に、ひとつ足す。",Rect2(100,164,1080,38),20,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	for i in sim.choices.size():
		var key: String=sim.choices[i];var def: Array=Concert.UPGRADES[key]
		var x=106+i*368
		var b=button(menu,"",Rect2(x,244,332,296),func():sim.choose(i),false)
		icon(b,int(def[2]),Rect2(124,25,84,84))
		label(b,str(i+1)+"  "+str(def[0]),Rect2(14,119,304,43),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		var copy=label(b,str(def[1]),Rect2(24,174,284,70),18,Color("d3dee4"));copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(b,"今回だけ回復" if key=="heal" else "Lv.%d → %d"%[sim.ranks[key],sim.ranks[key]+1],Rect2(23,257,286,23),16,MINT,HORIZONTAL_ALIGNMENT_CENTER)
		if i==0: b.grab_focus()
	var roll=button(menu,"候補を交換  /  残り%d"%sim.rerolls,Rect2(452,583,376,52),func():sim.reroll())
	roll.disabled=sim.rerolls<=0
	label(menu,"回収＋連鎖 Lv.2：連鎖花火  /  陣地＋吸引 Lv.2：敵を集めるステージ",Rect2(100,658,1080,28),16,Color("adbfcb"),HORIZONTAL_ALIGNMENT_CENTER)

func pause_menu() -> void:
	panel(menu,Rect2(0,0,1280,720),Color(.025,.055,.09,.84))
	panel(menu,Rect2(395,152,490,429),INK)
	label(menu,"ひと休み",Rect2(440,179,400,62),39,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	label(menu,"帰り道も、線も、そのまま。",Rect2(430,253,420,39),20,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	var b=button(menu,"ライブに戻る",Rect2(451,321,378,60),func():sim.resume(),true);b.grab_focus()
	button(menu,"効果音："+("ON" if record.sound else "OFF"),Rect2(451,401,178,45),func():record.sound=not record.sound;settings_changed())
	button(menu,"演出："+("控えめ" if record.reduced else "通常"),Rect2(650,401,179,45),func():record.reduced=not record.reduced;settings_changed())
	button(menu,"タイトルへ戻る",Rect2(451,488,378,48),func():sim=Concert.new();view.sim=sim;mouse_goal=Vector2(-1,-1))

func result_menu() -> void:
	panel(menu,Rect2(0,0,1280,720),Color(.025,.055,.09,.90))
	texture(menu,"player",Rect2(45,83,368,575),Art.PLAYER_RECTS[0 if sim.state=="won" else 4])
	label(menu,"LIVE CLEAR" if sim.state=="won" else "また、明日のステージで。",Rect2(431,89,784,74),49,MINT if sim.state=="won" else CORAL)
	label(menu,sim.ending,Rect2(435,180,748,51),27)
	label(menu,"「次のライブはいつ？」\n横丁の掲示板に、小さな手書きの紙。" if sim.state=="won" else "こはく「片づけたら、次の作戦を考えよっか」\nねむ「うん。次は、もっと大きく囲もう」",Rect2(435,242,754,77),21,Color("c0cfda"))
	label(menu,"%d pt"%sim.score,Rect2(435,356,376,70),49,PAPER)
	label(menu,"最大同時 %d体  /  囲み %d回\n回収 %d体  /  到達 Lv.%d"%[sim.best_loop,sim.loops,sim.kills,sim.level],Rect2(830,351,366,86),21,MINT)
	var b=button(menu,"もう一度、開演  →",Rect2(437,491,714,62),restart,true);b.grab_focus()
	button(menu,"タイトルへ",Rect2(437,574,243,48),func():sim=Concert.new();view.sim=sim)
	label(menu,"最高記録を保存しました" if save_ok and qa.is_empty() else ("検証モード：記録は保存しません" if not qa.is_empty() else "記録を保存できませんでした"),Rect2(700,576,468,44),16,Color("adbfcb"),HORIZONTAL_ALIGNMENT_RIGHT)

func restart() -> void:
	sim=Concert.new();view.sim=sim;view.effects.clear();mouse_goal=Vector2(-1,-1);qa_index=0;sim.start()

func record_result() -> void:
	if not qa.is_empty(): return
	record.best=maxi(int(record.best),sim.best_loop);record.score=maxi(int(record.score),sim.score)
	if sim.state=="won": record.wins+=1
	save_ok=Records.save_record(record)

func settings_changed() -> void:
	view.reduced=record.reduced
	if qa.is_empty(): save_ok=Records.save_record(record)
	menu_stamp="";refresh_menu()

func play_tone(frequency: int, duration: float) -> void:
	if not record.sound or tone_cooldown>0: return
	tone_cooldown=.08
	if not tone_cache.has(frequency):
		var samples=int(22050*duration);var bytes=PackedByteArray();bytes.resize(samples*2)
		for i in samples:
			var t=float(i)/22050;var envelope=pow(1.0-float(i)/samples,2)*minf(t*180,1)
			var value=int(sin(TAU*frequency*t)*envelope*10000)
			bytes.encode_s16(i*2,value)
		var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050;wav.data=bytes;tone_cache[frequency]=wav
	sfx.stream=tone_cache[frequency];sfx.play()

func fixture() -> void:
	sim.start()
	match qa:
		"upgrade": sim.xp=sim.threshold();sim.check_level()
		"boss": sim.clock=150;sim.spawn_boss()
		"won": sim.spawn_boss();sim.boss.hp=0;sim.step(.01,Vector2.ZERO)
		"lost": sim.hp=0;sim.step(.01,Vector2.ZERO)
		"stress":
			for i in 300: sim.spawn_enemy(Vector2(130+(i%25)*40,200+(i/25)*32),i%3)
