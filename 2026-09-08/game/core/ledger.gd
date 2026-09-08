class_name RescueLedger
extends Control

signal stage_selected(index: int)
signal dismissed
var tiles: Array[Button] = []
var close_button: Button
var heading: Label
var summary: Label
var scroll: ScrollContainer
var grid: GridContainer

class WorkTile extends Button:
	var work_index: int = 0
	var completed: bool = false
	var cuts: int = 0
	func _draw() -> void:
		var room: int = RescueArt.room_for(work_index)
		draw_rect(Rect2(7,7,size.x-14,104),RescueArt.paper(room))
		draw_line(Vector2(14,100),Vector2(size.x-14,100),RescueArt.accent(room),2)
		if work_index in [5,7,11,13,14,15]:
			draw_set_transform(Vector2(size.x/2-22,70),-0.08,Vector2.ONE*1.25)
			RescueArt.vase(self,RescueArt.kind_for(work_index))
			draw_set_transform(Vector2(size.x/2+22,70),0.08,Vector2.ONE*1.25)
			RescueArt.vase(self,RescueArt.kind_for(work_index,1))
		else:
			draw_set_transform(Vector2(size.x/2,68),0,Vector2.ONE*1.6)
			RescueArt.vase(self,RescueArt.kind_for(work_index))
		draw_set_transform(Vector2.ZERO)
		if completed:
			draw_circle(Vector2(size.x-25,25),11,Color("426d60"))
			draw_polyline(PackedVector2Array([Vector2(size.x-31,25),Vector2(size.x-27,29),Vector2(size.x-20,20)]),Color("faf6e9"),2,true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	heading = Label.new()
	heading.text = "搬出台帳"
	heading.add_theme_font_size_override("font_size",30)
	add_child(heading)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size",15)
	add_child(summary)
	close_button = Button.new()
	close_button.text = "模型に戻る"
	close_button.pressed.connect(func() -> void: dismissed.emit())
	add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	for i: int in range(RescueLevels.all().size()):
		var tile := WorkTile.new()
		tile.work_index = i
		tile.custom_minimum_size = Vector2(140,184)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = "%02d %s を遊ぶ" % [i+1,RescueArt.WORKS[i]]
		tile.pressed.connect(_select_stage.bind(i))
		grid.add_child(tile)
		tiles.append(tile)
		var name_label := Label.new()
		name_label.text = "%02d  %s" % [i+1,RescueArt.WORKS[i]]
		name_label.position = Vector2(12,118)
		name_label.add_theme_font_size_override("font_size",14)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(name_label)
		var record := Label.new()
		record.name = "Record"
		record.position = Vector2(12,145)
		record.add_theme_font_size_override("font_size",13)
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(record)
	var focus_order: Array[Control] = [close_button]
	for tile: Button in tiles:
		focus_order.append(tile)
	for i: int in range(focus_order.size()):
		focus_order[i].focus_next = focus_order[(i+1)%focus_order.size()].get_path()
		focus_order[i].focus_previous = focus_order[posmod(i-1,focus_order.size())].get_path()
	get_viewport().size_changed.connect(_layout)
	_layout()

func open(best: Dictionary) -> void:
	visible = true
	summary.text = "%d / %d 模型を搬出済み\n作品を選んで、搬出をはじめる。" % [best.size(),tiles.size()]
	for i: int in range(tiles.size()):
		var tile: WorkTile = tiles[i]
		tile.completed = best.has(str(i))
		tile.cuts = int(best.get(str(i),0))
		(tile.get_node("Record") as Label).text = "搬出済 / 最少 %d 切断" % tile.cuts if tile.completed else "未搬出 / 選んで遊ぶ"
		tile.queue_redraw()
	scroll.scroll_vertical = 0
	_layout()
	close_button.grab_focus()

func _layout() -> void:
	size = get_viewport_rect().size
	var w: float = size.x
	heading.position = Vector2(24,24)
	close_button.position = Vector2(w-140,24)
	close_button.size = Vector2(116,44)
	summary.position = Vector2(24,76)
	summary.size = Vector2(w-48,44)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Change columns first: otherwise the old four-column minimum clamps width.
	grid.columns = 2 if w<700 else 4
	scroll.position = Vector2(24,136)
	scroll.size = Vector2(w-48,maxf(100,size.y-160))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("ece7db"))
	draw_line(Vector2(24,127),Vector2(size.x-24,127),Color("b6ac97"),1)

func _select_stage(index: int) -> void:
	stage_selected.emit(index)
