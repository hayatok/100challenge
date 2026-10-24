extends Node3D

signal passed(event_id: String, near: bool)
signal hit
var course: Node3D
var rider
var s := 280.0
var side := -1.0
var event_id := ""
var elapsed := 0.0
var armed := false
var fired := false
var completed := false
var active := false
var _closest := INF
var _warn: MeshInstance3D
var _model_anchor: Node3D

const ZONE_HALF_LENGTH: float = 8.5
const SAFE_HALF_WIDTH: float = 0.4
const WARNING_LIFT: float = 0.055


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("sentries")
	position = course.call("center_at", s)
	_model_anchor = Node3D.new()
	_model_anchor.name = "Model"
	_model_anchor.position = Vector3(side * 5.8, 3.0, 0.0)
	add_child(_model_anchor)
	var placeholder := MeshInstance3D.new()
	placeholder.name = "BLOCKOUT"
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("9a9e9f")
	sphere.material = grey
	placeholder.mesh = sphere
	_model_anchor.add_child(placeholder)
	_warn = MeshInstance3D.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, blend_mix; uniform float active = 0.0; void fragment(){float stripe=step(0.5,fract((UV.x+UV.y)*12.0)); ALBEDO=mix(vec3(0.9,0.46,0.08),vec3(1.0,0.83,0.22),stripe); ALPHA=0.20+active*0.43;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	_warn.material_override = material
	_warn.mesh = _build_warning_mesh()
	_warn.visible = false
	add_child(_warn)


func _physics_process(delta: float) -> void:
	if not active or completed or rider == null:
		return
	var ahead: float = s - rider.progress
	if not armed and ahead <= 75.0 and ahead > 0.0:
		armed = true
		_warn.visible = true
	if armed:
		elapsed += delta
		fired = elapsed >= 1.7
		_warn.material_override.set_shader_parameter("active", 1.0 if fired else 0.0)
	if absf(ahead) <= ZONE_HALF_LENGTH:
		_closest = minf(_closest, (rider.global_position + Vector3.UP).distance_to(_model_anchor.global_position))
	if fired and is_position_in_zone(rider.global_position) and rider.is_on_floor():
		if rider.take_hit():
			hit.emit()
		completed = true
		_warn.visible = false
	elif ahead < -12.0:
		completed = true
		_warn.visible = false
		passed.emit(event_id, _closest <= 2.0)


func reset_run() -> void:
	elapsed = 0.0
	armed = false
	fired = false
	completed = false
	active = false
	_closest = INF
	if is_instance_valid(_warn):
		_warn.visible = false


# The same fixed-z / world-X cross section used by the road and warning vertices.
func is_position_in_zone(world_position: Vector3) -> bool:
	var progress := -world_position.z
	if absf(s - progress) > ZONE_HALF_LENGTH:
		return false
	var center: Vector3 = course.call("center_at", progress)
	var signed_offset := side * (world_position.x - center.x)
	return signed_offset > SAFE_HALF_WIDTH and signed_offset <= float(course.call("half_width_at", progress))


func _build_warning_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := s - ZONE_HALF_LENGTH
	var end := s + ZONE_HALF_LENGTH
	var progress := start
	while progress < end:
		# Align intermediate cross sections with the actual road's 1m tessellation.
		var next := minf(end, floorf(progress) + 1.0)
		var a := _warning_vertex(progress, SAFE_HALF_WIDTH)
		var b := _warning_vertex(progress, float(course.call("half_width_at", progress)))
		var c := _warning_vertex(next, float(course.call("half_width_at", next)))
		var d := _warning_vertex(next, SAFE_HALF_WIDTH)
		var uv_a := Vector2(0.0, (progress - start) / (2.0 * ZONE_HALF_LENGTH))
		var uv_b := Vector2(1.0, uv_a.y)
		var uv_c := Vector2(1.0, (next - start) / (2.0 * ZONE_HALF_LENGTH))
		var uv_d := Vector2(0.0, uv_c.y)
		for entry in [[a, uv_a], [c, uv_c], [b, uv_b], [a, uv_a], [d, uv_d], [c, uv_c]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(entry[1])
			surface.add_vertex(entry[0])
		progress = next
	return surface.commit()


func _warning_vertex(progress: float, offset: float) -> Vector3:
	var point: Vector3 = course.call("surface_at", progress, side * offset, WARNING_LIFT)
	return to_local(point)
