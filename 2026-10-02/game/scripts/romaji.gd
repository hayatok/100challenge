class_name RelayRomaji
extends RefCounted

# Accepted spellings are a finite prefix language, not a fixed display string.
# This preserves progress when the player chooses shi/si, chi/ti or n/nn.
const MORA := {
"あ":["a"],"い":["i","yi"],"う":["u","wu","whu"],"え":["e"],"お":["o"],
"か":["ka"],"き":["ki"],"く":["ku","cu","qu"],"け":["ke"],"こ":["ko","co"],
"さ":["sa"],"し":["shi","si","ci"],"す":["su"],"せ":["se","ce"],"そ":["so"],
"た":["ta"],"ち":["chi","ti"],"つ":["tsu","tu"],"て":["te"],"と":["to"],
"な":["na"],"に":["ni"],"ぬ":["nu"],"ね":["ne"],"の":["no"],
"は":["ha"],"ひ":["hi"],"ふ":["fu","hu"],"へ":["he"],"ほ":["ho"],
"ま":["ma"],"み":["mi"],"む":["mu"],"め":["me"],"も":["mo"],
"や":["ya"],"ゆ":["yu"],"よ":["yo"],"ら":["ra"],"り":["ri"],"る":["ru"],"れ":["re"],"ろ":["ro"],
"わ":["wa"],"を":["wo"],"が":["ga"],"ぎ":["gi"],"ぐ":["gu"],"げ":["ge"],"ご":["go"],
"ざ":["za"],"じ":["ji","zi"],"ず":["zu"],"ぜ":["ze"],"ぞ":["zo"],
"だ":["da"],"ぢ":["di","ji"],"づ":["du","zu"],"で":["de"],"ど":["do"],
"ば":["ba"],"び":["bi"],"ぶ":["bu"],"べ":["be"],"ぼ":["bo"],"ぱ":["pa"],"ぴ":["pi"],"ぷ":["pu"],"ぺ":["pe"],"ぽ":["po"],
"きゃ":["kya"],"きゅ":["kyu"],"きょ":["kyo"],"しゃ":["sha","sya"],"しゅ":["shu","syu"],"しょ":["sho","syo"],
"ちゃ":["cha","tya","cya"],"ちゅ":["chu","tyu","cyu"],"ちょ":["cho","tyo","cyo"],
"にゃ":["nya"],"にゅ":["nyu"],"にょ":["nyo"],"ひゃ":["hya"],"ひゅ":["hyu"],"ひょ":["hyo"],
"みゃ":["mya"],"みゅ":["myu"],"みょ":["myo"],"りゃ":["rya"],"りゅ":["ryu"],"りょ":["ryo"],
"ぎゃ":["gya"],"ぎゅ":["gyu"],"ぎょ":["gyo"],"じゃ":["ja","jya","zya"],"じゅ":["ju","jyu","zyu"],"じょ":["jo","jyo","zyo"],
"びゃ":["bya"],"びゅ":["byu"],"びょ":["byo"],"ぴゃ":["pya"],"ぴゅ":["pyu"],"ぴょ":["pyo"],
"ぁ":["xa","la"],"ぃ":["xi","li"],"ぅ":["xu","lu"],"ぇ":["xe","le"],"ぉ":["xo","lo"],
"ゃ":["xya","lya"],"ゅ":["xyu","lyu"],"ょ":["xyo","lyo"],"ー":["-"],"っ":["xtu","ltu","xtsu","ltsu"]
}
var candidates: Array[String] = []
var typed := ""
var complete := false

static func spellings(kana: String) -> Array[String]:
    return _expand(kana, 0)

static func _expand(kana: String, index: int) -> Array[String]:
    if index >= kana.length():
        return [""]
    var token := kana.substr(index, 2)
    if not MORA.has(token):
        token = kana.substr(index, 1)
    var rest: Array[String] = _expand(kana, index + token.length())
    var options: Array = MORA.get(token, [token.to_lower()])
    if token == "ん":
        options = ["nn", "xn"]
        if rest[0].is_empty() or not rest[0].left(1) in ["a","i","u","e","o","y","n"]:
            options.push_front("n")
        else:
            options.append("n'")
    var result: Array[String] = []
    for suffix in rest:
        if token == "っ" and not suffix.is_empty():
            var initial := suffix.left(1)
            if not initial in ["a","i","u","e","o","n"]:
                result.append(initial + suffix)
            if suffix.begins_with("ch"):
                result.append("t" + suffix)
        for option in options:
            if result.size() < 4096:
                var value: String = option + suffix
                if not result.has(value):
                    result.append(value)
    return result

func reset(kana: String) -> void:
    candidates = spellings(kana)
    typed = ""
    complete = false

func accept(letter: String) -> bool:
    if complete:
        if candidates.has(typed + letter.to_lower()):
            typed += letter.to_lower()
            return true
        return false
    var next := typed + letter.to_lower()
    for word in candidates:
        if word.begins_with(next):
            typed = next
            complete = candidates.has(typed)
            return true
    return false

func hint() -> String:
    for word in candidates:
        if word.begins_with(typed):
            return word
    return candidates[0] if not candidates.is_empty() else ""

func clear() -> void:
    typed = ""
    complete = false

func can_start(letter: String) -> bool:
    for word in candidates:
        if word.begins_with(typed + letter.to_lower()):
            return true
    return false
