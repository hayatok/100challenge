extends SceneTree
## Cache lifetime and geometry checks; no gameplay clock, rules or storage changes.

const Renderer := preload("res://scripts/garden_view.gd")
const Campaign := preload("res://scripts/campaign.gd")

class RenderState:
	extends RefCounted
	var state := "playing"
	var elapsed := 0.0
	var chapter := 0
	var chapter_elapsed := 0.0
	var chapter_stage := "assault"
	var player := Vector2.ZERO
	var echo := Vector2.ZERO
	var echo_active := false
	var health := 100.0
	var facing := 1.0
	var invulnerable := 0.0
	var pickup_radius := 172.0
	var enemies: Array = []
	var projectiles: Array = []
	var pickups: Array = []
	var effects: Array = []
	var hazards: Array = []
	var chests: Array = []
	func chapter_info() -> Dictionary:
		return Campaign.chapter(chapter)

var model := RenderState.new()
var view
var checks := 0
var failed := false

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL: " + message)
		quit(1)

func settle(frames: int = 3) -> void:
	for i in range(frames):
		view.refresh()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw

func cache_ids() -> Array:
	var ids: Array = []
	for chapter in range(3):
		var entry: Dictionary = view.scenery_cache._entries[chapter]
		ids.append([entry.floor.get_instance_id(), entry.viewport.get_instance_id(), entry.texture.get_rid().get_id()])
	return ids

func build_summary(info: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in info.chapters:
		result.append({"chapter": entry.chapter, "floor_builds": entry.floor_builds, "atlas_builds": entry.atlas_builds, "atlas_size": entry.atlas_size})
	return result

func _run() -> void:
	view = Renderer.new()
	view.run = model
	root.add_child(view)
	for chapter in range(3):
		model.chapter = chapter
		model.elapsed += 0.1
		await settle()
	var warmed: Dictionary = view.scenery_cache.diagnostics()
	var ids := cache_ids()
	expect(warmed.count == 3 and warmed.limit == 3, "Cache must be bounded to three chapters")
	for chapter in range(3):
		var entry: Dictionary = view.scenery_cache._entries[chapter]
		var geometry := Campaign.chapter(chapter)
		expect(entry.geometry.bounds == geometry.bounds, "Cached bounds differ from collision bounds")
		expect(entry.geometry.obstacles == geometry.obstacles, "Cached obstacles differ from collision rectangles")
		expect(entry.parts.size() == geometry.obstacles.size() * 2, "Each obstacle needs separate base and body layers")
		for i in range(entry.parts.size()):
			var part: Dictionary = entry.parts[i]
			expect(part.obstacle == geometry.obstacles[int(i / 2)], "Painter order changed obstacle index")
			expect(part.frame == part.obstacle.grow(20), "Transparent padding changed footprint placement")
			expect(Rect2(Vector2.ZERO, Vector2(entry.viewport.size)).encloses(part.region), "Atlas region falls outside its texture")
			for j in range(i + 1, entry.parts.size()):
				expect(not part.region.intersects(entry.parts[j].region), "Atlas source regions overlap")
		expect(entry.viewport.size.x <= 1024 and entry.viewport.size.y <= 2048, "Atlas exceeds its fixed texture bounds")
	# Moving actors and the camera must not rebuild the static draw commands.
	for i in range(120):
		model.elapsed += 1.0 / 60.0
		model.chapter_elapsed += 1.0 / 60.0
		model.player = Vector2(sin(float(i) * 0.12) * 850, cos(float(i) * 0.12) * 600)
		view.refresh()
		expect(view.scenery_cache.position == -model.player + view.screen * Vector2(0.5, 0.52), "Camera transform disagrees with world drawing")
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
	expect(view.scenery_cache.diagnostics() == warmed, "Per-frame movement rebuilt static geometry")
	model.state = "paused"
	await settle()
	var paused: Array = view.last_signature.duplicate()
	await settle(4)
	expect(view.last_signature == paused, "Paused draw state changed")
	view.reduced_motion = true
	await settle()
	expect(view.scenery_cache.diagnostics() == warmed, "Reduced motion rebuilt static chapter surfaces")
	root.size = Vector2i(960, 540)
	await settle()
	root.size = Vector2i(1280, 720)
	await settle()
	var resized: Dictionary = view.scenery_cache.diagnostics()
	expect(cache_ids() == ids, "Window resize allocated replacement cache resources")
	# Godot re-notifies CanvasItem draws on resize and when becoming visible.
	# Those infrequent rebuilds are allowed; cache resources must still be reused.
	for cycle in range(3):
		for chapter in range(3):
			model.chapter = chapter
			model.elapsed += 0.1
			await settle()
	model.state = "title"
	await settle()
	expect(not view.scenery_cache.visible, "Title did not hide the world cache")
	model.state = "playing"
	model.chapter = 0
	model.elapsed = 0
	model.chapter_elapsed = 0
	model.player = Vector2.ZERO
	await settle()
	expect(view.scenery_cache.visible, "Retry did not show the world cache")
	expect(cache_ids() == ids, "Chapter/title/retry allocated replacement cache resources")
	var final: Dictionary = view.scenery_cache.diagnostics()
	expect(final.count == 3, "Retries grew the cache count")
	if failed:
		return
	print("RENDERER_CACHE_PASS " + JSON.stringify({"checks": checks, "renderer": DisplayServer.get_name(), "draw_execution_verified": DisplayServer.get_name() != "headless", "cache_limit": 3, "moving_frames": 120, "chapter_reentries": 9, "native_window_resizes": 2, "resource_ids_reused": true, "warm": build_summary(warmed), "after_resize": build_summary(resized), "after_retry": build_summary(final)}))
	quit()
