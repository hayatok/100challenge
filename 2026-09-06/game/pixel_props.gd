extends RefCounted
const People=preload("res://pixel_people.gd")
static var cache={}
static func rect(img:Image,x:int,y:int,w:int,h:int,index:int):
	img.fill_rect(Rect2i(x,y,w,h),Color(People.COLORS[index]))
static func texture(kind:String,umbrella:int,identity:int,direction:int) -> Texture2D:
	var key="%s:%d:%d:%d"%[kind,umbrella,identity%4,direction]
	if not cache.has(key):cache[key]=ImageTexture.create_from_image(make_image(kind,umbrella,identity,direction))
	return cache[key]
static func make_image(kind:String,umbrella:int,identity:int,direction:int) -> Image:
	# Body occupies (8,16)..(24,40); feet sit at (16,38).
	var img=Image.create(32,40,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
	if kind.begins_with("basket"):
		rect(img,12,27,12,7,0);rect(img,13,28,10,5,10);rect(img,12,27,12,1,5)
		for x in [14,17,20]:rect(img,x,29,1,3,11)
		rect(img,15,24,6,1,0);rect(img,14,25,1,3,0);rect(img,21,25,1,3,0)
	if kind.begins_with("bag"):
		rect(img,20,28,4,2,0);rect(img,20,29,1,3,5);rect(img,23,29,1,3,5)
		rect(img,18,31,8,7,0);rect(img,19,31,6,6,5);rect(img,19,35,6,1,24);rect(img,22,32,2,2,8)
	if kind.ends_with("long"):
		# A loaf sticks out of the actual basket/bag; it is never conjured from a name.
		rect(img,22,14,3,18,0);rect(img,23,13,1,19,12);rect(img,22,16,1,15,13)
		for y in [17,21,25,29]:rect(img,23,y,2,1,5)
	if kind=="box":
		rect(img,11,27,14,8,0);rect(img,12,28,12,6,13);rect(img,12,28,12,1,12)
		rect(img,17,28,2,6,5);rect(img,20,31,3,2,24)
	if umbrella==1:
		rect(img,26,26,1,12,0);rect(img,25,27,3,8,[18,10,20,22][identity%4]);rect(img,26,26,1,2,5)
	elif umbrella==2:
		rect(img,21,11,1,19,0);rect(img,20,29,2,1,0)
		var color=[18,10,20,22][identity%4]
		for tier in 6:
			var width=[6,14,22,26,28,30][tier];var x=16-width/2
			rect(img,x,3+tier*2,width,2,0)
			if tier>0:rect(img,x+1,3+tier*2,width-2,2,color)
		rect(img,15,3,2,10,5);rect(img,5,13,4,1,0);rect(img,23,13,4,1,0)
	if direction in [0,2]:img.flip_x()
	return img
