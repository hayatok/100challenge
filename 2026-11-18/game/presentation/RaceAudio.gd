extends Node

var track := preload("res://media/regatta.wav") as AudioStreamWAV
const CUES := {
	"count": preload("res://media/count.wav"),
	"go": preload("res://media/go.wav"),
	"step": preload("res://media/step.wav"),
	"jump": preload("res://media/jump.wav"),
	"land": preload("res://media/land.wav"),
	"bump": preload("res://media/bump.wav"),
	"splash": preload("res://media/splash.wav"),
	"finish": preload("res://media/finish.wav")
}
var music := AudioStreamPlayer.new()
var channels: Array[AudioStreamPlayer] = []
var cursor := 0
var music_active := false

func _ready() -> void:
	add_child(music)
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = roundi(track.get_length() * track.mix_rate)
	music.stream = track
	music.volume_db = -10.0
	for i in 5:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		channels.append(voice)

func play_cue(cue: String) -> void:
	var voice := channels[cursor]
	cursor = (cursor + 1) % channels.size()
	voice.stream = CUES[cue]
	voice.volume_db = -21.0 if cue == "step" else -8.0
	voice.play()

func reset() -> void:
	end_music()
	for voice in channels:
		voice.stop()
		voice.stream_paused = false

func start_music(enabled: bool) -> void:
	music_active = true
	set_music_enabled(enabled)

func set_music_enabled(enabled: bool) -> void:
	if not enabled or not music_active:
		music.stop()
	elif not music.playing:
		music.play()

func end_music() -> void:
	music_active = false
	music.stop()
	music.stream_paused = false

func suspend(value: bool) -> void:
	music.stream_paused = value
	for voice in channels:
		voice.stream_paused = value
