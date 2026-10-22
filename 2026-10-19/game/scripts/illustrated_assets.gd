extends RefCounted
## Shared, retained painted icons. Source PNGs remain unmodified and local.

const ITEMS := preload("res://assets/art/items-painted-r3.png")
const REWARDS := preload("res://assets/art/rewards-painted-r3.png")
const CHEST_OPEN := preload("res://assets/art/chest-open-painted-r3.png")
const Actors := preload("res://scripts/pixel_actors.gd")
const ENEMY_IDS := ["hound", "charger", "archer", "bat", "sentinel", "enemy_wisp", "boss_thorn", "boss_mirror", "boss_bell"]
const ITEM_REFERENCE_SIZE := Vector2(1774, 887)
const REWARD_REFERENCE_SIZE := Vector2(1448, 1086)
const ITEM_IDS := ["lightning", "moon", "thorn", "wisp", "frost", "bell", "storm_ink", "moonstone", "thorn_seed", "lantern_oil", "ice_crystal", "silver_bell", "swift_boots", "magnet_ring", "ward_leaf", "blood_vial", "hourglass", "echo_mirror"]
const REWARD_IDS := ["chapter_garden", "chapter_mirror", "chapter_bell", "dawn", "chest", "heart", "magnet", "shield", "blast", "echo", "power", "locked"]
# Measured visible alpha bounds plus two source pixels. Equal cell boundaries
# would crop ornaments, including the garden gate and the dawn's lower star.
const ITEM_REGIONS := [
	Rect2(69, 38, 194, 241), Rect2(344, 49, 223, 228), Rect2(626, 33, 232, 244), Rect2(946, 17, 194, 267), Rect2(1232, 35, 210, 250), Rect2(1506, 29, 235, 271),
	Rect2(64, 327, 188, 240), Rect2(350, 327, 198, 237), Rect2(640, 307, 213, 266), Rect2(957, 306, 164, 267), Rect2(1246, 312, 195, 252), Rect2(1533, 312, 167, 254),
	Rect2(27, 607, 234, 244), Rect2(364, 646, 194, 169), Rect2(632, 594, 213, 262), Rect2(966, 594, 158, 255), Rect2(1257, 593, 155, 253), Rect2(1532, 582, 212, 271)
]
const REWARD_REGIONS := [
	Rect2(33, 5, 349, 389), Rect2(431, 14, 307, 352), Rect2(760, 5, 308, 379), Rect2(1113, 6, 323, 369),
	Rect2(23, 404, 365, 308), Rect2(423, 378, 297, 329), Rect2(759, 405, 288, 301), Rect2(1125, 375, 285, 333),
	Rect2(23, 719, 351, 341), Rect2(408, 707, 317, 354), Rect2(787, 710, 261, 361), Rect2(1124, 709, 281, 364)
]
const ALIASES := {"heal": "heart", "ward": "shield", "treasure": "chest", "resonance": "echo", "specialization": "echo", "stride": "swift_boots"}
static var _icons: Dictionary = {}

static func warm_cache() -> void:
	if not _icons.is_empty():
		return
	_add_sheet(ITEMS, ITEM_REFERENCE_SIZE, ITEM_IDS, ITEM_REGIONS)
	_add_sheet(REWARDS, REWARD_REFERENCE_SIZE, REWARD_IDS, REWARD_REGIONS)
	var chest_scale := CHEST_OPEN.get_size() / Vector2(1312, 1199)
	_add_icon("chest_open", CHEST_OPEN, Rect2(Vector2(116, 41) * chest_scale, Vector2(1099, 1130) * chest_scale))
	for id in ENEMY_IDS:
		var actor_kind := "wisp" if id == "enemy_wisp" else str(id)
		var source: Texture2D = Actors.SOURCES[actor_kind]
		var normalized: Rect2 = Actors.SOURCE_REGIONS[actor_kind]
		_add_icon(str(id), source, Rect2(normalized.position * source.get_size(), normalized.size * source.get_size()))

static func _add_sheet(source: Texture2D, reference_size: Vector2, ids: Array, regions: Array) -> void:
	var source_scale := source.get_size() / reference_size
	for i in range(ids.size()):
		var authored: Rect2 = regions[i]
		_add_icon(str(ids[i]), source, Rect2(authored.position * source_scale, authored.size * source_scale))

static func _add_icon(id: String, source: Texture2D, region: Rect2) -> void:
	var icon := AtlasTexture.new()
	icon.atlas = source
	icon.region = region
	icon.filter_clip = true
	_icons[id] = icon

static func texture_for(id: String) -> AtlasTexture:
	warm_cache()
	var canonical := str(ALIASES.get(id, id))
	if canonical.begins_with("enemy:"):
		canonical = canonical.trim_prefix("enemy:")
		if canonical == "wisp":
			canonical = "enemy_wisp"
	return _icons.get(canonical) as AtlasTexture

static func cached_ids() -> Array:
	warm_cache()
	return _icons.keys()

static func draw_icon(canvas: CanvasItem, id: String, at: Vector2, extent: float, tint: Color = Color.WHITE) -> bool:
	var icon := texture_for(id)
	if icon == null or canvas == null or not at.is_finite() or not is_finite(extent) or extent <= 0:
		return false
	var dimensions := icon.get_size()
	var fit := extent / maxf(dimensions.x, dimensions.y)
	var destination := Rect2(at - dimensions * fit * 0.5, dimensions * fit)
	canvas.draw_texture_rect(icon, destination, false, tint)
	return true
