extends SceneTree
const Icon=preload("res://product_icon.gd")
const Catalog=preload("res://core/catalog.gd")
func _init():call_deferred("render_board")
func render_board():
	root.size=Vector2i(1100,768)
	var board=Control.new();root.add_child(board);board.size=Vector2(1100,768)
	var bg=ColorRect.new();bg.color=Color("f7e6bc");bg.size=board.size;board.add_child(bg)
	var theme=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansCJKjp-Medium.otf");theme.default_font_size=10;theme.set_color("font_color","Label",Color("20283f"));board.theme=theme
	var title=Label.new();title.text="まちあかりマート / 商品の原寸ピクセル作画・内容確認用ボード";title.position=Vector2(12,8);title.add_theme_font_size_override("font_size",16);board.add_child(title)
	for product in Catalog.products():
		var at=Vector2((product.id%10)*110,(product.id/10)*88+36)
		var icon=Icon.new();icon.product=product;icon.position=at+Vector2(34,4);board.add_child(icon)
		var name_label=Label.new();name_label.text=str(product.id)+" "+product.name.substr(0,8);
		for start in range(8,product.name.length(),8):name_label.text+="\n"+product.name.substr(start,8)
		name_label.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY;name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;board.add_child(name_label);name_label.position=at+Vector2(3,48);name_label.size=Vector2(104,36)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png("res://../art/beta/product-board.png")
	print("Product board saved, error ",result)
	quit(result)
