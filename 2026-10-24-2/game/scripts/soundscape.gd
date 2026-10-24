extends Node

const SAMPLE_RATE: int = 22050
const VOICE_COUNT: int = 4
const SILENT_DB: float = -80.0
const FINISH_STEPS: Array[float] = [0.0, 4.0, 7.0, 12.0]

var _wind: AudioStreamPlayer
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_levels: Array[float] = []
var _cues: Dictionary = {}
var _next_voice: int = 0
var _speed: float = 0.0
var _boosting: bool = false
var _volume: float = 1.0
var _wind_db: float = -55.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_wind = _make_player("Wind")
	_wind.stream = _make_wind()
	_wind.volume_db = _wind_db + _gain_db()
	_wind.pitch_scale = 0.7
	_wind.play()
	_music = _make_player("PrototypeChords")
	_music.stream = _make_music()
	_music.volume_db = -23.0 + _gain_db()
	_music.play()
	for kind in ["jump", "land", "gate", "hit", "finish", "count", "boost"]:
		_cues[kind] = _make_cue(kind)
	for i in VOICE_COUNT:
		_voices.append(_make_player("Cue%d" % i))
		_voice_levels.append(-14.0)


func set_speed(speed: float, boosting: bool) -> void:
	_speed = clampf(speed, 0.0, 40.0)
	_boosting = boosting


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if not is_instance_valid(_wind):
		return
	_wind.volume_db = _wind_db + _gain_db()
	_music.volume_db = -23.0 + _gain_db()
	for i in _voices.size():
		_voices[i].volume_db = _voice_levels[i] + _gain_db()


func cue(kind: String) -> void:
	if not _cues.has(kind) or _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	voice.stop()
	voice.stream = _cues[kind]
	var level := -14.0
	if kind == "finish":
		level = -12.0
	elif kind == "hit":
		level = -17.0
	_voice_levels[_next_voice] = level
	voice.volume_db = level + _gain_db()
	voice.pitch_scale = 1.0
	voice.play()
	_next_voice = (_next_voice + 1) % VOICE_COUNT


func _process(delta: float) -> void:
	if not is_instance_valid(_wind):
		return
	var speed_ratio := clampf(_speed / 34.0, 0.0, 1.0)
	var target_db := -34.0 + speed_ratio * 17.0 + (3.0 if _boosting else 0.0)
	if _speed < 0.5:
		target_db = -55.0
	var response := 1.0 - exp(-4.0 * delta)
	_wind_db = lerpf(_wind_db, target_db, response)
	_wind.volume_db = _wind_db + _gain_db()
	var target_pitch := 0.7 + speed_ratio * 0.55 + (0.12 if _boosting else 0.0)
	_wind.pitch_scale = lerpf(_wind.pitch_scale, target_pitch, response)


func _gain_db() -> float:
	return linear_to_db(_volume) if _volume > 0.0 else SILENT_DB


func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	return player


func _make_wind() -> AudioStreamWAV:
	var count := SAMPLE_RATE * 2
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73019
	var low_pass := 0.0
	var previous := 0.0
	for i in count:
		var white := rng.randf_range(-1.0, 1.0)
		low_pass = lerpf(low_pass, white, 0.24)
		var air := low_pass - previous * 0.45
		previous = low_pass
		var swell := 0.78 + sin(TAU * float(i) / float(count)) * 0.12
		samples[i] = air * swell
	# Crossfade the tail into the same noise sequence used by the loop head.
	const SEAM: int = 512
	for i in SEAM:
		var blend := float(i) / float(SEAM - 1)
		samples[count - SEAM + i] = lerpf(samples[count - SEAM + i], samples[i], blend)
	# The head follows the crossfade's end, avoiding a discontinuous final sample.
	return _wave(samples, true, SEAM)


func _make_music() -> AudioStreamWAV:
	var count := SAMPLE_RATE * 8
	var samples := PackedFloat32Array()
	samples.resize(count)
	var chords: Array[PackedFloat32Array] = [
		PackedFloat32Array([146.8324, 220.0, 277.1826, 369.9944]),
		PackedFloat32Array([138.5913, 220.0, 246.9417, 329.6276]),
		PackedFloat32Array([123.4708, 184.9972, 246.9417, 293.6648]),
		PackedFloat32Array([146.8324, 195.9977, 246.9417, 293.6648])
	]
	for i in count:
		var time := float(i) / float(SAMPLE_RATE)
		var chord_index := mini(3, int(time / 2.0))
		var local_time := fmod(time, 2.0)
		var envelope := pow(sin(PI * local_time / 2.0), 1.5)
		var sample := 0.0
		for frequency in chords[chord_index]:
			sample += sin(TAU * frequency * local_time) * 0.042
			sample += sin(TAU * frequency * 2.0 * local_time) * 0.009
		samples[i] = sample * envelope
	return _wave(samples, true)


func _make_cue(kind: String) -> AudioStreamWAV:
	var duration := 0.24
	var start_hz := 440.0
	var end_hz := 660.0
	match kind:
		"jump":
			duration = 0.18
			start_hz = 360.0
			end_hz = 720.0
		"land":
			duration = 0.20
			start_hz = 210.0
			end_hz = 110.0
		"gate":
			duration = 0.40
			start_hz = 660.0
			end_hz = 990.0
		"hit":
			duration = 0.22
			start_hz = 170.0
			end_hz = 75.0
		"finish":
			duration = 1.10
			start_hz = 523.2511
			end_hz = 1046.5022
		"count":
			duration = 0.10
			start_hz = 880.0
			end_hz = 880.0
		"boost":
			duration = 0.36
			start_hz = 220.0
			end_hz = 880.0
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var time := float(i) / float(SAMPLE_RATE)
		var normalized := time / duration
		var frequency := lerpf(start_hz, end_hz, normalized)
		if kind == "finish":
			var semitone: float = FINISH_STEPS[mini(3, int(normalized * 4.0))]
			frequency = start_hz * pow(2.0, semitone / 12.0)
		phase += TAU * frequency / float(SAMPLE_RATE)
		var envelope := minf(1.0, time / 0.008) * pow(1.0 - normalized, 1.7)
		var sample := sin(phase) * 0.40 + sin(phase * 2.0) * 0.10
		if kind == "hit":
			sample = sin(phase) * 0.30 + sin(phase * 1.43) * 0.17
		elif kind == "gate" or kind == "finish":
			sample += sin(phase * 1.5) * 0.15
		samples[i] = sample * envelope
	return _wave(samples)


func _wave(samples: PackedFloat32Array, looped: bool = false, loop_start: int = 0) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = loop_start
		stream.loop_end = samples.size()
	return stream
