import { PLACES, createSimulation, snapshot, seek, advance, reroll, selectPerson, selectPlace } from './model.js';
import { createRenderer } from './renderer.js';
import { STORAGE_KEY, parseSaved, serializeSaved, escapeHTML as esc, safeURL } from './storage.js';
import { observationTime, pointsThrough, materialStatus, recordNotes } from './presentation.js';

const $ = id => document.getElementById(id);
const number = new Intl.NumberFormat('ja-JP', { maximumFractionDigits: 3 });
const driverDescriptions = {
  population: '全国の人口を縮めて、人の模型の密度を変えています。模型の一人が、実在の一人を表すものではありません。',
  industry: '同じ分類の最初の記録との比から、田畑と工場の模型の量を変えています。異なる調査や産業分類は、つなげずに描き分けています。',
  housing: '総住宅数を縮めて家を描き、空き家数を参考に灯りの消えた家を置いています。町ごとの配置は架空です。',
  water: '上水道の給水人口を縮めて、水道設備の模型の量を変えています。水道の普及率や電化率を表すものではありません。',
  education: '小学校と大学の在学者の記録を、それぞれの最初の年と比べ、学校と通学の人影を描いています。架空の人の進学を決める数字にはしていません。',
  rice: '一人一年当たりの米の供給量を参考に、米屋の俵の模型を増減しています。実際に食べた量や、買った量とは異なります。',
  prices: '商店のそばに、そのままの物価指数を掲げています。円の価格や、個人の家計への換算はしていません。',
  bus: '記録のある月の乗合バス輸送人員を縮めて、走るバスの模型の量を変えています。実際の車両数や路線ではありません。'
};
let archive, drivers, sim, current, renderer, sources, statistics, series;
let playing = true, speed = 1, view = 'japan', reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let motionTime = 0, lastFrame = 0, lastModel = 0, accumulatedMonths = 0, frameId = 0, dirty = true;
let archiveSection = 'statistics', seriesDetail = null, seriesPage = 1, seriesYear = null, detailResume = false, archiveLimit = 30;
let lastUIStamp = '', livingPage = 0, lastHistoryIndex = 0, lastCuration = 0, saveAvailable = true;
const dialogs = [$('detail-dialog'), $('archive-dialog')];

function announce(message) { $('announcement').textContent = message; }
function era(year) {
  const eras = [[2019, '令和'], [1989, '平成'], [1926, '昭和'], [1912, '大正'], [1868, '明治']];
  const [start, name] = eras.find(([start]) => year >= start);
  return `${name}${year === start ? '元' : year - start + 1}年`;
}
function sourceHTML(id, locator = '') {
  const source = sources.get(id); if (!source) return '<p class="small">出典の詳しい情報がありません。</p>';
  const url = safeURL(source.url);
  return `<div class="source-entry">${url ? `<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">${esc(source.title)} ↗</a>` : `<strong>${esc(source.title)}</strong>`}<p>${esc(source.institution || '')}${source.checked_at ? ` ／ 確認日 ${esc(String(source.checked_at).slice(0, 10))}` : ''}</p>${locator ? `<p>参照箇所：${esc(locator)}</p>` : ''}${source.perspective_limit ? `<p>${esc(source.perspective_limit)}</p>` : ''}</div>`;
}
function formatValue(observation) {
  if (observation.value === null || !Number.isFinite(observation.value)) return '—';
  return number.format(observation.value);
}
function readableUnit(unit) { return /未取得|未確認|未確定/.test(unit || '') ? '単位は確認中' : unit || ''; }
function observationLabel(id, index = 0) {
  if (id === 'industry') return index ? '製造業の働き手' : current.year < 1953 ? '農業の有業者' : '農業・林業の就業者';
  return ({ population: ['全国人口'], housing: ['総住宅数', '空き家数'], water: ['上水道の給水人口'], education: ['小学校の在学者数', '大学の在学者数'], rice: ['米の供給量／1人・1年'], prices: ['総合指数', '食料指数'], bus: ['乗合バス輸送人員／月次'] })[id]?.[index] || '';
}
function pointDate(observation) { return observation.point?.timeLabel || observation.point?.time_label || 'この年代の記録はありません'; }
function sourceForEvent(event) { return (event.source_ids || []).map(id => sourceHTML(id, event.locator || event.source_locator)).join(''); }
function boundedYear(input, allowEmpty = false) {
  if (allowEmpty && input === '') return null;
  const value = Number(input);
  return Number.isInteger(value) && value >= 1900 && value <= 2026 ? value : undefined;
}
function choosePerson(excluded = null) {
  const local = current.world.people.filter(person => person.placeId === sim.placeId);
  const preferred = local.filter(person => person.age >= 15 && person.age <= 65);
  const candidates = preferred.length ? preferred : local;
  if (candidates.length) { const index = candidates.findIndex(person => person.id === excluded); sim = selectPerson(sim, candidates[(index + 1) % candidates.length].id); current = snapshot(sim); }
}
function refresh(selectDefault = false) {
  current = snapshot(sim);
  if (selectDefault || !current.selectedPerson) choosePerson();
  dirty = true; renderUI(true); save();
}
function save() {
  try {
    localStorage.setItem(STORAGE_KEY, serializeSaved(current, { placeId: sim.placeId, personId: sim.personId, speed, reducedMotion }));
    $('save-status').textContent = 'この端末に続きを保存しています。';
  } catch { saveAvailable = false; $('save-status').textContent = 'この端末では保存できません。開いている間は遊べます。'; }
}
function playState() {
  if (current?.ended) { playing = false; $('play-state').textContent = 'いまにつながりました'; $('toggle-play').textContent = '↶ 最初から'; $('toggle-play').setAttribute('aria-label', '1900年から眺め直す'); }
  else { $('play-state').textContent = playing ? '時代が流れています' : '時間を止めています'; $('toggle-play').textContent = playing ? 'Ⅱ 止める' : '▶ 眺める'; $('toggle-play').setAttribute('aria-label', playing ? '時間を止める' : '時間を進める'); }
}
function setPlaying(value, message = '') {
  playing = value; accumulatedMonths = 0; lastModel = performance.now(); dirty = true; playState();
  if (message) $('time-message').textContent = message;
}
function setView(next) {
  view = next;
  $('view-japan').setAttribute('aria-pressed', String(view === 'japan'));
  $('view-place').setAttribute('aria-pressed', String(view === 'place'));
  $('scene-title').hidden = view === 'place';
  dirty = true; renderUI(true);
}
function setPlace(id, zoom = true) {
  sim = selectPlace(sim, id); current = snapshot(sim); choosePerson();
  if (zoom) setView('place');
  refresh(); announce(`${current.selectedPlace.region}の${current.selectedPlace.name}を眺めます。`);
}
function portrait(person) {
  const color = ['#8d584c', '#627e67', '#647783', '#b99a59'][person.name.length % 4];
  return `<svg class="person-portrait" viewBox="0 0 62 72" aria-hidden="true"><path d="M12 72V53q19-14 38 0v19" fill="${color}"/><path d="M26 42v12h10V42" fill="#d9b78e"/><ellipse cx="31" cy="29" rx="15" ry="19" fill="#e9c89d"/><path d="M16 29q-3-23 15-23 20 0 15 25l-5-15-19 3z" fill="#3f3c33"/><circle cx="25" cy="29" r="1.2" fill="#3f3c33"/><circle cx="37" cy="29" r="1.2" fill="#3f3c33"/><path d="M28 38q3 2 6 0" fill="none" stroke="#a36b59" stroke-width="1.5"/></svg>`;
}
function renderPerson() {
  const person = current.selectedPerson;
  if (!person) { $('person-content').innerHTML = '<p class="observation-empty">この町を歩く人を、まだ見つけられませんでした。別の場所ものぞいてみてください。</p>'; return; }
  const unborn = person.birthYear > current.year;
  const aliveLabel = unborn ? 'まだ生まれていません' : person.alive ? `${person.age}歳 ／ ${person.birthYear}年生まれ` : `${person.birthYear}–${person.deathYear}年の暮らし`;
  const family = person.family?.filter(member => member.generation > person.generation) || [];
  $('person-content').innerHTML = `<div class="person-intro">${portrait(person)}<div><p class="person-name">${esc(person.name)}</p><p class="person-age">${esc(aliveLabel)}</p><span class="fiction-tag">箱庭に生まれた架空の人物</span></div></div><p class="person-activity">${esc(unborn ? '時代を進めると、この人の暮らしが始まります。' : person.activity)}</p><ol class="life-journal">${person.lifeEvents.slice(-3).map(event => `<li><span>${event.year}</span><span>${esc(event.text)}</span></li>`).join('')}</ol>${family.length ? `<button type="button" class="follow-family" data-person="${esc(family[0].id)}">次の世代、${esc(family[0].name)}${family[0].alive ? 'を見守る →' : 'の記録へ →'}</button>` : ''}`;
}
function currentHistory() {
  const exact = archive.events.filter(event => String(event.date_start).slice(0, 4) === String(current.year) && (!/^-?\d{4}-\d{2}/.test(String(event.date_start)) || Number(String(event.date_start).slice(5, 7)) <= current.month));
  const pool = exact.length ? exact.sort((a, b) => String(b.date_start).localeCompare(String(a.date_start))) : current.events;
  return pool.length ? pool[lastHistoryIndex % pool.length] : null;
}
function renderHistory() {
  const event = currentHistory();
  $('history-year').textContent = event ? String(event.date_start).slice(0, 4) : '';
  if (!event) { $('history-content').innerHTML = '<p class="observation-empty">この時点までに日付を確かめられた出来事はありません。これから届く時代の便りを待ちましょう。</p>'; return; }
  $('history-content').innerHTML = `<p class="history-kicker">${esc(event.date_start)} ${esc(event.geography || '')}</p><h3 class="history-title">${esc(event.title)}</h3><p class="history-summary">${esc(event.summary)}</p><button type="button" class="inline-link" data-event="${esc(event.id)}">出典と詳しい記録 ↗</button>`;
}
function sparkline(observation) {
  const points = pointsThrough(observation.series, current.year, current.month).filter(point => observation.segment === null || point.year >= observation.segment);
  if (points.length < 2) return '';
  const values = points.map(point => point.value), min = Math.min(...values), max = Math.max(...values), first = observationTime(points[0]), span = Math.max(1, observationTime(points.at(-1)) - first);
  return `<svg class="sparkline" viewBox="0 0 90 24" aria-hidden="true">${points.map(point => `<circle cx="${((observationTime(point) - first) / span * 88 + 1).toFixed(1)}" cy="${(20 - (point.value - min) / Math.max(1, max - min) * 17).toFixed(1)}" r="1.1" fill="#56715b"/>`).join('')}</svg>`;
}
function renderMacro() {
  $('macro-grid').innerHTML = drivers.drivers.map(driver => {
    const signal = current.macro[driver.id];
    const unavailable = signal.status === 'unavailable';
    return `<button type="button" class="macro-card" data-driver="${driver.id}"><span class="metric-label">${esc(driver.label)}<span aria-hidden="true">↗</span></span><span class="metric-context">${esc(observationLabel(driver.id))}</span><span class="metric-value${unavailable ? ' unavailable' : ''}">${unavailable ? 'この年の記録なし' : `${formatValue(signal)}<small>${esc(readableUnit(signal.unit))}</small>`}</span><span class="metric-date">${unavailable ? (signal.point ? `原表の記号：${esc(signal.point.raw)}` : 'ある年から、数字が見えてきます') : `${signal.status === 'historical' ? '過去の記録：' : ''}${esc(pointDate(signal))}`}</span><span class="metric-link">${esc(driver.worldTarget.replace('模型', '風景'))}</span>${unavailable ? '' : sparkline(signal)}</button>`;
  }).join('');
  const missing = Object.values(current.macro).filter(signal => signal.status === 'unavailable').length;
  const past = Object.values(current.macro).filter(signal => signal.status === 'historical').length;
  $('basis-note').textContent = `${missing ? `${missing}項目にはこの時点で使える数字がありません。` : ''}${past ? '過去の年の記録を参考にしている風景があります。観測年を併記しています。' : ''}数値のない量や町ごとの配置、人物の暮らしには作者の想像を含みます。`;
}
function renderLiving() {
  const entries = current.living;
  if (!entries.length) { $('living-content').innerHTML = '<p class="observation-empty">この年に結びつけられる暮らしの記録は、まだありません。年を決めきれない記憶も「各地の記録」から読めます。</p>'; return; }
  const regional = entries.filter(item => String(item.geography).includes(current.selectedPlace.region));
  const pool = [...regional, ...entries.filter(item => !regional.includes(item))];
  const offset = livingPage % Math.max(1, pool.length);
  const selected = [...pool.slice(offset), ...pool.slice(0, offset)].slice(0, 3);
  $('living-content').innerHTML = selected.map(item => `<article class="living-card"><span class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</span><h3>${esc(item.title)}</h3><p>${esc(item.what_it_shows)}</p><button type="button" class="inline-link" data-living="${esc(item.id)}">誰の記録か、出典を読む ↗</button></article>`).join('');
}
function renderUI(force = false) {
  if (!current) return;
  const stamp = `${current.year}-${current.month}-${sim.personId}-${sim.placeId}-${sim.seed}-${view}`;
  if (!force && stamp === lastUIStamp) return;
  lastUIStamp = stamp;
  $('year-label').textContent = current.year; $('era-label').textContent = era(current.year); $('month-label').textContent = current.month;
  if (document.activeElement !== $('year-input')) $('year-input').value = current.year;
  $('year-range').value = current.year; $('place-select').value = sim.placeId;
  $('scene-caption').textContent = view === 'japan' ? '12の架空の町で、日本の暮らしを描いています。' : `${current.selectedPlace.region} ／ ${current.selectedPlace.name}。人物を押すと、その暮らしを追えます。`;
  $('world-canvas').setAttribute('aria-label', `${current.year}年${current.month}月の${view === 'japan' ? '日本の全景' : current.selectedPlace.name}。架空の人々が暮らす箱庭。場所と人は画面右の操作でも選べます。`);
  $('vital-records').innerHTML = [['00110', '出生数'], ['00150', '死亡数']].map(([code, label]) => {
    const entry = archive.series.find(item => item.id === `SD-STAT001:cat01=${code}`), point = entry.points.find(item => item.year === current.year);
    return `<button type="button" data-vital="${code}"><span>${current.year}年の記録 ／ ${label}</span><strong>${point?.kind === 'number' ? `${number.format(point.value)}<small>人</small>` : '記録なし'}</strong><span class="vital-source">対象と出典 ↗</span></button>`;
  }).join('');
  renderPerson(); renderHistory(); renderMacro(); renderLiving(); playState();
}
function period(start, end) {
  if (!start && !end) return '年代を確かめきれていない記録';
  return start === end || !end ? `${start ?? end}年` : `${start ?? '始まり不詳'}–${end}年`;
}
function openDialog(dialog) {
  if (!dialogs.some(item => item.open)) detailResume = playing;
  setPlaying(false); if (!dialog.open) dialog.showModal();
}
function dialogClosed() {
  if (!dialogs.some(dialog => dialog.open) && detailResume && !current.ended) { setPlaying(true); detailResume = false; }
}
function detail(title, html) {
  $('detail-title').textContent = title; $('detail-body').innerHTML = html; openDialog($('detail-dialog')); $('detail-dialog').scrollTop = 0;
}
function eventDetail(id) {
  const event = archive.events.find(item => item.id === id); if (!event) return;
  detail(event.title, `<p class="small">${esc(event.date_start)}${event.date_end ? ` — ${esc(event.date_end)}` : ''} ／ ${esc(event.geography || '')}</p><p>${esc(event.summary)}</p>${event.qualification ? `<div class="detail-note"><p>${esc(event.qualification)}</p></div>` : ''}<h3>出典</h3>${sourceForEvent(event)}`);
}
function vitalDetail(code) {
  const entry = series.get(`SD-STAT001:cat01=${code}`), point = entry.points.find(item => item.year === current.year), stat = statistics.get(entry.statId);
  detail(`${current.year}年の${entry.label}`, `${point?.kind === 'number' ? `<p class="detail-value">${number.format(point.value)} <small>人</small></p>` : '<p class="missing-note">この年の数字はありません。1944〜1946年は、戦災などによる資料の不備で原表から省略されています。最新の収録年は2024年です。</p>'}<p>その年全体の公表集計です。今見ている月の人数ではありません。架空の人物が生まれたり亡くなったりする抽選には使っていません。</p><div class="detail-note"><p>歴史的な領域・国籍・届出の範囲に違いがあり、全期間を同じ集団として比較できるとは限りません。1947〜1972年は沖縄県を含みません。詳しい対象の変遷には確認が残っています。</p></div>${chartHTML({series:entry,point})}<button type="button" data-series="${esc(entry.id)}">原表の年・数字・欠測を見る →</button>${sourceHTML(entry.sourceId, `統計表 ${entry.tableId}`)}`);
}
function livingDetail(id) {
  const item = archive.living.find(record => record.id === id); if (!item) return;
  detail(item.title, `<p class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</p><div class="detail-note"><p>${esc(materialStatus(item))}</p></div><p>${esc(item.what_it_shows)}</p><dl class="detail-dl"><dt>記録の形</dt><dd>${esc(item.material_type)}</dd><dt>誰の経験か</dt><dd>${esc(item.whose_voice)}</dd></dl><div class="detail-note"><p>${esc(item.representativeness_limit || 'この記録を全国の人々の平均としては扱えません。')}</p></div><h3>出典</h3>${sourceHTML(item.source_id, item.item_locator)}<p class="small">原資料の文章・写真・映像の利用条件は、それぞれの公開元をご確認ください。</p>`);
}
function chartHTML(observation) {
  const pts = observation.series.points.filter(point => point.year !== null && Number.isFinite(point.value) && point.kind === 'number');
  if (pts.length < 2) return '';
  const minYear = Math.min(...pts.map(point => point.year)), maxYear = Math.max(...pts.map(point => point.year));
  const firstTime = Math.min(...pts.map(observationTime)), lastTime = Math.max(...pts.map(observationTime));
  const low = Math.min(...pts.map(point => point.value)), high = Math.max(...pts.map(point => point.value));
  const x = point => 28 + (observationTime(point) - firstTime) / Math.max(1, lastTime - firstTime) * 540;
  const y = value => 140 - (value - low) / Math.max(1, high - low) * 120;
  // Show observations as dots. A line would imply continuity through missing years and changes in scope.
  return `<svg class="detail-chart" viewBox="0 0 600 170" role="img" aria-label="${esc(observation.series.label)}の観測点。${minYear}年から${maxYear}年。"><line x1="28" x2="568" y1="141" y2="141" stroke="#C9C4BA"/>${pts.map(point => `<circle cx="${x(point).toFixed(1)}" cy="${y(point.value).toFixed(1)}" r="${point.id === observation.point?.id ? 4 : 2.2}" fill="${point.id === observation.point?.id ? '#B73529' : '#56715b'}"/>`).join('')}<text x="28" y="162" font-size="11" fill="#5B5A54">${minYear}</text><text x="568" y="162" text-anchor="end" font-size="11" fill="#5B5A54">${maxYear}</text></svg><p class="chart-caption">点は原表の観測値です。点と点の間の数字は作っていません。</p>`;
}
function driverDetail(id) {
  const driver = drivers.drivers.find(item => item.id === id), signal = current.macro[id]; if (!driver || !signal) return;
  detail(driver.label, `<div class="detail-note"><p>${esc(driverDescriptions[id])}</p></div>${signal.observations.map((observation, index) => `<h3>${esc(observationLabel(id, index))}</h3>${observation.status === 'unavailable' ? `<p class="missing-note">${observation.point ? `この時点では使える記録がありません。原表の値は「${esc(observation.point.raw)}」です。` : 'この時点までの数字を確認できていません。'} 数字を補って風景の量を決めてはいません。</p>` : `<p class="detail-value">${formatValue(observation)} <small>${esc(readableUnit(observation.unit))}</small></p><p class="small">${esc(pointDate(observation))}${observation.status === 'historical' ? ' の記録を参考にしています。見る年そのものの値ではありません。' : ''}</p>`}${chartHTML(observation)}<button type="button" data-series="${esc(observation.series.id)}">原表の年・数字・記号を見る →</button>${sourceHTML(observation.series.sourceId, `統計表 ${observation.series.tableId}`)}`).join('')}<h3>数字の読み方</h3><p>${esc(driver.limitation || '')}</p>${driver.boundaries?.length ? `<p class="small">比較の区切り：${driver.boundaries.map(boundary => `${boundary.year}年 ${esc(boundary.reason)}`).join(' ／ ')}</p>` : ''}`);
}
function seriesDetailHTML() {
  const entry = series.get(seriesDetail), stat = statistics.get(entry.statId), year = seriesYear;
  const all = entry.points.filter(point => year === null || year === undefined || point.year === year);
  const points = all.slice(0, seriesPage * 100);
  const peers = archive.series.filter(item => item.statId === entry.statId);
  return `<p class="small">${esc(stat.title)} ／ ${esc(entry.geography || '')}</p><label class="small" for="series-picker">同じ表の区分</label><select id="series-picker" class="series-select">${peers.map(item => `<option value="${esc(item.id)}"${item.id === entry.id ? ' selected' : ''}>${esc(item.label)}</option>`).join('')}</select><p>単位：${esc(readableUnit(entry.unit) || '原表を参照')}。原表の時間の表記と欠測記号をそのまま示しています。</p>${year !== null && year !== undefined && !all.length ? `<p class="missing-note">${year}年の観測は、この区分にはありません。0ではありません。</p><button type="button" id="show-all-series-years">すべての年の記録を見る</button>` : ''}<div class="record-table-wrap"><table class="record-table"><thead><tr><th scope="col">原表の時期</th><th scope="col">値</th><th scope="col">単位</th><th scope="col">記録の状態</th></tr></thead><tbody>${points.map(point => `<tr><td>${esc(point.timeLabel || point.time_label || '時期を確かめきれていません')}</td><td>${esc(point.raw)}</td><td>${esc(readableUnit(point.unit || entry.unit))}</td><td>${point.kind === 'number' ? '数値' : `原表の記号${point.value_note ? `：${esc(point.value_note)}` : '（0ではありません）'}`}</td></tr>`).join('')}</tbody></table></div><p class="small">${points.length} / ${all.length}件表示</p>${all.length > points.length ? '<button id="more-series" type="button" class="more-records">次の100件を表示</button>' : ''}<h3>対象と比較の注意</h3><p>${esc(stat.population_definition || stat.acquisition_scope || '')}</p><p>${recordNotes(stat.comparability_breaks).map(note => esc(note)).join('<br>')}</p><p>${recordNotes(stat.missing_periods).map(note => esc(note)).join('<br>')}</p><h3>出典</h3>${sourceHTML(entry.sourceId, `統計表 ${entry.tableId}`)}`;
}
function showSeries(id) {
  if (!series.has(id)) return; seriesDetail = id; seriesPage = 1;
  seriesYear = $('archive-dialog').open ? boundedYear($('archive-year').value, true) : null;
  detail(series.get(id).label, seriesDetailHTML());
}
function matchesYear(item, section, year) {
  if (year === null) return true;
  if (section === 'statistics') return archive.series.some(entry => entry.statId === item.id && entry.points.some(point => point.year === year));
  const start = section === 'events' ? item.date_start : section === 'sources' ? item.scope_start : item.period_start;
  const end = section === 'events' ? item.date_end : section === 'sources' ? item.scope_end : item.period_end;
  if (!start && !end) return false;
  const from = Number(String(start ?? end).slice(0, 4)), to = Number(String(end ?? start).slice(0, 4));
  return from <= year && to >= year;
}
function renderArchive() {
  const query = $('archive-search').value.trim().toLocaleLowerCase('ja'), year = boundedYear($('archive-year').value, true);
  if (year === undefined) { $('archive-count').textContent = '1900〜2026年の範囲で年を入力してください。'; $('archive-results').innerHTML = ''; return; }
  const fields = { statistics: ['title', 'geography', 'unit', 'notes', 'population_definition'], events: ['title', 'summary', 'geography'], living: ['title', 'what_it_shows', 'geography', 'whose_voice'], sources: ['title', 'institution', 'geography', 'perspective_limit'], gaps: ['description', 'finding', 'remaining_reason', 'geography'] }[archiveSection];
  const pool = archive[archiveSection].filter(item => (archiveSection !== 'gaps' || item.review_status !== 'resolved') && (!query || fields.some(field => String(item[field] || '').toLocaleLowerCase('ja').includes(query))) && matchesYear(item, archiveSection, year));
  $('archive-count').textContent = `${pool.length}件${year !== null ? ` ／ ${year}年` : ''}`;
  if (!pool.length) { $('archive-results').innerHTML = `<p class="observation-empty">この条件に合う記録はありません。${archiveSection === 'statistics' ? 'この年の数字を確認できていない場合もあります。' : ''}言葉や年の絞り込みを戻してみてください。</p>`; return; }
  $('archive-results').innerHTML = pool.slice(0, archiveLimit).map(item => {
    if (archiveSection === 'statistics') {
      const entries = archive.series.filter(entry => entry.statId === item.id), count = entries.reduce((n, entry) => n + entry.points.length, 0);
      const dated = entries.flatMap(entry => entry.points).map(point => point.year).filter(Number.isInteger);
      return `<article class="archive-result"><h3>${esc(item.title)}</h3><p>${esc(item.geography)} ／ ${entries.length}区分 ／ ${number.format(count)}観測</p><p>${dated.length ? `確認できた数字の時期：${Math.min(...dated)}–${Math.max(...dated)}年。` : '数字の時期を確かめきれていません。'}収録している区分と地域は、原表の一部です。</p><button type="button" data-series="${esc(entries[0].id)}">区分を選んで数字・欠測・出典を見る →</button></article>`;
    }
    if (archiveSection === 'events') return `<article class="archive-result"><span class="small">${esc(item.date_start)}${item.date_end ? `–${esc(item.date_end)}` : ''} ／ ${esc(item.geography)}</span><h3>${esc(item.title)}</h3><p>${esc(item.summary)}</p><button type="button" data-event="${esc(item.id)}">詳しい記録と出典 →</button><button type="button" data-jump="${esc(String(item.date_start).slice(0, 4))}">この年を眺める</button></article>`;
    if (archiveSection === 'living') return `<article class="archive-result"><span class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</span><h3>${esc(item.title)}</h3><p>${esc(item.what_it_shows)}</p><p>${esc(materialStatus(item))}</p><button type="button" data-living="${esc(item.id)}">誰の記録か、出典を読む →</button></article>`;
    if (archiveSection === 'sources') return `<article class="archive-result">${sourceHTML(item.id)}<p>${esc(period(item.scope_start, item.scope_end))} ／ ${esc(item.geography || '')}</p></article>`;
    return `<article class="archive-result"><span class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</span><h3>${esc(item.description)}</h3>${item.finding ? `<p>分かったこと：${esc(item.finding)}</p>` : ''}<p>まだ確かめきれていない理由：${esc(item.remaining_reason || item.next_action || 'この範囲は調査が済んでいません。')}</p>${(item.source_ids || []).map(id => sourceHTML(id)).join('')}</article>`;
  }).join('') + (pool.length > archiveLimit ? '<button type="button" id="more-archive" class="more-records">次の30件を表示</button>' : '');
}
function openArchive(section = 'statistics', year = '') {
  archiveSection = section; archiveLimit = 30; $('archive-year').value = year; $('archive-search').value = '';
  document.querySelectorAll('[data-section]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.section === section)));
  renderArchive(); openDialog($('archive-dialog')); $('archive-dialog').scrollTop = 0;
}
function jumpYear(year) {
  if (boundedYear(year) === undefined) { $('time-message').textContent = '1900〜2026年の範囲で年を入力してください。'; $('year-input').setAttribute('aria-invalid', 'true'); return; }
  $('year-input').removeAttribute('aria-invalid'); sim = seek(sim, Number(year), 1); accumulatedMonths = 0; lastHistoryIndex = 0; livingPage = 0; refresh();
  if (current.ended) setPlaying(false);
  $('time-message').textContent = `${current.year}年に移りました。${playing ? 'このまま時代が進みます。' : '「眺める」で時間が進みます。'}`;
}
function showAbout() {
  detail('時代は同じ。暮らしは、ひとつずつ。', '<p>1900年から2026年まで、日本の時代が自動で流れる箱庭です。何もしなくても、人々が歩き、風景が変わっていきます。</p><p>町を押して近づいたり、気になる人の暮らしを見守ったり。時間を止めて数字を読み、遠い年代へ移ってもかまいません。「別の暮らし」を押すと、同じ歴史の中に別の人々が生まれます。</p><h3>歴史と数字は、そのまま。</h3><p>政府統計はestatで取得した原値です。41表・14,083観測、177の出来事、85の生活史料を収めています。統計には対象・分類・欠測の違いがあり、年と年の間の数値は作っていません。</p><h3>小さな暮らしは、架空のもの。</h3><p>町の配置、人物の名前・家族・寿命・仕事・日常には、作者が決めた範囲の偶然があります。史実の被害や全国の数字から、一人の運命を決めるものではありません。風景の縮尺や年代ごとの建物・交通の形にも作者の想像を含みます。</p><p>統計のない量を描く場合は作者の模型として扱い、過去の観測を参考にした風景にはその観測年を示します。「当時の暮らしの記録」は実際の史料ですが、架空の人物の体験とは別のものです。</p><h3>いまの輪郭で、過去を眺める。</h3><p>日本列島はNatural Earthの地形を参考にしています。地図は1900年当時の政治的領域や、各統計の調査範囲を表していません。12の町の位置と暮らしは架空です。</p><p class="small">2026年10月16日までに確認した記録から。続きをこの端末に保存します。外部への送信やアカウント登録はありません。</p>');
}
function bindControls() {
  $('toggle-play').addEventListener('click', () => {
    if (current.ended) { sim = seek(sim, 1900, 1); refresh(true); setPlaying(true, '1900年から、もう一度眺めます。'); }
    else setPlaying(!playing, playing ? '時間を止めました。じっくり眺められます。' : '眺めているだけで、時代が進みます。');
  });
  $('speed').addEventListener('change', event => { speed = Number(event.target.value); save(); $('time-message').textContent = `${speed}倍の速さで時代を眺めます。`; });
  $('year-range').addEventListener('input', event => jumpYear(event.target.value));
  $('year-input').addEventListener('input', event => { if (/^\d{4}$/.test(event.target.value) && boundedYear(event.target.value) !== undefined) jumpYear(event.target.value); });
  $('year-input').addEventListener('change', event => jumpYear(event.target.value));
  $('year-input').addEventListener('keydown', event => { if (event.key === 'Enter') { jumpYear(event.target.value); event.target.blur(); } });
  $('place-select').addEventListener('change', event => setPlace(event.target.value));
  $('view-japan').addEventListener('click', () => setView('japan')); $('view-place').addEventListener('click', () => setView('place'));
  $('next-person').addEventListener('click', () => { const old = sim.personId; choosePerson(old); refresh(); });
  $('next-history').addEventListener('click', () => { lastHistoryIndex++; renderHistory(); });
  $('next-living').addEventListener('click', () => { livingPage += 3; renderLiving(); });
  $('reroll').addEventListener('click', () => {
    const values = new Uint32Array(1); crypto.getRandomValues(values); sim = reroll(sim, values[0] || 1); refresh(true);
    $('time-message').textContent = '歴史と統計は同じまま、別の人々の暮らしになりました。'; announce('別の人々の暮らしになりました。');
  });
  $('reduce-motion').addEventListener('change', event => { reducedMotion = event.target.checked; $('motion-note').textContent = reducedMotion ? '動きを抑えて表示しています。' : ''; dirty = true; save(); });
  $('open-archive').addEventListener('click', () => openArchive()); $('open-about').addEventListener('click', showAbout);
  $('more-history').addEventListener('click', () => openArchive('events', current.year)); $('more-living').addEventListener('click', () => openArchive('living'));
  $('detail-close').addEventListener('click', () => $('detail-dialog').close()); $('archive-close').addEventListener('click', () => $('archive-dialog').close());
  dialogs.forEach(dialog => dialog.addEventListener('close', dialogClosed));
  $('archive-search').addEventListener('input', () => { archiveLimit = 30; renderArchive(); });
  $('archive-year').addEventListener('input', () => { archiveLimit = 30; renderArchive(); });
  $('archive-clear').addEventListener('click', () => { $('archive-search').value = ''; $('archive-year').value = ''; archiveLimit = 30; renderArchive(); });
  document.addEventListener('change', event => { if (event.target.id === 'series-picker') { seriesDetail = event.target.value; seriesPage = 1; $('detail-title').textContent = series.get(seriesDetail).label; $('detail-body').innerHTML = seriesDetailHTML(); } });
  document.addEventListener('click', event => {
    const button = event.target.closest('button'); if (!button) return;
    if (button.dataset.driver) driverDetail(button.dataset.driver);
    if (button.dataset.vital) vitalDetail(button.dataset.vital);
    if (button.dataset.event) eventDetail(button.dataset.event);
    if (button.dataset.living) livingDetail(button.dataset.living);
    if (button.dataset.series) showSeries(button.dataset.series);
    if (button.dataset.person) { sim = selectPerson(sim, button.dataset.person); setView('place'); refresh(); }
    if (button.dataset.section) { archiveSection = button.dataset.section; archiveLimit = 30; document.querySelectorAll('[data-section]').forEach(tab => tab.setAttribute('aria-pressed', String(tab === button))); renderArchive(); }
    if (button.dataset.jump) { jumpYear(button.dataset.jump); dialogs.forEach(dialog => dialog.close()); }
    if (button.id === 'more-archive') { archiveLimit += 30; renderArchive(); }
    if (button.id === 'more-series') { seriesPage++; $('detail-body').innerHTML = seriesDetailHTML(); }
    if (button.id === 'show-all-series-years') { seriesYear = null; $('detail-body').innerHTML = seriesDetailHTML(); }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden && playing) setPlaying(false, '画面を離れたので、時間を止めました。「眺める」で続きます。'); });
  window.addEventListener('blur', () => { if (playing) setPlaying(false, '画面を離れたので、時間を止めました。「眺める」で続きます。'); });
  window.addEventListener('pagehide', save);
  new ResizeObserver(() => { renderer?.resize(); dirty = true; }).observe($('world-canvas'));
}
function frame(now) {
  const dt = Math.min(.1, (now - (lastFrame || now)) / 1000); lastFrame = now;
  if (playing) { accumulatedMonths += dt * 2 * speed; motionTime += dt; }
  if (playing && motionTime - lastCuration >= 10) { lastCuration = motionTime; lastHistoryIndex++; livingPage += 3; renderHistory(); renderLiving(); }
  if (playing && now - lastModel >= 200) {
    const previous = current.year * 12 + current.month;
    sim = advance(sim, accumulatedMonths); accumulatedMonths = 0; current = snapshot(sim); lastModel = now; dirty = true;
    if (previous !== current.year * 12 + current.month) { renderUI(); if (saveAvailable) save(); }
    if (current.ended) { playState(); $('time-message').textContent = '2026年10月、いまにつながりました。過去の年や、別の暮らしも眺められます。'; }
  }
  if (dirty || (playing && !reducedMotion)) {
    renderer.render(current, motionTime, { view, placeId: sim.placeId, selectedPersonId: sim.personId, reducedMotion }); dirty = false;
  }
  frameId = requestAnimationFrame(frame);
}
async function boot() {
  $('loading').hidden = false; $('load-error').hidden = true;
  try {
    const files = await Promise.all(['archive.json', 'drivers.json', 'japan.geo.json'].map(async file => {
      const response = await fetch(`./data/${file}`); if (!response.ok) throw new Error('読み込みが止まりました'); return response.json();
    }));
    [archive, drivers] = files;
    sources = new Map(archive.sources.map(source => [source.id, source])); statistics = new Map(archive.statistics.map(stat => [stat.id, stat])); series = new Map(archive.series.map(entry => [entry.id, entry]));
    let saved = null; try { saved = parseSaved(localStorage.getItem(STORAGE_KEY)); } catch { saveAvailable = false; }
    const values = new Uint32Array(1); crypto.getRandomValues(values);
    sim = createSimulation(archive, drivers, saved || { seed: values[0] || 1, year: 1900, month: 1 });
    if (saved?.personId) sim = selectPerson(sim, saved.personId);
    speed = saved?.speed || 1; reducedMotion = saved?.reducedMotion ?? reducedMotion; $('speed').value = speed; $('reduce-motion').checked = reducedMotion;
    $('motion-note').textContent = reducedMotion ? '動きを抑えて表示しています。' : '';
    $('place-select').innerHTML = PLACES.map(place => `<option value="${place.id}">${esc(place.region)} ／ ${esc(place.name)}</option>`).join('');
    renderer?.destroy();
    renderer = createRenderer($('world-canvas'), { geometry: files[2], onPlaceSelect: id => setPlace(id), onPersonSelect: id => { sim = selectPerson(sim, id); refresh(); }, onViewChange: setView });
    $('loading').hidden = true; $('app').hidden = false;
    refresh(!saved?.personId); renderer.resize();
    if (saved) $('time-message').textContent = '前に眺めていた暮らしの続きから始めます。';
    bindControls(); $('open-archive').disabled = false; $('open-about').disabled = false; if (!frameId) frameId = requestAnimationFrame(frame);
  } catch (error) { $('loading').hidden = true; $('load-error').hidden = false; $('app').hidden = true; console.error('箱庭をひらけませんでした。', error); }
}
$('retry').addEventListener('click', boot);
boot();
