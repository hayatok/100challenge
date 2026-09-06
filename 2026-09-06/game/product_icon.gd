extends Control
var product={}
const INK=Color("20283f")
const PAPER=Color("f7e6bc")
const RED=Color("d65b54")
const GOLD=Color("e7ab53")
const BROWN=Color("b77843")
const GREEN=Color("378c78")
const BLUE=Color("67a9bb")
const DARK=Color("70463f")
func _ready():
	custom_minimum_size=Vector2(42,42);mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func p(x:int,y:int,w:int,h:int,c:Color):draw_rect(Rect2(x,y,w,h),c)
func pack(c:Color):
	p(3,3,14,15,INK);p(4,4,12,13,c);p(4,3,12,2,PAPER);p(4,15,12,2,PAPER)
func cup(c:Color):
	p(3,5,14,3,INK);p(4,8,12,8,INK);p(6,16,8,2,INK);p(5,8,10,7,c);p(6,15,8,1,c);p(2,4,16,4,INK);p(3,5,14,2,PAPER)
func bottle(c:Color):
	p(7,1,6,3,INK);p(6,4,8,2,c);p(4,6,12,12,INK);p(5,6,10,11,c);p(5,10,10,5,PAPER);p(8,11,4,3,c);p(6,7,2,2,PAPER)
func bun(c:Color):
	p(3,8,14,7,INK);p(4,6,12,9,INK);p(6,4,8,3,INK);p(5,7,10,7,c);p(4,9,12,4,c);p(7,5,6,3,c);p(8,6,4,1,PAPER);p(6,14,8,1,BROWN)
func book(c:Color):
	p(3,3,14,15,INK);p(4,4,12,13,PAPER);p(4,4,3,13,c)
	for i in 4:p(9,6+i*3,5,1,c)
func _draw():
	if product.is_empty():return
	draw_set_transform(Vector2(1,1),0,Vector2.ONE*2)
	var v=int(product.id)%10
	match int(product.cat):
		0:
			if v in [0,1,2,4,7]:
				for i in 6:p(8-i,3+i*2,4+i*2,2,INK)
				for i in 5:p(8-i,5+i*2,4+i*2,2,BROWN if v==7 else PAPER)
				p(7,10,5,5,GREEN);p(9,6,2,2,RED if v in [1,2] else (GOLD if v==4 else PAPER))
			elif v==5:
				p(3,4,14,13,INK);p(4,5,12,11,PAPER);p(5,7,10,2,GOLD);p(5,11,10,2,GOLD);p(13,5,2,11,BROWN)
			else:
				p(1,5,18,12,INK);p(2,6,16,9,PAPER);p(10,7,6,6,BROWN);p(4,9,3,3,RED);p(12,7,3,2,GREEN)
				if v==8:p(11,8,2,2,GOLD);p(14,11,2,2,RED)
				if v==9:p(1,15,18,2,RED)
		1:
			if v in [3,7]:
				p(0,8,20,7,INK);p(1,7,18,7,BROWN);p(2,8,16,2,GOLD)
				for i in 4:p(3+i*4,9,2,3,PAPER)
			elif v==5:
				bun(BROWN);p(8,8,5,4,INK);p(9,8,3,3,PAPER);p(5,7,2,2,GOLD)
			elif v==8:
				p(4,3,12,15,INK);p(2,4,16,6,INK);p(3,4,14,5,BROWN);p(5,5,10,11,PAPER);p(5,16,10,1,BROWN)
			elif v in [1,9]:
				p(2,8,16,6,INK);p(3,6,14,7,BROWN);p(6,4,8,8,GOLD);p(7,12,6,3,PAPER);p(1,12,4,2,BROWN);p(15,12,4,2,BROWN)
			else:
				bun(Color("77679d") if v==6 else GOLD)
				if v==4:
					for i in 3:p(5+i*4,6,1,7,BROWN);p(5,7+i*3,10,1,BROWN)
				elif v==0:p(8,6,4,2,DARK)
				else:p(6,7,2,4,PAPER);p(11,7,2,4,PAPER)
		2:
			if v in [1,4,7]:
				cup(GREEN if v==7 else (GOLD if v==4 else DARK));p(7,9,6,4,PAPER);p(9,9,2,3,GREEN if v==7 else DARK)
			elif v in [3,8]:
				p(5,3,10,15,INK);p(6,5,8,12,PAPER);p(7,1,6,3,INK);p(8,2,4,3,PAPER);p(5,9,10,5,BLUE if v==8 else BROWN);p(8,10,4,3,PAPER)
			elif v==6:
				p(5,3,10,15,INK);p(6,4,8,13,DARK);p(6,4,8,2,PAPER);p(7,8,6,5,GOLD);p(7,15,6,1,PAPER)
			else:bottle([GREEN,GREEN,BLUE,GOLD,GOLD,BLUE,DARK,GREEN,PAPER,RED][v])
		3:
			if v in [2,3]:
				pack(DARK);p(4,12,12,5,RED if v==3 else GOLD)
				for x in 3:
					for y in 2:p(5+x*4,5+y*3,3,2,BROWN)
			elif v in [8,9]:
				p(2,5,16,12,INK);p(3,6,14,10,RED if v==9 else GOLD);p(9,6,2,10,PAPER);p(3,10,14,2,PAPER)
				if v==9:p(5,3,4,3,RED);p(11,3,4,3,RED)
			else:
				pack([GOLD,RED,DARK,DARK,PAPER,GREEN,RED,BLUE][v])
				for i in 3:p(6+i*3,8+(i%2)*3,3,3,BROWN if v in [0,1,4,6] else (PAPER if v==5 else RED))
		4:
			if v==1:
				p(8,13,4,6,DARK);p(9,13,2,5,BROWN);p(4,3,12,12,INK);p(6,1,8,3,INK);p(5,4,10,10,PAPER);p(7,2,6,3,PAPER);p(6,5,2,6,BLUE)
			elif v==2:
				p(3,5,14,12,INK);p(4,6,12,10,PAPER);p(6,7,9,8,GOLD);p(7,8,7,6,PAPER);p(9,9,4,4,RED);p(3,15,14,2,GOLD)
			elif v==7:
				p(2,13,16,4,BROWN);p(3,11,14,4,GOLD);p(5,8,10,5,Color("77679d"));p(7,6,6,3,PAPER)
			elif v==9:
				p(5,10,10,8,INK);p(6,10,8,7,BLUE);p(4,7,12,5,INK);p(6,4,8,5,INK);p(5,8,10,3,PAPER);p(7,5,6,4,PAPER);p(8,2,4,3,RED);p(7,12,6,2,RED);p(7,15,6,1,GOLD)
			else:
				cup(GREEN if v==4 else (PAPER if v==5 else (DARK if v==8 else GOLD)));p(4,7,12,2,DARK if v in [0,3,8] else PAPER)
				if v==6:p(7,11,2,2,RED);p(9,10,2,2,RED);p(11,8,2,3,RED)
				if v==3:p(6,2,2,3,GOLD);p(9,1,2,4,GOLD);p(12,2,2,3,GOLD)
		5:
			if v in [2,3,5]:
				p(1,5,18,12,INK);p(2,6,16,10,BLUE if v==5 else (RED if v==3 else GOLD));p(3,8,14,6,PAPER)
				for i in 4:p(4+i*3,9,2,4,BROWN)
			else:
				cup(GREEN if v==4 else (BLUE if v==9 else (RED if v==6 else GOLD)));p(6,9,8,4,PAPER);p(8,10,4,2,RED)
				if v in [1,6]:p(8,1,2,3,RED);p(11,2,2,2,GOLD)
		6:
			if v in [0,5,7]:
				bun(PAPER);p(9,5,2,3,RED if v==5 else BROWN)
				if v==7:p(4,1,1,3,PAPER);p(14,1,1,3,PAPER)
			elif v==4:
				p(5,4,9,13,INK);p(4,6,11,9,Color("77679d"));p(7,4,6,5,GOLD);p(7,13,3,3,PAPER)
			elif v in [6,9]:
				cup(GREEN if v==9 else BROWN);p(4,5,12,3,GOLD);p(5,6,4,2,PAPER);p(11,5,3,3,BROWN)
			else:
				p(8,12,3,7,BROWN);p(5,4,10,10,INK);p(4,6,12,5,INK);p(5,6,10,5,GOLD);p(7,4,6,9,GOLD);p(7,6,2,2,PAPER)
				if v==3:p(14,1,1,8,INK);p(15,1,4,3,RED)
				if v==8:p(5,9,10,2,PAPER)
		7:
			match v:
					3:
						for i in 4:p(8-i*2,3+i*2,4+i*4,2,RED)
						p(9,9,2,8,INK);p(7,17,4,2,INK);p(8,4,1,5,PAPER)
					1:
						p(2,7,16,10,INK);p(3,8,14,8,BLUE);p(6,5,8,7,PAPER);p(7,4,6,2,PAPER);p(5,13,10,2,PAPER)
					5:
						p(3,3,14,15,INK);p(4,4,12,13,PAPER);p(8,7,4,8,RED);p(6,9,8,4,RED)
					6:
						p(8,2,5,16,INK);p(9,3,3,12,BLUE);p(9,15,2,3,GOLD);p(12,3,2,6,INK)
					7:
						for x in [3,11]:p(x,4,6,14,INK);p(x+1,5,4,12,RED);p(x+2,2,2,2,INK);p(x+1,6,4,3,GOLD);p(x+2,6,2,3,PAPER)
					_:
						book([INK,GREEN,GREEN,RED,RED,RED,BLUE,RED,GREEN,Color("77679d")][v])
						if v in [4,8,9]:p(8,7,6,6,GOLD if v==4 else BLUE);p(9,8,4,4,PAPER)
	draw_set_transform(Vector2.ZERO)
