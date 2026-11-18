extends Node3D

signal spawn_wave(kinds: Array, positions: Array)
signal encounter_changed(checkpoint: int)
signal chapter_finished
signal bell_rang(point: Vector3)
signal rush_discharge(point: Vector3, radius: float)
signal sound(event: String, point: Vector3)
signal objective(text: String)
signal supplied

const PROP = preload("res://world/prop.gd")
const RUSH_BELL = preload("res://world/rush_bell.gd")
var chapter := 0
var checkpoint := 0
var wave := 0
var armed := false
var fighting := false
var cleared := false
var finished := false
var gates: Array[StaticBody3D] = []
var mats: Dictionary = {}
var exit_switch: Node3D
var ramp: Node3D
var intro_shutter: Node3D
var rng := RandomNumberGenerator.new()
var rally_active := false
var rally_target := Vector3.ZERO
var wave_pending := false
var rally_marker: Node3D
var warning_light: OmniLight3D
var detour_phase := 0
var detour_fight := 0
var route_points: Array[Vector3] = []
var service_exit: StaticBody3D
var service_lights: Array[OmniLight3D] = []
var rush_bells: Array[RUSH_BELL] = []
var rush_warning_lights: Array[OmniLight3D] = []
var rush_warning_left := 0.0

func build_rush() -> void:
	_reset(0, 0, 0.34)
	_shell(0)
	_market(0, false)
	intro_shutter.position.y = 7.35
	# Seal the edge of the market floor and give the far spawn line a loading shutter.
	_box(Vector3(0, 3.5, 0.12), Vector3(28, 7, 0.5), "steel")
	_box(Vector3(0, 3.5, -35.9), Vector3(28, 7, 0.7), "steel")
	_box(Vector3(0, 2.3, -35.48), Vector3(13.6, 4.6, 0.2), "black", false)
	for slat in range(16):
		_box(Vector3(0, 0.24 + slat * 0.27, -35.33), Vector3(13.5, 0.24, 0.125), "steel", false)
	_lamp(Vector3(-6, 5.7, -9), Color("72e9cc"), 2.05)
	_lamp(Vector3(-4.8, 5.5, -23.5), Color("73d9d1"), 2.05)
	_lamp(Vector3(8.3, 5.3, -12.8), Color("f3ab55"), 2.5)
	_lamp(Vector3(6, 5.4, -27), Color("ffba72"), 2.5)
	_rush_trusses()
	_floor_details(0)
	_add_rush_bell(Vector3(-3.45, 0, -8.8))
	_add_rush_bell(Vector3(3.8, 0, -24.4))
	for position in [Vector3(-4, 3.2, -34.7), Vector3(4, 3.2, -34.7),
			Vector3(-4, 3.2, -0.65), Vector3(4, 3.2, -0.65)]:
		var beacon := OmniLight3D.new()
		beacon.position = position
		beacon.light_color = Color("ff512e")
		beacon.omni_range = 9.0
		beacon.light_energy = 3.1
		beacon.visible = false
		add_child(beacon)
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.37, 0.16, 0.18)
		marker.mesh = mesh
		var red := StandardMaterial3D.new()
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red.albedo_color = Color("ff522e")
		marker.material_override = red
		beacon.add_child(marker)
		rush_warning_lights.append(beacon)

func _rush_trusses() -> void:
	# Box beams and braces give the open shutter a visible frame and break up the ceiling.
	for z in [-7.0, -16.6, -25.5, -34.3]:
		_box(Vector3(0, 6.42, z), Vector3(27.1, 0.16, 0.2), "black", false)
		_box(Vector3(0, 6.96, z), Vector3(27.1, 0.16, 0.2), "black", false)
		for segment in range(8):
			var brace := _box(Vector3((float(segment) - 3.5) * 3.3, 6.7, z),
				Vector3(3.45, 0.14, 0.16), "steel", false)
			brace.rotation.z = 0.164 if segment % 2 == 0 else -0.164

func _add_rush_bell(point: Vector3) -> void:
	var bell := RUSH_BELL.new()
	bell.position = point
	bell.setup(rush_bells.size() + 1, mats.steel, mats.yellow)
	bell.add_to_group("rush_bells")
	add_child(bell)
	rush_bells.append(bell)
	bell.lure.connect(func(center: Vector3):
		bell_rang.emit(center)
		sound.emit("bell", center)
	)
	bell.discharge.connect(func(center: Vector3, radius: float):
		rush_discharge.emit(center, radius)
		sound.emit("discharge", center)
	)

func set_rush_flash(enabled: bool) -> void:
	for bell in rush_bells:
		bell.set_flash(enabled)

func rush_bell_ready() -> bool:
	for bell in rush_bells:
		if bell.state == RUSH_BELL.State.READY:
			return true
	return false

func rush_spawn_points(wave_index: int, count: int, player_position: Vector3) -> Array:
	# Each lane is between the fish stalls. Start at the far shutter, then rotate sides and ends.
	var order := [0, 1, 3, 0, 2, 1, 2, 3]
	var lane: int = order[posmod(wave_index, order.size())]
	var positions: Array = []
	if count <= 0:
		return positions
	for flank in [lane, lane ^ 1, lane ^ 3, lane ^ 2]:
		var side := -1.0 if flank % 2 == 0 else 1.0
		var back: bool = flank < 2
		for row in range(3):
			for x in [2.15, 4.0, 5.65]:
				var depth := -33.6 + row * 1.6 if back else -1.7 - row * 1.6
				var point := Vector3(side * x, 0.2, depth)
				if point.distance_squared_to(player_position) >= 9.0 * 9.0:
					positions.append(point)
					if positions.size() == count:
						return positions
	return positions

func warn_rush_spawns(points: Array, seconds: float) -> void:
	rush_warning_left = seconds
	for beacon in rush_warning_lights:
		beacon.visible = false
	if seconds <= 0.0:
		return
	for point: Vector3 in points:
		var lane := (0 if point.z < -18 else 2) + (0 if point.x < 0.0 else 1)
		if lane < rush_warning_lights.size():
			rush_warning_lights[lane].visible = true

func _reset(chapter_index: int, checkpoint_index: int, ambient := -1.0) -> void:
	chapter = clampi(chapter_index, 0, 2)
	checkpoint = clampi(checkpoint_index, 0, 2)
	rng.seed = 417
	intro_shutter = null
	rally_active = false
	wave_pending = false
	rally_marker = null
	detour_phase = 0
	detour_fight = 0
	route_points.clear()
	service_lights.clear()
	rush_bells.clear()
	rush_warning_lights.clear()
	rush_warning_left = 0.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	gates.clear()
	mats.clear()
	wave = 0
	armed = false
	fighting = false
	cleared = false
	finished = false
	_materials()
	_environment(ambient)

func build(chapter_index: int, checkpoint_index: int) -> void:
	_reset(chapter_index, checkpoint_index)
	for bay in range(3):
		_shell(bay)
		match chapter:
			0: _market(bay)
			1: _freezer(bay)
			2: _ferry(bay)
		var gate := _box(Vector3(0, 3.0, -float(bay + 1) * 36), Vector3(6, 27, 0.5), "steel")
		gate.rotation.z = PI / 2
		gate.set_meta("animated", true)
		gates.append(gate)
		if bay < checkpoint:
			gate.position.y = 10
		if chapter != 0 or bay != 0:
			_sign(["競り場", "冷凍庫", "車両甲板"][chapter] + "  /  0" + str(bay + 1), Vector3(0, 5.7, -float(bay) * 36 - 16), 0.016)
		_lamp(Vector3(-6, 5.8, -float(bay) * 36 - 10), Color("7df1d6") if chapter == 0 else (Color("88caff") if chapter == 1 else Color("ffc383")))
		_lamp(Vector3(6, 5.8, -float(bay) * 36 - 25), Color("ffbb72") if chapter != 1 else Color("88caff"))
		_floor_details(bay)
	_box(Vector3(0, -0.3, -115), Vector3(28, 0.6, 14), "floor")
	_box(Vector3(-14, 3, -115), Vector3(1, 6, 14), "steel")
	_box(Vector3(14, 3, -115), Vector3(1, 6, 14), "steel")
	_box(Vector3(0, 3, -122), Vector3(28, 6, 1), "steel")
	exit_switch = _box(Vector3(0, 1.1, -116), Vector3(1.4, 2.2, 0.8), "yellow")
	_sign("ランプ操作" if chapter == 2 else "出口", Vector3(0, 3, -116))
	if chapter == 2:
		ramp = _box(Vector3(0, -0.1, -111), Vector3(8, 0.2, 6), "yellow")
		ramp.set_meta("animated", true)
	_build_detour()
	for child in get_children():
		if child is OmniLight3D and absf(child.position.x) < 14 and child.position.z < -36 and child.position.z > -72:
			service_lights.append(child)
			child.light_energy *= 0.3
	_build_rally()
	_objective()

func spawn_position() -> Vector3:
	return Vector3(0, 0.15, -float(checkpoint) * 36 - 3)

func spawn_yaw() -> float:
	return 0.0

func start_encounter() -> void:
	armed = true
	_objective()
	if chapter == 0 and checkpoint == 0:
		fighting = true
		_launch_wave()
		if is_instance_valid(intro_shutter):
			create_tween().tween_property(intro_shutter, "position:y", 6.8, 2.8).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if rush_warning_left > 0.0:
		rush_warning_left -= delta
		if rush_warning_left <= 0.0:
			for beacon in rush_warning_lights:
				beacon.visible = false
	if not armed or finished:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if rally_active and player.global_position.distance_to(rally_target) < 2.2:
		_step_route()
	if not fighting and not cleared and player.global_position.z < -float(checkpoint) * 36 - 7:
		fighting = true
		_announce_wave()
	if cleared:
		if checkpoint < 2 and player.global_position.z < -float(checkpoint + 1) * 36 - 2:
			checkpoint += 1
			wave = 0
			cleared = false
			encounter_changed.emit(checkpoint)
			_objective()
		elif checkpoint == 2 and player.global_position.distance_to(exit_switch.global_position) < 2.8:
			finished = true
			armed = false
			sound.emit("gate", exit_switch.global_position)
			if chapter == 2 and is_instance_valid(ramp):
				var tween := create_tween()
				tween.tween_property(ramp, "rotation:x", -1.15, 2.0)
				tween.tween_callback(func(): chapter_finished.emit())
			else:
				chapter_finished.emit()

func notify_clear() -> void:
	if not fighting or wave_pending or rally_active:
		return
	if detour_fight > 0:
		detour_fight = 0
		_begin_route(2 if detour_phase == 1 else 3)
		return
	wave += 1
	if wave < (3 if checkpoint < 2 else 2):
		if checkpoint == 1 and wave == 1:
			_begin_route(1)
		else:
			_announce_wave()
	else:
		fighting = false
		cleared = true
		var tween := create_tween()
		tween.tween_property(gates[checkpoint], "position:y", 10.0, 2.0)
		sound.emit("gate", gates[checkpoint].position)
		supplied.emit()
		objective.emit("補給完了。開いたシャッターの先へ。" if checkpoint < 2 else ("船尾の黄色い装置に近づき、ランプを上げる。" if chapter == 2 else "奥の出口へ進む。"))

func _launch_wave() -> void:
	if detour_fight > 0:
		_spawn_detour()
		return
	var kinds: Array = []
	var positions: Array = []
	var count := 5 + chapter * 2 + checkpoint + wave * 2
	for i in range(count):
		kinds.append(1 if i % 4 == 0 else (2 if i % 5 == 0 else 0))
		positions.append(Vector3(-5.0 + float(i % 5) * 2.5, 0.2, -float(checkpoint) * 36 - 26 - float(i / 5) * 2.5))
	if checkpoint == 2 and wave == 1:
		if chapter == 2:
			kinds.append(3)
			positions.append(Vector3(0, 0.2, -float(checkpoint) * 36 - 29))
		else:
			for side in [-1.0, 1.0]:
				kinds.append(2)
				positions.append(Vector3(side * 5, 0.2, -float(checkpoint) * 36 - 33))
	if chapter == 0 and checkpoint == 0 and wave == 0:
		positions = [Vector3(0.7, 0.2, -10.5), Vector3(-4.5, 0.2, -18.7), Vector3(-2.3, 0.2, -20.0), Vector3(3.7, 0.2, -19.5), Vector3(5.4, 0.2, -22.0)]
		kinds = [0, 0, 1, 0, 1]
	if wave > 0:
		for i in range(positions.size()):
			if wave == 1:
				positions[i] = Vector3((-5.5 if i % 2 == 0 else 5.5), 0.2, -checkpoint * 36 - 24 - (i / 2) * 1.3)
			else:
				positions[i] = Vector3(-4.5 + (i % 4) * 3.0, 0.2, -checkpoint * 36 - 30 - (i / 4) * 1.1)
	wave_pending = false
	spawn_wave.emit(kinds, positions)
	var goals := [
		["黄色い鐘を撃つと群れが集まる。競り場のシャッターを突破する。", "競り台を確保し、左の非常配電室への入口を開く。", "荷捌き場を制圧し、冷凍庫への扉を開く。"],
		["赤い金具を撃って吊り荷を落とす。冷却通路を進む。", "冷却通路を確保し、右上段の圧縮機室へ向かう。", "氷柱の間で潜水夫を止め、車両甲板へ向かう。"],
		["車列の間を突破する。左右の鐘で群れを誘導できる。", "車列を確保し、右舷歩廊のウインチ電源へ向かう。", "船長を倒し、奥の黄色いランプ装置へ。"]]
	if checkpoint == 1 and detour_phase == 4:
		objective.emit(["電源復帰。外売場の増援を倒し、搬送シャッターを開く。", "解凍した搬出口を確保し、奥の冷却区画へ。", "通電した車列を突破し、船長の待つ船尾へ。"][chapter])
	else:
		objective.emit(goals[chapter][checkpoint])

func _objective() -> void:
	objective.emit(["黄色い鐘は銃で鳴らせる。競り場の奥へ。", "赤い吊り金具を撃つと荷が落ちる。冷凍庫の奥へ。", "船首へ進み、甲板を制圧する。"][chapter])

func _materials() -> void:
	var palette := {"floor": Color("42585a"), "steel": Color("657277"), "white": Color("d6d9c9"), "yellow": Color("d5a539"), "blue": Color("355772"), "red": Color("994d40"), "ice": Color("acc8ce"), "wood": Color("77614b"), "black": Color("354047"), "water": Color("35516c")}
	for key in palette:
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in range(64):
			for x in range(64):
				var c: Color = palette[key]
				var grain := rng.randf_range(0.98, 1.02)
				match key:
					"steel":
						c *= 0.8 + 0.2 * sin(float(y % 12) / 12.0 * TAU)
						if (x * 17 + 11) % 61 < 5 and y < 5 + (x * 7) % 19:
							c = c.lerp(Color("865339"), 0.7)
						if (x % 32 < 2 and y % 32 < 2): c = Color("b2b2a1")
					"floor":
						if x % 32 == 0 or y % 32 == 0: c *= 0.65
						if sin(x * 0.18) + cos(y * 0.23) > 0.9: c *= 0.85
					"white":
						if y % 32 < 2: c *= 0.8
						if (x * 13 + y * 7) % 79 == 0: c *= 0.87
					"yellow":
						if (x + y) % 40 < 13: c = Color("454a42")
					"ice":
						if sin(x * 0.13 + y * 0.08) > 0.8 or y % 31 < 3: c = c.lightened(0.3)
					"wood":
						if x % 16 == 0: c *= 0.65
						grain += sin(x * 2.1 + y * 0.1) * 0.03
					"water":
						grain += sin(x * 0.5 + y * 2.0) * 0.07
				img.set_pixel(x, y, c * grain)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.2 if key == "floor" or key == "ice" else 0.85
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
		mats[key] = mat
	for pair in [["steel", "corrugated", 0.25], ["floor", "deck" if chapter == 2 else "wet_floor", 0.19]]:
		var material: StandardMaterial3D = mats[pair[0]]
		material.albedo_texture = load("res://world/surfaces/%s.png" % pair[1])
		material.uv1_scale = Vector3.ONE * float(pair[2])
	var crate := StandardMaterial3D.new()
	crate.albedo_texture = load("res://world/surfaces/fish_crate.png")
	crate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mats["crate_print"] = crate
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.65, 0.84, 0.9, 0.23)
	plastic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastic.roughness = 0.16
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["plastic"] = plastic
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e0ac3b")
	gold.metallic = 0.6
	gold.roughness = 0.4
	gold.emission_enabled = true
	gold.emission = Color("5a3d0e")
	gold.emission_energy_multiplier = 0.35
	mats["gold"] = gold

func _box(pos: Vector3, size: Vector3, material: String, solid := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1 if solid else 0
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mats[material]
	body.add_child(mesh)
	if solid:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		body.add_child(col)
	add_child(body)
	return body

func _shell(bay: int) -> void:
	var z := -float(bay) * 36 - 18
	_box(Vector3(0, -0.3, z), Vector3(28, 0.6, 36), "floor")
	for side in [-1.0, 1.0]:
		if bay == 1 and side == (-1.0 if chapter == 0 else 1.0):
			var doors := [-48.0, -66.0] if chapter == 0 else ([-54.0, -66.0] if chapter == 1 else [-54.0, -68.0])
			var top := -36.0
			for door in doors:
				var edge: float = door + 2.6
				_box(Vector3(side * 14, 3.5, (top + edge) * 0.5), Vector3(0.7, 7, top - edge), "steel")
				top = door - 2.6
			if top > -72:
				_box(Vector3(side * 14, 3.5, (top - 72) * 0.5), Vector3(0.7, 7, top + 72), "steel")
		else:
			_box(Vector3(side * 14, 0.7 if chapter == 2 else 3.5, z), Vector3(0.7, 1.4 if chapter == 2 else 7.0, 36), "white" if chapter == 2 else "steel")
	if chapter < 2:
		_box(Vector3(0, 7.3, z), Vector3(28, 0.5, 36), "black")
	for offset in [-14.0, -3.0, 9.0]:
		_box(Vector3(0, 6.6, z + offset), Vector3(28, 0.4, 0.4), "black", false)
		for side in [-1.0, 1.0]:
			_box(Vector3(side * 12.8, 3.3, z + offset), Vector3(0.6, 6.6, 0.6), "yellow")
	for x in [-4.0, 4.0]:
		_box(Vector3(x, 0.012, z), Vector3(0.14, 0.02, 35), "yellow", false)
	if bay == 0:
		_box(Vector3(0, 3.5, 1), Vector3(28, 7, 0.5), "steel")

func _market(bay: int, campaign_bells := true) -> void:
	var z := -float(bay) * 36
	for side in [-1.0, 1.0]:
		for row in range(4 if bay == 0 else 2):
			var p := Vector3(side * 9, 0.6, z - 9 - row * (6 if bay == 0 else 16))
			_box(p, Vector3(4, 1.2, 2.8), "white")
			_box(p + Vector3(0, 0.7, 0), Vector3(3.9, 0.18, 2.7), "ice", false)
			for fish in range(3):
				_fish(p + Vector3(-1.1 + fish, 0.85, 0))
			for printed in range(3):
				_crate_face(p + Vector3(-1.3 + printed * 1.3, 0, 1.42), Vector2(1.27, 1.1))
		for strip in range(5):
			_box(Vector3(side * 10 + strip * 0.62 - 1.2, 4.7, z - 13), Vector3(0.57, 1.3, 0.07), "blue", false)
	_box(Vector3(12.25, 2.7, z - 3), Vector3(1.1, 2.3, 0.12), "white", false)
	_sign("場内\n禁煙", Vector3(12.25, 2.7, z - 2.91), 0.012)
	_box(Vector3(-10, 4, z - 3), Vector3(5, 1.4, 0.15), "white", false)
	_sign("競り場  04:17", Vector3(-10, 4, z - 2.89), 0.018)
	if campaign_bells:
		_bell(Vector3(5.8, 2.3, z - 12))
	if bay == 0:
		_market_entrance(campaign_bells)
	if bay == 1:
		_box(Vector3(0, 0.42, z - 21), Vector3(3, 0.84, 5), "wood")
		_sign("競売番号  四一七", Vector3(0, 3.8, z - 21), 0.018)
		for side in [-1.0, 1.0]:
			_box(Vector3(side * 8, 1.5, z - 17), Vector3(1, 3, 5), "white")
	if bay == 2:
		_box(Vector3(-10, 0.8, z - 29), Vector3(5, 1.6, 5), "blue")
		_box(Vector3(8, 0.65, z - 18), Vector3(3, 1.3, 4), "yellow")
		for fork in [-1.0, 1.0]:
			_box(Vector3(8 + fork, 0.2, z - 21), Vector3(0.3, 0.3, 3), "steel")
			_box(Vector3(8 + fork, 2.2, z - 19), Vector3(0.25, 4, 0.25), "black")

func _freezer(bay: int) -> void:
	var z := -float(bay) * 36
	for side in ([-1.0, 1.0] if bay == 1 else ([-1.0] if bay == 0 else [1.0])):
		_box(Vector3(side * 11, 2.8, z - 23), Vector3(5, 0.4, 18), "steel")
		var slope := _box(Vector3(side * 11, 1.35, z - 9), Vector3(5, 0.4, 11), "yellow")
		slope.rotation.x = deg_to_rad(16)
		for row in range(4):
			if not (bay == 1 and side > 0 and row == 3):
				_box(Vector3(side * 13, 4.5, z - 16 - row * 5), Vector3(1, 3, 3), "ice")
			_box(Vector3(side * 11, 0.6, z - 18 - row * 4), Vector3(3, 1.2, 1), "white")
		_sign("−28°C", Vector3(side * 10, 5.8, z - 27), 0.025)
	for side in [-1.0, 1.0]:
		for row in range(3):
			_fan(Vector3(side * 13.5, 5.1, z - 10 - row * 9), side)
		_box(Vector3(side * 13.4, 3.6, z - 18), Vector3(0.3, 0.3, 34), "ice", false)
	for row in range(3 if bay == 2 else 2):
		_hook(Vector3(-3 + (row % 2) * 6, 4.5, z - 18 - row * 6))
	if bay == 1:
		_box(Vector3(0, 5.6, z - 26), Vector3(22, 0.25, 3), "steel", false)
	if bay == 2:
		for pillar in [-7.0, 7.0]:
			_box(Vector3(pillar, 2.5, z - 22), Vector3(1.2, 5, 1.2), "ice")
	for icicle in range(20):
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.14
		cone.bottom_radius = 0.015
		cone.height = 0.4 + float(icicle % 4) * 0.18
		cone.radial_segments = 5
		spike.mesh = cone
		spike.material_override = mats.ice
		spike.position = Vector3(-13.0 + icicle * 1.35, 6.2, z - 16)
		add_child(spike)
	for strip in range(12):
		_box(Vector3(-5.4 + strip * 0.95, 3.4, z - 12), Vector3(0.87, 5.3, 0.035), "plastic", false)
	_sign("冷蔵  −28°C", Vector3(0, 5.9, z - 12), 0.014)
	_box(Vector3(0, 0.2, z - 16), Vector3(3, 0.4, 4), "ice")

func _ferry(bay: int) -> void:
	var z := -float(bay) * 36
	for side in [-1.0, 1.0]:
		for row in range(1 if bay == 2 else 2):
			var p := Vector3(side * (10.5 if bay == 2 else 9), 1.4, z - 12 - row * 13)
			_box(p, Vector3(4.5, 2.8, 7), "red" if (bay + row) % 2 == 0 else "blue")
			_box(p + Vector3(0, -0.55, 4), Vector3(4.4, 1.7, 1.6), "white")
			_box(p + Vector3(0, 0.3, 4.82), Vector3(3.8, 0.8, 0.05), "black", false)
			for dx in [-2.2, 2.2]:
				for axle in [-2.5, 2.6]:
					var wheel := MeshInstance3D.new()
					var cylinder := CylinderMesh.new()
					cylinder.top_radius = 0.6
					cylinder.bottom_radius = 0.6
					cylinder.height = 0.45
					cylinder.radial_segments = 10
					wheel.mesh = cylinder
					wheel.material_override = mats.black
					wheel.rotation.z = PI / 2
					wheel.position = p + Vector3(dx, -0.8, axle)
					add_child(wheel)
		_box(Vector3(side * 13.6, 2.2, z - 18), Vector3(0.15, 0.15, 34), "yellow", false)
		for rail in range(9):
			_box(Vector3(side * 13.6, 1.6, z - 2 - rail * 4), Vector3(0.12, 1.3, 0.12), "yellow", false)
		_sign("救命浮環", Vector3(side * 12, 3.5, z - 5), 0.016)
		_bell(Vector3(side * 5.9, 2.3, z - (16 if bay == 1 else 18)))
	if bay == 1:
		_box(Vector3(0, 1.0, z - 17), Vector3(3, 2, 7), "blue")
		_box(Vector3(0, 2.1, z - 17), Vector3(3.1, 0.2, 7.1), "yellow", false)
	if bay == 2:
		_box(Vector3(0, 9, z - 34), Vector3(27, 5, 5), "white", false)
		for window in range(9):
			_box(Vector3(-11.2 + window * 2.8, 9.2, z - 31.45), Vector3(2, 1.5, 0.1), "black", false)
		_box(Vector3(9, 14, z - 35), Vector3(4, 5, 4), "red", false)
		_box(Vector3(9, 15.5, z - 35), Vector3(4.1, 0.7, 4.1), "white", false)
		_sign("第七便  出航", Vector3(0, 6.3, z - 30), 0.025)

func _sign(value: String, pos: Vector3, pixel := 0.024) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 48
	if ResourceLoader.exists("res://media/jp.ttf"):
		label.font = load("res://media/jp.ttf")
	label.pixel_size = pixel
	label.modulate = Color("f2e5b2")
	label.outline_modulate = Color("192b32")
	label.outline_size = 2
	add_child(label)
	if pixel >= 0.014:
		var width := maxf(2.0, value.length() * pixel * 40.0)
		_box(pos + Vector3(0, 0, -0.09), Vector3(width + 0.4, pixel * 68.0, 0.12), "black", false)

func _lamp(pos: Vector3, tint: Color, energy := 3.2) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = 17
	add_child(light)
	var fixture := _box(pos, Vector3(3.2, 0.15, 0.5), "white", false)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = 2.0
	(fixture.get_child(0) as MeshInstance3D).material_override = glow

func _bell(pos: Vector3) -> void:
	var prop = PROP.new()
	prop.position = pos
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 0.9
	var col := CollisionShape3D.new()
	col.shape = shape
	prop.add_child(col)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.25
	cylinder.bottom_radius = 0.6
	cylinder.height = 0.9
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.material_override = mats.gold
	prop.add_child(mesh)
	add_child(prop)
	prop.activated.connect(func(point: Vector3):
		bell_rang.emit(point)
		sound.emit("bell", point)
	)
	_box(pos + Vector3(0, 0.9, 0), Vector3(0.08, 1, 0.08), "black", false)

func _hook(pos: Vector3) -> void:
	var prop = PROP.new()
	prop.kind = "hook"
	prop.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.8, 0.7)
	col.shape = shape
	prop.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = mats.red
	prop.add_child(mesh)
	add_child(prop)
	var landing_y := 3.0 if chapter == 1 and absf(pos.x) > 14 else 0.0
	var load_body := _box(pos + Vector3(0, -1.1, 0), Vector3(2.6, 1.4, 2.6), "white", false)
	load_body.set_meta("animated", true)
	_box(pos + Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08), "black", false)
	prop.activated.connect(func(point: Vector3):
		var tween := create_tween()
		tween.tween_property(load_body, "position:y", landing_y + 0.75, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			sound.emit("crash", point)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node3D and enemy.global_position.distance_to(Vector3(point.x, landing_y + 0.5, point.z)) < 4.3 and enemy.has_method("receive_shot"):
					enemy.receive_shot(260.0, enemy.global_position + Vector3.UP, Vector3.DOWN)
		)
	)

func _environment(ambient: float) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dc9379") if chapter == 2 else Color("132a32")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c8d0")
	env.ambient_light_energy = ambient if ambient >= 0.0 else (0.5 if chapter < 2 else 0.55)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	if chapter == 2:
		_box(Vector3(0, -3, -60), Vector3(900, 0.2, 900), "water", false)
		_box(Vector3(-70, -1, -75), Vector3(20, 2, 90), "black", false)
		_box(Vector3(-62, 8, -36), Vector3(3, 20, 3), "white", false)
		_box(Vector3(-62, 12, -36), Vector3(3.05, 2, 3.05), "red", false)
		_box(Vector3(-62, 17, -36), Vector3(4, 1.4, 4), "gold", false)
		_lamp(Vector3(-62, 17, -36), Color("ffbb55"))
		for wharf in range(8):
			_box(Vector3(-80, 2 + wharf % 3, -10 - wharf * 12), Vector3(12, 5 + wharf % 3, 8), "steel", false)
		var sky := Sky.new()
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = load("res://world/surfaces/dawn.jpg")
		sky_mat.energy_multiplier = 0.9
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -25, 0)
	sun.light_color = Color("ffd6a0") if chapter == 2 else Color("92b8cf")
	sun.light_energy = 0.65
	sun.shadow_enabled = not (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func _fan(pos: Vector3, side: float) -> void:
	var fan := Node3D.new()
	fan.position = pos
	fan.rotation.z = PI / 2 * side
	add_child(fan)
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 1.2
	shape.bottom_radius = 1.2
	shape.height = 0.2
	shape.radial_segments = 12
	mesh.mesh = shape
	mesh.material_override = mats.black
	fan.add_child(mesh)
	for blade in range(5):
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.12, 2.15)
		wing.mesh = box
		wing.material_override = mats.steel
		wing.rotation.y = float(blade) * PI / 5
		wing.position.y = 0.15
		fan.add_child(wing)

func _fish(pos: Vector3) -> void:
	var fish := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	fish.mesh = sphere
	fish.scale = Vector3(0.35, 0.14, 0.85)
	fish.position = pos
	fish.material_override = mats.blue
	add_child(fish)
	var tail := _box(pos + Vector3(0, 0, 0.75), Vector3(0.55, 0.06, 0.35), "blue", false)
	tail.rotation.y = PI / 4

func _fish_stamp(pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere
	mesh.scale = Vector3(0.65, 0.22, 0.015)
	mesh.position = pos
	mesh.material_override = mats.blue
	add_child(mesh)
	var tail := _box(pos + Vector3(-0.4, 0, 0), Vector3(0.3, 0.3, 0.02), "blue", false)
	tail.rotation.z = PI / 4

func _floor_details(bay: int) -> void:
	var z := -float(bay) * 36
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 6.2, 0.022, z - 18), Vector3(0.55, 0.03, 35), "black", false)
		for grate in range(45):
			_box(Vector3(side * 6.2, 0.04, z - 0.6 - grate * 0.78), Vector3(0.6, 0.03, 0.07), "steel", false)
	if chapter < 2:
		for light_index in range(2):
			var tint := Color(0.2, 0.6, 0.5, 0.14) if chapter == 0 else Color(0.4, 0.65, 0.8, 0.12)
			var reflected := StandardMaterial3D.new()
			reflected.albedo_color = tint
			reflected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			reflected.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for ripple in range(12):
				var pos := Vector3(-6 if light_index == 0 else 6, 0.045, z - 10 - light_index * 15 + ripple * 0.26)
				var streak := _box(pos, Vector3(rng.randf_range(1.3, 3.6), 0.01, 0.12), "floor", false)
				(streak.get_child(0) as MeshInstance3D).material_override = reflected

func _crate_face(pos: Vector3, size: Vector2) -> void:
	var print_mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	print_mesh.mesh = quad
	print_mesh.material_override = mats.crate_print
	print_mesh.position = pos
	add_child(print_mesh)

func _market_entrance(campaign_bells: bool) -> void:
	# A foreground bell, angled crate silhouettes and the opening shutter frame the first worker.
	if campaign_bells:
		_bell(Vector3(-3.6, 3.0, -7.8))
		_box(Vector3(-4.25, 3.2, -7.8), Vector3(0.45, 6.4, 0.5), "steel")
		_box(Vector3(-3.8, 4.0, -7.8), Vector3(1.3, 0.2, 0.35), "gold", false)
	intro_shutter = _box(Vector3(1.4, 3.5, -17.0), Vector3(6.8, 17.2, 0.4), "steel")
	intro_shutter.rotation.z = PI / 2
	intro_shutter.set_meta("animated", true)
	for side in [-7.5, 10.2]:
		_box(Vector3(side, 3.5, -17), Vector3(0.8, 7, 0.9), "yellow")
	_box(Vector3(0.3, 5.6, -16.65), Vector3(5.6, 1.1, 0.12), "white", false)
	var nameplate := Label3D.new()
	nameplate.text = "競 り 場"
	nameplate.font = load("res://media/jp.ttf")
	nameplate.font_size = 64
	nameplate.pixel_size = 0.013
	nameplate.modulate = Color("26302b")
	nameplate.outline_size = 0
	nameplate.position = Vector3(0.3, 5.6, -16.55)
	add_child(nameplate)
	var clock := Label3D.new()
	clock.text = "04:17"
	clock.font_size = 72
	clock.pixel_size = 0.019
	clock.modulate = Color("ff4937")
	clock.outline_modulate = Color("441810")
	clock.outline_size = 6
	clock.position = Vector3(6.2, 4.7, -16.6)
	add_child(clock)
	for pile in range(5):
		for level in range(1 + pile % 3):
			var pos := Vector3(-10.8 + (pile % 2) * 1.5, 0.45 + level * 0.85, -4.5 - pile * 1.7)
			_box(pos, Vector3(2.2, 0.8, 1.5), "white")
			_crate_face(pos + Vector3(0, 0, 0.76), Vector2(2.12, 0.76))
	for beam in range(4):
		_box(Vector3(-7 + beam * 5, 6.8, -18), Vector3(0.18, 0.25, 34), "steel", false)
	for strand in range(3):
		for segment in range(10):
			var x := -11 + segment * 2.4
			var sag := 0.8 * sin(float(segment) / 9.0 * PI)
			var cable := _box(Vector3(x, 6.3 - sag, -8.5 - strand * 9), Vector3(2.5, 0.06, 0.06), "black", false)
			cable.rotation.z = -0.11 * cos(float(segment) / 9.0 * PI)

func navigation_goal() -> Vector3:
	return rally_target if rally_active else Vector3.ZERO

func _build_rally() -> void:
	rally_target = Vector3.ZERO
	rally_marker = Node3D.new()
	add_child(rally_marker)
	rally_marker.position = rally_target
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 1.2, 0.8)
	mesh.mesh = box
	mesh.material_override = mats.gold if chapter != 1 else mats.ice
	rally_marker.add_child(mesh)
	var lamp := OmniLight3D.new()
	lamp.position.y = 1.5
	lamp.light_color = Color("72e6ff") if chapter == 1 else Color("ffce59")
	lamp.light_energy = 4
	lamp.omni_range = 9
	rally_marker.add_child(lamp)
	var label := Label3D.new()
	label.text = ["非常配電室", "圧縮機室", "ウインチ電源"][chapter]
	label.position.y = 2.0
	label.font = load("res://media/jp.ttf")
	label.font_size = 48
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rally_marker.add_child(label)
	rally_marker.visible = false
	warning_light = OmniLight3D.new()
	warning_light.light_color = Color("ff573b")
	warning_light.light_energy = 4
	warning_light.omni_range = 12
	warning_light.visible = false
	add_child(warning_light)

func _announce_wave() -> void:
	if wave_pending:
		return
	wave_pending = true
	warning_light.position = Vector3(-5.5 if wave == 1 else 0.0, 3.0, -checkpoint * 36 - 26)
	if detour_fight > 0:
		warning_light.position = Vector3(_side() * (22 if detour_fight == 1 else 34), _deck_y() + 3, -57)
	warning_light.visible = true
	sound.emit("gate", warning_light.position)
	if detour_fight > 0:
		objective.emit("配管の奥に足音。赤い警報灯の方向に注意。" if detour_fight == 1 else "電源復帰。復路の荷口が開く。赤い警報灯に注意。")
	else:
		objective.emit("左右の荷口が開く。赤い警報灯の方向に注意。" if wave == 1 else "奥のシャッターに反応。赤い警報灯の方向に注意。")
	var tween := create_tween()
	tween.tween_interval(0.7)
	tween.tween_callback(func():
		warning_light.visible = false
		_launch_wave())

func _side() -> float:
	return -1.0 if chapter == 0 else 1.0

func _deck_y() -> float:
	return 3.0 if chapter == 1 else 0.0

func navigation_route() -> Array[Vector3]:
	return route_points.duplicate()

func _begin_route(phase: int) -> void:
	detour_phase = phase
	var side := _side()
	var y := _deck_y() + 0.15
	route_points.clear()
	if phase == 1:
		match chapter:
			0: route_points.assign([Vector3(-5, 0.15, -48), Vector3(-17, 0.15, -48), Vector3(-22, 0.15, -50)])
			1: route_points.assign([Vector3(5, 0.15, -38), Vector3(11, 0.15, -38), Vector3(11, 3.15, -52), Vector3(18, 3.15, -54), Vector3(22, 3.15, -54)])
			2: route_points.assign([Vector3(5, 0.15, -54), Vector3(18, 0.15, -54), Vector3(22, 0.15, -54)])
		objective.emit(["外売場の電源が落ちた。左の入口から非常配電室へ。", "解凍電源を復帰する。右の坂を上がり、圧縮機室へ。", "船尾ゲートは停電中。右の車間から舷側歩廊へ。"][chapter])
	elif phase == 2:
		route_points.assign([Vector3(side * 22, y, -62), Vector3(side * 34, y, -62), Vector3(side * 34, y, -46)])
		objective.emit(["配管を回り、奥の黄色い配電盤へ。近づくと電源が戻る。", "圧縮機の裏を回り、奥の青い解凍レバーへ。", "舷側歩廊を回り、奥の黄色いウインチ電源へ。"][chapter])
	else:
		var exit_z := -68.0 if chapter == 2 else -66.0
		route_points.assign([Vector3(side * 34, y, -66), Vector3(side * 20, y, exit_z), Vector3(side * 11, y, exit_z), Vector3(side * 5, 0.15, -66), Vector3(side * 5, 0.15, -57)])
		objective.emit(["外売場に明かりが戻った。開いた搬送口を通って競り場へ。", "解凍完了。開いた搬出口から冷凍庫へ戻る。", "ウインチ通電。開いた復路ゲートから車列へ戻る。"][chapter])
	rally_active = true
	rally_marker.visible = true
	_show_route_target()

func _show_route_target() -> void:
	rally_target = route_points[0]
	rally_marker.position = rally_target + Vector3(0, 0.7, 0)

func _step_route() -> void:
	route_points.pop_front()
	if not route_points.is_empty():
		_show_route_target()
		return
	rally_active = false
	rally_marker.visible = false
	if detour_phase == 1:
		detour_fight = 1
	elif detour_phase == 2:
		detour_fight = 2
		supplied.emit()
		sound.emit("switch", rally_target)
		for light in service_lights: light.light_energy = 3.5
		create_tween().tween_property(service_exit, "position:y", _deck_y() + 8.0, 1.0)
	else:
		detour_phase = 4
	_announce_wave()

func _spawn_detour() -> void:
	var kinds: Array
	if detour_fight == 1:
		kinds = [[0, 1, 0, 1], [2, 0, 0, 1], [1, 1, 0, 2]][chapter]
	else:
		kinds = [[1, 0, 1, 2, 0], [2, 0, 1, 2, 0], [2, 1, 0, 1, 0]][chapter]
	var positions: Array = []
	for i in range(kinds.size()):
		var x := (20.0 if detour_fight == 1 else 30.8) + (i % 3) * 1.8
		positions.append(Vector3(_side() * x, _deck_y() + 0.2, -57.0 - (i / 3) * 3.0))
	wave_pending = false
	spawn_wave.emit(kinds, positions)
	objective.emit((["配電室の入口を確保する。黄色い鐘で群れを寄せる。", "圧縮機室の入口を確保する。赤い金具を撃ち、吊り荷を落とす。", "舷側歩廊を確保する。黄色い鐘で走者を誘導する。"][chapter]) if detour_fight == 1 else "復路の群れを突破する。電源盤へは戻らず、開いた搬出口へ。")

func _build_detour() -> void:
	var side := _side()
	var y := _deck_y()
	_box(Vector3(side * 26, y - 0.3, -56), Vector3(24, 0.6, 30), "floor")
	_box(Vector3(side * 38, y + (0.7 if chapter == 2 else 3.0), -56), Vector3(0.6, 1.4 if chapter == 2 else 6.0, 30), "steel")
	for end in [-41.0, -71.0]:
		_box(Vector3(side * 26, y + 3, end), Vector3(24, 6, 0.6), "steel")
	_box(Vector3(side * 27, y + 2.2, -49), Vector3(0.7, 4.4, 16), "steel" if chapter != 1 else "ice")
	if chapter != 2:
		_box(Vector3(side * 26, y + 6.2, -56), Vector3(24, 0.4, 30), "black")
	var exit_z := -68.0 if chapter == 2 else -66.0
	service_exit = _box(Vector3(side * 14, y + 2.5, exit_z), Vector3(0.65, 5, 5.2), "yellow")
	service_exit.set_meta("animated", true)
	for pos in [Vector3(side * 21, y + 4, -50), Vector3(side * 34, y + 4, -63), Vector3(side * 34, y + 4, -46)]:
		var lamp := OmniLight3D.new()
		lamp.position = pos
		lamp.omni_range = 15
		lamp.light_color = Color("71dfea") if chapter == 1 else Color("ffd58b")
		lamp.light_energy = 1.4
		add_child(lamp)
		service_lights.append(lamp)
	var control := _box(Vector3(side * 34, y + 1, -43.5), Vector3(2.8, 2, 1), "blue" if chapter == 1 else "yellow")
	control.set_meta("animated", true)
	for fuse in range(4):
		_box(Vector3(side * 34 - 0.9 + fuse * 0.6, y + 1.3, -42.95), Vector3(0.2, 0.5, 0.1), "red", false)
	_sign(["非常配電室", "圧縮機室", "ウインチ電源"][chapter], Vector3(side * 34, y + 3.6, -43.3), 0.012)
	_sign(["配電室 ←", "圧縮機室 →", "舷側歩廊 →"][chapter], Vector3(side * 11, y + 3.5, -51), 0.012)
	for conduit in range(3):
		_box(Vector3(side * (28 + conduit * 0.35), y + 4.9, -55), Vector3(0.14, 0.14, 27), "red" if chapter == 0 else "blue", false)
	if chapter == 1:
		for pos in [Vector3(22, y + 4.4, -58), Vector3(34, y + 4.4, -58)]: _hook(pos)
		for machine in range(3):
			_box(Vector3(36.5, y + 1.2, -52 - machine * 6), Vector3(2, 2.4, 3), "ice")
			_fan(Vector3(35.4, y + 1.6, -52 - machine * 6), -1)
	else:
		_bell(Vector3(side * 25, y + 2.4, -57))
		_bell(Vector3(side * 36, y + 2.4, -57))
		for machine in range(3):
			_box(Vector3(side * 16, y + 0.65, -57 - machine * 3), Vector3(2, 1.3, 2), "white" if chapter == 0 else "blue")

	if chapter == 2:
		_box(Vector3(37.5, 2, -56), Vector3(0.12, 0.12, 30), "yellow", false)
		for post in range(8):
			_box(Vector3(37.5, 1.5, -42 - post * 4), Vector3(0.12, 1.2, 0.12), "yellow", false)
		var winch := MeshInstance3D.new()
		var spool := CylinderMesh.new()
		spool.top_radius = 0.9
		spool.bottom_radius = 0.9
		spool.height = 1.8
		spool.radial_segments = 12
		winch.mesh = spool
		winch.material_override = mats.black
		winch.rotation.z = PI / 2
		winch.position = Vector3(36, 1.2, -46)
		add_child(winch)
		_box(Vector3(36, 0.2, -46), Vector3(2.5, 0.4, 2.3), "yellow", false)
	elif chapter == 0:
		for cabinet in range(3):
			_box(Vector3(-37, 1.8, -48 - cabinet * 4), Vector3(1, 3.6, 2), "blue")
			_sign("高電圧", Vector3(-36.45, 2.5, -47.1 - cabinet * 4), 0.008)
