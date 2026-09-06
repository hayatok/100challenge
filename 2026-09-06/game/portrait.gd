extends Control
const People=preload("res://pixel_people.gd")
var identity=0
func _ready():
	custom_minimum_size=Vector2(64,80);mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _draw():
	draw_rect(Rect2(0,0,64,80),Color("9bc59d"))
	draw_rect(Rect2(3,3,58,74),Color("f7e6bc"))
	draw_texture_rect(People.texture(identity,1,0,false,"idle"),Rect2(8,5,48,72),false)
