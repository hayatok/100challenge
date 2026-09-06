extends SceneTree
const Sound=preload("res://audio.gd")
func _init():
	var sound=Sound.new();var data=PackedByteArray();var cues=[]
	for kind in ["click","arrival","sale","delivery","error","good","open","story","star"]:
		var stream=sound.make_effect(kind);var peak=0
		for i in stream.data.size()/2:peak=maxi(peak,absi(stream.data.decode_s16(i*2)))
		cues.append({"kind":kind,"start":data.size()/44100.0,"duration":stream.data.size()/44100.0,"peak":peak/32768.0})
		data.append_array(stream.data)
		var silence=PackedByteArray();silence.resize(22050);data.append_array(silence)
	var preview=AudioStreamWAV.new();preview.format=AudioStreamWAV.FORMAT_16_BITS;preview.mix_rate=22050;preview.data=data
	preview.save_to_wav("res://../art/beta/sound-cues.wav")
	var file=FileAccess.open("res://../docs/beta-sound-cues.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"sample_rate":22050,"channels":1,"max_effect_voices":4,"cues":cues},"  "));file.close()
	sound.free();print("Exported production sound cues with durations and peaks");quit()
