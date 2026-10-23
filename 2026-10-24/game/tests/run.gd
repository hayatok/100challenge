extends SceneTree
## Physics fixtures: regression evidence for rules, not a natural playthrough.

var _failures: int = 0
var _world: Node3D
var _player: CharacterBody3D
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WorldScript = preload("res://scripts/world.gd")

func _initialize() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "dash", "attack", "heavy", "wire", "lock"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _enemy(at: Vector3) -> CharacterBody3D:
	var enemy := EnemyScript.new()
	enemy.position = at
	root.add_child(enemy)
	enemy.player = _player
	return enemy

func _run() -> void:
	_world = WorldScript.new()
	root.add_child(_world)
	_player = PlayerScript.new()
	root.add_child(_player)
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	await _ticks(8)
	await _kill_resource_rules()
	await _wire_rules()
	await _target_snapshot_rules()
	await _enemy_rules()
	await _attack_participation_rules()
	await _core_rules()
	await _pause_reset_rules()
	if _failures == 0:
		print("PASS: TENSAI physics fixtures (kills/resources, wire/path/history, core, pause/reset)")
	else:
		push_error("TENSAI fixtures failed: %d" % _failures)
	quit(0 if _failures == 0 else 1)

func _kill_resource_rules() -> void:
	_player.reset_at(Vector3(0, 4, 7))
	_player.set_active(true)
	await _ticks(2)
	_player.air_dashes = 0
	var enemy := _enemy(_player.global_position + Vector3(0, 0, -1.4))
	_player.call("_strike", 100, false, 3.0)
	_check(_player.total_kills == 1 and _player.air_dashes == 1, "one kill awards exactly one air dash")
	_player.call("_strike", 100, false, 3.0)
	_check(_player.total_kills == 1 and _player.air_dashes == 1, "dead enemy cannot award twice")
	_player.air_dashes = 2
	var second := _enemy(_player.global_position + Vector3(0, 0, -1.4))
	_player.call("_strike", 100, false, 3.0)
	_check(_player.total_kills == 2 and _player.air_dashes == 2, "kill refill is capped at two")
	_player.call("_start_dash", Vector3.FORWARD, false)
	_player.call("_start_dash", Vector3.FORWARD, false)
	_check(_player.air_dashes == 0, "two aerial dashes consume two charges")
	enemy.queue_free()
	second.queue_free()
	await _ticks(1)

func _wire_rules() -> void:
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	await _ticks(8)
	var anchor: Node3D = null
	for target in get_nodes_in_group("tether_targets"):
		if target.get_meta("kind", "") == "anchor" and target.global_position.distance_to(Vector3(0, 2.7, -2)) < 0.2:
			anchor = target
	_check(anchor != null, "first route anchor exists")
	if not anchor:
		return
	_check(_player.call("_eligible", anchor), "first anchor is visibly reachable from spawn")
	_player.current_target = anchor
	_player.call("_start_wire", _player.current_target)
	await _ticks(70)
	_check(_player.global_position.z < 0.0 and _player.is_on_floor(), "real tether motion reaches bridge and lands")

	# A thin world collider blocks the complete capsule path, even at wire speed.
	_player.reset_at(Vector3(0, 0.2, 7))
	_player.set_active(true)
	await _ticks(3)
	_player.current_target = anchor
	_player.call("_start_wire", _player.current_target)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 7, 0.08)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = Vector3(0, 3, 3.5)
	await _ticks(2)
	_check(not _player.call("_eligible", anchor), "thin wall excludes a blocked tether candidate")
	await _ticks(24)
	_check(_player.global_position.z > 3.5, "active fast wire cannot tunnel through a newly introduced thin wall")
	_check(_player.state_name != "wire", "wall contact releases active wire")
	wall.queue_free()
	await _ticks(2)

	_player.reset_at(Vector3(0, 4, 7))
	_player.set_active(true)
	await _ticks(2)
	var enemy := _enemy(_player.global_position + Vector3(0, 0, -2))
	_player.current_target = enemy
	_player.call("_start_wire", _player.current_target)
	_check(_player.state_name == "wire", "airborne enemy tether starts")
	_check(_player.get("_wire_history").has(enemy.get_instance_id()), "enemy tether records its identity")
	_check(not _player.call("_eligible", enemy), "same airborne enemy cannot be selected again")
	enemy.receive_hit(100, false, _player.global_position)
	await _ticks(2)
	_check(_player.state_name != "wire" and _player.get("_wire_target") == null, "target death releases an active wire")
	await _ticks(90)
	_check(_player.is_on_floor() and _player.get("_wire_history").is_empty(), "landing clears enemy connection history")

func _target_snapshot_rules() -> void:
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	await _ticks(8)
	var enemy := _enemy(_player.global_position + Vector3(0, 0, -1.6))
	_player.current_target = enemy
	var press := InputEventAction.new()
	press.action = "wire"
	press.pressed = true
	_player.call("_unhandled_input", press)
	enemy.receive_hit(100, false, _player.global_position)
	_player.call("_update_target")
	Input.action_press("wire")
	await _ticks(2)
	Input.action_release("wire")
	_check(_player.current_target != null and _player.current_target != enemy, "a replacement candidate exists after displayed target dies")
	_check(_player.get("_wire_target") == null and _player.state_name != "wire", "E on a just-invalid displayed target never substitutes another candidate")

func _enemy_rules() -> void:
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	await _ticks(8)
	var spawn := Vector3(0, 0.1, 5.2)
	var enemy := _enemy(spawn)
	enemy.receive_hit(1, true, _player.global_position)
	enemy.global_position = Vector3(30, -21, 0)
	await _ticks(2)
	_check(enemy.global_position.distance_to(spawn) < 1.0 and enemy.is_available(), "airborne living enemy crossing fall boundary recovers to its spawn")
	_check(enemy.health == 89, "fall recovery preserves enemy damage instead of granting a fresh life")
	enemy.queue_free()
	await _ticks(2)
	enemy = _enemy(spawn)
	await _ticks(8)
	_check(enemy.state_name == "windup", "visible nearby enemy starts an announced attack")
	_player.get("_rig").yaw = PI
	await _ticks(64)
	_check(_player.health == 86, "turning camera after windup does not cancel a geometrically valid strike")
	enemy.queue_free()
	_player.get("_rig").yaw = 0.0
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	await _ticks(8)
	enemy = _enemy(spawn)
	await _ticks(8)
	_check(enemy.state_name == "windup", "second visible enemy begins its attack before cover appears")
	var cover := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.12)
	collider.shape = shape
	cover.add_child(collider)
	cover.position = Vector3(0, 1.4, 6.1)
	root.add_child(cover)
	await _ticks(64)
	_check(_player.health == 100, "world cover still blocks an attack committed before the cover appeared")
	enemy.queue_free()
	cover.queue_free()
	await _ticks(2)

func _attack_participation_rules() -> void:
	_player.reset_at(_world.get_spawn())
	_player.set_active(true)
	# Keep the observer in place while multiple real enemies compete for attack slots.
	_player.set("_invulnerable", 10.0)
	await _ticks(8)
	var enemies: Array[CharacterBody3D] = []
	for x in [-1.0, 0.0, 1.0]:
		enemies.append(_enemy(Vector3(x, 0.1, 5.4)))
	var participants: Dictionary = {}
	var exceeded := false
	for i in range(140):
		await physics_frame
		var committed := 0
		for enemy in enemies:
			if enemy.state_name in ["windup", "strike"]:
				committed += 1
				participants[enemy.get_instance_id()] = true
		if committed > 1:
			exceeded = true
	_check(not exceeded, "three nearby enemies never wind up or strike simultaneously")
	_check(participants.size() >= 2, "attack slot transfers to another enemy after recovery")
	for enemy in enemies:
		enemy.queue_free()
	await _ticks(2)

func _core_rules() -> void:
	var core: Node3D = null
	for target in get_nodes_in_group("tether_targets"):
		if target.get_meta("kind", "") == "core":
			core = target
	_check(core != null, "colossus core exists")
	if not core:
		return
	_check(not core.receive_hit(100, false, core.global_position + Vector3.RIGHT * 5), "core rejects attacks outside four meters")
	_check(core.receive_hit(26, false, core.global_position + Vector3.RIGHT), "core accepts nearby hit")
	_check(not core.receive_hit(26, false, core.global_position + Vector3.RIGHT), "core cooldown rejects immediate repeated hit")
	await _ticks(29)
	_check(core.receive_hit(26, false, core.global_position + Vector3.RIGHT), "core accepts second hit after cooldown")
	_check(core.is_available(), "two accepted hits do not finish core")
	await _ticks(29)
	_check(core.receive_hit(26, false, core.global_position + Vector3.RIGHT), "third accepted hit breaks core")
	_check(not core.is_available(), "core becomes unavailable after three hits")
	_check(not core.receive_hit(26, false, core.global_position), "destroyed core rejects further hits")
	_check(_player.total_kills == 0, "core hits never award an enemy kill")

func _pause_reset_rules() -> void:
	_player.reset_at(Vector3(0, 4, 7))
	_player.set_active(true)
	await _ticks(3)
	_player.call("_start_dash", Vector3.FORWARD, false)
	await _ticks(1)
	_player.set("_jump_buffer", 0.13)
	_player.set("_attack_buffer", 0.14)
	Input.action_press("attack")
	var before := _player.global_position
	var speed_before := _player.velocity
	var state_before: String = _player.state_name
	var time_before: float = _player.get("_action_time")
	_player.clear_input()
	_check(_player.velocity.is_equal_approx(speed_before) and _player.state_name == state_before and _player.get("_action_time") == time_before, "pause input clearing preserves velocity, action and action progress")
	_check(_player.get("_jump_buffer") == 0.0 and _player.get("_attack_buffer") == 0.0, "pause discards queued input")
	paused = true
	# SceneTree timers explicitly process while paused; actor physics must not.
	await create_timer(0.06, true).timeout
	_check(_player.global_position.is_equal_approx(before) and _player.velocity.is_equal_approx(speed_before), "tree pause freezes position and velocity")
	_check(_player.state_name == state_before and _player.get("_action_time") == time_before, "tree pause freezes action progress")
	paused = false
	await _ticks(2)
	_check(_player.global_position.distance_to(before) > 0.1 and _player.state_name == state_before, "resume continues the suspended dash")
	_check(float(_player.get("_action_time")) < time_before, "resumed action advances from the preserved progress")
	_check(_player.get("_attack_buffer") == 0.0 and _player.get("_blocked_until_release"), "held attack is ignored until released after resume")
	Input.action_release("attack")
	_check(_player.air_dashes == 1, "pause and resume preserve remaining dash resource")
	_player.set("_wire_history", {123: true})
	_player.health = 20
	_player.total_kills = 8
	_player.reset_at(_world.get_spawn())
	_check(_player.health == 100 and _player.air_dashes == 2 and _player.total_kills == 0, "reset restores health, resources and kill count")
	_check(_player.current_target == null and _player.get("_wire_target") == null and _player.get("_wire_history").is_empty(), "reset removes target references and connection history")
	_check(_player.velocity == Vector3.ZERO and _player.state_name == "idle" and _player.get("_action_time") == 0.0, "restart explicitly clears physical action and velocity")
