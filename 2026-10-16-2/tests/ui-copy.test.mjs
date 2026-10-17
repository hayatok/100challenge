import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { cleanSeriesLabel, statisticTitle, statisticDefinition, recordTitle, eventSummary, livingSummary, materialAccess, statisticNotes, citationPages, displayUnit, sourceTitle } from '../app/src/ui-copy.js';
import { GAP_COPY } from '../app/src/ui-gap-copy.js';
const archive = JSON.parse(readFileSync(new URL('../app/data/archive.json',import.meta.url)));
const additions = JSON.parse(readFileSync(new URL('../app/data/history-expanded.json',import.meta.url)));

test('all statistical choices have readable names without dropping ages, household sizes or units', () => {
  for(const entry of archive.series) assert.doesNotMatch(cleanSeriesLabel(entry.label), /#?[A-Z]\d{4,}_|\d+_|観測値|統合集計|収録版|_/);
  assert.equal(cleanSeriesLabel('全国 / 2_平日 / 1_夫 / 3_35～44歳 / 01_睡眠 / 総平均時間'), '全国 ／ 平日 ／ 夫 ／ 35～44歳 ／ 睡眠 ／ 総平均時間');
  assert.match(cleanSeriesLabel(archive.series.find(e=>e.statId==='EST04').label), /３人.*有業者１人.*30～34/);
  for(const stat of archive.statistics) { assert.ok(statisticTitle(stat)); assert.ok(statisticDefinition(stat)); }
  for(const entry of archive.series) assert.doesNotMatch(displayUnit(entry.unit), /確認|取得|表章名/);
  assert.equal(displayUnit('年（平均余命ex。公式方法説明で確認）'), '年');
  assert.equal(sourceTitle({title:'前川國男邸（96290002）'}), '前川國男邸');
  assert.match(statisticDefinition(archive.statistics.find(s=>s.id==='EST09')), /1世帯1か月.*年平均/);
  assert.match(statisticDefinition(archive.statistics.find(s=>s.id==='EST02')), /名目.*四半期/);
});
test('historical facts and source limitations survive removing editorial work notes', () => {
  const product=additions.events.find(e=>e.id==='E5-032');
  assert.match(eventSummary(product), /NEC.*コンピューター/);
  assert.doesNotMatch(eventSummary(product), /同一視|ここでは/);
  assert.match(product.summary,/同一視/);
  const law=additions.events.find(e=>e.id==='E5-052');
  assert.match(eventSummary(law), /年10日.*5日/);
  const school=archive.events.find(e=>e.id==='L-E001');
  assert.doesNotMatch(recordTitle(school),/確認/);
  assert.match(school.title,/確認/);
  const unread=archive.living.find(e=>e.id==='L2-M002');
  assert.match(livingSummary(unread),/家計簿/);
  assert.match(materialAccess(unread),/本文未確認/);
  assert.match(statisticNotes(archive.statistics.find(s=>s.id==='E2ST02')).join(' '),/1971年度以前.*沖縄/);
  assert.equal(citationPages('トップ掲載動画案内／資料検索 keyword=27005P&typeVideo=on'), '');
  assert.equal(citationPages('論文 pp. 61–75。取得ログや管理番号は掲載しない。'), 'pp. 61–75');
});
test('every unresolved research gap has an authored reader-facing explanation', () => {
  const ids=archive.gaps.filter(g=>g.review_status!=='resolved').map(g=>g.id).sort();
  assert.deepEqual(Object.keys(GAP_COPY).sort(),ids);
  for(const note of Object.values(GAP_COPY)) assert.doesNotMatch(note,/API|CLI|receipt|evidence\/|statsへ|PDFium|第[23]版/);
  assert.match(GAP_COPY['EG_PREWAR'],/戦前.*全国統計.*未収録/);
  assert.match(GAP_COPY['D3-G001'],/6,386,207.*6,483,515/);
});
