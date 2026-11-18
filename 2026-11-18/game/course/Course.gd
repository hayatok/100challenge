extends Node3D

@onready var bridge: Node3D = $TiltingBridge
@onready var start_bar: Node3D = $StartBar/Sweeper
@onready var finish_bar: Node3D = $FinishBar/Sweeper
@onready var sea: ShaderMaterial = $Sea.material_override


func set_mechanisms(bridge_angle: float, bar_angles: PackedFloat32Array, water_time: float) -> void:
	bridge.rotation.x = bridge_angle
	start_bar.rotation.y = bar_angles[0]
	finish_bar.rotation.y = bar_angles[1]
	sea.set_shader_parameter(&"swell_time", water_time)
