class_name RescueProgress
extends RefCounted
const PATH: String = "user://rescue-v1.json"

static func validate(raw: Variant, count: int) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("best") is Dictionary:
		return clean
	for key: Variant in raw["best"]:
		if not key is String or not key.is_valid_int():
			continue
		var index: int = int(key)
		var cuts: Variant = raw["best"][key]
		if index >= 0 and index < count and (cuts is int or cuts is float) and float(cuts) == floorf(float(cuts)) and cuts >= 1 and cuts <= 12:
			clean[str(index)] = int(cuts)
	return clean

static func load_best(count: int) -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH,FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return {}
	return validate(JSON.parse_string(file.get_as_text()),count)

static func save_best(best: Dictionary) -> bool:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":1,"best":best}))
	return file.get_error() == OK
