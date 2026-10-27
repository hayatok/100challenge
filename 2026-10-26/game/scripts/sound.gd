extends Node
## Presentation-only audio. Original PCM is authored offline, never per turn.
## Four phase-aligned 20-second stems share one musical clock at 96 BPM.

const AUDIO_PATH := "res://assets/audio/"
const MUSIC_BUS := "TideMusic"
const EFFECT_BUS := "TideEffects"
const UI_BUS := "TideUI"
const SEA_BUS := "TideSea"
const MIX_BUS := "TideMix"
const SILENCE_DB := -80.0
const VOICE_LIMIT := 8
const STEM_NAMES := ["bed", "melody", "pulse", "tide"]
const EVENT_FILES := ["attack", "hurt", "loot", "use", "tide", "extract", "death", "click", "repair", "depart"]

var enabled := true
var unlocked := false
var ambience: AudioStreamPlayer
var sounds: Dictionary = {}
var _active := true
var _screen := "title"
var _tide := 0
var _result_loss := false
var _music: Array[AudioStreamPlayer] = []
var _voices: Array[AudioStreamPlayer] = []
var _priority: Array[int] = []
var _voice_age: Array[int] = []
var _target_db: Array[float] = [-2.0, -2.0, SILENCE_DB, SILENCE_DB]
var _last_event: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _step_take := 0
var _duck_left := 0.0
var _duck_amount := 0.0
var _music_bus_db := -7.0

func _ready() -> void:
	_rng.randomize()
	# Private category buses avoid changing any other scene's mix or Master.
	_ensure_bus(MIX_BUS, "Master", -3.0)
	_ensure_bus(MUSIC_BUS, MIX_BUS, -7.0)
	# Eight simultaneous worst-case voices plus all stems stay below full scale.
	_ensure_bus(EFFECT_BUS, MIX_BUS, -11.0)
	_ensure_bus(UI_BUS, MIX_BUS, -12.0)
	_ensure_bus(SEA_BUS, MIX_BUS, -11.0)
	ambience = _new_player(SEA_BUS)
	ambience.stream = _load_loop("sea")
	for stem: String in STEM_NAMES:
		var player := _new_player(MUSIC_BUS)
		player.stream = _load_loop("music_" + stem)
		player.volume_db = SILENCE_DB
		_music.append(player)
	for kind: String in EVENT_FILES:
		sounds[kind] = load(AUDIO_PATH + kind + ".wav")
	for take: int in range(3):
		sounds["step_%d" % take] = load(AUDIO_PATH + "step_%d.wav" % take)
	for index: int in range(VOICE_LIMIT):
		_voices.append(_new_player(EFFECT_BUS))
		_priority.append(-1)
		_voice_age.append(0)
	set_enabled(enabled)

func _new_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.max_polyphony = 1
	add_child(player)
	return player

func _ensure_bus(bus_name: String, send: String, db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	AudioServer.set_bus_volume_db(index, db)

func _load_loop(file_name: String) -> AudioStreamWAV:
	# Duplicate the imported resource: do not mutate a shared WAV import.
	var source := load(AUDIO_PATH + file_name + ".wav") as AudioStreamWAV
	if source == null:
		return null
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported WAVs can use QOA/ADPCM compression: byte size is not sample count.
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream

func start_ambience() -> void:
	unlocked = true
	_resume_loops()

func set_enabled(value: bool) -> void:
	enabled = value
	for bus_name: String in [MIX_BUS, MUSIC_BUS, EFFECT_BUS, UI_BUS, SEA_BUS]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_mute(index, not value)
	if not enabled:
		_stop_voices()
	_resume_loops()

func set_active(value: bool) -> void:
	_active = value
	if not value:
		_stop_voices()
	_resume_loops()

func _resume_loops() -> void:
	if not is_instance_valid(ambience):
		return
	var can_play := enabled and unlocked and _active
	var loops: Array[AudioStreamPlayer] = [ambience]
	loops.append_array(_music)
	for player: AudioStreamPlayer in loops:
		if can_play and not player.playing:
			player.play()
		player.stream_paused = not can_play

func set_scene(screen: String, tide: int = 0) -> void:
	_screen = screen
	_tide = clampi(tide, 0, 4)
	# Optional explicit result aliases also represent a restored result screen.
	if screen in ["result_dead", "result_extracted"]:
		_screen = "result"
		_result_loss = screen == "result_dead"
	elif screen != "result":
		_result_loss = false
	_update_targets()

func _update_targets() -> void:
	match _screen:
		"harbor":
			_target_db = [0.0, 0.0, -9.0, SILENCE_DB]
		"expedition":
			# Tension comes from a soft pulse, never a louder master mix.
			_target_db = [-2.0, -5.0 - _tide, -2.0, -15.0 + _tide * 3.0 if _tide > 0 else SILENCE_DB]
		"result":
			_target_db = [-3.0, SILENCE_DB if _result_loss else -3.0, SILENCE_DB, SILENCE_DB]
		_:
			_target_db = [-2.0, -2.0, SILENCE_DB, SILENCE_DB]

func _process(delta: float) -> void:
	if not enabled or not unlocked or not _active:
		return
	for index: int in range(_music.size()):
		var player := _music[index]
		# Interpolate amplitude rather than spending the fade at inaudible dB.
		var gain := move_toward(db_to_linear(player.volume_db), db_to_linear(_target_db[index]), delta * 0.7)
		player.volume_db = linear_to_db(maxf(gain, 0.0001))
	_duck_left = maxf(0.0, _duck_left - delta)
	var desired_db := -7.0 - (_duck_amount if _duck_left > 0.0 else 0.0)
	_music_bus_db = move_toward(_music_bus_db, desired_db, delta * (35.0 if _duck_left > 0.0 else 6.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), _music_bus_db)

func _stop_voices() -> void:
	for player: AudioStreamPlayer in _voices:
		player.stop()
	_duck_left = 0.0
	_last_event.clear()

func play_event(kind: String) -> void:
	if kind in ["move", "touch"]:
		kind = "step" if kind == "move" else "click"
	if kind == "slash":
		kind = "attack"
	if kind == "return":
		kind = "extract"
	if kind == "loss":
		kind = "death"
	# Keep the result arrangement correct even when the event happens while muted.
	if kind in ["death", "extract"]:
		_result_loss = kind == "death"
		_update_targets()
	if not enabled or not unlocked or not _active:
		return
	if kind == "kill":
		# The attack and hurt events already supply contact; avoid duplicate hits.
		return
	if kind == "equip":
		kind = "click"
	var now := Time.get_ticks_msec()
	var cooldown := 100 if kind == "step" else 55
	if now - int(_last_event.get(kind, -10000)) < cooldown:
		return
	_last_event[kind] = now
	var sound_key := kind
	if kind == "step":
		_step_take = (_step_take + 1 + _rng.randi_range(0, 1)) % 3
		sound_key = "step_%d" % _step_take
	if not sounds.has(sound_key):
		return
	var importance := 0 if kind in ["step", "click"] else 1
	if kind in ["hurt", "loot", "tide"]:
		importance = 2
	if kind in ["extract", "death", "repair"]:
		importance = 3
	var slot := -1
	var oldest := now + 1
	for index: int in range(_voices.size()):
		if not _voices[index].playing:
			slot = index
			break
		if _priority[index] <= importance and _voice_age[index] < oldest:
			oldest = _voice_age[index]
			slot = index
	if slot < 0:
		return
	var player := _voices[slot]
	player.stop()
	player.stream = sounds[sound_key]
	player.bus = UI_BUS if kind == "click" else EFFECT_BUS
	player.volume_db = -11.0 if kind == "step" else (-5.0 if importance >= 2 else -7.0)
	if kind in ["loot", "extract", "repair"]:
		# Tonal receipts need more sustain than the much hotter impact samples.
		player.volume_db = -1.0
	elif kind in ["death", "tide", "use", "depart"]:
		player.volume_db = -3.0
	player.pitch_scale = _rng.randf_range(0.96, 1.04) if kind in ["step", "attack", "click"] else 1.0
	_priority[slot] = importance
	_voice_age[slot] = now
	player.play()
	if importance >= 2:
		_duck_amount = 5.0 if importance == 3 else 3.0
		_duck_left = 1.1 if importance == 3 else 0.45

func _exit_tree() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_music.clear()
	_voices.clear()
	sounds.clear()
