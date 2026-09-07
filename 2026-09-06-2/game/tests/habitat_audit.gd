extends SceneTree
const W = preload("res://core/world.gd")
const E = preload("res://core/ecology.gd")
const DNA = preload("res://core/genome.gd")
func _initialize() -> void:
	var result: Array = []
	var failures: int = 0
	for seed_id in [1, 42, 20260906]:
		var world = W.new(seed_id)
		var samples: Array = []
		for i in 18000:
			world.step()
			if i % 4500 == 4499:
				var sample: Dictionary = world.survey()
				var preference: Array = []
				for area in 3:
					var local_total: float = 0
					var all_total: float = 0
					var local_count: int = 0
					for c in world.creatures:
						var efficiency: float = E.efficiency(world.phenotypes[c.id], area)
						all_total += efficiency
						if W.habitat(Vector2(c.x, c.y)) == area: local_total += efficiency; local_count += 1
					preference.append({"local": local_total / maxf(1, local_count), "island": all_total / maxf(1, world.creatures.size())})
				samples.append({"time": world.time, "alive": world.creatures.size(), "births": world.births, "areas": sample.areas, "food_efficiency": preference, "notes": world.notes.size()})
				if world.creatures.size() < 10 or W.restore(world.snapshot()) == null: failures += 1
		result.append({"seed": seed_id, "samples": samples, "census_size": world.census.size()})
	print("HABITAT HOUR AUDIT ", JSON.stringify(result))
	print("AUDIT failures ", failures)
	quit(1 if failures else 0)
