class_name RescueBeam
extends RigidBody2D

signal struck(at: Vector2, strength: float)
var previous_velocity: Vector2 = Vector2.ZERO
var previous_spin: float = 0.0
var impact_cooldown: float = 0.0

var dimensions: Vector2 = Vector2(300, 18)
var material_kind: String = "wood"

func _ready() -> void:
	mass = 3.0
	contact_monitor = true
	max_contacts_reported = 4
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

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	impact_cooldown = maxf(0,impact_cooldown-state.step)
	if impact_cooldown<=0:
		for i: int in range(state.get_contact_count()):
			var at: Vector2 = state.get_contact_local_position(i)
			var arm: Vector2 = at-state.transform.origin
			var velocity: Vector2 = previous_velocity+Vector2(-arm.y,arm.x)*previous_spin
			var speed: float = -(velocity-state.get_contact_collider_velocity_at_position(i)).dot(state.get_contact_local_normal(i))
			if speed>85:
				struck.emit(at,clampf(speed/220,0.5,1.5))
				impact_cooldown = 0.3
				break
	previous_velocity = state.linear_velocity
	previous_spin = state.angular_velocity

func _draw() -> void:
	var rect := Rect2(-dimensions / 2.0, dimensions)
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color("b4ad9f"))
	draw_rect(rect, Color("b89162") if material_kind == "wood" else Color("ddd7c9"))
	draw_rect(rect, Color("75614b"), false, 1.5)
	draw_line(rect.position + Vector2(1, 2), rect.position + Vector2(dimensions.x - 1, 2), Color("ead4af"), 2)
	for i: int in range(3):
		var y: float = -dimensions.y / 2.0 + 6.0 + float(i) * 4
		draw_line(Vector2(-dimensions.x / 2.0 + 12, y), Vector2(dimensions.x / 2.0 - 12, y + 1), Color("987750"), 0.6)

	# End grain and a narrow brass ferrule keep the moving beam recognizable at any angle.
	for side: float in [-1.0,1.0]:
		var x: float = side*(dimensions.x/2-7)
		draw_rect(Rect2(x-3,-9,6,18),Color("b29a60"))
		draw_line(Vector2(x-2,-7),Vector2(x-2,7),Color("e7d7a6"),1)
		draw_circle(Vector2(side*(dimensions.x/2-18),0),2,Color("624f3b"))
