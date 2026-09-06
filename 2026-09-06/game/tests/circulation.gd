extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Nav=preload("res://core/navigation.gd")
var checks=0
var errors=[]
func check(ok:bool,message:String):
	checks+=1
	if not ok:errors.append(message);printerr("FAIL: ",message)
func _init():
	var game=Sim.new(20260906)
	var till=game.fixture(8)
	check(Nav.DOOR.x==0,"door on facade")
	check(Nav.validate(game.s.fixtures,0).is_empty(),"planned layout includes clear queues and staff side")
	check(Nav.access(till)!=Nav.clerk(till),"opposite sides of counter")
	check(Nav.queue_cells(till,game.s.fixtures,0).size()==4,"four physical queue slots")
	for tier in 3:
		for far in [false,true]:
			var path=Nav.path(Nav.street_start(tier,far),Nav.DEPOT,game.s.fixtures,tier,true)
			check(Nav.street_start(tier,far)!=Nav.street_end(tier,far),"street endpoints keep arrivals and departures separate at tier "+str(tier))
			check(path.has(Nav.DOOR),"street route passes door at tier "+str(tier))
			check(path.all(func(p):return p.x>=-3),"arrivals remain on widened sidewalk at tier "+str(tier))
			var departure=Nav.path(Nav.DOOR,Nav.street_end(tier,far),game.s.fixtures,tier)
			check(departure.all(func(p):return p.x>=-3),"departures remain on widened sidewalk at tier "+str(tier))
	check(not Nav.walkable(Vector2i(-4,2),Nav.dimensions(0)),"road remains outside the pedestrian network")
	check(not Nav.connected(Vector2i(-1,4),Vector2i(0,4)),"glass facade cannot be crossed")
	check(game.command("place",{"kind":0,"x":3,"y":7,"dir":1})!="","clerk position cannot be built over")
	check(game.command("place",{"kind":0,"x":1,"y":8,"dir":0})!="","inside threshold clear")
	check(game.command("place",{"kind":0,"x":1,"y":6,"dir":1})!="","queue cannot be shortened below three cells")
	# A basket and an assigned clerk are insufficient until both reach their side.
	game.s.schedule=[{"at":0,"rid":0,"wait":0}];game.spawn_due()
	var customer=game.s.visits[0]
	check(customer.pos.x<0 and customer.state=="entering","customer originates on street")
	customer.basket=[game.lot(0,1)];customer.spent=140;customer.state="queue";customer.target=till.id;till.queue=[customer.id];till.clerk=0
	var clerk=game.s.staff[0];clerk.task="register";clerk.target=till.id
	for i in 10:game.update_registers()
	check(game.s.today.sales==0,"no remote checkout while neither has arrived")
	customer.pos=Nav.access(till)
	for i in 10:game.update_registers()
	check(game.s.today.sales==0,"customer arrival alone cannot pay")
	clerk.pos=Nav.clerk(till)
	for i in 6:game.update_registers()
	check(game.s.today.sales==140 and customer.state=="leaving","checkout only across counter")
	check(customer.path.has(Nav.EXIT_DOOR) and customer.path[-1].x<0,"paid visit exits through door to street")
	var old_buys=game.s.residents[0].buys
	game.repath_all()
	check(customer.state=="leaving" and customer.path[-1].x<0,"relocation preserves departure")
	check(game.s.residents[0].buys==old_buys,"relocation never duplicates checkout")
	game.command("expand") # Locked expansion leaves route unchanged.
	game.s.star=1;game.s.cash=100000
	game.command("expand")
	check(customer.path[-1]==game.exit_point(customer),"expanded street has valid departure endpoint")
	# Upgrade the untouched old layout without resetting the shop economy.
	var legacy=Sim.new(71);legacy.s.erase("layout_version");legacy.s.cash=76543
	for f in legacy.s.fixtures:
		if f.id==8:f.x=2;f.y=7;f.dir=3
		else:f.x=3+(f.id%3)*3;f.y=3+(f.id/3)*2;f.dir=0
	var lots=var_to_bytes(legacy.s.fixtures.map(func(f):return f.lots))
	check(not legacy.restore_spatial_state().is_empty(),"old layout correction explained")
	check(legacy.s.cash==76543 and var_to_bytes(legacy.s.fixtures.map(func(f):return f.lots))==lots,"old layout preserves money and every inventory lot")
	check(Nav.validate(legacy.s.fixtures,legacy.s.tier).is_empty(),"old factory layout becomes a valid shop")
	# Custom arrangements stay editable even if multiple old constraints need repairs.
	legacy=Sim.new(71);legacy.s.erase("layout_version")
	legacy.fixture(8).y=7;legacy.fixture(6).x=3;legacy.fixture(6).y=7;legacy.fixture(6).dir=0
	legacy.fixture(7).x=2;legacy.fixture(7).y=4;legacy.fixture(7).dir=3
	legacy.restore_spatial_state()
	check(legacy.s.layout_needs_review and legacy.fixture(6).x==3,"custom geometry preserved with explicit review flag")
	check(legacy.command("move",{"fixture":6,"x":8,"y":6,"dir":0}).is_empty(),"old store can repair its first invalid fixture")
	check(legacy.command("move",{"fixture":7,"x":11,"y":4,"dir":3}).is_empty() and not legacy.s.layout_needs_review,"old store can complete staged repairs")
	legacy=Sim.new(71);legacy.s.layout_version=2;legacy.fixture(7).x=0;legacy.fixture(7).y=9;legacy.fixture(7).dir=1
	lots=var_to_bytes(legacy.fixture(7).lots);var cash=legacy.s.cash
	check(not legacy.restore_spatial_state().is_empty() and legacy.s.layout_needs_review,"Old customized second doorway has no repair guidance")
	check(legacy.fixture(7).x==0 and legacy.s.cash==cash and var_to_bytes(legacy.fixture(7).lots)==lots,"Wider doorway silently moved old furniture or inventory")
	check(legacy.command("move",{"fixture":7,"x":11,"y":4,"dir":3}).is_empty() and not legacy.s.layout_needs_review,"Customized old doorway could not be opened through normal building controls")
	# Continuous normal simulation. Report all spatial invariants as aggregate checks.
	var stepped=true;var facade=true;var terminal=true;var counter=true;var queue=true;var unique_browse=true
	var public_floor=true;var separate_workers=true
	var entered=0;var departed=0;var served=0;var max_queue=0;var captured=false
	game=Sim.new(20260906)
	game.command("hire",{"id":2});game.command("shift",{"id":2,"slot":0});game.command("shift",{"id":2,"slot":1})
	for tick in 1440*3:
		var previous={}
		for v in game.s.visits:previous[v.id]=v.duplicate(true)
		game.step()
		var browsing={};var active={}
		for v in game.s.visits:
			active[v.id]=true
			if Nav.backroom(v.pos):public_floor=false
			if game.s.staff.any(func(w):return w.hired and w.pos==v.pos):separate_workers=false
			var distance=absi(v.pos.x-v.prev.x)+absi(v.pos.y-v.prev.y)
			if distance>1:stepped=false
			if v.prev.x<0 and v.pos.x>=0:
				entered+=1
				if v.pos!=Nav.DOOR:facade=false
			if v.prev.x>=0 and v.pos.x<0 and v.prev not in [Nav.DOOR,Nav.EXIT_DOOR]:facade=false
			if v.state=="paying":
				served+=1;var f=game.fixture(v.target)
				if v.pos!=Nav.access(f) or f.clerk<0 or game.s.staff[f.clerk].pos!=Nav.clerk(f):counter=false
			if v.state=="browsing":
				if browsing.has(v.pos):unique_browse=false
				browsing[v.pos]=true
		for id in previous:
			if not active.has(id):
				departed+=1
				if previous[id].pos.x>=0 or previous[id].state!="leaving":terminal=false
		for f in game.s.fixtures:
			if not Nav.is_register(f):continue
			max_queue=maxi(max_queue,f.queue.size())
			if "--qa" in OS.get_cmdline_user_args() and not captured and game.s.visits.filter(func(v):return v.target==f.id and v.state in ["paying","queue"]).size()>=3:
				var snapshot=FileAccess.open("user://qa-current.save",FileAccess.WRITE)
				snapshot.store_var({"game":game.s,"settings":{}});snapshot.close();captured=true
				print("CIRCULATION QA snapshot: day ",game.s.day," minute ",game.minute()," queue ",f.queue.size())
			var cells=Nav.queue_cells(f,game.s.fixtures,game.s.tier)
			var positions={}
			for v in game.s.visits:
				if v.target==f.id and v.state in ["queue","paying"]:
					if positions.has(v.pos):queue=false
					positions[v.pos]=true
	check(stepped,"no teleport: every person moves at most one adjacent tile per minute")
	check(facade,"all crossings use physical doorway")
	check(terminal and departed>10,"people disappear only after walking to road endpoint")
	check(counter and served>10,"normal live payments use opposite positions")
	check(queue and max_queue>=2,"multiple customers occupy different queue cells")
	check(unique_browse,"customers take turns at a shelf")
	check(entered>20,"normal arrivals traverse street and doorway")
	check(public_floor,"customers never enter the staff backroom")
	check(separate_workers,"Customers never share a public floor cell with on-duty or off-duty staff")
	print("CIRCULATION: ",checks," checks, ",errors.size()," failures; entered=",entered," departed=",departed," payment_minutes=",served," max_queue=",max_queue)
	quit(1 if errors else 0)
