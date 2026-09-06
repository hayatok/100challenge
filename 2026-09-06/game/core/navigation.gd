extends RefCounted
const DIRS = [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]
const DOOR = Vector2i(0,8)
const EXIT_DOOR = Vector2i(0,9)
const DEPOT = Vector2i(1,1)

static func dimensions(tier: int) -> Vector2i:
	return [Vector2i(12,10),Vector2i(16,13),Vector2i(20,16)][clampi(tier,0,2)]
static func access(f: Dictionary) -> Vector2i:
	return Vector2i(f.x,f.y)+DIRS[int(f.dir)%4]
static func clerk(f: Dictionary) -> Vector2i:
	return Vector2i(f.x,f.y)-DIRS[int(f.dir)%4]
static func is_register(f:Dictionary) -> bool:
	return int(f.get("kind",-1)) in [2,10,18]
static func backroom(p:Vector2i) -> bool:
	return p.x>=0 and p.x<2 and p.y>=0 and p.y<3
static func staff_equipment(f:Dictionary) -> bool:
	return int(f.get("kind",-1)) in [5,6,19]
static func street_end(tier:int,far_end:bool=false) -> Vector2i:
	return Vector2i(-1 if far_end else -2,dimensions(tier).y+3 if far_end else -3)
static func street_start(tier:int,far_end:bool=false) -> Vector2i:
	return Vector2i(-2 if far_end else -1,dimensions(tier).y+3 if far_end else -3)
static func obstacles(fixtures:Array,staff:bool=true) -> Dictionary:
	var out={}
	if not staff:
		for x in 2:
			for y in 3:out[Vector2i(x,y)]=true
	for f in fixtures:
		out[Vector2i(f.x,f.y)]=true
		if not staff and is_register(f):out[clerk(f)]=true
	return out
static func inside(p:Vector2i,dims:Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<dims.x and p.y<dims.y
static func walkable(p:Vector2i,dims:Vector2i) -> bool:
	return inside(p,dims) or (p.x>=-3 and p.x<0 and p.y>=-3 and p.y<=dims.y+3)
static func connected(a:Vector2i,b:Vector2i) -> bool:
	# The third pavement lane leaves room to yield at the curb and street ends.
	# Keep opposite sidewalk traffic in separate walking lanes.
	if a.x==b.x and a.x==-2:return b.y<a.y
	if a.x==b.x and a.x==-1:return b.y>a.y
	# The facade is a wall. Only the doorway joins the sidewalk and shop.
	if a.x<0 and b.x>=0:return b==DOOR and a==DOOR+Vector2i.LEFT
	if a.x>=0 and b.x<0:return a in [DOOR,EXIT_DOOR] and b==a+Vector2i.LEFT
	if backroom(a)!=backroom(b):return (a==DEPOT and b==Vector2i(2,1)) or (b==DEPOT and a==Vector2i(2,1))
	return true
static func path(start:Vector2i,end:Vector2i,fixtures:Array,tier:int,staff:bool=false,avoid:Dictionary={}) -> Array:
	if start==end:return []
	var dims=dimensions(tier);var blocked=obstacles(fixtures,staff)
	blocked.merge(avoid,true)
	if not walkable(end,dims) or blocked.has(end):return []
	var queue=[start];var prev={start:start};var cursor=0
	while cursor<queue.size():
		var at:Vector2i=queue[cursor];cursor+=1
		for d in DIRS:
			var next:Vector2i=at+d
			if not walkable(next,dims) or not connected(at,next) or blocked.has(next) or prev.has(next):continue
			prev[next]=at
			if next==end:
				var result=[];var p=end
				while p!=start:result.push_front(p);p=prev[p]
				return result
			queue.append(next)
	return []
static func reachable(start:Vector2i,end:Vector2i,fixtures:Array,tier:int,staff:bool=false) -> bool:
	return start==end or not path(start,end,fixtures,tier,staff).is_empty()
static func walk_region(start:Vector2i,fixtures:Array,tier:int,avoid:Dictionary={}) -> Dictionary:
	var blocked=obstacles(fixtures,false);blocked.merge(avoid,true)
	var dims=dimensions(tier);var queue=[start];var visited={start:true};var cursor=0
	while cursor<queue.size():
		var at:Vector2i=queue[cursor];cursor+=1
		for d in DIRS:
			var next:Vector2i=at+d
			if not walkable(next,dims) or not connected(at,next) or blocked.has(next) or visited.has(next):continue
			visited[next]=true;queue.append(next)
	return visited
static func waiting_cells(fixtures:Array,tier:int,avoid:Dictionary={}) -> Dictionary:
	# Removing a non-articulation cell cannot divide the shop's walking space.
	# One graph traversal replaces a flood-fill for every possible waiting spot.
	var blocked=obstacles(fixtures,false);blocked.merge(avoid,true)
	var dims=dimensions(tier);var graph={}
	for x in dims.x:
		for y in dims.y:
			var at=Vector2i(x,y)
			if blocked.has(at):continue
			graph[at]=[]
			for d in DIRS:
				var next=at+d
				if inside(next,dims) and not blocked.has(next) and connected(at,next):graph[at].append(next)
	var context={"graph":graph,"order":{},"low":{},"cuts":{},"time":0}
	if graph.has(DOOR):_wait_dfs(DOOR,DOOR,context)
	var safe={}
	for cell in context.order:
		if not context.cuts.has(cell):safe[cell]=true
	return safe
static func _wait_dfs(at:Vector2i,parent:Vector2i,context:Dictionary):
	context.time+=1;context.order[at]=context.time;context.low[at]=context.time
	var children=0
	for next in context.graph[at]:
		if not context.order.has(next):
			children+=1;_wait_dfs(next,at,context)
			context.low[at]=mini(context.low[at],context.low[next])
			if parent!=at and context.low[next]>=context.order[at]:context.cuts[at]=true
		elif next!=parent:context.low[at]=mini(context.low[at],context.order[next])
	if parent==at and children>1:context.cuts[at]=true
static func queue_cells(f:Dictionary,fixtures:Array,tier:int) -> Array:
	var head=access(f);var d:Vector2i=DIRS[int(f.dir)%4]
	var best=[];var blocked=obstacles(fixtures,false);var dims=dimensions(tier)
	for tangent in [Vector2i(d.y,-d.x),Vector2i(-d.y,d.x)]:
		var cells=[]
		for i in 4:
			var p=head+tangent*i
			if not inside(p,dims) or blocked.has(p) or p in [DOOR,EXIT_DOOR,DOOR+Vector2i.RIGHT,DEPOT]:break
			cells.append(p)
		if cells.size()>best.size():best=cells
	return best
static func browse_cells(f:Dictionary,fixtures:Array,tier:int) -> Array:
	var head=access(f);var d:Vector2i=DIRS[int(f.dir)%4]
	var blocked=obstacles(fixtures,false);var dims=dimensions(tier)
	for other in fixtures:
		if other.id!=f.id:blocked[access(other)]=true
		if is_register(other):
			for cell in queue_cells(other,fixtures,tier):blocked[cell]=true
	var best=[head]
	for tangent in [Vector2i(d.y,-d.x),Vector2i(-d.y,d.x)]:
		var cells=[head]
		for i in range(1,3):
			var at=head+tangent*i
			if not inside(at,dims) or blocked.has(at) or at in [DOOR,EXIT_DOOR,DOOR+Vector2i.RIGHT,DEPOT]:break
			cells.append(at)
		if cells.size()>best.size():best=cells
	return best

static func validate(fixtures:Array,tier:int,positions:Array=[],strict:bool=true) -> String:
	var occupied={};var dims=dimensions(tier)
	for f in fixtures:
		var p=Vector2i(f.x,f.y)
		if not inside(p,dims):return "敷地の外には置けません。"
		if p in [DOOR,EXIT_DOOR,DEPOT,DOOR+Vector2i.RIGHT]:return "出入口と倉庫への通路を空けてください。"
		if occupied.has(p):return "別の設備と重なっています。"
		if backroom(p) and not staff_equipment(f):return "倉庫の中には売り場を置けません。"
		occupied[p]=true
	if not reachable(DOOR,DEPOT,fixtures,tier,true):return "倉庫へ通れなくなります。"
	var reserved={}
	for f in fixtures:
		if not reachable(DOOR,access(f),fixtures,tier,not strict or staff_equipment(f)):return "設備の手前に、通れるマスが必要です。向きを変えてみましょう。"
		if strict and is_register(f):
			if not inside(clerk(f),dims) or not reachable(DEPOT,clerk(f),fixtures,tier,true):return "レジの裏側に、店員が立てる通路を空けてください。"
			var cells=queue_cells(f,fixtures,tier)
			if cells.size()<3:return "レジの正面から横へ3マス以上、待機列を空けてください。"
			for p in cells:
				if reserved.has(p):return "レジの待機列が重なります。位置か向きを変えてください。"
				reserved[p]=true
	for f in fixtures:
		if strict and not is_register(f) and reserved.has(access(f)):return "売り場の利用面がレジの待機列と重なります。"
	for p in positions:
		if occupied.has(p) or not reachable(p,DOOR,fixtures,tier,true):return "店内の人の通り道を塞いでしまいます。"
	return ""
