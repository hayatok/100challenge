export const MIN_YEAR = 1900;
export const MAX_YEAR = 2026;
export const defaultState = Object.freeze({ year: 1935, birthYear: 1900, metric: 'vital' });
const SAVE_VERSION = 'history-local-v1';
const METRICS = ['vital', 'cpi', 'household'];
const own = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
const record = o => o !== null && typeof o === 'object' && !Array.isArray(o);
export const validYear = value => typeof value === 'number' && Number.isInteger(value) && value >= MIN_YEAR && value <= MAX_YEAR;
const requireYear = y => { if (!validYear(y)) throw new RangeError('Year must be between 1900 and 2026'); };

export function eraLabel(year) {
  requireYear(year);
  if (year === 1912) return '明治45年／大正元年';
  if (year === 1926) return '大正15年／昭和元年';
  if (year === 1989) return '昭和64年／平成元年';
  if (year === 2019) return '平成31年／令和元年';
  if (year >= 2020) return `令和${year - 2018}年`;
  if (year >= 1990) return `平成${year - 1988}年`;
  if (year >= 1927) return `昭和${year - 1925}年`;
  if (year >= 1913) return `大正${year - 1911}年`;
  return `明治${year - 1867}年`;
}

export function ageLabel(year, birthYear) {
  requireYear(year); requireYear(birthYear);
  const age = year - birthYear;
  return age < 0 ? `生まれる${-age}年前` : `${birthYear}年生まれなら、${age}歳になる年`;
}

export function parseState(search, saved = null) {
  const params = new URLSearchParams(typeof search === 'string' ? search : '');
  const accepted = record(saved) && own(saved, 'version') && saved.version === SAVE_VERSION;
  const result = { ...defaultState };
  for (const [field, key] of [['year', 'y'], ['birthYear', 'b'], ['metric', 'm']]) {
    let value = accepted && own(saved, field) ? saved[field] : defaultState[field];
    if (params.has(key)) {
      const raw = params.get(key);
      value = field === 'metric' ? raw : /^\d{4}$/.test(raw) ? Number(raw) : NaN;
    }
    result[field] = field === 'metric' ? (METRICS.includes(value) ? value : defaultState[field]) : (validYear(value) ? value : defaultState[field]);
  }
  return result;
}

function dateYear(value) {
  if (value === null) return null;
  if (typeof value === 'number') return Number.isInteger(value) ? value : NaN;
  return typeof value === 'string' && /^\d{4}(?:-\d{2})?(?:-\d{2})?$/.test(value) ? Number(value.slice(0, 4)) : NaN;
}

export function getYearRecords(data, year) {
  requireYear(year);
  return {
    living: data.living.filter(r => r.start !== null && r.end !== null && dateYear(r.start) <= year && year <= dateYear(r.end)),
    events: data.events.filter(e => dateYear(e.date_start) === year || (e.date_precision === 'range' && e.date_end !== null && dateYear(e.date_start) <= year && year <= dateYear(e.date_end))),
  };
}

export const getUndatedLiving = data => data.living.filter(r => r.start === null || r.end === null);

const NOTES = {
  vital: ['出生と死亡は、その年に記録された人数です。個人が生まれる確率や亡くなる確率ではありません。', '1944〜1946年は戦災による資料喪失などのため原表で省略されています。人数が0だったという意味ではありません。', '1947〜1972年は沖縄県を含みません。1973年から数える地域が変わります。', '戦前を含む国籍や地域の数え方は、全期間を通しては確認しきれていません。同じ範囲の人々を数え続けた記録とはいえません。'],
  cpi: ['全国の暦年平均で、2025年を100とした物価の指数です。円の金額や個人の生活費ではありません。', '過去の数値は公式に接続された指数です。調べる品目や重みは、時代を通して同じではありません。', 'この指数から計算した変化率と、公式に発表された前年比が一致しない場合があります。'],
  household: ['全国の二人以上の世帯が対象で、農林漁家を含みます。単身世帯や個人の平均ではありません。', '各年の1世帯1か月当たり支出の平均です。年額ではなく、その当時の円で表しています。', '消費支出には税や社会保険料は含みません。世帯の人数や年齢も変わるため、同じ家族を追った記録ではありません。'],
};

export function statisticView(data, metric, year) {
  requireYear(year);
  if (!METRICS.includes(metric) || !own(data.metrics, metric)) throw new RangeError('Unknown metric');
  const m = data.metrics[metric];
  const series = m.series.map((s, index) => ({ label: s.label, code: s.code, index, point: s.points.find(p => p.year === year) ?? null }));
  let status = '';
  if (metric === 'vital') {
    if (year >= 1944 && year <= 1946) status = '戦災による資料喪失などのため、1944〜1946年は原表で省略されています。0人という意味ではありません。';
    else if (year >= 2025) status = 'この年の人数はここでは表示していません。この作品で紹介する年別の人数は2024年までです。';
  } else if (metric === 'cpi') {
    if (year < 1970) status = 'ここで表示できる物価の暦年平均は1970年からです。この年の値はありません。';
    else if (year === 2026) status = '2026年の暦年平均はここでは表示していません。月ごとの値や2025年の値とは分けています。';
  } else {
    if (year < 1985) status = 'この表には、この年の家計の記載がありません。ここで紹介する集計は2000年からです。';
    else if (year < 2000) status = '農林漁家を含む二人以上世帯の集計は2000年からです。1985〜1999年の「-」は0円ではありません。';
    else if (year === 2026) status = '2026年の年平均はここでは表示していません。2025年の値をこの年の値として扱いません。';
  }
  if (!status && series.some(s => !s.point)) status = 'この年の数値を確認できませんでした。0として表示せず、空白にしています。';
  let scopeNote;
  if (metric === 'vital') {
    const caution = '戦前を含む国籍や地域の数え方は全期間では確認しきれていません。';
    scopeNote = year >= 1944 && year <= 1946 ? '1944〜1946年は資料の不足で空白です。' : year >= 1947 && year <= 1972 ? `沖縄県を含まない人数です。1973年から数える地域が変わります。${caution}` : year >= 1973 ? `1973年から沖縄県を含む範囲へ変わっています。${caution}` : `原表に掲載された人数です。${caution}`;
  } else if (metric === 'cpi') scopeNote = '全国・暦年平均。2025年=100。過去の数値は公式に接続された指数です。';
  else scopeNote = '全国の二人以上の世帯（農林漁家を含む）。その当時の円で表した、1か月の支出の年平均です。';
  return { metric: m, series, status, scopeNote, sourceNotes: [...NOTES[metric]] };
}

export function formatValue(point, metric) {
  if (point === null || point === undefined) return '—';
  if (!Number.isFinite(point.value) || !Number.isFinite(metric?.divisor) || metric.divisor <= 0) throw new TypeError('Invalid display value');
  return (point.value / metric.divisor).toLocaleString('ja-JP', { maximumFractionDigits: 2 });
}

export function safeSourceURL(value) {
  if (typeof value !== 'string') return null;
  try {
    const u = new URL(value);
    return u.protocol === 'https:' && !u.username && !u.password ? u.href : null;
  } catch { return null; }
}

function assert(ok, message) { if (!ok) throw new TypeError(`Invalid history data: ${message}`); }
function text(value, name) { assert(typeof value === 'string' && value.trim().length > 0, name); }
function date(value, nullable, name) {
  if (value === null && nullable) return;
  const y = dateYear(value); assert(validYear(y), name);
  if (typeof value === 'string' && value.length > 4) {
    const [yy, mm, dd] = value.split('-').map(Number);
    assert(mm >= 1 && mm <= 12, name);
    if (dd !== undefined) assert(dd >= 1 && dd <= new Date(Date.UTC(yy, mm, 0)).getUTCDate(), name);
  }
}

// This is an integrity boundary for this fixed local experience, not a generic
// e-Stat parser. Expected years prevent accidental interpolation or carry-forward.
function dateEdge(value, upper) {
  const parts = String(value).split('-').map(Number);
  const year = parts[0], month = parts[1] ?? (upper ? 12 : 1);
  const day = parts[2] ?? (upper ? new Date(Date.UTC(year, month, 0)).getUTCDate() : 1);
  return Date.UTC(year, month - 1, day);
}

export function validateDataset(data) {
  assert(record(data), 'root'); text(data.version, 'version');
  assert(data.cutoff === '2026-10-16', 'cutoff');
  assert(record(data.metrics) && record(data.sources), 'metrics/sources');
  assert(Array.isArray(data.living) && Array.isArray(data.events), 'living/events');
  const expected = {
    vital: { id: 'SD-STAT001', table: '0003411561', codes: ['00110', '00150'], divisor: 10000, start: 1900, end: 2024, omit: [1944, 1945, 1946] },
    cpi: { id: 'E2ST01', table: '0004052037', codes: ['0001', '0002'], divisor: 1, start: 1970, end: 2025, omit: [] },
    household: { id: 'EST09', table: '0002070003', codes: ['059'], divisor: 10000, start: 2000, end: 2025, omit: [] },
  };
  assert(Object.keys(data.metrics).length === METRICS.length, 'metric count');
  for (const key of METRICS) {
    const m = data.metrics[key], spec = expected[key];
    assert(record(m), key); assert(m.stat_id === spec.id && m.table_id === spec.table, `${key} source table`);
    assert(m.divisor === spec.divisor, `${key} divisor`);
    for (const k of ['title', 'source', 'unit', 'checked_at']) text(m[k], `${key}.${k}`);
    assert(safeSourceURL(m.url) !== null, `${key}.url`);
    assert(Array.isArray(m.notes) && m.notes.every(n => typeof n === 'string'), `${key}.notes`);
    assert(Array.isArray(m.series) && m.series.length === spec.codes.length, `${key} series`);
    m.series.forEach((s, i) => {
      assert(record(s) && s.code === spec.codes[i], `${key} category`); text(s.label, `${key} label`);
      assert(Array.isArray(s.points), `${key} points`);
      const years = new Set(); let previous = -Infinity;
      for (const p of s.points) {
        assert(record(p) && validYear(p.year) && p.year > previous && !years.has(p.year), `${key} unique ascending years`);
        assert(Number.isFinite(p.value) && p.value >= 0, `${key} finite nonnegative value`);
        text(p.raw, `${key} raw`); text(p.unit, `${key} point unit`);
        assert(Number(p.raw) === p.value, `${key} raw/value mismatch`);
        assert(p.unit === (key === 'vital' ? '人' : key === 'household' ? '円' : p.unit), `${key} point unit`);
        years.add(p.year); previous = p.year;
      }
      const allowed = Array.from({ length: spec.end - spec.start + 1 }, (_, j) => spec.start + j).filter(y => !spec.omit.includes(y));
      assert(years.size === allowed.length && allowed.every(y => years.has(y)), `${key} observation coverage`);
    });
  }
  for (const [id, s] of Object.entries(data.sources)) {
    text(id, 'source id'); assert(record(s), 'source'); text(s.title, 'source title'); text(s.institution, 'source institution');
    assert(s.url === null || safeSourceURL(s.url) !== null, 'source url');
  }
  const eventIds = new Set();
  for (const e of data.events) {
    assert(record(e), 'event'); text(e.id, 'event id'); assert(!eventIds.has(e.id), 'duplicate event'); eventIds.add(e.id);
    for (const k of ['title', 'summary', 'geography', 'source_locator']) text(e[k], `event.${k}`);
    date(e.date_start, false, 'event start'); date(e.date_end, true, 'event end');
    assert(e.date_end === null || dateEdge(e.date_start, false) <= dateEdge(e.date_end, true), 'event order');
    assert(String(e.date_start) <= data.cutoff, 'event after cutoff');
    assert(['day', 'month', 'year', 'range'].includes(e.date_precision), 'event precision');
    assert(['content_verified', 'needs_crosscheck'].includes(e.verification), 'event verification');
    assert(Array.isArray(e.source_ids) && e.source_ids.length > 0 && e.source_ids.every(id => typeof id === 'string' && own(data.sources, id)), 'event source reference');
  }
  const livingIds = new Set();
  for (const r of data.living) {
    assert(record(r) && Array.isArray(r.ids) && r.ids.length > 0, 'living ids');
    for (const id of r.ids) { text(id, 'living id'); assert(!livingIds.has(id), 'duplicate living id'); livingIds.add(id); }
    for (const k of ['source_id', 'title', 'period', 'layer', 'summary', 'geo', 'limit', 'source_title', 'institution', 'locator', 'summary_author']) text(r[k], `living.${k}`);
    date(r.start, true, 'living start'); date(r.end, true, 'living end');
    assert(r.start === null || r.end === null || dateEdge(r.start, false) <= dateEdge(r.end, true), 'living order');
    assert(r.url === null || safeSourceURL(r.url) !== null, 'living url');
    assert(r.amount === null || typeof r.amount === 'string', 'living amount');
    assert(['top', 'source', 'pending_notice'].includes(r.link_status), 'living link status');
    // Living records embed their source details; sources indexes event sources only.
  }
  return true;
}
