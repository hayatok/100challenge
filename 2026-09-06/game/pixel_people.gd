extends RefCounted
# Native 16x24 sprites. Each glyph below is one pixel, not a scaled illustration.
# Body, face, clothing and props share a palette and feet at row 22.
const COLORS=["20283f","394357","596070","858991","b9b9ad","f7e6bc","ffffff","9bc59d","378c78","235b58","d65b54","9a414e","e7ab53","b77843","70463f","eec89d","c99379","976453","67a9bb","3f6b92","77679d","b99cc5","7a9859","506743","dfd2ad","798a87","a5c8bf","303749"]
const FRONT=[
"................",
"......HHHH......",
"....HHhhhhHH....",
"...HhhhhhhhhH...",
"...HhhhhhhhhH...",
"...HhHHhHHhhH...",
"...HSSSSSSShH...",
"...HSSSSSSSSH...",
"....SISSSISS....",
"....SSSSSSSS....",
".....StttSS.....",
"....ICCCCI......",
"...IcCCCCccI....",
"...IcCCCCccSI...",
"...ISCCCCccSI...",
"...ISCCCCccSI...",
"....IcCCCCcI....",
"....IcCCCCcI....",
".....IPPPPI.....",
".....IPPPPI.....",
".....IP.I PI....",
".....IP..IPI....",
".....II..III....",
"................"]
const BACK=[
"................",
"......HHHH......",
"....HHhhhhHH....",
"...HhhhhhhhhH...",
"...HhhhhhhhhH...",
"...HhhhhhhhhH...",
"...HhhhhhhhhH...",
"...HhhhhhhhhH...",
"....HhhhhhhH....",
"....HHhhhhHH....",
".....HtttHH.....",
"....ICCCCI......",
"...IcCCCCccI....",
"...IcCCCCccSI...",
"...ISCCCCccSI...",
"...ISCCCCccSI...",
"....IcCCCCcI....",
"....IcCCCCcI....",
".....IPPPPI.....",
".....IPPPPI.....",
".....IP.I PI....",
".....IP..IPI....",
".....II..III....",
"................"]
# Every lead resident has authored hair/clothing/prop identity, also used by portraits.
const LOOKS=[
[14,13,10,11,1,0], # Minori: chestnut bob, coral cardigan, shoulder bag
[0,1,18,19,1,1],  # Makoto: dark spiky hair, blue school jacket, backpack
[14,13,20,1,1,2], # Nagi: auburn hair, purple knit, book
[0,1,12,13,1,3],  # Suzu: cap and delivery jacket
[3,4,22,23,14,4], # Fumio: silver hair, green vest, newspaper
[0,1,7,8,19,5],   # Riku: scrub top, neck towel
[14,13,20,21,1,6],# Tsumugi: tied hair, glasses, laptop bag
[0,1,10,11,1,7],  # Aki: beanie, red jacket, strap
[14,13,21,20,11,8],# Momo: twin buns, pink coat
[0,1,19,1,1,9],   # Sota: navy suit and coral tie
[14,13,12,13,19,10],# Sakura: yellow coat, red handbag
[0,1,5,4,1,11]]   # Jun: chef bandana, white jacket
static var cache={}
static func rect(img:Image,x:int,y:int,w:int,h:int,c:Color):
	for yy in range(maxi(0,y),mini(24,y+h)):
		for xx in range(maxi(0,x),mini(16,x+w)):img.set_pixel(xx,yy,c)
static func texture(identity:int,direction:int=1,frame:int=0,staff:bool=false,pose:String="idle") -> Texture2D:
	var key=str(identity)+":"+str(direction)+":"+str(frame)+":"+str(staff)+":"+pose
	if cache.has(key):return cache[key]
	var img=make_image(identity,direction,frame,staff,pose)
	var tex=ImageTexture.create_from_image(img);cache[key]=tex;return tex
static func make_image(identity:int,direction:int=1,frame:int=0,staff:bool=false,pose:String="idle") -> Image:
	var look=LOOKS[posmod(identity,12)].duplicate()
	if identity>=12 and not staff:
		look[2]=[8,10,12,18,20,22][(identity/12)%6]
		look[3]=[9,11,13,19,1,23][(identity/12)%6]
	if staff:look[2]=8;look[3]=9
	var ink=Color(COLORS[0]);var skin=Color(COLORS[15 if identity%4!=3 else 16])
	var colors={"I":ink,"H":Color(COLORS[look[0]]),"h":Color(COLORS[look[1]]),"S":skin,"t":Color(COLORS[16]),"C":Color(COLORS[look[2]]),"c":Color(COLORS[look[3]]),"P":Color(COLORS[look[4]])}
	var img=Image.create(16,24,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
	var back=direction in [2,3];var rows=BACK if back else FRONT
	for y in 24:
		for x in mini(rows[y].length(),16):
			var glyph=rows[y][x]
			if colors.has(glyph):img.set_pixel(x,y,colors[glyph])
	var prop=int(look[5]);var hair=colors.h
	match prop:
		0:rect(img,3,6,2,6,colors.H);rect(img,11,6,2,6,colors.H);rect(img,11,15,3,5,Color(COLORS[13]));rect(img,12,12,1,4,ink)
		1:rect(img,5,0,2,3,colors.H);rect(img,9,0,2,3,colors.H);rect(img,10,13,4,6,Color(COLORS[19]));rect(img,11,14,2,1,Color(COLORS[5]))
		2:rect(img,4,11,8,2,Color(COLORS[5]));rect(img,11,15,3,5,ink);rect(img,12,15,2,4,Color(COLORS[5]))
		3:rect(img,4,1,8,4,Color(COLORS[19]));rect(img,6,4,9,1,ink);rect(img,6,12,2,4,Color(COLORS[5]))
		4:
			rect(img,5,2,7,2,Color(COLORS[4]));rect(img,5,7,6,2,Color(COLORS[5]));rect(img,5,8,2,1,ink);rect(img,9,8,2,1,ink)
			rect(img,11,15,3,6,Color(COLORS[5]));rect(img,12,16,2,1,Color(COLORS[3]));rect(img,12,18,2,1,Color(COLORS[3]))
		5:rect(img,5,11,2,5,Color(COLORS[5]));rect(img,9,11,2,3,Color(COLORS[5]))
		6:
			rect(img,2,3,3,5,hair);rect(img,5,7,6,1,ink);rect(img,5,8,2,1,ink);rect(img,9,8,2,1,ink);rect(img,11,16,4,4,Color(COLORS[14]))
		7:rect(img,4,1,8,4,Color(COLORS[11]));rect(img,3,4,10,2,Color(COLORS[10]));rect(img,10,11,1,8,Color(COLORS[12]))
		8:rect(img,2,2,3,4,colors.H);rect(img,11,2,3,4,colors.H);rect(img,3,3,2,1,Color(COLORS[10]));rect(img,11,3,2,1,Color(COLORS[10]))
		9:rect(img,6,11,4,2,Color(COLORS[5]));rect(img,8,12,1,5,Color(COLORS[10]));rect(img,12,16,3,4,Color(COLORS[14]))
		10:rect(img,7,12,1,6,ink);rect(img,11,15,4,5,Color(COLORS[10]))
		11:rect(img,4,3,8,2,Color(COLORS[5]));rect(img,5,4,1,3,Color(COLORS[5]));rect(img,7,13,1,1,ink);rect(img,7,16,1,1,ink)
	if staff:
		rect(img,5,12,6,6,Color(COLORS[8]));rect(img,5,12,6,1,Color(COLORS[5]));rect(img,9,14,2,1,Color(COLORS[5]));rect(img,7,16,2,1,Color(COLORS[9]))
	if back:
		# Head and nape cover face-specific props; back silhouettes retain hair and hats.
		if prop not in [3,7,11]:rect(img,5,6,6,4,colors.H);rect(img,6,6,4,2,hair)
		if prop==1:rect(img,5,13,6,6,Color(COLORS[19]));rect(img,6,14,4,1,Color(COLORS[18]))
	else:
		rect(img,5,8,1,1,ink);rect(img,9,8,1,1,ink)
		if pose=="joy":rect(img,5,8,2,1,ink);rect(img,9,8,2,1,ink);rect(img,7,10,2,1,Color(COLORS[11]))
	if frame>0:
		# Alternate feet on their own rows; no squashing or interpolation of artwork.
		rect(img,4,20,8,4,Color.TRANSPARENT)
		var left=1 if frame==1 else 0;var right=1-left
		rect(img,5,19,2,2+left,colors.P);rect(img,8,19,2,2+right,colors.P)
		rect(img,4,21+left,3,1,ink);rect(img,8,21+right,3,1,ink)
	if pose=="browse" and not back:rect(img,12,11,2,2,skin);rect(img,12,13,2,2,colors.C)
	if pose=="joy":rect(img,1,11,2,3,skin);rect(img,2,14,2,2,colors.C)
	if pose in ["carry","wait","surprised"]:
		rect(img,3,14,2,3,Color.TRANSPARENT);rect(img,12,14,2,3,Color.TRANSPARENT)
		rect(img,3,12,2,2,colors.C);rect(img,12,12,2,2,colors.C)
		if pose=="carry":rect(img,4,13,2,2,skin);rect(img,12,13,2,2,skin)
		elif pose=="wait":
			rect(img,4,14,7,2,colors.C);rect(img,8,14,3,1,skin);rect(img,7,14,1,1,Color(COLORS[12]))
		else:
			rect(img,11,10,2,2,skin);rect(img,12,12,2,2,colors.C)
			if not back:rect(img,5,7,2,1,ink);rect(img,9,7,2,1,ink);rect(img,7,10,2,2,ink)
	if direction in [0,2]:img.flip_x()
	return img
