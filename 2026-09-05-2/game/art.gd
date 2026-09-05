extends RefCounted
## All painted imagery is ImageGen. Source PNGs remain unmodified.
## Atlas regions and chroma removal are normal Godot runtime presentation.
const FILES = {"arena":"amedori.png","player":"kohaku-walk.png","enemies":"echoes.png","boss":"boss-kit.png","fx":"effects.png","hero":"key-art.png"}
const PLAYER_RECTS = [
	Rect2(180,20,205,478),Rect2(535,20,195,478),Rect2(810,20,232,478),Rect2(1150,20,230,478),
	Rect2(178,517,210,484),Rect2(535,517,195,484),Rect2(810,517,232,484),Rect2(1150,517,230,484)
]
var textures: Dictionary = {}
var key_material: ShaderMaterial

func _init() -> void:
	for key in FILES:
		var path="res://assets/images/"+FILES[key]
		if ResourceLoader.exists(path): textures[key]=load(path)
	var shader=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){ float spill=min(COLOR.r,COLOR.b)-COLOR.g; COLOR.a*=1.0-smoothstep(0.035,0.22,spill); }"
	key_material=ShaderMaterial.new()
	key_material.shader=shader

func atlas(key: String, region: Rect2) -> AtlasTexture:
	var result=AtlasTexture.new()
	result.atlas=textures.get(key)
	result.region=region
	result.filter_clip=true
	return result

func icon(index: int) -> AtlasTexture:
	return atlas("fx",Rect2((index%4)*384,(index/4)*341,384,341))
