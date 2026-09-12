class_name TownEnemy
extends TownProp

@export var awareness_radius: float = 18.0
@export var telegraph_seconds: float = 1.15
@export var recovery_seconds: float = 2.6
var phase: String = "rest"
var timer: float = .8
var aim: Vector3 = Vector3.ZERO
var telegraph: Node3D
var charge_direction: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if game == null or not game.running or exposed or consumed:
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		return
	if global_position.distance_to(game.player.global_position) > awareness_radius:
		return
	timer -= delta
	if phase == "rest":
		if timer <= 0:
			aim = game.player.global_position
			phase = "aim"
			timer = telegraph_seconds if kind != 4 else 1.6
			if kind == 4:
				telegraph = game.warning_circle(aim, 3.2)
			else:
				var direction: Vector3 = (aim-global_position).normalized()
				model.rotation.y = atan2(direction.x,direction.z)
				telegraph = game.warning_line(global_position,aim, .45 if kind == 2 else 1.25)
			game.sound("warn", 1.05 if kind == 4 else .9, -12)
	elif phase == "aim" and timer <= 0:
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		if kind == 2:
			game.fire_shell(global_position+Vector3.UP*.75,aim+Vector3.UP*.75)
			phase = "rest"
			timer = recovery_seconds
		elif kind == 3:
			charge_direction = (aim-global_position).normalized()
			phase = "charge"
			timer = .7
		else:
			game.ring(aim,3.2,Color("ffad64"),.5)
			game.impact(aim,1.0,Color("ffad64"))
			if game.player.global_position.distance_to(aim) < 3.2+game.player.body_scale*.35:
				game.player.hurt(19,global_position)
			phase = "rest"
			timer = recovery_seconds+1
	elif phase == "charge":
		var hit := move_and_collide(charge_direction*12*delta)
		if hit:
			if hit.get_collider() == game.player:
				game.player.hurt(17,global_position)
			var obstacle := hit.get_collider() as TownProp
			if obstacle:
				obstacle.strike(charge_direction,1,true)
			timer = 0
		if timer <= 0:
			phase = "rest"
			timer = recovery_seconds+1.2
