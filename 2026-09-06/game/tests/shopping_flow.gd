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
	print("SHOPPING FLOW: concurrent approach, physical shelf line, completed payments and staff yielding; ",failures.size()," failures")
	quit(1 if failures else 0)
