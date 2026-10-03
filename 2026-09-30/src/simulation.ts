import { DAY_SECONDS, SIM_STEP, EVENT_LIMIT, HISTORY_LIMIT } from './constants.ts';
import { applyPendingPowers, advanceDisasters, isPassable } from './disasters.ts';
import { advanceResidents, depart, findRoute, jobCapacity, neighbors, newResident, residentCell, synchronizeResidents } from './mobility.ts';
export { advanceResidents } from './mobility.ts';
import type { Cell, CellKind, Economy, PowerCommand, Resident, TownEvent, TownStats, Weather, World } from './types.ts';
const KINDS: CellKind[] = ['grass','tree','water','road','house','shop','farm','factory','ruin','park'];
const BUILDINGS = new Set<CellKind>(['house','shop','farm','factory']);
const clamp = (v: number, low = 0, high = 100) => Math.max(low, Math.min(high, v));
function random(world: World): number {
  world.rng = (world.rng + 0x6d2b79f5) >>> 0;
  let v = world.rng; v = Math.imul(v ^ (v >>> 15), v | 1); v ^= v + Math.imul(v ^ (v >>> 7), v | 61);
  return ((v ^ (v >>> 14)) >>> 0) / 4294967296;
}
function emptyStats(): TownStats { return { population: 0, homes: 0, shops: 0, farms: 0, factories: 0, ruins: 0, roads: 0, environment: 0, jobs: 0, born: 0, retired: 0 }; }
function defaultEconomy(): Economy { return { workers: 0, employed: 0, food: 0, harvest: 0, visits: 0, commutes: 0, materials: 0, starving: 0, evacuated: 0, deaths: 0, births: 0, arrivals: 0, departures: 0, failedPurchases: 0 }; }
function defaultWeather(size: number): Weather { return { kind: 'clear', temperature: 18, rainfall: 0, cloud: 0, windX: .1, windY: .04, remaining: DAY_SECONDS, frontX: size / 2, frontY: size / 2, frontRadius: size }; }
function statistics(world: World): TownStats {
  const result = emptyStats(); let environment = 0, land = 0;
  for (const cell of world.cells) { result.jobs += jobCapacity(cell); const key = ({house:'homes',shop:'shops',farm:'farms',factory:'factories',ruin:'ruins',road:'roads'} as const)[cell.kind as 'house']; if (key) result[key]++; if (cell.terrain === 'land') { environment += cell.environment; land++; } }
  result.population = world.residents.length; result.environment = Math.round(environment / Math.max(1, land)); result.born = world.stats.born; result.retired = world.stats.retired; return result;
}
function reconcile(world: World): void {
  for (const cell of world.cells) cell.population = 0;
  for (const person of world.residents) if (world.cells[person.home].kind === 'house') world.cells[person.home].population++;
  world.stats = statistics(world); world.economy.workers = world.residents.filter(p => p.role === 'worker').length; world.economy.employed = world.residents.filter(p => p.workplace !== null).length;
  world.economy.food = world.cells.reduce((s,c) => s+c.stock,0) + world.residents.reduce((s,p) => s+p.food,0) + world.shipments.reduce((s,c) => s+c.food,0);
  world.economy.materials = world.cells.reduce((s,c) => s+c.materials,0) + world.shipments.reduce((s,c) => s+c.materials,0); world.economy.starving = world.residents.filter(p => p.hunger > 1).length; world.economy.evacuated = world.residents.filter(p => p.displaced).length;
}
function setKind(cell: Cell, kind: CellKind, tick: number, reason: string): void { cell.kind = kind; cell.age = 0; cell.level = BUILDINGS.has(kind) ? 1 : 0; cell.population = kind === 'house' ? 6 : 0; cell.vitality = BUILDINGS.has(kind) ? 72 : 0; cell.reason = reason; cell.changedAt = tick; cell.condition = kind === 'road' || BUILDINGS.has(kind) ? 88 : 0; cell.development = 0; cell.employed = 0; cell.customers = 0; cell.crop = kind === 'farm' ? 10 : 0; cell.work = 0; cell.closed = false; cell.buildingPlan = null; }
function event(world: World, cell: Cell, kind: TownEvent['kind'], text: string): void { world.events.push({ tick: world.tick, x: cell.x, y: cell.y, kind, text }); if (world.events.length > EVENT_LIMIT) world.events.shift(); }
export function createWorld(seed: number, size = 48): World {
  if (!Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw new Error('街の種は0〜4294967295の整数で指定してください。');
  if (!Number.isInteger(size) || size < 24 || size > 64) throw new Error('街の大きさは24〜64の整数で指定してください。');
  const world: World = { version: 3, step: 0, remainder: 0, revision: 0, topologyVersion: 0, hazardRng: (seed ^ 0x9e3779b9) >>> 0, nextCommandId: 0, pending: [], effects: [], shipments: [], nextShipmentId: 0, naturalPolicy: 'gentle', migrationGrace: DAY_SECONDS * 3, clock: 0, nextResidentId: 0, residents: [], weather: defaultWeather(size), economy: defaultEconomy(), seed, rng: seed, size, tick: 0, cells: [], stats: emptyStats(), events: [], history: [] };
  const phase = random(world) * Math.PI * 2;
  const riverOffset = (random(world) - .5) * size * .06;
  for (let y = 0; y < size; y++) {
    const river = size * .5 + riverOffset + Math.sin(y / size * Math.PI * 2 + phase) * size * .07;
    for (let x = 0; x < size; x++) {
      const water = Math.abs(x - river) < 1.4;
      const woods = Math.sin(x * .21 + phase) * Math.cos(y * .17 - phase) > .28;
      const tree = !water && random(world) < (woods ? .72 : .07);
      world.cells.push({ x, y, terrain: water ? 'water' : 'land', kind: water ? 'water' : tree ? 'tree' : 'grass', level: 0, age: tree ? 48 : 0, population: 0, vitality: 0, environment: water ? 90 : tree ? 94 : 78, traffic: 0, variant: Math.floor(random(world) * 8), reason: water ? '川の流れが、この土地をうるおしています。' : tree ? '林が空気を整え、生きものの居場所を守っています。' : '水と緑に囲まれた、まだ静かな草地です。', changedAt: 0, moisture: water ? 100 : 55, fertility: tree ? 85 : 72, vegetation: tree ? 90 : 35, crop: 0, condition: 0, development: 0, employed: 0, customers: 0, accessible: false, elevation: water ? 0 : 2 + Math.abs(x - river) * .12, waterDepth: water ? 1 : 0, fire: 0, snow: 0, rubble: 0, crater: 0, stock: 0, materials: 0, work: 0, region: -1, closed: false, buildingPlan: null });
    }
  }
  const roadAt = (x: number, y: number) => {
    const cell = world.cells[y * size + x];
    setKind(cell, 'road', 0, cell.terrain === 'water' ? '二つの集落を結ぶ橋。川の向こうへ仕事と暮らしを運びます。' : '集落をつなぐ道。沿道に人と仕事が集まります。');
  };
  const trunkY = Math.floor(size * .52);
  const centers = [Math.floor(size * .25), Math.floor(size * .74)];
  for (let x = centers[0] - 4; x <= centers[1] + 4; x++) roadAt(x, trunkY);
  for (const centerX of centers) {
    for (let y = trunkY - 5; y <= trunkY + 5; y++) roadAt(centerX, y);
    for (let x = centerX - 4; x <= centerX + 4; x++) roadAt(x, trunkY - 3);
    const lots: [number, number, CellKind][] = [
      [-1, -1, 'house'], [1, -1, 'house'], [-1, 1, 'house'], [1, 1, 'house'],
      [-2, -2, 'house'], [2, -2, 'house'], [-3, 1, 'house'], [3, 1, 'house'],
      [-1, -4, 'farm'], [1, -4, 'farm'], [-3, -4, 'farm'], [3, -4, 'farm'],
      [-2, 1, 'shop'], [2, 1, 'shop'], [-1, 3, 'park'], [1, 3, 'park'], [-1, 4, 'factory'], [1, 4, 'farm'],
    ];
    for (const [dx, dy, kind] of lots) {
      const cell = world.cells[(trunkY + dy) * size + centerX + dx];
      if (cell.terrain === 'water') continue;
      setKind(cell, kind, 0, kind === 'house' ? '道と畑のそばに、小さな集落ができました。' : kind === 'farm' ? '川に近い土地を耕し、集落の食と仕事を支えています。' : kind === 'shop' ? '集落の住民が通う、道沿いの小さな商店です。' : '集落の端で、暮らしを支える仕事が生まれました。');
      cell.age = Math.floor(random(world) * 24); cell.stock = kind === 'shop' ? 70 : kind === 'farm' ? 35 : kind === 'house' ? 8 : 0; cell.materials = kind === 'factory' ? 40 : 8;
    }
  }
  for (const [home, cell] of world.cells.entries()) if (cell.kind === 'house') for (let n = 0; n < cell.population; n++) world.residents.push(newResident(world, home, n % 3 === 2 ? 'dependent' : 'worker'));
  reconcile(world);
  world.events.push({ tick: 0, x: centers[0], y: trunkY, kind: 'birth', text: '川をはさんだ二つの集落から、町の時間が始まります。' });
  world.history.push({ tick: 0, population: world.stats.population });
  synchronizeResidents(world); reconcile(world);
  return world;
}


function settle(world: World, command: PowerCommand): void {
  const candidates = world.cells.flatMap((c, i) => c.terrain === 'land' && ['grass','tree','ruin','park'].includes(c.kind) && isPassable(c) && c.fire < 1 && c.rubble < 20 && Math.hypot(c.x-command.target.x,c.y-command.target.y) <= command.radius ? [i] : []).sort((a,b) => Math.hypot(world.cells[a].x-command.target.x,world.cells[a].y-command.target.y)-Math.hypot(world.cells[b].x-command.target.x,world.cells[b].y-command.target.y) || a-b);
  if (!candidates.length) { event(world,world.cells[Math.round(command.target.y)*world.size+Math.round(command.target.x)],'refuge','危険な土地には入植できず、住民は到着を見合わせました。'); return; }
  const footprint=[[-2,0],[-1,0],[0,0],[1,0],[2,0],[-1,-1],[1,-1],[0,-1],[-1,1],[1,1],[2,1]];
  const site=candidates.find(index=>footprint.every(([dx,dy])=>{const c=world.cells[index],x=c.x+dx,y=c.y+dy;if(x<0||y<0||x>=world.size||y>=world.size)return false;const p=world.cells[y*world.size+x];return p.terrain==='land'&&isPassable(p)&&['grass','tree','ruin','park','road'].includes(p.kind)&&p.fire<1&&p.rubble<20;}));
  if(site===undefined){event(world,world.cells[candidates[0]],'refuge','安全な仮住居と畑を置く土地が足りず、入植者は到着を見合わせました。');return;}
  const center = world.cells[site], x = center.x, y = center.y;
  const place = (dx: number,dy: number,kind: CellKind): number | null => {
    const xx=x+dx, yy=y+dy; if(xx<0||yy<0||xx>=world.size||yy>=world.size) return null;
    const index=yy*world.size+xx, cell=world.cells[index]; if(cell.terrain!=='land'||!isPassable(cell)||!['grass','tree','ruin','park','road'].includes(cell.kind)||cell.rubble>20) return null;
    setKind(cell,kind,world.tick,'入植者が持参した食・道具・資材で、小さな暮らしを始めています。'); cell.population=0; cell.materials=kind==='factory'?45:12; cell.stock=kind==='shop'?100:kind==='farm'?45:kind==='house'?18:0; cell.crop=kind==='farm'?65:0; cell.rubble=0; return index;
  };
  for(let dx=-2;dx<=2;dx++) place(dx,0,'road');
  const homes=[place(-1,-1,'house'),place(1,-1,'house')].filter((i):i is number=>i!==null);
  place(-1,1,'farm');place(1,1,'farm');place(0,-1,'shop');place(2,1,'factory');
  for(const home of homes) for(let n=0;n<6;n++) {const person=newResident(world,home,n%3===2?'dependent':'worker');person.food=5;world.residents.push(person);world.economy.arrivals++;}
  world.topologyVersion++; synchronizeResidents(world); reconcile(world); event(world,center,'refuge',`食と修繕資材、仮住居と農具を持った${homes.length*6}人が入植しました。`);
}

/** Shipment inventory is removed at dispatch and remains cargo while a bridge is blocked. */
function advanceShipments(world: World): void {
  for(const cargo of world.shipments) {
    let remaining=SIM_STEP;
    while(remaining>1e-10&&cargo.routeIndex<cargo.route.length-1) {
      const next=world.cells[cargo.route[cargo.routeIndex+1]];
      cargo.blocked=!isPassable(next);
      if(cargo.blocked)break;
      const consumed=Math.min(remaining,(1-cargo.progress)/1.5);
      cargo.progress=Math.min(1,cargo.progress+consumed*1.5);remaining-=consumed;
      if(cargo.progress>=1-1e-10){cargo.routeIndex++;cargo.progress=0;}
      if(cargo.routeIndex===cargo.route.length-1){const cell=world.cells[cargo.to];cell.stock+=cargo.food;cell.materials+=cargo.materials;cargo.food=0;cargo.materials=0;}
    }
  }
  world.shipments=world.shipments.filter(c=>c.routeIndex<c.route.length-1);
}
function dispatch(world: World): void {
  const requests: {from:number;to:number;food:number;materials:number;route:number[]}[]=[];
  const incoming=new Map<number,{food:number;materials:number}>();
  for(const cargo of world.shipments) {const v=incoming.get(cargo.to)??{food:0,materials:0};v.food+=cargo.food;v.materials+=cargo.materials;incoming.set(cargo.to,v);}
  const shops=world.cells.flatMap((c,i)=>c.kind==='shop'&&!c.closed&&isPassable(c)&&c.stock+(incoming.get(i)?.food??0)<45?[i]:[]);
  const sites=world.cells.flatMap((c,i)=>isPassable(c)&&((BUILDINGS.has(c.kind)&&c.materials+(incoming.get(i)?.materials??0)<6)||(c.kind==='road'&&neighbors(world,i).some(n=>(world.cells[n].kind==='road'&&world.cells[n].condition<70)||world.cells[n].buildingPlan!==null)&&c.materials+(incoming.get(i)?.materials??0)<12))?[i]:[]);
  for(const [from,cell] of world.cells.entries()) {
    if(!isPassable(cell)||cell.closed)continue;
    const routed=(targets:number[])=>targets.filter(to=>to!==from).map(to=>({to,route:findRoute(world,from,to)})).filter((v):v is {to:number;route:number[]}=>v.route!==null).sort((a,b)=>a.route.length-b.route.length||a.to-b.to).slice(0,3);
    if(cell.kind==='farm'&&cell.stock>5)for(const target of routed(shops))requests.push({from,to:target.to,food:Math.min(16,45-world.cells[target.to].stock-(incoming.get(target.to)?.food??0)),materials:0,route:target.route});
    // Surviving household/workshop reserves can bootstrap a destroyed factory.
    if(cell.materials>6)for(const target of routed(sites))requests.push({from,to:target.to,food:0,materials:Math.min(8,12-world.cells[target.to].materials-(incoming.get(target.to)?.materials??0)),route:target.route});
  }
  const demandFrom=new Map<number,{food:number;materials:number}>(), demandTo=new Map<number,{food:number;materials:number}>();
  for(const r of requests) for(const [map,index] of [[demandFrom,r.from],[demandTo,r.to]] as const) {const v=map.get(index)??{food:0,materials:0};v.food+=r.food;v.materials+=r.materials;map.set(index,v);}
  const prepared=requests.map(r=>{const src=world.cells[r.from], dst=world.cells[r.to], a=demandFrom.get(r.from)!,b=demandTo.get(r.to)!;return {...r,food:r.food*Math.min(1,src.stock/Math.max(1,a.food),Math.max(0,45-dst.stock-(incoming.get(r.to)?.food??0))/Math.max(1,b.food)),materials:r.materials*Math.min(1,Math.max(0,src.materials-3)/Math.max(1,a.materials),Math.max(0,12-dst.materials-(incoming.get(r.to)?.materials??0))/Math.max(1,b.materials))};});
  for(const r of prepared) if(r.food+r.materials>.01){world.cells[r.from].stock=Math.max(0,world.cells[r.from].stock-r.food);world.cells[r.from].materials=Math.max(0,world.cells[r.from].materials-r.materials);world.shipments.push({id:world.nextShipmentId++,from:r.from,to:r.to,food:r.food,materials:r.materials,route:[...r.route],routeIndex:0,progress:0,blocked:false});}
}
function purchaseAndEat(world: World): void {
  const demands=new Map<number,Resident[]>();
  for(const person of world.residents) {
    if(person.health<=0)continue;
    if(person.state==='shop'&&person.timer<=0&&person.destination!==null) {const list=demands.get(person.destination)??[];list.push(person);demands.set(person.destination,list);}
    // A household pantry is local food already delivered/initially stocked, never a shared world pool.
    if((person.state==='home'||person.state==='shelter')&&person.food<1) {const source=person.shelter??person.home;const list=demands.get(source)??[];list.push(person);demands.set(source,list);}
  }
  for(const [index,people] of demands) {
    const cell=world.cells[index], each=isPassable(cell)&&!cell.closed?Math.min(4,cell.stock/people.length):0;
    for(const person of people.sort((a,b)=>a.id-b.id)) {person.food+=each;if(person.state==='shop') {if(each>.001){world.economy.visits++;cell.customers++;}else world.economy.failedPurchases++;if(!depart(world,person,person.shelter??person.home,'return')) {person.state='wait';person.timer=2;}}}
    cell.stock=Math.max(0,cell.stock-each*people.length);
  }
  const removed=new Set<number>();
  for(const person of world.residents) {
    if(person.health<=0){removed.add(person.id);world.economy.deaths++;event(world,world.cells[residentCell(world,person)],'decline','災害の被害で、住民を一人失いました。');continue;}
    const need=SIM_STEP/DAY_SECONDS, eaten=Math.min(need,person.food);person.food=Math.max(0,person.food-eaten);
    person.hunger=Math.max(0,person.hunger+(need-eaten)*2-eaten*.45);
    if(world.migrationGrace<=0) {if(person.hunger>.75)person.health=Math.max(0,person.health-SIM_STEP/DAY_SECONDS*(person.hunger-.5)*14);else if(eaten>=need*.99)person.health=Math.min(100,person.health+SIM_STEP/DAY_SECONDS*3);}
    if(person.health<=0) {removed.add(person.id);world.economy.deaths++;event(world,world.cells[residentCell(world,person)],'decline',person.hunger>.75?'食不足が続き、住民を一人失いました。':'災害の被害で、住民を一人失いました。');}
  }
  if(removed.size)world.residents=world.residents.filter(p=>!removed.has(p.id));
}
function workAndRepair(world: World): void {
  for(const cell of world.cells) cell.employed=0;
  const labour=new Map<number,number>();
  for(const person of world.residents) {
    if(person.role!=='worker'||person.health<15||person.hunger>2)continue;
    const effort=SIM_STEP*(person.health/100)*(person.hunger>.7?.4:1);
    if(person.state==='work'&&person.destination!==null&&isPassable(world.cells[person.destination])&&jobCapacity(world.cells[person.destination])) {const cell=world.cells[person.destination];cell.employed++;cell.work+=effort;labour.set(person.destination,(labour.get(person.destination)??0)+effort);}
    else if(person.state==='home'&&world.cells[person.home].kind==='house')labour.set(person.home,(labour.get(person.home)??0)+effort*.35);
    else if(person.state==='repair'&&person.destination!==null)labour.set(person.destination,(labour.get(person.destination)??0)+effort);
  }
  for(const [index,effort] of labour) {
    const cell=world.cells[index];if(!isPassable(cell))continue;
    if(cell.kind==='farm') {const fertility=Math.min(1,cell.fertility/65), moisture=Math.min(1,cell.moisture/35)*Math.min(1,(105-cell.moisture)/25);const grown=effort*.65*fertility*moisture*(world.weather.temperature<2?.25:1);cell.stock+=grown;world.economy.harvest+=grown;cell.crop=clamp(cell.crop+grown*.3);cell.reason=moisture<.5?'乾燥や水の多さで収穫が鈍っています。':'畑へ来た働き手が食を収穫し、在庫を店へ運んでいます。';}
    if(cell.kind==='factory') {cell.materials+=effort*.16;cell.reason='現場で働く住民が修繕資材を作っています。';}
    const targets=cell.kind==='road'?neighbors(world,index).filter(i=>(world.cells[i].kind==='road'&&world.cells[i].condition<80)||world.cells[i].buildingPlan!==null):cell.condition<95?[index]:[];
    const available=cell.materials, requested=targets.length?effort*.08:0, spent=Math.min(available,requested), fraction=requested?spent/requested:0;
    if(targets.length&&spent>0) {cell.materials-=spent;for(const target of targets) {const site=world.cells[target];const before=isPassable(site);site.condition=clamp(site.condition+effort*.65*fraction/targets.length);site.rubble=Math.max(0,site.rubble-effort*1.2*fraction/targets.length);if(site.kind==='road'&&site.condition>=30&&site.rubble<25&&site.fire<1&&site.waterDepth<1){site.closed=false;site.reason='住民が安全な側から資材を使い、道を修復しています。';}if(site.buildingPlan!==null&&site.fire<1&&site.waterDepth<1) {site.development=clamp(site.development+effort*2*fraction/targets.length);site.reason='住民が安全な道から資材を運び、暮らしの場所を建設しています。';if(site.development>=100&&site.rubble<1){const plan=site.buildingPlan;setKind(site,plan,world.tick,'資材と住民の労働で新しい建物が完成しました。');site.population=0;world.stats.born++;world.topologyVersion++;event(world,site,'growth','資材と働き手が届き、建物が完成しました。');}}if(before!==isPassable(site))world.topologyVersion++;}}
    if(BUILDINGS.has(cell.kind)&&cell.level<3&&cell.condition>75&&world.economy.starving===0&&cell.vitality>65&&cell.materials>3) {const amount=Math.min(cell.materials,effort*.035);cell.materials-=amount;cell.development=clamp(cell.development+amount*20);if(cell.development>=100){cell.level++;cell.development=0;cell.changedAt=world.tick;event(world,cell,'growth','届いた資材と住民の労働で建物が増築されました。');}}
  }
}
function planConstruction(world: World): void {
  if(!world.residents.some(p=>p.role==='worker'&&p.health>50)||world.economy.food<world.residents.length*2||world.economy.starving>0)return;
  const underway=world.cells.filter(c=>c.buildingPlan!==null).length;if(underway>=3)return;
  const capacity=world.cells.reduce((sum,c)=>sum+(c.kind==='house'?3+c.level*3:0),0);
  const kind: Cell['buildingPlan']=world.stats.factories===0?'factory':world.residents.some(p=>p.displaced)||capacity<world.residents.length*1.15?'house':world.economy.food<world.residents.length*5?'farm':world.stats.factories<Math.ceil(world.residents.length/60)?'factory':world.stats.shops<Math.ceil(world.residents.length/35)?'shop':null;
  if(kind===null)return;
  const sources=world.cells.flatMap((c,i)=>c.materials>3&&isPassable(c)?[i]:[]);
  const sites=world.cells.flatMap((c,i)=>c.terrain==='land'&&(c.kind==='grass'||c.kind==='ruin')&&c.buildingPlan===null&&c.fire<1&&c.waterDepth<1&&neighbors(world,i).some(n=>world.cells[n].kind==='road'&&isPassable(world.cells[n])&&sources.some(source=>findRoute(world,source,n)))?[i]:[]).sort((a,b)=>+(world.cells[b].kind==='ruin')-+(world.cells[a].kind==='ruin')||a-b);
  const index=sites[0];if(index===undefined)return;const c=world.cells[index];c.buildingPlan=kind;c.development=.01;c.reason='食と住まいの需要を受け、資材と働き手が届く建設を計画しています。';
}
function dailyLife(world: World): void {
  const homes=world.cells.flatMap((c,i)=>c.kind==='house'&&isPassable(c)?[i]:[]);
  for(const person of world.residents) {
    if(person.displaced&&person.shelter!==null&&world.cells[person.shelter].kind==='house'&&world.cells[person.shelter].population<3+world.cells[person.shelter].level*3) {person.home=person.shelter;person.shelter=null;person.displaced=false;world.cells[person.home].population++;event(world,world.cells[person.home],'refuge','避難先の家で、暮らしを立て直し始めました。');}
    if(world.migrationGrace<=0&&person.role==='worker'&&person.workplace===null&&!person.displaced&&random(world)<.012){world.residents=world.residents.filter(p=>p.id!==person.id);world.economy.departures++;event(world,world.cells[person.home],'decline','届く仕事場がなく、住民が仕事を求めて町を離れました。');continue;}
    if(world.migrationGrace<=0&&(person.hunger>1.2||(person.displaced&&person.shelter===null))&&random(world)<.08) {world.residents=world.residents.filter(p=>p.id!==person.id);world.economy.departures++;event(world,world.cells[residentCell(world,person)],'decline','食や安全な住まいを求め、住民が町を離れました。');}
  }
  const driveways=new Set(world.residents.flatMap(p=>p.route));
  const oldVegetation=world.cells.map(c=>c.kind),oldWork=world.cells.map(c=>c.work);
  for(const [index,cell] of world.cells.entries()) {
    if(cell.terrain==='land'&&cell.fire<1&&cell.waterDepth<1.6) {
      const growing=cell.moisture>20&&cell.moisture<95&&cell.fertility>35&&world.weather.temperature>2;
      if(cell.kind==='grass'||cell.kind==='tree'||cell.kind==='park') {cell.vegetation=clamp(cell.vegetation+(growing?(cell.kind==='tree'?1.2:1.8):-1.5));cell.fertility=clamp(cell.fertility+(cell.kind==='tree'?.2:.04));cell.environment=Math.round(clamp(65+cell.vegetation*.3));}
      if(cell.kind==='tree'&&cell.vegetation<1&&cell.age>5){setKind(cell,'grass',world.tick,'乾燥や火で木が弱り、草地から回復を待っています。');world.topologyVersion++;}
      else if(cell.kind==='grass'&&cell.buildingPlan===null&&cell.rubble<1&&cell.vegetation>70&&growing&&!driveways.has(index)&&!neighbors(world,index).some(i=>oldVegetation[i]==='road')&&neighbors(world,index).some(i=>oldVegetation[i]==='tree')&&random(world)<.04){setKind(cell,'tree',world.tick,'近くの林から種が届き、湿った土に若木が芽吹きました。');cell.vegetation=45;world.topologyVersion++;event(world,cell,'nature','雨と土に支えられ、若い木が芽吹きました。');}
      if(cell.kind==='farm')cell.fertility=clamp(cell.fertility+(cell.work>1?-.08:.15));
    }
    if(BUILDINGS.has(cell.kind)){const pollution=neighbors(world,index).filter(i=>oldVegetation[i]==='factory'&&oldWork[i]>1).length*5;cell.environment=Math.round(clamp(75+cell.vegetation*.15-pollution));}
    cell.age+=1;cell.traffic*=.85;cell.customers*=.8;
    if(BUILDINGS.has(cell.kind)) {
      const household=world.residents.filter(p=>p.home===index), activity=cell.kind==='house'?household.length?household.reduce((s,p)=>s+p.health,0)/household.length - household.filter(p=>p.role==='worker'&&p.workplace===null).length/household.length*25 - Math.max(0,65-cell.environment)*.5:0:cell.work>1?80:25;
      cell.vitality=Math.round(clamp(cell.vitality*.85+activity*.15));cell.condition=clamp(cell.condition-(activity<30?.65:.12));cell.closed=cell.condition<15||!isPassable({...cell,closed:false});
      if(cell.kind==='house')cell.reason=household.some(p=>p.hunger>.75)?'食不足で健康が弱まり、生活を立て直す備蓄が必要です。':household.length?'地元の食と通勤、住民の手入れが暮らしを支えています。':'住まいに空きがあり、新しい住民を待っています。';
      if(cell.condition<8&&cell.vitality<20){setKind(cell,'ruin',world.tick,'食・仕事・修繕が途絶え、建物が荒廃しました。');cell.population=0;cell.rubble=25;world.stats.retired++;world.topologyVersion++;event(world,cell,'decline','使われなくなった建物が荒廃しました。');}
      cell.work=0;
    } else if(cell.kind==='ruin'&&cell.buildingPlan===null&&cell.rubble<1&&cell.age>12) {setKind(cell,'grass',world.tick,'瓦礫の跡に草が戻り、自然が土地を回復しています。');world.topologyVersion++;event(world,cell,'nature','荒廃した土地に草が戻りました。');}
  }
  reconcile(world);
  if(world.residents.length>0) {
    if(world.tick%3===0&&world.economy.food>world.residents.length*3&&world.economy.starving===0&&world.economy.employed<world.stats.jobs) for(const home of homes) {const c=world.cells[home];if(c.population<3+c.level*3&&c.vitality>60&&c.accessible){const person=newResident(world,home);world.residents.push(person);c.population++;world.economy.arrivals++;event(world,c,'birth','食と仕事のある町に、新しい住民が移ってきました。');break;}}
    if(world.tick%12===0)for(const home of homes){const family=world.residents.filter(p=>p.home===home&&!p.displaced);if(family.length>=2&&family.length<3+world.cells[home].level*3&&family.every(p=>p.health>80&&p.hunger<.2)&&random(world)<.12){const baby=newResident(world,home,'dependent');baby.food=0;world.residents.push(baby);world.economy.births++;event(world,world.cells[home],'birth','食と住まいが安定した家で、小さな住民が生まれました。');}}
  }
  planConstruction(world); synchronizeResidents(world);reconcile(world);
  world.history.push({tick:world.tick,population:world.stats.population});if(world.history.length>HISTORY_LIMIT)world.history.shift();
}
/** One shared fixed clock for weather, people, resources and commands. Partition-invariant remainder. */
export function advanceWorld(world: World, seconds: number, onBeforeCommands?: (world: World)=>void): World {
  if(!Number.isFinite(seconds)||seconds<0)throw new Error('進める時間は有限の非負数で指定してください。');
  const total=world.remainder+seconds, steps=Math.floor((total+1e-10)/SIM_STEP);world.remainder=Math.max(0,Math.round((total-steps*SIM_STEP)*1e10)/1e10);
  for(let n=0;n<steps;n++) {
    if(world.pending.some(c=>c.atStep<=world.step+1))onBeforeCommands?.(world);
    world.step++;world.clock=world.step*SIM_STEP;world.tick=Math.floor(world.clock/DAY_SECONDS);world.revision++;
    const topology=world.topologyVersion;const applied=applyPendingPowers(world);for(const command of applied)if(command.kind==='settle')settle(world,command);
    advanceDisasters(world,SIM_STEP);if(topology!==world.topologyVersion)synchronizeResidents(world);
    advanceShipments(world);advanceResidents(world,SIM_STEP);purchaseAndEat(world);const beforeRepair=world.topologyVersion;workAndRepair(world);if(beforeRepair!==world.topologyVersion)synchronizeResidents(world);
    world.migrationGrace=Math.max(0,world.migrationGrace-SIM_STEP);
    if(world.step%8===0)dispatch(world);
    if(world.step%(DAY_SECONDS/SIM_STEP)===0)dailyLife(world);
    reconcile(world);
  }
  return world;
}
/** Convenience for tests/manual day stepping. Main loop should call advanceWorld with elapsed seconds. */
export function stepWorld(world: World): World {return advanceWorld(world,DAY_SECONDS);}
export function serializeWorld(world: World): string {return JSON.stringify(world,(_key,value:unknown)=>value!==null&&typeof value==='object'&&!Array.isArray(value)?Object.fromEntries(Object.keys(value).sort().map(k=>[k,(value as Record<string,unknown>)[k]])):value);}

function invalid(detail: string): never {throw new Error(`保存した街を読み込めません: ${detail}`);}
function record(v:unknown,label:string):Record<string,unknown>{if(v===null||typeof v!=='object'||Array.isArray(v))invalid(`${label}の形式が不正です。`);return v as Record<string,unknown>;}
function num(v:unknown,label:string,min=0,max=1e12,integer=false):number{if(typeof v!=='number'||!Number.isFinite(v)||v<min||v>max||(integer&&!Number.isInteger(v)))invalid(`${label}の数値が不正です。`);return v;}
function textValue(v:unknown,label:string,max=500):string{if(typeof v!=='string'||v.length>max)invalid(`${label}の文字列が不正です。`);return v;}
function bool(v:unknown,label:string):boolean{if(typeof v!=='boolean')invalid(`${label}の値が不正です。`);return v;}
function enumeration<T extends string>(v:unknown,values:readonly T[],label:string):T{if(!values.includes(v as T))invalid(`${label}の種類が不正です。`);return v as T;}
function array(v:unknown,label:string,max:number):unknown[]{if(!Array.isArray(v)||v.length>max)invalid(`${label}の数が不正です。`);return v;}
/** Strict bounded plain-data decoding, allowing valid journeys whose saved road is now broken. */
export function restoreWorld(json:string):World {
  if(typeof json!=='string'||json.length>12_000_000)invalid('保存データが大きすぎます。');let parsed:unknown;try{parsed=JSON.parse(json);}catch{invalid('JSONが壊れています。');}
  const d=record(parsed,'街'),version=num(d.version,'形式',1,3,true),legacy=version!==3,size=num(d.size,'大きさ',24,64,true),length=size*size;
  const oldTick=num(d.tick,'暦',0,1e10,true),clock=version===1?oldTick*4:legacy?Math.max(oldTick*4,num(d.clock,'時計',0,1e12)):num(d.clock,'時計',0,1e12),step=legacy?Math.floor(clock/SIM_STEP):num(d.step,'固定時刻',0,4e12,true),tick=Math.floor(step*SIM_STEP/DAY_SECONDS);
  const index=(v:unknown,label:string)=>num(v,label,0,length-1,true),nullable=(v:unknown,label:string)=>v===null?null:index(v,label);
  const savedCells=array(d.cells,'土地',length);if(savedCells.length!==length)invalid('土地の数が一致しません。');
  const cells=savedCells.map((value,i):Cell=>{
    const c=record(value,'土地'),kind=enumeration(c.kind,KINDS,'土地'),terrain=enumeration(c.terrain,['land','water'] as const,'地形');
    const x=index(c.x,'横位置'),y=index(c.y,'縦位置');if(x!==i%size||y!==Math.floor(i/size))invalid('土地の並びが不正です。');
    if((terrain==='water'&&kind!=='water'&&kind!=='road')||(terrain==='land'&&kind==='water'))invalid('地形と建物が一致しません。');
    const level=num(c.level,'段階',0,3,true),population=num(c.population,'人口',0,length*12,true),vitality=num(c.vitality,'活力',0,100);
    if((BUILDINGS.has(kind)&&level<1)||(!BUILDINGS.has(kind)&&(level!==0||vitality!==0))||(kind!=='house'&&population!==0))invalid('建物と人口の組み合わせが不正です。');
    const oldAge=num(c.age,'築日',0,1e12),oldChanged=num(c.changedAt,'変化時刻',0,oldTick,true);
    const cell:Cell={x,y,terrain,kind,level,population,vitality,age:legacy?oldAge*4/DAY_SECONDS:oldAge,changedAt:legacy?Math.floor(oldChanged*4/DAY_SECONDS):oldChanged,environment:num(c.environment,'環境',0,100),traffic:num(c.traffic,'通行',0,100),variant:num(c.variant,'外観',0,7,true),reason:textValue(c.reason,'理由'),moisture:version===1?terrain==='water'?100:55:num(c.moisture,'水分',0,100),fertility:version===1?72:num(c.fertility,'土',0,100),vegetation:version===1?kind==='tree'?90:35:num(c.vegetation,'植生',0,100),crop:version===1?kind==='farm'?10:0:num(c.crop,'作物',0,100),condition:version===1?BUILDINGS.has(kind)||kind==='road'?80:0:num(c.condition,'状態',0,100),development:version===1?0:num(c.development,'工事',0,100),employed:version===1?0:num(c.employed,'現場人数',0,length*24),customers:version===1?0:num(c.customers,'購入者',0,1e12),accessible:version===1?false:bool(c.accessible,'到達性'),elevation:legacy?terrain==='water'?0:3:num(c.elevation,'標高',-100,100),waterDepth:legacy?terrain==='water'?1:0:num(c.waterDepth,'浸水',0,10000),fire:legacy?0:num(c.fire,'火',0,100),snow:legacy?0:num(c.snow,'雪',0,10000),rubble:legacy?0:num(c.rubble,'瓦礫',0,100),crater:legacy?0:num(c.crater,'穴',0,10000),stock:legacy?kind==='shop'?50:kind==='farm'?25:kind==='house'?8:0:num(c.stock,'食の在庫',0,1e10),materials:legacy?kind==='factory'?40:8:num(c.materials,'資材',0,1e10),work:legacy?0:num(c.work,'労働',0,1e10),region:legacy?-1:num(c.region,'地区',-1,length,true),closed:legacy?false:bool(c.closed,'休業'),buildingPlan:legacy?null:c.buildingPlan===null?null:enumeration(c.buildingPlan,['house','shop','farm','factory'] as const,'建築計画')};
    if(legacy&&kind==='road')cell.condition=80;return cell;
  });
  const statsData=record(d.stats,'統計'),economy=legacy?defaultEconomy():record(d.economy,'経済'),weatherData=version===1?defaultWeather(size):record(d.weather,'天候');
  const weather:Weather={kind:enumeration(weatherData.kind,['clear','cloudy','rain','storm','snow'] as const,'天候'),temperature:num(weatherData.temperature,'気温',-100,100),rainfall:num(weatherData.rainfall,'雨量',0,10000),cloud:legacy?0:num(weatherData.cloud,'雲',0,100),windX:legacy?.1:num(weatherData.windX,'風X',-100,100),windY:legacy?.04:num(weatherData.windY,'風Y',-100,100),remaining:legacy?DAY_SECONDS:num(weatherData.remaining,'天候残り',0,1e12),frontX:legacy?size/2:num(weatherData.frontX,'雲位置X',-size*10,size*10),frontY:legacy?size/2:num(weatherData.frontY,'雲位置Y',-size*10,size*10),frontRadius:legacy?size:num(weatherData.frontRadius,'雲範囲',0,size*10)};
  const world:World={version:3,step,clock:step*SIM_STEP,tick,remainder:legacy?Math.round((clock-step*SIM_STEP)*1e10)/1e10:num(d.remainder,'端数',0,SIM_STEP-1e-12),revision:legacy?0:num(d.revision,'更新番号',0,1e12,true),topologyVersion:legacy?0:num(d.topologyVersion,'道路更新',0,1e12,true),hazardRng:legacy?(num(d.seed,'種',0,0xffffffff,true)^0x9e3779b9)>>>0:num(d.hazardRng,'災害乱数',0,0xffffffff,true),nextCommandId:legacy?0:num(d.nextCommandId,'命令番号',0,1e12,true),pending:[],effects:[],shipments:[],nextShipmentId:legacy?0:num(d.nextShipmentId,'輸送番号',0,1e12,true),naturalPolicy:legacy?'gentle':enumeration(d.naturalPolicy,['off','gentle','wild','apocalyptic'] as const,'自然災害'),migrationGrace:legacy?DAY_SECONDS*3:num(d.migrationGrace,'移行猶予',0,1e12),seed:num(d.seed,'種',0,0xffffffff,true),rng:num(d.rng,'乱数',0,0xffffffff,true),size,cells,residents:[],nextResidentId:version===1?0:num(d.nextResidentId,'住民採番',0,1e12,true),weather,economy:defaultEconomy(),stats:emptyStats(),events:[],history:[]};
  world.stats.born=num(statsData.born,'建物誕生',0,1e12,true);world.stats.retired=num(statsData.retired,'建物閉鎖',0,1e12,true);
  const validateRoute=(value:unknown):number[]=>{const route=array(value,'経路',length+6).map(v=>index(v,'経路セル'));if(route.some((v,n)=>n>0&&!neighbors(world,route[n-1]).includes(v)))invalid('経路がつながっていません。');return route;};
  const ids=new Set<number>();
  if(version!==1)world.residents=array(d.residents,'住民',length*24).map((value):Resident=>{
    const p=record(value,'住民'),id=num(p.id,'住民番号',0,world.nextResidentId-1,true);if(ids.has(id))invalid('住民番号が重複しています。');ids.add(id);
    const home=index(p.home,'住まい'),route=validateRoute(p.route),routeIndex=num(p.routeIndex,'経路位置',0,Math.max(0,route.length-1),true),progress=num(p.progress,'歩行',0,1-1e-12),destination=nullable(p.destination,'目的地'),state=enumeration(p.state,['home','travel','work','shop','park','shelter','wait','repair'] as const,'行動');
    if(state==='travel'&&(destination===null||route.length<2||routeIndex>=route.length-1||route.at(-1)!==destination))invalid('旅行と経路が一致しません。');
    if(progress>0&&(routeIndex>=route.length-1||!['travel','wait'].includes(state)))invalid('歩行状態が不正です。');
    const x=num(p.x,'人物X',0,size-1),y=num(p.y,'人物Y',0,size-1),origin=cells[route.length?route[routeIndex]:destination??home],next=progress>0?cells[route[routeIndex+1]]:origin;
    if(Math.abs(x-(origin.x+(next.x-origin.x)*progress))>1e-6||Math.abs(y-(origin.y+(next.y-origin.y)*progress))>1e-6)invalid('住民の位置と経路が一致しません。');
    return {id,home,route,routeIndex,progress,destination,state,x,y,workplace:nullable(p.workplace,'職場'),shop:nullable(p.shop,'店'),purpose:enumeration(p.purpose,['commute','shopping','stroll','return','refuge','repair'] as const,'目的'),timer:num(p.timer,'滞在',0,1e12)*(legacy?DAY_SECONDS/150:1),color:num(p.color,'服',0,5,true),trips:num(p.trips,'旅行数',0,1e12,true),role:legacy?'worker':enumeration(p.role,['worker','dependent'] as const,'役割'),health:legacy?100:num(p.health,'健康',0,100),hunger:legacy?0:num(p.hunger,'飢え',0,1e10),food:legacy?4:num(p.food,'携帯食',0,1e10),shelter:legacy?null:nullable(p.shelter,'避難所'),displaced:legacy?cells[home].kind!=='house':bool(p.displaced,'被災')};
  });
  const history=array(d.history,'人口履歴',HISTORY_LIMIT).map(v=>{const h=record(v,'履歴');return {tick:num(h.tick,'履歴時刻',0,oldTick,true),population:num(h.population,'履歴人口',0,length*24,true)};});
  if(!history.length||history.some((h,n)=>n>0&&h.tick<=history[n-1].tick)||history.at(-1)!.tick!==oldTick)invalid('人口履歴の時刻が不正です。');
  world.events=array(d.events,'記録',EVENT_LIMIT).map(v=>{const e=record(v,'記録');return {tick:legacy?Math.floor(num(e.tick,'記録時刻',0,oldTick,true)*4/DAY_SECONDS):num(e.tick,'記録時刻',0,tick,true),x:num(e.x,'記録X',0,size-1,true),y:num(e.y,'記録Y',0,size-1,true),kind:enumeration(e.kind,['birth','growth','decline','nature','road','god','disaster','supply','refuge'] as const,'記録'),text:textValue(e.text,'記録')};});
  if(world.events.some((e,n)=>n>0&&e.tick<world.events[n-1].tick))invalid('記録の順序が不正です。');
  if(legacy) {
    const oldPopulation=num(statsData.population,'旧人口',0,length*12,true),total=cells.reduce((s,c)=>s+c.population,0);if(oldPopulation!==total)invalid('旧人口が土地と一致しません。');
    if(world.residents.length>oldPopulation)invalid('旧住民が総人口を超えています。');
    const counts=new Map<number,number>();for(const p of world.residents)counts.set(p.home,(counts.get(p.home)??0)+1);
    let missing=oldPopulation-world.residents.length;
    for(const [home,c] of cells.entries())if(c.kind==='house')for(let n=counts.get(home)??0;n<c.population&&missing>0;n++,missing--)world.residents.push(newResident(world,home,n%3===2?'dependent':'worker'));
    if(missing)invalid('旧人口を住まいへ移行できません。');
    world.legacyCalendar={tick:oldTick,history};world.history=[{tick,population:oldPopulation}];
    if(version===2){const old=record(d.economy,'旧経済');world.economy.visits=num(old.visits,'旧来店',0,1e12,true);world.economy.commutes=num(old.commutes,'旧通勤',0,1e12,true);const food=num(old.food,'旧食料',0,1e10);const stores=cells.filter(c=>c.kind==='shop');for(const c of stores)c.stock+=food/Math.max(1,stores.length);}
    synchronizeResidents(world);reconcile(world);return world;
  }
  if(world.tick!==oldTick||Math.abs(world.clock-clock)>1e-9)invalid('固定時刻と時計が一致しません。');
  const commandIds=new Set<number>();
  const command=(value:unknown):PowerCommand=>{const c=record(value,'命令'),target=record(c.target,'地点'),id=num(c.id,'命令ID',0,world.nextCommandId-1,true);if(commandIds.has(id))invalid('命令IDが重複しています。');commandIds.add(id);return {id,kind:enumeration(c.kind,['rain','sun','storm','lightning','earthquake','meteor','growth','settle'] as const,'力'),target:{x:num(target.x,'地点X',0,size-1,true),y:num(target.y,'地点Y',0,size-1,true)},radius:num(c.radius,'範囲',0,Math.ceil(Math.hypot(size,size))),intensity:num(c.intensity,'強さ',1,4),duration:num(c.duration,'期間',0,3600),source:enumeration(c.source,['god','nature'] as const,'命令元'),seed:num(c.seed,'命令種',0,0xffffffff,true),atStep:num(c.atStep,'実行時刻',0,4e12,true)};};
  world.pending=array(d.pending,'予約',100000).map(v=>{const c=command(v);if(c.atStep<=world.step||c.duration%SIM_STEP!==0)invalid('予約の時刻や期間が不正です。');return c;});
  world.effects=array(d.effects,'効果',100000).map(v=>{const e=record(v,'効果'),c=command(v),limit=Math.max(2,c.duration,SIM_STEP),remaining=num(e.remaining,'効果残り',0,limit),elapsed=num(e.elapsed,'効果経過',0,limit);if(c.atStep>world.step||c.duration%SIM_STEP!==0||remaining+elapsed>limit+1e-8)invalid('効果の時刻や期間が不正です。');return {...c,remaining,elapsed};});
  const shipmentIds=new Set<number>();world.shipments=array(d.shipments,'輸送',length*24).map(v=>{const s=record(v,'輸送'),id=num(s.id,'輸送ID',0,world.nextShipmentId-1,true);if(shipmentIds.has(id))invalid('輸送IDが重複しています。');shipmentIds.add(id);const from=index(s.from,'輸送元'),to=index(s.to,'輸送先'),route=validateRoute(s.route);if(route.length<2||route[0]!==from||route.at(-1)!==to)invalid('輸送と経路が一致しません。');return {id,from,to,route,routeIndex:num(s.routeIndex,'搬送位置',0,route.length-2,true),progress:num(s.progress,'搬送歩行',0,1-1e-12),food:num(s.food,'搬送食料',0,1e10),materials:num(s.materials,'搬送資材',0,1e10),blocked:bool(s.blocked,'搬送待機')};});
  for(const key of Object.keys(defaultEconomy()) as (keyof Economy)[])world.economy[key]=num(economy[key],`経済${key}`,0,1e12,['visits','commutes','evacuated','deaths','births','arrivals','departures','failedPurchases','workers','employed','starving'].includes(key));
  const savedEconomy={...world.economy},savedPop=cells.map(c=>c.population);reconcile(world);
  for(const key of Object.keys(world.stats) as (keyof TownStats)[])if(num(statsData[key],`統計${key}`,0,1e12,true)!==world.stats[key])invalid(`統計${key}が一致しません。`);
  if(savedPop.some((p,i)=>p!==cells[i].population))invalid('住民と家の人口が一致しません。');
  for(const key of ['workers','employed','food','materials','starving'] as const)if(Math.abs(savedEconomy[key]-world.economy[key])>1e-6)invalid(`経済${key}が在庫と一致しません。`);
  if(history.at(-1)!.population!==world.stats.population&&world.clock%DAY_SECONDS===0)invalid('人口履歴が現在人口と一致しません。');world.history=history;
  if(d.legacyCalendar!==undefined){const l=record(d.legacyCalendar,'旧暦'),last=num(l.tick,'旧暦時刻',0,1e10,true);world.legacyCalendar={tick:last,history:array(l.history,'旧履歴',HISTORY_LIMIT).map(v=>{const h=record(v,'旧履歴');return {tick:num(h.tick,'旧履歴時刻',0,last,true),population:num(h.population,'旧履歴人口',0,length*24,true)};})};}
  return world;
}
