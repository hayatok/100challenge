class_name RescueProgress
extends RefCounted
const PATH: String = "user://rescue-v2.json"
const LEGACY_PATH: String = "user://rescue-v1.json"
# Original eight models survive; their chapter order changed in the 16-model edition.
const LEGACY_ORDER: Array[int] = [0,1,2,4,5,3,6,7]

static func validate(raw: Variant, count: int) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary or raw.get("version") != 2 or not raw.get("best") is Dictionary:
		return clean
	for key: Variant in raw["best"]:
		if not key is String or not key.is_valid_int():
			continue
		var index: int = int(key)
		var cuts: Variant = raw["best"][key]
		if index >= 0 and index < count and (cuts is int or cuts is float) and float(cuts) == floorf(float(cuts)) and cuts >= 1 and cuts <= 12:
			clean[str(index)] = int(cuts)
	return clean

static func migrate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1:
		return {}
	var old: Dictionary = validate({"version":2,"best":raw.get("best")},8)
	var result: Dictionary = {}
	for key: String in old:
		result[str(LEGACY_ORDER[int(key)])] = old[key]
	return result

static func load_best(count: int) -> Dictionary:
	var legacy: bool = not FileAccess.file_exists(PATH)
	var source: String = LEGACY_PATH if legacy else PATH
	if not FileAccess.file_exists(source):
		return {}
	var file := FileAccess.open(source,FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return {}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	return migrate(raw) if legacy else validate(raw,count)

static func save_best(best: Dictionary) -> bool:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":2,"best":best}))
	return file.get_error() == OK
