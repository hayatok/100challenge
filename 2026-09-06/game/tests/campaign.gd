extends SceneTree
const Sim=preload("res://core/simulation.gd")
const City=preload("res://core/city.gd")
const Campaign=preload("res://core/campaign.gd")
const Stories=preload("res://core/resident_stories.gd")
const Nav=preload("res://core/navigation.gd")
var failures=[]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func _init():
	var game=Sim.new()
	check(not game.command("winter_plan",{"value":"night"}).is_empty(),"Winter choice opened before autumn")
	game.s.day=29
	check(game.command("winter_plan",{"value":"night"}).is_empty(),"Cannot select the night promise")
	check(game.event_for(45).hour==2 and game.event_for(45).needs.has("warm soup"),"Chosen promise differs from forecast")
	game.s.day=43
	check(not game.command("winter_plan",{"value":"treats"}).is_empty() and game.s.winter_plan=="night","Promise changed after invitations went out")
	for plan in Campaign.PLANS:
		for need in Campaign.PLANS[plan].needs:check(game.products.any(func(p):return p.unlock<=4 and Stories.product_matches(p.id,need)),"Unfulfillable winter promise: "+need)
	# Visitors turned away by capacity count as missed promises, not an invisible success boost.
	game=Sim.new();game.s.day=45;game.s.winter_plan="breakfast"
	game.s.visits=[]
	for i in 40:game.s.visits.append({"state":"walking"})
	var rid=0
	while City.need(45,rid,game.s.seed,"breakfast").is_empty():rid+=1
	game.s.schedule=[{"at":0,"rid":rid,"wait":30}];game.spawn_due()
	check(game.s.today.completed==1 and game.s.today.winter_results.size()==1 and game.s.schedule.is_empty(),"Capacity rejection disappeared from promise results")
	# Passing the 14-day rating is a milestone, not the premature ending.
	game=Sim.new();game.s.cash=100000;game.s.star=4
	var report=game.new_report(36);report.sales=10000;report.profit=2000;report.cogs=5000;report.visitors=30;report.event_results={"chili":{"completed":20,"buyers":18},"pudding":{"completed":20,"buyers":18}}
	game.s.review={"status":"active","reports":[],"cohort":range(20),"days":{}}
	for id in range(20):game.s.review.days[str(id)]=2
	for day in 13:game.s.review.reports.append(report.duplicate(true))
	game.update_review(report)
	check(game.s.star==5 and game.s.review.status=="passed" and not game.s.won and game.s.result.is_empty(),"Five stars stopped the campaign before winter")
	# Actual cash register transactions count people and requested goods, not just receipts.
	game=Sim.new();game.s.day=45;game.s.winter_plan="breakfast";game.s.schedule=[]
	var till=game.fixture(8);var clerk=game.s.staff[0];clerk.task="register";clerk.target=8;clerk.pos=Nav.clerk(till);till.clerk=0
	for id in 2:
		var v={"id":id,"rid":id,"pos":Nav.access(till),"prev":Nav.access(till),"state":"queue","target":8,"basket":[game.lot(0 if id==0 else 70,2)],"spent":280,"wait":0,"goal":0,"need":"rice light","event_id":"winter_breakfast","mood":"","bought":false,"path":[],"dir":0}
		game.s.visits=[v];till.queue=[id];till.pay_timer=0
		for minute in 12:game.update_registers()
	check(game.s.today.winter_results["rice light"].completed==2 and game.s.today.winter_results["rice light"].served==1,"Promise counted two items as people or newspaper as breakfast")
	var counts={"rice light":{"completed":20,"served":14},"bread":{"completed":20,"served":14},"tea":{"completed":20,"served":14}}
	game.s.reports=[{"day":56,"winter_results":counts}]
	check(Campaign.metrics(game.s).pass,"70 percent promise boundary failed")
	counts.tea.served=13
	check(not Campaign.metrics(game.s).pass,"Below 70 percent cleared")
	counts.tea.served=14
	game.s.reports[0].day=57
	check(not Campaign.metrics(game.s).pass,"Practice receipts rewrote the campaign result")
	game.s.reports[0].day=55;game.s.reports[0].profit=0;game.s.day=56;game.s.star=5;game.s.cash=100000;game.s.today=game.new_report(56)
	game.finish_day()
	check(game.s.day==57 and game.s.won and game.s.result=="won","Full year and both achievements did not clear")
	game.command("continue");game.finish_day()
	check(game.s.result.is_empty() and game.s.won,"Continuing the completed store triggered another ending")
	for year_report in game.s.reports:
		if year_report.day==56:year_report.cash_close=-1
	game.s.cash=1000000
	check(not Campaign.ending_qualified(game.s),"Money earned after the year rewrote the year-end finances")
	game.s.star=4;game.s.review={"status":"failed"}
	check(game.command("review").is_empty(),"Practice mode cannot retry the rating")
	print("CAMPAIGN: forecast choices, rating milestone, real purchases, final-year boundaries; ",failures.size()," failures")
	quit(1 if failures else 0)
