extends SceneTree
var race: Node3D
var ticks: int = 0
var failed: int = 0
func check(condition: bool, message: String) -> void:
 if not condition:
  failed += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 race = load("res://scenes/race.tscn").instantiate()
 root.add_child(race)
 check(race.circuit.error.is_empty(), "Course must form a loop")
 check(race.circuit.length > 300.0, "Course length")
 var record = load("res://scripts/records.gd").new()
 check(record.valid_time("123") == 0.0, "Reject string record")
 check(record.valid_time(-1.0) == 0.0, "Reject negative record")
 check(record.valid_time(INF) == 0.0, "Reject infinite record")
 check(record.valid_time(90.5) == 90.5, "Accept valid record")
 race.records.storage_path = "user://test-records.cfg"
 race.records.best_lap = 0.0
 race.start(false)
 race.player.player = false
 race.player.pace = 1.0
func _physics_process(_delta: float) -> bool:
 if race == null:
  return false
 ticks += 1
 if ticks == 120:
  race.toggle_pause()
  var before: float = race.elapsed
  race._physics_process(1.0)
  check(race.elapsed == before, "Pause freezes timer")
  race.toggle_pause()
 if race.phase == race.Phase.RESULT or ticks > 60 * 360:
  print("CIRCUIT ",race.circuit.length," m; ticks ",ticks)
  for car in race.cars:
   print(car.driver_name," progress=",car.progress," laps=",car.total_laps," recoveries=",car.recovery_count," finish=",car.finish_time)
  check(race.player.total_laps == 3, "AI must finish three laps")
  check(race.player.recovery_count == 0, "Player model should negotiate course without recovery")
  var old_progress: float = race.player.progress
  race.phase = race.Phase.RACING
  race.player.finish_time = -1.0
  race.player.player = true
  race.player.position = Vector3(48, 0.31, -54)
  race.player.speed = 0.0
  race.player.throttle = 0.0
  race.player.step(1.0 / 60.0, race.elapsed)
  check(race.player.progress == old_progress, "Teleport shortcut must not count")
  race.player.recover()
  check(race.player.speed == 0.0 and race.player.velocity == Vector3.ZERO, "Recovery clears velocity")
  race.start(true)
  check(not race.cars[1].visible and race.cars[1].collision_layer == 0, "Time trial disables CPU collision")
  check(race.player.total_laps == 0 and race.elapsed == 0.0, "Restart resets lap and clock")
  race.phase = race.Phase.RACING
  var key := InputEventKey.new()
  key.physical_keycode = KEY_W
  key.keycode = KEY_W
  key.pressed = true
  Input.parse_input_event(key)
  Input.flush_buffered_events()
  race._physics_process(1.0 / 60.0)
  check(race.player.speed > 0.0, "Physical W accelerates")
  var release: InputEventKey = key.duplicate()
  release.pressed = false
  Input.parse_input_event(release)
  Input.flush_buffered_events()
  race.player.speed = 8.0
  race.touch_brake = true
  race._physics_process(1.0 / 60.0)
  check(race.player.speed < 8.0, "Brake slows the car")
  var gas: Control = race.get_node("HUD/Root/Controls/Gas")
  var left: Control = race.get_node("HUD/Root/Controls/Left")
  for touch_data in [[0, gas.get_global_rect().get_center()], [1, left.get_global_rect().get_center()]]:
   var event := InputEventScreenTouch.new()
   event.index = touch_data[0]
   event.position = touch_data[1]
   event.pressed = true
   race._input(event)
  check(race.touch_gas and race.touch_left, "Two fingers can accelerate and steer together")
  race.clear_touch()
  check(not race.touch_gas and not race.touch_left, "Focus loss clears touch controls")
  print("RACING CHECKS ", "PASS" if failed == 0 else "FAIL")
  DirAccess.remove_absolute("user://test-records.cfg")
  quit(1 if failed else 0)
 return false
