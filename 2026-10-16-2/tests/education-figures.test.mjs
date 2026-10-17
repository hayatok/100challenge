import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { budgetFigure, comparisonFigure } from '../app/src/education-figures.js';

const figure = (a, b, extra = {}) => comparisonFigure({ a: { value: a, year: 1900, label: '前の年' }, b: { value: b, year: 2024, label: '後の年' }, unit: '人', title: '人口の比較', ...extra });
const bars = html => [...html.matchAll(/class="figure-bar" x="([^"]+)" y="161" width="([^"]+)"/g)].map(match => ({ x: Number(match[1]), width: Number(match[2]) }));

test('budget keeps the recorded salary, rent and exact part of salary', async () => {
  const archive = JSON.parse(await readFile(new URL('../app/data/archive.json', import.meta.url)));
  const record = archive.living.find(item => item.id === 'L3-M008');
  assert.match(record.what_it_shows, /月給40円/);
  assert.match(record.what_it_shows, /月額家賃3円50銭/);
  const html = budgetFigure();
  assert.match(html, /1904年、広島のある教員世帯/);
  assert.match(html, /3円50銭/);
  assert.match(html, /8\.75%/);
  const salary = Number(html.match(/class="budget-salary-bar"[^>]*width="([^"]+)"/)[1]);
  const rent = Number(html.match(/class="budget-rent-bar"[^>]*width="([^"]+)"/)[1]);
  assert.equal(rent / salary, 3.5 / 40);
  assert.ok(html.includes(record.source_url));
  assert.doesNotMatch(html, /style=|可処分|生活費|平均|現在価値/);
});

test('comparison preserves values, years and units with a shared bar scale', () => {
  const html = figure(1000, 2500);
  assert.match(html, /1900年/);
  assert.match(html, /2024年/);
  assert.match(html, /1,000/);
  assert.match(html, /2,500/);
  assert.match(html, /figure-unit">人/);
  assert.deepEqual(bars(html), [{ x: 30, width: 120 }, { x: 30, width: 300 }]);
  assert.doesNotMatch(html, /style=/);
});

test('a zero is a known zero; absence has no bar and never becomes zero', () => {
  const html = figure(0, null);
  assert.match(html, /data-state="zero" data-value="0"/);
  assert.match(html, /data-state="missing"/);
  assert.match(html, /figure-value">—<\/p>/);
  assert.deepEqual(bars(html), [{ x: 30, width: 0 }]);
  for (const missing of [undefined, NaN, Infinity, '12']) {
    assert.match(figure(missing, null), /figure-value">—<\/p>/);
    assert.equal(bars(figure(missing, null)).length, 0);
  }
});

test('negative values extend left of the same zero and retain their sign', () => {
  const html = figure(-5, 10);
  assert.match(html, /data-state="negative" data-value="-5"/);
  assert.match(html, /figure-value">-5 /);
  assert.deepEqual(bars(html), [{ x: 30, width: 100 }, { x: 130, width: 200 }]);
  assert.deepEqual(bars(figure(-10, -5)), [{ x: 30, width: 300 }, { x: 180, width: 150 }]);
  const extreme = figure(-1e308, 1e308);
  assert.deepEqual(bars(extreme), [{ x: 30, width: 150 }, { x: 180, width: 150 }]);
});

test('percentage grids use exactly 100 cells and retain fractional percentages', () => {
  const html = figure(8.75, 100, { kind: 'phones', unit: '%' });
  assert.match(html, /data-scale="percent-grid"/);
  assert.equal((html.match(/stroke-width="\.6"/g) || []).length, 200);
  assert.match(html, /class="figure-grid-fill"[^>]*width="8\.25"/);
  assert.match(html, /figure-value">8\.75 /);
  assert.match(figure(101, 90, { unit: '%' }), /data-scale="shared-bar"/);
  assert.match(figure(-1, 90, { unit: '%' }), /data-scale="shared-bar"/);
  assert.match(figure(0, null, { unit: '%' }), /data-scale="percent-grid"/);
});

test('small values stay precise and every subject has its own SVG motif', () => {
  const html = figure(0.0000001, 1);
  assert.match(html, /figure-value">0\.0000001 /);
  assert.ok(bars(html)[0].width > 0 && bars(html)[0].width < 0.001);
  const motifs = ['people', 'rice', 'phones', 'computers', 'books', 'homes', 'prices'].map(kind => figure(1, 2, { kind }).match(/<g class="figure-motif"[^>]*>([\s\S]*?)<\/g>/)[1]);
  assert.equal(new Set(motifs).size, 7);
});

test('all caller-provided text is escaped in content and accessible labels', () => {
  const attack = '<img src=x onerror="alert(1)">&\'';
  const html = comparisonFigure({ kind: attack, a: { value: 2, year: attack, label: attack }, b: { value: 3, year: 2024, label: attack }, unit: attack, title: attack });
  assert.doesNotMatch(html, /<img|onerror="alert/);
  assert.match(html, /&lt;img src=x onerror=&quot;alert\(1\)&quot;&gt;&amp;&#39;/);
  assert.match(html, /data-kind="people"/);
});
