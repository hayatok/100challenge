extends Node
## Local PCM bells and a quiet looping night motif. No network or external audio.

var enabled := true
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_player := 0
var music: AudioStreamPlayer
var context := "title"
var music_started := false
var music_start_count := 0

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
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	music.stream = _night_motif()
	add_child(music)

func play_event(event: String) -> void:
	if not enabled or not sounds.has(event) or players.is_empty():
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

func set_context(value: String) -> void:
	if value == context:
		return
	context = value
	_sync_music()

func _sync_music() -> void:
	if not is_instance_valid(music):
		return
	if not enabled or context in ["title", "victory", "defeat"]:
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
