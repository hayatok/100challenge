extends SceneTree
## Native composition fixtures; these images are separate from real Web play.

const Run := preload("res://scripts/run_model.gd")
const Garden := preload("res://scripts/garden_view.gd")
const Interface := preload("res://scripts/interface.gd")
var model = Run.new()
var view
var ui
var out := ""
var frames := 0
var checks := 0
var failed := false

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This composition capture needs the native renderer")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	out = OS.get_environment("MOTION_RENDER_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../.cache/motion/native")
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + label)

func settle() -> void:
	view.refresh()
	ui.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	frames += 1
	expect(int(view.presentation_fx.diagnostics().particles_drawn) <= 96, "actual rendered particle budget")

func capture(name: String) -> void:
	await settle()
	var image: Image = root.get_texture().get_image()
	expect(image.get_width() == 1280 and image.get_height() == 720, "native screenshot keeps logical dimensions")
	image.save_png(out.path_join(name + ".png"))

func advance(seconds: float) -> void:
	model.elapsed += seconds
	model.chapter_elapsed += seconds
	model._update_effects(seconds)

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	model.reset(true, 196)
	model.elapsed = 20.0
	model.chapter_elapsed = 20.0
	model.enemies.clear()
	model.effects.clear()
	model.pickups.clear()
	model.echo_active = true
	model.echo = Vector2(-120, 95)
	var kinds := ["hound", "charger", "archer", "bat", "sentinel", "wisp"]
	var points := [Vector2(-360,-120),Vector2(-190,-210),Vector2(160,-190),Vector2(350,-80),Vector2(290,145),Vector2(-300,155)]
	for i in range(kinds.size()):
		var enemy: Dictionary = model.spawn_enemy(kinds[i], points[i])
		enemy.phase = "seek"
		enemy.timer = 0.0
	view = Garden.new()
	view.run = model
	root.add_child(view)
	ui = Interface.new()
	ui.run = model
	root.add_child(ui)
	await settle()
	await capture("garden-idle")
	var ids: Array = view.pixel_actors.diagnostics().texture_ids
	for i in range(6):
		model.player += Vector2(8, 0)
		model.echo += Vector2(0, -5)
		for enemy in model.enemies:
			enemy.position += Vector2(-4, 1)
		advance(0.06)
		await capture("garden-walk-%d" % i)
	model.cast({"kind":"lightning"}, model.player, false)
	advance(0.016)
	await capture("garden-cast-0")
	advance(0.12)
	await capture("garden-cast-1")
	for enemy in model.enemies:
		enemy.phase = "warning"
		enemy.timer = 0.35
		enemy.direction = (model.player - enemy.position).normalized()
		enemy.warning_length = 240.0
	advance(0.05)
	await capture("garden-warning")
	# Exercise the actual renderer at its feedback limit with frozen real hit cues.
	for i in range(45):
		view.presentation._emit("resonance", model.player + Vector2(i % 5 * 14, i % 4 * 12), {"echo": i % 2 == 0}, 0.42, 2)
	advance(0.07)
	await capture("feedback-crowd")
	model.pause()
	await settle()
	var paused_pose: Dictionary = view.motion_snapshot()
	await settle()
	expect(view.motion_snapshot() == paused_pose, "native paused frame and resources stay frozen")
	view.reduced_motion = true
	await capture("reduced-motion")
	expect(view.camera_offset == Vector2.ZERO, "native reduced-motion removes camera offset")
	for chapter in range(3):
		model.chapter = chapter
		model._start_chapter(false)
		model.chapter_stage = "boss"
		model.elapsed += 1.0
		model.chapter_elapsed = 180.4
		model.echo_active = true
		model.echo = Vector2(-130,60)
		model.state = "playing"
		view.reduced_motion = false
		var boss: Dictionary = model.spawn_enemy(str(model.chapter_info().boss_id), Vector2(225,-10))
		boss.phase = "seek"
		boss.timer = 0.0
		await capture("boss-%d-idle" % chapter)
		boss.phase = "warning"
		boss.timer = 0.45
		model._boss_pattern(boss)
		advance(0.1)
		await capture("boss-%d-warning" % chapter)
		expect(view.pixel_actors.diagnostics().texture_ids == ids, "chapters reuse all actor textures")
	print("MOTION_NATIVE: %d checks, %d frames, failed=%s, out=%s" % [checks,frames,failed,out])
	ui.free()
	view.free()
	await process_frame
	quit(1 if failed else 0)
