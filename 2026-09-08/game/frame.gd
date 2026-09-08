extends ScrollContainer
var display_poll: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_display_scale()
	resized.connect(_fit_content)
	_fit_content()

func _fit_content() -> void:
	var content: Control = get_node("Rescue")
	# Godot owns scrolling: Web touch listeners prevent the browser's native pan.
	content.custom_minimum_size.y = maxf(size.y,size.x*0.645833+630.0) if size.x < 900 else maxf(size.y,720.0)

func _process(delta: float) -> void:
	display_poll += delta
	if OS.has_feature("web") and display_poll >= 0.5:
		display_poll = 0.0
		_update_display_scale()

func _update_display_scale() -> void:
	if OS.has_feature("web"):
		# Layout uses CSS pixels, including on Retina. The engine keeps the high-DPI canvas.
		var ratio: float = float(JavaScriptBridge.eval("window.devicePixelRatio || 1"))
		if not is_equal_approx(get_window().content_scale_factor,ratio):
			get_window().content_scale_factor = ratio
