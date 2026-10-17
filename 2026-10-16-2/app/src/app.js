import { PLACES, createSimulation, snapshot, seek, advance, reroll, selectPerson, selectPlace } from './model.js';
import { createRenderer } from './renderer.js';
import { STORAGE_KEY, parseSaved, serializeSaved, escapeHTML as esc, safeURL } from './storage.js';
import { observationTime, pointsThrough, materialStatus, recordNotes, readableResearchText, eraLabel, materialInYear, regionalMaterial, period } from './presentation.js';
import { createStatisticsExplorer, mountChart, presetTracks } from './charts.js';
import { routineAt, dayClockAt, DAILY_CYCLE_SECONDS } from './routines.js';
import { eraProfile } from './era-art.js';
import { mergeHistory, eventDateLabel, eventThemeIds, filterHistory, HISTORY_CHAPTERS, HISTORY_THEMES } from './history-data.js';

const $ = id => document.getElementById(id);
const number = new Intl.NumberFormat('ja-JP', { maximumFractionDigits: 3 });
const JOURNEYS = [
  {id:'teacher',year:1904,month:1,placeId:'sanyo',region:'広島',title:'教員家族の机',material:'L3-M008',prop:'book'},
  {id:'weaving',year:1911,month:2,placeId:'shikoku',region:'徳島',title:'織りの手仕事',material:'L3-M017',prop:'cloth'},
  {id:'fishing',year:1931,month:1,placeId:'shikoku',region:'愛媛',title:'海士の共同出漁',material:'L3-M012',prop:'net'},
  {id:'harbour',year:1934,month:7,placeId:'okinawa',region:'石垣島',title:'漁から戻る浜辺',material:'L3-M005',prop:'basket'},
  {id:'shopping',year:1937,month:2,placeId:'kanto',region:'小平',title:'覚帳の買物',material:'L3-M007',prop:'basket'},
  {id:'water',year:1943,month:8,placeId:'koshin',region:'北信濃',title:'通い帳と水汲み',material:'L3-M004',prop:'bucket'},
  {id:'fuel',year:1955,month:1,placeId:'kanto',region:'杉並',title:'家事と燃料の記憶',material:'L3-M006',prop:'tools'}
];
const TOPICS = {culture_leisure:'文化と余暇',disaster_environment:'災害と環境',economy_household:'家計',education:'教育',food_clothing:'衣食',health_welfare:'健康と福祉',housing_infrastructure:'住まいと設備',law_rights_politics:'制度と政治',media_technology:'通信と道具',population_family:'人口と家族',transport:'移動',war_empire:'戦争と歴史的な領域',work_industry:'仕事と産業'};
let archive, drivers, sim, current, renderer, sources, statistics, series;
let playing = true, speed = 4, view = 'place', reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let motionTime = 15, lastFrame = 0, lastModel = 0, lastRoutineFrame=0, accumulatedMonths = 0, frameId = 0, dirty = true;
let page = 'town', inspector='people', explorer, zoom = 1, lastRoutineStamp = '', lastPlanStamp = '', lastDailyStamp = '', historyLimit = 36, lastHistoricalDay = 0;
let archiveSection = 'statistics', seriesDetail = null, seriesPage = 1, seriesYear = null, detailResume = false, archiveLimit = 30;
let lastUIStamp = '', livingPage = 0, lastHistoryIndex = 0, lastCuration = 0, saveAvailable = true;
const dialogs = [$('detail-dialog'), $('archive-dialog')];

function announce(message) { $('announcement').textContent = message; }
function sourceHTML(id, locator = '') {
  const source = sources.get(id); if (!source) return '<p class="small">出典の詳しい情報がありません。</p>';
  const url = safeURL(source.url);
  return `<div class="source-entry">${url ? `<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">${esc(source.title)} ↗</a>` : `<strong>${esc(source.title)}</strong>`}<p>${esc(source.institution || '')}${source.checked_at ? ` ／ 確認日 ${esc(String(source.checked_at).slice(0, 10))}` : ''}</p>${locator ? `<p>参照箇所：${esc(readableResearchText(locator))}</p>` : ''}${source.perspective_limit ? `<p>${esc(readableResearchText(source.perspective_limit))}</p>` : ''}</div>`;
}
function formatValue(observation) {
  if (observation.value === null || !Number.isFinite(observation.value)) return '—';
  return number.format(observation.value);
}
function readableUnit(unit) { return /未取得|未確認|未確定/.test(unit || '') ? '単位は確認中' : unit || ''; }
function observationLabel(id, index = 0) {
  if (id === 'industry') return index ? '製造業の働き手' : current.year < 1953 ? '農業の有業者' : '農業・林業の就業者';
  if (id === 'population') return current.year < 1975 ? '人口動態の基礎人口' : '全国人口';
  if (id === 'education') return index ? current.year >= 2017 ? '大学の学部学生数' : '大学の在学者数' : '小学校の在学者数';
  if (id === 'communication') return index ? current.year >= 2010 ? 'スマートフォンの世帯保有率' : '携帯電話の世帯保有率' : 'パソコンの世帯保有率';
  return ({ housing: ['総住宅数', '空き家数'], water: ['上水道の給水人口'], rice: ['米の供給量／1人・1年'], prices: ['総合指数', '食料指数'], bus: ['乗合バス輸送人員／月次'], rail:['鉄道の旅客数量／月次'], energy:['年間エネルギー消費／1世帯'] })[id]?.[index] || '';
}
function pointDate(observation) {
  const label = observation.point?.timeLabel || observation.point?.time_label || 'この年代の記録はありません';
  return /^全国_.+_\d{4}$/.test(label) ? `${observation.point.year}年度` : label;
}
function sourceForEvent(event) { return (event.source_ids || []).map(id => sourceHTML(id, event.locator || event.source_locator)).join(''); }
function boundedYear(input, allowEmpty = false) {
  if (allowEmpty && input === '') return null;
  const value = Number(input);
  return Number.isInteger(value) && value >= 1900 && value <= 2026 ? value : undefined;
}
function choosePerson(excluded = null) {
  const local = current.world.placePeople?.[sim.placeId] || current.world.people.filter(person => person.placeId === sim.placeId);
  const preferred = local.filter(person => person.age >= 15 && person.age <= 65);
  const candidates = preferred.length ? preferred : local;
  if (candidates.length) { const index = candidates.findIndex(person => person.id === excluded); sim = selectPerson(sim, candidates[(index + 1) % candidates.length].id); current = snapshot(sim); }
}
function refresh(selectDefault = false) {
  current = snapshot(sim);
  if (selectDefault || !current.selectedPerson) choosePerson();
  else if (!current.selectedPerson.alive) {
    const next = current.selectedPerson.family?.filter(p=>p.alive&&p.age>=15).sort((a,b)=>Math.abs(a.age-35)-Math.abs(b.age-35))[0];
    if(next){sim=selectPerson(sim,next.id);current=snapshot(sim);}else choosePerson();
  }
  dirty = true; renderUI(true); save();
}
function setPage(next) {
  if(!current)return;
  page = next;
  $('playback').hidden=next==='about';
  if(next!=='town'&&playing)setPlaying(false,'時間を止めて、時代の記録をたどっています。');
  document.querySelectorAll('[data-workspace]').forEach(section=>{section.hidden=section.dataset.workspace!==next;});
  document.querySelectorAll('[data-page]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.page===next)));
  if(next==='statistics')explorer?.syncYear(current.year);
  if(next==='history')renderChronicle();
  if(next==='town'){renderer?.resize();dirty=true;}
  window.scrollTo({top:0,behavior:reducedMotion?'instant':'smooth'});
}
function setInspector(next){
  inspector=next;
  document.querySelector('.person-panel').hidden=next!=='people';document.querySelector('.residents-panel').hidden=next!=='people';document.querySelector('.history-panel').hidden=next!=='history';
  document.querySelectorAll('[data-inspector]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.inspector===next)));
}
function save() {
  try {
    localStorage.setItem(STORAGE_KEY, serializeSaved(current, { placeId: sim.placeId, personId: sim.personId, speed, reducedMotion,clockSeconds:motionTime,zoom }));
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
  if(current)save();
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
  const seed=[...person.id].reduce((n,c)=>Math.imul(n^c.charCodeAt(0),16777619)>>>0,2166136261),elder=person.age>=65,child=person.age<15;
  const color = ['#8d584c', '#627e67', '#647783', '#b99a59','#89729b','#527d80'][seed%6],hair=elder?'#b3b1a3':'#3f3c33';
  return `<svg class="person-portrait" viewBox="0 0 62 72" aria-hidden="true"><path d="M9 72V55q22-18 44 0v17" fill="${color}"/><path d="M26 42v12h10V42" fill="#d9b78e"/><ellipse cx="31" cy="29" rx="${child?14:15}" ry="${child?17:19}" fill="#e9c89d"/><path d="${seed%3===0?'M16 30Q9 8 31 6q24 1 15 26l-6-17-18 5z':seed%3===1?'M16 29q-3-23 15-23 20 0 15 25l-5-15-19 3z':'M16 27q-2-21 15-21 19 1 15 23l-9-15-18 5z'}" fill="${hair}"/><circle cx="25" cy="29" r="1.2" fill="#3f3c33"/><circle cx="37" cy="29" r="1.2" fill="#3f3c33"/>${seed%4===0?'<path d="M19 26h11v8H19zm13 0h11v8H32zM30 29h2" stroke="#605d50" fill="none" stroke-width="1"/>':''}<path d="M27 38q4 ${person.personality==='話好き'?5:2} 8 0" fill="none" stroke="#a36b59" stroke-width="1.5"/>${elder?'<path d="m19 35 3 1m18-1 3-1" stroke="#b38f74" stroke-width=".8"/>':''}${current.year<1945?'<path d="m20 50 10 20 12-20m-23 13h24" stroke="#d2bf9b" fill="none" stroke-width="2"/>':'<path d="m23 50 8 9 8-9" stroke="#d8dbc9" fill="none" stroke-width="2"/>'}</svg>`;
}
function propIcon(prop = 'basket') {
  const paths = {
    bucket:'<path d="M9 15h22l-3 17H12z"/><path d="M12 15v-4a8 8 0 0 1 16 0v4"/>',
    basket:'<path d="M6 17h28l-4 15H10z"/><path d="m11 17 6-11m12 11L23 6M15 21v7m5-7v7m5-7v7"/>',
    net:'<path d="m7 9 26 5-7 18-19-8zM12 10l-2 16m8-15-4 18m10-17-5 18m11-17-7 18M8 16l22 5M8 21l19 5"/>',
    cloth:'<path d="M9 7h22v26H9zM13 7v26m6-26v26m6-26v26M9 14h22M9 22h22M9 29h22"/>',
    letter:'<path d="M5 11h30v21H5zM5 11l15 13 15-13"/>',
    book:'<path d="M20 10q-8-6-15-2v23q8-3 15 2 7-5 15-2V8q-7-4-15 2v23M9 15l7 1m8 0 7-1M9 21l7 1m8 0 7-1"/>',
    tools:'<path d="m10 31 18-23m-9 1 10 8M7 29l5 4M9 8v15m-4-9h8"/>',
    food:'<path d="M6 20h28q-2 13-14 13T6 20M9 16q2-7 6-2 3-9 7-2 5-5 8 4"/>',
    phone:'<rect x="12" y="4" width="17" height="31" rx="3"/><path d="M16 9h9m-9 19h9"/>',
    tablet:'<rect x="6" y="7" width="28" height="24" rx="2"/><path d="M10 11h20v15H10zm7 23h6"/>',
    bicycle:'<circle cx="10" cy="28" r="7"/><circle cx="31" cy="28" r="7"/><path d="m10 28 8-14 7 14H10m8-14h10l3 14M14 12h8m5-3h6"/>',
    broom:'<path d="m26 5-9 20m-5-2 10 4-3 9-12-5zM12 26l-3 6m7-5-3 6m7-5-3 6"/>',
    ball:'<circle cx="20" cy="20" r="14"/><path d="m20 11 8 6-3 10H15l-3-10zM20 6v5m14 4-6 2m-3 10 4 5m-14-5-4 5m1-15-6-2"/>',
    briefcase:'<rect x="6" y="13" width="28" height="21" rx="2"/><path d="M14 13V7h12v6M6 22h28m-16-3h4v6h-4"/>',
    camera:'<path d="M5 13h8l3-5h10l3 5h6v20H5z"/><circle cx="21" cy="23" r="7"/><path d="M8 17h4"/>',
    radio:'<rect x="5" y="13" width="30" height="20" rx="2"/><path d="m10 13 20-9M9 18h16m-16 4h16m-16 4h16"/><circle cx="30" cy="24" r="2"/>',
    umbrella:'<path d="M5 20a15 15 0 0 1 30 0q-5-4-10 0-5-4-10 0-5-4-10 0m15-14v27q0 5-5 1M15 20q-1-9 5-14 6 5 5 14"/>',
    sewing:'<path d="m7 33 24-26m-6-2 8 8m-1-1q6-10-3-7M7 33q2-15 8-5t13 0"/>',
    kettle:'<path d="M11 16h20l2 17H9zm3 0q-2-15 13 0M11 22l-8-5v11l7 2m21-8 6-6v9l-5 4"/>',
    cart:'<path d="M5 9h5l5 21h18M12 15h24l-3 11H14"/><circle cx="17" cy="33" r="2"/><circle cx="30" cy="33" r="2"/>'
  };
  return `<svg class="prop-icon" viewBox="0 0 40 40" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${paths[prop] || paths.basket}</svg>`;
}
function renderPerson() {
  const person = current.selectedPerson;
  if (!person) { $('person-content').innerHTML = '<p class="observation-empty">この町を歩く人を、まだ見つけられませんでした。別の場所ものぞいてみてください。</p>'; return; }
  const unborn = person.birthYear > current.year;
  const aliveLabel = unborn ? 'まだ生まれていません' : person.alive ? `${person.age}歳 ／ ${person.birthYear}年生まれ` : `${person.birthYear}–${person.deathYear}年の暮らし`;
  const family = person.family?.filter(member => member.generation > person.generation&&member.alive) || [];
  const inspired = person.scene?.sourceMaterialIds?.length;
  $('person-content').innerHTML = `<div class="person-intro">${portrait(person)}<div><p class="person-name">${esc(person.name)}</p><p class="person-age">${esc(aliveLabel)}</p><span class="fiction-tag">${esc(person.occupation || '')}${person.personality ? ` ／ ${esc(person.personality)}` : ''}</span></div></div><div id="routine-now" class="person-scene"></div><p id="routine-description" class="routine-description"></p><div class="routine-progress"><span id="routine-progress-bar"></span></div><p class="routine-next" id="routine-next"></p><div id="routine-plan" class="routine-plan"></div><details class="day-agenda"><summary>今日の予定をひらく</summary><ol id="day-agenda-list"></ol></details>${person.alive ? `<button type="button" class="inline-link scene-origin" data-scene="${esc(person.id)}">${inspired ? 'この日常に着想をくれた記録 ↗' : '一日と、この人の記録 ↗'}</button>` : ''}<details class="person-journal"><summary>これまでの暮らし${person.hobby ? ` ／ 楽しみは${esc(person.hobby)}`:''}</summary><ol class="life-journal">${person.lifeEvents.slice(-8).map(event => `<li><span>${event.year}</span><span>${esc(event.text)}</span></li>`).join('')}</ol></details>${family.length ? `<button type="button" class="follow-family" data-person="${esc(family[0].id)}">家族の${esc(family[0].name)}を見守る →</button>` : ''}`;
  lastRoutineStamp='';lastPlanStamp='';renderRoutineUI();
  const residents=current.world.placePeople?.[sim.placeId] || current.world.people.filter(p=>p.placeId===sim.placeId);
  $('resident-count').textContent=`${residents.length}人`;
  $('resident-list').innerHTML=residents.map(p=>`<button type="button" data-person="${esc(p.id)}" aria-pressed="${p.id===person.id}"><strong>${esc(p.name)}</strong><span>${p.age}歳 ／ ${esc(p.occupation||'町の住民')}</span></button>`).join('');
}
function renderRoutineUI() {
  const p=current?.selectedPerson;if(!p)return;
  const runtime=routineAt(p,motionTime),clock=dayClockAt(motionTime);
  const stamp=`${p.id}-${runtime.stageIndex}-${clock.dayIndex}-${Math.floor(motionTime)}`;
  if(stamp===lastRoutineStamp)return;lastRoutineStamp=stamp;
  $('day-clock').textContent=clock.timeLabel;
  if(document.activeElement!==$('day-range'))$('day-range').value=Math.floor(motionTime%DAILY_CYCLE_SECONDS);
  if(!$('routine-now'))return;
  $('routine-now').innerHTML=`${propIcon(runtime.scene?.prop)}<p class="person-activity">${esc(runtime.activity||p.activity)}</p>`;
  $('routine-description').textContent=runtime.scene?.text||'';
  $('routine-next').innerHTML=runtime.companions?.length?`いっしょに：${runtime.companions.map(q=>`<button type="button" class="inline-link" data-person="${esc(q.id)}">${esc(q.name)}</button>`).join('、')}`:esc(runtime.nextStage?`このあと：${runtime.nextStage.scene.activity}`:'');
  $('routine-progress-bar').style.width=`${Math.round((runtime.progress||0)*100)}%`;
  const stages=runtime.sceneStages||[],places={home:'家',farm:'畑',workshop:'工房',shop:'店',office:'仕事場',school:'学校',factory:'工場',post:'郵便',water:'井戸',square:'広場',coast:'浜',river:'川',path:'道',clinic:'診療所',meeting:'待ち合わせ'};
  const phaseLabels={morning:'朝',work:p.role==='student'?'学び':'仕事',midday:'昼',errand:'用事',hobby:'楽しみ',social:'交流',evening:'帰宅',night:'夜'};
  const shown=stages.filter((s,i)=>s.scene.pose!=='walk'&&!stages.slice(0,i).some(before=>before.scene.pose!=='walk'&&before.phase===s.phase));
  const planStamp=`${p.id}-${current.year}-${current.month}-${clock.dayIndex}`;
  if(lastPlanStamp!==planStamp){lastPlanStamp=planStamp;$('routine-plan').innerHTML=shown.map(s=>`<button type="button" data-day-time="${(s.startsAt+s.endsAt)/2}" data-day-phase="${s.phase}" title="${esc(s.scene.activity)}">${esc(phaseLabels[s.phase]||places[s.scene.destinationKind]||'町')}</button>`).join('');$('day-agenda-list').innerHTML=stages.filter(s=>s.scene.pose!=='walk').map(s=>`<li><time>${dayClockAt(s.startsAt).timeLabel}</time><button type="button" data-day-time="${(s.startsAt+s.endsAt)/2}">${esc(s.scene.activity)}</button></li>`).join('');}
  $('routine-plan').querySelectorAll('[data-day-phase]').forEach(b=>{b.className=b.dataset.dayPhase===runtime.stage?.phase?'active':Number(b.dataset.dayTime)<clock.phase*DAILY_CYCLE_SECONDS?'past':'';b.setAttribute('aria-pressed',String(b.dataset.dayPhase===runtime.stage?.phase));});
  renderDaily();
}
function renderDaily() {
  const stories = (current.world.localStories || []).filter(story => story.placeId === sim.placeId).slice(0, 2);
  const fallback = current.selectedPerson?.alive ? [{...current.selectedPerson.dailyEvent, personId:current.selectedPerson.id, title:current.selectedPerson.name, sourceMaterialIds:[]}] : [];
  const local=current.world.placePeople?.[sim.placeId]||current.world.people.filter(p=>p.placeId===sim.placeId);
  const watched=[current.selectedPerson,...local.filter(p=>p.id!==sim.personId&&p.profession!==current.selectedPerson?.profession)].filter(Boolean).slice(0,3);
  const activeStories=watched.map(p=>({...routineAt(p,motionTime).scene,personId:p.id}));
  const dailyStamp=JSON.stringify([sim.seed,current.year,current.month,activeStories.map(s=>[s.personId,s.id])]);
  if(lastDailyStamp!==dailyStamp){lastDailyStamp=dailyStamp;
  $('daily-stories').innerHTML = (activeStories.length ? activeStories : stories.length ? stories : fallback).map(story => {
    const person = local.find(item => item.id === story.personId) || current.selectedPerson;
    const material = story.sourceMaterialIds?.find(id => archive.living.some(item => item.id === id));
    return `<article class="daily-story"><button type="button" class="daily-person" data-person="${esc(story.personId)}">${propIcon(story.prop)}<span><strong>${esc(story.activity || '町で過ごす')}</strong><span>${esc(person?.name || story.title || '')}の一日を見守る →</span></span></button>${material ? `<button type="button" class="daily-source" data-living="${esc(material)}">着想の記録 ↗</button>` : ''}</article>`;
  }).join('') || '<p class="observation-empty">この町の暮らしを、ゆっくり眺めてみましょう。</p>';}
  const atmosphere = current.selectedPlace.atmosphere;
  $('season-stamp').hidden = view !== 'place';
  $('season-stamp').textContent = atmosphere ? `${atmosphere.seasonLabel || ''} ／ ${{sunny:'晴れ間',cloudy:'くもり空',rain:'雨模様',snow:'雪景色'}[atmosphere.weather] || ''}` : '';
  document.querySelectorAll('[data-journey]').forEach(button => {
    const stop = JOURNEYS.find(item => item.id === button.dataset.journey);
    button.setAttribute('aria-pressed', String(stop.year === current.year && stop.placeId === sim.placeId && stop.month === current.month));
  });
}
function journeyTo(id) {
  const stop = JOURNEYS.find(item => item.id === id); if (!stop) return;
  sim = seek(selectPlace(sim, stop.placeId), stop.year, stop.month); current = snapshot(sim);
  const person = (current.world.placePeople?.[stop.placeId]||current.world.people).find(item => item.placeId === stop.placeId && item.scene?.sourceMaterialIds?.includes(stop.material));
  if (person) {sim = selectPerson(sim, person.id);const stage=person.routine?.days[0]?.find(s=>s.scene.sourceMaterialIds?.includes(stop.material));motionTime=stage?(stage.startsAt+stage.endsAt)/2:15;lastHistoricalDay=0;} else choosePerson();
  livingPage = 0; accumulatedMonths = 0; lastHistoryIndex = 0;
  setView('place'); refresh(); setPlaying(false, `${stop.year}年の${stop.region}に残る記録から。時間を止めています。「眺める」で続きます。`);
  announce(`${stop.year}年${stop.month}月、${stop.title}の風景に移りました。`);
}
function sceneDetail(id) {
  const person = current.world.placePeople?.[sim.placeId]?.find(item => item.id === id) || current.world.people.find(item => item.id === id) || current.selectedPerson;
  if (!person || person.id !== id) return;
  const scene = routineAt(person,motionTime).scene || person.scene || person.dailyEvent;
  const materials = [...new Set([...(scene?.sourceMaterialIds||[]),...(person.routine?.sourceMaterialIds||[])])].map(key => archive.living.find(item => item.id === key)).filter(Boolean);
  detail(`${person.name}の小さな一日`, `<div class="scene-detail-heading">${propIcon(scene?.prop)}<div><p class="small">${current.year}年${current.month}月 ／ ${esc(current.selectedPlace.name)}</p><h3>${esc(scene?.activity||person.activity)}</h3></div></div><p>${esc(scene?.text || person.dailyEvent?.text || 'いつもの町で、一日を過ごしています。')}</p>${materials.length ? '<h3>ゆかりの記録</h3>' + materials.map(item => `<article class="inspiration-record"><p class="small">${esc(period(item.period_start,item.period_end))} ／ ${esc(item.geography)}</p><h3>${esc(item.title)}</h3><p>${esc(item.what_it_shows)}</p><button type="button" class="inline-link" data-living="${esc(item.id)}">出典・詳細 ↗</button></article>`).join('') : ''}`);
}

function currentHistory() {
  const exact = archive.events.filter(event => String(event.date_start).slice(0, 4) === String(current.year));
  const pool = exact.length ? exact.sort((a, b) => String(b.date_start).localeCompare(String(a.date_start))) : current.events;
  return pool.length ? pool[lastHistoryIndex % pool.length] : null;
}
function renderHistory() {
  const event = currentHistory();
  $('history-year').textContent = event ? String(event.date_start).slice(0, 4) : '';
  if (!event) { $('history-content').innerHTML = '<p class="observation-empty">この時点までに日付を確かめられた出来事はありません。これから届く時代の便りを待ちましょう。</p>'; return; }
  const nearby=archive.events.filter(e=>Number(String(e.date_start).slice(0,4))===current.year);
  $('year-event-count').textContent=nearby.length;
  $('history-content').innerHTML = `<p class="history-kicker">${esc(eventDateLabel(event))} ${esc(event.geography || '')}</p><h3 class="history-title">${esc(event.title)}</h3><p class="history-summary">${esc(event.summary)}</p><button type="button" class="inline-link" data-event="${esc(event.id)}">出典と詳しい記録 ↗</button>${nearby.length>1?`<p class="history-count">この年には${nearby.length}件の出来事。<button type="button" class="inline-link" data-history-year="${current.year}">まとめて読む →</button></p>`:''}`;
}
function renderChronicle() {
  const query=$('history-search').value.trim(),theme=$('history-theme').value,region=$('history-region').value;
  const from=boundedYear($('history-from').value),through=boundedYear($('history-through').value);
  if(from===undefined||through===undefined||from>through){$('history-result-count').textContent='1900〜2026年の範囲で、最初と最後の年を選んでください。';$('history-results').innerHTML='';$('history-more').hidden=true;return;}
  const events=filterHistory(archive.events,{query,theme,region,from,through});
  $('history-result-count').textContent=`${events.length}件 ／ ${from}–${through}年`;
  let lastYear=null;
  $('history-results').innerHTML=events.slice(0,historyLimit).map(event=>{
    const year=Number(String(event.date_start).slice(0,4)),heading=year!==lastYear?`<div class="chronicle-year"><strong>${year}</strong><span>${esc(eraLabel(year,1))}</span><button type="button" data-jump="${year}">この年の町へ ↗</button></div>`:'';lastYear=year;
    const topic=eventThemeIds(event).map(id=>HISTORY_THEMES.find(t=>t.id===id)?.label||TOPICS[id]).filter(Boolean).slice(0,2);
    return `${heading}<article class="chronicle-event"><div class="chronicle-meta"><span>${esc(eventDateLabel(event))}</span><span>${esc(event.geography||'')}</span>${topic.map(label=>`<span class="theme-label">${esc(label)}</span>`).join('')}</div><h3><button type="button" data-event="${esc(event.id)}">${esc(event.title)}</button></h3><p>${esc(event.summary)}</p><div class="chronicle-actions"><button type="button" class="inline-link" data-event="${esc(event.id)}">出典をたどる ↗</button><button type="button" class="inline-link" data-jump="${year}">この時代を眺める →</button></div></article>`;
  }).join('')||'<p class="observation-empty">この条件の記録はありません。言葉や年代を変えて探せます。</p>';
  $('history-more').hidden=events.length<=historyLimit;
}
function historyAround(year) {
  $('history-from').value=Math.max(1900,Number(year)-2);$('history-through').value=Math.min(2026,Number(year)+2);historyLimit=36;setPage('history');
}
function setupChronicle() {
  $('history-total').textContent=`${archive.events.length}の出来事、${archive.living.length}の暮らしの記録`;
  $('history-theme').innerHTML='<option value="">すべて</option>'+HISTORY_THEMES.map(t=>`<option value="${esc(t.id)}">${esc(t.label)}</option>`).join('');
  $('history-region').innerHTML='<option value="">全国・各地</option>'+PLACES.map(p=>`<option value="${p.id}">${esc(p.region)}</option>`).join('');
  $('history-chapters').innerHTML=HISTORY_CHAPTERS.map(c=>`<button type="button" data-history-range="${c.from},${c.through}"><span>${c.from}–${c.through}</span><strong>${esc(c.title||c.label)}</strong></button>`).join('');
  const counts=Array.from({length:127},(_,i)=>archive.events.filter(e=>Number(String(e.date_start).slice(0,4))===1900+i).length),max=Math.max(...counts,1);
  $('history-density').innerHTML=counts.map((n,i)=>`<button type="button" data-history-year="${1900+i}" title="${1900+i}年：${n}件" aria-label="${1900+i}年の前後を読む、${n}件"><i data-density-height="${Math.max(3,n/max*55)}"></i>${i%10===0?`<span>${1900+i}</span>`:''}</button>`).join('');
  $('history-density').querySelectorAll('[data-density-height]').forEach(i=>i.style.height=`${i.dataset.densityHeight}px`);
  renderChronicle();
}
function sparkline(observation) {
  const points = pointsThrough(observation.series, current.year, current.month).filter(point => observation.segment === null || point.year >= observation.segment);
  if (points.length < 2) return '';
  const values = points.map(point => point.value), min = Math.min(...values), max = Math.max(...values), first = observationTime(points[0]), span = Math.max(1, observationTime(points.at(-1)) - first);
  return `<svg class="sparkline" viewBox="0 0 90 24" aria-hidden="true">${points.map(point => `<circle cx="${((observationTime(point) - first) / span * 88 + 1).toFixed(1)}" cy="${(20 - (point.value - min) / Math.max(1, max - min) * 17).toFixed(1)}" r="1.1" fill="#56715b"/>`).join('')}</svg>`;
}
function renderMacro() {
  $('macro-grid').innerHTML = drivers.drivers.flatMap(driver => {
    const signal = current.macro[driver.id];
    if(signal.status === 'unavailable' || !Number.isFinite(signal.value))return [];
    const unit=/未取得|未確認|未確定/.test(signal.unit||'')?'':signal.unit||'';
    return [`<button type="button" class="macro-card" data-driver="${driver.id}"><span class="metric-label">${esc(driver.label)}<span aria-hidden="true">↗</span></span><span class="metric-context">${esc(observationLabel(driver.id))}</span><span class="metric-value">${formatValue(signal)}<small>${esc(unit)}</small></span><span class="metric-date">${esc(pointDate(signal))}</span>${sparkline(signal)}</button>`];
  }).join('');
}
function renderLiving() {
  const entries = current.living;
  document.querySelector('.living-section').hidden=!entries.length;
  if (!entries.length) { $('living-content').innerHTML = ''; return; }
  const regional = entries.filter(item => regionalMaterial(item, sim.placeId)).sort((a,b)=>Number(b.id.startsWith('L3-'))-Number(a.id.startsWith('L3-')));
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
  $('year-label').textContent = current.year; $('era-label').textContent = eraLabel(current.year, current.month); $('month-label').textContent = current.month;
  $('era-note').textContent=eraProfile(current.year).label;
  if (document.activeElement !== $('year-input')) $('year-input').value = current.year;
  $('year-range').value = current.year; $('place-select').value = sim.placeId;
  $('season-select').value=[1,4,7,10][Math.floor((current.month-1)/3)];
  $('scene-caption').textContent = view === 'japan' ? '町を押すと、近づいて眺められます。' : `${current.selectedPlace.region} ／ ${current.selectedPlace.name}。人を押すと暮らしを追えます。`;
  $('world-canvas').setAttribute('aria-label', `${current.year}年${current.month}月の${view === 'japan' ? '日本の全景' : current.selectedPlace.name}。場所と人は画面右の操作でも選べます。`);
  $('vital-records').innerHTML = [['00110', '出生数'], ['00150', '死亡数']].map(([code, label]) => {
    const entry = archive.series.find(item => item.id === `SD-STAT001:cat01=${code}`), point = entry.points.find(item => item.year === current.year);
    if(point?.kind!=='number')return '';
    return `<button type="button" data-vital="${code}"><span>${current.year}年の記録 ／ ${label}</span><strong>${point?.kind === 'number' ? `${number.format(point.value)}<small>人</small>` : '記録なし'}</strong><span class="vital-source">出典・詳細 ↗</span></button>`;
  }).join('');
  renderPerson(); renderDaily(); renderHistory(); renderMacro(); renderLiving(); playState();
  explorer?.syncYear(current.year);
  const era=eraProfile(current.year);document.querySelectorAll('[data-era-year]').forEach(b=>b.setAttribute('aria-pressed',String(eraProfile(Number(b.dataset.eraYear)).id===era.id)));
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
  mountInlineCharts();
}
function eventDetail(id) {
  const event = archive.events.find(item => item.id === id); if (!event) return;
  detail(event.title, `<p class="small">${esc(event.date_start)}${event.date_end ? ` — ${esc(event.date_end)}` : ''} ／ ${esc(event.geography || '')}</p><p>${esc(event.summary)}</p>${event.qualification ? `<div class="detail-note"><p>${esc(event.qualification)}</p></div>` : ''}<h3>出典</h3>${sourceForEvent(event)}`);
}
function vitalDetail(code) {
  const entry = series.get(`SD-STAT001:cat01=${code}`), point = entry.points.find(item => item.year === current.year), stat = statistics.get(entry.statId);
  detail(`${current.year}年の${entry.label}`, `${point?.kind === 'number' ? `<p class="detail-value">${number.format(point.value)} <small>人</small></p>` : '<p class="missing-note">この年の数字はありません。1944〜1946年は、戦災などによる資料の不備で原表から省略されています。最新の収録年は2024年です。</p>'}<div class="detail-note"><p>歴史的な領域・国籍・届出の範囲に違いがあり、全期間を同じ集団として比較できるとは限りません。1947〜1972年は沖縄県を含みません。詳しい対象の変遷には確認が残っています。</p></div>${chartHTML({series:entry,point})}<button type="button" data-series="${esc(entry.id)}">原表の年・数字・欠測を見る →</button>${sourceHTML(entry.sourceId, `統計表 ${entry.tableId}`)}`);
}
function livingDetail(id) {
  const item = archive.living.find(record => record.id === id); if (!item) return;
  detail(item.title, `<p class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</p><div class="detail-note"><p>${esc(materialStatus(item))}</p></div><p>${esc(item.what_it_shows)}</p><dl class="detail-dl"><dt>記録の形</dt><dd>${esc(item.material_type)}</dd><dt>誰の経験か</dt><dd>${esc(item.whose_voice)}</dd></dl><div class="detail-note"><p>${esc(item.representativeness_limit || 'この記録を全国の人々の平均としては扱えません。')}</p></div><h3>出典</h3>${sourceHTML(item.source_id, item.item_locator)}<p class="small"></p>`);
}
function chartHTML(observation) { return `<div class="inline-chart" data-inline-chart="${esc(observation.series.id)}"></div>`; }
function mountInlineCharts() {
  $('detail-body').querySelectorAll('[data-inline-chart]').forEach(root=>mountChart(root,presetTracks(archive,drivers,root.dataset.inlineChart),{year:current.year,onYear:year=>{detailResume=false;dialogs.forEach(d=>d.close());jumpYear(year);setPlaying(false);setPage('town');},onSeries:id=>showSeries(id)}));
}
function driverDetail(id) {
  if (!drivers.drivers.some(driver=>driver.id===id)) return;
  explorer?.select(id);setPage('statistics');
}
function seriesDetailHTML() {
  const entry = series.get(seriesDetail), stat = statistics.get(entry.statId), year = seriesYear;
  const all = entry.points.filter(point => year === null || year === undefined || point.year === year);
  const points = all.slice(0, seriesPage * 100);
  const peers = archive.series.filter(item => item.statId === entry.statId);
  return `<p class="small">${esc(stat.title)} ／ ${esc(entry.geography || '')}</p><label class="small" for="series-picker">同じ表の区分</label><select id="series-picker" class="series-select">${peers.map(item => `<option value="${esc(item.id)}"${item.id === entry.id ? ' selected' : ''}>${esc(item.label)}</option>`).join('')}</select>${chartHTML({series:entry})}<p>単位：${esc(readableUnit(entry.unit) || '原表を参照')}。原表の時間の表記と欠測記号をそのまま示しています。</p>${year !== null && year !== undefined && !all.length ? `<p class="missing-note">${year}年の観測は、この区分にはありません。0ではありません。</p><button type="button" id="show-all-series-years">すべての年の記録を見る</button>` : ''}<div class="record-table-wrap"><table class="record-table"><thead><tr><th scope="col">原表の時期</th><th scope="col">値</th><th scope="col">単位</th><th scope="col">記録の状態</th></tr></thead><tbody>${points.map(point => `<tr><td>${esc(point.timeLabel || point.time_label || '時期を確かめきれていません')}</td><td>${esc(point.raw)}</td><td>${esc(readableUnit(point.unit || entry.unit))}</td><td>${point.kind === 'number' ? '数値' : `原表の記号${point.value_note ? `：${esc(point.value_note)}` : '（0ではありません）'}`}</td></tr>`).join('')}</tbody></table></div><p class="small">${points.length} / ${all.length}件表示</p>${all.length > points.length ? '<button id="more-series" type="button" class="more-records">次の100件を表示</button>' : ''}<h3>対象と比較の注意</h3><p>${esc(readableResearchText(stat.population_definition || stat.acquisition_scope || ''))}</p><p>${[...new Set(recordNotes(stat.comparability_breaks))].map(note => esc(readableResearchText(note))).join('<br>')}</p><p>${[...new Set(recordNotes(stat.missing_periods))].map(note => esc(readableResearchText(note))).join('<br>')}</p><h3>出典</h3>${sourceHTML(entry.sourceId, `統計表 ${entry.tableId}`)}`;
}
function showSeries(id) {
  if (!series.has(id)) return; seriesDetail = id; seriesPage = 1;
  seriesYear = $('archive-dialog').open ? boundedYear($('archive-year').value, true) : null;
  detail(series.get(id).label, seriesDetailHTML());
}
function matchesYear(item, section, year) {
  if (year === null) return true;
  if (section === 'living') return materialInYear(item, year);
  if (section === 'statistics') return archive.series.some(entry => entry.statId === item.id && entry.points.some(point => point.year === year));
  const start = section === 'events' ? item.date_start : section === 'sources' ? item.scope_start : item.period_start;
  const end = section === 'events' ? item.date_end : section === 'sources' ? item.scope_end : item.period_end;
  if (!start && !end) return false;
  const from = Number(String(start ?? end).slice(0, 4)), to = Number(String(end ?? start).slice(0, 4));
  return from <= year && to >= year;
}
function relatedSources(item) {
  const ids = new Set(item.source_ids || []);
  for (const id of item.related_ids || []) {
    if (sources.has(id)) ids.add(id);
    const record = statistics.get(id) || archive.living.find(entry => entry.id === id) || archive.events.find(entry => entry.id === id);
    if (record?.source_id) ids.add(record.source_id);
    for (const sourceId of record?.source_ids || []) ids.add(sourceId);
  }
  return [...ids];
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
      return `<article class="archive-result"><h3>${esc(item.title)}</h3><p>${esc(item.geography)} ／ ${entries.length}区分 ／ ${number.format(count)}観測</p><p>${dated.length ? `確認できた数字の時期：${Math.min(...dated)}–${Math.max(...dated)}年。` : '数字の時期を確かめきれていません。'}</p><button type="button" data-series="${esc(entries[0].id)}">区分を選んで数字・欠測・出典を見る →</button></article>`;
    }
    if (archiveSection === 'events') return `<article class="archive-result"><span class="small">${esc(item.date_start)}${item.date_end ? `–${esc(item.date_end)}` : ''} ／ ${esc(item.geography)}</span><h3>${esc(item.title)}</h3><p>${esc(item.summary)}</p><button type="button" data-event="${esc(item.id)}">詳しい記録と出典 →</button><button type="button" data-jump="${esc(String(item.date_start).slice(0, 4))}">この年を眺める</button></article>`;
    if (archiveSection === 'living') return `<article class="archive-result"><span class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</span><h3>${esc(item.title)}</h3><p>${esc(item.what_it_shows)}</p><p>${esc(materialStatus(item))}</p><button type="button" data-living="${esc(item.id)}">誰の記録か、出典を読む →</button></article>`;
    if (archiveSection === 'sources') return `<article class="archive-result">${sourceHTML(item.id)}<p>${esc(period(item.scope_start, item.scope_end))} ／ ${esc(item.geography || '')}</p></article>`;
    const remaining = item.remaining_reason || item.description || item.next_action || 'この範囲は調査が済んでいません。';
    const heading = (item.topic_ids || []).slice(0, 2).map(id => TOPICS[id]).filter(Boolean).join('・') || '歴史と暮らし';
    return `<article class="archive-result"><span class="small">${esc(period(item.period_start, item.period_end))} ／ ${esc(item.geography)}</span><h3>${esc(heading)}に残る確認</h3>${item.finding && item.finding !== remaining ? `<p>分かったこと：${esc(readableResearchText(item.finding))}</p>` : ''}<p>まだ確かめきれていない理由：${esc(readableResearchText(remaining))}</p>${relatedSources(item).map(id => sourceHTML(id)).join('')}</article>`;
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
  if(page==='statistics')explorer?.syncYear(current.year);
  $('time-message').textContent = `${current.year}年に移りました。${playing ? 'このまま時代が進みます。' : '「眺める」で時間が進みます。'}`;
}
function showAbout() { setPage('about'); }

function bindControls() {
  $('toggle-play').addEventListener('click', () => {
    if (current.ended) { sim = seek(sim, 1900, 1); refresh(true); setPlaying(true, '1900年から、もう一度眺めます。'); }
    else setPlaying(!playing, playing ? '時間を止めました。じっくり眺められます。' : '眺めているだけで、時代が進みます。');
  });
  $('speed').addEventListener('change', event => { speed = Number(event.target.value); save(); $('time-message').textContent = `一日が巡ると、翌年の別の季節へ。${speed}倍の速さで眺めます。`; });
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
  $('more-history').addEventListener('click', () => historyAround(current.year)); $('more-living').addEventListener('click', () => openArchive('living'));
  $('day-range').addEventListener('input',event=>{motionTime=Math.floor(motionTime/DAILY_CYCLE_SECONDS)*DAILY_CYCLE_SECONDS+Number(event.target.value);dirty=true;renderRoutineUI();});
  $('zoom-range').addEventListener('input',event=>{zoom=Number(event.target.value);dirty=true;save();});
  $('season-select').addEventListener('change',event=>{sim=seek(sim,current.year,Number(event.target.value));motionTime=15;lastHistoricalDay=0;refresh();});
  for(const id of ['history-search','history-theme','history-region','history-from','history-through'])$(id).addEventListener('input',()=>{historyLimit=36;renderChronicle();});
  $('history-reset').addEventListener('click',()=>{for(const id of ['history-search','history-theme','history-region'])$(id).value='';$('history-from').value=1900;$('history-through').value=2026;historyLimit=36;renderChronicle();});
  $('history-more').addEventListener('click',()=>{historyLimit+=36;renderChronicle();});
  $('detail-close').addEventListener('click', () => $('detail-dialog').close()); $('archive-close').addEventListener('click', () => $('archive-dialog').close());
  dialogs.forEach(dialog => dialog.addEventListener('close', dialogClosed));
  $('archive-search').addEventListener('input', () => { archiveLimit = 30; renderArchive(); });
  $('archive-year').addEventListener('input', () => { archiveLimit = 30; renderArchive(); });
  $('archive-clear').addEventListener('click', () => { $('archive-search').value = ''; $('archive-year').value = ''; archiveLimit = 30; renderArchive(); });
  document.addEventListener('change', event => { if (event.target.id === 'series-picker') { seriesDetail = event.target.value; seriesPage = 1; $('detail-title').textContent = series.get(seriesDetail).label; $('detail-body').innerHTML = seriesDetailHTML();mountInlineCharts(); } });
  document.addEventListener('click', event => {
    const button = event.target.closest('button'); if (!button) return;
    if(button.dataset.page)setPage(button.dataset.page);
    if(button.dataset.inspector)setInspector(button.dataset.inspector);
    if(button.dataset.dayTime){motionTime=Math.floor(motionTime/DAILY_CYCLE_SECONDS)*DAILY_CYCLE_SECONDS+Number(button.dataset.dayTime);dirty=true;renderRoutineUI();save();}
    if(button.dataset.eraYear){jumpYear(button.dataset.eraYear);motionTime=15;lastHistoricalDay=0;setPage('town');renderRoutineUI();}
    if(button.dataset.historyYear)historyAround(button.dataset.historyYear);
    if(button.dataset.historyRange){const [from,through]=button.dataset.historyRange.split(',');$('history-from').value=from;$('history-through').value=through;historyLimit=36;renderChronicle();}
    if (button.dataset.driver) driverDetail(button.dataset.driver);
    if (button.dataset.scene) sceneDetail(button.dataset.scene);
    if (button.dataset.journey) journeyTo(button.dataset.journey);
    if (button.dataset.vital) vitalDetail(button.dataset.vital);
    if (button.dataset.event) eventDetail(button.dataset.event);
    if (button.dataset.living) livingDetail(button.dataset.living);
    if (button.dataset.series) showSeries(button.dataset.series);
    if (button.dataset.person) { sim = selectPerson(sim, button.dataset.person); setView('place');setInspector('people'); refresh(); }
    if (button.dataset.section) { archiveSection = button.dataset.section; archiveLimit = 30; document.querySelectorAll('[data-section]').forEach(tab => tab.setAttribute('aria-pressed', String(tab === button))); renderArchive(); }
    if (button.dataset.jump) { detailResume=false;jumpYear(button.dataset.jump); dialogs.forEach(dialog => dialog.close());setPage('town');setPlaying(false,'この年の暮らしです。「眺める」で一日が動き始めます。'); }
    if (button.id === 'more-archive') { archiveLimit += 30; renderArchive(); }
    if (button.id === 'more-series') { seriesPage++; $('detail-body').innerHTML = seriesDetailHTML();mountInlineCharts(); }
    if (button.id === 'show-all-series-years') { seriesYear = null; $('detail-body').innerHTML = seriesDetailHTML();mountInlineCharts(); }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden && playing) setPlaying(false, '画面を離れたので、時間を止めました。「眺める」で続きます。'); });
  window.addEventListener('blur', () => { if (playing) setPlaying(false, '画面を離れたので、時間を止めました。「眺める」で続きます。'); });
  window.addEventListener('pagehide', save);
  new ResizeObserver(() => { renderer?.resize(); dirty = true; }).observe($('world-canvas'));
}
function frame(now) {
  const dt = Math.min(.1, (now - (lastFrame || now)) / 1000); lastFrame = now;
  if (playing) { motionTime += dt*speed; }
  if(now-lastRoutineFrame>=150){renderRoutineUI();lastRoutineFrame=now;}
  if (playing && motionTime - lastCuration >= 10) { lastCuration = motionTime; lastHistoryIndex++; livingPage += 3; renderHistory(); renderLiving(); }
  if (playing && now - lastModel >= 200) {
    const day=Math.floor(motionTime/DAILY_CYCLE_SECONDS);
    if(day>lastHistoricalDay){const days=day-lastHistoricalDay,nextMonth=[1,4,7,10][(Math.floor((current.month-1)/3)+days)%4];sim=advance(sim,days*12);if(!snapshot(sim).ended)sim=seek(sim,Math.floor(sim.time/12),nextMonth);lastHistoricalDay=day;refresh();}
    lastModel = now;dirty=true;
    if (current.ended) { playState(); $('time-message').textContent = '2026年10月、いまにつながりました。過去の年や、別の暮らしも眺められます。'; }
  }
  if (dirty || (playing && !reducedMotion)) {
    if(page==='town')renderer.render(current, motionTime, { view, placeId: sim.placeId, selectedPersonId: sim.personId, reducedMotion,zoom }); dirty = false;
  }
  frameId = requestAnimationFrame(frame);
}
async function boot() {
  $('loading').hidden = false; $('load-error').hidden = true;
  try {
    const files = await Promise.all(['archive.json', 'drivers.json', 'japan.geo.json','history-expanded.json'].map(async file => {
      const response = await fetch(`./data/${file}`); if (!response.ok) throw new Error('読み込みが止まりました'); return response.json();
    }));
    archive=mergeHistory(files[0],files[3]);drivers=files[1];
    sources = new Map(archive.sources.map(source => [source.id, source])); statistics = new Map(archive.statistics.map(stat => [stat.id, stat])); series = new Map(archive.series.map(entry => [entry.id, entry]));
    let saved = null; try { saved = parseSaved(localStorage.getItem(STORAGE_KEY)); } catch { saveAvailable = false; }
    const values = new Uint32Array(1); crypto.getRandomValues(values);
    sim = createSimulation(archive, drivers, saved || { seed: values[0] || 1, year: 1900, month: 1 });
    if (saved?.personId) sim = selectPerson(sim, saved.personId);
    motionTime=saved?.clockSeconds??15;lastHistoricalDay=Math.floor(motionTime/DAILY_CYCLE_SECONDS);zoom=saved?.zoom??1;$('zoom-range').value=zoom;
    speed = saved ? saved.clockSeconds===undefined ? ({1:4,4:12,12:48}[saved.speed]||4) : saved.speed : 4; reducedMotion = saved?.reducedMotion ?? reducedMotion; $('speed').value = speed; $('reduce-motion').checked = reducedMotion;
    $('motion-note').textContent = reducedMotion ? '動きを抑えて表示しています。' : '';
    $('place-select').innerHTML = PLACES.map(place => `<option value="${place.id}">${esc(place.region)} ／ ${esc(place.name)}</option>`).join('');
    renderer?.destroy();
    renderer = createRenderer($('world-canvas'), { geometry: files[2], onPlaceSelect: id => setPlace(id), onPersonSelect: id => { sim = selectPerson(sim, id); refresh(); }, onViewChange: setView });
    $('loading').hidden = true; $('app').hidden = false;
    explorer=createStatisticsExplorer($('statistics-explorer'),archive,drivers,{year:sim.year||1900,onYear:year=>{jumpYear(year);setPlaying(false);setPage('town');},onSeries:id=>showSeries(id)});
    setupChronicle();
    $('era-stops').innerHTML=[[1900,'木の町と手仕事'],[1925,'瓦屋根と洋風の店'],[1945,'低い軒の町'],[1965,'団地と広がる道'],[1985,'看板と四角いビル'],[2005,'ガラスの駅前'],[2026,'いまの暮らし']].map(([year,label],i)=>`<button type="button" data-era-year="${year}" aria-pressed="false"><span class="era-mini era-${i}" aria-hidden="true"><i></i><i></i><i></i></span><span><strong>${year}</strong><span>${label}</span></span></button>`).join('');
    refresh(!saved?.personId); renderer.resize();
    if (saved) $('time-message').textContent = '前に眺めていた暮らしの続きから始めます。';
    $('archive-intro').textContent = `${archive.statistics.length}の統計表、${archive.events.length}の出来事、${archive.living.length}の暮らしの記録から。気になる時代や言葉から探せます。`;
    $('journey-stops').innerHTML = JOURNEYS.map(stop => `<button type="button" class="journey-stop" data-journey="${stop.id}" aria-pressed="false">${propIcon(stop.prop)}<span><span class="journey-date">${stop.year}年 ／ ${stop.region}</span><strong>${stop.title}</strong></span><span class="journey-arrow" aria-hidden="true">↗</span></button>`).join('');
    bindControls(); $('open-archive').disabled = false; $('open-about').disabled = false;document.querySelectorAll('.page-tabs button').forEach(b=>b.disabled=false); if (!frameId) frameId = requestAnimationFrame(frame);
    setInspector('people');
  } catch (error) { $('loading').hidden = true; $('load-error').hidden = false; $('app').hidden = true; console.error('箱庭をひらけませんでした。', error); }
}
$('retry').addEventListener('click', boot);
boot();
