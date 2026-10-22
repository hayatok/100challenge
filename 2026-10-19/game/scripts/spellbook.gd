extends RefCounted
## Content and exact upgrade values are shared by cards, codex, and combat.

const WEAPON_IDS := ["lightning", "moon", "thorn", "wisp", "frost", "bell"]
const RELIC_IDS := ["storm_ink", "moonstone", "thorn_seed", "lantern_oil", "ice_crystal", "silver_bell", "swift_boots", "magnet_ring", "ward_leaf", "blood_vial", "hourglass", "echo_mirror"]
const ENEMY_IDS := ["hound", "charger", "archer", "sentinel", "wisp", "bat", "boss_thorn", "boss_mirror", "boss_bell"]
const MAX_LEVEL := 5
const WEAPON_SLOTS := 3
const RELIC_SLOTS := 3

static func weapon_info(id: String) -> Dictionary:
	var info := {"id": id, "icon": id, "title": "雷", "body": "近い敵へ雷を放ち、直線上の敵を貫く。", "evolution": "天裂の雷", "requirement": "storm_ink", "max_level": MAX_LEVEL}
	match id:
		"moon":
			info.title = "月輪"
			info.body = "自分の周りに輪を広げ、一度ずつ敵を払う。"
			info.evolution = "双月の環"
			info.requirement = "moonstone"
		"thorn":
			info.title = "茨針"
			info.body = "扇状の針が敵を貫き、毒を残す。同じ詠唱は一体へ一度だけ当たる。"
			info.evolution = "常闇の茨"
			info.requirement = "thorn_seed"
		"wisp":
			info.title = "鬼火"
			info.body = "壁を越える追尾の火が、命中した場所で弾ける。"
			info.evolution = "道しるべの灯"
			info.requirement = "lantern_oil"
		"frost":
			info.title = "霜結"
			info.body = "敵の足元に霜の庭をつくり、動きを鈍らせる。"
			info.evolution = "冬の庭"
			info.requirement = "ice_crystal"
		"bell":
			info.title = "鐘波"
			info.body = "広がる音の輪が敵を押し戻し、足を止める。"
			info.evolution = "暁の鐘"
			info.requirement = "silver_bell"
	info.requirement_title = relic_info(str(info.requirement)).title
	info.evolution_id = id
	info.evolution_body = {"lightning": "雷が4本に増え、命中先から別の敵へ連鎖する。", "moon": "広い月輪を3重に放つ。", "thorn": "針が7本に増え、命中先に茨の庭を残す。", "wisp": "爆発が広がり、火が別の敵へ最大3回跳ぶ。", "frost": "霜の庭が広がり、命中のたびに敵を短く凍らせる。", "bell": "二重の鐘波が広がり、ボスの足も短く止める。"}.get(id, "")
	return info

static func relic_info(id: String) -> Dictionary:
	var info := {"id": id, "title": "", "body": "", "icon": id}
	match id:
		"storm_ink":
			info.title = "静電のインク"
			info.body = "本体の4回目の詠唱ごとに、その攻撃の威力+45%。残像も同じ強さで再現。"
		"moonstone":
			info.title = "月長石"
			info.body = "全ての魔法の範囲と太さ+22%。射程は変わらない。"
		"thorn_seed":
			info.title = "茨の種"
			info.body = "全ての魔法が3秒間、毎秒3の毒を付ける。茨針の毒には毎秒3を加える。"
		"lantern_oil":
			info.title = "灯火の油"
			info.body = "残像の魔法威力+30%。元の詠唱時に効果を記録する。"
		"ice_crystal":
			info.title = "氷晶"
			info.body = "全ての魔法が敵の移動を1.2秒間、30%遅くする。霜結の減速を弱めない。"
		"silver_bell":
			info.title = "銀の音叉"
			info.body = "挟撃で敵を0.45秒止める。ボスには0.2秒。"
		"swift_boots":
			info.title = "風縫いの靴"
			info.body = "移動速度+15%。魔法の威力−8%。残像との距離をつくりやすい。"
		"magnet_ring":
			info.title = "星屑の環"
			info.body = "経験値の回収範囲+90。経験値の雫から得る量+20%。"
		"ward_leaf":
			info.title = "守り葉"
			info.body = "18秒ごとに盾を1枚用意する。盾は次の被弾を一度防ぐ。上限1枚。"
		"blood_vial":
			info.title = "赤い小瓶"
			info.body = "最大HP+24。12体倒すごとにHPを2回復する。"
		"hourglass":
			info.title = "砂時計"
			info.body = "詠唱間隔−15%。魔法の威力−10%。"
		"echo_mirror":
			info.title = "欠けた鏡"
			info.body = "挟撃に必要な距離を100から70へ。挟撃の追加威力+10。"
	info.evolves = ""
	for weapon_id in WEAPON_IDS:
		if RELIC_IDS.find(id) == WEAPON_IDS.find(weapon_id) and RELIC_IDS.find(id) < 6:
			info.evolves = weapon_id
	return info

static func enemy_info(id: String) -> Dictionary:
	var labels := {"hound": ["影の群れ", "近づいてくる獣。道を分けて挟撃しよう。"], "charger": ["月牙の獣", "進路を示してから突進する。予告を横にかわそう。"], "archer": ["夜の射手", "赤い射線を示してから矢を放つ。障害物で矢を防げる。"], "sentinel": ["書庫の番人", "硬く大きな守り手。挟撃と毒が役に立つ。"], "wisp": ["迷い灯", "少し離れて3本の弾を放つ。射線を横に抜けよう。"], "bat": ["夜羽", "速い小さな群れ。周囲を払う魔法で道をつくろう。"], "boss_thorn": ["茨の庭守", "足元の茨と三叉の道を予告する。半分のHPで攻勢が変わる。"], "boss_mirror": ["鏡の司書", "交差する射線と鏡の円で通路を狭める。予告には必ず退路がある。"], "boss_bell": ["夜鐘の主", "音の輪と十字の鐘波を放つ。輪の内側か外側へ移ろう。"]}
	var data: Array = labels.get(id, [id, ""])
	return {"id": id, "title": data[0], "body": data[1], "icon": id}

static func _base_weapon(id: String, rank: int) -> Dictionary:
	var n := maxi(1, rank)
	var data := {"level": rank, "max_level": MAX_LEVEL, "evolved": false, "damage": 12.0, "count": 1, "range": 400.0, "width": 11.0, "radius": 0.0, "cooldown": 0.78, "power_scale": 1.0, "range_scale": 1.0, "radius_scale": 1.0, "cooldown_scale": 1.0, "pierce": 1, "poison": 0.0, "poison_duration": 0.0, "slow": 1.0, "slow_duration": 0.0, "stagger": 0.0}
	match id:
		"lightning":
			data.damage = [12.0, 14.0, 18.0, 22.0, 28.0][n - 1]
			data.count = [1, 2, 2, 2, 3][n - 1]
			data.range = 460.0 if n >= 3 else 400.0
			data.width = 16.0 if n >= 3 else 11.0
			data.cooldown = [0.78, 0.78, 0.78, 0.62, 0.56][n - 1]
		"moon":
			data.damage = [13.0, 17.0, 21.0, 26.0, 33.0][n - 1]
			data.radius = [118.0, 142.0, 158.0, 174.0, 190.0][n - 1]
			data.count = 2 if n >= 3 else 1
			data.cooldown = [2.15, 2.15, 2.0, 1.7, 1.45][n - 1]
		"thorn":
			data.damage = [13.0, 16.0, 19.0, 22.0, 26.0][n - 1]
			data.count = [2, 3, 4, 4, 5][n - 1]
			data.range = 620.0
			data.width = 16.0
			data.radius = 8.0
			data.pierce = 3 if n >= 4 else 2
			data.poison = 3.0 + float(n - 1)
			data.poison_duration = 2.5
			data.cooldown = [1.4, 1.4, 1.25, 1.12, 1.05][n - 1]
		"wisp":
			data.damage = [19.0, 23.0, 27.0, 31.0, 36.0][n - 1]
			data.count = [1, 1, 2, 2, 3][n - 1]
			data.range = 570.0
			data.radius = 42.0
			data.cooldown = [1.3, 1.2, 1.2, 1.1, 1.05][n - 1]
		"frost":
			data.damage = [6.0, 8.0, 10.0, 12.0, 15.0][n - 1]
			data.radius = [80.0, 90.0, 100.0, 110.0, 122.0][n - 1]
			data.range = 450.0
			data.count = 2 if n >= 4 else 1
			data.cooldown = [2.7, 2.6, 2.5, 2.4, 2.3][n - 1]
			data.slow = 0.5
			data.slow_duration = 1.0
		"bell":
			data.damage = [15.0, 19.0, 23.0, 28.0, 34.0][n - 1]
			data.radius = [220.0, 240.0, 265.0, 290.0, 320.0][n - 1]
			data.width = 46.0
			data.cooldown = [2.4, 2.35, 2.2, 2.0, 1.8][n - 1]
			data.stagger = 0.35
	return data

static func initial_weapons(starter: String = "lightning") -> Dictionary:
	if starter not in WEAPON_IDS:
		starter = "lightning"
	var result := {}
	for id in WEAPON_IDS:
		result[id] = _base_weapon(id, 1 if id == starter else 0)
	return result

static func _rebuild(id: String, previous: Dictionary, rank: int, evolved: bool) -> Dictionary:
	var data := _base_weapon(id, clampi(rank, 0, MAX_LEVEL))
	for scale in ["power_scale", "range_scale", "radius_scale", "cooldown_scale"]:
		data[scale] = float(previous.get(scale, 1.0))
	data.damage *= float(data.power_scale)
	data.range *= float(data.range_scale)
	data.radius *= float(data.radius_scale)
	data.width *= float(data.radius_scale)
	data.cooldown *= float(data.cooldown_scale)
	data.evolved = evolved
	if evolved:
		data.damage *= 1.25
		match id:
			"lightning":
				data.count = 4
				data.range += 100.0 * float(data.range_scale)
				data.width += 8.0
			"moon":
				data.count = 3
				data.radius += 30.0 * float(data.radius_scale)
			"thorn":
				data.count = 7
				data.pierce = 6
				data.poison += 3.0
				data.poison_duration = 5.0
			"wisp": data.radius = 90.0 * float(data.radius_scale)
			"frost":
				data.radius += 30.0 * float(data.radius_scale)
				data.slow = 0.3
				data.stagger = 0.25
			"bell":
				data.count = 2
				data.stagger = 0.6
	return data

static func rank_cap(chapter_index: int) -> int:
	return 3 + clampi(chapter_index, 0, 2)

static func rank_weapon(id: String, weapons: Dictionary, cap: int = MAX_LEVEL) -> bool:
	if id not in WEAPON_IDS or int(weapons[id].level) >= mini(MAX_LEVEL, cap):
		return false
	weapons[id] = _rebuild(id, weapons[id], int(weapons[id].level) + 1, false)
	return true

static func evolve_weapon(id: String, weapons: Dictionary, relics: Array, chapter_index: int = -1, treasure: bool = false) -> bool:
	if chapter_index != 2 or not treasure:
		return false
	if id not in WEAPON_IDS or int(weapons[id].level) != MAX_LEVEL or bool(weapons[id].evolved) or str(weapon_info(id).requirement) not in relics:
		return false
	weapons[id] = _rebuild(id, weapons[id], MAX_LEVEL, true)
	return true

static func weapon_summary(data: Dictionary, id: String) -> String:
	if int(data.level) == 0:
		return "未習得"
	var text := "威力 %.1f / %.2f秒ごと" % [float(data.damage), float(data.cooldown)]
	match id:
		"lightning": text += "\n%d本 / 射程 %.1f" % [int(data.count), float(data.range)]
		"frost": text += "\n%dか所 / 範囲 %.1f" % [int(data.count), float(data.radius)]
		"moon", "bell": text += "\n%d重 / 範囲 %.1f" % [int(data.count), float(data.radius)]
		"thorn": text += "\n%d本 / %d体を貫通 / 毒 %.1f毎秒" % [int(data.count), int(data.pierce), float(data.poison)]
		"wisp": text += "\n%d個 / 爆発範囲 %.1f" % [int(data.count), float(data.radius)]
	return text

static func equipped_ids(weapons: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id in WEAPON_IDS:
		if int(weapons[id].level) > 0:
			ids.append(id)
	return ids

static func offer(id: String, weapons: Dictionary, _speed: float = 215.0, _maximum_health: float = 100.0) -> Dictionary:
	var result := {"id": id, "kind": "heal", "title": "生命の栞", "tag": "回復", "body": "HPを28回復する。\n最大HPを超えては回復しない。", "effect": "HP +28", "icon": "heart", "specialization": false, "before": "", "after": "", "requirement": "", "full_slots": false, "replace_id": ""}
	if id.begins_with("spec_"):
		result.kind = "specialization"
		result.specialization = true
		match id:
			"spec_lightning":
				result.merge({"title": "雷の魔女", "tag": "専門化・貫通", "body": "雷の威力と射程が伸びる。\n月輪の威力は30%下がる。", "effect": "雷威力 +40% / 射程 +15%\n月輪威力 −30%", "icon": "lightning"}, true)
			"spec_moon":
				result.merge({"title": "月の魔女", "tag": "専門化・広域", "body": "月輪を習得し、大きく速くする。\n雷の射程は25%短くなる。", "effect": "月輪範囲 +40% / 間隔 −15%\n雷射程 −25%", "icon": "moon"}, true)
			"spec_echo":
				result.merge({"title": "残響の魔女", "tag": "専門化・挟撃", "body": "挟撃の追加威力が2倍に。\n全ての魔法の威力は15%下がる。", "effect": "挟撃 +100% / 魔法 −15%", "icon": "echo"}, true)
		return result
	if id.begins_with("relic:"):
		var relic_id := id.trim_prefix("relic:")
		var relic := relic_info(relic_id)
		result.merge({"kind": "relic", "item_id": relic_id, "title": relic.title, "body": relic.body, "effect": relic.body, "tag": "遺物・3枠", "icon": relic_id, "after": relic.body}, true)
		return result
	if id.begins_with("weapon:") or id.begins_with("evolve:"):
		var evolution := id.begins_with("evolve:")
		var weapon_id := id.get_slice(":", 1)
		var info := weapon_info(weapon_id)
		var previous: Dictionary = weapons[weapon_id]
		var next := _rebuild(weapon_id, previous, MAX_LEVEL if evolution else int(previous.level) + 1, evolution)
		var new_weapon := int(previous.level) == 0
		result.merge({"kind": "evolution" if evolution else "weapon", "item_id": weapon_id, "title": info.evolution if evolution else info.title, "body": info.evolution_body if evolution else info.body, "tag": "進化" if evolution else ("新しい魔法・3枠" if new_weapon else "魔法 Rank %d → %d" % [int(previous.level), int(next.level)]), "effect": weapon_summary(next, weapon_id), "icon": weapon_id, "before": weapon_summary(previous, weapon_id), "after": weapon_summary(next, weapon_id), "requirement": "第3章の宝箱 / Rank 5 ＋ %s" % info.requirement_title, "evolved": evolution}, true)
	return result

static func offers(weapons: Dictionary, level: int, speed: float, maximum_health: float, rng: RandomNumberGenerator, specialization: String = "未選択", relics: Array = [], treasure: bool = false, excluded: Array = [], chapter_index: int = 0) -> Array[Dictionary]:
	var ids: Array[String] = []
	if level >= 4 and specialization == "未選択" and not treasure:
		ids = ["spec_lightning", "spec_moon", "spec_echo"]
	else:
		var pool: Array[String] = []
		var progression: Array[String] = []
		var new_weapons: Array[String] = []
		var needed_relics: Array[String] = []
		var owned := equipped_ids(weapons)
		var cap := rank_cap(chapter_index)
		for weapon_id in WEAPON_IDS:
			var data: Dictionary = weapons[weapon_id]
			if int(data.level) < cap:
				var upgrade_id := "weapon:" + str(weapon_id)
				pool.append(upgrade_id)
				if int(data.level) > 0:
					progression.append(upgrade_id)
				else:
					new_weapons.append(upgrade_id)
			elif chapter_index == 2 and treasure and not bool(data.evolved) and int(data.level) == MAX_LEVEL and str(weapon_info(weapon_id).requirement) in relics:
				progression.push_front("evolve:" + str(weapon_id))
				pool.append("evolve:" + str(weapon_id))
			if int(data.level) > 0:
				var required := str(weapon_info(weapon_id).requirement)
				if required not in relics:
					needed_relics.append("relic:" + required)
		for relic_id in RELIC_IDS:
			if relic_id not in relics:
				pool.append("relic:" + str(relic_id))
		pool.append("heal")
		for old in excluded:
			pool.erase(str(old))
			progression.erase(str(old))
			new_weapons.erase(str(old))
			needed_relics.erase(str(old))
		if level == 2 and not treasure and excluded.is_empty():
			var starter := owned[0]
			var teaching := ["weapon:moon" if starter != "moon" else "weapon:lightning", "weapon:" + starter, "relic:" + str(weapon_info(starter).requirement)]
			for candidate in teaching:
				if candidate in pool and candidate not in ids:
					ids.append(candidate)
					pool.erase(candidate)
		else:
			if not progression.is_empty():
				var first := str(progression[0]) if str(progression[0]).begins_with("evolve:") else str(progression[rng.randi_range(0, progression.size() - 1)])
				ids.append(first)
				pool.erase(first)
			# A filled rank cap should introduce a different spell, not strand vacant slots.
			if owned.size() < WEAPON_SLOTS:
				var limit := 2 if progression.is_empty() else 1
				for i in range(limit):
					if new_weapons.is_empty() or ids.size() >= 3:
						break
					var next: String = new_weapons.pop_at(rng.randi_range(0, new_weapons.size() - 1))
					ids.append(next)
					pool.erase(next)
			if (treasure or relics.size() < RELIC_SLOTS) and not needed_relics.is_empty() and ids.size() < 3:
				var next: String = needed_relics[rng.randi_range(0, needed_relics.size() - 1)]
				ids.append(next)
				pool.erase(next)
		while ids.size() < 3 and not pool.is_empty():
			ids.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		if progression.is_empty() and owned.size() >= WEAPON_SLOTS and "heal" not in ids and "heal" not in excluded:
			ids[ids.size() - 1] = "heal"
	var result: Array[Dictionary] = []
	for id in ids:
		var card := offer(id, weapons, speed, maximum_health)
		if card.kind == "weapon" and int(weapons[card.item_id].level) == 0:
			card.full_slots = equipped_ids(weapons).size() >= WEAPON_SLOTS
		elif card.kind == "relic":
			card.full_slots = relics.size() >= RELIC_SLOTS
		elif id == "spec_moon" and int(weapons.moon.level) == 0:
			card.full_slots = equipped_ids(weapons).size() >= WEAPON_SLOTS
		if card.full_slots:
			card.body += "\n選択後に、交換する装備を選ぶ。"
		result.append(card)
	return result

static func specialize(id: String, weapons: Dictionary) -> String:
	match id:
		"spec_lightning":
			weapons.lightning.damage *= 1.4
			weapons.lightning.power_scale *= 1.4
			weapons.lightning.range *= 1.15
			weapons.lightning.range_scale *= 1.15
			weapons.moon.damage *= 0.7
			weapons.moon.power_scale *= 0.7
			return "雷の魔女"
		"spec_moon":
			if int(weapons.moon.level) == 0:
				rank_weapon("moon", weapons)
			weapons.moon.radius *= 1.4
			weapons.moon.radius_scale *= 1.4
			weapons.moon.cooldown *= 0.85
			weapons.moon.cooldown_scale *= 0.85
			weapons.lightning.range *= 0.75
			weapons.lightning.range_scale *= 0.75
			return "月の魔女"
		"spec_echo":
			for kind in WEAPON_IDS:
				weapons[kind].damage *= 0.85
				weapons[kind].power_scale *= 0.85
			return "残響の魔女"
	return "未選択"

static func apply(id: String, weapons: Dictionary) -> void:
	if id.begins_with("weapon:"):
		rank_weapon(id.get_slice(":", 1), weapons)
