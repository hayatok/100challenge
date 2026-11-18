extends StaticBody3D

signal activated(point: Vector3)
var kind := "bell"
var used := false
var cooldown := 0.0

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func receive_shot(_damage: float, _hit_position: Vector3, _direction: Vector3) -> void:
	if cooldown > 0.0 or used:
		return
	cooldown = 2.0
	activated.emit(global_position)
	if kind == "hook":
		used = true
