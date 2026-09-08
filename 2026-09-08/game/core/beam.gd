class_name RescueBeam
extends RigidBody2D

var dimensions: Vector2 = Vector2(300, 18)
var material_kind: String = "wood"

func _ready() -> void:
	mass = 3.0
	collision_layer = 1
	collision_mask = 3
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = 0.15
	angular_damp = 2.8
	var material := PhysicsMaterial.new()
	material.friction = 0.3
	material.bounce = 0.0
	physics_material_override = material
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	var rect := Rect2(-dimensions / 2.0, dimensions)
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color("b4ad9f"))
	draw_rect(rect, Color("b89162") if material_kind == "wood" else Color("ddd7c9"))
	draw_rect(rect, Color("75614b"), false, 1.5)
	draw_line(rect.position + Vector2(1, 2), rect.position + Vector2(dimensions.x - 1, 2), Color("ead4af"), 2)
	for i: int in range(3):
		var y: float = -dimensions.y / 2.0 + 6.0 + float(i) * 4
		draw_line(Vector2(-dimensions.x / 2.0 + 12, y), Vector2(dimensions.x / 2.0 - 12, y + 1), Color("987750"), 0.6)
