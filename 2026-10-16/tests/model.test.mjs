import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { MIN_YEAR, MAX_YEAR, defaultState, validYear, eraLabel, ageLabel, parseState, getYearRecords, getUndatedLiving, statisticView, formatValue, validateDataset, safeSourceURL } from '../app/src/model.mjs';

const data = JSON.parse(readFileSync(new URL('../app/data/history.json', import.meta.url), 'utf8'));
const copy = () => structuredClone(data);
const counts = Object.fromEntries(Object.entries(data.metrics).map(([key, m]) => [key, m.series.reduce((n, s) => n + s.points.length, 0)]));
const ESTAT_FIXTURES = {
  vital: { file: 'vital_series', table: '0003411561', codes: ['00110', '00150'], dimensions: {}, sha256: '2aef19512e260f470ff3cb8565b3fb85d8770200b6a256e48df8b3ee935e4a25' },
  cpi: { file: 'cpi_new_calendar', table: '0004052037', codes: ['0001', '0002'], dimensions: { area: '00000', tab: '1' }, sha256: '05ac1b556bf564c0e8750ec133b75074f980dcacf6dd2104ee3d82ece6fe9691' },
  household: { file: 'family_spending_data', table: '0002070003', codes: ['059'], dimensions: { area: '00000', tab: '01', cat02: '03' }, sha256: '294428ef1bc5d857c5b4ac25533986fd9652627254083d626272fad428adf301' },
};
function estatFixture(spec) {
  // Fixtures are mandatory, including in a standalone clone. Never skip this read.
  const bytes = readFileSync(new URL(`./fixtures/estat/${spec.file}.json`, import.meta.url));
  const receipt = JSON.parse(readFileSync(new URL(`./fixtures/estat/${spec.file}.receipt.json`, import.meta.url), 'utf8'));
  return { bytes, receipt, output: JSON.parse(bytes.toString('utf8')) };
}

test('bundled e-Stat outputs retain their original receipt hashes and successful acquisition records', () => {
  for (const spec of Object.values(ESTAT_FIXTURES)) {
    const { bytes, receipt, output } = estatFixture(spec);
    assert.equal(receipt.exit_code, 0);
    assert.equal(receipt.json_valid, true);
    assert.equal(receipt.sha256, spec.sha256);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), receipt.sha256);
    assert.ok(receipt.command.includes(spec.table));
    assert.equal(output.table.id, spec.table);
    assert.ok(Array.isArray(output.records) && output.records.length > 0);
  }
});

test('all 382 shipped cells match the bundled e-Stat outputs directly, including selected dimensions', () => {
  let checked = 0;
  assert.deepEqual(Object.keys(data.metrics).sort(), Object.keys(ESTAT_FIXTURES).sort());
  for (const [key, spec] of Object.entries(ESTAT_FIXTURES)) {
    const { output } = estatFixture(spec), metric = data.metrics[key];
    assert.equal(metric.table_id, spec.table);
    assert.deepEqual(metric.series.map(s => s.code), spec.codes);
    // The app compresses dimensions into a metric's filters and a series code.
    // Check that mapping as well as the value, rather than trusting category names.
    for (const [dimension, code] of Object.entries(spec.dimensions)) assert.deepEqual(metric.filters[dimension], [code]);
    const cells = output.records.filter(r => {
      assert.equal(r.table_id, spec.table);
      assert.match(r.dimensions.time.code, /^\d{4}000000$/);
      const year = Number(r.dimensions.time.code.slice(0, 4));
      return year >= MIN_YEAR && spec.codes.includes(r.dimensions.cat01.code) && r.value.kind === 'number' && Object.entries(spec.dimensions).every(([dimension, code]) => r.dimensions[dimension]?.code === code);
    });
    assert.equal(cells.length, counts[key]);
    const seen = new Set();
    for (const series of metric.series) for (const point of series.points) {
      const time = `${point.year}000000`;
      const matches = cells.filter(r => r.dimensions.cat01.code === series.code && r.dimensions.time.code === time);
      assert.equal(matches.length, 1, `${key}/${series.code}/${point.year} must identify one original cell`);
      const r = matches[0];
      assert.deepEqual(Object.keys(r.dimensions).sort(), ['cat01', 'time', ...Object.keys(spec.dimensions)].sort());
      assert.equal(r.value.kind, 'number');
      assert.equal(point.year, Number(r.dimensions.time.code.slice(0, 4)));
      assert.equal(point.raw, r.value.raw);
      assert.equal(point.value, r.value.number);
      if (key === 'cpi') {
        // e-Stat omits a unit field for this index. Its table title identifies
        // the base year; the app explicitly supplies that label, not yen or %.
        assert.match(output.table.title, /2025年基準/);
        assert.equal(r.unit, undefined);
        assert.equal(point.unit, '指数（2025年=100）');
      } else assert.equal(point.unit, r.unit);
      const cellKey = JSON.stringify([r.table_id, Object.entries(r.dimensions).map(([id, category]) => [id, category.code]).sort()]);
      assert.ok(!seen.has(cellKey), 'An original cell must not be displayed twice');
      seen.add(cellKey); checked++;
    }
    assert.equal(seen.size, cells.length, 'No intended original cell may be omitted');
  }
  assert.equal(checked, 382);
});

test('the shipped experience contains all 382 intended observations and no substituted years', () => {
  assert.equal(validateDataset(data), true);
  assert.deepEqual(counts, { vital: 244, cpi: 112, household: 26 });
  for (const metric of ['vital', 'cpi', 'household']) {
    const v = statisticView(data, metric, 2026);
    assert.ok(v.series.every(s => s.point === null));
    assert.match(v.status, /202[45]年/);
  }
  assert.ok(statisticView(data, 'vital', 1945).series.every(s => s.point === null));
  assert.match(statisticView(data, 'vital', 1945).status, /戦災.*省略/);
  assert.equal(statisticView(data, 'household', 1999).series[0].point, null);
  assert.match(statisticView(data, 'household', 1999).status, /2000年.*0円/);
  assert.match(statisticView(data, 'cpi', 1935).status, /1970年/);
});

test('every displayed value agrees exactly with its original observation when the local research ledger is available', t => {
  const path = new URL('../data/observations.json', import.meta.url);
  if (!existsSync(path)) return t.skip('Research ledger is optional in the standalone app clone; shipped coverage is tested separately.');
  const obs = JSON.parse(readFileSync(path, 'utf8'));
  let checked = 0;
  for (const [key, m] of Object.entries(data.metrics)) for (const s of m.series) {
    const candidates = obs.filter(r => r.table_id === m.table_id && r.dimensions.cat01.code === s.code && Number.isInteger(r.year) && r.year >= MIN_YEAR && r.value !== null && (key !== 'cpi' || (r.dimensions.area.code === '00000' && r.dimensions.tab.code === '1' && r.dimensions.time.code === `${r.year}000000`)) && (key !== 'household' || (r.dimensions.area.code === '00000' && r.dimensions.cat02.code === '03' && r.dimensions.tab.code === '01')));
    assert.equal(candidates.length, s.points.length);
    for (const p of s.points) {
      const rows = candidates.filter(r => r.year === p.year);
      assert.equal(rows.length, 1);
      assert.deepEqual(p, { year: rows[0].year, value: rows[0].value, raw: rows[0].raw, unit: rows[0].unit });
      checked++;
    }
  }
  assert.equal(checked, 382);
});

test('data corruption cannot silently invent observations, drop a year, or change a unit', () => {
  for (const corrupt of [
    d => d.metrics.vital.series[0].points.push({ year: 1945, value: 0, raw: '0', unit: '人' }),
    d => d.metrics.household.series[0].points.pop(),
    d => d.metrics.cpi.series[0].points.push(d.metrics.cpi.series[0].points[0]),
    d => { d.metrics.cpi.series[0].points[0].value = NaN; },
    d => { d.metrics.vital.series[0].points[0].unit = '件'; },
    d => { d.metrics.household.series[0].points[0].raw = '1'; },
    d => { d.metrics.household.divisor = 12; },
    d => { d.events[0].source_ids = ['missing-source']; },
    d => { d.living[0].start = '1935-02-31'; },
    d => { d.living[0].start = '1935-12-31'; d.living[0].end = '1935-01-01'; },
    d => { d.events[0].date_start = '2026-10-17'; },
  ]) {
    const d = copy(); corrupt(d); assert.throws(() => validateDataset(d), TypeError);
  }
});

test('uncertain end dates remain separate, while a bounded record appears in both endpoint years', () => {
  const d = copy();
  d.living = [ { ...d.living[0], ids: ['bounded'], start: '1935-03-13', end: '1936-03-12' }, { ...d.living[0], ids: ['open-end'], start: '1945', end: null }, { ...d.living[0], ids: ['open-start'], start: null, end: '1945' } ];
  assert.equal(getYearRecords(d, 1935).living.length, 1);
  assert.equal(getYearRecords(d, 1936).living.length, 1);
  assert.equal(getYearRecords(d, 1945).living.length, 0);
  assert.deepEqual(getUndatedLiving(d).map(x => x.ids[0]), ['open-end', 'open-start']);
  assert.ok(getYearRecords(data, 1945).events.every(e => e.date_start.startsWith('1945')));
});

test('URL state overrides only specified fields, invalid input resets to defaults, and foreign saves are ignored', () => {
  const saved = { version: 'history-local-v1', year: 2000, birthYear: 1950, metric: 'cpi' };
  assert.deepEqual(parseState('?y=1945', saved), { year: 1945, birthYear: 1950, metric: 'cpi' });
  assert.deepEqual(parseState('?y=0&b=2e3&m=toString', saved), defaultState);
  assert.deepEqual(parseState('?y=&b=2027&m=', saved), defaultState);
  assert.deepEqual(parseState('', { ...saved, version: 'japan-history-lens-v1' }), defaultState);
  assert.deepEqual(parseState('', { version: 'history-local-v1', year: '2000', birthYear: Infinity, metric: '__proto__' }), defaultState);
  assert.deepEqual(parseState(null, []), defaultState);
  assert.deepEqual(parseState('?y=1900&b=2026&m=household', null), { year: MIN_YEAR, birthYear: MAX_YEAR, metric: 'household' });
  assert.equal(validYear('1935'), false);
  assert.equal(validYear(1935.5), false);
  assert.equal(validYear(Infinity), false);
});

test('year-only age and era labels acknowledge birthdays and era transitions', () => {
  assert.equal(ageLabel(1935, 1900), '1900年生まれなら、35歳になる年');
  assert.equal(ageLabel(1900, 1945), '生まれる45年前');
  assert.equal(ageLabel(1900, 1900), '1900年生まれなら、0歳になる年');
  for (const [y, text] of [[1900, '明治33年'], [1912, '明治45年／大正元年'], [1926, '大正15年／昭和元年'], [1989, '昭和64年／平成元年'], [2019, '平成31年／令和元年'], [2026, '令和8年']]) assert.equal(eraLabel(y), text);
  assert.throws(() => ageLabel(2027, 1900), RangeError);
  assert.throws(() => eraLabel(1899), RangeError);
});

test('scope explanations preserve Okinawa boundaries and do not expose internal terminology', () => {
  assert.match(statisticView(data, 'vital', 1972).scopeNote, /沖縄県を含まない.*1973年/);
  assert.match(statisticView(data, 'vital', 1973).scopeNote, /1973年から沖縄県を含む/);
  assert.match(statisticView(data, 'vital', 1935).scopeNote, /国籍.*確認しきれて/);
  for (const m of ['vital', 'cpi', 'household']) for (const y of [1900, 1945, 1972, 1973, 1999, 2025, 2026]) {
    const v = statisticView(data, m, y);
    assert.doesNotMatch([v.status, v.scopeNote, ...v.sourceNotes].join(''), /採用|系列|区分03|未取得|初期版|正本|実装|台帳|API/);
  }
});

test('display conversion keeps exact raw values and accepts only safe source links', () => {
  const p = data.metrics.vital.series[0].points[0], before = structuredClone(p);
  assert.equal(formatValue({ value: 1234567 }, { divisor: 10000 }), '123.46');
  assert.equal(formatValue({ value: 317328 }, { divisor: 10000 }), '31.73');
  assert.equal(formatValue(null, data.metrics.vital), '—');
  formatValue(p, data.metrics.vital); assert.deepEqual(p, before);
  assert.throws(() => formatValue({ value: Infinity }, { divisor: 1 }), TypeError);
  for (const url of ['http://example.com', 'javascript:alert(1)', 'data:text/html,a', '//example.com', 'https://user:password@example.com', {}, null]) assert.equal(safeSourceURL(url), null);
  assert.equal(safeSourceURL('https://example.com/source?a=1'), 'https://example.com/source?a=1');
});
