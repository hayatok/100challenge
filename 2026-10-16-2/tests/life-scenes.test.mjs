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
