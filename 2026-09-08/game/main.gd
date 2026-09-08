extends Control
const World = preload("res://core/world.gd")
const Levels = preload("res://core/levels.gd")
const Progress = preload("res://core/progress.gd")
const Sound = preload("res://core/sound.gd")
const FONT = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
const INK := Color("343e3b")
const MUTED := Color("696e64")
const BRASS := Color("987333")
const GREEN := Color("426d60")
var levels: Array[Dictionary] = Levels.all()
var stage: int = 0
var best: Dictionary = {}
var persist_progress: bool = true
var world: RescueWorld
var viewport: SubViewport
var board: SubViewportContainer
var pin_buttons: Array[Button] = []
var title_label: Label
var subtitle: Label
var number_label: Label
var stage_label: Label
var chapter_label: Label
var instruction: Label
var status_label: Label
var detail: Label
var tally: Label
var footer: Label
var retry: Button
var pause_button: Button
var hint_button: Button
var mute_button: Button
var next_button: Button
var menu: OptionButton
var sound: RescueSound
var hint_step: int = 0
var board_rect: Rect2
var side_rect: Rect2
var small: bool = false
var effects: Array[Dictionary] = []
var reduce_motion: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	best = Progress.load_best(levels.size()) if persist_progress else {}
	sound = Sound.new()
	add_child(sound)
	_make_ui()
	resized.connect(_layout)
	if OS.has_feature("web"):
		reduce_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
	_load_stage(0)

func label_node(text_value: String, font_size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func style(bg: Color, border: Color, roundness: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(roundness)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s

func button_node(caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_stylebox_override("normal",style(Color("f5f2e9"),Color("bbb4a3")))
	b.add_theme_stylebox_override("hover",style(Color("e9dfc8"),BRASS))
	b.add_theme_stylebox_override("pressed",style(Color("d8c59d"),BRASS))
	var focus := style(Color(0,0,0,0),GREEN)
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus",focus)
	b.pressed.connect(action)
	add_child(b)
	return b

func _make_ui() -> void:
	title_label = label_node("こわさず、壊す。",42)
	subtitle = label_node("解体と救出の、小さなアトリエ",15,MUTED)
	number_label = label_node("",14,BRASS)
	chapter_label = label_node("",14,BRASS)
	stage_label = label_node("",24)
	instruction = label_node("",16)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = label_node("",24,GREEN)
	detail = label_node("",16,MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tally = label_node("",15,MUTED)
	footer = label_node("",13,MUTED)
	retry = button_node("やり直す  R",func() -> void: _load_stage(stage))
	pause_button = button_node("一時停止",_toggle_pause)
	hint_button = button_node("ヒント",_hint)
	mute_button = button_node("音 ON",_mute)
	next_button = button_node("次の模型へ",_next)
	next_button.add_theme_stylebox_override("normal",style(GREEN,GREEN))
	next_button.add_theme_color_override("font_color",Color("faf6e9"))
	menu = OptionButton.new()
	menu.add_theme_color_override("font_color",INK)
	menu.add_theme_stylebox_override("normal",style(Color("f5f2e9"),Color("bbb4a3")))
	menu.get_popup().add_theme_stylebox_override("panel",style(Color("f5f2e9"),Color("bbb4a3")))
	menu.get_popup().add_theme_stylebox_override("hover",style(Color("e4d5b5"),BRASS))
	menu.get_popup().add_theme_constant_override("v_separation",22)
	menu.get_popup().add_theme_color_override("font_color",INK)
	menu.get_popup().add_theme_color_override("font_hover_color",INK)
	menu.item_selected.connect(_load_stage)
	add_child(menu)
	board = SubViewportContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size = Vector2(960,620)
	add_child(board)
	move_child(board,0)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,620)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	board.add_child(viewport)

func _load_stage(index: int) -> void:
	get_tree().paused = false
	stage = clampi(index,0,levels.size()-1)
	if get_parent() is ScrollContainer:
		get_parent().set_deferred("scroll_vertical",0)
	hint_step = 0
	effects.clear()
	if is_instance_valid(world):
		viewport.remove_child(world)
		world.queue_free()
	for b: Button in pin_buttons:
		b.queue_free()
	pin_buttons.clear()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	viewport.add_child(world)
	world.build(levels[stage])
	world.finished.connect(_finish)
	world.changed.connect(_update_counts)
	world.cut_made.connect(_cut_feedback)
	for i: int in range(world.pins.size()):
		var b := button_node(str(i+1),func() -> void: _cut(i))
		b.tooltip_text = "接合点 %d を切る（キー %d）" % [i+1,i+1]
		b.add_theme_stylebox_override("normal",style(Color("e4c98a"),Color("8a682c"),24))
		b.add_theme_stylebox_override("hover",style(Color("f5dfab"),BRASS,24))
		b.add_theme_stylebox_override("pressed",style(Color("d5b46c"),BRASS,24))
		pin_buttons.append(b)
	stage_label.text = "%02d  %s" % [stage+1,levels[stage]["title"]]
	chapter_label.text = levels[stage]["chapter"]
	instruction.text = levels[stage]["lesson"]
	status_label.text = "残すことも、選択。"
	status_label.add_theme_color_override("font_color",GREEN)
	hint_button.text = "ヒント"
	detail.text = "番号の接合点をタップして切断。\n陶器を、緑の梱包箱へ届けよう。"
	pause_button.text = "一時停止"
	pause_button.disabled = false
	next_button.visible = false
	hint_button.disabled = false
	menu.clear()
	for i: int in range(levels.size()):
		menu.add_item("%s %02d  %s" % ["✓" if best.has(str(i)) else "·",i+1,levels[i]["title"]])
	menu.select(stage)
	_update_counts()
	_layout()

func _cut(index: int) -> void:
	if world.cut(index):
		pin_buttons[index].visible = false
		status_label.text = "切った先を、見届ける。" if not get_tree().paused else "停止中に、次の一手。"
		detail.text = "床が止まる場所、陶器が落ちる先を見よう。\nいつでも一時停止・やり直しできます。"

func _update_counts() -> void:
	tally.text = "切断 %d  /  目安 %d  /  最少 %s\n救出する陶器 %d 点" % [world.cuts,levels[stage]["par"],str(best.get(str(stage),"未記録")),world.ceramics.size()]
	number_label.text = "COLLECTION  %02d / %02d" % [best.size(),levels.size()]

func _finish(success: bool, reason: String) -> void:
	get_tree().paused = true
	pause_button.text = "完了"
	pause_button.disabled = true
	status_label.text = "無傷で、届けました。" if success else "もう一度、組み立てる。"
	status_label.add_theme_color_override("font_color",GREEN if success else Color("a04c36"))
	detail.text = reason
	if success:
		sound.play("win")
		var key := str(stage)
		best[key] = mini(world.cuts,int(best.get(key,99)))
		menu.set_item_text(stage,"✓ %02d  %s" % [stage+1,levels[stage]["title"]])
		if persist_progress and not Progress.save_best(best):
			detail.text += "\n記録を保存できませんでした。この画面では続けて遊べます。"
		elif world.cuts <= int(levels[stage]["par"]):
			detail.text += "\n少ない切断で、搬出できました。"
		next_button.text = "全作品を見返す" if stage == levels.size()-1 else "次の模型へ"
		next_button.visible = true
	else:
		sound.play("break")
		for b: Button in pin_buttons:
			b.disabled = true
	_update_counts()
	_layout()

func _toggle_pause() -> void:
	if world.ended:
		return
	get_tree().paused = not get_tree().paused
	pause_button.text = "再開する" if get_tree().paused else "一時停止"
	status_label.text = "停止中に、次の一手。" if get_tree().paused else "残すことも、選択。"

func _hint() -> void:
	var hints: Array = levels[stage]["hints"]
	detail.text = hints[mini(hint_step,hints.size()-1)]
	hint_step += 1
	status_label.text = "構造を読む、小さなヒント。"
	hint_button.text = "もう一つヒント" if hint_step == 1 else "ヒントを再表示"

func _mute() -> void:
	sound.muted = not sound.muted
	mute_button.text = "音 OFF" if sound.muted else "音 ON"

func _next() -> void:
	_load_stage((stage+1)%levels.size())

func _cut_feedback(at: Vector2) -> void:
	sound.play("cut")
	if not reduce_motion:
		effects.append({"at":at,"age":0.0})

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if menu.get_popup().visible:
		return
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		_cut(key-KEY_1)
	elif key == KEY_R:
		_load_stage(stage)
	elif key == KEY_SPACE:
		_toggle_pause()
	elif key == KEY_H:
		_hint()
	elif key == KEY_N and world.won:
		_next()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	for effect: Dictionary in effects:
		effect["age"] += delta
	effects = effects.filter(func(e: Dictionary) -> bool: return e["age"] < 0.35)
	queue_redraw()

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x,y)
	control.size = Vector2(w,h)

func _layout() -> void:
	if not is_instance_valid(world):
		return
	var w: float = size.x
	var h: float = size.y
	if w < 100:
		return
	small = w < 900
	var pad: float = 18.0 if small else 32.0
	title_label.add_theme_font_size_override("font_size",30 if small else 42)
	_place(title_label,pad,16,w-2*pad,52)
	_place(subtitle,pad,66,w-2*pad,26)
	number_label.visible = not small
	_place(number_label,w-270,42,240,25)
	if small:
		var scale_value: float = (w-16.0)/960.0
		board_rect = Rect2(8,104,960*scale_value,620*scale_value)
		side_rect = Rect2(pad,board_rect.end.y+12,w-2*pad,330)
		chapter_label.visible = false
		stage_label.add_theme_font_size_override("font_size",20)
		_place(stage_label,pad,side_rect.position.y,w-2*pad,32)
		_place(instruction,pad,side_rect.position.y+38,w-2*pad,55)
		_place(tally,pad,side_rect.position.y+98,w-2*pad,46)
		var y: float = side_rect.position.y+154
		var bw: float = (w-2*pad-18)/4
		_place(retry,pad,y,bw,44)
		_place(pause_button,pad+bw+6,y,bw,44)
		_place(hint_button,pad+2*(bw+6),y,bw,44)
		_place(mute_button,pad+3*(bw+6),y,bw,44)
		retry.text = "やり直す"
		hint_button.text = "ヒント"
		_place(status_label,pad,y+57,w-2*pad,28)
		status_label.add_theme_font_size_override("font_size",19)
		_place(detail,pad,y+93,w-2*pad,80)
		_place(next_button,pad,y+181,w-2*pad,44)
		_place(menu,pad,y+233,w-2*pad,44)
		footer.visible = false
	else:
		var available := Vector2(w-360,h-220)
		var scale_value: float = minf(available.x/960.0,available.y/620.0)
		board_rect = Rect2(24,120,960*scale_value,620*scale_value)
		side_rect = Rect2(w-300,128,268,h-150)
		chapter_label.visible = true
		_place(chapter_label,side_rect.position.x,130,268,24)
		stage_label.add_theme_font_size_override("font_size",21)
		_place(stage_label,side_rect.position.x,164,268,64)
		stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_place(instruction,side_rect.position.x,235,268,75)
		_place(tally,side_rect.position.x,320,268,52)
		_place(retry,side_rect.position.x,390,130,44)
		_place(pause_button,side_rect.position.x+138,390,130,44)
		_place(hint_button,side_rect.position.x,442,130,44)
		_place(mute_button,side_rect.position.x+138,442,130,44)
		_place(status_label,side_rect.position.x,504,268,34)
		status_label.add_theme_font_size_override("font_size",20)
		_place(detail,side_rect.position.x,546,268,100)
		_place(next_button,side_rect.position.x,minf(h-60,660),268,44)
		_place(menu,32,h-52,minf(board_rect.size.x,540),40)
		footer.visible = true
		footer.text = "1–9  切断     SPACE  停止     R  やり直す     H  ヒント"
		_place(footer,32,board_rect.end.y-6,board_rect.size.x,30)
	board.position = board_rect.position
	board.scale = Vector2.ONE * board_rect.size.x / 960.0
	for i: int in range(pin_buttons.size()):
		var at: Vector2 = world.pins[i]["at"]
		var diameter: float = 44.0
		var p: Vector2 = board_rect.position+at*board.scale.x-Vector2.ONE*diameter/2.0
		_place(pin_buttons[i],p.x,p.y,diameter,diameter)
	# Leaders keep small ceramics visible instead of covering them with a touch target.
	for i: int in range(pin_buttons.size()):
		for vase: Vector2 in levels[stage]["vases"]:
			var art_rect := Rect2(board_rect.position+(vase-Vector2(18,24))*board.scale.x,Vector2(36,48)*board.scale.x)
			if pin_buttons[i].get_rect().intersects(art_rect.grow(4)):
				pin_buttons[i].position.y = art_rect.position.y-52.0
	# Keep touch targets separate on compact models; leaders retain the physical attachment.
	for iteration: int in range(4):
		for i: int in range(pin_buttons.size()):
			for j: int in range(i+1,pin_buttons.size()):
				var delta: Vector2 = pin_buttons[j].position-pin_buttons[i].position
				if delta.length() < 48.0:
					var direction: Vector2 = delta.normalized() if delta.length()>0 else Vector2.RIGHT
					var correction: Vector2 = direction*(48.0-delta.length())/2.0
					pin_buttons[i].position -= correction
					pin_buttons[j].position += correction
	for i: int in range(pin_buttons.size()):
		world.pins[i]["label_at"] = (pin_buttons[i].position+Vector2(22,22)-board_rect.position)/board.scale.x
	world.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("ece7db"))
	draw_line(Vector2(24,106),Vector2(size.x-24,106),Color("c6bead"),1)
	if not small:
		draw_line(Vector2(side_rect.position.x-20,130),Vector2(side_rect.position.x-20,size.y-30),Color("c6bead"),1)
	for effect: Dictionary in effects:
		var p: Vector2 = board_rect.position + effect["at"]*board.scale.x
		var t: float = effect["age"] / 0.35
		draw_arc(p,22+t*18,0,TAU,32,Color(0.58,0.40,0.15,1-t),2,true)
