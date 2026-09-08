class_name RaceRecords
extends RefCounted
var storage_path: String = "user://chibi-records.cfg"
var best_lap: float = 0.0
var best_race: float = 0.0
var color_index: int = 0
var save_ok: bool = true
func valid_time(value: Variant) -> float:
 if (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0 and float(value) < 86400.0:
  return float(value)
 return 0.0
func read() -> void:
 var config := ConfigFile.new()
 if config.load(storage_path) != OK:
  return
 best_lap = valid_time(config.get_value("record", "lap", 0.0))
 best_race = valid_time(config.get_value("record", "race", 0.0))
 var color: Variant = config.get_value("record", "color", 0)
 color_index = int(color) if color is int and color >= 0 and color < 4 else 0
func write() -> void:
 var config := ConfigFile.new()
 config.set_value("record", "lap", best_lap)
 config.set_value("record", "race", best_race)
 config.set_value("record", "color", color_index)
 save_ok = config.save(storage_path) == OK
