import type { GridHints, OcrToken, Rect, TableCell, TableData } from '../types';

export const MAX_ROWS = 100;
export const MAX_COLUMNS = 40;
const blank = (): TableCell => ({ value: '', confidence: 1, reviewed: true });
const median = (values: number[]) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? 0;
};

function checkSize(rows: number, columns: number) {
  if (!Number.isInteger(rows) || !Number.isInteger(columns) || rows < 1 || columns < 1 || rows > MAX_ROWS || columns > MAX_COLUMNS) {
    throw new Error(`表は1〜${MAX_ROWS}行・1〜${MAX_COLUMNS}列にしてください。認識範囲を小さくするか、表を分けてください。`);
  }
}

function cleanEdges(values: number[] | undefined, extent: number): number[] {
  if (!values) return [];
  const sorted = values.filter(v => Number.isFinite(v) && v >= 0 && v <= extent).sort((a, b) => a - b);
  return sorted.filter((v, i) => i === 0 || v - sorted[i - 1] > 1);
}

function validateTokens(tokens: OcrToken[], width: number, height: number): OcrToken[] {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) throw new Error('認識画像のサイズが不正です。');
  return tokens.filter(t => {
    if (!t || typeof t.text !== 'string' || !t.box || !Number.isFinite(t.confidence) || t.confidence < 0 || t.confidence > 1 ||
      ![t.box.x, t.box.y, t.box.width, t.box.height].every(Number.isFinite) || t.box.width <= 0 || t.box.height <= 0 ||
      t.box.x < -1 || t.box.y < -1 || t.box.x + t.box.width > width + 1 || t.box.y + t.box.height > height + 1) {
      throw new Error('文字認識の座標または信頼度が不正です。認識をやり直してください。');
    }
    return t.text.trim().length > 0;
  });
}

const units = (text: string) => Array.from(text).reduce((sum, c) => sum + (c.codePointAt(0)! > 255 ? 1 : .6), 0);

/** Only explicit wide whitespace can justify splitting an OCR line. Character
 * positions within that line are estimates; no characters are manufactured.
 */
function splitSpacedLine(token: OcrToken): OcrToken[] {
  const separators = [...token.text.matchAll(/\t+| {2,}|\u3000+/g)];
  if (!separators.length) return [token];
  const parts: { text: string; start: number; end: number }[] = [];
  let cursor = 0;
  for (const match of separators) {
    if (match.index > cursor) parts.push({ text: token.text.slice(cursor, match.index), start: cursor, end: match.index });
    cursor = match.index + match[0].length;
  }
  if (cursor < token.text.length) parts.push({ text: token.text.slice(cursor), start: cursor, end: token.text.length });
  const total = units(token.text);
  return parts.filter(p => p.text.trim()).map(part => ({
    text: part.text,
    confidence: token.confidence,
    box: { ...token.box, x: token.box.x + token.box.width * units(token.text.slice(0, part.start)) / total,
      width: token.box.width * units(part.text) / total },
  }));
}

interface Band { tokens: OcrToken[]; top: number; bottom: number; center: number }
function rowBands(tokens: OcrToken[]): Band[] {
  const bands: Band[] = [];
  for (const token of [...tokens].sort((a, b) => (a.box.y + a.box.height / 2) - (b.box.y + b.box.height / 2) || a.box.x - b.box.x)) {
    const center = token.box.y + token.box.height / 2;
    const band = bands.find(b => Math.abs(b.center - center) <= Math.min(b.bottom - b.top, token.box.height) * .6);
    if (band) {
      band.tokens.push(token);
      band.top = Math.min(band.top, token.box.y);
      band.bottom = Math.max(band.bottom, token.box.y + token.box.height);
      band.center = median(band.tokens.map(t => t.box.y + t.box.height / 2));
    } else bands.push({ tokens: [token], top: token.box.y, bottom: token.box.y + token.box.height, center });
  }
  return bands.sort((a, b) => a.center - b.center);
}

function inferColumns(bands: Band[], width: number): number[] {
  const tokens = bands.flatMap(b => b.tokens);
  const tolerance = Math.max(4, median(tokens.map(t => t.box.height)) * .7);
  const clusters: { xs: number[]; tokens: OcrToken[]; rows: Set<number> }[] = [];
  bands.forEach((band, row) => {
    [...band.tokens].sort((a, b) => a.box.x - b.box.x).forEach(token => {
      // Common left edges identify text columns; common right edges / nested
      // boxes identify right-aligned numbers whose digit lengths vary. Never
      // collapse two boxes from the same baseline into one recurring anchor.
      const candidates = clusters.filter(c => !c.rows.has(row)).map(c => {
        const leftDelta = Math.abs(median(c.xs) - token.box.x);
        const rightDelta = Math.abs(median(c.tokens.map(t => t.box.x + t.box.width)) - token.box.x - token.box.width);
        const overlap = Math.max(...c.tokens.map(t => Math.max(0, Math.min(t.box.x + t.box.width, token.box.x + token.box.width) - Math.max(t.box.x, token.box.x)) / Math.min(t.box.width, token.box.width)));
        return { cluster: c, score: Math.min(leftDelta, rightDelta), matches: leftDelta <= tolerance || rightDelta <= tolerance || overlap >= .5 };
      }).filter(c => c.matches).sort((a, b) => a.score - b.score);
      const cluster = candidates[0]?.cluster;
      if (cluster) { cluster.xs.push(token.box.x); cluster.tokens.push(token); cluster.rows.add(row); }
      else clusters.push({ xs: [token.box.x], tokens: [token], rows: new Set([row]) });
    });
  });
  // Recurrence across rows is the evidence for a column, including a column
  // missing from one row. A single-row image can only use its visible gaps.
  const leftmost = Math.min(...tokens.map(t => t.box.x));
  let anchors = clusters.filter(c => c.rows.size >= 2 || Math.abs(median(c.xs) - leftmost) <= tolerance || bands.length === 1)
    .map(c => median(c.xs)).sort((a, b) => a - b);
  if (bands.length === 1) {
    const ordered = [...tokens].sort((a, b) => a.box.x - b.box.x);
    anchors = anchors.filter(x => x === anchors[0] || !ordered.some(t => t.box.x < x && t.box.x + t.box.width >= x - Math.max(12, tolerance * 1.8)));
  }
  if (!anchors.length) return [0, width];
  // Multiple left indents in a single text column must not become new columns.
  anchors = anchors.filter((x, i) => i === 0 || x - anchors[i - 1] > tolerance);
  const edges = [0];
  for (let i = 1; i < anchors.length; i++) {
    const previous = anchors[i - 1], current = anchors[i];
    const previousEnds = tokens.filter(t => Math.abs(t.box.x - previous) <= tolerance && t.box.x + t.box.width < current)
      .map(t => t.box.x + t.box.width);
    const end = previousEnds.length ? median(previousEnds) : previous;
    edges.push(Math.max(previous + 1, Math.min(current - 1, (end + current) / 2)));
  }
  return [...edges, width];
}

function cellIndex(edges: number[], center: number): number {
  for (let i = 1; i < edges.length; i++) if (center < edges[i]) return i - 1;
  return edges.length - 2;
}

function hasRepeatedGutters(bands: Band[], rowEdges: number[], columnEdges: number[]): boolean {
  const minimumGap = Math.max(12, median(bands.flatMap(b => b.tokens.map(t => t.box.height))) * 1.25);
  return columnEdges.slice(1, -1).every(edge => {
    const supportedRows = new Set<number>();
    for (const band of bands) {
      // An intact line spanning this candidate is evidence against splitting
      // a real single column. Indented wrapped lines alone do not form gutters.
      if (band.tokens.some(t => t.box.x + 2 < edge && t.box.x + t.box.width - 2 > edge)) return false;
      const leftEnds = band.tokens.filter(t => t.box.x + t.box.width <= edge).map(t => t.box.x + t.box.width);
      const rightStarts = band.tokens.filter(t => t.box.x >= edge).map(t => t.box.x);
      if (leftEnds.length && rightStarts.length && Math.min(...rightStarts) - Math.max(...leftEnds) >= minimumGap) {
        supportedRows.add(cellIndex(rowEdges, band.center));
      }
    }
    return supportedRows.size >= 2;
  });
}

function unionBox(tokens: OcrToken[]): Rect {
  const x = Math.min(...tokens.map(t => t.box.x)), y = Math.min(...tokens.map(t => t.box.y));
  return { x, y, width: Math.max(...tokens.map(t => t.box.x + t.box.width)) - x,
    height: Math.max(...tokens.map(t => t.box.y + t.box.height)) - y };
}

function joinTokens(tokens: OcrToken[]): string {
  const lines = rowBands(tokens);
  return lines.map(line => {
    const ordered = [...line.tokens].sort((a, b) => a.box.x - b.box.x);
    return ordered.map((token, index) => {
      if (!index) return token.text;
      const previous = ordered[index - 1];
      const gap = token.box.x - previous.box.x - previous.box.width;
      const charWidth = previous.box.width / Math.max(1, units(previous.text));
      // Keep Japanese fragments together; retain a word space when boxes have
      // a visible gap. Newline is reserved for distinct baselines in one cell.
      return (gap > Math.max(2, charWidth * .4) ? ' ' : '') + token.text;
    }).join('');
  }).join('\n');
}

export function reconstructTable(rawTokens: OcrToken[], width: number, height: number, hints?: GridHints): TableData {
  const valid = validateTokens(rawTokens, width, height);
  const tokens = valid.flatMap(splitSpacedLine);
  const bands = rowBands(tokens);
  let rowEdges = cleanEdges(hints?.rowEdges, height), columnEdges = cleanEdges(hints?.columnEdges, width);
  const ruledRows = rowEdges.length >= 2, ruledColumns = columnEdges.length >= 2;
  if (!tokens.length && (!ruledRows || !ruledColumns)) throw new Error('文字を認識できませんでした。表を大きく切り抜くか、明るく鮮明な画像で再試行してください。');
  if (!ruledRows) rowEdges = [0, ...bands.slice(1).map((b, i) => (bands[i].bottom + b.top) / 2), height];
  if (!ruledColumns) columnEdges = inferColumns(bands, width);
  let inferredInnerColumns = false;
  if (ruledColumns && columnEdges.length === 2 && bands.length >= 2) {
    // Two outer vertical rules only prove an enclosing rectangle. Repeated,
    // wide gutters in separate table rows can still reveal internal columns.
    const candidates = [columnEdges[0], ...inferColumns(bands, width).slice(1, -1)
      .filter(edge => edge > columnEdges[0] && edge < columnEdges[1]), columnEdges[1]];
    if (candidates.length > 2 && hasRepeatedGutters(bands, rowEdges, candidates)) {
      columnEdges = candidates;
      inferredInnerColumns = true;
    }
  }
  checkSize(rowEdges.length - 1, columnEdges.length - 1);
  const buckets: OcrToken[][][] = Array.from({ length: rowEdges.length - 1 }, () => Array.from({ length: columnEdges.length - 1 }, () => []));
  const warnings = new Set<string>();
  if (!ruledRows || !ruledColumns) warnings.add('罫線のない部分は文字の位置から推定しました。空白行・列と改行を確認してください。');
  if (inferredInnerColumns) warnings.add('外枠の内側に列の罫線がないため、複数行でそろう文字の間隔から列を推定しました。列数と空白セルを確認してください。');
  if (!tokens.length) warnings.add('文字を認識できませんでした。空のセルを作成しました。元画像を確認してください。');
  if (tokens.length !== valid.length) warnings.add('大きな空白で区切られた文字列を分割しました。列の位置を確認してください。');
  for (const token of tokens) {
    const cx = token.box.x + token.box.width / 2, cy = token.box.y + token.box.height / 2;
    // Do not silently discard OCR content outside the detected outer rules.
    if (cx < columnEdges[0] || cx > columnEdges.at(-1)! || cy < rowEdges[0] || cy > rowEdges.at(-1)!) {
      warnings.add('外側の罫線の外に文字があります。最寄りのセルに配置したため、範囲とセルを確認してください。');
    }
    const row = Math.max(0, cellIndex(rowEdges, cy)), col = Math.max(0, cellIndex(columnEdges, cx));
    if (columnEdges.slice(1, -1).some(edge => edge > token.box.x + 2 && edge < token.box.x + token.box.width - 2)) {
      warnings.add('複数列にまたがる文字列があります。文字を保持したまま1セルに配置しました。列を確認してください。');
    }
    buckets[row][col].push(token);
  }
  const cells = buckets.map(row => row.map(group => group.length ? {
    value: joinTokens(group), confidence: Math.min(...group.map(t => t.confidence)), reviewed: false, box: unionBox(group),
  } : blank()));
  return { cells, rowEdges, columnEdges, method: ruledRows && ruledColumns && !inferredInnerColumns ? 'ruled' : 'aligned', warnings: [...warnings] };
}

export function createBlankTable(rows = 4, cols = 3): TableData {
  checkSize(rows, cols);
  return { cells: Array.from({ length: rows }, () => Array.from({ length: cols }, blank)), rowEdges: [], columnEdges: [], method: 'manual', warnings: [] };
}

function dimensions(table: TableData): [number, number] {
  const rows = table.cells.length, cols = table.cells[0]?.length ?? 0;
  checkSize(rows, cols);
  if (table.cells.some(row => row.length !== cols)) throw new Error('表の列数がそろっていません。');
  return [rows, cols];
}
function checkIndex(index: number, length: number, insertion = false) {
  if (!Number.isInteger(index) || index < 0 || index >= length + (insertion ? 1 : 0)) throw new Error('セルの位置が範囲外です。');
}
const structural = (table: TableData, cells: TableCell[][]): TableData => ({ ...table, cells, rowEdges: [], columnEdges: [], method: 'manual' });
export function editCell(table: TableData, row: number, column: number, value: string): TableData {
  const [rows, cols] = dimensions(table); checkIndex(row, rows); checkIndex(column, cols);
  return { ...table, cells: table.cells.map((cells, r) => r === row ? cells.map((cell, c) => c === column ? { ...cell, value, confidence: 1, reviewed: true } : cell) : cells) };
}
export function addRow(table: TableData, index: number): TableData {
  const [rows, cols] = dimensions(table); checkSize(rows + 1, cols); checkIndex(index, rows, true);
  return structural(table, [...table.cells.slice(0, index), Array.from({ length: cols }, blank), ...table.cells.slice(index)]);
}
export function deleteRow(table: TableData, index: number): TableData {
  const [rows, cols] = dimensions(table); checkIndex(index, rows); checkSize(rows - 1, cols);
  return structural(table, table.cells.filter((_, r) => r !== index));
}
export function addColumn(table: TableData, index: number): TableData {
  const [rows, cols] = dimensions(table); checkSize(rows, cols + 1); checkIndex(index, cols, true);
  return structural(table, table.cells.map(row => [...row.slice(0, index), blank(), ...row.slice(index)]));
}
export function deleteColumn(table: TableData, index: number): TableData {
  const [rows, cols] = dimensions(table); checkIndex(index, cols); checkSize(rows, cols - 1);
  return structural(table, table.cells.map(row => row.filter((_, c) => c !== index)));
}

/** Prefix potential spreadsheet formulas with a literal apostrophe, including
 * those preceded by whitespace/control characters. Plain negative decimal /
 * scientific numbers remain numeric. CSV/TSV text import may coerce digit-only
 * IDs; HTML copy supplies a text-format hint to retain their leading zeros.
 */
function exportValue(value: string, protect: boolean): string {
  const trimmed = value.trimStart();
  const ordinaryNegative = /^-(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?\s*$/.test(trimmed);
  return protect && /^[=+@-]/.test(trimmed) && !ordinaryNegative ? `'${value}` : value;
}
function quote(value: string, delimiter: string): string {
  return value.includes(delimiter) || /["\r\n]/.test(value) ? `"${value.replaceAll('"', '""')}"` : value;
}
export function toTSV(table: TableData, protectFormulas = true): string {
  dimensions(table);
  return table.cells.map(row => row.map(cell => quote(exportValue(cell.value, protectFormulas), '\t')).join('\t')).join('\r\n');
}
export function toCSV(table: TableData, protectFormulas = true): string {
  dimensions(table);
  return '\uFEFF' + table.cells.map(row => row.map(cell => quote(exportValue(cell.value, protectFormulas), ',')).join(',')).join('\r\n');
}
const escapeHTML = (value: string) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
export function toHTML(table: TableData, protectFormulas = true): string {
  dimensions(table);
  return '<table><tbody>' + table.cells.map(row => '<tr>' + row.map(cell => '<td style="mso-number-format:\'\\@\';white-space:pre-wrap">' + escapeHTML(exportValue(cell.value, protectFormulas)).replace(/\r\n|\r|\n/g, '<br>') + '</td>').join('') + '</tr>').join('') + '</tbody></table>';
}
