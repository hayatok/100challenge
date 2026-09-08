class_name RescueLevels
extends RefCounted

static func beam(x: float, y: float, length: float, angle: float = 0.0) -> Dictionary:
	return {"p": Vector2(x,y), "length": length, "angle": angle}

static func all() -> Array[Dictionary]:
	var first: Dictionary = {
		"title": "片方だけ、ほどく", "chapter": "I  支点のアトリエ",
		"lesson": "真鍮の接合点を切る。\n残した支点で、床が道になる。",
		"hints": ["箱は右側。床の右端を下げるには？", "右の接合点②を切り、左の①を残そう。"],
		"beams": [beam(310,230,300)],
		"pins": [{"beam":0,"end":-1}, {"beam":0,"end":1}],
		"solids": [Rect2(416,342,35,228)],
		"vases": [Vector2(300,200)], "box": Rect2(465,350,155,100),
		"solution": [{"pin":1,"at":0.5}], "par":1
	}
	var mirror: Dictionary = {
		"title":"残す側を、見きわめる", "chapter":"I  支点のアトリエ",
		"lesson":"同じ床でも、届ける方向が変われば残す支点も変わる。",
		"hints":["今度の箱は左。前の手順を、そのまま使わないで。","左の①を切る。右の②が支点になる。"],
		"beams":[beam(650,210,320)], "pins":[{"beam":0,"end":-1},{"beam":0,"end":1}],
		"solids":[Rect2(501,331,36,239)], "vases":[Vector2(650,180)],
		"box":Rect2(330,345,155,110), "solution":[{"pin":0,"at":0.5}], "par":1
	}
	var bridge: Dictionary = {
		"title":"壁だった、橋", "chapter":"II  崩して、つなぐ",
		"lesson":"立っている梁も、倒せば道になる。陶器を動かす前に、行き先をつくろう。",
		"hints":["右の長い梁は、根元を残すと右へ倒れる。","④を切って橋が落ち着くのを待つ。そのあと②を切る。"],
		"beams":[beam(310,190,300),beam(502,215,300,-1.35)],
		"pins":[{"beam":0,"end":-1},{"beam":0,"end":1},{"beam":1,"end":-1},{"beam":1,"end":1}],
		"solids":[Rect2(416,302,35,268),Rect2(720,444,35,126)],
		"vases":[Vector2(300,160)],"box":Rect2(770,445,140,110),
		"solution":[{"pin":3,"at":0.5},{"pin":1,"at":4.5}],"par":2
	}
	var pair: Dictionary = {
		"title":"ふたつの、小さな命", "chapter":"II  崩して、つなぐ",
		"lesson":"ひとつ届いても、仕事は途中。すべての陶器を箱へ。",
		"hints":["左右の床を、中央へ向かう坂にしよう。","左床の②、右床の③を切る。外側の支点は残す。"],
		"beams":[beam(235,240,260),beam(725,240,260)],
		"pins":[{"beam":0,"end":-1},{"beam":0,"end":1},{"beam":1,"end":-1},{"beam":1,"end":1}],
		"solids":[Rect2(323,342,32,228),Rect2(605,342,32,228)],
		"vases":[Vector2(235,210),Vector2(725,210)],"box":Rect2(370,365,220,130),
		"solution":[{"pin":1,"at":0.5},{"pin":2,"at":0.5}],"par":2
	}
	var cradle: Dictionary = {
		"title":"水平のまま、降ろす", "chapter":"I  支点のアトリエ",
		"lesson":"傾けない方がいい時もある。小さな台ごと、そっと梱包する。",
		"hints":["真下の箱へ、台を水平に落としたい。停止中にも切れる。","一時停止して①と②を切り、再開する。"],
		"beams":[beam(480,235,100)], "pins":[{"beam":0,"end":-1},{"beam":0,"end":1}],
		"solids":[], "vases":[Vector2(480,205)], "box":Rect2(412,260,136,95),
		"solution":[{"pin":0,"at":0.5},{"pin":1,"at":0.5}], "par":2
	}
	var cascade: Dictionary = {
		"title":"帰り道を、先に", "chapter":"III  構造を読む",
		"lesson":"上の床は右へ、下の床は左へ。陶器が来る前に、折り返す道を。",
		"hints":["下の床が水平だと、陶器は右へ走り抜けてしまう。","先に③で下の床を左下がりに。そのあと②を切る。"],
		"beams":[beam(310,230,300),beam(570,350,230)],
		"pins":[{"beam":0,"end":-1},{"beam":0,"end":1},{"beam":1,"end":-1},{"beam":1,"end":1}],
		"solids":[Rect2(416,342,35,20),Rect2(483,470,34,100),Rect2(300,390,155,18)],
		"vases":[Vector2(310,200)], "box":Rect2(300,460,165,100),
		"solution":[{"pin":2,"at":0.5},{"pin":1,"at":2.5}], "par":2
	}
	var roof: Dictionary = first.duplicate(true)
	roof["title"] = "触れない、勇気"
	roof["chapter"] = "III  構造を読む"
	roof["lesson"] = "切れる場所が増えても、全部切る必要はない。上の梁は誰の味方？"
	roof["beams"].append(beam(320,130,240))
	roof["pins"].append({"beam":1,"end":-1})
	roof["pins"].append({"beam":1,"end":1})
	roof["hints"] = ["上の梁を外すと、下には陶器がある。","②だけを切る。屋根を残すのも、立派な解体。"]
	var finale: Dictionary = bridge.duplicate(true)
	finale["title"] = "こわさず、壊す。"
	finale["chapter"] = "IV  最後の搬出"
	finale["lesson"] = "二つの陶器、ひとつの橋。残す支点と切る順序で、最後の搬出を。"
	finale["vases"] = [Vector2(255,160),Vector2(335,160)]
	finale["box"] = Rect2(765,435,150,120)
	finale["hints"] = ["陶器の数が増えても、道づくりの基本は変わらない。","④で橋を倒し、止まってから②。①と③は最後まで残す。"]
	return [first,mirror,cradle,bridge,pair,roof,cascade,finale]
