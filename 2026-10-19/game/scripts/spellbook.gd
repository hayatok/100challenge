extends RefCounted
## Upgrade descriptions and the exact production values live together.

static func initial_weapons() -> Dictionary:
	return {
		"lightning": {"level": 1, "damage": 12.0, "count": 1, "range": 400.0, "width": 11.0, "cooldown": 0.78, "power_scale": 1.0, "range_scale": 1.0},
		"moon": {"level": 0, "damage": 13.0, "count": 1, "radius": 118.0, "cooldown": 2.15, "power_scale": 1.0, "radius_scale": 1.0}
	}

static func offer(id: String, weapons: Dictionary, speed: float, maximum_health: float) -> Dictionary:
	var lightning: Dictionary = weapons.lightning
	var moon: Dictionary = weapons.moon
	match id:
		"spec_lightning":
			return {"id": id, "specialization": true, "title": "雷の魔女", "tag": "専門化・貫通", "body": "雷の威力と射程が伸びる。\n月輪の威力は30%下がる。", "effect": "雷威力 +40% / 月輪威力 −30%", "icon": "lightning"}
		"spec_moon":
			return {"id": id, "specialization": true, "title": "月の魔女", "tag": "専門化・広域", "body": "月輪を習得、大きく速く。\n雷の射程は25%短くなる。", "effect": "月輪範囲 +40% / 雷射程 −25%", "icon": "moon"}
		"spec_echo":
			return {"id": id, "specialization": true, "title": "残響の魔女", "tag": "専門化・挟撃", "body": "挟撃の追加威力が2倍に。\n通常の魔法は15%弱まる。", "effect": "挟撃 +100% / 魔法 −15%", "icon": "echo"}
		"moon_unlock":
			return {"id": id, "title": "月輪をひらく", "tag": "新しい魔法", "body": "魔女と残像の周囲に\n月の輪が広がる。", "effect": "周囲に広がる / 2.15秒ごと", "icon": "moon"}
		"lightning_fork":
			return {"id": id, "title": "枝分かれの雷", "tag": "雷・弾数", "body": "別の敵へも雷を放つ。\n離れた群れを同時に狙う。", "effect": "雷 %d本 → %d本" % [lightning.count, int(lightning.count) + 1], "icon": "lightning"}
		"lightning_reach":
			return {"id": id, "title": "太く、遠くへ", "tag": "雷・攻撃範囲", "body": "雷の道が太く長くなる。\n並んだ敵を貫きやすい。", "effect": "太さ +%d%% / 射程 +%d%%" % [roundi(700.0 / float(lightning.width)), roundi(5500.0 * float(lightning.range_scale) / float(lightning.range))], "icon": "lightning"}
		"lightning_haste":
			return {"id": id, "title": "早口の詠唱", "tag": "雷・速さ", "body": "雷を放つ間隔を短くする。\n残像の雷も同じ速さに。", "effect": "間隔 %.2f秒 → %.2f秒" % [lightning.cooldown, maxf(0.44, float(lightning.cooldown) * 0.84)], "icon": "lightning"}
		"moon_range":
			return {"id": id, "title": "満ちゆく月", "tag": "月輪・攻撃範囲", "body": "月の輪が大きく広がる。\n自分の周りに道をつくる。", "effect": "輪の大きさ +%d%%" % roundi(3000.0 * float(moon.radius_scale) / float(moon.radius)), "icon": "moon"}
		"moon_double":
			return {"id": id, "title": "重なる月輪", "tag": "月輪・弾数", "body": "少し遅れて次の輪を放つ。\n追ってくる敵を押し返す。", "effect": "月輪 %d重 → %d重" % [moon.count, int(moon.count) + 1], "icon": "moon"}
		"moon_haste":
			return {"id": id, "title": "月の巡り", "tag": "月輪・速さ", "body": "月輪を放つ間隔を短くする。\n近づく敵を続けて払う。", "effect": "間隔 %.2f秒 → %.2f秒" % [moon.cooldown, maxf(1.10, float(moon.cooldown) * 0.82)], "icon": "moon"}
		"stride":
			return {"id": id, "title": "風をまとう靴", "tag": "移動・回収", "body": "歩く速さと回収範囲を広げる。\n残像との距離をつくりやすい。", "effect": "移動 +%d%% / 回収範囲も拡大" % roundi(1800.0 / speed), "icon": "stride"}
		"heal":
			return {"id": id, "title": "生命の栞", "tag": "体力・回復", "body": "最大HPが増え、HPも回復。\n少し強気に経験値を拾える。", "effect": "最大HP %d → %d  /  HP +36" % [maximum_health, maximum_health + 16], "icon": "heart"}
		_:
			return {"id": "power", "title": "魔術書の余白", "tag": "魔法・威力", "body": "二つの魔法の威力を上げる。\n専門にした魔法は伸びやすい。", "effect": "魔法の基礎威力 +3", "icon": "power"}

static func offers(weapons: Dictionary, level: int, speed: float, maximum_health: float, rng: RandomNumberGenerator, specialization: String = "未選択") -> Array[Dictionary]:
	var ids: Array[String] = []
	if level >= 4 and specialization == "未選択":
		ids = ["spec_lightning", "spec_moon", "spec_echo"]
	elif level == 2:
		ids = ["moon_unlock", "lightning_fork", "stride"]
	else:
		var pool: Array[String] = ["lightning_reach", "heal", "power"]
		if int(weapons.lightning.count) < 3:
			pool.append("lightning_fork")
		if float(weapons.lightning.cooldown) > 0.441:
			pool.append("lightning_haste")
		if speed < 268.0:
			pool.append("stride")
		if int(weapons.moon.level) == 0:
			ids.append("moon_unlock")
		else:
			pool.append("moon_range")
			if int(weapons.moon.count) < 2:
				pool.append("moon_double")
			if float(weapons.moon.cooldown) > 1.101:
				pool.append("moon_haste")
		while ids.size() < 3:
			var index := rng.randi_range(0, pool.size() - 1)
			ids.append(pool.pop_at(index))
	var result: Array[Dictionary] = []
	for id in ids:
		result.append(offer(id, weapons, speed, maximum_health))
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
			weapons.moon.level = maxi(1, int(weapons.moon.level))
			weapons.moon.radius *= 1.4
			weapons.moon.radius_scale *= 1.4
			weapons.moon.cooldown = maxf(1.1, float(weapons.moon.cooldown) * 0.85)
			weapons.lightning.range *= 0.75
			weapons.lightning.range_scale *= 0.75
			return "月の魔女"
		"spec_echo":
			for kind in ["lightning", "moon"]:
				weapons[kind].damage *= 0.85
				weapons[kind].power_scale *= 0.85
			return "残響の魔女"
	return "未選択"

static func apply(id: String, weapons: Dictionary) -> void:
	match id:
		"moon_unlock": weapons.moon.level = 1
		"lightning_fork":
			weapons.lightning.count = mini(3, int(weapons.lightning.count) + 1)
			weapons.lightning.level += 1
		"lightning_reach":
			weapons.lightning.width += 7.0
			weapons.lightning.range += 55.0 * float(weapons.lightning.range_scale)
			weapons.lightning.level += 1
		"lightning_haste":
			weapons.lightning.cooldown = maxf(0.44, float(weapons.lightning.cooldown) * 0.84)
			weapons.lightning.level += 1
		"moon_range":
			weapons.moon.radius += 30.0 * float(weapons.moon.radius_scale)
			weapons.moon.level += 1
		"moon_double":
			weapons.moon.count = mini(2, int(weapons.moon.count) + 1)
			weapons.moon.level += 1
		"moon_haste":
			weapons.moon.cooldown = maxf(1.1, float(weapons.moon.cooldown) * 0.82)
			weapons.moon.level += 1
		"power":
			for kind in ["lightning", "moon"]:
				weapons[kind].damage += 3.0 * float(weapons[kind].power_scale)
