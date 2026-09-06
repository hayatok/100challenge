extends Control
# World pixels and interface text have separate rendering resolutions.
const Scene=preload("res://store_scene.gd")
signal picked(kind:String,id:int)
signal placed(cell:Vector2i)
signal hovered(cell:Vector2i)
var sim
var selected_kind=""
var selected_id=-1
var build_kind=-1
var build_dir=0
var move_id=-1
var reduced=false
var interp=0.0
var zoom=1.0
var world:Control
var viewport:SubViewport
var output:TextureRect
var pixel_scale=2
var output_origin=Vector2.ZERO
var font:Font
var previous_size=Vector2.ZERO
var previous_zoom=0.0
func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
	font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	viewport=SubViewport.new();viewport.disable_3d=true;viewport.transparent_bg=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	world=Scene.new();world.sim=sim;viewport.add_child(world)
	output=TextureRect.new();output.texture=viewport.get_texture();output.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	output.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;output.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(output)
	# Draw overlay text after the world texture.
	var overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	overlay.draw.connect(draw_labels.bind(overlay))
	world.picked.connect(func(k,id):picked.emit(k,id));world.placed.connect(func(c):placed.emit(c));world.hovered.connect(func(c):hovered.emit(c))
	resized.connect(configure)
	configure()
func configure():
	if viewport==null:return
	var base=2 if size.x>=900 else 1
	pixel_scale=clampi(roundi(base*zoom),1,4)
	var dimensions=Vector2i(maxi(1,floori(size.x/pixel_scale)),maxi(1,floori(size.y/pixel_scale)))
	viewport.size=dimensions;world.size=Vector2(dimensions)
	output.size=Vector2(dimensions)*pixel_scale;output_origin=((size-output.size)/2).floor();output.position=output_origin
	previous_size=size;previous_zoom=zoom
func _process(_delta):
	if world==null:return
	if previous_size!=size or previous_zoom!=zoom:configure()
	for key in ["sim","selected_kind","selected_id","build_kind","build_dir","move_id","reduced","interp"]:world.set(key,get(key))
	get_child(get_child_count()-1).queue_redraw()
func reset_camera():
	zoom=1.0
	if world!=null:world.reset_camera()
	configure()
func zoom_step(direction:int):
	var base=2 if size.x>=900 else 1
	zoom=clampf(float(pixel_scale+direction)/base,1.0/base,4.0/base);configure()
func _gui_input(event):
	if world==null:return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_step(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1);accept_event();return
	var mapped=event.duplicate()
	if mapped is InputEventMouse:
		mapped.position=(event.position-output_origin)/pixel_scale
		mapped.global_position=mapped.position
	if mapped is InputEventMouseMotion:mapped.relative=event.relative/pixel_scale
	world._gui_input(mapped);accept_event()
func draw_labels(canvas:Control):
	if world==null:return
	var ordered=world.labels.duplicate()
	ordered.sort_custom(func(a,b):return a.get("priority",0)>b.get("priority",0))
	var occupied=[]
	for item in ordered:
		var point=(output_origin+item.at*pixel_scale).round()
		var fs=maxi(10,roundi(item.size*pixel_scale*0.5))
		if item.get("caption",false):fs=11
		var width=font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		if item.get("bubble",false):
			point.x=clampf(point.x,4,maxf(4,size.x-width-12))
			var anchor=point
			var frame=Rect2()
			for offset in [0,-1,1,-2,2]:
				var proposed=point+Vector2(0,offset*(fs+12))
				var bounds=Rect2(proposed-Vector2(4,fs+2),Vector2(width+8,fs+8))
				if bounds.position.y<4 or bounds.end.y>size.y-4:continue
				if occupied.any(func(other):return other.grow(3).intersects(bounds)):continue
				point=proposed;frame=bounds;break
			if frame.size==Vector2.ZERO:continue
			occupied.append(frame)
			if point!=anchor:
				canvas.draw_line(anchor+Vector2(width/2,3),frame.get_center(),Color("20283f"),1)
			canvas.draw_rect(frame,Color("20283f"))
			canvas.draw_rect(frame.grow(-1),Color("f7e6bc"))
		canvas.draw_string(font,point,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,item.color)
