extends RefCounted
# Forecasts are deterministic, visible before ordering, and never created as a surprise penalty.
const CHAPTERS=[
["春・いつもの店をつくる","朝の定番と放課後の寄り道。まずは棚切れと会計の流れを覚えよう。"],
["夏・冷たいものと熱い締切","暑い日の飲料、夜の勉強、配送の遅れ。同じ発注数で毎日は回らない。"],
["秋・食欲にも得意分野がある","季節の味と読書のお供。常連の定番を残しながら、どの売り場を変える？"],
["冬・街の明かりを守る","温かい食事と夜勤の帰り道。長い納品待ちに備え、店の強みを完成させよう。"]]
const OCCASIONS={
8:{"id":"office","name":"商店街の朝活週間","detail":"出勤前にコーヒーかパンを探す人が増えます。朝の補充と会計を両立しよう。","needs":["coffee","bread"],"cats":[2,1],"share":0.45,"hour":8},
13:{"id":"sports","name":"町内ゆるゆる運動会","detail":"走る前から休憩の相談。すっきりした飲み物か、軽いお米の食事を探します。","needs":["drink health","rice light"],"cats":[2,0],"share":0.45,"hour":11},
15:{"id":"heat","name":"最初の猛暑日","detail":"日陰の会議は満員。冷たい飲み物を探す人が増えます。冷蔵棚と午後の補充が大切。","needs":["drink cold"],"cats":[2],"share":0.55,"weather":"暑い"},
16:{"id":"heat","name":"猛暑は続くよ、明日まで","detail":"昨日の売れ方が今日の発注のヒント。冷たい飲み物の欠品と余らせすぎに注意。","needs":["drink cold"],"cats":[2],"share":0.55,"weather":"暑い"},
20:{"id":"summer_break","name":"夏休みのおやつ会議","detail":"宿題をする前に、おやつを決めます。甘いおやつか冷たい飲み物が目的の来店。","needs":["snack sweet","drink cold"],"cats":[3,2],"share":0.45,"hour":16},
23:{"id":"study","name":"締切前夜の自習室","detail":"ノートは開いた。あとは起きるだけ。コーヒーか温かい麺を探す夜の来店が増えます。","needs":["coffee","noodle warm"],"cats":[2,5],"share":0.5,"hour":22},
27:{"id":"rain","name":"傘を忘れた人の集会","detail":"全員、天気予報は見たそうです。傘が目的の来店が増えます。日用品の棚を見直そう。","needs":["rain"],"cats":[7],"share":0.4,"weather":"雨"},
29:{"id":"harvest","name":"焼きいもの季節、開幕","detail":"食欲の秋は会議を待たない。季節の温かい品を探す人が増えます。保温棚の容量と期限を確認。","needs":["warm seasonal"],"cats":[6],"share":0.45},
30:{"id":"autumn","name":"秋の小さな収穫祭","detail":"季節の甘いものを目当てに街を歩く人たち。定番を残すか、新しい味に棚を譲るか。","needs":["sweet seasonal"],"cats":[4,1],"share":0.45},
34:{"id":"books","name":"本より厚いおやつ会","detail":"しおりは入れた。おやつは別腹。お茶か焼き菓子を探す読書好きが増えます。","needs":["tea","cookie"],"cats":[2,3],"share":0.45,"hour":14},
37:{"id":"office","name":"朝活ふたたび","detail":"朝の行列を覚えていますか。コーヒーかパンを探す人が、出勤前に集中します。","needs":["coffee","bread"],"cats":[2,1],"share":0.5,"hour":8},
41:{"id":"autumn","name":"秋のごほうび最終便","detail":"季節の甘いものに、もう一票。常連の定番と季節の売り場を両立しよう。","needs":["sweet seasonal"],"cats":[4,1],"share":0.45},
43:{"id":"cold","name":"冬の入り口、湯気の出口","detail":"手袋より先に温かいスープ。スープが目的の人が増えます。麺売り場と保温棚のどちらで応える？","needs":["warm soup"],"cats":[5,6],"share":0.55},
44:{"id":"cold","name":"今夜もスープ日和","detail":"冬は二日目も冬。温かいスープの在庫と夜のスタッフを確認しよう。","needs":["warm soup"],"cats":[5,6],"share":0.5},
48:{"id":"night_shift","name":"夜勤明けのごはん便","detail":"街が眠る間も働く人へ。温かく満腹になる食事を朝5時から探します。","needs":["warm hearty"],"cats":[6,0],"share":0.45,"hour":5},
51:{"id":"office","name":"今年最後の朝活","detail":"出勤前のコーヒーかパン。店が大きくなっても、朝の一本の列は大切です。","needs":["coffee","bread"],"cats":[2,1],"share":0.5,"hour":8},
55:{"id":"neighbors","name":"あかり町の持ち寄り会","detail":"最後まで、いつもの暮らし。温かい食事か甘いものを探す住人が集まります。","needs":["warm hearty","sweet"],"cats":[6,4],"share":0.45,"hour":17}}
const DELAYS={9:180,18:360,32:240,46:480}
static func event(day:int) -> Dictionary:
	var result={"id":"normal","name":"いつもの街","detail":"いつもの人に、いつもの一品。","cats":[],"mult":1.0,"needs":[],"share":0.0}
	match day%7:
		3:result.merge({"id":"chili","name":"激辛がまん大会","detail":"辛い麺と飲み物。強気の参加者にも、水は必要。","cats":[5,2],"needs":["spicy noodle","drink"],"share":0.35},true)
		5:result.merge({"id":"hero","name":"ヒーロー撮影日","detail":"世界より先に昼休み。お米の食事か温かい食事を探す人が昼に集中します。","cats":[0,6],"needs":["rice","warm hearty"],"share":0.4,"hour":12},true)
		0:result.merge({"id":"pudding","name":"プリン総選挙","detail":"清き一口を。スイーツを探す人が増えます。食べ比べの一票を大切に。","cats":[4],"needs":["dessert"],"share":0.35},true)
	if OCCASIONS.has(day):result.merge(OCCASIONS[day],true)
	result.delivery_delay=DELAYS.get(day,0)
	return result
static func need(day:int,rid:int,seed:int) -> String:
	var e=event(day)
	if e.needs.is_empty() or posmod(seed+day*37+rid*61,100)>=roundi(e.share*100):return ""
	return e.needs[posmod(rid+day,e.needs.size())]
static func delivery_tick(tick:int) -> int:
	var day_index=tick/1440;var offset=tick%1440
	# Trading day begins at 06:00. Orders at the afternoon cutoff go to next morning.
	if offset<480:return day_index*1440+480+int(DELAYS.get(day_index+1,0))
	return (day_index+1)*1440
static func shipping_text(day:int) -> String:
	var delay=int(DELAYS.get(day,0))
	if delay==0:return "納品 06:00 / 14:00"
	return "配送予告：道路・集荷の都合で午後便が%02d:00着。発注締切は14:00のまま。"%[14+delay/60]
static func chapter(day:int) -> Array:return CHAPTERS[clampi((day-1)/14,0,3)]
