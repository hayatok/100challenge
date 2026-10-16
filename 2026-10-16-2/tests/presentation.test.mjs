import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { observationTime, pointsThrough, materialStatus, recordNotes, readableResearchText, eraLabel, materialInYear, regionalMaterial, period } from '../app/src/presentation.js';
const archive = JSON.parse(readFileSync(new URL('../app/data/archive.json', import.meta.url)));
test('a month before an era change keeps the old era, and a transition month names both eras', () => {
  assert.equal(eraLabel(2019, 1), '平成31年');
  assert.equal(eraLabel(2019, 5), '令和元年');
  assert.equal(eraLabel(1912, 7), '明治45年／大正元年');
  assert.equal(eraLabel(1926, 12), '大正15年／昭和元年');
  assert.equal(eraLabel(1989, 1), '昭和64年／平成元年');
});
test('the monthly preview does not expose later months as an earlier month; distinct months get distinct plot coordinates', () => {
  const bus = archive.series.find(series => series.statId === 'EST05' && series.dimensions.area === '00001');
  const january = pointsThrough(bus, 2019, 1);
  const december = pointsThrough(bus, 2019, 12);
  assert.equal(january.at(-1).timeLabel, '2019年1月');
  assert.equal(december.length - january.length, 11);
  assert.equal(new Set(december.filter(point => point.year === 2019).map(observationTime)).size, 12);
});
test('unread and catalog-only materials retain their confirmation limits, and missing markers render as readable notes', () => {
  const unread = archive.living.find(item => item.id === 'L2-M002');
  assert.match(materialStatus(unread), /本文は読み取れていません/);
  assert.match(materialStatus({ verification: 'catalog_verified' }), /本文の内容は未確認/);
  const table = archive.statistics.find(stat => stat.id === 'EST09');
  assert.ok(recordNotes(table.missing_periods).includes('該当数字がないもの'));
  assert.equal(recordNotes(table.missing_periods).some(note => String(note).includes('[object Object]')), false);
  const notes = archive.gaps.map(item => readableResearchText(`${item.description} ${item.remaining_reason || ''}`)).join(' ');
  assert.equal(/evidence\/|SD-GAP\d+|receipt/.test(notes), false);
  const sources = archive.sources.map(item => readableResearchText(item.perspective_limit)).join(' ');
  assert.equal(/\b(?:tab|area|cat\d+|axis|time)\s*=/.test(sources), false);
  assert.match(readableResearchText('大学は学部のみ。cat01=E6302、tab=00001。2016年の不一致は未解決。'), /2016年の不一致は未解決/);
});
test('open or unknown living periods cannot be silently assigned to the endpoint year', () => {
  const open = archive.living.find(item => item.id === 'L3-M003');
  assert.equal(open.period_start, null);
  assert.equal(materialInYear(open, 1943), false);
  const known = archive.living.find(item => item.id === 'L3-M007');
  assert.equal(materialInYear(known, 1937), true);
  assert.equal(materialInYear(known, 1936), false);
  assert.equal(materialInYear(known, 1938), false);
});
test('regional records can be found without claiming a fictional town is the historic location', () => {
  const northern = archive.living.find(item => item.id === 'L3-M004');
  const southern = archive.living.find(item => item.id === 'L3-M005');
  assert.equal(regionalMaterial(northern, 'koshin'), true);
  assert.equal(regionalMaterial(northern, 'okinawa'), false);
  assert.equal(regionalMaterial(southern, 'okinawa'), true);
  assert.equal(regionalMaterial(southern, 'kanto'), false);
});
test('readable periods retain an unknown start or end instead of suggesting a closed date', () => {
  assert.equal(period(null, 1943), '始まり不詳〜1943年');
  assert.equal(period(1900, null), '1900年〜終わり不詳');
  assert.equal(period(null, null), '年代を確かめきれていない記録');
  assert.equal(period('1937-01', '1937-03'), '1937年1月〜1937年3月');
  assert.equal(period('1934-07-03', '1934-07-03'), '1934年7月3日');
});
