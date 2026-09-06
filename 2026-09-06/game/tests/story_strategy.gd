extends "res://tests/strategy.gd"
var resident_id=0
var wanted=[]
func _init(id:int=0):
	resident_id=id
	super("staples")
func plan_assortment(game,focus:int):
	var req=Stories.request(game.s.residents[resident_id])
	if req.is_empty():super.plan_assortment(game,focus);return
	wanted=[]
	for group in req.get("all",[]):
		if wanted.any(func(p):return Stories.product_matches(p,group)):continue
		var candidates=game.products.filter(func(p):return p.unlock<=game.s.star and Stories.product_matches(p.id,group) and game.s.fixtures.any(func(f):return game.compatible(f,p.id)))
		candidates.sort_custom(func(a,b):return a.price<b.price)
		if not candidates.is_empty():wanted.append(candidates[0].id)
	if req.has("distinct"):
		var candidates=game.products.filter(func(p):return p.unlock<=game.s.star and p.cat==req.distinct_cat and not wanted.has(p.id) and game.s.fixtures.any(func(f):return game.compatible(f,p.id)))
		candidates.sort_custom(func(a,b):return a.price<b.price)
		for p in candidates:
			if wanted.filter(func(id):return game.products[id].cat==req.distinct_cat).size()>=req.distinct:break
			wanted.append(p.id)
	for p in wanted:
		if game.s.fixtures.any(func(f):return f.product==p):continue
		var candidates=game.s.fixtures.filter(func(f):return game.compatible(f,p) and not wanted.has(f.product) and f.y!=11)
		candidates.sort_custom(func(a,b):return game.volume(a.lots)<game.volume(b.lots))
		if not candidates.is_empty():do(game,"assign",{"fixture":candidates[0].id,"product":p})
