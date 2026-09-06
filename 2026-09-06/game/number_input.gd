extends SpinBox

func _ready():
	var line=get_line_edit()
	line.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	# Japanese IMEs commit full-width digits; the expression parser expects ASCII.
	# Keep submission/focus behavior, so partial budgets are not applied while typing.
	line.text_changed.connect(func(text:String):
		var normalized=""
		for i in text.length():
			var code=text.unicode_at(i)
			normalized+=String.chr(code-0xFEE0) if code>=0xFF10 and code<=0xFF19 else text[i]
		if normalized!=text:
			var caret=line.caret_column
			line.text=normalized
			line.caret_column=caret
	)
