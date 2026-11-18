extends SceneTree

const Voyage = preload("res://voyage.gd")
var voyage: Voyage
var failures := 0
var path := "user://qa-rush-%s.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func load_voyage() -> void:
	voyage = Voyage.new()
	voyage.storage = path
	root.add_child(voyage)
	voyage.set_physics_process(false)
	voyage.bridge.set_process(false)

func shoot_bell(bell: StaticBody3D) -> void:
	var eye := voyage.player.camera.global_position
	var center := bell.global_position + Vector3.UP * 2.65
	var query := PhysicsRayQueryParameters3D.create(eye, center, 5, [voyage.player.get_rid()])
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	expect(hit.get("collider") == bell, "The foreground bell must be reachable from the starting camera")
	if hit.get("collider") == bell:
		hit.collider.receive_shot(18, hit.position, (center-eye).normalized())

func _run() -> void:
	# An existing v1.0 config has no rush section.
	var legacy := {"version":1, "chapter":1, "checkpoint":2, "kills":127, "elapsed":234.5,
		"player":{"hp":62.0, "weapon":1, "owned":[true,true,false], "ammo":[61,12,4]}}
	var config := ConfigFile.new()
	config.set_value("run", "entry", legacy)
	config.set_value("options", "values", {"volume":0.0, "flash":false})
	expect(config.save(path) == OK, "Create legacy save fixture")
	load_voyage()
	expect(voyage.saved == legacy and voyage.rush_best == 0, "Read legacy progress without arcade record")
	voyage.bridge.rush_requested.emit()
	expect(voyage.rush != null and voyage.saved == legacy, "Standalone start keeps legacy checkpoint")
	voyage.player.set_physics_process(false)
	expect(voyage.remaining == 0 and not voyage.incoming_points.is_empty(), "Gate lights precede the first spawn")
	voyage._physics_process(1.0)
	var actors := get_nodes_in_group("enemies")
	expect(actors.size() == 4, "First announced group arrives")
	var bells := get_nodes_in_group("rush_bells")
	expect(bells.size() == 2, "Two separate chargeable bells")
	if actors.size() != 4 or bells.size() != 2:
		_finish()
		return
	var bell: StaticBody3D = bells[0]
	for i in range(actors.size()):
		actors[i].set_physics_process(false)
		actors[i].global_position = bell.global_position + Vector3(0.8 + i * 2.6, 0.2, -0.3)
	await physics_frame
	await physics_frame
	shoot_bell(bell)
	expect(actors[0].lure_time > 0 and not voyage.world.rush_bell_ready(), "First shot lures before charge")
	bell._process(0.6)
	shoot_bell(bell)
	expect(voyage.rush.kills == 0, "Early shot cannot discharge")
	bell._process(0.61)
	expect(voyage.world.rush_bell_ready(), "Charged bell exposes ready state to HUD")
	shoot_bell(bell)
	expect(voyage.rush.kills == 2 and voyage.remaining == 2, "Discharge only defeats enemies in the marked radius")
	expect(voyage.rush.score == 350 and voyage.rush.best_discharge == 2, "A two-kill discharge earns 350")
	expect(not voyage.world.rush_bell_ready() and not bell.flash_enabled, "Cooldown starts and respects reduced flashes")
	shoot_bell(bell)
	expect(voyage.rush.score == 350, "Cooling bell cannot score twice")
	var before := voyage.rush.time_left
	voyage.bridge.pause_requested.emit()
	voyage._physics_process(9)
	expect(voyage.rush.time_left == before and paused, "Pausing freezes rush time")
	voyage.bridge.resume_requested.emit()
	voyage.player.hp = 20.0
	voyage._physics_process(30.0)
	expect(voyage.rush.stage == 2 and voyage.player.hp == 45.0, "Stage transition supplies health")
	voyage._physics_process(60.0)
	expect(voyage.mode == "rush_result" and voyage.rush_best == 350, "Timer ends and records the run")
	voyage.bridge.rush_requested.emit()
	expect(voyage.rush.score == 0 and voyage.rush.time_left == 90 and voyage.rush_best == 350, "Retry resets only the round")
	voyage.player.receive_damage(200)
	expect(voyage.mode == "rush_result" and voyage.rush_best == 350, "Defeat retains the higher best")
	voyage.bridge.title_requested.emit()
	voyage.free()
	load_voyage()
	expect(voyage.rush_best == 350 and voyage.saved == legacy and not voyage.settings.flash, "Record, settings and legacy run survive reload")
	voyage.bridge.begin.emit(true)
	expect(voyage.rush == null and voyage.chapter == 1 and voyage.checkpoint == 2 and voyage.kills == 127, "Continue returns to the old campaign")
	_finish()

func _finish() -> void:
	voyage.sound.stop_all()
	await create_timer(0.15, true).timeout
	voyage.free()
	await create_timer(0.15, true).timeout
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Rush save, arena and scoring integration: %d failures" % failures)
	quit(1 if failures else 0)
