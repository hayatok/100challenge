extends Node2D
## Retain world geometry and bake obstacle layers once for each of three chapters.

const FloorArt := preload("res://scripts/campaign_floor.gd")
const MAX_CHAPTERS := 3
const ATLAS_WIDTH := 1024
const MAX_ATLAS_HEIGHT := 2048
const PART_MARGIN := 20.0
const PART_GUTTER := 4

class FloorLayer:
	extends Node2D
	var geometry: Dictionary
	var textures: Dictionary
	var run: Dictionary
	var screen: Vector2
	var world_frame: Rect2
	var builds := 0

	func configure(chapter: int, info: Dictionary, art: Dictionary) -> void:
		geometry = info.duplicate(true)
		textures = art
		world_frame = (info.get("bounds", Rect2(-1100, -800, 2200, 1600)) as Rect2).grow(64)
		screen = world_frame.size
		run = {"chapter": chapter, "player": world_frame.position + screen * Vector2(0.5, 0.52)}
		position = world_frame.position

	func world(at: Vector2) -> Vector2:
		return at - world_frame.position

	func _draw() -> void:
		builds += 1
		FloorArt.draw_floor(self, geometry, textures)

	func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
		draw_set_transform(at, 0, Vector2(1, radius.y / maxf(0.01, radius.x)))
		draw_circle(Vector2.ZERO, radius.x, color)
		draw_set_transform(Vector2.ZERO)

class ObstacleAtlas:
	extends Node2D
	var parts: Array[Dictionary] = []
	var run: Dictionary
	var screen: Vector2
	var builds := 0
	var _world_origin := Vector2.ZERO
	var _atlas_origin := Vector2.ZERO

	func world(at: Vector2) -> Vector2:
		return at - _world_origin + _atlas_origin

	func _draw() -> void:
		builds += 1
		for part in parts:
			_world_origin = (part.frame as Rect2).position
			_atlas_origin = (part.region as Rect2).position
			if bool(part.base):
				FloorArt.draw_obstacle_base(self, part.obstacle)
			else:
				FloorArt.draw_obstacle(self, part.obstacle, int(run.chapter), int(part.index))

	func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
		draw_set_transform(at, 0, Vector2(1, radius.y / maxf(0.01, radius.x)))
		draw_circle(Vector2.ZERO, radius.x, color)
		draw_set_transform(Vector2.ZERO)

var _entries: Dictionary = {}
var _active_chapter := -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	# The floor has a bounded world surface. This retained quad fills the distant
	# void at every supported camera position without a screen-sized redraw.
	draw_rect(Rect2(-16384, -16384, 32768, 32768), Color("0c1420"))

func select_chapter(chapter: int, geometry: Dictionary, textures: Dictionary) -> void:
	assert(chapter >= 0 and chapter < MAX_CHAPTERS)
	if not _entries.has(chapter):
		_entries[chapter] = _create_entry(chapter, geometry, textures)
	if _active_chapter == chapter:
		return
	for id in _entries:
		(_entries[id].floor as Node2D).visible = int(id) == chapter
	_active_chapter = chapter

func _create_entry(chapter: int, geometry: Dictionary, textures: Dictionary) -> Dictionary:
	var layer := FloorLayer.new()
	layer.configure(chapter, geometry, textures)
	var layout := _atlas_layout(geometry.get("obstacles", []))
	var viewport := SubViewport.new()
	viewport.name = "ObstacleAtlas%d" % chapter
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.size = layout.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var atlas := ObstacleAtlas.new()
	atlas.parts.assign(layout.parts)
	atlas.run = {"chapter": chapter}
	atlas.screen = Vector2(layout.size)
	add_child(layer)
	add_child(viewport)
	viewport.add_child(atlas)
	return {"floor": layer, "viewport": viewport, "atlas": atlas, "texture": viewport.get_texture(), "parts": layout.parts, "geometry": geometry.duplicate(true)}

static func _atlas_layout(obstacles: Array) -> Dictionary:
	var cursor := Vector2i.ZERO
	var row_height := 0
	var used_width := 1
	var parts: Array[Dictionary] = []
	for i in range(obstacles.size()):
		var obstacle: Rect2 = obstacles[i]
		var frame := obstacle.grow(PART_MARGIN)
		var part_size := Vector2i(ceili(frame.size.x), ceili(frame.size.y))
		assert(part_size.x <= ATLAS_WIDTH)
		for base in [true, false]:
			if cursor.x + part_size.x > ATLAS_WIDTH:
				cursor.x = 0
				cursor.y += row_height + PART_GUTTER
				row_height = 0
			parts.append({"index": i, "base": base, "obstacle": obstacle, "frame": frame, "region": Rect2(Vector2(cursor), Vector2(part_size))})
			used_width = maxi(used_width, cursor.x + part_size.x)
			cursor.x += part_size.x + PART_GUTTER
			row_height = maxi(row_height, part_size.y)
	var used_height := maxi(1, cursor.y + row_height)
	assert(used_height <= MAX_ATLAS_HEIGHT)
	return {"size": Vector2i(used_width, used_height), "parts": parts}

func draw_obstacle(view, index: int, base: bool = false) -> void:
	var entry: Dictionary = _entries[_active_chapter]
	var part: Dictionary = entry.parts[index * 2 + (0 if base else 1)]
	var frame: Rect2 = part.frame
	var destination := Rect2(view.world(frame.position), frame.size)
	if destination.intersects(Rect2(Vector2.ZERO, view.screen)):
		view.draw_texture_rect_region(entry.texture, destination, part.region)

func diagnostics() -> Dictionary:
	var chapters: Array[Dictionary] = []
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var viewport: SubViewport = entry.viewport
		chapters.append({"chapter": id, "floor_builds": int(entry.floor.builds), "atlas_builds": int(entry.atlas.builds), "atlas_size": viewport.size, "atlas_update_mode": viewport.render_target_update_mode, "geometry": entry.geometry.duplicate(true)})
	return {"count": _entries.size(), "limit": MAX_CHAPTERS, "active": _active_chapter, "chapters": chapters}
