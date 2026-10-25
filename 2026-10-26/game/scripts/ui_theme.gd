extends RefCounted

const INK := Color("efe4ce")
const MUTED := Color("b6b8a7")
const GOLD := Color("e4b36b")
const SURFACE := Color("1d3037")
const LINE := Color("526268")

static func box(fill: Color = SURFACE, border: Color = LINE, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	t.default_font_size = 16
	for kind: String in ["Label", "Button", "CheckButton", "RichTextLabel"]:
		t.set_color("font_color", kind, INK)
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("normal", "Button", box(Color("21373e")))
	t.set_stylebox("hover", "Button", box(Color("345057"), GOLD))
	t.set_stylebox("pressed", "Button", box(Color("101f26"), GOLD))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 0))
	t.set_stylebox("disabled", "Button", box(Color("18272d"), Color("35474d")))
	t.set_color("font_disabled_color", "Button", Color("8a9693"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	t.set_stylebox("background", "ProgressBar", box(Color("101d25"), LINE, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color("a8c7ad"), Color("a8c7ad"), 0))
	return t
