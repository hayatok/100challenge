class_name CampaignData
extends RefCounted

# Content and derived presentation only. Ownership and rewards are resolved by Rules.
const DISTRICTS: Dictionary = {
	"quay": {"name": "灯台の波止場", "subtitle": "高架の帰路と沈んだ街", "objective": "旧灯台で集光芯を回収する", "requires": "", "lockReason": "", "goal": {"x": 21, "y": 3}, "palette": {"stone": "#d9c8a6", "water": "#57b9bf", "accent": "#e2b260"}, "landmarks": [{"kind": "lighthouse", "x": 18, "y": 2}, {"kind": "market", "x": 7, "y": 11}, {"kind": "clinic", "x": 20, "y": 12}, {"kind": "pump", "x": 5, "y": 3}, {"kind": "arch", "x": 8, "y": 9}, {"kind": "palms", "x": 16, "y": 17}, {"kind": "pump", "x": 3, "y": 5}, {"kind": "palms", "x": 3, "y": 17}]},
	"market": {"name": "中庭市場", "subtitle": "見通しのよい中庭と二本の裏路地", "objective": "北の揚水小屋で歯車を回収する", "requires": "beacon", "lockReason": "「港へ灯りを」を完了すると開く", "goal": {"x": 12, "y": 4}, "palette": {"stone": "#e6c6a1", "water": "#72c1b4", "accent": "#d58b64"}, "landmarks": [{"kind": "market", "x": 6, "y": 9}, {"kind": "market", "x": 18, "y": 9}, {"kind": "pump", "x": 9, "y": 2}, {"kind": "clinic", "x": 21, "y": 14}, {"kind": "arch", "x": 8, "y": 7}, {"kind": "arch", "x": 16, "y": 17}, {"kind": "palms", "x": 6, "y": 20}, {"kind": "palms", "x": 18, "y": 20}]},
	"canal": {"name": "群島運河", "subtitle": "橋を渡る遠回り、潮をかぶる近道", "objective": "北東の測量所で航路図を回収する", "requires": "pump", "lockReason": "「市場の水を抜く」を完了すると開く", "goal": {"x": 19, "y": 4}, "palette": {"stone": "#c5d7b6", "water": "#489ba9", "accent": "#d4bd72"}, "landmarks": [{"kind": "arch", "x": 5, "y": 15}, {"kind": "pump", "x": 17, "y": 9}, {"kind": "clinic", "x": 23, "y": 4}, {"kind": "palms", "x": 2, "y": 18}, {"kind": "market", "x": 9, "y": 14}, {"kind": "palms", "x": 14, "y": 5}, {"kind": "arch", "x": 13, "y": 11}]},
	"observatory": {"name": "岬の観測所", "subtitle": "外周を回り、守りの向きを崩す", "objective": "北の保管庫で太陽レンズを回収する", "requires": "channel", "lockReason": "「運河に航路を」を完了すると開く", "goal": {"x": 12, "y": 3}, "palette": {"stone": "#ccc5da", "water": "#6a9fbd", "accent": "#e7c680"}, "landmarks": [{"kind": "lighthouse", "x": 12, "y": 1}, {"kind": "arch", "x": 3, "y": 6}, {"kind": "pump", "x": 21, "y": 12}, {"kind": "palms", "x": 3, "y": 19}, {"kind": "clinic", "x": 17, "y": 15}, {"kind": "market", "x": 7, "y": 10}, {"kind": "arch", "x": 21, "y": 19}]}}

const STORY_IDS: Array = ["beacon", "pump", "channel", "network"]
const CONTRACTS: Dictionary = {
	"beacon": {"title": "港へ灯りを", "character": "kohaku", "district": "quay", "description": "集光芯と端材で港の灯りを直す。次の遠征から視界が1マス広がり、市場へ渡れる。", "requires": "", "requirements": {"core": 1, "scrap": 1}, "reward": {"credits": 20, "items": [], "unlock": "market"}},
	"pump": {"title": "市場の水を抜く", "character": "ritsu", "district": "market", "description": "揚水機の歯車と端材を届ける。市場の船路を通し、群島運河へ進む。", "requires": "beacon", "requirements": {"pumpGear": 1, "scrap": 2}, "reward": {"credits": 24, "items": [], "unlock": "canal"}},
	"channel": {"title": "運河に航路を", "character": "sui", "district": "canal", "description": "航路図と目印に使う潮真珠を届ける。観測所までの船路を開く。", "requires": "pump", "requirements": {"chart": 1, "pearl": 1}, "reward": {"credits": 28, "items": [], "unlock": "observatory"}},
	"network": {"title": "港をつなぐ光", "character": "isana", "district": "observatory", "description": "太陽レンズと予備の歯車を届け、港どうしを結ぶ灯りを完成させる。", "requires": "channel", "requirements": {"sunLens": 1, "pumpGear": 1}, "reward": {"credits": 40, "items": [], "unlock": ""}},
	"isana_parcel": {"title": "イサナの配達袋", "character": "isana", "district": "quay", "description": "袋の留め具に端材を、受取人の目印に潮真珠を。配達の仕事をもう一度始めたい。", "requires": "", "requirements": {"scrap": 1, "pearl": 1}, "reward": {"credits": 12, "items": ["coat"], "unlock": ""}},
	"ritsu_clinic": {"title": "リツの救護棚", "character": "ritsu", "district": "market", "description": "救急包を2個届け、港の救護棚に備える。遠征に持ち出す分との配分を考えよう。", "requires": "beacon", "requirements": {"medicine": 2}, "reward": {"credits": 18, "items": ["flare"], "unlock": ""}},
	"kohaku_tools": {"title": "コハクの作業場", "character": "kohaku", "district": "market", "description": "爆薬と端材を届け、作業場の崩れた壁を片づける。直した銛を1本渡してくれる。", "requires": "pump", "requirements": {"bomb": 1, "scrap": 1}, "reward": {"credits": 12, "items": ["harpoon"], "unlock": ""}},
	"sui_atlas": {"title": "スイの航路帳", "character": "sui", "district": "canal", "description": "潮真珠と発煙筒を届け、流れの目印を測る。スイは自分の航路帳を仕上げたい。", "requires": "channel", "requirements": {"pearl": 1, "flare": 1}, "reward": {"credits": 20, "items": ["bomb"], "unlock": ""}}}

const SHOP: Dictionary = {"medicine": 10, "flare": 12, "bomb": 18, "knife": 16, "coat": 24, "harpoon": 42}
const PERSONAL: Dictionary = {"isana": "isana_parcel", "ritsu": "ritsu_clinic", "kohaku": "kohaku_tools", "sui": "sui_atlas"}

static func unlocked(state: Dictionary, district: String) -> bool:
	if not DISTRICTS.has(district):
		return false
	var required: String = DISTRICTS[district].requires
	return required.is_empty() or required in state.profile.completedContracts

static func current_district(state: Dictionary) -> Dictionary:
	var id: String = str(state.run.district) if state.run is Dictionary else str(state.profile.selectedDistrict)
	var row: Dictionary = DISTRICTS[id].duplicate(true)
	row["id"] = id
	row["unlocked"] = unlocked(state, id)
	return row

static func contracts(state: Dictionary) -> Array:
	var rows: Array = []
	for id: String in CONTRACTS:
		var row: Dictionary = CONTRACTS[id].duplicate(true)
		row["id"] = id
		row["accepted"] = state.profile.activeContract == id
		row["lockReason"] = "先に「%s」を完了する" % CONTRACTS[row.requires].title if not str(row.requires).is_empty() else ""
		var ready: bool = true
		var requirements: Array = []
		for kind: String in row.requirements:
			var owned: int = 0
			for item: Dictionary in state.profile.stash:
				if item.kind == kind:
					owned += 1
			var count: int = int(row.requirements[kind])
			ready = ready and owned >= count
			requirements.append({"kind": kind, "count": count, "owned": owned})
		row.requirements = requirements
		row["status"] = "claimed" if id in state.profile.completedContracts else "locked" if not str(row.requires).is_empty() and row.requires not in state.profile.completedContracts else "ready" if ready else "available"
		rows.append(row)
	return rows

static func campaign_summary(state: Dictionary) -> Dictionary:
	var completed: int = 0
	var next: String = ""
	for id: String in STORY_IDS:
		if id in state.profile.completedContracts:
			completed += 1
		elif next.is_empty():
			next = id
	var selected: String = str(state.profile.activeContract)
	var target: String = selected if not selected.is_empty() else next
	return {"completed": completed, "total": STORY_IDS.size(), "title": CONTRACTS[target].title if not target.is_empty() else "港の灯りがつながった", "description": CONTRACTS[target].description if not target.is_empty() else "4つの地区が船路でつながった。仲間の仕事や残った回収を続けられる。", "nextDistrict": CONTRACTS[next].district if not next.is_empty() else "", "activeContract": selected}

static func shop_rows(state: Dictionary) -> Array:
	var rows: Array = []
	for kind: String in SHOP:
		rows.append({"kind": kind, "price": SHOP[kind], "affordable": int(state.profile.credits) >= int(SHOP[kind]) and state.profile.stash.size() < 10000})
	return rows

static func dialogue(state: Dictionary, character: String) -> Array:
	if not PERSONAL.has(character):
		return []
	var done: Array = state.profile.completedContracts
	var personal_done: bool = PERSONAL[character] in done
	var district: String = current_district(state).name
	var lines: Dictionary = {
		"isana": ["配達袋、また使えるね。次の荷物も大事に運ぶよ。" if personal_done else "配達の仕事を再開したいんだ。留め具と目印があれば、あの袋を使える。", "港の灯りがつながった。今度は遠くの人にも届けられるね。" if "network" in done else "灯りがついたから、帰る場所を見失わずに済むね。" if "beacon" in done else "まず灯台の集光芯を持ち帰ろう。帰りの袋も空けておこうね。"],
		"ritsu": ["救護棚の備えができた。必要な人に渡せる。ありがとう。" if personal_done else "救急包を2個、港に備えておきたい。持ち出す分も忘れないで。", "運河までの流れは落ち着いた。%sでも高い道を探そう。" % district if "pump" in done else "市場の揚水機が止まっている。歯車を持ち帰れば船を通せる。" if "beacon" in done else "まず灯りを直そう。潮が満ちても、高架の帰路は沈まない。"],
		"kohaku": ["作業場が使えるようになった。あの銛、役に立ってる？" if personal_done else "あたしの作業場も直したい。市場の排水が済んだら、壁を片づけよう。", "灯りの連絡網、ちゃんと動いてる。部品を運んだ甲斐があったね。" if "network" in done else "市場の歯車は予備もある。最後の灯りのため、1個は倉庫に残しておこう。" if "pump" in done else "集光芯と端材が1個ずつあれば、港の灯りを直せるよ。"],
		"sui": ["航路帳ができた。自分の足で確かめた道が、やっと一冊になった。" if personal_done else "運河の航路が開いたら、私の航路帳も仕上げたい。目印を測り直すんだ。", "観測所への航路が読めた。%sの帰り道も、出る前に確かめよう。" % district if "channel" in done else "運河の測量所に航路図がある。橋は遠回り、低い道は満ち潮に注意。" if "pump" in done else "%sの見えない曲がり角は、地図を開いて確かめよう。" % district]}
	return lines[character]
