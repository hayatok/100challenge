class_name RescueSound
extends Node
var muted: bool = false
var sounds: Dictionary = {}

func _ready() -> void:
	for kind: String in ["cut","win","break"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var duration: float = 0.16 if kind == "cut" else 0.65
		var samples := PackedByteArray()
		samples.resize(int(duration * 22050) * 2)
		for i: int in range(samples.size()/2):
			var t: float = float(i) / 22050.0
			var frequency: float = 1100.0 if kind == "cut" else (523.25 if kind == "win" else 160.0)
			var value: float = sin(TAU * frequency * t) * exp(-t * 12.0)
			if kind == "win":
				value = (sin(TAU*523.25*t)+sin(TAU*659.25*t)+sin(TAU*783.99*t))*exp(-t*5.5)/3.0
			elif kind == "break":
				value += sin(TAU*2361*t)*exp(-t*18)*0.5
			var sample: int = int(value*7000.0)
			samples.encode_s16(i*2,sample)
		wav.data = samples
		sounds[kind] = wav

func play(kind: String) -> void:
	if muted:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sounds[kind]
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
