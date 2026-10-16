import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const read = async (path) => JSON.parse(await readFile(new URL(path, root), 'utf8'));
const hash = (value) => createHash('sha256').update(value).digest('hex');
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
const archive = await read('app/data/archive.json');
const driverDoc = await read('app/data/drivers.json');
const baseline = await read('tests/fixtures/source_snapshot.v3.json');
const points = archive.series.flatMap((series) => series.points);
const sourcePoint = ({ timeCode, timeLabel, kind, evidenceId, ...point }) => point;
const recordKey = (table, dimensions) => canonical([table, Object.fromEntries(Object.entries(dimensions)
  .map(([key, value]) => [key, value.code]))]);

// The capture receipts are frozen source evidence, independent of the app's normalized archive.
const outputs = new Map();
for (const evidence of archive.evidence) outputs.set(evidence.id, await read(evidence.fixturePath));

test('the exported archive keeps all researched tables, cells, events, living materials and sources', () => {
  assert.deepEqual(archive.counts, {
    statistics: 53, observations: 15728, events: 184, living: 105, sources: 259, gaps: 115,
  });
  assert.equal(archive.statistics.length, 53);
  assert.equal(archive.series.length, 557);
  assert.equal(points.length, 15728);
  assert.equal(new Set(points.map(({ id }) => id)).size, 15728);
  assert.equal(archive.events.length, 184);
  assert.equal(archive.living.length, 105);
  assert.equal(archive.sources.length, 259);
  assert.equal(archive.gaps.length, 115);
  assert.equal(archive.evidence.length, 55);
  assert.equal(archive.cutoff, '2026-10-16');
});

test('every original observation retains every source attribute and its original value spelling', () => {
  assert.equal(Object.keys(baseline.observationHashes).length, points.length);
  for (const point of points) {
    assert.equal(hash(canonical(sourcePoint(point))), baseline.observationHashes[point.id], point.id);
    assert.equal(point.timeCode, point.time_code);
    assert.equal(point.timeLabel, point.time_label);
    assert.equal(point.kind, point.value_kind);
    if (point.kind !== 'number') assert.equal(point.value, null);
  }
});

test('all 55 original CLI outputs and receipts pass their byte SHA-256 checks', async () => {
  let total = 0;
  for (const evidence of archive.evidence) {
    const bytes = await readFile(new URL(evidence.fixturePath, root));
    const receipt = await read(evidence.receiptPath);
    assert.deepEqual(receipt, evidence.receipt);
    assert.equal(hash(bytes), receipt.sha256, evidence.originalPath);
    assert.equal(hash(bytes), evidence.sha256);
    assert.equal(receipt.exit_code, 0);
    assert.equal(receipt.json_valid, true);
    assert.equal(receipt.command[0], '/Users/hayatok/.local/bin/estat');
    assert.equal(receipt.command[1], 'data');
    assert.equal(receipt.command[2], 'get');
    const output = outputs.get(evidence.id);
    assert.equal(output.records.length, evidence.recordCount);
    assert.equal(output.table.id, receipt.command[3]);
    total += output.records.length;
  }
  assert.equal(total, 15728);
});

test('all 15,728 archive cells directly match original CLI cells by table and every dimension', () => {
  const lookup = new Map();
  for (const [id, output] of outputs) {
    const entries = new Map();
    for (const record of output.records) {
      const key = recordKey(record.table_id, record.dimensions);
      assert.equal(entries.has(key), false, `duplicate CLI key ${id} ${key}`);
      entries.set(key, record);
    }
    lookup.set(id, entries);
  }
  const used = new Map();
  for (const point of points) {
    const key = recordKey(point.table_id, point.dimensions);
    const original = lookup.get(point.evidenceId)?.get(key);
    assert.ok(original, `no CLI cell for ${point.id}`);
    assert.equal(point.raw, original.value.raw, point.id);
    assert.equal(point.value, original.value.number, point.id);
    assert.equal(point.kind, original.value.kind, point.id);
    assert.equal(point.evidence_path, archive.evidence.find((e) => e.id === point.evidenceId).originalPath);
    used.set(`${point.evidenceId}:${key}`, point.id);
  }
  assert.equal(used.size, 15728);
});

test('the complete source, material, gap and statistical metadata exports match the frozen ledger', () => {
  for (const name of ['living', 'sources', 'gaps']) {
    assert.equal(hash(canonical(archive[name])), baseline.inputs[name].canonicalSha256, name);
  }
  const statistics = archive.statistics.map(({ seriesIds, actualNumericPeriod,
    exportedCells, exportedNumericCells, worldUse, ...original }) => original);
  assert.equal(hash(canonical(statistics)), baseline.inputs.statistics.canonicalSha256);
  const events = archive.events.map(({ originalSummary, qualification, locator, editorial, editorialSource, ...original }) => ({
    ...original, summary: originalSummary,
  }));
  assert.equal(hash(canonical(events)), baseline.inputs.events.canonicalSha256);
  const editorial = { version: 1, events: Object.fromEntries(archive.events.filter((event) => event.editorialSource === 'v2_reader_edit').map((event) => [event.id, event.editorial])) };
  assert.equal(hash(canonical(editorial)), baseline.inputs.editorial.canonicalSha256);
  for (const event of archive.events) {
    assert.equal(event.summary, event.editorial.summary);
    assert.equal(event.locator, event.editorial.locator);
    assert.equal(event.qualification, event.editorial.qualification);
  }
});

test('every source reference and every point is reachable through a table and series', () => {
  const sources = new Set(archive.sources.map(({ id }) => id));
  const statistics = new Map(archive.statistics.map((stat) => [stat.id, stat]));
  const evidenceIds = new Set(archive.evidence.map(({ id }) => id));
  for (const series of archive.series) {
    const stat = statistics.get(series.statId);
    assert.ok(stat?.seriesIds.includes(series.id));
    assert.ok(sources.has(series.sourceId));
    assert.equal(series.tableId, stat.table_id);
    for (const point of series.points) {
      assert.ok(sources.has(point.source_id));
      assert.ok(evidenceIds.has(point.evidenceId));
      assert.equal(point.statistic_id, series.statId);
      assert.equal(point.table_id, series.tableId);
      for (const [axis, code] of Object.entries(series.dimensions)) assert.equal(point.dimensions[axis].code, code);
    }
  }
  for (const event of archive.events) for (const id of event.source_ids) assert.ok(sources.has(id));
  for (const material of archive.living) assert.ok(sources.has(material.source_id));
});

test('eleven world signals refer to separate original series and preserve snapshots, gaps and definition breaks', () => {
  assert.deepEqual(driverDoc.drivers.map(({ id }) => id), [
    'population', 'industry', 'housing', 'water', 'education', 'rice', 'prices', 'bus', 'rail', 'communication', 'energy',
  ]);
  const series = new Map(archive.series.map((item) => [item.id, item]));
  for (const driver of driverDoc.drivers) {
    assert.equal(driver.status, 'allowed_with_notes');
    assert.ok(driver.worldTarget && driver.notes.length >= 2);
    assert.ok(driver.limitation && !/CLI|receipt|statId|cat01|SSD|採用|駆動/.test(driver.limitation));
    assert.equal(driver.selectionPolicy.showObservationYear, true);
    assert.equal(driver.selectionPolicy.treatSnapshotAsCurrent, false);
    assert.equal(driver.selectionPolicy.interpolate, false);
    assert.equal(driver.selectionPolicy.missingRawStopsSnapshot, true);
    for (const id of driver.seriesIds) {
      const s = series.get(id);
      assert.ok(s, id);
      assert.ok(s.points.length >= 1);
      assert.ok(s.unit && s.notes.length >= 2);
    }
  }
  const prices = driverDoc.drivers.find(({ id }) => id === 'prices');
  assert.ok(prices.seriesIds.every((id) => series.get(id).statId === 'E2ST01'));
  assert.ok(archive.series.some(({ statId }) => statId === 'EST01'));
  assert.ok(archive.series.some(({ statId }) => statId === 'EST15'));
  const industry = driverDoc.drivers.find(({ id }) => id === 'industry');
  assert.ok(industry.boundaries.some(({ year }) => year === 2003));
  const rice = driverDoc.drivers.find(({ id }) => id === 'rice');
  assert.ok(rice.boundaries.some(({ year }) => year === 1972));
  assert.ok(rice.boundaries.some(({ year }) => year === 2018));
  const held = archive.statistics.find(({ id }) => id === 'SD-STAT015');
  assert.equal(held.worldUse.status, 'archive_only');
  const invalidYear = points.filter(({ year }) => year === null);
  assert.ok(invalidYear.length > 0);
  assert.ok(invalidYear.every(({ statistic_id }) => statistic_id === 'SD-STAT009'));
});

test('housing stays in dwellings, industry classifications stay separate, and buses keep their observation months', () => {
  const findSeries = (statId, indicator) => archive.series.find((s) =>
    s.statId === statId && s.dimensions.cat01 === indicator && s.dimensions.area === '00000');
  for (const code of ['H1100', 'H110202']) {
    const housing = findSeries('EST13', code);
    assert.equal(housing.unit, '戸');
    assert.deepEqual(housing.points.map(({ year }) => year), [1978, 1983, 1988, 1993, 1998, 2003, 2008, 2013, 2018, 2023]);
    assert.ok(housing.points.every(({ timeLabel }) => timeLabel.endsWith('年度')));
  }
  const oldManufacturing = findSeries('SD2-STAT002', 'A009');
  const newManufacturing = findSeries('SD-STAT005', '010');
  assert.equal(oldManufacturing.numericEnd, 2002);
  assert.equal(newManufacturing.numericStart, 2003);
  assert.notEqual(oldManufacturing.id, newManufacturing.id);
  assert.match(oldManufacturing.labels.cat01, /\*/);
  const bus = archive.series.find(({ statId }) => statId === 'EST05');
  assert.equal(bus.unit, '千');
  assert.equal(bus.points.length, 114);
  assert.equal(bus.points[0].timeLabel, '2010年10月');
  assert.equal(bus.points.at(-1).timeLabel, '2020年3月');
  assert.ok(bus.points.every(({ timeLabel }) => /^\d{4}年\d{1,2}月$/.test(timeLabel)));
  assert.ok(bus.points.filter(({ year }) => year === 2019).length === 12);
  assert.equal(findSeries('SD-STAT016', 'A1101').numericEnd, 2024);
  assert.ok(!findSeries('SD-STAT016', 'A1101').points.some(({ year }) => year === 2026));
});

test('the evidence bundle contains no source images, workbooks, PDFs or credentials', async () => {
  async function files(url) {
    const result = [];
    for (const entry of await readdir(url, { withFileTypes: true })) {
      if (entry.isDirectory()) result.push(...await files(new URL(`${entry.name}/`, url)));
      else result.push(entry.name);
    }
    return result;
  }
  const names = await files(new URL('tests/fixtures/', root));
  assert.ok(names.every((name) => name.endsWith('.json')));
  for (const evidence of archive.evidence) {
    assert.ok(!evidence.receipt.command.some((argument) => /(?:api[_-]?key|appId)=/i.test(argument)));
  }
});

test('all original 14,083 v2 observations and every previously captured fixture remain unchanged', async () => {
  const v2 = await read('tests/fixtures/source_snapshot.v2.json');
  assert.equal(v2.counts.observations, 14083);
  const current = new Map(points.map((point) => [point.id, point]));
  for (const [id, expectedHash] of Object.entries(v2.observationHashes)) {
    assert.ok(current.has(id), `v2 observation removed: ${id}`);
    assert.equal(hash(canonical(sourcePoint(current.get(id)))), expectedHash, id);
  }
  assert.equal(points.filter(({ kind }) => kind === 'number').length, 15594);
  assert.equal(points.filter(({ kind }) => kind !== 'number').length, 134);
});

test('series keys separate actual time axes and month, fiscal year and half-year frequencies', () => {
  const mixed = archive.series.filter(({ statId }) => statId === 'E3-ST006');
  assert.equal(mixed.length, 6);
  assert.deepEqual(mixed.map(({ frequency }) => frequency).sort(), [
    '上半期（年度4〜9月）', '上半期（年度4〜9月）', '年度', '年度', '月次', '月次',
  ].sort());
  const byFrequency = Object.fromEntries(['月次', '年度', '上半期（年度4〜9月）']
    .map((frequency) => [frequency, mixed.filter((s) => s.frequency === frequency)
      .reduce((sum, s) => sum + s.points.length, 0)]));
  assert.deepEqual(byFrequency, { 月次: 72, 年度: 6, '上半期（年度4〜9月）': 6 });
  const energy = archive.series.filter(({ statId }) => statId === 'E3-ST007');
  assert.equal(energy.length, 5);
  for (const s of energy) {
    assert.equal(s.timeDimension, 'cat02');
    assert.equal(s.frequency, '年度');
    assert.equal(s.dimensions.cat02, undefined);
    assert.equal(s.labels.cat02, undefined);
    assert.equal(s.dimensions.time, '000107');
    assert.match(s.id, /axis=cat02:frequency=年度$/);
    assert.deepEqual(s.points.map(({ year }) => year), [2017, 2018, 2019, 2020, 2021, 2022, 2023]);
    for (const p of s.points) {
      assert.equal(p.timeCode, p.dimensions.cat02.code);
      assert.equal(p.timeLabel, p.dimensions.cat02.name);
      assert.equal(Number(p.timeLabel.split('_').at(-1)), p.year);
    }
  }
});

test('all timeline segments are ordered, nonoverlapping and reference their channel union', () => {
  const month = (label) => {
    assert.match(label, /^\d{4}-\d{2}$/);
    const [year, month] = label.split('-').map(Number);
    assert.ok(month >= 1 && month <= 12);
    return year * 12 + month - 1;
  };
  for (const driver of driverDoc.drivers) {
    let previousEnd = -Infinity;
    for (const segment of driver.segments) {
      assert.ok(month(segment.from) > previousEnd, `${driver.id}: overlapping segments`);
      assert.ok(month(segment.from) <= month(segment.through));
      previousEnd = month(segment.through);
      assert.ok(segment.label && segment.limitation);
      for (const id of segment.seriesIds) assert.ok(driver.seriesIds.includes(id));
    }
  }
  const find = (driverId, at) => driverDoc.drivers.find(({ id }) => id === driverId).segments
    .find((s) => s.from <= at && s.through >= at);
  assert.match(find('population', '1900-01').label, /内地人/);
  assert.match(find('population', '1967-01').label, /日本人人口/);
  assert.match(find('population', '1973-01').label, /沖縄/);
  assert.match(find('population', '1975-01').seriesIds[0], /^SD-STAT016:/);
  assert.match(find('industry', '2007-01').seriesIds[0], /^D3-ST003:/);
  assert.match(find('industry', '2011-01').seriesIds[0], /^D3-ST004:/);
  assert.match(find('education', '2016-12').seriesIds[0], /^SD-STAT003:/);
  assert.match(find('education', '2017-01').seriesIds[0], /^D3-ST002:/);
  assert.match(find('education', '2017-01').limitation, /学部のみ/);
  assert.match(find('bus', '2020-03').seriesIds[0], /^EST05:/);
  assert.match(find('bus', '2020-04').seriesIds[0], /^E3-ST001:/);
});

test('new signal definitions preserve population scope, the 2011 missing marker and observed endpoints', () => {
  const map = new Map(archive.series.map((s) => [s.id, s]));
  const signal = (id) => driverDoc.drivers.find((d) => d.id === id);
  const basis = map.get(signal('population').segments[0].seriesIds[0]);
  assert.equal(basis.unit, '人');
  assert.equal(basis.points.find(({ year }) => year === 1900).raw, '43847000');
  const modernIndustry = signal('industry').segments.at(-1);
  for (const id of modernIndustry.seriesIds) {
    const entry = map.get(id);
    const missing = entry.points.find(({ year }) => year === 2011);
    assert.equal(missing.kind, 'special');
    assert.equal(missing.raw, '…');
    assert.equal(missing.value, null);
    assert.match(missing.value_note, /震災|調査.*困難/);
    assert.equal(entry.numericStart, 2012);
    assert.equal(entry.numericEnd, 2025);
  }
  const rail = map.get(signal('rail').seriesIds[0]);
  assert.equal(rail.unit, '千人');
  assert.equal(rail.points[0].timeLabel, '2020年4月');
  assert.equal(rail.points.at(-1).timeLabel, '2026年6月');
  const energy = map.get(signal('energy').seriesIds[0]);
  assert.equal(energy.unit, 'GJ/世帯・年');
  assert.equal(energy.numericEnd, 2023);
  assert.match(signal('energy').notes.join(' '), /自動車|ガソリン/);
  assert.match(signal('communication').notes.join(' '), /2017.*2025.*未採用/);
  assert.equal(signal('communication').segments.at(-1).seriesIds.length, 2);
});

test('all seven new dated life materials and the seven new events retain their original qualifications', () => {
  const expected = ['L3-M004', 'L3-M005', 'L3-M006', 'L3-M007', 'L3-M008', 'L3-M012', 'L3-M017'];
  for (const id of expected) {
    const material = archive.living.find((m) => m.id === id);
    assert.ok(material.period_start && material.period_end && material.geography);
    assert.equal(material.verification, 'item_content_verified');
    assert.ok(material.representativeness_limit && material.notes);
  }
  const events = archive.events.filter(({ editorialSource }) => editorialSource === 'v3_research_summary');
  assert.equal(events.length, 7);
  assert.ok(events.every((event) => event.qualification === event.disputed_or_qualified));
});
