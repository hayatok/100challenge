extends RefCounted
# Authored uses distinguish products inside a category; these are not upgrade ranks.
const TAG_LABELS={"dessert":"スイーツ","rice":"お米","bread":"パン","tea":"お茶","coffee":"コーヒー","drink":"飲み物","sweet":"甘い","spicy":"辛い","hearty":"満腹","light":"軽め","warm":"温かい","cold":"冷たい","health":"すっきり","snack":"おやつ","noodle":"麺","practical":"日用品","news":"新聞","rain":"雨支度","novel":"変わり種","seasonal":"季節もの","soup":"スープ","cookie":"焼き菓子"}
const PROFILES=[
["rice light","rice hearty","rice light health","rice hearty warm","rice hearty novel","bread light","rice hearty","rice warm","rice hearty novel","rice seasonal hearty"],
["bread sweet","bread light","bread sweet light","bread hearty novel","bread sweet","bread health","bread sweet seasonal","bread hearty novel","bread light","bread sweet seasonal"],
["drink tea health cold","drink coffee health","drink health cold","drink tea sweet","drink coffee sweet novel","drink cold","drink coffee novel","drink tea warm","drink hearty cold","drink sweet seasonal cold"],
["snack light","snack hearty","snack sweet","snack sweet novel","snack health","snack light","snack sweet cookie","snack sweet novel","snack sweet cookie","snack sweet seasonal cookie"],
["sweet cold","sweet light","sweet cold","sweet novel cold","sweet tea cold","sweet light cold","sweet novel cold","sweet seasonal","sweet coffee cold","sweet seasonal cold"],
["noodle warm","noodle spicy warm","noodle hearty","noodle spicy novel","soup warm health","noodle cold seasonal","noodle spicy novel","noodle warm light","noodle warm hearty","noodle hearty seasonal"],
["warm hearty","warm hearty","warm hearty","warm hearty novel","warm sweet seasonal","warm sweet","warm soup seasonal","warm hearty novel","warm hearty","warm soup health"],
["practical news","practical light","practical","practical rain","practical novel","practical health","practical novel","practical","practical light","practical novel"]]
const TASTES=[
{"sweet":1.0,"coffee":0.8,"novel":0.4},
{"spicy":1.0,"noodle":0.8,"hearty":0.4},
{"tea":1.0,"cookie":0.8,"bread":0.5},
{"rice":1.0,"hearty":0.8,"drink":0.3},
{"bread":1.0,"news":0.8,"novel":0.3},
{"warm":1.0,"soup":0.8,"health":0.4},
{"drink":0.8,"coffee":0.7,"health":0.5},
{"hearty":0.7,"rice":0.6,"warm":0.5},
{"sweet":0.9,"novel":1.0,"seasonal":0.7},
{"rice":0.8,"coffee":1.0,"light":0.5},
{"practical":1.0,"health":0.6,"tea":0.4},
{"warm":0.7,"hearty":0.8,"seasonal":0.7}]
static func tags(product:int) -> PackedStringArray:
	var result=PROFILES[product/10][product%10].split(" ")
	if product/10==4:result.append("dessert")
	return result
static func description(product:int) -> String:
	var words=[]
	for tag in tags(product):words.append(TAG_LABELS[tag])
	return "・".join(words)
static func affinity(rid:int,product:int) -> float:
	var result=0.0;var taste=TASTES[posmod(rid,12)]
	for tag in tags(product):result+=float(taste.get(tag,0))*8.0
	return minf(result,20.0)
static func preference(rid:int) -> String:
	var words=[]
	for tag in TASTES[posmod(rid,12)]:words.append(TAG_LABELS[tag])
	return " / ".join(words)
