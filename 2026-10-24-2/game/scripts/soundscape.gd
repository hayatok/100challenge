extends Node

const SAMPLE_RATE := 22050
const VOICE_COUNT := 4
const SILENT_DB := -80.0
const FINISH_STEPS: Array[float] = [0.0, 4.0, 7.0, 12.0]

var _wind: AudioStreamPlayer
var _edge: AudioStreamPlayer
var _charge_voice: AudioStreamPlayer
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_levels: Array[float] = []
var _cues: Dictionary = {}
var _next_voice := 0
var _speed := 0.0
var _boosting := false
var _carve := 0.0
var _charge := 0.0
var _airborne := false
var _volume := 1.0
var _wind_db := -55.0
var _edge_db := -80.0
var _charge_db := -80.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_wind = _make_player("Wind")
	_wind.stream = _make_noise(false)
	_wind.volume_db = SILENT_DB
	_wind.play()
	_edge = _make_player("CarveEdge")
	_edge.stream = _make_noise(true)
	_edge.volume_db = SILENT_DB
	_edge.play()
	_charge_voice = _make_player("WindCharge")
	_charge_voice.stream = _make_charge_loop()
	_charge_voice.volume_db = SILENT_DB
	_charge_voice.play()
	_music = _make_player("SurfPulse")
	_music.stream = _make_music()
	_music.volume_db = -25.0 + _gain_db()
	_music.play()
	for kind in ["jump", "land", "clean", "gate", "hit", "finish", "count", "boost", "release", "near", "trick", "charge"]:
		_cues[kind] = _make_cue(kind)
	for i in VOICE_COUNT:
		_voices.append(_make_player("Cue%d" % i))
		_voice_levels.append(-14.0)


func set_speed(speed: float, boosting: bool) -> void:
	_speed = clampf(speed, 0.0, 50.0)
	_boosting = boosting


func set_motion(carve: float, charge: float, airborne: bool) -> void:
	_carve = clampf(absf(carve), 0.0, 1.0)
	_charge = clampf(charge, 0.0, 1.0)
	_airborne = airborne


func reset_audio() -> void:
	_speed = 0.0
	_boosting = false
	_carve = 0.0
	_charge = 0.0
	_airborne = false
	_wind_db = -55.0
	_edge_db = SILENT_DB
	_charge_db = SILENT_DB
	if not is_instance_valid(_wind):
		return
	for voice in _voices:
		voice.stop()
	_wind.volume_db = _wind_db + _gain_db()
	_edge.volume_db = SILENT_DB
	_charge_voice.volume_db = SILENT_DB


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if not is_instance_valid(_wind):
		return
	_wind.volume_db = _wind_db + _gain_db()
	_edge.volume_db = _edge_db + _gain_db()
	_charge_voice.volume_db = _charge_db + _gain_db()
	_music.volume_db = -25.0 + _gain_db()
	for i in _voices.size():
		_voices[i].volume_db = _voice_levels[i] + _gain_db()


func cue(kind: String) -> void:
	if not _cues.has(kind) or _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	voice.stop()
	voice.stream = _cues[kind]
	var level := -14.0
	match kind:
		"finish", "clean": level = -13.0
		"hit": level = -16.0
		"near", "release": level = -12.0
		"count": level = -18.0
	_voice_levels[_next_voice] = level
	voice.volume_db = level + _gain_db()
	voice.pitch_scale = 1.0
	voice.play()
	_next_voice = (_next_voice + 1) % VOICE_COUNT


func _process(delta: float) -> void:
	if not is_instance_valid(_wind):
		return
	var ratio := clampf(_speed / 38.0, 0.0, 1.0)
	var target_db := -36.0 + ratio * 16.0 + (2.0 if _boosting else 0.0)
	if _speed < 0.5:
		target_db = -55.0
	var response := 1.0 - exp(-8.0 * delta)
	_wind_db = lerpf(_wind_db, target_db, response)
	_wind.volume_db = _wind_db + _gain_db()
	_wind.pitch_scale = lerpf(_wind.pitch_scale, 0.75 + ratio * 0.6 + (0.16 if _airborne else 0.0), response)
	var edge_target := -31.0 + _carve * 12.0 if _carve > 0.10 and not _airborne and _speed > 4.0 else SILENT_DB
	_edge_db = lerpf(_edge_db, edge_target, response)
	_edge.volume_db = _edge_db + _gain_db()
	_edge.pitch_scale = 0.75 + _carve * 0.6
	var charge_target := -32.0 + _charge * 13.0 if _charge > 0.05 and _carve > 0.1 else SILENT_DB
	_charge_db = lerpf(_charge_db, charge_target, response)
	_charge_voice.volume_db = _charge_db + _gain_db()
	_charge_voice.pitch_scale = 0.8 + _charge * 1.25


func _gain_db() -> float:
	return linear_to_db(_volume) if _volume > 0.0 else SILENT_DB


func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	return player


func _make_noise(edge: bool) -> AudioStreamWAV:
	var count := SAMPLE_RATE * 2
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9031 if edge else 73019
	var low_pass := 0.0
	var previous := 0.0
	for i in count:
		var white := rng.randf_range(-1.0, 1.0)
		low_pass = lerpf(low_pass, white, 0.40 if edge else 0.12)
		var air := low_pass - previous * (0.92 if edge else 0.45)
		previous = low_pass
		var time := float(i) / float(SAMPLE_RATE)
		var swell := 0.72 + sin(TAU * time * (29.0 if edge else 0.5)) * 0.18
		samples[i] = air * swell * (1.8 if edge else 1.0)
	const SEAM := 512
	for i in SEAM:
		var blend := float(i) / float(SEAM - 1)
		samples[count - SEAM + i] = lerpf(samples[count - SEAM + i], samples[i], blend)
	return _wave(samples, true, SEAM)


func _make_charge_loop() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(SAMPLE_RATE)
	for i in SAMPLE_RATE:
		var time := float(i) / float(SAMPLE_RATE)
		var pulse := 0.70 + sin(TAU * 8.0 * time) * 0.25
		samples[i] = (sin(TAU * 220.0 * time) * 0.27 + sin(TAU * 330.0 * time) * 0.13) * pulse
	return _wave(samples, true)


func _make_music() -> AudioStreamWAV:
	var count := SAMPLE_RATE * 8
	var samples := PackedFloat32Array()
	samples.resize(count)
	var chords: Array[PackedFloat32Array] = [
		PackedFloat32Array([146.8324, 220.0, 277.1826, 369.9944]),
		PackedFloat32Array([138.5913, 220.0, 246.9417, 329.6276]),
		PackedFloat32Array([123.4708, 184.9972, 246.9417, 293.6648]),
		PackedFloat32Array([146.8324, 195.9977, 246.9417, 293.6648])]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19378
	for i in count:
		var time := float(i) / float(SAMPLE_RATE)
		var chord_index := mini(3, int(time / 2.0))
		var local_time := fmod(time, 2.0)
		var envelope := pow(sin(PI * local_time / 2.0), 1.5)
		var sample := 0.0
		for frequency in chords[chord_index]:
			sample += sin(TAU * frequency * local_time) * 0.030 * envelope
		var beat := fmod(time, 0.5)
		sample += sin(TAU * (48.0 * beat + 2.8 * (1.0 - exp(-beat * 45.0)))) * exp(-beat * 18.0) * 0.19
		var hat := fmod(time + 0.25, 0.5)
		sample += rng.randf_range(-1.0, 1.0) * exp(-hat * 75.0) * 0.065
		var pluck := fmod(time, 0.25)
		var note := chords[chord_index][int(time * 4.0) % 4] * 2.0
		sample += sin(TAU * note * pluck) * exp(-pluck * 25.0) * 0.045
		samples[i] = sample
	return _wave(samples, true)


func _make_cue(kind: String) -> AudioStreamWAV:
	var duration := 0.24
	var start_hz := 440.0
	var end_hz := 660.0
	match kind:
		"jump":
			duration = 0.20
			start_hz = 240.0
			end_hz = 850.0
		"land", "clean":
			duration = 0.25 if kind == "land" else 0.38
			start_hz = 145.0
			end_hz = 60.0
		"gate", "trick":
			duration = 0.35
			start_hz = 660.0
			end_hz = 990.0
		"hit":
			duration = 0.22
			start_hz = 110.0
			end_hz = 48.0
		"finish":
			duration = 1.10
			start_hz = 523.2511
			end_hz = 1046.5022
		"count":
			duration = 0.10
			start_hz = 880.0
			end_hz = 880.0
		"boost", "release":
			duration = 0.40
			start_hz = 100.0
			end_hz = 650.0
		"near":
			duration = 0.22
			start_hz = 1100.0
			end_hz = 260.0
		"charge":
			duration = 0.16
			start_hz = 330.0
			end_hz = 495.0
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var noise := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9812 + kind.hash()
	for i in count:
		var time := float(i) / float(SAMPLE_RATE)
		var normalized := time / duration
		var frequency := lerpf(start_hz, end_hz, normalized)
		if kind == "finish":
			frequency = start_hz * pow(2.0, FINISH_STEPS[mini(3, int(normalized * 4.0))] / 12.0)
		phase += TAU * frequency / float(SAMPLE_RATE)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.32)
		var envelope := minf(1.0, time / 0.005) * pow(1.0 - normalized, 1.7)
		var sample := sin(phase) * 0.32 + sin(phase * 2.0) * 0.07
		match kind:
			"jump": sample = noise * 0.60 + sin(phase) * 0.17
			"boost", "release": sample = noise * 0.85 + sin(phase) * 0.22 + sin(phase * 0.5) * 0.14
			"near": sample = noise * 0.85 + sin(phase) * sin(PI * normalized) * 0.12
			"land", "clean": sample = sin(phase) * 0.48 + noise * exp(-time * 40.0) * 0.6
			"hit": sample = noise * 0.72 + sin(phase) * 0.35 + sin(phase * 1.43) * 0.2
			"gate", "trick", "finish": sample += sin(phase * 1.5) * 0.15
		if kind == "clean":
			sample += sin(TAU * 1320.0 * time) * 0.14 * exp(-time * 7.0)
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
