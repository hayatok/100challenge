extends SceneTree
# Automated integration coverage; this does not replace a human playtest.
const Voyage = preload("res://voyage.gd")
const Prop = preload("res://world/prop.gd")
var voyage
var wave_count := 0
var boss_count := 0
var rally_count := 0
var checkpoint_count := 0
var failures := 0
var save_path := "user://qa-campaign-%s.cfg" % OS.get_process_id()

func _initialize() -> void:
	create_timer(45.0, true).timeout.connect(func():
		push_error("Campaign regression exceeded 45 seconds")
		_cleanup()
		quit(2))
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
		_cleanup()
		quit(1)

func _cleanup() -> void:
	paused = false
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

func _new_voyage() -> void:
	voyage = Voyage.new()
	voyage.storage = save_path # Set before _ready; never touch the real save.
	root.add_child(voyage)
	voyage.set_physics_process(false)
	# Headless has no pointer capture. Test menu signals, not OS focus events.
	voyage.bridge.set_process(false)

func _freeze_stage() -> void:
	voyage.world.set_process(false)
	voyage.player.set_physics_process(false)
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)

func _observe_world() -> void:
	_freeze_stage()
	checkpoint_count += 1
	if voyage.world.fighting and voyage.remaining > 0:
		wave_count += 1
	voyage.world.encounter_changed.connect(func(_point): checkpoint_count += 1)
	voyage.world.spawn_wave.connect(func(kinds, positions):
		wave_count += 1
		_expect(kinds.size() == positions.size(), "Wave spawn arrays differ")
		for kind in kinds:
			if kind == 3:
				boss_count += 1
				_expect(voyage.chapter == 2 and voyage.checkpoint == 2, "Captain outside finale")
		_freeze_stage())

func _trigger(point: int) -> void:
	voyage.player.position = Vector3(0, 0.15, -point * 36 - 8)
	voyage.world._process(0.016)
	voyage.world._process(0.016)
	_freeze_stage()
	if voyage.world.wave_pending:
		await create_timer(0.76, true).timeout
	_check_spawn_clearance()

func _kill_wave() -> void:
	var actors := get_nodes_in_group("enemies").duplicate()
	_expect(not actors.is_empty(), "Expected active wave")
	for actor in actors:
		actor.receive_shot(10000.0, actor.global_position + Vector3.UP, Vector3.FORWARD)
	if voyage.world.rally_active:
		rally_count += 1
		_expect(voyage.remaining == 0 and not voyage.world.cleared, "Rally must block next wave without clearing encounter")
		voyage.world._process(0.016)
		_expect(voyage.world.rally_active, "Standing at combat center does not activate remote objective")
		for step in range(12):
			if not voyage.world.rally_active: break
			voyage.player.position = voyage.world.navigation_goal()
			voyage.world._process(0.016)
		_expect(not voyage.world.rally_active and voyage.world.wave_pending, "Reaching marked objective schedules reinforcements")
	if voyage.world.wave_pending:
		_expect(voyage.remaining == 0, "Warning precedes reinforcement spawn")
		await create_timer(0.76, true).timeout
	_check_spawn_clearance()

func _shoot_prop(prop: StaticBody3D) -> void:
	var query := PhysicsRayQueryParameters3D.create(prop.global_position + Vector3(0, 0, 2), prop.global_position, 1)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and hit.collider == prop, "Prop is not reachable with a world-layer ray")
	if not hit.is_empty() and hit.collider.has_method("receive_shot"):
		hit.collider.receive_shot(24.0, hit.position, Vector3.FORWARD)

func _find_prop(kind: String) -> StaticBody3D:
	for child in voyage.world.get_children():
		if child.get_script() == Prop and child.kind == kind:
			return child
	return null

func _run() -> void:
	_cleanup()
	_new_voyage()
	_expect(voyage.mode == "title" and voyage.saved.is_empty(), "Fresh title state")
	var options := {"volume":0.0, "sensitivity":0.6, "reduced_motion":true}
	voyage.bridge.options_changed.emit(options)
	voyage.bridge.begin.emit(false)
	_freeze_stage()
	_expect(voyage.mode == "play" and voyage.chapter == 0 and voyage.remaining == 5, "New game state")
	_expect(voyage.player.position.distance_to(voyage.world.spawn_position()) < 0.01, "Initial spawn")
	voyage.bridge.pause_requested.emit()
	_expect(paused and voyage.mode == "paused", "Pause signal")
	voyage.bridge.resume_requested.emit()
	_expect(not paused and voyage.mode == "play", "Resume signal")
	await _trigger(0)
	for i in range(3): await _kill_wave()
	await _trigger(1)
	_expect(voyage.checkpoint == 1 and voyage.saved.checkpoint == 1, "Checkpoint save")
	var saved_inventory: Dictionary = voyage.saved.player.duplicate(true)
	voyage.player.hurt_cooldown = 0
	voyage.player.receive_damage(1000)
	_expect(voyage.mode == "dead" and paused, "Death signal pauses game")
	voyage.bridge.retry_requested.emit()
	_freeze_stage()
	_expect(voyage.mode == "play" and not paused and voyage.checkpoint == 1, "Retry restores checkpoint")
	_expect(voyage.player.snapshot() == saved_inventory, "Retry restores saved inventory")
	voyage.bridge.title_requested.emit()
	_expect(voyage.mode == "title" and voyage.session == null, "Return to title disposes stage")
	voyage.free()
	await process_frame
	_new_voyage()
	_expect(voyage.saved.checkpoint == 1 and voyage.settings == options, "Fresh instance reads save and options")
	voyage.bridge.begin.emit(true)
	_freeze_stage()
	_expect(voyage.checkpoint == 1 and voyage.player.snapshot() == saved_inventory, "Continue restores inventory")
	voyage.bridge.title_requested.emit()
	voyage.bridge.begin.emit(false)
	_expect(voyage.checkpoint == 0 and voyage.kills == 0 and voyage.settings == options, "New run resets progress and keeps options")
	for chapter in range(3):
		_expect(voyage.chapter == chapter, "Chapter transition")
		_observe_world()
		await physics_frame
		if chapter == 1:
			_check_service_exit()
		for point in range(3):
			await _trigger(point)
			_expect(voyage.checkpoint == point and voyage.remaining > 0, "Encounter trigger")
			await physics_frame
			await physics_frame
			var gate = voyage.world.gates[point]
			var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -(point + 1) * 36 + 2), Vector3(0, 1, -(point + 1) * 36 - 2), 1)
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and hit.collider == gate, "Live encounter gate blocks route")
			var old_point: int = voyage.checkpoint
			voyage.player.position.z = -(point + 1) * 36 - 3
			voyage.world._process(0.016)
			_expect(voyage.checkpoint == old_point and not voyage.world.cleared, "Cannot skip active encounter")
			voyage.player.position = Vector3(0, 0.15, -point * 36 - 8)
			if chapter == 0 and point == 0:
				var bell := _find_prop("bell")
				_expect(bell != null, "Bell exists")
				_shoot_prop(bell)
				var lured := 0
				for actor in get_nodes_in_group("enemies"):
					if actor.kind < 2 and actor.lure_time > 0: lured += 1
				_expect(lured > 0, "Bell signal lures workers")
			if chapter == 1 and point == 0:
				var hook := _find_prop("hook")
				_expect(hook != null, "Cargo hook exists")
				var victim = get_nodes_in_group("enemies")[0]
				victim.position = Vector3(hook.position.x, 0.15, hook.position.z)
				_shoot_prop(hook)
				await create_timer(0.5, true).timeout
				_expect(hook.used and victim.dead, "Hook drops cargo and damages enemy")
			for wave in range(5 if point == 1 else (3 if point == 0 else 2)):
				await _kill_wave()
			_expect(voyage.remaining == 0 and voyage.world.cleared, "Encounter clears after final wave")
			_expect(voyage.mode == "play", "Clear alone does not finish chapter")
			_expect(voyage.player.hp > 0, "Supply keeps living player")
		if chapter == 2:
			var ramp_query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -111), Vector3(0, -1, -111), 1)
			var ramp_hit := root.world_3d.direct_space_state.intersect_ray(ramp_query)
			_expect(not ramp_hit.is_empty() and absf(ramp_hit.position.y) < 0.02, "Ramp starts flush with the deck; no unsupported step")
		voyage.player.position = voyage.world.exit_switch.position + Vector3(0, 0, 1.5)
		voyage.world._process(0.016)
		if chapter == 2:
			_expect(voyage.mode == "play" and voyage.world.finished, "Ramp begins before departure result")
			await create_timer(2.2, true).timeout
		else:
			await process_frame
	_expect(wave_count == 30 and checkpoint_count == 9, "Campaign must contain 30 waves and nine checkpoints")
	_expect(rally_count == 9, "Each chapter has entrance, switch and return routes")
	_expect(boss_count == 1, "Exactly one final captain")
	_expect(voyage.mode == "won" and voyage.saved.is_empty() and voyage.session == null, "Departure clears save and stage")
	var config := ConfigFile.new()
	_expect(config.load(save_path) == OK and config.get_value("run", "entry", null) == {}, "Completion persisted")
	_expect(config.get_value("options", "values", {}) == options, "Completion preserves options")
	voyage.bridge.begin.emit(false)
	_freeze_stage()
	_expect(voyage.mode == "play" and voyage.chapter == 0 and voyage.kills == 0, "Restart after victory")
	voyage.sound.stop_all()
	await create_timer(0.12, true).timeout
	voyage.free()
	await create_timer(0.12, true).timeout
	_cleanup()
	if failures == 0:
		print("PASS campaign: title, pause, death/retry, disk continue, 9 checkpoints, 30 waves, bell, cargo, gate blockade, captain, ramp departure, restart/options")
	quit(0 if failures == 0 else 1)

func _check_spawn_clearance() -> void:
	for actor in get_nodes_in_group("enemies"):
		var shape := CapsuleShape3D.new()
		shape.radius = 0.38 if actor.kind < 2 else 0.55
		shape.height = 1.8 if actor.kind < 2 else 2.4
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = actor.global_position + Vector3.UP * shape.height * 0.5
		query.collision_mask = 1
		var hits := root.world_3d.direct_space_state.intersect_shape(query)
		_expect(hits.is_empty(), "Enemy spawned inside world geometry at %s" % actor.global_position)

func _check_service_exit() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = Vector3(13, 4.05, -66)
	query.collision_mask = 1
	_expect(root.world_3d.direct_space_state.intersect_shape(query).is_empty(), "Coldstore return opening must fit the player capsule")
