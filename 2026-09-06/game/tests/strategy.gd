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
	if s.day>=29 and s.day<=42 and s.get("winter_plan","").is_empty():do(game,"winter_plan",{"value":"treats" if style=="sweets" else ("night" if style=="night" else "breakfast")})
	if s.day>1 and not s.auto:do(game,"auto",{"enabled":true})
	var limit=40000 if s.star>=4 else 24000
	if s.auto_limit!=limit:do(game,"auto_limit",{"amount":limit})
	# Invest after the customer base has grown, while leaving working capital.
	if s.star>=1 and not s.staff[2].hired and s.cash>24000:
		do(game,"hire",{"id":2});do(game,"shift",{"id":2,"slot":0});do(game,"shift",{"id":2,"slot":1})
	if s.star>=2 and not s.staff[3].hired and s.cash>28000:
		do(game,"hire",{"id":3});do(game,"shift",{"id":3,"slot":2});do(game,"shift",{"id":3,"slot":3})
	# A mature store needs stock coverage while both tills are busy.
	if s.star>=4 and s.cash>40000:
		for hire in [[4,0,1],[5,2,3]]:
			if not s.staff[hire[0]].hired:
				do(game,"hire",{"id":hire[0]});do(game,"shift",{"id":hire[0],"slot":hire[1]});do(game,"shift",{"id":hire[0],"slot":hire[2]});do(game,"priority",{"id":hire[0],"value":"stock"})
	if s.star>=4 and s.cash>50000:
		for f in s.fixtures.duplicate():
			if f.kind==2:
				var spot={"kind":10,"x":f.x,"y":f.y,"dir":f.dir}
				if do(game,"remove",{"fixture":f.id}).is_empty():do(game,"place",spot)
		# The entrance-side hot case already uses the old third-till approach.
		# Give the extra counter its own queue on the expanded floor.
		if s.tier>0 and not s.fixtures.any(func(f):return f.x==12 and f.y==5):do(game,"place",{"kind":10,"x":12,"y":5,"dir":1})
		for hire in [[6,0,1],[7,2,3]]:
			if not s.staff[hire[0]].hired:
				do(game,"hire",{"id":hire[0]});do(game,"shift",{"id":hire[0],"slot":hire[1]});do(game,"shift",{"id":hire[0],"slot":hire[2]});do(game,"priority",{"id":hire[0],"value":"register"})
	if s.star>=2 and s.cash>32000 and s.fixtures.filter(func(f):return f.kind==10).is_empty():
		do(game,"place",{"kind":10,"x":4,"y":8,"dir":0})
	if s.star>=1 and s.tier==0 and s.cash>50000:do(game,"expand")
	if s.star>=2 and s.cash>32000 and not s.reports.is_empty() and (style=="fixed_plan" or s.reports[-1].miss.get("行列",0)>3):
		for w in s.staff:
			if w.hired and not game.working(w) and w.training<2:do(game,"train",{"id":w.id})
	# The theme changes the actual assortment, shelf geography and financial risk.
	var focus=0 if style=="morning" else (4 if style=="sweets" else (6 if style=="night" else 2))
	if s.star>=1 and s.cash>28000 and s.fixtures.size()<11:
		var kind=9 if focus in [2,4] else (11 if focus==6 else 8)
		if do(game,"place",{"kind":kind,"x":9,"y":2,"dir":3}).is_empty():
			do(game,"assign",{"fixture":s.next_fixture-1,"product":43 if focus==4 else focus*10+1})
	# Two small flexible bays have the same capital cost in the fixed and adaptive comparisons.
	if s.star>=2 and s.cash>42000:
		for bay in [[9,9,4,20],[8,9,6,10]]:
			if not s.fixtures.any(func(f):return f.x==bay[1] and f.y==bay[2]):
				if do(game,"place",{"kind":bay[0],"x":bay[1],"y":bay[2],"dir":3}).is_empty():do(game,"assign",{"fixture":s.next_fixture-1,"product":bay[3]})
	if s.day>=43:prepare_promise(game)
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
					target=maxi(target,ceili(expected*(0.9 if forecast.id.begins_with("winter_") else (0.45 if game.products[p].life<=1440 else 0.65)))+3)
		if style!="fixed_plan" and game.products[p].life<=1440:
			var spoiled=0.0
			for report in reports:spoiled+=report.get("waste_products",{}).get(p,{}).get("amount",0)
			target=maxi(4,target-ceili(spoiled/maxi(reports.size(),1)*0.7))
		if s.day>=43 and style!="fixed_plan":target+=8*maxi(0,s.fixtures.filter(func(bay):return bay.product==p).size()-1)
		if int(s.targets.get(p,0))!=target:do(game,"target",{"product":p,"amount":target})
		var price=1
		# Once customers are being turned away, stop the introductory rice discount.
		# Extra demand has become a capacity cost, even while the shop is profitable.
		if style=="morning" and p==0 and not s.reports.any(func(report):return report.miss.get("満員",0)>0):price=0
		if style!="fixed_plan" and game.stock_expiring(p)>maxf(2,mean*0.25):price=0
		if int(s.prices.get(p,1))!=price:do(game,"price",{"product":p,"level":price})
	if s.star>=4 and s.review.get("status","") not in ["active","passed"] and s.day<=42:do(game,"review")

func plan_assortment(game,focus:int):
	var s=game.s;var demands=[];var minimum_life={}
	for day in [s.day,s.day+1]:
		for group in game.event_for(day).needs:
			if not demands.has(group):demands.append(group)
			var hour=int(game.event_for(day).get("hour",14))
			var since_delivery=(hour+24-14) if hour<6 else (hour-6 if hour<14 else hour-14)
			minimum_life[group]=maxi(minimum_life.get(group,0),since_delivery*60+120)
	for group in demands:
		if s.fixtures.any(func(f):return f.product>=0 and Stories.product_matches(f.product,group) and game.products[f.product].life>minimum_life[group]):continue
		var candidates=game.products.filter(func(p):return p.unlock<=s.star and Stories.product_matches(p.id,group) and p.life>minimum_life[group])
		candidates.sort_custom(func(a,b):return (a.cost-(50 if a.cat==focus else 0))<(b.cost-(50 if b.cat==focus else 0)))
		var choice={};var score=100000
		for p in candidates:
			for f in s.fixtures:
				if not game.compatible(f,p.id) or f.y==11:continue
				var protected=false
				for other in demands:
					if f.product>=0 and Stories.product_matches(f.product,other) and not s.fixtures.any(func(ff):return ff.id!=f.id and ff.product>=0 and Stories.product_matches(ff.product,other)):protected=true;break
				if protected:continue
				var cost=p.cost+(80 if f.id<8 else 0)+(40 if f.product>=0 and game.products[f.product].cat==focus else 0)-(30 if p.cat==focus else 0)
				if cost<score:score=cost;choice={"f":f,"p":p.id}
		if not choice.is_empty():
			if do(game,"assign",{"fixture":choice.f.id,"product":choice.p}).is_empty() and game.total_stock(choice.p)<6:do(game,"order",{"product":choice.p,"amount":6})

func prepare_promise(game):
	var plan=game.s.get("winter_plan","")
	if not game.Campaign.PLANS.has(plan):return
	for i in 3:
		var x=5+i*4
		if game.s.fixtures.any(func(f):return f.x==x and f.y==11):continue
		var group=game.Campaign.PLANS[plan].needs[i]
		var candidates=game.products.filter(func(p):return p.unlock<=game.s.star and Stories.product_matches(p.id,group))
		# Keep a long-lived option for the night instead of relying on a 12-hour hot case.
		candidates.sort_custom(func(a,b):return a.cost+(150 if a.life<=1440 else 0)<b.cost+(150 if b.life<=1440 else 0))
		var p=candidates[0];var kind=14 if p.storage=="frozen" else (17 if p.storage=="chilled" else (11 if p.storage=="hot" else 16))
		if game.s.cash-game.equipment[kind].cost<game.review_metrics().reserve:continue
		# Face the dedicated bays toward the open rear aisle, away from the tills.
		if do(game,"place",{"kind":kind,"x":x,"y":11,"dir":0}).is_empty():do(game,"assign",{"fixture":game.s.next_fixture-1,"product":p.id})
