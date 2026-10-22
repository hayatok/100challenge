extends SceneTree
const Renderer := preload("res://scripts/garden_view.gd")
func _initialize() -> void:
	var checked := 0
	var skipped := 0
	var old_failures := 0
	var radii: Array[float] = [-1.0, 0.0, 1.0e-16, 1.0e-12, 0.00002, 0.002, 0.02, 0.2, 0.499999, 0.5]
	for i in range(1, 4097):
		radii.append(float(i) / 256.0)
	for radius in radii:
		var points: PackedVector2Array = Renderer._star_points(radius)
		if radius < Renderer.MIN_STAR_RADIUS:
			assert(points.is_empty(), "Nonvisible star must end before triangulation")
			skipped += 1
			continue
		assert(points.size() == 8, "Visible star lost a vertex")
		var indices := Geometry2D.triangulate_polygon(points)
		assert(indices.size() == 18, "Visible star did not yield six triangles: " + str(radius))
		var area := 0.0
		for i in range(points.size()):
			area += points[i].cross(points[(i + 1) % points.size()])
			assert(points[i].length() <= radius + 0.0001)
		assert(absf(area) > 0.0001, "Visible star area vanished")
		checked += 1
	# Confirm the former screen-space algorithm fails in the reported camera range.
	for radius in [0.002, 0.02, 0.2]:
		for at in [Vector2(727.8345,615.5197), Vector2(927.8345,538.5197), Vector2(1120,640)]:
			var old := PackedVector2Array()
			for i in range(8):
				old.append(at + Vector2.from_angle(-PI * 0.5 + float(i) * TAU / 8) * (radius if i % 2 == 0 else radius * 0.25))
			if Geometry2D.triangulate_polygon(old).is_empty():
				old_failures += 1
	print("STAR_GEOMETRY_PASS visible=%d skipped_subpixel=%d original_screen_space_failures=%d" % [checked, skipped, old_failures])
	quit()
