extends SceneTree
## Retained painted-puppet geometry, source alpha, and native render evidence.
## The legacy file name stays in the test runner; source art has one frame.

const Actors := preload("res://scripts/pixel_actors.gd")
const STATES := ["idle", "walk", "cast", "hit", "warning", "rush", "recover", "arrival", "death"]
const EVIDENCE := {
	"witch_feet": ["witch", "walk", 1, 4, Rect2(0.36, 0.73, 0.34, 0.25)],
	"witch_book_arm": ["witch", "cast", 0, 1, Rect2(0.62, 0.26, 0.36, 0.40)],
	"hound_paws": ["hound", "walk", 1, 4, Rect2(0.47, 0.57, 0.51, 0.40)],
	"charger_hooves": ["charger", "walk", 1, 4, Rect2(0.27, 0.61, 0.58, 0.37)],
	"archer_draw_hand": ["archer", "warning", 0, 3, Rect2(0.45, 0.27, 0.35, 0.29)],
	"bat_wings": ["bat", "walk", 0, 1, Rect2(0.02, 0.17, 0.96, 0.57)],
	"sentinel_shield": ["sentinel", "warning", 0, 3, Rect2(0.45, 0.24, 0.52, 0.53)],
	"wisp_flame": ["wisp", "cast", 0, 1, Rect2(0.18, 0.04, 0.62, 0.52)],
	"thorn_branches": ["boss_thorn", "warning", 0, 3, Rect2(0.02, 0.25, 0.96, 0.64)],
	"mirror_shield": ["boss_mirror", "cast", 0, 1, Rect2(0.55, 0.16, 0.44, 0.58)],
	"bell_clapper": ["boss_bell", "idle", 0, 2, Rect2(0.37, 0.43, 0.28, 0.35)],
}

static func pose_at(animation: String, frame: int) -> Dictionary:
	return {"animation": animation, "time": (frame + 0.01) / float(Actors.ANIMATIONS[animation].fps)}

class Sheet:
	extends Node2D
	var actors
	var mode := 0
	var clock := 0.0
	var samples := 0
	var sample_kind := "witch"
	var sample_animation := "walk"
	var first_frame := 1
	var second_frame := 4
	func _sample_pose(animation: String, frame: int) -> Dictionary:
		return {"animation": animation, "time": (frame + 0.01) / float(Actors.ANIMATIONS[animation].fps)}
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 1160)), Color("101b25"))
		var font := ThemeDB.fallback_font
		if mode == 0:
			for column in range(STATES.size()):
				draw_string(font, Vector2(136 + column * 124, 29), STATES[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dbc182"))
			for row in range(Actors.KINDS.size()):
				var kind: String = Actors.KINDS[row]
				var y := 42 + row * 109
				draw_string(font, Vector2(8, y + 57), kind.trim_prefix("boss_"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f5efdf"))
				for column in range(STATES.size()):
					var x := 174.0 + column * 124
					draw_rect(Rect2(x - 51, y, 102, 104), Color("172533"))
					draw_line(Vector2(x - 35, y + 94), Vector2(x + 35, y + 94), Color("344954"))
					actors.draw_actor(self, Vector2(x, y + 94), kind, 96 if kind.begins_with("boss_") else 94,
						{"animation": STATES[column], "time": 0.19, "gait": 0.32, "cast": 0.36, "phase_progress": 0.68}, Color.WHITE)
		elif mode == 1:
			var index := 0
			for animation in Actors.ANIMATIONS:
				var count: int = Actors.ANIMATIONS[animation].count
				for frame in range(count):
					var x := 64.0 + (index % 12) * 104
					var y := 44.0 + int(index / 12) * 210
					draw_string(font, Vector2(x - 48, y), "%s pose %d" % [animation, frame], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbc182"))
					actors.draw_actor(self, Vector2(x, y + 169), "witch", 156, _sample_pose(animation, frame), Color.WHITE)
					index += 1
			for row in range(2):
				for column in range(6):
					var kind: String = Actors.KINDS[1 + column]
					var x := 106.0 + column * 212
					var y := 720.0 + row * 210
					draw_string(font, Vector2(x - 82, y), kind + (" warning" if row == 0 else " cast"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbc182"))
					actors.draw_actor(self, Vector2(x, y + 175), kind, 176, {"animation": "warning" if row == 0 else "cast", "time": 0.19, "phase_progress": 0.99, "cast": 0.36}, Color.WHITE)
		elif mode == 2:
			# The marker also verifies that draw_actor preserves the host transform.
			draw_set_transform(Vector2(90, 90))
			for i in range(80):
				var kind: String = Actors.KINDS[i % Actors.KINDS.size()]
				var animation := "walk" if i % 3 == 0 else "cast" if i % 3 == 1 else "warning"
				actors.draw_actor(self, Vector2((i % 16) * 72, int(i / 16) * 100 + 80), kind, 64,
					{"animation": animation, "time": clock, "gait": clock * 1.6, "facing": -1 if i % 2 else 1}, Color.WHITE, i % 5 == 0)
			actors.draw_actor(self, Vector2.ZERO, "witch", NAN, {}, Color.WHITE)
			actors.draw_actor(self, Vector2(INF, 0), "witch", 64, {}, Color.WHITE)
			actors.draw_actor(self, Vector2.ZERO, "witch", 64, {}, Color(NAN, 1, 1, 1))
			draw_rect(Rect2(2, 2, 5, 5), Color.MAGENTA)
			draw_set_transform(Vector2.ZERO)
			samples += 1
		elif mode == 3:
			actors.draw_actor(self, Vector2(300, 400), sample_kind, 320, _sample_pose(sample_animation, first_frame), Color.WHITE)
			actors.draw_actor(self, Vector2(800, 400), sample_kind, 320, _sample_pose(sample_animation, second_frame), Color.WHITE)
		elif mode == 4:
			actors.draw_actor(self, Vector2(300, 400), "witch", 256, {"facing": 1}, Color.WHITE)
			actors.draw_actor(self, Vector2(800, 400), "witch", 256, {"facing": -1}, Color.WHITE)

var actors
var checks := 0
var failures := 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func pixels_different(a: Image, b: Image, area: Rect2i, tolerance: float = 0.005) -> int:
	var different := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a) > tolerance:
				different += 1
	return different

func alpha_sum(colors: PackedColorArray) -> float:
	var result := 0.0
	for color in colors:
		result += color.a
	return result

func maximum_part_motion(kind: String, animation: String, first: int, second: int, region: Rect2) -> float:
	var before: Dictionary = actors.pose_geometry(kind, pose_at(animation, first))
	var after: Dictionary = actors.pose_geometry(kind, pose_at(animation, second))
	var maximum := 0.0
	for row in range(Actors.GRID_ROWS + 1):
		for column in range(Actors.GRID_COLUMNS + 1):
			var normalized := Vector2(float(column) / Actors.GRID_COLUMNS, float(row) / Actors.GRID_ROWS)
			if region.has_point(normalized):
				var index := row * (Actors.GRID_COLUMNS + 1) + column
				maximum = maxf(maximum, (before.vertices[index] as Vector3).distance_to(after.vertices[index]))
	return maximum

func native_part_area(kind: String, normalized: Rect2) -> Rect2i:
	var info: Dictionary = actors.frame_info(kind)
	var region: Rect2 = info.region
	var aspect := region.size / maxf(region.size.x, region.size.y)
	var anchor: Vector2 = Actors.BODY_ANCHORS[kind]
	var corner := Vector2(300, 400) + (normalized.position - anchor) * aspect * 320.0
	var extent := normalized.size * aspect * 320.0
	return Rect2i(Vector2i(floorf(corner.x), floorf(corner.y)), Vector2i(ceilf(extent.x), ceilf(extent.y)))

func settle() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _run() -> void:
	actors = Actors.new()
	var ids: Dictionary = actors.diagnostics()
	expect(ids.art_mode == "painted_regional_mesh" and ids.source_frames_per_actor == 1, "diagnostics distinguish one painted source from logical mesh poses")
	expect(ids.mesh_pose_count == 360 and ids.region_count == 10, "ten source regions retain 360 bounded mesh poses")
	var unique_sources: Dictionary = {}
	var source_pixels := 0
	for kind in Actors.KINDS:
		var base: Dictionary = actors.frame_info(kind)
		var source: Texture2D = Actors.SOURCES[kind]
		var source_region: Rect2 = base.region
		expect(maxf(source_region.size.x, source_region.size.y) >= Actors.display_size(kind) * 4.0, kind + " retains at least four source pixels per displayed pixel")
		if not unique_sources.has(source.get_instance_id()):
			unique_sources[source.get_instance_id()] = true
			source_pixels += source.get_width() * source.get_height()
		var image := source.get_image()
		expect(image.has_mipmaps(), kind + " painted source supplies mipmaps for minification")
		expect(source.get_width() > 400 and source.get_height() > 400 and source.get_width() <= 4096 and source.get_height() <= 4096, kind + " uses a bounded detailed source illustration")
		expect(image.detect_alpha() != Image.ALPHA_NONE and image.get_used_rect().has_area(), kind + " source has actual alpha and visible artwork")
		expect(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(image.get_width() - 1, 0).a < 0.01, kind + " source corners are transparent")
		expect(Rect2(Vector2.ZERO, source.get_size()).encloses(base.region), kind + " source region lies inside its original texture")
		var bottom: PackedVector3Array = actors.pose_geometry(kind).vertices
		for animation in Actors.ANIMATIONS:
			var track: Dictionary = Actors.ANIMATIONS[animation]
			for frame in range(int(track.count)):
				var pose := pose_at(animation, frame)
				var info: Dictionary = actors.frame_info(kind, pose)
				var geometry: Dictionary = actors.pose_geometry(kind, pose)
				var vertices: PackedVector3Array = geometry.vertices
				var uvs: PackedVector2Array = geometry.uvs
				var colors: PackedColorArray = geometry.colors
				var indices: PackedInt32Array = geometry.indices
				expect(info.region == base.region and info.source_frame == 0, kind + " poses reuse a single honest source region")
				expect(vertices.size() == 323 and uvs.size() == 323 and colors.size() == 323 and indices.size() == 1728, kind + " retained mesh topology stays fixed")
				var finite := true
				var uv_inside := true
				var ground_fixed := true
				var triangle_valid := true
				var texture_region := Rect2((info.region as Rect2).position / source.get_size(), (info.region as Rect2).size / source.get_size()).grow(0.00001)
				for index in range(vertices.size()):
					finite = finite and vertices[index].is_finite() and absf(vertices[index].x) < float(info.cell) * 2.0 and absf(vertices[index].y) < float(info.cell) * 2.0
					uv_inside = uv_inside and uvs[index].is_finite() and texture_region.has_point(uvs[index])
					if index >= Actors.GRID_ROWS * (Actors.GRID_COLUMNS + 1):
						ground_fixed = ground_fixed and vertices[index].is_equal_approx(bottom[index])
				for index in range(0, indices.size(), 3):
					var a := vertices[indices[index]]
					var b := vertices[indices[index + 1]]
					var c := vertices[indices[index + 2]]
					triangle_valid = triangle_valid and Vector2(b.x - a.x, b.y - a.y).cross(Vector2(c.x - a.x, c.y - a.y)) > 0.0001
				expect(finite and uv_inside, kind + " mesh positions are finite and UVs stay in source bounds")
				expect(ground_fixed and info.anchor == base.anchor, kind + " mesh poses preserve their ground anchor")
				expect(triangle_valid, "%s %s %d never folds its illustration mesh" % [kind, animation, frame])
			var still_a: Dictionary = actors.frame_info(kind, {"animation": animation, "time": 0.01, "gait": 0.0, "cast": 1.0, "phase_progress": 0.0}, true)
			var still_b: Dictionary = actors.frame_info(kind, {"animation": animation, "time": 19.8, "gait": 0.9, "cast": 0.0, "phase_progress": 1.0}, true)
			if animation != "death":
				expect(still_a.mesh_id == still_b.mesh_id, kind + " reduced motion holds the same retained action pose")
		var previous := INF
		for frame in range(5):
			var geometry: Dictionary = actors.pose_geometry(kind, pose_at("death", frame))
			var opacity := alpha_sum(geometry.colors)
			expect(opacity < previous, kind + " retained death colors dissolve monotonically")
			previous = opacity
		expect(previous == 0.0 and not actors.frame_info(kind, {"animation": "death", "phase_progress": 1.0}).visible, kind + " death reaches fully invisible terminal pose")
		for invalid in [{"time": INF}, {"time": NAN}, {"time": 1e30}, {"gait": -44.8, "animation": "walk"}, {"animation": "unknown", "time": "bad"}, {"animation": "cast", "cast": INF}, {"animation": "warning", "phase_progress": NAN}]:
			var safe: Dictionary = actors.frame_info(kind, invalid)
			expect(safe.index >= 0 and safe.index < Actors.FRAME_COUNT, kind + " malformed pose input stays bounded")
		var fixed_pose := {"animation": "walk", "time": 7.2, "gait": 0.31}
		expect(actors.frame_info(kind, fixed_pose) == actors.frame_info(kind, fixed_pose), kind + " unchanged game clock and gait keep exactly the same pose")
		expect(actors.frame_info(kind, {"animation": "walk", "time": 1.0, "gait": 0.31}).mesh_id == actors.frame_info(kind, {"animation": "walk", "time": 100.0, "gait": 0.31}).mesh_id, kind + " walked distance controls gait independently of wall time")
	expect(ids.source_count == unique_sources.size() and ids.texture_ids.size() == unique_sources.size(), "one retained CanvasTexture per unique original source")
	expect(source_pixels < 32000000, "painted source textures stay within the explicit 32-megapixel budget")
	expect(actors.frame_info("unknown").kind == "hound", "unknown actor kind has the established safe fallback")
	expect(Actors.display_size("unknown") == Actors.display_size("hound"), "unknown actor keeps its fallback artwork at the same display size")
	var geometry_evidence: Dictionary = {}
	for label in EVIDENCE:
		var entry: Array = EVIDENCE[label]
		var difference := maximum_part_motion(entry[0], entry[1], entry[2], entry[3], entry[4])
		geometry_evidence[label] = difference
		expect(difference > 0.45, label + " has substantial localized retained-mesh movement")
	var sheet := Sheet.new()
	sheet.actors = actors
	root.add_child(sheet)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 1160)
	await settle()
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("/private/tmp/echo-painted-actors-contact.png")
		sheet.mode = 1
		sheet.queue_redraw()
		await settle()
		root.get_texture().get_image().save_png("/private/tmp/echo-painted-actors-motion.png")
	sheet.mode = 2
	for frame in range(180):
		sheet.clock = frame / 60.0
		sheet.queue_redraw()
		await settle()
	expect(actors.diagnostics() == ids, "180 crowd redraws reuse the exact textures and pose meshes")
	var native_evidence: Dictionary = {}
	if DisplayServer.get_name() != "headless":
		var drawn := root.get_texture().get_image()
		expect(drawn.get_pixel(94, 94).is_equal_approx(Color.MAGENTA), "draw_actor preserves the caller draw transform")
		drawn.save_png("/private/tmp/echo-painted-actors-lifetime.png")
		sheet.mode = 3
		for label in EVIDENCE:
			var entry: Array = EVIDENCE[label]
			sheet.sample_kind = entry[0]
			sheet.sample_animation = entry[1]
			sheet.first_frame = entry[2]
			sheet.second_frame = entry[3]
			sheet.queue_redraw()
			await settle()
			var rendered := root.get_texture().get_image()
			var area := native_part_area(entry[0], entry[4])
			var before := rendered.get_region(area)
			var after := rendered.get_region(Rect2i(area.position + Vector2i(500, 0), area.size))
			var difference := pixels_different(before, after, Rect2i(Vector2i.ZERO, area.size))
			native_evidence[label] = difference
			expect(difference > 50, label + " changes actual imported illustration pixels in native drawing")
			if label == "witch_book_arm" or label == "bat_wings" or label == "thorn_branches":
				rendered.save_png("/private/tmp/echo-painted-actor-" + label + ".png")
		sheet.mode = 4
		sheet.queue_redraw()
		await settle()
		var pair := root.get_texture().get_image()
		var right := pair.get_region(Rect2i(40, 40, 520, 520))
		var left := pair.get_region(Rect2i(540, 40, 520, 520))
		left.flip_x()
		expect(pixels_different(right, left, Rect2i(0, 0, 520, 520), 0.02) < 100, "left-facing painted mesh mirrors around the same world foot anchor")
		pair.save_png("/private/tmp/echo-painted-actors-facing.png")
	print("PIXEL_ACTORS " + JSON.stringify({"art_mode": ids.art_mode, "checks": checks, "failures": failures, "renderer": DisplayServer.get_name(), "draw_execution_verified": DisplayServer.get_name() != "headless", "draw_notifications": sheet.samples, "native_draw_frames": sheet.samples if DisplayServer.get_name() != "headless" else 0, "resources_reused": actors.diagnostics() == ids, "regional_mesh_motion": geometry_evidence, "native_part_pixel_motion": native_evidence, "source_count": ids.source_count, "source_frames_per_actor": 1, "retained_pose_count_per_actor": 36, "source_pixels": source_pixels}))
	quit(1 if failures else 0)
