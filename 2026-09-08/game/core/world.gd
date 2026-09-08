class_name RescueWorld
extends Node2D

signal changed
signal finished(won: bool, reason: String)
signal cut_made(at: Vector2)
signal impact_made(at: Vector2, strength: float)
var art_id: int = 0
var visuals: RescueVisualEffects
var level: Dictionary
var beams: Array[RescueBeam] = []
var ceramics: Array[RescueCeramic] = []
var pins: Array[Dictionary] = []
var structures: Array[Dictionary] = []
var cuts: int = 0
var elapsed: float = 0.0
var ended: bool = false
var won: bool = false
var active: bool = true
var rescue_time: float = 0.0
var box: Rect2
var trace: Array[Vector2] = []
var trace_tick: int = 0
var failure_at: Vector2 = Vector2.ZERO
var anchor: StaticBody2D
var cables: Array[RescueCable] = []
var rails: Array[Dictionary] = []
var fixed_joints: Array[Dictionary] = []
var crate: RescueBeam
var surfaces: Array[Dictionary] = []

func build(data: Dictionary) -> void:
	level = data
	art_id = int(data.get("art_id",0))
	visuals = RescueVisualEffects.new()
	visuals.work_number = art_id+1
	add_child(visuals)
	box = data["box"]
	anchor = StaticBody2D.new()
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	add_child(anchor)
	_solid(Rect2(30,570,900,30))
	for rect: Rect2 in data.get("solids", []):
		_solid(rect)
	if not data.has("crate"):
		_solid(Rect2(box.position.x, box.end.y-16, box.size.x,16), true)
		_solid(Rect2(box.position.x-8,box.position.y+22,8,box.size.y-22), true)
		_solid(Rect2(box.end.x,box.position.y+22,8,box.size.y-22), true)
	for surface: Dictionary in data.get("surfaces",[]):
		_surface(surface)
	for spec: Dictionary in data["beams"]:
		var b := RescueBeam.new()
		b.position = spec["p"]
		b.dimensions = spec.get("size",Vector2(spec.get("length",100),18))
		b.rotation = spec.get("angle",0.0)
		b.body_mass = spec.get("mass",3.0)
		b.shape_kind = spec.get("kind","beam")
		b.fixed_rotation = spec.get("lock",false)
		b.padded = spec.get("pad",false)
		b.wall_height = spec.get("wall",48.0)
		b.friction = spec.get("friction",0.3)
		b.caption = spec.get("caption","")
		b.parts = spec.get("parts",[])
		add_child(b)
		beams.append(b)
		b.struck.connect(func(at: Vector2, strength: float) -> void:
			if not ended:
				visuals.impact(at,strength)
				impact_made.emit(at,strength))
	if data.has("crate"):
		crate = beams[data["crate"]]
	for spec: Dictionary in data.get("rails",[]):
		var body: RescueBeam = beams[spec["beam"]]
		var from: Vector2 = spec["from"]
		var to: Vector2 = spec["to"]
		var joint := GrooveJoint2D.new()
		joint.position = from
		joint.rotation = (to-from).angle()-PI/2.0
		joint.length = from.distance_to(to)
		joint.initial_offset = from.distance_to(body.position)
		add_child(joint)
		joint.node_a = anchor.get_path()
		joint.node_b = body.get_path()
		rails.append(spec)
	for spec: Dictionary in data.get("joints",[]):
		var entry: Dictionary = _joint(spec)
		fixed_joints.append(entry)
		if spec.has("other"):
			beams[spec["beam"]].add_collision_exception_with(beams[spec["other"]])
			beams[spec["other"]].add_collision_exception_with(beams[spec["beam"]])
	for spec: Dictionary in data.get("cables",[]):
		var cable := RescueCable.new()
		cable.a = beams[spec["a"]]
		cable.b = beams[spec["b"]]
		cable.local_a = spec.get("local_a",Vector2.ZERO)
		cable.local_b = spec.get("local_b",Vector2.ZERO)
		for guide: Vector2 in spec.get("guides",[]):
			cable.guides.append(guide)
		add_child(cable)
		cable.rest_length = cable.measure()+float(spec.get("slack",0.0))
		cables.append(cable)
	for spec: Dictionary in data["pins"]:
		if spec.has("cable"):
			var cable: RescueCable = cables[spec["cable"]]
			pins.append({"cable":cable,"body":cable.a,"at":spec["at"],"cut":false})
		else:
			pins.append(_joint(spec))
	for p: Vector2 in data["vases"]:
		var v := RescueCeramic.new()
		v.position = p
		v.kind = RescueArt.kind_for(art_id,ceramics.size())
		add_child(v)
		v.shattered.connect(_shatter)
		ceramics.append(v)
	_restore_connections()
	queue_redraw()

func _restore_connections() -> void:
	for entry: Dictionary in fixed_joints:
		if entry["other"] >= 0:
			(entry["body"] as RescueBeam).add_collision_exception_with(beams[entry["other"]])

func _joint(spec: Dictionary) -> Dictionary:
	var b: RescueBeam = beams[spec["beam"]]
	var offset: Vector2 = spec.get("local",Vector2(float(spec.get("end",0))*(b.dimensions.x/2.0-10.0),0))
	var at: Vector2 = b.to_global(offset)
	var joint := PinJoint2D.new()
	joint.disable_collision = false
	joint.position = at
	add_child(joint)
	joint.node_a = beams[spec["other"]].get_path() if spec.has("other") else anchor.get_path()
	if spec.has("frame_surface"):
		joint.node_a = (surfaces[spec["frame_surface"]]["body"] as StaticBody2D).get_path()
		joint.disable_collision = true
	joint.node_b = b.get_path()
	if spec.has("limits"):
		joint.angular_limit_enabled = true
		joint.angular_limit_lower = spec["limits"].x
		joint.angular_limit_upper = spec["limits"].y
	return {"joint":joint,"body":b,"local":offset,"at":at,"cut":false,"moving":spec.has("other"),"other":spec.get("other",-1)}

func _surface(spec: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.position = spec["p"]
	body.rotation = spec.get("angle",0.0)
	body.collision_layer = 1
	body.collision_mask = 3
	if spec.get("pad",false):
		body.set_meta("cushion",true)
	var shape := RectangleShape2D.new()
	shape.size = spec["size"]
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	surfaces.append({"body":body,"size":spec["size"],"pad":spec.get("pad",false)})

func _solid(rect: Rect2, cushion: bool = false) -> void:
	var b := StaticBody2D.new()
	b.position = rect.get_center()
	b.collision_layer = 1
	b.collision_mask = 3
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	b.add_child(collision)
	if cushion:
		b.set_meta("cushion",true)
	add_child(b)
	structures.append({"rect":rect,"cushion":cushion})

func cut(index: int) -> bool:
	if ended or index < 0 or index >= pins.size() or pins[index]["cut"]:
		return false
	var pin: Dictionary = pins[index]
	pin["cut"] = true
	if pin.has("cable"):
		(pin["cable"] as RescueCable).severed = true
	else:
		(pin["joint"] as PinJoint2D).queue_free()
	(pin["body"] as RescueBeam).sleeping = false
	cuts += 1
	visuals.cut(pin["at"])
	cut_made.emit(pin["at"])
	changed.emit()
	queue_redraw()
	return true

func pick(point: Vector2, radius: float) -> int:
	var closest: int = -1
	var distance: float = radius
	for i: int in range(pins.size()):
		if pins[i]["cut"]:
			continue
		var d: float = point.distance_to(pins[i]["at"])
		if d < distance:
			distance = d
			closest = i
	return closest

func _physics_process(delta: float) -> void:
	if not active:
		return
	_restore_connections()
	elapsed += delta
	for cable: RescueCable in cables:
		cable.step()
		cable.queue_redraw()
	for pin: Dictionary in pins:
		if pin.get("moving",false) and not pin["cut"]:
			pin["at"] = (pin["body"] as RescueBeam).to_global(pin["local"])
	if is_instance_valid(crate):
		box = Rect2(crate.position-Vector2(crate.dimensions.x/2,crate.wall_height),Vector2(crate.dimensions.x,crate.wall_height))
	if ended:
		queue_redraw()
		return
	var all_inside: bool = true
	for v: RescueCeramic in ceramics:
		if v.position.y > 600 or v.position.x < -30 or v.position.x > 990:
			_shatter("模型の外へ落下しました。\n箱につながる道を残して。", v.position)
			return
		var interior := Rect2(box.position + Vector2(15,0), box.size - Vector2(30,12))
		if not interior.has_point(v.position) or v.linear_velocity.length() > 35:
			all_inside = false
		if is_instance_valid(crate) and (crate.linear_velocity.length() > 8 or absf(crate.rotation)>0.08):
			all_inside = false
		if not interior.has_point(v.position) and v.position.y > 540 and v.linear_velocity.length() < 10 and cuts > 0:
			_shatter("箱の外で止まりました。\n床の傾きと、落ちる先を見よう。", v.position)
			return
	rescue_time = rescue_time + delta if all_inside else 0.0
	if rescue_time >= 0.65:
		ended = true
		won = true
		for v: RescueCeramic in ceramics:
			v.rescued = true
		visuals.pack(box)
		finished.emit(true,"すべての陶器を、無傷で梱包。")
	trace_tick += 1
	if trace_tick % 12 == 0 and cuts > 0 and not ceramics.is_empty():
		trace.append(ceramics[0].position)
		if trace.size() > 160:
			trace.pop_front()
	queue_redraw()

func _shatter(reason: String, at: Vector2) -> void:
	if ended:
		return
	ended = true
	failure_at = at
	for v: RescueCeramic in ceramics:
		if v.broken:
			v.visible = false
			visuals.fracture(at,RescueArt.GLAZES[v.kind])
	finished.emit(false,reason)
	queue_redraw()

func _draw() -> void:
	RescueArt.room(self,RescueArt.room_for(art_id))
	for rail: Dictionary in rails:
		draw_line(rail["from"],rail["to"],Color("a9a393"),4,true)
		for endpoint: Vector2 in [rail["from"],rail["to"]]:
			draw_circle(endpoint,5,Color("706e61"))
	for surface: Dictionary in surfaces:
		var body: StaticBody2D = surface["body"]
		draw_set_transform(body.position,body.rotation)
		draw_rect(Rect2(-surface["size"]/2,surface["size"]),Color("8eab96") if surface["pad"] else Color("d3cbb9"))
		draw_rect(Rect2(-surface["size"]/2,surface["size"]),Color("938b79"),false,1.5)
		draw_set_transform(Vector2.ZERO)
	for joint: Dictionary in fixed_joints:
		var at: Vector2 = (joint["body"] as RescueBeam).to_global(joint["local"])
		draw_circle(at,7,Color("75614b"))
		draw_circle(at,3,Color("d4bc7b"))
	for s: Dictionary in structures:
		var rect: Rect2 = s["rect"]
		draw_rect(Rect2(rect.position+Vector2(4,5),rect.size),Color("c4bcae"))
		draw_rect(rect, Color("aabaad") if s["cushion"] else Color("dfd9c9"))
		draw_rect(rect, Color("989284"), false, 1)
		if s["cushion"]:
			for x: int in range(int(rect.position.x)+3,int(rect.end.x),8):
				draw_line(Vector2(x,rect.position.y+2),Vector2(x,rect.end.y-2),Color("829886"),1)
		else:
			draw_line(rect.position+Vector2(2,2),Vector2(rect.end.x-2,rect.position.y+2),Color("fcf7e9"),3)
			if rect.size.y>80:
				draw_rect(Rect2(rect.position+Vector2(5,8),rect.size-Vector2(10,16)),Color("c8c0ad"),false,1)
			for x: int in range(int(rect.position.x)+8,int(rect.end.x),16):
				draw_line(Vector2(x,rect.end.y-2),Vector2(x+8,rect.position.y+2),Color("c0b9aa"),1)
	for pin: Dictionary in pins:
		var p: Vector2 = pin["at"]
		if not pin.has("cable") and not pin.get("moving",false):
			draw_line(Vector2(p.x,80),p-Vector2(0,8 if pin["cut"] else 0),Color("c0b8a4"),1)
			draw_circle(Vector2(p.x,80),3,Color("aaa18b"))
		if pin["cut"]:
			draw_line(p-Vector2(5,5),p+Vector2(5,5),Color("987333"),1.5)
			draw_line(p-Vector2(5,-5),p+Vector2(5,-5),Color("987333"),1.5)
		else:
			draw_line(p,pin.get("label_at",p),Color("987333"),2,true)
	for i: int in range(1,trace.size()):
		draw_line(trace[i-1],trace[i],Color(0.25,0.43,0.43,0.3),1.4,true)
	# The padded receiving crate is open at the top.
	draw_rect(Rect2(box.position+Vector2(0,22),box.size-Vector2(0,22)),Color(0.45,0.55,0.47,0.13))
	draw_line(box.position+Vector2(-15,6),box.position+Vector2(0,22),Color("8eab96"),4)
	draw_line(Vector2(box.end.x+15,box.position.y+6),Vector2(box.end.x,box.position.y+22),Color("8eab96"),4)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(box.position.x+12,box.end.y+25),"SAFE / FRAGILE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("4a7063"))
	if ended and not won:
		draw_arc(failure_at,31,0,TAU,40,Color("a34e38"),2,true)
