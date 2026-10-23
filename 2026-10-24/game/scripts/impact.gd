extends Node3D
var sparks: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []
var life: Array[float] = []
var next := 0
var arc: MeshInstance3D
var arc_life := 0.0
var reduced := false
func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffe4a3")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shape := BoxMesh.new()
	shape.size = Vector3(.025,.025,.32)
	for i in range(24):
		var spark := MeshInstance3D.new()
		spark.mesh = shape
		spark.material_override = material
		spark.visible = false
		add_child(spark)
		sparks.append(spark)
		velocities.append(Vector3.ZERO)
		life.append(0.0)
	arc = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(18):
		var a := -1.3 + float(i)/18.0*2.6
		var b := -1.3 + float(i+1)/18.0*2.6
		for vertex in [Vector3(sin(a)*1.3,0,-cos(a)*1.3),Vector3(sin(b)*1.3,0,-cos(b)*1.3),Vector3(sin(a)*1.7,0,-cos(a)*1.7),Vector3(sin(a)*1.7,0,-cos(a)*1.7),Vector3(sin(b)*1.3,0,-cos(b)*1.3),Vector3(sin(b)*1.7,0,-cos(b)*1.7)]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	arc.mesh = mesh
	var arc_mat := material.duplicate()
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = arc_mat
	arc.visible = false
	add_child(arc)
func strike(at: Vector3, yaw: float) -> void:
	arc.global_position = at + Vector3.UP*1.2
	arc.rotation = Vector3(.2,yaw,.2)
	arc_life = .07 if reduced else .12
	arc.visible = true
func hit(at: Vector3) -> void:
	for j in range(3 if reduced else 7):
		var i := next
		next = (next+1)%sparks.size()
		life[i] = .16 + float(j%3)*.035
		sparks[i].global_position = at
		velocities[i] = Vector3(sin(float(j)*2.4)*5.0,2.0+float(j%3),cos(float(j)*2.4)*5.0)
		sparks[i].rotation = Vector3(0,float(j)*2.4,.4)
		sparks[i].visible = true
func _process(delta: float) -> void:
	arc_life -= delta
	arc.visible = arc_life > 0
	for i in range(life.size()):
		if life[i] <= 0: continue
		life[i] -= delta
		sparks[i].visible = life[i] > 0
		sparks[i].position += velocities[i]*delta
		velocities[i].y -= delta*10.0
