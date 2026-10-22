extends Control
## Painted equipment and reward icons within the manuscript selection feedback.

const Grimoire = preload("res://scripts/grimoire_theme.gd")
const Illustrated := preload("res://scripts/illustrated_assets.gd")

var gold := Grimoire.GOLD
var blue := Grimoire.ECHO
var paper := Grimoire.TEXT
var on_paper := false:
	set(value):
		on_paper = value
		queue_redraw()

var kind := "lightning":
	set(value):
		kind = value
		queue_redraw()
var evolved := false:
	set(value):
		evolved = value
		queue_redraw()

func _ready() -> void:
	Illustrated.warm_cache()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	gold = Grimoire.GOLD_INK if on_paper else Grimoire.GOLD
	blue = Grimoire.ECHO_INK if on_paper else Grimoire.ECHO
	paper = Grimoire.INK if on_paper else Grimoire.TEXT
	var id := str(kind)
	var is_evolved := evolved or id.ends_with("_evolved") or id.begins_with("evolution_")
	id = id.trim_suffix("_evolved").trim_prefix("evolution_")
	var fit := minf(size.x, size.y) / 54.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * fit)
	draw_circle(Vector2.ZERO, 22, Color(gold, 0.055))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 48, Color(gold, 0.32), 1, true)
	var painted := Illustrated.draw_icon(self, id, Vector2.ZERO, 40.0)
	if is_evolved:
		draw_arc(Vector2.ZERO, 19.5, 0, TAU, 48, Color(blue, 0.50), 1, true)
		for angle in [-PI * 0.5, PI * 0.5]:
			_star(Vector2.from_angle(angle) * 21, 4, paper)
	if painted:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match id:
		"empty":
			draw_line(Vector2(-8, 0), Vector2(8, 0), Color(paper, 0.28), 1.5, true)
		"new", "evolution":
			_star(Vector2.ZERO, 15, gold)
			_star(Vector2.ZERO, 8, blue)
		_:
			_book()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _book() -> void:
	draw_rect(Rect2(-14, -11, 28, 24), Color(gold, 0.14))
	draw_rect(Rect2(-14, -11, 28, 24), gold, false, 1.7)
	draw_line(Vector2(0, -11), Vector2(0, 13), gold, 1.7, true)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 4, -4), Vector2(side * 10, -4), Color(paper, 0.65), 1, true)
		draw_line(Vector2(side * 4, 2), Vector2(side * 10, 2), Color(paper, 0.65), 1, true)
	_star(Vector2(0, -17), 3, blue)

func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(at + Vector2.from_angle(-PI * 0.5 + float(i) * TAU / 8) * (radius if i % 2 == 0 else radius * 0.28))
	draw_colored_polygon(points, color)

