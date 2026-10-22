extends Control
## Drawn manuscript sigils. Labels supply names; silhouettes distinguish contents.

const Grimoire = preload("res://scripts/grimoire_theme.gd")

var gold := Grimoire.GOLD
var blue := Grimoire.ECHO
var paper := Grimoire.TEXT
var ink := Grimoire.INK
var leaf := Grimoire.LEAF
var rose := Grimoire.ROSE
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	gold = Grimoire.GOLD_INK if on_paper else Grimoire.GOLD
	blue = Grimoire.ECHO_INK if on_paper else Grimoire.ECHO
	paper = Grimoire.INK if on_paper else Grimoire.TEXT
	ink = Grimoire.PAPER_EDGE if on_paper else Grimoire.INK
	leaf = Grimoire.INK_SOFT if on_paper else Grimoire.LEAF
	rose = Grimoire.DANGER_INK if on_paper else Grimoire.ROSE
	var id := str(kind)
	var is_evolved := evolved or id.ends_with("_evolved") or id.begins_with("evolution_")
	id = id.trim_suffix("_evolved").trim_prefix("evolution_")
	var fit := minf(size.x, size.y) / 54.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * fit)
	draw_circle(Vector2.ZERO, 22, Color(gold, 0.055))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 48, Color(gold, 0.32), 1, true)
	if is_evolved:
		draw_arc(Vector2.ZERO, 19.5, 0, TAU, 48, Color(blue, 0.50), 1, true)
		for angle in [-PI * 0.5, PI * 0.5]:
			_star(Vector2.from_angle(angle) * 21, 4, paper)
	match id:
		"lightning":
			_bolt(Vector2.ZERO, 1.0, gold)
			if is_evolved:
				_bolt(Vector2(-8, -2), 0.56, blue)
				_bolt(Vector2(8, 3), 0.56, paper)
		"moon":
			draw_arc(Vector2(-2, 0), 14, -PI * 0.67, PI * 0.67, 30, blue, 2.7, true)
			draw_line(Vector2(0, -14), Vector2(7, -6), gold, 1.5, true)
			_star(Vector2(0, 0), 4, gold)
			if is_evolved:
				draw_arc(Vector2(4, 0), 13, PI * 0.34, PI * 1.66, 30, gold, 2, true)
		"thorn":
			_thorn(Vector2.ZERO, leaf)
			if is_evolved:
				draw_arc(Vector2.ZERO, 15, 0, TAU, 36, Color(gold, 0.7), 1.4, true)
		"wisp":
			_flame(Vector2.ZERO, blue)
			if is_evolved:
				for side in [-1.0, 1.0]:
					draw_polyline(PackedVector2Array([Vector2(side * 3, 4), Vector2(side * 16, -7), Vector2(side * 11, 12), Vector2(side * 2, 13)]), gold, 1.5, true)
		"frost":
			_snowflake(Vector2.ZERO, 16, blue)
			if is_evolved:
				_hexagon(Vector2.ZERO, 13, gold)
		"bell":
			_bell(Vector2.ZERO, 1, gold)
			if is_evolved:
				draw_arc(Vector2.ZERO, 19, -PI * 0.30, PI * 0.30, 18, blue, 1.5, true)
				draw_arc(Vector2.ZERO, 19, PI * 0.70, PI * 1.30, 18, blue, 1.5, true)
		"storm_ink":
			_bottle(Vector2(0, 3), 0.88, ink)
			_bolt(Vector2(0, 1), 0.48, gold)
			_star(Vector2(8, -14), 3, blue)
		"moonstone":
			_gem(Vector2.ZERO, 13, blue)
			draw_arc(Vector2(1, -1), 7, -PI * 0.5, PI * 0.6, 20, paper, 2, true)
		"thorn_seed":
			draw_circle(Vector2(0, 10), 5, gold)
			draw_line(Vector2(0, 8), Vector2(0, -8), leaf, 2.5, true)
			_leaf(Vector2(-6, -4), 0.60, leaf, -0.8)
			_leaf(Vector2(7, -9), 0.65, leaf, 0.6)
		"lantern_oil":
			_bottle(Vector2(-3, 3), 0.84, gold)
			draw_arc(Vector2(8, -5), 5, -PI * 0.5, PI * 0.5, 15, gold, 1.8, true)
			_flame(Vector2(-3, 4), gold, 0.45)
		"ice_crystal":
			_gem(Vector2(-5, 1), 12, blue)
			_gem(Vector2(7, 6), 7, paper)
			draw_line(Vector2(-5, -11), Vector2(-5, 13), Color(ink, 0.5), 1, true)
		"silver_bell":
			_bell(Vector2.ZERO, 0.83, blue)
			_star(Vector2(12, -13), 3, paper)
		"swift_boots", "stride":
			_boot(Vector2(-4, -1), gold)
			draw_line(Vector2(-17, 0), Vector2(-9, 0), blue, 1.7, true)
			draw_line(Vector2(-18, 6), Vector2(-11, 6), blue, 1.7, true)
		"magnet_ring":
			draw_arc(Vector2(0, 2), 10, -PI * 0.10, PI * 1.10, 28, blue, 4, true)
			draw_line(Vector2(-10, -7), Vector2(-10, 2), paper, 4, true)
			draw_line(Vector2(10, -7), Vector2(10, 2), gold, 4, true)
			_star(Vector2(0, -10), 3, gold)
		"ward_leaf":
			_leaf(Vector2.ZERO, 1.05, leaf, 0)
			draw_arc(Vector2.ZERO, 18, PI * 0.15, PI * 0.85, 22, gold, 1.7, true)
		"blood_vial":
			_bottle(Vector2(0, 2), 0.9, rose)
			_heart(Vector2(0, 4), 0.43, paper)
		"hourglass":
			_hourglass()
		"echo_mirror":
			_mirror()
		"heart":
			_heart(Vector2.ZERO, 1, rose)
		"heal":
			draw_line(Vector2(0, -13), Vector2(0, 13), leaf, 6, true)
			draw_line(Vector2(-13, 0), Vector2(13, 0), leaf, 6, true)
			_star(Vector2(11, -12), 3, gold)
		"power":
			_book()
		"echo", "resonance", "specialization":
			draw_arc(Vector2(-7, 0), 11, 0, TAU, 32, gold, 2, true)
			draw_arc(Vector2(7, 0), 11, 0, TAU, 32, blue, 2, true)
			_star(Vector2.ZERO, 4, paper)
		"treasure", "chest":
			_chest()
		"hound":
			var muzzle := PackedVector2Array([Vector2(-16, 2), Vector2(-13, -10), Vector2(-4, -4), Vector2(4, -4), Vector2(13, -10), Vector2(16, 2), Vector2(6, 12), Vector2(-6, 12), Vector2(-16, 2)])
			draw_colored_polygon(muzzle, Color(paper, 0.20))
			draw_polyline(muzzle, paper, 1.5, true)
			draw_line(Vector2(-9, 0), Vector2(-3, 2), rose, 2, true)
			draw_line(Vector2(9, 0), Vector2(3, 2), rose, 2, true)
		"charger":
			for side in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([Vector2(side * 3, 13), Vector2(side * 6, -2), Vector2(side * 13, -9), Vector2(side * 10, -17)]), paper, 2.2, true)
				draw_line(Vector2(side * 7, -3), Vector2(side * 17, -12), gold, 1.5, true)
			_gem(Vector2(0, 8), 6, rose)
		"archer":
			draw_arc(Vector2(-9, 0), 16, -PI * 0.44, PI * 0.44, 28, paper, 2, true)
			draw_line(Vector2(-6, -16), Vector2(-6, 16), gold, 1.3, true)
			draw_line(Vector2(-15, 0), Vector2(17, 0), rose, 2, true)
			draw_polyline(PackedVector2Array([Vector2(10, -6), Vector2(17, 0), Vector2(10, 6)]), rose, 2, true)
		"sentinel":
			var shield := PackedVector2Array([Vector2(-12, -13), Vector2(12, -13), Vector2(13, 4), Vector2(0, 17), Vector2(-13, 4), Vector2(-12, -13)])
			draw_colored_polygon(shield, Color(paper, 0.17))
			draw_polyline(shield, paper, 1.8, true)
			draw_line(Vector2(0, -7), Vector2(0, 10), rose, 2, true)
			draw_line(Vector2(-7, 0), Vector2(7, 0), rose, 2, true)
		"bat":
			for side in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(0, -2), Vector2(side * 18, -13), Vector2(side * 13, 4), Vector2(side * 8, 0), Vector2(side * 5, 8), Vector2(0, 4)])
				draw_colored_polygon(wing, rose)
			_star(Vector2(0, 1), 3, paper)
		"boss_thorn":
			_thorn(Vector2.ZERO, leaf)
			_crown()
		"boss_mirror":
			_mirror()
			_crown()
		"boss_bell":
			_bell(Vector2(0, 2), 0.85, gold)
			_crown()
		"chapter_garden":
			_thorn(Vector2.ZERO, leaf)
			for angle in [-PI * 0.5, PI * 0.17, PI * 0.83]:
				_star(Vector2.from_angle(angle) * 12, 4, rose)
		"chapter_mirror":
			_mirror()
		"chapter_bell":
			_bell(Vector2.ZERO, 1, gold)
			for angle in [0.0, PI]:
				draw_arc(Vector2.ZERO, 19, angle - 0.32, angle + 0.32, 14, blue, 1.5, true)
		"dawn":
			draw_arc(Vector2(0, 4), 14, PI, TAU, 36, gold, 2.6, true)
			draw_line(Vector2(-20, 5), Vector2(20, 5), gold, 2, true)
			for angle in [-PI * 0.88, -PI * 0.68, -PI * 0.5, -PI * 0.32, -PI * 0.12]:
				var ray := Vector2.from_angle(angle)
				draw_line(Vector2(0, 4) + ray * 18, Vector2(0, 4) + ray * 23, gold, 1.6, true)
			draw_arc(Vector2(-6, 7), 9, 0, PI, 20, blue, 1.8, true)
			draw_arc(Vector2(6, 7), 9, 0, PI, 20, gold, 1.8, true)
		"empty", "locked":
			draw_line(Vector2(-8, 0), Vector2(8, 0), Color(paper, 0.28), 1.5, true)
		"new", "evolution":
			_star(Vector2.ZERO, 15, gold)
			_star(Vector2.ZERO, 8, blue)
		_:
			_book()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _bolt(at: Vector2, scale_factor: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(4, -17), Vector2(-10, 2), Vector2(-1, 1), Vector2(-4, 16), Vector2(11, -4), Vector2(2, -3)])
	for i in range(points.size()):
		points[i] = points[i] * scale_factor + at
	draw_colored_polygon(points, color)

func _thorn(at: Vector2, color: Color) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-12, 13), at + Vector2(-4, 5), at + Vector2(0, -4), at + Vector2(6, -15)]), color, 2.6, true)
	for point in [at + Vector2(-5, 6), at + Vector2(0, -4)]:
		draw_polyline(PackedVector2Array([point + Vector2(-8, -6), point, point + Vector2(8, 2)]), color, 1.8, true)
	draw_line(at + Vector2(-3, -6), at + Vector2(7, -8), gold, 1.2, true)

func _flame(at: Vector2, color: Color, scale_factor: float = 1) -> void:
	var flame := PackedVector2Array([Vector2(1, -18), Vector2(9, -6), Vector2(12, 3), Vector2(8, 12), Vector2(0, 16), Vector2(-9, 12), Vector2(-13, 3), Vector2(-5, -8), Vector2(-4, 3), Vector2(1, -3)])
	for i in range(flame.size()):
		flame[i] = flame[i] * scale_factor + at
	draw_colored_polygon(flame, color)
	_star(at + Vector2(0, 5) * scale_factor, 5 * scale_factor, paper)

func _snowflake(at: Vector2, radius: float, color: Color) -> void:
	for i in range(6):
		var direction := Vector2.from_angle(float(i) * TAU / 6 - PI * 0.5)
		draw_line(at + direction * 2, at + direction * radius, color, 2, true)
		for side in [-1.0, 1.0]:
			draw_line(at + direction * radius * 0.62, at + direction * radius * 0.62 + direction.rotated(PI - side * 0.72) * radius * 0.33, color, 1.5, true)

func _hexagon(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(7):
		points.append(at + Vector2.from_angle(float(i) * TAU / 6 - PI * 0.5) * radius)
	draw_polyline(points, color, 1.4, true)

func _bell(at: Vector2, scale_factor: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-14, 9), Vector2(-10, 3), Vector2(-8, -8), Vector2(-4, -13), Vector2(4, -13), Vector2(8, -8), Vector2(10, 3), Vector2(14, 9), Vector2(-14, 9)])
	for i in range(points.size()):
		points[i] = points[i] * scale_factor + at
	draw_colored_polygon(points, Color(color, 0.14))
	draw_polyline(points, color, 2, true)
	draw_line(at + Vector2(-15, 13) * scale_factor, at + Vector2(15, 13) * scale_factor, color, 2, true)
	draw_circle(at + Vector2(0, 17) * scale_factor, 2.5 * scale_factor, color)
	draw_arc(at + Vector2(0, -14) * scale_factor, 3 * scale_factor, PI, TAU, 12, color, 1.8, true)

func _gem(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius * 0.7, -radius * 0.3), at + Vector2(radius * 0.5, radius * 0.7), at + Vector2(0, radius), at + Vector2(-radius * 0.7, radius * 0.3), at + Vector2(-radius * 0.5, -radius * 0.7), at + Vector2(0, -radius)])
	draw_colored_polygon(points, Color(color, 0.22))
	draw_polyline(points, color, 1.7, true)
	draw_line(at + Vector2(0, -radius), at + Vector2(-radius * 0.17, radius * 0.2), Color(paper, 0.75), 1, true)
	draw_line(at + Vector2(-radius * 0.17, radius * 0.2), at + Vector2(0, radius), Color(paper, 0.75), 1, true)

func _bottle(at: Vector2, scale_factor: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-5, -15), Vector2(5, -15), Vector2(5, -8), Vector2(10, -2), Vector2(9, 13), Vector2(-9, 13), Vector2(-10, -2), Vector2(-5, -8), Vector2(-5, -15)])
	for i in range(points.size()):
		points[i] = points[i] * scale_factor + at
	draw_colored_polygon(points, Color(color, 0.32))
	draw_polyline(points, color, 1.8, true)
	draw_line(at + Vector2(-6, -16) * scale_factor, at + Vector2(6, -16) * scale_factor, gold, 3, true)

func _leaf(at: Vector2, scale_factor: float, color: Color, angle: float) -> void:
	var points := PackedVector2Array([Vector2(-10, 14), Vector2(-12, 0), Vector2(-6, -11), Vector2(11, -15), Vector2(11, 2), Vector2(3, 12), Vector2(-10, 14)])
	for i in range(points.size()):
		points[i] = points[i].rotated(angle) * scale_factor + at
	draw_colored_polygon(points, Color(color, 0.35))
	draw_polyline(points, color, 1.5, true)
	draw_line(at + Vector2(-10, 14).rotated(angle) * scale_factor, at + Vector2(7, -10).rotated(angle) * scale_factor, color, 1.8, true)

func _heart(at: Vector2, scale_factor: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, 15), Vector2(-15, -1), Vector2(-13, -11), Vector2(-6, -14), Vector2(0, -7), Vector2(6, -14), Vector2(13, -11), Vector2(15, -1)])
	for i in range(points.size()):
		points[i] = points[i] * scale_factor + at
	draw_colored_polygon(points, color)

func _boot(at: Vector2, color: Color) -> void:
	var boot := PackedVector2Array([at + Vector2(-4, -15), at + Vector2(7, -15), at + Vector2(5, 3), at + Vector2(15, 8), at + Vector2(15, 14), at + Vector2(-5, 14), at + Vector2(-8, 9), at + Vector2(-4, -15)])
	draw_colored_polygon(boot, Color(color, 0.18))
	draw_polyline(boot, color, 2, true)
	draw_line(at + Vector2(-3, -10), at + Vector2(6, -10), paper, 1.5, true)
	draw_line(at + Vector2(-5, 10), at + Vector2(13, 10), color, 1.3, true)

func _hourglass() -> void:
	for y in [-15.0, 15.0]:
		draw_line(Vector2(-12, y), Vector2(12, y), gold, 3, true)
	draw_polyline(PackedVector2Array([Vector2(-9, -13), Vector2(-7, -6), Vector2(5, 6), Vector2(9, 13)]), blue, 1.6, true)
	draw_polyline(PackedVector2Array([Vector2(9, -13), Vector2(7, -6), Vector2(-5, 6), Vector2(-9, 13)]), blue, 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -10), Vector2(6, -10), Vector2(0, -2)]), gold)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 12), Vector2(7, 12), Vector2(0, 7)]), gold)
	draw_line(Vector2.ZERO, Vector2(0, 5), gold, 1, true)

func _mirror() -> void:
	var mirror := PackedVector2Array([Vector2(0, -17), Vector2(12, -11), Vector2(13, 7), Vector2(0, 15), Vector2(-13, 7), Vector2(-12, -11), Vector2(0, -17)])
	draw_colored_polygon(mirror, Color(blue, 0.18))
	draw_polyline(mirror, blue, 2, true)
	draw_line(Vector2(-6, -8), Vector2(5, 7), Color(paper, 0.75), 1.5, true)
	draw_line(Vector2(0, -10), Vector2(8, 1), Color(paper, 0.42), 1, true)
	draw_line(Vector2(0, 15), Vector2(0, 20), gold, 2.5, true)
	draw_line(Vector2(-7, 20), Vector2(7, 20), gold, 2.5, true)

func _book() -> void:
	draw_rect(Rect2(-14, -11, 28, 24), Color(gold, 0.14))
	draw_rect(Rect2(-14, -11, 28, 24), gold, false, 1.7)
	draw_line(Vector2(0, -11), Vector2(0, 13), gold, 1.7, true)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 4, -4), Vector2(side * 10, -4), Color(paper, 0.65), 1, true)
		draw_line(Vector2(side * 4, 2), Vector2(side * 10, 2), Color(paper, 0.65), 1, true)
	_star(Vector2(0, -17), 3, blue)

func _chest() -> void:
	draw_rect(Rect2(-15, -3, 30, 18), Color(gold, 0.18))
	draw_rect(Rect2(-15, -3, 30, 18), gold, false, 1.8)
	var lid := PackedVector2Array([Vector2(-17, -3), Vector2(-12, -13), Vector2(12, -13), Vector2(17, -3), Vector2(-17, -3)])
	draw_polyline(lid, gold, 1.8, true)
	draw_line(Vector2(-9, -12), Vector2(-9, 13), gold, 1.3, true)
	draw_line(Vector2(9, -12), Vector2(9, 13), gold, 1.3, true)
	_star(Vector2.ZERO, 4, paper)

func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(at + Vector2.from_angle(-PI * 0.5 + float(i) * TAU / 8) * (radius if i % 2 == 0 else radius * 0.28))
	draw_colored_polygon(points, color)

func _crown() -> void:
	var crown := PackedVector2Array([Vector2(-11, -12), Vector2(-14, -20), Vector2(-4, -17), Vector2(0, -24), Vector2(4, -17), Vector2(14, -20), Vector2(11, -12)])
	draw_colored_polygon(crown, rose)
