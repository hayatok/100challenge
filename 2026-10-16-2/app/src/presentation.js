export function observationTime(point) {
  if (!Number.isInteger(point.year)) return null;
  const month = String(point.timeLabel || point.time_label || '').match(/年\s*(\d{1,2})月/);
  return point.year * 12 + (month ? Number(month[1]) - 1 : 0);
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
