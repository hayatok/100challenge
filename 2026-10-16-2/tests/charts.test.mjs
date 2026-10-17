import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {statisticCatalogue,presetTracks,observationsAt,nearestObservation,chartData,chartTime} from '../app/src/charts.js';
const archive=JSON.parse(await readFile(new URL('../app/data/archive.json',import.meta.url)));
const drivers=JSON.parse(await readFile(new URL('../app/data/drivers.json',import.meta.url)));

test('the graph catalogue exposes all 557 original series and every original observation',()=>{
  const entries=statisticCatalogue(archive);
  assert.equal(entries.length,557);
  assert.deepEqual(new Set(entries.map(e=>e.id)),new Set(archive.series.map(e=>e.id)));
  assert.equal(entries.reduce((n,e)=>n+e.entry.points.length,0),15728);
  for(const e of entries)assert.equal(e.entry,archive.series.find(s=>s.id===e.id));
});
test('the default population graph starts in 1900 and keeps early scopes and the 1975 switch visible',()=>{
  const tracks=presetTracks(archive,drivers,'population'),early=observationsAt(tracks,1900);
  assert.equal(early.length,1);assert.equal(early[0].point.raw,'43847000');
  assert.match(early[0].track.label,/旧内地/);
  assert.deepEqual(chartData(tracks).range,[1900,2026]);
  for(let year=1900;year<=1974;year++)assert.equal(observationsAt(tracks,year).length,1,`${year} has the original early observation`);
  assert.match(observationsAt(tracks,1967)[0].track.label,/日本人人口/);
  assert.match(observationsAt(tracks,1975)[0].track.label,/総人口/);
  assert.equal(observationsAt(tracks,2026).length,0);
});
test('wartime absence is not a zero and neither a missing symbol nor a scope change is joined',()=>{
  const births=presetTracks(archive,drivers,'SD-STAT001:cat01=00110');
  assert.equal(observationsAt(births,1900)[0].point.raw,'1420534');
  for(const year of [1944,1945,1946])assert.equal(observationsAt(births,year).filter(({point})=>point.kind==='number').length,0);
  const paths=chartData(births).panels[0].segments[0].paths;
  assert.ok(!paths.some(path=>path.some(p=>p.year===1943)&&path.some(p=>p.year===1947)));
  const industry=presetTracks(archive,drivers,'industry'),missing=observationsAt(industry,2011)[0];
  assert.equal(missing.point.raw,'…');assert.equal(missing.point.value,null);
  assert.equal(nearestObservation(industry,2011).point.raw,'…');
  assert.equal(chartData(industry).panels.length,2,'people and ten-thousand people keep separate scales');
  const housing=presetTracks(archive,drivers,'housing');
  assert.equal(nearestObservation(housing,1925,{range:[1900,1945]}),null,'an empty viewport cannot visit a future observation');
  assert.ok(nearestObservation(industry,2012,{range:[2000,2026],unit:'万人'}));
  assert.equal(nearestObservation(industry,2012,{range:[2000,2026],unit:'人'}),null,'different-unit panels cannot steal each other\'s points');
});
test('monthly, quarterly and half-year observations have distinct original-period plot coordinates',()=>{
  for(const label of ['1994年1～3月期','1994年4～6月期','1994年7～9月期','1994年10～12月期']){
    assert.equal(chartTime({year:1994,timeLabel:label}),1994+Number(label.match(/年(\d+)/)[1]-1)/12);
  }
  assert.notEqual(chartTime({year:2013,timeLabel:'2013年度4～9月期'}),chartTime({year:2013,timeLabel:'2013年度10～3月期'}));
  const gdp=archive.series.find(e=>e.statId==='EST02');
  assert.equal(new Set(gdp.points.filter(p=>p.year===1994).map(chartTime)).size,4);
});

test('the original-series detail also keeps documented scope breaks',()=>{
  const id=archive.series.find(e=>e.statId==='D3-ST001'&&/^総数/.test(e.label)).id;
  const tracks=presetTracks(archive,drivers,id),data=chartData(tracks);
  assert.ok(observationsAt(tracks,2024).length,'full original series is retained');
  assert.ok(tracks[0].boundaries.some(b=>b.year===1945));
  for(const segment of data.panels[0].segments)for(const path of segment.paths)for(const b of tracks[0].boundaries)assert.ok(!path.some(p=>p.year<b.year)||!path.some(p=>p.year>=b.year));
});

test('monthly method changes split in April without inventing a January break',()=>{
  const bus=drivers.drivers.find(d=>d.id==='bus'),old=presetTracks(archive,drivers,bus.seriesIds[0]);
  const paths=chartData(old).panels[0].segments[0].paths;
  assert.ok(paths.some(path=>path.some(p=>p.timeLabel==='2019年12月')&&path.some(p=>p.timeLabel==='2020年1月')));
  const start=observationsAt(old,2020).map(r=>r.point);
  const newer=presetTracks(archive,drivers,bus.seriesIds[1]);
  const april=observationsAt(newer,2020).map(r=>r.point).find(p=>p.timeLabel==='2020年4月');
  assert.ok(april&&start.length===3);
  // A copied fixture isolates the boundary logic without changing either source.
  const combined=[{...old[0],entry:{...old[0].entry,points:[...start,april]}}];
  const split=chartData(combined).panels[0].segments[0].paths;
  assert.ok(split.some(path=>path.length===3&&path[2].timeLabel==='2020年3月'));
  assert.ok(split.some(path=>path.length===1&&path[0]===april));
});
