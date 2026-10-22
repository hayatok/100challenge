extends SceneTree

const Sound = preload("res://scripts/soundscape.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var audio = Sound.new()
	root.add_child(audio)
	expect(audio.themes.size() == 4, "four locally bundled music themes")
	audio.set_context("playing")
	expect(audio.music_start_count == 1, "explicit first start")
	for i in range(300):
		audio.set_context("playing")
		audio.set_scene(0, false)
	expect(audio.music_start_count == 1, "unchanged per-frame contexts never restart music")
	audio.set_context("upgrade")
	expect(audio.music.stream_paused, "upgrade freezes music")
	audio.set_context("playing")
	expect(audio.music_start_count == 1 and not audio.music.stream_paused, "upgrade resumes same stream")
	audio.set_context("treasure")
	expect(audio.music.stream_paused, "treasure freezes music")
	audio.set_context("playing")
	audio.set_scene(0, true)
	expect(audio.scene_key == "boss" and audio.music_start_count == 2, "boss theme changes once")
	audio.set_context("chapter_clear")
	expect(audio.music.stream_paused, "chapter map freezes music")
	audio.set_scene(1, false)
	expect(audio.scene_key == "mirror" and not audio.music_started and audio.music_start_count == 2, "chapter theme waits while map is open")
	audio.set_context("playing")
	expect(audio.music_start_count == 3, "next chapter starts once")
	audio.set_levels(0.0, 0.0)
	expect(not audio.music_started, "zero music volume stops playback")
	audio.set_levels(0.5, 0.7)
	expect(audio.music_started and audio.music_start_count == 4, "unmute starts once")
	audio.set_enabled(false)
	expect(not audio.music_started, "master sound off stops playback")
	audio.set_enabled(true)
	expect(audio.music_start_count == 5, "master sound on starts once")
	audio.set_context("paused")
	expect(audio.music.stream_paused, "pause freezes music")
	audio.stop_all()
	expect(not audio.music_started, "retry stops old stream")
	for id in ["thorn", "wisp", "frost", "bell", "treasure", "evolution", "boss", "chapter"]:
		expect(audio.sounds.has(id), "event " + id + " has a sound")
	audio.stop_all()
	await create_timer(0.2).timeout
	await process_frame
	await process_frame
	audio.free()
	await process_frame
	print("AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
