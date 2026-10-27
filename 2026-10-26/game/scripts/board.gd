extends Control
## Layered Godot presentation for a resolved expedition. Owns no game rules.

signal cell_selected(x: int, y: int)

const ACTOR_SCENE := preload("res://scenes/actor.tscn")
const TILE := 64
const PATTERN_SPAN := 2
const LANDMARK_SHADER = preload("res://shaders/coastal_landmark.gdshader")
const ART_ROOT := "res://assets/art/"
const R2_ROOT := "res://assets/art/r2/"
const RuleData = preload("res://scripts/rules.gd")
const WorldDataFile = preload("res://scripts/world_data.gd")
const FONT_PATH := "res://assets/fonts/NotoSansCJKjp-Medium.otf"

@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $World/Ground
@onready var outer_sea: TileMapLayer = $World/OuterSea
@onready var water: TileMapLayer = $World/Water
@onready var walls: TileMapLayer = $World/Walls
@onready var shore: Node2D = $World/Shore
@onready var depth: Node2D = $World/Depth
@onready var details: Node2D = $World/Details
@onready var landmarks: Node2D = $World/Landmarks
@onready var ambient: Node2D = $World/Ambient
@onready var actors: Node2D = $World/Actors
@onready var telegraphs: Node2D = $World/Telegraphs
@onready var fog: Node2D = $World/Fog
@onready var effects: Node2D = $World/Effects

var _run: Dictionary = {}
var _visible: Dictionary = {}
var _seen: Dictionary = {}
var _fog_cells: Dictionary = {}
var _actor_nodes: Dictionary = {}
var _textures: Dictionary = {}
var _tile_set: TileSet
var _character := "isana"
var _reduce := false
var _seed := -999
var _last_turn := -1
var _last_tide := -1
var _camera_tween: Tween
var _has_world := false
var _terrain_signature := -1
var _focus_paused := false
var _overlay_paused := false
var _motion_time := 0.0
var _glint_clock := 0.0
var _landmark_nodes: Array[Dictionary] = []
var _route_mask: ImageTexture
var _crate_nodes: Dictionary = {}
var _previous_positions: Dictionary = {}
var _light_texture: Texture2D
var _font: Font

func _ready() -> void:
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input)
	visibility_changed.connect(_update_motion_state)
	_font = load(FONT_PATH) as Font
	_create_terrain()
	_create_light_texture()

func present(state: Dictionary, events: Array = [], reduced_motion: bool = false) -> void:
	if not is_node_ready():
		await ready
	_reduce = reduced_motion
	(water.material as ShaderMaterial).set_shader_parameter("reduced_motion", _reduce)
	if not state.get("run") is Dictionary or state.get("run", {}).is_empty():
		return
	# Result overlays retain the final resolved place instead of destroying it.
	var incoming: Dictionary = state["run"]
	_character = str(state.get("character", incoming.get("character", "isana")))
	_run = incoming
	_visible = _compute_visibility(_run)
	_seen.clear()
	for key: Variant in _run.get("seen", []):
		_seen[str(key)] = true
	for key: Variant in _visible:
		_seen[str(key)] = true
	var map_changed := not _has_world or int(_run.get("seed", 0)) != _seed or int(_run.get("turn", 0)) < _last_turn
	if map_changed:
		_seed = int(_run.get("seed", 0))
		_last_turn = -1
		_build_map()
	else:
		_refresh_terrain()
	_refresh_fog()
	_refresh_landmark_clearance()
	_refresh_details()
	_refresh_actors(map_changed)
	_refresh_telegraphs()
	_position_camera(map_changed or _reduce)
	if int(_run.get("turn", 0)) != _last_turn or map_changed:
		_play_events(events)
	_last_turn = int(_run.get("turn", 0))
	_last_tide = int(_run.get("tide", 0))
	_has_world = true
	_update_motion_state()

func get_visible_tiles() -> Dictionary:
	return _visible.duplicate()

func set_presentation_paused(paused: bool) -> void:
	_overlay_paused = paused
	_update_motion_state()

func _presentation_paused() -> bool:
	return _overlay_paused or _focus_paused or not is_visible_in_tree()

func _process(delta: float) -> void:
	if not _has_world or _presentation_paused() or _reduce:
		return
	_motion_time += minf(delta, 0.05)
	(water.material as ShaderMaterial).set_shader_parameter("motion_time", _motion_time)
	(fog.material as ShaderMaterial).set_shader_parameter("motion_time", _motion_time)
	_glint_clock += delta
	if _glint_clock > 2.6:
		_glint_clock = 0.0
		var candidates: Array[String] = []
		for key: String in _visible:
			var xy := key.split(",")
			if _is_flooded(int(xy[0]), int(xy[1])):
				candidates.append(key)
		if not candidates.is_empty():
			var selected := candidates[int(_motion_time * 7) % candidates.size()].split(",")
			effects.ripple(_cell_position(int(selected[0]), int(selected[1])), 0.9, Color(1, 1, 0.9, 0.65), 1.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_paused = true
		_update_motion_state()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_paused = false
		_update_motion_state()

func _update_motion_state() -> void:
	if not is_node_ready():
		return
	var pause_motion := _presentation_paused()
	world.process_mode = Node.PROCESS_MODE_DISABLED if pause_motion else Node.PROCESS_MODE_INHERIT
	(water.material as ShaderMaterial).set_shader_parameter("reduced_motion", _reduce)
	ambient.reduced_motion = _reduce
	effects.reduced_motion = _reduce
	if _camera_tween != null and _camera_tween.is_valid():
		if pause_motion:
			_camera_tween.pause()
		else:
			_camera_tween.play()
	for child: Node in effects.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED if pause_motion else Node.PROCESS_MODE_INHERIT

func _on_gui_input(event: InputEvent) -> void:
	if _run.is_empty() or _presentation_paused():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (event.position - world.position) / world.scale
		var cell := Vector2i(floori(local.x / TILE), floori(local.y / TILE))
		if _in_bounds(cell.x, cell.y):
			cell_selected.emit(cell.x, cell.y)
		accept_event()

func _on_resized() -> void:
	if _has_world:
		_position_camera(true)

func _position_camera(immediate: bool) -> void:
	if size.x < 1 or size.y < 1 or _run.is_empty():
		return
	var p: Dictionary = _run["player"]
	var zoom_factor := clampf(size.x / (7.35 * TILE), 0.66, 1.08)
	# Keep enough route in view above the character while respecting the map edge.
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	var feet := _cell_position(int(p["x"]), int(p["y"])) + Vector2(0, 19)
	var destination := center - feet * zoom_factor
	var map_size := Vector2(int(_run.get("width", 25)), int(_run.get("height", 25))) * TILE * zoom_factor
	destination.x = clampf(destination.x, size.x * 0.5 - map_size.x, size.x * 0.5)
	destination.y = clampf(destination.y, minf(16.0, size.y - map_size.y - maxf(TILE * zoom_factor * 4.0, size.y * 0.58)), size.y * 0.48)
	world.scale = Vector2.ONE * zoom_factor
	ambient.area = Rect2(-destination / zoom_factor, size / zoom_factor)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	if immediate:
		world.position = destination
	else:
		_camera_tween = create_tween()
		_camera_tween.tween_property(world, "position", destination, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _create_terrain() -> void:
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(TILE, TILE)
	# Two-cell painted patches keep stone sizes subordinate to actors and buildings.
	var patch_size := TILE * PATTERN_SPAN
	var atlas_image := Image.create(patch_size * 4, patch_size, false, Image.FORMAT_RGBA8)
	var atlas_texture := _texture("terrain-day")
	if atlas_texture == null:
		atlas_texture = _texture("terrain-atlas")
	for tile_index in 4:
		var part: Image
		if atlas_texture != null:
			var source_image := atlas_texture.get_image()
			var half := Vector2i(source_image.get_width() / 2, source_image.get_height() / 2)
			part = source_image.get_region(Rect2i(Vector2i(tile_index % 2, tile_index / 2) * half, half))
			part.resize(patch_size, patch_size, Image.INTERPOLATE_LANCZOS)
			part.convert(Image.FORMAT_RGBA8)
		else:
			part = _temporary_terrain(tile_index)
			part.resize(patch_size, patch_size)
		atlas_image.blit_rect(part, Rect2i(0, 0, patch_size, patch_size), Vector2i(tile_index * patch_size, 0))
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(atlas_image)
	atlas_source.texture_region_size = Vector2i(TILE, TILE)
	for y in PATTERN_SPAN:
		for x in PATTERN_SPAN * 4:
			atlas_source.create_tile(Vector2i(x, y))
	_tile_set.add_source(atlas_source, 0)
	ground.tile_set = _tile_set
	water.tile_set = _tile_set
	outer_sea.tile_set = _tile_set
	walls.tile_set = _tile_set

func _atlas_coordinate(kind: int, x: int, y: int) -> Vector2i:
	return Vector2i(kind * PATTERN_SPAN + x % PATTERN_SPAN, y % PATTERN_SPAN)

func _temporary_terrain(index: int) -> Image:
	# Native fallback is only used during initial imports while art is being created.
	var colors := [Color("445355"), Color("69706b"), Color("676456"), Color("23525a")]
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(colors[index])
	for y in TILE:
		for x in TILE:
			var edge := x % 31 == 0 or y % 23 == 0
			var grain := float((x * 17 + y * 29) % 19) / 300.0
			image.set_pixel(x, y, colors[index].lightened(grain).darkened(0.2 if edge else 0.0))
	return image

func _create_light_texture() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 0.81, 0.48, 0.8), Color(0.96, 0.61, 0.21, 0.25), Color(1, 0.66, 0.3, 0)])
	gradient.offsets = PackedFloat32Array([0, 0.35, 1])
	var radial := GradientTexture2D.new()
	radial.gradient = gradient
	radial.width = 128
	radial.height = 128
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1, 0.5)
	_light_texture = radial

func _build_map() -> void:
	_terrain_signature = -1
	_clear_children(shore)
	_clear_children(depth)
	_clear_children(fog)
	_clear_children(actors)
	_clear_children(effects)
	_clear_children(landmarks)
	_landmark_nodes.clear()
	_crate_nodes.clear()
	_previous_positions.clear()
	_actor_nodes.clear()
	_fog_cells.clear()
	ground.clear()
	water.clear()
	walls.clear()
	outer_sea.clear()
	for y in range(-8, 41):
		for x in range(-8, 34):
			outer_sea.set_cell(Vector2i(x, y), 0, _atlas_coordinate(3, posmod(x, PATTERN_SPAN), posmod(y, PATTERN_SPAN)))
	var tiles: Array = _run.get("tiles", [])
	for y in tiles.size():
		for x in (tiles[y] as Array).size():
			var cover := Polygon2D.new()
			cover.polygon = _rect_polygon(Vector2.ZERO, Vector2(TILE + 0.8, TILE + 0.8))
			cover.position = Vector2(x, y) * TILE
			cover.use_parent_material = true
			fog.add_child(cover)
			_fog_cells[_key(x, y)] = cover
	_refresh_terrain()
	_build_landmarks()

func _refresh_terrain() -> void:
	var signature: int = hash([_run.get("tiles", []), _run.get("tide", 0)])
	if signature == _terrain_signature:
		return
	_terrain_signature = signature
	water.clear()
	walls.clear()
	_clear_children(shore)
	_clear_children(depth)
	var tiles: Array = _run.get("tiles", [])
	for y in tiles.size():
		for x in (tiles[y] as Array).size():
			var tile: Dictionary = tiles[y][x]
			var kind := str(tile.get("type", "floor"))
			var raised := int(tile.get("elevation", 1)) >= 5
			ground.set_cell(Vector2i(x, y), 0, _atlas_coordinate(2 if raised and kind != "wall" else 0, x, y))
			var outer_harbor := kind == "wall" and (y == 24 or (x in [0, 24] and y >= 18))
			if outer_harbor or _is_flooded(x, y):
				water.set_cell(Vector2i(x, y), 0, _atlas_coordinate(3, x, y))
				if outer_harbor:
					_line(shore, Vector2(x * TILE, y * TILE + 3), Vector2((x + 1) * TILE, y * TILE + 3), Color("fff1c9"), 5)
				else:
					_add_water_edges(x, y)
			elif kind == "wall":
				walls.set_cell(Vector2i(x, y), 0, _atlas_coordinate(1, x, y))
				_add_wall_face(x, y)
			elif raised:
				_line(depth, Vector2(x * TILE + 2, y * TILE + TILE - 2), Vector2((x + 1) * TILE - 2, (y + 1) * TILE - 2), Color("fff0bd"), 2)
				if x == 12 and y % 3 == 0:
					_add_pier_post(Vector2(x * TILE + 4, y * TILE + 44))
			if kind == "gate":
				_line(depth, Vector2(x * TILE + 4, y * TILE + 7), Vector2(x * TILE + 4, y * TILE + 55), Color("e7cda2"), 5)
				_line(depth, Vector2((x + 1) * TILE - 4, y * TILE + 7), Vector2((x + 1) * TILE - 4, y * TILE + 55), Color("e7cda2"), 5)

func _add_water_edges(x: int, y: int) -> void:
	for offset: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if not _in_bounds(x + offset.x, y + offset.y) or _is_flooded(x + offset.x, y + offset.y):
			continue
		var start := Vector2(x, y) * TILE
		var end := start
		if offset.y == -1:
			end += Vector2(TILE, 0)
		elif offset.y == 1:
			start += Vector2(0, TILE)
			end += Vector2(TILE, TILE)
		elif offset.x == -1:
			end += Vector2(0, TILE)
		else:
			start += Vector2(TILE, 0)
			end += Vector2(TILE, TILE)
		_line(shore, start, end, Color(0.15, 0.58, 0.61, 0.4), 7)
		_line(shore, start, end, Color(0.98, 1, 0.91, 0.94), 2.4)

func _add_wall_face(x: int, y: int) -> void:
	# Low retaining walls are distinct from the authored houses and workshops.
	var origin := Vector2(x, y) * TILE
	if _tile_type(x, y + 1) != "wall":
		var cast_shadow := Polygon2D.new()
		cast_shadow.position = origin
		cast_shadow.polygon = PackedVector2Array([Vector2(2, 53), Vector2(63, 53), Vector2(70, 71), Vector2(9, 71)])
		cast_shadow.color = Color(0.2, 0.5, 0.53, 0.13)
		depth.add_child(cast_shadow)
	var face := Polygon2D.new()
	face.position = origin + Vector2(1, 49)
	face.polygon = _rect_polygon(Vector2.ZERO, Vector2(62, 13))
	face.color = Color("e5dbbf")
	depth.add_child(face)
	_line(depth, origin + Vector2(0, 48), origin + Vector2(64, 48), Color("fff1d1"), 5)
	_line(depth, origin + Vector2(1, 62), origin + Vector2(64, 62), Color(0.25, 0.49, 0.5, 0.3), 2)
	if (x * 3 + y * 5) % 7 == 0:
		_line(depth, origin + Vector2(19, 50), origin + Vector2(21, 59), Color(0.55, 0.63, 0.54, 0.35), 1.3)

func _add_pier_post(at: Vector2) -> void:
	_line(depth, at + Vector2(2, 4), at + Vector2(2, -10), Color(0.27, 0.42, 0.4, 0.25), 8)
	_line(depth, at, at + Vector2(0, -13), Color("a87a4d"), 5)
	_line(depth, at + Vector2(-4, -13), at + Vector2(4, -13), Color("ffe1a0"), 3)

func _refresh_fog() -> void:
	for key: Variant in _fog_cells:
		var cover: Polygon2D = _fog_cells[key]
		cover.visible = not _visible.has(key)
		cover.color = Color(0.77, 0.87, 0.83, 0.57) if _seen.has(key) else Color("b8d8d4")
	for entry: Dictionary in _landmark_nodes:
		var known := _seen.has(entry.key)
		var prop: Sprite2D = entry.node
		prop.visible = known
		if entry.get("mooring") != null:
			(entry.mooring as CanvasItem).visible = known
		prop.modulate = Color.WHITE if _visible.has(entry.key) else Color(0.84, 0.94, 0.92, 0.62)

func _refresh_landmark_clearance() -> void:
	var image := Image.create(25, 25, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for key: String in _visible:
		var xy := key.split(",")
		var x := int(xy[0])
		var y := int(xy[1])
		if WorldDataFile.is_walkable(_run, x, y):
			image.set_pixel(x, y, Color.WHITE)
	if _route_mask == null:
		_route_mask = ImageTexture.create_from_image(image)
	else:
		_route_mask.update(image)
	var player: Dictionary = _run["player"]
	var feet := _cell_position(int(player["x"]), int(player["y"])) + Vector2(0, 19)
	for entry: Dictionary in _landmark_nodes:
		var material: ShaderMaterial = (entry.node as Sprite2D).material
		material.set_shader_parameter("route_mask", _route_mask)
		material.set_shader_parameter("player_feet", feet)

func _refresh_details() -> void:
	_clear_children(details)
	_crate_nodes.clear()
	var tiles: Array = _run.get("tiles", [])
	for y in tiles.size():
		for x in (tiles[y] as Array).size():
			if not _visible.has(_key(x, y)):
				continue
			var tile: Dictionary = tiles[y][x]
			if str(tile.get("type", "")) != "floor" or _is_flooded(x, y):
				continue
			var variant := int(tile.get("variant", 0)) + x * 13 + y * 17
			if variant % 17 == 0:
				_add_rope(_cell_position(x, y) + Vector2(21, 19))
			elif variant % 19 == 0:
				_add_flowers(_cell_position(x, y) + Vector2(-22, 19))
			elif variant % 29 == 0 and y >= 18:
				_add_bollard(_cell_position(x, y) + Vector2(-22, 18))
			elif variant % 23 == 0:
				var edge := _cell_position(x, y) + Vector2(24, -22)
				_line(details, edge + Vector2(-4, 5), edge + Vector2(-7, -3), Color("98b286"), 1.6)
				_line(details, edge + Vector2(-2, 5), edge + Vector2(-1, -6), Color("80a37a"), 1.8)
				_line(details, edge + Vector2(0, 5), edge + Vector2(5, -2), Color("a1b98d"), 1.6)
	for container: Dictionary in _run.get("containers", []):
		var x := int(container["x"])
		var y := int(container["y"])
		if not _visible.has(_key(x, y)):
			continue
		var empty := bool(container.get("searched", false)) and (container.get("items", []) as Array).is_empty()
		var crate := _painted_crate(_cell_position(x, y) + Vector2(0, 12), empty)
		_crate_nodes[_key(x, y)] = crate
	var exit_cell: Dictionary = _run.get("exit", {})
	if not exit_cell.is_empty() and _seen.has(_key(int(exit_cell["x"]), int(exit_cell["y"]))):
		_add_exit(int(exit_cell["x"]), int(exit_cell["y"]))

func _painted_crate(at: Vector2, empty: bool) -> Node2D:
	var crate := Node2D.new()
	crate.position = at
	details.add_child(crate)
	var shadow := Polygon2D.new()
	shadow.polygon = _rect_polygon(Vector2(-19, 5), Vector2(43, 12))
	shadow.color = Color(0.15, 0.43, 0.44, 0.22)
	crate.add_child(shadow)
	var front := Polygon2D.new()
	front.polygon = PackedVector2Array([Vector2(-20, -8), Vector2(19, -8), Vector2(19, 14), Vector2(-20, 14)])
	front.color = Color("b9894c") if empty else Color("e8b560")
	crate.add_child(front)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-20, -8), Vector2(-11, -19), Vector2(27, -19), Vector2(19, -8)])
	lid.color = Color("d3b47d") if empty else Color("ffe0a0")
	if empty:
		lid.position = Vector2(0, -8)
		lid.rotation = -0.12
	crate.add_child(lid)
	var side := Polygon2D.new()
	side.polygon = PackedVector2Array([Vector2(19, -8), Vector2(27, -19), Vector2(27, 4), Vector2(19, 14)])
	side.color = Color("a27848") if empty else Color("ce9850")
	crate.add_child(side)
	_line(crate, Vector2(-20, -7), Vector2(19, -7), Color("825d39"), 2)
	_line(crate, Vector2(-11, -19), Vector2(27, -19), Color("fff0c2"), 1.5)
	for px in [-11, 11]:
		_line(crate, Vector2(px, -6), Vector2(px, 12), Color("347b82"), 4)
	if not empty:
		var diamond := Polygon2D.new()
		diamond.position = Vector2(3, -29)
		diamond.polygon = PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
		diamond.color = Color("fff2a0")
		crate.add_child(diamond)
	return crate

func _add_flowers(at: Vector2) -> void:
	for i in 3:
		var stem := at + Vector2(i * 3 - 3, -i % 2 * 3)
		_line(details, stem + Vector2(0, 4), stem + Vector2(0, -5), Color("69a981"), 2)
		var petal := Polygon2D.new()
		petal.position = stem + Vector2(0, -5)
		petal.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(-2, -3), Vector2(1, -4), Vector2(4, -1), Vector2(2, 2), Vector2(0, 3)])
		petal.color = Color("f38c7d") if i % 2 else Color("fff5c6")
		details.add_child(petal)

func _build_landmarks() -> void:
	# Each building remains anchored on a blocked tile; projection is visual only.
	var anchors := [
		{"kind":"prop_market", "x":9, "y":13, "width":122.0},
		{"kind":"prop_clinic", "x":16, "y":13, "width":134.0, "offset":Vector2(-22, 0)},
		{"kind":"prop_pump", "x":8, "y":4, "width":118.0},
		{"kind":"prop_lighthouse", "x":18, "y":3, "height":196.0},
		{"kind":"prop_boat", "x":11, "y":24, "width":126.0},
		{"kind":"prop_boat", "x":13, "y":24, "width":119.0},
		{"kind":"prop_planter", "x":9, "y":24, "width":53.0},
		{"kind":"prop_planter", "x":14, "y":24, "width":53.0}]
	var occupied: Dictionary = {}
	for anchor: Dictionary in anchors:
		occupied[_key(int(anchor.x), int(anchor.y))] = true
	for y in range(2, 24):
		for x in range(1, 24):
			if _tile_type(x, y) == "wall" and (x * 5 + y * 7) % 19 == 0 and not occupied.has(_key(x, y)):
				anchors.append({"kind":"prop_planter", "x":x, "y":y, "width":47.0})
	for anchor: Dictionary in anchors:
		var x := int(anchor.x)
		var y := int(anchor.y)
		if _tile_type(x, y) not in ["wall", "water"]:
			var replacement := x - 1
			if _tile_type(replacement, y) not in ["wall", "water"]:
				continue
			x = replacement
		var texture := _texture(str(anchor.kind))
		if texture == null:
			continue
		var factor: float = float(anchor.height) / texture.get_height() if anchor.has("height") else float(anchor.width) / texture.get_width()
		var prop := Sprite2D.new()
		prop.texture = texture
		prop.scale = Vector2.ONE * factor
		# Set the base on the wall's southern edge. Height grows into the skyline.
		var base := _cell_position(x, y) + Vector2(0, 27)
		prop.position = base - Vector2(0, texture.get_height() * factor * 0.5) + Vector2(anchor.get("offset", Vector2.ZERO))
		var mooring: Line2D
		if str(anchor.kind) == "prop_boat":
			# Boats float off the quay rather than placing their hull on paving.
			prop.position.y += 50
			var side := 1.0 if x == 13 else -1.0
			if x == 13:
				prop.flip_h = true
			mooring = Line2D.new()
			mooring.points = PackedVector2Array([base + Vector2(side * 23, -56), base + Vector2(side * 28, 9), base + Vector2(side * 31, 30)])
			mooring.default_color = Color("ac8957")
			mooring.width = 2.3
			mooring.antialiased = true
			landmarks.add_child(mooring)
		var material := ShaderMaterial.new()
		material.shader = LANDMARK_SHADER
		material.set_shader_parameter("map_center", prop.position)
		material.set_shader_parameter("map_scale", factor)
		prop.material = material
		landmarks.add_child(prop)
		_landmark_nodes.append({"node":prop, "key":_key(x, y), "kind":str(anchor.kind), "base":base, "mooring":mooring})

func _refresh_actors(immediate: bool) -> void:
	var active_ids: Dictionary = {}
	var player: Dictionary = _run["player"]
	_sync_actor("player", player, _character, true, true, immediate)
	active_ids["player"] = true
	for enemy: Dictionary in _run.get("enemies", []):
		var actor_id := str(enemy["id"])
		active_ids[actor_id] = true
		var is_visible := _visible.has(_key(int(enemy["x"]), int(enemy["y"])))
		_sync_actor(actor_id, enemy, str(enemy.get("kind", "crab")), false, is_visible, immediate)
	for actor_id: Variant in _actor_nodes.keys():
		if not active_ids.has(actor_id):
			var removed: Node2D = _actor_nodes[actor_id]
			removed.queue_free()
			_actor_nodes.erase(actor_id)

func _sync_actor(actor_id: String, data: Dictionary, kind: String, player_actor: bool, show_actor: bool, immediate: bool) -> void:
	var actor: Node2D = _actor_nodes.get(actor_id)
	var fresh := actor == null
	if fresh:
		actor = ACTOR_SCENE.instantiate()
		actors.add_child(actor)
		_actor_nodes[actor_id] = actor
	actor.configure(_texture("crew_" + kind) if player_actor else _texture(kind), kind, player_actor, _reduce)
	actor.set_intent(not player_actor and data.get("intent") is Dictionary and not (data["intent"] as Dictionary).is_empty())
	var was_visible := actor.visible
	actor.visible = show_actor
	var p := _cell_position(int(data["x"]), int(data["y"]))
	var old_position: Vector2 = _previous_positions.get(actor_id, p)
	actor.move_to(p, fresh or immediate or not show_actor or not was_visible)
	if not fresh and not immediate and show_actor and was_visible and p != old_position:
		effects.step(old_position.lerp(p, 0.75), _is_flooded(int(data["x"]), int(data["y"])), (p - old_position).normalized())
	_previous_positions[actor_id] = p
	var face_data: Dictionary = data.get("facing", {})
	actor.face(Vector2(float(face_data.get("x", 1)), float(face_data.get("y", 0))))
	var maximum := int(data.get("maxHp", {"crab": 5, "wader": 7, "diver": 11}.get(kind, 10)))
	actor.set_health(int(data.get("hp", maximum)), maximum)

func _refresh_telegraphs() -> void:
	_clear_children(telegraphs)
	var player: Dictionary = _run["player"]
	for delta: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell := Vector2i(int(player["x"]), int(player["y"])) + delta
		if not _visible.has(_key(cell.x, cell.y)) or _tile_type(cell.x, cell.y) in ["water", "wall"]:
			continue
		var origin := Vector2(cell) * TILE
		var hint_color := Color(0.1, 0.55, 0.62, 0.64)
		for corner: Vector2 in [Vector2(6, 6), Vector2(58, 6), Vector2(58, 58), Vector2(6, 58)]:
			var sign_x := 1.0 if corner.x < 32 else -1.0
			var sign_y := 1.0 if corner.y < 32 else -1.0
			var mark := Line2D.new()
			mark.points = PackedVector2Array([origin + corner + Vector2(0, sign_y * 7), origin + corner, origin + corner + Vector2(sign_x * 7, 0)])
			mark.width = 1.25
			mark.default_color = hint_color
			telegraphs.add_child(mark)
	for enemy: Dictionary in _run.get("enemies", []):
		var x := int(enemy["x"])
		var y := int(enemy["y"])
		if not _visible.has(_key(x, y)) or not enemy.get("intent") is Dictionary or (enemy["intent"] as Dictionary).is_empty():
			continue
		var intent: Dictionary = enemy["intent"]
		var delta := Vector2i(int(intent.get("dx", 0)), int(intent.get("dy", 0)))
		if delta == Vector2i.ZERO:
			continue
		for distance in range(1, 4):
			var target := Vector2i(x, y) + delta * distance
			if not _in_bounds(target.x, target.y) or _tile_type(target.x, target.y) in ["wall", "water"]:
				break
			if not _visible.has(_key(target.x, target.y)):
				continue
			var panel := Polygon2D.new()
			panel.position = Vector2(target) * TILE
			panel.polygon = _rect_polygon(Vector2(5, 5), Vector2(TILE - 10, TILE - 10))
			panel.color = Color(0.98, 0.42, 0.32, 0.28)
			telegraphs.add_child(panel)
			var c := _cell_position(target.x, target.y)
			var direction := Vector2(delta)
			var side := direction.orthogonal() * 9
			var tip := c + direction * 11
			var arrow := Line2D.new()
			arrow.points = PackedVector2Array([c - direction * 7 + side, tip, c - direction * 7 - side])
			arrow.width = 3
			arrow.default_color = Color("c45544")
			arrow.antialiased = true
			telegraphs.add_child(arrow)

func _play_events(events: Array) -> void:
	effects.reduced_motion = _reduce
	var player: Dictionary = _run["player"]
	var player_point := _cell_position(int(player["x"]), int(player["y"]))
	for event: Dictionary in events:
		var kind := str(event.get("type", ""))
		var actor_id := str(event.get("actorId", "player"))
		var actor: Node2D = _actor_nodes.get(actor_id)
		var player_actor: Node2D = _actor_nodes.get("player")
		var point := _cell_position(int(event.get("x", player["x"])), int(event.get("y", player["y"])))
		match kind:
			"attack":
				if player_actor != null:
					player_actor.face(point - player_point)
					player_actor.play_reaction("attack")
				if actor != null and actor.visible:
					effects.schedule(0.13, actor.play_reaction.bind("hurt"))
				if _visible.has(_key(int(event.get("x", player["x"])), int(event.get("y", player["y"])))):
					effects.strike(player_point.lerp(point, 0.55), (point - player_point).normalized())
					if event.has("amount"):
						effects.number("−%s" % event["amount"], point + Vector2(0, -61), Color("a35a27"))
			"hurt":
				if player_actor != null:
					effects.schedule(0.2 if actor != null and actor.kind == "diver" else 0.12, player_actor.play_reaction.bind("hurt"))
				if actor != null and actor != player_actor and actor.visible:
					actor.face(player_point - actor.position)
					actor.play_reaction("attack")
					effects.strike(player_point, (player_point - actor.position).normalized(), actor.kind == "diver")
				else:
					effects.impact(player_point, Color("f18a72"), 5)
				if event.has("amount"):
					effects.number("−%s" % event["amount"], player_point + Vector2(0, -64), Color("cc5a42"))
			"loot":
				if event.has("amount") and int(event["amount"]) > 0:
					effects.loot(point, int(event["amount"]), str(event.get("text", "")).contains("集光芯"))
				else:
					effects.impact(point + Vector2(0, 15), Color("b7d8be"), 3)
				var crate: Node2D = _crate_nodes.get(_key(int(event.get("x", player["x"])), int(event.get("y", player["y"]))))
				if crate != null and not _reduce:
					var bounce := crate.create_tween()
					bounce.tween_property(crate, "position:y", crate.position.y - 11, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					bounce.tween_property(crate, "position:y", crate.position.y, 0.17).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			"use":
				effects.impact(point, Color("76c6a1"), 10)
			"kill":
				if _visible.has(_key(int(event.get("x", -1)), int(event.get("y", -1)))):
					effects.impact(point, Color("59b8b0"), 12)
			"tide":
				if _last_tide >= 0:
					effects.wave(player_point)

func _add_rope(at: Vector2) -> void:
	var coil := Line2D.new()
	for i in 55:
		var phase := float(i) / 54.0
		var angle := phase * TAU * 2.6
		var radius := 2.0 + phase * 9.0
		coil.add_point(Vector2(cos(angle) * radius, sin(angle) * radius * 0.55))
	coil.position = at
	coil.width = 2.2
	coil.default_color = Color(0.72, 0.54, 0.3, 0.85)
	coil.antialiased = true
	details.add_child(coil)

func _add_bollard(at: Vector2) -> void:
	var shadow := Polygon2D.new()
	shadow.position = at + Vector2(3, 4)
	shadow.polygon = _rect_polygon(Vector2(-7, -3), Vector2(18, 8))
	shadow.color = Color(0.02, 0.05, 0.06, 0.6)
	details.add_child(shadow)
	_line(details, at, at + Vector2(0, -13), Color("438b93"), 9)
	_line(details, at + Vector2(-7, -12), at + Vector2(7, -12), Color("b9d6c1"), 4)
	_line(details, at + Vector2(-5, -10), at + Vector2(5, -10), Color("b7a573"), 1.3)

func _add_exit(x: int, y: int) -> void:
	var center := _cell_position(x, y)
	var badge := Polygon2D.new()
	badge.position = center + Vector2(0, 14)
	badge.polygon = PackedVector2Array([Vector2(-25, -19), Vector2(25, -19), Vector2(28, 3), Vector2(0, 17), Vector2(-28, 3)])
	badge.color = Color(1.0, 0.85, 0.4, 0.45)
	details.add_child(badge)
	var edge := Line2D.new()
	edge.position = badge.position
	edge.points = PackedVector2Array([Vector2(-25, -19), Vector2(25, -19), Vector2(28, 3), Vector2(0, 17), Vector2(-28, 3), Vector2(-25, -19)])
	edge.width = 2.5
	edge.default_color = Color("fff2b9")
	details.add_child(edge)
	_line(details, center + Vector2(-25, 8), center + Vector2(-25, -23), Color("4b8990"), 4)
	var flag := Polygon2D.new()
	flag.position = center + Vector2(-25, -24)
	flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(17, 3), Vector2(11, 8), Vector2(0, 7)])
	flag.color = Color("f29a72")
	details.add_child(flag)

func _add_prop(kind: String, at: Vector2, target_size: Vector2, opacity: float) -> Sprite2D:
	var texture := _texture(kind)
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	var factor := minf(target_size.x / texture.get_width(), target_size.y / texture.get_height())
	sprite.scale = Vector2.ONE * factor
	sprite.modulate = Color(1, 1, 1, opacity)
	details.add_child(sprite)
	return sprite

func _texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	for root: String in [R2_ROOT, ART_ROOT]:
		for filename: String in [kind + ".tres", kind + ".png", "prop-" + kind + ".png", "enemy-" + kind + ".png"]:
			var path := root + filename
			if ResourceLoader.exists(path):
				var texture := load(path) as Texture2D
				if texture != null:
					_textures[kind] = texture
					return texture
	# Portraits are retained only while field art is being imported during production.
	if kind.begins_with("crew_"):
		return _texture(kind.trim_prefix("crew_"))
	return null

func _compute_visibility(run: Dictionary) -> Dictionary:
	return RuleData.visible_tiles(run)

func _is_flooded(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	return _tile_type(x, y) == "water" or WorldDataFile.is_flooded(_run, x, y)

func _tile_type(x: int, y: int) -> String:
	if not _in_bounds(x, y):
		return "water"
	return str(_run["tiles"][y][x].get("type", "floor"))

func _in_bounds(x: int, y: int) -> bool:
	var tiles: Array = _run.get("tiles", [])
	return y >= 0 and y < tiles.size() and x >= 0 and x < (tiles[y] as Array).size()

func _cell_position(x: int, y: int) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE

func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _rect_polygon(at: Vector2, rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(rect_size.x, 0), at + rect_size, at + Vector2(0, rect_size.y)])

func _line(parent: Node, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.default_color = color
	line.width = width
	parent.add_child(line)

func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
