extends Node
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var cursor := 0
var music: AudioStreamPlayer
var warning: AudioStreamPlayer3D
func _ready() -> void:
	for name in ["slash", "wire", "impact", "dash", "chime"]:
		samples[name] = load("res://assets/audio/%s.wav" % name)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	warning = AudioStreamPlayer3D.new()
	warning.stream = samples["impact"]
	warning.volume_db = -5
	warning.pitch_scale = 1.8
	warning.unit_size = 5
	add_child(warning)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/wind_music.wav")
	music.volume_db = -12
	music.finished.connect(func(): music.play())
	add_child(music)
func cue(name: String) -> void:
	if not samples.has(name): return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = samples[name]
	voice.volume_db = -9
	voice.play()
func begin() -> void:
	if not music.playing: music.play()
func stop() -> void:
	warning.stop()
	music.stop()
	for voice in voices: voice.stop()

func warn_at(at: Vector3) -> void:
	warning.global_position = at
	warning.play()
