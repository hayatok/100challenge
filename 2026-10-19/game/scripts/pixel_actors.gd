extends RefCounted
## Combat-only original pixel artwork. All textures and frame regions are retained.

const KINDS := ["witch", "hound", "charger", "archer", "bat", "sentinel", "wisp", "boss_thorn", "boss_mirror", "boss_bell"]
const ATLAS_COLUMNS := 8
const FRAME_COUNT := 36
const GROUND_Y := {"hound": 53.0, "charger": 56.0, "sentinel": 58.0}
const ANIMATIONS := {
	"idle": {"start": 0, "count": 4, "fps": 4.0, "loop": true},
	"walk": {"start": 4, "count": 6, "fps": 10.0, "loop": true},
	"cast": {"start": 10, "count": 4, "fps": 12.0, "loop": false},
	"hit": {"start": 14, "count": 2, "fps": 10.0, "loop": false},
	"warning": {"start": 16, "count": 4, "fps": 8.0, "loop": false},
	"rush": {"start": 20, "count": 4, "fps": 12.0, "loop": true},
	"recover": {"start": 24, "count": 3, "fps": 10.0, "loop": false},
	"arrival": {"start": 27, "count": 4, "fps": 8.0, "loop": false},
	"death": {"start": 31, "count": 5, "fps": 10.0, "loop": false},
}
const STILL_FRAMES := {"idle": 0, "walk": 1, "cast": 2, "hit": 0, "warning": 2, "rush": 2, "recover": 1, "arrival": 3}
const SOURCES := {
	"witch": preload("res://assets/art/pixel-actors-witch.svg"),
	"hound": preload("res://assets/art/pixel-actors-hound.svg"),
	"charger": preload("res://assets/art/pixel-actors-charger.svg"),
	"archer": preload("res://assets/art/pixel-actors-archer.svg"),
	"bat": preload("res://assets/art/pixel-actors-bat.svg"),
	"sentinel": preload("res://assets/art/pixel-actors-sentinel.svg"),
	"wisp": preload("res://assets/art/pixel-actors-wisp.svg"),
	"boss_thorn": preload("res://assets/art/pixel-actors-boss-thorn.svg"),
	"boss_mirror": preload("res://assets/art/pixel-actors-boss-mirror.svg"),
	"boss_bell": preload("res://assets/art/pixel-actors-boss-bell.svg"),
}

var _atlases: Dictionary = {}
var _regions: Dictionary = {}

func _init() -> void:
	for kind in KINDS:
		# CanvasTexture supplies a filter override only for this artwork. The host
		# canvas can keep its linear illustration/font filtering unchanged.
		var texture := CanvasTexture.new()
		texture.diffuse_texture = SOURCES[kind]
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		_atlases[kind] = texture
		var cell := 96 if str(kind).begins_with("boss_") else 64
		var frames: Array[Rect2] = []
		for index in range(FRAME_COUNT):
			frames.append(Rect2(Vector2((index % ATLAS_COLUMNS) * cell, int(index / ATLAS_COLUMNS) * cell), Vector2.ONE * cell))
		_regions[kind] = frames

func _number(pose: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value: Variant = pose.get(key, fallback)
	if not (value is int or value is float):
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback

func _animation(pose: Dictionary) -> String:
	var requested := str(pose.get("animation", "idle"))
	return requested if ANIMATIONS.has(requested) else "idle"

func _local_frame(pose: Dictionary, animation: String, reduced_motion: bool) -> int:
	var track: Dictionary = ANIMATIONS[animation]
	var count := int(track.count)
	# Dissolution remains temporal because the final frame really is empty.
	# All decorative loops and cloth/wing motion stop in the reduced mode.
	if reduced_motion and animation != "death":
		return int(STILL_FRAMES[animation])
	if animation == "walk" and pose.has("gait"):
		return mini(count - 1, int(fposmod(_number(pose, "gait"), 1.0) * count))
	if pose.has("phase_progress") and animation in ["warning", "recover", "arrival", "death"]:
		return mini(count - 1, int(clampf(_number(pose, "phase_progress"), 0.0, 1.0) * count))
	if pose.has("cast") and animation == "cast":
		return mini(count - 1, int((1.0 - clampf(_number(pose, "cast"), 0.0, 1.0)) * count))
	var seconds := maxf(0.0, _number(pose, "time"))
	# Bound floating-point clocks before conversion; long sessions or malformed
	# finite timestamps cannot overflow the integer frame index.
	if bool(track.loop):
		return mini(count - 1, int(fposmod(seconds, float(count) / float(track.fps)) * float(track.fps)))
	return int(minf(seconds * float(track.fps), count - 1))

func frame_info(kind: String, pose: Dictionary = {}, reduced_motion: bool = false) -> Dictionary:
	var resolved := kind if _atlases.has(kind) else "hound"
	var animation := _animation(pose)
	var local_frame := _local_frame(pose, animation, reduced_motion)
	var index := int(ANIMATIONS[animation].start) + local_frame
	var cell := 96 if resolved.begins_with("boss_") else 64
	return {
		"kind": resolved, "animation": animation, "frame": local_frame,
		"index": index, "region": _regions[resolved][index], "cell": cell,
		"anchor": Vector2(cell * 0.5, float(GROUND_Y.get(resolved, cell - (6 if cell == 96 else 4)))),
		"facing": -1.0 if _number(pose, "facing", 1.0) < 0.0 else 1.0,
	}

func draw_actor(canvas: CanvasItem, at: Vector2, kind: String, size: float, pose: Dictionary, tint: Color, reduced_motion: bool = false) -> void:
	if not is_finite(size) or size <= 0.0 or not at.is_finite():
		return
	var resolved := kind if _atlases.has(kind) else "hound"
	var animation := _animation(pose)
	var index := int(ANIMATIONS[animation].start) + _local_frame(pose, animation, reduced_motion)
	var cell := 96.0 if resolved.begins_with("boss_") else 64.0
	var scale_factor := size / cell
	var foot := float(GROUND_Y.get(resolved, cell - (6.0 if cell == 96.0 else 4.0)))
	var flipped := _number(pose, "facing", 1.0) < 0.0
	var destination := Rect2(at - Vector2(size * 0.5, foot * scale_factor), Vector2.ONE * size)
	if flipped:
		destination.size.x = -size
	# No draw_set_transform call: every draw inherits and preserves the host
	# transform, including an existing camera or caller's composition transform.
	canvas.draw_texture_rect_region(_atlases[resolved], destination, _regions[resolved][index], tint, false, true)

func diagnostics() -> Dictionary:
	var ids: Array = []
	for kind in KINDS:
		ids.append((_atlases[kind] as CanvasTexture).get_instance_id())
	return {"atlas_count": _atlases.size(), "frame_count": FRAME_COUNT, "region_count": FRAME_COUNT * KINDS.size(), "texture_ids": ids}
