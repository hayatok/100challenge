import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { LENSES, lensMeasures, lensTracks, comparisonRecords, comparisonPayload, figureUnit, chapterAt, validateEducation, educationEvents } from '../app/src/education-data.js';
import { chartData, observationsAt, presetTracks } from '../app/src/charts.js';
import { mergeHistory, eventYear } from '../app/src/history-data.js';

const readJSON=async name=>JSON.parse(await readFile(new URL(`../app/data/${name}.json`,import.meta.url)));
const [frozen,expansion,drivers,lessons,media]=await Promise.all(['archive','history-expanded','drivers','lessons','media'].map(readJSON));
const archive=mergeHistory(frozen,expansion);
const tracks=(id,measure)=>lensTracks(archive,drivers,id,measure);
const dated=ts=>chartData(ts).panels.flatMap(panel=>panel.segments.flatMap(segment=>segment.points));
const years=ts=>[...new Set(dated(ts).map(p=>p.year))].sort((a,b)=>a-b);

test('seven lenses expose their default descriptions and all offered measures have real records',()=>{
  assert.deepEqual(LENSES.map(l=>l.id),['population','work','food','prices','education','communication','housing']);
  const defaults={population:'population',work:'agriculture',food:'rice',prices:'cpi',education:'primary',communication:'computer',housing:'housing'};
  for(const lens of LENSES){
    const measures=lensMeasures(lens.id);
    assert.equal(measures[0].id,defaults[lens.id]);
    assert.equal(measures[0].question,lens.question);
    assert.equal(measures[0].intro,lens.intro);
    assert.deepEqual(tracks(lens.id),tracks(lens.id,measures[0].id));
    for(const m of measures){assert.ok(m.label&&m.question&&m.intro&&m.kind);assert.ok(dated(tracks(lens.id,m.id)).length>0);}
  }
  assert.equal(lensMeasures('work').length,3);
  assert.equal(lensMeasures('education').length,2);
  assert.equal(lensMeasures('communication').length,3);
  assert.doesNotMatch(lensMeasures('work')[0].question,/どこへ|向かった|移った/);
  for(const [lens,driver] of [['population','population'],['food','rice'],['prices','prices'],['housing','housing']])assert.deepEqual(tracks(lens),presetTracks(archive,drivers,driver));
});

test('agriculture and manufacturing retain original survey segments without the wrong industry label',()=>{
  const driver=drivers.drivers.find(d=>d.id==='industry');
  for(const [measure,index,pattern] of [['agriculture',0,/農業/],['manufacturing',1,/製造業/]]){
    const ts=tracks('work',measure);
    assert.equal(ts.length,5);
    for(const [i,t] of ts.entries()){
      assert.equal(t.entry,archive.series.find(s=>s.id===driver.segments[i].seriesIds[index]));
      assert.match(t.label,pattern);
      assert.deepEqual(t.boundaries,driver.boundaries);
      assert.equal(t.from,Number(driver.segments[i].from.slice(0,4)));
      assert.equal(t.through,Number(driver.segments[i].through.slice(0,4))+Number(driver.segments[i].through.slice(5,7))/12-1e-5);
    }
    assert.deepEqual(chartData(ts).panels.map(p=>p.unit),['人','万人']);
    assert.deepEqual(years(ts).slice(0,4),[1920,1930,1940,1950]);
    assert.deepEqual(years(ts).slice(-3),[2023,2024,2025]);
  }
  assert.doesNotMatch(tracks('work','agriculture')[1].label,/製造業/);
  assert.match(tracks('work','agriculture')[1].label,/農業・林業/);
  assert.match(tracks('work','manufacturing')[1].label,/旧産業分類/);
  assert.equal(observationsAt(tracks('work','agriculture'),1953)[0].point.raw,'1487');
  assert.equal(observationsAt(tracks('work','manufacturing'),1953)[0].point.raw,'720');
});

test('primary education includes 1948–2024 and separates unconfirmed units from 2017 onward',()=>{
  const ts=tracks('education');
  assert.deepEqual(years(ts),Array.from({length:77},(_,i)=>1948+i));
  assert.equal(observationsAt(ts,1948)[0].point.raw,'10774652');
  assert.equal(observationsAt(ts,2016)[0].point.raw,'6386207');
  assert.equal(observationsAt(ts,2017)[0].point.raw,'6448658');
  assert.equal(observationsAt(ts,2024)[0].point.raw,'5941733');
  assert.match(ts[0].entry.unit,/単位文字列未取得/);
  assert.equal(ts[1].entry.unit,'人');
  assert.deepEqual(comparisonRecords(ts).map(r=>r.point.year),Array.from({length:69},(_,i)=>1948+i));
  assert.deepEqual(comparisonRecords(ts,'人').map(r=>r.point.year),Array.from({length:8},(_,i)=>2017+i));
  assert.equal(figureUnit(comparisonRecords(ts)[0]),'');
  assert.deepEqual(ts[1].boundaries,drivers.drivers.find(d=>d.id==='education').boundaries);
  assert.ok(chartData(ts).panels.every(panel=>panel.segments.every(s=>!s.paths.some(path=>path.some(p=>p.year===2016)&&path.some(p=>p.year===2017)))));
});

test('university advancement retains its real denominator label and 1954–2016 observations',()=>{
  const ts=tracks('education','advancement');
  assert.deepEqual(years(ts),Array.from({length:63},(_,i)=>1954+i));
  assert.equal(ts[0].entry.statId,'SD-STAT004');
  assert.equal(ts[0].entry.unit,'％');
  assert.match(ts[0].label,/学部.*本科.*過年度高卒者/);
  assert.equal(observationsAt(ts,1954)[0].point.raw,'10.1');
  assert.equal(observationsAt(ts,2016)[0].point.raw,'56.8');
});

test('computer, smartphone and mobile records keep device definitions and unobserved years separate',()=>{
  const pc=tracks('communication');
  assert.ok(pc.every(t=>/パソコン/.test(t.entry.label)&&t.entry.unit==='%'));
  assert.deepEqual(years(pc),[1996,1997,1998,1999,2000,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016]);
  assert.deepEqual(years(tracks('communication','smartphone')),[2010,2011,2012,2013,2014,2015,2016]);
  const mobile=tracks('communication','mobile');
  assert.equal(mobile.length,3);
  assert.deepEqual(years(mobile),[1996,1997,1998,1999,2000,2005,2006,2007,2008,2013,2014,2015,2016]);
  assert.match(mobile[2].entry.label,/^携帯電話\(PHSを含む\)/);
  assert.ok(!mobile.some(t=>/cat01=(130|140|150):/.test(t.entry.id)));
  assert.equal(observationsAt(mobile,2009).length,0);
  assert.equal(observationsAt(mobile,2012).length,0);
  assert.ok(!chartData(mobile).panels[0].segments.some(s=>s.paths.some(path=>path.some(p=>p.year===2008)&&path.some(p=>p.year===2013))));
});

test('unemployment keeps individual months and original missing symbols without turning them into zero',()=>{
  const ts=tracks('work','unemployment'),points=dated(ts),records=comparisonRecords(ts);
  assert.equal(points.length,704);
  assert.equal(records.length,698);
  assert.equal(points[0].timeLabel,'1968年1月');
  assert.equal(points.at(-1).timeLabel,'2026年8月');
  const missing=points.filter(p=>p.kind!=='number');
  assert.deepEqual(missing.map(p=>p.timeLabel),[3,4,5,6,7,8].map(m=>`2011年${m}月`));
  assert.ok(missing.every(p=>p.raw==='…'&&p.value===null));
  assert.equal(comparisonPayload(records.at(-1)).year,'2026年8月');
  assert.equal(new Set(records.map(r=>r.key)).size,698);
  const absent=observationsAt(tracks('work'),2011)[0];
  assert.equal(absent.point.raw,'…');
  assert.equal(comparisonPayload(absent).value,null);
  // The archive has no numerical zero. Inject one into a copied real series
  // to verify the selector's zero branch without changing original records.
  const zero={...records[0].point,id:'known-zero',value:0,raw:'0'};
  const copied=[{...ts[0],entry:{...ts[0].entry,points:[zero,missing[0]]}}];
  assert.deepEqual(comparisonRecords(copied).map(r=>r.point.raw),['0']);
  assert.equal(comparisonPayload(comparisonRecords(copied)[0]).value,0);
});

test('chapters cover every year once and connect real photos, events, living records and sources',()=>{
  assert.equal(validateEducation(lessons,media,archive),true);
  for(let year=1900;year<=2026;year++){
    const matches=lessons.chapters.filter(c=>year>=c.from&&year<=c.through);
    assert.equal(matches.length,1);
    assert.equal(chapterAt(lessons.chapters,year),matches[0]);
  }
  for(const c of lessons.chapters){
    assert.ok(media.items.some(p=>p.chapters.includes(c.id)&&p.year>=c.from&&p.year<=c.through));
    for(const id of c.eventIds){const e=archive.events.find(e=>e.id===id);assert.ok(eventYear(e)>=c.from&&eventYear(e)<=c.through);}
    for(const id of c.livingIds)assert.ok(archive.living.some(l=>l.id===id));
    for(const id of c.sourceIds)assert.ok(archive.sources.some(s=>s.id===id));
  }
});

test('validation catches broken photo coordinates, URLs, references, duplicate chapters and gaps',()=>{
  const bad=(edit)=>{const l=structuredClone(lessons),m=structuredClone(media);edit(l,m);assert.throws(()=>validateEducation(l,m,archive));};
  bad((l,m)=>{m.items[0].hotspots[0].x=101;});
  bad((l,m)=>{m.items[0].sourceUrl='javascript:alert(1)';});
  bad((l,m)=>{m.items[0].chapters=['unknown-chapter'];});
  bad((l,m)=>{m.items[0].year=2020;});
  bad(l=>{l.chapters[0].eventIds.push('unknown-event');});
  bad(l=>{l.chapters[0].focus[0].livingIds.push('unknown-record');});
  bad(l=>{l.chapters[0].sourceIds.push('unknown-source');});
  bad(l=>{l.chapters[1].id=l.chapters[0].id;});
  bad(l=>{l.chapters[1].from++;});
  bad((l,m)=>{m.items=m.items.filter(p=>!p.chapters.includes('present'));});
});

test('only three confirmed same-event pairs are grouped and each original description and source remains reachable',()=>{
  const before=JSON.stringify(archive.events),shown=educationEvents(archive.events);
  assert.equal(shown.length,391);
  assert.equal(JSON.stringify(archive.events),before);
  for(const id of ['H2-E024','H2-E016','H-E102']){
    const e=shown.find(e=>e.id===id);assert.equal(e.relatedRecords.length,2);
    assert.deepEqual(new Set(e.source_ids),new Set(e.relatedRecords.flatMap(r=>r.source_ids)));
    assert.ok(e.relatedRecords.every(r=>archive.events.includes(r)));
  }
  for(const id of ['H-E015','L-E007','H-E033','L-E011'])assert.ok(shown.some(e=>e.id===id));
});
