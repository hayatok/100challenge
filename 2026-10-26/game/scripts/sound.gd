extends Node

var enabled := true
var unlocked := false
var ambience: AudioStreamPlayer
var sounds: Dictionary = {}

func _ready() -> void:
	for bus_name: String in ["Sea", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Sea"
	ambience.volume_db = -25.0
	add_child(ambience)
	var wave := _synthesize(5.0, 70.0, 0.7, "sea")
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_end = wave.data.size() / 2
	ambience.stream = wave
	for kind: String in ["step", "attack", "hurt", "loot", "use", "tide", "extract", "death", "click", "repair"]:
		var freq: float = {"step": 130.0, "attack": 250.0, "hurt": 95.0, "loot": 640.0, "use": 430.0, "tide": 130.0, "extract": 520.0, "death": 130.0, "click": 360.0, "repair": 660.0}[kind]
		sounds[kind] = _synthesize(0.13 if kind in ["step", "click"] else 0.45, freq, 0.6, kind)

func start_ambience() -> void:
	unlocked = true
	if enabled and not ambience.playing:
		ambience.play()

func set_enabled(value: bool) -> void:
	enabled = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sea"), not value)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), not value)
	if value and unlocked:
		start_ambience()

func set_active(value: bool) -> void:
	if is_instance_valid(ambience):
		ambience.stream_paused = not value
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = not value

func _exit_tree() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	sounds.clear()

func play_event(kind: String) -> void:
	if not enabled:
		return
	if kind == "move":
		kind = "step"
	if not sounds.has(kind):
		return
	var player := AudioStreamPlayer.new()
	player.stream = sounds[kind]
	player.bus = "Effects"
	player.volume_db = -17.0 if kind in ["step", "click"] else -11.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _synthesize(duration: float, frequency: float, gain: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41027
	var filtered := 0.0
	for i: int in range(count):
		var time := float(i) / rate
		var fraction := float(i) / count
		var sample := 0.0
		filtered = filtered * 0.92 + rng.randf_range(-1, 1) * 0.08
		if kind == "sea":
			sample = filtered * (0.5 + 0.3 * sin(time * TAU / duration)) + sin(time * 2 * TAU) * 0.012
		else:
			var env := sin(minf(time * 100, PI / 2)) * pow(1.0 - fraction, 2.0)
			var pitch := frequency * (1.0 - fraction * 0.4) if kind in ["attack", "hurt", "death"] else frequency
			sample = (sin(TAU * time * pitch) * 0.42 + sin(TAU * time * pitch * 2.01) * 0.12 + filtered * (0.8 if kind in ["step", "attack"] else 0.1)) * env
			if kind in ["loot", "extract", "repair"]:
				sample += sin(TAU * time * frequency * 1.5) * env * 0.18
		data.encode_s16(i * 2, int(clampf(sample * gain, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
