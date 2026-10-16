import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createLifeIndex,lifeScene,sceneDestination,seasonAt } from '../app/src/life-scenes.js';
import { createSimulation,snapshot,seek,advance,reroll,selectPerson,serializeSimulation,restoreSimulation } from '../app/src/model.js';
const archive=JSON.parse(readFileSync(new URL('../app/data/archive.json',import.meta.url),'utf8'));
const drivers=JSON.parse(readFileSync(new URL('../app/data/drivers.json',import.meta.url),'utf8'));
const life=createLifeIndex(archive.living);
const person=(placeId='kanto')=>({id:'test-person',placeId,birthYear:1880,home:{x:.2,y:.3},destination:{x:.6,y:.7}});
const stops=[['L3-M008',1904,1,'sanyo'],['L3-M017',1911,2,'shikoku'],['L3-M012',1931,1,'shikoku'],['L3-M005',1934,7,'okinawa'],['L3-M007',1937,2,'kanto'],['L3-M004',1943,8,'koshin'],['L3-M006',1955,1,'kanto']];

test('all seven dated travel stops guarantee a visible source scene and matching local story across seeds',()=>{
  for(const seed of [1,6,42,771])for(const [id,year,month,placeId] of stops){
    const s=snapshot(createSimulation(archive,drivers,{seed,year,month,placeId}));
    const actor=s.world.people.find(p=>p.placeId===placeId&&p.scene.sourceMaterialIds.includes(id));
    assert.ok(actor,`${seed}/${id}`);assert.equal(actor.scene.fictional,true);
    assert.ok(s.world.localStories.some(story=>story.personId===actor.id&&story.sourceMaterialIds.includes(id)&&story.text===actor.scene.text));
    assert.ok(s.selectedPlace.atmosphere.sourceMaterialIds.includes(id));
  }
});

test('source eligibility rechecks exact months, regions, endpoint-only events and unknown dates',()=>{
  assert.equal(life.size,7);
  for(const [id,year,month,placeId] of stops){
    const p=person(placeId);p.birthYear=year-30;
    assert.ok(lifeScene(life,p,1,year,month,{sourceMaterialId:id}));
    assert.equal(lifeScene(life,{...p,placeId:'tohoku'},1,year,month,{sourceMaterialId:id}),null);
  }
  for(const [id,year,months,placeId] of [['L3-M005',1934,[6,8],'okinawa'],['L3-M007',1937,[4,12],'kanto'],['L3-M017',1911,[1,3,12],'shikoku'],['L3-M017',1916,[3,5],'shikoku']]){
    for(const month of months){
      const p={...person(placeId),birthYear:year-30};
      assert.equal(lifeScene(life,p,1,year,month,{sourceMaterialId:id}),null);
      const s=snapshot(createSimulation(archive,drivers,{year,month,seed:1}));
      assert.ok(s.world.people.every(p=>!p.scene.sourceMaterialIds.includes(id)));
    }
  }
  const malformed=structuredClone(archive.living);malformed.find(m=>m.id==='L3-M004').period_start='1943-13';
  assert.equal(createLifeIndex(malformed).has('L3-M004'),false);
});

test('season-stable scenes and weather reproduce across fractional frames, seeks and seed replay',()=>{
  const p={...person('koshin'),birthYear:1900};
  const scenes=[6,7,8].map(month=>lifeScene(life,p,42,1943,month,{sourceMaterialId:'L3-M004'}));
  assert.deepEqual(scenes[0],scenes[1]);assert.deepEqual(scenes[1],scenes[2]);
  assert.equal(seasonAt(1936,12).key,seasonAt(1937,2).key);
  const sim=createSimulation(archive,drivers,{year:1943,month:7,seed:42});
  const original=snapshot(sim),fraction=snapshot(advance(sim,.8));
  assert.deepEqual(original.world.people.map(p=>p.scene),fraction.world.people.map(p=>p.scene));
  assert.deepEqual(original.world.places.map(p=>p.atmosphere),fraction.world.places.map(p=>p.atmosphere));
  assert.deepEqual(snapshot(seek(seek(sim,2000),1943,7)),original);
  const alternate=snapshot(reroll(sim,771));
  assert.deepEqual(original.macro,alternate.macro);assert.deepEqual(original.events,alternate.events);assert.deepEqual(original.activeEvents,alternate.activeEvents);assert.deepEqual(original.living,alternate.living);
  assert.notDeepEqual(original.world.people.map(p=>p.scene),alternate.world.people.map(p=>p.scene));
});

test('pose positions, props and targets agree with the scene and actual model buildings',()=>{
  let moving=0,stationary=0,buildingTargets=0;
  for(const [,year,month] of stops){
    const s=snapshot(createSimulation(archive,drivers,{year,month,seed:42}));
    for(const p of s.world.people){
      assert.equal(p.activity,p.scene.activity);assert.equal(p.dailyEvent.text,p.scene.text);
      assert.deepEqual(p.dailyEvent.sourceMaterialIds,p.scene.sourceMaterialIds);
      if(p.scene.pose!=='walk'){stationary++;assert.deepEqual(p.from,p.to);assert.equal(p.x,p.to.x);assert.equal(p.y,p.to.y);}else moving++;
      if(['shop','farm','school'].includes(p.scene.destinationKind)){
        const target=s.world.buildings.find(b=>b.placeId===p.placeId&&b.type===p.scene.destinationKind);
        if(target){buildingTargets++;const endpoint=p.scene.pose==='walk'?[p.from,p.to].find(q=>q.x===target.x&&q.y===target.y):p.to;assert.deepEqual(endpoint,{x:target.x,y:target.y});}
      }
    }
  }
  assert.ok(moving>0&&stationary>0&&buildingTargets>0);
  assert.deepEqual(sceneDestination({destinationKind:'coast'},person(),1),{x:.94,y:.24});
});

test('tracking source scenes preserves current diary evidence, save compatibility and death records',()=>{
  let sim=createSimulation(archive,drivers,{year:1934,month:7,seed:42,placeId:'okinawa'});
  const actor=snapshot(sim).world.people.find(p=>p.scene.sourceMaterialIds.includes('L3-M005'));
  sim=selectPerson(sim,actor.id);
  const s=snapshot(sim),tracked=s.selectedPerson;
  assert.deepEqual(tracked.scene,s.world.people.find(p=>p.id===actor.id).scene);
  const current=tracked.lifeEvents.find(e=>e.kind==='daily'&&e.year===1934&&e.month===7);
  assert.deepEqual(current,tracked.dailyEvent);
  assert.ok(tracked.lifeEvents.every(e=>e.year<1934||(e.year===1934&&e.month<=7)));
  assert.deepEqual(snapshot(restoreSimulation(archive,drivers,serializeSimulation(sim))),s);
  const dead=snapshot(seek(sim,actor.deathYear)).selectedPerson;
  assert.equal(dead.alive,false);assert.equal(dead.scene,null);assert.equal(dead.dailyEvent,null);
  assert.equal(dead.age,actor.deathYear-actor.birthYear);assert.ok(dead.lifeEvents.some(e=>e.kind==='death'));
  assert.deepEqual(snapshot(seek(seek(sim,2000),1934,7)).selectedPerson,tracked);
});

test('authored day moves continuously through home, work or learning, errands, interests and return',async()=>{
  const {routineAt,dayClockAt,DAILY_CYCLE_SECONDS}=await import('../app/src/routines.js');
  const s=snapshot(createSimulation(archive,drivers,{year:1975,month:4,seed:42}));
  const roles=new Set();
  for(const p of Object.values(s.world.placePeople).flat()){
    roles.add(p.role);assert.ok(p.personality&&p.hobby&&p.occupation);assert.ok(p.sceneStages.length>=9);
    for(const stages of p.routine.days){
      assert.deepEqual(stages[0].from,p.home);assert.deepEqual(stages.at(-1).to,p.home);
      assert.equal(stages[0].startsAt,0);assert.equal(stages.at(-1).endsAt,DAILY_CYCLE_SECONDS);
      for(let i=1;i<stages.length;i++){
        assert.deepEqual(stages[i-1].to,stages[i].from,`${p.id}/${i} cannot teleport`);
        assert.equal(stages[i-1].endsAt,stages[i].startsAt);
      }
      assert.ok(stages.some(stage=>stage.phase==='work'));
      assert.ok(stages.some(stage=>stage.phase==='errand'));
      assert.ok(stages.some(stage=>stage.phase==='hobby'));
      assert.ok(stages.some(stage=>stage.phase==='social'));
    }
    let changed=false,previous=routineAt(p,0);
    for(let second=1;second<DAILY_CYCLE_SECONDS;second++){
      const current=routineAt(p,second);assert.equal(current.activity,current.scene.activity);
      if(current.x!==previous.x||current.y!==previous.y||current.scene.id!==previous.scene.id)changed=true;
      if(current.scene.pose!=='walk'){assert.deepEqual(current.from,current.to);assert.equal(current.x,current.to.x);}
      previous=current;
    }
    assert.ok(changed,`${p.id} has a changing day`);
    assert.deepEqual(routineAt(p,0).scene,routineAt(p,DAILY_CYCLE_SECONDS*3).scene);assert.deepEqual(routineAt(p,0).from,routineAt(p,DAILY_CYCLE_SECONDS*3).from);
  }
  assert.ok(roles.has('student')&&roles.has('worker')&&roles.has('elder')&&roles.has('child'));
  assert.equal(dayClockAt(0).timeLabel,'06:00');assert.equal(dayClockAt(48).timeLabel,'14:00');
});

test('routine actions respect role, region, season and technology with at least forty distinct realized actions',async()=>{
  const {routineEligible,ROUTINE_ACTIONS}=await import('../app/src/routines.js');
  const realized=new Set();
  for(const seed of [1,42])for(const year of [1900,1931,1955,1975,2005,2026])for(const month of [1,4,7,10]){
    const s=snapshot(createSimulation(archive,drivers,{year,month,seed}));
    for(const p of Object.values(s.world.placePeople).flat())for(const stages of p.routine.days)for(const stage of stages){
      const authored=ROUTINE_ACTIONS.find(a=>a.id===stage.scene.id);
      if(authored){assert.ok(routineEligible(authored,p,year,month),`${year}/${month}/${p.role}/${authored.id}`);realized.add(authored.id);}
      assert.ok(stage.scene.fictional);
      if(['phone','tablet'].includes(stage.scene.prop))assert.ok(year>=(stage.scene.prop==='phone'?2000:1985));
      if(stage.scene.prop==='bicycle')assert.ok(year>=1920);
      if(stage.scene.pose!=='walk'&&['shop','farm','school','factory','water'].includes(stage.scene.destinationKind)){
        const b=s.world.buildings.find(b=>b.placeId===p.placeId&&b.type===stage.scene.destinationKind);
        if(b)assert.deepEqual(stage.to,{x:b.x,y:b.y});
      }
    }
  }
  assert.ok(realized.size>=40,`only ${realized.size} realized actions: ${[...realized]}`);
});

test('routine relationships refer to living local relatives or peers, source stops remain bounded',async()=>{
  const {routineAt}=await import('../app/src/routines.js');
  for(const [id,year,month,placeId] of stops){
    const s=snapshot(createSimulation(archive,drivers,{year,month,placeId,seed:42}));
    const actor=s.world.people.find(p=>p.scene.sourceMaterialIds.includes(id));
    assert.ok(actor.routine.days[0].some(stage=>stage.scene.sourceMaterialIds.includes(id)));
    const all=Object.values(s.world.placePeople).flat();
    for(const p of all){
      const ids=new Set(p.relationships.map(r=>r.id));
      assert.ok(p.relationships.every(r=>r.age>=0));
      for(const stages of p.routine.days)for(const stage of stages)assert.ok(stage.companionIds.every(id=>ids.has(id)));
    }
    assert.deepEqual(routineAt(actor,25),routineAt(structuredClone(actor),25));
  }
});

test('appointments put actual visible relatives, schoolmates and neighbors together at the same clock',async()=>{
  const {routineAt,DAILY_CYCLE_SECONDS}=await import('../app/src/routines.js');
  const kinds=new Set();let encounters=0;
  for(const seed of [42,771])for(const year of [1900,1945,2005,2026]){
    const s=snapshot(createSimulation(archive,drivers,{year,month:4,seed}));
    for(const residents of Object.values(s.world.placePeople)){
      const byId=new Map(residents.map(p=>[p.id,p]));
      for(const p of residents)for(let day=0;day<3;day++){
        const clock=day*DAILY_CYCLE_SECONDS+76,current=routineAt(p,clock);
        assert.equal(current.stage.phase,'social');assert.equal(current.scene.pose,'talk');
        assert.equal(current.stage.startsAt,72);assert.equal(current.stage.endsAt,80);
        assert.ok(current.companions.length>=1&&current.companions.length<=2);
        assert.equal(current.facingId,current.companions[0].id);
        for(const companion of current.companions){
          encounters++;kinds.add(companion.kind);
          assert.ok(byId.has(companion.id),'the other person must actually be rendered in this town');
          const other=routineAt(byId.get(companion.id),clock);
          assert.equal(other.meetingId,current.meetingId);assert.equal(other.stage.phase,'social');
          assert.equal(other.placeId,current.placeId);assert.equal(other.x,current.x);assert.equal(other.y,current.y);
          assert.equal(companion.name,other.name);assert.equal(companion.occupation,other.occupation);
          assert.equal(companion.personality,other.personality);assert.equal(companion.hobby,other.hobby);
        }
        assert.deepEqual(routineAt(p,clock),routineAt(structuredClone(p),clock));
        assert.deepEqual(routineAt(p,day*DAILY_CYCLE_SECONDS+60).companions,[]);
        for(const boundary of [72,80]){
          const before=routineAt(p,day*DAILY_CYCLE_SECONDS+boundary-.00001),after=routineAt(p,day*DAILY_CYCLE_SECONDS+boundary+.00001);
          assert.ok(Math.hypot(before.x-after.x,before.y-after.y)<.00001,'arrival and departure cannot teleport');
        }
      }
    }
  }
  assert.ok(encounters>1000);for(const kind of ['parent','child','family','schoolmate','neighbor'])assert.ok(kinds.has(kind),kind);
});

test('simultaneous conversations spread across town venues without forming one central crowd',async()=>{
  const {routineAt,DAILY_CYCLE_SECONDS}=await import('../app/src/routines.js');
  const projected=p=>({x:(p.x-p.y)*320,y:(p.x+p.y-1)*174});
  const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
  for(const seed of [1,42,771,829])for(const year of [1900,1945,1985,2026]){
    const s=snapshot(createSimulation(archive,drivers,{year,month:7,seed}));
    for(const residents of Object.values(s.world.placePeople))for(let day=0;day<3;day++){
      const people=residents.map(p=>routineAt(p,day*DAILY_CYCLE_SECONDS+76));
      const groups=new Map();for(const p of people){if(!groups.has(p.meetingId))groups.set(p.meetingId,[]);groups.get(p.meetingId).push(p);}
      assert.ok(groups.size>=7,'28 residents need several independently visible conversations');
      const centers=[...groups.values()].map(g=>projected(g[0]));
      for(const group of groups.values()){
        assert.ok(group.length>=2&&group.length<=4,'a meeting remains a pair or small family group');
        assert.ok(group.every(p=>p.meetingVenue?.id===group[0].meetingVenue.id));
        assert.ok(group.every(p=>p.x>=0&&p.x<=1&&p.y>=0&&p.y<=1),'all venues remain inside the town coordinate bounds');
        assert.ok(group.every(p=>p.scene.destinationKind==='meeting'&&p.scene.venueLabel===p.meetingVenue.label));
        for(const p of group){
          assert.ok(group.every(q=>distance(projected(p),projected(q))<1e-9),'companions really meet at one venue');
          if(p.role==='child')assert.ok(p.companions.some(q=>q.age>=16),'a small child meets a family caregiver');
          const nearby=people.filter(q=>distance(projected(p),projected(q))<40);
          assert.ok(nearby.length<=4,'no more than four residents occupy one 80px-wide conversation area');
        }
      }
      for(let i=0;i<centers.length;i++)for(let j=i+1;j<centers.length;j++)assert.ok(distance(centers[i],centers[j])>=80,'independent groups must leave room for figures and gestures');
      const kinds=new Set(people.map(p=>p.meetingVenue.kind));assert.ok(kinds.size>=3,'meetings use different kinds of places');
      assert.ok(Math.max(...centers.map(p=>p.x))-Math.min(...centers.map(p=>p.x))>=350,'use the west and east of town');
      assert.ok(Math.max(...centers.map(p=>p.y))-Math.min(...centers.map(p=>p.y))>=170,'use front and rear districts');
    }
  }
});
