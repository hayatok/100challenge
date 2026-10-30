extends RefCounted

const Base = preload("res://scripts/campaign_data.gd")
const DISTRICTS = Base.DISTRICTS
const CONTRACTS = Base.CONTRACTS
const STORY_IDS = Base.STORY_IDS
const SHOP = Base.SHOP
const PERSONAL = Base.PERSONAL
const SOURCES: Dictionary = {
	"beacon": "波止場・1層の金枠の荷箱に集光芯と端材。",
	"pump": "市場・1層の金枠の荷箱に歯車2個と端材2個。",
	"channel": "運河・1層の金枠の荷箱に航路図と潮真珠。",
	"network": "観測所・1層の金枠の荷箱に太陽レンズと歯車。",
	"isana_parcel": "端材と潮真珠は各地区の荷箱。真珠は奥の層にもある。",
	"ritsu_clinic": "救急包は各地区の荷箱か、港の物資交換。",
	"kohaku_tools": "端材は荷箱、爆薬は荷箱か港の物資交換。",
	"sui_atlas": "潮真珠と発煙筒は各地区の荷箱。発煙筒は購入もできる。"}
const EFFECTS: Dictionary = {
	"beacon": "港の灯りを修復し、市場への航路を開く。次の遠征から視界＋1。",
	"pump": "市場の排水を復旧し、群島運河への航路を開く。",
	"channel": "運河の船路を読み解き、岬の観測所へ進める。",
	"network": "4地区を結ぶ灯りが完成する。仲間の依頼と繰り返しの回収依頼は続く。",
	"isana_parcel": "発煙筒の購入価格が12 Gから10 Gになる。",
	"ritsu_clinic": "救急包の購入価格が10 Gから8 Gになる。売却価格を下回らない。",
	"kohaku_tools": "爆薬の購入価格が18 Gから14 Gになる。売却価格を下回らない。",
	"sui_atlas": "次の遠征から部屋の地形を地図に記す。荷箱や敵は見えない。"}
const ORDERS: Array = [
	{"district": "market", "requirements": {"core": 1, "pumpGear": 1}, "credits": 90, "tool": "medicine"},
	{"district": "canal", "requirements": {"pumpGear": 1, "chart": 1}, "credits": 100, "tool": "bomb"},
	{"district": "observatory", "requirements": {"chart": 1, "sunLens": 1}, "credits": 130, "tool": "flare"},
	{"district": "quay", "requirements": {"core": 1, "pearl": 2}, "credits": 110, "tool": "harpoon"}]

static func unlocked(state: Dictionary, district: String) -> bool:
	return Base.unlocked(state, district)

static func current_district(state: Dictionary) -> Dictionary:
	return Base.current_district(state)

static func contracts(state: Dictionary) -> Array:
	var rows: Array = Base.contracts(state)
	for row: Dictionary in rows:
		row["why"] = row.description
		row["effect"] = EFFECTS.get(row.id, row.description)
		row["sources"] = SOURCES.get(row.id, "各地区の荷箱。品は帰還後に倉庫から届ける。")
		row["result"] = row.effect
	var cycle: int = int(state.profile.get("commissionCycle", 0))
	var order: Dictionary = ORDERS[cycle % ORDERS.size()]
	var requirements: Array = []
	var ready: bool = true
	for kind: String in order.requirements:
		var owned: int = 0
		for item: Dictionary in state.profile.stash:
			if item.kind == kind:
				owned += 1
		var count: int = int(order.requirements[kind])
		ready = ready and owned >= count
		requirements.append({"kind": kind, "count": count, "owned": owned})
	rows.append({"id": "salvage_order", "title": "港の回収依頼 %d" % (cycle + 1), "character": "isana", "district": order.district,
		"description": "複数の地区で回収した部品を届ける。完了すると次の依頼が届く。", "why": "復旧した港では、遠くの地区の部品も必要になった。",
		"effect": "報酬の所持金と道具を受け取り、次の回収依頼が届く。", "result": "次の依頼を受けられる。", "sources": "集光芯は波止場、歯車は市場、航路図は運河、太陽レンズは観測所。潮真珠は各地区の荷箱。",
		"requires": "beacon", "requirements": requirements, "reward": {"credits": order.credits, "items": [order.tool], "unlock": ""},
		"accepted": state.profile.activeContract == "salvage_order", "lockReason": "先に「港へ灯りを」を完了する", "status": "locked" if "beacon" not in state.profile.completedContracts else "ready" if ready else "available"})
	return rows

static func campaign_summary(state: Dictionary) -> Dictionary:
	# The frozen campaign does not know the repeatable identifier.
	var copy: Dictionary = state.duplicate(true)
	if copy.profile.activeContract == "salvage_order":
		copy.profile.activeContract = ""
	var summary: Dictionary = Base.campaign_summary(copy)
	var target: String = str(state.profile.activeContract)
	if target.is_empty() and int(summary.completed) == int(summary.total):
		for row: Dictionary in contracts(state):
			if row.status not in ["claimed", "locked"]:
				target = row.id
				break
	if target == "salvage_order" or (int(summary.completed) == int(summary.total) and not target.is_empty()):
		for row: Dictionary in contracts(state):
			if row.id == target:
				summary.title = row.title
				summary.description = row.description + " " + row.effect
				summary.nextDistrict = row.district
				summary.activeContract = str(state.profile.activeContract)
	return summary

static func price(state: Dictionary, kind: String) -> int:
	var result: int = int(SHOP[kind])
	if kind == "medicine" and "ritsu_clinic" in state.profile.completedContracts:
		result = 8
	elif kind == "bomb" and "kohaku_tools" in state.profile.completedContracts:
		result = 14
	elif kind == "flare" and "isana_parcel" in state.profile.completedContracts:
		result = 10
	return result

static func shop_rows(state: Dictionary) -> Array:
	var rows: Array = Base.shop_rows(state)
	for row: Dictionary in rows:
		row.price = price(state, row.kind)
		row.affordable = int(state.profile.credits) >= int(row.price) and state.profile.stash.size() < 10000
	return rows

static func dialogue(state: Dictionary, character: String) -> Array:
	var lines: Array = Base.dialogue(state, character)
	if PERSONAL.has(character) and PERSONAL[character] in state.profile.completedContracts:
		lines.append(EFFECTS[PERSONAL[character]])
	return lines
