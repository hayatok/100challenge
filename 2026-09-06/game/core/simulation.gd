extends RefCounted
const Campaign=preload("res://core/campaign.gd")
const City=preload("res://core/city.gd")
const Goods=preload("res://core/merchandise.gd")
const Stories=preload("res://core/resident_stories.gd")
const Catalog=preload("res://core/catalog.gd")
const Nav=preload("res://core/navigation.gd")
var products=Catalog.products()
var equipment=Catalog.equipment()
var s:Dictionary={}
var rng=RandomNumberGenerator.new()

func _init(world_seed:int=20260906):
	reset(world_seed)

func reset(world_seed:int):
	rng.seed=world_seed
	s={"layout_version":2,"storage_version":1,"seed":world_seed,"rng":rng.state,"tick":0,"day":1,"cash":42000,"tier":0,"star":0,"residents":Catalog.residents(world_seed),"staff":Catalog.staff(),"fixtures":[],"warehouse":[],"orders":[],"visits":[],"next_visit":0,"next_fixture":0,"prices":{},"targets":{},"auto":false,"auto_limit":8000,"reports":[],"today":new_report(1),"logs":[],"effects":[],"schedule":[],"clean":100.0,"loan":false,"debt":0,"due":0,"review":{},"pending_review":false,"winter_plan":"","won":false,"result":"","practice":false,"tutorial":0,"favorites":[],"streak":0,"seasons_profit":[],"event_pass":false,"elapsed":0,"episode_events":[]}
	for cat in 8:
		var kind=[0,0,1,0,1,0,3,4][cat]
		var layout=[Vector3i(5,3,3),Vector3i(6,3,1),Vector3i(5,0,0),Vector3i(5,5,3),Vector3i(6,0,0),Vector3i(6,5,1),Vector3i(2,9,3),Vector3i(11,4,3)]
		var cell:Vector3i=layout[cat]
		var f=make_fixture(kind,cell.x,cell.y,cell.z)
		f.product=cat*10
		f.lots=[lot(cat*10,12)]
		s.fixtures.append(f)
		s.warehouse.append(lot(cat*10,6))
		s.targets[cat*10]=18
	var till=make_fixture(2,2,7,3);s.fixtures.append(till)
	new_schedule()
	s.rng=rng.state
	log_message("朝6時。小さな店の、大きな一日が始まります。")

func new_report(day:int) -> Dictionary:
	return {"day":day,"sales":0,"cogs":0,"waste":0,"fixed":0,"wages":0,"work_minutes":{},"orders":0,"investment":0,"other":0,"profit":0,"visitors":0,"buyers":0,"miss":{},"product_sales":{},"hours":{},"returners":[],"cash_open":s.get("cash",42000),"event":event_for(day).id,"season":season(day),"need_visitors":0,"needs_served":0,"completed":0,"purpose_completed":0,"event_results":{},"unmet_needs":{},"lost_visits":[],"waste_products":{},"winter_results":{}}

func season(day:int=-1) -> int:
	return ((s.day if day<0 else day)-1)/14%4
func minute() -> int:
	return (s.tick+360)%1440
func shift() -> int:
	return s.tick/360%4
func fixed_cost() -> int:
	return 1500+s.tier*1100+int(s.fixtures.size()*35)
func roster_size() -> int:
	return mini(120,40+s.star*20)
func counts(lots:Array, product:int=-1) -> int:
	var n=0
	for l in lots:
		if product<0 or l.product==product: n+=l.amount
	return n
func volume(lots:Array) -> int:
	var n=0
	for l in lots: n+=l.amount*products[l.product].size
	return n
func warehouse_capacity() -> int:
	return 220+s.tier*180
func total_stock(product:int) -> int:
	var n=counts(s.warehouse,product)
	for f in s.fixtures: n+=counts(f.lots,product)
	for w in s.staff:n+=counts(w.carry,product)
	for o in s.orders:
		if o.product==product:n+=o.amount
	return n
func stock_expiring(product:int,within:int=360) -> int:
	var lots=s.warehouse.duplicate()
	for f in s.fixtures:lots.append_array(f.lots)
	for w in s.staff:lots.append_array(w.carry)
	var result=0
	for l in lots:
		if l.product==product and l.expires<=s.tick+within:result+=l.amount
	return result
func lot(product:int,amount:int,expires:int=-1) -> Dictionary:
	return {"product":product,"amount":amount,"expires":s.get("tick",0)+products[product].life if expires<0 else expires,"cost":products[product].cost}
func selling_price(product:int) -> int:
	return roundi(products[product].price*[0.85,1.0,1.2][int(s.prices.get(product,1))])
func fixture(id:int) -> Dictionary:
	for f in s.fixtures:
		if f.id==id:return f
	return {}
func make_fixture(kind:int,x:int,y:int,dir:int) -> Dictionary:
	var id=s.next_fixture;s.next_fixture+=1
	return {"id":id,"kind":kind,"x":x,"y":y,"dir":dir,"product":-1,"lots":[],"ready":s.tick,"queue":[],"clerk":-1,"pay_timer":0}
func log_message(message:String):
	s.logs.push_front({"day":s.day,"minute":minute(),"text":message})
	if s.logs.size()>40:s.logs.resize(40)
func effect(pos:Vector2i,text:String,kind:String="good"):
	s.effects.append({"pos":pos,"text":text,"time":s.tick,"kind":kind})
	if s.effects.size()>16:s.effects.pop_front()
func miss(reason:String,product:int=-1):
	s.today.miss[reason]=s.today.miss.get(reason,0)+1
	if product>=0:
		var key="p"+str(product)
		s.today.miss[key]=s.today.miss.get(key,0)+1

func event_for(day:int) -> Dictionary:return City.event(day,s.get("winter_plan",""))
func weather_for(day:int) -> String:
	var forecast=event_for(day)
	if forecast.has("weather"):return forecast.weather
	var value=absi(s.get("seed",1)*31+day*7919)%10
	return "雨" if value<3 else ("暑い" if season(day)==1 or value==8 else "晴れ")
func new_schedule():
	s.schedule=[]
	var event=event_for(s.day)
	for i in roster_size():
		var r=s.residents[i]
		var chance=clampf(0.70+r.loyalty/250.0+(r.satisfaction-50)*0.001,0.35,0.96)
		if rng.randf()>chance:continue
		var hour=r.hour
		if s.day%7 in [6,0]:hour=(hour+2)%24
		if event.has("hour") and not City.need(s.day,i,s.seed,s.get("winter_plan","")).is_empty():hour=event.hour
		var t=(hour*60-360+1440)%1440+rng.randi_range(0,80)
		s.schedule.append({"at":s.tick+mini(t,1439),"rid":i,"wait":0})
	s.schedule.sort_custom(func(a,b):return a.at<b.at)

func command(name:String,args:Dictionary={}) -> String:
	if name in ["shift","priority","train"]:
		if int(args.get("id",-1)) not in range(s.staff.size()):return "スタッフを選んでください。"
		if not s.staff[int(args.id)].hired:return "先に採用してください。"
	if name=="favorite" and int(args.get("id",-1)) not in range(s.residents.size()):return "住人を選んでください。"
	if name in ["place","move"] and int(args.get("dir",0)) not in range(4):return "設備の向きを選んでください。"
	match name:
		"order":return order(int(args.product),int(args.amount))
		"price":
			if int(args.product) not in range(80) or int(args.level) not in range(3):return "価格を選んでください。"
			s.prices[int(args.product)]=int(args.level)
		"target":
			if int(args.product) not in range(80):return "商品が見つかりません。"
			s.targets[int(args.product)]=clampi(int(args.amount),0,100)
		"auto":
			if s.reports.is_empty():return "最初の日次レポートで自動発注が解放されます。"
			s.auto=bool(args.enabled)
		"auto_limit":s.auto_limit=clampi(int(args.amount),1000,50000)
		"assign":
			var f=fixture(int(args.fixture));var p=int(args.product)
			if f.is_empty() or p not in range(80):return "棚と商品を選んでください。"
			if equipment[f.kind].capacity<=0:return "この設備には商品を置けません。"
			if products[p].unlock>s.star:return "まだ仕入れ先が解放されていません。"
			if not compatible(f,p):return equipment[f.kind].name+"は「"+Catalog.equipment_use(f.kind)+"」。"+products[p].name+"は"+Catalog.storage_label(products[p].storage)+"の商品です。"
			if volume(f.lots)>0 and volume(s.warehouse)+volume(f.lots)>warehouse_capacity():return "入れ替える在庫を置く倉庫の空きがありません。"
			s.warehouse.append_array(f.lots);f.lots=[];f.product=p
			s.tutorial=maxi(s.tutorial,1)
		"place","move":
			var kind=int(args.get("kind",0));var moving=fixture(int(args.get("fixture",-1)))
			if name=="move":
				if moving.is_empty():return "設備を選んでください。"
				kind=moving.kind
			if kind not in range(20) or equipment[kind].unlock>s.star:return "この設備はまだ解放されていません。"
			if name=="place" and s.cash<equipment[kind].cost:return "設備を買う資金が足りません。"
			var draft=s.fixtures.duplicate(true)
			if name=="move":draft= draft.filter(func(f):return f.id!=moving.id)
			var candidate={"id":s.next_fixture,"kind":kind,"x":int(args.x),"y":int(args.y),"dir":int(args.get("dir",0)),"product":-1,"lots":[],"queue":[],"ready":s.tick+15,"clerk":-1,"pay_timer":0}
			if name=="move":candidate=moving.duplicate(true);candidate.x=int(args.x);candidate.y=int(args.y);candidate.dir=int(args.get("dir",moving.dir));candidate.ready=s.tick+15
			draft.append(candidate)
			var positions=[]
			for v in s.visits:positions.append(v.pos)
			for w in s.staff:
				if w.hired:positions.append(w.pos)
			var error=Nav.validate(draft,s.tier,positions,not s.get("layout_needs_review",false))
			if not error.is_empty():return error
			if name=="place":s.cash-=equipment[kind].cost;s.today.investment+=equipment[kind].cost;s.next_fixture+=1
			s.fixtures=draft
			s.layout_needs_review=not Nav.validate(draft,s.tier).is_empty()
			repath_all()
			log_message(equipment[kind].name+"を"+("設置" if name=="place" else "移設")+"。15分後に使えます。")
		"remove":
			var f=fixture(int(args.fixture))
			if f.is_empty():return "設備を選んでください。"
			if equipment[f.kind].kind=="register" and s.fixtures.filter(func(a):return equipment[a.kind].kind=="register").size()<=1:return "最後のレジは残してください。"
			if volume(s.warehouse)+volume(f.lots)>warehouse_capacity():return "商品を戻す倉庫の空きがありません。"
			s.warehouse.append_array(f.lots)
			s.cash+=int(equipment[f.kind].cost/2);s.today.other+=int(equipment[f.kind].cost/2)
			s.fixtures.erase(f);repath_all()
		"expand":
			if s.tier>=2:return "増床は最大です。"
			if s.star<s.tier+1:return "次の増床には星"+str(s.tier+1)+"が必要です。"
			var cost=[26000,60000][s.tier]
			if s.cash<cost:return "増床資金が足りません。"
			s.cash-=cost;s.today.investment+=cost;s.tier+=1
			for v in s.visits:
				if v.state=="leaving":v.path=Nav.path(v.pos,exit_point(v),s.fixtures,s.tier)
			log_message("新しい床、新しい悩み。店が広くなりました！")
		"hire":
			var id=int(args.id)
			if id<=0 or id>=s.staff.size():return "スタッフを選んでください。"
			if s.staff[id].hired:return "すでに働いています。"
			if s.cash<2000:return "採用費2,000円が必要です。"
			s.cash-=2000;s.today.investment+=2000;s.staff[id].hired=true
			log_message(s.staff[id].name+"が仲間入り。シフトを設定しましょう。")
		"shift":
			var w=s.staff[int(args.id)];var slot=int(args.slot)
			if slot not in range(4):return "勤務時間を選んでください。"
			if not w.shifts[slot] and w.shifts.count(true)>=2:return "1人の勤務は2枠まで。休息も仕事のうち。"
			w.shifts[slot]=not w.shifts[slot];s.tutorial=maxi(s.tutorial,4)
		"priority":
			if args.value not in ["auto","register","stock","clean"]:return "担当を選んでください。"
			s.staff[int(args.id)].priority=args.value
		"train":
			var w=s.staff[int(args.id)]
			if not w.hired or w.training>=3:return "教育は最大3回です。"
			if w.shifts[shift()]:return "勤務していない時間に教育できます。"
			var cost=1800*(w.training+1)
			if s.cash<cost:return "教育費が足りません。"
			s.cash-=cost;s.today.investment+=cost;w.training+=1;w.register+=0.18;w.stock+=0.18;w.service+=0.15
			log_message(w.name+"の教育完了。レジも補充も一歩成長。")
		"favorite":s.residents[int(args.id)].favorite=not s.residents[int(args.id)].favorite
		"winter_plan":
			if s.day<29 or s.day>42:return "冬の約束は29〜42日目に選べます。冬が始まると変更できません。"
			var plan=str(args.get("value",""))
			if not Campaign.PLANS.has(plan):return "街に届ける約束を選んでください。"
			s.winter_plan=plan;log_message("冬の約束："+Campaign.PLANS[plan].name+"。45・49・53・56日目にお待ちしています。")
		"review":
			if s.star<4:return "四つ星に到達すると最終審査を受けられます。"
			if s.day>42 and not s.practice:return "期限内の14日間を確保できません。"
			if s.review.get("status","") in ["active","passed"] or s.pending_review:return "審査はすでに予約・進行中です。"
			s.pending_review=true;log_message("明朝から14日間、五つ星審査に挑戦します。")
		"loan":
			if s.loan:return "追加の救済融資はありません。"
			if s.cash>15000:return "救済融資は所持金15,000円以下のときに使えます。"
			s.loan=true;s.cash+=20000;s.today.other+=20000;s.debt=22000;s.due=s.day+7;s.result=""
			log_message("救済融資20,000円。7日後の返済は22,000円。立て直しましょう。")
		"continue":s.result="";s.practice=true
		_:return "操作が見つかりません。"
	if s.result=="debt" and s.cash>=0:s.result=""
	return ""

func compatible(f:Dictionary,p:int) -> bool:
	return Catalog.accepts(f.kind,products[p])

func restore_storage_state() -> String:
	if s.get("storage_version",0)>=1:return ""
	var changed=[]
	for f in s.fixtures:
		if f.product>=0 and not compatible(f,f.product):
			changed.append(f.id);s.warehouse.append_array(f.lots);f.lots=[];f.product=-1
	s.storage_version=1
	if changed.is_empty():return ""
	# Migration must preserve every lot even if the warehouse is temporarily over capacity.
	# Normal replenishment clears that overflow; no expiry dates or money are changed.
	for w in s.staff:s.warehouse.append_array(w.carry);w.carry=[]
	repath_all()
	return "保管条件を更新しました。対応しない売り場"+str(changed.size())+"か所の商品を、期限を保って倉庫へ戻しました。対応する棚に並べ直せます。"
func order(p:int,amount:int) -> String:
	if p not in range(80) or amount<=0 or amount>100:return "発注数は1〜100個です。"
	if products[p].unlock>s.star:return "この商品はまだ解放されていません。"
	var incoming=0
	for o in s.orders:incoming+=o.amount*products[o.product].size
	if volume(s.warehouse)+incoming+amount*products[p].size>warehouse_capacity():return "倉庫と発注済み在庫がいっぱいです。"
	var cost=products[p].cost*amount
	if cost>s.cash:return "仕入れ資金が足りません。"
	var delivery=City.delivery_tick(s.tick)
	s.orders.append({"product":p,"amount":amount,"due":delivery,"cost":cost})
	s.cash-=cost;s.today.orders+=cost;s.tutorial=maxi(s.tutorial,2)
	return ""

func take(lots:Array,p:int,amount:int) -> Array:
	lots.sort_custom(func(a,b):return a.expires<b.expires)
	var picked=[];var remain=amount
	for l in lots:
		if l.product!=p or remain<=0:continue
		var n=mini(remain,l.amount)
		picked.append({"product":p,"amount":n,"expires":l.expires,"cost":l.cost});l.amount-=n;remain-=n
	for i in range(lots.size()-1,-1,-1):
		if lots[i].amount<=0:lots.remove_at(i)
	return picked
func waste(lots:Array):
	for l in lots:
		s.today.waste+=l.amount*l.cost
		if not s.today.has("waste_products"):s.today.waste_products={}
		var entry=s.today.waste_products.get(l.product,{"amount":0,"cost":0})
		entry.amount+=l.amount;entry.cost+=l.amount*l.cost;s.today.waste_products[l.product]=entry
func expire(lots:Array):
	for i in range(lots.size()-1,-1,-1):
		if lots[i].expires<=s.tick:waste([lots[i]]);lots.remove_at(i)
func return_goods(lots:Array):
	for l in lots:
		if l.expires<=s.tick or volume(s.warehouse)+l.amount*products[l.product].size>warehouse_capacity():waste([l])
		else:s.warehouse.append(l)
func repath_all():
	for f in s.fixtures:f.queue=[];f.clerk=-1
	for v in s.visits:
		v.erase("wait_spot")
		v.path=[];v.target=-1
		if v.state=="leaving":v.path=Nav.path(v.pos,exit_point(v),s.fixtures,s.tier)
		elif v.pos.x<0:v.state="entering";v.path=Nav.path(v.pos,Nav.DOOR,s.fixtures,s.tier)
		else:v.state="choose" if v.basket.is_empty() else "checkout"
	for w in s.staff:
		return_goods(w.carry);w.carry=[];w.path=[];w.task="idle";w.target=-1

func restore_spatial_state() -> String:
	if s.get("layout_version",0)>=2:return ""
	# Correct only the unchanged factory layout; preserve every lot and account.
	var factory=true
	for i in 9:
		var f=fixture(i)
		var old=Vector3i(2,7,3) if i==8 else Vector3i(3+(i%3)*3,3+(i/3)*2,0)
		if f.is_empty() or Vector3i(f.x,f.y,f.dir)!=old:factory=false;break
	var corrected=false
	if factory:
		var draft=s.fixtures.duplicate(true)
		var layout=[Vector3i(5,3,3),Vector3i(6,3,1),Vector3i(5,0,0),Vector3i(5,5,3),Vector3i(6,0,0),Vector3i(6,5,1),Vector3i(2,9,3),Vector3i(11,4,3),Vector3i(2,7,3)]
		for f in draft:
			if f.id<9:f.x=layout[f.id].x;f.y=layout[f.id].y;f.dir=layout[f.id].z
		if Nav.validate(draft,s.tier).is_empty():s.fixtures=draft;corrected=true
	s.layout_version=2
	# Saved actors are resumed on a free adjacent floor cell if an old fixture moved under them.
	var blocked=Nav.obstacles(s.fixtures,false)
	for actor in s.visits+s.staff:
		if blocked.has(actor.pos):
			for d in Nav.DIRS:
				var next:Vector2i=actor.pos+d
				if not blocked.has(next) and Nav.reachable(next,Nav.DOOR,s.fixtures,s.tier,true):actor.pos=next;break
		actor.prev=actor.pos
	repath_all()
	s.layout_needs_review=not Nav.validate(s.fixtures,s.tier).is_empty()
	if s.layout_needs_review:return "以前の配置を維持しました。建設からレジ裏と待機列を空けるよう移設してください。"
	return "旧版の初期配置と動線を修正しました。在庫と資金はそのままです。" if corrected else ""

func exit_point(v:Dictionary) -> Vector2i:
	return Nav.street_end(s.tier,v.rid%2==0)

func step(minutes:int=1):
	for _i in minutes:
		if not s.result.is_empty():break
		rng.state=s.rng
		s.tick+=1
		if s.tick%1440==0:finish_day()
		if not s.result.is_empty():s.rng=rng.state;break
		for i in range(s.orders.size()-1,-1,-1):
			var o=s.orders[i]
			if o.due<=s.tick:
				s.warehouse.append(lot(o.product,o.amount));s.orders.remove_at(i)
				effect(Nav.DEPOT,"納品 +"+str(o.amount),"stock")
		expire(s.warehouse)
		for f in s.fixtures:expire(f.lots)
		for w in s.staff:expire(w.carry)
		if s.tick%30==0:
			if s.auto and s.today.orders<s.auto_limit:auto_order()
		for v in s.visits:v.prev=v.pos
		for w in s.staff:w.prev=w.pos
		spawn_due()
		update_staff()
		update_visits()
		update_registers()
		s.clean=maxf(0,s.clean-0.003*s.visits.size())
		s.effects=s.effects.filter(func(e):return s.tick-e.time<10)
		s.rng=rng.state

func auto_order():
	for p in s.targets:
		var amount=mini(12,int(s.targets[p])-total_stock(int(p)))
		if amount<=0:continue
		var cost=amount*products[int(p)].cost
		if s.today.orders+cost>s.auto_limit or s.cash-cost<fixed_cost()*2:continue
		order(int(p),amount)

func spawn_due():
	for i in range(s.schedule.size()-1,-1,-1):
		var due=s.schedule[i]
		if due.at>s.tick:continue
		if s.visits.filter(func(v):return v.state!="leaving").size()>=40:
			due.wait+=1
			if due.wait>30:
				miss("満員");s.today.visitors+=1
				var need=City.need(s.day,due.rid,s.seed,s.get("winter_plan",""))
				record_visit_outcome({"need":need,"event_id":event_for(s.day).id},false)
				if not need.is_empty():
					s.today.need_visitors=s.today.get("need_visitors",0)+1
					s.today.unmet_needs[need]=s.today.unmet_needs.get(need,0)+1
				if s.today.lost_visits.size()<12:s.today.lost_visits.append({"rid":due.rid,"need":need,"reason":"満員","minute":minute()})
				s.schedule.remove_at(i)
			continue
		var spawn=Nav.street_end(s.tier,due.rid%2!=0)
		if s.visits.any(func(v):return v.pos==spawn):continue
		var r=s.residents[due.rid];var event=event_for(s.day)
		var goal=r.fav
		if minute()<600 and r.id%3==0:goal=0
		if not event.cats.is_empty() and rng.randf()<0.45:goal=event.cats[rng.randi_range(0,event.cats.size()-1)]
		if weather_for(s.day)=="暑い" and rng.randf()<0.25:goal=2
		if season()==3 and rng.randf()<0.25:goal=6
		if season()==0 and rng.randf()<0.1:goal=1
		if season()==2 and rng.randf()<0.15:goal=4
		var budget=roundi(r.budget*rng.randf_range(0.8,1.15))
		budget=mini(budget,Stories.request(r).get("budget",budget))
		var v={"id":s.next_visit,"rid":r.id,"pos":spawn,"prev":spawn,"path":Nav.path(spawn,Nav.DOOR,s.fixtures,s.tier),"state":"entering","target":-1,"basket":[],"spent":0,"budget":budget,"goal":goal,"wait":0,"timer":0,"steps":0,"attempts":0,"wanted":-1,"mood":"今日は何にしよう","since":s.tick,"bought":false,"dir":0,"need":City.need(s.day,r.id,s.seed,s.get("winter_plan","")),"failure_reason":"","event_id":event.id}
		s.next_visit+=1;s.visits.append(v);s.schedule.remove_at(i);s.today.visitors+=1;r.visits+=1
		if not v.need.is_empty():
			s.today.need_visitors=s.today.get("need_visitors",0)+1;v.mood=need_name(v.need)+"を探しています"
		if r.favorite:log_message(r.name+"さんが来店しました。")

func move_actor(a:Dictionary) -> bool:
	if a.path.is_empty():return true
	var next:Vector2i=a.path[0]
	# A saved route may predate the sidewalk rule. Replan without moving the person.
	if not Nav.connected(a.pos,next):
		a.path=Nav.path(a.pos,a.path[-1],s.fixtures,s.tier,a.has("task"))
		if a.path.is_empty():return false
		next=a.path[0]
	if a.has("task") and a.path.size()==1 and s.visits.any(func(v):return v.pos==next):return false
	if a.get("state","")=="entering" and a.path.size()==1 and s.visits.any(func(v):return v!=a and v.pos==next):return false
	var blocked={}
	for v in s.visits:
		if v!=a and (v.state in ["browsing","browse_queue","queue","paying"] or (v.state=="choose" and v.get("wait_spot",Vector2i(-99,-99))==v.pos)):blocked[v.pos]=true
	for w in s.staff:
		if w!=a and working(w) and w.task in ["register","stock"] and w.path.is_empty():blocked[w.pos]=true
	if blocked.has(next):
		var destination:Vector2i=a.path[-1]
		if blocked.has(destination):return false
		var detour=Nav.path(a.pos,destination,s.fixtures,s.tier,a.has("task"),blocked)
		if detour.is_empty():return false
		a.path=detour;next=a.path[0]
	a.dir=Nav.DIRS.find(next-a.pos)
	a.pos=next;a.path.pop_front()
	return a.path.is_empty()

func need_name(group:String) -> String:
	var words=[]
	for tag in group.split(" "):
		words.append(Goods.TAG_LABELS.get(tag,tag))
	return "・".join(words)
func browse_line(fixture_id:int) -> Array:
	var head=Nav.access(fixture(fixture_id))
	var line=s.visits.filter(func(v):return v.target==fixture_id and (v.state in ["walking","browse_queue","browsing"] or (v.state=="choose" and v.pos==head)))
	line.sort_custom(func(a,b):return a.get("browse_ticket",a.id)<b.get("browse_ticket",b.id))
	return line

func shelf_route(v:Dictionary,destination:Vector2i,line:Array,cells:Array) -> Array:
	var reserved={}
	for i in mini(line.size(),cells.size()):
		if line[i]!=v:reserved[cells[i]]=true
	return Nav.path(v.pos,destination,s.fixtures,s.tier,false,reserved)

func wait_for_shelf(v:Dictionary):
	# A full shelf is a reason to wait in the shop, not to pile up on the doorway.
	if not v.has("wait_spot"):
		var blocked=Nav.obstacles(s.fixtures,false)
		for f in s.fixtures:
			blocked[Nav.access(f)]=true
			for cell in (Nav.queue_cells(f,s.fixtures,s.tier) if Nav.is_register(f) else Nav.browse_cells(f,s.fixtures,s.tier)):blocked[cell]=true
		for other in s.visits:
			if other!=v:blocked[other.pos]=true;blocked[other.get("wait_spot",other.pos)]=true
		for w in s.staff:
			if w.hired:blocked[w.pos]=true
		var spots=[];var dims=Nav.dimensions(s.tier)
		for x in range(2,dims.x):
			for y in range(3,dims.y):
				var at=Vector2i(x,y)
				if not blocked.has(at):spots.append(at)
		spots.sort_custom(func(a,b):return Vector2(a-v.pos).length_squared()<Vector2(b-v.pos).length_squared())
		for at in spots:
			var path=Nav.path(v.pos,at,s.fixtures,s.tier,false,blocked)
			if at==v.pos or not path.is_empty():v.wait_spot=at;v.path=path;break
	if v.has("wait_spot") and v.pos!=v.wait_spot:move_actor(v)
	v.mood="先の人が選ぶのを待とう"

func move_to_shelf(v:Dictionary):
	var f=fixture(v.target)
	if f.is_empty() or f.product!=v.wanted or f.ready>s.tick:v.state="choose";return
	var line=browse_line(f.id);var index=line.find(v);var cells=Nav.browse_cells(f,s.fixtures,s.tier)
	if index<0 or index>=cells.size():v.state="choose";return
	var destination:Vector2i=cells[index];v.browse_slot=destination
	if v.pos!=destination:
		var reserved={}
		for i in mini(line.size(),cells.size()):
			if line[i]!=v:reserved[cells[i]]=true
		if v.path.is_empty() or v.path[-1]!=destination or v.path.any(func(p):return reserved.has(p)):v.path=shelf_route(v,destination,line,cells)
		# The next shopper takes the place only after its previous occupant has left.
		var occupied=s.visits.any(func(other):return other.id!=v.id and other.pos==destination)
		occupied=occupied or s.staff.any(func(w):return working(w) and w.pos==destination)
		# Resolve an old crossed approach by stepping aside, never swapping occupied slots.
		if occupied and reserved.has(v.pos):
			for direction in Nav.DIRS:
				var at:Vector2i=v.pos+direction
				if cells.has(at) or Nav.obstacles(s.fixtures,false).has(at) or not Nav.inside(at,Nav.dimensions(s.tier)) or not Nav.connected(v.pos,at):continue
				if s.visits.any(func(other):return other!=v and (other.pos==at or other.get("wait_spot",other.pos)==at)):continue
				if s.staff.any(func(w):return w.hired and w.pos==at):continue
				v.path=[at];move_actor(v);v.state="walking";return
		if not (v.path.size()==1 and occupied):move_actor(v)
	if v.pos!=destination:return
	if index==0:v.state="browsing";v.timer=2;v.dir=Nav.DIRS.find(Vector2i(f.x,f.y)-v.pos)
	else:v.state="browse_queue";v.mood="次は、わたしの番。"

func choose(v:Dictionary):
	var r=s.residents[v.rid];var best={};var best_score=-1000.0
	var best_wish=false
	var offered=0;var stocked=0;var affordable=0;var reachable=0;var busy=false
	var need=v.get("need","");var basket_ids=v.basket.map(func(l):return int(l.product))
	var seeking=not need.is_empty() and not Stories.basket_has(basket_ids,need)
	for f in s.fixtures:
		var p=int(f.product)
		if p<0 or f.ready>s.tick:continue
		if seeking and not Stories.product_matches(p,need):continue
		offered+=1
		if counts(f.lots,p)<=0:continue
		stocked+=1
		var price=selling_price(p)
		if price+v.spent>v.budget:continue
		affordable+=1
		var line=browse_line(f.id);var cells=Nav.browse_cells(f,s.fixtures,s.tier)
		var holding=line.has(v)
		if not holding and line.size()>=cells.size():busy=true;continue
		var slot:Vector2i=cells[0] if holding else cells[line.size()]
		if s.visits.any(func(other):return other.target!=f.id and other.state in ["walking","browse_queue","browsing"] and other.get("browse_slot",other.pos)==slot):busy=true;continue
		var path=shelf_route(v,slot,line,cells)
		if path.is_empty() and v.pos!=slot:continue
		reachable+=1
		var cat=products[p].cat
		var relevance=Stories.relevance(r,p,basket_ids)
		var wish=not seeking and relevance>0
		var personal=Goods.affinity(r.id,p)+relevance
		var score=personal+r.taste[cat]*35+(40 if cat==v.goal or seeking else 0)+products[p].quality*12-price/float(r.budget)*35-path.size()*0.65+rng.randf()*8
		var premium=price/float(products[p].price)-1.0
		score-=premium*145.0*r.get("price_sensitivity",1.0)
		if v.attempts>0:score-=counts(v.basket,p)*35
		# Buy the missing part of an explicit shopping list before optional repeats.
		if (wish and not best_wish) or (wish==best_wish and score>best_score):
			best_wish=wish;best_score=score;best={"fixture":f.id,"product":p,"path":path,"slot":slot,"holding":holding}
	if best.is_empty() or best_score<25:
		if best.is_empty() and busy:wait_for_shelf(v);return
		if v.basket.is_empty():
			var reason="価格"
			if offered==0:reason="品揃え"
			elif stocked==0:reason="欠品"
			elif affordable==0:reason="予算"
			elif reachable==0:reason="通路"
			v.failure_reason=reason;miss(reason)
			v.mood=(need_name(need)+"：" if seeking else "")+{"品揃え":"探している品がない","欠品":"棚が空っぽ","予算":"予算を超えてしまう","通路":"売り場へ行けない","価格":"今日は買いたいものがないな"}[reason]
			r.last_reason=v.mood;leave(v,false)
		else:v.state="checkout"
		return
	v.erase("wait_spot")
	v.target=best.fixture;v.wanted=best.product;v.path=best.path;v.browse_slot=best.slot;v.browse_ticket=v.get("browse_ticket",v.id) if best.holding else s.tick*10000+v.id;v.state="walking";v.mood=products[best.product].name+"が気になる"

func update_visits():
	# People who have physically joined a line precede distant reservations.
	for f in s.fixtures:
		if not Nav.is_register(f):continue
		var arrived=[];var approaching=[]
		for id in f.queue:
			for v in s.visits:
				if v.id==id:
					if v.get("queued",false):arrived.append(id)
					else:approaching.append(id)
		f.queue=arrived+approaching
	var remove=[]
	for v in s.visits:
		var r=s.residents[v.rid]
		if s.tick-v.since>240 and v.state not in ["paying","leaving","entering"]:v.failure_reason="滞在時間";leave(v,false)
		match v.state:
			"entering":
				if move_actor(v) and v.pos==Nav.DOOR:v.state="choose"
			"choose":choose(v)
			"walking","browse_queue":move_to_shelf(v)
			"browsing":
				v.timer-=1
				if v.timer>0:continue
				var f=fixture(v.target);var p=v.wanted
				if f.is_empty() or f.ready>s.tick or f.product!=p:v.state="choose";continue
				if counts(f.lots,p)<=0:
					miss("補充待ち" if counts(s.warehouse,p)>0 else "欠品",p);v.attempts+=1
					v.state="choose" if v.attempts<4 else "checkout";v.mood="あ、最後の一個が…";continue
				var price=selling_price(p)
				if v.spent+price>v.budget:v.state="checkout";continue
				v.basket.append_array(take(f.lots,p,1));v.spent+=price;v.attempts+=1
				v.mood=joke_for(v.rid,p)
				var has_wish=not Stories.request(r).is_empty()
				if counts(v.basket)<4 and v.attempts<5 and (Stories.wants_more(r,v.basket.map(func(l):return int(l.product))) or (not has_wish and rng.randf()<0.70)):v.state="choose"
				else:v.state="checkout"
			"checkout":
				if v.basket.is_empty():leave(v,false);continue
				var best={};var score=100000.0
				for f in s.fixtures:
					if equipment[f.kind].kind!="register" or f.ready>s.tick:continue
					var cells=Nav.queue_cells(f,s.fixtures,s.tier)
					if f.queue.size()>=cells.size():continue
					var goal:Vector2i=cells[f.queue.size()]
					var path=Nav.path(v.pos,goal,s.fixtures,s.tier)
					if path.is_empty() and v.pos!=goal:continue
					var n=path.size()+f.queue.size()*5+(10 if f.clerk<0 else 0)
					if n<score:score=n;best={"f":f,"path":path}
				if best.is_empty():
					v.wait+=1;v.mood="列が空くのを待とう"
					if v.wait>r.patience+comfort():v.failure_reason="行列";leave(v,false);miss("行列")
					continue
				v.target=best.f.id;v.path=best.path;v.state="to_queue";best.f.queue.append(v.id)
			"to_queue","queue":
				var f=fixture(v.target)
				if f.is_empty():v.state="checkout";continue
				var cells=Nav.queue_cells(f,s.fixtures,s.tier);var index=f.queue.find(v.id)
				if index<0 or index>=cells.size():f.queue.erase(v.id);v.state="checkout";continue
				var destination:Vector2i=cells[index]
				if v.pos!=destination:
					if v.path.is_empty() or v.path[-1]!=destination:v.path=Nav.path(v.pos,destination,s.fixtures,s.tier)
					move_actor(v)
				if v.pos==destination:v.state="queue";v.queued=true;v.mood="お会計、お願いします"
				else:v.state="to_queue"
				if v.get("queued",false):v.wait+=1
				if v.wait>r.patience+comfort():
					v.failure_reason="行列";miss("行列");v.mood="時間がない。また今度…";r.last_reason=v.mood;leave(v,false)
			"leaving":
				if move_actor(v) and v.pos==exit_point(v) and v.prev==v.pos:remove.append(v)
	for v in remove:s.visits.erase(v)

func joke_for(rid:int,p:int) -> String:
	if products[p].cat==4 and rid%12==0:return "今日は見るだけ。…これも買おう。"
	if products[p].cat==5 and rid%12==1:return "前回は引き分け。今日こそ。"
	if products[p].size==2:return "会議より長い。袋に入る？"
	if event_for(s.day).id=="hero":return "世界より先に、昼休み。"
	if products[p].joke:return ["明日から本気。今日はこれ。","これは必要経費です。","自分への議決、可決。","胃袋の会議を始めます。"][rid%4]
	return ["これ、いつもの。","ついでに、もう一つ。","今日もお疲れさま。","いいもの見つけた。"][rid%4]

func record_visit_outcome(v:Dictionary,success:bool):
	s.today.completed=s.today.get("completed",0)+1
	if not v.get("need","").is_empty():s.today.purpose_completed=s.today.get("purpose_completed",0)+1
	var event_id=v.get("event_id",event_for(s.day).id)
	if event_id!="normal":
		if not s.today.has("event_results"):s.today.event_results={}
		var tally=s.today.event_results.get(event_id,{"completed":0,"buyers":0})
		tally.completed+=1
		if success:tally.buyers+=1
		s.today.event_results[event_id]=tally
	if event_id.begins_with("winter_") and not v.get("need","").is_empty():
		if not s.today.has("winter_results"):s.today.winter_results={}
		var tally=s.today.winter_results.get(v.need,{"completed":0,"served":0})
		tally.completed+=1
		if success and v.get("purpose_met",false):tally.served+=1
		s.today.winter_results[v.need]=tally

func leave(v:Dictionary,success:bool):
	v.erase("wait_spot")
	if v.state=="leaving":return
	record_visit_outcome(v,success)
	var r=s.residents[v.rid]
	for f in s.fixtures:f.queue.erase(v.id)
	if not success:
		var reason=v.get("failure_reason","")
		if reason.is_empty():reason="会計前に退店"
		var need=v.get("need","")
		if not need.is_empty():
			if not s.today.has("unmet_needs"):s.today.unmet_needs={}
			s.today.unmet_needs[need]=s.today.unmet_needs.get(need,0)+1
		if not s.today.has("lost_visits"):s.today.lost_visits=[]
		if s.today.lost_visits.size()<12:s.today.lost_visits.append({"rid":r.id,"need":need,"reason":reason,"minute":minute()})
		r.last_reason=(need_name(need)+" / " if not need.is_empty() else "")+reason+"で買えなかった"
		return_goods(v.basket);v.basket=[];r.loyalty=maxf(0,r.loyalty-3);r.satisfaction=maxf(0,r.satisfaction-8)
	v.state="leaving";v.path=Nav.path(v.pos,exit_point(v),s.fixtures,s.tier)
	v.bought=success

func update_registers():
	for f in s.fixtures:
		if equipment[f.kind].kind!="register" or f.clerk<0 or f.ready>s.tick:continue
		if f.queue.is_empty():f.pay_timer=0;continue
		var v={}
		for a in s.visits:
			if a.id==f.queue[0]:v=a;break
		if v.is_empty():f.queue.pop_front();continue
		var w=s.staff[f.clerk]
		if w.pos!=Nav.clerk(f) or w.task!="register" or not working(w) or v.pos!=Nav.access(f) or v.state not in ["queue","paying"]:continue
		if v.state=="queue":v.dir=Nav.DIRS.find(Vector2i(f.x,f.y)-v.pos);v.state="paying";f.pay_timer=maxi(2,roundi((3+counts(v.basket))*1.4/(w.register*equipment[f.kind].speed*(1-w.fatigue*0.0035))))
		f.pay_timer-=1
		if f.pay_timer>0:continue
		var r=s.residents[v.rid];var cost=0
		for l in v.basket:
			cost+=l.amount*l.cost;s.today.product_sales[l.product]=s.today.product_sales.get(l.product,0)+l.amount
		var prior=r.last_day
		s.cash+=v.spent;s.today.sales+=v.spent;s.today.cogs+=cost;s.today.buyers+=1
		v.purpose_met=not v.get("need","").is_empty() and Stories.basket_has(v.basket.map(func(l):return int(l.product)),v.need)
		if v.purpose_met:s.today.needs_served=s.today.get("needs_served",0)+1
		var h=minute()/60;s.today.hours[h]=s.today.hours.get(h,0)+v.spent
		if prior>0 and prior!=s.day and not s.today.returners.has(r.id):s.today.returners.append(r.id)
		r.buys+=1;r.last_day=s.day;r.satisfaction=clampf(r.satisfaction+8+w.service*2-(100-s.clean)*0.12,0,100)
		var fulfilled=false
		for l in v.basket:
			if products[l.product].cat==v.goal:fulfilled=true
		r.loyalty=clampf(r.loyalty+(6 if fulfilled else 2)+(3 if v.goal==r.fav and fulfilled else 0)-v.wait*0.05,0,100)
		r.last_reason="購入できた / 待ち時間 "+str(v.wait)+"分"
		var names=[]
		for l in v.basket:names.append(products[l.product].name)
		var receipt={"day":s.day,"items":names,"products":v.basket.map(func(l):return int(l.product)),"price":v.spent,"wait":v.wait,"minute":minute(),"event":event_for(s.day).id,"weather":weather_for(s.day)}
		receipt.story_feedback=Stories.feedback(Stories.request(r),receipt)
		r.history.push_front(receipt)
		if r.history.size()>8:r.history.resize(8)
		var chapter=Stories.record(r,receipt)
		if chapter>=0:
			var text=r.name+"「"+Catalog.EPISODES[r.id][chapter*2+1]+"」"
			s.episode_events.push_front({"rid":r.id,"chapter":chapter,"day":s.day,"text":text});log_message(text)
			if s.episode_events.size()>36:s.episode_events.resize(36)
		v.basket=[];v.mood="ありがとう！";effect(v.pos,"¥"+str(v.spent));leave(v,true)
		s.tutorial=maxi(s.tutorial,1)

func working(w:Dictionary) -> bool:
	return w.hired and w.shifts[shift()]
func comfort() -> int:
	var n=0
	for f in s.fixtures:
		if equipment[f.kind].kind=="decor" and f.ready<=s.tick:n+=4 if f.kind==15 else 2
	return mini(8,n)
func update_staff():
	for f in s.fixtures:
		if f.clerk>=0:
			var w=s.staff[f.clerk]
			if not working(w) or w.task!="register" or w.target!=f.id:
				f.clerk=-1;f.pay_timer=0
				for v in s.visits:
					if v.target==f.id and v.state=="paying":v.state="queue";v.mood="交代を待っています"
	for w in s.staff:
		if not w.hired:continue
		if not working(w):
			if w.task!="off":
				return_goods(w.carry);w.carry=[];w.task="off";w.path=Nav.path(w.pos,Nav.DEPOT,s.fixtures,s.tier,true)
			move_actor(w);w.fatigue=maxf(0,w.fatigue-0.4);continue
		s.today.work_minutes[w.id]=s.today.work_minutes.get(w.id,0)+1
		w.fatigue+=0.14
		if w.task=="off":w.task="idle"
		if w.task=="rest":
			move_actor(w);w.timer-=1;w.fatigue=maxf(0,w.fatigue-w.get("recovery",1.8))
			if w.timer<=0:w.task="idle"
			continue
		if w.fatigue>85 and w.task=="idle":
			w.task="rest";w.timer=25;w.recovery=1.8;w.path=Nav.path(w.pos,Nav.DEPOT,s.fixtures,s.tier,true)
			for f in s.fixtures:
				if equipment[f.kind].kind=="rest" and f.ready<=s.tick:w.timer=10 if f.kind==19 else 15;w.recovery=4.5 if f.kind==19 else 3.0;w.path=Nav.path(w.pos,Nav.access(f),s.fixtures,s.tier,true);break
			continue
		if w.task=="register":
			var f=fixture(w.target)
			if f.is_empty():w.task="idle";continue
			if move_actor(w) and w.pos==Nav.clerk(f):
				f.clerk=w.id;w.timer+=1;w.dir=Nav.DIRS.find(Vector2i(f.x,f.y)-w.pos)
				if f.queue.is_empty() and w.timer>5:f.clerk=-1;w.task="idle"
			continue
		if w.task=="depot":
			if move_actor(w):
				var f=fixture(w.target)
				if f.is_empty() or f.product<0:w.task="idle";continue
				var room=int((equipment[f.kind].capacity-volume(f.lots))/products[f.product].size)
				w.carry=take(s.warehouse,f.product,mini(room,roundi(7*w.stock*(1-w.fatigue*0.003))))
				w.path=Nav.path(w.pos,Nav.access(f),s.fixtures,s.tier,true);w.task="stock";w.timer=2
			continue
		if w.task=="stock":
			if move_actor(w):
				w.timer-=1
				if w.timer<=0:
					var f=fixture(w.target)
					if f.is_empty():return_goods(w.carry)
					else:
						var space=equipment[f.kind].capacity-volume(f.lots)
						for l in w.carry:
							if l.product==f.product and l.amount*products[l.product].size<=space:f.lots.append(l);space-=l.amount*products[l.product].size
							else:return_goods([l])
						if not w.carry.is_empty():effect(w.pos,"補充 +"+str(counts(w.carry)),"stock")
					w.carry=[];w.task="idle"
			continue
		if w.task=="clean":
			if move_actor(w):
				var boost=1.0
				for f in s.fixtures:
					if equipment[f.kind].kind=="clean" and f.ready<=s.tick:boost=1.7;break
				s.clean=minf(100,s.clean+3*boost);w.timer-=1
				if w.timer<=0:w.task="idle"
			continue
		var best={};var score=-1.0
		if w.priority in ["auto","register"]:
			for f in s.fixtures:
				if equipment[f.kind].kind!="register" or f.ready>s.tick or f.clerk>=0:continue
				var assigned=false
				for other in s.staff:
					if other.id!=w.id and other.task=="register" and other.target==f.id and working(other):assigned=true
				if assigned:continue
				var demand=f.queue.size()
				for v in s.visits:
					if v.target==f.id and v.state=="to_queue":demand+=1
				if demand>score and demand>0:best=f;score=demand
			if not best.is_empty():w.task="register";w.target=best.id;w.path=Nav.path(w.pos,Nav.clerk(best),s.fixtures,s.tier,true);w.timer=0;continue
		if w.priority in ["auto","stock"]:
			best={};score=0
			for f in s.fixtures:
				if f.product<0 or f.ready>s.tick or counts(s.warehouse,f.product)<=0:continue
				var assigned=false
				for other in s.staff:
					if other.task in ["stock","depot"] and other.target==f.id:assigned=true
				if assigned:continue
				var capacity=equipment[f.kind].capacity
				var need=1.0-volume(f.lots)/float(maxi(capacity,1))
				if need>0.35 and need>score:score=need;best=f
			if not best.is_empty():w.task="depot";w.target=best.id;w.path=Nav.path(w.pos,Nav.DEPOT,s.fixtures,s.tier,true);continue
		if s.clean<85 and w.priority in ["auto","clean"]:
			w.task="clean";w.timer=8;w.path=Nav.path(w.pos,Vector2i(2,2),s.fixtures,s.tier,true)
		elif w.task=="idle":
			# Clear a shelf face after restocking instead of standing in its customer's place.
			if w.path.is_empty() and s.fixtures.any(func(f):return Nav.access(f)==w.pos):
				var destination=Nav.DEPOT
				for d in Nav.DIRS:
					var at:Vector2i=w.pos+d
					if Nav.obstacles(s.fixtures,true).has(at) or not Nav.inside(at,Nav.dimensions(s.tier)):continue
					if s.fixtures.any(func(f):return Nav.access(f)==at or (Nav.is_register(f) and Nav.clerk(f)==at)):continue
					if s.visits.any(func(v):return v.pos==at):continue
					destination=at;break
				w.path=Nav.path(w.pos,destination,s.fixtures,s.tier,true)
			move_actor(w)

func regulars() -> int:
	return s.residents.filter(func(r):return r.loyalty>=35).size()
func wages() -> int:
	var n=0
	for w in s.staff:
		if w.hired:n+=w.wage*w.shifts.count(true)
	return n
func finish_day():
	var r=s.today
	r.fixed=fixed_cost()
	for id in r.work_minutes:r.wages+=ceili(s.staff[int(id)].wage*r.work_minutes[id]/360.0)
	s.cash-=r.fixed+r.wages
	if s.debt>0 and s.day>=s.due:s.cash-=s.debt;r.other-=s.debt;s.debt=0
	r.profit=r.sales-r.cogs-r.waste-r.fixed-r.wages;r.cash_close=s.cash
	r.regulars=regulars();r.rate=r.buyers/float(maxi(r.get("completed",r.visitors),1));r.clean=s.clean
	s.reports.append(r)
	if s.reports.size()>84:s.reports.pop_front()
	s.streak=s.streak+1 if r.profit>0 else 0
	if r.has("event_results"):
		for tally in r.event_results.values():
			if tally.completed>=20 and tally.buyers/float(tally.completed)>=0.75:s.event_pass=true
	elif r.event!="normal" and r.visitors>=20 and r.rate>=0.75:s.event_pass=true
	if s.day%7==0:
		var weekly=0
		for prior in s.reports.slice(maxi(0,s.reports.size()-7)):weekly+=prior.profit
		if weekly>0 and not s.seasons_profit.has(r.season):s.seasons_profit.append(r.season)
	var before=s.star
	if s.star==0 and s.streak>=3:s.star=1
	if s.star==1 and regulars()>=8:s.star=2
	if s.star==2 and s.event_pass:s.star=3
	if s.star==3 and s.tier>=1 and s.seasons_profit.size()>=2:s.star=4
	if s.star>before:log_message("祝・"+str(s.star)+"つ星！ 新しい品揃えと住人が解放されました。")
	update_review(r)
	if s.pending_review:
		s.review={"start":s.day+1,"reports":[],"cohort":s.residents.filter(func(a):return a.loyalty>=35).map(func(a):return a.id),"days":{},"status":"active"};s.pending_review=false
	log_message("営業"+str(s.day)+"日目：利益 ¥"+str(r.profit)+("。本日の常連：廃棄箱。" if r.waste>r.sales*0.15 else "。お疲れさまでした。"))
	s.day+=1;s.today=new_report(s.day);s.tutorial=maxi(s.tutorial,3)
	if s.cash<0:s.result="debt"
	elif s.day>56 and not s.practice:
		s.won=Campaign.ending_qualified(s)
		s.result="won" if s.won else "deadline"
	new_schedule()

func update_review(report:Dictionary):
	if s.review.is_empty() or s.review.get("status","")!="active":return
	s.review.reports.append(report.duplicate(true))
	for rid in s.review.cohort:
		var r=s.residents[rid]
		if r.last_day==report.day:
			var key=str(rid)
			s.review.days[key]=s.review.days.get(key,0)+1
	if s.review.reports.size()<14:return
	var result=review_metrics()
	if result.pass:
		s.star=5;s.review.status="passed"
		log_message("練習で五つ星条件を達成。本編の結果はそのままです。" if s.practice else "五つ星獲得！ 次は冬の約束。街の『いつもの店』として一年を締めくくろう。")
	else:
		log_message("五つ星審査は未達。経営画面で理由を振り返りましょう。")
		s.review.status="failed"

func review_metrics() -> Dictionary:
	var sales=0;var profit=0;var waste_cost=0;var cogs=0;var events={};var event_totals={};var second=0;var visitors=0
	for r in s.review.get("reports",[]):
		sales+=r.sales;profit+=r.profit;waste_cost+=r.waste;cogs+=r.cogs;visitors+=r.visitors
		if r.has("event_results"):
			for id in r.event_results:
				var totals=event_totals.get(id,{"completed":0,"buyers":0})
				totals.completed+=r.event_results[id].completed;totals.buyers+=r.event_results[id].buyers;event_totals[id]=totals
		elif r.event!="normal" and r.visitors>=20 and r.rate>=0.8:events[r.event]=true
	for id in event_totals:
		var totals=event_totals[id]
		if totals.completed>=20 and totals.buyers/float(totals.completed)>=0.8:events[id]=true
	for key in s.review.get("days",{}):
		if s.review.days[key]>=2:second+=1
	var cohort=s.review.get("cohort",[]).size()
	var margin=profit/float(maxi(sales,1));var waste_rate=waste_cost/float(maxi(waste_cost+cogs,1));var repeat=second/float(maxi(cohort,1))
	var reserve=(fixed_cost()+wages())*3+s.debt+4000
	return {"margin":margin,"waste":waste_rate,"repeat":repeat,"cohort":cohort,"visitors":visitors,"events":events.size(),"reserve":reserve,"days":s.review.get("reports",[]).size(),"pass":sales>0 and margin>=0.05 and waste_rate<=0.08 and cohort>=20 and repeat>=0.7 and events.size()>=2 and s.cash>=reserve and visitors>=280}
