extends SceneTree
const World = preload("res://core/world.gd")
const Levels = preload("res://core/levels.gd")
const Progress = preload("res://core/progress.gd")
var checks: int = 0
var failures: Array[String] = []
var report: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func trial(data: Dictionary, actions: Array, shift: float = 0.0) -> Dictionary:
	var w := World.new()
	root.add_child(w)
	var changed_data: Dictionary = data.duplicate(true)
	for i: int in range(changed_data["vases"].size()):
		changed_data["vases"][i].x += shift
	w.build(changed_data)
	var reason: Array[String] = []
	w.finished.connect(func(_won: bool, why: String) -> void: reason.append(why))
	for tick: int in range(3600):
		for a: Dictionary in actions:
			if tick == int(float(a["at"])*120):
				w.cut(a["pin"])
		await physics_frame
		for b: RescueBeam in w.beams:
			if not b.position.is_finite() or not is_finite(b.rotation):
				check(false,"Non-finite rigid body")
		if w.ended:
			break
	var damage: bool = false
	for v: RescueCeramic in w.ceramics:
		damage = damage or v.broken
	var result: Dictionary = {"won":w.won,"ended":w.ended,"reason":reason,"broken":damage,"seconds":snappedf(w.elapsed,0.01),"cuts":w.cuts}
	w.free()
	return result

func run() -> void:
	var all: Array[Dictionary] = Levels.all()
	for i: int in range(all.size()):
		var data: Dictionary = all[i]
		for repeat: int in range(10):
			var actions: Array = data["solution"].duplicate(true)
			for action: Dictionary in actions:
				action["at"] += float(repeat % 3)*0.1
			var result: Dictionary = await trial(data,actions,float(repeat % 3 - 1))
			check(result["won"] and not result["broken"],"Stage %d solution %d failed: %s" % [i+1,repeat,result])
			if repeat == 0:
				report.append({"stage":i+1,"result":result})
		var wrong: Array = []
		for j: int in range(data["pins"].size()):
			wrong.append({"pin":j,"at":0.5})
		var result: Dictionary = await trial(data,wrong)
		check(bool(result["won"]) == (i == 2),"All-cut outcome stage %d: %s" % [i+1,result])
	# Solution feasibility is not difficulty: audit early release and omitted phases.
	for i: int in range(9,16):
		var early: Array = all[i]["solution"].duplicate(true)
		for action: Dictionary in early:
			action["at"] = 0.5
		var early_result: Dictionary = await trial(all[i],early)
		check(not early_result["won"] and early_result["broken"],"Stage %d lost its receiving decision: %s" % [i+1,early_result])
		var reversed: Array = all[i]["solution"].duplicate(true)
		var last_phase: float = float(reversed.back()["at"])
		for action: Dictionary in reversed:
			action["at"] = last_phase+0.5-float(action["at"])
		check(not (await trial(all[i],reversed))["won"],"Stage %d ignores phase order" % (i+1))
		var waiting: Array = all[i]["solution"].duplicate(true)
		for action: Dictionary in waiting:
			# Shift each phase independently by seconds, keeping its simultaneous pair.
			if float(action["at"])>=5.0:
				action["at"] += 3.0
		var waited: Dictionary = await trial(all[i],waiting,0.5)
		check(waited["won"],"Stage %d penalizes patient observation: %s" % [i+1,waited])
		var no_receiving_release: Array = all[i]["solution"].filter(func(a: Dictionary) -> bool: return a["pin"] not in [2,3])
		check(not (await trial(all[i],no_receiving_release))["won"],"Stage %d bypasses receiving phase" % (i+1))
	# A real alternate: tip the delivery tray instead of dropping both fastenings.
	check((await trial(all[10],[{"pin":1,"at":0.5},{"pin":3,"at":5.0}]))["won"],"Tray alternative was artificially forbidden")
	check(not (await trial(all[14],[{"pin":6,"at":0.5},{"pin":7,"at":0.5},{"pin":1,"at":3.0},{"pin":2,"at":9.0},{"pin":3,"at":9.0}]))["won"],"Final chapter bypasses lower route preparation")
	# A wrong remaining support must cause a real contact fracture.
	var impact: Dictionary = await trial(all[0],[{"pin":0,"at":0.5}])
	check(impact["broken"] and not impact["won"],"Wrong support did not shatter ceramic")
	var late: Dictionary = await trial(all[6],[{"pin":1,"at":0.5},{"pin":2,"at":6.5}])
	check(late["broken"] and not late["won"],"Late return route must miss ceramic")
	var simultaneous: Dictionary = await trial(all[6],[{"pin":1,"at":0.5},{"pin":2,"at":0.5}])
	check(simultaneous["won"],"Simultaneous preparation should remain a valid alternative")
	var alternate: Dictionary = await trial(all[2],[{"pin":0,"at":0.5}])
	check(alternate["won"],"Cradle one-cut alternative should remain possible")
	# Untouched models must remain safe and must never award a passive win.
	for data: Dictionary in all:
		var untouched: Dictionary = await trial(data,[])
		check(not untouched["won"] and not untouched["broken"],"Uncut model is unstable: %s" % data["title"])
	# Invalid input and duplicate cuts are no-ops, including after a result.
	var w := World.new()
	root.add_child(w)
	w.build(all[0])
	check(not w.cut(-1) and not w.cut(10),"Invalid index mutated world")
	check(w.cut(1) and not w.cut(1) and w.cuts == 1,"Duplicate cut changed count")
	w.ended = true
	check(not w.cut(0),"Finished world accepted a cut")
	w.free()
	check(Progress.validate(null,8).is_empty(),"Null save accepted")
	check(Progress.validate({"version":99,"best":{"0":1}},8).is_empty(),"Unknown save version accepted")
	check(Progress.validate({"version":2,"best":{"0":1,"1":2.5,"2":"3","9":1,"3":-1,"4":999}},8) == {"0":1},"Save bounds not enforced")
	check(Progress.migrate({"version":1,"best":{"3":2,"4":2,"5":1,"7":2,"8":1}})=={"4":2,"5":2,"3":1,"7":2},"Legacy records assigned to wrong models")
	check(Progress.validate({"version":2,"best":{"15":8,"16":1,"-1":1}},16)=={"15":8},"Sixteen-model save bounds not enforced")
	print("PHYSICS CHECKS ",checks," failures=",failures.size())
	print("STAGE REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
