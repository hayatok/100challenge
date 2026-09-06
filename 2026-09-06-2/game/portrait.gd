extends Control
const Art = preload("res://creature_art.gd")
var art = Art.new()
var genes: Dictionary = {}
var egg: bool = false
var caption: String = ""
var font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
func _draw() -> void:
	if genes.is_empty(): return
	var fit: Dictionary = art.portrait_fit(genes, size, not caption.is_empty(), egg)
	art.render(self, genes, fit.center, fit.scale, 0, 0 if egg else 30, 0, false, true)
	if not caption.is_empty(): draw_string(font, Vector2(4, size.y - 6), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 13, Color("253d36"))
