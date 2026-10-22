extends SceneTree

var checks := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var heading := load("res://assets/fonts/ZenOldMincho-Bold.ttf") as FontFile
	var body := load("res://assets/fonts/NotoSansCJKjp-Medium.otf") as FontFile
	var required := "残響の魔女月下の庭園鏡の回廊夜明けの鐘楼茨の番人鏡守鐘を喰う影魔術書装備図鑑強化1234567890"
	for font in [heading, body]:
		expect(font != null, "font is imported")
		if font != null:
			var supported: String = font.get_supported_chars()
			for character in required:
				expect(supported.contains(character), "font glyph " + character)
	for id in ["boss-thorn", "boss-mirror", "boss-bell"]:
		var texture := load("res://assets/art/%s.png" % id) as Texture2D
		var image := texture.get_image() if texture != null else null
		expect(image != null and not image.is_empty(), id + " image available")
		if image != null and not image.is_empty():
			expect(image.get_width() > 500 and image.get_height() > 500, id + " resolution")
			expect(image.get_pixel(0, 0).a < 0.1 and image.get_pixel(image.get_width() - 1, 0).a < 0.1, id + " transparent corners")
	expect(FileAccess.file_exists("res://assets/fonts/ZEN-OFL.txt"), "heading font license bundled")
	expect(FileAccess.file_exists("res://assets/fonts/LICENSE.txt"), "body font license bundled")
	print("ASSETS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
