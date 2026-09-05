extends Control
var product={}
const INK=Color("344a43")
func _ready():
	custom_minimum_size=Vector2(42,42);mouse_filter=Control.MOUSE_FILTER_IGNORE
func pixel(x:float,y:float,w:float,h:float,c:Color):draw_rect(Rect2(x,y,w,h),c)
func _draw():
	if product.is_empty():return
	draw_set_transform(Vector2(2,2),0,Vector2.ONE*2)
	var c=Color(product.color);var v=product.id%10
	var cream=Color("fff4d1");var red=Color("c76550")
	match product.cat:
		0:
			if v%3==0:
				for i in 6:pixel(8-i,3+i*2,4+i*2,2,INK)
				for i in 5:pixel(8-i,5+i*2,4+i*2,2,cream)
				pixel(7,10,5,5,Color("3e6850"))
			else:
				pixel(1,5,18,12,INK);pixel(2,6,16,9,cream);pixel(10,7,6,6,c);pixel(4,9,3,3,red);pixel(12,7,3,2,Color("7ba06e"))
		1:
			pixel(2,7,16,8,INK);pixel(3,5,14,10,c);pixel(5,4,10,2,c.lightened(0.2))
			for i in 3:pixel(5+i*4,7,2,5,cream)
			if product.size==2:pixel(0,9,20,4,c.lightened(0.2))
		2:
			pixel(7,1,6,3,INK);pixel(6,4,8,2,c);pixel(4,6,12,12,INK);pixel(5,6,10,11,c);pixel(5,10,10,5,cream);pixel(8,11,4,3,c.darkened(0.2));pixel(6,7,2,2,Color.WHITE)
		3:
			pixel(3,3,14,15,INK);pixel(4,4,12,13,c);pixel(4,3,12,2,cream);pixel(4,15,12,2,cream);pixel(7,8,6,5,c.darkened(0.3));pixel(9,7,3,2,cream)
		4:
			pixel(4,6,12,3,INK);pixel(3,9,14,8,INK);pixel(4,9,12,7,Color("edce83"));pixel(5,8,10,3,Color("ae7052"));pixel(5,14,10,2,c);pixel(8,4,4,3,cream);pixel(9,3,2,2,red)
		5:
			pixel(3,4,14,3,INK);pixel(4,7,12,9,INK);pixel(5,7,10,8,c);pixel(6,15,8,2,INK);pixel(2,4,16,2,cream);pixel(6,9,8,3,cream);pixel(7,10,5,1,red)
		6:
			if v%3==0:
				pixel(3,8,14,7,INK);pixel(4,6,12,9,cream);pixel(6,4,8,3,cream);pixel(9,5,2,3,c);pixel(6,14,8,2,c)
			else:
				pixel(8,12,3,7,Color("b28b5a"));pixel(5,4,10,10,INK);pixel(4,6,12,5,INK);pixel(5,6,10,5,c);pixel(7,4,6,9,c);pixel(7,6,2,2,cream)
		7:
			if v==3:
				for i in 4:pixel(8-i*2,3+i*2,4+i*4,2,c)
				pixel(9,9,2,8,INK);pixel(7,17,4,2,INK)
			else:
				pixel(3,3,14,15,INK);pixel(4,4,12,13,cream);pixel(4,4,3,13,c)
				for i in 4:pixel(9,6+i*3,5,1,c.darkened(0.3))
	draw_set_transform(Vector2.ZERO)
