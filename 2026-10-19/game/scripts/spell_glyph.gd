extends Control
## Small vector sigils share the game palette; card labels carry their meaning.
var kind := "lightning"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var at := Vector2(26, 24)
	var gold := Color("dbc182")
	var blue := Color("92d4e8")
	draw_circle(at, 22, Color(gold, 0.065))
	draw_arc(at, 22, 0, TAU, 40, Color(gold, 0.35), 1, true)
	match kind:
		"moon":
			draw_arc(at, 14, -PI * 0.65, PI * 0.65, 30, blue, 3, true)
			draw_line(at + Vector2(0, -14), at + Vector2(7, -6), gold, 1.5, true)
			draw_circle(at + Vector2(0, 0), 3, gold)
		"heart":
			var heart := PackedVector2Array([at + Vector2(0, 15), at + Vector2(-15, -1), at + Vector2(-13, -11), at + Vector2(-6, -14), at + Vector2(0, -7), at + Vector2(6, -14), at + Vector2(13, -11), at + Vector2(15, -1)])
			draw_colored_polygon(heart, Color("cb8a98"))
		"power":
			draw_rect(Rect2(at + Vector2(-14, -11), Vector2(28, 24)), Color(gold, 0.14))
			draw_rect(Rect2(at + Vector2(-14, -11), Vector2(28, 24)), gold, false, 1.7)
			draw_line(at + Vector2(0, -11), at + Vector2(0, 13), gold, 1.7, true)
			draw_circle(at + Vector2(0, -18), 2, blue)
		"heal", "stride":
			for i in range(4):
				var direction := Vector2.from_angle(float(i) * PI * 0.5)
				draw_line(at + direction * 4, at + direction * 14, blue, 4, true)
		"echo", "resonance":
			draw_arc(at + Vector2(-7, 0), 11, 0, TAU, 32, gold, 2, true)
			draw_arc(at + Vector2(7, 0), 11, 0, TAU, 32, blue, 2, true)
		_:
			var bolt := PackedVector2Array([at + Vector2(4, -17), at + Vector2(-10, 2), at + Vector2(-1, 1), at + Vector2(-4, 16), at + Vector2(11, -4), at + Vector2(2, -3)])
			draw_colored_polygon(bolt, gold)
