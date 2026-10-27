extends Node2D
## Directional contacts and editable action clips present already-resolved turns.

const CREW_FRAMES := {
	"isana": preload("res://resources/crew/isana_motion.tres"),
	"ritsu": preload("res://resources/crew/ritsu_motion.tres"),
	"kohaku": preload("res://resources/crew/kohaku_motion.tres"),
	"sui": preload("res://resources/crew/sui_motion.tres")}
const CREW_FACTOR := 94.0 / 288.0
# Measured glove/hand centers in the normalized 320-square pose canvases.
const HAND_SOCKETS := {
	"isana": {"down":[Vector2(128,164),Vector2(135,151)], "up":[Vector2(205,178),Vector2(108,166)], "side":[Vector2(191,183),Vector2(221,152)]},
	"ritsu": {"down":[Vector2(119,163),Vector2(128,164)], "up":[Vector2(210,171),Vector2(109,172)], "side":[Vector2(90,174),Vector2(215,152)]},
	"kohaku": {"down":[Vector2(120,162),Vector2(125,162)], "up":[Vector2(211,173),Vector2(106,172)], "side":[Vector2(89,171),Vector2(219,150)]},
	"sui": {"down":[Vector2(120,157),Vector2(123,163)], "up":[Vector2(218,163),Vector2(107,171)], "side":[Vector2(197,154),Vector2(226,151)]}}

@onready var body: Node2D = $Facing/BodyPivot
@onready var sprite: Sprite2D = $Facing/BodyPivot/Sprite
@onready var crew: AnimatedSprite2D = $Facing/BodyPivot/Crew
@onready var tool_socket: Node2D = $Facing/BodyPivot/ToolSocket
@onready var weapon_pivot: Node2D = $Facing/BodyPivot/ToolSocket/WeaponPivot
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var ring: Line2D = $GroundRing
@onready var shadow: Polygon2D = $Shadow
@onready var health_back: Polygon2D = $HealthBack
@onready var health_fill: Polygon2D = $HealthFill

@export var action_displacement := 0.0
@export var stance_drop := 0.0
@export var pose_rotation := 0.0
var reduced_motion := false
var is_player := false
var kind := ""
var _texture: Texture2D
var _move_tween: Tween
var _pose_tween: Tween
var _move_target := Vector2.ZERO
var _ready_stance := false
var _reaction := ""
var _facing := "down"
var _facing_direction := Vector2.DOWN
var _action_axis := Vector2.RIGHT
var _contact_index := 0
var _next_contact := 1
var _step_count := 0
var _stage_pose := ""
var _queued_hurt_direction := Vector2.ZERO
var _overlay_paused := false
var _focus_paused := false

func _ready() -> void:
	animation.animation_finished.connect(_animation_finished)
	animation.animation_started.connect(_animation_started)
	crew.frame_changed.connect(_sync_tool_socket)

func configure(texture: Texture2D, actor_kind: String, player_actor: bool, reduce: bool) -> void:
	var identity_changed := kind != actor_kind or is_player != player_actor
	var motion_changed := reduced_motion != reduce
	kind = actor_kind
	is_player = player_actor
	reduced_motion = reduce
	ring.visible = is_player or _ready_stance
	ring.default_color = Color("1e9ba8") if is_player else Color("e56c57")
	if identity_changed:
		_stop_pose()
		animation.stop()
		_stage_pose = ""
		_contact_index = 0
		_step_count = 0
		_facing = "down"
		_facing_direction = Vector2.DOWN
		$Facing.scale.x = 1.0
		_reset_pose()
	crew.visible = is_player and CREW_FRAMES.has(kind)
	sprite.visible = not crew.visible
	tool_socket.visible = crew.visible
	if crew.visible:
		if crew.sprite_frames != CREW_FRAMES[kind]:
			crew.sprite_frames = CREW_FRAMES[kind]
		crew.animation = _facing
		crew.frame = _contact_index
		crew.stop()
		_sync_tool_socket()
	elif texture != null and texture != _texture:
		_texture = texture
		var height := 53.0 if kind == "crab" else 85.0
		sprite.texture = texture
		sprite.scale = Vector2.ONE * (height / maxf(1.0, texture.get_height()))
		sprite.position = Vector2(0, -height * 0.5)
	if motion_changed and reduced_motion:
		if _move_tween != null and _move_tween.is_valid():
			_move_tween.kill()
			position = _move_target
		_stop_pose()
		animation.stop()
		_reset_pose()
	if reduced_motion:
		animation.stop()
	elif not animation.is_playing() and _reaction.is_empty() and _stage_pose.is_empty():
		animation.play(_rest_clip())

func set_stage_scale(factor: float) -> void:
	scale = Vector2.ONE * clampf(factor, 0.5, 3.0)
	ring.visible = false
	health_back.visible = false
	health_fill.visible = false

func set_presentation_paused(paused: bool) -> void:
	_overlay_paused = paused
	_update_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_paused = true
		_update_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_paused = false
		_update_pause()

func _update_pause() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if _overlay_paused or _focus_paused else Node.PROCESS_MODE_INHERIT

func _process(_delta: float) -> void:
	# Action tracks move a visual pivot around grounded feet, never the resolved cell.
	body.position = _action_axis * action_displacement + Vector2(0, stance_drop)
	body.rotation = pose_rotation

func set_health(hp: int, maximum: int) -> void:
	health_back.visible = not is_player and hp < maximum
	health_fill.visible = health_back.visible
	var fraction := clampf(float(hp) / maxf(float(maximum), 1.0), 0.0, 1.0)
	health_fill.polygon = PackedVector2Array([Vector2(-19, -2), Vector2(-19 + 38 * fraction, -2), Vector2(-19 + 38 * fraction, 2), Vector2(-19, 2)])
	var bar_y := -45.0 if kind == "crab" else -76.0
	health_back.position.y = bar_y
	health_fill.position.y = bar_y

func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	_facing_direction = direction.normalized()
	if is_player:
		_facing = "side" if absf(direction.x) > absf(direction.y) else "up" if direction.y < 0 else "down"
		$Facing.scale.x = -1.0 if _facing == "side" and direction.x < 0 else 1.0
		crew.animation = _facing
		crew.frame = _contact_index
		_sync_tool_socket()
	elif absf(direction.x) > 0.01:
		$Facing.scale.x = -1.0 if direction.x < 0 else 1.0

func set_intent(charging: bool) -> void:
	if _ready_stance == charging:
		return
	_ready_stance = charging
	ring.visible = is_player or charging
	if _reaction.is_empty() and _stage_pose.is_empty() and not reduced_motion:
		animation.play(_rest_clip())

func move_to(target: Vector2, immediate: bool = false) -> void:
	if not immediate and target == _move_target and _move_tween != null and _move_tween.is_valid() and _move_tween.is_running():
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_target = target
	var distance := position.distance_to(target)
	if immediate or reduced_motion or distance > 256.0:
		position = target
		if immediate:
			_stop_pose()
			animation.stop()
			_reset_pose()
			if not reduced_motion:
				animation.play(_rest_clip())
		return
	if distance < 0.1:
		return
	var direction := (target - position).normalized()
	face(direction)
	var charge := kind == "wader" and distance > 90
	var duration := 0.18 if charge else 0.26 if kind == "diver" else 0.22
	_move_tween = create_tween()
	if charge:
		_move_tween.tween_interval(0.08)
	_move_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play_reaction("attack" if charge else "step")

func play_reaction(reaction: String, direction: Vector2 = Vector2.ZERO) -> void:
	# Preserve the attack's contact before a same-turn hurt; the queued clip is presentation only.
	if not reduced_motion and reaction == "hurt" and animation.current_animation.ends_with("attack") and animation.current_animation_position < 0.13:
		_queued_hurt_direction = direction.normalized() if direction.length_squared() > 0.0001 else -_facing_direction
		animation.queue("hurt")
		return
	_stop_pose()
	animation.stop()
	_reset_pose()
	_stage_pose = ""
	_reaction = reaction
	var world_axis := direction.normalized() if direction.length_squared() > 0.0001 else -_facing_direction if reaction == "hurt" else _facing_direction
	_action_axis = Vector2(world_axis.x * $Facing.scale.x, world_axis.y)
	if reduced_motion:
		_reaction = ""
		if reaction == "hurt":
			body.modulate = Color("ffbdad")
			_pose_tween = create_tween()
			_pose_tween.tween_property(body, "modulate", Color.WHITE, 0.16)
		return
	if reaction == "step":
		_step_count += 1
		_next_contact = _step_count % 2
		animation.play("crew_step" if is_player else "step")
	elif reaction == "attack":
		animation.play("crew_attack" if is_player else kind + "_attack" if animation.has_animation(kind + "_attack") else "attack")
	elif animation.has_animation(reaction):
		animation.play(reaction)
	else:
		_reaction = ""
		animation.play(_rest_clip())

func play_arrival(celebrate: bool = true) -> void:
	_play_stage("arrival" if celebrate else "arrival_quiet")

func play_loss() -> void:
	_play_stage("loss")

func _play_stage(stage: String) -> void:
	_stop_pose()
	animation.stop()
	_reset_pose()
	_stage_pose = stage
	face(Vector2.DOWN)
	_action_axis = Vector2.DOWN
	if reduced_motion:
		weapon_pivot.rotation = -0.65 if stage == "loss" else -0.4
		body.modulate = Color("d6dce0") if stage == "loss" else Color.WHITE
	else:
		animation.play(stage)

func _land_next_contact() -> void:
	if crew.visible:
		_contact_index = _next_contact
		crew.frame = _contact_index
		_sync_tool_socket()

func _action_contact() -> void:
	if crew.visible:
		crew.frame = 1 - _contact_index
		_sync_tool_socket()

func _restore_contact() -> void:
	if crew.visible:
		crew.frame = _contact_index
		_sync_tool_socket()

func _sync_tool_socket() -> void:
	if not is_node_ready() or not is_player or not HAND_SOCKETS.has(kind):
		return
	var socket: Vector2 = HAND_SOCKETS[kind][_facing][crew.frame]
	tool_socket.position = (socket - Vector2(160,304)) * CREW_FACTOR
	var local_direction := Vector2(_facing_direction.x * $Facing.scale.x, _facing_direction.y)
	tool_socket.rotation = local_direction.angle() + 0.65
	tool_socket.z_index = 1

func _rest_clip() -> String:
	if _ready_stance:
		return kind + "_ready" if animation.has_animation(kind + "_ready") else "ready"
	return "crew_idle" if is_player else "idle"

func _stop_pose() -> void:
	animation.clear_queue()
	_queued_hurt_direction = Vector2.ZERO
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_reaction = ""

func _reset_pose() -> void:
	action_displacement = 0.0
	stance_drop = 0.0
	pose_rotation = 0.0
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	weapon_pivot.rotation = 0.0
	shadow.scale = Vector2.ONE
	_restore_contact()

func _animation_finished(_clip: StringName) -> void:
	if animation.get_queue().size() > 0:
		return
	_reaction = ""
	if not _stage_pose.is_empty():
		return
	_reset_pose()
	if not reduced_motion:
		animation.play(_rest_clip())

func _animation_started(clip: StringName) -> void:
	if clip == &"hurt" and _queued_hurt_direction != Vector2.ZERO:
		_action_axis = Vector2(_queued_hurt_direction.x * $Facing.scale.x, _queued_hurt_direction.y)
		_queued_hurt_direction = Vector2.ZERO
