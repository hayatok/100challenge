extends Node3D
## Exported comic employee and vehicle. Gameplay owns motion; these pivots own acting.

const AssetLibrary := preload("res://scripts/asset_library.gd")

var _made := false
var _time := 0.0
var _chair: Node3D
var _person: Node3D
var _head: Node3D
var _tie: Node3D
var _tank: Node3D
var _nozzle: Node3D
var _right_arm: Node3D
var _left_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _mouth: Node3D
var _eyes: Node3D
var _happy_eyes: Node3D
var _brows: Node3D
var _cheeks: Node3D
var _tears: Node3D
var _seat_height := 1.0
var _tank_home := Vector3(0.64, 0.40, -0.30)

func build() -> void:
	if _made:
		return
	_made = true
	_chair = AssetLibrary.model("chair", true)
	add_child(_chair)
	var seat := _chair.find_child("SeatPivot", true, false) as Node3D
	if seat:
		# Pelvis intersects the plush seat slightly, so the body has a clear seated contact.
		_seat_height = seat.position.y + 0.13
	_person = AssetLibrary.model("employee", false)
	_chair.add_child(_person)
	_person.position = Vector3(0, _seat_height, -0.04)
	_head = _part("Head")
	_tie = _part("Tie")
	_left_arm = _part("ArmLeft")
	_right_arm = _part("ArmRight")
	_left_leg = _part("LegLeft")
	_right_leg = _part("LegRight")
	_mouth = _part("Mouth")
	_eyes = _part("EyesOpen")
	_happy_eyes = _part("EyesHappy")
	_brows = _part("Brows")
	_cheeks = _part("Cheeks")
	_tears = _part("Tears")
	_tank = AssetLibrary.model("extinguisher", false)
	_person.add_child(_tank)
	_nozzle = _tank.find_child("NozzleTip", true, false) as Node3D
	assert(_nozzle != null, "Extinguisher needs its modeled nozzle tip")
	# Shared material comes from AssetLibrary. Only large body/head groups need
	# shadow passes; facial details, limbs and the held tank retain their colors.
	for label in ["Employee_Geometry", "Head_Geometry"]:
		var silhouette := _person.find_child(label, true, false) as MeshInstance3D
		if silhouette:
			silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var meshes := find_children("*", "MeshInstance3D", true, false)
	set_meta("render_mesh_count", meshes.size())
	set_meta("asset_source", "Blender v0.4 reference-based employee/chair/extinguisher")
	update_pose(0.0, 0.0, 0.0, false, 0.0, false, false)

func nozzle_position() -> Vector3:
	return _nozzle.global_position

func _part(label: String) -> Node3D:
	var part := _person.find_child(label, true, false) as Node3D
	assert(part != null, "Employee asset is missing animation pivot " + label)
	return part

func update_pose(delta: float, speed: float, turn: float, spray: bool, impact: float, rush: bool, won: bool) -> void:
	if not _made:
		build()
	_time += maxf(delta, 0.0)
	var moving := clampf(speed / 9.0, 0.0, 1.0)
	var hit := clampf(impact, 0.0, 1.0)
	var thrust := 1.0 if spray else 0.0
	var happy := 1.0 if won else 0.0
	var bounce := sin(_time * (13.0 if spray else 2.4))
	_chair.rotation = Vector3(-0.045 * thrust - hit * 0.12, 0, -turn * (0.07 + moving * 0.075) + sin(_time * 22.0) * hit * 0.08)
	_person.position.y = _seat_height + bounce * (0.018 + thrust * 0.012) + hit * 0.08
	_person.rotation = Vector3(thrust * -0.10 + hit * -0.16, -1.0, turn * -0.13)
	# He checks the ridiculous plume over his shoulder; the face stays readable from the camera.
	_head.rotation = Vector3(0.17 + thrust * 0.08 + hit * 0.16, -1.25 + turn * 0.10 + sin(_time * 1.9) * 0.045, -turn * 0.09 + sin(_time * 16.0) * hit * 0.08)
	_head.scale = Vector3(1.0 + hit * 0.18, 1.0 - hit * 0.18 + (0.04 if rush else 0.0), 1.0 + hit * 0.08)
	_tie.rotation = Vector3(-0.12 - thrust * 0.9 + sin(_time * 19.0) * thrust * 0.13, sin(_time * 12.0) * thrust * 0.13, turn * -0.35 + sin(_time * 16.0) * (0.04 + thrust * 0.13))
	_left_leg.rotation.x = -0.04 - thrust * 0.13 - hit * 0.22 + sin(_time * 12.0) * moving * 0.07
	_right_leg.rotation.x = -0.08 - thrust * 0.16 - hit * 0.32 - sin(_time * 12.0) * moving * 0.07
	_left_arm.rotation = Vector3(happy * 1.0, 0.0, 0.08 + hit * 0.20 - happy * 0.68)
	_right_arm.rotation = Vector3(happy * 0.12, 0.0, -0.06 - hit * 0.12 + happy * 0.08)
	# Shoulders retain their exported contact point. The left arm cheers while the right
	# keeps the tank below the face, so victory never hides the expression.
	_tank.position = _tank_home + Vector3(0.04 * happy, 0.08 * happy, -0.06 * happy)
	_tank.rotation = Vector3(0.13 + thrust * 0.06 + sin(_time * 17.0) * hit * 0.06, 1.24, -0.16 - happy * 0.16)
	_mouth.scale = Vector3(0.90 + thrust * 0.11 + hit * 0.15 + happy * 0.08, 0.87 + thrust * 0.14 + hit * 0.13 + happy * 0.04, 1.0)
	_eyes.visible = not won
	_happy_eyes.visible = won
	_eyes.scale.y = 1.0 - hit * 0.32
	_brows.rotation.z = sin(_time * 19.0) * thrust * 0.025 + hit * 0.05
	_cheeks.scale.x = 1.0 + hit * 0.13 + thrust * (0.03 + sin(_time * 23.0) * 0.025)
	_tears.visible = won or (rush and spray)
	_tears.position.y = -happy * (0.015 + sin(_time * 6.0) * 0.025)
