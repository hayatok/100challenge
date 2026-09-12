class_name KaijuGame
extends Node3D

static var restart_requested: bool = false
static var restart_loadout: int = -1

const SAVE_PATH := "user://marunomi-v05.json"
const MUTATION_NAMES := ["雷のツノ", "ドリルの頭", "バネの脚"]
var running: bool = false
var health: float = 100
var growth: int = 0
var eaten: int = 0
var combo: int = 0
var elapsed: float = 0
var player: KaijuPlayer
var boss: TownProp
var notice_left: float = 0
var bullets: Array[Dictionary] = []
var unlocked: Array[int] = []
var wins: int = 0
var selected_start: int = -1
var state: String = "title"
var pending_evolution: bool = false
var audio_cache: Dictionary = {}
var music: AudioStreamPlayer
var test_mode: bool = false
var hit_pause_active: bool = false
@onready var ui = $HUD

func _enter_tree() -> void:
	add_to_group("game")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as KaijuPlayer
	load_progress()
	ui.bind_game(self)
	ui.show_title()
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/town.wav")
	music.volume_db = -19
	add_child(music)
	if restart_requested:
		restart_requested = false
		selected_start = restart_loadout
		call_deferred("start")

func start() -> void:
	state = "play"
	running = true
	get_tree().paused = false
	if selected_start >= 0:
		set_mutation(selected_start)
	ui.show_play()
	notice("WASDで移動  ・  左クリックでかじる",4)
	if not test_mode:music.play()

func _process(delta: float) -> void:
	if running:
		elapsed += delta
		notice_left = maxf(0,notice_left-delta)
		if notice_left <= 0:ui.set_notice("")
		ui.refresh()
		if music and not music.playing and not test_mode:music.play()

func _physics_process(delta: float) -> void:
	if not running:return
	for i in range(bullets.size()-1,-1,-1):
		var bullet := bullets[i]
		var body: Node3D = bullet.node
		var end: Vector3 = body.global_position+bullet.velocity*delta
		var query := PhysicsRayQueryParameters3D.create(body.global_position,end,6)
		query.exclude = bullet.exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		bullet.life -= delta
		if not hit.is_empty():
			if hit.collider == player:
				player.hurt(15,body.global_position)
			elif hit.collider is TownProp:
				hit.collider.strike(bullet.velocity.normalized(),1,true)
			impact(hit.position,.5,Color("ffcf87"))
			body.queue_free()
			bullets.remove_at(i)
		elif bullet.life <= 0:
			body.queue_free()
			bullets.remove_at(i)
		else:
			body.global_position = end

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if state == "play":
				running = false
				state = "pause"
				get_tree().paused = true
				ui.show_pause()
			elif state == "pause":resume()
		elif state == "title" and event.physical_keycode == KEY_ENTER:start()

func resume() -> void:
	state = "play"
	running = true
	get_tree().paused = false
	ui.show_play()

func retry() -> void:
	restart_requested = true
	restart_loadout = selected_start
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_title() -> void:
	restart_requested = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func feed(amount: int, kind: int) -> void:
	growth += amount
	eaten += 1
	health = minf(100,health+(6 if kind >= 2 else 2))
	ui.pulse_growth()
	if player.stage == 0 and growth >= 100:
		player.grow_to(1)
		notice("ぐーんと成長！ 車もまるのみできる",3.4)
		pending_evolution = false
		queue_choice()
	elif player.stage == 1 and growth >= 340:
		player.grow_to(2)
		notice("大怪獣！ 戦車を食べ、ビルを崩そう",3.5)
		pending_evolution = true
		queue_choice()
	elif eaten == 1:
		notice("いい食べっぷり！ 車に向かってSpaceで突進",4)

func queue_choice() -> void:
	await get_tree().create_timer(.95).timeout
	choose_mutation()

func choose_mutation() -> void:
	if state != "play":return
	running = false
	state = "mutation"
	get_tree().paused = true
	ui.show_mutation(pending_evolution)

func set_mutation(index: int) -> void:
	if pending_evolution:
		player.evolved = true
	else:
		player.mutation = clampi(index,0,2)
		if not unlocked.has(player.mutation):
			unlocked.append(player.mutation)
			save_progress()
	update_mutation_model()
	get_tree().paused = false
	running = true
	state = "play"
	ui.show_play()
	notice(("変異が進化！ " if pending_evolution else "変異！ ")+MUTATION_NAMES[player.mutation]+"  右クリックで発動",4)

func update_mutation_model() -> void:
	for child in player.visual.find_children("MutationPart*", "Node3D", true, false):child.queue_free()
	var paths := ["res://scenes/mutation_lightning.tscn","res://scenes/mutation_drill.tscn","res://scenes/mutation_spring.tscn"]
	var component: PackedScene = load(paths[player.mutation])
	var hips := player.get_node("Visual/Model/Rig/Hips")
	if player.mutation < 2:
		hips.get_node("Head").add_child(component.instantiate())
	else:
		hips.get_node("LegL").add_child(component.instantiate())
		hips.get_node("LegR").add_child(component.instantiate())

func finish(won: bool) -> void:
	if state == "result":return
	running = false
	state = "result"
	if won:
		wins += 1
		save_progress()
		player.play_motion("joy")
		sound("victory",1)
	else:
		player.play_motion("hurt")
	ui.show_result(won)
	if music:music.stop()

func notice(message: String, seconds: float = 2.0) -> void:
	notice_left = seconds
	if is_instance_valid(ui):ui.set_notice(message)

func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .55
	if unshaded:mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func beam(from: Vector3, to: Vector3, color: Color, duration: float, width: float = .1) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = width
	shape.bottom_radius = width
	shape.height = maxf(.001,from.distance_to(to))
	shape.radial_segments = 8
	node.mesh = shape
	node.material_override = material(color,true)
	add_child(node)
	node.global_position = (from+to)*.5
	node.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	if duration > 0:
		var tween := node.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(node.queue_free)
	return node

func warning_line(from: Vector3, to: Vector3, width: float) -> Node3D:
	var direction := (to-from).normalized()
	return beam(from+Vector3.UP*.12,from+direction*22+Vector3.UP*.12,Color("f27850"),0,width)

func warning_circle(at: Vector3, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-.13
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 8
	node.mesh = torus
	node.material_override = material(Color("ef774e"),true)
	add_child(node)
	node.global_position = at+Vector3.UP*.13
	return node

func ring(at: Vector3, radius: float, color: Color, duration: float) -> void:
	var node := warning_circle(at,maxf(.3,radius))
	node.material_override = material(color,true)
	node.scale = Vector3.ONE*.3
	var tween := node.create_tween()
	tween.tween_property(node,"scale",Vector3.ONE,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(node.queue_free)

func impact(at: Vector3, strength: float, color: Color) -> void:
	if strength >= 1.0 and running and not test_mode and not hit_pause_active:hit_stop()
	ring(at,strength*1.8,color,.25)
	for i in 7:
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.18,.18,.38)*strength
		node.mesh = mesh
		node.material_override = material(color,true)
		add_child(node)
		node.global_position = at
		var direction := Vector3(cos(i*TAU/7),.45+randf()*.7,sin(i*TAU/7))
		var tween := node.create_tween().set_parallel(true)
		tween.tween_property(node,"position",at+direction*strength*1.6,.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node,"scale",Vector3.ZERO,.35)
		tween.chain().tween_callback(node.queue_free)

func hit_stop() -> void:
	hit_pause_active = true
	Engine.time_scale = .18
	await get_tree().create_timer(.04,true,false,true).timeout
	Engine.time_scale = 1.0
	hit_pause_active = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func debris(model: Node3D, at: Vector3) -> void:
	var meshes: Array[Node] = model.find_children("*","MeshInstance3D",true,false)
	var count := 0
	for child in meshes:
		if count >= 16:break
		if not child is MeshInstance3D:continue
		var bit := MeshInstance3D.new()
		bit.mesh = child.mesh
		add_child(bit)
		bit.global_transform = child.global_transform
		var end := bit.global_position+Vector3(randf_range(-4,4),-bit.global_position.y+.2,randf_range(-4,4))
		var tween := bit.create_tween().set_parallel(true)
		tween.tween_property(bit,"global_position",end,.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit,"rotation",Vector3(randf(),randf(),randf())*3,.65)
		tween.chain().tween_interval(3)
		tween.tween_property(bit,"scale",Vector3.ZERO,.5)
		tween.chain().tween_callback(bit.queue_free)
		count += 1
	impact(at,2,Color("f4dbac"))

func fire_shell(from: Vector3, aim: Vector3) -> void:
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .17
	sphere.height = .34
	body.mesh = sphere
	body.material_override = material(Color("ffe0a0"),true)
	add_child(body)
	var direction := (aim-from).normalized()
	body.global_position = from+direction*1.9
	var exclude: Array[RID] = []
	for target in get_tree().get_nodes_in_group("targets"):
		if target.global_position.distance_to(from) < 2:exclude.append(target.get_rid())
	bullets.append({"node":body,"velocity":direction*18,"life":1.25,"exclude":exclude})
	sound("shot",randf_range(.88,1.04),-7)

func sound(id: String, pitch: float = 1.0, volume: float = -4) -> void:
	if test_mode:return
	if not audio_cache.has(id):audio_cache[id] = load("res://assets/audio/"+id+".wav")
	var speaker := AudioStreamPlayer.new()
	speaker.stream = audio_cache[id]
	speaker.pitch_scale = pitch
	speaker.volume_db = volume
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()

func load_progress() -> void:
	if test_mode:return
	if not FileAccess.file_exists(SAVE_PATH):return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:return
	if parsed.get("version") != 1:return
	var saved = parsed.get("unlocked",[])
	if saved is Array:
		for item in saved:
			if (item is float or item is int) and int(item) in [0,1,2] and not unlocked.has(int(item)):
				unlocked.append(int(item))
	var saved_wins = parsed.get("wins",0)
	if saved_wins is float or saved_wins is int:wins = clampi(int(saved_wins),0,9999)

func save_progress() -> void:
	if test_mode:return
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"wins":wins}))
