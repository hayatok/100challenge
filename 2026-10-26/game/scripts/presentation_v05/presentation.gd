extends RefCounted
## Shared reading surfaces; no game state or turn ownership.
const Palette = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/rules.gd")

static func make_theme() -> Theme:
	var result := Palette.make_theme()
	for style: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = {"normal":Color("f6f2df"), "hover":Color("ffffff"), "pressed":Color("c4e4db"), "disabled":Color("e1e4d8")}[style]
		var box := Palette.box(fill, Color("94b4b0"), 7)
		box.shadow_size = 0
		box.set_corner_radius_all(4)
		box.set_border_width_all(1)
		result.set_stylebox(style, "Button", box)
	result.default_font_size = 14
	return result

static func primary(button: Button) -> void:
	for style: String in ["normal", "hover", "pressed"]:
		var box := Palette.box(Palette.PRIMARY if style == "normal" else Color("ffda87") if style == "hover" else Color("d9a24c"), Palette.GOLD, 10)
		box.set_corner_radius_all(5)
		box.shadow_size = 0
		button.add_theme_stylebox_override(style, box)
	button.add_theme_font_size_override("font_size", 17)

static func label(text: String, font_size: int = 14, color: Color = Palette.INK) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func mission(state: Dictionary) -> String:
	var selected: Dictionary = {}
	for row: Dictionary in Data.contracts(state):
		if row.status in ["claimed", "locked"]:
			continue
		if row.accepted:
			selected = row
			break
		if selected.is_empty() and row.id in Data.Campaign.STORY_IDS:
			selected = row
	if selected.is_empty():
		return "自由回収 / 倉庫に品を蓄えよう"
	var needs: Array[String] = []
	for requirement: Dictionary in selected.requirements:
		needs.append("%s %d/%d" % [Data.ITEMS[requirement.kind].name, requirement.owned, requirement.count])
	return "%s%s\n%s" % [selected.title, " / 納品できます" if selected.status == "ready" else "", "・".join(needs)]

static func item_row(item: Dictionary, action_text: String = "", equipped: bool = false, compact: bool = false) -> Control:
	if compact:
		return _preparation_row(item, action_text, equipped)
	var tile: PanelContainer = preload("res://scenes/presentation_v05/item_tile.tscn").instantiate()
	tile.set_meta("item_uid", item.uid)
	tile.set_meta("item_kind", item.kind)
	tile.get_node("Content/Icon").texture = Palette.icon(item.kind)
	tile.get_node("Content/Name").text = Data.ITEMS[item.kind].name
	tile.get_node("Content/Name").tooltip_text = Data.ITEMS[item.kind].description
	tile.get_node("Content/Detail").text = "出発時に装備" if equipped else "%d pt" % Data.ITEMS[item.kind].value
	var button: Button = tile.get_node("Content/Transfer")
	button.visible = not action_text.is_empty()
	button.text = action_text
	button.accessibility_name = "%sを%s" % [Data.ITEMS[item.kind].name, action_text]
	button.tooltip_text = "%s / %s" % [Data.ITEMS[item.kind].name, Data.ITEMS[item.kind].description]
	button.set_meta("item_uid", item.uid)
	return tile

## Preparation keeps the full item name next to separate ownership actions.
## Result receipts retain the authored tile layout through item_row's default.
static func _preparation_row(item: Dictionary, action_text: String, equipped: bool) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("item_uid", item.uid)
	row.set_meta("item_kind", item.kind)
	var box := Palette.box(Color("e2eee1") if equipped else Color("f4efdb"), Color("8fa59a"), 4)
	box.set_corner_radius_all(4)
	box.set_border_width_all(1)
	box.shadow_size = 0
	row.add_theme_stylebox_override("panel", box)
	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	row.add_child(content)
	var inspect := Button.new()
	inspect.name = "Inspect"
	inspect.text = ""
	inspect.custom_minimum_size = Vector2(96, 52)
	inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect.accessibility_name = "%sの説明を読む" % Data.ITEMS[item.kind].name
	inspect.tooltip_text = Data.ITEMS[item.kind].description
	inspect.set_meta("item_uid", item.uid)
	inspect.set_meta("item_action", "inspect")
	for state: String in ["normal", "hover", "pressed"]:
		inspect.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	content.add_child(inspect)
	var identity := HBoxContainer.new()
	identity.name = "Identity"
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.add_child(identity)
	identity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	identity.offset_left = 2
	identity.offset_right = -2
	identity.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = Palette.icon(item.kind)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(icon)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 1)
	identity.add_child(words)
	var name_label := label(Data.ITEMS[item.kind].name, 14)
	name_label.name = "Name"
	words.add_child(name_label)
	var detail := label("装備中" if equipped else "説明を見る", 12, Palette.SUCCESS if equipped else Palette.MUTED)
	detail.name = "Detail"
	words.add_child(detail)
	var transfer := Button.new()
	transfer.name = "Transfer"
	transfer.text = action_text
	transfer.custom_minimum_size = Vector2(52, 52)
	transfer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	transfer.add_theme_font_size_override("font_size", 13)
	transfer.set_meta("item_uid", item.uid)
	transfer.set_meta("item_action", "transfer")
	transfer.accessibility_name = "%sを%s" % [Data.ITEMS[item.kind].name, action_text]
	transfer.tooltip_text = "%sを倉庫から携行品へ移す" % Data.ITEMS[item.kind].name if action_text == "詰める" else "%sを携行品から倉庫へ戻す" % Data.ITEMS[item.kind].name
	content.add_child(transfer)
	return row

static func secondary(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var fill := Color("215966") if state == "normal" else Color("337383") if state == "hover" else Color("133b46")
		var box := Palette.box(fill, Color("92b6ad"), 6)
		box.shadow_size = 0
		box.set_corner_radius_all(4)
		box.set_border_width_all(1)
		button.add_theme_stylebox_override(state, box)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, Color("fff6dc"))
