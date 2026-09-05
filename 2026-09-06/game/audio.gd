extends Node
var music_volume=0.24
var effects_volume=0.45
var ambient_volume=0.16
var enabled=false
var night=false
var last_fx=0.0
var day_player:AudioStreamPlayer
var night_player:AudioStreamPlayer
var room_player:AudioStreamPlayer
var night_mix=0.0
func _ready():
	day_player=loop_player("res://assets/audio/day.wav")
	night_player=loop_player("res://assets/audio/night.wav")
	room_player=loop_player("res://assets/audio/room.wav")
func loop_player(path:String) -> AudioStreamPlayer:
	var stream=load(path).duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2
	var player=AudioStreamPlayer.new();player.stream=stream;player.volume_db=-80;add_child(player);return player
func _process(delta):
	if not enabled:return
	for player in [day_player,night_player,room_player]:
		if not player.playing:player.play()
	night_mix=move_toward(night_mix,1.0 if night else 0.0,delta*0.25)
	day_player.volume_db=linear_to_db(maxf(0.0001,music_volume*(1-night_mix)))
	night_player.volume_db=linear_to_db(maxf(0.0001,music_volume*night_mix))
	room_player.volume_db=linear_to_db(maxf(0.0001,ambient_volume*0.12))
func tone(freq:float,duration:float,volume:float):
	if not enabled or volume<=0:return
	var sample=PackedByteArray();var count=int(duration*22050);sample.resize(count*2)
	for i in count:
		var t=i/22050.0;var env=minf(t*100,1)*pow(maxf(0,1-t/duration),2)
		var wave=sin(TAU*freq*t)*0.85+sin(TAU*freq*2*t)*0.15
		sample.encode_s16(i*2,roundi(wave*env*volume*32767))
	var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050;stream.data=sample
	var player=AudioStreamPlayer.new();player.stream=stream;add_child(player);player.finished.connect(player.queue_free);player.play()
func effect(kind:String):
	if not enabled:return
	var now=Time.get_ticks_msec()/1000.0
	if now-last_fx<0.13:return
	last_fx=now
	tone({"click":620,"sale":880,"error":180,"good":1046,"open":523}.get(kind,620),0.06 if kind=="click" else 0.23,effects_volume*0.13)
	if kind in ["good","open"]:
		get_tree().create_timer(0.12).timeout.connect(func():tone(659,0.27,effects_volume*0.08))
		get_tree().create_timer(0.24).timeout.connect(func():tone(784,0.30,effects_volume*0.08))

func _exit_tree():
	enabled=false
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
