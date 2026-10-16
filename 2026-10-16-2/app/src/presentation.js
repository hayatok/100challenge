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
export function materialInYear(item, year) {
  if (item.period_start === null || item.period_start === undefined || item.period_end === null || item.period_end === undefined) return false;
  const start = Number(String(item.period_start).slice(0, 4)), end = Number(String(item.period_end).slice(0, 4));
  return Number.isInteger(start) && Number.isInteger(end) && start <= year && year <= end;
}
export function period(start, end) {
  const present = value => value !== null && value !== undefined && value !== '';
  const label = value => String(value).replace(/^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?$/, (_, year, month, day) => `${year}年${month ? `${Number(month)}月` : ''}${day ? `${Number(day)}日` : ''}`);
  if (!present(start) && !present(end)) return '年代を確かめきれていない記録';
  if (!present(start)) return `始まり不詳〜${label(end)}`;
  if (!present(end)) return `${label(start)}〜終わり不詳`;
  if (String(start) === String(end)) return label(start);
  if (/^\d{4}$/.test(String(start)) && /^\d{4}$/.test(String(end))) return `${start}–${end}年`;
  return `${label(start)}〜${label(end)}`;
}
const regionalNames = {
  hokkaido: /北海道|浜益/, tohoku: /青森|岩手|宮城|秋田|山形|福島/, hokuriku: /新潟|富山|石川|福井/,
  kanto: /東京|神奈川|埼玉|千葉|茨城|栃木|群馬/, koshin: /長野|山梨/, tokai: /静岡|愛知|岐阜|三重/,
  kinki: /滋賀|京都|大阪|兵庫|奈良|和歌山/, sanin: /鳥取|島根/, sanyo: /岡山|広島|山口/,
  shikoku: /徳島|香川|愛媛|高知/, kyushu: /福岡|佐賀|長崎|熊本|大分|宮崎|鹿児島/, okinawa: /沖縄|石垣|西表/
};
export function regionalMaterial(item, placeId) { return regionalNames[placeId]?.test(String(item.geography)) ?? false; }
export function recordNotes(value) {
  if (!value) return [];
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.flatMap(recordNotes);
  return [value.meaning, value.instruction, value.description, value.reason, value.cause].filter(Boolean).flatMap(recordNotes);
}
export function readableResearchText(value = '') {
  return String(value ?? '')
    .replace(/CLI catalogヘルプは検索のみ。?/g, '')
    .replace(/\b(?:cat\d+|tab|area|time(?:From|To)?|axis|frequency|limit|startPosition|meta)\s*=\s*[^\s。、；;）)]+/gi, '')
    .replace(/\s*証拠\s*=\s*[^\s。]+/g, '')
    .replace(/evidence\/[A-Za-z0-9_./-]+/g, '原資料の取得記録')
    .replace(/\b(?:SD2?-GAP\d+|EG_[A-Z_]+|SD2?-STAT\d+|E2?ST\d+|[DEHL]3-(?:ST|S|M|E|G)\d+|SD2?-CAT\d+)\b/g, '関連する記録')
    .replace(/最古time/g, '最も古い年')
    .replace(/SSD0歳/g, '社会・人口統計の0歳')
    .replace(/\bcatalog\b/gi, '公開目録')
    .replace(/\bdescribe\b/gi, '表の説明を確認')
    .replace(/\btime\b/gi, '年の表示')
    .replace(/\bSSD\b/g, '社会・人口統計')
    .replace(/\bDB\b/g, '統計表')
    .replace(/DB\d{10}/g, '統計表')
    .replace(/\bE2501\b/g, '小学校の在学者数')
    .replace(/\bE6302\b/g, '大学学部の学生数')
    .replace(/API102(?:エラー)?/g, '検索条件を受け付けないエラー')
    .replace(/\bAPI\b/g, '配信される統計')
    .replace(/\braw\b/gi, '原表')
    .replace(/\bCLI\b/g, '統計取得用ツール')
    .replace(/\breceipt\b/gi, '取得時の記録')
    .replace(/\b(?:XLSX?|CSV)\b/gi, '公開表')
    .replace(/(固定電話|スマートフォン|FAX|PC|携帯(?:電話)?)\d{3}(?:\/\d{3})*/g, '$1')
    .replace(/チャネル/g, '指標')
    .replace(/\b(?:cat\d+|time_year_map|time_dimension)\b/g, '原表の区分')
    .replace(/\b(?:partial|blocked|not_researched)\b/g, '確認が残る範囲')
    .replace(/（関連する記録）/g, '')
    .replace(/[、,]\s*(?=[、,。])/g, '')
    .replace(/。{2,}/g, '。')
    .replace(/ {2,}/g, ' ');
}
