import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createSimulation,snapshot,seek,advance,reroll,selectPerson,selectPlace,serializeSimulation,restoreSimulation,PLACES } from '../app/src/model.js';
const archive=JSON.parse(readFileSync(new URL('../app/data/archive.json',import.meta.url),'utf8'));
const drivers=JSON.parse(readFileSync(new URL('../app/data/drivers.json',import.meta.url),'utf8'));
const create=(options={})=>createSimulation(archive,drivers,options);
const snap=(year,month=1)=>snapshot(create({year,month,seed:42}));

test('seed changes fictional lives and placement while leaving all evidence invariant',()=>{
  const a=snap(2000),b=snapshot(reroll(create({year:2000,seed:42}),771));
  assert.deepEqual(a.macro,b.macro);assert.deepEqual(a.events,b.events);assert.deepEqual(a.activeEvents,b.activeEvents);assert.deepEqual(a.living,b.living);
  assert.deepEqual(a.world.directives,b.world.directives);
  assert.notDeepEqual(a.world.people,b.world.people);assert.notDeepEqual(a.world.buildings,b.world.buildings);
  assert.equal(a.world.places.length,12);assert.equal(PLACES.length,12);
  assert.equal(a.world.people.length,a.world.directives.personCount);
});

test('seeded local coordinates spread across the isometric town instead of collapsing into one column',()=>{
  const buildings=snap(2000).world.buildings;
  const projected=buildings.map(building=>building.x-building.y);
  assert.ok(Math.max(...projected)-Math.min(...projected)>.8);
  assert.ok(projected.some(x=>x<-.3)&&projected.some(x=>x>.3));
  assert.ok(buildings.every(b=>b.x>=0&&b.x<=1&&b.y>=0&&b.y<=1));
});

test('seeking backward and jumping reproduce exactly the same seeded world',()=>{
  const original=create({seed:829,year:1987,month:6});
  const returned=seek(seek(advance(original,24.75),1900,1),1987,6);
  assert.deepEqual(snapshot(returned),snapshot(original));
  assert.deepEqual(snapshot(create({seed:829,year:1987,month:6})),snapshot(original));
  assert.equal(snapshot(original).month,6);assert.equal(snapshot(advance(original,.25)).month,6);
  const moved=snapshot(advance(original,.25)).world.people;
  assert.ok(snapshot(original).world.people.some((person,i)=>person.x!==moved[i].x||person.y!==moved[i].y));
});

test('original values, units, time labels and evidence references are retained verbatim',()=>{
  const {macro}=snap(1975);
  const p=macro.population;
  assert.equal(p.status,'exact');assert.equal(p.value,111939643);assert.equal(p.point.timeLabel,'1975年度');assert.equal(p.unit,'人');
  const sourceSeries=archive.series.find(s=>s.id===p.series.id);
  assert.equal(p.point,sourceSeries.points.find(o=>o.id===p.point.id));
  assert.equal(p.source,archive.sources.find(s=>s.id===p.series.sourceId));
  assert.equal(macro.prices.unit,'指数（2025年=100）');
  assert.equal(macro.education.unit,'単位文字列未取得。表章名「在学者数」');
});

test('pre-1975 population is an author model; observations are neither extrapolated nor interpolated',()=>{
  const early=snap(1900),lastEarly=snap(1974),first=snap(1975),housing=snap(1980),latest=snap(2026);
  assert.equal(early.macro.population.status,'unavailable');assert.equal(lastEarly.macro.population.value,null);
  assert.equal(early.world.directives.personCount,180);assert.equal(early.world.directives.populationBasis,'author');
  assert.equal(first.world.directives.personCount,Math.round(111939643/600000));
  assert.equal(housing.macro.housing.status,'historical');assert.equal(housing.macro.housing.point.year,1978);
  assert.equal(latest.macro.population.status,'historical');assert.equal(latest.macro.population.point.year,2024);
  assert.equal(latest.macro.population.value,123802000);
});

test('monthly bus observations respect the month and never become an invented annual average',()=>{
  assert.equal(snap(2010,9).macro.bus.status,'unavailable');
  const october=snap(2010,10).macro.bus;
  assert.equal(october.status,'exact');assert.equal(october.point.timeLabel,'2010年10月');assert.equal(october.value,357839);
  const april=snap(2020,4).macro.bus;
  assert.equal(april.status,'historical');assert.equal(april.point.timeLabel,'2020年3月');assert.equal(april.value,295010);
  assert.equal(snap(2026).macro.bus.point.timeLabel,'2020年3月');
});

test('a raw missing marker stops historical fallback instead of substituting an older value or zero',()=>{
  const copied=structuredClone(archive),id=drivers.drivers.find(d=>d.id==='population').seriesIds[0];
  const missing=copied.series.find(s=>s.id===id).points.find(p=>p.year===1980);
  missing.value=null;missing.kind='missing';missing.raw='…';
  const s=snapshot(createSimulation(copied,drivers,{year:1980}));
  assert.equal(s.macro.population.status,'unavailable');assert.equal(s.macro.population.value,null);assert.equal(s.macro.population.point.raw,'…');
  assert.equal(s.world.directives.populationBasis,'author');assert.equal(s.world.directives.personCount,180);
  assert.equal(snapshot(createSimulation(copied,drivers,{year:1981})).macro.population.status,'exact');
  const bus=copied.series.find(s=>s.id===drivers.drivers.find(d=>d.id==='bus').seriesIds[0]);
  const last=bus.points.at(-1);last.kind='missing';last.value=null;last.raw='***';
  const past=snapshot(createSimulation(copied,drivers,{year:2020,month:4})).macro.bus;
  assert.equal(past.status,'unavailable');assert.equal(past.point.timeLabel,'2020年3月');
});

test('industry survey and classification boundaries select distinct segments and ratio bases',()=>{
  const census=snap(1952).macro.industry,labour=snap(1953).macro.industry,old=snap(2002).macro.industry,modern=snap(2003).macro.industry;
  assert.equal(census.point.year,1950);assert.equal(census.unit,'人');assert.equal(labour.unit,'万人');
  assert.notEqual(census.series.id,labour.series.id);
  assert.match(old.observations[1].series.id,/A009/);assert.match(modern.observations[1].series.id,/010/);
  assert.equal(modern.observations[1].baseline.year,2003);assert.equal(modern.observations[1].segment,2003);
  assert.equal(snap(2003).world.directives.factoryCount,12);
  assert.equal(snap(1964).macro.rice.segment,null);assert.equal(snap(1965).macro.rice.segment,1965);
});

test('each adopted signal has an explicit draw rule tied to the selected original point',()=>{
  const s=snap(2015),d=s.world.directives,m=s.macro;
  assert.equal(d.houseCount,Math.round(m.housing.value/450000));
  assert.equal(d.emptyHouseCount,Math.round(m.housing.observations[1].value/450000));
  assert.equal(d.waterCount,Math.round(m.water.value/10000000));
  assert.equal(d.riceSacks,Math.round(m.rice.value/5));
  assert.equal(d.busCount,Math.round(m.bus.value/100000));
  assert.equal(d.priceIndex,m.prices.value);assert.equal(d.foodPriceIndex,m.prices.observations[1].value);
  assert.equal(d.farmCount,Math.round(12*m.industry.value/m.industry.baseline.value));
  assert.equal(d.studentCount,Math.round(48*m.education.value/m.education.baseline.value));
  for(const id of Object.keys(m)){assert.ok(d.rules[id]);assert.equal(d.references[id][0].pointId,m[id].point.id);}
  for(const [field,visual] of [['houseCount','houses'],['farmCount','farm'],['factoryCount','factory'],['emptyHouseCount','vacancy'],['waterCount','water'],['riceSacks','rice'],['busCount','bus']])assert.equal(s.world.places.reduce((sum,p)=>sum+p.visual[visual],0),d[field]);
  assert.equal(s.world.buildings.filter(b=>b.type==='house'&&!b.lit).length,d.emptyHouseCount);
});

test('tracking is stable across decades, death and backward seeks, with no future life journal',()=>{
  let sim=create({year:1900,seed:441});
  const person=snapshot(sim).world.people.find(p=>p.age>=18&&p.age<50&&p.childrenIds.length);
  sim=selectPerson(sim,person.id);
  const before=snapshot(sim).selectedPerson;
  assert.equal(before.name,person.name);assert.ok(before.lifeEvents.every(e=>e.year<=1900));
  assert.ok(before.family.every(p=>p.birthYear<=1900));
  const after=snapshot(seek(sim,person.deathYear+1)).selectedPerson;
  assert.equal(after.id,person.id);assert.equal(after.alive,false);assert.equal(after.activity,'人生の記録');
  assert.ok(after.lifeEvents.some(e=>e.kind==='death'));
  assert.deepEqual(snapshot(seek(seek(sim,2000),1900)).selectedPerson,before);
  const child=after.childrenIds[0];assert.ok(child);assert.equal(snapshot(selectPerson(seek(sim,person.birthYear+30),child)).selectedPerson.familyId,person.familyId);
  assert.equal(snapshot(selectPlace(sim,'kyushu')).selectedPerson,null);
});

test('fictional lifespans are unchanged when macro values or historical events change',()=>{
  const modified=structuredClone(archive);
  modified.events=[];
  const population=modified.series.find(s=>s.id===drivers.drivers[0].seriesIds[0]);
  population.points.forEach(p=>{p.value=60000000;p.raw='60000000';});
  const a=snapshot(create({year:2000,seed:7}));
  const selected=a.world.people[0].id;
  const b=createSimulation(modified,drivers,{year:2000,seed:7});
  assert.deepEqual(snapshot(selectPerson(create({year:2000,seed:7}),selected)).selectedPerson,snapshot(selectPerson(b,selected)).selectedPerson);
});

test('fictional journals vary by person and month, obey time, and record actual fictional child births',()=>{
  let sim=create({year:1950,month:5,seed:6});
  const available=snapshot(sim).world.people.filter(p=>p.childrenIds.length&&p.age>30);
  sim=selectPerson(sim,available[0].id);
  const person=snapshot(sim).selectedPerson;
  assert.ok(person.lifeEvents.filter(e=>e.kind==='daily').length>10);
  assert.ok(person.lifeEvents.every(e=>e.year<1950||(e.year===1950&&e.month<=5)));
  assert.ok(person.lifeEvents.every(e=>e.fictional));
  for(const event of person.lifeEvents.filter(e=>e.kind==='family'))assert.equal(event.year,person.childBirths.find(child=>child.id===event.personId).year);
  const activities=Array.from({length:12},(_,i)=>snapshot(seek(sim,1950,i+1)).selectedPerson.dailyEvent.activity);
  assert.ok(new Set(activities).size>=3);
  const other=snapshot(selectPerson(sim,available[1].id)).selectedPerson;
  assert.notDeepEqual(person.lifeEvents.map(e=>[e.year,e.month,e.text]),other.lifeEvents.map(e=>[e.year,e.month,e.text]));
  assert.deepEqual(snapshot(seek(seek(sim,2000),1950,5)).selectedPerson,person);
});

test('unknown-date life collections stay on the shelf; current history is a fixed dated record',()=>{
  const s=snap(1945,8);
  assert.ok(s.living.length>0);assert.ok(s.living.every(item=>item.period_start!==null&&item.period_end!==null));
  assert.ok(s.activeEvents.every(event=>event.date_start<= '1945-08-31'));
  assert.ok(s.events.every(event=>Number(event.date_start.slice(0,4))<=1945));
  for(const event of s.events)assert.equal(event,archive.events.find(e=>e.id===event.id));
});

test('time boundaries and a small strict save reproduce the same month, person and placement',()=>{
  assert.equal(snapshot(seek(create(),1800)).year,1900);
  assert.equal(snapshot(advance(create(),100000)).year,2026);assert.equal(snapshot(advance(create(),100000)).month,10);assert.equal(snapshot(advance(create(),100000)).ended,true);
  assert.throws(()=>seek(create(),2000,13));assert.throws(()=>advance(create(),NaN));
  let sim=advance(create({year:1993,month:4,seed:51}),.375);sim=selectPerson(sim,snapshot(sim).world.people[0].id);
  assert.deepEqual(snapshot(restoreSimulation(archive,drivers,serializeSimulation(sim))),snapshot(sim));
  for(const raw of ['{','null',JSON.stringify({version:2}),serializeSimulation(sim).replace('"seed":51','"seed":-1')])assert.throws(()=>restoreSimulation(archive,drivers,raw));
});
