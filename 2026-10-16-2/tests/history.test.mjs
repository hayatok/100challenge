import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const readJSON = async (path) => JSON.parse(await readFile(new URL(path, root), 'utf8'));
const history = await readJSON('app/data/history.json');

test('three dated chapters retain the scope and sources of their historical background', () => {
  assert.equal(history.version, 1);
  assert.deepEqual(history.phases.map(({ year }) => year), [1955, 1973, 2000]);
  for (const phase of history.phases) {
    assert.ok(phase.title && phase.summary && phase.gameNote);
    assert.match(phase.gameNote, /作者.*設定/);
    assert.ok(phase.events.length >= 1 && phase.events.length <= 2);
    assert.ok(phase.statistics.length >= 1 && phase.statistics.length <= 2);
    for (const event of phase.events) {
      assert.equal(Number(event.date.slice(0, 4)), phase.year);
      assert.match(event.date, /^\d{4}(?:-\d{2})?(?:-\d{2})?$/);
      assert.ok(event.title && event.description && event.institution && event.locator);
      assert.ok(event.qualification && event.checkedAt && event.sourceType);
      assert.equal(new URL(event.url).protocol, 'https:');
    }
  }
  assert.match(history.phases[0].events[0].url, /^https:\/\/www\.ur-net\.go\.jp\//);
  assert.equal(history.phases[0].events[0].datePrecision, 'year');
  assert.equal(history.phases[2].events[0].datePrecision, 'month');
  assert.equal(history.phases[2].events[0].date, '2000-04');
});

test('every unchanged estat CLI output matches its capture receipt SHA-256', async () => {
  const names = await readdir(new URL('tests/fixtures/estat/', root));
  const receipts = names.filter((name) => name.endsWith('.receipt.json'));
  assert.equal(receipts.length, 3);
  for (const name of receipts) {
    const receipt = await readJSON(`tests/fixtures/estat/${name}`);
    const outputName = name.replace('.receipt.json', '.json');
    assert.equal(receipt.exit_code, 0);
    assert.equal(receipt.json_valid, true);
    assert.equal(receipt.command[0], '/Users/hayatok/.local/bin/estat');
    assert.equal(receipt.command.at(-1) === 'raw' || receipt.command.includes('json'), true);
    assert.equal(receipt.output_path.split('/').at(-1), outputName);
    const bytes = await readFile(new URL(`tests/fixtures/estat/${outputName}`, root));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), receipt.sha256);
  }
});

test('all displayed numbers directly match one numeric CLI record with every dimension fixed', async () => {
  let count = 0;
  for (const phase of history.phases) {
    for (const stat of phase.statistics) {
      const source = await readJSON(stat.sourceFile);
      const receipt = await readJSON(stat.receiptFile);
      assert.equal(source.kind, 'data');
      assert.equal(source.table.id, stat.tableId);
      assert.equal(stat.url, `https://www.e-stat.go.jp/dbview?sid=${stat.tableId}`);
      assert.equal(stat.institution, source.table.organization);
      assert.equal(stat.checkedAt, receipt.finished_at);
      assert.equal(stat.year, phase.year);
      assert.equal(stat.dimensions.time.code, `${phase.year}000000`);
      assert.equal(stat.dimensions.time.name, `${phase.year}年`);
      const keys = Object.keys(stat.dimensions).sort();
      assert.deepEqual(keys, source.dimensions.map(({ id }) => id).sort());
      const matches = source.records.filter((record) =>
        record.table_id === stat.tableId && keys.every((key) =>
          record.dimensions[key].code === stat.dimensions[key].code));
      assert.equal(matches.length, 1);
      assert.deepEqual(stat.dimensions, matches[0].dimensions);
      assert.equal(matches[0].value.kind, 'number');
      assert.equal(stat.raw, matches[0].value.raw);
      assert.equal(stat.value, matches[0].value.number);
      assert.ok(Number.isFinite(stat.value));
      assert.ok(stat.unit && stat.scope && stat.notes.length >= 3);
      assert.ok(!['-', '', '…', '*'].includes(stat.raw));
      count += 1;
    }
  }
  assert.equal(count, 5);
});

test('1955 manufacturing keeps the historical classification and unresolved scope visible', async () => {
  const stat = history.phases[0].statistics[0];
  assert.equal(stat.tableId, '0002060053');
  assert.equal(stat.raw, '757');
  assert.equal(stat.unit, '万人');
  assert.equal(stat.dimensions.cat01.code, 'A009');
  assert.equal(stat.dimensions.cat02.code, '0');
  assert.equal(stat.dimensions.cat03.code, '00');
  assert.equal(stat.dimensions.area.code, '00000');
  assert.equal(stat.dimensions.tab.code, '01');
  const metadata = await readJSON(stat.definitionFile);
  const definition = metadata.GET_META_INFO.METADATA_INF;
  assert.equal(definition.TABLE_INF['@id'], stat.tableId);
  assert.equal(definition.TABLE_INF.CYCLE, '年次');
  const axes = definition.CLASS_INF.CLASS_OBJ;
  assert.equal(axes.find((axis) => axis['@id'] === 'tab').CLASS['@unit'], stat.unit);
  assert.match(axes.find((axis) => axis['@id'] === 'cat01')['@description'], /現行分類と内容が異なる/);
  assert.match(stat.notes.join(' '), /現行.*一致しない/);
  assert.match(stat.notes.join(' '), /対象領域.*確定していない/);
  assert.match(stat.notes.join(' '), /1点/);
});

test('CPI shows only acquired calendar-year indices and cannot stand in for construction costs', () => {
  for (const phase of history.phases.slice(1)) {
    assert.deepEqual(phase.statistics.map((stat) => stat.dimensions.cat01.code), ['0001', '0002']);
    for (const stat of phase.statistics) {
      assert.equal(stat.tableId, '0004052037');
      assert.equal(stat.dimensions.tab.code, '1');
      assert.equal(stat.dimensions.area.code, '00000');
      assert.equal(stat.unit, '指数（2025年=100）');
      assert.match(stat.scope, /全国・暦年平均/);
      assert.match(stat.notes.join(' '), /公式接続指数/);
      assert.match(stat.notes.join(' '), /工事費.*根拠には使わない/);
      assert.notEqual(stat.tableId, '0003410379');
    }
  }
  assert.deepEqual(history.phases[1].statistics.map(({ raw }) => raw), ['34.5', '28.4']);
  assert.deepEqual(history.phases[2].statistics.map(({ raw }) => raw), ['86.9', '69.4']);
  assert.match(history.phases[1].gameNote, /4から5.*作者の設定/);
});
