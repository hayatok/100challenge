extends Node2D
var sim
var art
var reduced = false
var effects: Array = []
var facing = 0
var anim_clock = 0.0
var pointer = Vector2(-1,-1)
var preview = false
var font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")

func _ready() -> void:
	material=art.key_material

func update_view(dt: float) -> void:
	if sim.state=="running":
		anim_clock+=dt
		if sim.velocity.length()>1:
			if absf(sim.velocity.x)>absf(sim.velocity.y): facing=3 if sim.velocity.x>0 else 2
			else: facing=0 if sim.velocity.y>0 else 1
		for fx in effects: fx.life-=dt
		effects=effects.filter(func(f):return f.life>0)
	queue_redraw()

func add_event(e: Dictionary) -> void:
	var item=e.duplicate()
	item.life=0.28 if e.kind=="beam" else 0.65
	if e.kind=="loop": item.life=0.85
	item.total=item.life
	effects.append(item)
	if effects.size()>120: effects.pop_front()

func sprite(key: String, region: Rect2, feet: Vector2, height: float, tint: Color = Color.WHITE, bob: float = 0.0) -> void:
	if not art.textures.has(key): return
	var width=height*region.size.x/region.size.y
	draw_texture_rect_region(art.textures[key],Rect2(feet-Vector2(width/2,height+bob),Vector2(width,height)),region,tint)

func effect_icon(index: int, at: Vector2, size: float, tint: Color = Color.WHITE) -> void:
	if not art.textures.has("fx"): return
	var src=Rect2((index%4)*384,(index/4)*341,384,341)
	draw_texture_rect_region(art.textures.fx,Rect2(at-Vector2.ONE*size/2,Vector2.ONE*size),src,tint)

func _draw() -> void:
	if sim==null: return
	if art.textures.has("arena"): draw_texture_rect(art.textures.arena,Rect2(0,0,1280,720),false)
	if sim.state in ["title","briefing","won","lost"]: return
	# These changing polygons are rules geometry, not substitutes for painted art.
	for stage in sim.stages:
		var life=clampf(float(stage.life)/2,0,1)
		draw_colored_polygon(stage.polygon,Color(0.22,0.84,0.73,0.11*life))
		var outline: PackedVector2Array=stage.polygon.duplicate()
		outline.append(outline[0])
		draw_polyline(outline,Color(0.44,0.94,0.82,0.75*life),2.0,true)
		effect_icon(11,stage.center,54,Color(0.70,1,0.88,0.8*life))
	if sim.loops==0 and sim.state=="running" and sim.clock<16:
		var guide=PackedVector2Array([Vector2(640,490),Vector2(430,490),Vector2(430,310),Vector2(680,310),Vector2(680,540),Vector2(560,540),Vector2(560,450)])
		for i in range(guide.size()-1):
			var a=guide[i];var b=guide[i+1];var length=a.distance_to(b)
			for j in range(0,int(length),24): draw_line(a.move_toward(b,j),a.move_toward(b,minf(j+9,length)),Color(1,.92,.72,.28),2,true)
		draw_string(font,Vector2(380,290),"線を横切ると、そこがステージ。",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff0cc"))
	for drop in sim.drops:
		effect_icon(8,drop.p,19)
	for terminal in sim.terminals:
		if terminal.active:
			effect_icon(11,terminal.p,82,Color(0.7,1,1,0.75))
			sprite("boss",Rect2(1045,560,430,400),terminal.p,62)
			draw_string(font,terminal.p+Vector2(-24,21),"囲もう",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("91f4df"))
	if sim.trail.size()>1:
		for i in range(sim.trail.size()-1):
			var age=sim.clock-float(sim.trail[i].t)
			var alpha=clampf((sim.trail_life()-age)/1.0,0.08,1.0)
			if not reduced: draw_line(sim.trail[i].p,sim.trail[i+1].p,Color(.2,.8,.8,.12*alpha),11,true)
			draw_line(sim.trail[i].p,sim.trail[i+1].p,Color(.42,.96,.89,alpha),3.3,true)
		draw_line(sim.trail[-1].p,sim.player,Color("98ffee"),3.3,true)
	# Telegraphs are drawn before actors; the foot position remains visible on top.
	for e in sim.enemies:
		if e.kind==1 and e.phase==1:
			draw_line(e.p,e.p+e.dir*180,Color(1,.49,.20,.65),9,true)
	for hazard in sim.hazards:
		var rect=Rect2(hazard.coordinate-28,150,56,520) if hazard.axis==0 else Rect2(112,hazard.coordinate-28,1056,56)
		draw_rect(rect,Color(1,.35,.25,.20 if hazard.warning>0 else .65))
		draw_rect(rect,Color(1,.65,.35,.85),false,2)
	var actors: Array=[]
	for e in sim.enemies: actors.append({"p":e.p,"enemy":e})
	actors.append({"p":sim.player,"player":true})
	if not sim.boss.is_empty(): actors.append({"p":sim.boss.p,"boss":true})
	actors.sort_custom(func(a,b):return a.p.y<b.p.y)
	for item in actors:
		if item.has("player"):
			effect_icon(11,sim.player+Vector2(0,3),34,Color(.6,1,1,.50))
			var frame=4 if sim.velocity.length()>1 and int(anim_clock*7)%2==1 else 0
			var tint=Color(1,1,1,0.45) if sim.invulnerable>0 and int(anim_clock*14)%2==0 else Color.WHITE
			sprite("player",art.PLAYER_RECTS[facing+frame],sim.player+Vector2(0,6),115,tint,0 if reduced or sim.velocity.length()<1 else sin(anim_clock*14)*1.2)
		elif item.has("boss"):
			sprite("boss",Rect2(45,20,900,980),sim.boss.p,174)
			if sim.boss.open<=0: effect_icon(11,sim.boss.p-Vector2(0,66),160,Color(.6,.85,1,.58))
		else:
			var e: Dictionary=item.enemy
			var row=1 if int(anim_clock*3+int(e.id))%2 else 0
			var size=[47.0,65.0,78.0][int(e.kind)]
			var tint=Color(1.7,1.4,1.1) if e.hit>0 else Color.WHITE
			sprite("enemies",Rect2(int(e.kind)*512,row*512,512,512),e.p+Vector2(0,10),size,tint,0 if reduced else sin(anim_clock*4+e.id)*1.8)
			if e.kind==2 and e.hp<e.max_hp:
				draw_line(e.p+Vector2(-17,-67),e.p+Vector2(17,-67),Color("253340"),4)
				draw_line(e.p+Vector2(-17,-67),e.p+Vector2(-17+34*e.hp/e.max_hp,-67),Color("ffc282"),3)
	for fx in effects:
		var alpha=clampf(float(fx.life)/float(fx.total),0,1)
		match fx.kind:
			"beam":
				draw_line(fx.p-Vector2(0,25),fx.to-Vector2(0,18),Color(.92,.97,.72,alpha),2,true)
				effect_icon(9,fx.to-Vector2(0,20),25,Color(1,1,1,alpha))
			"pop": effect_icon(9,fx.p-Vector2(0,15),(28+(1-alpha)*26)*float(fx.get("size",1)),Color(1,1,1,alpha))
			"loop":
				effect_icon(11,fx.p,70+(1-alpha)*90,Color(.8,1,1,alpha))
				if fx.count>0: draw_string(font,fx.p+Vector2(-44,-24-(1-alpha)*22),"%d 回収！"%fx.count,HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color(1,.96,.78,alpha))
			"unlock": effect_icon(9,fx.p,115,Color(.8,1,1,alpha))
			"hurt": effect_icon(9,fx.p-Vector2(0,40),80,Color(1,.5,.5,alpha))
	if pointer.x>=0 and sim.state=="running":
		effect_icon(11,pointer,25,Color(1,1,1,.45))
