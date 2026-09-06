extends SceneTree
const Stories=preload("res://core/resident_stories.gd")
const Goods=preload("res://core/merchandise.gd")
const Catalog=preload("res://core/catalog.gd")
const Sim=preload("res://core/simulation.gd")
const Nav=preload("res://core/navigation.gd")
var failures=[]
const EXAMPLES=[[[40],[40,21],[40,43]],[[50],[53,20],[53,20]],[[10],[20,36],[20,36]],[[0],[3,20],[0,20]],[[10,70],[13,70],[10,70]],[[60],[54],[54]],[[21],[20,21],[40,20]],[[0],[0,20],[0,20]],[[40],[43],[40,41]],[[0],[0,21],[0,21]],[[73],[20],[70,20]],[[60],[66],[60,40]]]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func receipt(ids:Array,day:int=1) -> Dictionary:
	return {"products":ids,"day":day,"wait":4,"price":400,"minute":480,"event":"pudding","weather":"晴れ"}
func _init():
	var residents=Catalog.residents(20260906)
	for rid in 12:
		var r=residents[rid]
		for stage in 3:
			r.episode=stage;r.story_days=[]
			var req=Stories.request(r);var sale=receipt(EXAMPLES[rid][stage]);sale.weather=req.get("weather","晴れ")
			if req.has("weekdays"):sale.day=6
			check(Stories.matches(req,sale),"Authored example cannot satisfy %d/%d"%[rid,stage])
			var wrong=sale.duplicate(true);wrong.products=[]
			check(not Stories.matches(req,wrong),"Empty sale satisfies %d/%d"%[rid,stage])
			var days=req.get("days",1)
			for day in days:
				sale.day=day+(6 if req.has("weekdays") else 1)
				var result=Stories.record(r,sale)
				check(result==(stage if day==days-1 else -1),"Stage dates failed %d/%d"%[rid,stage])
				if day<days-1:check(Stories.record(r,sale)==-1 and r.story_days.size()==day+1,"Repeated checkout counted as a new day")
	check(not Stories.matches(Stories.REQUESTS[0][1],receipt([24])),"Sweet coffee faked a dessert and coffee combination")
	check(not Stories.matches(Stories.REQUESTS[2][2],receipt([20,36],5)),"Friday counted toward a weekend request")
	check(Stories.matches(Stories.REQUESTS[2][2],receipt([20,36],7)),"Sunday did not count toward a weekend request")
	check(Stories.feedback(Stories.REQUESTS[4][1],receipt([13])).contains("新聞"),"Missing newspaper is not explained")
	check(Stories.feedback(Stories.REQUESTS[2][2],receipt([20,36],5)).contains("土・日"),"Weekday rejection is not explained")
	var reader=Catalog.residents(1)[2];reader.episode=2
	var weekend=receipt([20,36],6)
	Stories.record(reader,weekend);Stories.record(reader,weekend)
	check(reader.story_receipts.size()==1,"One receipt was saved twice as story evidence")
	weekend.day=7;Stories.record(reader,weekend)
	check(reader.story_evidence[2].size()==2 and reader.story_evidence[2][0].day==6,"Completed story lost its actual purchase dates")
	# Cross-product tag unions must not pretend a non-spicy noodle was spicy.
	check(not Stories.matches({"all":["sweet novel"]},receipt([40,26])),"An ordinary pudding and novelty coffee faked a novelty dessert")
	check(not Stories.matches({"all":["sweet"],"distinct_cat":4,"distinct":2},receipt([40,40])),"Two units faked two flavours")
	var late=receipt([0,21]);late.minute=600
	check(not Stories.matches(Stories.REQUESTS[9][2],late),"Morning deadline ignored")
	var slow=receipt([0]);slow.wait=11
	check(not Stories.matches(Stories.REQUESTS[3][0],slow),"Queue wait ignored")
	var expensive=receipt([53,20]);expensive.price=651
	check(not Stories.matches(Stories.REQUESTS[1][2],expensive),"Personal budget ignored")
	check(Goods.affinity(1,53)>Goods.affinity(1,50),"Spicy fan cannot distinguish noodles")
	check(Goods.affinity(2,36)>Goods.affinity(2,30),"Bookshop resident cannot distinguish cookies")
	var shopping=Sim.new();shopping.s.schedule=[{"at":0,"rid":4,"wait":0}];shopping.spawn_due()
	var customer=shopping.s.visits[0];shopping.s.residents[4].episode=1
	customer.pos=Nav.access(shopping.fixture(1));customer.prev=customer.pos;customer.need="";customer.state="choose";customer.goal=1;customer.budget=700;customer.basket=[shopping.lot(13,1)];customer.spent=226
	shopping.choose(customer)
	check(customer.wanted==70,"An optional extra took priority over the newspaper explicitly requested with bread")
	# Merely taking an item is not enough: the real till must complete a sale.
	var sim=Sim.new();var f=sim.s.fixtures[8];var r=sim.s.residents[0];var w=sim.s.staff[0]
	var v={"id":900,"rid":0,"pos":Nav.access(f),"prev":Nav.access(f),"path":[],"state":"queue","target":f.id,"basket":[sim.lot(40,1)],"spent":210,"wait":1,"bought":false,"goal":4,"dir":0,"mood":"","since":0}
	sim.s.visits=[v];f.queue=[900];f.clerk=0;w.task="register";w.pos=Nav.DEPOT
	for n in 20:sim.update_registers()
	check(r.episode==0 and sim.s.today.sales==0,"Story progressed before cashier arrival")
	w.pos=Nav.clerk(f)
	for n in 20:sim.update_registers()
	check(r.episode==1 and sim.s.episode_events.size()==1 and sim.s.today.sales==210,"Paid purchase did not advance the correct story once")
	print("STORIES: 36 authored stages, budget/time/product/date counterexamples and real checkout; ",failures.size()," failures")
	quit(1 if failures else 0)
