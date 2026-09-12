extends Node3D
@export var follow_rate: float = 7.0
@export var camera_offset: Vector3 = Vector3(12,20,20)
@export var base_size: float = 23.0
@onready var camera: Camera3D = $Camera3D
var initialized: bool = false
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:return
	var target := player.global_position+Vector3.UP*1.2
	if not initialized:
		global_position = target
		initialized = true
	global_position = global_position.lerp(target,1-exp(-delta*follow_rate))
	camera.position = camera_offset
	camera.look_at(target)
	var game := get_tree().get_first_node_in_group("game")
	var target_size: float = 12.5 if game and game.state == "title" else base_size+player.stage*6.0
	camera.size = lerpf(camera.size,target_size,1-exp(-delta*2))
