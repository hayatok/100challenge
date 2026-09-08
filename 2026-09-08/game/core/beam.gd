class_name RescueBeam
extends RigidBody2D

signal struck(at: Vector2, strength: float)
var previous_velocity: Vector2 = Vector2.ZERO
var previous_spin: float = 0.0
var impact_cooldown: float = 0.0

var dimensions: Vector2 = Vector2(300, 18)
var material_kind: String = "wood"
var body_mass: float = 3.0
var shape_kind: String = "beam"
var wall_height: float = 48.0
var padded: bool = false
var friction: float = 0.3
var fixed_rotation: bool = false
var caption: String = ""
var parts: Array = []

func _ready() -> void:
	mass = body_mass
	can_sleep = false
	lock_rotation = fixed_rotation
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 1
	collision_mask = 3
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = 0.15
	angular_damp = 2.8
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0.0
	physics_material_override = material
	if padded:
		set_meta("cushion",true)
	if shape_kind in ["tray","crate","hanger"]:
		for side: float in [-1.0,1.0]:
			_add_shape(Vector2(8,wall_height),Vector2(side*(dimensions.x/2-4),-wall_height/2))
	for part: Dictionary in parts:
		_add_shape(part["size"],part["p"])
	if shape_kind != "hanger":
		_add_shape(dimensions,Vector2.ZERO)
	else:
		_add_shape(Vector2(dimensions.x,8),Vector2(0,-wall_height))

func _add_shape(size: Vector2, at: Vector2) -> void:
	var collision := CollisionShape2D.new()
	collision.position = at
	var shape := RectangleShape2D.new()
	shape.size = size
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
	for part: Dictionary in parts:
		draw_rect(Rect2(part["p"]-part["size"]/2,part["size"]),Color("82663f"))
	if shape_kind == "crate":
		for side: float in [-1.0,1.0]:
			draw_circle(Vector2(side*(dimensions.x/2-20),dimensions.y/2+2),7,Color("59665f"))
	if shape_kind in ["tray","crate","hanger"]:
		var ink := Color("4a7063") if shape_kind == "crate" else Color("82663f")
		for side: float in [-1.0,1.0]:
			draw_rect(Rect2(Vector2(side*(dimensions.x/2-4)-4,-wall_height),Vector2(8,wall_height)),ink)
		draw_rect(Rect2(Vector2(-dimensions.x/2,-wall_height),Vector2(dimensions.x,wall_height)),Color(0.35,0.55,0.42,0.1))
	if shape_kind == "weight":
		draw_rect(Rect2(-dimensions/2,dimensions),Color("969f9a"))
		draw_rect(Rect2(-dimensions/2,dimensions),Color("59665f"),false,2)
		draw_string(ThemeDB.fallback_font,Vector2(-dimensions.x/2+6,5),str(int(body_mass)),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("34463e"))
		return
	if shape_kind == "hanger":
		draw_line(Vector2(-dimensions.x/2,-wall_height),Vector2(dimensions.x/2,-wall_height),Color("82663f"),8)
		return
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

	if padded:
		draw_line(Vector2(-dimensions.x/2+8,-dimensions.y/2),Vector2(dimensions.x/2-8,-dimensions.y/2),Color("8eab96"),5)
	if not caption.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(-dimensions.x/2,-wall_height-10),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("4a7063"))
