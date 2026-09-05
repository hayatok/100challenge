extends Control
var look=0
var tint=Color.WHITE
var atlas:Texture2D
func _ready():
	custom_minimum_size=Vector2(60,82);mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	atlas=load("res://assets/images/neighbors.png")
	var shader=Shader.new();shader.code="shader_type canvas_item; varying vec4 tint_color; void vertex(){tint_color=COLOR;} void fragment(){vec4 t=texture(TEXTURE,UV);if(t.r>0.72&&t.b>0.65&&t.g<0.22)t.a=0.0;COLOR=t*tint_color;}"
	var mat=ShaderMaterial.new();mat.shader=shader;material=mat
func _draw():
	if atlas:draw_texture_rect_region(atlas,Rect2(0,0,60,82),Rect2(1306,26+look*237,157,215),tint)
