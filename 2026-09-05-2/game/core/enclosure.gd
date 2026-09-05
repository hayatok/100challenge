extends RefCounted
## Pixel-space, finite-segment geometry. Rendering and input have no influence.
const EPS = 0.001

static func crossing(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Dictionary:
	var ab = b-a
	var cd = d-c
	var denominator = ab.cross(cd)
	if absf(denominator) < EPS:
		return {}
	var t = (c-a).cross(cd)/denominator
	var u = (c-a).cross(ab)/denominator
	if t > EPS and t <= 1.0+EPS and u >= -EPS and u <= 1.0+EPS:
		return {"point":a+ab*clampf(t,0.0,1.0), "t":t}
	return {}

static func area(polygon: PackedVector2Array) -> float:
	var twice = 0.0
	for i in polygon.size():
		twice += polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(twice)*0.5

static func contains(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	for i in polygon.size():
		if Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]).distance_squared_to(point) < 0.01:
			return true
	return Geometry2D.is_point_in_polygon(point,polygon)

static func close(path: Array, next: Vector2, now: float, minimum := 900.0) -> PackedVector2Array:
	if path.size() < 4:
		return PackedVector2Array()
	var previous: Vector2 = path[-1].p
	var candidates: Array = []
	for i in range(path.size()-2):
		if now-float(path[i+1].t) < 0.25:
			continue
		var hit = crossing(previous,next,path[i].p,path[i+1].p)
		if not hit.is_empty():
			hit["index"] = i
			candidates.append(hit)
	candidates.sort_custom(func(a,b):return a.t < b.t)
	for hit in candidates:
		var polygon = PackedVector2Array([hit.point])
		for i in range(int(hit.index)+1,path.size()):
			if polygon[-1].distance_squared_to(path[i].p)>0.01:
				polygon.append(path[i].p)
		if area(polygon) >= minimum:
			return polygon
	return PackedVector2Array()
