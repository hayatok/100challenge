extends SceneTree
const People=preload("res://pixel_people.gd")
const Props=preload("res://pixel_props.gd")
func _init():
	var cases=[["browse","",0,false],["wait","basket",0,false],["carry","basket",0,false],["joy","bag",0,false],["carry","bag_long",0,false],["carry","bag",2,false],["surprised","basket",1,false],["carry","box",0,true]]
	var board=Image.create(320,192,false,Image.FORMAT_RGBA8);board.fill(Color("596070"))
	for direction in 4:
		for i in cases.size():
			var item=cases[i];var pos=Vector2i(i*40+4,direction*48+4)
			var body=People.make_image(i,direction,0,item[3],item[0]);var props=Props.make_image(item[1],item[2],i,direction)
			if direction in [2,3]:board.blend_rect(props,Rect2i(0,0,32,40),pos)
			board.blend_rect(body,Rect2i(0,0,16,24),pos+Vector2i(8,16))
			if direction in [0,1]:board.blend_rect(props,Rect2i(0,0,32,40),pos)
	board.save_png("res://../art/beta/life-board-native.png")
	print("Life board: 8 actual poses/props x 4 directions, native pixels")
	quit()
