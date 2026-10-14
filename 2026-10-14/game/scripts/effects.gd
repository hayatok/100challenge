extends Node3D

const AssetLibrary := preload("res://scripts/asset_library.gd")

const SAMPLE_RATE := 22050
const MAX_PARTICLES := 80

var _particles: Array[Dictionary] = []
var _material: StandardMaterial3D
var _powder_mesh: Mesh
var _paper_mesh: Mesh
var _cube_mesh: Mesh
var _quality := "派手"
var _music_volume := 0.45
var _sfx_volume := 0.75
var _ready_once := false
var _spraying := false
var _rush := false
var _at := Vector3.ZERO
var _backward := Vector3.BACK
var _exhaust_clock := 0.0
var _noise: AudioStreamPlayer
var _music: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _combo_player: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _combo_streams: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _audio_enabled := DisplayServer.get_name() != "headless"

func setup() -> void:
	if _ready_once:
		return
	_ready_once = true
	_rng.randomize()
	# Small modeled shapes share an unshaded vertex-color material and no shadows.
	_powder_mesh = AssetLibrary.particle_mesh("fx_powder")
	_paper_mesh = AssetLibrary.particle_mesh("fx_paper")
	_cube_mesh = AssetLibrary.particle_mesh("fx_cube")
	_material = AssetLibrary.particle_material()
	_noise = _audio("Extinguisher", _make_noise(), -19.0)
	_impact = _audio("PaperImpact", _make_impact(), -10.0)
	_impact.max_polyphony = 3
	_combo_player = _audio("Combo", _make_notes([523.25], 0.14), -13.0)
	_victory = _audio("ClockOut", _make_notes([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.16), -11.0)
	for count in 8:
		_combo_streams.append(_make_notes([261.63 * pow(2.0, count / 12.0), 523.25 * pow(2.0, count / 12.0)], 0.075))
	_music = _audio("OfficeSynth", _make_music(), -23.0)
	set_volumes(_music_volume, _sfx_volume)
	if _audio_enabled:
		_music.play()

func _audio(audio_name: String, stream: AudioStreamWAV, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = audio_name
	player.stream = stream
	player.set_meta("base_db", base_db)
	add_child(player)
	return player

func set_quality(level: String) -> void:
	_quality = level
	while _particles.size() > _limit():
		var oldest: Dictionary = _particles.pop_front()
		(oldest["node"] as MeshInstance3D).queue_free()

func set_volumes(music: float, sfx: float) -> void:
	_music_volume = clampf(music, 0.0, 1.0)
	_sfx_volume = clampf(sfx, 0.0, 1.0)
	if not _ready_once:
		return
	_apply_volume(_music, _music_volume)
	for player in [_noise, _impact, _combo_player, _victory]:
		_apply_volume(player, _sfx_volume)

func _apply_volume(player: AudioStreamPlayer, value: float) -> void:
	player.volume_db = float(player.get_meta("base_db")) + linear_to_db(maxf(value, 0.00001))
	player.volume_linear = 0.0 if value <= 0.0 else db_to_linear(player.volume_db)

func set_exhaust(at: Vector3, backward: Vector3, spraying: bool, rush: bool) -> void:
	_at = at
	_backward = backward.normalized() if backward.length_squared() > 0.001 else Vector3.BACK
	_spraying = spraying
	_rush = rush
	if not _ready_once:
		return
	if not _audio_enabled:
		return
	if spraying and not _noise.playing:
		_noise.play()
	elif not spraying and _noise.playing:
		_noise.stop()

func _limit() -> int:
	return 20 if _quality == "控えめ" else (52 if _quality == "標準" else MAX_PARTICLES)

func _density() -> float:
	return 0.25 if _quality == "控えめ" else (0.65 if _quality == "標準" else 1.0)

func _spawn(at: Vector3, velocity: Vector3, kind: int, duration: float) -> void:
	if not _ready_once or _particles.size() >= _limit():
		return
	var node := MeshInstance3D.new()
	node.mesh = _powder_mesh if kind == 0 else (_paper_mesh if kind == 1 else _cube_mesh)
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = at
	node.rotation = Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
	var size_factor := _rng.randf_range(0.65, 1.2)
	node.scale = Vector3.ONE * size_factor
	_particles.append({"node": node, "velocity": velocity, "life": duration, "duration": duration, "kind": kind, "size": size_factor, "spin": Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-4, 4), _rng.randf_range(-3, 3))})

func burst(at: Vector3, strength: float = 1.0) -> void:
	if not _ready_once:
		return
	var amount := roundi(22 * _density() * clampf(strength, 0.6, 1.5))
	for index in amount:
		var angle := _rng.randf_range(0, TAU)
		var velocity := Vector3(cos(angle) * _rng.randf_range(1.2, 3.0), _rng.randf_range(1.5, 3.4), sin(angle) * _rng.randf_range(1.2, 3.0))
		var kind := 2 if index % 7 == 0 else 1
		_spawn(at + Vector3(0, 0.55, 0), velocity, kind, _rng.randf_range(0.65, 1.25))
	_impact.pitch_scale = _rng.randf_range(0.9, 1.1)
	if _audio_enabled:
		_impact.play()

func play_combo(count: int) -> void:
	if not _ready_once or not _audio_enabled:
		return
	_combo_player.stream = _combo_streams[clampi(count - 1, 0, 7)]
	_combo_player.play()

func celebrate(at: Vector3) -> void:
	if not _ready_once:
		return
	# Small fans at each side of the actor leave the face and the exit visible.
	for index in roundi(38 * _density()):
		var side := -1.0 if index % 2 == 0 else 1.0
		var origin := at + Vector3(side * 1.2, 0.7, 0)
		var velocity := Vector3(side * _rng.randf_range(0.6, 2.8), _rng.randf_range(2.5, 5.0), _rng.randf_range(-0.8, 1.7))
		_spawn(origin, velocity, 2 if index % 5 == 0 else 1, _rng.randf_range(1.0, 1.8))
	_noise.stop()
	_spraying = false
	if _audio_enabled:
		_victory.play()

func _process(delta: float) -> void:
	if not _ready_once:
		return
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle["life"] = float(particle["life"]) - delta
		var node := particle["node"] as MeshInstance3D
		if float(particle["life"]) <= 0.0:
			node.queue_free()
			_particles.remove_at(index)
			continue
		var velocity: Vector3 = particle["velocity"]
		if int(particle["kind"]) == 0:
			velocity *= exp(-1.4 * delta)
			velocity.y += 0.35 * delta
		else:
			velocity.y -= 5.0 * delta
			velocity.x *= exp(-0.55 * delta)
			velocity.z *= exp(-0.55 * delta)
		particle["velocity"] = velocity
		node.position += velocity * delta
		node.rotation += (particle["spin"] as Vector3) * delta
		var fade := minf(1.0, float(particle["life"]) / 0.22)
		node.scale = Vector3.ONE * float(particle["size"]) * fade
		_particles[index] = particle
	if _spraying:
		_exhaust_clock += delta
		var period := 1.0 / (38.0 * _density())
		while _exhaust_clock >= period:
			_exhaust_clock -= period
			var jitter := Vector3(_rng.randf_range(-0.14, 0.14), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.14, 0.14))
			var origin := _at
			_spawn(origin + jitter, _backward * _rng.randf_range(2.0, 4.0) + Vector3(0, 0.4, 0) + jitter, 0, _rng.randf_range(0.3, 0.65))
			if _rush and _rng.randf() < 0.22:
				_spawn(origin, _backward * 3 + Vector3(_rng.randf_range(-1, 1), 1, 0), 2, 0.45)
	else:
		_exhaust_clock = 0.0

func _notification(what: int) -> void:
	if not _ready_once:
		return
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		for player in [_noise, _music, _impact, _combo_player, _victory]:
			if is_instance_valid(player):
				player.stream_paused = what == NOTIFICATION_PAUSED

func _exit_tree() -> void:
	for player in [_noise, _music, _impact, _combo_player, _victory]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, clampi(roundi(samples[index] * 32767), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

func _make_noise() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(SAMPLE_RATE)
	var smooth := 0.0
	for index in samples.size():
		smooth = smooth * 0.62 + _rng.randf_range(-1, 1) * 0.38
		samples[index] = smooth * 0.65
	return _wav(samples, true)

func _make_impact() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(roundi(SAMPLE_RATE * 0.22))
	for index in samples.size():
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 22.0) * minf(time * 1500, 1.0)
		samples[index] = (sin(TAU * (135 * time - 80 * time * time)) * 0.5 + _rng.randf_range(-1, 1) * 0.4) * envelope
	return _wav(samples)

func _make_notes(notes: Array, length: float) -> AudioStreamWAV:
	var note_samples := roundi(SAMPLE_RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(note_samples * notes.size())
	for note_index in notes.size():
		for index in note_samples:
			var time := float(index) / SAMPLE_RATE
			var envelope := minf(time / 0.006, 1.0) * pow(maxf(0.0, 1.0 - time / length), 1.4)
			var phase := TAU * float(notes[note_index]) * time
			samples[note_index * note_samples + index] = (sin(phase) * 0.68 + sin(phase * 2) * 0.2 + sin(phase * 3) * 0.08) * envelope * 0.7
	return _wav(samples)

func _make_music() -> AudioStreamWAV:
	var melody := [523.25, 0.0, 659.25, 783.99, 659.25, 523.25, 392.0, 0.0, 440.0, 523.25, 659.25, 523.25, 392.0, 440.0, 493.88, 0.0]
	var bass := [130.81, 130.81, 110.0, 98.0]
	var step := 0.22
	var count := roundi(SAMPLE_RATE * step * melody.size())
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in count:
		var time := float(index) / SAMPLE_RATE
		var note_index := mini(int(time / step), melody.size() - 1)
		var local_time := fmod(time, step)
		var envelope := minf(local_time / 0.012, 1.0) * maxf(0.0, 1.0 - local_time / step)
		var lead := sin(TAU * float(melody[note_index]) * local_time) * 0.22 if float(melody[note_index]) > 0.0 else 0.0
		var low := sin(TAU * float(bass[note_index / 4]) * time) * 0.16
		var tick := _rng.randf_range(-1, 1) * exp(-local_time * 95) * 0.08
		samples[index] = (lead + low) * envelope + tick
	return _wav(samples, true)
