extends Control
## Native ornaments for the portrait stage and paper dividers.
@export var variant := "portrait"
@export var accent := Color("efbd69")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if variant == "portrait":
		var p := Vector2(size.x * 0.46, size.y * 0.54)
		var radius := minf(size.x * 0.43, size.y * 0.46)
		draw_circle(p, radius, Color("c1e4d8"))
		draw_arc(p, radius - 7, 0, TAU, 90, Color("fff8e5"), 2.0, true)
		for i: int in 16:
			var direction := Vector2.from_angle(float(i) * TAU / 16.0)
			draw_line(p + direction * (radius - 19), p + direction * (radius - 12), Color(0.3, 0.6, 0.61, 0.34), 1.7, true)
		for i: int in 4:
			_star(p + Vector2(-radius * 0.8 + i * radius * 0.5, radius * (0.68 if i % 2 else -0.7)), 5 + i % 3, accent)
	elif variant == "rule":
		var y := size.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("b0ccc0"), 1.5, true)
		for i: int in 3:
			_star(Vector2(size.x * 0.5 + (i - 1) * 18, y), 3 if i != 1 else 5, accent)
	elif variant == "seal":
		var p := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(p, radius, Color("f4c05d"))
		draw_arc(p, radius - 5, 0, TAU, 64, Color("fff8e5"), 2, true)
		_star(p, radius * 0.54, Color("fff8e5"))
	elif variant == "frame":
		var ink := Color(0.36, 0.57, 0.56, 0.4)
		for p: Vector2 in [Vector2(7,7), Vector2(size.x-7,7), Vector2(7,size.y-7), Vector2(size.x-7,size.y-7)]:
			draw_circle(p, 1.5, ink)
		draw_line(Vector2(16,5), Vector2(size.x-16,5), Color(1,1,1,0.65), 1, true)

func _star(p: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 8:
		points.append(p + Vector2.from_angle(-PI / 2 + i * TAU / 8) * (radius if i % 2 == 0 else radius * 0.28))
	draw_colored_polygon(points, color)
