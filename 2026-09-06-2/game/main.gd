extends Node2D
const World = preload("res://core/world.gd")
const DNA = preload("res://core/genome.gd")
const Island = preload("res://island_view.gd")
const Portrait = preload("res://portrait.gd")
const INK = Color("253d36")
const PAPER = Color("f7f2df")
const MINT = Color("b4ce9b")
const CORAL = Color("dc694b")
const SAVE = "user://lineage-v1.json"
var font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
var sim = World.new()
var view
var root: Control
var inspector: Panel
var modal: Panel
var title_label: Label
var stats: Label
var info: Label
var selected_title: Label
var selected_detail: Label
var notice: Label
var event_line: Label
var portrait
var pause_button: Button
var speed_button: Button
var rain_button: Button
var follow_button: Button
var selected: int = 1
var paused: bool = false
var speed: int = 1
var reduced: bool = false
var auto_watch: bool = false
var mobile: bool = false
var accumulator: float = 0
var refresh_clock: float = 0
var save_clock: float = 0
var watch_clock: float = 0
var toast: String = "眺めるだけで、暮らしが続きます。"
var toast_life: float = 8
var save_blocked: bool = false
var modal_open: bool = false
var last_size: Vector2
var qa: String = ""
var capture_path: String = ""
var capture_after: float = 2
var wall: float = 0
var captured: bool = false
var pixel_ratio: float = 1.0
var window_pixels: Vector2i = Vector2i.ZERO
var backdrop: ColorRect

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if OS.has_feature("web"):
		pixel_ratio = float(JavaScriptBridge.eval("window.devicePixelRatio || 1"))
	sync_window()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-after="): capture_after = float(arg.trim_prefix("--capture-after="))
		if OS.is_debug_build() and arg.begins_with("--qa="): qa = arg.trim_prefix("--qa=")
	if OS.has_feature("web"):
		reduced = bool(JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches"))
		if OS.is_debug_build(): qa = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''"))
	if qa.is_empty(): load_world()
	else: fixture()
	var layer = CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	view = Island.new()
	view.sim = sim
	view.selected = selected
	view.reduced = reduced
	view.picked.connect(select_creature)
	root.add_child(view)
	layout()
	print("LINEAGE ready / seed ", sim.seed_value, " / population ", sim.creatures.size())

func sync_window() -> void:
	if get_window().size == window_pixels: return
	window_pixels = get_window().size
	get_window().content_scale_size = Vector2i(Vector2(window_pixels) / pixel_ratio)
	get_window().content_scale_factor = 1.0

func flat(color: Color, border: bool = true) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(2 if border else 0)
	style.set_content_margin_all(8)
	return style

func label(parent: Control, text: String, rect: Rect2, pixels: int = 16, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", pixels)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Control, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 14 if mobile else 16)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", Color("6a7669"))
	var normal: StyleBoxFlat = flat(MINT if primary else PAPER)
	normal.shadow_color = INK
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(2, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", flat(Color("e6d697")))
	b.add_theme_stylebox_override("pressed", flat(Color("eab08b")))
	b.add_theme_stylebox_override("disabled", flat(Color("e3e3d4")))
	var focus: StyleBoxFlat = flat(Color.TRANSPARENT)
	focus.border_color = CORAL
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func layout() -> void:
	close_modal()
	last_size = get_viewport_rect().size
	root.size = last_size
	mobile = last_size.x < 850
	for child in root.get_children():
		if child != view: root.remove_child(child); child.queue_free()
	modal = null
	modal_open = false
	var w: float = last_size.x
	var h: float = last_size.y
	var margin: float = 12 if mobile else 24
	title_label = label(root, "へんないきものの系譜", Rect2(margin, 12, w - margin * 2, 48), 25 if mobile else 36)
	stats = label(root, "", Rect2(margin, 58, w - margin * 2, 26), 13 if mobile else 16)
	var labels: Array = ["停止", "速度 1×", "雨を降らす", "拡大", "次の子", "追跡", "保存", "手帳"]
	var actions: Array[Callable] = [toggle_pause, cycle_speed, rain, zoom_in, next_creature, toggle_follow, manual_save, open_notebook]
	var buttons: Array[Button] = []
	var cols: int = 4 if mobile else 8
	var button_w: float = (w - margin * 2 - (cols - 1) * 8) / cols if mobile else minf(130, (w - 48 - 7 * 10) / 8)
	for i in labels.size():
		var b: Button = button(root, labels[i], Rect2(margin + (i % cols) * (button_w + 8), 90 + (i / cols) * 46, button_w, 38), actions[i], i == 0)
		buttons.append(b)
	pause_button = buttons[0]
	speed_button = buttons[1]
	rain_button = buttons[2]
	follow_button = buttons[5]
	var top: float = 196 if mobile else 158
	var board_h: float = maxf(170, h - top - (248 if mobile else 72))
	view.position = Vector2(margin, top)
	view.size = Vector2(w - margin * 2 if mobile else w - 390, board_h)
	if mobile and view.zoom == 1: view.zoom = 1.8
	label(root, "草地  /  茂み  /  浅瀬", Rect2(margin, top - 24, 250, 22), 12)
	inspector = Panel.new()
	inspector.position = Vector2(margin, top + board_h + 12) if mobile else Vector2(w - 350, top)
	inspector.size = Vector2(w - margin * 2 if mobile else 326, 188 if mobile else board_h)
	inspector.add_theme_stylebox_override("panel", flat(PAPER))
	root.add_child(inspector)
	selected_title = label(inspector, "", Rect2(14, 10, inspector.size.x - 28, 28), 19)
	portrait = Portrait.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = Vector2(6, 48)
	portrait.size = Vector2(116, 106) if mobile else Vector2(inspector.size.x - 20, 150)
	inspector.add_child(portrait)
	selected_detail = label(inspector, "", Rect2(128, 46, inspector.size.x - 140, 90) if mobile else Rect2(16, 216, inspector.size.x - 32, 150), 13 if mobile else 16)
	selected_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(inspector, "親子・系譜を見る", Rect2(128 if mobile else 16, 140 if mobile else 380, inspector.size.x - (142 if mobile else 32), 34 if mobile else 42), open_lineage, true)
	if not mobile:
		info = label(inspector, "形には、暮らしの理由がある。\n長い脚は速い。大きい体は腹ぺこ。\nヒレは浅瀬で、真価を発揮する。", Rect2(16, 445, inspector.size.x - 32, 80), 13)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.visible = board_h > 540
	event_line = label(root, "", Rect2(margin, h - 46, w - margin * 2, 22), 12 if mobile else 14)
	event_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice = label(root, "", Rect2(margin, h - 24, w - margin * 2, 22), 11 if mobile else 13)
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	refresh()

func refresh() -> void:
	stats.text = "%s  ·  %d匹  ·  誕生 %d  ·  %.1f分" % [sim.season_name(), sim.creatures.size(), sim.births, sim.time / 60]
	pause_button.text = "再開" if paused else "停止"
	speed_button.text = "速度 %d×" % speed
	rain_button.disabled = sim.rain_cooldown > 0
	rain_button.text = "雨 %d秒" % ceili(sim.rain_cooldown) if sim.rain_cooldown > 0 else "雨を降らす"
	follow_button.text = "追跡中" if view.follow else "追跡"
	var h: Dictionary = sim.history.get(str(selected), {})
	if h.is_empty():
		selected_title.text = "まだ、誰もいません。"
		selected_detail.text = "手帳から新しい島を始められます。"
		portrait.genes = {}
	else:
		selected_title.text = h.name
		var c: Dictionary = sim.living(selected)
		var p: Dictionary = DNA.traits(h.genes)
		var state: String = c.state if not c.is_empty() else "土へ還った個体"
		selected_detail.text = "%s · 第%d世代\n脚 %d対 / 体節 %d\n陸の速さ %.0f / 水の適性 %.0f%%\n%s" % [state, h.generation, p.pairs, p.parts, p.speed, p.swim * 100, "元気 %.0f / 100" % c.energy if not c.is_empty() else "生きた姿は系譜に残ります。"]
		portrait.genes = h.genes
		portrait.egg = not c.is_empty() and c.age < 4
	portrait.queue_redraw()
	view.selected = selected
	event_line.text = sim.events[0].text if not sim.events.is_empty() else "小さな変化を、待っています。"
	notice.text = toast if toast_life > 0 else "クリックで観察 / ドラッグで移動 / ホイールで拡大 / Spaceで停止" if not mobile else "タップで観察・ドラッグで島を移動"
	if sim.creatures.is_empty(): notice.text = "島は静かになりました。手帳から系譜を振り返り、新しい島へ。"
	if sim.history_full: notice.text = "記録が2万匹に到達。保存して手帳から新しい島へ。"

func _process(delta: float) -> void:
	if root == null: return
	wall += delta
	sync_window()
	if get_viewport_rect().size != last_size: layout()
	toast_life = maxf(0, toast_life - delta)
	if not paused and not modal_open:
		accumulator += minf(delta, 0.2) * speed
		while accumulator >= World.STEP:
			sim.step()
			accumulator -= World.STEP
		if view.follow and sim.living(selected).is_empty():
			var children: Array = sim.descendants(selected)
			for id in children:
				if not sim.living(int(id)).is_empty(): select_creature(int(id)); say("子孫に追跡を引き継ぎました。"); break
		watch_clock += delta
		if auto_watch and watch_clock > 14 and not sim.events.is_empty():
			watch_clock = 0
			for e in sim.events:
				if e.id > 0 and not sim.living(int(e.id)).is_empty(): select_creature(int(e.id)); view.follow = true; break
	view.visual_time = sim.time + accumulator
	refresh_clock += delta
	save_clock += delta
	if refresh_clock > 0.4: refresh_clock = 0; refresh()
	if save_clock > 30 and not save_blocked and qa.is_empty(): save_clock = 0; save_world(false)
	if not capture_path.is_empty() and not captured and wall >= capture_after:
		captured = true
		get_viewport().get_texture().get_image().save_png(capture_path)

func say(message: String) -> void:
	toast = message
	toast_life = 7
	if notice != null: notice.text = message

func select_creature(id: int) -> void:
	if not sim.history.has(str(id)): return
	selected = id
	refresh()

func toggle_pause() -> void:
	paused = not paused
	refresh()

func cycle_speed() -> void:
	speed = 1 if speed == 4 else speed * 2
	refresh()

func rain() -> void:
	if sim.pour_rain(): say("雨のあとは、餌がよく育ちます。")
	refresh()

func zoom_in() -> void:
	view.zoom = 1.0 if view.zoom >= 3 else view.zoom + 0.6
	say("拡大 %.1f×。ドラッグで島を移動できます。" % view.zoom)

func next_creature() -> void:
	if sim.creatures.is_empty(): return
	var next: int = 0
	for i in sim.creatures.size():
		if sim.creatures[i].id == selected: next = (i + 1) % sim.creatures.size(); break
	select_creature(sim.creatures[next].id)
	var c: Dictionary = sim.living(selected)
	view.camera = Vector2(c.x, c.y)

func toggle_follow() -> void:
	view.follow = not view.follow
	say("この子と、生きている子孫を追いかけます。" if view.follow else "カメラを自由に動かせます。")
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: close_modal(); return
	if modal_open: return
	match event.keycode:
		KEY_SPACE: toggle_pause()
		KEY_1: speed = 1
		KEY_2: speed = 2
		KEY_4: speed = 4
		KEY_R: rain()
		KEY_N: next_creature()
		KEY_F: toggle_follow()
		KEY_S: manual_save()
		KEY_L: open_lineage()
		KEY_H: open_notebook()
	refresh()

func begin_modal(title: String) -> VBoxContainer:
	close_modal()
	modal_open = true
	background_focus(root, false)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.1, 0.18, 0.14, 0.35)
	backdrop.size = last_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)
	modal = Panel.new()
	modal.position = Vector2(12, 16) if mobile else Vector2((last_size.x - 690) / 2, 50)
	modal.size = Vector2(last_size.x - 24, last_size.y - 32) if mobile else Vector2(690, minf(780, last_size.y - 100))
	modal.add_theme_stylebox_override("panel", flat(PAPER))
	root.add_child(modal)
	label(modal, title, Rect2(16, 12, modal.size.x - 108, 32), 21 if mobile else 26)
	button(modal, "閉じる", Rect2(modal.size.x - 84, 12, 68, 34), close_modal).grab_focus()
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size = modal.size - Vector2(32, 80)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	return box

func paragraph(box: VBoxContainer, text: String, pixels: int = 15) -> Label:
	var l = Label.new()
	l.text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", pixels)
	l.add_theme_color_override("font_color", INK)
	box.add_child(l)
	return l

func row_button(box: VBoxContainer, text: String, action: Callable, primary: bool = false) -> Button:
	var b: Button = button(box, text, Rect2(0, 0, 240, 42), action, primary)
	b.custom_minimum_size.y = 42
	return b

func background_focus(node: Node, enabled: bool) -> void:
	if node == modal or node == backdrop: return
	if node is Button or node == view: node.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for child in node.get_children(): background_focus(child, enabled)

func close_modal() -> void:
	if is_instance_valid(modal): root.remove_child(modal); modal.queue_free()
	modal = null
	if is_instance_valid(backdrop):
		if backdrop.get_parent() == root: root.remove_child(backdrop)
		backdrop.queue_free()
	backdrop = null
	modal_open = false
	if root != null: background_focus(root, true)

func open_lineage() -> void:
	var h: Dictionary = sim.history.get(str(selected), {})
	var box: VBoxContainer = begin_modal("親子の面影")
	if h.is_empty(): paragraph(box, "まだ観察記録がありません。"); return
	paragraph(box, "%s · 第%d世代" % [h.name, h.generation], 19)
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 120
	box.add_child(row)
	var ids: Array = h.parents.duplicate()
	ids.append(selected)
	for id in ids:
		var entry: Dictionary = sim.history[str(int(id))]
		var p = Portrait.new()
		p.genes = entry.genes
		p.caption = ("この子" if int(id) == selected else "親") + " #%03d" % id
		p.custom_minimum_size = Vector2(90, 120)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
	if h.parents.is_empty(): paragraph(box, "この子は島の創始個体。ここから系譜が始まります。")
	else:
		paragraph(box, "両親から遺伝情報を1本ずつ継承。脚・節は片方の特徴、体格などは両方の影響が現れます。まれに変異が加わります。")
		for parent in h.parents:
			row_button(box, "親：" + sim.history[str(int(parent))].name, func(): select_creature(int(parent)); open_lineage())
	paragraph(box, "子孫の記録", 19)
	var children: Array = sim.descendants(selected)
	var alive: int = 0
	for id in children:
		if not sim.living(int(id)).is_empty(): alive += 1
	paragraph(box, "子孫 %d匹 / いま生きている子孫 %d匹" % [children.size(), alive])
	if children.is_empty(): paragraph(box, "子孫はまだいません。元気な成体どうしが出会うと、卵が生まれます。")
	for i in mini(children.size(), 40):
		var id: int = int(children[children.size() - 1 - i])
		var child: Dictionary = sim.history[str(id)]
		row_button(box, "%s · 第%d世代%s" % [child.name, child.generation, " / 土へ" if child.died >= 0 else ""], func(): select_creature(id); close_modal(); view.follow = true)
	if children.size() > 40: paragraph(box, "最近の40匹を表示。各個体から親をたどれます。")
	var name_input = LineEdit.new()
	name_input.text = h.name
	name_input.max_length = 40
	name_input.placeholder_text = "この子の名前"
	name_input.add_theme_font_override("font", font)
	name_input.add_theme_color_override("font_color", INK)
	name_input.add_theme_stylebox_override("normal", flat(PAPER))
	name_input.custom_minimum_size.y = 42
	box.add_child(name_input)
	row_button(box, "名前を付ける", func():
		var value: String = name_input.text.strip_edges()
		if value.is_empty(): name_input.placeholder_text = "名前を入力してください"; return
		sim.history[str(selected)].name = value
		close_modal(); refresh(); say("名前を記録しました。保存で残せます。"))

func open_notebook() -> void:
	var box: VBoxContainer = begin_modal("観察手帳")
	paragraph(box, "なんでこうなった。", 25)
	paragraph(box, "食べる、出会う、卵を産む。眺めるだけで世代が進みます。生き物を選ぶと、体の特徴と親子のつながりが見られます。")
	paragraph(box, "草地は歩きやすい。茂みは小さな体が有利。浅瀬はヒレの適性と長い脚が役立ちます。大きい体や装甲には維持の負担があります。雨は餌の再生を早めます。")
	paragraph(box, "初期版：卵は4秒、成体は18秒から。寿命は体質で変化します。『第○世代』は両親の大きい方＋1。系譜は祖先の記録で、新種の認定ではありません。")
	row_button(box, "おまかせ観察：" + ("ON" if auto_watch else "OFF"), func(): auto_watch = not auto_watch; open_notebook())
	row_button(box, "動きを控える：" + ("ON" if reduced else "OFF"), func(): reduced = not reduced; view.reduced = reduced; open_notebook())
	paragraph(box, "観察の達成", 19)
	var generation: int = 0
	for h in sim.history.values(): generation = maxi(generation, h.generation)
	for task in [[sim.births > 0, "はじめての卵"], [generation >= 3, "3世代のつながり"], [sim.births >= 50, "50匹の誕生を見届ける"]]:
		paragraph(box, ("達成  " if task[0] else "未達成  ") + task[1])
	paragraph(box, "最近のできごと", 19)
	for e in sim.events.slice(0, 18):
		if e.id > 0: row_button(box, "%d秒  %s" % [e.time, e.text], func(): select_creature(int(e.id)); open_lineage())
		else: paragraph(box, "%d秒  %s" % [e.time, e.text])
	paragraph(box, "保存はこの端末・ブラウザ内。30秒ごとに自動保存。別タブや閉じている間の進化は計算しません。手帳を開いている間も停止します。")
	paragraph(box, "Space 停止 / 1・2・4 速度 / N 次の個体 / F 追跡 / R 雨 / L 系譜 / H 手帳 / S 保存 / Esc 閉じる")
	row_button(box, "新しい島を始める", confirm_reset)

func confirm_reset() -> void:
	var box: VBoxContainer = begin_modal("新しい島へ")
	paragraph(box, "現在の世界を前の島として保存し、新しいseedで始めます。前の島は一つだけ残ります。")
	row_button(box, "保存して、新しい島へ", func():
		if not save_world(true): return
		var error: Error = DirAccess.copy_absolute(SAVE, "user://previous-island.json")
		if error != OK: say("前の島を保存できません。今の島を続けます。"); return
		sim = World.new(int(Time.get_unix_time_from_system()))
		view.sim = sim; selected = 1; paused = false; view.follow = false; view.camera = World.BOUNDS * 0.5
		close_modal(); save_world(true); refresh(), true)
	if FileAccess.file_exists("user://previous-island.json"):
		row_button(box, "前の島を復元する", func():
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://previous-island.json"))
			var restored = World.decode(data.get("world") if data is Dictionary else null)
			if restored == null: say("前の島を読み込めません。現在の島を保持します。"); return
			if not save_world(true): return
			if DirAccess.copy_absolute(SAVE, "user://previous-island.json") != OK: say("今の島の退避に失敗しました。"); return
			sim = restored; view.sim = sim; selected = 1; close_modal(); save_world(true); refresh(); say("前の島を復元しました。"))

func manual_save() -> void:
	if save_blocked:
		var box: VBoxContainer = begin_modal("保存データの復旧")
		paragraph(box, "以前の保存を読み込めなかったため、自動保存を止めています。元ファイルを退避して、この島を保存できます。")
		row_button(box, "元ファイルを退避して保存", func():
			if FileAccess.file_exists(SAVE):
				if DirAccess.copy_absolute(SAVE, "user://unreadable-%d.json" % Time.get_unix_time_from_system()) != OK: say("退避に失敗しました。"); return
			save_blocked = false; close_modal(); save_world(true))
	else: save_world(true)

func save_world(manual: bool) -> bool:
	if save_blocked: say("保存の復旧が必要です。保存ボタンを押してください。"); return false
	if not qa.is_empty(): say("検証用の島は通常の保存に書き込みません。"); return true
	var file = FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null: say("保存できません。端末の空き容量・保存許可を確認してください。"); return false
	file.store_string(JSON.stringify({"world": World.encode(sim.snapshot()), "selected": selected, "speed": speed, "reduced": reduced, "auto_watch": auto_watch}, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(SAVE + ".tmp", SAVE) != OK: say("保存に失敗しました。前の記録を保持します。"); return false
	if manual: say("この端末に、島と系譜を保存しました。")
	return true

func load_world() -> void:
	if not FileAccess.file_exists(SAVE): return
	if FileAccess.get_file_as_bytes(SAVE).size() > 48000000: save_blocked = true; say("保存が大きすぎるため読み込みを止めました。保存から復旧できます。"); return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var restored = World.decode(data.get("world") if data is Dictionary else null)
	if restored == null:
		save_blocked = true
		say("保存を読み込めません。元データを保持。保存から復旧できます。")
		return
	sim = restored
	selected = int(data.get("selected", 1)) if World.number(data.get("selected", 1), 1, sim.next_id) else 1
	speed = int(data.get("speed", 1)) if data.get("speed", 1) in [1, 2, 4] else 1
	reduced = data.get("reduced", reduced) == true
	auto_watch = data.get("auto_watch", false) == true
	say("おかえりなさい。前の島の続きです。")

func fixture() -> void:
	if qa == "empty": sim = World.new(7, 0)
	elif qa == "family":
		sim = World.new(19, 20)
		sim.creatures[0].age = 30; sim.creatures[1].age = 30
		sim.creatures[0].cooldown = 0; sim.creatures[1].cooldown = 0
		sim.creatures[0].energy = 90; sim.creatures[1].energy = 90
		sim.breed(sim.creatures[0], sim.creatures[1])
		selected = sim.next_id - 1
	elif qa == "crowd": sim = World.new(88, 200); sim.capacity = 200
	elif qa == "save-error": save_blocked = true; say("保存を読み込めません。保存から復旧できます。")
