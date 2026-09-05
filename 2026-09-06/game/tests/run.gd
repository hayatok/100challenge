extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Nav=preload("res://core/navigation.gd")
var checks=0
var failures=0
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func _init():
	var sim=Sim.new(100)
	check(sim.products.size()==80,"80 products")
	check(sim.equipment.size()==20,"20 fixtures")
	check(sim.s.residents.size()==120,"120 residents")
	check(sim.s.staff.size()==13,"owner + 12 staff")
	check(Nav.validate(sim.s.fixtures,0).is_empty(),"initial routes")
	check(sim.command("place",{"kind":0,"x":1,"y":8})!="","door cannot block")
	var original=sim.s.cash
	check(sim.command("order",{"product":0,"amount":10})=="","place order")
	check(sim.s.cash==original-sim.products[0].cost*10,"pay once")
	check(sim.s.today.cogs==0,"ordering is not cogs")
	check(sim.s.orders[0].due==480,"afternoon delivery")
	var goods=[sim.lot(0,3,20),sim.lot(0,4,10)]
	var taken=sim.take(goods,0,5)
	check(sim.counts(taken)==5 and sim.counts(goods)==2,"stock conservation")
	check(taken[0].expires==10,"first expiry first")
	check(sim.command("shift",{"id":0,"slot":2})!="","owner max shifts")
	check(sim.command("price",{"product":0,"level":2})=="","price change")
	check(sim.selling_price(0)==168,"integer price")
	var a=Sim.new(90);var b=Sim.new(90)
	a.step(500)
	for i in 500:b.step()
	check(a.s==b.s,"speed-independent deterministic update")
	check(a.s.today.buyers>0,"customers really purchase")
	for seed in 4:
		var game=Sim.new(seed+1)
		game.step(1440*3)
		check(not game.s.reports.is_empty(),"report generated "+str(seed))
		for r in game.s.reports:check(r.profit==r.sales-r.cogs-r.waste-r.fixed-r.wages,"accounting "+str(seed))
		for f in game.s.fixtures:check(game.counts(f.lots)>=0,"nonnegative shelf")
	deep_checks()
	print("MACHI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func deep_checks():
	var game=Sim.new(42)
	var names={}
	for r in game.s.residents:
		check(not names.has(r.name),"resident names are distinct "+str(r.id));names[r.name]=true
		check(r.taste.size()==8 and r.budget>0 and r.patience>0,"complete individual "+str(r.id))
	check(game.command("shift",{"id":99,"slot":0})!="","invalid staff rejected")
	check(game.command("shift",{"id":8,"slot":0})!="","unhired staff rejected")
	check(game.command("place",{"kind":0,"x":2,"y":2,"dir":4})!="","invalid facing rejected")
	check(game.command("order",{"product":79,"amount":1})!="","locked product rejected")
	check(game.command("order",{"product":0,"amount":0})!="","zero order rejected")
	check(game.command("assign",{"fixture":0,"product":20})!="","drink needs cold storage")
	check(game.command("remove",{"fixture":8})!="","last checkout remains")
	check(game.command("place",{"kind":0,"x":3,"y":3})!="","overlap rejected")
	check(game.command("place",{"kind":0,"x":1,"y":1})!="","depot remains accessible")
	check(game.command("place",{"kind":0,"x":-1,"y":3})!="","outside rejected")
	var old=game.s.cash
	game.command("order",{"product":20,"amount":10})
	game.step(479)
	check(game.s.orders.size()==1,"not delivered early")
	game.step()
	check(game.s.orders.is_empty(),"14:00 delivery")
	check(game.s.today.orders==game.products[20].cost*10,"delivery not charged twice")
	game.command("order",{"product":20,"amount":10})
	check(game.s.orders[-1].due==1440,"14:00 cutoff -> next 06:00")
	game=Sim.new(42);game.s.tick=100
	game.s.warehouse=[game.lot(0,3,101)];game.s.fixtures[0].lots=[]
	game.step()
	check(game.counts(game.s.warehouse,0)==0 and game.s.today.waste==249,"expiry at exact minute")
	game=Sim.new(42)
	game.s.staff[0].carry=[game.lot(20,5)]
	check(game.total_stock(20)==23,"moving stock included in order target")
	var total=all_goods(game)
	check(game.command("move",{"fixture":0,"x":4,"y":3,"dir":0})=="","legal move")
	check(all_goods(game)==total,"relocation preserves carrying stock")
	check(Nav.validate(game.s.fixtures,0).is_empty(),"all routes after relocation")
	game=Sim.new(42);game.step(1439)
	var accrued=game.s.today.work_minutes.get(1,0)
	for i in 4:
		if game.s.staff[1].shifts[i]:game.command("shift",{"id":1,"slot":i})
	game.step()
	check(game.s.reports[0].wages==ceili(accrued*450/360.0),"late shift change cannot erase wages")
	for report in game.s.reports:
		check(report.cash_close-report.cash_open==report.sales-report.orders-report.fixed-report.wages-report.investment+report.other,"cash flow reconciliation")
	game=Sim.new(42);game.s.cash=-100;game.s.result="debt"
	check(game.command("remove",{"fixture":0})=="" and game.s.result.is_empty(),"sale can recover from debt")
	game.s.cash=-500;game.s.result="debt"
	check(game.command("loan")=="" and game.s.cash==19500 and game.s.debt==22000,"one recovery loan")
	check(game.command("loan")!="","loan cannot repeat")
	game.s.cash=50000;game.s.day=game.s.due;game.finish_day()
	check(game.s.debt==0 and game.s.cash==50000-game.fixed_cost()-22000,"loan due repayment")
	game=Sim.new(42);game.s.star=4;game.s.day=42
	check(game.command("review")=="","last valid review booking")
	game.finish_day()
	check(game.s.review.start==43 and game.s.review.reports.is_empty(),"review starts next day without counting booking day")
	game.s.review.status="failed";game.s.day=36
	check(game.command("review")=="","failed review can be retried")
	game.s.pending_review=false;game.s.day=43
	check(game.command("review")!="","late booking rejected")
	game=Sim.new(42);game.s.day=56;game.s.cash=100000;game.finish_day()
	check(game.s.result=="deadline","year-end result")
	game.command("continue");game.step(1440)
	check(game.s.result.is_empty() and game.s.practice,"practice continues after deadline")
	game=Sim.new(42)
	game.s.schedule=[{"at":0,"rid":0,"wait":0},{"at":0,"rid":1,"wait":0}];game.spawn_due()
	var f=game.fixture(8);f.clerk=0
	for v in game.s.visits:
		v.state="queue";v.target=f.id;v.basket=[game.lot(0,1)];v.spent=140;f.queue.append(v.id)
	var first=game.s.visits[0].rid;var second=game.s.visits[1].rid
	for i in 6:game.update_registers()
	check(game.s.residents[first].buys==1 and game.s.residents[second].buys==0,"checkout FIFO")
	check(game.s.today.sales==140 and game.s.today.cogs==83,"charge basket exactly once")
	for i in 6:game.update_registers()
	check(game.s.today.sales==280 and game.s.residents[second].buys==1,"next customer served")
	game=Sim.new(42);game.s.cash=100000
	check(game.command("place",{"kind":7,"x":2,"y":3})=="","place comfort fixture")
	check(game.comfort()==0,"fixture unavailable during setup")
	game.step(15);check(game.comfort()==2,"decoration affects patience")
	game=Sim.new(42);game.step(600)
	var snapshot=var_to_bytes(game.s)
	var restored=Sim.new(1);restored.s=bytes_to_var(snapshot)
	game.step(840);restored.step(840)
	check(game.s==restored.s,"save/reload preserves deterministic continuation")

func all_goods(game) -> int:
	var total=game.counts(game.s.warehouse)
	for f in game.s.fixtures:total+=game.counts(f.lots)
	for w in game.s.staff:total+=game.counts(w.carry)
	for v in game.s.visits:total+=game.counts(v.basket)
	return total
