class_name RescueCeramic
extends RigidBody2D

signal shattered(reason: String, at: Vector2)
const BREAK_SPEED: float = 390.0
var broken: bool = false
var rescued: bool = false
var max_impact: float = 0.0
var previous_velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var kind: int = 0

func _ready() -> void:
	mass = 1.0
	collision_layer = 2
	collision_mask = 3
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 12
	linear_damp = 0.08
	angular_damp = 0.35
	var material := PhysicsMaterial.new()
	material.friction = 0.16
	material.bounce = 0.02
	physics_material_override = material
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	shape.shape = circle
	add_child(shape)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	age += state.step
	if not broken and not rescued and age > 0.2:
		for i: int in range(state.get_contact_count()):
			var normal: Vector2 = state.get_contact_local_normal(i)
			var other_velocity: Vector2 = state.get_contact_collider_velocity_at_position(i)
			var impact: float = maxf(0.0, -(previous_velocity - other_velocity).dot(normal))
			max_impact = maxf(max_impact, impact)
			var collider: Object = state.get_contact_collider_object(i)
			var cushion: bool = collider != null and collider.has_meta("cushion")
			if impact > BREAK_SPEED and not cushion:
				broken = true
				shattered.emit("硬い部材に強く衝突しました。落差を小さくするか、先に道を用意して。", state.transform.origin)
				queue_redraw()
				break
	state.linear_velocity = state.linear_velocity.limit_length(800.0)
	previous_velocity = state.linear_velocity

func _draw() -> void:
	var ink := Color("315c62")
	if broken:
		for i: int in range(7):
			var a: float = float(i) * TAU / 7.0
			var p := Vector2.from_angle(a) * 20.0
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(8, 4), p + Vector2(-2, 10)]), Color("ceded7"))
		return
	# Round ceramic body with a small neck: collision follows the load-bearing belly.
	draw_circle(Vector2(3, 3), 19, Color("a8aaa0"))
	draw_circle(Vector2.ZERO, 18, ink)
	draw_circle(Vector2.ZERO, 16, Color("dbe8df"))
	draw_rect(Rect2(-7, -23, 14, 12), ink)
	draw_rect(Rect2(-5, -22, 10, 11), Color("dbe8df"))
	draw_line(Vector2(-8, -23), Vector2(8, -23), ink, 3)
	draw_arc(Vector2.ZERO, 11, 0.25, 2.9, 24, ink, 2, true)
	draw_circle(Vector2(-6, -7), 3, Color("f5f7ee"))
	if kind == 1:
		draw_line(Vector2(-12, 1), Vector2(12, 1), ink, 2)
		draw_circle(Vector2(0, 6), 3, ink)
