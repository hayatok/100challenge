extends RefCounted
const DNA = preload("res://core/genome.gd")
const INK = Color("253d36")
var cache: Dictionary = {}

func morphology(g: Dictionary) -> Dictionary:
	var key: int = hash(g)
	if cache.has(key) and cache[key].genes == g: return cache[key]
	var p: Dictionary = DNA.traits(g)
	var r: float = p.radius
	var nodes: Array = []
	var bounds: Rect2 = Rect2(Vector2(-1, -1), Vector2(2, 2))
	for i in p.blueprint.nodes.size():
		var n: Array = p.blueprint.nodes[i]
		var depth: int = 0 if i == 0 else int(nodes[int(n[0])].depth) + 1
		var rx: float = r * (0.72 + n[2] * 0.8) * (1.0 - depth * 0.055)
		var ry: float = r * (0.48 + n[3] * 0.43) * (1.0 - depth * 0.045)
		var bend: float = n[1] * 1.4
		var pos: Vector2 = Vector2.ZERO
		if i > 0:
			var parent: Dictionary = nodes[int(n[0])]
			pos = parent.pos + Vector2(-cos(bend), sin(bend)) * parent.rx * (0.62 + p.segments * 0.25)
		var shape: PackedVector2Array = []
		for j in 33:
			var angle: float = TAU * j / 32.0
			var wave: float = 1 + sin(angle * (3 + i % 3) + p.pattern * 5) * 0.045
			var point: Vector2 = pos + Vector2(cos(angle) * rx, sin(angle) * ry).rotated(bend * 0.25) * wave
			shape.append(point)
			bounds = bounds.expand(point)
		nodes.append({"pos": pos, "rx": rx, "ry": ry, "depth": depth, "shape": shape})
	var organs: Array = []
	for o in p.blueprint.organs:
		var node: Dictionary = nodes[int(o[1])]
		var angle: float = float(o[2]) * TAU
		var root: Vector2 = node.pos + Vector2(cos(angle) * node.rx, sin(angle) * node.ry) * 0.78
		var reach: float = 10 + p.reach * 10 + float(o[3]) * 18
		if int(o[0]) == 3: reach *= 1.2
		organs.append({"kind": int(o[0]), "root": root, "angle": angle, "reach": reach})
		bounds = bounds.merge(Rect2(root - Vector2.ONE * reach * 1.55, Vector2.ONE * reach * 3.1))
	var eye_size: float = 3.7 + p.eyes * 4.2
	var eye_origin: Vector2 = Vector2(nodes[0].rx * 0.62, -nodes[0].ry * 0.65 - p.sense * 4)
	var eye_positions: Array = []
	for i in int(p.blueprint.eyes):
		var at: Vector2 = eye_origin + Vector2(-i * ((eye_size + 1.6) * 2 + 1), -i * 2)
		eye_positions.append(at)
		bounds = bounds.merge(Rect2(at - Vector2.ONE * (eye_size + 2), Vector2.ONE * (eye_size + 2) * 2))
	var rng = RandomNumberGenerator.new()
	rng.seed = int(p.pattern * 1000000 + p.hue * 70000 + p.length * 9999)
	var spots: Array = []
	for i in 3 + int(p.pattern * 7): spots.append(Vector2(rng.randf_range(-0.55, 0.5), rng.randf_range(-0.48, 0.48)))
	var result: Dictionary = {"genes": g, "p": p, "nodes": nodes, "organs": organs, "eyes": eye_positions,
		"eye_size": eye_size, "spots": spots, "bounds": bounds.grow(10), "color": Color.from_hsv(p.hue, 0.33 + p.pattern * 0.20, 0.86)}
	if cache.size() >= 512: cache.clear()
	cache[key] = result
	return result

func bounds(g: Dictionary, age: float = 30) -> Rect2:
	if age < 4: return Rect2(-5, -6, 11, 15)
	var grow: float = lerpf(0.48, 1, clampf((age - 4) / 14, 0, 1))
	var shape: Rect2 = morphology(g).bounds
	return Rect2(shape.position * grow, shape.size * grow)

func portrait_fit(g: Dictionary, size: Vector2, caption: bool, egg: bool) -> Dictionary:
	var rect: Rect2 = Rect2(Vector2(8, 6), (size - Vector2(16, 30 if caption else 12)).max(Vector2.ONE))
	var shape: Rect2 = bounds(g, 0 if egg else 30)
	var scale_value: float = minf(2.2, minf(rect.size.x / shape.size.x, rect.size.y / shape.size.y))
	return {"center": rect.get_center() - shape.get_center() * scale_value, "scale": scale_value, "bounds": shape}

func polygon(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float = 2.3) -> void:
	canvas.draw_colored_polygon(points, color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, INK, width, true)

func draw_organ(canvas: CanvasItem, o: Dictionary, index: int, phase: float, color: Color, stance: float) -> void:
	var length: float = o.reach
	var root: Vector2 = o.root
	for side in [-1, 1]:
		var wave: float = sin(phase + index * 1.3 + (PI if side < 0 else 0))
		var start: Vector2 = root + Vector2(side * 1.5, side * 1.0)
		var angle: float = o.angle + side * 0.17
		var axis: Vector2 = Vector2.from_angle(angle)
		var normal: Vector2 = axis.orthogonal()
		match o.kind:
			0:
				var stride: float = wave * length * 0.13
				var knee: Vector2 = start + Vector2(side * length * (0.18 + stance * 0.12) + stride, length * 0.5)
				var toe: Vector2 = start + Vector2(side * length * 0.30 - stride, length)
				canvas.draw_polyline(PackedVector2Array([start, knee, toe, toe + Vector2(4, 0)]), INK, 3, true)
			1:
				axis = axis.rotated(wave * 0.11)
				var tip: Vector2 = start + axis * length
				polygon(canvas, PackedVector2Array([start, start + axis * length * 0.65 + normal * length * 0.3, tip, start + axis * length * 0.65 - normal * length * 0.3]), color.lightened(0.16))
				canvas.draw_line(start, tip, INK, 1.3, true)
			2:
				var line: PackedVector2Array = []
				for j in 9:
					var t: float = j / 8.0
					line.append(start + axis * length * t + normal * sin(t * 5.5 + phase + side) * length * 0.16 * t)
				canvas.draw_polyline(line, INK, 5, true)
				canvas.draw_polyline(line, color.lightened(0.2), 2.4, true)
				canvas.draw_circle(line[-1], 2.4, INK)
			3:
				axis = axis.rotated(wave * 0.19)
				var tip: Vector2 = start + axis * length
				var left: Vector2 = start + axis * length * 0.70 + normal * length * 0.48
				var right: Vector2 = start + axis * length * 0.66 - normal * length * 0.48
				polygon(canvas, PackedVector2Array([start, left, tip, right]), color.lightened(0.28))
				for finger in [left, tip, right]: canvas.draw_line(start, finger, INK, 1.4, true)

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
	canvas.draw_set_transform(center + Vector2(0, sin(phase * 2) * 1.6 * zoom), 0, Vector2(zoom * facing, zoom))
	for i in data.organs.size():
		if data.organs[i].kind in [1, 3]: draw_organ(canvas, data.organs[i], i, phase, data.color, p.legs)
	for i in range(data.nodes.size() - 1, -1, -1):
		var n: Dictionary = data.nodes[i]
		polygon(canvas, n.shape, data.color.darkened(i * 0.018))
		for spot in data.spots:
			var at: Vector2 = n.pos + Vector2(spot.x * n.rx, spot.y * n.ry)
			if p.pattern < 0.5: canvas.draw_circle(at, 1.5 + p.pattern * 3, data.color.darkened(0.22))
			else: canvas.draw_line(at - Vector2(1, 3), at + Vector2(2, 3), data.color.darkened(0.22), 2, true)
		if p.shell > 0.6: canvas.draw_arc(n.pos, n.ry * 0.74, PI, TAU, 16, INK, 2.3, true)
		if p.spines > 0.5:
			for j in 3:
				var at: Vector2 = n.pos + Vector2((j - 1) * n.rx * 0.52, -n.ry * 0.7)
				polygon(canvas, PackedVector2Array([at - Vector2(3, 0), at + Vector2(0, -p.spines * 9), at + Vector2(3, 0)]), data.color.lightened(0.22), 1.8)
	for i in data.organs.size():
		if data.organs[i].kind in [0, 2]: draw_organ(canvas, data.organs[i], i, phase, data.color, p.legs)
	for at in data.eyes:
		var stalk: Vector2 = Vector2(clampf(at.x, -data.nodes[0].rx * 0.65, data.nodes[0].rx * 0.65), -data.nodes[0].ry * 0.35)
		canvas.draw_line(stalk, at, INK, 2, true)
		canvas.draw_circle(at, data.eye_size + 1.6, INK)
		canvas.draw_circle(at, data.eye_size, Color("fffaf0"))
		canvas.draw_circle(at + Vector2(1.2, 0.8), data.eye_size * 0.43, INK)
	canvas.draw_arc(Vector2(data.nodes[0].rx * 0.68, p.radius * 0.16), 2.5 + p.mouth * 3, 0.0, PI * 0.85, 8, INK, 1.8, true)
	canvas.draw_set_transform(Vector2.ZERO)

func egg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fff7de")
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
