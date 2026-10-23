extends RefCounted
## Authored chapter geometry and encounter pacing, shared by simulation and drawing.

const DURATION := 180.0
const CHAPTER_COUNT := 3

static func chapter(index: int) -> Dictionary:
	var info := {
		"id": "thorn_garden", "name": "眠りの庭園", "subtitle": "第一章 / 茨の門", "biome": "garden",
		"goal": "3分の攻勢をしのぎ、茨の庭守を倒す", "duration": DURATION,
		"bounds": Rect2(-1100, -800, 2200, 1600), "obstacles": [],
		"chest_positions": [Vector2(760, -540), Vector2(-760, 540)], "chest_times": [30.0, 105.0],
		"boss_id": "boss_thorn", "boss_name": "茨の庭守", "boss_hp": 4500.0,
		"phase_names": ["残像の目覚め", "獣の足音", "茨の小径", "月下の射手", "門番の包囲", "茨の門が開く"],
		"phase_hints": ["道を分け、二人で狙おう", "突進の予告を横にかわそう", "花壇を回り、宝箱を探そう", "射線を花壇の陰で切ろう", "挟撃で硬い敵を崩そう", "回収を終え、庭守に備えよう"]
	}
	match index:
		0:
			info.obstacles = [Rect2(-480, -380, 260, 180), Rect2(220, -380, 260, 180), Rect2(-480, 200, 260, 180), Rect2(220, 200, 260, 180)]
		1:
			info.id = "mirror_archive"
			info.name = "鏡の書庫"
			info.subtitle = "第二章 / 忘れられた言葉"
			info.biome = "archive"
			info.goal = "書架の間を抜け、鏡の司書を倒す"
			info.obstacles = [Rect2(-650, -520, 170, 430), Rect2(-650, 150, 170, 370), Rect2(-150, -580, 300, 160), Rect2(-150, 420, 300, 160), Rect2(480, -520, 170, 430), Rect2(480, 150, 170, 370)]
			info.chest_positions = [Vector2(-850, 0), Vector2(850, 0)]
			info.boss_id = "boss_mirror"
			info.boss_name = "鏡の司書"
			info.boss_hp = 8500.0
			info.phase_names = ["書庫の入口", "飛び交う言葉", "鏡の番人", "折り重なる射線", "迷いの回廊", "閉じる書物"]
			info.phase_hints = ["書架の切れ目に残像を置こう", "射線を見て通路を変えよう", "硬い番人は挟撃で崩そう", "長い通路に留まらない", "遠い宝箱へ道をつくろう", "司書を迎える場所を選ぼう"]
		2:
			info.id = "night_belfry"
			info.name = "夜鐘の塔"
			info.subtitle = "第三章 / 夜明けの約束"
			info.biome = "belfry"
			info.goal = "最後の攻勢を越え、夜鐘の主を倒す"
			info.obstacles = [Rect2(-720, -270, 300, 160), Rect2(420, -270, 300, 160), Rect2(-720, 110, 300, 160), Rect2(420, 110, 300, 160), Rect2(-170, -550, 340, 130), Rect2(-170, 420, 340, 130)]
			info.chest_positions = [Vector2(0, -670), Vector2(0, 670)]
			info.boss_id = "boss_bell"
			info.boss_name = "夜鐘の主"
			info.boss_hp = 17000.0
			info.phase_names = ["塔のふもと", "夜羽の群れ", "鳴らない鐘", "最後の回廊", "夜の総攻勢", "夜明け前"]
			info.phase_hints = ["柱を回り、出口を空けよう", "小さな群れには広い魔法を", "番人と射手の間を抜けよう", "残像と違う通路へ進もう", "進化した魔法で道をひらこう", "鐘の主を倒し、朝を呼ぼう"]
	return info
