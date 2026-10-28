extends PanelContainer
## A receipt of ownership already resolved by Rules, never an item transfer.
signal continue_requested()
const Data = preload("res://scripts/rules.gd")
const UI = preload("res://scripts/presentation_v05/presentation.gd")
const Palette = preload("res://scripts/ui_theme.gd")
@onready var _fallback_portrait: TextureRect = %Portrait
@onready var stage_slot: Control = %StageSlot
@onready var continue_button: Button = %Continue
@onready var result_scroll: ScrollContainer = %ResultScroll

func _ready() -> void:
	theme = UI.make_theme()
	UI.primary(continue_button)
	continue_button.call_deferred("grab_focus")
	result_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(func(): continue_requested.emit())
	resized.connect(_adapt)
	_adapt()

func attach_stage(stage: Control) -> void:
	UI.clear(stage_slot)
	stage.custom_minimum_size = Vector2.ZERO
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_slot.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func present(state: Dictionary) -> void:
	var receipt: Dictionary = state.result
	var success: bool = receipt.outcome == "extracted"
	var empty: bool = receipt.inventory.is_empty()
	var who: Dictionary = Data.CHARACTERS[state.character]
	if is_instance_valid(_fallback_portrait):
		_fallback_portrait.texture = Palette.portrait(state.character)
	%Eyebrow.text = "WELCOME HOME" if success else "EXPEDITION LOST"
	%Outcome.text = "帰還成功" if success and not empty else "無事に帰港" if success else "回収失敗"
	%Outcome.add_theme_color_override("font_color", Color("fff6dc") if success else Color("ffb2a2"))
	%Count.text = "%d個を倉庫へ" % receipt.inventory.size() if success else "%d個を失いました" % receipt.inventory.size()
	%Turns.text = "%d手の遠征" % receipt.turns
	%Speaker.text = "%s / %s" % [who.name, who.role]
	# Full-width speech, without added brackets that can become a lone line.
	%Quote.text = who.lossLine if not success else who.emptyLine if empty else who.returnLine
	%Cause.text = "原因：%s" % receipt.cause
	%Cause.visible = not success
	%Cause.add_theme_color_override("font_color", Color("ffb2a2"))
	%ReceiptTitle.text = "持ち帰った戦利品" if success else "失った携行品"
	%Value.text = "%d pt" % receipt.value
	%Value.add_theme_color_override("font_color", Palette.GOLD if success else Palette.DANGER)
	%Ownership.text = "倉庫へ保管済み。次の遠征に持ち出せます。" if success and not empty else "持ち帰った品はありません。" if success else "倉庫の品と港の復興は残ります。武器なしでも貸出ナイフで再出発できます。"
	var progress: Dictionary = Data.campaign_summary(state)
	%Progress.text = "港の復興  %d / %d" % [progress.completed, progress.total]
	%Mission.text = UI.mission(state)
	UI.clear(%Items)
	if empty and not success:
		%Items.add_child(UI.label("品はありません。", 14, Palette.MUTED))
	for item: Dictionary in receipt.inventory:
		%Items.add_child(UI.item_row(item))
	_adapt()

func _adapt() -> void:
	if not is_node_ready():
		return
	var wide := size.x >= 720
	%Body.vertical = not wide
	%Arrival.custom_minimum_size.x = minf(480, size.x * 0.43) if wide else 0
	%Hero.custom_minimum_size.y = 330 if wide else 174
	stage_slot.custom_minimum_size = Vector2(180, 330) if wide else Vector2(130, 174)
	%Items.columns = 1 if %Items.get_child_count() == 1 and %Items.get_child(0) is Label else 4 if wide else 3
