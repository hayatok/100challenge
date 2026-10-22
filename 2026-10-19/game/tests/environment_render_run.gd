extends SceneTree
## Arranged environment fixtures, using the production cache and collision layout.
## Native screenshots expose every obstacle; these are not gameplay playthroughs.

const Run := preload("res://scripts/run_model.gd")
const Garden := preload("res://scripts/garden_view.gd")
const FloorArt := preload("res://scripts/campaign_floor.gd")
const Campaign := preload("res://scripts/campaign.gd")
var model = Run.new()
var view
var out := ""
var checks := 0
var failed := false
var captures: Array[Dictionary] = []

func _initialize() -> void:
	out = OS.get_environment("ENVIRONMENT_RENDER_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../.cache/art-upgrade/environment")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + label)

func settle() -> void:
	for i in range(3):
		view.refresh()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw

func _run() -> void:
	root.content_scale_size = Vector2i(1440, 1240)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1440, 1240)
	model.reset(true, 197, "moon")
	model.enemies.clear()
	model.effects.clear()
	model.pickups.clear()
	model.chests.clear()
	model.echo_active = false
	view = Garden.new()
	view.run = model
	view.reduced_motion = true
	root.add_child(view)
	for chapter in range(3):
		model.chapter = chapter
		model._chapter_data = Campaign.chapter(chapter)
		model.player = Vector2.ZERO
		model.elapsed += 0.1
		var geometry := Campaign.chapter(chapter)
		var terrain := FloorArt.terrain_region(chapter)
		expect(terrain.has_area(), "Every chapter has a painted terrain region")
		expect(Rect2(Vector2.ZERO, FloorArt.TERRAIN.get_size()).encloses(terrain), "Terrain panel stays inside source texture")
		for obstacle in geometry.obstacles:
			var modules := FloorArt.obstacle_modules(obstacle, chapter, 0)
			var covered_area := 0.0
			for module in modules:
				expect((obstacle as Rect2).encloses(module.target), "Painted module footprint stays in the collision solid")
				expect(Rect2(Vector2.ZERO, FloorArt.SCENERY.get_size()).encloses(module.source), "Prop panel stays inside source texture")
				covered_area += (module.target as Rect2).get_area()
			expect(is_equal_approx(covered_area, (obstacle as Rect2).get_area()), "Module banks cover their complete collision footprint")
			if (obstacle as Rect2).size.y > (obstacle as Rect2).size.x * 1.45:
				expect(modules.size() > 1, "Long shelf uses multiple intact motifs")
		await settle()
		var entry: Dictionary = view.scenery_cache._entries[chapter]
		expect(entry.geometry.obstacles == geometry.obstacles, "Painted cache retains model collision rectangles")
		expect(entry.parts.size() == geometry.obstacles.size() * 2, "Painted cache preserves base/body part count")
		expect(entry.viewport.size.x <= 1024 and entry.viewport.size.y <= 2048, "Painted atlas stays within the existing budget")
		if DisplayServer.get_name() != "headless":
			var path := out.path_join("chapter-%d-all-props.png" % (chapter + 1))
			var image: Image = root.get_texture().get_image()
			expect(image.save_png(path) == OK, "Environment fixture saved")
			captures.append({"chapter": chapter, "path": path, "size": image.get_size(), "all_collision_obstacles": geometry.obstacles.size(), "atlas_size": entry.viewport.size})
	var before: Dictionary = view.scenery_cache.diagnostics()
	var resources: Array = []
	for chapter in range(3):
		var entry: Dictionary = view.scenery_cache._entries[chapter]
		resources.append([entry.floor.get_instance_id(), entry.viewport.get_instance_id(), entry.texture.get_rid().get_id()])
	for chapter in range(3):
		model.chapter = chapter
		model._chapter_data = Campaign.chapter(chapter)
		model.elapsed += 0.1
		await settle()
		var entry: Dictionary = view.scenery_cache._entries[chapter]
		expect(resources[chapter] == [entry.floor.get_instance_id(), entry.viewport.get_instance_id(), entry.texture.get_rid().get_id()], "Reentry reuses painted floor and obstacle resources")
	expect(view.scenery_cache.diagnostics().count == 3 and before.count == 3, "Painted cache remains bounded to three chapters")
	var report := {"kind": "arranged native environment fixtures", "real_gameplay": false, "renderer": DisplayServer.get_name(), "checks": checks, "failed": failed, "terrain_size": FloorArt.TERRAIN.get_size(), "scenery_size": FloorArt.SCENERY.get_size(), "captures": captures}
	if DisplayServer.get_name() != "headless":
		var manifest := FileAccess.open(out.path_join("fixtures.json"), FileAccess.WRITE)
		expect(manifest != null, "Environment manifest opens")
		if manifest != null:
			manifest.store_string(JSON.stringify(report, "\t"))
	print("ENVIRONMENT_ART " + JSON.stringify(report))
	view.free()
	await process_frame
	quit(1 if failed else 0)
