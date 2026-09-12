class_name KaijuPlayer
extends CharacterBody3D

@export var run_speed: float = 6.5
@export var acceleration: float = 32.0
@export var dash_speed: float = 24.0
@export var dash_duration: float = .30
@export var recharge_seconds: float = 2.4
var stage: int = 0
var body_scale: float = 1.0
var mutation: int = -1
var evolved: bool = false
var facing: Vector3 = Vector3.BACK
var dash_direction: Vector3 = Vector3.ZERO
var dash_left: float = 0
var charges: int = 2
var recharge: float = 0
var bite_left: float = 0
var bite_pending: bool = false
var invulnerable: float = 0
var ability_cooldown: float = 0
var locked_anim: float = 0
var struck: Dictionary = {}
var game: Node
var was_moving: bool = false
@onready var visual: Node3D = $Visual
@onready var anim: AnimationPlayer = $Visual/AnimationPlayer

func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	anim.play("idle")

func _physics_process(delta: float) -> void:
	if game == null:
		game = get_tree().get_first_node_in_group("game")
	if game == null or not game.running:
		return
	invulnerable = maxf(0, invulnerable-delta)
	ability_cooldown = maxf(0, ability_cooldown-delta)
	locked_anim = maxf(0, locked_anim-delta)
	if charges < 2:
		recharge += delta
		if recharge >= recharge_seconds:
			charges += 1
			recharge = 0
	bite_left = maxf(0, bite_left-delta)
	if bite_pending and bite_left < .24:
		bite_pending = false
		bite_targets()
	var camera := get_viewport().get_camera_3d()
	var desired := read_movement(camera)
	if dash_left <= 0:
		facing = read_aim(camera)
	if wants_bite() and bite_left <= 0 and dash_left <= 0:
		start_bite()
	if dash_left > 0:
		dash_left -= delta
		velocity = dash_direction*dash_speed*(1.0+stage*.12)
		velocity.y = -1
	else:
		velocity.x = move_toward(velocity.x, desired.x*run_speed*(1+stage*.10), acceleration*delta)
		velocity.z = move_toward(velocity.z, desired.z*run_speed*(1+stage*.10), acceleration*delta)
		velocity.y = -1
	move_and_slide()
	if dash_left > 0:
		for i in get_slide_collision_count():
			var target := get_slide_collision(i).get_collider() as TownProp
			if target and not struck.has(target.get_instance_id()):
				struck[target.get_instance_id()] = true
				target.strike(dash_direction, 1 + stage)
	position.x = clampf(position.x, -33, 33)
	position.z = clampf(position.z, -33, 33)
	var visual_direction: Vector3 = desired if desired.length() > .1 and locked_anim <= 0 else facing
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(visual_direction.x, visual_direction.z), minf(1,delta*18))
	visual.visible = invulnerable <= 0 or fmod(invulnerable,.14) < .10
	var moving := Vector2(velocity.x,velocity.z).length() > .25
	if locked_anim <= 0:
		if moving:
			play_motion("run" if velocity.length() > 3 else "walk")
			anim.speed_scale = clampf(velocity.length()/run_speed, .5, 1.25)
		elif was_moving:
			play_motion("stop")
			locked_anim = .23
		else:
			play_motion("idle")
		was_moving = moving

func read_movement(camera: Camera3D) -> Vector3:
	if camera == null:return Vector3.ZERO
	var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var right := camera.global_basis.x
	var forward := camera.global_basis.z
	right.y = 0
	forward.y = 0
	return (right.normalized()*axis.x+forward.normalized()*axis.y).limit_length()

func read_aim(camera: Camera3D) -> Vector3:
	if camera == null:return facing
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_dir := camera.project_ray_normal(mouse)
	var aim = Plane(Vector3.UP, .5).intersects_ray(ray_origin, ray_dir)
	if aim != null:
		var towards: Vector3 = aim-global_position
		towards.y = 0
		if towards.length() > .4:return towards.normalized()
	return facing

func wants_bite() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		start_dash()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and bite_left <= 0 and dash_left <= 0:
		start_bite()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		ability()

func play_motion(motion: String) -> void:
	if anim.current_animation != motion or not anim.is_playing():
		anim.speed_scale = 1.0
		anim.play(motion, .055)

func start_bite() -> void:
	bite_left = .4
	bite_pending = true
	play_motion("bite")
	locked_anim = .38

func bite_targets() -> void:
	var nearest: TownProp = null
	var distance := 100.0
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as TownProp
		if target == null or target.consumed:
			continue
		var offset: Vector3 = target.global_position-global_position
		offset.y = 0
		var reach := 1.75*body_scale + (.7 if target.kind != 5 else 1.4)
		if offset.length() <= reach and offset.normalized().dot(facing) > .25 and offset.length() < distance:
			nearest = target
			distance = offset.length()
	if nearest:
		if nearest.edible(stage):
			if nearest.kind == 6:
				nearest.strike(facing, 1+stage, false)
			else:
				nearest.consume()
		elif nearest.kind == 1:
			game.notice("車はまだ大きい。Spaceで弾こう", 1.2)
		else:
			game.notice("硬い装甲！ 車をぶつけるか、突進で崩そう", 1.2)

func start_dash() -> void:
	if charges <= 0 or dash_left > 0:
		return
	charges -= 1
	dash_left = dash_duration
	dash_direction = facing
	struck.clear()
	bite_pending = false
	play_motion("dash")
	locked_anim = dash_duration
	game.sound("dash", 1-stage*.1)
	game.ring(global_position, 1.0*body_scale, Color("fff2c3"), .25)

func ability() -> void:
	if mutation < 0 or ability_cooldown > 0:
		return
	ability_cooldown = 5.0 if evolved else 7.0
	play_motion("dash")
	locked_anim = .35
	game.sound("power", .9)
	if mutation == 0:
		var last: Vector3 = global_position+Vector3.UP
		var count := 0
		for node in get_tree().get_nodes_in_group("targets"):
			var target := node as TownProp
			if target and target.kind > 0 and target.global_position.distance_to(last) < (10.0 if evolved else 7.0):
				game.beam(last, target.global_position+Vector3.UP, Color("b9ffe9"), .35, .13)
				last = target.global_position
				target.strike(facing, 2, true)
				count += 1
				if count >= (6 if evolved else 4):
					break
	elif mutation == 1:
		dash_left = .55 if evolved else .43
		dash_direction = facing
		struck.clear()
		for node in get_tree().get_nodes_in_group("targets"):
			var target := node as TownProp
			if target:
				var offset: Vector3 = target.global_position-global_position
				if offset.dot(facing) > 0 and offset.dot(facing) < 11 and offset.cross(facing).length() < 2.3:
					target.strike(facing, 4 if evolved else 3, true)
		game.beam(global_position+Vector3.UP, global_position+facing*10+Vector3.UP, Color("ffd184"), .28, .8)
	else:
		var landing: Vector3 = global_position+facing*7
		landing.x = clampf(landing.x,-32,32)
		landing.z = clampf(landing.z,-32,32)
		# Kinematic jump uses collision-swept motion; cosmetic arc does not move the body through walls.
		dash_direction = facing
		dash_left = .33
		invulnerable = .65
		var tween := create_tween()
		tween.tween_property(visual,"position:y",3.0,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual,"position:y",0.0,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(stomp)

func stomp() -> void:
	var radius := 8.0 if evolved else 5.5
	game.ring(global_position,radius,Color("ffe5a3"),.45)
	game.impact(global_position,1.4,Color("ffe5a3"))
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as TownProp
		if target and target.global_position.distance_to(global_position) < radius:
			target.strike((target.global_position-global_position).normalized(),3,true)

func grow_to(next_stage: int) -> void:
	stage = next_stage
	body_scale = [1.0,1.6,2.3][stage]
	var tween := create_tween()
	tween.tween_property(self,"scale",Vector3.ONE*body_scale,.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	play_motion("grow")
	locked_anim = .9
	invulnerable = 2
	game.sound("grow", 1.0)

func hurt(amount: float, source: Vector3) -> void:
	if invulnerable > 0 or dash_left > 0:
		return
	invulnerable = 1.1
	game.health = maxf(0,game.health-amount)
	play_motion("hurt")
	locked_anim = .32
	velocity += (global_position-source).normalized()*6
	game.sound("hurt", 1.0)
	game.impact(global_position+Vector3.UP, .6, Color("f07864"))
	if game.health <= 0:
		game.finish(false)
