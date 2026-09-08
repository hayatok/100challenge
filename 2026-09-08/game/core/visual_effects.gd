class_name RescueVisualEffects
extends Node2D

# Pure drawing: these bursts never add collision bodies or modify the simulation.
var reduced: bool = false
var bursts: Array[Dictionary] = []
var packed_box: Rect2
var packing: bool = false
var packing_age: float = 0.0
var success: bool = false
var work_number: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20

func cut(at: Vector2) -> void:
	if not reduced:
		bursts.append({"at":at,"age":0.0,"kind":"cut","fracture":false,"color":Color("d9ae54"),"strength":1.0})

func impact(at: Vector2, strength: float) -> void:
	if not reduced:
		bursts.append({"at":at,"age":0.0,"kind":"impact","fracture":false,"color":Color("bcad94"),"strength":strength})

func fracture(at: Vector2, color: Color) -> void:
	bursts.append({"at":at,"age":1.1 if reduced else 0.0,"kind":"fracture","fracture":true,"color":color,"strength":1.0})

func pack(box: Rect2) -> void:
	packed_box = box
	packing = true
	success = true
	packing_age = 2.4 if reduced else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var moving: bool = packing and packing_age<2.4
	if moving:
		packing_age = minf(2.4,packing_age+delta)
	for burst: Dictionary in bursts:
		if burst["age"]<1.1:
			moving = true
			burst["age"] = minf(1.1,float(burst["age"])+delta)
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b["fracture"] or b["age"]<1.1)
	if moving:
		queue_redraw()

func _draw() -> void:
	for burst: Dictionary in bursts:
		var at: Vector2 = burst["at"]
		var t: float = burst["age"]
		var kind: String = burst["kind"]
		var col: Color = burst["color"]
		var fade: float = maxf(0,1-t/1.1)
		if kind=="impact":
			var strength: float = burst["strength"]
			for i: int in range(16):
				var drift := Vector2((i%2*2-1)*(25+i*6)*t*strength,-22*t)
				draw_circle(at+drift, (7+i%4*3)*(0.5+t),Color(col,fade*0.32))
			draw_arc(at,12+t*65*strength,PI,TAU,32,Color("e7d9b5")*Color(1,1,1,fade),2,true)
		elif kind=="cut":
			# Two halves of the brass fastening and long, bright splinters.
			for side: float in [-1.0,1.0]:
				var p: Vector2 = at+Vector2(side*72*t,42*t*t)
				draw_arc(p,8,side*t*5,side*t*5+PI,12,Color(col,fade),4,true)
			for i: int in range(22):
				var direction := Vector2.from_angle(i*2.399)
				var p: Vector2 = at+direction*(45+i%5*24)*t+Vector2(0,65*t*t)
				draw_line(p-direction*(7+i%3*4)*fade,p,Color("fff1b6") if t<0.14 else Color(col,fade),3,true)
			draw_arc(at,10+t*62,0,TAU,40,Color(col,fade),3,true)
			if t<0.14:
				draw_line(at-Vector2(24,24),at+Vector2(24,24),Color("fff8da"),6,true)
		else:
			for i: int in range(28):
				var angle: float = i*2.399
				var p: Vector2 = at+Vector2.from_angle(angle)*(65+i%5*25)*t+Vector2(0,100*t*t)
				var r: float = 4+i%4*2.5
				var shard := PackedVector2Array([p+Vector2(-r,0).rotated(t*i),p+Vector2(r,-r).rotated(t*i),p+Vector2(r*0.6,r).rotated(t*i)])
				draw_colored_polygon(shard,col if i%3 else col.lightened(0.3))
				shard.append(shard[0])
				draw_polyline(shard,col.darkened(0.45),1.5,true)
			if fade>0:
				draw_arc(at,22+t*115,0,TAU,48,Color("a34e38")*Color(1,1,1,fade),3,true)
	if packing:
		_draw_pack()

func _draw_pack() -> void:
	var t: float = clampf(packing_age/0.45,0,1)
	var r := Rect2(packed_box.position+Vector2(-8,18),packed_box.size+Vector2(16,-12))
	var edge := Color("647765")
	# Ease into closed lids, then stamp and release paper ribbons around the crate.
	var closed: float = 1-pow(1-t,3)
	for side: int in range(2):
		var x: float = r.position.x if side==0 else r.end.x-r.size.x*0.5*closed
		var flap := Rect2(x,r.position.y,r.size.x*0.5*closed,r.size.y)
		draw_rect(flap,Color("b8c3ac"))
		draw_rect(flap,edge,false,2)
	if t<1:
		return
	draw_rect(Rect2(r.get_center().x-7,r.position.y,14,r.size.y),Color("e2d5b6"))
	var stamp_t: float = clampf((packing_age-0.45)/0.23,0,1)
	var stamp_scale: float = 1+0.65*pow(1-stamp_t,2)
	draw_set_transform(r.get_center(),-0.035,Vector2.ONE*stamp_scale)
	var label_width: float = minf(180,r.size.x-16)
	draw_rect(Rect2(-label_width/2,-20,label_width,40),Color("f6edcf"))
	draw_rect(Rect2(-label_width/2,-20,label_width,40),edge,false,2)
	draw_string(ThemeDB.fallback_font,Vector2(-label_width/2+10,7),"SAFE / %02d" % work_number,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("426d60"))
	draw_set_transform(Vector2.ZERO)
	var age: float = maxf(0,packing_age-0.62)
	if age>0 and age<1.78 and not reduced:
		var fade: float = clampf((1.78-age)/0.7,0,1)
		for i: int in range(36):
			var direction := Vector2.from_angle(PI+float(i)*PI/35)
			var p: Vector2 = r.get_center()+direction*(60+i%5*23)*age+Vector2(0,75*age*age)
			var color: Color = [Color("c49a48"),Color("628878"),Color("e6d2a3"),Color("b77863")][i%4]
			draw_set_transform(p,age*(i%3-1)*5,Vector2.ONE)
			draw_rect(Rect2(-3,-7,6,14),Color(color,fade))
			draw_set_transform(Vector2.ZERO)
		draw_arc(r.get_center(),r.size.x*0.4+age*90,PI,TAU,48,Color("c49a48")*Color(1,1,1,fade*0.65),3,true)
