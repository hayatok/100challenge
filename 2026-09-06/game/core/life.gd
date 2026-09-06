extends RefCounted
# Presentation reads actual visits and receipts, without changing simulation state.
static func products(game,actor:Dictionary) -> Array:
	if actor.bought:
		if actor.has("purchase"):return actor.purchase.products
		var history=game.s.residents[actor.rid].history
		return history[0].get("products",[]) if not history.is_empty() else []
	return actor.basket.map(func(lot):return int(lot.product))
static func purchased_at(game,actor:Dictionary) -> int:
	if actor.has("purchase"):return actor.purchase.at
	var history=game.s.residents[actor.rid].history
	if not actor.bought or history.is_empty():return -99999
	var receipt=history[0]
	return (int(receipt.day)-1)*1440+posmod(int(receipt.get("minute",360))-360,1440)
static func appearance(game,actor:Dictionary,staff:bool=false,reduced:bool=false) -> Dictionary:
	if staff:return {"pose":"carry" if not actor.carry.is_empty() else "idle","prop":"box" if not actor.carry.is_empty() else "","umbrella":0}
	var ids=products(game,actor)
	var prop="bag" if actor.bought else ("basket" if not ids.is_empty() else "")
	if ids.has(13) or ids.has(17):prop+="_long"
	var pose="carry" if not prop.is_empty() else "idle"
	if actor.state=="browsing":pose="surprised" if actor.get("wanted",-1)==53 else "browse"
	elif actor.state in ["queue","browse_queue"] and actor.wait>8:pose="wait"
	elif actor.bought and not reduced and game.s.tick-purchased_at(game,actor) in range(3):pose="joy"
	var rain=game.weather_for(game.s.day)=="雨"
	# Some residents forgot their umbrella. People explicitly shopping for one all did.
	var brought=actor.rid%3!=0 and not "rain" in actor.get("need","")
	var has_umbrella=(rain and brought) or (actor.bought and ids.has(73))
	var umbrella=(2 if rain and actor.pos.x<0 else 1) if has_umbrella else 0
	return {"pose":pose,"prop":prop,"umbrella":umbrella}
