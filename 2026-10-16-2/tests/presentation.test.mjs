import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { observationTime, pointsThrough, materialStatus, recordNotes } from '../app/src/presentation.js';
const archive = JSON.parse(readFileSync(new URL('../app/data/archive.json', import.meta.url)));
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
});
