extends SceneTree
const World = preload("res://core/world.gd")
const Campaign = preload("res://core/campaign.gd")
var failures: Array[String] = []
var checks: int = 0
const Progress = preload("res://core/progress.gd")
func _initialize() -> void:
	call_deferred("run")
func trial(data: Dictionary,actions: Array,shift: float=0.0) -> Dictionary:
	var w := World.new()
	root.add_child(w)
	var copy: Dictionary = data.duplicate(true)
	for i: int in range(copy["vases"].size()):
		copy["vases"][i].x += shift
	w.build(copy)
	var reason: String = "waiting"
	for tick: int in range(14400):
		for a: Dictionary in actions:
			if tick == int(float(a["at"])*120):
				w.cut(int(a["pin"]))
		await physics_frame
		if w.ended: break
		if actions.is_empty() and tick>=3600: break
	var positions: Array = []
	for v: RescueCeramic in w.ceramics:
		positions.append(v.position.round())
	var result: Dictionary = {"won":w.won,"ended":w.ended,"seconds":snappedf(w.elapsed,0.01),"vases":positions}
	w.free()
	return result
func verify(ok: bool,label: String,result: Dictionary) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ",label," ",result)
func run() -> void:
	var all: Array[Dictionary] = Campaign.all()
	verify(all.size() == 16,"sixteen distinct stage entries",{})
	verify(Progress.validate({"version":2,"best":{"0":1}},16).is_empty(),"old records stay separate",{})
	verify(Progress.validate({"version":3,"best":{"0":1,"1":2.5,"16":1}},16)=={"0":1},"save bounds",{})
	for i: int in range(all.size()):
		var d: Dictionary = all[i]
		var r: Dictionary = await trial(d,d["solution"])
		verify(r["won"],"%02d solution" % [i+1],r)
		print("STAGE ",i+1," ",r)
		if i < 8:
			var waiting: Array = d["solution"].duplicate(true)
			for j: int in range(waiting.size()):
				waiting[j]["at"] += float(j+1)*3.0
			r = await trial(d,waiting,1.0)
			verify(r["won"],"%02d patient" % [i+1],r)
			for trap: Array in d["traps"]:
				r = await trial(d,trap)
				verify(not r["won"] or i == 2,"%02d trap" % [i+1],r)
			var cuts: Array = []
			for pin: int in range(d["pins"].size()):
				cuts.append({"pin":pin,"at":0.5})
			r = await trial(d,cuts)
			verify(not r["won"],"%02d all cut" % [i+1],r)
		r = await trial(d,[])
		verify(not r["ended"],"%02d untouched" % [i+1],r)
	print("CAMPAIGN CHECKS ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
