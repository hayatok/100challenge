extends RefCounted
const Stories=preload("res://core/resident_stories.gd")
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
		do(game,"place",{"kind":10,"x":4,"y":8,"dir":0})
	if s.star>=1 and s.tier==0 and s.cash>50000:do(game,"expand")
	if s.star>=2 and s.cash>32000 and not s.reports.is_empty() and (style=="fixed_plan" or s.reports[-1].miss.get("行列",0)>3):
		for w in s.staff:
			if w.hired and not game.working(w) and w.training<2:do(game,"train",{"id":w.id})
	# The theme changes the actual assortment, shelf geography and financial risk.
	var focus=0 if style=="morning" else (4 if style=="sweets" else 2)
	if s.star>=1 and s.cash>28000 and s.fixtures.size()<11:
		var kind=9 if focus in [2,4] else 8
		if do(game,"place",{"kind":kind,"x":9,"y":2,"dir":3}).is_empty():
			do(game,"assign",{"fixture":s.next_fixture-1,"product":focus*10+1})
	# Two small flexible bays have the same capital cost in the fixed and adaptive comparisons.
	if s.star>=2 and s.cash>42000:
		for bay in [[9,9,4,20],[8,9,6,10]]:
			if not s.fixtures.any(func(f):return f.x==bay[1] and f.y==bay[2]):
				if do(game,"place",{"kind":bay[0],"x":bay[1],"y":bay[2],"dir":3}).is_empty():do(game,"assign",{"fixture":s.next_fixture-1,"product":bay[3]})
	if style!="fixed_plan":plan_assortment(game,focus)
	var active=s.fixtures.filter(func(f):return f.product>=0).map(func(f):return f.product)
	for p in s.targets.keys():
		if not active.has(int(p)) and s.targets[p]!=0:do(game,"target",{"product":int(p),"amount":0})
	for f in s.fixtures:
		if f.product<0:continue
		var p=f.product
		var mean=0.0;var reports=s.reports.slice(maxi(0,s.reports.size()-3))
		for r in reports:mean+=r.product_sales.get(p,0)
		mean=mean/maxi(reports.size(),1)
		var target=12 if reports.is_empty() else clampi(ceili(mean*1.3)+3,4,60)
		if game.products[p].life<=1440:target=mini(target,ceili(mean*0.6)+3)
		if game.products[p].cat==focus:target+=3
		if style=="fixed_plan":target=6 if game.products[p].life<=1440 else 18
		else:
			var traffic=40.0 if reports.is_empty() else reports[-1].visitors
			for day in [s.day,s.day+1]:
				var forecast=game.event_for(day)
				var matching=forecast.needs.filter(func(group):return Stories.product_matches(p,group)).size()
				if matching>0:
					var expected=traffic*forecast.share*matching/float(forecast.needs.size())
					target=maxi(target,ceili(expected*(0.45 if game.products[p].life<=1440 else 0.65))+3)
		if style!="fixed_plan" and game.products[p].life<=1440:
			var spoiled=0.0
			for report in reports:spoiled+=report.get("waste_products",{}).get(p,{}).get("amount",0)
			target=maxi(4,target-ceili(spoiled/maxi(reports.size(),1)*0.7))
		if int(s.targets.get(p,0))!=target:do(game,"target",{"product":p,"amount":target})
		var price=1
		if style=="morning" and p==0:price=0
		if style!="fixed_plan" and game.stock_expiring(p)>maxf(2,mean*0.25):price=0
		if int(s.prices.get(p,1))!=price:do(game,"price",{"product":p,"level":price})
	if s.star>=4 and s.review.get("status","") not in ["active","passed"] and s.day<=42:do(game,"review")

func plan_assortment(game,focus:int):
	var s=game.s;var demands=[]
	for day in [s.day,s.day+1]:
		for group in game.event_for(day).needs:
			if not demands.has(group):demands.append(group)
	for group in demands:
		if s.fixtures.any(func(f):return f.product>=0 and Stories.product_matches(f.product,group)):continue
		var candidates=game.products.filter(func(p):return p.unlock<=s.star and Stories.product_matches(p.id,group))
		candidates.sort_custom(func(a,b):return (a.cost-(50 if a.cat==focus else 0))<(b.cost-(50 if b.cat==focus else 0)))
		var choice={};var score=100000
		for p in candidates:
			for f in s.fixtures:
				if not game.compatible(f,p.id):continue
				var protected=false
				for other in demands:
					if f.product>=0 and Stories.product_matches(f.product,other) and not s.fixtures.any(func(ff):return ff.id!=f.id and ff.product>=0 and Stories.product_matches(ff.product,other)):protected=true;break
				if protected:continue
				var cost=p.cost+(80 if f.id<8 else 0)+(40 if f.product>=0 and game.products[f.product].cat==focus else 0)-(30 if p.cat==focus else 0)
				if cost<score:score=cost;choice={"f":f,"p":p.id}
		if not choice.is_empty():
			if do(game,"assign",{"fixture":choice.f.id,"product":choice.p}).is_empty() and game.total_stock(choice.p)<6:do(game,"order",{"product":choice.p,"amount":6})
