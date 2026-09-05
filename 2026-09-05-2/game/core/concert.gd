extends RefCounted
const Geo = preload("res://core/enclosure.gd")
const BOUNDS = Rect2(120,164,1040,490)
const CAP = 300
const BOSS_TIME = 150.0
const LIMIT = 210.0
const UPGRADES = {
	"burst":["オーバードライブ","回収ダメージ +2。大きな群れを一度に。",0],
	"trail":["ロング・フレーズ","軌跡の寿命 +1秒。帰り道を長く描ける。",1],
	"stage":["アンコール・ステージ","陣地の寿命 +2秒、陣地攻撃 +1。",2],
	"tempo":["アップテンポ","自動射撃を20%速く。帰り道を開く。",3],
	"speed":["軽やかなステップ","移動速度 +8%。大きく回り込める。",4],
	"heal":["差し入れキャンディ","HPを35回復。もう一曲いける。",5],
	"chain":["火花のコーラス","回収撃破から近くの敵へ爆発が広がる。",6],
	"magnet":["観客、こっち！","経験値の吸引範囲 +30px。進化で敵も吸引。",7]
}
var rng = RandomNumberGenerator.new()
var seed_value = 0
var state = "title"
var clock = 0.0
var player = Vector2(640,490)
var velocity = Vector2.ZERO
var hp = 100.0
var invulnerable = 0.0
var xp = 0.0
var level = 1
var score = 0
var kills = 0
var loops = 0
var best_loop = 0
var last_loop = 0
var rerolls = 2
var ranks = {"burst":0,"trail":0,"stage":0,"tempo":0,"speed":0,"chain":0,"magnet":0}
var enemies: Array = []
var drops: Array = []
var trail: Array = []
var stages: Array = []
var choices: Array = []
var events: Array = []
var boss: Dictionary = {}
var terminals: Array = []
var hazards: Array = []
var fire_clock = 0.0
var spawn_clock = 0.0
var next_id = 0
var sources = {"burst":0,"shot":0,"stage":0,"chain":0}
var ending = ""
var evolution_fireworks = false
var evolution_gravity = false
var chain_budget = 0

func _init(run_seed: int = 20260906) -> void:
	seed_value = run_seed
	rng.seed = run_seed

func start() -> void:
	if state not in ["title","briefing"]:
		return
	state = "running"
	trail = [{"p":player,"t":clock}]
	for i in 8:
		spawn_enemy(Vector2(470+(i%4)*35,330+(i/4)*40),0)
	emit("start",player)

func emit(kind: String, at: Vector2, extra: Dictionary = {}) -> void:
	var e = {"kind":kind,"p":at}
	e.merge(extra)
	events.append(e)
	if events.size() > 120:
		events.pop_front()

func speed() -> float:
	return 238.0*(1.0+0.08*int(ranks.speed))

func trail_life() -> float:
	return 6.0+int(ranks.trail)

func threshold() -> float:
	return 12.0+(level-1)*7.0

func pause() -> void:
	if state == "running": state = "paused"

func resume() -> void:
	if state == "paused": state = "running"

func spawn_enemy(at: Vector2, kind: int) -> void:
	if enemies.size() >= CAP: return
	next_id += 1
	var health = [2.0,3.0,7.0][clampi(kind,0,2)]
	enemies.append({"id":next_id,"p":at,"kind":kind,"hp":health,"max_hp":health,"phase":0,"timer":rng.randf_range(1.5,4.5),"dir":Vector2.ZERO,"hit":0.0})

func spawn_edge() -> void:
	var edge = rng.randi_range(0,3)
	var p = Vector2.ZERO
	match edge:
		0: p=Vector2(105,rng.randf_range(190,630))
		1: p=Vector2(1175,rng.randf_range(190,630))
		2: p=Vector2(rng.randf_range(155,1125),149)
		3: p=Vector2(rng.randf_range(155,1125),668)
	var kind = 0
	var roll = rng.randf()
	if clock>32 and roll<0.18: kind=1
	if clock>65 and roll>0.82: kind=2
	spawn_enemy(p,kind)

func step(dt: float, direction: Vector2) -> void:
	if state != "running": return
	dt = clampf(dt,0.0,0.1)
	clock += dt
	invulnerable = maxf(0.0,invulnerable-dt)
	velocity = direction.limit_length()*speed()
	player = (player+velocity*dt).clamp(BOUNDS.position,BOUNDS.end)
	while trail.size()>0 and clock-float(trail[0].t)>trail_life():
		trail.pop_front()
	if trail.is_empty(): trail.append({"p":player,"t":clock})
	if player.distance_squared_to(trail[-1].p)>=25:
		var polygon = Geo.close(trail,player,clock)
		if polygon.size()>=3:
			collect(polygon)
			trail = [{"p":player,"t":clock}]
		else:
			trail.append({"p":player,"t":clock})
	spawn_clock -= dt
	if spawn_clock<=0:
		spawn_clock += 1.0/(2.0+minf(clock/65.0,2.5))
		spawn_edge()
	for enemy in enemies:
		if enemy.hp<=0: continue
		enemy.hit = maxf(0.0,float(enemy.hit)-dt)
		move_enemy(enemy,dt)
		if enemy.p.distance_squared_to(player)<pow(18.0 if enemy.kind==2 else 15.0,2):
			hurt(4)
			enemy.p += (enemy.p-player).normalized()*16
	for stage in stages:
		stage.life -= dt
		stage.fire -= dt
		if stage.life>0 and stage.fire<=0:
			stage.fire += 0.65
			var targets: Array = []
			for enemy in enemies:
				if enemy.hp>0 and Geo.contains(enemy.p,stage.polygon): targets.append(enemy)
			if targets.is_empty():
				var near = nearest(stage.center,150)
				if not near.is_empty(): targets.append(near)
			for i in mini(2,targets.size()):
				hit(targets[i],1.0+int(ranks.stage),"stage")
				emit("beam",stage.center,{"to":targets[i].p,"stage":true})
			if not boss.is_empty() and boss.open>0 and Geo.contains(boss.p,stage.polygon):
				damage_boss(1+int(ranks.stage),"stage")
	stages = stages.filter(func(s):return s.life>0)
	fire_clock -= dt
	if fire_clock<=0:
		fire_clock += 0.72*pow(0.8,int(ranks.tempo))
		var target = nearest(player,330)
		if not boss.is_empty() and boss.hp>0 and boss.open>0 and player.distance_to(boss.p)<430:
			damage_boss(3.0,"shot")
			emit("beam",player,{"to":boss.p})
		elif not target.is_empty():
			hit(target,1.0,"shot")
			target.p += (target.p-player).normalized()*6
			emit("beam",player,{"to":target.p})
	for drop in drops:
		var distance = drop.p.distance_to(player)
		if distance<65+int(ranks.magnet)*30:
			drop.p = drop.p.move_toward(player,(250+distance)*dt)
		if drop.p.distance_to(player)<17 and drop.value>0:
			xp += drop.value
			drop.value = 0
	drops = drops.filter(func(d):return d.value>0)
	enemies = enemies.filter(func(e):return e.hp>0)
	if clock>=BOSS_TIME and boss.is_empty(): spawn_boss()
	update_boss(dt)
	if hp<=0:
		finish(false,"声を整えて、もう一度。")
	elif not boss.is_empty() and boss.hp<=0:
		finish(true,"雨灯横丁の明かりが、戻った。")
	elif clock>=LIMIT:
		finish(false,"閉演時刻。今日は、ここまで。")
	else:
		check_level()

func move_enemy(e: Dictionary, dt: float) -> void:
	var direction: Vector2 = (player-e.p).normalized()
	var pace = [40.0,61.0,28.0][int(e.kind)]
	if e.kind==1:
		e.timer -= dt
		if e.phase==0 and e.timer<=0:
			e.phase=1; e.timer=0.75; e.dir=direction
		elif e.phase==1:
			pace=0
			if e.timer<=0: e.phase=2; e.timer=0.70
		elif e.phase==2:
			direction=e.dir; pace=250
			if e.timer<=0: e.phase=0; e.timer=rng.randf_range(3.0,5.0)
	if evolution_gravity:
		for stage in stages:
			if e.p.distance_to(stage.center)<180:
				direction=direction.lerp((stage.center-e.p).normalized(),0.65).normalized()
				break
	e.p = (e.p+direction*pace*dt).clamp(Vector2(85,130),Vector2(1195,680))

func nearest(at: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var distance = radius*radius
	for enemy in enemies:
		var d = at.distance_squared_to(enemy.p)
		if enemy.hp>0 and d<distance:
			distance=d; best=enemy
	return best

func hurt(amount: float) -> void:
	if invulnerable>0 or hp<=0: return
	hp=maxf(0,hp-amount)
	invulnerable=1.2
	emit("hurt",player)

func hit(enemy: Dictionary, amount: float, source: String, generation: int = 0) -> void:
	if enemy.hp<=0: return
	enemy.hp -= amount
	enemy.hit = 0.13
	if enemy.hp>0: return
	kills += 1
	score += 10
	sources[source] += 1
	emit("pop",enemy.p,{"size":1.5 if enemy.kind==2 else 1.0})
	if source=="burst": xp+=1.3
	elif drops.size()<200: drops.append({"p":enemy.p,"value":1.0})
	else: xp+=1.0
	if (source=="burst" or source=="chain") and int(ranks.chain)>0 and generation<(3 if evolution_fireworks else 1):
		var budget = 0
		for other in enemies:
			if other.hp>0 and chain_budget<100 and other.p.distance_squared_to(enemy.p)<pow(40+12*int(ranks.chain),2):
				chain_budget+=1
				hit(other,2+int(ranks.chain),"chain",generation+1)
				budget+=1
				if budget>=10: break

func collect(polygon: PackedVector2Array) -> void:
	loops+=1
	chain_budget=0
	var before = kills
	for enemy in enemies:
		if enemy.hp>0 and Geo.contains(enemy.p,polygon): hit(enemy,4+2*int(ranks.burst),"burst")
	for drop in drops:
		if drop.value>0 and Geo.contains(drop.p,polygon):
			xp+=drop.value; drop.value=0
	for terminal in terminals:
		if terminal.active and Geo.contains(terminal.p,polygon):
			terminal.active=false; boss.open=10.0
			emit("unlock",terminal.p)
	if not boss.is_empty() and boss.hp>0 and Geo.contains(boss.p,polygon):
		damage_boss(minf(4+2*int(ranks.burst),float(boss.max_hp)*0.08),"burst")
	last_loop=kills-before
	# Audience candy rewards deliberate group collection, not idle survival.
	if hp>0: hp=minf(100,hp+mini(9,(last_loop/5)*3))
	best_loop=maxi(best_loop,last_loop)
	score+=last_loop*5+int(Geo.area(polygon)/1000)
	var center = Vector2.ZERO
	for p in polygon: center+=p
	center/=polygon.size()
	stages.append({"polygon":polygon,"life":8.0+2*int(ranks.stage),"max_life":8.0+2*int(ranks.stage),"center":center,"fire":0.1})
	if stages.size()>3: stages.pop_front()
	emit("loop",center,{"count":last_loop,"polygon":polygon})

func check_level() -> void:
	if state=="running" and xp>=threshold():
		state="upgrade"
		make_choices()
		emit("upgrade",player)

func make_choices() -> void:
	var pool: Array = []
	for key in UPGRADES:
		if key=="heal":
			if hp<90: pool.append(key)
		elif int(ranks[key])<3: pool.append(key)
	choices=[]
	if hp<45 and "heal" in pool:
		choices.append("heal");pool.erase("heal")
	while choices.size()<3 and not pool.is_empty():
		var i=rng.randi_range(0,pool.size()-1)
		choices.append(pool.pop_at(i))
	if choices.is_empty(): choices=["heal"]

func choose(index: int) -> void:
	if state!="upgrade" or index<0 or index>=choices.size(): return
	var key: String=choices[index]
	xp-=threshold()
	level+=1
	if key=="heal": hp=minf(100,hp+35)
	else: ranks[key]+=1
	if not evolution_fireworks and ranks.burst>=2 and ranks.chain>=2:
		evolution_fireworks=true; emit("evolution",player,{"name":"連鎖花火"})
	if not evolution_gravity and ranks.stage>=2 and ranks.magnet>=2:
		evolution_gravity=true; emit("evolution",player,{"name":"ブラックホール・ステージ"})
	state="running"
	check_level()

func reroll() -> void:
	if state=="upgrade" and rerolls>0:
		rerolls-=1
		make_choices()

func spawn_boss() -> void:
	boss={"p":Vector2(640,320),"hp":96.0,"max_hp":96.0,"open":0.0,"fire":3.0,"terminal_clock":0.0}
	terminals=[{"p":Vector2(462,390),"active":true},{"p":Vector2(818,455),"active":true}]
	emit("boss",boss.p)

func damage_boss(amount: float, source: String) -> void:
	if boss.is_empty() or boss.hp<=0 or boss.open<=0: return
	if source=="burst": amount=minf(amount,float(boss.max_hp)*0.08)
	boss.hp=maxf(0,float(boss.hp)-amount)
	emit("boss_hit",boss.p)

func update_boss(dt: float) -> void:
	if boss.is_empty() or boss.hp<=0: return
	boss.open=maxf(0,float(boss.open)-dt)
	boss.fire-=dt
	boss.terminal_clock+=dt
	if boss.terminal_clock>=12:
		boss.terminal_clock=0.0
		for t in terminals: t.active=true
	if boss.fire<=0:
		boss.fire=3.8
		var vertical = rng.randf()>0.5
		hazards.append({"axis":0 if vertical else 1,"coordinate":player.x if vertical else player.y,"warning":1.0,"life":1.3,"fired":false})
	for hazard in hazards:
		hazard.warning-=dt; hazard.life-=dt
		if hazard.warning<=0 and not hazard.fired:
			hazard.fired=true
			var distance=absf((player.x if hazard.axis==0 else player.y)-float(hazard.coordinate))
			if distance<28: hurt(18)
			emit("strike",Vector2(hazard.coordinate,390) if hazard.axis==0 else Vector2(640,hazard.coordinate))
	hazards=hazards.filter(func(h):return h.life>0)

func finish(won: bool, message: String) -> void:
	if state in ["won","lost"]: return
	state="won" if won else "lost"
	ending=message
	if won: score+=500
	emit("win" if won else "lose",player)
