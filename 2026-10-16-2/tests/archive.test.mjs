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
const baseline = await read('tests/fixtures/source_snapshot.json');
const points = archive.series.flatMap((series) => series.points);
const sourcePoint = ({ timeCode, timeLabel, kind, evidenceId, ...point }) => point;
const recordKey = (table, dimensions) => canonical([table, Object.fromEntries(Object.entries(dimensions)
  .map(([key, value]) => [key, value.code]))]);

// The capture receipts are frozen source evidence, independent of the app's normalized archive.
const outputs = new Map();
for (const evidence of archive.evidence) outputs.set(evidence.id, await read(evidence.fixturePath));

test('the exported archive keeps all researched tables, cells, events, living materials and sources', () => {
  assert.deepEqual(archive.counts, {
    statistics: 41, observations: 14083, events: 177, living: 85, sources: 213, gaps: 107,
  });
  assert.equal(archive.statistics.length, 41);
  assert.equal(archive.series.length, 498);
  assert.equal(points.length, 14083);
  assert.equal(new Set(points.map(({ id }) => id)).size, 14083);
  assert.equal(archive.events.length, 177);
  assert.equal(archive.living.length, 85);
  assert.equal(archive.sources.length, 213);
  assert.equal(archive.gaps.length, 107);
  assert.equal(archive.evidence.length, 42);
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

test('all 42 original CLI outputs and receipts pass their byte SHA-256 checks', async () => {
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
  assert.equal(total, 14083);
});

test('all 14,083 archive cells directly match original CLI cells by table and every dimension', () => {
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
  assert.equal(used.size, 14083);
});

test('the complete source, material, gap and statistical metadata exports match the frozen ledger', () => {
  for (const name of ['living', 'sources', 'gaps']) {
    assert.equal(hash(canonical(archive[name])), baseline.inputs[name].canonicalSha256, name);
  }
  const statistics = archive.statistics.map(({ seriesIds, actualNumericPeriod,
    exportedCells, exportedNumericCells, worldUse, ...original }) => original);
  assert.equal(hash(canonical(statistics)), baseline.inputs.statistics.canonicalSha256);
  const events = archive.events.map(({ originalSummary, qualification, locator, editorial, ...original }) => ({
    ...original, summary: originalSummary,
  }));
  assert.equal(hash(canonical(events)), baseline.inputs.events.canonicalSha256);
  const editorial = { version: 1, events: Object.fromEntries(archive.events.map((event) => [event.id, event.editorial])) };
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

test('eight world signals refer to separate original series and preserve snapshots, gaps and definition breaks', () => {
  assert.deepEqual(driverDoc.drivers.map(({ id }) => id), [
    'population', 'industry', 'housing', 'water', 'education', 'rice', 'prices', 'bus',
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
      assert.ok(s.points.length >= 4);
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
