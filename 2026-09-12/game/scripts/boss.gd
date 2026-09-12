extends TownEnemy

var awakened: bool = false
var cycle: int = 0
var gait: float = 0
var cores_left: int = 3
var bites_this_opening: int = 0
var barrage: Array[Vector3] = []
var warnings: Array[Node3D] = []

func _physics_process(delta: float) -> void:
	if game == null:game = get_tree().get_first_node_in_group("game")
	if game == null or not game.running or consumed:return
	hit_cooldown = maxf(0,hit_cooldown-delta)
	if not awakened:
		if global_position.distance_to(game.player.global_position) < 21:
			awakened = true
			game.notice("道路整備ロボ・ドーザン  接近！",3)
			game.boss = self
			timer = 1.7
		return
	timer -= delta
	if exposed:
		core.rotation.y += delta*2
		if timer <= 0:recover()
		return
	if phase == "rest" and timer <= 0:
		if cycle % 2 == 1:
			phase = "barrage"
			timer = 1.8
			barrage.clear()
			var center: Vector3 = game.player.global_position
			for offset in [Vector3.ZERO,Vector3(4,0,2),Vector3(-4,0,-2)]:
				barrage.append(center+offset)
				warnings.append(game.warning_circle(center+offset,2.8))
			game.notice("地面が割れる！ 印の外へ",2)
			game.sound("warn",.7)
		else:
			aim = game.player.global_position
			charge_direction = (aim-global_position).normalized()
			charge_direction.y = 0
			model.rotation.y = atan2(charge_direction.x,charge_direction.z)
			phase = "aim"
			timer = 1.6
			telegraph = game.warning_line(global_position,global_position+charge_direction*18,2.4)
			game.notice("突進が来る！ 横へ抜けて、足元を狙おう",2)
			game.sound("warn", .65)
	elif phase == "barrage" and timer <= 0:
		for warning in warnings:
			if is_instance_valid(warning):warning.queue_free()
		warnings.clear()
		for point in barrage:
			game.ring(point,2.8,Color("ffac74"),.45)
			game.impact(point,1.3,Color("ffac74"))
			if game.player.global_position.distance_to(point)<2.8+game.player.body_scale*.4:
				game.player.hurt(23,global_position)
		phase = "rest"
		timer = 1.0
		cycle += 1
	elif phase == "aim" and timer <= 0:
		if is_instance_valid(telegraph):telegraph.queue_free()
		phase = "charge"
		timer = 1.2
	elif phase == "charge":
		gait += delta*18
		var rig := model.get_node_or_null("Rig/Body")
		if rig:
			rig.get_node("LegL").rotation.x = sin(gait)*.42
			rig.get_node("LegR").rotation.x = -sin(gait)*.42
		var hit := move_and_collide(charge_direction*(13+3-cores_left)*delta)
		if hit:
			if hit.get_collider() == game.player:game.player.hurt(28,global_position)
			var target := hit.get_collider() as TownProp
			if target:target.strike(charge_direction,5,true)
			timer = 0
		if absf(position.x) > 31 or absf(position.z) > 31:
			position.x = clampf(position.x,-31,31)
			position.z = clampf(position.z,-31,31)
			timer = 0
		if timer <= 0:
			exposed = true
			bites_this_opening = 0
			core.show()
			timer = 4.0
			create_tween().tween_property(model,"rotation:x",-.55,.3)
			game.notice("転倒！ コアを3回かじって、引きはがせ",2.8)
			game.impact(global_position,2.0,Color("ffd37d"))

func recover() -> void:
	exposed = false
	core.hide()
	phase = "rest"
	timer = 1.4
	cycle += 1
	create_tween().tween_property(model,"rotation:x",0.0,.4)

func strike(_direction: Vector3, _power: int, projectile: bool = false) -> void:
	if consumed or hit_cooldown > 0 or game == null:return
	if not exposed:
		if projectile and phase == "charge":timer = maxf(0,timer-.4)
		return
	if projectile:return
	hit_cooldown = .35
	bites_this_opening += 1
	game.impact(global_position+Vector3.UP*2,1.5,Color("bdffe3"))
	game.sound("bite",.7)
	if bites_this_opening >= 3:
		cores_left -= 1
		armor = cores_left
		game.health = minf(100,game.health+12)
		game.notice("コアをまるのみ！ 残り%d個" % cores_left,2)
		game.sound("grow",.7)
		if cores_left > 0:recover()
		else:
			consumed = true
			remove_from_group("targets")
			game.debris(model,global_position)
			model.hide()
			core.hide()
			$Collision.set_deferred("disabled",true)
			game.finish(true)
