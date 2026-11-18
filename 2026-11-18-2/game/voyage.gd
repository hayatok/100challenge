extends Node3D

const Geometry = preload("res://build/harbor_geometry.gd")
const RushDirector = preload("res://combat/rush_director.gd")
const Harbor = preload("res://world/harbor.gd")
const Player = preload("res://combat/player.gd")
const Enemy = preload("res://combat/enemy.gd")
const Bridge = preload("res://ui/bridge.gd")
const Sound = preload("res://sound.gd")
const BOSS_CUES := {"boss_warning":"鎖が上がった。横へ！", "boss_exposed":"船長の肩を狙え！", "boss_phase":"船長が向きを変えた。次は二連突進！"}

var bridge := Bridge.new()
var sound := Sound.new()
var session: Node3D
var world: Harbor
var player: Player
var chapter := 0
var checkpoint := 0
var remaining := 0
var kills := 0
var elapsed := 0.0
var objective := ""
var mode := "title"
var rush: RushDirector
var rush_best := 0
var rush_bonus := 0
var bonus_left := 0.0
var incoming_kinds: Array = []
var incoming_points: Array = []
var arrival_left := 0.0
var stride_left := 0.0
var saved: Dictionary = {}
var settings: Dictionary = {}
var storage := "user://voyage.cfg"
var hud_cache: Dictionary = {}
var boss_cue := ""
var cue_left := 0.0

func _fit_render_resolution() -> void:
	var framebuffer := DisplayServer.window_get_size()
	var longest := maxi(framebuffer.x, framebuffer.y)
	if longest > 0:
		var target := 720.0 if DisplayServer.is_touchscreen_available() else 1440.0
		get_viewport().scaling_3d_scale = clampf(target / longest, 0.25, 1.0)

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_render_resolution)
	_fit_render_resolution()
	var config := ConfigFile.new()
	if config.load(storage) == OK:
		var stored_settings = config.get_value("options", "values", {})
		if stored_settings is Dictionary: settings = stored_settings
		var best = config.get_value("rush", "best", 0)
		if best is int and best >= 0: rush_best = best
		var data = config.get_value("run", "entry", {})
		if data is Dictionary and _valid_entry(data): saved = data
	add_child(sound)
	add_child(bridge)
	bridge.begin.connect(_begin)
	bridge.rush_requested.connect(_begin_rush)
	bridge.retry_requested.connect(_retry)
	bridge.resume_requested.connect(_resume)
	bridge.pause_requested.connect(_pause)
	bridge.weapon_requested.connect(func(slot: int):
		if mode == "play": player.set_weapon(slot))
	bridge.title_requested.connect(_title)
	bridge.options_changed.connect(_configure)
	bridge.set_options(settings)
	sound.set_volume(settings.get("volume",0.7))
	bridge.show_title(not saved.is_empty(), rush_best)

func _valid_entry(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("player") is Dictionary: return false
	if data.get("chapter") not in [0,1,2] or data.get("checkpoint") not in [0,1,2]: return false
	var inventory: Dictionary = data.player
	for key in ["ammo","owned"]:
		if not inventory.get(key) is Array or inventory[key].size() != 3: return false
	for rounds in inventory.ammo:
		if not rounds is int or rounds < 0: return false
	for owned in inventory.owned:
		if not owned is bool: return false
	if inventory.get("weapon") not in [0,1,2]: return false
	if not (data.get("kills",0) is int and (data.get("elapsed",0) is float or data.get("elapsed",0) is int)): return false
	return inventory.get("hp") is float or inventory.get("hp") is int

func _commit() -> void:
	var config := ConfigFile.new()
	config.set_value("options", "values", settings)
	config.set_value("run", "entry", saved)
	config.set_value("rush", "best", rush_best)
	var scratch := storage + ".tmp"
	if config.save(scratch) == OK:
		var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(scratch), ProjectSettings.globalize_path(storage))
		if err != OK: push_warning("Could not update saved voyage: " + error_string(err))

func _configure(values: Dictionary) -> void:
	settings = values.duplicate()
	if is_instance_valid(player): player.configure(settings)
	if rush and world: world.set_rush_flash(settings.get("flash",true))
	sound.set_volume(settings.get("volume",0.7))
	_commit()

func _begin(continued: bool) -> void:
	if continued and _valid_entry(saved):
		_retry()
		return
	kills = 0
	elapsed = 0.0
	_enter(0,0,{})

func _begin_rush() -> void:
	_enter(0, 0, {}, true)

func _retry() -> void:
	if not _valid_entry(saved): return
	kills = int(saved.get("kills",0))
	elapsed = float(saved.get("elapsed",0.0))
	_enter(saved.chapter,saved.checkpoint,saved.player)

func _dispose_stage() -> void:
	stride_left = 0.0
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
	incoming_kinds.clear()
	incoming_points.clear()
	rush = null
	session = null
	world = null
	player = null
	remaining = 0

func _enter(next_chapter: int, point: int, inventory: Dictionary, arcade := false) -> void:
	_dispose_stage()
	chapter = next_chapter
	checkpoint = point
	mode = "play"
	get_tree().paused = false
	session = Node3D.new()
	add_child(session)
	world = Harbor.new()
	session.add_child(world)
	world.bell_rang.connect(_ring)
	world.sound.connect(sound.effect)
	if arcade:
		rush = RushDirector.new()
		bonus_left = 0.0
		world.rush_discharge.connect(_discharge)
		world.build_rush()
		world.set_rush_flash(settings.get("flash",true))
	else:
		world.objective.connect(func(line: String): objective = line)
		world.spawn_wave.connect(_spawn)
		world.encounter_changed.connect(_checkpoint)
		world.chapter_finished.connect(_exit_reached)
		world.supplied.connect(_supply)
		world.build(chapter,checkpoint)
	Geometry.batch(world)
	player = Player.new()
	player.position = world.spawn_position()
	player.rotation.y = world.spawn_yaw()
	session.add_child(player)
	player.configure(settings)
	if arcade:
		player.restore({"weapon":0, "owned":[true,true,false], "ammo":[120,24,0]})
	elif not inventory.is_empty(): player.restore(inventory)
	player.died.connect(_die)
	player.feedback.connect(_feedback)
	if chapter >= 1 and not player.owned[1]: player.unlock_weapon(1)
	if chapter >= 2 and not player.owned[2]: player.unlock_weapon(2)
	sound.set_scene(chapter)
	hud_cache.clear()
	cue_left = 0.0
	bridge.show_play()
	if arcade:
		sound.battle(false)
		_advance_rush(0.0)
	else:
		world.start_encounter()
		_save_position()
	_update_hud()

func _checkpoint(point: int) -> void:
	checkpoint = point
	if chapter == 0 and point == 1 and not player.owned[1]: player.unlock_weapon(1)
	_save_position()

func _save_position() -> void:
	saved = {"version":1, "chapter":chapter, "checkpoint":checkpoint, "kills":kills,
		"elapsed":elapsed, "player":player.snapshot()}
	_commit()

func _spawn(kinds: Array, positions: Array) -> void:
	remaining += kinds.size()
	for i in range(kinds.size()):
		var actor := Enemy.new()
		actor.setup(int(kinds[i]),player)
		actor.position = positions[i]
		actor.defeated.connect(_defeated)
		actor.feedback.connect(_feedback)
		session.add_child(actor)
	sound.battle(3 in kinds)

func _defeated(_enemy: Node3D) -> void:
	if mode != "play": return
	remaining -= 1
	if rush:
		rush.register_kill()
		return
	kills += 1
	if remaining == 0:
		# Spawning another wave can synchronously repopulate remaining.
		world.notify_clear()
		if remaining == 0 and (world.cleared or world.rally_active): sound.quiet()

func _ring(point: Vector3) -> void:
	for actor in get_tree().get_nodes_in_group("enemies"):
		if actor.kind < 2: actor.lure(point, 7.0 if rush else 4.5)

func _discharge(point: Vector3, radius: float) -> void:
	if not rush or mode != "play": return
	var before := rush.kills
	for actor in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = actor.global_position - point
		offset.y = 0.0
		if offset.length_squared() <= radius * radius:
			actor.receive_shot(270.0, actor.global_position + Vector3.UP, offset.normalized())
	var previous := rush.score
	rush.register_discharge(rush.kills - before)
	if rush.score > previous:
		rush_bonus = rush.score - previous
		bonus_left = 2.0

func _advance_rush(delta: float) -> void:
	bonus_left = maxf(0.0, bonus_left - delta)
	var stage_before := rush.stage
	# Let the announced group arrive before reserving another spawn lane.
	var occupied := remaining if incoming_kinds.is_empty() else RushDirector.ALIVE_LIMITS.back() as int
	var kinds := rush.advance(delta, occupied)
	if rush.finished:
		_finish_rush(true)
		return
	if rush.stage > stage_before:
		player.refill()
		player.give_health(25)
	if not incoming_kinds.is_empty():
		arrival_left -= delta
		if arrival_left <= 0.0:
			var arriving: Array = []
			var positions: Array = []
			for i in range(incoming_points.size()):
				if player.global_position.distance_to(incoming_points[i]) >= 3.0:
					arriving.append(incoming_kinds[i])
					positions.append(incoming_points[i])
			if not arriving.is_empty(): _spawn(arriving, positions)
			incoming_kinds.clear()
			incoming_points.clear()
	if not kinds.is_empty():
		incoming_kinds = kinds
		incoming_points = world.rush_spawn_points(rush.wave, kinds.size(), player.global_position)
		arrival_left = 1.0
		world.warn_rush_spawns(incoming_points, arrival_left)

func _finish_rush(survived: bool) -> void:
	if mode != "play": return
	mode = "rush_result"
	player.set_controls(Vector2.ZERO, Vector2.ZERO, false)
	session.process_mode = Node.PROCESS_MODE_DISABLED
	var record := rush.score > rush_best
	if record:
		rush_best = rush.score
		_commit()
	sound.stop_all()
	if survived: sound.ending()
	bridge.show_rush_result({"score":rush.score, "best":rush_best, "kills":rush.kills,
		"best_discharge":rush.best_discharge, "survived":survived, "new_best":record})

func _supply() -> void:
	player.give_health(45)
	player.refill()

func _feedback(event: String, point: Vector3) -> void:
	sound.effect(event,point)
	if BOSS_CUES.has(event):
		boss_cue = BOSS_CUES[event]
		cue_left = 1.4 if event == "boss_warning" else 2.0
	if event in ["hurt","hit","kill"]: bridge.impact(event)
	if event == "hurt" and is_instance_valid(player):
		var incoming := player.to_local(point)
		bridge.hurt_from(Vector2(incoming.x, incoming.z))

func _exit_reached() -> void:
	if mode != "play": return
	if chapter < 2:
		var carried := player.snapshot()
		_enter(chapter+1,0,carried)
	else:
		mode = "won"
		_dispose_stage()
		saved.clear()
		_commit()
		sound.ending()
		bridge.show_result({"kills":kills, "time_seconds":elapsed})

func _physics_process(delta: float) -> void:
	if mode != "play" or not is_instance_valid(player): return
	if rush:
		_advance_rush(delta)
		if mode != "play": return
	else:
		elapsed += delta
	cue_left = maxf(0.0,cue_left-delta)
	var control := bridge.consume_controls()
	player.set_controls(control.move,control.look,control.fire)
	stride_left -= delta * Vector2(player.velocity.x,player.velocity.z).length()
	if stride_left <= 0 and control.move.length() > 0.15 and player.is_on_floor():
		sound.effect("step%d" % chapter, player.global_position)
		stride_left = 1.85
	_update_hud()

func _update_hud() -> void:
	var state := player.snapshot()
	state.ammo = state.ammo[state.weapon]
	if rush:
		state.merge({"rush":true, "seconds":ceili(rush.time_left), "score":rush.score,
			"stage":rush.stage, "bell_ready":world.rush_bell_ready(),
			"bonus":rush_bonus if bonus_left > 0.0 else 0})
	else:
		state.merge({"chapter":chapter+1,"checkpoint":str(checkpoint+1)+"/3","kills":kills,"objective":boss_cue if cue_left > 0 else objective})
	if state != hud_cache:
		hud_cache = state
		bridge.update_hud(state)

func _pause() -> void:
	if mode != "play": return
	mode = "paused"
	player.set_controls(Vector2.ZERO,Vector2.ZERO,false)
	get_tree().paused = true
	bridge.show_pause()

func _resume() -> void:
	if mode != "paused": return
	mode = "play"
	get_tree().paused = false
	bridge.show_play()

func _die() -> void:
	if mode != "play": return
	if rush:
		_finish_rush(false)
		return
	mode = "dead"
	get_tree().paused = true
	bridge.show_death()

func _title() -> void:
	mode = "title"
	get_tree().paused = false
	_dispose_stage()
	sound.stop_all()
	bridge.show_title(not saved.is_empty(), rush_best)
