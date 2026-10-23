extends SceneTree
const Simulation = preload("res://tests/campaign_simulation.gd")

func _initialize() -> void:
	var configurations := [
		{"seed": 731, "starter": "lightning", "weapons": ["lightning", "moon", "bell"], "relics": ["storm_ink", "moonstone", "ward_leaf"], "spec": "spec_lightning"},
		{"seed": 2026, "starter": "moon", "weapons": ["moon", "frost", "wisp"], "relics": ["moonstone", "ice_crystal", "lantern_oil"], "spec": "spec_moon"},
		{"seed": 196, "starter": "thorn", "weapons": ["thorn", "bell", "wisp"], "relics": ["echo_mirror", "silver_bell", "thorn_seed"], "spec": "spec_echo"}
	]
	var wins := 0
	var pacing_passes := 0
	for configuration in configurations:
		var result: Dictionary = Simulation.play(configuration.seed, configuration.starter, configuration.weapons, configuration.relics, configuration.spec)
		print("CAMPAIGN_SIMULATION " + JSON.stringify(result))
		if result.get("state", "") == "victory":
			wins += 1
		var valid: bool = result.get("state", "") == "victory"
		for chapter_index in range(3):
			var growth := 0
			for choice in result.get("choice_log", []):
				if int(choice.chapter) == chapter_index and choice.kind != "heal":
					growth += 1
			valid = valid and growth >= 3
		for choice in result.get("choice_log", []):
			if choice.kind == "evolution":
				valid = valid and int(choice.chapter) == 2 and choice.source == "treasure"
		var final_use := float(result.get("elapsed", 0.0)) - float(result.get("last_evolution_time", 0.0))
		valid = valid and final_use >= 60.0 and final_use <= 120.0
		valid = valid and int(result.get("decision_breakdown", {}).get("heal", 100)) <= 3
		if valid:
			pacing_passes += 1
		else:
			push_error("Ordinary campaign pacing failed for seed %d" % int(configuration.seed))
	print("CAMPAIGN_SIMULATION_RESULT %d/%d complete; %d/%d chapter-growth/evolution/payoff checks" % [wins, configurations.size(), pacing_passes, configurations.size()])
	quit(0 if wins == configurations.size() and pacing_passes == configurations.size() else 1)
