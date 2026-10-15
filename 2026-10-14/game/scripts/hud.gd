extends CanvasLayer

signal start_requested
signal restart_requested
signal resume_requested
signal title_requested
signal pause_requested
signal settings_changed(effect_level: String, music_volume: float, sfx_volume: float)

const FONT = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
const DISPLAY_FONT = preload("res://assets/fonts/TaikinComic-Black.otf")
const Surface = preload("res://scripts/ui/comic_surface.gd")
const INK = Color("223443")
const PAPER = Color("fff4dc")
const RED = Color("f4433e")
const GOLD = Color("ffd45b")
const GREEN = Color("159b9c")
const PINK = Color("f36a99")

var _accents: Control
var _celebration: Control
var _visual_speed := 0.0
var _visual_boosting := false
var _visual_rush := false
var _visual_impact := 0.0
var _root: Control
var _play: Control
var _menu: Control
var _title: Control
var _pause: Control
var _result: Control
var _settings: Control
var _shade: ColorRect
var _time: Label
var _damage: Label
var _combo: Label
var _combo_ticket: Control
var _combo_value: Label
var _pressure_text: Label
var _pressure: ProgressBar
var _gauge: Control
var _pressure_hint: Label
var _distance: Label
var _notice: Label
var _bonus: Label
var _notice_group: Control
var _notice_shape: Control
var _bonus_ticket: Control
var _result_time: Label
var _result_rank: Label
var _result_sub: Label
var _best: Label
var _best_record: Label
var _best_stamp: Control
var _result_stamp: Control
var _result_damage: Label
var _result_combo: Label
var _save_error: Label
var _music_value: Label
var _sfx_value: Label
var _mode := ""
var _burst_left := 0.0
var _burst_duration := 0.95
var _quality := "派手"
var _music := 0.45
var _sfx := 0.75
var _counter_age := 1.0
var _damage_age := 1.0
var _stamp_age := 1.0
var _celebration_age := 2.0
var _last_combo := 0
var _last_damage := 0
var _counter_birth := false
var _damage_birth := false
var _notice_birth := false
var _stamp_birth := false
var _window_focused := true
var _title_start: Button
var _pause_resume: Button
var _result_retry: Button
var _settings_close: Button
var _settings_return: Control
var _animation_clock := 0.0
var _rush_starts := 0
var _success_starts := 0
var _burst_kind := ""
var _rush_guard := 0.0
var _rush_lock := false

func build() -> void:
	if is_instance_valid(_root): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = _group(self)
	_root.name = "JapaneseHUD"
	_play = _group(_root)
	_accents = _surface(_play,"edges",Rect2(0,0,1920,1080))
	_build_play()
	_shade = ColorRect.new()
	_shade.color = Color(0.06,0.1,0.13,0.12)
	_shade.size = Vector2(1920,1080)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_menu = _group(_root)
	_title = _group(_menu)
	_pause = _group(_menu)
	_result = _group(_menu)
	_build_title()
	_build_pause()
	_build_result()
	_notice_group = _group(_root)
	_notice_group.position = Vector2(502,118)
	_notice_group.size = Vector2(916,215)
	_notice_group.pivot_offset = Vector2(458,80)
	_notice_shape = _surface(_notice_group,"burst",Rect2(0,0,916,155),PAPER)
	_notice = _label(_notice_group,"",Rect2(80,26,756,97),64,INK,HORIZONTAL_ALIGNMENT_CENTER,2)
	_bonus_ticket = _surface(_notice_group,"receipt",Rect2(206,146,505,73))
	_bonus_ticket.rotation = -0.025
	_bonus = _label(_bonus_ticket,"",Rect2(14,1,477,65),44,RED,HORIZONTAL_ALIGNMENT_CENTER)
	_notice_group.hide()
	_build_settings()
	_fit()
	present("title",{})

func _group(parent: Node) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = Vector2(1920,1080)
	parent.add_child(node)
	return node

func _surface(parent: Node, kind: String, rect: Rect2, fill: Color = PAPER) -> Control:
	var node := Surface.new()
	node.kind = kind
	node.fill = fill
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _label(parent: Node, text: String, rect: Rect2, font_size: int = 32, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font",DISPLAY_FONT if font_size >= 32 else FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",INK)
	label.add_theme_constant_override("outline_size",outline)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _line(parent: Node, rect: Rect2, color: Color = Color("a79e89")) -> void:
	var line := ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _style(fill: Color, border: Color = INK, width: int = 3, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = Vector2(rect.size.x,maxf(rect.size.y,88))
	button.add_theme_font_override("font",DISPLAY_FONT)
	button.add_theme_font_size_override("font_size",48 if primary else 30)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,PAPER if primary else INK)
	var empty := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","disabled"]: button.add_theme_stylebox_override(state,empty)
	var focus := _style(Color.TRANSPARENT,GOLD,5,2)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	button.add_theme_stylebox_override("focus",focus)
	var surface := _surface(button,"button",Rect2(Vector2.ZERO,button.size),RED if primary else PAPER)
	surface.show_behind_parent = true
	button.mouse_entered.connect(func():
		surface.fill = Color("d83232") if primary else Color("ffdf8d")
		surface.queue_redraw()
	)
	button.mouse_exited.connect(func():
		surface.fill = RED if primary else PAPER
		surface.queue_redraw()
	)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _key(parent: Node, text: String, rect: Rect2, size_px: int = 32) -> void:
	var cap := _surface(parent,"keycap",rect,INK)
	_label(cap,text,Rect2(6,0,rect.size.x-17,rect.size.y-8),size_px,PAPER,HORIZONTAL_ALIGNMENT_CENTER)

func _build_play() -> void:
	var clock := _surface(_play,"timecard",Rect2(34,31,438,174))
	_label(clock,"退勤TIME",Rect2(26,6,301,60),35,PAPER)
	_time = _label(clock,"00:00.00",Rect2(22,70,392,91),74,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	var receipt := _surface(_play,"receipt",Rect2(1460,29,425,180))
	_label(receipt,"被害総額",Rect2(25,15,360,53),32)
	_line(receipt,Rect2(24,73,377,2))
	_line(receipt,Rect2(24,83,80,2))
	_line(receipt,Rect2(24,94,80,2))
	_damage = _label(receipt,"¥0",Rect2(28,77,365,69),48,RED,HORIZONTAL_ALIGNMENT_RIGHT)
	_damage.pivot_offset = Vector2(365,35)
	_combo_ticket = _group(_play)
	_combo_ticket.position = Vector2(1460,217)
	_combo_ticket.size = Vector2(425,166)
	_combo = _label(_combo_ticket,"0",Rect2(0,-20,164,180),138,GOLD,HORIZONTAL_ALIGNMENT_CENTER,10)
	_combo.pivot_offset = Vector2(82,88)
	var ticket := _surface(_combo_ticket,"receipt",Rect2(160,40,260,86))
	ticket.rotation = -0.065
	_combo_value = _label(ticket,"連鎖 ×1",Rect2(12,1,237,70),39,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_combo_ticket.hide()
	var pressure := _surface(_play,"paper",Rect2(141,900,420,144))
	_surface(_play,"extinguisher",Rect2(20,865,145,181))
	_label(pressure,"消火器",Rect2(20,4,145,53),32,RED)
	_pressure_text = _label(pressure,"残圧 100%",Rect2(162,4,240,53),32)
	_gauge = _surface(pressure,"meter",Rect2(20,62,376,43))
	_pressure_hint = _label(pressure,"離すと回復",Rect2(20,105,376,30),22)
	# Retain a ProgressBar as the semantic pressure value; the visible drawing is segmented.
	_pressure = ProgressBar.new()
	_pressure.max_value = 100
	_pressure.visible = false
	_play.add_child(_pressure)
	var controls := _surface(_play,"paper",Rect2(1179,907,701,137))
	_key(controls,"← →",Rect2(17,15,129,70),33)
	_key(controls,"A D",Rect2(154,15,107,70),30)
	_key(controls,"SPACE",Rect2(272,15,169,70),32)
	_key(controls,"R",Rect2(452,15,85,70),34)
	_key(controls,"ESC",Rect2(548,15,134,70),32)
	_label(controls,"旋回",Rect2(17,88,244,32),23,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_label(controls,"噴射",Rect2(272,88,169,32),23,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_label(controls,"再挑戦",Rect2(444,88,102,32),22,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_label(controls,"ポーズ",Rect2(546,88,138,32),22,INK,HORIZONTAL_ALIGNMENT_CENTER)
	var exit_sign := _surface(_play,"button",Rect2(783,22,354,77),GREEN)
	_distance = _label(exit_sign,"EXIT ↑ 106m",Rect2(14,1,320,62),34,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_button(_play,"Ⅱ ポーズ",Rect2(1658,790,222,90),func(): pause_requested.emit())

func _build_title() -> void:
	_surface(_title,"logo",Rect2(54,25,820,330))
	var logo := _group(_title)
	logo.position = Vector2(57,205)
	logo.size = Vector2(823,208)
	logo.rotation = -0.055
	_label(logo,"全力退勤",Rect2(17,17,805,216),176,PINK,HORIZONTAL_ALIGNMENT_LEFT,22)
	var cream := _label(logo,"全力退勤",Rect2(0,0,805,216),176,PAPER,HORIZONTAL_ALIGNMENT_LEFT,28)
	cream.add_theme_color_override("font_outline_color",INK)
	var red := _label(logo,"全力退勤",Rect2(0,0,805,216),176,RED,HORIZONTAL_ALIGNMENT_LEFT,14)
	red.add_theme_color_override("font_outline_color",PAPER)
	var ribbon := _surface(_title,"ribbon",Rect2(149,442,663,83))
	ribbon.rotation = -0.03
	_label(ribbon,"定時だ。飛べ。",Rect2(32,2,599,73),46,INK,HORIZONTAL_ALIGNMENT_CENTER)
	var message := _surface(_title,"receipt",Rect2(97,548,708,68))
	_label(message,"消火器の反動で、オフィスを駆け抜けろ。",Rect2(18,6,672,53),27,INK,HORIZONTAL_ALIGNMENT_CENTER)
	var instruction := _surface(_title,"paper",Rect2(91,638,721,168))
	_key(instruction,"← →",Rect2(32,23,117,64),30)
	_key(instruction,"A D",Rect2(159,23,117,64),30)
	_label(instruction,"椅子の向きを変える",Rect2(301,24,374,54),29)
	_key(instruction,"SPACE",Rect2(32,94,244,56),29)
	_label(instruction,"噴射・離すと残圧回復",Rect2(301,92,391,57),29)
	_title_start = _button(_title,"退勤する →",Rect2(85,825,732,130),func(): start_requested.emit(),true)
	_button(_title,"設定",Rect2(108,980,321,88),_toggle_settings)
	_button(_title,"クレジット",Rect2(454,980,340,88),func():
		OS.shell_open("credits.html" if OS.has_feature("web") else "https://godotengine.org/license/")
	)

func _build_pause() -> void:
	var paper := _surface(_pause,"paper",Rect2(587,176,746,746))
	var stamp := _surface(paper,"stamp",Rect2(110,40,526,120))
	stamp.accent = GREEN
	stamp.rotation = -0.045
	_label(stamp,"ひと休み",Rect2(20,5,486,105),70,GREEN,HORIZONTAL_ALIGNMENT_CENTER)
	_label(paper,"退勤タイムは停止中",Rect2(43,179,660,66),34,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_pause_resume = _button(paper,"再開する →",Rect2(56,271,634,110),func(): resume_requested.emit(),true)
	_button(paper,"最初から",Rect2(56,407,303,98),func(): restart_requested.emit())
	_button(paper,"設定",Rect2(382,407,308,98),_toggle_settings)
	_button(paper,"タイトルへ",Rect2(56,532,634,98),func(): title_requested.emit())
	_label(paper,"ESCでも再開",Rect2(56,655,634,48),26,INK,HORIZONTAL_ALIGNMENT_CENTER)

func _build_result() -> void:
	_celebration = _surface(_result,"celebration",Rect2(0,0,1920,1080))
	var receipt := _surface(_result,"receipt",Rect2(64,89,867,936))
	# A clip on a short header slip makes the result a filed office receipt.
	_surface(receipt,"paper",Rect2(18,-12,206,49))
	_surface(receipt,"clip",Rect2(112,-30,68,80))
	_result_stamp = _surface(receipt,"stamp",Rect2(20,29,824,180))
	_result_stamp.pivot_offset = Vector2(412,90)
	_result_stamp.rotation = -0.055
	_label(_result_stamp,"退勤成功！",Rect2(22,9,780,154),112,RED,HORIZONTAL_ALIGNMENT_CENTER)
	_label(receipt,"退勤TIME",Rect2(45,234,720,57),37)
	_result_time = _label(receipt,"00:24.86",Rect2(42,285,786,133),117,INK,HORIZONTAL_ALIGNMENT_CENTER)
	_line(receipt,Rect2(46,425,772,8),RED)
	var rosette := _surface(receipt,"rosette",Rect2(36,456,217,217))
	_result_rank = _label(rosette,"SSS",Rect2(19,70,180,94),70,INK,HORIZONTAL_ALIGNMENT_CENTER,2)
	var rank_ticket := _surface(receipt,"burst",Rect2(280,469,538,119),GOLD)
	_result_sub = _label(rank_ticket,"爆速帰宅",Rect2(57,17,427,79),51,INK,HORIZONTAL_ALIGNMENT_CENTER,1)
	_best_record = _label(receipt,"",Rect2(282,614,536,68),26,INK)
	_best_stamp = _surface(receipt,"stamp",Rect2(420,611,365,76))
	_best_stamp.accent = GREEN
	_best_stamp.rotation = -0.045
	_best = _label(_best_stamp,"自己ベスト！",Rect2(13,5,339,63),37,GREEN,HORIZONTAL_ALIGNMENT_CENTER)
	_line(receipt,Rect2(285,696,534,2))
	_result_damage = _label(receipt,"被害総額 ¥0",Rect2(282,704,542,55),32,RED)
	_result_combo = _label(receipt,"最大連鎖 0",Rect2(282,761,542,48),30)
	_line(receipt,Rect2(285,815,534,2))
	_surface(receipt,"barcode",Rect2(40,766,210,29))
	_result_retry = _button(receipt,"もう一度 →",Rect2(38,836,495,91),func(): restart_requested.emit(),true)
	_button(receipt,"タイトルへ",Rect2(555,836,273,91),func(): title_requested.emit())
	_save_error = _label(_result,"",Rect2(110,1030,800,35),23,RED)
	var secrecy := _surface(_result,"receipt",Rect2(1378,934,431,96))
	secrecy.rotation = -0.055
	_label(secrecy,"総務には内緒。",Rect2(22,11,387,68),40,INK,HORIZONTAL_ALIGNMENT_CENTER)

func _build_settings() -> void:
	_settings = _group(_root)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1920,1080)
	backdrop.color = Color(0.03,0.06,0.08,0.70)
	_settings.add_child(backdrop)
	var paper := _surface(_settings,"paper",Rect2(551,143,818,796))
	_label(paper,"設定",Rect2(49,30,640,102),65)
	_line(paper,Rect2(50,145,715,4),RED)
	_label(paper,"演出の量",Rect2(49,171,300,88),34)
	var quality := OptionButton.new()
	quality.position = Vector2(973,315)
	quality.size = Vector2(338,88)
	quality.add_theme_font_override("font",DISPLAY_FONT)
	quality.add_theme_font_size_override("font_size",34)
	for color_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: quality.add_theme_color_override(color_name,INK)
	quality.add_theme_stylebox_override("normal",_style(PAPER,INK,5))
	quality.add_theme_stylebox_override("hover",_style(GOLD,INK,5))
	quality.add_theme_stylebox_override("pressed",_style(GOLD,INK,5))
	quality.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,RED,5))
	for text in ["派手","標準","控えめ"]: quality.add_item(text)
	var popup := quality.get_popup()
	popup.add_theme_font_override("font",FONT)
	popup.add_theme_font_size_override("font_size",32)
	popup.add_theme_color_override("font_color",INK)
	popup.add_theme_color_override("font_hover_color",INK)
	popup.add_theme_stylebox_override("panel",_style(PAPER,INK,5,6))
	popup.add_theme_stylebox_override("hover",_style(GOLD,INK,3,3))
	popup.add_theme_constant_override("v_separation",28)
	quality.item_selected.connect(func(index: int):
		_quality = quality.get_item_text(index)
		_emit_settings()
	)
	_settings.add_child(quality)
	_label(paper,"BGM 音量",Rect2(49,302,420,60),33)
	_music_value = _label(paper,"45%",Rect2(578,302,186,60),33,RED,HORIZONTAL_ALIGNMENT_RIGHT)
	_slider(paper,Rect2(49,370,715,90),_music,func(value: float):
		_music=value
		_music_value.text="%d%%" % roundi(value*100)
		_emit_settings()
	)
	_label(paper,"効果音 音量",Rect2(49,484,420,60),33)
	_sfx_value = _label(paper,"75%",Rect2(578,484,186,60),33,RED,HORIZONTAL_ALIGNMENT_RIGHT)
	_slider(paper,Rect2(49,552,715,90),_sfx,func(value: float):
		_sfx=value
		_sfx_value.text="%d%%" % roundi(value*100)
		_emit_settings()
	)
	_settings_close = _button(paper,"閉じる",Rect2(49,682,715,88),_toggle_settings,true)
	_settings.hide()

func _slider(parent: Node, rect: Rect2, value: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value=0
	slider.max_value=1
	slider.step=0.01
	slider.value=value
	slider.add_theme_stylebox_override("slider",_style(INK,INK,3,3))
	slider.add_theme_stylebox_override("grabber_area",_style(GOLD,INK,3,3))
	slider.add_theme_stylebox_override("grabber_area_highlight",_style(RED,INK,3,3))
	var knob := GradientTexture2D.new()
	knob.width=36
	knob.height=56
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([RED,RED])
	knob.gradient=gradient
	slider.add_theme_icon_override("grabber",knob)
	slider.add_theme_icon_override("grabber_highlight",knob)
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider

func _toggle_settings() -> void:
	_settings.visible = not _settings.visible
	if _settings.visible:
		_settings_return = get_viewport().gui_get_focus_owner()
		_settings_close.grab_focus()
	elif is_instance_valid(_settings_return):
		_settings_return.grab_focus()

func _emit_settings() -> void:
	_accents.reduced = _quality == "控えめ"
	_celebration.reduced = _quality == "控えめ"
	if _quality == "控えめ":
		_combo.scale=Vector2.ONE
		_damage.scale=Vector2.ONE
		_notice_group.scale=Vector2.ONE
		_result_stamp.scale=Vector2.ONE
	_accents.queue_redraw()
	_celebration.queue_redraw()
	settings_changed.emit(_quality,_music,_sfx)

func _fit() -> void:
	if not is_instance_valid(_root): return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x/1920.0,viewport_size.y/1080.0)
	_root.scale=Vector2.ONE*factor
	_root.position=(viewport_size-Vector2(1920,1080)*factor)*0.5

func _reset_presentation(reset_metrics: bool = true) -> void:
	_burst_left=0
	if reset_metrics:
		_animation_clock=0
		_rush_starts=0
		_success_starts=0
	_burst_kind=""
	_rush_guard=0
	_rush_lock=false
	_counter_age=1
	_damage_age=1
	_stamp_age=1
	_celebration_age=2
	_notice_birth=false
	_counter_birth=false
	_damage_birth=false
	_stamp_birth=false
	_notice.text=""
	_bonus.text=""
	_result_stamp.scale=Vector2.ONE
	_notice_group.hide()
	_notice_group.scale=Vector2.ONE
	_notice_group.modulate.a=1
	_combo.scale=Vector2.ONE
	_damage.scale=Vector2.ONE
	_last_combo=0
	_last_damage=0
	_accents.intensity=0
	_accents.phase=0
	_celebration.phase=0
	_celebration.hide()

## Explicit reset also covers retry before the official run timer has begun.
func reset_run() -> void:
	if not is_instance_valid(_root): return
	_reset_presentation()
	_visual_rush=false
	_visual_speed=0
	_visual_boosting=false

func present(mode: String, data: Dictionary) -> void:
	if not is_instance_valid(_root): return
	var old_mode := _mode
	if mode != _mode:
		_mode=mode
		_settings.hide()
		_play.visible=mode in ["playing","paused"]
		_menu.visible=mode!="playing"
		_title.visible=mode=="title"
		_pause.visible=mode=="paused"
		_result.visible=mode=="result"
		_shade.visible=mode!="playing"
		if mode in ["title","result"] or (mode=="playing" and old_mode!="paused"):
			_reset_presentation(mode!="result")
		if mode=="title": _title_start.grab_focus()
		elif mode=="paused":
			_notice_group.hide()
			_pause_resume.grab_focus()
		elif mode=="result":
			_success_starts=1
			_burst_kind="success"
			_stamp_age=0
			_stamp_birth=true
			_celebration_age=0
			_celebration.show()
			_result_stamp.scale=Vector2.ONE if _quality=="控えめ" else Vector2.ONE*1.15
			_result_retry.grab_focus()
		elif old_mode=="paused":
			_notice_group.visible=_burst_left>0
	_visual_speed=float(data.get("speed",0))
	_visual_boosting=bool(data.get("boosting",false))
	if _visual_rush and not bool(data.get("rush",false)): _rush_lock=false
	_visual_rush=bool(data.get("rush",false))
	_visual_impact=float(data.get("impact",0))
	_time.text=_format_time(float(data.get("elapsed",0)))
	var damage := int(data.get("damage",0))
	_damage.text="¥"+_money(damage)
	_damage.add_theme_font_size_override("font_size",48 if damage<10000000 else 38)
	if damage>_last_damage and mode=="playing":
		_damage_age=0.06
		_damage_birth=true
	_last_damage=damage
	var count := int(data.get("combo",0))
	_combo.text=str(count)
	_combo.add_theme_font_size_override("font_size",138 if count<10 else (103 if count<100 else 78))
	_combo_value.text="連鎖 ×%d" % int(data.get("multiplier",1))
	_combo_ticket.visible=count>0
	if count>_last_combo and mode=="playing":
		_counter_age=0.065
		_counter_birth=true
	_last_combo=count
	var pressure := float(data.get("pressure",100))
	_pressure.value=pressure
	_gauge.amount=pressure
	_gauge.queue_redraw()
	_pressure_text.text="残圧 %d%%" % roundi(pressure)
	_pressure_text.add_theme_color_override("font_color",RED if pressure<20 else INK)
	_pressure_hint.text="離して回復！" if pressure<=0.1 else ("残圧わずか・離すと回復" if pressure<20 else "離すと回復")
	_pressure_hint.add_theme_color_override("font_color",RED if pressure<20 else INK)
	_distance.text="EXIT ↑ %dm" % ceili(float(data.get("distance",0)))
	if mode=="result":
		_result_time.text=_format_time(float(data.get("elapsed",0)))
		_result_rank.text=str(data.get("rank","SSS"))
		_result_sub.text=str(data.get("rank_text","爆速帰宅"))
		_best_stamp.visible=bool(data.get("new_best",false))
		_best_record.visible=not _best_stamp.visible
		var best_time := float(data.get("best_time",0))
		_best_record.text="自己ベスト "+_format_time(best_time) if best_time>0 else "おつかれさまでした！"
		_result_damage.text="被害総額 ¥"+_money(damage)
		_result_damage.add_theme_font_size_override("font_size",32 if damage<10000000 else 27)
		_result_combo.text="最大連鎖 %d" % int(data.get("max_combo",0))
		_save_error.text="記録を保存できませんでした" if bool(data.get("save_error",false)) else ""

func burst(text: String, bonus: String = "", kind: String = "impact") -> void:
	if not is_instance_valid(_notice): return
	# The result already owns its stamp clock. A success call never replays the entrance.
	if kind=="success" and _mode=="result": return
	if _mode!="playing": return
	if kind=="rush" and _rush_lock:
		if not bonus.is_empty():
			_bonus.text=bonus
			_bonus_ticket.show()
		return
	if _rush_guard>0 and kind!="rush":
		_bonus.text=bonus
		_bonus_ticket.visible=not bonus.is_empty()
		return
	if kind=="rush":
		_rush_starts+=1
		_rush_guard=0.5
		_rush_lock=true
	_burst_kind=kind
	_notice.text=text
	_notice.add_theme_font_size_override("font_size",64 if text.length()<=9 else (54 if text.length()<=12 else 42))
	_notice.add_theme_color_override("font_color",INK)
	_notice_shape.fill=GOLD if kind=="rush" else PAPER
	_notice_shape.queue_redraw()
	_bonus.text=bonus
	_bonus_ticket.visible=not bonus.is_empty()
	_burst_duration=1.2 if kind=="rush" else 0.85
	_burst_left=_burst_duration
	_notice_birth=true
	_notice_group.scale=Vector2.ONE
	_notice_group.modulate.a=1
	_notice_group.show()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: _window_focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: _window_focused=true

func _process(delta: float) -> void:
	_fit()
	if not is_instance_valid(_accents): return
	# All new animation clocks obey both game pause and focus, including result clocks.
	if get_tree().paused or not _window_focused or _mode=="paused": return
	if _mode in ["playing","result"]: _animation_clock+=delta
	var subdued := _quality=="控えめ"
	if _mode=="playing":
		_accents.reduced=subdued
		_accents.active=_visual_rush
		_accents.phase+=delta
		var target := clampf(_visual_speed/9.0,0,1)*0.85 if _visual_boosting else 0.0
		if _visual_rush: target=1.0
		_accents.intensity=move_toward(_accents.intensity,target,delta*5)
		_accents.queue_redraw()
		if not _notice_birth: _rush_guard=maxf(0,_rush_guard-delta)
		if _counter_birth: _counter_birth=false
		else: _counter_age+=delta
		if _damage_birth: _damage_birth=false
		else: _damage_age+=delta
		_combo.scale=Vector2.ONE*(1.0+(sin(clampf(_counter_age/0.18,0,1)*PI)*0.15 if not subdued else 0.0))
		_damage.scale=Vector2.ONE*(1.0+(sin(clampf(_damage_age/0.16,0,1)*PI)*0.07 if not subdued else 0.0))
		if _burst_left>0:
			# Hold birth for one draw so large frame deltas cannot consume an unseen impact.
			if _notice_birth: _notice_birth=false
			else: _burst_left=maxf(0,_burst_left-delta)
			var age := _burst_duration-_burst_left
			var pop := 1.0+(sin(clampf(age/0.18,0,1)*PI)*0.07 if not subdued else 0.0)
			_notice_group.scale=Vector2.ONE*pop
			_notice_group.modulate.a=minf(1,_burst_left/0.18)
			if _burst_left<=0: _notice_group.hide()
	elif _mode=="result":
		if _stamp_birth: _stamp_birth=false
		else:
			_stamp_age+=delta
			_celebration_age+=delta
		var stamp_scale := 1.0
		if not subdued and _stamp_age<0.14: stamp_scale=lerpf(1.15,0.97,_stamp_age/0.14)
		elif not subdued and _stamp_age<0.26: stamp_scale=lerpf(0.97,1.0,(_stamp_age-0.14)/0.12)
		_result_stamp.scale=Vector2.ONE*stamp_scale
		_celebration.reduced=subdued
		_celebration.phase=_celebration_age
		_celebration.modulate.a=clampf((1.2-_celebration_age)/0.3,0,1)
		_celebration.queue_redraw()
		if _celebration_age>=1.2: _celebration.hide()

func _format_time(value: float) -> String:
	var hundredths := floori(maxf(value,0)*100)
	return "%02d:%02d.%02d" % [hundredths/6000,(hundredths/100)%60,hundredths%100]

func _money(value: int) -> String:
	var digits := str(value)
	var output := ""
	for index in digits.length():
		if index>0 and (digits.length()-index)%3==0: output+=","
		output+=digits[index]
	return output

## Read-only state for integration checks. Rectangles are in the fixed 1920×1080 canvas.
func debug_snapshot() -> Dictionary:
	return {
		"mode":_mode,"animation_clock":_animation_clock,"phase":_accents.phase,
		"root_scale":[_root.scale.x,_root.scale.y],"root_offset":[_root.position.x,_root.position.y],
		"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],
		"controls":{
			"title_start":[85,825,732,130],"title_settings":[108,980,321,88],
			"title_credits":[454,980,340,88],"playing_pause":[1658,790,222,90],
			"pause_resume":[643,447,634,110],"pause_restart":[643,583,303,98],
			"pause_settings":[969,583,308,98],"pause_title":[643,708,634,98],
			"result_retry":[102,925,495,91],"result_title":[619,925,273,91],
			"settings_quality":[973,315,338,88],"settings_music":[600,513,715,90],
			"settings_sfx":[600,695,715,90],"settings_close":[600,825,715,88]
		},
		"burst_left":_burst_left,"burst_kind":_burst_kind,"notice_text":_notice.text,
		"bonus_text":_bonus.text,"notice_visible":_notice_group.visible,
		"rush_starts":_rush_starts,"success_starts":_success_starts,
		"rush_guard":_rush_guard,"stamp_age":_stamp_age,"celebration_age":_celebration_age,
		"counter_age":_counter_age,"damage_age":_damage_age,"focused":_window_focused,
		"quality":_quality,"best_stamp_visible":_best_stamp.visible,
		"timer_rect":Rect2(34,31,438,174),"exit_rect":Rect2(783,22,354,77),
		"notice_rect":Rect2(502,118,916,215),"pressure_rect":Rect2(20,865,541,181),
		"combo_rect":Rect2(1460,217,425,166),
		"start_rect":Rect2(85,825,732,130),"retry_rect":Rect2(102,925,495,91),
		"pause_rect":Rect2(1658,790,222,90),"settings_visible":_settings.visible,
		"stamp_scale":[_result_stamp.scale.x,_result_stamp.scale.y],
		"combo_scale":[_combo.scale.x,_combo.scale.y],"damage_scale":[_damage.scale.x,_damage.scale.y]
	}
