extends Node
var music_volume=0.24
var effects_volume=0.45
var ambient_volume=0.16
var enabled=false
var night=false
var last_fx={}
var voices=[]
var streams={}
var played_counts={}
var observed_source=0
var observed_tick=-1
var observed_visits={}
var observed_orders=[]
var observed_story=""
const COOLDOWN={"click":0.06,"sale":0.4,"arrival":0.9,"delivery":2.0,"error":0.15,"good":0.25,"open":1.0,"story":2.0,"star":2.0}
const PRIORITY={"click":0,"sale":1,"arrival":1,"delivery":1,"error":2,"good":2,"open":2,"story":3,"star":3}
var day_player:AudioStreamPlayer
var night_player:AudioStreamPlayer
var room_player:AudioStreamPlayer
var night_mix=0.0
func _ready():
	day_player=loop_player("res://assets/audio/day.wav")
	night_player=loop_player("res://assets/audio/night.wav")
	room_player=loop_player("res://assets/audio/room.wav")
	for i in 4:
		var voice=AudioStreamPlayer.new();add_child(voice);voices.append(voice)
	for kind in COOLDOWN:streams[kind]=make_effect(kind)
func loop_player(path:String) -> AudioStreamPlayer:
	var stream=load(path).duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2
	var player=AudioStreamPlayer.new();player.stream=stream;player.volume_db=-80;add_child(player);return player
func _process(delta):
	if not enabled:return
	for voice in voices:voice.volume_db=linear_to_db(maxf(0.0001,effects_volume*0.22))
	for player in [day_player,night_player,room_player]:
		if not player.playing:player.play()
	night_mix=move_toward(night_mix,1.0 if night else 0.0,delta*0.25)
	day_player.volume_db=linear_to_db(maxf(0.0001,music_volume*(1-night_mix)))
	night_player.volume_db=linear_to_db(maxf(0.0001,music_volume*night_mix))
	room_player.volume_db=linear_to_db(maxf(0.0001,ambient_volume*0.12))
func make_effect(kind:String) -> AudioStreamWAV:
	# A-major motifs share the original day/night score's key.
	var notes={
		"click":[[0,880,0.04]],
		"sale":[[0,1109,0.065],[0.08,1661,0.11]],
		"arrival":[[0,659,0.13],[0.16,554,0.19]],
		"delivery":[[0,220,0.06],[0.10,220,0.06],[0.22,440,0.15]],
		"error":[[0,220,0.09],[0.11,165,0.13]],
		"good":[[0,659,0.09],[0.10,880,0.17]],
		"open":[[0,440,0.12],[0.14,554,0.12],[0.28,659,0.24]],
		"story":[[0,554,0.13],[0.14,659,0.13],[0.28,830,0.13],[0.44,1109,0.30]],
		"star":[[0,440,0.12],[0.14,554,0.12],[0.28,659,0.12],[0.42,880,0.38]]
	}[kind]
	var duration=float(notes[-1][0])+float(notes[-1][2]);var count=ceili(duration*22050)
	var mix=PackedFloat32Array();mix.resize(count)
	for note in notes:
		var offset=roundi(note[0]*22050);var length=mini(roundi(note[2]*22050),count-offset)
		for i in length:
			var t=i/22050.0;var phase=TAU*note[1]*t
			var env=minf(t/0.005,1.0)*pow(maxf(0,1-t/note[2]),1.7)
			mix[offset+i]+=(sin(phase)+sin(phase*3)/9.0+sin(phase*5)/25.0)*env*0.6
	var sample=PackedByteArray();sample.resize(count*2)
	for i in count:sample.encode_s16(i*2,roundi(clampf(mix[i],-0.95,0.95)*32767))
	var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050;stream.data=sample
	return stream
func effect(kind:String):
	if not enabled or effects_volume<=0 or not streams.has(kind):return
	var now=Time.get_ticks_msec()/1000.0
	if now-float(last_fx.get(kind,-999))<COOLDOWN[kind]:return
	var chosen:AudioStreamPlayer=null
	for voice in voices:
		if not voice.playing:chosen=voice;break
	if chosen==null:
		for voice in voices:
			if chosen==null or voice.get_meta("priority",0)<chosen.get_meta("priority",0):chosen=voice
		if chosen.get_meta("priority",0)>PRIORITY[kind]:return
	chosen.stop();chosen.stream=streams[kind];chosen.set_meta("priority",PRIORITY[kind])
	chosen.volume_db=linear_to_db(maxf(0.0001,effects_volume*0.22));chosen.play()
	last_fx[kind]=now;played_counts[kind]=played_counts.get(kind,0)+1
func reset_observer():
	observed_source=0;observed_tick=-1;observed_visits={};observed_orders=[];observed_story=""
func observe(game):
	var source=game.get_instance_id();var baseline=source!=observed_source or game.s.tick<observed_tick or observed_tick<0
	var current={}
	for actor in game.s.visits:
		var previous=observed_visits.get(actor.id,{})
		if not baseline and not previous.is_empty():
			if previous.outside and actor.pos.x>=0:effect("arrival")
			if not previous.bought and actor.bought:effect("sale")
		current[actor.id]={"outside":actor.pos.x<0,"bought":actor.bought}
	var story=""
	if not game.s.episode_events.is_empty():
		var entry=game.s.episode_events[0];story="%s:%s:%s"%[entry.rid,entry.chapter,entry.day]
	if not baseline:
		if not story.is_empty() and story!=observed_story:effect("story")
		if observed_orders.any(func(due):return due>observed_tick and due<=game.s.tick):effect("delivery")
	observed_source=source;observed_tick=game.s.tick;observed_visits=current;observed_story=story
	observed_orders=game.s.orders.map(func(order):return order.due)

func _exit_tree():
	enabled=false
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
