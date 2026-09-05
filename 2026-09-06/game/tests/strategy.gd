extends RefCounted
var style="staples"
var commands=[]
func _init(kind:String="staples"):style=kind
func do(game,name:String,args:Dictionary={}):
	var error=game.command(name,args)
	if error.is_empty():commands.append({"tick":game.s.tick,"command":name,"args":args.duplicate(true)})
	return error
func update(game):
	var s=game.s
	if s.day>1 and not s.auto:do(game,"auto",{"enabled":true})
	if s.auto_limit!=24000:do(game,"auto_limit",{"amount":24000})
	# Invest after the customer base has grown, while leaving working capital.
	if s.star>=1 and not s.staff[2].hired and s.cash>24000:
		do(game,"hire",{"id":2});do(game,"shift",{"id":2,"slot":0});do(game,"shift",{"id":2,"slot":1})
	if s.star>=2 and not s.staff[3].hired and s.cash>28000:
		do(game,"hire",{"id":3});do(game,"shift",{"id":3,"slot":2});do(game,"shift",{"id":3,"slot":3})
	if s.star>=2 and s.cash>32000 and s.fixtures.filter(func(f):return f.kind==10).is_empty():
		do(game,"place",{"kind":10,"x":4,"y":7,"dir":3})
	if s.star>=1 and s.tier==0 and s.cash>50000:do(game,"expand")
	if s.star>=2 and s.cash>32000 and not s.reports.is_empty() and s.reports[-1].miss.get("行列",0)>3:
		for w in s.staff:
			if w.hired and not game.working(w) and w.training<2:do(game,"train",{"id":w.id})
	# The theme changes the actual assortment, shelf geography and financial risk.
	var focus=0 if style=="morning" else (4 if style=="sweets" else 2)
	if s.star>=1 and s.cash>28000 and s.fixtures.size()<11:
		var kind=9 if focus in [2,4] else 8
		if do(game,"place",{"kind":kind,"x":4,"y":5,"dir":1}).is_empty():
			do(game,"assign",{"fixture":s.next_fixture-1,"product":focus*10+1})
	for f in s.fixtures:
		if f.product<0:continue
		var p=f.product
		var mean=0.0;var reports=s.reports.slice(maxi(0,s.reports.size()-3))
		for r in reports:mean+=r.product_sales.get(p,0)
		mean=mean/maxi(reports.size(),1)
		var target=12 if reports.is_empty() else clampi(ceili(mean*1.3)+3,4,60)
		if game.products[p].life<=1440:target=mini(target,ceili(mean*0.6)+3)
		if game.products[p].cat==focus:target+=3
		if int(s.targets.get(p,0))!=target:do(game,"target",{"product":p,"amount":target})
		var price=1
		if style=="morning" and p==0:price=0
		if int(s.prices.get(p,1))!=price:do(game,"price",{"product":p,"level":price})
	if s.star>=4 and s.review.get("status","") not in ["active","passed"] and s.day<=42:do(game,"review")
