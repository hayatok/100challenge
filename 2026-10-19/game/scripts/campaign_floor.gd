extends RefCounted
## Authored dressing uses the exact collision rectangles supplied by chapter_info.

const GOLD := Color("dbc182")
const BLUE := Color("92d4e8")
const STONE := Color("61716d")

static func draw_floor(view, info: Dictionary, textures: Dictionary) -> void:
	var chapter := int(info.get("id", 0)) if info.get("id", 0) is int else int(view.run.chapter)
	var bounds: Rect2 = info.get("bounds", Rect2(-1100, -800, 2200, 1600))
	var at: Vector2 = view.world(bounds.position)
	var visible_rect := Rect2(Vector2.ZERO, view.screen)
	var ground := Color("172c31") if chapter == 0 else Color("222a3d") if chapter == 1 else Color("2b2c33")
	view.draw_rect(visible_rect, Color("0c1420"))
	view.draw_rect(Rect2(at, bounds.size), ground)
	_draw_tiles(view, bounds, textures, chapter)
	match chapter:
		0:
			_draw_garden_floor(view, bounds)
		1:
			_draw_mirror_floor(view, bounds)
		_:
			_draw_bell_floor(view, bounds)
	_draw_boundary(view, bounds, chapter)

static func _draw_tiles(view, bounds: Rect2, textures: Dictionary, chapter: int) -> void:
	if not textures.has("garden_tile"):
		return
	var camera: Vector2 = view.run.player - view.screen * Vector2(0.5, 0.52)
	var tile_size := 384.0
	var start := (camera / tile_size).floor() * tile_size
	var tint := Color(0.74, 0.91, 0.89, 0.43)
	if chapter == 1:
		tint = Color(0.75, 0.78, 1.05, 0.28)
	elif chapter == 2:
		tint = Color(1.05, 0.91, 0.73, 0.32)
	var texture: Texture2D = textures.garden_tile
	var source_size := texture.get_size()
	for x in range(-1, int(view.screen.x / tile_size) + 2):
		for y in range(-1, int(view.screen.y / tile_size) + 2):
			var cell := Rect2(start + Vector2(x, y) * tile_size, Vector2.ONE * tile_size)
			var clipped := cell.intersection(bounds)
			if not clipped.has_area():
				continue
			var source := Rect2((clipped.position - cell.position) / tile_size * source_size, clipped.size / tile_size * source_size)
			view.draw_texture_rect_region(texture, Rect2(view.world(clipped.position), clipped.size), source, tint)

static func _draw_garden_floor(view, bounds: Rect2) -> void:
	var center: Vector2 = view.world(Vector2.ZERO)
	# Pale avenue inlay, with moss between the old stones. All marks are flat.
	view.draw_rect(Rect2(view.world(Vector2(bounds.position.x + 26, -48)), Vector2(bounds.size.x - 52, 96)), Color(0.42, 0.47, 0.43, 0.08))
	view.draw_rect(Rect2(view.world(Vector2(-48, bounds.position.y + 26)), Vector2(96, bounds.size.y - 52)), Color(0.42, 0.47, 0.43, 0.08))
	for radius in [182.0, 202.0, 214.0]:
		view.draw_arc(center, radius, 0, TAU, 72, Color(0.63, 0.68, 0.57, 0.14), 2, true)
	for i in range(12):
		var direction := Vector2.from_angle(float(i) * TAU / 12)
		var petal := PackedVector2Array([center + direction * 42, center + direction.rotated(-0.10) * 147, center + direction * 180, center + direction.rotated(0.10) * 147])
		view.draw_colored_polygon(petal, Color(0.58, 0.64, 0.54, 0.07))
		view.draw_line(center + direction * 194, center + direction * 222, Color(GOLD, 0.18), 2, true)
	# Ferns and rose petals follow fixed authored positions, never camera parallax.
	for side in [-1.0, 1.0]:
		for i in range(6):
			var floor_at := Vector2(side * (755 + float(i % 2) * 90), -625 + float(i) * 252)
			_draw_floor_flower(view, floor_at, i)
	for i in range(26):
		var floor_at := Vector2(-960 + fposmod(float(i * 337), 1920), -680 + fposmod(float(i * 191), 1360))
		var point: Vector2 = view.world(floor_at)
		if _on_screen(view, point, 15):
			view.draw_line(point, point + Vector2(5, -2), Color("4b6155"), 1.5, true)
			view.draw_line(point + Vector2(3, 0), point + Vector2(6, 3), Color(0.55, 0.54, 0.56, 0.36), 1.2, true)

static func _draw_floor_flower(view, position: Vector2, seed_value: int) -> void:
	var at: Vector2 = view.world(position)
	if not _on_screen(view, at, 80):
		return
	for i in range(5):
		var stem := at + Vector2(float(i - 2) * 13, float((i + seed_value) % 3) * 8)
		view.draw_line(stem + Vector2(0, 9), stem + Vector2(2, -13), Color("3e5950"), 2, true)
		view.draw_line(stem, stem + Vector2(-8, -5), Color("496451"), 2, true)
		for p in range(5):
			var direction := Vector2.from_angle(float(p) * TAU / 5)
			view.draw_circle(stem + Vector2(2, -11) + direction * 3, 2.4, Color(0.57, 0.52, 0.64, 0.44))
		view.draw_circle(stem + Vector2(2, -11), 1.6, Color(GOLD, 0.47))

static func _draw_mirror_floor(view, bounds: Rect2) -> void:
	var center: Vector2 = view.world(Vector2.ZERO)
	# Elongated floor lozenges and reflected window light establish the corridors.
	for column in [-1.0, 1.0]:
		var ribbon := Rect2(view.world(Vector2(column * 520 - 88, bounds.position.y + 35)), Vector2(176, bounds.size.y - 70))
		view.draw_rect(ribbon, Color(0.34, 0.41, 0.59, 0.10))
		for i in range(7):
			var point: Vector2 = view.world(Vector2(column * 520, -670 + float(i) * 220))
			if not _on_screen(view, point, 180):
				continue
			var lozenge := PackedVector2Array([point + Vector2(0, -90), point + Vector2(65, 0), point + Vector2(0, 90), point + Vector2(-65, 0), point + Vector2(0, -90)])
			view.draw_polyline(lozenge, Color(BLUE, 0.16), 2, true)
			view.draw_line(point + Vector2(-47, 0), point + Vector2(47, 0), Color(BLUE, 0.07), 1, true)
	for r in [104.0, 146.0, 160.0]:
		view.draw_arc(center, r, 0, TAU, 64, Color(BLUE, 0.15), 1.5, true)
	for i in range(8):
		var direction := Vector2.from_angle(float(i) * TAU / 8)
		var diamond := PackedVector2Array([center + direction * 45, center + direction.rotated(-0.13) * 122, center + direction * 151, center + direction.rotated(0.13) * 122])
		view.draw_colored_polygon(diamond, Color(0.49, 0.58, 0.75, 0.09))
	# Thin silver seams read as flat floor detail rather than collision walls.
	for i in range(-4, 5):
		var y := float(i) * 170
		view.draw_line(view.world(Vector2(bounds.position.x + 30, y)), view.world(Vector2(bounds.end.x - 30, y)), Color(0.51, 0.55, 0.65, 0.07), 1, true)

static func _draw_bell_floor(view, _bounds: Rect2) -> void:
	var center: Vector2 = view.world(Vector2.ZERO)
	# The circular brass clock is an inlaid floor; the outer wall remains rectangular.
	for r in [118.0, 136.0, 346.0, 365.0, 666.0, 690.0]:
		view.draw_arc(center, r, 0, TAU, 120, Color(GOLD, 0.13 if r < 400 else 0.10), 2, true)
	for i in range(16):
		var direction := Vector2.from_angle(float(i) * TAU / 16)
		view.draw_line(center + direction * 143, center + direction * 658, Color(GOLD, 0.055), 2, true)
		view.draw_line(center + direction * 676, center + direction * 697, Color(GOLD, 0.22), 3, true)
		if i % 2 == 0:
			var point := center + direction * 323
			var tangent := direction.orthogonal()
			view.draw_line(point - tangent * 11, point + tangent * 11, Color(GOLD, 0.25), 2, true)
	# A quiet bell-shaped mosaic distinguishes the start from the damaging boss rings.
	var bell := PackedVector2Array([center + Vector2(-39, 20), center + Vector2(-29, 0), center + Vector2(-26, -37), center + Vector2(-13, -54), center + Vector2(13, -54), center + Vector2(26, -37), center + Vector2(29, 0), center + Vector2(39, 20), center + Vector2(-39, 20)])
	view.draw_polyline(bell, Color(GOLD, 0.20), 3, true)
	view.draw_line(center + Vector2(-39, 27), center + Vector2(39, 27), Color(GOLD, 0.17), 2, true)
	view.draw_circle(center + Vector2(0, 36), 6, Color(GOLD, 0.19))

static func _draw_boundary(view, bounds: Rect2, chapter: int) -> void:
	var rect := Rect2(view.world(bounds.position), bounds.size)
	var stone := Color("58655e") if chapter == 0 else Color("656477") if chapter == 1 else Color("716958")
	# The bright inner seam is exactly the traversable model boundary.
	view.draw_rect(rect.grow(16), Color("0c111b"), false, 32)
	view.draw_rect(rect, Color(stone, 0.80), false, 4)
	view.draw_rect(rect.grow(8), Color(stone, 0.38), false, 3)
	for i in range(19):
		var x := bounds.position.x + float(i) * bounds.size.x / 18
		for y in [bounds.position.y - 8, bounds.end.y + 8]:
			var point: Vector2 = view.world(Vector2(x, y))
			if _on_screen(view, point, 45):
				view.draw_rect(Rect2(point - Vector2(8, 12), Vector2(16, 24)), stone)
				view.draw_line(point + Vector2(-5, -9), point + Vector2(5, -9), Color(GOLD, 0.42), 2, true)
	for i in range(13):
		var y := bounds.position.y + float(i) * bounds.size.y / 12
		for x in [bounds.position.x - 8, bounds.end.x + 8]:
			var point: Vector2 = view.world(Vector2(x, y))
			if _on_screen(view, point, 45):
				view.draw_rect(Rect2(point - Vector2(9, 9), Vector2(18, 18)), stone)
				view.draw_line(point + Vector2(-5, -5), point + Vector2(5, -5), Color(GOLD, 0.42), 2, true)

static func draw_obstacle_base(view, obstacle: Rect2) -> void:
	var rect := Rect2(view.world(obstacle.position), obstacle.size)
	if not rect.grow(80).intersects(Rect2(Vector2.ZERO, view.screen)):
		return
	view.draw_rect(Rect2(rect.position + Vector2(4, 8), rect.size + Vector2(6, 5)), Color(0.01, 0.025, 0.04, 0.42))
	view.draw_rect(rect, Color("0e171f"))
	view.draw_rect(rect, Color("b1b2a0"), false, 2)

static func draw_obstacle(view, obstacle: Rect2, chapter: int, index: int) -> void:
	var rect := Rect2(view.world(obstacle.position), obstacle.size)
	if not rect.grow(85).intersects(Rect2(Vector2.ZERO, view.screen)):
		return
	match chapter:
		0:
			_draw_planter(view, rect, index)
		1:
			_draw_column(view, rect, index)
		_:
			_draw_buttress(view, rect, index)

static func _draw_planter(view, rect: Rect2, index: int) -> void:
	# Bevelled stone contains an irregular rose thicket; the clear front lip is
	# exactly the collision footprint, so no leaf becomes an invisible wall.
	view.draw_rect(rect, Color("4c5650"))
	view.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 19), Vector2(rect.size.x, 19)), Color("303d39"))
	view.draw_rect(rect.grow(-7), Color("20392f"))
	view.draw_rect(rect, Color("82907b"), false, 2)
	view.draw_line(rect.position + Vector2(5, 4), rect.position + Vector2(rect.size.x - 5, 4), Color("a0a38a"), 2, true)
	view.draw_line(rect.position + Vector2(4, 4), rect.position + Vector2(4, rect.size.y - 5), Color("74816e"), 2, true)
	var count := maxi(12, int(rect.size.x * rect.size.y / 1200))
	var colors: Array[Color] = [Color("335144"), Color("3b5948"), Color("425e4b"), Color("46634f")]
	for i in range(count):
		var px := fposmod(float(i * 73 + index * 31), maxf(1, rect.size.x - 34))
		var py := fposmod(float(i * i * 17 + i * 83 + index * 29), maxf(1, rect.size.y - 47))
		var at := rect.position + Vector2(17 + px, 20 + py)
		var tint: Color = colors[(i + index) % colors.size()]
		view._ellipse(at + Vector2(2, 5), Vector2(18, 10), Color("203c30"))
		view._ellipse(at, Vector2(15 + float(i % 3), 8 + float(i % 4)), tint)
		var stem := PackedVector2Array([at + Vector2(-8, 5), at + Vector2(-3, -1), at + Vector2(5, -7), at + Vector2(8, -13)])
		view.draw_polyline(stem, Color("6a8165"), 1.4, true)
		for side in [-1.0, 1.0]:
			var leaf := PackedVector2Array([at + Vector2(0, 1), at + Vector2(side * 10, -9), at + Vector2(side * 12, -3), at + Vector2(side * 5, 3)])
			view.draw_colored_polygon(leaf, tint.lightened(0.045))
		if i % 4 == 0:
			var flower_at := at + Vector2(4, -8)
			for petal in range(5):
				view.draw_circle(flower_at + Vector2.from_angle(float(petal) * TAU / 5) * 3, 2.7, Color("a18a9e") if i % 8 == 0 else Color("b2aaa2"))
			view.draw_circle(flower_at, 2, Color("c9b583"))
	# Mortar joints and a worn lip belong to masonry, not a rectangular UI frame.
	for x in range(1, int(rect.size.x / 43)):
		var point := rect.position + Vector2(float(x) * 43, rect.size.y - 17)
		view.draw_line(point, point + Vector2(0, 15), Color("74806e"), 1, true)
	view.draw_line(rect.position + Vector2(8, rect.size.y - 18), rect.end - Vector2(8, 18), Color("839079"), 1.5, true)

static func _draw_column(view, rect: Rect2, index: int) -> void:
	view.draw_rect(rect, Color("4b5061"))
	view.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 16), Vector2(rect.size.x, 16)), Color("303648"))
	var inner := rect.grow(-17)
	view.draw_rect(inner, Color("29354b"))
	# Fluted pale stone uprights and broad mouldings read as physical architecture.
	for side in [0.0, 1.0]:
		var x: float = rect.position.x + 4 + float(side) * (rect.size.x - 17)
		view.draw_rect(Rect2(x, rect.position.y + 7, 10, rect.size.y - 15), Color("666c79"))
		view.draw_line(Vector2(x + 2, rect.position.y + 10), Vector2(x + 2, rect.end.y - 12), Color("999ca5"), 1.5, true)
		view.draw_line(Vector2(x + 8, rect.position.y + 11), Vector2(x + 8, rect.end.y - 12), Color("303a4e"), 1.5, true)
	for y in [rect.position.y + 4, rect.end.y - 11]:
		view.draw_rect(Rect2(rect.position.x + 2, y, rect.size.x - 4, 7), Color("858797"))
		view.draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), Color("a8a8b0"), 1, true)
	# Light fades across the glass; fine etching and one crack break perfect symmetry.
	var face := PackedVector2Array([inner.position + Vector2(3, 0), inner.position + Vector2(inner.size.x * 0.65, 0), inner.end - Vector2(3, 0), inner.position + Vector2(inner.size.x * 0.30, inner.size.y)])
	view.draw_colored_polygon(face, Color(0.56, 0.76, 0.84, 0.13))
	view.draw_rect(inner, Color("899aaa"), false, 1.5)
	view.draw_line(inner.position + inner.size * Vector2(0.25, 0.10), inner.position + inner.size * Vector2(0.65, 0.90), Color(BLUE, 0.22), 2, true)
	view.draw_line(inner.position + inner.size * Vector2(0.45, 0.10), inner.position + inner.size * Vector2(0.80, 0.78), Color(BLUE, 0.10), 1, true)
	var at := inner.get_center()
	if rect.size.y > rect.size.x:
		for side in [-1.0, 1.0]:
			var ornament := PackedVector2Array([at + Vector2(side * 14, -38), at + Vector2(side * 29, -17), at + Vector2(side * 27, 15), at + Vector2(side * 14, 38)])
			view.draw_polyline(ornament, Color(BLUE, 0.18), 1, true)
	if index % 2 == 0:
		view.draw_polyline(PackedVector2Array([at + Vector2(-8, -32), at + Vector2(4, -12), at + Vector2(-3, 2), at + Vector2(10, 26)]), Color(0.12, 0.20, 0.32, 0.70), 2, true)

static func _draw_buttress(view, rect: Rect2, index: int) -> void:
	view.draw_rect(rect, Color("454b46"))
	var cap := rect.grow(-12)
	view.draw_rect(cap, Color("56594e"))
	# Broad, bevelled blocks catch the moon on the upper and left faces.
	view.draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(cap.end.x, cap.position.y), cap.position]), Color("858575"))
	view.draw_colored_polygon(PackedVector2Array([rect.position, cap.position, Vector2(cap.position.x, cap.end.y), Vector2(rect.position.x, rect.end.y)]), Color("6c7263"))
	view.draw_colored_polygon(PackedVector2Array([Vector2(rect.end.x, rect.position.y), rect.end, cap.end, Vector2(cap.end.x, cap.position.y)]), Color("343d3a"))
	view.draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x, rect.end.y), Vector2(cap.position.x, cap.end.y), cap.end, rect.end]), Color("303b35"))
	view.draw_rect(rect, Color("8e917b"), false, 1.5)
	for row in range(1, int(cap.size.y / 29)):
		var y := cap.position.y + float(row) * 29
		view.draw_line(Vector2(cap.position.x + 1, y), Vector2(cap.end.x - 1, y), Color(0.19, 0.23, 0.20, 0.52), 1.3, true)
		for column in range(1, int(cap.size.x / 61)):
			var x := cap.position.x + float(column) * 61 + (25 if row % 2 == 0 else 0)
			if x < cap.end.x - 10:
				view.draw_line(Vector2(x, y - 28), Vector2(x, y - 1), Color(0.18, 0.22, 0.19, 0.46), 1, true)
	var at := cap.get_center()
	var width := minf(16, cap.size.x * 0.20)
	var height := minf(25, cap.size.y * 0.28)
	var rune := PackedVector2Array([at + Vector2(-width, height), at + Vector2(-width * 0.7, -height * 0.5), at + Vector2(0, -height), at + Vector2(width * 0.7, -height * 0.5), at + Vector2(width, height), at + Vector2(-width, height)])
	view.draw_polyline(rune, Color(GOLD, 0.62), 1.7, true)
	view.draw_line(at + Vector2(-width - 3, height + 4), at + Vector2(width + 3, height + 4), Color(GOLD, 0.55), 1.5, true)
	view.draw_circle(at + Vector2(0, height + 7), 2.5, Color(GOLD, 0.65))
	if index % 2 == 0:
		view.draw_polyline(PackedVector2Array([cap.position + Vector2(19, 1), cap.position + Vector2(28, 16), cap.position + Vector2(22, 25), cap.position + Vector2(36, 35)]), Color("333f36"), 1.4, true)

static func draw_ambient(view, chapter: int) -> void:
	var camera: Vector2 = view.run.player - view.screen * Vector2(0.5, 0.52)
	var color := GOLD if chapter != 1 else BLUE
	# Fixed world anchors; only cosmetic drift is suppressed by reduced motion.
	for i in range(13):
		var base := Vector2(-970 + fposmod(float(i * 227), 1940), -690 + fposmod(float(i * 307), 1380))
		var phase := float(i) * 1.77
		var drift := Vector2.ZERO if view.reduced_motion else Vector2(sin(view.run.elapsed * 0.35 + phase) * 5, cos(view.run.elapsed * 0.3 + phase) * 4)
		var at: Vector2 = base - camera + drift
		if _on_screen(view, at, 12):
			view._disc(at, 6, Color(color, 0.035))
			view._disc(at, 1.1, Color(color, 0.38))

static func _on_screen(view, at: Vector2, margin: float) -> bool:
	return Rect2(Vector2.ONE * -margin, view.screen + Vector2.ONE * margin * 2).has_point(at)
