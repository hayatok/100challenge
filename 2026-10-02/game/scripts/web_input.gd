extends Node

# Keep the JavaScript callback alive for the lifetime of this node.
var game
var bridge: JavaScriptObject
var callback: JavaScriptObject
var last_snapshot := ""

func _ready() -> void:
    if not OS.has_feature("web"): return
    bridge = JavaScriptBridge.get_interface("BlackRelayMobile")
    if bridge == null: return
    callback = JavaScriptBridge.create_callback(_on_action)
    bridge.bindGame(callback)
    _sync()

func _process(_delta: float) -> void:
    _sync()

func _on_action(arguments: Array) -> void:
    if arguments.size() != 2: return
    # DOM buttons do not pass through Godot's canvas gesture handlers. Resume
    # the pinned 4.7.2 template's AudioContext while this user gesture is live.
    # The export script checks that this guarded adapter still exists.
    if str(arguments[0]) in ["menu", "begin"]:
        JavaScriptBridge.eval("if (typeof _godot_audio_resume === 'function') _godot_audio_resume();")
    game.web_action(str(arguments[0]), str(arguments[1]))
    # Synchronous state acknowledgement lets the same browser tap open the
    # keyboard, without a deferred focus that iOS may reject.
    _sync()

func _sync() -> void:
    if bridge == null: return
    var snapshot := JSON.stringify(game.web_snapshot())
    if snapshot == last_snapshot: return
    last_snapshot = snapshot
    bridge.update(snapshot)
