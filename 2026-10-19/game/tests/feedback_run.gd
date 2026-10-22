extends SceneTree

const Run := preload("res://scripts/run_model.gd")
const Presentation := preload("res://scripts/presentation.gd")
const Feedback := preload("res://scripts/presentation_fx.gd")
var checks := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var run = Run.new()
	run.reset(true, 196)
	var presentation = Presentation.new()
	var fx = Feedback.new()
	presentation.update(run)
	fx.camera_offset(presentation, run, false)
	run.take_damage(8.0)
	presentation.update(run)
	var impulse: Vector2 = fx.camera_offset(presentation, run, false)
	expect(impulse.length() > 0.001, "a real player hit drives a bounded visual recoil")
	expect(impulse.length() <= Feedback.CAMERA_LIMIT, "camera stays inside the stated pixel range")
	var texture_id: int = fx.texture.get_instance_id()
	run.pause()
	for i in range(500):
		presentation.update(run)
		expect(fx.camera_offset(presentation, run, false).is_equal_approx(impulse), "paused updates keep the same recoil position")
	expect(fx.texture.get_instance_id() == texture_id, "paused feedback reuses its atlas")
	expect(fx.camera_offset(presentation, run, true) == Vector2.ZERO, "reduced motion removes camera movement")
	expect(fx.camera_offset(presentation, run, false) == Vector2.ZERO, "disabling reduced mode does not replay an old impulse")
	run.resume()
	run.tick(0.3)
	presentation.update(run)
	expect(fx.camera_offset(presentation, run, false) == Vector2.ZERO, "short impulse expires on the combat clock")
	run.state = "chapter_clear"
	run.next_chapter()
	presentation.update(run)
	expect(fx.camera_offset(presentation, run, false) == Vector2.ZERO, "chapter transition clears recoil")
	run.reset(true, 196)
	presentation.update(run)
	expect(fx.camera_offset(presentation, run, false) == Vector2.ZERO, "retry clears recoil")
	expect(fx.texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel filtering is scoped to the feedback texture")
	print("FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
