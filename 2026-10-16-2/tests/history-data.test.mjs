import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mergeHistory, eventYear, eventDateLabel, chapterForYear, HISTORY_CHAPTERS, HISTORY_THEMES, eventThemeIds, filterHistory, eventsForYear, eventInRegion } from '../app/src/history-data.js';

const read = async file => JSON.parse(await readFile(new URL(`../app/data/${file}`, import.meta.url), 'utf8'));
const archive = await read('archive.json');
const expansion = await read('history-expanded.json');

test('verified additions have precise provenance, independent ids and no repeated event titles', () => {
  assert.equal(expansion.events.length, 210);
  assert.equal(expansion.sources.length, 32);
  const sourceIds = new Set(expansion.sources.map(source => source.id));
  const originalIds = new Set([...archive.events, ...archive.sources].map(item => item.id));
  const titles = new Set(archive.events.map(event => event.title));
  for (const source of expansion.sources) {
    assert.ok(!originalIds.has(source.id));
    assert.match(source.url, /^https:\/\//);
    assert.equal(source.verification, 'content_verified');
    assert.equal(source.checked_at, '2026-10-17');
    assert.ok(source.locator && source.perspective_limit);
  }
  for (const event of expansion.events) {
    assert.ok(!originalIds.has(event.id));
    assert.ok(!titles.has(event.title), event.title);
    titles.add(event.title);
    assert.ok(event.source_ids.length && event.source_ids.every(id => sourceIds.has(id)));
    assert.ok(event.source_locator && event.summary && event.geography && event.qualification);
    assert.equal(event.verification, 'content_verified');
    assert.equal(event.date_start.length, { year: 4, month: 7, day: 10 }[event.date_precision]);
    assert.ok(event.theme_ids.every(id => HISTORY_THEMES.some(theme => theme.id === id)));
  }
});

test('merging preserves all frozen data and original records without mutation', () => {
  const before = JSON.stringify(archive);
  const additionsBefore = JSON.stringify(expansion);
  const combined = mergeHistory(archive, expansion);
  assert.equal(combined.events.length, 394);
  assert.equal(combined.sources.length, 291);
  assert.equal(combined.historyExpansion.eventCount, 210);
  assert.deepEqual(combined.counts, archive.counts);
  assert.equal(combined.series, archive.series);
  assert.equal(combined.statistics, archive.statistics);
  assert.equal(combined.living, archive.living);
  for (const event of archive.events) assert.equal(combined.events.find(item => item.id === event.id), event);
  assert.equal(JSON.stringify(archive), before);
  assert.equal(JSON.stringify(expansion), additionsBefore);
  assert.throws(() => mergeHistory(archive, {events:[archive.events[0]],sources:[]}), /Duplicate/);
  assert.throws(() => mergeHistory(archive, {events:[{id:'new',source_ids:['missing']}],sources:[]}), /Unresolved/);
});

test('year and month dates are shown without fabricated first days', () => {
  assert.equal(eventDateLabel({date_start:'1900',date_precision:'year'}), '1900年');
  assert.equal(eventDateLabel({date_start:'1960-01',date_precision:'month'}), '1960年1月');
  assert.equal(eventDateLabel({date_start:'1900-03-16',date_precision:'day'}), '1900年3月16日');
  assert.equal(eventDateLabel({date_start:null}), '時期未確認');
  assert.equal(eventYear({date_start:null}), null);
  assert.equal(eventYear({date_start:'1960-01'}), 1960);
  const values = [{id:'b',date_start:'1900-03-16'}, {id:'c',date_start:'1900-03'}, {id:'a',date_start:'1900'}];
  const result = filterHistory(values);
  assert.deepEqual(result.map(item=>item.id), ['a','c','b']);
  assert.deepEqual(result.map(item=>item.date_start), ['1900','1900-03','1900-03-16']);
});

test('chapters cover each year exactly once from 1900 through 2026', () => {
  for (let year=1900;year<=2026;year++) {
    assert.ok(chapterForYear(year));
    assert.equal(HISTORY_CHAPTERS.filter(chapter=>chapter.from<=year&&year<=chapter.through).length,1);
  }
  assert.equal(chapterForYear(1899),null);
  assert.equal(chapterForYear(2027),null);
  assert.equal(chapterForYear(1945).id,'war');
  assert.equal(chapterForYear(1946).id,'rebuilding');
});

test('search combines Japanese terms, themes, dates, chapters and explicit regions', () => {
  const events=mergeHistory(archive,expansion).events;
  const result=filterHistory(events,{query:'新潟 水道',from:1900,through:1919,region:'hokuriku'});
  assert.ok(result.some(event=>event.title==='新潟市の上水道が給水を開始'));
  assert.ok(filterHistory(events,{theme:'rural',chapter:'interwar'}).some(event=>event.title==='生振捷水路が開通'));
  assert.ok(filterHistory(events,{theme:'war',region:'koshin'}).some(event=>event.title==='松代大本営の工事が始まる'));
  assert.equal(filterHistory(events,{query:'確実に存在しない検索文言'}).length,0);
  const oki=filterHistory(events,{region:'okinawa',query:'パン給食'});
  assert.equal(oki.length,1);
  assert.equal(eventDateLabel(oki[0]),'1960年1月');
  assert.ok(eventsForYear(events,1900).length>=2);
  assert.ok(eventsForYear(events,2025).some(event=>event.title==='2025年農林業センサスの調査期日'));
  assert.ok(!eventInRegion({geography:'日本',title:'全国の制度'},'hokkaido'));
});

test('additional regional history and early decades materially expand coverage', () => {
  assert.ok(expansion.events.filter(event=>eventYear(event)<1946).length>=70);
  assert.ok(expansion.events.filter(event=>!event.region_ids.includes('national')).length>=50);
  for (const region of ['hokkaido','hokuriku','koshin','kinki','okinawa']) {
    assert.ok(filterHistory(expansion.events,{region}).length>=8,region);
  }
  for (const theme of ['rural','food','transport','communication','culture','education','war']) {
    assert.ok(expansion.events.some(event=>eventThemeIds(event).includes(theme)),theme);
  }
});

test('railway bridge openings do not imply all parallel ferry routes closed', () => {
  for (const title of ['青函トンネルを通る津軽海峡線が開業','瀬戸大橋を通る本四備讃線が開業']) {
    const event = expansion.events.find(item => item.title === title);
    assert.ok(event);
    assert.doesNotMatch(event.summary, /航路.{0,5}廃止/);
    assert.equal(event.summary, event.life_relevance);
  }
});

test('Okinawa locality notes do not assign school meals to Kyushu', () => {
  const meal = expansion.events.find(event=>event.title==='沖縄でパン給食が始まる');
  const amami = expansion.events.find(event=>event.title==='奄美群島の施政権返還');
  assert.ok(eventInRegion(meal,'okinawa'));
  assert.ok(!eventInRegion(meal,'kyushu'));
  assert.ok(eventInRegion(amami,'kyushu'));
  assert.ok(!eventInRegion(amami,'okinawa'));
  assert.ok(expansion.events.filter(event=>event.source_ids.includes('S4-OKINAWA')&&eventInRegion(event,'kyushu')).length<5);
});

test('modern additions fill documented empty years without assuming product adoption', () => {
  const combined=mergeHistory(archive,expansion);
  const modern=expansion.events.filter(event=>event.id.startsWith('E5-'));
  assert.equal(modern.length,60);
  for (let year=1970;year<=2026;year++) assert.ok(eventsForYear(combined.events,year).length>0,year);
  for (const theme of ['culture','communication','technology','everyday','work']) assert.ok(modern.filter(event=>eventThemeIds(event).includes(theme)).length>=6,theme);
  assert.ok(modern.every(event=>event.qualification&&event.source_locator));
  const closed=modern.find(event=>event.title==='FOMA・iモードのサービス終了');
  assert.equal(closed.date_start,'2026-03-31');
  assert.equal(closed.date_precision,'day');
  assert.match(closed.qualification,/特定サービス/);
  const pc=modern.find(event=>event.title==='個人向けパソコン「PC-8001」登場');
  assert.equal(pc.date_precision,'year');
  assert.match(pc.summary,/発表と出荷/);
  assert.ok(modern.some(event=>event.title==='出生時育児休業「産後パパ育休」開始'));
  assert.ok(modern.some(event=>event.title==='国立国会図書館関西館が開館'));
});
