extends PanelContainer
## A reusable engraved book cover. Ornament follows the bounds, never the text.

var accent := Color("dbc182")
var divided := false
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	if compact:
		for origin in [Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(4, size.y - 4), Vector2(size.x - 4, size.y - 4)]:
			var direction := Vector2(1 if origin.x < size.x * 0.5 else -1, 1 if origin.y < size.y * 0.5 else -1)
			draw_line(origin, origin + Vector2(7 * direction.x, 0), Color(accent, 0.65), 1.0, true)
			draw_line(origin, origin + Vector2(0, 7 * direction.y), Color(accent, 0.65), 1.0, true)
		return
	var line := Color(accent, 0.65)
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), line, false, 1.0)
	for origin in [Vector2(15, 15), Vector2(size.x - 15, 15), Vector2(15, size.y - 15), Vector2(size.x - 15, size.y - 15)]:
		var direction := Vector2(1 if origin.x < size.x * 0.5 else -1, 1 if origin.y < size.y * 0.5 else -1)
		draw_line(origin, origin + Vector2(34 * direction.x, 0), accent, 2.0, true)
		draw_line(origin, origin + Vector2(0, 34 * direction.y), accent, 2.0, true)
		var jewel: Vector2 = origin + direction * 10
		draw_polyline(PackedVector2Array([jewel + Vector2(0, -4), jewel + Vector2(4, 0), jewel + Vector2(0, 4), jewel + Vector2(-4, 0), jewel + Vector2(0, -4)]), accent, 1.5, true)
		draw_arc(origin + direction * 5, 4, 0, TAU, 16, Color(accent, 0.45), 1.0, true)
	if divided:
		draw_line(Vector2(size.x * 0.5, 30), Vector2(size.x * 0.5, size.y - 30), Color(accent, 0.3), 1.0, true)
	draw_line(Vector2(size.x * 0.5 - 27, 8), Vector2(size.x * 0.5 + 27, 8), accent, 3.0, true)
	draw_line(Vector2(size.x * 0.5 - 27, size.y - 8), Vector2(size.x * 0.5 + 27, size.y - 8), accent, 3.0, true)
