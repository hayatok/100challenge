extends Control

const Data = preload("res://scripts/rules.gd")
const WorldDataFile = preload("res://scripts/world_data.gd")
const UiPalette = preload("res://scripts/ui_theme.gd")
const Store = preload("res://scripts/save_store.gd")
const Sound = preload("res://scripts/sound.gd")
const BoardScene = preload("res://scenes/board.tscn")
const NAMES := {"isana": "ISANA", "ritsu": "RITSU", "kohaku": "KOHAKU", "sui": "SUI"}
const SYMBOLS := {"knife": "╱", "loanKnife": "╱", "harpoon": "↟", "coat": "衣", "medicine": "＋", "bomb": "●", "flare": "灯", "scrap": "銅", "core": "芯", "pearl": "○"}

@onready var content: VBoxContainer = %Content
@onready var header: HBoxContainer = %Header
@onready var backdrop: TextureRect = %Backdrop
@onready var shade: ColorRect = %Shade
@onready var overlay: Control = %Overlay
@onready var notice: Label = %SaveNotice
var state: Dictionary
var settings: Dictionary
var screen := "title"
var corrupt := false
var stored := false
var audio: Node
var board: Control
var modal: Control
var modal_panel: PanelContainer
var modal_scroll: ScrollContainer
var modal_body_height := 540.0
var pending_item := ""
var status_label: Label
var hp_label: Label
var tide_label: Label
var turn_label: Label
var bag_label: Label
var log_label: Label
var hp_bar: ProgressBar
var interact_button: Button
var harbor_feedback := ""
var qa_session := OS.get_cmdline_user_args().has("--qa")
var last_size := Vector2.ZERO
var resize_timer: Timer

func _ready() -> void:
	theme = UiPalette.make_theme()
	var loaded: Dictionary = {"state": Data.new_game(), "corrupt": false, "found": false, "error": ""} if qa_session else Store.load_game()
	state = loaded.state
	corrupt = loaded.corrupt
	stored = loaded.found
	settings = Store.load_settings()
	if OS.has_feature("web"):
		var motion_preference: Variant = JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'reduce' : 'full'")
		if str(motion_preference) == "reduce":
			settings.reduced = true
	audio = Sound.new()
	add_child(audio)
	audio.set_enabled(settings.sound and not qa_session)
	backdrop.texture = load("res://assets/art/harbor-cover.png")
	_set_notice(loaded.error)
	resize_timer = Timer.new()
	resize_timer.one_shot = true
	resize_timer.wait_time = 0.18
	add_child(resize_timer)
	resize_timer.timeout.connect(_resize_layout)
	resized.connect(func(): resize_timer.start())
	_read_safe_area()
	_render()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.title='潮還り / SHIOGAERI'")

func _resize_layout() -> void:
	_read_safe_area()
	if is_instance_valid(modal_panel):
		modal_panel.custom_minimum_size.x = minf(540, overlay.size.x - 28)
		modal_scroll.custom_minimum_size.y = minf(overlay.size.y - 205, modal_body_height)
	var crossed_breakpoint := (size.x > 760.0) != (last_size.x > 760.0)
	if (crossed_breakpoint or absf(size.x - last_size.x) > 80.0) and screen != "expedition" and not is_instance_valid(modal):
		_render()

func _read_safe_area() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("(function(){var e=document.getElementById('safe-area-probe');if(!e)return '';var s=getComputedStyle(e);return JSON.stringify([parseFloat(s.paddingLeft)||0,parseFloat(s.paddingTop)||0,parseFloat(s.paddingRight)||0,parseFloat(s.paddingBottom)||0,innerWidth,innerHeight]);})()")
	var parser := JSON.new()
	if raw == null or parser.parse(str(raw)) != OK or not parser.data is Array or parser.data.size() != 6:
		return
	var data: Array = parser.data
	var scale_x: float = size.x / maxf(1, float(data[4]))
	var scale_y: float = size.y / maxf(1, float(data[5]))
	_apply_safe_area(Vector4(float(data[0]) * scale_x, float(data[1]) * scale_y, float(data[2]) * scale_x, float(data[3]) * scale_y))

func _apply_safe_area(insets: Vector4) -> void:
	var safe: MarginContainer = %SafeFrame
	safe.add_theme_constant_override("margin_left", 18 + ceili(insets.x))
	safe.add_theme_constant_override("margin_top", 18 + ceili(insets.y))
	safe.add_theme_constant_override("margin_right", 18 + ceili(insets.z))
	safe.add_theme_constant_override("margin_bottom", 18 + ceili(insets.w))
	overlay.offset_left = insets.x
	overlay.offset_top = insets.y
	overlay.offset_right = -insets.z
	overlay.offset_bottom = -insets.w

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _label(text: String, font_size: int = 16, color: Color = UiPalette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	if primary:
		button.add_theme_stylebox_override("normal", UiPalette.box(UiPalette.GOLD, Color("ebc990")))
		button.add_theme_stylebox_override("hover", UiPalette.box(Color("f0cd94"), Color.WHITE))
		button.add_theme_stylebox_override("pressed", UiPalette.box(Color("bc945a"), UiPalette.GOLD))
		button.add_theme_color_override("font_color", Color("15252c"))
		button.add_theme_color_override("font_hover_color", Color("15252c"))
	return button

func _panel(parent: Node, margin: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiPalette.box(Color("172a32"), UiPalette.LINE, margin))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _portrait(character: String, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load("res://assets/art/%s.png" % character)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = minimum
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _render() -> void:
	last_size = size
	_clear(header)
	_clear(content)
	board = null
	var brand := _label("SHIOGAERI  /  潮還り", 15, UiPalette.GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var help := _button("設定", _settings)
	help.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(help)
	shade.color.a = 0.48 if screen == "title" else 0.92
	match screen:
		"title": _title()
		"harbor": _harbor()
		"expedition": _expedition()
		"result": _result()

func _title() -> void:
	_spacer(content)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 300
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 14)
	content.add_child(column)
	column.add_child(_label("沿岸回収組合・遠征記録", 13, Color("d0d0ba")))
	column.add_child(_label("潮還り", 72, Color("f3ead5")))
	column.add_child(_label("潮が戻る前に、帰ろう。", 21))
	column.add_child(_label("沈んだ街を歩き、道具で生き延びる。\n見つけた宝は、持ち帰ってこそ。", 16, Color("d1d3c6")))
	column.add_child(_label("一手ずつ進む探索 / 倒れると携行品を全ロスト", 13, UiPalette.GOLD))
	var begin := _button("続きから" if stored and not corrupt else "港へ向かう", _begin, true)
	column.add_child(begin)
	column.add_child(_button("遊び方", _help))
	begin.grab_focus()
	_spacer(content)
	content.add_child(_label("最初の目標：旧灯台の集光芯を持ち帰る", 13, Color("d8d0b8")))
	content.add_child(_label("4人の回収屋 / ターン制・持ち帰り探索", 13, UiPalette.MUTED))

func _begin() -> void:
	audio.start_ambience()
	if corrupt:
		var body := _open_modal("保存データの確認", 180)
		body.add_child(_label("保存データを読み込めませんでした。新しく始めると、元のデータを置き換えます。"))
		body.add_child(_button("新しく始める", func():
			corrupt = false
			state = Data.new_game()
			_close_modal()
			_enter()
			_persist(), true))
		return
	_enter()

func _enter() -> void:
	screen = state.mode
	pending_item = ""
	_render()

func _harbor() -> void:
	var profile: Dictionary = state.profile
	var who: Dictionary = Data.CHARACTERS[state.character]
	var top := HBoxContainer.new()
	content.add_child(top)
	var heading := _label("回収組合の港", 25)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var record := _label("生還 %d / 遠征 %d" % [int(profile.extracts), int(profile.runs)], 13, UiPalette.MUTED)
	record.custom_minimum_size.x = 120
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(record)
	if not harbor_feedback.is_empty():
		content.add_child(_label(harbor_feedback, 13, UiPalette.GOLD))
	var area: BoxContainer = HBoxContainer.new() if size.x > 760 else VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 20)
	var harbor_scroll := ScrollContainer.new()
	harbor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	harbor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(harbor_scroll)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harbor_scroll.add_child(area)
	var cast := VBoxContainer.new()
	cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(cast)
	var hero := HBoxContainer.new()
	hero.custom_minimum_size.y = 230 if size.x < 760 else 360
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cast.add_child(hero)
	hero.add_child(_portrait(state.character, Vector2(125, 215)))
	var character_info := VBoxContainer.new()
	character_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(character_info)
	character_info.add_child(_label(NAMES[state.character], 13, Color(who.color)))
	character_info.add_child(_label(who.name, 30))
	character_info.add_child(_label(who.role, 15, UiPalette.MUTED))
	character_info.add_child(_label(who.trait, 16, Color(who.color)))
	character_info.add_child(_label("「%s」" % who.idleLine, 14))
	var choices := HBoxContainer.new()
	cast.add_child(choices)
	for key: String in Data.CHARACTERS:
		var char_id: String = key
		var b := _button(Data.CHARACTERS[key].name, func(): _act({"type": "choose", "character": char_id}), state.character == key)
		b.add_theme_font_size_override("font_size", 14)
		choices.add_child(b)
	var cargo := VBoxContainer.new()
	cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_child(cargo)
	var stats: Dictionary = Data.stats(state)
	cargo.add_child(_label("出発の支度", 20))
	var inventory_columns := HBoxContainer.new()
	inventory_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo.add_child(inventory_columns)
	_harbor_items(inventory_columns, "倉庫  %d" % profile.stash.size(), profile.stash, "pack")
	_harbor_items(inventory_columns, "携行  %d / %d" % [state.loadout.size(), stats.capacity], state.loadout, "unpack")
	var preparation := HBoxContainer.new()
	cargo.add_child(preparation)
	preparation.add_child(_button("基本の支度", _basic_loadout))
	var repaired := bool(profile.lampRepaired)
	var repair := _button("灯りを修理" if not repaired else "灯りは修復済み", func(): _act({"type": "repair"}))
	repair.disabled = repaired or not _has_kind(profile.stash, "core") or not _has_kind(profile.stash, "scrap")
	repair.tooltip_text = "集光芯と銅の端材を1個ずつ使う。次回から視界＋1。"
	preparation.add_child(repair)
	var counts := "攻撃 %d  /  防御 %d  /  体力 %d" % [stats.attack, stats.defense, stats.maxHp]
	cargo.add_child(_label(counts, 14, UiPalette.MUTED))
	content.add_child(_label("倒れると、装備中の物を含む携行品をすべて失います。倉庫の品は残ります。", 13, Color("e8c7b0")))
	var depart := _button("この装備で出発する", func(): _act({"type": "depart"}), true)
	content.add_child(depart)
	depart.grab_focus()

func _has_kind(items: Array, kind: String) -> bool:
	for item: Dictionary in items:
		if item.kind == kind:
			return true
	return false

func _harbor_items(parent: Node, title: String, items: Array, action: String) -> void:
	var box := _panel(parent, 9)
	box.add_child(_label(title, 15, UiPalette.GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 125
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if items.is_empty():
		list.add_child(_label("空いています" if action == "unpack" else "品はありません", 13, UiPalette.MUTED))
	for item: Dictionary in items:
		var uid: String = item.uid
		var data: Dictionary = Data.ITEMS[item.kind]
		var b := _button(("＋ " if action == "pack" else "− ") + data.name, func(): _act({"type": action, "uid": uid}))
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.tooltip_text = data.description
		list.add_child(b)

func _basic_loadout() -> void:
	var picked: Array = []
	for item: Dictionary in state.profile.stash:
		if item.kind in ["knife", "coat", "medicine", "bomb", "flare"] and not picked.has(item.kind) and not _has_kind(state.loadout, item.kind):
			picked.append(item.kind)
			var response: Dictionary = Data.apply_action(state, {"type": "pack", "uid": item.uid})
			state = response.state
	_persist()
	_render()

func _expedition() -> void:
	var hud := HBoxContainer.new()
	content.add_child(hud)
	var health := VBoxContainer.new()
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(health)
	hp_label = _label("", 16)
	health.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 7
	hp_bar.show_percentage = false
	health.add_child(hp_bar)
	var counters := VBoxContainer.new()
	counters.custom_minimum_size.x = 110
	hud.add_child(counters)
	turn_label = _label("", 13, UiPalette.MUTED)
	bag_label = _label("", 13, UiPalette.GOLD)
	counters.add_child(turn_label)
	counters.add_child(bag_label)
	tide_label = _label("", 14, Color("adc8c9"))
	content.add_child(tide_label)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiPalette.box(Color("0b161d"), Color("627878"), 0))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(frame)
	board = BoardScene.instantiate()
	board.custom_minimum_size = Vector2(0, 220)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(board)
	board.cell_selected.connect(_cell_selected)
	status_label = _label("", 13, UiPalette.GOLD)
	content.add_child(status_label)
	log_label = _label("", 13)
	log_label.custom_minimum_size.y = 40
	content.add_child(log_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 20)
	content.add_child(controls)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	controls.add_child(pad)
	for entry: Array in [["",0,0],["↑",0,-1],["",0,0],["←",-1,0],["待つ",0,0],["→",1,0],["",0,0],["↓",0,1],["",0,0]]:
		if entry[0] == "":
			var blank := Control.new()
			blank.custom_minimum_size = Vector2(52, 52)
			pad.add_child(blank)
		else:
			var dx: int = entry[1]
			var dy: int = entry[2]
			var b := _button(entry[0], func(): _direction(dx, dy))
			b.custom_minimum_size = Vector2(52, 52)
			b.tooltip_text = "一手待つ" if dx == 0 and dy == 0 else "一マス移動。隣の敵がいれば攻撃。"
			b.add_theme_font_size_override("font_size", 13 if entry[0] == "待つ" else 23)
			pad.add_child(b)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(actions)
	interact_button = _button("調べる", _interact, true)
	actions.add_child(interact_button)
	actions.add_child(_button("持ち物  [I]", _inventory))
	actions.add_child(_button("地図", _map))
	_update_hud([])

func _update_hud(events: Array) -> void:
	if state.mode != "expedition":
		return
	var run: Dictionary = state.run
	var player: Dictionary = run.player
	var who: Dictionary = Data.CHARACTERS[state.character]
	hp_label.text = "%s  %d / %d" % [who.name, player.hp, player.maxHp]
	hp_bar.max_value = player.maxHp
	hp_bar.value = player.hp
	turn_label.text = "%03d 手" % int(run.turn)
	bag_label.text = "携行 %d / %d" % [run.inventory.size(), Data.stats(state).capacity]
	var next_tide := 32 * (int(run.tide) + 1) - int(run.turn)
	var tide_names: Array = ["干潮", "満ち始め", "上げ潮", "満潮"]
	tide_label.text = "潮 %s  /  次の変化まで %d 手" % [tide_names[mini(int(run.tide), 3)], next_tide] if next_tide > 0 and run.tide < 3 else "潮  満潮  /  高架の道を通って帰ろう"
	var tile: Dictionary = run.tiles[int(player.y)][int(player.x)]
	var exit_dist: int = absi(int(player.x) - int(run.exit.x)) + absi(int(player.y) - int(run.exit.y))
	status_label.text = "%s  /  船着き場まで目安 %d マス" % [tile.zone, exit_dist]
	if not pending_item.is_empty():
		status_label.text = "使う方向を選ぶ  /  設定・Escで取り消し"
	elif WorldDataFile.is_flooded(run, player.x, player.y):
		status_label.text = "浸水中：ここで一手終えると体力−1。高所へ。"
	interact_button.text = "帰還する" if int(player.x) == int(run.exit.x) and int(player.y) == int(run.exit.y) else "調べる  [E]"
	var lines: Array = []
	for i: int in range(maxi(0, run.log.size() - 2), run.log.size()):
		lines.append(run.log[i])
	for entry: Dictionary in events:
		if not lines.has(entry.text):
			lines.append(entry.text)
	if lines.size() > 2:
		lines = lines.slice(lines.size() - 2)
	log_label.text = "\n".join(lines)
	board.present(state, events, settings.reduced)

func _direction(dx: int, dy: int) -> void:
	if is_instance_valid(modal):
		return
	if dx == 0 and dy == 0:
		if pending_item.is_empty():
			_act({"type": "wait"})
		return
	if not pending_item.is_empty():
		var uid := pending_item
		pending_item = ""
		_act({"type": "use", "uid": uid, "dx": dx, "dy": dy})
	else:
		_act({"type": "move", "dx": dx, "dy": dy})

func _act(action: Dictionary) -> void:
	var response: Dictionary = Data.apply_action(state, action)
	state = response.state
	var events: Array = response.events
	_persist()
	for event: Dictionary in events:
		audio.play_event(event.type)
		harbor_feedback = event.text
	if state.mode != screen:
		_close_modal()
		_enter()
	elif screen == "expedition":
		_update_hud(events)
	elif screen == "harbor":
		_render()

func _interact() -> void:
	if state.mode != "expedition":
		return
	pending_item = ""
	var run: Dictionary = state.run
	if int(run.player.x) == int(run.exit.x) and int(run.player.y) == int(run.exit.y):
		var owned_count := 0
		for item: Dictionary in run.inventory:
			if item.kind != "loanKnife":
				owned_count += 1
		var body := _open_modal("港へ帰還", 180)
		body.add_child(_label("%d個の品を倉庫へ持ち帰ります。もう少し探すなら、戻って探索を続けられます。" % owned_count))
		if owned_count < run.inventory.size():
			body.add_child(_label("貸出ナイフは帰還時に返却します。", 13, UiPalette.MUTED))
		body.add_child(_button("持ち帰って遠征を終える", func():
			_close_modal()
			_act({"type": "interact"}), true))
	else:
		_act({"type": "interact"})

func _cell_selected(x: int, y: int) -> void:
	if state.mode != "expedition" or is_instance_valid(modal):
		return
	var run: Dictionary = state.run
	var visible: Dictionary = Data.visible_tiles(run)
	if not visible.has("%d,%d" % [x, y]):
		return
	var dx := x - int(run.player.x)
	var dy := y - int(run.player.y)
	if absi(dx) + absi(dy) == 1:
		_direction(dx, dy)
	elif dx == 0 and dy == 0:
		_interact()
	else:
		for enemy: Dictionary in run.enemies:
			if int(enemy.x) == x and int(enemy.y) == y:
				var body := _open_modal(Data.ENEMIES[enemy.kind].name, 160)
				body.add_child(_label(Data.ENEMIES[enemy.kind].description))
				body.add_child(_label("体力 %d  /  攻撃 %d" % [enemy.hp, Data.ENEMIES[enemy.kind].attack], 14, UiPalette.GOLD))
				return
		status_label.text = "隣のマスをタップして移動。離れた場所へは自動移動しません。"

func _open_modal(title: String, content_height: float = 540) -> VBoxContainer:
	_close_modal()
	modal_body_height = content_height
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(modal)
	var dark := ColorRect.new()
	dark.color = Color(0.015, 0.035, 0.05, 0.88)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dark)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	modal_panel = panel
	panel.custom_minimum_size.x = minf(540, overlay.size.x - 28)
	panel.add_theme_stylebox_override("panel", UiPalette.box(Color("182c34"), UiPalette.GOLD, 16))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(_label(title, 23, UiPalette.GOLD))
	var scroll := ScrollContainer.new()
	modal_scroll = scroll
	scroll.custom_minimum_size = Vector2(0, minf(overlay.size.y - 205, modal_body_height))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var close := _button("閉じる", _close_modal)
	column.add_child(close)
	close.grab_focus()
	return body

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
		modal_panel = null
		modal_scroll = null

func _inventory() -> void:
	if state.mode != "expedition":
		return
	var body := _open_modal("持ち物  %d / %d" % [state.run.inventory.size(), Data.stats(state).capacity])
	body.add_child(_label("読む間は手数が進みません。使用・装備・置く操作は1手です。", 13, UiPalette.MUTED))
	for item: Dictionary in state.run.inventory:
		var uid: String = item.uid
		var kind: String = item.kind
		var info: Dictionary = Data.ITEMS[kind]
		var box := _panel(body, 10)
		var equipped: bool = uid == state.run.weapon or uid == state.run.armor
		box.add_child(_label("%s  %s%s" % [SYMBOLS.get(kind, "◇"), info.name, "  装備中" if equipped else ""], 17, UiPalette.GOLD if equipped else UiPalette.INK))
		box.add_child(_label(info.description, 13, UiPalette.MUTED))
		var buttons := HBoxContainer.new()
		box.add_child(buttons)
		if info.category == "consumable":
			buttons.add_child(_button("使う", func():
				_close_modal()
				if kind in ["bomb", "flare"]:
					pending_item = uid
					status_label.text = "%s：矢印で使う方向を選ぶ。Escで取り消し。" % info.name
				else:
					_act({"type": "use", "uid": uid})))
		elif info.category in ["weapon", "armor"]:
			var equip := _button("装備中" if equipped else "装備する", func():
				_close_modal()
				_act({"type": "equip", "uid": uid}))
			equip.disabled = equipped
			buttons.add_child(equip)
		buttons.add_child(_button("足元に置く", func():
			_close_modal()
			_act({"type": "drop", "uid": uid})))

func _result() -> void:
	var receipt: Dictionary = state.result
	var success: bool = receipt.outcome == "extracted"
	var who: Dictionary = Data.CHARACTERS[state.character]
	var row: BoxContainer = HBoxContainer.new() if size.x > 760 else VBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	if size.x > 760:
		row.add_child(_portrait(state.character, Vector2(260, 350)))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	box.add_child(_label("EXTRACTION COMPLETE" if success else "EXPEDITION LOST", 13, UiPalette.GOLD if success else Color("f19a83")))
	box.add_child(_label("生還" if success else "漂着", 56))
	var result_line: String = who.lossLine if not success else who.emptyLine if receipt.inventory.is_empty() else who.returnLine
	box.add_child(_label("「%s」" % result_line, 18))
	box.add_child(_label("%d手の遠征 / %d個を%s" % [receipt.turns, receipt.inventory.size(), "倉庫へ移しました" if success else "失いました"], 15, UiPalette.MUTED))
	if not success:
		box.add_child(_label("最後の原因：%s" % receipt.cause, 15, Color("f19a83")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 140
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var items := VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items)
	for item: Dictionary in receipt.inventory:
		items.add_child(_label("%s  %s" % [SYMBOLS.get(item.kind, "◇"), Data.ITEMS[item.kind].name], 16))
	if receipt.inventory.is_empty():
		items.add_child(_label("持ち帰った品はありません。" if success else "携行品はありませんでした。", 15, UiPalette.MUTED))
	var next_message := "倉庫の品は残っています。次の支度を整えよう。" if not success else "港に戻りました。次の遠征の支度を整えよう。" if receipt.inventory.is_empty() else "品は倉庫に保管されました。次の遠征に持ち出せます。"
	box.add_child(_label(next_message, 14, UiPalette.MUTED))
	content.add_child(_button("港で支度をする", func(): _act({"type": "return"}), true))

func _map() -> void:
	if state.mode != "expedition":
		return
	var body := _open_modal("回収屋の地図")
	var run: Dictionary = state.run
	var image := Image.create(run.width, run.height, false, Image.FORMAT_RGB8)
	var seen: Dictionary = {}
	for key: String in run.seen:
		seen[key] = true
	for y: int in run.height:
		for x: int in run.width:
			var color := Color("101d25")
			if seen.has("%d,%d" % [x, y]):
				var tile: Dictionary = run.tiles[y][x]
				color = Color("64746b") if tile.type != "wall" else Color("273d44")
				if tile.type == "water" or WorldDataFile.is_flooded(run, x, y):
					color = Color("386c78")
				if tile.type == "exit":
					color = Color("e4b36b")
			image.set_pixel(x, y, color)
	image.set_pixel(run.player.x, run.player.y, Color("f4e8ca"))
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(280, 280)
	body.add_child(view)
	body.add_child(_label("明るい点：現在地 / 金色：帰還地点\n青：水路・浸水 / 地図は見えた範囲を記録します。", 14))
	body.add_child(_label("旧灯台は北東。集光芯と銅の端材を持ち帰り、港の灯りを修理しよう。", 15, UiPalette.GOLD))

func _settings() -> void:
	pending_item = ""
	if screen == "expedition" and is_instance_valid(board):
		_update_hud([])
	var body := _open_modal("設定と中断")
	var sound := CheckButton.new()
	sound.text = "音を鳴らす"
	sound.custom_minimum_size.y = 48
	sound.button_pressed = settings.sound
	body.add_child(sound)
	sound.toggled.connect(func(value: bool):
		settings.sound = value
		audio.set_enabled(value)
		_set_notice(Store.save_settings(settings)))
	var motion := CheckButton.new()
	motion.text = "動きを減らす"
	motion.custom_minimum_size.y = 48
	motion.button_pressed = settings.reduced
	body.add_child(motion)
	motion.toggled.connect(func(value: bool):
		settings.reduced = value
		if is_instance_valid(board):
			board.present(state, [], value)
		_set_notice(Store.save_settings(settings)))
	body.add_child(_label("一手が終わるたびに、このブラウザへ保存します。画面を閉じても、その手から再開できます。保存に失敗した場合は画面下に表示します。", 14, UiPalette.MUTED))
	body.add_child(_button("遊び方", _help))
	body.add_child(_button("タイトルへ戻る", func():
		_close_modal()
		screen = "title"
		_render()))

func _help() -> void:
	var body := _open_modal("回収屋の心得")
	for entry: Array in [["一手ずつ、考える", "矢印ボタン、矢印キー、WASDで一マス移動。隣の敵に向かって進むと攻撃します。長押しで連続移動しません。"], ["調べる・拾う", "荷箱の隣か上で「調べる」。Eキーでも操作できます。鞄に入りきらない品は、その場に残ります。"], ["道具で切り抜ける", "持ち物はIキー。救急包で回復し、爆薬で敵や壁を破壊し、発煙筒で敵を誘導できます。使用と装備変更は一手です。"], ["潮と敵を読む", "潮は32・64・96手で変わります。低い道は浸水すると一手ごとに体力を1失います。木の高架は沈みません。構えた鳥の正面からは横へ避けよう。"], ["持ち帰って初めて、自分の物", "南の船着き場で「帰還」。倒れると装備と携行品をすべて失います。倉庫の品は残り、武器がなくても貸出ナイフで再出発できます。"], ["最初の仕事", "北東の旧灯台で集光芯を見つけ、銅の端材と一緒に持ち帰ろう。港の灯りを修理すると、次回から視界が1マス広がります。"]]:
		body.add_child(_label(entry[0], 18, UiPalette.GOLD))
		body.add_child(_label(entry[1], 15))

func _persist() -> void:
	if qa_session or corrupt:
		return
	var error: String = Store.save_game(state)
	if error.is_empty():
		stored = true
	_set_notice(error)

func _set_notice(text: String) -> void:
	notice.text = text
	notice.visible = not text.is_empty()
	notice.add_theme_color_override("font_color", Color("f19a83"))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			_close_modal()
		elif not pending_item.is_empty():
			pending_item = ""
			_update_hud([])
		else:
			_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(modal):
		if event.keycode == KEY_TAB:
			var controls: Array = []
			_collect_focus(modal, controls)
			if not controls.is_empty():
				var index: int = controls.find(get_viewport().gui_get_focus_owner())
				controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
			get_viewport().set_input_as_handled()
		return
	if screen != "expedition":
		return
	if event.is_action_pressed("step_north"):
		_direction(0, -1)
	elif event.is_action_pressed("step_south"):
		_direction(0, 1)
	elif event.is_action_pressed("step_west"):
		_direction(-1, 0)
	elif event.is_action_pressed("step_east"):
		_direction(1, 0)
	elif event.is_action_pressed("wait_turn"):
		_direction(0, 0)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("inventory"):
		_inventory()
	elif event.is_action_pressed("area_map"):
		_map()
	else:
		return
	get_viewport().set_input_as_handled()

func _collect_focus(parent: Node, result: Array) -> void:
	for child: Node in parent.get_children():
		if child is BaseButton and child.visible and not child.disabled:
			result.append(child)
		_collect_focus(child, result)

func _notification(what: int) -> void:
	if not is_instance_valid(audio):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		audio.set_active(false)
		if is_instance_valid(board):
			board.process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		audio.set_active(true)
		if is_instance_valid(board):
			board.process_mode = Node.PROCESS_MODE_INHERIT
