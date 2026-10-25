class_name Rules
extends RefCounted

const World = preload("res://scripts/world_data.gd")
const ITEMS: Dictionary = {
	"knife": {"name": "回収ナイフ", "description": "隣の敵を攻撃する。攻撃力3。", "category": "weapon", "icon": "knife", "value": 12, "attack": 3},
	"loanKnife": {"name": "貸出ナイフ", "description": "武器を持たずに出発すると借りられる。攻撃力3。帰還時に返却する。", "category": "weapon", "icon": "knife", "value": 0, "attack": 3},
	"harpoon": {"name": "銛", "description": "攻撃力5の武器。装備に1手。", "category": "weapon", "icon": "harpoon", "value": 32, "attack": 5},
	"coat": {"name": "厚手の雨具", "description": "敵から受けるダメージを1減らす。装備に1手。", "category": "armor", "icon": "coat", "value": 18, "defense": 1},
	"medicine": {"name": "救急包", "description": "体力を10回復する。使用に1手。", "category": "consumable", "icon": "medicine", "value": 8},
	"bomb": {"name": "爆薬", "description": "隣の壁を壊す。着弾点と周囲1マスの敵に8ダメージ。使用に1手。自分は傷つかない。", "category": "consumable", "icon": "bomb", "value": 14},
	"flare": {"name": "発煙筒", "description": "隣の場所へ投げ、8マス以内の敵を4手引きつける。使用に1手。", "category": "consumable", "icon": "flare", "value": 9},
	"scrap": {"name": "銅の端材", "description": "港の灯りの修理に1個使う。", "category": "material", "icon": "scrap", "value": 6},
	"core": {"name": "灯台の集光芯", "description": "持ち帰り、銅の端材1個と合わせて港の灯りを直す。次の遠征から視界が1マス広がる。", "category": "material", "icon": "core", "value": 50},
	"pearl": {"name": "潮真珠", "description": "沈んだ街で見つかる宝。持ち帰ると倉庫に残る。", "category": "treasure", "icon": "pearl", "value": 24}}
const ENEMIES: Dictionary = {
	"crab": {"name": "錆ガニ", "description": "近づくと追い、隣で爪を振るう。", "hp": 5, "attack": 2},
	"wader": {"name": "潮歩き", "description": "縦横3マス以内で構え、次の手に直線を突進する。横へ避けよう。", "hp": 7, "attack": 3},
	"diver": {"name": "潜り守", "description": "灯台を守る重い潜水服。偶数の手だけ動き、隣で強く殴る。", "hp": 11, "attack": 4}}
const CHARACTERS: Dictionary = {
	"isana": {"name": "イサナ", "role": "運び屋", "description": "道具を大事にする、人懐こい運び屋。", "trait": "携行枠＋2", "color": "#e4b36b", "idleLine": "持ち帰る分の鞄も空けておこう。", "returnLine": "ただいま。ちゃんと持って帰ったよ。", "emptyLine": "身軽で帰ってきちゃった。次は収穫も欲しいね。", "lossLine": "次は荷物を欲張らずに行こう。"},
	"ritsu": {"name": "リツ", "role": "潜水士", "description": "危険を先に見て動く、落ち着いた潜水士。", "trait": "最大体力＋4", "color": "#abbfce", "idleLine": "潮と帰り道を確かめてから。", "returnLine": "港に着いた。これで一息。", "emptyLine": "無事に戻れた。今日はそれでよし。", "lossLine": "あの一手を覚えておく。"},
	"kohaku": {"name": "コハク", "role": "整備士", "description": "壊れた物にも使い道を見つける、快活な整備士。", "trait": "近接攻撃力＋1", "color": "#df977c", "idleLine": "使える物なら、あたしが直すよ。", "returnLine": "いい部品だ。仕事が増えるね。", "emptyLine": "手ぶらか。次は何か拾って帰ろう。", "lossLine": "道具は失った。でも手は覚えてる。"},
	"sui": {"name": "スイ", "role": "測量士", "description": "潮と帰路を読む、静かで好奇心の強い測量士。", "trait": "視界＋1", "color": "#c2b5d5", "idleLine": "まだ地図にない道を見てみたい。", "returnLine": "今日の道を、地図に残しておく。", "emptyLine": "持ち帰る物はなかった。道は覚えたよ。", "lossLine": "次は、あの曲がり角から見直す。"}}
const DIRECTIONS: Array = [{"x": 0, "y": -1}, {"x": -1, "y": 0}, {"x": 1, "y": 0}, {"x": 0, "y": 1}]

static func new_game() -> Dictionary:
	var state: Dictionary = {"version": 1, "mode": "harbor", "character": "isana", "profile": {"stash": [], "runs": 0, "extracts": 0, "deaths": 0, "lampRepaired": false}, "loadout": [], "run": null, "result": null, "nextId": 1}
	for kind: String in ["knife", "coat", "medicine", "medicine", "bomb", "bomb", "flare", "flare"]:
		state.profile.stash.append(_new_item(state, kind))
	return state

static func _new_item(state: Dictionary, kind: String) -> Dictionary:
	var item: Dictionary = {"uid": "i%d" % int(state.nextId), "kind": kind}
	state.nextId += 1
	return item

static func stats(state: Dictionary) -> Dictionary:
	var run: Variant = state.get("run")
	var inventory: Array = run.inventory if run is Dictionary else state.loadout
	var attack: int = 1
	var defense: int = 0
	for item: Dictionary in inventory:
		var data: Dictionary = ITEMS[item.kind]
		if data.category == "weapon" and (item.uid == run.weapon if run is Dictionary else attack == 1):
			attack = data.attack
		if data.category == "armor" and (item.uid == run.armor if run is Dictionary else defense == 0):
			defense = data.defense
	var character: String = state.character
	return {"attack": attack + (1 if character == "kohaku" else 0), "defense": defense,
		"capacity": 14 if character == "isana" else 12, "maxHp": 28 if character == "ritsu" else 24,
		"sight": 5 + (1 if state.profile.lampRepaired else 0) + (1 if character == "sui" else 0)}

static func _distance(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a.x) - int(b.x)) + absi(int(a.y) - int(b.y))

static func _direction(dx: Variant, dy: Variant) -> bool:
	return _integer(dx, -1, 1) and _integer(dy, -1, 1) and abs(dx) + abs(dy) == 1

static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func _event(events: Array, kind: String, text: String, details: Dictionary = {}) -> void:
	var entry: Dictionary = {"type": kind, "text": text}
	entry.merge(details)
	events.append(entry)

static func _clear_sight(run: Dictionary, from: Dictionary, to: Dictionary) -> bool:
	var x: int = int(from.x)
	var y: int = int(from.y)
	var nx: int = absi(int(to.x) - x)
	var ny: int = absi(int(to.y) - y)
	var sx: int = signi(int(to.x) - x)
	var sy: int = signi(int(to.y) - y)
	var ix: int = 0
	var iy: int = 0
	while ix < nx or iy < ny:
		var cross: int = (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if cross == 0:
			if run.tiles[y][x + sx].type == "wall" and run.tiles[y + sy][x].type == "wall":
				return false
			x += sx
			y += sy
			ix += 1
			iy += 1
		elif cross < 0:
			x += sx
			ix += 1
		else:
			y += sy
			iy += 1
		if x == int(to.x) and y == int(to.y):
			return true
		if run.tiles[y][x].type == "wall":
			return false
	return true

static func visible_tiles(run: Dictionary, radius: int = -1) -> Dictionary:
	if radius < 0:
		radius = int(run.sight)
	var visible: Dictionary = {}
	for y: int in range(maxi(0, int(run.player.y) - radius), mini(int(run.height) - 1, int(run.player.y) + radius) + 1):
		for x: int in range(maxi(0, int(run.player.x) - radius), mini(int(run.width) - 1, int(run.player.x) + radius) + 1):
			if (x - int(run.player.x)) ** 2 + (y - int(run.player.y)) ** 2 <= radius ** 2 and _clear_sight(run, run.player, {"x": x, "y": y}):
				visible[_key(x, y)] = true
	return visible

static func _remember(run: Dictionary) -> void:
	var seen: Dictionary = {}
	for tile: String in run.seen:
		seen[tile] = true
	seen.merge(visible_tiles(run))
	run.seen = seen.keys()

static func _value(items: Array) -> int:
	var total: int = 0
	for item: Dictionary in items:
		total += int(ITEMS[item.kind].value)
	return total

static func _finish(state: Dictionary, events: Array, outcome: String, cause: String) -> void:
	var run: Dictionary = state.run
	var receipt: Array = run.inventory.duplicate(true)
	if outcome == "extracted":
		# The free knife is returned, never converted into stash ownership.
		receipt = receipt.filter(func(item: Dictionary) -> bool: return item.kind != "loanKnife")
		state.profile.stash.append_array(receipt.duplicate(true))
		state.profile.extracts += 1
		_event(events, "extract", "%d個の品を倉庫に持ち帰った。貸出品は返却した。" % receipt.size(), {"x": run.exit.x, "y": run.exit.y, "amount": receipt.size()})
	else:
		state.profile.deaths += 1
		_event(events, "death", "倒れた。装備と携行品%d個を失った。倉庫の品は残る。" % receipt.size(), {"x": run.player.x, "y": run.player.y})
	state.result = {"outcome": outcome, "inventory": receipt, "turns": run.turn, "cause": cause, "value": _value(receipt)}
	state.run = null
	state.mode = "result"

static func _hurt(state: Dictionary, events: Array, amount: int, cause: String, actor_id: String) -> void:
	var player: Dictionary = state.run.player
	var damage: int = maxi(1, amount - int(stats(state).defense))
	player.hp = maxi(0, int(player.hp) - damage)
	_event(events, "hurt", "%s。体力が%d減った。" % [cause, damage], {"x": player.x, "y": player.y, "amount": damage, "actorId": actor_id})
	if int(player.hp) == 0:
		_finish(state, events, "dead", cause)

static func _strike(run: Dictionary, events: Array, enemy: Dictionary, damage: int, text: String) -> void:
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	_event(events, "attack", "%s。%sに%dダメージ。" % [text, ENEMIES[enemy.kind].name, damage], {"x": enemy.x, "y": enemy.y, "amount": damage, "actorId": enemy.id})
	if int(enemy.hp) == 0:
		_event(events, "kill", "%sを倒した。" % ENEMIES[enemy.kind].name, {"x": enemy.x, "y": enemy.y, "actorId": enemy.id})
		run.enemies = run.enemies.filter(func(other: Dictionary) -> bool: return other.id != enemy.id)

static func _enemy_at(run: Dictionary, x: int, y: int, except_id: String = "") -> Variant:
	for enemy: Dictionary in run.enemies:
		if int(enemy.x) == x and int(enemy.y) == y and enemy.id != except_id:
			return enemy
	return null

static func _next_step(run: Dictionary, enemy: Dictionary, target: Dictionary) -> Dictionary:
	if _distance(enemy, target) == 0:
		return {}
	var queue: Array = [{"x": enemy.x, "y": enemy.y, "first": {}}]
	var seen: Dictionary = {_key(int(enemy.x), int(enemy.y)): true}
	var index: int = 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		index += 1
		for d: Dictionary in DIRECTIONS:
			var x: int = int(cell.x) + int(d.x)
			var y: int = int(cell.y) + int(d.y)
			var k: String = _key(x, y)
			if seen.has(k) or not World.is_walkable(run, x, y) or _enemy_at(run, x, y, enemy.id) != null:
				continue
			var first: Dictionary = cell.first if not cell.first.is_empty() else {"x": x, "y": y}
			if x == int(target.x) and y == int(target.y):
				return first
			seen[k] = true
			queue.append({"x": x, "y": y, "first": first})
	return {}

static func _enemy_turn(state: Dictionary, events: Array) -> void:
	var run: Dictionary = state.run
	for enemy: Dictionary in run.enemies.duplicate():
		if state.run == null:
			break
		var definition: Dictionary = ENEMIES[enemy.kind]
		if int(enemy.get("stunned", 0)) > 0:
			enemy.stunned -= 1
			continue
		if enemy.has("target"):
			enemy.erase("intent")
			var lure_step: Dictionary = _next_step(run, enemy, enemy.target)
			if not lure_step.is_empty() and _distance(lure_step, run.player) != 0:
				enemy.x = lure_step.x
				enemy.y = lure_step.y
			enemy.target.turns -= 1
			if int(enemy.target.turns) <= 0:
				enemy.erase("target")
			continue
		if enemy.kind == "diver" and int(run.turn) % 2 != 0:
			continue
		if enemy.kind == "wader" and enemy.has("intent"):
			var intent: Dictionary = enemy.intent
			enemy.erase("intent")
			_event(events, "message", "%sが突進した。" % definition.name, {"x": enemy.x, "y": enemy.y, "actorId": enemy.id})
			for step: int in range(3):
				var x: int = int(enemy.x) + int(intent.dx)
				var y: int = int(enemy.y) + int(intent.dy)
				if not World.is_walkable(run, x, y) or _enemy_at(run, x, y, enemy.id) != null:
					break
				if int(run.player.x) == x and int(run.player.y) == y:
					_hurt(state, events, int(definition.attack) + 2, "%sの突進" % definition.name, enemy.id)
					break
				enemy.x = x
				enemy.y = y
			enemy["stunned"] = 1
			continue
		var reach: int = 4 if enemy.kind == "diver" else 7 if enemy.kind == "wader" else 6
		var dist: int = _distance(enemy, run.player)
		if dist > reach or not _clear_sight(run, enemy, run.player):
			continue
		if enemy.kind == "wader" and dist <= 3 and (enemy.x == run.player.x or enemy.y == run.player.y):
			# Dot assignment of a new field creates a StringName key. Resolved
			# state must contain ordinary String keys before save validation.
			enemy["intent"] = {"dx": signi(int(run.player.x) - int(enemy.x)), "dy": signi(int(run.player.y) - int(enemy.y))}
			_event(events, "message", "%sが構えた。次の手に3マス突進する。横へ避けよう。" % definition.name, {"x": enemy.x, "y": enemy.y, "actorId": enemy.id})
		elif dist == 1:
			_hurt(state, events, int(definition.attack), "%sの攻撃" % definition.name, enemy.id)
		else:
			var move: Dictionary = _next_step(run, enemy, run.player)
			if not move.is_empty():
				enemy["facing"] = {"x": int(move.x) - int(enemy.x), "y": int(move.y) - int(enemy.y)}
				enemy.x = move.x
				enemy.y = move.y

static func _resolve_turn(state: Dictionary, events: Array) -> void:
	var run: Dictionary = state.run
	run.turn += 1
	var tide: int = mini(3, int(run.turn) / 32)
	if tide != int(run.tide):
		run.tide = tide
		_event(events, "tide", "潮が第%d段階に上がった。低い道では毎手、体力が1減る。高架の帰路は沈まない。" % tide, {"amount": tide})
	elif int(run.turn) in [28, 60, 92]:
		_event(events, "message", "あと4手で潮が上がる。高架の道へ戻ろう。")
	_enemy_turn(state, events)
	if state.run != null and World.is_flooded(run, int(run.player.x), int(run.player.y)):
		run.player.hp = maxi(0, int(run.player.hp) - 1)
		_event(events, "hurt", "浸水した道で体力が1減った。", {"x": run.player.x, "y": run.player.y, "amount": 1})
		if int(run.player.hp) == 0:
			_finish(state, events, "dead", "満ち潮にのまれた")
	if state.run != null:
		_remember(run)
		for entry: Dictionary in events:
			run.log.append(entry.text)
		while run.log.size() > 40:
			run.log.pop_front()

static func _invalid(input: Dictionary, text: String) -> Dictionary:
	return {"state": input, "events": [{"type": "message", "text": text}]}

static func _normalize(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for k: Variant in value:
			result[k] = _normalize(value[k])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value:
			result.append(_normalize(child))
		return result
	return value

static func apply_action(input: Dictionary, action: Dictionary) -> Dictionary:
	var state: Dictionary = _normalize(input)
	var events: Array = []
	var kind: String = str(action.get("type", ""))
	if state.mode == "result":
		if kind != "return":
			return _invalid(input, "港へ戻ってから操作しよう。")
		state.mode = "harbor"
		state.result = null
		return {"state": state, "events": events}
	if state.mode == "harbor":
		return _harbor_action(input, state, action, events)
	var run: Dictionary = state.run
	if kind == "move":
		if not _direction(action.get("dx"), action.get("dy")):
			return _invalid(input, "上下左右の1マスを選ぼう。")
		var x: int = int(run.player.x) + int(action.dx)
		var y: int = int(run.player.y) + int(action.dy)
		if not World.is_walkable(run, x, y):
			return _invalid(input, "壁や深い水は通れない。")
		run.player.facing = {"x": int(action.dx), "y": int(action.dy)}
		var enemy: Variant = _enemy_at(run, x, y)
		if enemy != null:
			_strike(run, events, enemy, stats(state).attack, "武器で攻撃した")
		else:
			run.player.x = x
			run.player.y = y
			_event(events, "move", "1マス進んだ。", {"x": x, "y": y})
	elif kind == "wait":
		_event(events, "message", "その場で様子を見た。")
	elif kind == "interact":
		if _distance(run.player, run.exit) == 0:
			_finish(state, events, "extracted", "船着き場から帰還した")
			return {"state": state, "events": events}
		var nearest: Dictionary = {}
		for container: Dictionary in run.containers:
			if _distance(container, run.player) <= 1 and not container.items.is_empty():
				if nearest.is_empty() or _distance(container, run.player) < _distance(nearest, run.player):
					nearest = container
		if nearest.is_empty():
			return _invalid(input, "足元か隣に調べられる荷箱はない。")
		var room: int = int(stats(state).capacity) - run.inventory.size()
		if room <= 0:
			return _invalid(input, "携行枠がいっぱい。品を置いてから調べよう。")
		var names: PackedStringArray = []
		while room > 0 and not nearest.items.is_empty():
			var found: Dictionary = nearest.items.pop_front()
			run.inventory.append(found)
			names.append(ITEMS[found.kind].name)
			room -= 1
		nearest.searched = true
		_event(events, "loot", "%sを拾った。%s" % ["、".join(names), "残り%d個は荷箱に残した。" % nearest.items.size() if not nearest.items.is_empty() else ""], {"x": nearest.x, "y": nearest.y, "amount": names.size()})
	elif kind == "equip":
		var item: Dictionary = _find_item(run.inventory, action.get("uid"))
		if item.is_empty() or ITEMS[item.kind].category not in ["weapon", "armor"]:
			return _invalid(input, "装備できるのは武器と雨具。")
		var slot: String = ITEMS[item.kind].category
		if run[slot] == item.uid:
			return _invalid(input, "すでに装備している。")
		run[slot] = item.uid
		_event(events, "equip", "%sを装備した。" % ITEMS[item.kind].name)
	elif kind == "drop":
		var item: Dictionary = _find_item(run.inventory, action.get("uid"))
		if item.is_empty():
			return _invalid(input, "その品は持っていない。")
		run.inventory.erase(item)
		for slot: String in ["weapon", "armor"]:
			if run[slot] == item.uid:
				run[slot] = null
		var ground: Dictionary = {}
		for container: Dictionary in run.containers:
			if _distance(container, run.player) == 0:
				ground = container
				break
		if ground.is_empty():
			ground = {"id": "ground-%d-%s" % [int(run.turn), item.uid], "x": run.player.x, "y": run.player.y, "items": [], "searched": false}
			run.containers.append(ground)
		ground.items.append(item)
		ground.searched = false
		_event(events, "loot", "%sを足元に置いた。" % ITEMS[item.kind].name, {"x": run.player.x, "y": run.player.y})
	elif kind == "use":
		var error: String = _use_item(state, action, events)
		if not error.is_empty():
			return _invalid(input, error)
	else:
		return _invalid(input, "その操作はできない。")
	_resolve_turn(state, events)
	return {"state": state, "events": events}

static func _find_item(items: Array, uid: Variant) -> Dictionary:
	for item: Dictionary in items:
		if item.uid == uid:
			return item
	return {}

static func _harbor_action(input: Dictionary, state: Dictionary, action: Dictionary, events: Array) -> Dictionary:
	var kind: String = str(action.get("type", ""))
	if kind == "choose":
		if not CHARACTERS.has(action.get("character")):
			return _invalid(input, "出発する仲間を選ぼう。")
		var capacity: int = 14 if action.character == "isana" else 12
		if state.loadout.size() > capacity:
			return _invalid(input, "持ち出す品を12個以下にしてから交代しよう。")
		state.character = action.character
	elif kind in ["pack", "unpack"]:
		var source: Array = state.profile.stash if kind == "pack" else state.loadout
		var destination: Array = state.loadout if kind == "pack" else state.profile.stash
		var item: Dictionary = _find_item(source, action.get("uid"))
		if item.is_empty():
			return _invalid(input, "その品は見つからない。")
		if kind == "pack" and destination.size() >= int(stats(state).capacity):
			return _invalid(input, "携行枠がいっぱい。")
		source.erase(item)
		destination.append(item)
	elif kind == "repair":
		if state.profile.lampRepaired:
			return _invalid(input, "港の灯りは修理済み。")
		var core: Dictionary = {}
		var scrap: Dictionary = {}
		for item: Dictionary in state.profile.stash:
			if item.kind == "core":
				core = item
			if item.kind == "scrap":
				scrap = item
		if core.is_empty() or scrap.is_empty():
			return _invalid(input, "倉庫に灯台の集光芯と銅の端材が1個ずつ必要。")
		state.profile.stash.erase(core)
		state.profile.stash.erase(scrap)
		state.profile.lampRepaired = true
		_event(events, "repair", "港の灯りを直した。次の遠征から視界が1マス広がる。")
	elif kind == "depart":
		if action.has("seed") and not _integer(action.seed, 0, 4294967295):
			return _invalid(input, "遠征の種は0から4294967295の整数で指定する。")
		var seed_value: int = int(action.get("seed", ((int(state.profile.runs) + 1) * 2654435761) & 0xffffffff))
		var world: Dictionary = World.create_world(seed_value, state.profile.lampRepaired)
		var inventory: Array = state.loadout
		var weapon: Variant = null
		var armor: Variant = null
		for item: Dictionary in inventory:
			if weapon == null and ITEMS[item.kind].category == "weapon":
				weapon = item.uid
			if armor == null and ITEMS[item.kind].category == "armor":
				armor = item.uid
		if weapon == null:
			if inventory.size() >= int(stats(state).capacity):
				return _invalid(input, "貸出ナイフのために携行枠を1個空けよう。")
			var loan: Dictionary = _new_item(state, "loanKnife")
			inventory.append(loan)
			weapon = loan.uid
		for container: Dictionary in world.containers:
			var items: Array = []
			for item: Dictionary in container.items:
				items.append(_new_item(state, item.kind))
			container.items = items
		var derived: Dictionary = stats(state)
		world.merge({"seed": seed_value, "turn": 0, "tide": 0, "player": {"x": world.exit.x, "y": world.exit.y, "hp": derived.maxHp, "maxHp": derived.maxHp, "facing": {"x": 0, "y": -1}}, "inventory": inventory, "weapon": weapon, "armor": armor, "seen": [], "log": []})
		world.sight = derived.sight
		state.run = world
		state.loadout = []
		state.mode = "expedition"
		state.profile.runs += 1
		_event(events, "depart", "船着き場を出た。北への高架は、満潮でも沈まない。")
		_remember(world)
		world.log.append(events[0].text)
	else:
		return _invalid(input, "港では持ち物を選んで出発しよう。")
	return {"state": state, "events": events}

static func _use_item(state: Dictionary, action: Dictionary, events: Array) -> String:
	var run: Dictionary = state.run
	var item: Dictionary = _find_item(run.inventory, action.get("uid"))
	if item.is_empty() or ITEMS[item.kind].category != "consumable":
		return "使える道具を選ぼう。"
	if item.kind == "medicine":
		if run.player.hp == run.player.maxHp:
			return "体力は満タン。"
		var healed: int = mini(10, int(run.player.maxHp) - int(run.player.hp))
		run.player.hp += healed
		_event(events, "use", "救急包で体力が%d回復した。" % healed, {"amount": healed})
	else:
		if not _direction(action.get("dx"), action.get("dy")):
			return "投げる方向を選ぼう。"
		var x: int = int(run.player.x) + int(action.dx)
		var y: int = int(run.player.y) + int(action.dy)
		if x <= 0 or y <= 0 or x >= int(run.width) - 1 or y >= int(run.height) - 1:
			return "街の外へは投げられない。"
		if item.kind == "bomb":
			var wall: bool = run.tiles[y][x].type == "wall"
			var targets: Array = run.enemies.filter(func(enemy: Dictionary) -> bool: return maxi(absi(int(enemy.x) - x), absi(int(enemy.y) - y)) <= 1)
			if not wall and targets.is_empty():
				return "そこに爆薬で壊せる壁や敵はいない。"
			if wall:
				run.tiles[y][x].type = "floor"
			_event(events, "use", "爆薬で壁を壊した。" if wall else "爆薬を投げた。", {"x": x, "y": y})
			for enemy: Dictionary in targets:
				_strike(run, events, enemy, 8, "爆薬が炸裂した")
		elif item.kind == "flare":
			if not World.is_walkable(run, x, y):
				return "発煙筒は通れる場所へ投げよう。"
			var targets: Array = run.enemies.filter(func(enemy: Dictionary) -> bool: return _distance(enemy, {"x": x, "y": y}) <= 8)
			if targets.is_empty():
				return "近くに引きつけられる敵はいない。"
			for enemy: Dictionary in targets:
				enemy["target"] = {"x": x, "y": y, "turns": 4}
				enemy.erase("intent")
			_event(events, "use", "発煙筒へ%d体の敵を引きつけた。" % targets.size(), {"x": x, "y": y, "amount": targets.size()})
	run.inventory.erase(item)
	return ""

static func _fields(value: Variant, required: Array, optional: Array = []) -> bool:
	if not value is Dictionary:
		return false
	for field: String in required:
		if not value.has(field):
			return false
	for field: Variant in value:
		if not field is String or (field not in required and field not in optional):
			return false
	return true

static func _integer(value: Variant, minimum: int = 0, maximum: int = 1000000000) -> bool:
	if not value is int and not value is float:
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floor(float(value))

static func _text(value: Variant, maximum: int = 200) -> bool:
	return value is String and not value.is_empty() and value.length() <= maximum

static func _list(value: Variant, maximum: int) -> bool:
	return value is Array and value.size() <= maximum

static func _position(value: Variant) -> bool:
	return _fields(value, ["x", "y"]) and _integer(value.x, 0, 24) and _integer(value.y, 0, 24)

static func _vector(value: Variant) -> bool:
	return _fields(value, ["x", "y"]) and _direction(value.x, value.y)

static func _item(value: Variant) -> bool:
	if not _fields(value, ["uid", "kind"]) or not _text(value.uid, 10) or not value.kind is String or not ITEMS.has(value.kind):
		return false
	var number: String = value.uid.substr(1)
	return value.uid.begins_with("i") and number.is_valid_int() and int(number) > 0 and str(int(number)) == number

static func _items(value: Variant, maximum: int) -> bool:
	if not _list(value, maximum):
		return false
	for item: Variant in value:
		if not _item(item):
			return false
	return true

static func _unique_items(items: Array, next_id: int) -> bool:
	var ids: Dictionary = {}
	for item: Dictionary in items:
		if ids.has(item.uid) or int(item.uid.substr(1)) >= next_id:
			return false
		ids[item.uid] = true
	return true

# Accept integral JSON floats, then normalize only when applying a valid action.
static func validate_state(value: Variant) -> bool:
	if not _fields(value, ["version", "mode", "character", "profile", "loadout", "run", "result", "nextId"]):
		return false
	if value.version != 1 or not _integer(value.version, 1, 1) or value.mode not in ["harbor", "expedition", "result"] or not value.character is String or not CHARACTERS.has(value.character) or not _integer(value.nextId, 1):
		return false
	var profile: Variant = value.profile
	if not _fields(profile, ["stash", "runs", "extracts", "deaths", "lampRepaired"]):
		return false
	if not _items(profile.stash, 10000) or not _integer(profile.runs) or not _integer(profile.extracts) or not _integer(profile.deaths) or not profile.lampRepaired is bool:
		return false
	for item: Dictionary in profile.stash:
		if item.kind == "loanKnife":
			return false
	var capacity: int = 14 if value.character == "isana" else 12
	if not _items(value.loadout, capacity):
		return false
	for item: Dictionary in value.loadout:
		if item.kind == "loanKnife":
			return false
	var all: Array = profile.stash.duplicate()
	all.append_array(value.loadout)
	if value.mode == "expedition":
		if value.result != null or not value.loadout.is_empty() or not _valid_run(value.run, value.character, profile.lampRepaired, all):
			return false
	elif value.run != null:
		return false
	if value.mode == "result":
		var receipt: Variant = value.result
		if not value.loadout.is_empty() or not _fields(receipt, ["outcome", "inventory", "turns", "cause", "value"]):
			return false
		if receipt.outcome not in ["extracted", "dead"] or not _items(receipt.inventory, capacity) or not _integer(receipt.turns) or not _text(receipt.cause) or not _integer(receipt.value) or receipt.value != _value(receipt.inventory) or not _unique_items(receipt.inventory, int(value.nextId)):
			return false
		if receipt.outcome == "extracted" and int(profile.extracts) == 0 or receipt.outcome == "dead" and int(profile.deaths) == 0:
			return false
		for item: Dictionary in receipt.inventory:
			var owned: Dictionary = _find_item(profile.stash, item.uid)
			if receipt.outcome == "extracted" and (owned.is_empty() or owned.kind != item.kind or item.kind == "loanKnife"):
				return false
			if receipt.outcome == "dead" and not owned.is_empty():
				return false
	elif value.result != null:
		return false
	if int(profile.runs) != int(profile.extracts) + int(profile.deaths) + (1 if value.mode == "expedition" else 0):
		return false
	return _unique_items(all, int(value.nextId))

static func _valid_run(run: Variant, character: String, lamp: bool, all: Array) -> bool:
	if not _fields(run, ["seed", "turn", "tide", "player", "inventory", "weapon", "armor", "tiles", "width", "height", "enemies", "containers", "seen", "exit", "log", "goal", "sight"]):
		return false
	if not _integer(run.seed, 0, 4294967295) or not _integer(run.turn) or not _integer(run.tide, 0, 3) or int(run.tide) != mini(3, int(run.turn) / 32) or not _integer(run.width, 25, 25) or not _integer(run.height, 25, 25):
		return false
	var sight: int = 5 + (1 if lamp else 0) + (1 if character == "sui" else 0)
	var max_hp: int = 28 if character == "ritsu" else 24
	if not _integer(run.sight, sight, sight) or not _fields(run.player, ["x", "y", "hp", "maxHp", "facing"]) or not _integer(run.player.x, 0, 24) or not _integer(run.player.y, 0, 24) or not _integer(run.player.maxHp, max_hp, max_hp) or not _integer(run.player.hp, 1, max_hp) or not _vector(run.player.facing):
		return false
	if not _list(run.tiles, 25) or run.tiles.size() != 25:
		return false
	var exit_count: int = 0
	for row: Variant in run.tiles:
		if not _list(row, 25) or row.size() != 25:
			return false
		for tile: Variant in row:
			if not _fields(tile, ["type", "elevation", "zone"], ["variant"]) or tile.type not in ["floor", "wall", "water", "gate", "exit"] or not _integer(tile.elevation, 0, 9) or not _text(tile.zone, 30):
				return false
			if tile.has("variant") and not _integer(tile.variant, 0, 3):
				return false
			if tile.type == "exit":
				exit_count += 1
	if exit_count != 1 or not _position(run.exit) or not _position(run.goal) or run.tiles[int(run.exit.y)][int(run.exit.x)].type != "exit" or not World.is_walkable(run, int(run.player.x), int(run.player.y)) or not World.is_walkable(run, int(run.goal.x), int(run.goal.y)):
		return false
	if not _items(run.inventory, 14 if character == "isana" else 12):
		return false
	all.append_array(run.inventory)
	for slot: String in ["weapon", "armor"]:
		if run[slot] != null:
			var equipped: Dictionary = _find_item(run.inventory, run[slot])
			if equipped.is_empty() or ITEMS[equipped.kind].category != slot:
				return false
	if not _list(run.enemies, 100):
		return false
	var enemy_ids: Dictionary = {}
	var occupied: Dictionary = {}
	for enemy: Variant in run.enemies:
		if not _fields(enemy, ["id", "kind", "x", "y", "hp"], ["facing", "intent", "stunned", "target"]) or not _text(enemy.id, 80) or not enemy.kind is String or not ENEMIES.has(enemy.kind) or not _integer(enemy.x, 0, 24) or not _integer(enemy.y, 0, 24) or not _integer(enemy.hp, 1, int(ENEMIES[enemy.kind].hp)):
			return false
		if not World.is_walkable(run, int(enemy.x), int(enemy.y)) or _distance(enemy, run.player) == 0 or enemy_ids.has(enemy.id) or occupied.has(_key(int(enemy.x), int(enemy.y))):
			return false
		enemy_ids[enemy.id] = true
		occupied[_key(int(enemy.x), int(enemy.y))] = true
		if enemy.has("facing") and not _vector(enemy.facing):
			return false
		if enemy.has("stunned") and not _integer(enemy.stunned, 0, 4):
			return false
		if enemy.has("intent") and (enemy.kind != "wader" or not _fields(enemy.intent, ["dx", "dy"]) or not _direction(enemy.intent.dx, enemy.intent.dy)):
			return false
		if enemy.has("target") and (not _fields(enemy.target, ["x", "y", "turns"]) or not _integer(enemy.target.x, 0, 24) or not _integer(enemy.target.y, 0, 24) or not _integer(enemy.target.turns, 1, 4) or not World.is_walkable(run, int(enemy.target.x), int(enemy.target.y))):
			return false
	if not _list(run.containers, 1000):
		return false
	var container_ids: Dictionary = {}
	for container: Variant in run.containers:
		if not _fields(container, ["id", "x", "y", "items", "searched"]) or not _text(container.id, 100) or not _integer(container.x, 0, 24) or not _integer(container.y, 0, 24) or not _items(container.items, 100) or not container.searched is bool:
			return false
		if not World.is_walkable(run, int(container.x), int(container.y)) or container_ids.has(container.id):
			return false
		container_ids[container.id] = true
		all.append_array(container.items)
	if not _list(run.seen, 625) or not _list(run.log, 40):
		return false
	var seen: Dictionary = {}
	for cell: Variant in run.seen:
		if not cell is String or seen.has(cell):
			return false
		var parts: PackedStringArray = cell.split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return false
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		if x < 0 or y < 0 or x > 24 or y > 24 or cell != _key(x, y):
			return false
		seen[cell] = true
	for cell: String in visible_tiles(run):
		if not seen.has(cell):
			return false
	for line: Variant in run.log:
		if not _text(line, 500):
			return false
	return true
