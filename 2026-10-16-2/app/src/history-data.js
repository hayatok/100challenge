/** Read-only presentation helpers. Source records and their date precision stay intact. */
export const HISTORY_CHAPTERS = Object.freeze([
  { id: 'early', from: 1900, through: 1918, label: '近代の町と村', description: '鉄道・学校・工場と、農村や地域の暮らし' },
  { id: 'interwar', from: 1919, through: 1936, label: '広がる文化、深まる不安', description: '都市の文化、農村の仕事、災害と社会の変化' },
  { id: 'war', from: 1937, through: 1945, label: '戦争が暮らしを覆う', description: '統制・移動の制限・空襲・植民地支配と住民の被害' },
  { id: 'rebuilding', from: 1946, through: 1959, label: '暮らしを立て直す', description: '食料・教育・土地・交通の再建と制度の変化' },
  { id: 'growth', from: 1960, through: 1973, label: '成長の光と影', description: '交通・食品・地域産業の変化と公害・過疎の問題' },
  { id: 'changing', from: 1974, through: 1989, label: '豊かさと地域の変化', description: '消費・通信・地域のつながりと産業の転換' },
  { id: 'connected', from: 1990, through: 2009, label: 'つながる社会の転機', description: '通信・福祉・地域交通と経済の変化' },
  { id: 'present', from: 2010, through: 2026, label: '災害を越えて、いまへ', description: '災害・感染症・多様な暮らしと地域の課題' },
].map(Object.freeze));

export const HISTORY_THEMES = Object.freeze([
  { id: 'everyday', label: '日々の暮らし', topics: ['economy_household', 'population_family', 'housing_infrastructure', 'health_welfare'] },
  { id: 'rural', label: '地方と農山漁村', topics: [] },
  { id: 'food', label: '食べる・着る', topics: ['food_clothing'] },
  { id: 'work', label: '働く・産業', topics: ['work_industry'] },
  { id: 'transport', label: '移動・交通', topics: ['transport'] },
  { id: 'communication', label: '便り・通信', topics: ['media_technology'] },
  { id: 'technology', label: '技術と道具', topics: ['media_technology'] },
  { id: 'culture', label: '文化・楽しみ', topics: ['culture_leisure'] },
  { id: 'education', label: '学校・学び', topics: ['education'] },
  { id: 'rights', label: '制度・権利', topics: ['law_rights_politics'] },
  { id: 'war', label: '戦争・支配', topics: ['war_empire'] },
  { id: 'environment', label: '自然・災害', topics: ['disaster_environment'] },
].map(item => Object.freeze({ ...item, topics: Object.freeze(item.topics) })));

export function eventYear(event) {
  const match = /^(\d{4})(?:$|-)/.exec(String(event?.date_start ?? ''));
  return match ? Number(match[1]) : null;
}

export function eventDateLabel(event) {
  const value = String(event?.date_start ?? '');
  const match = /^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$/.exec(value);
  if (!match) return '時期未確認';
  const [, year, month, day] = match;
  const precision = event.date_precision;
  if (precision === 'year' || !month) return `${year}年`;
  if (precision === 'month' || !day) return `${year}年${Number(month)}月`;
  return `${year}年${Number(month)}月${Number(day)}日`;
}

export function chapterForYear(year) {
  const value = Number(year);
  return HISTORY_CHAPTERS.find(chapter => chapter.from <= value && value <= chapter.through) ?? null;
}

export function eventThemeIds(event) {
  const ids = new Set(event?.theme_ids ?? []);
  const topics = event?.topic_ids ?? [];
  for (const theme of HISTORY_THEMES) if (theme.topics.some(topic => topics.includes(topic))) ids.add(theme.id);
  const text = `${event?.title ?? ''} ${event?.geography ?? ''} ${event?.summary ?? ''}`;
  if (/農村|農家|農業|山村|漁村|漁業|漁師|農地|林業|水稲|養蚕|製糸|小作|出稼|耕地|過疎/.test(text)) ids.add('rural');
  if (/地震|台風|津波|水害|洪水|大火|空襲|防災|公害|地盤沈下|環境/.test(text)) ids.add('environment');
  if (/戦争|戦時|空襲|植民地|軍用地|支配|隔離|疎開/.test(text)) ids.add('war');
  return [...ids];
}

const regionalPatterns = {
  hokkaido: /北海道|札幌|石狩|十勝|稚内|生振|日高|青函/,
  tohoku: /東北|青森|岩手|宮城|秋田|山形|福島|仙台/,
  hokuriku: /北陸|新潟|富山|石川|福井|能登|上越/,
  kanto: /関東|東京|神奈川|千葉|埼玉|茨城|栃木|群馬|浅草|上野/,
  koshin: /甲信|長野|山梨|松本|諏訪|飯山|松代|小諸|白馬/,
  tokai: /東海|愛知|岐阜|静岡|三重|名古屋|丹那|東海道/,
  kinki: /近畿|関西|大阪|京都|兵庫|滋賀|奈良|和歌山|阪神|生駒|神戸/,
  sanin: /山陰|鳥取|島根|出雲/,
  sanyo: /山陽|岡山|広島|山口|下関|倉敷/,
  shikoku: /四国|徳島|香川|愛媛|高知|瀬戸大橋|本四備讃/,
  kyushu: /九州|福岡|佐賀|長崎|熊本|大分|宮崎|鹿児島|奄美|関門/,
  okinawa: /沖縄|琉球|宮古|八重山|那覇|守礼門/,
};

/** A regional filter matches explicit locality; national policies are not assigned to every region. */
export function eventInRegion(event, region) {
  if (!region || region === 'all') return true;
  if (event?.region_ids?.includes(region)) return true;
  if (region === 'national') return ['日本', '全国'].includes(event?.geography);
  return regionalPatterns[region]?.test(`${event?.geography ?? ''} ${event?.title ?? ''} ${event?.summary ?? ''}`) ?? false;
}

function sortKey(event) {
  const date = String(event?.date_start ?? '');
  // Padding is only a comparison key. It never becomes a source date or a displayed date.
  const match = /^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$/.exec(date);
  return match ? `${match[1]}-${match[2] ?? '00'}-${match[3] ?? '00'}` : '9999';
}
export function compareHistory(a, b) {
  return sortKey(a).localeCompare(sortKey(b)) || String(a.id).localeCompare(String(b.id));
}

export function filterHistory(events, { query = '', theme = 'all', from = 1900, through = 2026, region = 'all', chapter = 'all' } = {}) {
  const words = String(query).normalize('NFKC').toLocaleLowerCase('ja').trim().split(/\s+/).filter(Boolean);
  const selectedChapter = HISTORY_CHAPTERS.find(item => item.id === chapter);
  return events.filter(event => {
    const year = eventYear(event);
    if (year === null || year < Number(from) || year > Number(through)) return false;
    if (selectedChapter && (year < selectedChapter.from || year > selectedChapter.through)) return false;
    if (theme && theme !== 'all' && !eventThemeIds(event).includes(theme) && !event.topic_ids?.includes(theme)) return false;
    if (!eventInRegion(event, region)) return false;
    const text = [event.title, event.summary, event.geography, event.life_relevance, eventDateLabel(event), ...(event.topic_ids ?? []), ...eventThemeIds(event).map(id => HISTORY_THEMES.find(t => t.id === id)?.label ?? '')].join(' ').normalize('NFKC').toLocaleLowerCase('ja');
    return words.every(word => text.includes(word));
  }).sort(compareHistory);
}

export function eventsForYear(events, year) {
  return events.filter(event => eventYear(event) === Number(year)).sort(compareHistory);
}

/** Keep the frozen archive intact; reject id collisions instead of silently overwriting research. */
export function mergeHistory(archive, expansion = { events: [], sources: [] }) {
  for (const collection of ['events', 'sources']) {
    if (!Array.isArray(archive[collection]) || !Array.isArray(expansion[collection])) throw new TypeError(`${collection} must be arrays`);
    const ids = new Set(archive[collection].map(item => item.id));
    for (const item of expansion[collection]) {
      if (!item.id || ids.has(item.id)) throw new Error(`Duplicate or missing ${collection} id: ${item.id}`);
      ids.add(item.id);
    }
  }
  const sourceIds = new Set([...archive.sources, ...expansion.sources].map(source => source.id));
  for (const event of expansion.events) {
    if (!(event.source_ids?.length) || event.source_ids.some(id => !sourceIds.has(id))) throw new Error(`Unresolved source for ${event.id}`);
  }
  return {
    ...archive,
    events: [...archive.events, ...expansion.events].sort(compareHistory),
    sources: [...archive.sources, ...expansion.sources],
    historyExpansion: { version: expansion.version ?? null, eventCount: expansion.events.length, sourceCount: expansion.sources.length, checkedAt: expansion.checkedAt ?? null, scopeNote: expansion.scopeNote ?? '' },
  };
}
