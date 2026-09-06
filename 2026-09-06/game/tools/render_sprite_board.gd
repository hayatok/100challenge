extends SceneTree
const People=preload("res://pixel_people.gd")
func _init():
	var board=Image.create(240,216,false,Image.FORMAT_RGBA8);board.fill(Color("596070"))
	for identity in 12:
		for direction in 4:
			board.blit_rect(People.make_image(identity,direction),Rect2i(0,0,16,24),Vector2i(identity*20+2,direction*24))
		for frame in 3:
			board.blit_rect(People.make_image(identity,1,frame),Rect2i(0,0,16,24),Vector2i(identity*20+2,(frame+4)*24))
		board.blit_rect(People.make_image(identity,1,0,false,"browse"),Rect2i(0,0,16,24),Vector2i(identity*20+2,7*24))
		board.blit_rect(People.make_image(identity,1,0,false,"joy"),Rect2i(0,0,16,24),Vector2i(identity*20+2,8*24))
	board.save_png("res://../art/beta/sprite-board-native.png")
	print("Exported authored sprite board at 240x216, native 16x24 characters")
	quit()
