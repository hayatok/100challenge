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
	for tick: int in range(2400):
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
	check(Progress.validate({"version":2,"best":{"0":1}},8).is_empty(),"Unknown save version accepted")
	check(Progress.validate({"version":1,"best":{"0":1,"1":2.5,"2":"3","9":1,"3":-1,"4":999}},8) == {"0":1},"Save bounds not enforced")
	print("PHYSICS CHECKS ",checks," failures=",failures.size())
	print("STAGE REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
