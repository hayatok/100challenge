extends RefCounted

const RulesData = preload("res://scripts/rules.gd")
const KEY := "shiogaeri-save-v1"
const SETTINGS := "shiogaeri-settings-v1"
const PATH := "user://expedition.json"

static func read_value(key: String, native_path: String) -> Dictionary:
	if OS.has_feature("web"):
		var code := "(function(){try{return localStorage.getItem(%s)||'';}catch(e){return '!STORAGE:'+e.message;}})()" % JSON.stringify(key)
		var raw: Variant = JavaScriptBridge.eval(code)
		if raw == null:
			return {"raw": "", "error": "保存領域を読み込めませんでした。"}
		if str(raw).begins_with("!STORAGE:"):
			return {"raw": "", "error": "このブラウザでは保存領域を使えません。"}
		return {"raw": str(raw), "error": ""}
	if not FileAccess.file_exists(native_path):
		return {"raw": "", "error": ""}
	var file := FileAccess.open(native_path, FileAccess.READ)
	if file == null:
		return {"raw": "", "error": "保存ファイルを開けませんでした。"}
	return {"raw": file.get_as_text(), "error": ""}

static func write_value(key: String, native_path: String, value: Dictionary) -> String:
	var serialized := JSON.stringify(value)
	if OS.has_feature("web"):
		var code := "(function(){try{localStorage.setItem(%s,%s);return '';}catch(e){return 'error';}})()" % [JSON.stringify(key), JSON.stringify(serialized)]
		var error: Variant = JavaScriptBridge.eval(code)
		return "" if error != null and str(error) == "" else "保存できませんでした。この画面を閉じると進行が失われる可能性があります。"
	var file := FileAccess.open(native_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "保存ファイルを作れませんでした。"
	file.store_string(serialized)
	file.flush()
	if file.get_error() != OK:
		file.close()
		return "保存ファイルへの書き込みに失敗しました。"
	file.close()
	if FileAccess.file_exists(native_path):
		DirAccess.copy_absolute(native_path, native_path + ".bak")
	if DirAccess.rename_absolute(native_path + ".tmp", native_path) != OK:
		return "保存ファイルを更新できませんでした。"
	return ""

static func load_game() -> Dictionary:
	var read := read_value(KEY, PATH)
	if not read.error.is_empty():
		return {"state": RulesData.new_game(), "error": read.error, "corrupt": false, "found": false}
	if read.raw.is_empty():
		return {"state": RulesData.new_game(), "error": "", "corrupt": false, "found": false}
	var parser := JSON.new()
	var decoded: Variant = parser.data if parser.parse(read.raw) == OK else null
	if not RulesData.validate_state(decoded):
		return {"state": RulesData.new_game(), "error": "保存データを読み込めませんでした。新しく始めると、このデータを置き換えます。", "corrupt": true, "found": true}
	return {"state": decoded, "error": "", "corrupt": false, "found": true}

static func save_game(state: Dictionary) -> String:
	if not RulesData.validate_state(state):
		return "状態を保存できませんでした。"
	return write_value(KEY, PATH, state)

static func load_settings() -> Dictionary:
	var raw := read_value(SETTINGS, "user://settings.json")
	var parser := JSON.new()
	var value: Variant = parser.data if not raw.raw.is_empty() and parser.parse(raw.raw) == OK else null
	if value is Dictionary and value.get("sound") is bool and value.get("reduced") is bool:
		return {"sound": value.sound, "reduced": value.reduced}
	return {"sound": true, "reduced": false}

static func save_settings(settings: Dictionary) -> String:
	return write_value(SETTINGS, "user://settings.json", settings)
