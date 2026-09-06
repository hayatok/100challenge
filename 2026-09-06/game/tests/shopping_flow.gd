extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Nav=preload("res://core/navigation.gd")
var failures=[]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func _init():
	var game=Sim.new();var shelf=game.fixture(7);shelf.product=73;shelf.lots=[game.lot(73,10)]
	game.s.schedule=[{"at":0,"rid":12,"wait":0},{"at":0,"rid":13,"wait":0}];game.spawn_due()
	for i in 2:
		var v=game.s.visits[i];v.pos=Vector2i(1+i,8);v.prev=v.pos;v.need="rain";v.budget=1000;v.state="choose";game.choose(v)
	check(game.s.visits.all(func(v):return v.state=="walking" and v.target==shelf.id),"A distant shopper exclusively reserved an empty shelf")
	check(game.s.visits[0].browse_slot!=game.s.visits[1].browse_slot,"Approaching shoppers reserved the same standing place")
	var waited=false;var separate=true
	for minute in 100:
		game.step()
		var positions={}
		for v in game.s.visits:
			if v.state=="browse_queue":waited=true
			if v.state in ["browse_queue","browsing"]:
				if positions.has(v.pos):separate=false
				positions[v.pos]=true
	check(waited and separate,"Shelf line was invisible or shared standing cells")
	check(game.s.residents[12].buys==1 and game.s.residents[13].buys==1,"Both customers could not finish their purchases")
	check([12,13].all(func(id):return not game.s.residents[id].history.is_empty() and game.s.residents[id].history[0].products==[73]),"An errand shopper kept browsing after purchasing the requested umbrella")
	# Taking a second item must not send the head to the occupied tail of its own line.
	var cells=Nav.browse_cells(shelf,game.s.fixtures,game.s.tier)
	game.s.visits=[]
	for i in 3:
		var v={"id":100+i,"rid":12+i,"state":"choose" if i==0 else "browse_queue","pos":cells[i],"target":shelf.id,"basket":[game.lot(73,1)] if i==0 else [],"spent":game.selling_price(73) if i==0 else 0,"budget":2000,"goal":7,"need":"rain","attempts":1,"browse_ticket":i+1,"path":[],"mood":""}
		game.s.visits.append(v)
	game.s.residents[12].taste[7]=5.0;shelf.lots=[game.lot(73,10)]
	game.choose(game.s.visits[0])
	check(game.s.visits[0].target==shelf.id and game.s.visits[0].browse_slot==cells[0] and game.s.visits[0].browse_ticket==1,"Second purchase created a circular shelf queue")
	game.s.visits=[];game.s.warehouse=[]
	for w in game.s.staff:w.hired=false
	var clerk=game.s.staff[0];clerk.hired=true;clerk.priority="stock";clerk.task="idle";clerk.path=[];clerk.pos=Nav.access(shelf);clerk.fatigue=0
	game.update_staff()
	check(clerk.pos!=Nav.access(shelf),"Idle stock clerk remained in the customer's place")
	clerk.task="idle";clerk.path=[];clerk.pos=Nav.access(shelf);clerk.fatigue=90
	game.update_staff()
	check(clerk.task=="rest" and not clerk.path.is_empty() and clerk.path[-1]==Nav.DEPOT,"Rest without a bench blocked the shop aisle")
	# A worker going off duty used to become invisible to customer collision checks.
	game=Sim.new();clerk=game.s.staff[2];clerk.hired=true;clerk.task="off"
	clerk.pos=Vector2i(7,3);clerk.prev=clerk.pos;clerk.path=[Vector2i(7,2)]
	var shopper={"id":500,"pos":Vector2i(7,4),"prev":Vector2i(7,4),"state":"walking","path":[Vector2i(7,3)],"dir":0}
	game.s.visits=[shopper];game.move_actor(shopper)
	check(shopper.pos!=clerk.pos,"An off-duty worker was ignored by customer collision checks")
	clerk.path=[shopper.pos];game.move_actor(shopper)
	check(shopper.pos==Vector2i(7,3) and clerk.pos==Vector2i(7,4),"Customer and off-duty worker could not pass in a public aisle")
	check(shopper.get("pass_tick",-1)==game.s.tick and clerk.get("pass_tick",-1)==game.s.tick,"Passing customer and worker did not receive separate drawing lanes")
	# Actual old saves can already contain the overlap: recover beside the shopper.
	clerk.pos=shopper.pos;clerk.prev=clerk.pos;clerk.path=Nav.path(clerk.pos,Nav.DEPOT,game.s.fixtures,0,true)
	var before_restore:Vector2i=clerk.pos
	game.restore_spatial_state()
	check(clerk.pos!=shopper.pos and absi(clerk.pos.x-before_restore.x)+absi(clerk.pos.y-before_restore.y)==1,"Loading an old overlapping off-duty worker failed to restore adjacent separation")
	# Reproduce the crossed approach found during the 49th morning of normal play.
	game=Sim.new();shelf=game.fixture(7);shelf.product=73;shelf.lots=[game.lot(73,20)]
	cells=Nav.browse_cells(shelf,game.s.fixtures,game.s.tier)
	game.s.schedule=[{"at":0,"rid":90,"wait":0},{"at":0,"rid":91,"wait":0}];game.spawn_due()
	for i in 2:
		var v=game.s.visits[i];v.pos=cells[1-i];v.prev=v.pos;v.state="walking";v.target=shelf.id;v.wanted=73;v.need="rain";v.budget=1000;v.browse_ticket=i;v.path=[cells[i]]
	var crossed=game.s.visits.duplicate()
	for minute in 100:game.step()
	check(crossed.all(func(v):return v.bought),"Crossed shelf approach remained deadlocked instead of stepping aside")
	# Busy shoppers need different waiting places away from the doorway.
	game=Sim.new();game.s.schedule=[{"at":0,"rid":90,"wait":0},{"at":0,"rid":91,"wait":0}];game.spawn_due()
	for v in game.s.visits:v.pos=Nav.DOOR;v.prev=v.pos;v.state="choose";v.path=[];game.wait_for_shelf(v)
	var waiters=game.s.visits.duplicate()
	check(waiters.all(func(v):return v.has("wait_spot") and v.wait_spot!=Nav.DOOR) and waiters[0].wait_spot!=waiters[1].wait_spot,"Busy shelf waiters shared the doorway or waiting place")
	for minute in 30:
		for v in waiters:game.wait_for_shelf(v)
	check(waiters.all(func(v):return v.pos==v.wait_spot),"Waiting area could not be reached")
	# Four walkers can block one another without forming a two-person head-on pair.
	game=Sim.new();game.s.visits=[]
	var corners=[Vector2i(7,7),Vector2i(8,7),Vector2i(8,8),Vector2i(7,8)]
	for i in 4:game.s.visits.append({"id":i,"pos":corners[i],"state":"walking","path":[corners[(i+1)%4]],"dir":0})
	var cycle_overlap=false;var jumped=false
	for minute in 20:
		game.s.tick+=1
		for v in game.s.visits:v.prev=v.pos
		for v in game.s.visits:
			var before:Vector2i=v.pos;game.move_actor(v)
			if absi(v.pos.x-before.x)+absi(v.pos.y-before.y)>1:jumped=true
			if game.s.visits.any(func(other):return other!=v and other.pos==v.pos):cycle_overlap=true
	check(game.s.visits.all(func(v):return v.pos==corners[(v.id+1)%4]) and not cycle_overlap and not jumped,"A circular aisle wait did not resolve by adjacent free steps")
	# A shopper leaving a bay may be surrounded by a fixed line and a new arrival.
	# The approaching walker must open the free side even without a direct swap.
	game=Sim.new();game.s.tier=1
	game.s.fixtures.append({"id":100,"kind":0,"x":5,"y":11,"dir":0})
	var trapped={"id":1,"pos":Vector2i(5,10),"state":"walking","path":[Vector2i(4,10),Vector2i(3,10)],"dir":0}
	var approaching={"id":2,"pos":Vector2i(6,10),"state":"walking","path":[Vector2i(5,10)],"dir":0}
	game.s.visits=[trapped,approaching,{"id":3,"pos":Vector2i(4,10),"state":"browse_queue","path":[]},{"id":4,"pos":Vector2i(5,9),"state":"queue","path":[]}]
	for minute in 30:
		game.s.tick+=1
		for v in game.s.visits:v.prev=v.pos
		game.move_actor(trapped);game.move_actor(approaching)
	check(trapped.pos==Vector2i(3,10) and approaching.pos==Vector2i(5,10),"An approaching walker trapped a shopper behind the stationary line")
	# The old shared endpoint could trap an arrival between two departing people.
	game=Sim.new();game.s.schedule=[{"at":0,"rid":90,"wait":0},{"at":0,"rid":91,"wait":0},{"at":0,"rid":93,"wait":0}]
	for minute in 3:game.step()
	var arrivals=game.s.visits.filter(func(v):return v.rid==90)
	var exits=game.s.visits.filter(func(v):return v.rid in [91,93])
	for i in exits.size():
		var v=exits[i];v.pos=Vector2i(-2,-3) if i==0 else Vector2i(-3,-2);v.prev=v.pos;v.state="leaving";v.path=[Vector2i(-3,-3)]
	arrivals[0].pos=Vector2i(-3,-3);arrivals[0].prev=arrivals[0].pos;arrivals[0].state="entering";arrivals[0].path=Nav.path(arrivals[0].pos,Nav.DOOR,game.s.fixtures,0)
	for minute in 40:game.step()
	check(exits.all(func(v):return not game.s.visits.has(v)) and arrivals[0].pos!=Vector2i(-3,-3),"Old arrivals and departures deadlocked at the pavement endpoint")
	# A burst from both street ends must form a physical crowd, not stacked sprites.
	game=Sim.new();game.s.schedule=[]
	for id in 60:game.s.schedule.append({"at":0,"rid":id,"wait":0})
	var overlap=false;var disconnected=false;var entered=0
	for minute in 600:
		game.step()
		var outside={};var waiting={};var departures={}
		for v in game.s.visits:
			if v.pos.x<0 or v.pos in [Nav.DOOR,Nav.EXIT_DOOR]:
				if outside.has(v.pos):overlap=true
				outside[v.pos]=true
			if v.state=="leaving":
				if departures.has(v.pos):overlap=true
				departures[v.pos]=true
			if v.state in ["choose","checkout"] and v.has("wait_spot"):waiting[v.wait_spot]=true
		var reached=Nav.walk_region(Nav.DOOR,game.s.fixtures,game.s.tier,waiting)
		for f in game.s.fixtures:
			if not Nav.staff_equipment(f) and not reached.has(Nav.access(f)):disconnected=true
		entered=maxi(entered,game.s.residents.reduce(func(total,r):return total+r.visits,0))
	check(not overlap,"Crowded arrivals or departures shared a sidewalk cell")
	check(not disconnected,"Shelf waiters cut off a service aisle")
	print("BURST admitted=",entered," remaining=",game.s.visits.size()," pending=",game.s.schedule.size());
	if not game.s.visits.is_empty():print(game.s.visits.map(func(v):return {"id":v.id,"pos":str(v.pos),"state":v.state,"path":str(v.path)}))
	check(entered>=40 and game.s.visits.is_empty(),"A burst of arrivals could not clear the doorway and depart")
	# Opposing traffic at the one-cell door must let the departing shopper through.
	game=Sim.new();game.s.schedule=[{"at":0,"rid":90,"wait":0},{"at":0,"rid":91,"wait":0}];game.spawn_due()
	var outgoing=game.s.visits[0];var incoming=game.s.visits[1]
	outgoing.pos=Nav.DOOR;outgoing.prev=outgoing.pos;outgoing.state="leaving";outgoing.path=Nav.path(outgoing.pos,game.exit_point(outgoing),game.s.fixtures,0)
	incoming.pos=Nav.DOOR+Vector2i.LEFT;incoming.prev=incoming.pos;incoming.state="entering";incoming.path=[Nav.DOOR]
	for minute in 8:game.step()
	check(outgoing.pos.x<0 and incoming.pos.x>=0 and outgoing.pos!=incoming.pos,"Opposing doorway traffic did not yield and enter separately")
	outgoing.pos=Nav.EXIT_DOOR;outgoing.prev=outgoing.pos;outgoing.state="leaving";outgoing.path=game.departure_path(outgoing)
	incoming.pos=Nav.EXIT_DOOR+Vector2i.LEFT;incoming.state="entering";incoming.path=Nav.path(incoming.pos,Nav.DOOR,game.s.fixtures,0)
	game.s.visits=[outgoing,incoming];game.move_actor(outgoing)
	check(outgoing.pos==Nav.EXIT_DOOR and not outgoing.path.has(Nav.DOOR),"A blocked exit sent a departing shopper back into the entry leaf")
	print("SHOPPING FLOW: concurrent approach, physical shelf line, completed payments and staff yielding; ",failures.size()," failures")
	quit(1 if failures else 0)
