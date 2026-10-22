extends SceneTree
## Image-space motion evidence and resource lifetime checks for original sprites.

const Actors := preload("res://scripts/pixel_actors.gd")

class Sheet:
	extends Node2D
	var actors
	var mode := 0
	var clock := 0.0
	var samples := 0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 1160)), Color("101b25"))
		var font := ThemeDB.fallback_font
		if mode == 0:
			var states := ["idle", "walk", "cast", "hit", "warning", "rush", "recover", "arrival", "death"]
			for column in range(states.size()):
				draw_string(font, Vector2(136 + column * 124, 29), states[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dbc182"))
			for row in range(Actors.KINDS.size()):
				var kind: String = Actors.KINDS[row]
				var y := 42 + row * 109
				draw_string(font, Vector2(8, y + 57), kind.trim_prefix("boss_"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f5efdf"))
				for column in range(states.size()):
					var x := 174.0 + column * 124
					draw_rect(Rect2(x - 51, y, 102, 104), Color("172533"))
					draw_line(Vector2(x - 35, y + 94), Vector2(x + 35, y + 94), Color("344954"))
					actors.draw_actor(self, Vector2(x, y + 94), kind, 96 if kind.begins_with("boss_") else 94,
						{"animation": states[column], "time": 0.19, "gait": 0.32, "cast": 0.36, "phase_progress": 0.68}, Color.WHITE)
		elif mode == 1:
			var index := 0
			for animation in Actors.ANIMATIONS:
				var count: int = Actors.ANIMATIONS[animation].count
				for frame in range(count):
					var x := 64.0 + (index % 12) * 104
					var y := 44.0 + int(index / 12) * 210
					var pose := {"animation": animation, "time": float(frame) / float(Actors.ANIMATIONS[animation].fps) + 0.002}
					draw_string(font, Vector2(x - 48, y), "%s %d" % [animation, frame], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbc182"))
					actors.draw_actor(self, Vector2(x, y + 169), "witch", 156, pose, Color.WHITE)
					index += 1
			# Props from the six enemy silhouettes are large enough to inspect here.
			for row in range(2):
				for column in range(6):
					var kind: String = Actors.KINDS[1 + column]
					var x := 106.0 + column * 212
					var y := 720.0 + row * 210
					draw_string(font, Vector2(x - 82, y), kind + (" warning" if row == 0 else " cast"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbc182"))
					actors.draw_actor(self, Vector2(x, y + 175), kind, 176, {"animation": "warning" if row == 0 else "cast", "time": 0.19, "phase_progress": 0.99, "cast": 0.36}, Color.WHITE)
		elif mode == 2:
			# Draw into an inherited transform, then draw a marker. Any renderer
			# that resets the host draw transform moves the marker to the wrong pixel.
			draw_set_transform(Vector2(90, 90))
			for i in range(80):
				var kind: String = Actors.KINDS[i % Actors.KINDS.size()]
				var animation := "walk" if i % 3 == 0 else "cast" if i % 3 == 1 else "warning"
				actors.draw_actor(self, Vector2((i % 16) * 72, int(i / 16) * 100 + 80), kind, 64,
					{"animation": animation, "time": clock, "gait": clock * 1.6, "facing": -1 if i % 2 else 1}, Color.WHITE, i % 5 == 0)
			draw_rect(Rect2(2, 2, 5, 5), Color.MAGENTA)
			draw_set_transform(Vector2.ZERO)
			samples += 1
		else:
			# A native, pixel-exact pair proves signed texture rectangles flip in
			# place instead of displacing a left-facing actor by its full width.
			actors.draw_actor(self, Vector2(96, 100), "witch", 64, {"facing": 1}, Color.WHITE)
			actors.draw_actor(self, Vector2(224, 100), "witch", 64, {"facing": -1}, Color.WHITE)

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

func pixels_different(a: Image, b: Image, area: Rect2i) -> int:
	var different := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				different += 1
	return different

func opaque_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count

func frame_image(kind: String, animation: String, local_frame: int) -> Image:
	var track: Dictionary = Actors.ANIMATIONS[animation]
	var pose := {"animation": animation, "time": (local_frame + 0.01) / float(track.fps)}
	var info: Dictionary = actors.frame_info(kind, pose)
	return (Actors.SOURCES[kind] as Texture2D).get_image().get_region(Rect2i(info.region))

func settle() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _run() -> void:
	actors = Actors.new()
	var ids: Dictionary = actors.diagnostics()
	expect(ids.atlas_count == 10 and ids.region_count == 360, "ten retained atlases and 360 source regions")
	for kind in Actors.KINDS:
		var info: Dictionary = actors.frame_info(kind)
		var source: Texture2D = Actors.SOURCES[kind]
		var image := source.get_image()
		expect(source.get_width() == info.cell * 8 and source.get_height() == info.cell * 5, kind + " fixed atlas dimensions")
		expect(source.get_width() <= 768 and source.get_height() <= 480, kind + " texture budget")
		var current: Array[Rect2] = []
		for animation in Actors.ANIMATIONS:
			var track: Dictionary = Actors.ANIMATIONS[animation]
			for frame in range(int(track.count)):
				var frame_info: Dictionary = actors.frame_info(kind, {"animation": animation, "time": (frame + 0.01) / float(track.fps)})
				var region: Rect2 = frame_info.region
				expect(Rect2(Vector2.ZERO, source.get_size()).encloses(region), kind + " frame lies inside atlas")
				for prior in current:
					expect(not prior.intersects(region), kind + " frames do not overlap")
				current.append(region)
				var tile := image.get_region(Rect2i(region))
				expect(tile.get_pixel(0, 0).a < 0.01 and tile.get_pixel(info.cell - 1, 0).a < 0.01, kind + " transparent corners")
				if animation == "death" and frame == 4:
					expect(opaque_count(tile) == 0, kind + " death ends in genuinely transparent frame")
				else:
					expect(opaque_count(tile) > (8 if animation == "death" else 100), "%s %s %d contains visible original artwork" % [kind, animation, frame])
		var death: Array[int] = []
		for frame in range(5):
			death.append(opaque_count(frame_image(kind, "death", frame)))
		expect(death[0] > death[1] and death[1] > death[2] and death[2] > death[3] and death[3] > death[4], kind + " death pieces dissolve monotonically")
		for animation in Actors.ANIMATIONS:
			var still_a: Dictionary = actors.frame_info(kind, {"animation": animation, "time": 0.01}, true)
			var still_b: Dictionary = actors.frame_info(kind, {"animation": animation, "time": 19.8}, true)
			if animation != "death":
				expect(still_a.index == still_b.index, kind + " reduced-motion pose stays still")
		for invalid in [{"time": INF}, {"time": NAN}, {"time": 1e30}, {"gait": -44.8, "animation": "walk"}, {"animation": "unknown", "time": "bad"}]:
			var safe: Dictionary = actors.frame_info(kind, invalid)
			expect(safe.index >= 0 and safe.index < Actors.FRAME_COUNT, kind + " malformed clock remains bounded")
	# Localized differences prove moving feet/props, not a whole-image rocking effect.
	var evidence := {
		"witch_feet": ["witch", "walk", 0, 3, Rect2i(20, 46, 26, 16), 25],
		"witch_book_arm": ["witch", "cast", 0, 2, Rect2i(39, 15, 23, 30), 40],
		"hound_paws": ["hound", "walk", 0, 3, Rect2i(12, 43, 40, 15), 25],
		"charger_hooves": ["charger", "walk", 0, 3, Rect2i(10, 46, 45, 14), 25],
		"archer_draws_string": ["archer", "warning", 0, 3, Rect2i(28, 32, 25, 12), 15],
		"bat_wings": ["bat", "walk", 0, 2, Rect2i(2, 7, 59, 43), 120],
		"sentinel_shield": ["sentinel", "warning", 0, 3, Rect2i(38, 22, 25, 36), 70],
		"wisp_flame": ["wisp", "cast", 0, 2, Rect2i(18, 1, 28, 37), 40],
		"thorn_fists": ["boss_thorn", "warning", 0, 3, Rect2i(62, 22, 33, 56), 100],
		"mirror_shards": ["boss_mirror", "cast", 0, 2, Rect2i(0, 12, 24, 74), 60],
		"bell_clapper": ["boss_bell", "idle", 0, 1, Rect2i(34, 68, 30, 17), 25],
	}
	var pixel_evidence: Dictionary = {}
	for label in evidence:
		var entry: Array = evidence[label]
		var difference := pixels_different(frame_image(entry[0], entry[1], entry[2]), frame_image(entry[0], entry[1], entry[3]), entry[4])
		pixel_evidence[label] = difference
		expect(difference >= int(entry[5]), label + " moves distinct body parts in actual imported pixels")
	for i in range(1, 7):
		for j in range(i + 1, 7):
			var first := frame_image(Actors.KINDS[i], "idle", 0)
			var second := frame_image(Actors.KINDS[j], "idle", 0)
			expect(pixels_different(first, second, Rect2i(0, 0, 64, 64)) > 450, "enemy silhouettes and artwork are genuinely distinct")
	# Hundreds of frames reuse the exact texture objects, including flipped and
	# reduced-motion calls. Native rendering also checks their inherited transform.
	var sheet := Sheet.new()
	sheet.actors = actors
	root.add_child(sheet)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 1160)
	await settle()
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("/private/tmp/echo-pixel-actors-contact.png")
		sheet.mode = 1
		sheet.queue_redraw()
		await settle()
		root.get_texture().get_image().save_png("/private/tmp/echo-pixel-actors-motion.png")
	sheet.mode = 2
	for frame in range(180):
		sheet.clock = frame / 60.0
		sheet.queue_redraw()
		await settle()
	expect(actors.diagnostics() == ids, "rendering does not allocate replacement texture resources")
	if DisplayServer.get_name() != "headless":
		var drawn := root.get_texture().get_image()
		expect(drawn.get_pixel(94, 94).is_equal_approx(Color.MAGENTA), "draw_actor preserves the caller draw transform")
		root.get_texture().get_image().save_png("/private/tmp/echo-pixel-actors-lifetime.png")
		sheet.mode = 3
		sheet.queue_redraw()
		await settle()
		var pair := root.get_texture().get_image()
		var right := pair.get_region(Rect2i(64, 40, 64, 64))
		var left := pair.get_region(Rect2i(192, 40, 64, 64))
		left.flip_x()
		expect(pixels_different(right, left, Rect2i(0, 0, 64, 64)) == 0, "left-facing sprite flips exactly around the same foot anchor")
		pair.save_png("/private/tmp/echo-pixel-actors-facing.png")
	print("PIXEL_ACTORS " + JSON.stringify({"checks": checks, "failures": failures, "renderer": DisplayServer.get_name(), "draw_execution_verified": DisplayServer.get_name() != "headless", "draw_notifications": sheet.samples, "native_draw_frames": sheet.samples if DisplayServer.get_name() != "headless" else 0, "resources_reused": actors.diagnostics() == ids, "pixel_motion_evidence": pixel_evidence, "atlas_count": ids.atlas_count, "frame_count_per_actor": 36}))
	quit(1 if failures else 0)
