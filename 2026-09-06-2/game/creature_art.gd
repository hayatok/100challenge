extends RefCounted
const DNA = preload("res://core/genome.gd")
const INK = Color("253d36")
var cache: Dictionary = {}

func morphology(g: Dictionary) -> Dictionary:
	var key: String = str(g)
	if cache.has(key): return cache[key]
	var p: Dictionary = DNA.traits(g)
	var r: float = p.radius
	var shape: PackedVector2Array = []
	for i in 33:
		var a: float = TAU * i / 32.0
		var wobble: float = 1.0 + sin(a * (3 + int(p.parts)) + p.eyes * 6) * 0.055
		shape.append(Vector2(cos(a) * r * (0.95 + p.length * 0.8), sin(a) * r * 0.78) * wobble)
	var spots: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = int(p.pattern * 1000000 + p.hue * 70000 + p.length * 9999)
	for i in 3 + int(p.pattern * 9): spots.append(Vector2(rng.randf_range(-0.65, 0.65), rng.randf_range(-0.48, 0.48)))
	var result: Dictionary = {"p": p, "shape": shape, "spots": spots, "color": Color.from_hsv(p.hue, 0.33 + p.pattern * 0.20, 0.86)}
	if cache.size() > 1500: cache.clear()
	cache[key] = result
	return result

func render(canvas: CanvasItem, genes: Dictionary, center: Vector2, scale_value: float, angle: float, age: float, clock: float, moving: bool, reduced: bool = false) -> void:
	var data: Dictionary = morphology(genes)
	var p: Dictionary = data.p
	var facing: float = 1.0 if cos(angle) >= 0 else -1.0
	var phase: float = clock * (3.0 + p.reach * 3.0) if moving and not reduced else 0.0
	var grow: float = lerpf(0.48, 1, clampf((age - 4) / 14, 0, 1))
	var zoom: float = scale_value * grow
	canvas.draw_set_transform(center, 0, Vector2(zoom, zoom))
	if age < 4:
		canvas.draw_circle(Vector2(2, 5), 9, Color(0.15, 0.24, 0.20, 0.15))
		canvas.draw_style_box(egg_style(), Rect2(-8, -11, 16, 22))
		canvas.draw_circle(Vector2(-2, -3), 2, data.color)
		canvas.draw_circle(Vector2(3, 4), 2.5, data.color)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var r: float = p.radius
	var shadow: PackedVector2Array = []
	for i in 20:
		var a: float = TAU * i / 20.0
		shadow.append(Vector2(cos(a) * r * (1.6 + p.length), sin(a) * r * 0.33 + r * 0.9))
	canvas.draw_colored_polygon(shadow, Color(0.15, 0.24, 0.20, 0.12))
	canvas.draw_set_transform(center + Vector2(0, sin(phase * 2) * 1.6 * zoom), 0, Vector2(zoom * facing, zoom))
	# Joint positions derive from the inherited body; no rigid-body node per limb.
	for i in int(p.pairs):
		var x: float = lerpf(-r * 0.8, r * 0.75, (i + 0.5) / p.pairs) * (0.8 + p.length)
		var reach: float = 6 + p.reach * 19
		for side in [-1, 1]:
			var stride: float = sin(phase + i * 1.5 + (PI if side < 0 else 0)) * (3 + p.reach * 4)
			var root: Vector2 = Vector2(x, r * 0.25)
			var knee: Vector2 = Vector2(x + side * 4 + stride, r * 0.45 + reach * 0.48)
			var toe: Vector2 = Vector2(x + side * 6 - stride * 0.6, r * 0.45 + reach)
			canvas.draw_polyline(PackedVector2Array([root, knee, toe, toe + Vector2(4, 0)]), INK, 3, true)
			if p.swim > 0.65: canvas.draw_colored_polygon(PackedVector2Array([toe, toe + Vector2(7, -4), toe + Vector2(8, 2)]), data.color.darkened(0.15))
	for segment in range(int(p.parts) - 1, -1, -1):
		var offset: Vector2 = Vector2(-segment * r * 0.67, sin(phase + segment) * 1.4)
		var shape: PackedVector2Array = []
		for point in data.shape: shape.append(point * (1.0 - segment * 0.095) + offset)
		canvas.draw_colored_polygon(shape, data.color.darkened(segment * 0.035))
		canvas.draw_polyline(shape, INK, 2.5, true)
	if p.spines > 0.30:
		for i in 2 + int(p.spines * 5):
			var x: float = lerpf(-r, r * 0.8, i / float(1 + int(p.spines * 5)))
			var points: PackedVector2Array = PackedVector2Array([Vector2(x - 3, -r * 0.5), Vector2(x, -r * 0.7 - p.spines * 12), Vector2(x + 4, -r * 0.5)])
			canvas.draw_colored_polygon(points, data.color.lightened(0.3))
			canvas.draw_polyline(points, INK, 2, true)
	for spot in data.spots:
		var at: Vector2 = Vector2(spot.x * r * (1 + p.length * 0.7), spot.y * r)
		if p.pattern < 0.5: canvas.draw_circle(at, 1.5 + p.pattern * 3, data.color.darkened(0.20))
		else: canvas.draw_line(at - Vector2(1, 3), at + Vector2(2, 3), data.color.darkened(0.2), 2, true)
	if p.shell > 0.6:
		canvas.draw_arc(Vector2(-r * 0.3, 0), r * 0.64, PI, TAU, 16, INK, 3, true)
		canvas.draw_line(Vector2(-r * 0.3, -r * 0.64), Vector2(-r * 0.3, r * 0.3), INK, 1.6, true)
	var eye: Vector2 = Vector2(r * (0.52 + p.length * 0.3), -r * 0.40 - p.sense * 4)
	var eye_size: float = 3.7 + p.eyes * 4.2
	for offset in [Vector2(-eye_size * 1.5, -2), Vector2.ZERO]:
		canvas.draw_line(eye + offset + Vector2(0, 4), eye + offset + Vector2(0, p.sense * 7), INK, 2, true)
		canvas.draw_circle(eye + offset, eye_size + 1.6, INK)
		canvas.draw_circle(eye + offset, eye_size, Color("fffaf0"))
		canvas.draw_circle(eye + offset + Vector2(1.2, 0.8), eye_size * 0.43, INK)
	canvas.draw_arc(Vector2(r * 0.65, r * 0.16), 2.5 + p.mouth * 3, 0.0, PI * 0.85, 8, INK, 1.8, true)
	canvas.draw_set_transform(Vector2.ZERO)

func egg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fff7de")
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
