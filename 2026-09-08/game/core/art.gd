class_name RescueArt
extends RefCounted

# Shared art direction only. Palettes and ornament never change collision/material physics.
const ROOMS: Array[String] = ["採光のアトリエ", "煉瓦の中庭", "青い収蔵庫", "夕暮れの展示室"]
const WORKS: Array[String] = ["朝露の一輪挿し", "波紋の壺", "琥珀の小瓶", "木の葉の壺", "藍の花器", "双子の白磁", "夜空の花器", "茜の二作品", "回廊の花器", "静寂の青磁", "運河の壺", "合流する白磁", "層の花器", "旅立ちの対器", "重なる青磁", "夜明けの二作品"]
const GLAZES: Array[Color] = [Color("cce3d5"),Color("c4dce5"),Color("dfae70"),Color("536d91"),Color("f2e8d4"),Color("9daf7c"),Color("647589"),Color("d19c87")]
const INKS: Array[Color] = [Color("31594f"),Color("375a73"),Color("735137"),Color("e4d6b2"),Color("777362"),Color("3d5947"),Color("e2c88f"),Color("713e3a")]

static func kind_for(stage: int, object_index: int = 0) -> int:
	var kinds: Array[int] = [0,1,2,5,3,4,6,7,3,0,1,4,6,7,1,7]
	return 4 if stage==5 else (kinds[clampi(stage,0,15)]+object_index)%8

static func room_for(stage: int) -> int:
	return clampi(stage / 4,0,3)

static func paper(room: int) -> Color:
	return [Color("eee6d6"),Color("e8dbcd"),Color("dce3e2"),Color("e8dcd7")][clampi(room,0,3)]

static func accent(room: int) -> Color:
	return [Color("957444"),Color("995e49"),Color("506b7d"),Color("845e65")][clampi(room,0,3)]

static func vase(c: CanvasItem, kind: int) -> void:
	var k: int = posmod(kind,8)
	var glaze: Color = GLAZES[k]
	var ink: Color = INKS[k]
	c.draw_circle(Vector2(3,4),19,Color(0.18,0.19,0.17,0.15))
	c.draw_circle(Vector2.ZERO,18,Color("394a48"))
	c.draw_circle(Vector2.ZERO,16.5,glaze)
	c.draw_rect(Rect2(-7,-23,14,12),Color("394a48"))
	c.draw_rect(Rect2(-5,-22,10,11),glaze)
	c.draw_line(Vector2(-8,-23),Vector2(8,-23),ink,2.5,true)
	c.draw_arc(Vector2(-2,-2),13,0.2,2.6,24,glaze.darkened(0.16),2,true)
	match [0,0,2,3,1,2,3,0][k]:
		0:
			for y: int in [-5,2,9]:
				c.draw_arc(Vector2(0,y-6),10,0.2,2.95,20,ink,1.3,true)
		1:
			for x: int in [-8,0,8]:
				c.draw_line(Vector2(x,-8),Vector2(x,10),ink,1.2,true)
			c.draw_line(Vector2(-13,2),Vector2(13,2),ink,1.2,true)
		2:
			c.draw_line(Vector2(-11,8),Vector2(9,-9),ink,1.5,true)
			for i: int in range(3):
				var p := Vector2(-6+i*5,4-i*4)
				c.draw_colored_polygon(PackedVector2Array([p,p+Vector2(-5,-6),p+Vector2(2,-3)]),ink)
		3:
			for i: int in range(6):
				var p: Vector2 = Vector2.from_angle(i*TAU/6)*9
				c.draw_circle(p,2,ink)
			c.draw_circle(Vector2.ZERO,3,ink)
	c.draw_line(Vector2(-8,-10),Vector2(-11,-2),Color(1,1,0.94,0.6),2,true)

static func arch(c: CanvasItem, rect: Rect2, fill: Color, edge: Color) -> void:
	var radius: float = rect.size.x/2
	var points := PackedVector2Array([rect.position+Vector2(0,rect.size.y),rect.end])
	for i: int in range(25):
		var a: float = -float(i)*PI/24
		points.append(rect.position+Vector2(radius,radius)+Vector2.from_angle(a)*radius)
	c.draw_colored_polygon(points,fill)
	points.append(points[0])
	c.draw_polyline(points,edge,2,true)

static func room(c: CanvasItem, theme_id: int) -> void:
	var base: Color = paper(theme_id)
	var line: Color = base.darkened(0.13)
	c.draw_rect(Rect2(22,35,916,568),Color("b9b09e"))
	c.draw_rect(Rect2(18,29,916,568),Color("f8f1e4"))
	c.draw_rect(Rect2(30,45,900,525),base)
	match theme_id:
		0:
			# Tall glazed windows and a raking patch of daylight in the rear wall.
			for x: int in [90,370,650]:
				var r := Rect2(x,74,210,358)
				arch(c,r,Color("e0e4d9"),line)
				c.draw_line(Vector2(x+105,82),Vector2(x+105,432),line,3)
				for y: int in [178,286]:
					c.draw_line(Vector2(x+5,y),Vector2(x+205,y),line,2)
			c.draw_colored_polygon(PackedVector2Array([Vector2(90,330),Vector2(295,330),Vector2(440,540),Vector2(170,540)]),Color(1,0.98,0.87,0.28))
		1:
			for row: int in range(13):
				var y: float = 50+row*39
				c.draw_line(Vector2(30,y),Vector2(930,y),line,1)
				for x: int in range(30+(row%2)*52,930,104):
					c.draw_line(Vector2(x,y),Vector2(x,y+39),line,1)
			for x: int in [130,600]:
				arch(c,Rect2(x,110,240,380),Color("d0d9cd"),Color("b8aea0"))
				arch(c,Rect2(x+14,125,212,365),Color("dce1d4"),line)
		2:
			c.draw_rect(Rect2(30,365,900,205),Color("cbd5d4"))
			for x: int in [95,365,635]:
				c.draw_rect(Rect2(x,85,215,240),Color("c5d1d2"))
				c.draw_rect(Rect2(x+8,93,199,224),Color("e3e6de"))
				c.draw_rect(Rect2(x+24,109,167,192),line,false,1)
				c.draw_line(Vector2(x+107,112),Vector2(x+107,290),Color("d0d8d5"),1)
			for x: int in range(55,931,52):
				c.draw_line(Vector2(x,390),Vector2(x,548),line,2)
		3:
			for x: int in [90,370,650]:
				arch(c,Rect2(x,74,210,388),Color("c7bac1"),line)
				arch(c,Rect2(x+10,85,190,377),Color("d8cad0"),line)
				c.draw_line(Vector2(x+105,95),Vector2(x+105,458),line,2)
				c.draw_line(Vector2(x+12,270),Vector2(x+198,270),line,2)
			c.draw_circle(Vector2(760,158),38,Color("ecdcb5"))
	# Architectural backdrop is deliberately softer than collision-bearing foreground.
	c.draw_line(Vector2(30,548),Vector2(930,548),line,2)
	c.draw_line(Vector2(30,554),Vector2(930,554),Color("f6f1e5"),2)
	for x: int in range(48,924,20):
		c.draw_line(Vector2(x,584),Vector2(x,590 if x%100==48 else 587),Color("a79e88"),1)
	c.draw_rect(Rect2(30,45,900,525),line,false,1)
