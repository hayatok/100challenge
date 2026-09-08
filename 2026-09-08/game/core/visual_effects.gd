class_name RescueVisualEffects
extends Node2D

var reduced: bool = false
var bursts: Array[Dictionary] = []
var packed_box: Rect2
var packing: bool = false
var packing_age: float = 0.0
var success: bool = false
var work_number: int = 1

func _ready() -> void:
	# Effects can finish after the physics world freezes; they never move physics bodies.
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20

func cut(at: Vector2) -> void:
	if not reduced:
		bursts.append({"at":at,"age":0.0,"fracture":false,"color":Color("bb9957")})

func fracture(at: Vector2, color: Color) -> void:
	bursts.append({"at":at,"age":0.7 if reduced else 0.0,"fracture":true,"color":color})

func pack(box: Rect2) -> void:
	packed_box = box
	packing = true
	success = true
	packing_age = 1.0 if reduced else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if packing:
		packing_age = minf(1.0,packing_age+delta)
	var had_bursts: bool = not bursts.is_empty()
	for burst: Dictionary in bursts:
		burst["age"] = minf(1.0,float(burst["age"])+delta)
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b["fracture"] or b["age"]<0.7)
	if packing or had_bursts:
		queue_redraw()

func _draw() -> void:
	for burst: Dictionary in bursts:
		var t: float = minf(0.7,burst["age"])
		var broken: bool = burst["fracture"]
		var col: Color = burst["color"]
		col.a = 1.0 if broken else maxf(0,1-t/0.7)
		for i: int in range(12 if broken else 8):
			var angle: float = i*2.399
			var speed: float = 40+(i%4)*18
			var p: Vector2 = burst["at"]+Vector2.from_angle(angle)*speed*t+Vector2(0,50*t*t)
			var r: float = 6.0 if broken else 1.7
			var shard := PackedVector2Array([p+Vector2(-r,0),p+Vector2(r,-r),p+Vector2(r*0.6,r)])
			draw_colored_polygon(shard,col)
			if broken:
				shard.append(shard[0])
				draw_polyline(shard,col.darkened(0.4),1.2,true)
		if broken:
			draw_arc(burst["at"],32,0,TAU,40,Color("a34e38"),2,true)
	if not packing:
		return
	var t: float = clampf(packing_age/0.65,0,1)
	var r := Rect2(packed_box.position+Vector2(-8,18),packed_box.size+Vector2(16,-12))
	var edge := Color("647765")
	# Folding lids close over the real receiving area, only after rescue was confirmed.
	for side: int in range(2):
		var x: float = r.position.x if side==0 else r.end.x-r.size.x*0.5*t
		var flap := Rect2(x,r.position.y,r.size.x*0.5*t,r.size.y)
		draw_rect(flap,Color("b8c3ac"))
		draw_rect(flap,edge,false,1.5)
	if t>=1:
		draw_rect(Rect2(r.get_center().x-7,r.position.y,14,r.size.y),Color("e2d5b6"))
		draw_rect(Rect2(r.position.x+10,r.get_center().y-16,r.size.x-20,32),Color("f1ead8"))
		draw_rect(Rect2(r.position.x+10,r.get_center().y-16,r.size.x-20,32),edge,false,1)
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x+18,r.get_center().y+6),"SAFE / %02d" % work_number,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("426d60"))
		draw_line(Vector2(r.end.x-28,r.get_center().y),Vector2(r.end.x-22,r.get_center().y+6),edge,2,true)
		draw_line(Vector2(r.end.x-22,r.get_center().y+6),Vector2(r.end.x-13,r.get_center().y-6),edge,2,true)
