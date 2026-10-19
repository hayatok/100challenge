extends Node

const Run = preload("res://scripts/run_model.gd")
const Garden = preload("res://scripts/garden_view.gd")
const Interface = preload("res://scripts/interface.gd")
const Soundscape = preload("res://scripts/soundscape.gd")

var run = Run.new()
var garden
var interface
var soundscape
var snapshot_timer := 0.0
var previous_state := ""

func _ready() -> void:
	_register_inputs()
	garden = Garden.new()
	garden.run = run
	add_child(garden)
	soundscape = Soundscape.new()
	add_child(soundscape)
	var layer := CanvasLayer.new()
	add_child(layer)
	interface = Interface.new()
	interface.run = run
	layer.add_child(interface)
	interface.start_requested.connect(_start)
	interface.retry_requested.connect(_start)
	interface.resume_requested.connect(_resume)
	interface.title_requested.connect(_title)
	interface.pause_requested.connect(func() -> void: run.pause())
	interface.upgrade_requested.connect(_choose)
	interface.sound_changed.connect(func(value: bool) -> void: soundscape.set_enabled(value))
	interface.motion_changed.connect(func(value: bool) -> void: garden.reduced_motion = value)
	_publish_snapshot()

func _register_inputs() -> void:
	var bindings := {"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "walk_up": [KEY_W, KEY_UP], "walk_down": [KEY_S, KEY_DOWN]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
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
	if previous_state != run.state:
		if run.state == "paused":
			soundscape.pause_all(true)
		elif previous_state == "paused":
			soundscape.pause_all(false)
		previous_state = run.state

func _process(delta: float) -> void:
	garden.refresh()
	interface.refresh()
	snapshot_timer += delta
	if snapshot_timer >= 0.25:
		snapshot_timer = 0.0
		_publish_snapshot()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: Key = event.physical_keycode
	if code == KEY_ESCAPE:
		if run.state == "playing":
			run.pause()
		elif run.state == "paused":
			_resume()
		get_viewport().set_input_as_handled()
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		match str(run.state):
			"title", "victory", "defeat": _start()
			"paused": _resume()
	elif code == KEY_R and run.state in ["paused", "victory", "defeat"]:
		_start()
	elif run.state == "upgrade" and code in [KEY_1, KEY_2, KEY_3]:
		_choose(int(code) - int(KEY_1))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if run != null:
			run.pause("画面を離れたため休止。続けるには明示操作が必要です。")

func _start() -> void:
	soundscape.stop_all()
	run.reset(true)
	get_viewport().gui_release_focus()
	soundscape.play_event("start")
	_publish_snapshot()

func _resume() -> void:
	run.resume()
	get_viewport().gui_release_focus()
	_publish_snapshot()

func _title() -> void:
	soundscape.stop_all()
	run.reset(false)
	_publish_snapshot()

func _choose(index: int) -> void:
	if run.choose_upgrade(index):
		get_viewport().gui_release_focus()
		_publish_snapshot()

func _publish_snapshot() -> void:
	if not OS.has_feature("web"):
		return
	var data: Dictionary = run.snapshot()
	data.settings = {"sound": interface.sound_enabled, "reduced_motion": garden.reduced_motion}
	data.upgrade_choices = data.choices
	data.arena = {"bounded": false, "obstacles": false}
	var encoded := JSON.stringify(data)
	JavaScriptBridge.eval("(()=>{const freeze=o=>{Object.values(o).forEach(v=>{if(v&&typeof v==='object')freeze(v)});return Object.freeze(o)};Object.defineProperty(window,'echoWitchSnapshot',{value:freeze(" + encoded + "),writable:false,configurable:true})})()")
