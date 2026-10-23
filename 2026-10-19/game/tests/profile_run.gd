extends SceneTree

const Profile = preload("res://scripts/profile.gd")
var failures: Array[String] = []
var checks := 0

class BlockedProfile:
	extends "res://scripts/profile.gd"
	func _read_storage() -> Dictionary:
		return {"ok": false}
	func _write_storage(_raw: String) -> Dictionary:
		return {"ok": false}

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _run() -> void:
	var profile := Profile.new("user://echo-witch-profile-test.json")
	_check(Profile.validate(profile.data), "default profile has a valid schema")
	var bad: Dictionary = profile.data.duplicate(true)
	bad.version = 99
	_check(not Profile.validate(bad), "future profile version cannot be overwritten")
	bad = profile.data.duplicate(true)
	bad.settings.music_volume = NAN
	_check(not Profile.validate(bad), "nonfinite volume is rejected")
	bad = profile.data.duplicate(true)
	bad.settings.music_volume = 2.0
	_check(not Profile.validate(bad), "out of range volume is rejected")
	bad = profile.data.duplicate(true)
	bad.settings.network_sync = true
	_check(not Profile.validate(bad), "unknown settings are rejected")
	bad = profile.data.duplicate(true)
	bad.discoveries.relics = ["invented_relic"]
	_check(not Profile.validate(bad), "unknown content IDs are rejected")
	bad = profile.data.duplicate(true)
	bad.starters.append("invincible")
	_check(not Profile.validate(bad), "unknown starter cannot enter loadout")
	bad = profile.data.duplicate(true)
	bad.clears = [0, 0]
	_check(not Profile.validate(bad), "duplicate chapter clears rejected")
	bad = profile.data.duplicate(true)
	bad.runs = -1
	_check(not Profile.validate(bad), "negative run count rejected")
	_check(not profile.load_document("{broken"), "corrupt document rejected")
	_check(profile.status == "invalid" and not profile.write_allowed and not profile.save(), "invalid document is protected from automatic saves")
	_check(profile.set_setting("large_text", true, false), "settings remain usable without a save")
	_check(not profile.write_allowed, "changing a setting cannot unlock protected storage")
	profile = Profile.new("user://echo-witch-profile-test.json")
	profile.begin_run()
	var chapter := {"state": "chapter_clear", "chapter": 0, "chapter_clears": [0], "elapsed": 190.0, "kills": 125, "discoveries": {"weapons": ["thorn"], "relics": ["storm_ink"], "enemies": ["boss_thorn"], "evolutions": []}}
	profile.record_run(chapter, false)
	_check(profile.has_starter("thorn") and profile.has_starter("wisp") and not profile.has_starter("frost"), "first chapter unlocks variety only")
	_check(profile.data.runs == 0, "chapter save is not a completed run")
	chapter.state = "defeat"
	profile.record_run(chapter, false)
	profile.record_run(chapter, false)
	_check(profile.data.runs == 1, "repeat result refresh counts a run once")
	profile.begin_run()
	profile.record_run(chapter, false)
	_check(profile.data.runs == 2, "new result counts the next run")
	chapter.state = "victory"
	chapter.chapter = 2
	chapter.chapter_clears = [0, 1, 2]
	profile.begin_run()
	profile.record_run(chapter, false)
	_check(profile.data.starters.size() == 6 and profile.data.best.victories == 1, "campaign victory unlocks remaining starters")
	_check(not profile.data.has("power") and not profile.data.has("stats"), "profile does not store permanent combat boosts")
	_check(profile.save(), "native profile writes atomically")
	var loaded := Profile.new("user://echo-witch-profile-test.json")
	_check(loaded.load_profile(), "saved profile reloads")
	_check(loaded.data == profile.data, "progress and settings survive JSON roundtrip")
	var duplicate: Dictionary = loaded.snapshot()
	duplicate.data.settings.sound = false
	_check(loaded.data.settings.sound, "public profile snapshot cannot mutate settings")
	var empty := FileAccess.open(profile.path, FileAccess.WRITE)
	empty.close()
	_check(not loaded.load_profile() and not loaded.save(), "an existing empty file is corrupt, not a missing save")
	var corrupt := FileAccess.open(profile.path, FileAccess.WRITE)
	corrupt.store_string("{keep this unreadable record}")
	corrupt.close()
	_check(not loaded.load_profile() and not loaded.save(), "file corruption remains protected")
	_check(FileAccess.get_file_as_string(profile.path) == "{keep this unreadable record}", "failed load and save preserve exact original bytes")
	_check(loaded.archive_invalid_and_reset() and Profile.validate(loaded.data), "explicit recovery archives original before reset")
	var blocked := BlockedProfile.new()
	_check(not blocked.load_profile() and blocked.status == "blocked", "unavailable storage is visible")
	blocked.record_run(chapter)
	_check(blocked.has_starter("bell") and blocked.status == "blocked", "unavailable storage does not prevent local play and unlocks")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.path))
	var user_directory := DirAccess.open("user://")
	if user_directory != null:
		for filename in user_directory.get_files():
			if filename.begins_with("echo-witch-profile-test.json."):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + filename))
	print("Profile tests: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
