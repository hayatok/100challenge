extends Node2D
## One resolved actor. Animation never modifies the simulation position.

@onready var body: Node2D = $Facing/BodyPivot
@onready var sprite: Sprite2D = $Facing/BodyPivot/Sprite
@onready var silhouette: Polygon2D = $Facing/BodyPivot/Silhouette
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var ring: Line2D = $GroundRing
@onready var health_back: Polygon2D = $HealthBack
@onready var health_fill: Polygon2D = $HealthFill

var reduced_motion := false
var is_player := false
var kind := ""
var _move_tween: Tween

func _ready() -> void:
	animation.animation_finished.connect(_animation_finished)

func configure(texture: Texture2D, actor_kind: String, player_actor: bool, reduce: bool) -> void:
	kind = actor_kind
	is_player = player_actor
	reduced_motion = reduce
	ring.visible = is_player
	if texture != null and sprite.texture != texture:
		sprite.texture = texture
		var desired_height := 97.0 if is_player else (47.0 if kind == "crab" else 83.0)
		var factor := desired_height / maxf(1.0, texture.get_height())
		sprite.scale = Vector2.ONE * factor
		sprite.position = Vector2(0.0, 20.0 - desired_height * 0.5)
		silhouette.visible = false
	elif texture == null:
		silhouette.visible = true
		sprite.texture = null
		silhouette.color = Color("d6aa64") if is_player else Color("81aaa4")
	if reduced_motion:
		animation.stop()
		_reset_pose()
	elif not animation.is_playing():
		animation.play("idle")

func set_health(hp: int, maximum: int) -> void:
	var show_health := not is_player and hp < maximum
	health_back.visible = show_health
	health_fill.visible = show_health
	var fraction := clampf(float(hp) / maxf(float(maximum), 1.0), 0.0, 1.0)
	health_fill.polygon = PackedVector2Array([Vector2(-18, -1), Vector2(-18 + 36 * fraction, -1), Vector2(-18 + 36 * fraction, 1), Vector2(-18, 1)])
	var bar_y := -82.0 if is_player else (-38.0 if kind == "crab" else -67.0)
	health_back.position.y = bar_y
	health_fill.position.y = bar_y

func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		$Facing.scale.x = -1.0 if direction.x < 0.0 else 1.0

func move_to(target: Vector2, immediate: bool = false) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if immediate or reduced_motion or position.distance_to(target) > 180.0:
		position = target
		return
	if position.distance_to(target) < 0.1:
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	play_reaction("step")

func play_reaction(reaction: String) -> void:
	if reduced_motion:
		_reset_pose()
		return
	_reset_pose()
	if animation.has_animation(reaction):
		animation.play(reaction)

func _reset_pose() -> void:
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.modulate = Color.WHITE

func _animation_finished(_clip: StringName) -> void:
	if not reduced_motion:
		_reset_pose()
		animation.play("idle")
