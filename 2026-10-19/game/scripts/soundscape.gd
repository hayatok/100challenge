extends Node
## Original local PCM music and bells. Playback starts only on explicit transitions.

var enabled := true
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_player := 0
var music: AudioStreamPlayer
var context := "title"
var music_started := false
var music_start_count := 0
var music_volume := 0.65
var sfx_volume := 0.8
var scene_key := "garden"
var themes: Dictionary = {}

func _ready() -> void:
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.volume_db = -17.0
		add_child(player)
		players.append(player)
	sounds.lightning = _tone(680, 220, 0.11, 0.32, 0.28)
	sounds.moon = _tone(280, 580, 0.23, 0.4, 0.0)
	sounds.pickup = _tone(980, 1430, 0.065, 0.22, 0.0)
	sounds.damage = _tone(180, 65, 0.22, 0.55, 0.2)
	sounds.level = _chord([440.0, 554.4, 659.2], 0.5)
	sounds.victory = _chord([523.3, 659.2, 783.9], 0.85)
	sounds.defeat = _chord([196.0, 233.1, 293.6], 0.65)
	sounds.start = _chord([329.6, 440.0], 0.25)
	sounds.resonance = _chord([587.3, 880.0, 1174.6], 0.19)
	sounds.thorn = _tone(310, 95, 0.19, 0.26, 0.45)
	sounds.wisp = _tone(540, 840, 0.23, 0.22, 0.05)
	sounds.frost = _chord([1046.5, 1396.9], 0.17)
	sounds.bell = _chord([261.6, 523.3, 783.9], 0.31)
	sounds.treasure = _chord([523.3, 659.2, 783.9, 1046.5], 0.72)
	sounds.evolution = _chord([392.0, 523.3, 659.2, 783.9, 1046.5], 0.95)
	sounds.boss = _chord([65.4, 98.0, 130.8], 0.8)
	sounds.chapter = _chord([392.0, 493.9, 587.3, 783.9], 0.78)
	for id in ["garden", "mirror", "bell", "boss"]:
		var stream := load("res://assets/audio/theme-%s.wav" % id) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
			themes[id] = stream
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	music.stream = themes["garden"] if themes.has("garden") else _night_motif()
	add_child(music)
	set_levels(music_volume, sfx_volume)

func play_event(event: String) -> void:
	if not enabled or sfx_volume <= 0.0 or not sounds.has(event) or players.is_empty():
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = sounds[event]
	player.pitch_scale = 1.0
	player.play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()
	else:
		play_event("pickup")
		_sync_music()

func set_levels(music_level: float, sfx_level: float) -> void:
	var was_muted := music_volume <= 0.0
	music_volume = clampf(music_level, 0.0, 1.0)
	sfx_volume = clampf(sfx_level, 0.0, 1.0)
	if is_instance_valid(music):
		music.volume_db = linear_to_db(maxf(0.0001, music_volume)) - 9.0
	for player in players:
		player.volume_db = linear_to_db(maxf(0.0001, sfx_volume)) - 17.0
	if music_volume <= 0.0 or was_muted:
		_sync_music()

func set_scene(chapter: int, boss: bool) -> void:
	var next_key := "boss" if boss else str(["garden", "mirror", "bell"][clampi(chapter, 0, 2)])
	if next_key == scene_key:
		return
	scene_key = next_key
	if is_instance_valid(music) and themes.has(scene_key):
		music.stop()
		music.stream = themes[scene_key]
		music_started = false
		_sync_music()

func set_context(value: String) -> void:
	if value == context:
		return
	context = value
	_sync_music()

func _sync_music() -> void:
	if not is_instance_valid(music):
		return
	if not enabled or music_volume <= 0.0 or context in ["title", "victory", "defeat"]:
		music.stop()
		music_started = false
	elif context == "playing":
		music.stream_paused = false
		# Web playback starts asynchronously: never poll `playing` to retry it.
		if not music_started:
			music_started = true
			music_start_count += 1
			music.play()
	else:
		music.stream_paused = true

func pause_all(paused: bool) -> void:
	for player in players:
		player.stream_paused = paused

func stop_all() -> void:
	music_started = false
	if is_instance_valid(music):
		music.stop()
	for player in players:
		player.stop()
		player.stream_paused = false

func _tone(from: float, to: float, seconds: float, gain: float, roughness: float) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(float(rate) * seconds)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var progress := float(i) / float(samples)
		phase += TAU * lerpf(from, to, progress) / float(rate)
		var envelope := minf(1.0, progress * 30.0) * pow(1.0 - progress, 1.8)
		var value := sin(phase) + sin(phase * 3.13) * roughness
		pcm.encode_s16(i * 2, int(clampf(value * envelope * gain, -1, 1) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream

func _chord(notes: Array, seconds: float) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(float(rate) * seconds)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	for i in range(samples):
		var time := float(i) / float(rate)
		var progress := float(i) / float(samples)
		var value := 0.0
		for j in range(notes.size()):
			var delay := float(j) * 0.055
			if time >= delay:
				value += sin((time - delay) * float(notes[j]) * TAU) * 0.14
		var envelope := minf(1.0, progress * 25.0) * pow(1.0 - progress, 1.5)
		pcm.encode_s16(i * 2, int(clampf(value * envelope, -1, 1) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream

func _night_motif() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 16.0
	var samples := int(rate * seconds)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var notes := [196.0, 293.66, 349.23, 261.63, 174.61, 261.63, 329.63, 293.66]
	for i in range(samples):
		var time := float(i) / rate
		var value := 0.0
		for note in range(notes.size()):
			# The preceding cycle supplies decays at the loop boundary.
			var age := fposmod(time - float(note) * 2.0, seconds)
			if age < 7.0:
				var envelope := minf(age * 15.0, 1.0) * exp(-age * 0.85)
				var phase := TAU * float(notes[note]) * age
				value += (sin(phase) + 0.28 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)) * envelope * 0.105
		pcm.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream
