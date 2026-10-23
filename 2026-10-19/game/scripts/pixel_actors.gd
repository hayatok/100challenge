extends RefCounted
## Painted source illustrations with retained regional paper-puppet poses.
## A logical frame selects a precomputed mesh; it is not another source drawing.

const KINDS := ["witch", "hound", "charger", "archer", "bat", "sentinel", "wisp", "boss_thorn", "boss_mirror", "boss_bell"]
const DISPLAY_SIZES := {
	"witch": 96.0, "hound": 80.0, "charger": 98.0, "archer": 88.0,
	"bat": 78.0, "sentinel": 98.0, "wisp": 82.0,
	"boss_thorn": 234.0, "boss_mirror": 232.0, "boss_bell": 242.0,
}
const FRAME_COUNT := 36
const GRID_COLUMNS := 16
const GRID_ROWS := 18
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
	"witch": preload("res://assets/art/witch-r2.png"),
	"hound": preload("res://assets/art/hound-r2.png"),
	"charger": preload("res://assets/art/charger-r2.png"),
	"archer": preload("res://assets/art/archer-r2.png"),
	"bat": preload("res://assets/art/bat-painted-r3.png"),
	"sentinel": preload("res://assets/art/sentinel-painted-r3.png"),
	"wisp": preload("res://assets/art/creatures-painted-r3.png"),
	"boss_thorn": preload("res://assets/art/boss-thorn.png"),
	"boss_mirror": preload("res://assets/art/boss-mirror.png"),
	"boss_bell": preload("res://assets/art/boss-bell.png"),
}
# Regions are fractions of the ORIGINAL image. The wisp uses the isolated right
# quarter of its sheet. Bounds trim transparent padding without resampling.
const SOURCE_REGIONS := {
	"witch": Rect2(0.1276, 0.0111, 0.8110, 0.9681),
	"hound": Rect2(0.0175, 0.0334, 0.9642, 0.9402),
	"charger": Rect2(0.0207, 0.0024, 0.9710, 0.9890),
	"archer": Rect2(0.0566, 0.0167, 0.9187, 0.9682),
	"bat": Rect2(0.046, 0.062, 0.936, 0.806),
	"sentinel": Rect2(0.031, 0.018, 0.951, 0.953),
	"wisp": Rect2(0.75, 0.0, 0.25, 1.0),
	"boss_thorn": Rect2(0.0, 0.0, 1.0, 1.0),
	"boss_mirror": Rect2(0.0, 0.0, 1.0, 1.0),
	"boss_bell": Rect2(0.003, 0.001, 0.994, 0.996),
}
# Ground/hover anchors are in each trimmed source region. Deformation vanishes
# at the anchor and below it, keeping the existing world/shadow contact stable.
const BODY_ANCHORS := {
	"witch": Vector2(0.51, 0.995), "hound": Vector2(0.65, 0.985),
	"charger": Vector2(0.54, 0.99), "archer": Vector2(0.54, 0.99),
	"bat": Vector2(0.53, 0.99), "sentinel": Vector2(0.50, 0.99), "wisp": Vector2(0.50, 0.96),
	"boss_thorn": Vector2(0.50, 0.99), "boss_mirror": Vector2(0.53, 0.94), "boss_bell": Vector2(0.50, 0.92),
}
# name, regional center/radius, gait displacement, action displacement,
# gait phase, idle weight, angular weight. All coordinates are source fractions.
# Compact smooth fields join adjacent regions without cuts through the drawing.
const RIGS := {
	"witch": [
		["cape", Vector2(0.31, 0.73), Vector2(0.36, 0.24), Vector2(0.030, -0.009), Vector2(-0.012, -0.016), 1.4, 0.25, 0.10],
		["near_leg", Vector2(0.57, 0.89), Vector2(0.12, 0.16), Vector2(0.040, -0.021), Vector2(0.005, -0.006), 0.0, 0.0, -0.09],
		["far_leg", Vector2(0.45, 0.86), Vector2(0.12, 0.16), Vector2(0.032, -0.025), Vector2(-0.005, -0.006), PI, 0.0, -0.09],
		["book_arm", Vector2(0.83, 0.48), Vector2(0.25, 0.23), Vector2(0.004, -0.010), Vector2(0.014, -0.080), 0.8, 0.3, 0.10],
		["hat_tip", Vector2(0.22, 0.18), Vector2(0.25, 0.23), Vector2(-0.015, 0.009), Vector2(-0.009, -0.007), 2.1, 0.25, -0.06],
	],
	"hound": [
		["near_paw", Vector2(0.85, 0.86), Vector2(0.19, 0.22), Vector2(0.052, -0.035), Vector2(0.034, -0.020), 0.0, 0.0, -0.13],
		["far_paw", Vector2(0.56, 0.67), Vector2(0.20, 0.22), Vector2(0.043, -0.036), Vector2(-0.014, 0.012), PI, 0.0, -0.12],
		["tail", Vector2(0.22, 0.29), Vector2(0.28, 0.32), Vector2(-0.020, 0.021), Vector2(-0.012, 0.012), 1.4, 0.28, 0.12],
		["jaw", Vector2(0.88, 0.64), Vector2(0.18, 0.19), Vector2(0.009, -0.005), Vector2(0.039, 0.022), 0.8, 0.1, 0.10],
	],
	"charger": [
		["near_hoof", Vector2(0.49, 0.84), Vector2(0.20, 0.24), Vector2(0.048, -0.031), Vector2(-0.014, 0.006), 0.0, 0.0, -0.12],
		["far_hoof", Vector2(0.72, 0.79), Vector2(0.20, 0.25), Vector2(0.049, -0.032), Vector2(0.027, -0.012), PI, 0.0, -0.12],
		["rear_hoof", Vector2(0.13, 0.73), Vector2(0.18, 0.20), Vector2(0.036, -0.026), Vector2(-0.016, 0.008), PI, 0.0, -0.09],
		["antlers", Vector2(0.66, 0.29), Vector2(0.38, 0.35), Vector2(0.006, -0.009), Vector2(0.025, 0.033), 0.8, 0.12, 0.09],
	],
	"archer": [
		["cloak", Vector2(0.23, 0.66), Vector2(0.31, 0.31), Vector2(0.035, -0.011), Vector2(-0.018, -0.013), 1.3, 0.25, 0.10],
		["near_leg", Vector2(0.66, 0.86), Vector2(0.15, 0.20), Vector2(0.037, -0.023), Vector2(0.009, 0.0), 0.0, 0.0, -0.10],
		["far_leg", Vector2(0.43, 0.81), Vector2(0.16, 0.20), Vector2(0.033, -0.023), Vector2(-0.008, 0.0), PI, 0.0, -0.10],
		["draw_hand", Vector2(0.61, 0.39), Vector2(0.20, 0.16), Vector2(0.0, -0.005), Vector2(-0.060, -0.018), 0.7, 0.08, -0.15],
		["bow_arm", Vector2(0.82, 0.48), Vector2(0.22, 0.37), Vector2(0.004, -0.007), Vector2(0.032, -0.009), 0.9, 0.05, 0.08],
	],
	"bat": [
		["left_wing", Vector2(0.24, 0.38), Vector2(0.29, 0.42), Vector2(-0.019, -0.072), Vector2(-0.026, -0.034), 0.0, 0.55, -0.24],
		["right_wing", Vector2(0.78, 0.55), Vector2(0.27, 0.35), Vector2(0.019, -0.072), Vector2(0.026, -0.034), 0.0, 0.55, 0.24],
		["tail", Vector2(0.50, 0.75), Vector2(0.18, 0.22), Vector2(0.018, 0.008), Vector2(0.0, -0.011), 1.4, 0.3, 0.10],
	],
	"sentinel": [
		["near_leg", Vector2(0.63, 0.86), Vector2(0.17, 0.22), Vector2(0.035, -0.021), Vector2(0.008, 0.0), 0.0, 0.0, -0.10],
		["far_leg", Vector2(0.31, 0.78), Vector2(0.17, 0.22), Vector2(0.032, -0.021), Vector2(-0.008, 0.0), PI, 0.0, -0.10],
		["shield", Vector2(0.77, 0.56), Vector2(0.26, 0.37), Vector2(0.006, -0.010), Vector2(-0.045, -0.034), 0.8, 0.1, -0.12],
		["weapon", Vector2(0.20, 0.58), Vector2(0.23, 0.31), Vector2(-0.009, -0.008), Vector2(0.020, -0.050), 1.1, 0.1, 0.16],
	],
	"wisp": [
		["flame", Vector2(0.48, 0.30), Vector2(0.30, 0.37), Vector2(0.026, -0.022), Vector2(0.0, -0.063), 0.0, 0.6, 0.18],
		["lantern", Vector2(0.51, 0.57), Vector2(0.27, 0.30), Vector2(-0.012, -0.013), Vector2(0.011, -0.028), PI, 0.32, -0.08],
		["smoke", Vector2(0.48, 0.79), Vector2(0.31, 0.22), Vector2(0.035, -0.014), Vector2(-0.014, -0.018), 1.2, 0.65, 0.16],
	],
	"boss_thorn": [
		["left_branches", Vector2(0.20, 0.52), Vector2(0.27, 0.34), Vector2(-0.015, 0.018), Vector2(-0.049, -0.048), 0.0, 0.25, -0.16],
		["right_branches", Vector2(0.81, 0.58), Vector2(0.25, 0.33), Vector2(0.016, -0.018), Vector2(0.052, -0.060), PI, 0.25, 0.16],
		["crown", Vector2(0.56, 0.20), Vector2(0.25, 0.27), Vector2(0.012, -0.010), Vector2(-0.012, -0.014), 1.0, 0.22, 0.08],
		["roots", Vector2(0.39, 0.86), Vector2(0.23, 0.22), Vector2(0.030, -0.020), Vector2(-0.012, 0.007), 0.0, 0.0, -0.07],
	],
	"boss_mirror": [
		["veil", Vector2(0.24, 0.66), Vector2(0.28, 0.35), Vector2(0.025, -0.010), Vector2(-0.036, -0.018), 1.0, 0.48, -0.10],
		["shield", Vector2(0.79, 0.43), Vector2(0.25, 0.29), Vector2(0.009, -0.009), Vector2(0.041, -0.022), 0.3, 0.15, 0.12],
		["sword_arm", Vector2(0.26, 0.53), Vector2(0.20, 0.30), Vector2(-0.009, 0.009), Vector2(-0.038, -0.044), 2.0, 0.15, -0.15],
		["mirror_crown", Vector2(0.52, 0.17), Vector2(0.17, 0.22), Vector2(0.010, -0.010), Vector2(0.0, -0.025), 0.5, 0.22, 0.06],
	],
	"boss_bell": [
		["left_mantle", Vector2(0.24, 0.58), Vector2(0.28, 0.35), Vector2(-0.018, -0.016), Vector2(-0.040, -0.048), 0.0, 0.4, -0.12],
		["right_mantle", Vector2(0.77, 0.58), Vector2(0.27, 0.35), Vector2(0.018, -0.016), Vector2(0.040, -0.048), PI, 0.4, 0.12],
		["clapper", Vector2(0.50, 0.61), Vector2(0.13, 0.19), Vector2(0.028, 0.006), Vector2(0.045, -0.012), 0.7, 0.75, 0.22],
		["smoke", Vector2(0.53, 0.80), Vector2(0.30, 0.23), Vector2(0.026, -0.012), Vector2(-0.020, -0.026), 1.3, 0.55, 0.12],
	],
}

var _atlases: Dictionary = {}
var _regions: Dictionary = {}
var _meshes: Dictionary = {}
var _pose_alpha: Dictionary = {}
var _aspect: Dictionary = {}
var _texture_ids: Array[int] = []
var _mesh_ids: Array[int] = []

static func display_size(kind: String) -> float:
	# Living and dissolving actors share this visual scale; combat shapes do not.
	return float(DISPLAY_SIZES.get(kind, 80.0))

func _init() -> void:
	var textures: Dictionary = {}
	for kind in KINDS:
		var source: Texture2D = SOURCES[kind]
		var source_id := source.get_instance_id()
		if not textures.has(source_id):
			var texture := CanvasTexture.new()
			texture.diffuse_texture = source
			texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			textures[source_id] = texture
			_texture_ids.append(texture.get_instance_id())
		_atlases[kind] = textures[source_id]
		var normalized: Rect2 = SOURCE_REGIONS[kind]
		var region := Rect2(normalized.position * source.get_size(), normalized.size * source.get_size())
		_regions[kind] = region
		_aspect[kind] = region.size / maxf(region.size.x, region.size.y)
		var poses: Array[ArrayMesh] = []
		var alphas: Array[float] = []
		for animation in ANIMATIONS:
			var track: Dictionary = ANIMATIONS[animation]
			for frame in range(int(track.count)):
				var mesh := _build_pose(kind, animation, frame)
				poses.append(mesh)
				_mesh_ids.append(mesh.get_instance_id())
				alphas.append(0.0 if animation == "death" and frame == 4 else 1.0)
		_meshes[kind] = poses
		_pose_alpha[kind] = alphas

func _influence(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var distance := (point - center) / radius
	var weight := maxf(0.0, 1.0 - distance.length_squared())
	return weight * weight

func _progress(animation: String, frame: int) -> float:
	return float(frame) / maxf(1.0, float(ANIMATIONS[animation].count) - 1.0)

func _action(animation: String, progress: float) -> float:
	match animation:
		"cast": return sin(progress * PI)
		"warning": return progress
		"rush": return 0.86
		"recover": return 1.0 - progress
		"hit": return -0.65 * (1.0 - progress)
		"arrival": return 0.24 * (1.0 - progress)
		"death": return -0.8 * progress
	return 0.0

func _deform(kind: String, point: Vector2, animation: String, frame: int) -> Vector2:
	var count := float(ANIMATIONS[animation].count)
	var cycle := float(frame) * TAU / count
	var progress := _progress(animation, frame)
	var action := _action(animation, progress)
	var anchor: Vector2 = BODY_ANCHORS[kind]
	var result := Vector2.ZERO
	for part in RIGS[kind]:
		var center: Vector2 = part[1]
		var radius: Vector2 = part[2]
		var gait := sin(cycle + float(part[5]))
		var amount := 0.0
		if animation == "walk":
			amount = gait
		elif animation == "rush":
			amount = gait * 1.35
		elif animation == "idle":
			amount = gait * float(part[6])
		var translation: Vector2 = (part[3] as Vector2) * amount + (part[4] as Vector2) * action
		var radial := point - center
		var rotation := Vector2(-radial.y, radial.x) * float(part[7]) * (amount + action * 0.7)
		result += (translation + rotation) * _influence(point, center, radius)
	var upper_body := 1.0 - smoothstep(0.62, anchor.y, point.y)
	if animation == "walk" or animation == "rush":
		result.y -= 0.009 * absf(sin(cycle)) * upper_body
	elif animation == "idle":
		result.y -= 0.003 * sin(cycle) * upper_body
	elif animation == "hit":
		result += Vector2(-0.027, 0.013) * (1.0 - progress) * upper_body
	elif animation == "warning":
		result += Vector2(-0.014, 0.022) * progress * upper_body
	elif animation == "arrival":
		result -= (point - anchor) * 0.16 * (1.0 - progress)
	elif animation == "death":
		result += Vector2((point.x - anchor.x) * 0.10 + sin(point.y * 23.0 + point.x * 7.0) * 0.028, (anchor.y - point.y) * 0.28) * progress
	# Keep the world contact stationary while one leg, hem, or root moves above it.
	result *= 1.0 - smoothstep(anchor.y - 0.025, anchor.y, point.y)
	return result

func _vertex_alpha(point: Vector2, animation: String, frame: int) -> float:
	var progress := _progress(animation, frame)
	if animation == "arrival":
		return lerpf(0.18, 1.0, progress)
	if animation != "death":
		return 1.0
	# A deterministic field breaks the drawing into fading regions, using vertex
	# colors on retained meshes. The last pose is fully transparent.
	var noise := fposmod(sin(floorf(point.x * 9.0) * 12.9898 + floorf(point.y * 11.0) * 78.233) * 43758.5453, 1.0)
	return clampf((1.0 - progress) * 1.8 - noise * 0.8, 0.0, 1.0)

func _build_pose(kind: String, animation: String, frame: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var region: Rect2 = _regions[kind]
	var source: Texture2D = SOURCES[kind]
	var anchor: Vector2 = BODY_ANCHORS[kind]
	var aspect: Vector2 = _aspect[kind]
	var cell := 96.0 if kind.begins_with("boss_") else 64.0
	for row in range(GRID_ROWS + 1):
		for column in range(GRID_COLUMNS + 1):
			var point := Vector2(float(column) / GRID_COLUMNS, float(row) / GRID_ROWS)
			var local := (point + _deform(kind, point, animation, frame) - anchor) * aspect * cell
			vertices.append(Vector3(local.x, local.y, 0.0))
			uvs.append((region.position + point * region.size) / source.get_size())
			colors.append(Color(1.0, 1.0, 1.0, _vertex_alpha(point, animation, frame)))
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			var top := row * (GRID_COLUMNS + 1) + column
			indices.append_array(PackedInt32Array([top, top + 1, top + GRID_COLUMNS + 1, top + 1, top + GRID_COLUMNS + 2, top + GRID_COLUMNS + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

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
	# Reduced mode holds a meaningful action pose. Death still reaches invisibility.
	if reduced_motion and animation != "death":
		return int(STILL_FRAMES[animation])
	if animation == "walk" and pose.has("gait"):
		return mini(count - 1, int(fposmod(_number(pose, "gait"), 1.0) * count))
	if pose.has("phase_progress") and animation in ["warning", "recover", "arrival", "death"]:
		return mini(count - 1, int(clampf(_number(pose, "phase_progress"), 0.0, 1.0) * count))
	if pose.has("cast") and animation == "cast":
		return mini(count - 1, int((1.0 - clampf(_number(pose, "cast"), 0.0, 1.0)) * count))
	var seconds := maxf(0.0, _number(pose, "time"))
	if bool(track.loop):
		return mini(count - 1, int(fposmod(seconds, float(count) / float(track.fps)) * float(track.fps)))
	return int(minf(seconds * float(track.fps), count - 1))

func frame_info(kind: String, pose: Dictionary = {}, reduced_motion: bool = false) -> Dictionary:
	var resolved := kind if _atlases.has(kind) else "hound"
	var animation := _animation(pose)
	var local_frame := _local_frame(pose, animation, reduced_motion)
	var index := int(ANIMATIONS[animation].start) + local_frame
	var cell := 96 if resolved.begins_with("boss_") else 64
	var source: Texture2D = SOURCES[resolved]
	return {
		"kind": resolved, "animation": animation, "frame": local_frame,
		"index": index, "region": _regions[resolved], "cell": cell,
		"anchor": (BODY_ANCHORS[resolved] as Vector2) * (_aspect[resolved] as Vector2) * cell,
		"facing": -1.0 if _number(pose, "facing", 1.0) < 0.0 else 1.0,
		"art_mode": "painted_regional_mesh", "source_frame": 0,
		"source_size": source.get_size(), "mesh_id": (_meshes[resolved][index] as ArrayMesh).get_instance_id(),
		"vertex_count": (GRID_COLUMNS + 1) * (GRID_ROWS + 1), "visible": float(_pose_alpha[resolved][index]) > 0.0,
	}

func pose_geometry(kind: String, pose: Dictionary = {}, reduced_motion: bool = false) -> Dictionary:
	# Inspection only: gameplay never reads back mesh arrays or source pixels.
	var info := frame_info(kind, pose, reduced_motion)
	var mesh: ArrayMesh = _meshes[info.kind][info.index]
	var arrays := mesh.surface_get_arrays(0)
	return {"vertices": arrays[Mesh.ARRAY_VERTEX], "uvs": arrays[Mesh.ARRAY_TEX_UV], "colors": arrays[Mesh.ARRAY_COLOR], "indices": arrays[Mesh.ARRAY_INDEX]}

func draw_actor(canvas: CanvasItem, at: Vector2, kind: String, size: float, pose: Dictionary, tint: Color, reduced_motion: bool = false) -> void:
	if not is_finite(size) or size <= 0.0 or not at.is_finite():
		return
	if not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b) or not is_finite(tint.a):
		return
	var resolved := kind if _atlases.has(kind) else "hound"
	var animation := _animation(pose)
	var index := int(ANIMATIONS[animation].start) + _local_frame(pose, animation, reduced_motion)
	if float(_pose_alpha[resolved][index]) <= 0.0:
		return
	var cell := 96.0 if resolved.begins_with("boss_") else 64.0
	var scale_factor := size / cell
	var facing := -1.0 if _number(pose, "facing", 1.0) < 0.0 else 1.0
	var local := Transform2D(Vector2(scale_factor * facing, 0.0), Vector2(0.0, scale_factor), at)
	if not local.x.is_finite() or not local.y.is_finite():
		return
	# A local draw_mesh transform composes with the caller's canvas transform;
	# it cannot reset a camera or move the next item drawn by the host.
	canvas.draw_mesh(_meshes[resolved][index], _atlases[resolved], local, tint)

func diagnostics() -> Dictionary:
	return {
		"art_mode": "painted_regional_mesh", "atlas_count": _texture_ids.size(),
		"source_count": _texture_ids.size(), "source_frames_per_actor": 1,
		"frame_count": FRAME_COUNT, "mesh_pose_count": _mesh_ids.size(), "region_count": KINDS.size(),
		"grid_columns": GRID_COLUMNS, "grid_rows": GRID_ROWS,
		"texture_ids": _texture_ids, "mesh_ids": _mesh_ids,
	}
