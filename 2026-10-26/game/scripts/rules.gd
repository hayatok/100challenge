class_name Rules
extends RefCounted

const V05 = preload("res://scripts/rules_v05.gd")
const V06 = preload("res://scripts/v06_rules.gd")
const Legacy = V05.Legacy
const World = V05.World
const Campaign = preload("res://scripts/v06_campaign.gd")
const ITEMS = V05.ITEMS
const ENEMIES = V05.ENEMIES
const CHARACTERS = V05.CHARACTERS
const DIRECTIONS = V05.DIRECTIONS

static func new_game() -> Dictionary:
	return V06.new_game()

static func _old_run(state: Dictionary) -> bool:
	return state.get("run") is Dictionary and state.run.get("ruleset") in ["legacy-v03", "encounter-v04"]

static func _upgrade(state: Dictionary) -> Dictionary:
	var result: Dictionary = V05._normalize(state)
	result.version = 4
	result["preparation"] = {"weapon": null, "armor": null}
	result.profile["commissionCycle"] = 0
	for item: Dictionary in result.loadout:
		var category: String = ITEMS[item.kind].category
		if category in ["weapon", "armor"] and result.preparation[category] == null:
			result.preparation[category] = item.uid
	return result

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("version") == 3:
		return V05.validate_state(value)
	return V06.validate_state(value)

static func migrate_state(value: Variant) -> Dictionary:
	if value is Dictionary and value.get("version") == 4:
		return V05._normalize(value) if V06.validate_state(value) else {}
	var old: Dictionary = V05.migrate_state(value)
	if old.is_empty():
		return {}
	return old if _old_run(old) else _upgrade(old)

static func apply_action(input: Dictionary, action: Dictionary) -> Dictionary:
	if _old_run(input):
		var resolved: Dictionary = V05.apply_action(input, action)
		# Preserve the frozen state through the exact terminal turn. Upgrade only
		# when the player explicitly leaves its result screen.
		return resolved
	if input.get("version") == 3:
		return V06.apply_action(_upgrade(input), action)
	return V06.apply_action(input, action)

static func current_district(state: Dictionary) -> Dictionary:
	return V05.current_district(state) if _old_run(state) else V06.current_district(state)

static func campaign_summary(state: Dictionary) -> Dictionary:
	return V05.campaign_summary(state) if _old_run(state) else V06.campaign_summary(state)

static func contracts(state: Dictionary) -> Array:
	return V05.contracts(state) if _old_run(state) else V06.contracts(state)

static func dialogue(state: Dictionary, character: String) -> Array:
	return V05.dialogue(state, character) if _old_run(state) else V06.dialogue(state, character)

static func shop_rows(state: Dictionary) -> Array:
	return V05.shop_rows(state) if _old_run(state) else V06.shop_rows(state)

static func stats(state: Dictionary) -> Dictionary:
	return V05.stats(state) if state.get("version") == 3 else V06.stats(state)

static func visible_tiles(run: Dictionary, radius: int = -1) -> Dictionary:
	return V05.visible_tiles(run, radius)

static func crew_info(state: Dictionary) -> Dictionary:
	return V05.crew_info(state) if _old_run(state) else V06.crew_info(state)

static func threats(state: Dictionary) -> Array:
	return V05.threats(state) if _old_run(state) else V06.threats(state)

static func preview_action(state: Dictionary, action: Dictionary) -> Dictionary:
	return V05.preview_action(state, action) if _old_run(state) else V06.preview_action(state, action)

static func nearby_containers(state: Dictionary) -> Array:
	return [] if _old_run(state) else V06.nearby_containers(state)

static func container_contents(state: Dictionary, id: String) -> Array:
	return [] if _old_run(state) else V06.container_contents(state, id)

static func contents(state: Dictionary, id: String) -> Array:
	return container_contents(state, id)

static func _distance(a: Dictionary, b: Dictionary) -> int:
	return V05._distance(a, b)

static func _enemy_at(run: Dictionary, x: int, y: int, except_id: String = "") -> Variant:
	return V05._enemy_at(run, x, y, except_id)

static func _find_item(items: Array, uid: Variant) -> Dictionary:
	return V05._find_item(items, uid)

static func _new_item(state: Dictionary, kind: String) -> Dictionary:
	return V05._new_item(state, kind)

static func _normalize(value: Variant) -> Variant:
	return V05._normalize(value)

static func _remember(run: Dictionary) -> void:
	V05._remember(run)
