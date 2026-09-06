extends SceneTree
const Sim=preload("res://core/simulation.gd")
class Swatch extends "res://store_scene.gd":
	var equipment_id=0
	var direction=0
	func _draw():
		if sim==null or font==null:return
		labels=[];scale_world=0.5;origin=Vector2(48,65)
		draw_set_transform(origin,0,Vector2.ONE*scale_world)
		var product=[0,20,-1,60,74,-1,-1,-1,30,20,-1,60,10,40,40,-1,50,20,-1,-1][equipment_id]
		var f={"id":0,"kind":equipment_id,"x":0,"y":0,"dir":direction,"product":product,"lots":[] if product<0 else [sim.lot(product,sim.equipment[equipment_id].capacity)],"ready":0}
		draw_fixture(f);draw_set_transform(Vector2.ZERO)
func _init():call_deferred("render_board")
func render_board():
	root.size=Vector2i(960,790)
	var direction=0
	if not OS.get_cmdline_user_args().is_empty():direction=int(OS.get_cmdline_user_args()[0])%4
	var game=Sim.new()
	var board=Control.new();root.add_child(board);board.size=Vector2(960,790)
	var bg=ColorRect.new();bg.color=Color("f7e6bc");bg.size=board.size;board.add_child(bg)
	var theme=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf");theme.default_font_size=13;theme.set_color("font_color","Label",Color("20283f"));board.theme=theme
	var title=Label.new();title.text="まちあかりマート / 設備20種・ランタイム原寸描画の2倍表示 / 向き "+str(direction);title.position=Vector2(16,8);board.add_child(title)
	for id in 20:
		var cell=Vector2(id%5*192,id/5*186+30)
		var viewport=SubViewport.new();viewport.size=Vector2i(96,80);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;board.add_child(viewport)
		var sample=Swatch.new();sample.sim=game;sample.equipment_id=id;sample.direction=direction;sample.size=Vector2(96,80);viewport.add_child(sample)
		var image=TextureRect.new();image.texture=viewport.get_texture();image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.position=cell;image.size=Vector2(192,160);board.add_child(image)
		var caption=Label.new();caption.text="%02d %s"%[id,game.equipment[id].name];caption.position=cell+Vector2(0,158);caption.size=Vector2(192,24);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;board.add_child(caption)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png("res://../art/beta/equipment-board-"+str(direction)+".png")
	print("Equipment board saved, error ",result);quit(result)
