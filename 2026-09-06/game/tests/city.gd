extends SceneTree
const City=preload("res://core/city.gd")
const Sim=preload("res://core/simulation.gd")
const Stories=preload("res://core/resident_stories.gd")
const Nav=preload("res://core/navigation.gd")
var failures=[]
func check(value:bool,message:String):
	if not value:failures.append(message);printerr(message)
func visit(need:String) -> Dictionary:
	return {"id":900,"rid":12,"pos":Nav.DOOR,"prev":Nav.DOOR,"path":[],"state":"choose","target":-1,"basket":[],"spent":0,"budget":900,"goal":7,"wait":0,"bought":false,"dir":0,"mood":"","since":0,"need":need,"attempts":0,"wanted":-1}
func _init():
	var game=Sim.new()
	# Every advertised need has an actual product; tags must not be decorative copy.
	for day in range(1,57):
		var event=City.event(day)
		for need in event.needs:check(game.products.any(func(p):return Stories.product_matches(p.id,need)),"No product satisfies forecast "+need)
	check(City.delivery_tick(0)==480 and City.delivery_tick(480)==1440,"Normal delivery boundary changed")
	var morning=8*1440
	check(City.delivery_tick(morning)==morning+660,"Roadwork forecast and actual delivery disagree")
	check(City.delivery_tick(morning+480)==morning+1440,"Delay incorrectly extended the order cutoff")
	game.s.tick=morning;game.s.day=9;game.s.schedule=[]
	game.command("order",{"product":20,"amount":6})
	var due=game.s.orders[0].due
	game.step(480)
	check(game.s.orders.size()==1 and game.s.orders[0].due==due,"Delayed order arrived at the old time")
	game.step(180)
	check(game.s.orders.is_empty(),"Delayed delivery did not arrive at forecast time")
	game=Sim.new();game.s.star=2
	var v=visit("rain");game.s.visits=[v];game.choose(v)
	check(v.state=="leaving" and v.failure_reason=="品揃え","Newspaper substituted for an umbrella")
	check(game.s.today.unmet_needs.get("rain",0)==1 and game.s.today.lost_visits[0].reason=="品揃え","Unmet purpose not recorded")
	game.s.visits=[]
	var f=game.s.fixtures[7];f.product=73;f.lots=[game.lot(73,6)]
	v=visit("rain");game.s.visits=[v];game.choose(v)
	check(v.state=="walking" and v.wanted==73,"Customer did not choose the requested umbrella")
	f.lots=[];v=visit("rain");game.s.visits=[v];game.choose(v)
	check(v.failure_reason=="欠品","Sold-out stock confused with missing assortment")
	f.lots=[game.lot(73,6)];v=visit("rain");v.budget=10;game.s.visits=[v];game.choose(v)
	check(v.failure_reason=="予算","Budget rejection confused with stock")
	game=Sim.new();var before=game.s.today.waste;game.waste([game.lot(40,3)])
	check(game.s.today.waste-before==game.products[40].cost*3 and game.s.today.waste_products[40].amount==3,"Waste drill-down and ledger disagree")
	# A previous night's customer finishes today: conversion must stay within 0..100%.
	game=Sim.new();game.s.today.visitors=0;game.s.today.buyers=1
	v=visit("rain");v.event_id="rain";game.leave(v,true);game.leave(v,true)
	check(game.s.today.completed==1 and game.s.today.event_results.rain.buyers==1,"Departure was counted twice")
	game.finish_day()
	check(game.s.reports[0].rate==1.0,"Cross-day conversion used new arrivals as denominator")
	# Two mediocre days cannot borrow unrelated walk-ins to pass a festival.
	game=Sim.new();game.s.review={"reports":[{"sales":1000,"profit":200,"waste":0,"cogs":500,"visitors":100,"event":"pudding","rate":1.0,"event_results":{"rain":{"completed":20,"buyers":10}}}],"days":{},"cohort":[]}
	check(game.review_metrics().events==0,"Festival score included unrelated customers")
	game.s.review.reports[0].event_results.rain.buyers=16
	check(game.review_metrics().events==1,"Actual festival customers were not counted")
	print("CITY: advertised needs, delivery boundaries, requested product and rejection causes; ",failures.size()," failures")
	quit(1 if failures else 0)
