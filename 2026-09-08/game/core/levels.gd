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
		"lesson":"立つ梁も、倒せば道になる。\n陶器の行き先を、先につくろう。",
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
	roof["lesson"] = "全部を切る必要はない。\n上の梁は、誰の味方？"
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
	# First half teaches individual tools. The second half composes them into
	# physical intermediate states; no solution-order flags are used by the world.
	roof["chapter"] = "I  支点を選ぶ"
	finale["title"] = "橋を渡る、二作品"
	finale["lesson"] = "ふたつとも、同じ箱へ。途中の支えも読み解こう。"
	var return_bridge: Dictionary = bridge.duplicate(true)
	return_bridge["title"] = "長い、帰り道"
	return_bridge["lesson"] = "橋の向こうに、もう一枚の床。箱までの道を組み立てる。"
	return_bridge["beams"].append(beam(790,490,200))
	add_pins(return_bridge,2)
	return_bridge["solids"] = [Rect2(416,302,35,20),Rect2(720,444,35,20),Rect2(889,428,18,40),Rect2(805,530,30,40)]
	return_bridge["box"] = Rect2(575,510,200,55)
	return_bridge["solution"] = [{"pin":3,"at":0.5},{"pin":4,"at":0.5},{"pin":1,"at":4.5}]
	return_bridge["par"] = 3
	return_bridge["hints"] = ["最後の床で、進む向きをもう一度変える。", "④で橋を倒し、⑤で右端の床を左下がりに。最後に②。"]
	var catch_tray: Dictionary = bridge.duplicate(true)
	catch_tray["title"] = "まだ、切らない"
	catch_tray["lesson"] = "先に道を作る？ それとも、今は残す？"
	catch_tray["beams"] = [beam(310,190,300),beam(560,360,220)]
	catch_tray["solids"] = [Rect2(416,302,35,20),Rect2(535,425,30,145),Rect2(659,298,18,40)]
	catch_tray["box"] = Rect2(300,460,190,105)
	catch_tray["solution"] = [{"pin":1,"at":0.5},{"pin":2,"at":5.0}]
	catch_tray["hints"] = ["下の床を早く傾けると、着地の衝撃が強すぎる。", "②で送り出し、下の水平な床に載って止まるまで待つ。そこで③。"]
	var drop_tray: Dictionary = catch_tray.duplicate(true)
	drop_tray["title"] = "床も、荷物になる"
	drop_tray["lesson"] = "箱の形が変わった。傾けるだけが、搬出じゃない。"
	drop_tray["beams"] = [beam(310,190,300),beam(560,330,220)]
	drop_tray["solids"] = [Rect2(416,302,35,20),Rect2(659,268,18,40)]
	drop_tray["box"] = Rect2(450,370,245,100)
	drop_tray["solution"] = [{"pin":1,"at":0.5},{"pin":2,"at":5.0},{"pin":3,"at":5.0}]
	drop_tray["par"] = 3
	drop_tray["hints"] = ["陶器を受け止めた床を、そのまま箱へ。", "②で送り、下の床で止まるのを待つ。停止中に③④を切り、再開。"]
	var merge_tray: Dictionary = catch_tray.duplicate(true)
	merge_tray["title"] = "合流して、折り返す"
	merge_tray["lesson"] = "別々の高さから、ひとつの道へ。全員が通れる構造を。"
	add_upper(merge_tray,2)
	merge_tray["solution"] = [{"pin":4,"at":0.5},{"pin":5,"at":0.5},{"pin":1,"at":3.0},{"pin":2,"at":9.0}]
	merge_tray["par"] = 4
	merge_tray["hints"] = ["上の小台を先に降ろせば、ふたつを一緒に送れる。", "⑤⑥で小台を降ろす。落ち着いてから②。二作品とも受け皿に載ってから③。"]
	var stack: Dictionary = drop_tray.duplicate(true)
	stack["title"] = "二枚の床の、役割"
	stack["lesson"] = "運ぶ床と、道になる床。最後まで残す支点を探そう。"
	stack["beams"].append(beam(560,395,240))
	add_pins(stack,2)
	stack["solids"].append(Rect2(535,460,30,110))
	stack["box"] = Rect2(270,440,240,120)
	stack["solution"] = [{"pin":1,"at":0.5},{"pin":2,"at":5.0},{"pin":3,"at":5.0},{"pin":4,"at":8.0}]
	stack["par"] = 4
	stack["hints"] = ["中段を台ごと降ろし、下段を坂に変える。", "②で中段に載せて待つ。③④で下段へ降ろし、⑤で左へ。下段の坂は先に作ってもよい。"]
	var merge_drop: Dictionary = merge_tray.duplicate(true)
	merge_drop["title"] = "最後のひとつを、待つ"
	merge_drop["lesson"] = "先に着いた作品だけで、搬出を始めない。"
	merge_drop["solids"] = [Rect2(416,302,35,20),Rect2(659,298,18,40)]
	merge_drop["box"] = Rect2(450,390,245,100)
	merge_drop["solution"] = [{"pin":4,"at":0.5},{"pin":5,"at":0.5},{"pin":1,"at":3.0},{"pin":2,"at":9.0},{"pin":3,"at":9.0}]
	merge_drop["par"] = 5
	merge_drop["hints"] = ["受け皿を降ろすのは、ふたつがそろってから。", "⑤⑥で合流、②で移動。二作品が中段で止まったら、停止中に③④を切って降ろす。"]
	var merge_stack: Dictionary = stack.duplicate(true)
	merge_stack["title"] = "重ねた床を、ほどく"
	merge_stack["lesson"] = "台と陶器が重なると、着地も変わる。下から上へ構造を読もう。"
	merge_stack["beams"] = [beam(310,190,300),beam(560,360,220),beam(560,400,240)]
	merge_stack["solids"] = [Rect2(416,302,35,20),Rect2(659,288,18,40),Rect2(535,465,30,105)]
	merge_stack["box"] = Rect2(270,450,240,115)
	add_upper(merge_stack,3)
	merge_stack["solution"] = [{"pin":4,"at":0.5},{"pin":6,"at":0.5},{"pin":7,"at":0.5},{"pin":1,"at":3.0},{"pin":2,"at":9.0},{"pin":3,"at":9.0}]
	merge_stack["par"] = 6
	merge_stack["hints"] = ["台を重ねて水平に落とすと衝撃が大きい。下段は坂にしておこう。", "⑤で下段を傾け、⑦⑧で小台を降ろす。②で二作品を中段へ。そろってから③④。"]
	var final_model: Dictionary = merge_stack.duplicate(true)
	final_model["title"] = "こわさず、壊す。"
	final_model["lesson"] = "離れた二作品、五枚の床。搬出の手順を、自分で組み立てる。"
	final_model["beams"].append(beam(235,120,90))
	add_pins(final_model,4)
	final_model["vases"] = [Vector2(235,90),Vector2(350,90)]
	final_model["solution"] = [{"pin":4,"at":0.5},{"pin":6,"at":0.5},{"pin":7,"at":0.5},{"pin":8,"at":0.5},{"pin":9,"at":0.5},{"pin":1,"at":3.0},{"pin":2,"at":9.0},{"pin":3,"at":9.0}]
	final_model["par"] = 8
	final_model["hints"] = ["終点の坂、出発前の合流、受け皿での待機。三つの場所を順に考える。", "⑤で出口を準備。⑦⑧と⑨⑩で二つの小台を降ろし、②。全員が中段で止まってから③④。"]
	var result: Array[Dictionary] = [first,mirror,cradle,roof,bridge,pair,cascade,finale,return_bridge,catch_tray,drop_tray,merge_tray,stack,merge_drop,merge_stack,final_model]
	var chapters: Array[String] = ["I  支点を選ぶ", "II  道をつなぐ", "III  残す時間", "IV  搬出を組み立てる"]
	for i: int in range(result.size()):
		result[i]["art_id"] = i
		result[i]["chapter"] = chapters[i/4]
		if i>=9:
			# Keep the receiving ledge readable while the player decides the next cut.
			var tray_y: float = result[i]["beams"][1]["p"].y
			result[i]["clear_zones"] = [Rect2(570,tray_y-52,96,44)]
	return result

static func add_pins(data: Dictionary, body: int) -> void:
	data["pins"].append({"beam":body,"end":-1})
	data["pins"].append({"beam":body,"end":1})

static func add_upper(data: Dictionary, body: int) -> void:
	data["beams"].append(beam(350,120,90))
	add_pins(data,body)
	data["vases"] = [Vector2(280,160),Vector2(350,90)]
