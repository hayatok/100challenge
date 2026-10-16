import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {getYearRecords} from '../app/src/model.mjs';

const history=JSON.parse(readFileSync(new URL('../app/data/history.json',import.meta.url),'utf8'));
const copy=JSON.parse(readFileSync(new URL('../app/data/editorial.json',import.meta.url),'utf8'));

test('all events have reader-facing explanations and source locations, with uncertainties retained',()=>{
  assert.equal(copy.version,1);
  assert.deepEqual(Object.keys(copy.events).sort(),history.events.map(e=>e.id).sort());
  for(const event of history.events){
    const record=copy.events[event.id];
    for(const key of ['summary','locator'])assert.ok(typeof record[key]==='string'&&record[key].trim(),`${event.id}.${key}`);
    if(event.disputed_or_qualified)assert.ok(typeof record.qualification==='string'&&record.qualification.trim(),`${event.id} lost its qualification`);
    else assert.equal(record.qualification,null);
    assert.doesNotMatch(Object.values(record).join('\n'),/採用|台帳|\bgap\b|\bAPI\b|未取得|起点|TODO|メタデータ|(?:H2|H|L2|L|E2|SD2)-[ESM]\d+/i,event.id);
  }
});

test('explicit event periods appear across their years, without extending point events',()=>{
  for(const year of [1986,1987,1991])assert.ok(getYearRecords(history,year).events.some(e=>e.id==='H-E081'));
  assert.ok(!getYearRecords(history,1992).events.some(e=>e.id==='H-E081'));
  assert.ok(!getYearRecords(history,1986).events.some(e=>e.id==='H-E060'));
});
