extends Node3D
## Pausable, bounded world feedback. Seven shared mesh batches; no particle nodes.

const AssetLibrary := preload("res://scripts/asset_library.gd")
const GraphicMeshes := preload("res://scripts/fx/graphic_meshes.gd")
const SAMPLE_RATE := 22050
const MAX_PARTICLES := 80
const POWDER := 0
const PAPER := 1
const CUBE := 2
const STAR := 3
const RING := 4
const STREAK := 5
const RIBBON := 6
const PALETTE := [Color("ffd45b"), Color("f36a99"), Color("159b9c"), Color("f4433e")]

var _particles: Array[Dictionary] = []
var _batches: Array[MultiMeshInstance3D] = []
var _quality := "派手"
var _music_volume := 0.45
var _sfx_volume := 0.75
var _ready_once := false
var _spraying := false
var _rush := false
var _at := Vector3.ZERO
var _backward := Vector3.BACK
var _exhaust_clock := 0.0
var _rush_starts := 0
var _combo_cues := 0
var _last_combo := 0
var _particle_clock := 0.0
var _noise: AudioStreamPlayer
var _music: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _combo_player: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _rush_player: AudioStreamPlayer
var _onset: AudioStreamPlayer
var _combo_streams: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _audio_enabled := DisplayServer.get_name() != "headless"

func setup() -> void:
	if _ready_once:
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ready_once = true
	_rng.randomize()
	var powder_material := AssetLibrary.particle_material().duplicate() as StandardMaterial3D
	powder_material.next_pass = _outline(Color("159b9c"), 0.027)
	var paper_material := AssetLibrary.particle_material().duplicate() as StandardMaterial3D
	paper_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var graphic_material := AssetLibrary.particle_material().duplicate() as StandardMaterial3D
	graphic_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes: Array[Mesh] = [AssetLibrary.particle_mesh("fx_powder"), GraphicMeshes.outlined_paper(AssetLibrary.particle_mesh("fx_paper")), AssetLibrary.particle_mesh("fx_cube"), GraphicMeshes.star(), GraphicMeshes.ring(), GraphicMeshes.streak(), GraphicMeshes.ribbon()]
	for kind in meshes.size():
		var batch := MultiMeshInstance3D.new()
		batch.name = ["Powder", "StampedPaper", "GoldCubes", "ImpactStars", "ImpactRings", "JetStreaks", "CelebrationRibbons"][kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = meshes[kind]
		multi.instance_count = MAX_PARTICLES
		multi.visible_instance_count = 0
		# A bounded effect area follows the course; avoids per-instance bounds work.
		multi.custom_aabb = AABB(Vector3(-120, -20, -120), Vector3(240, 80, 240))
		batch.multimesh = multi
		batch.material_override = powder_material if kind == POWDER else (paper_material if kind == PAPER else graphic_material)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		_batches.append(batch)
	_noise = _audio("Extinguisher", _make_noise(), -19.0)
	_onset = _audio("JetSnap", _make_snap(), -19.0)
	_impact = _audio("PaperImpact", _make_impact(), -10.0)
	_impact.max_polyphony = 3
	_combo_player = _audio("Combo", _make_notes([523.25], 0.14), -13.0)
	_rush_player = _audio("RushStinger", _make_notes([523.25, 783.99, 1046.5, 1567.98], 0.055), -13.0)
	_victory = _audio("ClockOut", _make_stamp(), -11.0)
	for count in 8:
		_combo_streams.append(_make_notes([261.63 * pow(2.0, count / 12.0), 523.25 * pow(2.0, count / 12.0)], 0.075))
	_music = _audio("OfficeSynth", _make_music(), -23.0)
	set_volumes(_music_volume, _sfx_volume)
	if _audio_enabled and _music_volume > 0.0:
		_music.play()

func _outline(color: Color, width: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = width
	return material

func _audio(audio_name: String, stream: AudioStreamWAV, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = audio_name
	player.stream = stream
	player.set_meta("base_db", base_db)
	add_child(player)
	return player

func _audio_players() -> Array:
	return [_noise, _music, _impact, _combo_player, _victory, _rush_player, _onset]

func set_quality(level: String) -> void:
	_quality = level
	if level == "控えめ":
		for index in range(_particles.size() - 1, -1, -1):
			if int(_particles[index]["kind"]) == STREAK:
				_particles.remove_at(index)
	while _particles.size() > _limit():
		_retire_one()
	_publish_batches()

func set_volumes(music: float, sfx: float) -> void:
	_music_volume = clampf(music, 0.0, 1.0)
	_sfx_volume = clampf(sfx, 0.0, 1.0)
	if not _ready_once:
		return
	_apply_volume(_music, _music_volume)
	for player in [_noise, _impact, _combo_player, _victory, _rush_player, _onset]:
		_apply_volume(player, _sfx_volume)

func _apply_volume(player: AudioStreamPlayer, value: float) -> void:
	player.volume_db = float(player.get_meta("base_db")) + linear_to_db(maxf(value, 0.00001))
	if value <= 0.0:
		player.stop()
	elif player == _music and _audio_enabled and not player.playing:
		player.play()

func set_exhaust(at: Vector3, backward: Vector3, spraying: bool, rush: bool) -> void:
	_at = at
	_backward = backward.normalized() if backward.length_squared() > 0.001 else Vector3.BACK
	var onset := spraying and not _spraying
	_spraying = spraying
	_rush = rush
	if not _ready_once:
		return
	if onset:
		_exhaust_clock = 0.0
		for index in (2 if _quality == "控えめ" else 5):
			var distance := 0.12 + float(index) * 0.22
			_spawn(_at + _backward * distance, _backward * 3.3, POWDER, 0.48, 0.45 + distance * 0.7, 0)
		if _audio_enabled and _sfx_volume > 0.0:
			_onset.play()
		_publish_batches()
	if _audio_enabled and _sfx_volume > 0.0 and spraying and not _noise.playing:
		_noise.play()
	elif not spraying:
		_noise.stop()

func _limit() -> int:
	return 20 if _quality == "控えめ" else (52 if _quality == "標準" else MAX_PARTICLES)

func _density() -> float:
	return 0.25 if _quality == "控えめ" else (0.65 if _quality == "標準" else 1.0)

func _reserve() -> int:
	return 6 if _quality == "控えめ" else (20 if _quality == "標準" else 28)

func _retire_one() -> void:
	# Important feedback replaces exhaust first, then the oldest event fragment.
	for index in _particles.size():
		if int(_particles[index]["priority"]) == 0:
			_particles.remove_at(index)
			return
	for index in _particles.size():
		if int(_particles[index]["priority"]) == 1:
			_particles.remove_at(index)
			return
	if not _particles.is_empty():
		_particles.pop_front()

func _spawn(at: Vector3, velocity: Vector3, kind: int, duration: float, size: float = 1.0, priority: int = 1, basis: Basis = Basis.IDENTITY, color: Color = Color.WHITE) -> void:
	if not _ready_once:
		return
	if priority == 0:
		var exhaust_count := 0
		for particle in _particles:
			if int(particle["priority"]) == 0:
				exhaust_count += 1
		if exhaust_count >= _limit() - _reserve() or _particles.size() >= _limit():
			return
	else:
		while _particles.size() >= _limit():
			_retire_one()
	var spin := Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-4, 4), _rng.randf_range(-3, 3))
	if kind == STAR or kind == RING or kind == STREAK:
		spin = Vector3.ZERO
	_particles.append({"position": at, "velocity": velocity, "life": duration, "duration": duration, "kind": kind, "size": size, "spin": spin, "basis": basis, "color": color, "priority": priority, "new": true})

func _camera_basis() -> Basis:
	var camera := get_viewport().get_camera_3d()
	return camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY

func _contact(at: Vector3, strength: float) -> void:
	var size := (0.38 if _quality == "控えめ" else 0.78) * clampf(strength, 0.6, 1.5)
	_spawn(at, Vector3.ZERO, STAR, 0.16, size, 2)
	_spawn(at, Vector3.ZERO, RING, 0.18, size * 1.35, 2, Basis.IDENTITY, Color("ffd45b"))
	if _quality != "控えめ":
		_spawn(at, Vector3.ZERO, RING, 0.18, size * 1.65, 2, Basis.IDENTITY, Color("c4faff"))

func _paper_fan(at: Vector3, normal: Vector3, strength: float, amount: int) -> void:
	var forward := normal.normalized() if normal.length_squared() > 0.01 else Vector3.BACK
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	for index in amount:
		var spread := lerpf(-1.0, 1.0, float(index) / maxf(1, amount - 1))
		var velocity := side * spread * _rng.randf_range(2.0, 3.4) + forward * _rng.randf_range(0.2, 1.2) + Vector3.UP * _rng.randf_range(1.4, 3.2)
		if _quality == "控えめ":
			velocity *= 0.45
		var kind := CUBE if index % 6 == 0 else PAPER
		var basis := _camera_basis().rotated(_camera_basis().z, spread * 0.65)
		if kind == PAPER:
			basis = basis * Basis(Vector3.UP, PI)
		var spread_size := 0.22 if _quality == "控えめ" else 0.85
		var origin := at + side * spread * spread_size + Vector3.UP * (0.18 + (1.0 - absf(spread)) * spread_size)
		var size := _rng.randf_range(1.5, 2.15) if kind == PAPER else _rng.randf_range(2.0, 2.8)
		_spawn(origin, velocity * clampf(strength, 0.6, 1.3), kind, _rng.randf_range(0.65, 1.12), size, 1, basis)

func burst(at: Vector3, strength: float = 1.0) -> void:
	if not _ready_once:
		return
	var center := at + Vector3.UP * 0.55
	_contact(center, strength)
	_paper_fan(center, _backward, strength, roundi(22 * _density() * clampf(strength, 0.6, 1.5)))
	_play_impact()
	_publish_batches()

func impact(at: Vector3, normal: Vector3, strength: float = 1.0) -> void:
	if not _ready_once:
		return
	var center := at + normal.normalized() * 0.08
	_contact(center, strength)
	_paper_fan(center, normal, strength, roundi(9 * _density()))
	_play_impact()
	_publish_batches()

func _play_impact() -> void:
	_impact.pitch_scale = _rng.randf_range(0.93, 1.07)
	if _audio_enabled and _sfx_volume > 0.0:
		_impact.play()

func play_combo(count: int) -> void:
	if not _ready_once:
		return
	_combo_cues += 1
	_last_combo = count
	if not _audio_enabled or _sfx_volume <= 0.0:
		return
	_combo_player.stream = _combo_streams[clampi(count - 1, 0, 7)]
	_combo_player.play()

func start_rush(at: Vector3) -> void:
	if not _ready_once:
		return
	_rush_starts += 1
	if _quality != "控えめ":
		# Local side accents; the actor and route remain open in the center.
		var side := _backward.cross(Vector3.UP).normalized()
		for index in roundi(8 * _density()):
			var sign_side := -1.0 if index % 2 == 0 else 1.0
			_spawn(at + side * sign_side * 0.85 + Vector3.UP * 0.55, side * sign_side * 2 + Vector3.UP, RIBBON, 0.45, 0.65, 1, _camera_basis(), PALETTE[index % 2])
	if _audio_enabled and _sfx_volume > 0.0:
		_rush_player.play()
	_publish_batches()

func celebrate(at: Vector3) -> void:
	if not _ready_once:
		return
	var side_axis := _camera_basis().x
	for index in roundi(44 * _density()):
		var side := -1.0 if index % 2 == 0 else 1.0
		var fan := float((index / 2) % 7) / 6.0
		var origin := at + side_axis * side * (1.0 + fan * 0.35) + Vector3.UP * _rng.randf_range(-0.35, 0.2)
		var velocity := side_axis * side * lerpf(1.2, 4.0, fan) + Vector3.UP * lerpf(5.0, 2.4, fan) + _backward * _rng.randf_range(-0.1, 0.7)
		if _quality == "控えめ":
			velocity *= 0.45
		var kind := PAPER if index % 4 == 0 else (CUBE if index % 7 == 0 else RIBBON)
		var color: Color = PALETTE[(index / 2) % PALETTE.size()] if kind == RIBBON else Color.WHITE
		var size := _rng.randf_range(1.6, 2.2) if kind == PAPER or kind == CUBE else _rng.randf_range(0.55, 1.0)
		var basis := _camera_basis().rotated(_camera_basis().z, side * lerpf(0.1, 0.9, fan))
		if kind == PAPER:
			basis = basis * Basis(Vector3.UP, PI)
		_spawn(origin, velocity, kind, _rng.randf_range(0.9, 1.2), size, 2, basis, color)
	_noise.stop()
	_spraying = false
	_exhaust_clock = 0.0
	if _audio_enabled and _sfx_volume > 0.0:
		_victory.play()
	_publish_batches()

func _process(delta: float) -> void:
	if not _ready_once:
		return
	_particle_clock += delta
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		# Births keep a complete peak render, even after a long/slow frame.
		if bool(particle["new"]):
			particle["new"] = false
			continue
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(index)
			continue
		var kind := int(particle["kind"])
		var velocity: Vector3 = particle["velocity"]
		if kind == POWDER:
			velocity *= exp(-0.7 * delta)
			velocity.y += 0.17 * delta
		elif kind == PAPER or kind == CUBE or kind == RIBBON:
			velocity.y -= (3.4 if kind == RIBBON else 4.5) * delta
			velocity.x *= exp(-0.55 * delta)
			velocity.z *= exp(-0.55 * delta)
		particle["velocity"] = velocity
		particle["position"] = (particle["position"] as Vector3) + velocity * delta
		var spin: Vector3 = particle["spin"]
		if _quality == "控えめ":
			spin *= 0.18
		particle["basis"] = (particle["basis"] as Basis) * Basis.from_euler(spin * delta)
	if _spraying:
		_exhaust_clock += delta
		var period := 1.0 / (30.0 * _density())
		var emissions := mini(4, int(_exhaust_clock / period))
		_exhaust_clock = fmod(_exhaust_clock, period)
		for index in emissions:
			var jitter := Vector3(_rng.randf_range(-0.07, 0.07), _rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.07, 0.07))
			_spawn(_at + _backward * 0.12 + jitter, _backward * (4.1 if _rush else 3.7) + Vector3.UP * 0.18, POWDER, 0.68, _rng.randf_range(0.48, 0.66), 0)
			if _quality != "控えめ" and index % 2 == 0:
				var axis := _backward.cross(Vector3.UP).normalized()
				var basis := Basis(axis, _backward, axis.cross(_backward)).orthonormalized()
				_spawn(_at + axis * _rng.randf_range(-0.2, 0.2), _backward * 4.3, STREAK, 0.19, _rng.randf_range(0.75, 1.15), 0, basis)
	else:
		_exhaust_clock = 0.0
	_publish_batches()

func _publish_batches() -> void:
	if _batches.is_empty():
		return
	var counts := [0, 0, 0, 0, 0, 0, 0]
	var camera_basis := _camera_basis()
	for particle in _particles:
		var kind := int(particle["kind"])
		var age := float(particle["duration"]) - float(particle["life"])
		var size := float(particle["size"])
		var fade := minf(1.0, float(particle["life"]) / (0.08 if kind == STAR or kind == RING else 0.16))
		if kind == POWDER:
			# Powder grows continuously: a narrow nozzle opens into a 2–3m rear cone.
			size *= 1.0 + age * (4.7 if _quality != "控えめ" else 1.3)
		elif kind == RING:
			size *= 1.0 + age * 2.1
		var basis: Basis = camera_basis if kind == STAR or kind == RING else particle["basis"]
		var transform := Transform3D(basis.scaled(Vector3.ONE * size * fade), particle["position"])
		var slot := int(counts[kind])
		_batches[kind].multimesh.set_instance_transform(slot, transform)
		_batches[kind].multimesh.set_instance_color(slot, particle["color"])
		counts[kind] += 1
	for kind in _batches.size():
		_batches[kind].multimesh.visible_instance_count = counts[kind]

func debug_snapshot() -> Dictionary:
	var counts := {"powder": 0, "paper": 0, "cube": 0, "star": 0, "ring": 0, "streak": 0, "ribbon": 0}
	var keys := ["powder", "paper", "cube", "star", "ring", "streak", "ribbon"]
	var exhaust_count := 0
	var life_total := 0.0
	for particle in _particles:
		counts[keys[int(particle["kind"])]] += 1
		life_total += float(particle["life"])
		if int(particle["priority"]) == 0:
			exhaust_count += 1
	return {"particles": _particles.size(), "limit": _limit(), "counts": counts, "exhaust": exhaust_count, "reserved": _reserve(), "batch_meshes": _batches.size(), "rush_starts": _rush_starts, "combo_cues": _combo_cues, "last_combo": _last_combo, "particle_clock": _particle_clock, "life_total": life_total, "spraying": _spraying, "audio_enabled": _audio_enabled}

func _notification(what: int) -> void:
	if not _ready_once:
		return
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		for player in _audio_players():
			if is_instance_valid(player):
				player.stream_paused = what == NOTIFICATION_PAUSED

func _exit_tree() -> void:
	_particles.clear()
	for player in _audio_players():
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
		var envelope := exp(-time * 26.0) * minf(time * 2200, 1.0)
		var thump := sin(TAU * (145 * time - 150 * time * time)) * 0.54 * envelope
		var snap := _rng.randf_range(-1, 1) * exp(-time * 110) * 0.38
		var paper := _rng.randf_range(-1, 1) * exp(-absf(time - 0.035) * 72) * 0.16
		samples[index] = clampf(thump + snap + paper, -0.95, 0.95)
	return _wav(samples)

func _make_snap() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(roundi(SAMPLE_RATE * 0.09))
	for index in samples.size():
		var time := float(index) / SAMPLE_RATE
		samples[index] = (_rng.randf_range(-1, 1) * 0.45 + sin(TAU * 480 * time) * 0.12) * exp(-time * 45)
	return _wav(samples)

func _make_stamp() -> AudioStreamWAV:
	var melody := _make_notes([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.13)
	var samples := PackedFloat32Array()
	samples.resize(melody.data.size() / 2)
	for index in samples.size():
		var time := float(index) / SAMPLE_RATE
		var thump := sin(TAU * (105 * time - 85 * time * time)) * exp(-time * 34) * 0.44
		var click := _rng.randf_range(-1, 1) * exp(-time * 130) * 0.19
		samples[index] = clampf(float(melody.data.decode_s16(index * 2)) / 32767 * 0.7 + thump + click, -0.95, 0.95)
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
