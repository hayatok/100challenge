extends RefCounted
## Authored dressing uses the exact collision rectangles supplied by chapter_info.

const Grimoire := preload("res://scripts/grimoire_theme.gd")
const GOLD := Grimoire.GOLD
const BLUE := Grimoire.ECHO
const TERRAIN := preload("res://assets/art/terrain-painted-r3.png")
const SCENERY := preload("res://assets/art/scenery-painted-r3.png")
const TERRAIN_TILE_WIDTH := 440.0
const PANEL_INSET := 2.0
# Measured alpha silhouettes, expressed against the original sheet dimensions.
# The painter let rose vines cross equal thirds: cell crops would cut them off.
const SCENERY_REFERENCE_SIZE := Vector2(1536, 1024)
const SCENERY_CROPS := [
	[Rect2(32, 128, 529, 348), Rect2(27, 643, 535, 345)],
	[Rect2(647, 1, 364, 479), Rect2(646, 496, 364, 492)],
	[Rect2(1162, 2, 281, 491), Rect2(1166, 491, 340, 519)]
]
const SCENERY_BASE := [0.976, 0.982, 0.981]

static func draw_floor(view, info: Dictionary, _textures: Dictionary) -> void:
	var chapter := int(info.get("id", 0)) if info.get("id", 0) is int else int(view.run.chapter)
	var bounds: Rect2 = info.get("bounds", Rect2(-1100, -800, 2200, 1600))
	var at: Vector2 = view.world(bounds.position)
	var visible_rect := Rect2(Vector2.ZERO, view.screen)
	var ground := Color("172c31") if chapter == 0 else Color("222a3d") if chapter == 1 else Color("2b2c33")
	view.draw_rect(visible_rect, Color("0c1420"))
	view.draw_rect(Rect2(at, bounds.size), ground)
	_draw_tiles(view, bounds, chapter)
	# A retained moonlit wash compresses the painted stone contrast behind actors.
	view.draw_rect(Rect2(at, bounds.size), Color(ground, 0.54))
	match chapter:
		0:
			_draw_garden_floor(view, bounds)
		1:
			_draw_mirror_floor(view, bounds)
		_:
			_draw_bell_floor(view, bounds)
	_draw_boundary(view, bounds, chapter)

static func terrain_region(chapter: int) -> Rect2:
	# Equal source panels: garden, archive, belfry, then spare neutral paving.
	var panel := Vector2(float(chapter % 2), float(chapter >> 1))
	var half := TERRAIN.get_size() * 0.5
	return Rect2(panel * half, half).grow(-PANEL_INSET)

static func scenery_region(chapter: int, variant: int) -> Rect2:
	var authored: Rect2 = SCENERY_CROPS[chapter][variant % 2]
	var source_scale := SCENERY.get_size() / SCENERY_REFERENCE_SIZE
	return Rect2(authored.position * source_scale, authored.size * source_scale)

static func _draw_tiles(view, bounds: Rect2, chapter: int) -> void:
	var source := terrain_region(chapter)
	var tile_size := Vector2(TERRAIN_TILE_WIDTH, TERRAIN_TILE_WIDTH * source.size.y / source.size.x)
	var first := (bounds.position / tile_size).floor()
	var last := (bounds.end / tile_size).ceil()
	# These quads are authored once into FloorLayer's retained draw list. Mirror
	# adjoining cells at the same painted edge instead of exposing atlas seams.
	var tint := Color(0.68, 0.77, 0.80, 1.0)
	if chapter == 1:
		tint = Color(0.69, 0.75, 0.88, 1.0)
	elif chapter == 2:
		tint = Color(0.80, 0.76, 0.68, 1.0)
	for x in range(int(first.x), int(last.x)):
		for y in range(int(first.y), int(last.y)):
			var cell := Rect2(Vector2(x, y) * tile_size, tile_size)
			var clipped := cell.intersection(bounds)
			if not clipped.has_area():
				continue
			var uv_start := (clipped.position - cell.position) / tile_size
			var uv_end := (clipped.end - cell.position) / tile_size
			if posmod(x, 2) == 1:
				uv_start.x = 1.0 - uv_start.x
				uv_end.x = 1.0 - uv_end.x
			if posmod(y, 2) == 1:
				uv_start.y = 1.0 - uv_start.y
				uv_end.y = 1.0 - uv_end.y
			var a: Vector2 = view.world(clipped.position)
			var b: Vector2 = a + clipped.size
			var points := PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
			var uvs := PackedVector2Array([uv_start, Vector2(uv_end.x, uv_start.y), uv_end, Vector2(uv_start.x, uv_end.y)])
			for i in range(uvs.size()):
				uvs[i] = (source.position + uvs[i] * source.size) / TERRAIN.get_size()
			view.draw_polygon(points, PackedColorArray([tint]), uvs, TERRAIN)

static func _draw_garden_floor(view, bounds: Rect2) -> void:
	var center: Vector2 = view.world(Vector2.ZERO)
	# Pale avenue inlay, with moss between the old stones. All marks are flat.
	view.draw_rect(Rect2(view.world(Vector2(bounds.position.x + 26, -48)), Vector2(bounds.size.x - 52, 96)), Color(0.42, 0.47, 0.43, 0.08))
	view.draw_rect(Rect2(view.world(Vector2(-48, bounds.position.y + 26)), Vector2(96, bounds.size.y - 52)), Color(0.42, 0.47, 0.43, 0.08))
	for radius in [182.0, 202.0, 214.0]:
		view.draw_arc(center, radius, 0, TAU, 72, Color(0.63, 0.68, 0.57, 0.10), 2, true)
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
		view.draw_arc(center, r, 0, TAU, 64, Color(BLUE, 0.11), 1.5, true)
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
		view.draw_arc(center, r, 0, TAU, 120, Color(GOLD, 0.10 if r < 400 else 0.08), 2, true)
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
	if not rect.grow(20).intersects(Rect2(Vector2.ZERO, view.screen)):
		return
	# The slab and its front edge keep the exact model footprint visible, even
	# through the irregular silhouette of the painted roses, shelves and stone.
	view.draw_rect(Rect2(rect.position + Vector2(4, 8), rect.size + Vector2(6, 5)), Color(0.01, 0.025, 0.04, 0.48))
	view.draw_rect(rect, Color("182329"))
	view.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color("a0a699"), 2.0, true)

static func obstacle_modules(obstacle: Rect2, chapter: int, index: int) -> Array[Dictionary]:
	# Long shelves form a bank of intact bookcases. Wide tower solids similarly
	# carry several intact buttresses instead of flattening a single tall arch.
	var vertical := obstacle.size.y > obstacle.size.x * 1.45
	var rows := maxi(1, ceili(obstacle.size.y / 235.0)) if vertical else 1
	var primary := scenery_region(chapter, index)
	var aspect := primary.size.x / primary.size.y
	var row_height := obstacle.size.y / rows
	var columns := clampi(roundi(obstacle.size.x / (row_height * aspect)), 1, 4)
	var result: Array[Dictionary] = []
	for row in range(rows):
		for column in range(columns):
			var offset := Vector2(obstacle.size.x * float(column) / columns, row_height * row)
			var target := Rect2(obstacle.position + offset, Vector2(obstacle.size.x / columns, row_height))
			var variant := posmod(index + row + column, 2)
			result.append({"target": target, "source": scenery_region(chapter, variant), "variant": variant})
	return result

static func draw_obstacle(view, obstacle: Rect2, chapter: int, index: int) -> void:
	var rect := Rect2(view.world(obstacle.position), obstacle.size)
	if not rect.grow(20).intersects(Rect2(Vector2.ZERO, view.screen)):
		return
	var stone := Color("65776c") if chapter == 0 else Color("626e83") if chapter == 1 else Color("837d69")
	view.draw_rect(rect, stone.darkened(0.54))
	# The painted material continues under each module so transparent gaps in a
	# source panel never suggest a walkable hole inside the collision rectangle.
	view.draw_texture_rect_region(TERRAIN, rect.grow(-3), terrain_region(chapter), Color(0.44, 0.48, 0.49, 1))
	for module in obstacle_modules(obstacle, chapter, index):
		var target: Rect2 = module.target
		var source: Rect2 = module.source
		var available := target.size + Vector2(12, 12)
		var scale_factor := minf(available.x / source.size.x, available.y / source.size.y)
		var size := source.size * scale_factor
		# Place the measured stone/wood contact edge on the authored footprint;
		# the source's last faint shadow pixels can extend into the 20px margin.
		var at: Vector2 = view.world(Vector2(target.get_center().x - size.x * 0.5, target.end.y - size.y * float(SCENERY_BASE[chapter])))
		view.draw_texture_rect_region(SCENERY, Rect2(at, size), source, Color(0.88, 0.92, 0.96, 1))
	view.draw_line(Vector2(rect.position.x + 2, rect.end.y - 2), rect.end - Vector2(2, 2), Color(stone, 0.86), 2.0, true)
	view.draw_line(rect.position + Vector2(1, 2), Vector2(rect.position.x + 1, rect.end.y - 2), Color(stone, 0.52), 1.5, true)

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
