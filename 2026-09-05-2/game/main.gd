extends Node3D
const Sim = preload("res://core/simulation.gd")
const Overlay = preload("res://overlay.gd")
const INK = Color("142432")
const CREAM = Color("fff0cd")
const PINK = Color("ed7183")
const CYAN = Color("66e4e0")
var sim = Sim.new()
var camera: Camera3D
var world_art: Node3D
var player_model: Node3D
var enemy_multimesh: MultiMesh
var enemy_basis = Transform3D.IDENTITY
var ui: Control
var overlay: Control
var hud: Control
var menu: Control
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var timer_label: Label
var stats_label: Label
var notice_label: Label
var loadout_label: Label
var menu_state = ""
var ui_font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
var reduced = false
var sound_enabled = true
var music: AudioStreamPlayer
var chime: AudioStreamPlayer
var last_event = 0
var last_level = 0
var best_record = 0
var save_ok = true
var touch_active = false
var touch_origin = Vector2.ZERO
var touch_position = Vector2.ZERO
var qa_mode = ""
var qa_route: Array = []
var qa_index = 0
var render_frames: Array = []
var simulation_us: Array = []
var metric_clock = 0.0

func _ready() -> void:
	_setup_input()
	_setup_world()
	_setup_audio()
	_load_record()
	_setup_ui()
	get_window().focus_exited.connect(_focus_lost)
	# Debug-only fixtures. Release exports ignore both command-line and URL QA requests.
	if OS.is_debug_build():
		print("LOOP_RENDER ",RenderingServer.get_current_rendering_method())
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--qa="):
				qa_mode = arg.trim_prefix("--qa=")
		if OS.has_feature("web"):
			var value = JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''")
			if value != null:
				qa_mode = str(value)
		if not qa_mode.is_empty():
			_apply_fixture(qa_mode)
	_refresh_menu()

func _setup_input() -> void:
	var bindings = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}
	for action in bindings:
		InputMap.add_action(action,0.2)
		for key in bindings[action]:
			var e = InputEventKey.new(); e.physical_keycode = key; InputMap.action_add_event(action,e)
	var axes = {"move_left":[JOY_AXIS_LEFT_X,-1.0],"move_right":[JOY_AXIS_LEFT_X,1.0],"move_up":[JOY_AXIS_LEFT_Y,-1.0],"move_down":[JOY_AXIS_LEFT_Y,1.0]}
	for action in axes:
		var e = InputEventJoypadMotion.new();e.axis=axes[action][0];e.axis_value=axes[action][1];InputMap.action_add_event(action,e)

func _setup_world() -> void:
	world_art = preload("res://world_art.gd").new()
	add_child(world_art)
	world_art.build()
	player_model = world_art.player
	camera = world_art.camera
	enemy_multimesh = MultiMesh.new()
	enemy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	enemy_multimesh.mesh = world_art.enemy_mesh
	enemy_basis = world_art.enemy_basis
	enemy_multimesh.instance_count = Sim.CAP
	enemy_multimesh.visible_instance_count = 0
	var crowd = MultiMeshInstance3D.new()
	crowd.multimesh = enemy_multimesh
	add_child(crowd)

func _setup_audio() -> void:
	music=AudioStreamPlayer.new();music.stream=preload("res://assets/audio/rehearsal.wav");music.volume_db=-15;add_child(music)
	music.finished.connect(func():
		if sim.state == "running" and sound_enabled: music.play())
	chime=AudioStreamPlayer.new();chime.stream=preload("res://assets/audio/loop.wav");chime.volume_db=-8;add_child(chime)

func _style(bg: Color, border: Color = INK, width: int = 3) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(width);s.set_content_margin_all(16);s.shadow_color=Color(0,0,0,.4);s.shadow_size=5;s.shadow_offset=Vector2(4,5);return s

func _focus_style() -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.draw_center=false;s.border_color=CREAM;s.set_border_width_all(3);return s

func _bar_style(color: Color) -> StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;return b

func _label(text: String, size_px: int = 20, color: Color = CREAM) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_px);l.add_theme_color_override("font_color",color);return l

func _button(text: String, callback: Callable, color: Color = CYAN) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=52;b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_hover_color",INK);b.add_theme_color_override("font_pressed_color",INK);b.add_theme_color_override("font_focus_color",INK)
	b.add_theme_stylebox_override("normal",_style(color));b.add_theme_stylebox_override("hover",_style(color.lightened(.12),CREAM));b.add_theme_stylebox_override("pressed",_style(color.darkened(.1)));b.add_theme_stylebox_override("focus",_focus_style());b.pressed.connect(callback);return b

func _setup_ui() -> void:
	var canvas=CanvasLayer.new();add_child(canvas)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme=Theme.new();theme.default_font=ui_font;theme.default_font_size=20;ui.theme=theme;canvas.add_child(ui)
	overlay=Overlay.new();overlay.host=self;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(hud)
	var top=PanelContainer.new();top.position=Vector2(24,20);top.size=Vector2(460,94);top.add_theme_stylebox_override("panel",_style(INK,Color("486170"),2));hud.add_child(top)
	var stack=VBoxContainer.new();top.add_child(stack)
	var title=_label("よふかしシグナル  /  こはく",18);stack.add_child(title)
	hp_bar=ProgressBar.new();hp_bar.custom_minimum_size=Vector2(380,13);hp_bar.show_percentage=false;hp_bar.add_theme_stylebox_override("fill",_bar_style(PINK));stack.add_child(hp_bar)
	xp_bar=ProgressBar.new();xp_bar.custom_minimum_size=Vector2(380,7);xp_bar.show_percentage=false;xp_bar.add_theme_stylebox_override("fill",_bar_style(CYAN));stack.add_child(xp_bar)
	timer_label=_label("",29);timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);timer_label.position=Vector2(-320,24);timer_label.size=Vector2(205,45);timer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hud.add_child(timer_label)
	timer_label.add_theme_color_override("font_outline_color",INK);timer_label.add_theme_constant_override("outline_size",4)
	var pause_button=_button("Ⅱ",_toggle_pause,CREAM);pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);pause_button.position=Vector2(-90,22);pause_button.size=Vector2(64,54);hud.add_child(pause_button)
	stats_label=_label("",18);stats_label.position=Vector2(24,130);hud.add_child(stats_label)
	stats_label.add_theme_color_override("font_outline_color",INK);stats_label.add_theme_constant_override("outline_size",4)
	var footer=ColorRect.new();footer.color=Color(.05,.10,.14,.95);footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_top=-92;footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(footer)
	notice_label=_label("",20);notice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);notice_label.position=Vector2(24,-84);notice_label.size=Vector2(1100,36);hud.add_child(notice_label)
	loadout_label=_label("",16,Color("b9cfd1"));loadout_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);loadout_label.position=Vector2(24,-43);loadout_label.size=Vector2(1100,30);hud.add_child(loadout_label)
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(menu)

func _refresh_menu() -> void:
	var key=sim.state+str(sim.level)+str(sim.rerolls)
	if key==menu_state:return
	menu_state=key
	if qa_mode in ["art","map"]:
		hud.visible=false;menu.visible=false
		return
	for child in menu.get_children():
		menu.remove_child(child);child.queue_free()
	hud.visible=sim.state!="ready"
	menu.visible=sim.state!="running"
	music.stream_paused=sim.state!="running"
	if sim.state=="running":
		if sound_enabled and not music.playing:music.play()
		return
	var veil=ColorRect.new();veil.color=Color(.035,.075,.11,.86);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(veil)
	if sim.state=="ready":
		var art=TextureRect.new();art.texture=preload("res://assets/yofukashi.png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(art)
		var left=ColorRect.new();left.color=Color(.035,.075,.11,.86);left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);left.anchor_right=.47;menu.add_child(left)
		var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.anchor_right=.47;margin.add_theme_constant_override("margin_left",40);margin.add_theme_constant_override("margin_right",32);margin.add_theme_constant_override("margin_top",64);margin.add_theme_constant_override("margin_bottom",40);menu.add_child(margin)
		var box=VBoxContainer.new();box.add_theme_constant_override("separation",16);margin.add_child(box)
		box.add_child(_label("よふかしシグナル  /  雨灯横丁",18,CYAN))
		box.add_child(_label("LOOP\nEATER",64))
		box.add_child(_label("オフライン・アンコール",23,PINK))
		var desc=_label("逃げ道を、わたしたちのステージに。\n走った線をつないで、大群を回収。",19);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(desc)
		var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(spacer)
		var play=_button("リハーサルを始める  →",_start);box.add_child(play);play.grab_focus()
		box.add_child(_label("180秒の操作・成長試作  /  WASD・矢印・パッド",14))
		box.add_child(_label("移動だけで攻撃。線は6秒、陣地は8秒。",14,Color("b9cfd1")))
		return
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(640,0);panel.add_theme_stylebox_override("panel",_style(INK,CYAN));center.add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",14);panel.add_child(box)
	if sim.state=="upgrade":
		box.add_child(_label("機材、アップデート。",32,CYAN))
		box.add_child(_label("LEVEL %02d  /  時間は止まっています"%sim.level,16))
		for i in sim.choices.size():
			var data=Sim.INFO[sim.choices[i]]
			var text="%d  %s   Lv.%d\n%s"%[i+1,data[0],sim.upgrades[sim.choices[i]]+1,data[1]]
			var button=_button(text,func():sim.choose(i);_refresh_menu(),CREAM);button.add_theme_font_size_override("font_size",18);box.add_child(button)
			if i==0:button.grab_focus()
		var reroll_button=_button("候補を入れ替える  残り%d回"%sim.rerolls,func():sim.reroll();_refresh_menu(),PINK);reroll_button.disabled=sim.rerolls==0;box.add_child(reroll_button)
	elif sim.state=="paused":
		box.add_child(_label("ひと息、入れよう。",32,CYAN))
		box.add_child(_label("りつ「帰り道まで、振付です」",20))
		var resume_button=_button("リハーサルを続ける",func():sim.resume();_refresh_menu());box.add_child(resume_button);resume_button.grab_focus()
		var audio_check=CheckButton.new();audio_check.text="BGM・効果音";audio_check.button_pressed=sound_enabled;audio_check.toggled.connect(func(on):sound_enabled=on;music.volume_db=-15 if on else -80);box.add_child(audio_check)
		var reduce_check=CheckButton.new();reduce_check.text="演出を控えめにする";reduce_check.button_pressed=reduced;reduce_check.toggled.connect(func(on):reduced=on);box.add_child(reduce_check)
		box.add_child(_button("最初からやり直す",_restart,CREAM))
		box.add_child(_button("タイトルへ戻る",_title,PINK))
	else:
		var success=sim.state=="won"
		box.add_child(_label("リハーサル、おつかれ！" if success else "今日は、ここまで。",32,CYAN if success else PINK))
		box.add_child(_label("180秒の練習を完走。製品版の本公演は、これから。" if success else "トウコの回収ドローンで撤収。次の帰り道を考えよう。",16))
		box.add_child(_label("回収 %d体    囲み %d回    最大同時 %d体"%[sim.kills,sim.loops,sim.best_loop],24))
		box.add_child(_label("囲み %d  /  陣地 %d  /  自動射撃 %d"%[sim.sources.burst,sim.sources.territory,sim.sources.weapon],18))
		box.add_child(_label("こはく「次は、もっと大きく囲めそう！」",20,PINK))
		box.add_child(_label("最高同時回収：%d体%s"%[best_record,"" if save_ok else "  /  保存できませんでした"],16))
		var again=_button("もう一度、違う強化で",_restart);box.add_child(again);again.grab_focus()
		box.add_child(_button("タイトルへ戻る",_title,CREAM))
	if not qa_mode.is_empty():box.add_child(_label("検証用表示："+qa_mode+"  /  記録保存なし",14,PINK))

func _start() -> void:
	sim.start();last_event=0;_refresh_menu()

func _restart() -> void:
	sim=Sim.new();qa_route.clear();_start()

func _title() -> void:
	sim=Sim.new();qa_route.clear();music.stop();_refresh_menu()

func _toggle_pause() -> void:
	if sim.state=="running":sim.pause()
	elif sim.state=="paused":sim.resume()
	_refresh_menu()

func _focus_lost() -> void:
	touch_active=false
	sim.pause();_refresh_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and sim.state != "ready":
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:world_art.zoom_by(-0.08)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:world_art.zoom_by(0.08)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:_toggle_pause()
		if event.keycode in [KEY_1,KEY_2,KEY_3]:sim.choose(event.keycode-KEY_1);_refresh_menu()
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START:_toggle_pause()
	# Drag movement uses the same movement vector; no extra combat action.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		touch_active=event.pressed and sim.state=="running";touch_origin=event.position;touch_position=event.position
	if event is InputEventMouseMotion and touch_active:touch_position=event.position
	if event is InputEventScreenTouch:
		touch_active=event.pressed and sim.state=="running";touch_origin=event.position;touch_position=event.position
	if event is InputEventScreenDrag and touch_active:touch_position=event.position

func _physics_process(dt: float) -> void:
	var direction=Input.get_vector("move_left","move_right","move_up","move_down")
	if touch_active:direction=(touch_position-touch_origin).limit_length(65)/65.0
	if not qa_route.is_empty() and sim.state=="running":
		if sim.player.distance_to(qa_route[qa_index]) < .24:qa_index=(qa_index+1)%qa_route.size()
		direction=(qa_route[qa_index]-sim.player).normalized()
	if qa_mode=="stress":
		sim.hurt_clock=9999
		if sim.state=="upgrade":sim.choose(0)
		while sim.enemies.size()<600:sim.spawn_enemy(Vector2(sim.rng.randf_range(-20,20),sim.rng.randf_range(-12,12)))
	var before=sim.state
	var began=Time.get_ticks_usec()
	sim.step(dt,direction)
	if not qa_mode.is_empty() and before=="running":
		simulation_us.append(Time.get_ticks_usec()-began)
		if simulation_us.size()>3600:simulation_us.pop_front()
	if sim.event_serial!=last_event:
		last_event=sim.event_serial
		if sound_enabled:chime.play()
	if before=="running" and sim.state in ["won","lost"]:_save_record()
	_refresh_menu()

func _process(dt: float) -> void:
	world_art.update_actor(dt,sim.player,sim.facing,sim.state=="running",reduced)
	if qa_mode == "art":
		camera.position=Vector3(3.5,2.4,5.3);camera.look_at(Vector3(0,1.5,0))
	elif qa_mode == "map":
		camera.position=Vector3(22,24,30);camera.look_at(Vector3(0,1,-2))
	enemy_multimesh.visible_instance_count=mini(Sim.CAP,sim.enemies.size())
	for i in enemy_multimesh.visible_instance_count:
		var e=sim.enemies[i];var direction: Vector2=sim.player-e.p
		var transform=Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.y)),Vector3(e.p.x,0,e.p.y))
		enemy_multimesh.set_instance_transform(i,transform*enemy_basis)
	hp_bar.value=sim.hp;xp_bar.max_value=sim.needed_xp();xp_bar.value=sim.xp
	timer_label.text="%02d:%02d / 03:00"%[int(sim.clock)/60,int(sim.clock)%60]
	stats_label.text="HP %d   LV.%02d\n回収 %d  /  囲み %d  /  最大 %d"%[sim.hp,sim.level,sim.kills,sim.loops,sim.best_loop]
	notice_label.text=sim.notice if sim.loops>0 else "自分の線を横切ると、囲んだ群れを回収。"
	loadout_label.text="線 %.2f秒  ·  陣地 %d / 3  ·  回収威力 %d     WASD / 矢印で移動 · ホイールで拡大 · Esc 停止"%[sim.trail_life(),sim.regions.size(),3+sim.upgrades.burst*2]
	if not qa_mode.is_empty() and sim.state=="running":
		loadout_label.text+="  [QA %s]"%qa_mode
		render_frames.append(dt*1000)
		if render_frames.size()>3600:render_frames.pop_front()
		metric_clock+=dt
		if metric_clock>10.0 and not simulation_us.is_empty():
			metric_clock=0.0
			var frames=render_frames.duplicate();frames.sort()
			var steps=simulation_us.duplicate();steps.sort()
			print("LOOP_QA ",JSON.stringify({"mode":qa_mode,"enemies":sim.enemies.size(),"loops":sim.loops,"clock":sim.clock,"render_p95_ms":frames[int(frames.size()*.95)],"simulation_p95_ms":steps[int(steps.size()*.95)]/1000.0}))
	overlay.queue_redraw()

func _load_record() -> void:
	var config=ConfigFile.new()
	if config.load("user://loop-eater.cfg")==OK:
		var value=config.get_value("records","best_loop",0)
		if typeof(value)==TYPE_INT and value>=0:best_record=value

func _save_record() -> void:
	if not qa_mode.is_empty():return
	best_record=maxi(best_record,sim.best_loop)
	var config=ConfigFile.new();config.set_value("records","best_loop",best_record)
	save_ok=config.save("user://loop-eater.cfg")==OK

func _apply_fixture(mode: String) -> void:
	sim.start()
	if mode in ["art","map"]:
		sim.enemies.clear();sim.state="art";sim.facing=Vector2.DOWN
	if mode in ["loop","stress"]:
		sim.enemies.clear()
		for i in (600 if mode=="stress" else 35):
			sim.spawn_enemy(Vector2(sim.rng.randf_range(-13,13),sim.rng.randf_range(-8,8)))
		qa_route=[Vector2(-5,0),Vector2(-5,-4),Vector2(3,-4),Vector2(3,2),Vector2(-2,2),Vector2(-2,-1)]
	elif mode=="upgrade":
		sim.xp=10;sim.check_level()
	elif mode=="won":sim.state="won";sim.kills=108;sim.loops=12;sim.best_loop=24
	elif mode=="lost":sim.state="lost";sim.hp=0
	elif mode=="paused":sim.pause()
