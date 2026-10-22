extends SceneTree
## Painted icon contracts plus a native contact sheet, separate from gameplay QA.

const Art := preload("res://scripts/illustrated_assets.gd")
const Glyph := preload("res://scripts/spell_glyph.gd")
const Actors := preload("res://scripts/pixel_actors.gd")
var checks := 0
var failed := false
var out := ""

class ContactSheet:
	extends Node2D
	var ids: Array = []
	var successful_draws := 0
	func _draw() -> void:
		successful_draws = 0
		draw_rect(Rect2(0, 0, 1440, 1080), Color("0b1120"))
		for i in range(ids.size()):
			var at := Vector2(float(i % 8) * 176 + 16, float(i / 8) * 176 + 12)
			draw_rect(Rect2(at, Vector2(88, 154)), Color("141e30"))
			draw_rect(Rect2(at + Vector2(88, 0), Vector2(88, 154)), Color("f5ecd8"))
			for x in [44.0, 132.0]:
				if Art.draw_icon(self, str(ids[i]), at + Vector2(x, 35), 36):
					successful_draws += 1
				if Art.draw_icon(self, str(ids[i]), at + Vector2(x, 111), 72):
					successful_draws += 1
			draw_string(ThemeDB.fallback_font, at + Vector2(5, 171), str(ids[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5ead4"))
		for i in range(8):
			var at := Vector2(float(i) * 176 + 16, 920)
			draw_rect(Rect2(at, Vector2(88, 122)), Color("141e30"))
			draw_rect(Rect2(at + Vector2(88, 0), Vector2(88, 122)), Color("f5ecd8"))

func _initialize() -> void:
	out = OS.get_environment("ILLUSTRATED_RENDER_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../.cache/art-upgrade/icons")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + label)

func resource_ids(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		var texture := Art.texture_for(str(id))
		result.append([texture.get_instance_id(), texture.atlas.get_instance_id()])
	return result

func _run() -> void:
	Art.warm_cache()
	var ids := Art.cached_ids()
	expect(ids.size() == 40, "Cache contains 18 items, 12 rewards, opened chest and nine enemy icons")
	expect(Art.texture_for("not-an-icon") == null, "Unknown icon has no placeholder resource")
	for source in [Art.ITEMS, Art.REWARDS, Art.CHEST_OPEN]:
		expect((source as Texture2D).get_image().has_mipmaps(), "Painted inventory sources supply minification mipmaps")
	var retained := resource_ids(ids)
	for id in ids:
		var icon := Art.texture_for(str(id))
		var region: Rect2 = icon.region
		var dimensions := icon.atlas.get_size()
		expect(region.has_area() and region.position.is_finite() and region.size.is_finite(), "Source region is finite and nonempty: " + str(id))
		expect(Rect2(Vector2.ZERO, dimensions).encloses(region), "Source region stays in its original PNG: " + str(id))
		var uv := Rect2(region.position / dimensions, region.size / dimensions)
		expect(Rect2(0, 0, 1, 1).encloses(uv), "Normalized texture coordinates stay within source: " + str(id))
		expect(icon.filter_clip, "Atlas filter clips neighboring source art: " + str(id))
	for alias in Art.ALIASES:
		expect(Art.texture_for(alias) == Art.texture_for(str(Art.ALIASES[alias])), "Alias reuses original icon resource: " + alias)
	for id in Art.ENEMY_IDS:
		var kind := "wisp" if id == "enemy_wisp" else str(id)
		var icon := Art.texture_for(str(id))
		var source: Texture2D = Actors.SOURCES[kind]
		var normalized: Rect2 = Actors.SOURCE_REGIONS[kind]
		expect(icon.atlas == source and icon.region == Rect2(normalized.position * source.get_size(), normalized.size * source.get_size()), "Enemy glyph shares authoritative battle source and region: " + kind)
		expect(Art.texture_for("enemy:" + kind) == icon, "Enemy-prefixed alias shares icon resource: " + kind)
	expect(Art.texture_for("wisp") != Art.texture_for("enemy:wisp"), "Wisp weapon and enemy keep distinct illustrations")
	expect(Art.texture_for("chest").atlas != Art.texture_for("chest_open").atlas, "Opened chest uses its distinct source illustration")
	for repeat in range(20):
		Art.warm_cache()
		for alias in Art.ALIASES:
			Art.texture_for(alias)
	expect(resource_ids(ids) == retained, "Repeated glyph lookups keep all texture resources")
	var sheet := ContactSheet.new()
	sheet.ids = ids
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.content_scale_size = Vector2i(1440, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1440, 1080)
	root.add_child(sheet)
	expect(not Art.draw_icon(sheet, "not-an-icon", Vector2.ZERO, 36), "Unknown draw reports false")
	expect(not Art.draw_icon(sheet, "moon", Vector2.ZERO, 0), "Empty extent does not submit an invalid draw")
	expect(not Art.draw_icon(sheet, "moon", Vector2(INF, 0), 36), "Nonfinite icon position is rejected")
	var glyph_ids := ["moon_evolved", "evolution_lightning", "empty", "new", "evolution", "locked", "enemy:wisp", "enemy:boss_bell"]
	for i in range(glyph_ids.size()):
		for paper in [false, true]:
			var glyph := Glyph.new()
			glyph.kind = glyph_ids[i]
			glyph.on_paper = paper
			glyph.position = Vector2(float(i) * 176 + (122 if paper else 42), 950)
			glyph.size = Vector2.ONE * 36
			sheet.add_child(glyph)
	for i in range(3):
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
	var capture_path := ""
	if DisplayServer.get_name() != "headless":
		expect(sheet.successful_draws == ids.size() * 4, "Native contact sheet submitted every icon on dark and paper at 36px and 72px")
		capture_path = out.path_join("painted-icons-contact-sheet.png")
		var image: Image = root.get_texture().get_image()
		expect(image.get_size() == Vector2i(1440, 1080), "Native contact sheet has intended pixel dimensions")
		expect(image.save_png(capture_path) == OK, "Native icon contact sheet saved")
	expect(resource_ids(ids) == retained and Art.cached_ids().size() == 40, "Native draws and glyph instances do not grow or replace the cache")
	var report := {"kind": "arranged native painted icon fixture", "real_gameplay": false, "renderer": DisplayServer.get_name(), "checks": checks, "failed": failed, "icon_count": ids.size(), "resource_ids_reused": resource_ids(ids) == retained, "native_draws": sheet.successful_draws, "capture": capture_path, "glyph_cases": glyph_ids}
	if not capture_path.is_empty():
		var manifest := FileAccess.open(out.path_join("fixtures.json"), FileAccess.WRITE)
		if manifest != null:
			manifest.store_string(JSON.stringify(report, "\t"))
	print("ILLUSTRATED_ASSETS " + JSON.stringify(report))
	sheet.free()
	await process_frame
	quit(1 if failed else 0)
