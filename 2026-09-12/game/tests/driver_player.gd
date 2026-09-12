extends KaijuPlayer
var drive_vector: Vector3 = Vector3.ZERO
var aim_vector: Vector3 = Vector3.BACK
var drive_bite: bool = false
func read_movement(_camera: Camera3D) -> Vector3:return drive_vector
func read_aim(_camera: Camera3D) -> Vector3:return aim_vector
func wants_bite() -> bool:return drive_bite
