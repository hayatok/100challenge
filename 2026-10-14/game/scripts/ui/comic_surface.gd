extends Control
## Decoration triangles share one cached colored mesh per office object.
## Text and controls remain native UI above this procedural geometry.
const INK = Color("223443")
const PAPER = Color("fff4dc")
const RED = Color("f4433e")
const GOLD = Color("ffd45b")
const TEAL = Color("159b9c")
const PINK = Color("f36a99")
var kind := "paper"
var fill := PAPER
var accent := RED
var amount := 100.0
var active := false
var phase := 0.0
var intensity := 0.0
var reduced := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var _mesh: ArrayMesh
var _mesh_key: Array = []
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()

func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	_colors.append(color)
	_colors.append(color)
	_colors.append(color)

func _fringe_triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	_colors.append(ca)
	_colors.append(cb)
	_colors.append(cc)

func _fill_poly(points: PackedVector2Array, color: Color, antialias: bool = false) -> void:
	var p := points.duplicate()
	if p.size()>2 and p[0].is_equal_approx(p[-1]): p.remove_at(p.size()-1)
	if p.size()<3: return
	var indices := Geometry2D.triangulate_polygon(p)
	for i in range(0,indices.size(),3):
		_triangle(p[indices[i]],p[indices[i+1]],p[indices[i+2]],color)
	if not antialias: return
	# One-pixel transparent fringes preserve the smooth outlines without separate line submissions.
	var signed_area := 0.0
	for i in p.size(): signed_area+=p[i].cross(p[(i+1)%p.size()])
	var outer := PackedVector2Array()
	for i in p.size():
		var before := (p[i]-p[(i+p.size()-1)%p.size()]).normalized()
		var after := (p[(i+1)%p.size()]-p[i]).normalized()
		var n0 := Vector2(before.y,-before.x)*(1.0 if signed_area>0 else -1.0)
		var n1 := Vector2(after.y,-after.x)*(1.0 if signed_area>0 else -1.0)
		var direction := (n0+n1).normalized()
		var miter := minf(2.0,1.0/maxf(0.1,absf(direction.dot(n1))))
		outer.append(p[i]+direction*miter)
	var clear := Color(color,0.0)
	for i in p.size():
		var j := (i+1)%p.size()
		_fringe_triangle(p[i],p[j],outer[j],color,color,clear)
		_fringe_triangle(p[i],outer[j],outer[i],color,clear,clear)

func _rect(rect: Rect2, color: Color) -> void:
	_fill_poly(PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]),color,false)

func _circle(center: Vector2, radius: float, color: Color) -> void:
	var p := PackedVector2Array()
	var segments := 12 if radius<4 else (20 if radius<16 else 64)
	for i in segments:
		var angle := TAU*float(i)/segments
		p.append(center+Vector2(cos(angle),sin(angle))*radius)
	_fill_poly(p,color)

func _stroke(points: PackedVector2Array, color: Color, width: float, _antialias: bool = true) -> void:
	if points.size()<2: return
	var half := width*0.5
	for i in points.size()-1:
		var direction := (points[i+1]-points[i]).normalized()
		var normal := Vector2(-direction.y,direction.x)*half
		_fill_poly(PackedVector2Array([points[i]+normal,points[i+1]+normal,points[i+1]-normal,points[i]-normal]),color,true)
	# Rounded joins fill small cracks; the outline remains hard and thick at game resolution.
	for i in range(1,points.size()-1): _circle(points[i],half,color)
	if points[0].is_equal_approx(points[-1]): _circle(points[0],half,color)

func _stroke_line(a: Vector2, b: Vector2, color: Color, width: float, antialias: bool = true) -> void:
	_stroke(PackedVector2Array([a,b]),color,width,antialias)

func _arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float, antialias: bool = true) -> void:
	var p := PackedVector2Array()
	for i in count: p.append(center+Vector2(cos(lerpf(start,end,float(i)/(count-1))),sin(lerpf(start,end,float(i)/(count-1))))*radius)
	_stroke(p,color,width,antialias)

func _polygon(points: PackedVector2Array, color: Color, width: float = 6.0) -> void:
	_fill_poly(points,color)
	var line := points.duplicate()
	line.append(line[0])
	_stroke(line,INK,width)

func _angular(rect: Rect2, cut: float = 20.0) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([p + Vector2(cut, 0), p + Vector2(s.x-cut, 0), p + Vector2(s.x, cut), p + s - Vector2(0, cut), p + s - Vector2(cut, 0), p + Vector2(cut, s.y), p + Vector2(0, s.y-cut), p + Vector2(0, cut)])

func _receipt() -> PackedVector2Array:
	var p := PackedVector2Array()
	var teeth := maxi(8, roundi(size.x / 22.0))
	for i in teeth + 1:
		p.append(Vector2(float(i) * size.x / teeth, 7.0 if i % 2 == 0 else 0.0))
	p.append(Vector2(size.x, size.y-7))
	for i in range(teeth, -1, -1):
		p.append(Vector2(float(i) * size.x / teeth, size.y-7 if i % 2 == 0 else size.y))
	p.append(Vector2(0, 7))
	return p

func _dots(rect: Rect2, color: Color, spacing: float = 13.0) -> void:
	for y in range(int(rect.position.y), int(rect.end.y), int(spacing)):
		for x in range(int(rect.position.x), int(rect.end.x), int(spacing)):
			_circle(Vector2(x, y), 2.0, color)

func _barcode(rect: Rect2) -> void:
	for i in int(rect.size.x / 4.0):
		var width := 1.0 + float((i * 7) % 3)
		_rect(Rect2(rect.position + Vector2(i * 4, 0), Vector2(width, rect.size.y)), Color(INK, 0.45))

func _clip(at: Vector2) -> void:
	_polygon(_angular(Rect2(at, Vector2(68, 50)), 6), INK, 4)
	var wire := PackedVector2Array([at+Vector2(16,42),at+Vector2(22,0),at+Vector2(12,-23),at+Vector2(14,-35),at+Vector2(34,-42),at+Vector2(54,-35),at+Vector2(56,-23),at+Vector2(46,0),at+Vector2(52,42)])
	_stroke(wire, PAPER, 8, true)
	_stroke(wire, INK, 3, true)

func _burst(rect: Rect2, color: Color) -> void:
	var p := PackedVector2Array()
	var corners := [Vector2(0,0.40),Vector2(0.12,0.31),Vector2(0.05,0.15),Vector2(0.23,0.24),Vector2(0.25,0),Vector2(0.36,0.17),Vector2(0.43,0.05),Vector2(0.52,0.16),Vector2(0.65,0.02),Vector2(0.66,0.19),Vector2(0.80,0.06),Vector2(0.78,0.23),Vector2(0.95,0.14),Vector2(0.88,0.36),Vector2(1,0.40),Vector2(0.91,0.51),Vector2(1,0.71),Vector2(0.82,0.69),Vector2(0.88,0.92),Vector2(0.68,0.80),Vector2(0.60,1),Vector2(0.52,0.82),Vector2(0.38,0.97),Vector2(0.35,0.79),Vector2(0.21,0.96),Vector2(0.24,0.75),Vector2(0.06,0.86),Vector2(0.12,0.64),Vector2(0,0.63),Vector2(0.10,0.51)]
	for corner in corners: p.append(rect.position+corner*rect.size)
	_polygon(p,color,6)

func _rosette_burst(rect: Rect2) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var angle := TAU*float(i)/32.0
		var r := 1.0 if i%2==0 else 0.8
		p.append(rect.get_center()+Vector2(cos(angle),sin(angle))*rect.size*0.5*r)
	_polygon(p,GOLD,5)

func _draw() -> void:
	var key := [kind,size,fill,accent]
	if kind=="meter": key.append(ceili(amount/10.0)); key.append(amount<20)
	elif kind=="edges":
		key.append(reduced)
		if not reduced: key.append_array([active,phase,intensity])
	elif kind=="celebration": key.append_array([phase if not reduced else 0.0,reduced])
	if _mesh_key!=key or _mesh==null:
		_mesh_key=key
		_vertices=PackedVector2Array()
		_colors=PackedColorArray()
		_build_geometry()
		_mesh=ArrayMesh.new()
		if not _vertices.is_empty():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=_vertices
			arrays[Mesh.ARRAY_COLOR]=_colors
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	if _mesh.get_surface_count()>0: draw_mesh(_mesh,null)

func _build_geometry() -> void:
	match kind:
		"paper", "receipt":
			var p := _receipt() if kind == "receipt" else _angular(Rect2(Vector2.ZERO,size),18)
			var shadow := PackedVector2Array()
			for point in p: shadow.append(point+Vector2(8,10))
			_fill_poly(shadow, INK)
			_polygon(p,fill)
			_dots(Rect2(size.x-82,18,60,55),Color(GOLD,0.7),12)
			_dots(Rect2(18,size.y-80,66,52),Color(TEAL,0.4),12)
			if kind == "receipt" and size.y > 125:
				_barcode(Rect2(24,size.y-39,size.x*0.29,18))
				_barcode(Rect2(size.x-145,size.y-39,115,18))
			elif kind == "paper" and size.y > 300:
				_clip(Vector2(size.x-106,10))
		"barcode":
			_barcode(Rect2(Vector2.ZERO,size))
		"clip":
			_clip(Vector2(0,35))
		"timecard":
			_polygon(_angular(Rect2(6,12,size.x,size.y),18), PINK)
			_polygon(_angular(Rect2(Vector2.ZERO,size),18), INK)
			var rim := _angular(Rect2(9,9,size.x-18,size.y-18),14)
			rim.append(rim[0])
			_stroke(rim, PAPER, 3, true)
			_polygon(_angular(Rect2(10,10,size.x-20,62),10),RED,4)
			_dots(Rect2(15,88,40,size.y-106),Color(TEAL,0.45),10)
			_dots(Rect2(size.x-48,88,32,size.y-106),Color(TEAL,0.45),10)
			_clip(Vector2(size.x-115,23))
		"button", "keycap":
			_polygon(_angular(Rect2(5,8,size.x-5,size.y-8),16),INK,4)
			_polygon(_angular(Rect2(0,0,size.x-5,size.y-8),16),fill,6)
			var rim := _angular(Rect2(10,9,size.x-25,size.y-27),9)
			rim.append(rim[0])
			_stroke(rim, GOLD if fill == RED else Color("8da4ac"),3,true)
			if kind == "button": _dots(Rect2(size.x-55,18,27,size.y-45),Color(PAPER,0.23),9)
		"ribbon":
			var p := PackedVector2Array([Vector2(0,0),Vector2(size.x,0),Vector2(size.x-28,size.y*0.5),Vector2(size.x,size.y),Vector2(0,size.y),Vector2(28,size.y*0.5)])
			_polygon(p,GOLD,7)
		"burst":
			_burst(Rect2(8,8,size.x-8,size.y-8),PINK)
			_burst(Rect2(0,0,size.x-8,size.y-8),GOLD)
			_burst(Rect2(17,14,size.x-42,size.y-34),fill)
		"stamp":
			var outer := _angular(Rect2(Vector2.ZERO,size),22)
			_fill_poly(outer, Color(PAPER,0.96))
			outer.append(outer[0])
			_stroke(outer,accent,10,true)
			var inner := _angular(Rect2(14,14,size.x-28,size.y-28),14)
			inner.append(inner[0])
			_stroke(inner,accent,4,true)
			for i in 64:
				var x := 22.0 + float((i*83)%int(size.x-44))
				var y := 7.0 if i%2==0 else size.y-8
				_circle(Vector2(x,y),1.6,PAPER)
		"rosette":
			var center := size*0.5
			_polygon(PackedVector2Array([center+Vector2(-42,30),center+Vector2(-66,112),center+Vector2(-24,87),center+Vector2(-2,120),center+Vector2(19,40)]),RED,5)
			_polygon(PackedVector2Array([center+Vector2(5,30),center+Vector2(20,113),center+Vector2(47,86),center+Vector2(77,110),center+Vector2(48,29)]),PINK,5)
			_rosette_burst(Rect2(0,0,size.x,size.y))
			_circle(center,size.x*0.37,Color("edb342"))
			_arc(center,size.x*0.37,0,TAU,64,INK,4,true)
			_arc(center,size.x*0.32,0,TAU,64,PAPER,3,true)
			_polygon(PackedVector2Array([center+Vector2(-25,-47),center+Vector2(-28,-65),center+Vector2(-10,-57),center+Vector2(0,-75),center+Vector2(12,-57),center+Vector2(28,-65),center+Vector2(24,-47)]),PAPER,3)
		"meter":
			_polygon(_angular(Rect2(Vector2.ZERO,size),13),INK,4)
			for i in 10:
				var w := (size.x-20)/10.0
				var c := GOLD if amount > i*10 else Color("536271")
				if amount < 20 and amount > i*10: c=RED
				_rect(Rect2(10+i*w,8,w-3,size.y-16),c)
			var rim := _angular(Rect2(4,4,size.x-8,size.y-8),9)
			rim.append(rim[0])
			_stroke(rim,PAPER,3,true)
		"extinguisher":
			_stroke(PackedVector2Array([Vector2(26,136),Vector2(19,65),Vector2(42,28),Vector2(77,24)]),INK,17,true)
			_polygon(_angular(Rect2(38,50,62,118),17),RED,6)
			_stroke_line(Vector2(48,67),Vector2(44,136),PAPER,5,true)
			_stroke_line(Vector2(41,93),Vector2(96,93),GOLD,3,true)
			_polygon(_angular(Rect2(34,145,67,25),6),INK,3)
			_polygon(PackedVector2Array([Vector2(60,51),Vector2(69,22),Vector2(102,17),Vector2(99,31),Vector2(78,36),Vector2(79,53)]),INK,4)
			_polygon(PackedVector2Array([Vector2(61,22),Vector2(40,10),Vector2(24,16),Vector2(29,27),Vector2(66,32)]),INK,4)
			_circle(Vector2(69,36),8,GOLD)
			_stroke_line(Vector2(109,60),Vector2(131,47),GOLD,8,true)
			_stroke_line(Vector2(112,99),Vector2(137,103),GOLD,8,true)
		"logo":
			_circle(Vector2(size.x*0.6,100),105,GOLD)
			for i in 12:
				var h := 42.0+float((i*43)%105)
				var x := 185.0+i*32.0
				_rect(Rect2(x,170-h,29,h),INK)
				for j in int(h/18): _rect(Rect2(x+7,165-h+j*18,4,6),GOLD)
			for i in 6:
				var x := 35.0+float(i)*121
				var y := 80.0+float((i*39)%74)
				_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+45,y-24),Vector2(x+76,y+31),Vector2(x+30,y+55)]),PAPER,4)
				for j in 3: _stroke_line(Vector2(x+20+j*5,y+4+j*9),Vector2(x+48+j*5,y-10+j*9),Color("ccba9c"),3,true)
			_dots(Rect2(12,184,size.x-24,72),Color(TEAL,0.5),16)
		"edges":
			if reduced or intensity < 0.01: return
			for side in 2:
				for i in 13:
					var y := 290.0+i*43.0
					var length := (56.0+float((i*29)%75))*intensity*(0.9+0.1*sin(phase*11+i))
					var x := 0.0 if side==0 else size.x
					var direction := 1.0 if side==0 else -1.0
					var slant := 42.0 if y<540 else -42.0
					_fill_poly(PackedVector2Array([Vector2(x,y-10),Vector2(x+length*direction,y+slant),Vector2(x,y+13)]), PINK if active and i%3==0 else GOLD)
		"celebration":
			for i in 28:
				var side := -1.0 if i%2==0 else 1.0
				var x := 1100.0+side*(125.0+float((i*71)%360))
				var y := 80.0+float((i*137)%850)
				if not reduced: y += sin(phase*5+i)*18
				var color := GOLD if i%3==0 else (PINK if i%3==1 else TEAL)
				_fill_poly(PackedVector2Array([Vector2(x,y),Vector2(x+14,y-7),Vector2(x+35,y+29),Vector2(x+20,y+39)]),color)
