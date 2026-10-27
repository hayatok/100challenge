extends RefCounted
## Sunlit enamel and expedition paper, with original equipment icon art.
const INK := Color("183e52")
const MUTED := Color("607b87")
const GOLD := Color("a96a20")
const PRIMARY := Color("f4c05d")
const SURFACE := Color("fff8e5")
const PAPER := Color("f7edcf")
const LINE := Color("99c7c4")
const SEA := Color("40b7bd")
const CORAL := Color("de796c")
const SUCCESS := Color("367f71")
const DANGER := Color("ae4644")

static func box(fill: Color = SURFACE, border: Color = LINE, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(9)
	s.corner_detail = 6
	s.shadow_color = Color(0.08, 0.23, 0.28, 0.17)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

static func icon(kind: String) -> Texture2D:
	return load("res://assets/ui/%s.svg" % ("knife" if kind == "loanKnife" else kind)) as Texture2D

static func avatar(character: String) -> Texture2D:
	var texture: Texture2D = load("res://assets/art/%s.png" % character)
	var crop := AtlasTexture.new()
	crop.atlas = texture
	var side := texture.get_width() * 0.65
	crop.region = Rect2(texture.get_width() * 0.175, 0, side, side)
	return crop

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/NotoSansCJKjp-Medium.otf")
	t.default_font_size = 16
	for kind: String in ["Label", "Button", "CheckButton", "RichTextLabel"]:
		t.set_color("font_color", kind, INK)
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("normal", "Button", box(Color("fff8e5"), Color("739fa3")))
	t.set_stylebox("hover", "Button", box(Color("ffffff"), SEA))
	var pressed := box(Color("cce4d8"), Color("4f8e94"))
	pressed.shadow_size = 0
	pressed.content_margin_top = 14
	pressed.content_margin_bottom = 10
	t.set_stylebox("pressed", "Button", pressed)
	var focus := box(Color(0, 0, 0, 0), Color("bd712a"), 0)
	focus.set_border_width_all(3)
	focus.shadow_size = 0
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", box(Color("ece5cd"), Color("c3c9b7")))
	t.set_color("font_disabled_color", "Button", Color("78887f"))
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	t.set_stylebox("background", "ProgressBar", box(Color("dfdfc5"), Color("b8c9b6"), 0))
	t.set_stylebox("fill", "ProgressBar", box(Color("58b49a"), Color("3d8e85"), 0))
	var track := box(Color("dae7d8"), Color(0, 0, 0, 0), 0)
	track.shadow_size = 0
	t.set_stylebox("scroll", "VScrollBar", track)
	var grabber := box(Color("70aaa8"), Color("467e89"), 0)
	grabber.shadow_size = 0
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(SEA, INK, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Color("47898e"), INK, 0))
	return t
