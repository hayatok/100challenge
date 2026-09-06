extends SceneTree
const W = preload("res://core/world.gd")
func _initialize():
	var output: Array = []
	for seed_id in [1, 42, 20260906]:
		var s = W.new(seed_id)
		var snapshots: Array = []
		for i in 18000:
			s.step()
			if i % 4500 == 4499: snapshots.append({"time":s.time,"alive":s.creatures.size(),"births":s.births})
		output.append({"seed":seed_id,"checkpoints":snapshots})
	print(JSON.stringify(output))
	quit()
