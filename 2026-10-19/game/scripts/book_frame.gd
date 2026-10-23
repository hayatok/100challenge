extends PanelContainer
## Retained book surfaces. Geometry, rather than extra borders, distinguishes a page.

const Grimoire = preload("res://scripts/grimoire_theme.gd")

var accent := Grimoire.GOLD
var divided := false
var compact := false
var surface := "cover"
var route_progress := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	match surface:
		"bookmark": _bookmark()
		"paper": _page()
		"route": _route()
		"cold_book": _spread(true)
		_:
			if divided:
				_spread()
			elif compact:
				_ledger()
			else:
				_cover()

func _cover() -> void:
	draw_rect(Rect2(Vector2(0, 7), size), Color(Grimoire.NIGHT, 0.62))
	draw_rect(Rect2(Vector2.ZERO, size), Grimoire.COVER)
	draw_rect(Rect2(0, 0, 15, size.y), Grimoire.COVER_LIT)
	draw_rect(Rect2(18, 12, size.x - 30, size.y - 24), Color(Grimoire.NIGHT, 0.26))
	for y in [20.0, size.y - 24.0]:
		draw_rect(Rect2(0, y, 20, 4), Grimoire.GOLD_INK)
	for x in [28.0, size.x - 20.0]:
		draw_line(Vector2(x, 18), Vector2(x, size.y - 18), Color(accent, 0.3), 1, true)
	for origin in [Vector2(28, 18), Vector2(size.x - 20, 18), Vector2(28, size.y - 18), Vector2(size.x - 20, size.y - 18)]:
		var side := 1.0 if origin.x < size.x * 0.5 else -1.0
		draw_line(origin, origin + Vector2(20 * side, 0), accent, 2, true)

func _ledger() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x - 10, 0), Vector2(size.x, 10), size, Vector2(0, size.y)]), Color(Grimoire.NIGHT, 0.94))
	draw_rect(Rect2(0, 0, 4, size.y), Grimoire.GOLD_INK)
	draw_line(Vector2(9, size.y - 1), Vector2(size.x - 9, size.y - 1), Color(accent, 0.45), 1, true)

func _page() -> void:
	draw_rect(Rect2(5, 5, size.x - 5, size.y - 2), Color(Grimoire.NIGHT, 0.3))
	draw_rect(Rect2(2, 3, size.x - 6, size.y - 1), Grimoire.PAPER_EDGE)
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x - 20, 0), Vector2(size.x, 20), Vector2(size.x, size.y - 4), Vector2(0, size.y - 4)])
	draw_colored_polygon(points, Grimoire.PAPER_LIT)
	draw_colored_polygon(PackedVector2Array([Vector2(size.x - 20, 0), Vector2(size.x - 20, 20), Vector2(size.x, 20)]), Grimoire.PAPER)
	draw_rect(Rect2(0, 0, 7, size.y - 4), Grimoire.PAPER)
	draw_line(Vector2(16, 16), Vector2(16, size.y - 22), Color(Grimoire.PAPER_EDGE, 0.6), 1, true)
	for y in range(28, int(size.y) - 18, 32):
		draw_line(Vector2(2, y), Vector2(10, y - 2), Grimoire.PAPER_EDGE, 1, true)
	draw_line(Vector2(22, size.y - 14), Vector2(size.x - 16, size.y - 14), Color(Grimoire.PAPER_EDGE, 0.4), 1, true)

func _spread(cold: bool = false) -> void:
	var paper := Grimoire.COOL_PAPER if cold else Grimoire.PAPER
	var lit := Grimoire.COOL_PAPER_LIT if cold else Grimoire.PAPER_LIT
	var edge := Grimoire.COOL_EDGE if cold else Grimoire.PAPER_EDGE
	draw_rect(Rect2(Vector2(0, 8), size), Color(Grimoire.NIGHT, 0.65))
	draw_rect(Rect2(Vector2.ZERO, size), Grimoire.COVER)
	for inset in [7.0, 10.0, 13.0]:
		draw_rect(Rect2(inset, 8 + inset * 0.2, size.x - inset * 2, size.y - 12), edge)
	var middle := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(14, 8), Vector2(middle - 10, 14), Vector2(middle - 10, size.y - 15), Vector2(14, size.y - 9)]), lit)
	draw_colored_polygon(PackedVector2Array([Vector2(middle + 10, 14), Vector2(size.x - 14, 8), Vector2(size.x - 14, size.y - 9), Vector2(middle + 10, size.y - 15)]), paper)
	draw_rect(Rect2(middle - 10, 14, 20, size.y - 29), edge)
	draw_rect(Rect2(middle - 3, 14, 6, size.y - 29), Color(Grimoire.INK, 0.19))
	for y in range(50, int(size.y) - 24, 54):
		draw_line(Vector2(middle - 5, y), Vector2(middle + 5, y + 3), Grimoire.GOLD_INK, 1.2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(size.x - 73, 8), Vector2(size.x - 49, 8), Vector2(size.x - 49, 53), Vector2(size.x - 61, 44), Vector2(size.x - 73, 53)]), Grimoire.GOLD_INK)

func _bookmark() -> void:
	var notch := minf(18.0, minf(size.y * 0.24, size.x * 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(size.x - notch, 5), Vector2(size.x - notch, size.y), Vector2(size.x * 0.52, size.y - notch), Vector2(0, size.y)]), Color(Grimoire.NIGHT, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y - 7), Vector2(size.x * 0.52, size.y - notch - 7), Vector2(0, size.y - 7)]), accent)
	draw_rect(Rect2(8, 0, 5, size.y - 9), Color(Grimoire.PAPER_LIT, 0.38))
	draw_line(Vector2(21, 10), Vector2(size.x - 16, 10), Color(Grimoire.GOLD_INK, 0.46), 1, true)

func _route() -> void:
	var start := Vector2(0, size.y * 0.5)
	var finish := Vector2(size.x, size.y * 0.5)
	draw_line(start, finish, Grimoire.COVER_LIT, 5, true)
	var completion := clampf(float(route_progress + 1) / 3.0, 0, 1)
	draw_line(start, start.lerp(finish, completion), accent, 3, true)
	for i in range(3):
		var at := Vector2(float(i) * size.x * 0.5, size.y * 0.5)
		draw_circle(at, 7, Grimoire.COVER)
		draw_circle(at, 4, accent if i <= route_progress else Grimoire.COVER_LIT)
