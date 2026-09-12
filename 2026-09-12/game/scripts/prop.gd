class_name TownProp
extends CharacterBody3D

@export_enum("Food", "Car", "Tank", "Hunter", "Mortar", "Building", "Boss") var kind: int = 0
@export var reward: int = 12
@export var armor: int = 1
@export var launch_speed: float = 23.0
var exposed: bool = false
var consumed: bool = false
var flight: Vector3 = Vector3.ZERO
var flight_hits: Dictionary = {}
var hit_cooldown: float = 0.0
var game: Node
@onready var model: Node3D = $Model
@onready var core: Node3D = $Core

func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")

func _physics_process(delta: float) -> void:
	if game == null:
		game = get_tree().get_first_node_in_group("game")
	if game == null or not game.running or consumed:
		return
	hit_cooldown = maxf(0, hit_cooldown - delta)
	if exposed:
		core.rotation.y += delta * 1.8
	if flight.length() > 0.4:
		var hit := move_and_collide(flight * delta)
		flight = flight.move_toward(Vector3.ZERO, delta * 18.0)
		if hit:
			var other := hit.get_collider() as TownProp
			if other and not flight_hits.has(other.get_instance_id()):
				flight_hits[other.get_instance_id()] = true
				other.strike(flight.normalized(), 2, true)
				game.impact(global_position + Vector3.UP, 1.0, Color("ffe3a0"))
			flight = flight.bounce(hit.get_normal()) * 0.18
	position.x = clampf(position.x, -34, 34)
	position.z = clampf(position.z, -34, 34)

func edible(stage: int) -> bool:
	if consumed:
		return false
	if kind == 6:
		return exposed
	if exposed or kind == 0:
		return true
	if kind == 1:
		return stage >= 1
	if kind >= 2 and kind <= 4:
		return stage >= 2
	return false

func strike(direction: Vector3, power: int, projectile: bool = false) -> void:
	if consumed or hit_cooldown > 0:
		return
	hit_cooldown = 0.22
	if kind == 1:
		flight = direction * launch_speed
		flight_hits.clear()
		game.sound("crash", 0.82)
		game.impact(global_position + Vector3.UP * .5, .65, Color("b9e2d0"))
		return
	if kind == 0:
		consume()
		return
	if kind == 5 and game.player.stage < 2 and not projectile and game.player.mutation != 1:
		game.notice("まだ硬い！ 大きくなってから", 1.3)
		return
	armor -= power
	game.sound("crash", .75 if kind == 5 else 1.05)
	game.impact(global_position + Vector3.UP, 1.1, Color("f4c466"))
	if armor <= 0 and not exposed:
		expose()
	elif not exposed:
		var tween := create_tween()
		tween.tween_property(model, "position:z", -.16, .045)
		tween.tween_property(model, "position:z", 0.0, .13)

func expose() -> void:
	exposed = true
	flight = Vector3.ZERO
	if kind == 5:
		game.debris(model, global_position)
		model.hide()
		$Collision.set_deferred("disabled", true)
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(model, "rotation:z", 1.20, .24).set_trans(Tween.TRANS_BACK)
		tween.tween_property(model, "position:y", .15, .24)
	core.show()
	game.notice("装甲が崩れた！ コアをかじれ", 1.5)
	game.combo += 1

func consume() -> void:
	if consumed or game == null:
		return
	consumed = true
	$Collision.set_deferred("disabled", true)
	remove_from_group("targets")
	game.feed(reward, kind)
	game.sound("bite", randf_range(.94, 1.10))
	var mouth: Node3D = game.player.visual.get_node("Model/Rig/Hips/Head/Jaw")
	var destination: Vector3 = mouth.global_position + mouth.global_basis.z.normalized() * .35 * game.player.body_scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", destination, .17)
	tween.tween_property(self, "scale", Vector3.ONE * .05, .19).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
