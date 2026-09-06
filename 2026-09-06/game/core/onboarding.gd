extends RefCounted
# The guide records real UI observations and the lots from a real manual order.
# It never changes money, stock, arrivals, staff, or the simulation clock.
static func state(s:Dictionary) -> Dictionary:
	if not s.has("guide"):s.guide={"hidden":s.day>1,"resident":-1,"shelf":-1,"order":{},"stocked_tick":-1,"sold":false}
	return s.guide
static func stage(s:Dictionary) -> int:
	var g=state(s)
	if g.resident<0:return 0
	if g.shelf<0:return 1
	if g.order.is_empty():return 2
	if g.stocked_tick<0:return 3
	return 5 if g.sold else 4
static func observe(game,kind:String,id:int):
	var g=state(game.s)
	if kind=="resident" and game.s.residents[id].visits>0:g.resident=id
	if kind=="fixture":
		var f=game.fixture(id)
		if not f.is_empty() and f.product>=0:g.shelf=id
static func ordered(game,order:Dictionary):
	var g=state(game.s)
	if g.order.is_empty() or (g.stocked_tick<0 and game.s.tick>=g.order.expires):
		g.order=order.duplicate(true);g.order.expires=order.due+game.products[order.product].life
static func update(game):
	var s=game.s;var g=state(s)
	if g.order.is_empty() or g.sold:return
	var p=int(g.order.product)
	if g.stocked_tick<0:
		for f in s.fixtures:
			if f.product==p and f.lots.any(func(lot):return lot.product==p and lot.expires==g.order.expires and lot.amount>0):
				g.stocked_tick=s.tick;g.shelf=f.id;break
	if g.stocked_tick>=0:
		for r in s.residents:
			for receipt in r.history:
				var at=(int(receipt.day)-1)*1440+posmod(int(receipt.get("minute",360))-360,1440)
				if at>=g.stocked_tick and receipt.get("products",[]).has(p):g.sold=true;g.buyer=r.id;return
