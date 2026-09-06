extends RefCounted
const Goods=preload("res://core/merchandise.gd")
# Every stage describes an observable purchase, never just lifetime purchase count.
# 'all' is a basket combination; 'days' counts separate successful dates.
const REQUESTS=[
[
{"hint":"帰り道の楽しみに、甘いものを買いたい。","all":["dessert"]},
{"hint":"甘いものとコーヒー。両方あると仕事がはかどりそう。","all":["dessert","coffee"]},
{"hint":"いつもの味と新味を食べ比べたい。違うスイーツを2種類。","all":["dessert novel"],"distinct_cat":4,"distinct":2}],
[
{"hint":"放課後のお腹に、麺がほしい。","all":["noodle"]},
{"hint":"辛い麺に挑戦。飲み物も一緒に買えると安心。","all":["spicy noodle","drink"]},
{"hint":"再戦は別の日に。辛い麺と飲み物を2日、650円以内で。","all":["spicy noodle","drink"],"days":2,"budget":650}],
[
{"hint":"読書のお供にパンを探しています。","all":["bread"]},
{"hint":"お茶と焼き菓子を、同じ店で買えたら。","all":["tea","cookie"]},
{"hint":"週末の読書セット。土・日にお茶と焼き菓子を計2日、待ち時間8分以内。","all":["tea","cookie"],"days":2,"wait":8,"weekdays":[5,6]}],
[
{"hint":"昼休みが短いので、お米の昼食を待ち時間10分以内で。","all":["rice"],"wait":10},
{"hint":"しっかりした昼食と飲み物を、待ち時間10分以内で。","all":["rice hearty","drink"],"wait":10},
{"hint":"配達の定番にしたい。昼食と飲み物を3日、待ち時間10分以内で。","all":["rice","drink"],"wait":10,"days":3}],
[
{"hint":"朝の見回りに、パンと新聞を買いたい。","all":["bread","news"]},
{"hint":"新聞はいつもの。パンは少し変わったものを試したい。","all":["bread novel","news"]},
{"hint":"朝の指定席に。パンと新聞を3日、朝10時までに。","all":["bread","news"],"before":600,"days":3}],
[
{"hint":"夜勤明け。温かいものが食べたい。","all":["warm"]},
{"hint":"夜明けのスープ。朝9時までに温かいスープを。","all":["warm soup"],"before":540},
{"hint":"また夜勤の日に。朝9時までの温かいスープを2日。","all":["warm soup"],"before":540,"days":2}],
[
{"hint":"締切の相棒に、コーヒーがほしい。","all":["coffee"]},
{"hint":"会議メンバーを増やします。違う飲み物を2種類。","all":["drink"],"distinct_cat":2,"distinct":2},
{"hint":"脱稿のお祝いは甘いものとお茶にします。","all":["sweet","tea"]}],
[
{"hint":"演奏前の腹ごしらえに、お米の食事を。","all":["rice"]},
{"hint":"食事と飲み物、合わせて500円なら助かる。","all":["rice","drink"],"budget":500},
{"hint":"またライブの日に。食事と飲み物を2日、500円以内で。","all":["rice","drink"],"budget":500,"days":2}],
[
{"hint":"まずはこのお店のスイーツを食べたい。","all":["dessert"]},
{"hint":"変わり種スイーツ、発見したら買います。","all":["dessert novel"]},
{"hint":"プリン総選挙の日に、違うスイーツを2種類食べ比べ。","all":["dessert"],"distinct_cat":4,"distinct":2,"event":"pudding"}],
[
{"hint":"朝は急ぎめ。お米の朝食を待ち時間8分以内で。","all":["rice"],"wait":8},
{"hint":"朝食とコーヒーを、待ち時間8分以内で。","all":["rice","coffee"],"wait":8},
{"hint":"朝の相棒に。朝10時までの朝食とコーヒーを3日、待ち時間8分以内。","all":["rice","coffee"],"wait":8,"before":600,"days":3}],
[
{"hint":"雨の日に傘を買いたい。予報は見ました。傘は忘れました。","all":["rain"],"weather":"雨"},
{"hint":"晴れた日はお茶も買っていこう。","all":["tea"],"weather":"晴れ"},
{"hint":"暮らしのよりどころに。日用品とお茶を2日。","all":["practical","tea"],"days":2}],
[
{"hint":"仕事が終わったら、温かいものを食べたい。","all":["warm"]},
{"hint":"季節の温かいものを、ごほうびに。","all":["warm seasonal"]},
{"hint":"ごほうびを習慣に。温かい食事と甘いものを2日。","all":["warm hearty","sweet"],"days":2}]]
static func request(r:Dictionary) -> Dictionary:
	if r.id>=12 or r.episode>=3:return {}
	return REQUESTS[r.id][r.episode]
static func product_matches(product:int,group:String) -> bool:
	var tags=Goods.tags(product)
	for tag in group.split(" "):
		if not tag in tags:return false
	return true
static func basket_has(ids:Array,group:String) -> bool:
	return ids.any(func(id):return product_matches(id,group))
static func wants_more(r:Dictionary,ids:Array) -> bool:
	var req=request(r)
	for group in req.get("all",[]):
		if not basket_has(ids,group):return true
	if req.has("distinct"):
		var unique={}
		for id in ids:
			if id/10==req.distinct_cat:unique[id]=true
		return unique.size()<req.distinct
	return false
static func matches(req:Dictionary,receipt:Dictionary) -> bool:
	return missing(req,receipt).is_empty()
static func group_label(group:String) -> String:
	return "・".join(Array(group.split(" ")).map(func(tag):return Goods.TAG_LABELS.get(tag,tag)))
static func missing(req:Dictionary,receipt:Dictionary) -> Array:
	var reasons=[]
	for group in req.get("all",[]):
		if not basket_has(receipt.products,group):reasons.append("不足："+group_label(group))
	if receipt.wait>req.get("wait",10000):reasons.append("レジ待ち%d分（上限%d分）"%[receipt.wait,req.wait])
	if receipt.price>req.get("budget",100000):reasons.append("予算%d円を超えました"%req.budget)
	if receipt.minute>=req.get("before",1441):reasons.append("会計が%02d:%02d以降でした"%[req.before/60,req.before%60])
	if req.has("event") and receipt.event!=req.event:reasons.append("総選挙の日を待っています")
	if req.has("weather") and receipt.weather!=req.weather:reasons.append(req.weather+"の日の買い物が必要です")
	if req.has("weekdays") and not (int(receipt.day)-1)%7 in req.weekdays:reasons.append("土・日の買い物が必要です")
	if req.has("distinct"):
		var distinct={}
		for id in receipt.products:
			if id/10==req.distinct_cat:distinct[id]=true
		if distinct.size()<req.distinct:reasons.append("違う商品%d種類 / 必要%d種類"%[distinct.size(),req.distinct])
	return reasons
static func feedback(req:Dictionary,receipt:Dictionary) -> String:
	if req.is_empty():return ""
	var reasons=missing(req,receipt)
	return "願いに合う買い物ができました。" if reasons.is_empty() else " / ".join(reasons)
static func record(r:Dictionary,receipt:Dictionary) -> int:
	var req=request(r)
	if req.is_empty() or not matches(req,receipt):return -1
	var dates:Array=r.get("story_days",[])
	if not dates.has(receipt.day):
		dates.append(receipt.day)
		var receipts:Array=r.get("story_receipts",[]);receipts.append(receipt.duplicate(true));r.story_receipts=receipts
	r.story_days=dates
	if dates.size()<req.get("days",1):return -1
	var chapter=int(r.episode);r.episode+=1;r.story_days=[]
	var evidence:Dictionary=r.get("story_evidence",{});evidence[chapter]=r.get("story_receipts",[]).duplicate(true);r.story_evidence=evidence;r.story_receipts=[]
	r.loyalty=minf(100,r.loyalty+8)
	return chapter
static func progress_text(r:Dictionary) -> String:
	var req=request(r)
	if req.is_empty():return "この店は、暮らしの一部になりました。" if r.id<12 else "買い物の履歴から、いつもの一品を探してみよう。"
	return req.hint+"\n達成した日：%d / %d日"%[r.get("story_days",[]).size(),req.get("days",1)]
static func relevance(r:Dictionary,product:int,basket:Array) -> float:
	var req=request(r)
	if req.is_empty():return 0
	var need=0
	for group in req.get("all",[]):
		if not basket_has(basket,group) and product_matches(product,group):need+=1
	if req.has("distinct") and product/10==req.distinct_cat and not basket.has(product):
		var unique={}
		for id in basket:
			if id/10==req.distinct_cat:unique[id]=true
		if unique.size()<req.distinct:need+=1
	return minf(44,need*30.0)
