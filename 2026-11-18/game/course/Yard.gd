extends Node3D

const Layout := preload("res://race/YardLayout.gd")

@onready var loads: Array[Node3D] = [$PracticeCrane/MovingLoad, $ChannelCrane/MovingLoad]
@onready var belts: Array[ShaderMaterial] = [
	$EntryBelt/Tread.material_override, $InnerBelt/Tread.material_override
]
@onready var water: ShaderMaterial = $Sea.material_override


func _ready() -> void:
	set_mechanisms(0.0, PackedFloat32Array(), 0.0)


func set_mechanisms(_bridge_angle: float, _bar_angles: PackedFloat32Array, race_time: float) -> void:
	for index in loads.size():
		loads[index].position.x = Layout.roof_x(index, race_time)
	for belt: ShaderMaterial in belts:
		belt.set_shader_parameter(&"race_time", race_time)
	var roof: Dictionary = Layout.ROOFS[1]
	water.set_shader_parameter(&"race_time", race_time)
	water.set_shader_parameter(&"roof_center", Vector2(loads[1].position.x, roof.p))
