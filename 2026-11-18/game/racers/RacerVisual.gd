extends Node3D

const Race := preload("res://race/RaceSimulation.gd")
const FLIGHT_SECONDS := 2.0 * Race.TAKEOFF_SPEED / Race.GRAVITY

const FILES := [
	"res://racers/01.glb", "res://racers/02.glb", "res://racers/03.glb",
	"res://racers/04.glb", "res://racers/05.glb", "res://racers/06.glb"
]
var model: Node3D
var player: AnimationPlayer
var active_clip := ""

func setup(index: int) -> void:
	if model:
		remove_child(model)
		model.queue_free()
	var packed := load(FILES[clampi(index, 0, FILES.size() - 1)]) as PackedScene
	model = packed.instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	player = null if players.is_empty() else players[0] as AnimationPlayer
	if player:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	active_clip = ""
	pose("idle", 0.0, 0.0, 0.0)

func pose(state: String, elapsed: float, phase: float, steer: float) -> void:
	if not player or not player.has_animation(state):
		return
	if state != active_clip:
		active_clip = state
		player.play(state)
	var duration := player.get_animation(state).length
	var t: float
	match state:
		"run", "sprint":
			t = fposmod(phase, 1.0) * duration
		"jump":
			t = clampf(elapsed / FLIGHT_SECONDS, 0.0, 1.0) * duration
		"slide":
			t = clampf(elapsed / Race.SLIDE_SECONDS, 0.0, 1.0) * duration
		"idle", "finish":
			t = fposmod(elapsed, duration)
		_:
			# A long fall holds the last reaching pose of the dive.
			t = clampf(elapsed, 0.0, duration)
	player.seek(t, true)
	model.rotation.z = clampf(steer, -1.0, 1.0) * (0.075 if state in ["run", "sprint"] else 0.035)
