class_name RescueWorld
extends Node2D

signal changed
signal finished(won: bool, reason: String)
signal cut_made(at: Vector2)
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

func build(data: Dictionary) -> void:
	level = data
	box = data["box"]
	anchor = StaticBody2D.new()
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	add_child(anchor)
	_solid(Rect2(30,570,900,30))
	for rect: Rect2 in data.get("solids", []):
		_solid(rect)
	_solid(Rect2(box.position.x, box.end.y-16, box.size.x,16), true)
	_solid(Rect2(box.position.x-8,box.position.y+22,8,box.size.y-22), true)
	_solid(Rect2(box.end.x,box.position.y+22,8,box.size.y-22), true)
	for spec: Dictionary in data["beams"]:
		var b := RescueBeam.new()
		b.position = spec["p"]
		b.dimensions.x = spec["length"]
		b.rotation = spec["angle"]
		add_child(b)
		beams.append(b)
	for spec: Dictionary in data["pins"]:
		var b: RescueBeam = beams[spec["beam"]]
		var offset := Vector2(float(spec["end"]) * (b.dimensions.x / 2.0 - 10.0), 0)
		var p: Vector2 = b.to_global(offset)
		var joint := PinJoint2D.new()
		joint.position = p
		add_child(joint)
		joint.node_a = anchor.get_path()
		joint.node_b = b.get_path()
		pins.append({"joint":joint,"body":b,"local":offset,"at":p,"cut":false})
	for p: Vector2 in data["vases"]:
		var v := RescueCeramic.new()
		v.position = p
		v.kind = ceramics.size() % 2
		add_child(v)
		v.shattered.connect(_shatter)
		ceramics.append(v)
	queue_redraw()

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
	(pin["joint"] as PinJoint2D).queue_free()
	(pin["body"] as RescueBeam).sleeping = false
	cuts += 1
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
	if ended or not active:
		return
	elapsed += delta
	var all_inside: bool = true
	for v: RescueCeramic in ceramics:
		if v.position.y > 600 or v.position.x < -30 or v.position.x > 990:
			_shatter("模型の外へ落下しました。箱までつながる道を残して。", v.position)
			return
		var interior := Rect2(box.position + Vector2(15,0), box.size - Vector2(30,12))
		if not interior.has_point(v.position) or v.linear_velocity.length() > 55:
			all_inside = false
		if v.position.y > 540 and v.linear_velocity.length() < 10 and cuts > 0:
			_shatter("箱の外で止まりました。床の傾きと、落ちる先を見直して。", v.position)
			return
	rescue_time = rescue_time + delta if all_inside else 0.0
	if rescue_time >= 0.65:
		ended = true
		won = true
		for v: RescueCeramic in ceramics:
			v.rescued = true
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
	finished.emit(false,reason)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(30,45,900,525), Color("f1eee5"))
	for x: int in range(50, 931, 40):
		for y: int in range(60,570,40):
			draw_circle(Vector2(x,y),0.8,Color("d3cfc3"))
	for s: Dictionary in structures:
		var rect: Rect2 = s["rect"]
		draw_rect(Rect2(rect.position+Vector2(4,5),rect.size),Color("c4bcae"))
		draw_rect(rect, Color("aabaad") if s["cushion"] else Color("dbd5c8"))
		draw_rect(rect, Color("989284"), false, 1)
		if not s["cushion"]:
			for x: int in range(int(rect.position.x)+8,int(rect.end.x),16):
				draw_line(Vector2(x,rect.end.y-2),Vector2(x+8,rect.position.y+2),Color("c0b9aa"),1)
	for pin: Dictionary in pins:
		var p: Vector2 = pin["at"]
		draw_line(Vector2(p.x,80),p,Color("c0b8a4"),1)
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
