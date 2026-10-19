extends SceneTree
const Run = preload("res://scripts/run_model.gd")
func _initialize() -> void:
	for build in ["lightning", "moon", "echo"]:
		for pattern in ["straight", "orbit", "turnback"]:
			for seed_value in [731, 422, 88]:
				simulate(build, pattern, seed_value)
	quit()
func simulate(build: String, pattern: String, seed_value: int) -> void:
	var run = Run.new()
	run.reset(true, seed_value)
	var first_upgrade := -1.0
	var first_resonance := -1.0
	var peak := 0
	var upgrade_times: Array[float] = []
	for frame in range(60 * 190):
		if run.state == "upgrade":
			upgrade_times.append(snappedf(run.elapsed, 0.01))
			if first_upgrade < 0.0: first_upgrade = run.elapsed
			var best := 0
			var score := -999
			for i in range(run.choices.size()):
				var id: String = run.choices[i].id
				var rank := 10
				if id == "moon_unlock": rank = 1000
				if id == "spec_" + build: rank = 2000
				if id == "power": rank = 80
				if id == "lightning_fork": rank = 75
				if id == "lightning_haste": rank = 70
				if id == "moon_range": rank = 65
				if id == "moon_double": rank = 60
				if id == "lightning_reach": rank = 55
				if id == "stride": rank = 50
				if id == "moon_haste": rank = 45
				if build == "moon" and id in ["moon_range", "moon_haste", "moon_double"]: rank += 35
				if build == "echo" and id in ["lightning_haste", "moon_range", "lightning_reach"]: rank += 25
				if id == "heal" and run.health < run.maximum_health * 0.65: rank = 1500
				if rank > score:
					score = rank
					best = i
			run.choose_upgrade(best)
		if run.state != "playing": break
		var direction := Vector2.RIGHT
		if pattern == "orbit": direction = Vector2.from_angle(run.elapsed / 2.8)
		if pattern == "turnback": direction = Vector2.RIGHT if fmod(run.elapsed, 6.4) < 3.2 else Vector2.LEFT
		run.tick(1.0 / 60.0, direction)
		run.drain_audio()
		peak = maxi(peak, run.enemies.size())
		if first_resonance < 0.0 and run.resonance_hits > 0: first_resonance = run.elapsed
	var late_gaps: Array[float] = []
	for i in range(1, upgrade_times.size()):
		if upgrade_times[i] >= 120.0:
			late_gaps.append(snappedf(upgrade_times[i] - upgrade_times[i - 1], 0.01))
	print(JSON.stringify({"upgrade_times":upgrade_times,"late_gaps":late_gaps,"build":build,"pattern":pattern,"seed":seed_value,"state":run.state,"time":snappedf(run.elapsed,0.1),"health":snappedf(run.health,0.1),"level":run.level,"kills":run.kills,"resonance":run.resonance_hits,"resonance_kills":run.resonance_kills,"damage":run.damage_taken,"peak_enemies":peak,"first_upgrade":snappedf(first_upgrade,0.1),"first_resonance":snappedf(first_resonance,0.1)}))
