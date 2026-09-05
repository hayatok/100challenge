extends RefCounted
const PATH = "user://loop-eater-2d.cfg"

static func clean_integer(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]: return 0
	if not is_finite(float(value)): return 0
	return clampi(int(value),0,100000000)

static func load_record() -> Dictionary:
	var file=ConfigFile.new()
	var data={"best":0,"score":0,"wins":0,"reduced":false,"sound":true}
	if file.load(PATH)!=OK: return data
	for key in ["best","score","wins"]: data[key]=clean_integer(file.get_value("record",key,0))
	for key in ["reduced","sound"]:
		var v=file.get_value("settings",key,data[key])
		if typeof(v)==TYPE_BOOL: data[key]=v
	return data

static func save_record(data: Dictionary) -> bool:
	var file=ConfigFile.new()
	for key in ["best","score","wins"]: file.set_value("record",key,clean_integer(data.get(key,0)))
	for key in ["reduced","sound"]: file.set_value("settings",key,bool(data.get(key,false)))
	return file.save(PATH)==OK
