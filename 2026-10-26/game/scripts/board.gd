extends Control
## Layered Godot presentation for a resolved expedition. Owns no game rules.

signal cell_selected(x: int, y: int)

const ACTOR_SCENE := preload("res://scenes/actor.tscn")
const TILE := 64
const PATTERN_SPAN := 4
const ART_ROOT := "res://assets/art/"
const FONT_PATH := "res://assets/fonts/NotoSansCJKjp-Medium.otf"

@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $World/Ground
@onready var water: TileMapLayer = $World/Water
@onready var walls: TileMapLayer = $World/Walls
@onready var shore: Node2D = $World/Shore
@onready var depth: Node2D = $World/Depth
@onready var details: Node2D = $World/Details
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
	var pause_motion := _focus_paused or not is_visible_in_tree()
	world.process_mode = Node.PROCESS_MODE_DISABLED if pause_motion else Node.PROCESS_MODE_INHERIT
	(water.material as ShaderMaterial).set_shader_parameter("reduced_motion", _reduce or pause_motion)
	if _camera_tween != null and _camera_tween.is_valid():
		if pause_motion:
			_camera_tween.pause()
		else:
			_camera_tween.play()
	for child: Node in effects.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED if pause_motion else Node.PROCESS_MODE_INHERIT

func _on_gui_input(event: InputEvent) -> void:
	if _run.is_empty():
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
	var zoom_factor := clampf(size.x / (8.25 * TILE), 0.61, 1.08)
	# Keep enough route in view above the character while respecting the map edge.
	var center := Vector2(size.x * 0.5, size.y * 0.57)
	var destination := center - _cell_position(int(p["x"]), int(p["y"])) * zoom_factor
	var map_size := Vector2(int(_run.get("width", 25)), int(_run.get("height", 25))) * TILE * zoom_factor
	destination.x = clampf(destination.x, minf(16.0, size.x - map_size.x - 16.0), 16.0)
	destination.y = clampf(destination.y, minf(16.0, size.y - map_size.y - 16.0), 16.0)
	world.scale = Vector2.ONE * zoom_factor
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
	# One painted quadrant spans four cells in each direction. This preserves the
	# size of stones and planks beside a person instead of shrinking to noisy gravel.
	var patch_size := TILE * PATTERN_SPAN
	var atlas_image := Image.create(patch_size * 4, patch_size, false, Image.FORMAT_RGBA8)
	var atlas_texture := _texture("terrain-atlas")
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
	_actor_nodes.clear()
	_fog_cells.clear()
	ground.clear()
	water.clear()
	walls.clear()
	var tiles: Array = _run.get("tiles", [])
	for y in tiles.size():
		for x in (tiles[y] as Array).size():
			var cover := Polygon2D.new()
			cover.polygon = _rect_polygon(Vector2.ZERO, Vector2(TILE + 0.8, TILE + 0.8))
			cover.position = Vector2(x, y) * TILE
			fog.add_child(cover)
			_fog_cells[_key(x, y)] = cover
	_refresh_terrain()

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
			var dock := str(tile.get("zone", "")).contains("船") or str(tile.get("zone", "")) in ["harbor", "dock", "docks", "pier"] or raised
			ground.set_cell(Vector2i(x, y), 0, _atlas_coordinate(2 if dock else 0, x, y))
			if kind == "wall":
				walls.set_cell(Vector2i(x, y), 0, _atlas_coordinate(1, x, y))
				if _tile_type(x, y + 1) != "wall":
					var face := Polygon2D.new()
					face.position = Vector2(x, y + 1) * TILE
					face.polygon = _rect_polygon(Vector2(0, -11), Vector2(TILE, 16))
					face.color = Color("25363a")
					depth.add_child(face)
					_line(depth, Vector2(x * TILE, (y + 1) * TILE - 10), Vector2((x + 1) * TILE, (y + 1) * TILE - 10), Color("84908a"), 2.0)
			elif _is_flooded(x, y):
				water.set_cell(Vector2i(x, y), 0, _atlas_coordinate(3, x, y))
				for offset: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
					if _in_bounds(x + offset.x, y + offset.y) and not _is_flooded(x + offset.x, y + offset.y):
						var a := Vector2(x * TILE, y * TILE)
						var b := a
						if offset.y == -1:
							b += Vector2(TILE, 0)
						elif offset.y == 1:
							a += Vector2(0, TILE)
							b += Vector2(TILE, TILE)
						elif offset.x == -1:
							b += Vector2(0, TILE)
						else:
							a += Vector2(TILE, 0)
							b += Vector2(TILE, TILE)
						_line(shore, a, b, Color(0.48, 0.71, 0.69, 0.44), 2.2)
			elif raised:
				# Raised return walkways retain a warm edge above the water.
				_line(depth, Vector2(x * TILE + 2, y * TILE + TILE - 2), Vector2((x + 1) * TILE - 2, (y + 1) * TILE - 2), Color(0.69, 0.56, 0.36, 0.48), 2.0)

func _refresh_fog() -> void:
	for key: Variant in _fog_cells:
		var cover: Polygon2D = _fog_cells[key]
		if _visible.has(key):
			cover.visible = false
		else:
			cover.visible = true
			cover.color = Color(0.015, 0.045, 0.06, 0.72) if _seen.has(key) else Color(0.022, 0.063, 0.082, 1.0)

func _refresh_details() -> void:
	_clear_children(details)
	# Static scattered salvage is deterministic and only belongs to revealed cells.
	var tiles: Array = _run.get("tiles", [])
	for y in tiles.size():
		for x in (tiles[y] as Array).size():
			var key := _key(x, y)
			if not _visible.has(key):
				continue
			var tile: Dictionary = tiles[y][x]
			var kind := str(tile.get("type", "floor"))
			var variant := int(tile.get("variant", 0)) + x * 13 + y * 17
			if kind == "floor" and variant % 17 == 0 and not _is_flooded(x, y):
				_add_rope(_cell_position(x, y) + Vector2(17, 16))
			elif kind == "floor" and variant % 23 == 0 and not _is_flooded(x, y):
				_add_bollard(_cell_position(x, y) + Vector2(-19, 15))
	for container: Dictionary in _run.get("containers", []):
		var x := int(container["x"])
		var y := int(container["y"])
		if not _visible.has(_key(x, y)):
			continue
		var empty := bool(container.get("searched", false)) and (container.get("items", []) as Array).is_empty()
		var node := _add_prop("crate", _cell_position(x, y) + Vector2(0, 11), Vector2(40, 34), 0.48 if empty else 1.0)
		if node == null:
			var crate := Polygon2D.new()
			crate.position = _cell_position(x, y) + Vector2(0, 12)
			crate.polygon = PackedVector2Array([Vector2(-17, -16), Vector2(15, -19), Vector2(19, 10), Vector2(-15, 14)])
			crate.color = Color("75654a") if empty else Color("b38b50")
			details.add_child(crate)
		if not empty:
			var marker := Polygon2D.new()
			marker.position = _cell_position(x, y) + Vector2(0, -12)
			marker.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
			marker.color = Color("f5d18a")
			details.add_child(marker)
	var exit_cell: Dictionary = _run.get("exit", {})
	if not exit_cell.is_empty() and _seen.has(_key(int(exit_cell["x"]), int(exit_cell["y"]))):
		_add_exit(int(exit_cell["x"]), int(exit_cell["y"]))
	var goal: Dictionary = _run.get("goal", {})
	if not goal.is_empty() and _visible.has(_key(int(goal["x"]), int(goal["y"]))):
		_add_prop("lighthouse", _cell_position(int(goal["x"]), int(goal["y"])) + Vector2(0, -16), Vector2(77, 112), 1.0)

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
	actor.configure(_texture(kind), kind, player_actor, _reduce)
	actor.visible = show_actor
	var p := _cell_position(int(data["x"]), int(data["y"]))
	actor.move_to(p, fresh or immediate or not show_actor)
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
		var hint_color := Color(0.79, 0.85, 0.79, 0.34)
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
			panel.color = Color(0.95, 0.29, 0.17, 0.27)
			telegraphs.add_child(panel)
			var c := _cell_position(target.x, target.y)
			var direction := Vector2(delta)
			var side := direction.orthogonal() * 9
			var tip := c + direction * 11
			var arrow := Line2D.new()
			arrow.points = PackedVector2Array([c - direction * 7 + side, tip, c - direction * 7 - side])
			arrow.width = 3
			arrow.default_color = Color("f3a17b")
			arrow.antialiased = true
			telegraphs.add_child(arrow)

func _play_events(events: Array) -> void:
	for event: Dictionary in events:
		var kind := str(event.get("type", ""))
		var actor_id := str(event.get("actorId", "player"))
		var actor: Node2D = _actor_nodes.get(actor_id)
		match kind:
			"attack":
				var player_actor: Node2D = _actor_nodes.get("player")
				if player_actor != null:
					player_actor.play_reaction("attack")
				if actor != null and actor.visible:
					actor.play_reaction("hurt")
				if event.has("x") and event.has("y"):
					var point := _cell_position(int(event["x"]), int(event["y"]))
					_spark(point, Color("f3d0a1"), 5)
					if event.has("amount"):
						_float_text("−%s" % event["amount"], point + Vector2(0, -58), Color("f4d6a7"))
			"hurt":
				var player_actor: Node2D = _actor_nodes.get("player")
				if player_actor != null:
					player_actor.play_reaction("hurt")
				if actor != null and actor != player_actor and actor.visible:
					actor.play_reaction("attack")
				if event.has("amount"):
					var point := _cell_position(int(_run["player"]["x"]), int(_run["player"]["y"]))
					_float_text("−%s" % event["amount"], point + Vector2(0, -58), Color("ffb49b"))
			"loot":
				var p: Dictionary = _run["player"]
				_spark(_cell_position(int(p["x"]), int(p["y"])), Color("f1cf85"), 7)
			"use":
				var p: Dictionary = _run["player"]
				_spark(_cell_position(int(event.get("x", p["x"])), int(event.get("y", p["y"]))), Color("b4dbbb"), 9)
			"kill":
				if event.has("x") and event.has("y"):
					_spark(_cell_position(int(event["x"]), int(event["y"])), Color("9dcbc0"), 9)
			"tide":
				if _last_tide >= 0:
					var p: Dictionary = _run["player"]
					_ripple(_cell_position(int(p["x"]), int(p["y"])))

func _spark(at: Vector2, color: Color, count: int) -> void:
	if _reduce:
		return
	for i in count:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(0, -3), Vector2(2, 0), Vector2(0, 3), Vector2(-2, 0)])
		particle.color = color
		particle.position = at + Vector2(0, -15)
		effects.add_child(particle)
		var direction := Vector2.from_angle(float(i) / count * TAU - PI * 0.5)
		var tween := particle.create_tween().set_parallel(true)
		tween.tween_property(particle, "position", particle.position + direction * (22 + i % 3 * 9), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.32)
		tween.chain().tween_callback(particle.queue_free)

func _ripple(at: Vector2) -> void:
	if _reduce:
		return
	var ripple := Line2D.new()
	for i in 33:
		var angle := float(i) / 32.0 * TAU
		ripple.add_point(Vector2(cos(angle), sin(angle) * 0.5) * 24)
	ripple.position = at
	ripple.width = 2.0
	ripple.default_color = Color(0.68, 0.86, 0.84, 0.7)
	effects.add_child(ripple)
	var tween := ripple.create_tween().set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2.ONE * 4, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(ripple.queue_free)

func _float_text(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at - Vector2(32, 0)
	label.size = Vector2(64, 25)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("11252c"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	effects.add_child(label)
	var tween := label.create_tween()
	if not _reduce:
		tween.tween_property(label, "position:y", at.y - 25, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_interval(0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)

func _add_rope(at: Vector2) -> void:
	var coil := Line2D.new()
	for i in 55:
		var phase := float(i) / 54.0
		var angle := phase * TAU * 2.6
		var radius := 2.0 + phase * 9.0
		coil.add_point(Vector2(cos(angle) * radius, sin(angle) * radius * 0.55))
	coil.position = at
	coil.width = 2.2
	coil.default_color = Color(0.66, 0.56, 0.37, 0.7)
	coil.antialiased = true
	details.add_child(coil)

func _add_bollard(at: Vector2) -> void:
	var shadow := Polygon2D.new()
	shadow.position = at + Vector2(3, 4)
	shadow.polygon = _rect_polygon(Vector2(-7, -3), Vector2(18, 8))
	shadow.color = Color(0.02, 0.05, 0.06, 0.6)
	details.add_child(shadow)
	_line(details, at, at + Vector2(0, -13), Color("243e44"), 9)
	_line(details, at + Vector2(-7, -12), at + Vector2(7, -12), Color("71817b"), 4)
	_line(details, at + Vector2(-5, -10), at + Vector2(5, -10), Color("b7a573"), 1.3)

func _add_exit(x: int, y: int) -> void:
	var center := _cell_position(x, y)
	var glow := Sprite2D.new()
	glow.texture = _light_texture
	glow.position = center + Vector2(0, -9)
	glow.scale = Vector2(1.5, 1.0)
	glow.modulate = Color(1, 0.84, 0.51, 0.78)
	details.add_child(glow)
	var lamp := _add_prop("lamp", center + Vector2(-20, -7), Vector2(29, 55), 1.0)
	if lamp == null:
		_line(details, center + Vector2(-20, 22), center + Vector2(-20, -25), Color("25383a"), 6)
		var lantern := Polygon2D.new()
		lantern.position = center + Vector2(-20, -26)
		lantern.polygon = _rect_polygon(Vector2(-6, -9), Vector2(12, 18))
		lantern.color = Color("f4cc7f")
		details.add_child(lantern)
	var edge := Line2D.new()
	edge.position = center
	edge.points = PackedVector2Array([Vector2(-24, -22), Vector2(24, -22), Vector2(24, 23), Vector2(-24, 23), Vector2(-24, -22)])
	edge.width = 2
	edge.default_color = Color(0.93, 0.75, 0.43, 0.76)
	details.add_child(edge)
	var light := PointLight2D.new()
	light.texture = _light_texture
	light.position = center + Vector2(-20, -28)
	light.texture_scale = 1.5
	light.color = Color("ffd494")
	light.energy = 0.32
	details.add_child(light)

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
	for filename: String in [kind + ".tres", kind + ".png", "prop-" + kind + ".png", "enemy-" + kind + ".png"]:
		var path := ART_ROOT + filename
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			_textures[kind] = texture
			return texture
	return null

func _compute_visibility(run: Dictionary) -> Dictionary:
	# Use the rule module when available; the fallback is for isolated scene previews.
	var rule_path := "res://scripts/rules.gd"
	if ResourceLoader.exists(rule_path):
		var rules = load(rule_path)
		if rules != null and rules.has_method("visible_tiles"):
			var result = rules.visible_tiles(run)
			if result is Dictionary:
				return result
	var visible: Dictionary = {}
	var player: Dictionary = run["player"]
	var radius := int(run.get("sight", 6))
	for y in range(maxi(0, int(player["y"]) - radius), mini(int(run.get("height", 25)), int(player["y"]) + radius + 1)):
		for x in range(maxi(0, int(player["x"]) - radius), mini(int(run.get("width", 25)), int(player["x"]) + radius + 1)):
			if Vector2(x - int(player["x"]), y - int(player["y"])).length() <= radius:
				visible[_key(x, y)] = true
	return visible

func _is_flooded(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	var tile: Dictionary = _run["tiles"][y][x]
	var kind := str(tile.get("type", "floor"))
	if kind == "water":
		return true
	return kind not in ["wall", "gate", "exit"] and int(_run.get("tide", 0)) >= int(tile.get("elevation", 1))

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
