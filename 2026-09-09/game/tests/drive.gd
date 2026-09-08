extends SceneTree
var race: Node3D
var ticks: int = 0
var capturing: bool = false
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size = Vector2i(1440, 900)
 race = load("res://scenes/race.tscn").instantiate()
 root.add_child(race)
 race.records.storage_path = "user://drive-test-records.cfg"
 race.start(false)
 race.player.player = false
 race.player.pace = 1.0
func save_frame(filename: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../qa/" + filename)
func complete() -> void:
 for i in range(5):
  await process_frame
 await save_frame("finish-real-run.png")
 print("RENDERED DRIVE: 3 laps, ",race.elapsed," seconds, recoveries ",race.player.recovery_count)
 DirAccess.remove_absolute("user://drive-test-records.cfg")
 race.queue_free()
 await process_frame
 quit()
func _physics_process(_delta: float) -> bool:
 if race == null:
  return false
 ticks += 1
 if ticks == 1300:
  save_frame.call_deferred("driving-real-run.png")
 if race.phase == race.Phase.RESULT and not capturing:
  capturing = true
  complete.call_deferred()
 if ticks > 60 * 240:
  push_error("Real rendered drive timed out")
  quit(1)
 return false
