extends Control
var host: Node3D
const CYAN = Color("66e4e0")
func point(p: Vector2, height: float = 0.08) -> Vector2:
	return host.camera.unproject_position(Vector3(p.x, height, p.y))
func _draw() -> void:
	if host == null or host.sim.state == "ready":
		return
	var s = host.sim
	for r in s.regions:
		var poly = PackedVector2Array()
		for p in r.poly:
			poly.append(point(p))
		var alpha = minf(1.0, r.life / 1.5)
		draw_colored_polygon(poly, Color(0.20,0.8,0.75,0.12*alpha))
		poly.append(poly[0])
		draw_polyline(poly, Color(.4,.85,.75,.55*alpha), 2.0, true)
		draw_arc(point(r.center), 11, -PI/2, -PI/2+TAU*minf(r.life/8.0,1.0),24,Color(.81,.86,.46,.8),3,true)
	for p in s.pickups:
		var at = point(p.p,0.25)
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(3,0),at+Vector2(0,4),at+Vector2(-3,0)]),Color("fbd783"))
	for i in range(1,s.trail.size()):
		var remaining = s.trail_life() - (s.clock - s.trail[i-1].t)
		var alpha = clampf(remaining / 1.2, 0.15, 1.0)
		var a = point(s.trail[i-1].p)
		var b = point(s.trail[i].p)
		draw_line(a,b,Color(.04,.12,.17,alpha),8,true)
		draw_line(a,b,Color(.4,.9,.88,alpha),4,true)
	if not s.trail.is_empty():
		draw_arc(point(s.trail[0].p),6,0,TAU,16,CYAN,2,true)
	var pp = point(s.player)
	draw_arc(pp,15,0,TAU,24,Color("fff0cd"),2,true)
	# A return hint is deliberately temporary and disappears after the first successful loop.
	if s.clock < 10.0 and s.loops == 0:
		var guide = [Vector2.ZERO,Vector2(-5,0),Vector2(-5,-4),Vector2(3,-4),Vector2(3,2),Vector2(-2,2),Vector2(-2,-1)]
		for i in range(guide.size()-1):
			var a = point(guide[i]); var b = point(guide[i+1])
			for j in range(0,10,2):
				draw_line(a.lerp(b,j/10.0),a.lerp(b,(j+1)/10.0),Color(1,.94,.8,.28),2,true)
	for fx in s.effects:
		var alpha = fx.life / fx.max_life
		var at = point(fx.p,0.4)
		match fx.kind:
			"shot", "stage_shot":
				draw_line(at,point(fx.to,0.4),Color(1,.85,.5,alpha),2,true)
			"loop":
				draw_arc(at,20+(1-alpha)*65,0,TAU,36,Color(.4,1,.9,alpha),3,true)
				if fx.count > 0:
					draw_string(host.ui_font,at+Vector2(-20,-22-(1-alpha)*20),"+%d"%fx.count,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color(1,.94,.8,alpha))
			"pop":
				if not host.reduced:
					for j in 4:
						var v = Vector2.from_angle(j*TAU/4+.4)*(5+(1-alpha)*16)
						draw_line(at+v,at+v*1.4,Color(1,.66,.4,alpha),2,true)
			"hurt":
				draw_arc(at,24,0,TAU,24,Color(1,.4,.5,alpha),3,true)
