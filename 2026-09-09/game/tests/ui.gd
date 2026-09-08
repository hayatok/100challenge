extends SceneTree
var failures: int = 0
func _initialize() -> void:
 call_deferred("run")
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func settled() -> void:
 for i in range(4):
  await process_frame
func run() -> void:
 var race: Node3D = load("res://scenes/race.tscn").instantiate()
 root.add_child(race)
 await settled()
 race.set_physics_process(false)
 race.records.storage_path = "user://ui-test-records.cfg"
 var render: bool = DisplayServer.get_name() != "headless"
 DirAccess.make_dir_recursive_absolute("res://../qa")
 for viewport_size in [Vector2i(375,812), Vector2i(768,1024), Vector2i(1024,768), Vector2i(1440,900)]:
  root.size = viewport_size
  race.phase = race.Phase.MENU
  race.title.text = "ちび車グランプリ"
  race.refresh_record_text()
  race.menu.show()
  await settled()
  race.layout_ui()
  race.update_hud()
  await settled()
  var rect: Rect2 = race.menu.get_global_rect()
  print(viewport_size, " root=",race.ui.size," menu=",rect)
  check(rect.position.x >= 0 and rect.end.x <= viewport_size.x + 1, "Menu fits width %d" % viewport_size.x)
  check(rect.end.y <= viewport_size.y - 12, "Menu fits height %d" % viewport_size.y)
  check(race.title.get_line_count() == 1, "Title stays on one line")
  if render:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../qa/menu-%d.png" % viewport_size.x)
  race.start(false)
  race.phase = race.Phase.RACING
  race.elapsed = 12.0
  race.snap_camera()
  race.layout_ui()
  race.update_hud()
  await settled()
  var controls: Control = race.get_node("HUD/Root/Controls")
  check(controls.get_global_rect().end.x <= viewport_size.x, "Driving buttons fit")
  check(not race.get_node("HUD/Root/Hint").visible, "Menu hint does not overlap driving controls")
  if render:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../qa/race-%d.png" % viewport_size.x)
  race.toggle_pause()
  await settled()
  race.layout_ui()
  check(race.menu.get_global_rect().end.x <= viewport_size.x + 1, "Pause fits")
  race.toggle_pause()
  race.player.best_lap = 31.234
  race.player.finish_time = 96.432
  race.player.total_laps = 3
  race.elapsed = 96.432
  race.finish()
  await settled()
  race.layout_ui()
  await settled()
  check(race.menu.get_global_rect().end.x <= viewport_size.x + 1, "Result fits %d" % viewport_size.x)
  if render:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../qa/result-%d.png" % viewport_size.x)
 DirAccess.remove_absolute("user://ui-test-records.cfg")
 print("RESPONSIVE UI CHECKS ", "PASS" if failures == 0 else "FAIL")
 race.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
