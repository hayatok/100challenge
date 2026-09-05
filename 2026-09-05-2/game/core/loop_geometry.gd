extends RefCounted
## Pure planar geometry. Display/camera coordinates never enter these functions.
const EPS = 0.00001

static func intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Dictionary:
	var r = b - a
	var s = d - c
	var cross = r.cross(s)
	if absf(cross) < EPS:
		return {} # Collinear retracing is not an enclosure.
	var t = (c - a).cross(s) / cross
	var u = (c - a).cross(r) / cross
	if t <= EPS or t > 1.0 + EPS or u < -EPS or u > 1.0 + EPS:
		return {}
	return {"point": a + r * t, "progress": t}

static func area(poly: PackedVector2Array) -> float:
	var result = 0.0
	for i in poly.size():
		result += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(result) * 0.5

static func contains(point: Vector2, poly: PackedVector2Array) -> bool:
	if poly.size() < 3:
		return false
	# Boundary is included. Match the visible filled region.
	for i in poly.size():
		var a = poly[i]
		var b = poly[(i + 1) % poly.size()]
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_squared_to(point) < EPS:
			return true
	return Geometry2D.is_point_in_polygon(point, poly)

static func close_loop(trail: Array, next: Vector2, now: float, min_area: float = 2.0) -> PackedVector2Array:
	var best = PackedVector2Array()
	var progress = INF
	if trail.size() < 4:
		return best
	var from: Vector2 = trail[-1].p
	for i in range(trail.size() - 2):
		if now - float(trail[i + 1].t) < 0.25:
			continue
		var hit = intersection(from, next, trail[i].p, trail[i + 1].p)
		if hit.is_empty() or hit.progress >= progress:
			continue
		var poly = PackedVector2Array([hit.point])
		for j in range(i + 1, trail.size()):
			poly.append(trail[j].p)
		if area(poly) >= min_area:
			best = simplify(poly)
			progress = hit.progress
	return best

static func bounds(poly: PackedVector2Array) -> Rect2:
	var box = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box

static func simplify(poly: PackedVector2Array) -> PackedVector2Array:
	# Remove redundant straight-line samples; keep turns and the enclosed shape.
	var result = PackedVector2Array()
	for p in poly:
		while result.size() >= 2:
			var a = result[-1] - result[-2]
			var b = p - result[-1]
			if absf(a.cross(b)) > EPS or a.dot(b) < 0.0:
				break
			result.remove_at(result.size()-1)
		result.append(p)
	return result
