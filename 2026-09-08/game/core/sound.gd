class_name RescueSound
extends Node
var muted: bool = false
var sounds: Dictionary = {}
var last_impact: int = -1000

func _ready() -> void:
	for kind: String in ["cut","impact","win","break"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var duration: float = 1.6 if kind=="win" else (0.8 if kind=="break" else 0.3)
		var samples := PackedByteArray()
		samples.resize(int(duration*22050)*2)
		for i: int in range(samples.size()/2):
			var t: float = float(i)/22050.0
			# Deterministic textured transients; no random state shared with physics.
			var noise: float = sin(float(i)*12.9898)*sin(float(i)*78.233)
			var value: float = 0
			match kind:
				"cut":
					value = sin(TAU*1450*t)*exp(-t*20)*0.5+sin(TAU*2380*t)*exp(-t*35)*0.3+noise*exp(-t*60)*0.5
				"impact":
					value = sin(TAU*95*t)*exp(-t*18)*0.7+noise*exp(-t*45)*0.4
				"break":
					value = noise*exp(-t*12)*0.7+sin(TAU*2361*t)*exp(-t*10)*0.25+sin(TAU*163*t)*exp(-t*18)*0.6
				"win":
					# Fold, stamp, then a rising glass-like chord.
					value = noise*exp(-t*22)*0.2
					if t>0.45:
						value += sin(TAU*100*(t-0.45))*exp(-(t-0.45)*28)*0.65
					for note: int in range(4):
						var age: float = t-0.62-note*0.085
						if age>=0:
							var frequency: float = [523.25,659.25,783.99,1046.5][note]
							value += sin(TAU*frequency*age)*exp(-age*5)*0.28
			samples.encode_s16(i*2,int(clampf(value,-1,1)*10000))
		wav.data = samples
		sounds[kind] = wav

func play(kind: String) -> void:
	if muted:
		return
	if kind=="impact":
		var now: int = Time.get_ticks_msec()
		if now-last_impact<150:
			return
		last_impact = now
	var player := AudioStreamPlayer.new()
	player.stream = sounds[kind]
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
