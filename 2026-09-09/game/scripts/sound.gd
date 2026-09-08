extends AudioStreamPlayer
var muted: bool = false
var speed: float = 0.0
var driving: bool = false
var phase: float = 0.0
var beep_left: float = 0.0
var beep_hz: float = 660.0
var playback: AudioStreamGeneratorPlayback
func _ready() -> void:
 if DisplayServer.get_name() == "headless":
  return
 playback_type = AudioServer.PLAYBACK_TYPE_STREAM
 play()
 playback = get_stream_playback()
func beep(frequency: float = 660.0) -> void:
 beep_hz = frequency
 beep_left = 0.14
func _process(_delta: float) -> void:
 if playback == null:
  return
 for i in range(playback.get_frames_available()):
  phase += 1.0 / 22050.0
  var value: float = 0.0
  if driving:
   value += sin(phase * TAU * (70.0 + speed * 8.0)) * 0.035
  if beep_left > 0.0:
   value += sin(phase * TAU * beep_hz) * 0.1 * minf(1.0, beep_left * 25.0)
   beep_left -= 1.0 / 22050.0
  playback.push_frame(Vector2.ONE * (0.0 if muted else value))
