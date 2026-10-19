extends Node
## Short local PCM tones. No network, audio asset licence or background music.

var enabled := true
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_player := 0
var last_cast_time := -1.0

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

func pause_all(paused: bool) -> void:
	for player in players:
		player.stream_paused = paused

func stop_all() -> void:
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
