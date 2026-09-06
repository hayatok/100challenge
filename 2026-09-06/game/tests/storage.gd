extends SceneTree
const Sim=preload("res://core/simulation.gd")
const Strategy=preload("res://tests/strategy.gd")
var failures=[]
func check(ok:bool,message:String):
	if not ok:failures.append(message);printerr("FAIL: ",message)
func _init():
	var game=Sim.new()
	for p in game.products:
		check(game.equipment.any(func(e):return e.unlock<=p.unlock and game.compatible({"kind":e.id},p.id)),"No available equipment for "+p.name)
	for pair in [[14,41],[14,49],[13,40],[12,10],[4,73],[3,60],[1,20],[0,0]]:
		check(game.compatible({"kind":pair[0]},pair[1]),"Correct storage rejected: "+str(pair))
	for pair in [[14,40],[14,20],[1,41],[13,49],[13,20],[12,70],[4,10],[0,60],[3,0]]:
		check(not game.compatible({"kind":pair[0]},pair[1]),"Wrong storage accepted: "+str(pair))
	game.s.star=1
	var before=var_to_bytes(game.s)
	check(not game.command("assign",{"fixture":4,"product":41}).is_empty(),"Ice cream accepted by refrigerator")
	check(var_to_bytes(game.s)==before,"Rejected assignment mutated inventory or money")
	# Old specialist assignments and carried stock survive a full warehouse unchanged.
	game.s.erase("storage_version");game.fixture(4).product=41;game.fixture(4).lots=[game.lot(41,12,900)]
	game.s.warehouse=[game.lot(0,220,1200)];game.s.staff[0].carry=[game.lot(20,5,1500)]
	var expected=inventory(game);var cash=game.s.cash
	check(not game.restore_storage_state().is_empty(),"Old incompatible shelf needs a visible migration notice")
	check(game.fixture(4).product==-1 and inventory(game)==expected and game.s.cash==cash,"Migration discarded stock, renewed expiry or changed cash")
	check(game.restore_storage_state().is_empty() and inventory(game)==expected,"Migration repeated its changes")
	check(game.command("assign",{"fixture":4,"product":20}).is_empty(),"Temporary warehouse overflow prevented assigning an empty shelf")
	# Build a freezer with earned money and unlocks, then buy and sell its goods normally.
	game=Sim.new();var strategy=Strategy.new("staples")
	while game.s.star<1 and game.s.day<10 and game.s.result.is_empty():
		strategy.update(game);game.step(480);strategy.update(game);game.step(960)
	check(game.s.star>=1,"Normal operation did not unlock the freezer")
	check(strategy.do(game,"place",{"kind":14,"x":8,"y":7,"dir":1}).is_empty(),"Earned funds could not build a freezer")
	var freezer=game.fixture(game.s.next_fixture-1)
	check(strategy.do(game,"assign",{"fixture":freezer.id,"product":41}).is_empty(),"Cannot assign ice cream")
	check(strategy.do(game,"order",{"product":41,"amount":12}).is_empty(),"Cannot order ice cream")
	strategy.do(game,"target",{"product":41,"amount":12})
	var stocked=false;var sold=0
	for minute in 4320:
		game.step()
		stocked=stocked or game.counts(freezer.lots)>0
		sold=game.s.today.product_sales.get(41,0)
		for report in game.s.reports:sold+=report.product_sales.get(41,0)
		if stocked and sold>0:break
	check(stocked and sold>0,"Ice cream did not travel from order through staff replenishment to checkout")
	if "--qa" in OS.get_cmdline_user_args():
		var save=FileAccess.open("user://qa-current.save",FileAccess.WRITE);save.store_var({"game":game.s,"settings":{}});save.close()
		var log=FileAccess.open("res://../docs/beta-storage-actions.json",FileAccess.WRITE);log.store_string(JSON.stringify({"seed":game.s.seed,"tick":game.s.tick,"commands":strategy.commands,"sold":sold},"\t"));log.close()
	print("STORAGE: equipment compatibility, unlocks, migration and normal freezer sale; ",failures.size()," failures; day=",game.s.day," cash=",game.s.cash," ice creams sold=",sold)
	quit(1 if failures else 0)
func inventory(game) -> Array:
	var lots=game.s.warehouse.duplicate(true)
	for f in game.s.fixtures:lots.append_array(f.lots.duplicate(true))
	for w in game.s.staff:lots.append_array(w.carry.duplicate(true))
	lots.sort_custom(func(a,b):return str(a)<str(b))
	return lots
