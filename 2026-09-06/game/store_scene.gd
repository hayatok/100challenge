extends Control
const Nav=preload("res://core/navigation.gd")
const People=preload("res://pixel_people.gd")
const Cat=preload("res://core/catalog.gd")
signal picked(kind:String,id:int)
signal placed(cell:Vector2i)
signal hovered(cell:Vector2i)
var sim
var selected_kind=""
var selected_id=-1
var build_kind=-1
var build_dir=0
var move_id=-1
var fixture_turn=0
var fixture_pivot=Vector2.ZERO
var hover_cell=Vector2i(-99,-99)
var zoom=1.0
var pan=Vector2.ZERO
var dragging=false
var drag_origin=Vector2.ZERO
var dragged=false
var reduced=false
var clock=0.0
var interp=0.0
var labels=[]
var screen_text=false
var color_cache={}
var font:Font
var origin=Vector2.ZERO
var scale_world=1.0
var painter_alpha=1.0
var hit_people=[]
var hit_fixtures=[]
const INK=Color("253d40")
const CREAM=Color("fff2d2")
# One glyph is one native pixel. The canopy is authored, not a stack of cubes.
const TREE_CROWN=[
"............ooooooo............",
".........oooLLLLLLLooo.........",
".......ooLLLhhLLLLLLLLoo.......",
"......oLLLLhhhhLLLLLLLLLo......",
"....ooLLLhhhhLLLssLLLLLLLoo....",
"...oLLLLLhhhLLLLssLLLLLLLLLo...",
"..oLLLLLLLLLLLLsssLLLLhhLLLLo..",
"..oLLLLLLLLLLLssssLLLhhhhLLLo..",
".oLLhhLLLLLLLsssLLLLLLhhLLLLLo.",
"oLLhhhhLLLLLLLLLLLLLLLLLLLLLLo.",
"oLLLhhLLLLLLLLLLLssLLLLLLLLLLLo",
"oLLLLLLLLLLLssLLLsssLLLLLLLLLLo",
"oLLLLLLLLLLssssLLLssssLLLLLLLLo",
".oLLLLLssLLssssLLLLssssLLLLLLo.",
".oLLLLssssLLssLLLLLLssssLLLLo..",
"..oLLLssssLLLLLLLssLLssssLLLo..",
"...ooLLssLLLLLLLssssLLsssLoo...",
".....oLLLLLssLLLssssLLLLLo.....",
"......oooLLssssLLssLLooo......",
".........oooLLLLLLooo.........",
"............oooooo............"]

func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	clip_contents=true
func _process(delta):
	clock+=delta
	queue_redraw()
func reset_camera():
	pan=Vector2.ZERO;zoom=1.0
func project(v:Vector2,z:float=0) -> Vector2:
	v=turn(v)
	return Vector2((v.x-v.y)*32,(v.x+v.y)*16-z)
func turn(v:Vector2) -> Vector2:
	var p=v-fixture_pivot
	match fixture_turn:
		1:p=Vector2(p.y,-p.x)
		2:p=-p
		3:p=Vector2(-p.y,p.x)
	return p+fixture_pivot
func cell_screen(v:Vector2,z:float=0) -> Vector2:
	return origin+project(v,z)*scale_world
func world_cell(at:Vector2) -> Vector2i:
	var q=(at-origin)/scale_world
	return Vector2i(floori((q.x/32+q.y/16)/2),floori((q.y/16-q.x/32)/2))
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:zoom=clampf(zoom*1.12,0.65,2.2);accept_event()
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:zoom=clampf(zoom/1.12,0.65,2.2);accept_event()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:dragging=true;drag_origin=event.position;dragged=false
			else:
				dragging=false
				if not dragged:choose_at(event.position)
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:reset_camera()
	if event is InputEventMouseMotion:
		if dragging and build_kind<0:
			if event.position.distance_to(drag_origin)>5:dragged=true
			if dragged:pan+=event.relative
		hover_cell=world_cell(event.position);hovered.emit(hover_cell)
func choose_at(at:Vector2):
	var cell=world_cell(at)
	if build_kind>=0:placed.emit(cell);return
	for i in range(hit_people.size()-1,-1,-1):
		if hit_people[i].rect.has_point(at):picked.emit(hit_people[i].kind,hit_people[i].id);return
	for i in range(hit_fixtures.size()-1,-1,-1):
		if hit_fixtures[i].rect.has_point(at):picked.emit("fixture",hit_fixtures[i].id);return
	picked.emit("",-1)
func with_alpha(color:Color) -> Color:
	var key=color.to_rgba32()
	if not color_cache.has(key):
		var best=color;var distance=INF
		for hex in People.COLORS:
			var candidate=Color(hex)
			var d=Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
			if d<distance:distance=d;best=candidate
		best.a=color.a;color_cache[key]=best
	color=color_cache[key];color.a*=painter_alpha;return color
func paint_rect(rect:Rect2,color:Color):draw_rect(rect,with_alpha(color))
func paint_arc(center:Vector2,radius:float,start:float,end:float,count:int,color:Color,width:float=1,antialias:bool=false):draw_arc(center,radius,start,end,count,with_alpha(color),width,antialias)
func poly(points:Array,color:Color):
	draw_colored_polygon(PackedVector2Array(points),with_alpha(color))
func tile(x:float,y:float,color:Color,z:float=0):
	poly([project(Vector2(x,y),z),project(Vector2(x+1,y),z),project(Vector2(x+1,y+1),z),project(Vector2(x,y+1),z)],color)
func box(x:float,y:float,w:float,d:float,h:float,color:Color,z:float=0):
	var saved_turn=fixture_turn
	var p0=turn(Vector2(x,y));var p1=turn(Vector2(x+w,y+d))
	x=minf(p0.x,p1.x);y=minf(p0.y,p1.y);w=absf(p1.x-p0.x);d=absf(p1.y-p0.y)
	fixture_turn=0
	var a=project(Vector2(x,y),h+z);var b=project(Vector2(x+w,y),h+z);var c=project(Vector2(x+w,y+d),h+z);var e=project(Vector2(x,y+d),h+z)
	poly([e,c,project(Vector2(x+w,y+d),z),project(Vector2(x,y+d),z)],color.darkened(0.25))
	poly([b,c,project(Vector2(x+w,y+d),z),project(Vector2(x+w,y),z)],color.darkened(0.42))
	poly([a,b,c,e],color)
	fixture_turn=saved_turn
func line(a:Vector2,b:Vector2,color:Color,width:float=1):draw_line(a,b,with_alpha(color),width,false)
func label(at:Vector2,text:String,color:Color=CREAM,font_size:int=12,bubble:bool=false,priority:int=0):
	labels.append({"at":at if screen_text else origin+at*scale_world,"text":text,"color":color,"size":font_size,"bubble":bubble,"caption":screen_text,"priority":priority})

func _draw():
	if sim==null or font==null:return
	labels=[];screen_text=false
	var s=sim.s;var dims=Nav.dimensions(s.tier)
	var night=sim.minute()<360 or sim.minute()>=1140
	var evening=sim.minute()>=990 and sim.minute()<1140
	var bg=Color("213743") if night else (Color("bb9986") if evening else Color("596070"))
	paint_rect(Rect2(Vector2.ZERO,size),bg)
	# Every world unit is rendered at the authored 32x16 tile scale.
	scale_world=0.5
	origin=(Vector2(size.x*0.5-(dims.x-dims.y-3)*16*scale_world,size.y*0.5-(dims.x+dims.y-3)*8*scale_world+20)+pan).floor()
	draw_set_transform(origin,0,Vector2.ONE*scale_world)
	# Raised corner of the neighborhood, sidewalks and street.
	box(-5,-4,dims.x+7,dims.y+9,10,Color("819485") if not night else Color("455b56"),-10)
	for x in range(-5,dims.x+2):
		for y in range(-4,dims.y+5):
			if x>=0 and y>=0 and x<dims.x and y<dims.y:continue
			var c=Color("b9b9ad")
			if x<=-3:c=Color("394357")
			if x==-2:c=Color("c4c3ae")
			tile(x,y,c.darkened(0.25) if night else c)
			if x>-3:
				line(project(Vector2(x,y)),project(Vector2(x+1,y)),Color("929b94"),1)
	for y in range(-3,dims.y+4,3):
		box(-4.1,y,0.07,1.2,0.2,Color("e4d8a9"))
	for i in 6:box(-4.8,Nav.DOOR.y+i*0.15,2.3,0.065,0.2,Color("e2dfc9"))
	draw_outdoor_weather(dims,night)
	# Concrete base and floor border.
	box(-0.15,-0.15,dims.x+0.3,dims.y+0.3,8,Color("526861"))
	for x in dims.x:
		for y in dims.y:
			var color=Color("f7e6bc")
			if x<2 and y<3:color=Color("bcbfab") if (x+y)%2==0 else Color("b0b59f")
			tile(x,y,color,9)
			line(project(Vector2(x,y),9),project(Vector2(x+1,y),9),Color("dfd2ad"),1)
			line(project(Vector2(x,y),9),project(Vector2(x,y+1),9),Color("dfd2ad"),1)
			if (x*13+y*7)%9==0:
				var at=project(Vector2(x+0.6,y+0.4),9);paint_rect(Rect2(at,Vector2(2,1)),Color("cfc5aa"))
	# Rear walls, teal skirting, windows and hand-lettered store name.
	box(0,-0.16,dims.x,0.16,76,Color("dfd8bd"),9)
	box(-0.16,0,0.16,3,76,Color("e9e0c2"),9)
	box(0,-0.22,dims.x,0.2,11,Color("378c78"),68)
	box(-0.22,0,0.2,3,11,Color("378c78"),68)
	box(0,-0.23,dims.x,0.22,4,Color("d65b54"),64)
	for x in range(2,dims.x-1,3):
		window(Vector2(x,0),night)
	# Glass storefront and a real gap at the shared logical doorway.
	for y in range(3,dims.y):
		if y==Nav.DOOR.y:continue
		var a=project(Vector2(0,y),10);var b=project(Vector2(0,y+1),10)
		poly([a,b,b+Vector2(0,-52),a+Vector2(0,-52)],Color(0.46,0.66,0.65,0.27))
		line(a,a+Vector2(0,-52),Color("8bada0"),2)
		line(a+Vector2(0,-52),b+Vector2(0,-52),Color("378c78"),3)
		line(a+Vector2(0,-20),b+Vector2(0,-20),Color("d99a77"),3)
	poster_art()
	# Backroom crates, notice board, tiny clock, sign.
	box(0.25,0.4,0.7,0.5,20,Color("b79159"),9)
	box(0.3,0.45,0.6,0.4,16,Color("c9a46a"),29)
	var notice=project(Vector2(0,2.8),61)
	paint_rect(Rect2(notice-Vector2(22,12),Vector2(38,30)),Color("aa8155"))
	paint_rect(Rect2(notice-Vector2(18,9),Vector2(17,22)),CREAM)
	paint_rect(Rect2(notice+Vector2(2,-6),Vector2(10,15)),Color("db9b77"))
	label(project(Vector2(2,0),89),"まちあかり MART",Color("f8ebce"),17)
	box(1.92,0,0.08,1,36,Color("b8bda7"),9)
	box(1.92,2,0.08,1,36,Color("b8bda7"),9)
	box(0,2.92,2,0.08,36,Color("b8bda7"),9)
	var staff_door_open=s.staff.any(func(w):return w.hired and (w.pos==Nav.DEPOT or w.pos==Vector2i(2,1)))
	if not staff_door_open:box(1.92,1,0.08,1,36,Color("4a7166"),9)
	label(project(Vector2(2,1.5),50),"倉庫",CREAM,9)
	# Door, threshold and mat use exactly the navigation coordinates.
	var door=Vector2(Nav.DOOR)
	tile(door.x-1,door.y,Color("34786a"),1)
	tile(door.x,door.y,Color("a8bd9d"),10)
	label(project(door+Vector2(-0.9,0.55),3),"入口",CREAM,10)
	var opening=false
	for v in s.visits:
		if Vector2(v.pos-Nav.DOOR).length()<2.5:opening=true
	for y in [door.y-0.06,door.y+1.02]:box(-0.10,y,0.10,0.06,58,Color("49786c"),9)
	box(-0.12,door.y,0.12,1,6,Color("49786c"),64)
	if not opening:
		var a=project(door,10);var b=project(door+Vector2(0,1),10)
		poly([a,b,b+Vector2(0,-51),a+Vector2(0,-51)],Color(0.67,0.81,0.77,0.42))
		line((a+b)/2,(a+b)/2+Vector2(0,-51),Color("e4e9ce"),2)
	else:
		line(project(door+Vector2(0,0.05),12),project(door+Vector2(0,0.05),61),Color("c1d7c8"),3)
		line(project(door+Vector2(0,0.95),12),project(door+Vector2(0,0.95),61),Color("c1d7c8"),3)
	label(project(door+Vector2(-0.1,0.8),76),"OPEN",CREAM,9)
	for f in s.fixtures:
		if not Nav.is_register(f):continue
		var cells=Nav.queue_cells(f,s.fixtures,s.tier)
		for i in cells.size():
			var p=Vector2(cells[i])
			line(project(p+Vector2(0.20,0.20),11),project(p+Vector2(0.70,0.20),11),Color("c2a268"),2)
			if i==0:label(project(p+Vector2(0.1,0.7),12),"お会計",Color("577564"),7)
	# Draw fixtures and actors by their feet.
	var draws=[]
	for f in s.fixtures:draws.append({"type":"fixture","data":f,"depth":f.x+f.y+0.65})
	for v in s.visits:
		var at=actor_at(v);draws.append({"type":"resident","data":v,"depth":at.x+at.y})
	for w in s.staff:
		if w.hired and (sim.working(w) or not w.path.is_empty() or w.get("prev",w.pos)!=w.pos):
			var at=actor_at(w);draws.append({"type":"staff","data":w,"depth":at.x+at.y+0.01})
	draws.sort_custom(func(a,b):return a.depth<b.depth)
	hit_people=[];hit_fixtures=[]
	for item in draws:
		if item.type=="fixture":draw_fixture(item.data)
		else:draw_person(item.data,item.type)
	# These planters stand beyond the public walkway, not on a navigation cell.
	for v in [Vector2(dims.x+0.4,1),Vector2(0.5,dims.y+0.6)]:
		plant_art(v,sim.season())
	neighborhood_art(dims,night)
	var bike=project(Vector2(5,dims.y+1),6)
	paint_arc(bike,8,0,TAU,12,INK,2,false);paint_arc(bike+Vector2(27,0),8,0,TAU,12,INK,2,false)
	line(bike,bike+Vector2(10,-16),Color("b46e54"),3);line(bike+Vector2(10,-16),bike+Vector2(27,0),Color("b46e54"),3);line(bike,bike+Vector2(27,0),Color("b46e54"),2)
	box(-1.7,6.7,0.35,0.45,28,Color("dfc3a0"));label(project(Vector2(-1.6,7),35),"MART",Color("334e4c"),8)
	# Build preview and accessible face marker.
	if build_kind>=0 and Nav.inside(hover_cell,dims):
		var draft=s.fixtures.duplicate(true)
		if move_id>=0:draft=draft.filter(func(f):return f.id!=move_id)
		draft.append({"x":hover_cell.x,"y":hover_cell.y,"dir":build_dir,"kind":build_kind})
		var valid=Nav.validate(draft,s.tier,[],not s.get("layout_needs_review",false)).is_empty()
		tile(hover_cell.x,hover_cell.y,Color(0.3,0.75,0.65,0.7) if valid else Color(0.85,0.32,0.26,0.7),13)
		box(hover_cell.x+0.05,hover_cell.y+0.05,0.9,0.9,36,Color(0.35,0.82,0.68,0.4) if valid else Color(0.85,0.32,0.26,0.4),14)
		var a=hover_cell+Nav.DIRS[build_dir]
		tile(a.x,a.y,Color(1,0.83,0.4,0.7),13)
		if Nav.is_register({"kind":build_kind}):
			var clerk=hover_cell-Nav.DIRS[build_dir]
			tile(clerk.x,clerk.y,Color(0.45,0.72,0.9,0.7),13)
			label(project(Vector2(clerk),15),"店員",INK,10)
		label(project(Vector2(hover_cell),24),"設置" if valid else "置けません",INK,12)
	# Short, result-driven feedback.
	for e in s.effects:
		var age=s.tick-e.time
		var pos=project(Vector2(e.pos)+Vector2(0.5,0.5),66+(0 if reduced else age*1.2))
		var width=font.get_string_size(e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		pass
		label(pos-Vector2(width/2,0),e.text,Color("397263") if e.kind=="good" else Color("956544"),12,true,1)
	draw_set_transform(Vector2.ZERO)
	# The shop stays under fluorescent light; only the outdoor palette changes at night.
	# Quiet map caption.
	screen_text=true
	label(Vector2(22,size.y-22),"住宅街・あかり町  /  "+str(dims.x)+" × "+str(dims.y)+"",Color("edf0df"),12)
	label(Vector2(22,size.y-43),"ドラッグで移動  ·  ホイールで拡大  ·  右クリックで中央",Color("e2e8d9"),11)

func draw_outdoor_weather(dims:Vector2i,night:bool):
	var season=sim.season()
	# Ground details are drawn before the store floor, so no rain or leaves fall indoors.
	for y in range(-2,dims.y+4,2):
		var at=Vector2(-1.5,y+0.45)
		if season==0:
			var p=project(at,1)
			for offset in [Vector2(0,0),Vector2(10,3),Vector2(-6,5)]:paint_rect(Rect2(p+offset,Vector2(2,2)),Color("b99cc5"))
		elif season==2:
			var p=project(at,1)
			paint_rect(Rect2(p,Vector2(4,2)),Color("b77843"));paint_rect(Rect2(p+Vector2(9,2),Vector2(2,4)),Color("e7ab53"))
		elif season==3:
			# Snow stays against the curb; the central path has been cleared.
			var length=0.7+posmod(y*7,4)*0.2
			box(-2.97,y,0.18,length,2,Color("a5c8bf") if night else Color("f7e6bc"),1)
			box(-2.82,y+0.15,0.12,length*0.6,1,Color("a5c8bf") if night else Color("f7e6bc"),1)
	if night:
		# A crisp pool from the storefront, with pixel stepping at its outer edge.
		for y in range(3,dims.y):
			tile(-1,y,Color("798a87"),0.4)
			if y%2==0:box(-1.3,y+0.1,0.3,0.8,0.1,Color("596070"),0.3)
	if sim.weather_for(sim.s.day)!="雨":return
	for y in range(-2,dims.y+3,3):
		var p=project(Vector2(-2,y+0.6),0.5)
		line(p+Vector2(-9,0),p+Vector2(8,0),Color("67a9bb") if night else Color("798a87"),2)
		line(p+Vector2(-4,3),p+Vector2(12,3),Color("a5c8bf"),1)
	if not reduced:
		draw_set_transform(Vector2.ZERO)
		for i in 70:
			var p=Vector2(fmod(i*97+clock*45,size.x),fmod(i*61+clock*155,size.y))
			line(p,p+Vector2(-2,5),Color(0.65,0.78,0.75,0.6))
		draw_set_transform(origin,0,Vector2.ONE*scale_world)

func neighborhood_art(dims:Vector2i,night:bool):
	var season=sim.season()
	# A little street tree is outside the shop and every public walking cell.
	var at=Vector2(dims.x+0.8,dims.y-2.0)
	box(at.x,at.y,0.8,0.8,8,Color("b77843"))
	box(at.x+0.34,at.y+0.34,0.14,0.14,56,Color("70463f"),8)
	var crown=project(at+Vector2(0.4,0.4),57)
	if season==3:
		for side in [-1,1]:
			line(crown+Vector2(0,15),crown+Vector2(side*17,-8),Color("70463f"),4)
			line(crown+Vector2(side*8,4),crown+Vector2(side*8,-12),Color("70463f"),3)
			paint_rect(Rect2(crown+Vector2(side*8-4,-14),Vector2(10,3)),Color("f7e6bc"))
		box(at.x+0.06,at.y+0.06,0.68,0.68,2,Color("f7e6bc"),8)
	else:
		var shade=Color(["77679d","235b58","9a414e"][season]);var lit=Color(["b99cc5","7a9859","e7ab53"][season])
		if night:shade=shade.darkened(0.2);lit=lit.darkened(0.2)
		for row in TREE_CROWN.size():
			for col in TREE_CROWN[row].length():
				var pixel=TREE_CROWN[row][col]
				if pixel==".":continue
				var color=lit
				if pixel in ["o","s"]:color=shade
				elif pixel=="h":color=Color("f7e6bc") if season==0 else Color("9bc59d") if season==1 else Color("b77843")
				paint_rect(Rect2(crown+Vector2(col*2-30,row*2-36),Vector2(2,2)),color)
	# The empty-cart rack and recycling bins sit beyond the cutaway front edge.
	for i in 2:
		var x=dims.x-2.2+i*0.55;var y=dims.y+0.6
		box(x,y,0.42,0.46,20,Color("798a87"));box(x-0.02,y-0.02,0.46,0.5,4,Color("378c78"),20)
		box(x+0.1,y+0.47,0.20,0.02,7,Color("f7e6bc"),10)
		box(x+0.12,y+0.48,0.16,0.02,2,Color("20283f"),18)

func poster_art():
	var season=sim.season()
	# Fixed posters use pictures at source scale, not illegible fake letters.
	var poster=project(Vector2(0,5.0),53)
	paint_rect(Rect2(poster-Vector2(13,14),Vector2(22,27)),Color("f7e6bc"))
	paint_rect(Rect2(poster-Vector2(11,12),Vector2(18,7)),Color(["b99cc5","67a9bb","e7ab53","d65b54"][season]))
	if season==0:
		paint_rect(Rect2(poster+Vector2(-6,-1),Vector2(10,7)),Color("e7ab53"));paint_rect(Rect2(poster+Vector2(-7,-3),Vector2(12,2)),Color("70463f"))
	elif season==1:
		paint_rect(Rect2(poster+Vector2(-4,-3),Vector2(5,12)),Color("67a9bb"));paint_rect(Rect2(poster+Vector2(-3,-6),Vector2(3,3)),Color("378c78"))
	elif season==2:
		paint_rect(Rect2(poster+Vector2(-7,-2),Vector2(14,8)),Color("77679d"));paint_rect(Rect2(poster+Vector2(-4,-3),Vector2(8,4)),Color("e7ab53"))
	else:
		paint_rect(Rect2(poster+Vector2(-7,1),Vector2(14,7)),Color("e7ab53"));paint_rect(Rect2(poster+Vector2(-8,-1),Vector2(16,2)),Color("70463f"))
		for x in [-4,2]:paint_rect(Rect2(poster+Vector2(x,-7),Vector2(2,4)),Color("858991"))

func window(v:Vector2,night:bool):
	var a=project(v,59)
	poly([a,a+Vector2(60,30),a+Vector2(60,2),a+Vector2(0,-28)],Color("789999") if not night else Color("253e55"))
	line(a+Vector2(30,15),a+Vector2(30,-13),Color("e7e0c7"),3)
	line(a+Vector2(1,-24),a+Vector2(58,4),Color("bfd0bd"),2)

func draw_fixture(f:Dictionary):
	var e=sim.equipment[f.kind];var x=float(f.x);var y=float(f.y)
	var selected=selected_kind=="fixture" and selected_id==f.id
	if selected:
		tile(x,y,Color("ebaa62"),11)
		var a=Nav.access(f);tile(a.x,a.y,Color("ebcb7b"),11)
		if Nav.is_register(f):
			var c=Nav.clerk(f);tile(c.x,c.y,Color("8dbac8"),11)
	fixture_turn=f.dir;fixture_pivot=Vector2(x+0.5,y+0.5)
	var height=fixture_art(f,x,y)
	if f.dir in [2,3]:fixture_back_art(f,x,y,height)
	if f.product>=0:
		var p=project(Vector2(x+0.52,y+1),13)
		paint_rect(Rect2(p-Vector2(9,8),Vector2(18,10)),CREAM)
		label(p-Vector2(7,0),str(sim.counts(f.lots)),Color("52645a"),8)
		if sim.counts(f.lots)==0:label(project(Vector2(x+0.6,y+0.6),height+22),"欠品",Color("a24739"),11)
	if f.ready>sim.s.tick:label(project(Vector2(x,y),height+18),"準備中",INK,11)
	fixture_turn=0
	var center=cell_screen(Vector2(x+0.5,y+0.5),height/2+9)
	hit_fixtures.append({"id":f.id,"rect":Rect2(center-Vector2(30,height/2+10)*scale_world,Vector2(60,height+30)*scale_world)})
func fixture_art(f:Dictionary,x:float,y:float) -> int:
	match int(f.kind):
		2,10,18:return register_art(f,x,y)
		1,9,17:return refrigerator_art(f,x,y)
		13:return dessert_art(f,x,y)
		14:return freezer_art(f,x,y)
		3,11:return hot_art(f,x,y)
		4:return magazine_art(f,x,y)
		12:return bread_art(f,x,y)
		7,15:
			plant_art(Vector2(x,y),sim.season(),f.kind==15)
			return 65 if f.kind==15 else 38
		6,19:return rest_art(f,x,y)
		5:
			box(x+0.12,y+0.24,0.65,0.55,4,Color("596070"),12)
			for side in [0.17,0.67]:box(x+side,y+0.27,0.08,0.12,5,Color("20283f"),10)
			box(x+0.18,y+0.3,0.38,0.38,20,Color("67a9bb"),16)
			box(x+0.20,y+0.32,0.34,0.34,2,Color("3f6b92"),36)
			var at=project(Vector2(x+0.65,y+0.52),16)
			line(at,at+Vector2(-4,-44),Color("b77843"),3)
			paint_rect(Rect2(at+Vector2(-7,-47),Vector2(10,4)),Color("f7e6bc"))
			box(x+0.12,y+0.7,0.27,0.04,8,Color("f7e6bc"),22)
			return 54
		_:return shelf_art(f,x,y)

func fixture_back_art(f:Dictionary,x:float,y:float,height:int):
	# Closed backs are nearer the camera in these two rotations. Draw them last;
	# otherwise stock would be visible through the metal or wooden rear panel.
	match int(f.kind):
		0,8,16:
			box(x+0.01,y+0.04,0.98,0.10,height-9,Color("b9b9ad"),10)
			for level in range(17,height,13):box(x+0.03,y+0.02,0.94,0.02,2,Color("858991"),level)
		1,9,17:
			box(x+0.04,y+0.06,0.92,0.08,height-6,Color("858991"),10)
			box(x+(0.04 if f.dir==2 else 0.90),y+0.06,0.06,0.84,height-6,Color("596070"),10)
			for level in range(18,height,8):box(x+0.14,y+0.04,0.72,0.02,2,Color("596070"),level)
			box(x+0.68,y+0.03,0.16,0.02,9,Color("f7e6bc"),19)
		3,11:
			box(x+0.12,y+0.1,0.78,0.05,height-30,Color("b77843"),28)
			for i in 4:box(x+0.2+i*0.15,y+0.08,0.04,0.02,8,Color("70463f"),34)
		12:
			box(x+0.05,y+0.13,0.90,0.08,45,Color("b77843"),10)
			for level in range(18,55,9):box(x+0.06,y+0.11,0.88,0.02,2,Color("70463f"),level)

func register_art(f:Dictionary,x:float,y:float) -> int:
	var top=Color("f7e6bc");var dark=Color("20283f")
	box(x+0.04,y+0.04,0.92,0.92,28,Color("378c78"),10)
	box(x+0.06,y+0.93,0.88,0.04,5,Color("d65b54"),31)
	box(x,y,1,1,5,top,38)
	# The terminal faces the clerk; the tray remains on the customer side.
	box(x+0.12,y+0.18,0.46,0.32,5,dark,43)
	box(x+0.17,y+0.20,0.36,0.08,12,dark,48)
	if f.dir in [2,3]:box(x+0.20,y+0.17,0.30,0.03,7,Color("67a9bb"),51)
	box(x+0.66,y+0.61,0.22,0.22,2,Color("67a9bb"),43)
	box(x+0.65,y+0.20,0.10,0.18,4,dark,43)
	if f.kind==10:
		box(x+0.71,y+0.36,0.18,0.16,7,dark,43)
		box(x+0.74,y+0.49,0.12,0.02,3,Color("d65b54"),46)
		box(x+0.10,y+0.62,0.26,0.16,1,top,44) # printed receipt
		for i in 3:box(x+0.12,y+0.65+i*0.03,0.18,0.01,1,Color("596070"),45)
	if f.kind==18:
		box(x+0.60,y+0.08,0.06,0.06,23,dark,43)
		box(x+0.48,y+0.08,0.35,0.05,12,dark,60)
		if f.dir in [0,1]:box(x+0.51,y+0.14,0.29,0.02,8,Color("9bc59d"),62)
		box(x+0.10,y+0.56,0.44,0.32,2,Color("596070"),43)
		for i in 4:box(x+0.12+i*0.10,y+0.57,0.03,0.28,1,dark,45)
	return 64 if f.kind==18 else 49

func shelf_art(f:Dictionary,x:float,y:float) -> int:
	var rows=4 if f.kind in [8,16] else 3
	var step=14 if f.kind==16 else 11
	var height=rows*step+8
	box(x+0.02,y+0.04,0.96,0.12,height,Color("b9b9ad"),10)
	for side in [0.02,0.91]:
		box(x+side,y+0.85,0.06,0.08,height,Color("b9b9ad"),10)
		if f.kind==16:
			for z in range(18,height+8,8):box(x+side,y+0.94,0.04,0.01,2,Color("596070"),z)
	for level in rows:
		var z=16+level*step
		box(x+0.02,y+0.18,0.95,0.75,3,Color("f7e6bc"),z)
		items(f,x+0.10,y+0.72,z+5,level,rows)
		price_rail(x+0.04,y+0.94,0.9,z)
	if f.kind==8:
		# Wide shelf uses the available depth, with baskets on the end cap.
		for side in [0.02,0.92]:box(x+side,y+0.1,0.06,0.82,3,Color("378c78"),height+10)
	if f.kind==16:
		box(x+0.04,y+0.08,0.92,0.12,8,Color("378c78"),height+10)
		for i in 3:box(x+0.15+i*0.25,y+0.21,0.13,0.02,3,Color("f7e6bc"),height+12)
	return height+10

func refrigerator_art(f:Dictionary,x:float,y:float) -> int:
	var industrial=f.kind==17
	var rows=4 if f.kind in [9,17] else 3
	var height=72 if industrial else (65 if f.kind==9 else 58)
	box(x+0.04,y+0.06,0.92,0.84,height-5,Color("20283f"),10)
	box(x+0.02,y+0.04,0.96,0.90,6,Color("b9b9ad") if industrial else Color("f7e6bc"),height+5)
	box(x+0.08,y+0.90,0.84,0.05,3,Color("a5c8bf"),height+4)
	for side in [0.04,0.90]:box(x+side,y+0.86,0.06,0.10,height-9,Color("b9b9ad"),14)
	for level in rows:
		var z=20+level*(12 if rows==4 else 14)
		box(x+0.12,y+0.53,0.76,0.38,2,Color("67a9bb"),z)
		items(f,x+0.12,y+0.74,z+4,level,rows)
		price_rail(x+0.12,y+0.92,0.76,z)
	box(x+0.05,y+0.91,0.90,0.04,5,Color("b9b9ad"),11)
	for i in 6:box(x+0.15+i*0.12,y+0.96,0.06,0.01,2,Color("20283f"),12)
	if f.kind==9:box(x+0.47,y+0.86,0.05,0.10,height-9,Color("f7e6bc"),14)
	if industrial:
		for side in [0.08,0.51]:
			var a=project(Vector2(x+side,y+0.97),19);var b=project(Vector2(x+side+0.4,y+0.97),19)
			poly([a,b,b+Vector2(0,-47),a+Vector2(0,-47)],Color(0.40,0.66,0.73,0.22))
			line(a+Vector2(3,-43),b+Vector2(-3,-25),Color("a5c8bf"),2)
		box(x+0.49,y+0.94,0.03,0.05,50,Color("b9b9ad"),18)
		for side in [0.43,0.56]:box(x+side,y+0.97,0.03,0.03,13,Color("f7e6bc"),32)
		for i in 5:box(x+0.14+i*0.15,y+0.95,0.06,0.02,2,Color("20283f"),height+7)
	return height+6

func dessert_art(f:Dictionary,x:float,y:float) -> int:
	box(x+0.04,y+0.08,0.92,0.82,23,Color("9a414e"),10)
	box(x+0.06,y+0.18,0.88,0.65,3,Color("f7e6bc"),34)
	for level in 2:
		var z=30+level*14
		box(x+0.12,y+0.32,0.76,0.56,2,Color("f7e6bc"),z)
		items(f,x+0.12,y+0.72,z+5,level,2)
	var a=project(Vector2(x+0.05,y+0.93),31);var b=project(Vector2(x+0.95,y+0.93),31)
	var c=project(Vector2(x+0.95,y+0.18),57);var d=project(Vector2(x+0.05,y+0.18),57)
	poly([a,b,c,d],Color(0.65,0.78,0.75,0.18))
	for edge in [[a,b],[b,c],[c,d],[d,a]]:
		line(edge[0],edge[1],Color("596070"),4)
		line(edge[0],edge[1],Color("f7e6bc"),2)
	price_rail(x+0.1,y+0.96,0.8,28)
	return 57

func freezer_art(f:Dictionary,x:float,y:float) -> int:
	box(x+0.03,y+0.06,0.94,0.88,27,Color("67a9bb"),10)
	box(x+0.04,y+0.07,0.92,0.86,3,Color("f7e6bc"),37)
	box(x+0.10,y+0.14,0.80,0.72,1,Color("3f6b92"),40)
	items(f,x+0.12,y+0.68,39,0,1)
	for side in [0.13,0.52]:
		var a=project(Vector2(x+side,y+0.18),43);var b=project(Vector2(x+side+0.35,y+0.18),43)
		var c=project(Vector2(x+side+0.35,y+0.82),43);var d=project(Vector2(x+side,y+0.82),43)
		poly([a,b,c,d],Color(0.65,0.78,0.75,0.25))
		line(a,c,Color("a5c8bf"),2)
	box(x+0.48,y+0.12,0.04,0.76,2,Color("f7e6bc"),43)
	for side in [0.39,0.56]:box(x+side,y+0.63,0.04,0.15,2,Color("20283f"),43)
	# Snowflake badge, not a second upright refrigerator.
	var mark=project(Vector2(x+0.5,y+0.96),25)
	line(mark+Vector2(-6,0),mark+Vector2(6,0),Color("f7e6bc"),2)
	line(mark+Vector2(0,-6),mark+Vector2(0,6),Color("f7e6bc"),2)
	return 44

func hot_art(f:Dictionary,x:float,y:float) -> int:
	var rows=3 if f.kind==11 else 2;var height=63 if f.kind==11 else 53
	box(x+0.05,y+0.05,0.9,0.9,18,Color("d65b54"),10)
	box(x+0.12,y+0.1,0.78,0.7,height-28,Color("70463f"),28)
	for level in rows:
		box(x+0.14,y+0.5,0.72,0.38,2,Color("e7ab53"),29+level*12)
		items(f,x+0.14,y+0.73,33+level*12,level,rows)
	for side in [0.10,0.85]:box(x+side,y+0.85,0.05,0.05,height-26,Color("f7e6bc"),27)
	box(x+0.08,y+0.08,0.84,0.84,4,Color("e7ab53"),height)
	if f.kind==11:
		for i in 3:box(x+0.15+i*0.25,y+0.96,0.12,0.02,4,Color("e7ab53"),20)
	if not reduced and sim.counts(f.lots)>0:
		var p=project(Vector2(x+0.5,y+0.3),height+5)
		for i in 2:paint_rect(Rect2(p+Vector2(i*7,-posmod(int(clock*4)+i*3,8)),Vector2(2,4)),Color(1,1,0.87,0.55))
	return height+4

func magazine_art(f:Dictionary,x:float,y:float) -> int:
	for side in [0.08,0.87]:box(x+side,y+0.12,0.05,0.75,38,Color("596070"),10)
	for level in 3:
		var depth=0.8-level*0.22;var z=14+level*13
		box(x+0.08,y+depth-0.22,0.84,0.26,2,Color("b9b9ad"),z)
		if f.product>=0 and f.product not in [70,72,74,78,79]:items(f,x+0.12,y+depth-0.03,z+5,level)
		elif f.product>=0:
			for i in 3:
				if level*3+i>=ceili(sim.counts(f.lots)/float(sim.equipment[f.kind].capacity)*9):continue
				var c=Color(["67a9bb","d65b54","e7ab53"][i])
				box(x+0.13+i*0.25,y+depth-0.18,0.21,0.03,15,c,z+2)
				box(x+0.15+i*0.25,y+depth-0.14,0.17,0.02,3,Color("f7e6bc"),z+12)
				box(x+0.18+i*0.25,y+depth-0.14,0.08,0.02,5,Color("20283f"),z+5)
		price_rail(x+0.09,y+depth+0.02,0.82,z)
	return 58

func bread_art(f:Dictionary,x:float,y:float) -> int:
	for side in [0.05,0.88]:box(x+side,y+0.14,0.07,0.72,45,Color("b77843"),10)
	for level in 3:
		var z=15+level*13
		box(x+0.07,y+0.22,0.86,0.67,3,Color("70463f"),z)
		items(f,x+0.10,y+0.68,z+5,level)
		box(x+0.06,y+0.87,0.88,0.05,5,Color("e7ab53"),z+1)
		for i in 7:box(x+0.12+i*0.12,y+0.93,0.03,0.02,4,Color("b77843"),z+1)
	box(x+0.05,y+0.12,0.9,0.12,10,Color("e7ab53"),55)
	var p=project(Vector2(x+0.5,y+0.28),60)
	paint_rect(Rect2(p-Vector2(7,2),Vector2(14,4)),Color("f7e6bc"))
	return 65

func rest_art(f:Dictionary,x:float,y:float) -> int:
	var sofa=f.kind==19
	for side in [0.10,0.80]:box(x+side,y+0.2,0.10,0.6,10,Color("70463f"),10)
	box(x+0.04,y+0.15,0.9,0.7,8,Color("378c78") if sofa else Color("b77843"),20)
	box(x+0.04,y+0.15,0.9,0.15,22,Color("235b58") if sofa else Color("b77843"),26)
	if sofa:
		for side in [0.05,0.82]:box(x+side,y+0.20,0.13,0.62,15,Color("378c78"),26)
		for side in [0.20,0.50]:box(x+side,y+0.34,0.28,0.44,4,Color("9bc59d"),29)
	else:
		for i in 4:box(x+0.10,y+0.24+i*0.14,0.78,0.02,1,Color("e7ab53"),28)
		box(x+0.10,y+0.31,0.78,0.02,2,Color("e7ab53"),39)
	return 49

func plant_art(at:Vector2,season:int,tall:bool=false):
	box(at.x+0.25,at.y+0.25,0.5,0.5,16,Color("b77843"),10)
	box(at.x+0.22,at.y+0.22,0.56,0.56,4,Color("e7ab53"),26)
	box(at.x+0.27,at.y+0.27,0.46,0.46,1,Color("70463f"),30)
	var p=project(at+Vector2(0.5,0.5),31)
	if tall:
		line(p,p+Vector2(0,-36),Color("70463f"),4)
		for i in 5:
			var tip=p+Vector2((-1 if i%2==0 else 1)*(14+i%2*3),-8-i*6)
			var root=p+Vector2(0,-i*5);var middle=(root+tip)*0.5;var normal=(tip-root).orthogonal().normalized()*6
			poly([root,middle+normal,tip,middle-normal],Color("378c78") if i%2==0 else Color("9bc59d"))
	else:
		for offset in [Vector2(-8,-2),Vector2(6,-3),Vector2(0,-12)]:
			paint_rect(Rect2(p+offset-Vector2(5,5),Vector2(10,8)),Color("506743"))
			paint_rect(Rect2(p+offset-Vector2(3,6),Vector2(7,5)),Color("7a9859"))
		var petals=Color(["b99cc5","f7e6bc","e7ab53","d65b54"][season])
		for offset in [Vector2(-7,-9),Vector2(5,-10),Vector2(0,-16)]:
			paint_rect(Rect2(p+offset,Vector2(4,4)),petals)

func price_rail(x:float,y:float,width:float,z:float):
	box(x,y,width,0.04,3,Color("378c78"),z)
	for i in 3:
		box(x+0.06+i*width/3,y+0.04,0.12,0.02,2,Color("f7e6bc"),z+0.5)
func items(f:Dictionary,x:float,y:float,z:float,row:int,rows:int=3):
	if f.product<0:return
	var n=sim.counts(f.lots);var e=sim.equipment[f.kind]
	var fill=ceili(n/float(maxi(e.capacity,1))*4*rows)
	var c=Color(Cat.COLORS[sim.products[f.product].cat])
	for i in 4:
		if i*rows+row>=fill:continue
		var at=Vector2(x+i*0.19,y)
		var p=project(at+Vector2(0.07,0.16),z+5).snapped(Vector2(2,2))
		var ink=Color("20283f");var paper=Color("f7e6bc");var variant=int(f.product)%10
		match sim.products[f.product].cat:
			0: # Boxed meals and rice triangles have different silhouettes.
				if variant in [3,6,8,9]:
					paint_rect(Rect2(p+Vector2(-2,-4),Vector2(10,6)),ink);paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,2)),paper);paint_rect(Rect2(p+Vector2(4,-2),Vector2(2,2)),Color("b77843"));continue
				paint_rect(Rect2(p+Vector2(-2,0),Vector2(10,4)),ink)
				paint_rect(Rect2(p+Vector2(2,-4),Vector2(2,2)),paper);paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,4)),paper);paint_rect(Rect2(p+Vector2(2,0),Vector2(2,2)),ink)
			1:
				paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,4)),Color("b77843"));paint_rect(Rect2(p+Vector2(2,-4),Vector2(4,4)),Color("e7ab53"));paint_rect(Rect2(p+Vector2(2,-2),Vector2(2,2)),paper)
			2:
				if variant in [1,4,7]:
					paint_rect(Rect2(p+Vector2(0,-6),Vector2(6,8)),ink);paint_rect(Rect2(p+Vector2(0,-6),Vector2(6,2)),paper);paint_rect(Rect2(p+Vector2(2,-2),Vector2(2,2)),Color("e7ab53"));continue
				paint_rect(Rect2(p+Vector2(2,-6),Vector2(2,2)),paper);paint_rect(Rect2(p+Vector2(0,-4),Vector2(6,6)),c);paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,2)),paper)
			4:
				paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,4)),Color("e7ab53"));paint_rect(Rect2(p+Vector2(0,-4),Vector2(6,2)),Color("70463f"));paint_rect(Rect2(p+Vector2(2,0),Vector2(2,2)),paper)
			5:
				paint_rect(Rect2(p+Vector2(0,-4),Vector2(6,2)),paper);paint_rect(Rect2(p+Vector2(0,-2),Vector2(6,4)),c);paint_rect(Rect2(p+Vector2(2,0),Vector2(2,2)),paper)
			7:
				if variant==3:
					paint_rect(Rect2(p+Vector2(2,-8),Vector2(2,8)),Color("d65b54"));paint_rect(Rect2(p+Vector2(0,0),Vector2(4,2)),ink)
				else:
					paint_rect(Rect2(p+Vector2(0,-6),Vector2(6,8)),ink);paint_rect(Rect2(p+Vector2(0,-6),Vector2(4,6)),paper);paint_rect(Rect2(p+Vector2(0,-4),Vector2(4,2)),c)
			_:
				paint_rect(Rect2(p+Vector2(0,-4),Vector2(6,6)),c);paint_rect(Rect2(p+Vector2(0,-4),Vector2(6,2)),paper);paint_rect(Rect2(p+Vector2(2,0),Vector2(2,2)),ink)


func actor_at(a:Dictionary) -> Vector2:
	var at=Vector2(a.get("prev",a.pos)).lerp(Vector2(a.pos),interp)+Vector2(0.5,0.5)
	# Each walking direction keeps to its own side of a wide floor tile.
	var d=int(a.get("dir",0))
	if d>=0 and d<4 and a.get("prev",a.pos)!=a.pos:
		var direction:Vector2=Vector2(Nav.DIRS[d]);at+=Vector2(-direction.y,direction.x)*0.14
	return at

func draw_person(a:Dictionary,kind:String):
	var staff=kind=="staff"
	var r=a if staff else sim.s.residents[a.rid]
	var at=actor_at(a)
	var moving=a.get("prev",a.pos)!=a.pos
	painter_alpha=1.0
	if at.x<0:
		var dims=Nav.dimensions(sim.s.tier)
		painter_alpha=clampf(minf(at.y+3,dims.y+4-at.y)/2.0,0,1)
	var base=project(at,1 if at.x<0 else 10)
	var select=selected_kind==kind and selected_id==(a.id if staff else a.rid)
	if select:
		paint_arc(base+Vector2(0,2),15,0,TAU,12,Color("ffdd8d"),3,false)
	poly([base+Vector2(-13,0),base+Vector2(0,-5),base+Vector2(13,0),base+Vector2(0,6)],Color(0.13,0.23,0.2,0.19))
	var dir=int(a.get("dir",0))
	var identity=int(r.id)
	var pose="joy" if not staff and a.bought else ("browse" if not staff and a.state=="browsing" else "idle")
	var frame=(1+int(clock*6)%2) if moving and not reduced else 0
	var sprite=People.texture(identity,dir,frame,staff,pose)
	var dest=Rect2((base+Vector2(-16,-46)).snapped(Vector2(2,2)),Vector2(32,48))
	draw_texture_rect(sprite,dest,false,Color(1,1,1,painter_alpha))
	if not staff and a.bought:
		box(at.x+0.2,at.y+0.15,0.20,0.16,10,Color("dfc392"),14)
		if r.history.size()>0 and "会議が長引くほど長いパン" in r.history[0].items:box(at.x+0.2,at.y+0.15,0.1,0.1,28,Color("c29458"),20)
	if staff and not a.carry.is_empty():box(at.x+0.15,at.y+0.15,0.35,0.25,13,Color("c49e68"),20)
	if staff and a.task=="clean":line(base+Vector2(7,-22),base+Vector2(19,3),Color("b78d62"),2)
	if not staff and sim.event_for(sim.s.day).id=="hero" and r.id%3==0:
		poly([base+Vector2(-12,-34),base+Vector2(-16,-10),base+Vector2(-5,-14)],Color("be695b"))
	var show=select or (not staff and (r.favorite or (a.state in ["browsing","paying"] and r.id%4==0)))
	if show:
		var text=a.get("mood",r.name) if not staff else {"register":"レジはおまかせ","stock":"棚の見回りです","depot":"商品、取ってきます","rest":"休息も、仕事。","clean":"床までぴかぴか"}.get(a.task,"ひと息つこう")
		if text.length()>15:text=text.substr(0,14)+"…"
		var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		var p=base+Vector2(-width/2,-67)
		label(p+Vector2(0,2),text,INK,12,true,2 if select else 0)
	var screen=origin+base*scale_world
	hit_people.append({"kind":kind,"id":a.id if staff else a.rid,"rect":Rect2(screen+Vector2(-20,-53)*scale_world,Vector2(40,55)*scale_world)})

	painter_alpha=1.0
