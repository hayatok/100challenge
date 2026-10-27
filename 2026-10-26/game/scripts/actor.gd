extends Node2D
## A cutout field actor. Poses and footplants follow resolved turns only.

@onready var body: Node2D = $Facing/BodyPivot
@onready var sprite: Sprite2D = $Facing/BodyPivot/Sprite
@onready var left_foot: Sprite2D = $Facing/BodyPivot/LeftFoot
@onready var right_foot: Sprite2D = $Facing/BodyPivot/RightFoot
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var ring: Line2D = $GroundRing
@onready var shadow: Polygon2D = $Shadow
@onready var health_back: Polygon2D = $HealthBack
@onready var health_fill: Polygon2D = $HealthFill

var reduced_motion := false
var is_player := false
var kind := ""
var _texture: Texture2D
var _move_tween: Tween
var _pose_tween: Tween
var _foot_left_rest := Vector2.ZERO
var _foot_right_rest := Vector2.ZERO
var _stride_sign := 1.0
var _ready_stance := false
var _reaction := ""

func _ready() -> void:
	animation.animation_finished.connect(_animation_finished)

func configure(texture: Texture2D, actor_kind: String, player_actor: bool, reduce: bool) -> void:
	kind = actor_kind
	is_player = player_actor
	var motion_changed := reduced_motion != reduce
	reduced_motion = reduce
	ring.visible = is_player or _ready_stance
	ring.default_color = Color("1e9ba8") if is_player else Color("e56c57")
	if texture != null and texture != _texture:
		_texture = texture
		_fit_cutout(texture)
	if reduced_motion:
		animation.stop()
		if motion_changed:
			_stop_pose()
		_reset_pose()
	elif not animation.is_playing() and _reaction.is_empty():
		animation.play("ready" if _ready_stance else "idle")

func _fit_cutout(texture: Texture2D) -> void:
	var height := 94.0 if is_player else (53.0 if kind == "crab" else 85.0)
	var factor := height / maxf(1.0, texture.get_height())
	var dimensions := Vector2(texture.get_width(), texture.get_height())
	var top := Vector2(-dimensions.x * factor * 0.5, 19.0 - height)
	if is_player:
		# The overlapping cuts keep coat hems joined while each boot can plant.
		var split_y := floorf(dimensions.y * 0.79)
		var boot_y := floorf(dimensions.y * 0.76)
		sprite.texture = _slice(texture, Rect2(0, 0, dimensions.x, split_y))
		sprite.centered = false
		sprite.scale = Vector2.ONE * factor
		sprite.position = top
		left_foot.texture = _slice(texture, Rect2(0, boot_y, dimensions.x * 0.5, dimensions.y - boot_y))
		right_foot.texture = _slice(texture, Rect2(dimensions.x * 0.5, boot_y, dimensions.x * 0.5, dimensions.y - boot_y))
		left_foot.scale = Vector2.ONE * factor
		right_foot.scale = Vector2.ONE * factor
		_foot_left_rest = top + Vector2(0, boot_y * factor)
		_foot_right_rest = top + Vector2(dimensions.x * factor * 0.5, boot_y * factor)
		left_foot.visible = true
		right_foot.visible = true
	else:
		sprite.texture = texture
		sprite.centered = true
		sprite.scale = Vector2.ONE * factor
		sprite.position = Vector2(0, 19.0 - height * 0.5)
		left_foot.visible = false
		right_foot.visible = false
	_reset_pose()

func _slice(texture: Texture2D, rect: Rect2) -> Texture2D:
	var cut := AtlasTexture.new()
	if texture is AtlasTexture:
		cut.atlas = texture.atlas
		cut.region = Rect2(texture.region.position + rect.position, rect.size)
	else:
		cut.atlas = texture
		cut.region = rect
	cut.filter_clip = true
	return cut

func set_health(hp: int, maximum: int) -> void:
	var show_health := not is_player and hp < maximum
	health_back.visible = show_health
	health_fill.visible = show_health
	var fraction := clampf(float(hp) / maxf(float(maximum), 1.0), 0.0, 1.0)
	health_fill.polygon = PackedVector2Array([Vector2(-19, -2), Vector2(-19 + 38 * fraction, -2), Vector2(-19 + 38 * fraction, 2), Vector2(-19, 2)])
	var bar_y := -45.0 if kind == "crab" else -76.0
	health_back.position.y = bar_y
	health_fill.position.y = bar_y

func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		$Facing.scale.x = -1.0 if direction.x < 0.0 else 1.0

func set_intent(charging: bool) -> void:
	if _ready_stance == charging:
		return
	_ready_stance = charging
	ring.visible = is_player or charging
	if not is_player:
		ring.default_color = Color("e56c57")
	if _reaction.is_empty() and not reduced_motion:
		animation.play("ready" if charging else "idle")

func move_to(target: Vector2, immediate: bool = false) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var distance := position.distance_to(target)
	if immediate or reduced_motion or distance > 256.0:
		position = target
		return
	if distance < 0.1:
		return
	var direction := (target - position).normalized()
	face(direction)
	var charge := kind == "wader" and distance > 90
	var duration := 0.18 if charge else (0.26 if kind == "diver" else 0.2)
	_move_tween = create_tween()
	if charge:
		_move_tween.tween_interval(0.08)
	_move_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	play_reaction("attack" if charge else "step")

func play_reaction(reaction: String) -> void:
	if reduced_motion:
		_stop_pose()
		animation.stop()
		_reset_pose()
		if reaction == "hurt":
			body.modulate = Color("ffbdad")
			_pose_tween = create_tween()
			_pose_tween.tween_property(body, "modulate", Color.WHITE, 0.16)
		return
	# A hit after an attack still shows the attack's contact before recoil.
	if reaction == "hurt" and animation.current_animation in ["attack", "crab_attack", "wader_attack", "diver_attack"] and animation.current_animation_position < 0.17:
		animation.queue("hurt")
		return
	_stop_pose()
	animation.stop()
	_reset_pose()
	_reaction = reaction
	if reaction == "step":
		_stride_sign *= -1.0
		animation.play("step")
		if is_player:
			_stride_feet()
	elif reaction == "attack":
		var clip := kind + "_attack"
		animation.play(clip if animation.has_animation(clip) else "attack")
	elif animation.has_animation(reaction):
		animation.play(reaction)
	else:
		_reaction = ""
		animation.play("idle")

func _stride_feet() -> void:
	_pose_tween = create_tween().set_parallel(true)
	var left_offset := Vector2(_stride_sign * 3.5, -5.0)
	var right_offset := Vector2(-_stride_sign * 2.0, 1.0)
	_pose_tween.tween_property(left_foot, "position", _foot_left_rest + left_offset, 0.085).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(right_foot, "position", _foot_right_rest + right_offset, 0.085).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.chain().set_parallel(true)
	_pose_tween.tween_property(left_foot, "position", _foot_left_rest, 0.115).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(right_foot, "position", _foot_right_rest, 0.115).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _stop_pose() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_reaction = ""

func _reset_pose() -> void:
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	left_foot.position = _foot_left_rest
	right_foot.position = _foot_right_rest
	shadow.scale = Vector2.ONE

func _animation_finished(_clip: StringName) -> void:
	if animation.get_queue().size() > 0:
		return
	_reaction = ""
	_reset_pose()
	if not reduced_motion:
		animation.play("ready" if _ready_stance else "idle")
