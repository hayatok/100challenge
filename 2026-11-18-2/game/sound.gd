extends Node

const EVENTS := ["fire0","fire1","fire2","reload","switch","empty","flesh","kill","hurt","attack","charge_warning","flare","bell","gate","crash","depart","hum0","hum1","hum2","step0","step1","step2","chain","discharge"]
var samples := {}
var music := AudioStreamPlayer.new()
var ambient := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer3D] = []
var index := 0
var level := 0
var active_music := ""
var score := {}
var last_flesh := 0
var playhead := {}

func _ready() -> void:
	for key in EVENTS:
		samples[key] = load("res://media/sfx/%s.wav" % key)
	for key in ["auction","captain"]:
		var track: AudioStreamMP3 = load("res://media/%s.mp3" % key)
		track.loop = true
		score[key] = track
	for channel in [music,ambient]: add_child(channel)
	music.volume_db = -13
	ambient.volume_db = -15
	for i in 20:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 8
		voice.max_distance = 50
		voices.append(voice)
		add_child(voice)

func set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(clampf(linear,0.0001,1.0)))

func set_scene(chapter: int) -> void:
	level = chapter
	ambient.volume_db = -15
	quiet()
	var loop: AudioStreamWAV = samples["hum%d"%level]
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size()/2
	ambient.stream = loop
	ambient.play()

func battle(boss: bool) -> void:
	var key := "captain" if boss else "auction"
	if active_music == key and music.playing: return
	active_music = key
	music.stream = score[key]
	music.play(float(playhead.get(key,0.0)))

func quiet() -> void:
	if music.playing and not active_music.is_empty():
		playhead[active_music] = music.get_playback_position()
	active_music = ""
	music.stop()

func stop_all() -> void:
	quiet()
	playhead.clear()
	ambient.stop()
	for voice in voices: voice.stop()

func ending() -> void:
	stop_all()
	ambient.stream = samples["depart"]
	ambient.volume_db = -6
	ambient.play()

func effect(event: String, point: Vector3) -> void:
	if event in ["boss_warning","boss_sweep"]: event = "chain"
	if event == "boss_charge": event = "charge_warning"
	if event == "boss_exposed": event = "crash"
	if event == "boss_phase": event = "depart"
	if not samples.has(event): return
	if event == "flesh":
		var now := Time.get_ticks_msec()
		if now - last_flesh < 55: return
		last_flesh = now
	var voice := voices[index]
	index = (index + 1) % voices.size()
	voice.stream = samples[event]
	voice.global_position = point
	voice.volume_db = -9 if event in ["fire0","flesh","attack"] else -3
	if event.begins_with("step"): voice.volume_db = -19
	voice.pitch_scale = randf_range(0.94,1.06) if event != "bell" else 1.0
	voice.play()
