extends SceneTree

const RaceScene := preload("res://HarborRace.tscn")
const DT := 1.0 / 60.0
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func press(button: Button) -> void:
	await process_frame
	await process_frame
	var point := button.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)

func ticks(count: int) -> void:
	for tick in count:
		game._physics_process(DT)

func check_layout(sizes: Array, buttons: Array) -> void:
	for dimensions: Vector2i in sizes:
		root.size = dimensions
		await process_frame
		await process_frame
		var hud: Control = game.hud
		var visible_rect := Rect2(Vector2.ZERO, hud.size)
		var scale_factor := Vector2(root.size) / hud.size
		var rects: Array[Rect2] = []
		for button: Button in buttons:
			var bounds := button.get_global_rect()
			check(visible_rect.encloses(bounds), "%s should fit at %s" % [button.accessibility_name, dimensions])
			var screen_size := bounds.size * scale_factor
			check(minf(screen_size.x, screen_size.y) >= 43.99, "Touch targets must be at least 44 pixels at %s" % dimensions)
			for other in rects:
				check(not other.intersects(bounds), "Controls must not overlap at %s" % dimensions)
			rects.append(bounds)

func run() -> void:
	root.size = Vector2i(420, 780)
	change_scene_to_packed(RaceScene)
	await process_frame
	await process_frame
	game = current_scene
	game.set_physics_process(false)
	game.sfx = false
	game.song = false
	var hud = game.hud
	var view_sizes := [Vector2i(320,568), Vector2i(1024,760), Vector2i(390,800)]
	await check_layout(view_sizes, hud.course_buttons)
	check(game.mode == "title" and game.get_node("Course").get_child_count() == 0, "Course selection should start without loading a 3D track")
	check(hud.course_buttons.size() == 2, "Both course cards should be available")
	await press(hud.course_buttons[1])
	check(game.mode == "countdown" and game.sim.course_id == "yard", "The sunset card should load the container yard")
	var hero = game.figures[0]
	var old_reduced: bool = game.reduced
	game.reduced = false
	ticks(100)
	check(hero.active_clip == "ready" and not hud.rank_panel.visible and hero.emotion.x > 0.1, "The grid lets the runners brace before the clock starts")
	ticks(54)
	await check_layout(view_sizes, [hud.left, hud.right, hud.jump, hud.boost, hud.halt])
	check(game.mode == "racing", "The countdown should release the racers")
	check(hero.active_clip == "launch" and hud.rank_panel.visible, "The opening push should follow the countdown")
	var rival = game.figures[1]
	var previous_position: Vector3 = rival.position
	rival.position = hero.position + (game.cam.position - hero.position - Vector3.UP * 0.76).normalized() * 0.65
	game._clear_chase_view(1.0)
	check(rival.visibility_from_camera < 0.15, "A rival between Nagi and the camera should clear the view")
	rival.position = previous_position + Vector3.LEFT * 3.0
	game._clear_chase_view(1.0)
	check(rival.visibility_from_camera > 0.99, "A rival in a separate lane should be solid")
	rival.position = previous_position
	var runner: Dictionary = game.sim.runners[0]
	await press(hud.boost)
	ticks(1)
	check(runner.boosts_left == 1 and hud.boosts_left == 1 and runner.state == "sprint", "The boost control should spend one flag and show sprint")
	ticks(9)
	check(hero.active_clip == "sprint" and hero.emotion.x > 0.70 and game.effects.strokes.size() > 0, "Sprinting should focus the eyes and leave paired heel strokes")
	await press(hud.jump)
	ticks(1)
	check(runner.state == "jump" and hud.jump.text == "ダイブ", "The jump button should change to the dive action in midair")
	ticks(20)
	key(KEY_SPACE)
	ticks(1)
	check(runner.state == "dive" and hud.jump.disabled, "A second press should dive once")
	ticks(2)
	check(hero.active_clip == "dive" and game.effects.trail_action == "dive", "The dive should switch the trail to the reaching hands")
	key(KEY_P)
	var clock: float = game.sim.time
	var face: Vector3 = hero.emotion
	var trail_clock: float = game.effects.trail_clock
	ticks(60)
	check(game.mode == "paused" and game.sim.time == clock, "Pausing during a dive should freeze the race")
	check(hero.emotion == face and game.effects.trail_clock == trail_clock, "Pausing should freeze the performance")
	await press(hud.resume)
	ticks(65)
	check(game.mode == "racing" and runner.grounded and not hud.jump.disabled, "A paused dive should land and enable jumping on resume")
	key(KEY_SHIFT)
	ticks(1)
	check(runner.boosts_left == 0 and hud.boost.disabled, "The keyboard should spend the second flag")
	await press(hud.halt)
	await press(hud.restart)
	check(game.mode == "countdown" and game.sim.runners[0].boosts_left == 2, "Restart should restore both flags")
	check(game.effects.strokes.is_empty() and hero.celebration_start < 0.0 and hero.active_clip == "ready", "A new race should clear strokes and restart the brace")
	await press(hud.halt)
	await press(hud.pause_courses)
	check(game.mode == "title", "Pause should lead back to course selection")
	await press(hud.course_buttons[0])
	check(game.sim.course_id == "wharf" and game.sim.finish_distance == 150 and game.get_node("Course").get_child_count() == 1, "Changing course should replace the previous track")
	ticks(155)
	# Exercise the finish-line transition rather than replaying the physical route tested separately.
	runner = game.sim.runners[0]
	runner.p = game.sim.finish_distance - 0.02
	runner.speed = 3.92
	ticks(2)
	check(game.mode == "result" and hud.result_time.text.begins_with("潮風ふ頭"), "The results should name the course actually finished")
	ticks(147)
	check(hero.active_clip == "finish_win" and game.result_cheered and hero.emotion.z > 0.9, "The winner should celebrate after braking")
	await press(hud.result_retry)
	check(game.mode == "countdown" and game.sim.course_id == "wharf", "Retry should keep the same course")
	await press(hud.halt)
	await press(hud.pause_courses)
	await press(hud.course_buttons[1])
	game.reduced = true
	ticks(155)
	await press(hud.boost)
	ticks(8)
	check(game.effects.strokes.is_empty() and game.effects.pieces.is_empty() and hero.active_clip == "sprint", "Reduced motion keeps the sprint but suppresses trails and bursts")
	runner = game.sim.runners[0]
	runner.p = game.sim.finish_distance - 0.02
	runner.x = 0.0
	runner.speed = 3.92
	ticks(2)
	await press(hud.result_courses)
	check(game.mode == "title", "The results should allow picking another course")
	game.reduced = old_reduced
	print("Course flow: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
