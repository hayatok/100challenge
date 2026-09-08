class_name RescueCampaign
extends RefCounted

static func body(x: float,y: float,w: float,h: float=18.0,kind: String="beam",m: float=3.0,angle: float=0.0) -> Dictionary:
	return {"p":Vector2(x,y),"size":Vector2(w,h),"kind":kind,"mass":m,"angle":angle}
static func pin(b: int,end: float=0.0) -> Dictionary:
	return {"beam":b,"end":end}
static func action(p: int,t: float) -> Dictionary:
	return {"pin":p,"at":t}
static func surface(x: float,y: float,w: float,h: float=18,angle: float=0,pad: bool=false) -> Dictionary:
	return {"p":Vector2(x,y),"size":Vector2(w,h),"angle":angle,"pad":pad}
static func rail(b: int,x: float,y: float,X: float,Y: float) -> Dictionary:
	return {"beam":b,"from":Vector2(x,y),"to":Vector2(X,Y)}
static func base(title: String,box: Rect2,vases: Array[Vector2]) -> Dictionary:
	return {"title":title,"box":box,"vases":vases,"beams":[],"pins":[],"solids":[],"surfaces":[],"joints":[],"cables":[],"rails":[],"lesson":"すべての陶器を、緑の梱包箱へ。","hints":[],"solution":[],"traps":[],"par":1}

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var d: Dictionary = base("残る、ひとつ",Rect2(465,350,155,100),[Vector2(300,200)])
	d["beams"] = [body(310,230,300)]
	d["pins"] = [pin(0,-1),pin(0,1)]
	d["solids"] = [Rect2(416,342,35,228)]
	d["lesson"] = "真鍮の接合点を切る。\n陶器を、緑の箱へ届けよう。"
	d["hints"] = ["切らない側が、回転の中心になる。","②を切り、①を残す。"]
	d["solution"] = [action(1,0.5)]
	d["traps"] = [[action(0,0.5)]]
	result.append(d)

	d = base("長い影",Rect2(770,445,140,110),[Vector2(300,160)])
	d["beams"] = [body(310,190,300),body(502,215,300,18,"beam",3,-1.35)]
	d["pins"] = [pin(0,-1),pin(0,1),pin(1,-1),pin(1,1)]
	d["solids"] = [Rect2(416,302,35,268),Rect2(720,444,35,126)]
	d["hints"] = ["梁の先端が、倒れる途中に通る場所を見よう。","③を残して④を切る。梁が載ったら②。"]
	d["solution"] = [action(3,0.5),action(1,4.5)]
	d["traps"] = [[action(2,0.5),action(1,4.5)],[action(1,0.5)]]
	result.append(d)

	d = base("二つの役目",Rect2(300,460,190,105),[Vector2(300,160)])
	d["beams"] = [body(310,190,300),body(560,360,220)]
	d["pins"] = [pin(0,-1),pin(0,1),pin(1,-1),pin(1,1)]
	d["solids"] = [Rect2(416,302,35,20),Rect2(535,425,30,145),Rect2(659,298,18,40)]
	d["hints"] = ["最初に陶器が触れる面を考えよう。","②で送り、水平な下の床で止まってから③。"]
	d["solution"] = [action(1,0.5),action(2,5)]
	d["traps"] = [[action(2,0.5),action(1,1)]]
	result.append(d)

	d = base("柱の向こう",Rect2(775,430,140,125),[Vector2(300,230)])
	d["beams"] = [body(310,260,300),body(590,200,360,22,"beam",8),body(600,330,180,18,"beam",3,-1.107),body(825,300,38,80)]
	for i: int in [1,2,3]:
		d["beams"][i]["lock"] = i != 2
	d["beams"][1]["friction"] = 0.05
	d["beams"][2]["friction"] = 0.05
	d["joints"] = [{"beam":2,"local":Vector2(-90,0),"frame_surface":0}]
	d["pins"] = [pin(0,-1),pin(0,1),pin(2,1),pin(3)]
	d["rails"] = [rail(1,590,195,590,530),rail(3,825,300,730,330)]
	d["solids"] = [Rect2(416,372,35,198)]
	d["surfaces"] = [surface(605,427,300,18,0.16)]
	d["hints"] = ["邪魔な柱の上を、たどってみよう。","④で代わりの支えを下ろす。③で柱を退けてから②。"]
	d["solution"] = [action(3,0.5),action(2,3.5),action(1,7)]
	d["traps"] = [[action(2,0.5),action(1,4)],[action(1,0.5),action(2,3)]]
	result.append(d)

	d = base("高い出口",Rect2(380,255,150,100),[Vector2(270,352)])
	d["beams"] = [body(270,390,170,18,"beam",3,0.13),body(640,180,50,50,"weight",6),body(350,359,70,12,"beam",0.3,-1.35)]
	d["beams"][0]["lock"] = true
	d["beams"][1]["lock"] = true
	d["rails"] = [rail(0,270,210,270,440),rail(1,640,125,640,470)]
	d["cables"] = [{"a":0,"b":1,"guides":[Vector2(270,80),Vector2(640,80)]}]
	d["joints"] = [{"beam":2,"local":Vector2(-35,0),"other":0}]
	d["pins"] = [pin(1),{"beam":2,"end":1,"other":0},{"cable":0,"at":Vector2(640,100)}]
	d["hints"] = ["重りの綱は、何につながっている？","③の綱を残して①。台が上で止まってから②。"]
	d["solution"] = [action(0,0.5),action(1,5)]
	d["traps"] = [[action(2,0.5),action(0,1)],[action(1,0.5),action(0,5)]]
	result.append(d)

	d = base("降りた、そのあと",Rect2(190,455,150,100),[Vector2(500,170)])
	d["beams"] = [body(500,200,105,8,"hanger",0.5),body(535,355,330,18,"beam",2.5,-0.18),body(500,200,96,12,"beam",0.2),body(300,390,35,50)]
	d["beams"][0].merge({"lock":true,"wall":70.0},true)
	d["beams"][1]["pad"] = true
	d["beams"][3]["lock"] = true
	d["rails"] = [rail(0,500,100,500,290),rail(3,300,390,395,440)]
	d["cables"] = [{"a":0,"b":1,"local_b":Vector2(-155,0),"guides":[Vector2(500,80),Vector2(380,80)]}]
	d["joints"] = [{"beam":1,"local":Vector2(120,0)},{"beam":2,"local":Vector2(-48,0),"other":0}]
	d["pins"] = [pin(3),{"beam":2,"end":1,"other":0}]
	d["surfaces"] = [surface(705,346,28,16)]
	d["hints"] = ["陶器がかごを離れたあと、下の橋を支える力は？","①の支えを橋の下へ。②を開ける前に、荷重が抜けても道が残るようにする。"]
	d["solution"] = [action(0,0.5),action(1,5)]
	d["traps"] = [[action(1,0.5)]]
	result.append(d)

	d = base("迎えの箱",Rect2(200,400,130,65),[Vector2(288,181)])
	d["beams"] = [body(700,230,130,16,"crate",3),body(580,304,16,65),body(345,405,16,100),body(408,225,70,12,"beam",0.3,-1.35)]
	d["beams"][0].merge({"lock":true,"pad":true,"wall":65.0},true)
	d["crate"] = 0
	d["rails"] = [rail(0,700,230,270,470)]
	d["surfaces"] = [surface(333,229,150,16,0.43)]
	d["joints"] = [{"beam":3,"local":Vector2(-35,0),"frame_surface":0}]
	d["pins"] = [pin(0),pin(1),pin(2),pin(3,1)]
	d["hints"] = ["箱を陶器のそばへ。どの止め木を残せば、そこで止まる？","②だけを退けて①。箱が③で止まったら④。"]
	d["solution"] = [action(1,0.5),action(0,2.5),action(3,8)]
	d["traps"] = [[action(1,0.5),action(2,0.5),action(0,2.5),action(3,8)],[action(3,0.5)]]
	result.append(d)

	d = base("近い作品、遠い作品",Rect2(180,335,175,120),[Vector2(250,170),Vector2(655,278)])
	d["beams"] = [body(250,200,105,8,"hanger",1.2),body(540,330,330,18,"beam",2.0,-0.2),body(250,200,96,12,"beam",0.2),body(610,275,70,12,"beam",0.2,1.35)]
	d["beams"][0]["lock"] = true
	d["beams"][0]["wall"] = 70.0
	d["rails"] = [rail(0,250,100,250,290)]
	d["cables"] = [{"a":0,"b":1,"local_b":Vector2(-155,0),"guides":[Vector2(250,80),Vector2(385,80)]}]
	d["joints"] = [{"beam":1,"local":Vector2(120,0)},{"beam":2,"local":Vector2(-48,0),"other":0},{"beam":3,"local":Vector2(35,0),"other":1}]
	d["pins"] = [{"beam":2,"end":1,"other":0},{"beam":3,"end":-1,"other":1}]
	d["surfaces"] = [surface(700,318,28,16)]
	d["hints"] = ["近い陶器のかごから、綱の先をたどろう。","①の陶器を重りとして残す。②で遠い陶器を箱へ送り、そのあと①。"]
	d["solution"] = [action(1,1),action(0,10)]
	d["traps"] = [[action(0,0.5),action(1,4)]]
	result.append(d)

	d = base("通り抜ける梁",Rect2(450,460,180,105),[Vector2(515,125)])
	d["beams"] = [body(650,169,24,24,"beam",3),body(590,160,300,18,"beam",2,0.08),body(570,110,70,8,"beam",0.1,1.35),body(740,235,180,18)]
	d["beams"][0]["lock"] = true
	d["beams"][0]["pad"] = true
	d["beams"][1]["pad"] = true
	d["beams"][3]["pad"] = true
	d["beams"][1]["friction"] = 0.04
	d["rails"] = [rail(0,650,169,650,490)]
	d["joints"] = [{"beam":1,"local":Vector2(60,0),"other":0,"limits":Vector2(-1.5,0.3)},{"beam":2,"local":Vector2(-35,0)},{"beam":3,"local":Vector2(90,0)}]
	d["pins"] = [pin(1,-1),pin(0),pin(2,1),pin(3,-1)]
	d["surfaces"] = [surface(285,398,550,18,0.12),surface(820,425,220,18,-0.12),surface(740,366,118,18,-0.84),surface(500,530,350,20,-0.08)]
	for receiving_surface: Dictionary in d["surfaces"]:
		receiving_surface["pad"] = true
	d["solids"] = [Rect2(802,172,15,63)]
	d["hints"] = ["上の待機棚と、下の道。梁を両方で使えないだろうか。","③で陶器を棚へ。①で空の梁を縦にし、②で下ろす。下で梁が落ち着いてから④。"]
	d["solution"] = [action(2,0.5),action(0,9),action(1,13),action(3,20)]
	d["traps"] = [[action(0,0.5),action(1,4),action(2,7),action(3,15)],[action(2,0.5),action(1,9),action(3,18)]]
	# Offset the transfer rig from the chute so the carriage clears its lip.
	for b: Dictionary in d["beams"]:
		b["p"].x += 30
	for r: Dictionary in d["rails"]:
		r["from"].x += 30
		r["to"].x += 30
	for j: int in [0,1,3]:
		d["surfaces"][j]["p"].x += 30
	d["solids"][0].position.x += 30
	d["vases"][0].x += 30
	d["box"].position.x += 30
	result.append(d)

	# Q is a contact cradle, not an automatically attached joint.
	d = base("支点の引越し",Rect2(130,425,175,135),[Vector2(605,180)])
	d["beams"] = [body(520,210,440,18,"beam",3,-0.1),body(390,275,42,42,"weight",8),body(575,175,70,12,"beam",0.2,1.35)]
	d["beams"][0]["parts"] = [{"p":Vector2(-28,20),"size":Vector2(10,32)},{"p":Vector2(28,20),"size":Vector2(10,32)}]
	d["joints"] = [{"beam":1,"other":0},{"beam":2,"local":Vector2(35,0),"other":0}]
	d["pins"] = [{"beam":0,"local":Vector2(-200,0)},pin(0,1),{"beam":2,"end":-1,"other":0}]
	d["surfaces"] = [surface(500,321,30,30),surface(500,446,18,220),surface(312,440,38,25),surface(280,400,500,18,-0.1,true)]
	d["hints"] = ["最初の支点を残したまま、左の箱へ傾けられる？","②で床を叉形の受け座へ載せ、①の旧支点を外す。重りが左を下げてから③。"]
	d["solution"] = [action(1,0.5),action(0,6),action(2,12)]
	d["traps"] = [[action(0,0.5),action(1,6),action(2,12)],[action(1,0.5),action(2,8)],[action(2,0.5),action(1,4),action(0,8)]]
	result.append(d)

	d = base("重りの残り仕事",Rect2(680,300,165,125),[Vector2(300,175)])
	d["beams"] = [body(520,390,230,18,"beam",3,0.1),body(780,170,100,8,"hanger",0.5),body(780,170,90,12,"beam",0.2),body(780,138,52,52,"weight",7),body(700,200,35,80),body(780,430,100,12,"tray",0.5),body(650,285,18,140,"beam",2),body(377,184,70,12,"beam",0.2,-1.35)]
	for i: int in [0,1,3,4,5,6]: d["beams"][i]["lock"] = true
	d["beams"][1]["wall"] = 75.0
	d["beams"][5]["wall"] = 60.0
	d["rails"] = [rail(0,520,230,520,390),rail(1,780,170,780,330),rail(4,700,200,570,285),rail(5,780,430,780,550),rail(6,650,165,650,285)]
	d["cables"] = [{"a":0,"b":1,"guides":[Vector2(520,75),Vector2(780,75)]},{"a":5,"b":6,"guides":[Vector2(780,95),Vector2(650,95)]}]
	d["surfaces"] = [surface(310,210,160,16,0.18)]
	d["joints"] = [{"beam":2,"local":Vector2(-45,0),"other":1},{"beam":7,"local":Vector2(-35,0),"frame_surface":0}]
	d["pins"] = [pin(1),pin(4),{"beam":2,"end":1,"other":1},pin(7,1),{"cable":0,"at":Vector2(520,110)}]
	d["hints"] = ["重りが下がったあとにも、橋をその高さに残せる？","①で昇橋、②でくさびを入れる。③で重りを下の受け鉢へ渡し、扉が上がったら④。"]
	d["solution"] = [action(0,0.5),action(1,6),action(2,11),action(3,17)]
	d["traps"] = [[action(2,0.5),action(0,4),action(3,12)],[action(0,0.5),action(2,6),action(3,12)],[action(0,0.5),action(1,6),action(3,12)]]
	result.append(d)

	d = base("橋にしない梁",Rect2(700,365,160,160),[Vector2(605,250)])
	d["beams"] = [body(510,185,300,18,"beam",3,1.3),body(350,130,44,44,"weight",7),body(220,450,110,14,"tray",0.5),body(690,300,18,150,"beam",2),body(610,280,160)]
	for i: int in [1,2,3]: d["beams"][i]["lock"] = true
	d["beams"][0]["friction"] = 0.03
	d["beams"][1]["friction"] = 0.03
	d["beams"][2]["wall"] = 60.0
	d["rails"] = [rail(2,220,450,220,550),rail(3,690,200,690,300)]
	d["cables"] = [{"a":2,"b":3,"guides":[Vector2(220,85),Vector2(690,85)]}]
	d["pins"] = [pin(0,-1),pin(0,1),pin(1),pin(4,-1),pin(4,1)]
	d["surfaces"] = [surface(268,403,32,24),surface(660,383,30,24)]
	d["hints"] = ["箱の扉から綱をたどると、何が必要だろう。","②を残して①で長い梁を左下がりに。③の重りを受け鉢へ送り、扉が上がったら⑤。"]
	d["solution"] = [action(0,0.5),action(2,6),action(4,13)]
	d["traps"] = [[action(1,0.5),action(2,6),action(4,13)],[action(2,0.5),action(0,6),action(4,13)],[action(4,0.5)]]
	result.append(d)

	# Two visible replacement props offer different occupied space below H.
	d = base("箱が支えている",Rect2(260,250,140,65),[Vector2(725,220)])
	d["beams"] = [body(330,315,140,16,"crate",3),body(560,239,600,22,"beam",5),body(895,320,40,140),body(915,320,38,140),body(100,180,50,50,"weight",9),body(740,250,120)]
	for i: int in [0,1,2,3,4]: d["beams"][i]["lock"] = true
	d["beams"][0].merge({"pad":true,"wall":65.0,"friction":0.03},true)
	d["beams"][1]["friction"] = 0.03
	d["crate"] = 0
	d["rails"] = [rail(0,330,315,740,375),rail(1,560,239,560,530),rail(2,895,320,850,340),rail(3,915,320,600,340),rail(4,100,180,100,500)]
	d["cables"] = [{"a":4,"b":0,"guides":[Vector2(100,80),Vector2(850,80)]}]
	d["joints"] = [{"beam":5,"local":Vector2(60,0)}]
	d["pins"] = [pin(0),pin(2),pin(3),pin(4),pin(5,-1)]
	d["hints"] = ["支えた天井の下を、箱の幅で通れるだろうか。","③の内側の支柱は通路を塞ぐ。②の外側の支柱を下ろし、④と①で箱を迎えに送り、停止後に⑤。"]
	d["solution"] = [action(1,0.5),action(3,6),action(0,7),action(4,15)]
	d["traps"] = [[action(3,0.5),action(0,1),action(4,10)],[action(2,0.5),action(3,6),action(0,7),action(4,15)]]
	result.append(d)

	d = base("遠回りのための解体",Rect2(825,455,100,110),[Vector2(520,290)])
	d["beams"] = [body(630,320,24,24),body(520,320,220),body(305,395,190),body(471.5,282.5,320,18,"beam",2.5,-1.75),body(560,380,40,40,"weight",5)]
	d["beams"][0]["lock"] = true
	d["beams"][1]["pad"] = true
	d["beams"][2]["pad"] = true
	d["rails"] = [rail(0,630,320,630,470)]
	d["joints"] = [{"beam":1,"local":Vector2(110,0),"other":0},{"beam":2,"local":Vector2(-95,0)},{"beam":3,"local":Vector2(-160,0)},{"beam":4,"other":3}]
	d["pins"] = [pin(1,-1),pin(0),pin(3,1),pin(2,1)]
	d["surfaces"] = [surface(430,380,24,18),surface(404,425,24,18),surface(420,456,28,24),surface(806,495,35,20)]
	d["solids"] = [Rect2(202,322,10,73)]
	d["hints"] = ["大きな梁を回す場所に、まだ陶器が残っていない？","①で左の退避棚へ。③で空いた場所に長い梁を倒し、②で床材を下ろす。戻る道ができてから④。"]
	d["solution"] = [action(0,0.5),action(2,8),action(1,13),action(3,20)]
	d["traps"] = [[action(2,0.5),action(0,5),action(1,10),action(3,16)],[action(0,0.5),action(3,7)],[action(1,0.5),action(0,1),action(2,6),action(3,12)]]
	result.append(d)

	d = base("渡り終えても必要",Rect2(175,250,140,70),[Vector2(245,165),Vector2(320,260)])
	d["beams"] = [body(245,195,105,8,"hanger",1.2),body(245,195,96,12,"beam",0.2),body(550,370,300,18,"beam",3,0.18),body(245,320,140,16,"crate",2),body(700,410,145,18,"beam",3),body(332,291,90,12,"beam",0.3),body(345,125,46,46,"weight",9),body(350,450,100,14,"tray",0.5),body(292,319,16,65),body(735,465,16,90)]
	for i: int in [0,3,6,7]: d["beams"][i]["lock"] = true
	d["beams"][0]["wall"] = 70.0
	d["beams"][2]["pad"] = true
	d["beams"][3].merge({"pad":true,"wall":70.0,"friction":0.03},true)
	d["beams"][7]["wall"] = 55.0
	d["crate"] = 3
	d["rails"] = [rail(0,245,100,245,290),rail(7,350,450,350,540)]
	d["cables"] = [{"a":0,"b":2,"local_b":Vector2(140,0),"guides":[Vector2(245,80),Vector2(665,80)]},{"a":7,"b":2,"local_b":Vector2(140,0),"guides":[Vector2(350,75),Vector2(665,75)],"slack":5.0}]
	d["joints"] = [{"beam":1,"local":Vector2(-48,0),"other":0},{"beam":2,"local":Vector2(-100,0)},{"beam":4,"local":Vector2(-72.5,0)},{"beam":5,"local":Vector2(-45,0)}]
	d["pins"] = [{"beam":1,"end":1,"other":0},pin(5,1),pin(6),pin(8),pin(4,1),pin(9)]
	d["surfaces"] = [surface(245,332,140,16,0.08),surface(673,371,28,16),surface(715,530,155,18)]
	d["solids"] = [Rect2(773,342,10,68)]
	d["hints"] = ["遠い陶器が渡ったあと、同じ橋をもう一度通る物は？","②でBを待機棚へ。③の重りで橋を引き継いでから①でAを箱へ。④で箱を送り、⑥の停止木を残して、最後に⑤。"]
	d["solution"] = [action(1,0.5),action(2,8),action(0,14),action(3,20),action(4,28)]
	d["traps"] = [[action(1,0.5),action(0,8),action(3,14),action(4,23)],[action(2,0.5),action(1,6),action(0,12),action(3,18),action(4,25)],[action(0,0.5),action(1,6),action(3,12),action(4,20)]]
	result.append(d)

	# The crate rides a lift bed, then rolls off it; it never teleports between rails.
	d = base("往路と復路",Rect2(690,385,140,70),[Vector2(340,185),Vector2(275,382)])
	d["beams"] = [body(760,455,140,16,"crate",2),body(760,474,170,18,"beam",3,-0.12),body(870,175,100,8,"hanger",0.5),body(870,175,90,12,"beam",0.2),body(870,143,52,52,"weight",10),body(630,218,24,24),body(500,210,280,18,"beam",3,0.06),body(580,290,35,90),body(688,335,16,330,"beam",4,0.06),body(870,440,100,14,"tray",0.5),body(397,191,70,12,"beam",0.2,-1.35),body(280,412,145),body(327,485,16,85)]
	for i: int in [0,1,2,4,5,7,9]: d["beams"][i]["lock"] = true
	d["beams"][0].merge({"pad":true,"wall":70.0,"friction":0.02},true)
	d["beams"][2]["wall"] = 75.0
	d["beams"][6]["pad"] = true
	d["beams"][9]["wall"] = 60.0
	d["crate"] = 0
	d["rails"] = [rail(1,760,315,760,474),rail(2,870,175,870,334),rail(5,630,218,630,325),rail(7,580,290,670,370),rail(9,870,440,870,555)]
	d["cables"] = [{"a":1,"b":2,"guides":[Vector2(760,65),Vector2(870,65)]},{"a":8,"b":9,"local_a":Vector2(0,100),"guides":[Vector2(480,435),Vector2(480,75),Vector2(870,75)]}]
	d["joints"] = [{"beam":3,"local":Vector2(-45,0),"other":2},{"beam":6,"local":Vector2(130,0),"other":5},{"beam":10,"local":Vector2(-35,0),"frame_surface":0},{"beam":8,"local":Vector2(0,165),"limits":Vector2(-1.7,0.0)},{"beam":11,"local":Vector2(-72.5,0)}]
	d["pins"] = [pin(2),pin(7),pin(10,1),pin(6,-1),pin(5),{"beam":3,"end":1,"other":2},pin(11,1),pin(12),{"cable":0,"at":Vector2(760,100)}]
	d["surfaces"] = [surface(330,218,150,16,0.13),surface(370,447,50,24),surface(630,355,45,20),surface(375,525,170,18),surface(710,345,18,220)]
	d["hints"] = ["箱を上へ運ぶ道と、一個目を受け取った後の帰り道を見比べよう。","①で昇降、②で台を保持し、③でAを箱へ。④→⑤で空の梁を復路へ移し、⑥で重りを次の受け鉢へ。⑧を残して箱を止め、最後に⑦。"]
	d["solution"] = [action(0,0.5),action(1,7),action(2,13),action(3,21),action(4,26),action(5,32),action(6,42)]
	d["traps"] = [[action(3,0.5),action(4,6),action(0,10),action(2,18)],[action(0,0.5),action(1,7),action(2,13),action(5,21)],[action(0,0.5),action(1,7),action(2,13),action(4,21),action(3,26),action(5,32),action(6,42)]]
	result.append(d)
	var chapters: Array[String] = ["I  支持と空間","II  荷重と順序","III  仕事の引継ぎ","IV  先を読む搬出"]
	for i: int in range(result.size()):
		result[i]["art_id"] = i
		result[i]["chapter"] = chapters[i/4]
		result[i]["par"] = result[i]["solution"].size()
	return result
