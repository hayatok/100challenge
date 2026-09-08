extends ScrollContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_fit_content)
	_fit_content()

func _fit_content() -> void:
	var content: Control = get_node("Rescue")
	# Godot owns scrolling: Web touch listeners prevent the browser's native pan.
	content.custom_minimum_size.y = maxf(size.y,size.x*0.645833+570.0) if size.x < 900 else maxf(size.y,720.0)
