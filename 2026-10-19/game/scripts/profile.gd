extends RefCounted
## Local progress contains unlocks and settings only. Combat never reads permanent stats.

const VERSION := 1
const STORAGE_KEY := "echo-witch-profile-v1"
const WEAPONS := ["lightning", "moon", "thorn", "wisp", "frost", "bell"]
const RELICS := ["storm_ink", "moonstone", "thorn_seed", "lantern_oil", "ice_crystal", "silver_bell", "swift_boots", "magnet_ring", "ward_leaf", "blood_vial", "hourglass", "echo_mirror"]
const ENEMIES := ["hound", "charger", "archer", "sentinel", "wisp", "bat", "boss_thorn", "boss_mirror", "boss_bell"]
const DISCOVERY_GROUPS := ["weapons", "relics", "enemies", "evolutions"]
const MAX_DOCUMENT_BYTES := 131072

var data: Dictionary = defaults()
var status := "new"
var message := "記録はこのブラウザー内だけに保存します。"
var write_allowed := true
var dirty := false
var last_unlocks: Array[String] = []
var path := "user://echo-witch-profile-v1.json"
var _raw_before_error := ""
var _result_recorded := false

func _init(storage_path: String = "user://echo-witch-profile-v1.json") -> void:
	path = storage_path

static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"settings": {"sound": true, "reduced_motion": false, "music_volume": 0.65, "sfx_volume": 0.8, "large_text": false},
		"starters": ["lightning", "moon"],
		"discoveries": {"weapons": ["lightning", "moon"], "relics": [], "enemies": [], "evolutions": []},
		"clears": [], "best": {"chapter": 0, "kills": 0, "seconds": 0.0, "victories": 0}, "runs": 0
	}

func load_profile() -> bool:
	var stored := _read_storage()
	if not bool(stored.get("ok", false)):
		status = "blocked"
		message = "保存先を読み込めません。この回の記録は保存できません。"
		write_allowed = false
		return false
	var raw := str(stored.get("raw", ""))
	if bool(stored.get("oversized", false)):
		_raw_before_error = ""
		return _reject_document()
	if not bool(stored.get("exists", not raw.is_empty())):
		data = defaults()
		status = "new"
		message = "記録はこの端末だけに保存します。"
		write_allowed = true
		return true
	return load_document(raw)

func load_document(raw: String) -> bool:
	_raw_before_error = raw
	if raw.length() > MAX_DOCUMENT_BYTES:
		return _reject_document()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return _reject_document()
	var parsed = parser.data
	if not parsed is Dictionary or not validate(parsed):
		return _reject_document()
	data = parsed.duplicate(true)
	data.version = int(data.version)
	data.runs = int(data.runs)
	for key in ["chapter", "kills", "victories"]:
		data.best[key] = int(data.best[key])
	for index in range(data.clears.size()):
		data.clears[index] = int(data.clears[index])
	_raw_before_error = ""
	write_allowed = true
	status = "saved"
	message = "この端末の記録を読み込みました。"
	dirty = false
	return true

func _reject_document() -> bool:
	# Keep the raw document in storage until the player explicitly archives it.
	write_allowed = false
	status = "invalid"
	message = "保存記録を読めません。元の記録を残し、この回は保存せず遊べます。"
	return false

static func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _ids(value: Variant, allowed: Array, limit: int) -> bool:
	if not value is Array or value.size() > limit:
		return false
	var seen := {}
	for id in value:
		if not id is String or not allowed.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true

static func validate(document: Dictionary) -> bool:
	if document.size() != 7 or not _whole(document.get("version"), VERSION, VERSION):
		return false
	var settings = document.get("settings")
	if not settings is Dictionary or settings.size() != 5:
		return false
	for key in ["sound", "reduced_motion", "large_text"]:
		if not settings.get(key) is bool:
			return false
	for key in ["music_volume", "sfx_volume"]:
		if not _number(settings.get(key), 0.0, 1.0):
			return false
	if not _ids(document.get("starters"), WEAPONS, 6):
		return false
	if not document.starters.has("lightning") or not document.starters.has("moon"):
		return false
	var discoveries = document.get("discoveries")
	if not discoveries is Dictionary or discoveries.size() != 4:
		return false
	for group in DISCOVERY_GROUPS:
		var entries = discoveries.get(group)
		if not entries is Array or entries.size() > 64:
			return false
		var seen := {}
		for id in entries:
			# The content registry can grow; accept only short safe registry IDs.
			if not id is String or id.is_empty() or id.length() > 64 or seen.has(id):
				return false
			for character in id:
				if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_"):
					return false
			seen[id] = true
		var allowed: Array = WEAPONS if group in ["weapons", "evolutions"] else (RELICS if group == "relics" else ENEMIES)
		if not _ids(entries, allowed, allowed.size()):
			return false
	var clears = document.get("clears")
	if not clears is Array or clears.size() > 3:
		return false
	var clear_seen := {}
	for chapter in clears:
		if not _whole(chapter, 0, 2) or clear_seen.has(int(chapter)):
			return false
		clear_seen[int(chapter)] = true
	var best = document.get("best")
	if not best is Dictionary or best.size() != 4:
		return false
	if not _whole(best.get("chapter"), 0, 3) or not _whole(best.get("kills"), 0, 1000000000) or not _whole(best.get("victories"), 0, 1000000000):
		return false
	if not _number(best.get("seconds"), 0.0, 86400.0) or not _whole(document.get("runs"), 0, 1000000000):
		return false
	return true

func settings() -> Dictionary:
	return data.settings.duplicate(true)

func snapshot() -> Dictionary:
	return {"status": status, "message": message, "can_save": write_allowed and status not in ["invalid", "blocked", "error"], "data": data.duplicate(true), "unlocks": last_unlocks.duplicate()}

func has_starter(id: String) -> bool:
	return data.starters.has(id)

func set_setting(key: String, value: Variant, persist: bool = true) -> bool:
	var candidate: Dictionary = data.duplicate(true)
	if not candidate.settings.has(key):
		return false
	candidate.settings[key] = value
	if not validate(candidate):
		return false
	data = candidate
	dirty = true
	return save() if persist else true

func begin_run() -> void:
	_result_recorded = false
	last_unlocks.clear()

func record_run(run: Dictionary, persist: bool = true) -> bool:
	var discoveries = run.get("discoveries", {})
	if discoveries is Dictionary:
		for group in DISCOVERY_GROUPS:
			var entries = discoveries.get(group, [])
			if entries is Array:
				for id in entries:
					if id is String and not data.discoveries[group].has(id):
						var candidate: Dictionary = data.duplicate(true)
						candidate.discoveries[group].append(id)
						if validate(candidate):
							data = candidate
	var chapter_clears = run.get("chapter_clears", [])
	if chapter_clears is Array:
		for chapter in chapter_clears:
			if _whole(chapter, 0, 2) and not data.clears.has(int(chapter)):
				data.clears.append(int(chapter))
	for id in WEAPONS:
		var unlock: bool = id in ["lightning", "moon"]
		unlock = unlock or (id in ["thorn", "wisp"] and data.clears.has(0))
		unlock = unlock or (id == "frost" and data.clears.has(1))
		unlock = unlock or (id == "bell" and data.clears.has(2))
		if unlock and not data.starters.has(id):
			data.starters.append(id)
			if not data.discoveries.weapons.has(id):
				data.discoveries.weapons.append(id)
			last_unlocks.append(id)
	data.best.chapter = maxi(int(data.best.chapter), clampi(int(run.get("chapter", 0)) + 1, 0, 3))
	data.best.kills = maxi(int(data.best.kills), clampi(int(run.get("kills", 0)), 0, 1000000000))
	data.best.seconds = maxf(float(data.best.seconds), clampf(float(run.get("elapsed", 0.0)), 0.0, 86400.0))
	if str(run.get("state", "")) in ["victory", "defeat"] and not _result_recorded:
		_result_recorded = true
		data.runs = mini(int(data.runs) + 1, 1000000000)
		if run.state == "victory":
			data.best.victories = mini(int(data.best.victories) + 1, 1000000000)
	dirty = true
	return save() if persist else true

func save() -> bool:
	if not write_allowed:
		return false
	if not validate(data):
		status = "error"
		message = "今回の記録を保存できません。読み込んだ記録は保持しています。"
		return false
	var written := _write_storage(JSON.stringify(data))
	if not bool(written.get("ok", false)):
		status = "blocked"
		message = "記録を保存できません。保存の許可や空き容量を確認してください。"
		return false
	status = "saved"
	message = "この端末に保存しました。"
	dirty = false
	return true

func retry_storage() -> bool:
	if status == "invalid":
		return false
	if not write_allowed:
		# Re-read before enabling writes; a formerly inaccessible save may exist.
		var in_memory: Dictionary = data.duplicate(true)
		if not load_profile():
			data = in_memory
			return false
		data.settings = in_memory.settings.duplicate(true)
		for group in DISCOVERY_GROUPS:
			for id in in_memory.discoveries[group]:
				if not data.discoveries[group].has(id):
					data.discoveries[group].append(id)
		for group in ["starters", "clears"]:
			for id in in_memory[group]:
				if not data[group].has(id):
					data[group].append(id)
		for key in data.best:
			data.best[key] = maxf(float(data.best[key]), float(in_memory.best[key]))
		data.runs = maxi(int(data.runs), int(in_memory.runs))
	return save()

func archive_invalid_and_reset() -> bool:
	if status != "invalid":
		return false
	var archived := _archive_invalid(_raw_before_error)
	if not archived:
		message = "元の記録を退避できません。保存せずに遊べます。"
		return false
	data = defaults()
	write_allowed = true
	_raw_before_error = ""
	return save()

func _read_storage() -> Dictionary:
	if OS.has_feature("web"):
		var script := "(()=>{try{const raw=localStorage.getItem(%s);return JSON.stringify({ok:true,raw:raw||'',exists:raw!==null})}catch(e){return JSON.stringify({ok:false})}})()" % JSON.stringify(STORAGE_KEY)
		var response = JSON.parse_string(str(JavaScriptBridge.eval(script, true)))
		return response if response is Dictionary else {"ok": false}
	if not FileAccess.file_exists(path):
		return {"ok": true, "raw": "", "exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	if file.get_length() > MAX_DOCUMENT_BYTES:
		return {"ok": true, "raw": "", "oversized": true}
	return {"ok": true, "raw": file.get_as_text(), "exists": true}

func _write_storage(raw: String) -> Dictionary:
	if OS.has_feature("web"):
		var script := "(()=>{try{localStorage.setItem(%s,%s);return true}catch(e){return false}})()" % [JSON.stringify(STORAGE_KEY), JSON.stringify(raw)]
		return {"ok": bool(JavaScriptBridge.eval(script, true))}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(raw)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"ok": false}
	return {"ok": DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK}

func _archive_invalid(raw: String) -> bool:
	var suffix := str(int(Time.get_unix_time_from_system())) + "-" + str(Time.get_ticks_usec())
	if OS.has_feature("web"):
		var backup_key := STORAGE_KEY + "-unreadable-" + suffix
		var script := "(()=>{try{localStorage.setItem(%s,%s);return true}catch(e){return false}})()" % [JSON.stringify(backup_key), JSON.stringify(raw)]
		return bool(JavaScriptBridge.eval(script, true))
	var backup_path := path + ".unreadable-" + suffix + ".json"
	if FileAccess.file_exists(path):
		return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path)) == OK
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return false
	backup.store_string(raw)
	backup.flush()
	return backup.get_error() == OK
