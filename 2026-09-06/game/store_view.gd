extends Control
const Nav=preload("res://core/navigation.gd")
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
var atlas:Texture2D
var font:Font
var origin=Vector2.ZERO
var scale_world=1.0
var hit_people=[]
var hit_fixtures=[]
const INK=Color("253d40")
const CREAM=Color("fff2d2")

func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	atlas=load("res://assets/images/neighbors.png")
	font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	var shader=Shader.new()
	shader.code="shader_type canvas_item; varying vec4 tint_color; void vertex(){tint_color=COLOR;} void fragment(){ vec4 t=texture(TEXTURE,UV); if(t.r>0.72 && t.b>0.65 && t.g<0.22) t.a=0.0; COLOR=t*tint_color; }"
	var mat=ShaderMaterial.new();mat.shader=shader;material=mat
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
func poly(points:Array,color:Color):
	draw_colored_polygon(PackedVector2Array(points),color)
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
func line(a:Vector2,b:Vector2,color:Color,width:float=1):draw_line(a,b,color,width,false)
func label(at:Vector2,text:String,color:Color=CREAM,font_size:int=12):draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw():
	if sim==null or font==null:return
	var s=sim.s;var dims=Nav.dimensions(s.tier)
	var night=sim.minute()<360 or sim.minute()>=1140
	var evening=sim.minute()>=990 and sim.minute()<1140
	var bg=Color("213743") if night else (Color("bb9986") if evening else Color("9eada0"))
	draw_rect(Rect2(Vector2.ZERO,size),bg)
	# Pixel-paper grain in the landscape, deterministic and static.
	for i in 140:
		var pos=Vector2((i*137+21)%maxi(int(size.x),1),(i*83+17)%maxi(int(size.y),1))
		draw_rect(Rect2(pos,Vector2(2,2)),bg.lightened(0.06))
	scale_world=clampf(minf((size.x-70)/((dims.x+dims.y+5)*32.0),(size.y-95)/((dims.x+dims.y+5)*16.0+100)),0.45,1.4)*zoom
	origin=Vector2(size.x*0.5-(dims.x-dims.y)*16*scale_world,size.y*0.5-(dims.x+dims.y)*8*scale_world+34)+pan
	draw_set_transform(origin,0,Vector2.ONE*scale_world)
	# Raised corner of the neighborhood, sidewalks and street.
	box(-2,-2,dims.x+4,dims.y+4,10,Color("819485") if not night else Color("455b56"),-10)
	for x in range(-2,dims.x+2):
		for y in range(-2,dims.y+2):
			if x>=0 and y>=0 and x<dims.x and y<dims.y:continue
			var c=Color("b2b8a9") if (x+y)%2==0 else Color("a7ae9f")
			if x>dims.x or y>dims.y:c=Color("637675")
			tile(x,y,c.darkened(0.25) if night else c)
	# Concrete base and floor border.
	box(-0.15,-0.15,dims.x+0.3,dims.y+0.3,8,Color("526861"))
	for x in dims.x:
		for y in dims.y:
			var color=Color("eee5c9") if (x+y)%2==0 else Color("e0d7b9")
			if x<2 and y<3:color=Color("bcbfab") if (x+y)%2==0 else Color("b0b59f")
			tile(x,y,color,9)
			if (x*13+y*7)%9==0:
				var at=project(Vector2(x+0.6,y+0.4),9);draw_rect(Rect2(at,Vector2(2,1)),Color("cfc5aa"))
	# Rear walls, teal skirting, windows and hand-lettered store name.
	box(0,-0.16,dims.x,0.16,76,Color("dfd8bd"),9)
	box(-0.16,0,0.16,dims.y,76,Color("e9e0c2"),9)
	box(0,-0.22,dims.x,0.2,11,Color("42756b"),68)
	box(-0.22,0,0.2,dims.y,11,Color("42756b"),68)
	box(0,-0.23,dims.x,0.22,4,Color("df9875"),64)
	for x in range(2,dims.x-1,3):
		window(Vector2(x,0),night)
	for y in range(4,dims.y-1,3):
		var p=project(Vector2(0,y),38)
		poly([p,p+Vector2(-40,20),p+Vector2(-40,-10),p+Vector2(0,-30)],Color("365c62"))
		line(p+Vector2(-20,10),p+Vector2(-20,-20),Color("9bb7aa"),2)
	# Backroom crates, notice board, tiny clock, sign.
	box(0.25,0.4,0.7,0.5,20,Color("b79159"),9)
	box(0.3,0.45,0.6,0.4,16,Color("c9a46a"),29)
	var notice=project(Vector2(0,2.8),61)
	draw_rect(Rect2(notice-Vector2(22,12),Vector2(38,30)),Color("aa8155"))
	draw_rect(Rect2(notice-Vector2(18,9),Vector2(17,22)),CREAM)
	draw_rect(Rect2(notice+Vector2(2,-6),Vector2(10,15)),Color("db9b77"))
	label(project(Vector2(2,0),89),"まちあかり MART",Color("f8ebce"),17)
	label(project(Vector2(0.5,1.4),14),"倉庫",Color("57645b"),10)
	# Door mat at permanent logical entrance.
	tile(1,8,Color("34786a"),10)
	var mat=project(Vector2(1.1,8.7),12);label(mat,"いらっしゃい",CREAM,8)
	# Draw fixtures and actors by their feet.
	var draws=[]
	for f in s.fixtures:draws.append({"type":"fixture","data":f,"depth":f.x+f.y+0.65})
	for v in s.visits:draws.append({"type":"resident","data":v,"depth":v.pos.x+v.pos.y+1.0})
	for w in s.staff:
		if w.hired and (sim.working(w) or not w.path.is_empty()):draws.append({"type":"staff","data":w,"depth":w.pos.x+w.pos.y+1.01})
	draws.sort_custom(func(a,b):return a.depth<b.depth)
	hit_people=[];hit_fixtures=[]
	for item in draws:
		if item.type=="fixture":draw_fixture(item.data)
		else:draw_person(item.data,item.type)
	# Small exterior details establish a lived-in corner.
	for v in [Vector2(dims.x+0.4,1),Vector2(0.5,dims.y+0.6)]:
		box(v.x,v.y,0.65,0.65,13,Color("bb8e66"));box(v.x+0.1,v.y+0.1,0.5,0.5,20,Color("55826c"),13)
		box(v.x+0.22,v.y+0.15,0.24,0.24,9,Color("86a271"),33)
	var bike=project(Vector2(5,dims.y+1),6)
	draw_arc(bike,8,0,TAU,12,INK,2,false);draw_arc(bike+Vector2(27,0),8,0,TAU,12,INK,2,false)
	line(bike,bike+Vector2(10,-16),Color("b46e54"),3);line(bike+Vector2(10,-16),bike+Vector2(27,0),Color("b46e54"),3);line(bike,bike+Vector2(27,0),Color("b46e54"),2)
	box(dims.x+0.1,4,0.6,0.7,40,Color("dfc3a0"));label(project(Vector2(dims.x+0.4,4.5),49),"OPEN",Color("334e4c"),9)
	# Build preview and accessible face marker.
	if build_kind>=0 and Nav.inside(hover_cell,dims):
		var draft=s.fixtures.duplicate(true)
		if move_id>=0:draft=draft.filter(func(f):return f.id!=move_id)
		draft.append({"x":hover_cell.x,"y":hover_cell.y,"dir":build_dir})
		var valid=Nav.validate(draft,s.tier).is_empty()
		tile(hover_cell.x,hover_cell.y,Color(0.3,0.75,0.65,0.7) if valid else Color(0.85,0.32,0.26,0.7),13)
		box(hover_cell.x+0.05,hover_cell.y+0.05,0.9,0.9,36,Color(0.35,0.82,0.68,0.4) if valid else Color(0.85,0.32,0.26,0.4),14)
		var a=hover_cell+Nav.DIRS[build_dir]
		tile(a.x,a.y,Color(1,0.83,0.4,0.7),13)
		label(project(Vector2(hover_cell),24),"設置" if valid else "置けません",INK,12)
	# Short, result-driven feedback.
	for e in s.effects:
		var age=s.tick-e.time
		var pos=project(Vector2(e.pos)+Vector2(0.5,0.5),66+(0 if reduced else age*1.2))
		var width=font.get_string_size(e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_rect(Rect2(pos-Vector2(width/2+5,14),Vector2(width+10,19)),Color("fff0c7"))
		label(pos-Vector2(width/2,0),e.text,Color("397263") if e.kind=="good" else Color("956544"),12)
	draw_set_transform(Vector2.ZERO)
	# Daylight tint stays subtle and leaves menus legible.
	if night:draw_rect(Rect2(Vector2.ZERO,size),Color(0.07,0.12,0.26,0.14))
	if sim.weather_for(s.day)=="雨" and not reduced:
		for i in 45:
			var p=Vector2(fmod(i*97+clock*45,size.x),fmod(i*61+clock*155,size.y))
			line(p,p+Vector2(-4,11),Color(0.83,0.9,0.94,0.3))
	# Quiet map caption.
	label(Vector2(22,size.y-22),"住宅街・あかり町  /  "+str(dims.x)+" × "+str(dims.y)+"",Color("edf0df"),12)
	label(Vector2(22,size.y-43),"ドラッグで移動  ·  ホイールで拡大  ·  右クリックで中央",Color("e2e8d9"),11)

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
	fixture_turn=f.dir;fixture_pivot=Vector2(x+0.5,y+0.5)
	var height=42
	match e.kind:
		"register":
			height=32
			box(x+0.04,y+0.04,0.92,0.92,28,Color("528879"),10)
			box(x,y,1,1,5,Color("ece3cb"),38)
			box(x+0.35,y+0.25,0.38,0.3,8,Color("425258"),43)
			box(x+0.4,y+0.28,0.3,0.1,10,Color("264950"),51)
			var p=project(Vector2(x+0.5,y+0.38),59);draw_rect(Rect2(p,Vector2(9,4)),Color("9ad1ac"))
			label(project(Vector2(x+0.45,y+0.9),30),"レジ",CREAM,9)
		"cold":
			height=51
			box(x+0.06,y+0.05,0.9,0.9,47,Color("cedcce"),10)
			box(x+0.08,y+0.08,0.84,0.85,3,Color("6b9c99"),57)
			for row in 3:
				box(x+0.12,y+0.53,0.76,0.38,2,Color("8bacab"),21+row*12)
				items(f,x+0.12,y+0.64,25+row*12,row)
		"hot":
			box(x+0.05,y+0.05,0.9,0.9,18,Color("a47753"),10)
			box(x+0.12,y+0.1,0.78,0.7,25,Color("e9cf95"),28)
			for row in 2:items(f,x+0.14,y+0.65,32+row*11,row)
			var p=project(Vector2(x+0.5,y+0.3),58)
			if not reduced and sim.counts(f.lots)>0:
				for i in 2:draw_rect(Rect2(p+Vector2(i*7,sin(clock*2+i)*3),Vector2(3,5)),Color(1,1,0.87,0.55))
		"decor":
			box(x+0.25,y+0.25,0.5,0.5,17,Color("c28b67"),10)
			box(x+0.12,y+0.18,0.72,0.65,20,Color("548675"),27)
			box(x+0.3,y+0.23,0.35,0.35,10,Color("87a976"),47)
		"rest":
			height=28
			box(x+0.04,y+0.15,0.9,0.7,16,Color("b88e62"),10)
			box(x+0.04,y+0.15,0.9,0.15,20,Color("628b7a"),26)
		"clean":
			height=34
			box(x+0.3,y+0.3,0.4,0.4,18,Color("7c9b99"),10)
			var p=project(Vector2(x+0.6,y+0.5),10);line(p,p+Vector2(3,-42),Color("a57955"),3)
		_:
			box(x+0.04,y+0.08,0.92,0.82,38,Color("be945f"),10)
			box(x+0.01,y+0.04,0.98,0.14,44,Color("d8b87e"),10)
			for row in 3:
				box(x+0.02,y+0.2,0.95,0.73,3,Color("efd2a0"),16+row*13)
				items(f,x+0.10,y+0.6,21+row*13,row)
	if f.product>=0:
		var p=project(Vector2(x+0.52,y+1),13)
		draw_rect(Rect2(p-Vector2(9,8),Vector2(18,10)),CREAM)
		label(p-Vector2(7,0),str(sim.counts(f.lots)),Color("52645a"),8)
		if sim.counts(f.lots)==0:label(project(Vector2(x+0.6,y+0.6),height+22),"欠品",Color("a24739"),11)
	if f.ready>sim.s.tick:label(project(Vector2(x,y),height+18),"準備中",INK,11)
	fixture_turn=0
	var center=cell_screen(Vector2(x+0.5,y+0.5),height/2+9)
	hit_fixtures.append({"id":f.id,"rect":Rect2(center-Vector2(30,height/2+10)*scale_world,Vector2(60,height+30)*scale_world)})
func items(f:Dictionary,x:float,y:float,z:float,row:int):
	if f.product<0:return
	var n=sim.counts(f.lots);var e=sim.equipment[f.kind]
	var fill=ceili(n/float(maxi(e.capacity,1))*12)
	var c=Color(Cat.COLORS[sim.products[f.product].cat])
	for i in 4:
		if i*3+row>=fill:continue
		var at=Vector2(x+i*0.19,y)
		box(at.x,at.y,0.13 if sim.products[f.product].size==1 else 0.18,0.16,6,c.lightened((i%2)*0.12),z)
		var p=project(at+Vector2(0.07,0.16),z+3);draw_rect(Rect2(p,Vector2(2,2)),CREAM)

func draw_person(a:Dictionary,kind:String):
	var staff=kind=="staff"
	var r=a if staff else sim.s.residents[a.rid]
	var at=Vector2(a.pos)+Vector2(0.5,0.5)
	var moving=not a.path.is_empty()
	if moving and not reduced:at=Vector2(a.get("prev",a.pos)).lerp(Vector2(a.pos),interp)+Vector2(0.5,0.5)
	var base=project(at,10)
	var select=selected_kind==kind and selected_id==(a.id if staff else a.rid)
	if select:
		draw_arc(base+Vector2(0,2),15,0,TAU,12,Color("ffdd8d"),3,false)
	poly([base+Vector2(-13,0),base+Vector2(0,-5),base+Vector2(13,0),base+Vector2(0,6)],Color(0.13,0.23,0.2,0.19))
	var col=6
	var dir=int(a.get("dir",0))
	if moving:
		if dir in [0,1]:col=0 if int(clock*6)%2==0 else 1
		elif dir==2:col=3
		else:col=2
	var row=3 if staff else r.look
	# Atlas authored in seven equally spaced columns; 4 rows, baseline corrected per row.
	var region=Rect2(40+col*211,26+row*237,157,215)
	var bounce=0.0 if reduced or not moving else sin(clock*12+a.id)*1.2
	var dest=Rect2(base+Vector2(-18,-49+bounce),Vector2(36,49))
	var tint=Color.WHITE if staff else [Color.WHITE,Color("f4dfbf"),Color("d4e7ea"),Color("ead2d1"),Color("dfdfbd"),Color("dcd3ed")][r.tint]
	draw_texture_rect_region(atlas,dest,region,tint)
	if not staff and a.bought:
		box(at.x+0.2,at.y+0.15,0.20,0.16,10,Color("dfc392"),14)
		if r.history.size()>0 and "会議が長引くほど長いパン" in r.history[0].items:box(at.x+0.2,at.y+0.15,0.1,0.1,28,Color("c29458"),20)
	if staff and not a.carry.is_empty():box(at.x+0.15,at.y+0.15,0.35,0.25,13,Color("c49e68"),20)
	if staff and a.task=="clean":line(base+Vector2(7,-22),base+Vector2(19,3),Color("b78d62"),2)
	if not staff and sim.event_for(sim.s.day).id=="hero" and r.id%3==0:
		poly([base+Vector2(-12,-34),base+Vector2(-16,-10),base+Vector2(-5,-14)],Color("be695b"))
	if not staff:
		var accessory=r.id%5
		if accessory==0:
			draw_rect(Rect2(base+Vector2(-9,-42),Vector2(18,3)),Color("c18b59"))
			draw_rect(Rect2(base+Vector2(-6,-47),Vector2(12,5)),Color("dcb887"))
		elif accessory==1:draw_rect(Rect2(base+Vector2(9,-25),Vector2(6,12)),Color("ba7758"))
		elif accessory==2:line(base+Vector2(-8,-19),base+Vector2(-12,1),Color("967759"),2)
	var show=select or (not staff and (r.favorite or (a.state in ["browsing","paying"] and r.id%4==0)))
	if show:
		var text=a.get("mood",r.name) if not staff else {"register":"レジはおまかせ","stock":"棚の見回りです","depot":"商品、取ってきます","rest":"休息も、仕事。","clean":"床までぴかぴか"}.get(a.task,"ひと息つこう")
		if text.length()>15:text=text.substr(0,14)+"…"
		var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		var p=base+Vector2(-width/2,-67)
		draw_rect(Rect2(p-Vector2(5,11),Vector2(width+10,19)),INK)
		draw_rect(Rect2(p-Vector2(3,9),Vector2(width+6,15)),CREAM)
		label(p+Vector2(0,2),text,INK,10)
	var screen=origin+base*scale_world
	hit_people.append({"kind":kind,"id":a.id if staff else a.rid,"rect":Rect2(screen+Vector2(-20,-53)*scale_world,Vector2(40,55)*scale_world)})
