import assert from 'node:assert/strict';
import test from 'node:test';
import { advanceWorld, createWorld, restoreWorld, serializeWorld, stepWorld } from '../src/simulation.ts';
import { advanceResidents, depart, findRoute, jobCapacity, neighbors, newResident, synchronizeResidents, walkingSpeed } from '../src/mobility.ts';
import { queuePower } from '../src/disasters.ts';
import { DAY_SECONDS, SIM_STEP, EVENT_LIMIT } from '../src/constants.ts';
import type { CellKind, World } from '../src/types.ts';

function assertInvariants(world: World) {
  assert.equal(world.version,3);assert.equal(world.stats.population,world.residents.length);
  assert.equal(world.clock,world.step*SIM_STEP);assert.equal(world.tick,Math.floor(world.clock/DAY_SECONDS));
  assert.equal(new Set(world.residents.map(p=>p.id)).size,world.residents.length);
  for(const [i,c] of world.cells.entries()) {
    assert.equal(c.x,i%world.size);assert.equal(c.y,Math.floor(i/world.size));assert.ok(c.changedAt<=world.tick);
    for(const key of ['stock','materials','condition','development','moisture','crop','rubble'] as const)assert.ok(Number.isFinite(c[key])&&c[key]>=0);
    if(c.kind==='house')assert.equal(c.population,world.residents.filter(p=>p.home===i).length);else assert.equal(c.population,0);
  }
  assert.equal(world.stats.jobs,world.cells.reduce((s,c)=>s+jobCapacity(c),0));
  assert.ok(world.events.length<=EVENT_LIMIT&&world.history.length<=180);
  assert.deepEqual(restoreWorld(serializeWorld(world)),world);
}
function lineWorld():World {
  const w=createWorld(42,24);w.naturalPolicy='off';w.residents=[];w.nextResidentId=0;w.shipments=[];w.events=[];w.history=[{tick:0,population:0}];
  for(const c of w.cells)Object.assign(c,{terrain:'land',kind:'grass',level:0,population:0,vitality:0,condition:0,stock:0,materials:0,work:0,fire:0,waterDepth:0,rubble:0,closed:false,buildingPlan:null});
  for(let y=0;y<24;y++)Object.assign(w.cells[y*24+12],{terrain:'water',kind:'water',waterDepth:1});
  for(let x=2;x<=21;x++)Object.assign(w.cells[12*24+x],{kind:'road',condition:90,closed:false});
  w.topologyVersion++;advanceWorld(w,.25);return w;
}
function building(w:World,x:number,y:number,kind:CellKind):number {const i=y*w.size+x;Object.assign(w.cells[i],{kind,level:1,condition:90,vitality:80,stock:0,materials:0,closed:false});w.topologyVersion++;return i;}

test('seed, fixed deltas, save continuation and command checkpoint are deterministic',()=>{
  for(const seed of [0,42,0xffffffff]) {
    const a=createWorld(seed),b=createWorld(seed);advanceWorld(a,81.7);for(let n=0;n<817;n++)advanceWorld(b,.1);
    assert.equal(serializeWorld(a),serializeWorld(b));const c=restoreWorld(serializeWorld(a));advanceWorld(a,90);advanceWorld(c,90);assert.equal(serializeWorld(a),serializeWorld(c));
  }
  const w=createWorld(9);queuePower(w,{kind:'rain',target:{x:10,y:10},radius:3,intensity:1,duration:2});let captured=-1;
  advanceWorld(w,.25,before=>{captured=before.step;assert.equal(before.clock,0);assert.equal(before.pending.length,1);});assert.equal(captured,0);assert.equal(w.step,1);
  for(const s of [-1,1.5,NaN,Infinity,0x100000000])assert.throws(()=>createWorld(s),/種/);for(const s of [23,65,48.5])assert.throws(()=>createWorld(1,s),/大きさ/);
});
test('one visible person represents one resident; assignments respect roads and capacity',()=>{
  const w=createWorld(42);assert.equal(w.residents.length,w.cells.reduce((s,c)=>s+c.population,0));assert.ok(w.residents.some(p=>p.role==='dependent'));
  const used=new Map<number,number>();for(const p of w.residents){if(p.role==='dependent')assert.equal(p.workplace,null);if(p.workplace===null)continue;used.set(p.workplace,(used.get(p.workplace)??0)+1);assert.ok(used.get(p.workplace)!<=jobCapacity(w.cells[p.workplace]));const route=findRoute(w,p.home,p.workplace)!;assert.ok(route);assert.ok(route.every((i,n)=>n===0||neighbors(w,route[n-1]).includes(i)));}
  const old=w.residents.pop()!;const count=w.residents.length;synchronizeResidents(w);assert.equal(w.residents.length,count,'housing never silently respawns the lost resident');assert.ok(w.residents.every(p=>p.id!==old.id));
});
test('quarter steps carry walking time across tile boundaries at the shared walking speed',()=>{
  const w=lineWorld(),home=building(w,8,11,'house'),work=building(w,11,11,'farm'),p=newResident(w,home);w.residents=[p];assert.ok(depart(w,p,work,'commute'));p.route=[home,home+24,home+25,home+26,home+27,work];
  assert.equal(walkingSpeed(w,p),1.3);for(let n=0;n<12;n++)advanceResidents(w,.25);
  assert.equal(p.routeIndex,3);assert.ok(Math.abs(p.progress-.9)<1e-10);assert.ok(Math.abs(p.x-10.9)<1e-10);assert.equal(p.y,12);
  for(let n=0;n<4;n++)advanceResidents(w,.25);assert.equal(p.state,'work');assert.equal(p.x,11);assert.equal(p.y,11);assert.equal(p.routeIndex,p.route.length-1);
  assert.ok(Math.abs(p.timer-(DAY_SECONDS*.28-(4-5/1.3)))<1e-10,'time remaining after arrival advances the visit timer');
  const a=lineWorld(),b=lineWorld();for(const world of [a,b]){const h=building(world,8,11,'house'),f=building(world,16,11,'farm'),person=newResident(world,h);world.residents=[person];depart(world,person,f,'commute');}
  advanceWorld(a,3.25);for(let n=0;n<13;n++)advanceWorld(b,.25);assert.equal(serializeWorld(a),serializeWorld(b));
});
test('a broken bridge stops an existing fractional trip and survives save/load without reverse teleport',()=>{
  const w=lineWorld(),home=building(w,8,11,'house'),work=building(w,16,11,'farm');const p=newResident(w,home);w.residents=[p];p.workplace=work;assert.ok(depart(w,p,work,'commute'));
  while(p.route[p.routeIndex+1]!==12*24+12)advanceResidents(w,.25);
  advanceResidents(w,.25);assert.ok(p.progress>0);const bridge=w.cells[12*24+12];bridge.condition=0;bridge.closed=true;w.topologyVersion++;
  const position={x:p.x,y:p.y,progress:p.progress,routeIndex:p.routeIndex};advanceWorld(w,.5);assert.equal(p.state,'wait');assert.deepEqual({x:p.x,y:p.y,progress:p.progress,routeIndex:p.routeIndex},position);
  const restored=restoreWorld(serializeWorld(w));advanceWorld(w,1);advanceWorld(restored,1);assert.equal(serializeWorld(w),serializeWorld(restored));assert.deepEqual({x:p.x,y:p.y,progress:p.progress,routeIndex:p.routeIndex},position);
  bridge.condition=90;bridge.closed=false;w.topologyVersion++;advanceWorld(w,.25);assert.equal(p.state,'travel');assert.ok(p.x>position.x);
});
test('food and materials require actual resident labour, never decaying arrival counters',()=>{
  const w=createWorld(42);w.naturalPolicy='off';w.residents=[];for(const c of w.cells)c.materials=0;for(const c of w.cells)if(c.kind==='farm'){c.crop=100;c.stock=0;c.employed=100;}else if(c.kind==='factory'){c.materials=0;c.employed=100;}
  stepWorld(w);assert.equal(w.economy.harvest,0);assert.equal(w.economy.food,w.cells.reduce((s,c)=>s+c.stock,0));assert.ok(w.cells.filter(c=>c.kind==='factory').every(c=>c.materials===0));
  const live=createWorld(42);live.naturalPolicy='off';advanceWorld(live,DAY_SECONDS*2);assert.ok(live.economy.harvest>0);const factoryWorld=lineWorld(), factory=building(factoryWorld,8,11,'factory');factoryWorld.cells[factory].condition=100;const worker=newResident(factoryWorld,factory);worker.destination=factory;worker.state='work';worker.timer=999;factoryWorld.residents=[worker];advanceWorld(factoryWorld,1);assert.ok(factoryWorld.cells[factory].materials>0);assert.ok(factoryWorld.cells[factory].work>0);assert.ok(live.economy.commutes>0);
});
test('only stocked purchases count, simultaneous shoppers share exactly the available stock',()=>{
  const w=lineWorld(),home=building(w,7,11,'house'),shop=building(w,8,11,'shop');
  const people=[newResident(w,home),newResident(w,home)];w.residents=people;for(const p of people){p.food=0;p.destination=shop;p.x=8;p.y=11;p.route=[home,home+24,shop+24,shop];p.routeIndex=3;p.state='shop';p.timer=0;p.shop=shop;}
  w.cells[shop].stock=2;advanceWorld(w,.25);assert.equal(w.economy.visits,2);assert.equal(w.cells[shop].stock,0);assert.equal(people[0].food,people[1].food);assert.ok(people[0].food<1&&people[0].food>.99);
  for(const p of people){p.destination=shop;p.x=8;p.y=11;p.route=[shop];p.routeIndex=0;p.progress=0;p.state='shop';p.timer=0;}
  const before=w.economy.visits;advanceWorld(w,.25);assert.equal(w.economy.visits,before);assert.equal(w.economy.failedPurchases,2);
});
test('cargo retains conserved stock and cannot feed across a broken bridge',()=>{
  const w=lineWorld(),farm=building(w,8,11,'farm'),shop=building(w,16,11,'shop');w.cells[farm].stock=40;const route=findRoute(w,farm,shop)!;
  w.shipments=[{id:0,from:farm,to:shop,food:10,materials:0,route,routeIndex:route.indexOf(12*24+11),progress:.4,blocked:false}];w.nextShipmentId=1;w.cells[farm].stock-=10;const bridge=w.cells[12*24+12];bridge.condition=0;bridge.closed=true;w.topologyVersion++;
  advanceWorld(w,10);assert.equal(w.cells[shop].stock,0);assert.equal(w.shipments[0].food,10);assert.equal(w.shipments[0].progress,.4);assert.equal(w.shipments[0].blocked,true);assert.equal(w.economy.food,40);assertInvariants(w);
});
test('hunger has a grace period, then reduces health and can end society without automatic respawn',()=>{
  const w=lineWorld(),home=building(w,8,11,'house');const p=newResident(w,home,'dependent');p.food=0;w.residents=[p];w.migrationGrace=45;
  advanceWorld(w,45);assert.equal(p.health,100);assert.ok(p.hunger>1);advanceWorld(w,45);assert.ok(p.health<100);
  advanceWorld(w,45*15);assert.equal(w.residents.length,0);const clock=w.clock;const vegetation=w.cells[0].vegetation;advanceWorld(w,45*2);assert.ok(w.clock>clock);assert.equal(w.residents.length,0);assert.ok(w.cells[0].vegetation!==vegetation||w.cells[0].moisture!==55);
  queuePower(w,{kind:'growth',target:{x:6,y:6},radius:4,intensity:2,duration:10});advanceWorld(w,1);assert.equal(w.residents.length,0);
  queuePower(w,{kind:'settle',target:{x:6,y:6},radius:4,intensity:1,duration:1});advanceWorld(w,.25);assert.ok(w.residents.length>0);assert.ok(w.economy.food>0&&w.economy.materials>0);assert.ok(w.stats.farms>0&&w.stats.homes>0);assertInvariants(w);
});
test('dead residents stay dead after migration grace; survivors evacuate on roads and ruins rebuild with labour',()=>{
  const extinct=createWorld(4821);extinct.migrationGrace=0;queuePower(extinct,{kind:'meteor',target:{x:24,y:24},radius:48,intensity:4,duration:0});advanceWorld(extinct,.25);assert.equal(extinct.residents.length,0);assert.equal(extinct.economy.deaths,96);
  const w=lineWorld(),home=building(w,8,11,'house'),park=building(w,10,11,'park');w.cells[park].level=0;w.cells[park].vitality=0;const person=newResident(w,home);w.residents=[person];Object.assign(w.cells[home],{kind:'ruin',level:0,vitality:0,population:0,condition:0,rubble:5,closed:true});w.topologyVersion++;
  advanceWorld(w,.25);assert.equal(person.displaced,true);assert.equal(person.state,'travel');assert.ok(Math.abs(person.x-8)<.001,'evacuation begins from the lost home');advanceWorld(w,10);assert.equal(person.shelter,park);assert.equal(person.state,'shelter');
  const road=12*24+8;w.cells[home].buildingPlan='house';w.cells[home].development=90;w.cells[road].materials=20;person.route=[road];person.routeIndex=0;person.progress=0;person.x=8;person.y=12;person.destination=road;person.state='repair';person.timer=999;advanceWorld(w,15);assert.equal(w.cells[home].kind,'house');assert.equal(w.cells[home].closed,false);assert.equal(w.cells[home].rubble,0);
});
test('repair and construction use present workers plus delivered materials; age alone causes no free repair',()=>{
  const w=lineWorld(),home=building(w,8,11,'house');w.cells[home].condition=60;w.cells[home].age=5000;const p=newResident(w,home);p.food=10;p.timer=999;w.residents=[p];w.migrationGrace=0;
  advanceWorld(w,1);assert.equal(w.cells[home].condition,60);w.cells[home].materials=2;advanceWorld(w,1);assert.ok(w.cells[home].condition>60);assert.ok(w.cells[home].materials<2);
  const road=12*24+9,target=11*24+9;w.cells[target].buildingPlan='house';w.cells[target].development=90;w.cells[road].materials=20;
  p.route=[road];p.routeIndex=0;p.progress=0;p.x=9;p.y=12;p.destination=road;p.state='repair';p.timer=999;advanceWorld(w,20);assert.equal(w.cells[target].kind,'house');assert.equal(w.cells[target].population,0,'building completion does not create people');assert.ok(w.cells[road].materials<20);
});
test('surviving local materials can rebuild a lost factory without fabricated resource grants',()=>{
  const w=createWorld(4821);w.naturalPolicy='off';for(const c of w.cells)if(c.kind==='factory')Object.assign(c,{kind:'ruin',level:0,vitality:0,population:0,condition:0,rubble:5,materials:0,closed:true});w.topologyVersion++;
  advanceWorld(w,DAY_SECONDS*8);assert.ok(w.stats.factories>0,'reachable household reserves bootstrap material production');assert.ok(w.stats.born>0);assert.ok(w.economy.materials>0);assertInvariants(w);
});
test('ordinary undisturbed towns keep real activity and can grow through arrivals for two years',()=>{
  for(const seed of [0,42]) {const w=createWorld(seed);w.naturalPolicy='off';advanceWorld(w,DAY_SECONDS*96);assert.ok(w.stats.population>96);assert.ok(w.economy.commutes>0&&w.economy.visits>0);assert.ok(w.stats.farms>0&&w.stats.homes>0);assert.equal(w.economy.deaths,0);assertInvariants(w);}
});
test('extinct wet land regrows from nearby trees while dry land withers, without automatic settlers',()=>{
  const w=lineWorld();for(let y=3;y<11;y++)for(let x=3;x<11;x++)Object.assign(w.cells[y*24+x],{kind:x%3===0&&y%3===0?'tree':'grass',moisture:80,fertility:85,vegetation:90});
  const dry=w.cells[3*24+19];dry.moisture=0;dry.vegetation=80;const trees=w.cells.filter(c=>c.kind==='tree').length;advanceWorld(w,DAY_SECONDS*10);assert.ok(w.cells.filter(c=>c.kind==='tree').length>trees);assert.ok(dry.vegetation<80);assert.equal(w.residents.length,0);assertInvariants(w);
});
test('rain and greenery recover scorched land; a safe wooded plot can host a new settlement',()=>{
  const w=createWorld(42);w.naturalPolicy='off';w.migrationGrace=0;queuePower(w,{kind:'meteor',target:{x:24,y:24},radius:48,intensity:4,duration:0});advanceWorld(w,.25);assert.equal(w.residents.length,0);
  for(const [kind,duration] of [['rain',15],['growth',60],['sun',30]] as const){queuePower(w,{kind,target:{x:6,y:6},radius:6,intensity:4,duration});advanceWorld(w,duration);assert.equal(w.residents.length,0);}
  // Mature woodland remains a valid plot; settlers clear only their small footprint.
  for(let y=4;y<=8;y++)for(let x=4;x<=8;x++){const c=w.cells[y*48+x];if(c.terrain==='land'&&c.fire<1&&c.waterDepth<1.6){c.kind='tree';c.level=0;c.vitality=0;}}
  queuePower(w,{kind:'settle',target:{x:6,y:6},radius:6,intensity:1,duration:1});advanceWorld(w,.25);assert.equal(w.residents.length,12);assert.ok(w.economy.food>0&&w.economy.materials>0);assertInvariants(w);
});
test('V1 and V2 migration preserve population, identities, old calendar and convert timer units',()=>{
  const original=createWorld(7);for(const version of [1,2]) {const old=JSON.parse(serializeWorld(original));old.version=version;old.tick=37;old.clock=150;old.history=[{tick:36,population:96},{tick:37,population:96}];old.events=[];for(const c of old.cells){c.age=50;c.changedAt=30;}
    if(version===1)for(const key of ['residents','nextResidentId','clock','weather','economy'])delete old[key];else {old.residents=old.residents.filter((_:unknown,n:number)=>n%2===0);old.residents[0].timer=30;}
    const migrated=restoreWorld(JSON.stringify(old));assert.equal(migrated.stats.population,96);assert.equal(migrated.residents.length,96);assert.equal(migrated.legacyCalendar!.tick,37);assert.deepEqual(migrated.legacyCalendar!.history,old.history);assert.equal(migrated.cells[0].age,50*4/DAY_SECONDS);assert.equal(migrated.cells[0].changedAt,Math.floor(30*4/DAY_SECONDS));assert.ok(migrated.migrationGrace>0);if(version===2){assert.equal(migrated.residents[0].id,old.residents[0].id);assert.equal(migrated.residents[0].timer,9);}assertInvariants(migrated);
  }
});
test('V3 validates bounded fields, finite positions, identity, stock totals and disconnected saved journeys',()=>{
  const initial=serializeWorld(createWorld(7));const corrupt=(change:(w:any)=>void)=>{const w=JSON.parse(initial);change(w);assert.throws(()=>restoreWorld(JSON.stringify(w)),/読み込めません/);};
  assert.throws(()=>restoreWorld('{bad'),/JSON/);assert.throws(()=>restoreWorld('x'.repeat(12_000_001)),/大き/);
  for(const change of [(w:any)=>w.version=4,(w:any)=>w.size=48.5,(w:any)=>w.clock=1,(w:any)=>w.rng=null,(w:any)=>w.cells.pop(),(w:any)=>w.cells[0].x=1,(w:any)=>w.cells[0].buildingPlan='castle',(w:any)=>w.cells[0].stock=-1,(w:any)=>w.residents[0].progress=null,(w:any)=>w.residents[1].id=w.residents[0].id,(w:any)=>w.residents[0].health=101,(w:any)=>w.residents[0].home=100000,(w:any)=>w.economy.food++,(w:any)=>w.stats.population++,(w:any)=>w.pending=[{id:0}],(w:any)=>w.history=[]])corrupt(change);
  const queued=createWorld(7);queuePower(queued,{kind:'rain',target:{x:10,y:10},radius:3,intensity:1,duration:2});const valid=serializeWorld(queued);for(const mutate of [(c:any)=>c.intensity=100,(c:any)=>c.duration=3601,(c:any)=>c.duration=.3,(c:any)=>c.radius=100,(c:any)=>c.target.x=10.5,(c:any)=>c.atStep=0]){const saved=JSON.parse(valid);mutate(saved.pending[0]);assert.throws(()=>restoreWorld(JSON.stringify(saved)),/読み込めません/);}
});
