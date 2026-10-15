import { describe, expect, it } from 'vitest';
import { detectGrid } from '../src/domain/grid';
import { addColumn, addRow, createBlankTable, deleteColumn, deleteRow, editCell, reconstructTable, toCSV, toHTML, toTSV } from '../src/domain/table';
import type { OcrToken, TableData } from '../src/types';

const token = (text: string, x: number, y: number, width = 25, height = 12, confidence = .93): OcrToken => ({ text, box: { x, y, width, height }, confidence });
const values = (table: TableData) => table.cells.map(row => row.map(cell => cell.value));
function tableFrom(values: string[][]) {
  let table = createBlankTable(values.length, values[0].length);
  values.forEach((row, r) => row.forEach((value, c) => { table = editCell(table, r, c, value); }));
  return table;
}
function image(width: number, height: number) {
  const pixels = new Uint8ClampedArray(width * height * 4).fill(255);
  const dot = (x: number, y: number) => { const i = (y * width + x) * 4; pixels[i] = pixels[i + 1] = pixels[i + 2] = 30; };
  return { pixels, dot };
}

describe('rule projection and table reconstruction', () => {
  it('finds thick rules and retains entirely empty rows and columns', () => {
    const { pixels, dot } = image(302, 182);
    for (const y of [1, 61, 121, 181]) for (let x = 1; x < 302; x++) dot(x, y);
    for (const x of [1, 101, 201, 301]) for (let y = 1; y < 182; y++) dot(x, y);
    // A short character-like vertical stroke and horizontal strokes are not rules.
    for (let y = 15; y < 30; y++) dot(24, y);
    for (let x = 20; x < 35; x++) dot(x, 18);
    const hints = detectGrid(pixels, 302, 182);
    expect(hints).toEqual({ rowEdges: [1, 61, 121, 181], columnEdges: [1, 101, 201, 301] });
    const table = reconstructTable([token('商品', 12, 12), token('金額', 215, 12), token('りんご', 12, 135), token('0012', 215, 135)], 302, 182, hints);
    expect(values(table)).toEqual([['商品', '', '金額'], ['', '', ''], ['りんご', '', '0012']]);
    expect(table.cells[1][1]).toEqual({ value: '', confidence: 1, reviewed: true });
    expect(table.cells[2][0].reviewed).toBe(false);
    expect(table.method).toBe('ruled');
  });

  it('collapses adjacent pixels of a thick rule and accepts short interruptions', () => {
    const { pixels, dot } = image(240, 120);
    for (const y of [0, 40, 80, 117]) for (let dy = 0; dy < 3; dy++) for (let x = 0; x < 240; x++) if (x !== 120) dot(x, y + dy);
    for (const x of [0, 80, 160, 237]) for (let dx = 0; dx < 3; dx++) for (let y = 0; y < 120; y++) dot(x + dx, y);
    expect(detectGrid(pixels, 240, 120)).toEqual({ rowEdges: [1, 41, 81, 118], columnEdges: [1, 81, 161, 238] });
  });

  it('does not treat a repeated row of separate character strokes as a border', () => {
    const { pixels, dot } = image(240, 120);
    for (let y = 12; y < 102; y += 30) for (let x = 8; x < 230; x += 14) {
      for (let a = 0; a < 10; a++) { dot(x + a, y); dot(x + a, y + 10); }
      for (let a = 0; a <= 10; a++) { dot(x, y + a); dot(x + 9, y + a); }
    }
    expect(detectGrid(pixels, 240, 120)).toEqual({ rowEdges: [], columnEdges: [] });
  });

  it('ignores RGB colour of fully transparent pixels', () => {
    const pixels = new Uint8ClampedArray(80 * 80 * 4);
    expect(detectGrid(pixels, 80, 80)).toEqual({ rowEdges: [], columnEdges: [] });
  });

  it('uses recurring borderless columns and keeps a middle blank cell', () => {
    const table = reconstructTable([
      token('商品', 10, 10), token('数量', 100, 11), token('金額', 180, 10),
      token('りんご', 10, 40, 48), token('300', 181, 41),
      token('みかん', 11, 70, 48), token('2', 101, 70), token('120', 180, 70),
    ], 240, 100);
    expect(values(table)).toEqual([['商品', '数量', '金額'], ['りんご', '', '300'], ['みかん', '2', '120']]);
    expect(table.method).toBe('aligned');
    expect(table.warnings.join('')).toContain('推定');
  });

  it('combines wrapped lines inside one ruled cell, with weakest confidence', () => {
    const table = reconstructTable([token('長い商品名', 10, 10, 70, 12, .97), token('続き', 10, 28, 24, 12, .72)], 200, 80,
      { rowEdges: [0, 60, 80], columnEdges: [0, 100, 200] });
    expect(values(table)).toEqual([['長い商品名\n続き', ''], ['', '']]);
    expect(table.cells[0][0].confidence).toBe(.72);
    expect(table.cells[0][0].box).toEqual({ x: 10, y: 10, width: 70, height: 30 });
  });

  it('retains a blank column from vertical rules when row rules are absent', () => {
    const table = reconstructTable([token('商品', 10, 10), token('300', 210, 10), token('りんご', 10, 45), token('200', 210, 45)],
      300, 80, { rowEdges: [], columnEdges: [0, 100, 200, 300] });
    expect(values(table)).toEqual([['商品', '', '300'], ['りんご', '', '200']]);
  });

  it('infers internal columns from repeated gutters inside an outer rectangle', () => {
    const table = reconstructTable([
      token('商品', 10, 10), token('数量', 110, 10), token('金額', 210, 10),
      token('りんご', 10, 60, 48), token('3', 110, 60, 10), token('360', 210, 60, 30),
    ], 300, 100, { rowEdges: [0, 50, 100], columnEdges: [0, 300] });
    expect(values(table)).toEqual([['商品', '数量', '金額'], ['りんご', '3', '360']]);
    expect(table.rowEdges).toEqual([0, 50, 100]);
    expect(table.columnEdges).toHaveLength(4);
    expect(table.method).toBe('aligned');
    expect(table.warnings.join('')).toContain('外枠の内側');
  });

  it('keeps truly single-column wrapped and indented text inside its row rules', () => {
    const table = reconstructTable([
      token('長い説明文の前半', 10, 8, 110), token('後半', 130, 27, 30),
      token('次の説明文の前半', 10, 58, 110), token('後半', 130, 77, 30),
    ], 300, 100, { rowEdges: [0, 50, 100], columnEdges: [0, 300] });
    expect(values(table)).toEqual([['長い説明文の前半\n後半'], ['次の説明文の前半\n後半']]);
    expect(table.method).toBe('ruled');
  });

  it('does not split a single text column just because OCR words repeat at nearby x positions', () => {
    const table = reconstructTable([
      token('Hello', 10, 10, 30), token('world', 45, 10, 30),
      token('Good', 10, 60, 28), token('morning', 45, 60, 42),
    ], 200, 100, { rowEdges: [0, 50, 100], columnEdges: [0, 200] });
    expect(values(table)).toEqual([['Hello world'], ['Good morning']]);
    expect(table.columnEdges).toEqual([0, 200]);
  });

  it('keeps a single-row sentence together when OCR splits close words', () => {
    const table = reconstructTable([token('Hello', 10, 10, 30), token('world', 45, 10, 30)], 160, 40);
    expect(values(table)).toEqual([['Hello world']]);
  });

  it('keeps one right-aligned amount column despite different digit lengths', () => {
    const table = reconstructTable([
      token('商品', 12, 8, 30), token('金額', 158, 8, 30),
      token('りんご', 10, 38, 48), token('8', 200, 38, 10),
      token('みかん', 11, 68, 48), token('1200', 170, 68, 40),
      token('ぶどう', 10, 98, 48), token('95', 190, 98, 20),
      token('もも', 12, 128, 30), token('7', 200, 128, 10),
    ], 240, 155);
    expect(values(table)).toEqual([['商品', '金額'], ['りんご', '8'], ['みかん', '1200'], ['ぶどう', '95'], ['もも', '7']]);
  });

  it('splits only meaningful spaces, and preserves an unsplittable long line', () => {
    const hints = { rowEdges: [0, 30, 60], columnEdges: [0, 100, 200] };
    const split = reconstructTable([token('りんご    300', 10, 8, 180)], 200, 60, hints);
    expect(values(split)[0]).toEqual(['りんご', '300']);
    const continuous = reconstructTable([token('りんご300円', 10, 8, 180)], 200, 60, hints);
    expect(values(continuous).flat().filter(Boolean)).toEqual(['りんご300円']);
    expect(continuous.warnings.join('')).toContain('またがる');
  });

  it('rejects impossible OCR coordinates and excessive table dimensions', () => {
    expect(() => reconstructTable([token('bad', 999, 0)], 200, 100)).toThrow('座標');
    expect(() => reconstructTable([token('bad', 0, 0, 10, 10, 93)], 200, 100)).toThrow('信頼度');
    expect(() => reconstructTable([token('many', 0, 0)], 200, 200,
      { rowEdges: Array.from({ length: 102 }, (_, i) => i * 1.9), columnEdges: [0, 200] })).toThrow('認識範囲');
    expect(() => reconstructTable([], 200, 100)).toThrow('認識できません');
  });
});

describe('spreadsheet output', () => {
  it('includes a UTF-8 BOM, CRLF, and reversible CSV quoting', () => {
    const csv = toCSV(tableFrom([['0012', 'りんご,青森', '"特選"'], ['2', '一行\n二行', '']]));
    expect(csv).toBe('\uFEFF0012,"りんご,青森","""特選"""\r\n2,"一行\n二行",');
  });
  it('quotes TSV fields that contain tabs, newlines, or double quotes', () => {
    expect(toTSV(tableFrom([['a\tb', '一行\n二行', '"q"']]))).toBe('"a\tb"\t"一行\n二行"\t"""q"""');
  });
  it('neutralizes formula prefixes after whitespace while preserving negative numeric data', () => {
    const source = tableFrom([['=1+2', '  +SUM(A1)', '\t@cmd', '-1+2', '-12.50', '-.5', '-1e3', '通常']]);
    expect(toCSV(source)).toBe('\uFEFF\'=1+2,\'  +SUM(A1),\'\t@cmd,\'-1+2,-12.50,-.5,-1e3,通常');
    expect(toTSV(source, false)).toContain('=1+2');
    expect(toCSV(source, false)).not.toContain("'=1+2");
    expect(values(source)[0][0]).toBe('=1+2');
  });
  it('escapes active HTML and keeps leading-zero text with an Excel format hint', () => {
    const html = toHTML(tableFrom([['<img src=x onerror="alert(1)">', '&', '00123', '=1+2', 'line\nnext']]));
    expect(html).not.toContain('<img');
    expect(html).toContain('&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');
    expect(html).toContain('&amp;');
    expect(html).toContain('mso-number-format:');
    expect(html).toContain('>00123</td>');
    expect(html).toContain('&#39;=1+2');
    expect(html).toContain('line<br>next');
  });
});

describe('immutable editing', () => {
  it('supports row/column edits without changing snapshots', () => {
    const original = tableFrom([['a', 'b'], ['c', 'd']]);
    const edited = editCell(original, 0, 1, 'fixed');
    const grown = addColumn(addRow(edited, 1), 1);
    expect(values(original)).toEqual([['a', 'b'], ['c', 'd']]);
    expect(values(grown)).toEqual([['a', '', 'fixed'], ['', '', ''], ['c', '', 'd']]);
    expect(values(deleteColumn(deleteRow(grown, 1), 1))).toEqual([['a', 'fixed'], ['c', 'd']]);
    expect(edited.cells[0][1]).toMatchObject({ reviewed: true, confidence: 1 });
  });
  it('keeps at least one row/column and rejects out-of-range edits and size overflow', () => {
    const one = createBlankTable(1, 1);
    expect(() => deleteRow(one, 0)).toThrow();
    expect(() => deleteColumn(one, 0)).toThrow();
    expect(() => editCell(one, 1, 0, 'x')).toThrow('範囲外');
    expect(() => addColumn(createBlankTable(1, 40), 40)).toThrow('40');
    expect(() => addRow(createBlankTable(100, 1), 100)).toThrow('100');
  });
});
