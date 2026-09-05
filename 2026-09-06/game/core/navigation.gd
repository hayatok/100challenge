extends RefCounted
const DIRS = [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]
const DOOR = Vector2i(1,8)
const DEPOT = Vector2i(1,1)

static func dimensions(tier: int) -> Vector2i:
	return [Vector2i(12,10),Vector2i(16,13),Vector2i(20,16)][clampi(tier,0,2)]

static func access(f: Dictionary) -> Vector2i:
	return Vector2i(f.x,f.y)+DIRS[int(f.dir)%4]

static func obstacles(fixtures: Array) -> Dictionary:
	var out={}
	for f in fixtures: out[Vector2i(f.x,f.y)]=true
	return out

static func inside(p: Vector2i, dims: Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<dims.x and p.y<dims.y

static func path(start: Vector2i, end: Vector2i, fixtures: Array, tier: int) -> Array:
	if start==end: return []
	var dims=dimensions(tier)
	var blocked=obstacles(fixtures)
	if not inside(end,dims) or blocked.has(end): return []
	var queue=[start];var prev={start:start};var cursor=0
	while cursor<queue.size():
		var at:Vector2i=queue[cursor];cursor+=1
		for d in DIRS:
			var next:Vector2i=at+d
			if not inside(next,dims) or blocked.has(next) or prev.has(next): continue
			prev[next]=at
			if next==end:
				var result=[];var p=end
				while p!=start: result.push_front(p);p=prev[p]
				return result
			queue.append(next)
	return []

static func reachable(start: Vector2i, end: Vector2i, fixtures: Array, tier:int) -> bool:
	return start==end or not path(start,end,fixtures,tier).is_empty()

static func validate(fixtures: Array, tier:int, positions: Array=[]) -> String:
	var occupied={};var dims=dimensions(tier)
	for f in fixtures:
		var p=Vector2i(f.x,f.y)
		if not inside(p,dims): return "敷地の外には置けません。"
		if p==DOOR or p==DEPOT: return "入口と倉庫への通路を空けてください。"
		if occupied.has(p): return "別の設備と重なっています。"
		occupied[p]=true
	if not reachable(DOOR,DEPOT,fixtures,tier): return "倉庫へ通れなくなります。"
	for f in fixtures:
		if not reachable(DOOR,access(f),fixtures,tier): return "設備の手前に、通れるマスが必要です。向きを変えてみましょう。"
	for p in positions:
		if occupied.has(p) or not reachable(p,DOOR,fixtures,tier): return "店内の人の通り道を塞いでしまいます。"
	return ""
