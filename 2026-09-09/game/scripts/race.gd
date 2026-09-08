extends Node3D
const CIRCUIT = preload("res://scripts/circuit.gd")
const RECORDS = preload("res://scripts/records.gd")
const CAR_MESHES: Array[Mesh] = [preload("res://assets/racing/raceCarRed.obj"), preload("res://assets/racing/raceCarOrange.obj"), preload("res://assets/racing/raceCarGreen.obj"), preload("res://assets/racing/raceCarWhite.obj")]
enum Phase { MENU, COUNTDOWN, RACING, PAUSED, RESULT, ERROR }
var phase: Phase = Phase.MENU
var resume_phase: Phase = Phase.RACING
var circuit: RaceCircuit = CIRCUIT.new()
var records: RaceRecords = RECORDS.new()
var cars: Array[TinyRaceCar] = []
var grid: Array[Vector2] = []
var elapsed: float = 0.0
var countdown: float = 3.0
var time_trial: bool = false
var touch_left: bool = false
var touch_right: bool = false
var touch_gas: bool = false
var touch_brake: bool = false
var recent_laps: int = 0
var menu_layout_frames: int = 3
var touch_points: Dictionary = {}
var lap_notice: float = 0.0
@onready var player: TinyRaceCar = $Cars/Player
@onready var camera: Camera3D = $FollowCamera
@onready var ui: Control = $HUD/Root
@onready var menu: PanelContainer = $HUD/Root/Menu
@onready var title: Label = $HUD/Root/Menu/Padding/Stack/Title
@onready var summary: Label = $HUD/Root/Menu/Padding/Stack/Summary
@onready var race_button: Button = $HUD/Root/Menu/Padding/Stack/Race
@onready var trial_button: Button = $HUD/Root/Menu/Padding/Stack/Trial
@onready var colors: HBoxContainer = $HUD/Root/Menu/Padding/Stack/Colors
@onready var status: Label = $HUD/Root/Status
@onready var top: HBoxContainer = $HUD/Root/Top
@onready var map: Control = $HUD/Root/Map
@onready var sound: AudioStreamPlayer = $Sound

func _ready() -> void:
 if OS.has_feature("web"):
  sync_web_scale()
  get_window().size_changed.connect(sync_web_scale)
 records.read()
 for car in $Cars.get_children():
  cars.append(car)
 if not circuit.build($Course):
  phase = Phase.ERROR
  title.text = "コースを確認してください"
  summary.text = circuit.error
  race_button.disabled = true
  trial_button.disabled = true
  return
 for car in cars:
  car.circuit = circuit
  var p: Dictionary = circuit.project(car.global_position)
  var side: Vector3 = Vector3(p.direction).cross(Vector3.UP)
  grid.append(Vector2(float(p.s), (car.global_position - Vector3(p.position)).dot(side)))
 player.model.mesh = CAR_MESHES[records.color_index]
 race_button.pressed.connect(func() -> void: start(false))
 trial_button.pressed.connect(func() -> void: start(true))
 for i in range(colors.get_child_count()):
  colors.get_child(i).pressed.connect(choose_color.bind(i))
 $HUD/Root/Top/Pause.pressed.connect(toggle_pause)
 $HUD/Root/Recover.pressed.connect(recover_player)
 $HUD/Root/Mute.pressed.connect(toggle_sound)
 for item in [["Left", "left"], ["Right", "right"], ["Brake", "brake"], ["Gas", "gas"]]:
  var button: Button = $HUD/Root/Controls.get_node(item[0])
  button.button_down.connect(touch.bind(item[1], true))
  button.button_up.connect(touch.bind(item[1], false))
 ui.resized.connect(func() -> void: menu_layout_frames = 3)
 map.circuit = circuit
 map.cars = cars
 refresh_record_text()
 layout_ui()
 update_hud()

func choose_color(index: int) -> void:
 records.color_index = index
 player.model.mesh = CAR_MESHES[index]
 for i in range(colors.get_child_count()):
  colors.get_child(i).button_pressed = i == index
 records.write()

func refresh_record_text() -> void:
 summary.text = "みどりの丘サーキット / 3周\nカーブの前で減速。出口でアクセル！\nベストラップ  " + format_time(records.best_lap)
 for i in range(colors.get_child_count()):
  colors.get_child(i).button_pressed = i == records.color_index

func start(trial: bool) -> void:
 if phase == Phase.ERROR:
  return
 if phase == Phase.PAUSED and not trial:
  phase = resume_phase
  menu.hide()
  return
 time_trial = trial
 elapsed = 0.0
 countdown = 3.0
 recent_laps = 0
 lap_notice = 0.0
 for i in range(cars.size()):
  cars[i].reset_at(grid[i].x, grid[i].y)
  cars[i].visible = not trial or cars[i].player
  cars[i].collision_layer = 2 if cars[i].visible else 0
  cars[i].collision_mask = 3 if cars[i].visible else 0
  cars[i].active = false
 phase = Phase.COUNTDOWN
 menu.hide()
 clear_touch()
 sound.beep()
 snap_camera()
 update_hud()

func _physics_process(delta: float) -> void:
 if phase == Phase.ERROR:
  return
 if phase == Phase.COUNTDOWN:
  var previous: int = ceili(countdown)
  countdown -= delta
  if ceili(countdown) != previous:
   sound.beep(880.0 if countdown <= 0.0 else 660.0)
  if countdown <= 0.0:
   phase = Phase.RACING
 if phase == Phase.RACING:
  if not touch_points.is_empty():
   update_touches()
  elapsed += delta
  player.throttle = 1.0 if touch_gas or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0
  player.braking = touch_brake or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_SPACE)
  var left: bool = touch_left or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
  var right: bool = touch_right or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
  player.steer_input = float(left) - float(right)
  for car in cars:
   car.active = car.visible
   car.step(delta, elapsed)
  if player.total_laps > recent_laps:
   recent_laps = player.total_laps
   lap_notice = 3.0
   sound.beep(990.0)
  if player.finish_time >= 0.0:
   finish()
 lap_notice = maxf(0.0, lap_notice - delta)
 update_camera(delta)
 sound.speed = player.speed
 sound.driving = phase == Phase.RACING
 update_hud()
 map.queue_redraw()

func rank_of_player() -> int:
 var rank: int = 1
 for car in cars:
  if car == player or not car.visible:
   continue
  if car.finish_time >= 0.0:
   if player.finish_time < 0.0 or car.finish_time < player.finish_time:
    rank += 1
  elif player.finish_time < 0.0 and car.progress > player.progress:
   rank += 1
 return rank

func finish() -> void:
 phase = Phase.RESULT
 clear_touch()
 var new_best: bool = records.best_lap == 0.0 or player.best_lap < records.best_lap
 if new_best:
  records.best_lap = player.best_lap
 if not time_trial and (records.best_race == 0.0 or elapsed < records.best_race):
  records.best_race = elapsed
 records.write()
 title.text = "FINISH!" if time_trial else "%d位でフィニッシュ！" % rank_of_player()
 summary.text = "3周完走  %s\n最速ラップ  %s%s\n%s" % [format_time(elapsed), format_time(player.best_lap), "  自己ベスト！" if new_best else "", "記録を保存しました。" if records.save_ok else "記録を保存できませんでした。"]
 race_button.text = "もう一度レース"
 trial_button.text = "タイムアタック"
 menu.show()
 menu_layout_frames = 3
 layout_ui()
 race_button.grab_focus()

func toggle_pause() -> void:
 if phase == Phase.PAUSED:
  phase = resume_phase
  menu.hide()
 elif phase in [Phase.RACING, Phase.COUNTDOWN]:
  resume_phase = phase
  phase = Phase.PAUSED
  title.text = "ひとやすみ"
  summary.text = "走行とタイマーを一時停止しています。\nEsc または「走行を再開」で続けられます。"
  race_button.text = "走行を再開"
  trial_button.text = "最初からタイムアタック"
  menu.show()
  menu_layout_frames = 3
  clear_touch()
  layout_ui()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  clear_touch()
  if phase in [Phase.RACING, Phase.COUNTDOWN]:
   toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode == KEY_ESCAPE:
   toggle_pause()
  elif event.physical_keycode == KEY_R:
   recover_player()
  elif event.physical_keycode == KEY_M:
   toggle_sound()

func recover_player() -> void:
 if phase == Phase.RACING:
  player.recover()
  snap_camera()
  lap_notice = 0.0

func toggle_sound() -> void:
 sound.muted = not sound.muted
 $HUD/Root/Mute.text = "音 OFF" if sound.muted else "音 ON"

func touch(action: String, pressed: bool) -> void:
 match action:
  "left": touch_left = pressed
  "right": touch_right = pressed
  "gas": touch_gas = pressed
  "brake": touch_brake = pressed

func clear_touch() -> void:
 touch_points.clear()
 touch_left = false
 touch_right = false
 touch_gas = false
 touch_brake = false

func snap_camera() -> void:
 var forward := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
 camera.position = player.position - forward * 11.0 + Vector3(0, 8, 0)
 camera.look_at(player.position + forward * 8.0)

func update_camera(delta: float) -> void:
 if phase == Phase.MENU:
  return
 var forward := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
 var target: Vector3 = player.position - forward * (11.0 + player.speed * 0.1) + Vector3(0, 8, 0)
 camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 6.0))
 camera.look_at(player.position + forward * 8.0)

func update_hud() -> void:
 top.get_node("Place").text = "TIME ATTACK" if time_trial else "%d / 4 位" % rank_of_player()
 top.get_node("Lap").text = "LAP %d / 3" % mini(player.total_laps + 1, 3)
 top.get_node("Clock").text = "00:00.000" if elapsed == 0.0 else format_time(elapsed)
 $HUD/Root/Speed.text = "%02d\nkm/h" % roundi(player.speed * 3.6)
 $HUD/Root/Controls.visible = phase in [Phase.RACING, Phase.COUNTDOWN]
 $HUD/Root/Recover.visible = phase == Phase.RACING
 top.visible = phase != Phase.MENU
 map.visible = phase != Phase.MENU
 $HUD/Root/Speed.visible = phase in [Phase.RACING, Phase.COUNTDOWN]
 $HUD/Root/Hint.visible = phase == Phase.MENU
 status.text = ""
 if phase == Phase.COUNTDOWN:
  status.text = str(ceili(countdown))
 elif phase == Phase.RACING:
  if elapsed < 1.0:
   status.text = "GO!"
  elif player.invalid_jump:
   status.text = "R / コースへ戻る で復帰"
  elif player.road_distance > 5.1:
   status.text = "芝生で減速中"
  elif lap_notice > 0.0:
   status.text = "LAP  %s" % format_time(player.last_lap)
 status.visible = not status.text.is_empty()

func layout_ui() -> void:
 var w: float = ui.size.x
 var h: float = ui.size.y
 var narrow: bool = w < 640.0
 var panel_width: float = minf(w - 28.0, 510.0)
 title.add_theme_font_size_override("font_size", 26 if narrow else 42)
 summary.add_theme_font_size_override("font_size", 14 if narrow else 17)
 menu.size = Vector2(panel_width, 0)
 menu.position = Vector2(40.0 if w >= 1100.0 and phase == Phase.MENU else (w - panel_width) * 0.5, maxf(70.0, (h - menu.size.y) * 0.5))
 for item in top.get_children():
  item.add_theme_font_size_override("font_size", 14 if narrow else 21)
 map.size = Vector2(112, 112) if narrow else Vector2(180, 180)
 map.position = Vector2(w - map.size.x - 12, h - map.size.y - 110)
 $HUD/Root/Speed.position = Vector2(20, h - 218)
 $HUD/Root/Hint.text = "WASD / 矢印: 運転   Space: ブレーキ\nR: コースへ戻る   Esc: 一時停止" if not narrow else "画面下のボタンでも運転できます"
 $HUD/Root/Hint.visible = phase == Phase.MENU

func format_time(value: float) -> String:
 if value <= 0.0 or not is_finite(value):
  return "--:--.---"
 var ms: int = int(round(value * 1000.0))
 return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

func _process(_delta: float) -> void:
 if menu_layout_frames > 0:
  layout_ui()
  menu_layout_frames -= 1

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   touch_points[event.index] = event.position
  else:
   touch_points.erase(event.index)
  update_touches()
 elif event is InputEventScreenDrag:
  touch_points[event.index] = event.position
  update_touches()

func update_touches() -> void:
 touch_left = false
 touch_right = false
 touch_gas = false
 touch_brake = false
 if phase != Phase.RACING:
  return
 for point: Vector2 in touch_points.values():
  for item in [["Left", "left"], ["Right", "right"], ["Brake", "brake"], ["Gas", "gas"]]:
   var button: Control = $HUD/Root/Controls.get_node(item[0])
   if button.get_global_rect().has_point(point):
    touch(item[1], true)

func sync_web_scale() -> void:
 # Godot's Web canvas uses device pixels; author UI in browser CSS pixels.
 var ratio: float = maxf(1.0, float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true)))
 var logical_size := Vector2i(Vector2(get_window().size) / ratio)
 if get_window().content_scale_size != logical_size:
  get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
  get_window().content_scale_size = logical_size
  menu_layout_frames = 3
