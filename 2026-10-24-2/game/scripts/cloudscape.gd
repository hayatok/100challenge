extends Node3D

@export var follow_rider: Node3D
@export var reduced_motion: bool = false
@export var cloud_height: float = -5.0
@export var extent: float = 2400.0
@export var billow_height: float = 2.4
@export var drift_speed: float = 0.45

var _sea: MeshInstance3D
var _material: ShaderMaterial
var _elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(extent, 800.0), maxf(extent, 800.0))
	plane.subdivide_width = 127
	plane.subdivide_depth = 127
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/cloud_sea.gdshader")
	_material.set_shader_parameter("billow_height", billow_height)
	_sea = MeshInstance3D.new()
	_sea.name = "AtmosphericCloudSea"
	_sea.mesh = plane
	_sea.material_override = _material
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.extra_cull_margin = billow_height + 2.0
	add_child(_sea)
	_update_origin()


func _process(delta: float) -> void:
	if not reduced_motion:
		_elapsed += delta * drift_speed
	_material.set_shader_parameter("drift_time", _elapsed)
	_update_origin()


func _update_origin() -> void:
	var origin := global_position
	if is_instance_valid(follow_rider):
		origin.x = roundf(follow_rider.global_position.x / 128.0) * 128.0
		origin.z = roundf(follow_rider.global_position.z / 128.0) * 128.0
	origin.y = cloud_height
	_sea.global_position = origin
