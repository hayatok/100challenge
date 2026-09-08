class_name RescueCable
extends Node2D

# A unilateral elastic cable: tension only, transmitted at its visible endpoints.
# No stage IDs, action order, timers or success conditions participate in forces.
var a: RigidBody2D
var b: RigidBody2D
var local_a: Vector2 = Vector2.ZERO
var local_b: Vector2 = Vector2.ZERO
var guides: Array[Vector2] = []
var rest_length: float = 0.0
var severed: bool = false
var tension: float = 0.0

func points() -> PackedVector2Array:
	var result := PackedVector2Array([a.to_global(local_a)])
	for p: Vector2 in guides:
		result.append(p)
	result.append(b.to_global(local_b))
	return result

func measure() -> float:
	var p: PackedVector2Array = points()
	var total: float = 0.0
	for i: int in range(1,p.size()):
		total += p[i-1].distance_to(p[i])
	return total

func step() -> void:
	if severed:
		return
	var p: PackedVector2Array = points()
	var da: Vector2 = (p[1]-p[0]).normalized()
	var db: Vector2 = (p[p.size()-2]-p[p.size()-1]).normalized()
	var ra: Vector2 = p[0]-a.global_position
	var rb: Vector2 = p[p.size()-1]-b.global_position
	var va: Vector2 = a.linear_velocity+Vector2(-ra.y,ra.x)*a.angular_velocity
	var vb: Vector2 = b.linear_velocity+Vector2(-rb.y,rb.x)*b.angular_velocity
	var extension: float = measure()-rest_length
	var speed: float = -va.dot(da)-vb.dot(db)
	tension = clampf(extension*3200.0+speed*100.0,0.0,24000.0) if extension > -0.5 else 0.0
	a.apply_force(da*tension,ra)
	b.apply_force(db*tension,rb)

func _draw() -> void:
	var p: PackedVector2Array = points()
	for guide: Vector2 in guides:
		draw_circle(guide,9,Color("bca064"))
		draw_circle(guide,6,Color("e4d5ad"))
		draw_circle(guide,2,Color("726750"))
	if not severed:
		draw_polyline(p,Color("6d6553"),2.5,true)
	else:
		for end: int in [0,p.size()-1]:
			draw_line(p[end],p[end]+Vector2(0,18),Color("a1937a"),2,true)
