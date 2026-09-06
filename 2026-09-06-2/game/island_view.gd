extends Control
const World = preload("res://core/world.gd")
const DNA = preload("res://core/genome.gd")
const Art = preload("res://creature_art.gd")
signal picked(id: int)
var sim
var art = Art.new()
var selected: int = 1
var zoom: float = 1.0
var camera: Vector2 = World.BOUNDS * 0.5
var follow: bool = false
var reduced: bool = false
var dragging: bool = false
var drag_distance: float = 0.0
var last_pointer: Vector2
var motion_time: float = 0
var visual_time: float = 0
var positions: Dictionary = {}
var font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")

func unit_scale() -> float:
	return minf(size.x / World.BOUNDS.x, size.y / World.BOUNDS.y) * zoom

func screen(p: Vector2) -> Vector2:
	return (p - camera) * unit_scale() + size * 0.5

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _process(delta: float) -> void:
	if sim == null: return
	motion_time = visual_time
	var alive_ids: Dictionary = {}
	for c in sim.creatures:
		alive_ids[c.id] = true
		var target: Vector2 = Vector2(c.x, c.y)
		positions[c.id] = positions.get(c.id, target).lerp(target, 1 - exp(-delta * 18))
	for id in positions.keys():
		if not alive_ids.has(id): positions.erase(id)
	if follow:
		var c: Dictionary = sim.living(selected)
		if not c.is_empty(): camera = camera.lerp(Vector2(c.x, c.y), 1 - exp(-delta * 3))
	queue_redraw()

func ellipse(center: Vector2, radius: Vector2, color: Color, edge: Color = Color.TRANSPARENT) -> void:
	var points: PackedVector2Array = []
	for i in 65:
		var a: float = i * TAU / 64
		var wave: float = 1 + sin(a * 5) * 0.025
		points.append(screen(center + Vector2(cos(a), sin(a)) * radius * wave))
	draw_colored_polygon(points, color)
	if edge.a > 0: draw_polyline(points, edge, 2, true)

func _draw() -> void:
	if sim == null: return
	var ink: Color = Color("253d36")
	draw_rect(Rect2(Vector2.ZERO, size), Color("eee6cb"))
	var island: Rect2 = Rect2(screen(Vector2.ZERO), World.BOUNDS * unit_scale())
	draw_rect(island, Color("d4dcb2"))
	ellipse(Vector2(315, 465), Vector2(230, 225), Color("a7c094"))
	ellipse(Vector2(820, 360), Vector2(258, 293), Color("f4e5be"))
	ellipse(Vector2(820, 360), Vector2(245, 280), Color("99c8bb"), Color("6c9e90"))
	for i in 100:
		var at: Vector2 = Vector2(fmod(i * 179.3 + 37, 1080) + 10, fmod(i * 137.9 + 17, 740) + 10)
		var p: Vector2 = screen(at)
		if World.habitat(at) == 2:
			draw_arc(p, 5 * unit_scale(), 0.2, 2.7, 10, Color("73ab9c"), 1.0, true)
		else:
			draw_line(p, p + Vector2(-2, -4) * unit_scale(), Color("8da77e"), 1.2, true)
			draw_line(p, p + Vector2(3, -5) * unit_scale(), Color("8da77e"), 1.2, true)
	for plant in sim.plants:
		if plant.food < 1: continue
		var at: Vector2 = screen(Vector2(plant.x, plant.y))
		var r: float = (2 + plant.food * 0.11) * unit_scale()
		var water: bool = World.habitat(Vector2(plant.x, plant.y)) == 2
		draw_circle(at, r + 1, Color("46684f"))
		draw_circle(at - Vector2(r * 0.2, r * 0.3), r * 0.85, Color("e9c56d") if water else Color("f5e3a0"))
		if not water: draw_line(at, at - Vector2(0, r + 3), Color("46684f"), 1.5, true)
	var ordered: Array = sim.creatures.duplicate()
	ordered.sort_custom(func(a, b): return a.y < b.y)
	for c in ordered:
		var pos: Vector2 = screen(positions.get(c.id, Vector2(c.x, c.y)))
		if not Rect2(Vector2(-100, -100), size + Vector2(200, 200)).has_point(pos): continue
		if c.id == selected:
			draw_arc(pos, 34 * unit_scale(), 0, TAU, 40, Color("dc694b"), 3, true)
		art.render(self, c.genes, pos, unit_scale(), c.angle, c.age, visual_time, c.state not in ["もぐもぐ", "卵"], reduced)
		if c.pulse > 0:
			draw_circle(pos + Vector2(0, -37) * unit_scale(), 4, Color("dc694b"))
		if c.id == selected:
			var text: String = "#%03d  %s" % [c.id, c.state]
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var where: Vector2 = Vector2(clampf(pos.x - width * 0.5, 6, maxf(6, size.x - width - 8)), clampf(pos.y - 38 * unit_scale(), 22, size.y - 12))
			draw_rect(Rect2(where - Vector2(5, 17), Vector2(width + 10, 23)), Color("fff7df"))
			draw_string(font, where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	if sim.rain > 0 and not reduced:
		for i in 45:
			var p: Vector2 = Vector2(fmod(i * 97.3 + motion_time * 18, size.x), fmod(i * 53.1 + motion_time * 220, size.y))
			draw_line(p, p + Vector2(-3, 11), Color(0.22, 0.47, 0.43, 0.35), 1.5, true)
	draw_rect(Rect2(Vector2.ZERO, size), ink, false, 3)
	if has_focus(): draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color("dc694b"), false, 2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = minf(3.5, zoom * 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = maxf(1, zoom / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: dragging = true; drag_distance = 0; last_pointer = event.position; grab_focus()
			else:
				dragging = false
				if drag_distance < 8:
					var best: float = 36
					var id: int = -1
					for c in sim.creatures:
						var distance: float = screen(Vector2(c.x, c.y)).distance_to(event.position)
						if distance < best: best = distance; id = c.id
					if id > 0: picked.emit(id)
	elif event is InputEventMouseMotion and dragging:
		drag_distance += event.relative.length()
		camera -= event.relative / unit_scale()
		camera = camera.clamp(Vector2.ZERO, World.BOUNDS)
		follow = false
