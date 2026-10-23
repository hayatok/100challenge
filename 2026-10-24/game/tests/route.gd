extends SceneTree
## Enemy-free route regression fixture. Camera aim and Input actions are scripted;
## this is not evidence of a person completing either distribution.
const WORLD = preload("res://scripts/world.gd")
const PLAYER = preload("res://scripts/player.gd")
var player: CharacterBody3D
var world: Node3D
var captures: String = ""
var failed: bool = false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): captures = argument.trim_prefix("--capture-dir=")
	call_deferred("run")

func fail(message: String) -> void:
	if failed: return
	failed = true
	push_error("ROUTE_FAIL " + message)
	quit(1)

func tick(count: int = 1) -> void:
	for frame in count: await physics_frame

func aim(target: Node3D) -> void:
	var offset := target.global_position - (player.global_position + Vector3.UP*1.3)
	player._rig.yaw = atan2(-offset.x,-offset.z)
	player._rig.pitch = clampf(atan2(offset.y,Vector2(offset.x,offset.z).length()),-1.12,0.72)
	player.camera.look_at(target.global_position)

func press(action: String, frames: int = 2) -> void:
	Input.action_press(action)
	await tick(frames)
	Input.action_release(action)
	await tick(2)

func wire_to(target: Node3D, label: String) -> bool:
	for frame in 12:
		aim(target)
		await tick()
		if player.current_target == target: break
	if player.current_target != target:
		print("SELECT_DEBUG eligible=",player._eligible(target)," sweep=",player._wire_path_clear(target)," current=",player.current_target.global_position if player.current_target else Vector3.ZERO," desired=",target.global_position)
		fail(label + " cannot select intended target at " + str(player.global_position))
		return false
	await press("wire")
	if player.state_name != "wire":
		fail(label + " wire did not start")
		return false
	for frame in 240:
		await tick()
		if player.global_position.y < -5:
			fail(label + " fell below route")
			return false
		if frame > 8 and player.is_on_floor() and player.state_name != "wire":
			print("ROUTE_LAND ",label," ",player.global_position)
			return true
	fail(label + " landing timeout")
	return false

func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label + ".png"))

func run() -> void:
	create_timer(70.0).timeout.connect(func(): fail("global timeout"))
	for action in ["move_left","move_right","move_forward","move_back","jump","dash","attack","heavy","wire","lock","pause"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	world = WORLD.new()
	root.add_child(world)
	player = PLAYER.new()
	root.add_child(player)
	player.reset_at(world.get_spawn())
	player.set_active(true)
	await tick(8)
	var targets := get_nodes_in_group("tether_targets")
	if targets.size() != 6:
		fail("unexpected target count")
		return
	for index in [0,1,2,3,4]:
		if not await wire_to(targets[index],"anchor_%d" % index): return
		if index == 3: await capture("shoulder")
	var core: Node3D = targets[5]
	if player.global_position.y < 7.0:
		fail("upper terrace not reached")
		return
	for hit in 3:
		for frame in 5:
			aim(core)
			await tick()
		await press("attack")
		await tick(36)
		if core.health != 2-hit:
			fail("real sword attack did not produce core hit " + str(hit+1))
			return
	if core.is_available():
		fail("core survived three sword attacks")
		return
	await capture("core_destroyed")
	# Jump across the return gap using the ordinary movement input, then plunge.
	player._rig.yaw = PI
	player._rig.pitch = -0.20
	await press("jump")
	Input.action_press("move_forward")
	var reached_return := false
	for frame in 100:
		await tick()
		if player.global_position.z > -24.8:
			reached_return = true
			break
	Input.action_release("move_forward")
	if not reached_return:
		fail("return jump could not reach arena")
		return
	await press("heavy")
	if player.state_name != "plunge":
		fail("return heavy did not start plunge")
		return
	var landed := false
	for frame in 100:
		await tick()
		if player.is_on_floor():
			landed = true
			break
	if not landed or player.global_position.y < 0.9 or player.global_position.z < -25.5:
		fail("plunge missed arena " + str(player.global_position))
		return
	await capture("return")
	print("ROUTE_FULL_SEQUENCE_PASS feet=",player.global_position)
	for phase in [-1.0,1.0]:
		if not await phase_case(phase): return
	print("ROUTE_PASS enemy_free full_sequence_and_both_shoulder_extremes")
	quit(0)

func phase_case(phase: float) -> bool:
	# Independent geometry boundary case: a fresh world and initial player placement.
	# Shoulder is held at one motion extreme; the full-sequence case above moves normally.
	player.set_active(false)
	player.queue_free()
	world.queue_free()
	await tick(2)
	world = WORLD.new()
	root.add_child(world)
	var giant: Node3D
	for child in world.get_children():
		if child.get_script() == load("res://scripts/colossus.gd"): giant = child
	if not giant:
		fail("missing giant in phase case")
		return false
	giant.set_physics_process(false)
	giant.shoulder.position = Vector3(4+phase*0.45,6+phase*0.45,1)
	player = PLAYER.new()
	root.add_child(player)
	player.reset_at(Vector3(5,1.05,-22))
	player.set_active(true)
	await tick(8)
	var targets := get_nodes_in_group("tether_targets")
	if not await wire_to(targets[3],"phase_%s_shoulder" % phase): return false
	if player.global_position.y < 5.9:
		fail("phase shoulder landing missed")
		return false
	if not await wire_to(targets[4],"phase_%s_upper" % phase): return false
	if player.global_position.y < 7.0:
		fail("phase upper landing missed")
		return false
	return true
