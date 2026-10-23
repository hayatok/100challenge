extends Node

const Run = preload("res://scripts/run_model.gd")
const Garden = preload("res://scripts/garden_view.gd")
const Interface = preload("res://scripts/interface.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Profile = preload("res://scripts/profile.gd")
const SNAPSHOT_BRIDGE_NAME := "__echoWitchSnapshotPublisherInit"
const SNAPSHOT_BRIDGE_CLEAR := "delete window.__echoWitchSnapshotPublisherInit;"
const SNAPSHOT_BRIDGE_SETUP := """
(() => {
	const freeze = object => {
		for (const value of Object.values(object)) {
			if (value && typeof value === 'object') freeze(value);
		}
		return Object.freeze(object);
	};
	window.__echoWitchSnapshotPublisherInit = Object.freeze({
		publish(encoded) {
			const data = JSON.parse(encoded);
			Object.defineProperty(window, 'echoWitchSnapshot', {
				value: freeze(data), writable: false, configurable: true
			});
		}
	});
})()
"""

var run = Run.new()
var profile = Profile.new()
var garden
var interface
var soundscape
var snapshot_timer := 0.0
var previous_state := "title"
var previous_chapter := 0
var _snapshot_publisher
var _feedback_generation := -1
var _feedback_serial := 0

func _ready() -> void:
	_register_inputs()
	profile.load_profile()
	garden = Garden.new()
	garden.run = run
	add_child(garden)
	soundscape = Soundscape.new()
	add_child(soundscape)
	var layer := CanvasLayer.new()
	add_child(layer)
	interface = Interface.new()
	interface.run = run
	interface.profile = profile
	layer.add_child(interface)
	interface.start_requested.connect(_start)
	interface.retry_requested.connect(_start)
	interface.resume_requested.connect(_resume)
	interface.title_requested.connect(_title)
	interface.pause_requested.connect(func() -> void: run.pause())
	interface.upgrade_requested.connect(_choose)
	interface.next_chapter_requested.connect(_next_chapter)
	interface.reroll_requested.connect(_reroll)
	interface.skip_requested.connect(_skip)
	interface.cancel_replacement_requested.connect(_cancel_replacement)
	interface.setting_changed.connect(_setting_changed)
	interface.storage_retry_requested.connect(func() -> void:
		profile.retry_storage()
		_publish_snapshot())
	interface.storage_reset_requested.connect(func() -> void:
		profile.archive_invalid_and_reset()
		_apply_settings()
		_publish_snapshot())
	_apply_settings()
	_publish_snapshot()

func _register_inputs() -> void:
	var bindings := {"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "walk_up": [KEY_W, KEY_UP], "walk_down": [KEY_S, KEY_DOWN]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			if not InputMap.action_has_event(action, key):
				InputMap.action_add_event(action, key)

func _physics_process(delta: float) -> void:
	var movement := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	run.tick(delta, movement)
	var events: Array = run.drain_audio()
	var played: Dictionary = {}
	for event in events:
		if not played.has(event):
			soundscape.play_event(event)
			played[event] = true
	soundscape.set_scene(int(run.chapter), str(run.chapter_stage) == "boss")
	soundscape.set_context(str(run.state))
	_record_milestones()

func _record_milestones() -> void:
	if str(run.state) == previous_state and int(run.chapter) == previous_chapter:
		return
	previous_state = str(run.state)
	previous_chapter = int(run.chapter)
	if str(run.state) in ["chapter_clear", "victory", "defeat"]:
		profile.record_run(run.snapshot())
		_publish_snapshot()

func _process(delta: float) -> void:
	garden.refresh()
	_play_presentation_audio()
	interface.refresh()
	snapshot_timer += delta
	if snapshot_timer >= 0.25:
		snapshot_timer = 0.0
		_publish_snapshot()

func _play_presentation_audio() -> void:
	var feedback = garden.presentation
	if int(feedback.generation) != _feedback_generation:
		_feedback_generation = int(feedback.generation)
		_feedback_serial = 0
	for event in feedback.events:
		var serial := int(event.get("serial", 0))
		if serial <= _feedback_serial:
			continue
		_feedback_serial = serial
		if str(run.state) == "playing":
			soundscape.play_feedback(event, float(run.elapsed))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: Key = event.physical_keycode
	if interface.handle_shortcut(code):
		get_viewport().set_input_as_handled()
		return
	# A focused GUI control owns Enter. An open subpage never starts or resumes combat.
	if not interface.local_screen.is_empty():
		return
	var handled := true
	if code == KEY_ESCAPE:
		if run.state == "playing":
			run.pause()
		elif run.state == "paused":
			_resume()
		else:
			handled = false
	elif code in [KEY_ENTER, KEY_KP_ENTER] and get_viewport().gui_get_focus_owner() == null:
		match str(run.state):
			"title", "victory", "defeat": _start()
			"paused": _resume()
			"chapter_clear": _next_chapter()
			_: handled = false
	elif code == KEY_R and run.state in ["paused", "victory", "defeat"]:
		_start()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if run != null:
			run.pause("画面を離れたため休止しました。続けるには操作が必要です。")

func _start() -> void:
	var starter: String = interface.selected_starter
	if not profile.has_starter(starter):
		starter = "lightning"
		interface.selected_starter = starter
	soundscape.stop_all()
	profile.begin_run()
	interface.local_screen = ""
	interface.screen_history.clear()
	run.reset(true, 0, starter)
	previous_state = "playing"
	previous_chapter = 0
	get_viewport().gui_release_focus()
	soundscape.play_event("start")
	_publish_snapshot()

func _resume() -> void:
	if not interface.local_screen.is_empty():
		return
	run.resume()
	get_viewport().gui_release_focus()
	_publish_snapshot()

func _title() -> void:
	if str(run.state) != "title":
		profile.record_run(run.snapshot())
	soundscape.stop_all()
	interface.local_screen = ""
	interface.screen_history.clear()
	run.reset(false, 0, interface.selected_starter)
	previous_state = "title"
	previous_chapter = 0
	_publish_snapshot()

func _choose(index: int) -> void:
	if run.choose_upgrade(index):
		get_viewport().gui_release_focus()
		_publish_snapshot()

func _next_chapter() -> void:
	if run.next_chapter():
		get_viewport().gui_release_focus()
		soundscape.play_event("chapter")
		_publish_snapshot()

func _reroll() -> void:
	if run.reroll_choices():
		_publish_snapshot()

func _skip() -> void:
	if run.skip_choice():
		get_viewport().gui_release_focus()
		_publish_snapshot()

func _cancel_replacement() -> void:
	if run.cancel_replacement():
		_publish_snapshot()

func _setting_changed(key: String, value: Variant) -> void:
	profile.set_setting(key, value)
	_apply_settings(key == "large_text")
	_publish_snapshot()

func _apply_settings(rebuild_text: bool = false) -> void:
	var values: Dictionary = profile.settings()
	interface.sound_enabled = bool(values.sound)
	interface.reduced_motion = bool(values.reduced_motion)
	interface.large_text = bool(values.large_text)
	garden.reduced_motion = bool(values.reduced_motion)
	soundscape.set_enabled(bool(values.sound))
	soundscape.set_levels(float(values.music_volume), float(values.sfx_volume))
	if rebuild_text:
		interface._build_hud()
		interface.last_screen = ""

func _performance_snapshot() -> Dictionary:
	var values := {"fps": maxi(0, Engine.get_frames_per_second()), "effects": run.effects.size(), "projectiles": run.projectiles.size()}
	var monitors := {
		"objects": Performance.OBJECT_COUNT,
		"resources": Performance.OBJECT_RESOURCE_COUNT,
		"nodes": Performance.OBJECT_NODE_COUNT,
		"orphans": Performance.OBJECT_ORPHAN_NODE_COUNT,
		"static_bytes": Performance.MEMORY_STATIC,
		"static_peak_bytes": Performance.MEMORY_STATIC_MAX
	}
	for key in monitors:
		var value: float = Performance.get_monitor(monitors[key])
		# Release templates may report zero for unavailable monitors.
		values[key] = maxi(0, int(value)) if is_finite(value) else 0
	return values

func _snapshot_payload() -> Dictionary:
	var data: Dictionary = run.snapshot()
	data.perf = _performance_snapshot()
	data.motion = garden.motion_snapshot() if is_instance_valid(garden) else {}
	data.settings = profile.settings()
	data.profile = profile.snapshot()
	data.gui = {"page": interface.local_screen, "starter": interface.selected_starter, "codex_category": interface.codex_category, "controls": interface.control_snapshot()}
	data.audio = {"music_starts": soundscape.music_start_count, "music_active": soundscape.music_started, "music_paused": soundscape.music.stream_paused}
	data.upgrade_choices = data.choices
	var chapter: Dictionary = run.chapter_info()
	if data.get("arena") is Dictionary:
		data.arena.obstacle_count = chapter.get("obstacles", []).size()
	return data

func _initialize_snapshot_bridge() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(SNAPSHOT_BRIDGE_SETUP, true)
	_snapshot_publisher = JavaScriptBridge.get_interface(SNAPSHOT_BRIDGE_NAME)
	# Godot keeps the object reference; no publisher remains on the public window.
	JavaScriptBridge.eval(SNAPSHOT_BRIDGE_CLEAR, true)
	return _snapshot_publisher != null

func _publish_snapshot() -> void:
	if not OS.has_feature("web"):
		return
	if _snapshot_publisher == null and not _initialize_snapshot_bridge():
		push_error("Snapshot publisher could not be initialized.")
		return
	_snapshot_publisher.publish(JSON.stringify(_snapshot_payload()))
