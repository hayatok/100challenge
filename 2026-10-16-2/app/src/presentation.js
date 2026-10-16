export function observationTime(point) {
  if (!Number.isInteger(point.year)) return null;
  const month = String(point.timeLabel || point.time_label || '').match(/年\s*(\d{1,2})月/);
  return point.year * 12 + (month ? Number(month[1]) - 1 : 0);
}
const japaneseYear = new Intl.DateTimeFormat('ja-JP-u-ca-japanese', { era: 'long', year: 'numeric', timeZone: 'UTC' });
export function eraLabel(year, month) {
  const first = japaneseYear.format(new Date(Date.UTC(year, month - 1, 1)));
  const last = japaneseYear.format(new Date(Date.UTC(year, month, 0)));
  return first === last ? first : `${first}／${last}`;
}
export function pointsThrough(entry, year, month) {
  const cutoff = year * 12 + month - 1;
  return entry.points.filter(point => point.kind === 'number' && Number.isFinite(point.value) && observationTime(point) !== null && observationTime(point) <= cutoff);
}
export function materialStatus(item) {
  return ({
    item_content_verified: 'この記録の一部を読み、内容を確認しています。',
    collection_content_verified: '資料群の解説を確認しています。個々の資料の本文を確認したとは限りません。',
    catalog_verified: '目録・書誌情報を確認しています。本文の内容は未確認です。',
    locator_only: '資料の所在は確認しています。本文は読み取れていません。記録期間や支出額も未確認です。'
  })[item.verification] || '確認できた範囲が限られています。';
}
export function recordNotes(value) {
  if (!value) return [];
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.flatMap(recordNotes);
  return [value.meaning, value.instruction, value.description, value.reason, value.cause].filter(Boolean).flatMap(recordNotes);
}
export function readableResearchText(value = '') {
  return String(value ?? '')
    .replace(/\s*証拠\s*=\s*[^\s。]+/g, '')
    .replace(/evidence\/[A-Za-z0-9_./-]+/g, '原資料の取得記録')
    .replace(/\b(?:SD2?-GAP\d+|EG_[A-Z_]+|SD2?-STAT\d+|E2?ST\d+)\b/g, '関連する調査項目')
    .replace(/最古time/g, '最も古い年')
    .replace(/SSD0歳/g, '社会・人口統計の0歳')
    .replace(/\bcatalog\b/gi, '公開目録')
    .replace(/\bdescribe\b/gi, '表の説明を確認')
    .replace(/\btime\b/gi, '年の表示')
    .replace(/\bSSD\b/g, '社会・人口統計')
    .replace(/\bDB\b/g, '統計表')
    .replace(/API102(?:エラー)?/g, '検索条件を受け付けないエラー')
    .replace(/\bAPI\b/g, '配信される統計')
    .replace(/\braw\b/gi, '原表')
    .replace(/\bCLI\b/g, '統計取得用ツール')
    .replace(/\breceipt\b/gi, '取得時の記録');
}
