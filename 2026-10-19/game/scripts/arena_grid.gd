extends RefCounted
## One static navigation grid per chapter. Paths are cached per enemy, never per frame.

const CELL := 50.0
var bounds := Rect2(-1100, -800, 2200, 1600)
var obstacles: Array[Rect2] = []
var grid := AStarGrid2D.new()

func configure(info: Dictionary) -> void:
	bounds = info.bounds
	obstacles.clear()
	for obstacle in info.obstacles:
		obstacles.append(obstacle)
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(roundi(bounds.size.x / CELL), roundi(bounds.size.y / CELL)))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = bounds.position + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in range(grid.region.size.x):
		for y in range(grid.region.size.y):
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not is_clear(grid.get_point_position(cell), 44.0))

func is_clear(at: Vector2, radius: float = 14.0) -> bool:
	if not bounds.grow(-radius).has_point(at):
		return false
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(at):
			return false
	return true

func safe_point(at: Vector2, radius: float = 14.0) -> Vector2:
	var inside := bounds.grow(-radius - 1.0)
	var point := Vector2(clampf(at.x, inside.position.x, inside.end.x), clampf(at.y, inside.position.y, inside.end.y))
	for obstacle in obstacles:
		var solid := obstacle.grow(radius + 1.0)
		if not solid.has_point(point):
			continue
		var distances := [absf(point.x - solid.position.x), absf(point.x - solid.end.x), absf(point.y - solid.position.y), absf(point.y - solid.end.y)]
		var closest := 0
		for i in range(1, 4):
			if float(distances[i]) < float(distances[closest]):
				closest = i
		match closest:
			0: point.x = solid.position.x - 0.1
			1: point.x = solid.end.x + 0.1
			2: point.y = solid.position.y - 0.1
			3: point.y = solid.end.y + 0.1
	return point

func move(at: Vector2, displacement: Vector2, radius: float = 14.0) -> Vector2:
	var candidate := at + displacement
	if is_clear(candidate, radius):
		return candidate
	# Sliding preserves the player's direction along a wall instead of gluing to it.
	var horizontal := at + Vector2(displacement.x, 0)
	var vertical := at + Vector2(0, displacement.y)
	if is_clear(horizontal, radius):
		at = horizontal
	if is_clear(at + Vector2(0, displacement.y), radius):
		return at + Vector2(0, displacement.y)
	if is_clear(vertical, radius) and horizontal == at:
		return vertical
	return safe_point(at, radius)

func segment_clear(from: Vector2, to: Vector2, radius: float = 14.0) -> bool:
	if not is_clear(from, radius) or not is_clear(to, radius):
		return false
	for obstacle in obstacles:
		var solid := obstacle.grow(radius)
		var top_right := Vector2(solid.end.x, solid.position.y)
		var bottom_left := Vector2(solid.position.x, solid.end.y)
		if Geometry2D.segment_intersects_segment(from, to, solid.position, top_right) != null or Geometry2D.segment_intersects_segment(from, to, top_right, solid.end) != null or Geometry2D.segment_intersects_segment(from, to, solid.end, bottom_left) != null or Geometry2D.segment_intersects_segment(from, to, bottom_left, solid.position) != null:
			return false
	return true

func _cell(at: Vector2) -> Vector2i:
	var result := Vector2i(((at - bounds.position) / CELL).floor())
	result.x = clampi(result.x, 0, grid.region.size.x - 1)
	result.y = clampi(result.y, 0, grid.region.size.y - 1)
	if not grid.is_point_solid(result):
		return result
	for radius in range(1, 7):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var test := result + Vector2i(x, y)
				if grid.is_in_boundsv(test) and not grid.is_point_solid(test):
					return test
	return result

func route(enemy: Dictionary, target: Vector2, dt: float) -> Vector2:
	var origin: Vector2 = enemy.position
	var radius := float(enemy.radius)
	if segment_clear(origin, target, radius + 2.0):
		enemy.nav_clock = 0.0
		return origin.direction_to(target)
	enemy.nav_clock = float(enemy.get("nav_clock", 0.0)) - dt
	var path: PackedVector2Array = enemy.get("nav_path", PackedVector2Array())
	if float(enemy.nav_clock) <= 0.0 or path.is_empty():
		path = grid.get_point_path(_cell(origin), _cell(target), true)
		enemy.nav_clock = 0.65 + float(int(enemy.id) % 5) * 0.08
		# Skip the current cell; path points use the same world coordinates as collision.
		if path.size() > 1:
			path.remove_at(0)
	while path.size() > 1 and origin.distance_to(path[0]) < 28.0:
		path.remove_at(0)
	enemy.nav_path = path
	if path.is_empty():
		return origin.direction_to(target)
	return origin.direction_to(path[0])
