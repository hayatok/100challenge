extends HBoxContainer
## A field-first instrument layout. The world and controls never overlap.
signal direction_requested(dx: int, dy: int)
signal interact_requested
signal inventory_requested
signal map_requested
signal crew_requested
signal settings_requested
signal feedback_requested

const Palette = preload("res://scripts/ui_theme.gd")
@onready var hp_label: Label = %Health
@onready var hp_bar: ProgressBar = %HealthBar
@onready var tide_label: Label = %Tide
@onready var bag_label: Label = %CargoCount
@onready var turn_label: Label = %Turn
@onready var objective_label: Label = %Objective
@onready var value_label: Label = %CargoValue
@onready var status_label: Label = %Feedback
@onready var interact_button: Button = %Interact
@onready var crew_button: Button = %CrewAction
@onready var controls: HBoxContainer = %Controls
@onready var controls_panel: PanelContainer = %ControlsPanel
@onready var world_slot: Control = %World
@onready var portrait: TextureRect = %Portrait
@onready var _column: VBoxContainer = %Column
@onready var _sidebar: PanelContainer = %Sidebar
@onready var _sidebar_top: VBoxContainer = %SidebarTop
@onready var _sidebar_bottom: VBoxContainer = %SidebarBottom
@onready var _instruments: PanelContainer = %Instruments
@onready var _purpose: PanelContainer = %Purpose
@onready var _goal_row: HBoxContainer = %GoalRow
@onready var _desktop_summary: HBoxContainer = %DesktopSummary
@onready var _pad: GridContainer = %Pad
@onready var _controls_stack: VBoxContainer = %ControlsStack
@onready var _settings_button: Button = %Settings
@onready var _instrument_row: HBoxContainer = %Instruments.get_node("Row")
@onready var _touch_toggle: Button = %TouchToggle
@onready var _legend: Label = %Legend
@onready var _feedback_timer: Timer = %FeedbackTimer
var _wide := false
var _desktop_touch := false

func _ready() -> void:
	theme = Palette.make_field_theme()
	for panel: PanelContainer in [_instruments, _purpose, controls_panel, _sidebar]:
		panel.add_theme_stylebox_override("panel", Palette.field_panel())
	_purpose.add_theme_stylebox_override("panel", Palette.field_panel(Color("173f4d"), 4))
	interact_button.expand_icon = true
	interact_button.add_theme_constant_override("icon_max_width", 20)
	interact_button.add_theme_stylebox_override("normal", Palette.field_panel(Palette.PRIMARY, 8))
	interact_button.add_theme_stylebox_override("hover", Palette.field_panel(Color("ffdc8f"), 8))
	interact_button.add_theme_stylebox_override("pressed", Palette.field_panel(Color("dfaa52"), 8))
	interact_button.add_theme_color_override("font_color", Palette.INK)
	interact_button.add_theme_color_override("font_hover_color", Palette.INK)
	interact_button.add_theme_color_override("font_pressed_color", Palette.INK)
	for pair: Array in [[%Up, 0, -1], [%Left, -1, 0], [%Wait, 0, 0], [%Right, 1, 0], [%Down, 0, 1]]:
		var dx: int = pair[1]
		var dy: int = pair[2]
		(pair[0] as Button).pressed.connect(func(): direction_requested.emit(dx, dy))
	_connect_menu(%Interact, func(): interact_requested.emit())
	_connect_menu(%Inventory, func(): inventory_requested.emit())
	_connect_menu(%Map, func(): map_requested.emit())
	_connect_menu(%CrewAction, func(): crew_requested.emit())
	_connect_menu(%Settings, func(): settings_requested.emit())
	_touch_toggle.pressed.connect(func():
		_desktop_touch = not _desktop_touch
		_pad.visible = not _wide or _desktop_touch
		_touch_toggle.text = "タッチ操作を閉じる" if _desktop_touch else "タッチ操作を開く")
	_feedback_timer.timeout.connect(clear_feedback)
	resized.connect(_adapt)
	call_deferred("_adapt")

func _connect_menu(button: Button, callback: Callable) -> void:
	button.pressed.connect(func():
		feedback_requested.emit()
		callback.call())

func _adapt() -> void:
	var wide := size.x >= 760.0 or (size.x >= 560.0 and size.y < 560.0)
	if wide != _wide:
		_wide = wide
		if wide:
			_instruments.reparent(_sidebar_top, false)
			_purpose.reparent(_sidebar_top, false)
			controls_panel.reparent(_sidebar_bottom, false)
			_settings_button.reparent(_sidebar_bottom, false)
			_pad.reparent(_controls_stack, false)
			_controls_stack.move_child(_pad, 0)
			_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			turn_label.reparent(_desktop_summary, false)
			value_label.reparent(_desktop_summary, false)
			turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			objective_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		else:
			_instruments.reparent(_column, false)
			_column.move_child(_instruments, 0)
			_purpose.reparent(_column, false)
			_column.move_child(_purpose, 1)
			controls_panel.reparent(_column, false)
			_settings_button.reparent(_instrument_row, false)
			_pad.reparent(controls, false)
			controls.move_child(_pad, 0)
			turn_label.reparent(_goal_row, false)
			value_label.reparent(_goal_row, false)
			turn_label.size_flags_horizontal = Control.SIZE_FILL
			objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sidebar.visible = wide
	_desktop_summary.visible = wide and not status_label.visible
	_touch_toggle.visible = wide
	_legend.visible = wide
	_pad.visible = not wide or _desktop_touch

func show_feedback(text: String, persistent: bool = false) -> void:
	if text.is_empty():
		return
	status_label.text = text
	status_label.show()
	_goal_row.hide()
	_desktop_summary.hide()
	_feedback_timer.stop()
	if not persistent:
		_feedback_timer.start()

func set_paused(paused: bool) -> void:
	_feedback_timer.paused = paused

func clear_feedback() -> void:
	_feedback_timer.stop()
	status_label.hide()
	_goal_row.show()
	_desktop_summary.visible = _wide

func show_previews(previews: Dictionary) -> void:
	for pair: Array in [[%Up,0,-1,"↑"], [%Left,-1,0,"←"], [%Wait,0,0,"待つ"], [%Right,1,0,"→"], [%Down,0,1,"↓"]]:
		var button: Button = pair[0]
		var preview: Dictionary = previews.get("%d,%d" % [pair[1],pair[2]], {})
		var damage := int(preview.get("damage", 0))
		button.disabled = not bool(preview.get("valid", false))
		button.text = "%s\n−%d" % [pair[3], damage] if damage > 0 else str(pair[3])
		button.add_theme_font_size_override("font_size", 16 if damage > 0 or pair[3] == "待つ" else 24)
		button.tooltip_text = str(preview.get("reason", "")) if button.disabled else "この一手の被ダメージ：%d" % damage
