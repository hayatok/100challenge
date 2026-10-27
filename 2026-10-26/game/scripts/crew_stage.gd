extends Control
## A decorative receipt actor; it never receives or changes game state.
const ActorScene = preload("res://scenes/actor.tscn")

var character := "isana"
var phase := "arrival"
var celebrate := false
var reduced_motion := false
var _paused := false
var _actor: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_actor = ActorScene.instantiate()
	add_child(_actor)
	_actor.configure(null, character, true, reduced_motion)
	_actor.set_stage_scale(1.65)
	_actor.get_node("GroundRing").visible = false
	resized.connect(_place_actor)
	_place_actor()
	if phase == "loss":
		_actor.play_loss()
	else:
		_actor.play_arrival(celebrate)
	_actor.set_presentation_paused(_paused)

func _place_actor() -> void:
	if is_instance_valid(_actor):
		_actor.position = Vector2(size.x * 0.5, size.y - 19.0 * 1.65 - 10.0)
	queue_redraw()

func set_presentation_paused(paused: bool) -> void:
	_paused = paused
	if is_instance_valid(_actor):
		_actor.set_presentation_paused(paused)

func set_reduced_motion(reduced: bool) -> void:
	if reduced_motion == reduced:
		return
	reduced_motion = reduced
	if not is_instance_valid(_actor):
		return
	_actor.configure(null, character, true, reduced)
	_actor.set_stage_scale(1.65)
	if reduced:
		if phase == "loss":
			_actor.play_loss()
		else:
			_actor.play_arrival(celebrate)
	# Restoring full motion leaves the resolved outcome held, without replaying it.
	_actor.set_presentation_paused(_paused)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var radius := minf(size.x * 0.47, size.y * 0.45)
	draw_circle(center, radius, Color("c1e4d8") if phase != "loss" else Color("dce1d6"))
	draw_arc(center, radius - 4, 0, TAU, 64, Color("fff8e5"), 1.5, true)
	for i: int in 12:
		var direction := Vector2.from_angle(i * TAU / 12.0)
		draw_line(center + direction * (radius - 11), center + direction * (radius - 6), Color(0.3, 0.6, 0.61, 0.34), 1.3, true)
