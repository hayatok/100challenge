import {MIN_YEAR, MAX_YEAR, defaultState, validYear, eraLabel, ageLabel, parseState, getYearRecords, getUndatedLiving, statisticView, formatValue, validateDataset, safeSourceURL} from './model.mjs';
import {createCharts} from './charts.mjs';

const $ = selector => document.querySelector(selector);
const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const sourceLink = (url,label)=>safeSourceURL(url)?`<a href="${esc(safeSourceURL(url))}" target="_blank" rel="noopener noreferrer">${esc(label)}</a>`:esc(label);
const STORAGE_KEY = 'history-nearby-v1';
let data = null, editorial = null, charts = null, activeView = null;
let state = {...defaultState}, visible = [true,true], expandedEvents = false, loadNumber = 0;
let sourceReturnFocus = null;

const scenes = {
  teacher: {file:'teacher-desk.png',title:'机の上の暮らし',alt:'帳面、葉書、野菜の置かれた机と、窓の外の木造の町を描いたイラスト'},
  rural: {file:'rural-day.png',title:'農村の日々',alt:'畑仕事と食卓がつながる、農村の家族の暮らしを描いたイラスト'},
  city: {file:'city-home.png',title:'街の住まい',alt:'台所、洗濯物、自転車と鉄道のある、街の日常を描いたイラスト'},
};
const sceneForYear = year=>year<1926?scenes.teacher:year<1970?scenes.rural:scenes.city;
const yearOf = value => Number(String(value).slice(0,4));

function storedState() {
  try {return JSON.parse(localStorage.getItem(STORAGE_KEY));} catch {return null;}
}
function persist() {
  try {localStorage.setItem(STORAGE_KEY,JSON.stringify({version:'history-local-v1',...state}));} catch { /* Reading remains available when storage is unavailable. */ }
  const params = new URLSearchParams(location.search);
  params.set('y',state.year);params.set('b',state.birthYear);params.set('m',state.metric);
  history.replaceState(null,'',`${location.pathname}?${params}${location.hash}`);
}
function announce(message) {$('#announcement').textContent=message;}
function showSource(title,body) {
  sourceReturnFocus=document.activeElement;
  $('#source-heading').textContent=title;
  $('#source-body').innerHTML=body;
  $('#source-dialog').showModal();
  $('#source-close').focus();
}
function closeSource() {$('#source-dialog').close();}
$('#source-close').addEventListener('click',closeSource);
$('#source-dialog').addEventListener('close',()=>{if(sourceReturnFocus?.isConnected)sourceReturnFocus.focus();});
$('#source-dialog').addEventListener('click',event=>{
  if(event.target!==event.currentTarget)return;
  const r=event.currentTarget.getBoundingClientRect();
  if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)closeSource();
});
$('#about-open').addEventListener('click',()=>showSource('この作品の読み方',`
  <p>生まれた年を置いて、1900年から現在までを行き来する作品です。年を動かすと、その年の社会の数字や出来事、暮らしの記録が変わります。</p>
  <h3>生まれ年を重ねてみる</h3><p>表示する年齢は、その年に迎える年齢です。誰かの生涯を予測するものではなく、時代と自分の距離を測る手がかりです。</p>
  <h3>一人の記録と、社会の数字</h3><p>家計簿や回想は、特定の人や家族の記録です。全国を集計した統計とは性格が違います。それぞれの「資料を読む」「出典と数字の読み方」から、対象となる人々や時期、分からない部分を確かめられます。</p>
  <h3>空白も、そのまま読む</h3><p>資料が失われた年や、ここで紹介していない年には、数値を補っていません。図の空白が何を意味するかは、説明と出典から読めます。</p>
  <h3>絵について</h3><p>暮らしのイラストは、この作品のためにAIで制作しました。実在する家族の姿や、選んだ年の風景を写した史料ではありません。</p>
  <p class="source-small">1900年1月1日〜2026年10月16日までに確認した資料を収めています。文章とグラフは、本作品が資料をもとに作成しました。</p>`));

function layerLabel(record) {
  if(record.ids.includes('L2-M001'))return '家計簿の原簿から';
  if(record.ids[0].startsWith('E2M'))return '研究論文を通して';
  return '本人や家族の回想から';
}
function lifeHTML(record) {
  const isTeacher=record.ids.includes('L2-M001');
  const period=record.period==='体験年を未特定'?'体験した年は不明':record.period;
  const amountNote=isTeacher?'一世帯の一日の記帳。食品の数量や単価は分かりません。':'個人の記録を研究者が集計した現金支出です。';
  return `<article class="life-record" data-life-id="${esc(record.ids[0])}"><p class="life-location">${esc(layerLabel(record))}</p><h3>${esc(record.title)}</h3><p class="record-period">${esc(period)}</p><p>${esc(record.summary)}</p>${record.amount?`<p class="record-amount">${esc(record.amount)}</p><p class="record-context">${esc(amountNote)}</p>`:''}<button type="button" class="source-button" data-life-source="${esc(record.ids[0])}">資料を読む <span aria-hidden="true">↗</span></button></article>`;
}
function showLifeSource(id) {
  const r=data.living.find(r=>r.ids.includes(id));
  if(!r)return;
  showSource(r.title,`<p class="source-small">${esc(layerLabel(r))}／${esc(r.period)}</p><h3>どこの、誰の記録か</h3><p>${esc(r.geo)}</p><h3>調べた資料</h3><p>${esc(r.source_title)}<br>${esc(r.institution)}</p><p>${esc(r.locator)}</p>${r.url?`<p>${sourceLink(r.url,r.link_status==='top'?`${r.institution}の公式サイト`:'資料の公開案内をひらく')}</p>`:''}<h3>この記録から分かる範囲</h3><p>${esc(r.limit)}</p><p class="source-small">記録の事実をもとに、本作品が説明を書いています。原簿画像や長い原文は掲載していません。確認日：2026年10月16日。</p>`);
}
function nearbyHTML() {
  const candidates=data.living.filter(r=>r.start!==null&&r.end!==null).sort((a,b)=>Math.abs(yearOf(a.start)-state.year)-Math.abs(yearOf(b.start)-state.year));
  const selected=[];
  candidates.forEach(r=>{if(selected.length<2&&!selected.some(s=>yearOf(s.start)===yearOf(r.start)))selected.push(r);});
  return `<div class="empty-reading"><p>この年の暮らしの記録は、まだ紹介できていません。</p><h3>少し先へ、少し前へ。</h3><p>別の年に残された記録を読んでみませんか。</p><div class="nearby-records">${selected.map(r=>{const year=yearOf(r.start),scene=sceneForYear(year);return `<button type="button" data-year="${year}"><img src="./assets/art/${scene.file}" alt="" loading="lazy" width="84" height="70"><span><small>${year}年の記録へ</small>${esc(r.title)}</span><span aria-hidden="true">→</span></button>`;}).join('')}</div></div>`;
}
function eventSummary(event) {
  return editorial.events[event.id].summary;
}
function dateLabel(date) {
  const parts=String(date).split('-').map(Number);
  return parts.length===3?`${parts[1]}月${parts[2]}日`:parts.length===2?`${parts[1]}月`:`${parts[0]}年`;
}
function eventDateLabel(event) {
  if(event.date_precision!=='range'||!event.date_end||event.date_start===event.date_end)return dateLabel(event.date_start);
  if(yearOf(event.date_start)!==yearOf(event.date_end))return `${yearOf(event.date_start)}〜${yearOf(event.date_end)}年`;
  return `${dateLabel(event.date_start)}〜${dateLabel(event.date_end)}`;
}
function eventHTML(event) {
  return `<article class="event-record" data-event-id="${esc(event.id)}"><p class="event-date">${esc(eventDateLabel(event))}${event.verification==='needs_crosscheck'?'<span class="event-qualification">日付・説明に補足あり</span>':''}</p><h3>${esc(event.title)}</h3><p>${esc(eventSummary(event))}</p><p class="event-location">${esc(event.geography)}</p><button type="button" class="source-button" data-event-source="${esc(event.id)}">出典を読む <span aria-hidden="true">↗</span></button></article>`;
}
function showEventSource(id) {
  const event=data.events.find(e=>e.id===id);
  if(!event)return;
  const locator=editorial.events[event.id].locator;
  const qualification=editorial.events[event.id].qualification;
  const period=event.date_precision==='range'&&event.date_end&&event.date_end!==event.date_start?`${event.date_start}〜${event.date_end}`:event.date_start;
  showSource(event.title,`<p class="source-small">${esc(period)}／${esc(event.geography)}</p><h3>出典</h3>${event.source_ids.map(id=>{const s=data.sources[id];return `<p>${sourceLink(s.url,s.title)}<br><span class="source-small">${esc(s.institution)}</span></p>`;}).join('')}<p>${esc(locator)}</p>${qualification?`<h3>日付や説明について</h3><p>${esc(qualification)}</p>`:''}<p class="source-small">出来事の起きた日と、社会全体の暮らしが変わった時期は必ずしも一致しません。</p>`);
}

function showStatSource() {
  const view=activeView,m=view.metric;
  const raw=view.series.filter(s=>s.point).map(s=>`${esc(s.label)}：${esc(s.point.raw)} ${esc(s.point.unit)}（${state.year}年）`).join('<br>');
  showSource(m.title,`<p>${sourceLink(m.url,`${m.source}・e-Statの統計表をひらく`)}</p><p class="source-small">表番号：${esc(m.table_id)}／確認日：${esc(m.checked_at)}<br>数値をもとに、本作品がグラフを作成しました。</p><h3>${state.year}年の原値</h3><p class="source-raw">${raw||esc(view.status)}</p><h3>数字の読み方</h3><ul>${view.sourceNotes.map(note=>`<li>${esc(note)}</li>`).join('')}</ul>${state.metric==='vital'?'<h3>数える範囲の変化</h3><p>1900〜1943年／1947〜1972年（沖縄県を含まない）／1973〜2024年。戦前を含む国籍・地域の対応は全期間では確かめきれていません。各年の掲載人数を点で示しています。</p>':''}`);
}
$('#stat-source').addEventListener('click',()=>{if(activeView)showStatSource();});

function renderStatistics() {
  activeView=statisticView(data,state.metric,state.year);
  const m=activeView.metric;
  $('#metric').value=state.metric;
  $('#stat-values').innerHTML=activeView.status?`<p class="stat-empty">${esc(state.year)}年<br>${esc(activeView.status)}</p>`:activeView.series.map(s=>`<div class="stat-value"><span class="stat-value-label">${esc(s.label)}</span><strong>${esc(formatValue(s.point,m))}</strong><span class="stat-value-unit">${esc(m.unit)}</span></div>`).join('');
  $('#chart-legend').innerHTML=m.series.map((s,i)=>`<button type="button" data-series="${i}" aria-pressed="${visible[i]}" aria-label="${esc(s.label)}を${visible[i]?'隠す':'表示する'}"><span class="legend-dot ${i?'secondary':''}" aria-hidden="true"></span>${esc(s.label)}</button>`).join('');
  $('#chart-caption').textContent=state.metric==='vital'?'点は各年の掲載人数。1944〜1946年は空白、1947年と1973年で集計範囲が変わります。':'各年の暦年平均。図を押すと、その年へ移動します。';
  $('#stat-scope').textContent=activeView.scopeNote;
  charts.render(state,activeView,visible);
}
function renderEvents(records) {
  const entries=[...records].sort((a,b)=>String(a.date_start).localeCompare(String(b.date_start)));
  $('#events-count').textContent=`${entries.length}件${state.year===2026?' · 10月16日まで':''}`;
  $('#events-list').innerHTML=entries.length?entries.slice(0,expandedEvents?entries.length:6).map(eventHTML).join(''):'<p class="empty-events">この年の出来事は、まだ紹介していません。</p>';
  const more=$('#more-events');
  more.hidden=entries.length<=6;
  more.textContent=expandedEvents?'少なく表示する':`ほかの${entries.length-6}件を読む`;
  more.setAttribute('aria-expanded',String(expandedEvents));
  more.setAttribute('aria-controls','events-list');
}
function updateScene() {
  const scene=sceneForYear(state.year),image=$('#scene-image');
  if(image.dataset.scene!==scene.file){
    image.src=`./assets/art/${scene.file}`;image.alt=scene.alt;image.dataset.scene=scene.file;
    image.classList.remove('scene-changing');
    requestAnimationFrame(()=>image.classList.add('scene-changing'));
  }
  $('#scene-caption').textContent=scene.title;
}
function renderYear() {
  $('#current-year').textContent=state.year;
  $('#era').textContent=eraLabel(state.year);
  $('#age-label').textContent=ageLabel(state.year,state.birthYear);
  $('#view-year').value=state.year;
  $('#year-range').value=state.year;
  $('#year-range').setAttribute('aria-valuetext',`${state.year}年、${ageLabel(state.year,state.birthYear)}`);
  $('#previous-year').disabled=state.year===MIN_YEAR;
  $('#next-year').disabled=state.year===MAX_YEAR;
  $('#previous-year').setAttribute('aria-label',state.year===MIN_YEAR?'1900年が最初の年です':'前年へ');
  $('#next-year').setAttribute('aria-label',state.year===MAX_YEAR?'2026年が最後の年です':'翌年へ');
  document.querySelectorAll('.chapter-links [data-year]').forEach(button=>button.setAttribute('aria-pressed',String(Number(button.dataset.year)===state.year)));
  const records=getYearRecords(data,state.year);
  $('#living-count').textContent=records.living.length?`${records.living.length}つの記録`:'';
  $('#living-records').innerHTML=records.living.length?records.living.map(lifeHTML).join(''):nearbyHTML();
  updateScene();renderStatistics();renderEvents(records.events);
  document.title=`${state.year}年 — 時代のとなりで`;
}
function changeYear(year) {
  if(!data||!validYear(year))return;
  state.year=year;expandedEvents=false;
  $('#year-error').hidden=true;$('#view-year').removeAttribute('aria-invalid');
  renderYear();persist();
  announce(`${state.year}年。${ageLabel(state.year,state.birthYear)}。${activeView.status}`);
}
function yearError(input,error) {
  input.setAttribute('aria-invalid','true');error.hidden=false;
  error.textContent='1900〜2026の間の年を、整数で入れてください。';
}
$('#previous-year').addEventListener('click',()=>changeYear(state.year-1));
$('#next-year').addEventListener('click',()=>changeYear(state.year+1));
$('#year-range').addEventListener('input',event=>changeYear(Number(event.target.value)));
$('#view-year').addEventListener('input',event=>{
  const year=Number(event.target.value);
  if(!event.target.value.trim()||!validYear(year)){yearError(event.target,$('#year-error'));return;}
  changeYear(year);
});
$('#birth-year').addEventListener('input',event=>{
  const year=Number(event.target.value);
  if(!event.target.value.trim()||!validYear(year)){yearError(event.target,$('#birth-error'));return;}
  $('#birth-error').hidden=true;event.target.removeAttribute('aria-invalid');state.birthYear=year;
  $('#age-label').textContent=ageLabel(state.year,state.birthYear);
  $('#year-range').setAttribute('aria-valuetext',`${state.year}年、${ageLabel(state.year,state.birthYear)}`);
  if(charts)charts.render(state,activeView,visible);
  persist();announce(ageLabel(state.year,state.birthYear));
});
$('#metric').addEventListener('change',event=>{
  if(!data)return;
  state.metric=event.target.value;visible=[true,true];renderStatistics();persist();
  announce(`${state.year}年。${activeView.metric.title}。${activeView.status}`);
});
$('#chart-legend').addEventListener('click',event=>{
  const button=event.target.closest('[data-series]');if(!button)return;
  const index=Number(button.dataset.series);visible[index]=!visible[index];
  // Keep the focused native button alive while changing its chart.
  button.setAttribute('aria-pressed',String(visible[index]));
  button.setAttribute('aria-label',`${activeView.metric.series[index].label}を${visible[index]?'隠す':'表示する'}`);
  charts.render(state,activeView,visible);
});
$('#more-events').addEventListener('click',()=>{expandedEvents=!expandedEvents;renderEvents(getYearRecords(data,state.year).events);});
$('#main-content').addEventListener('click',event=>{
  const yearButton=event.target.closest('button[data-year]');
  if(yearButton){changeYear(Number(yearButton.dataset.year));return;}
  const lifeButton=event.target.closest('button[data-life-source]');
  if(lifeButton){showLifeSource(lifeButton.dataset.lifeSource);return;}
  const eventButton=event.target.closest('button[data-event-source]');
  if(eventButton)showEventSource(eventButton.dataset.eventSource);
});
window.addEventListener('popstate',()=>{
  if(!data)return;
  state=parseState(location.search,storedState());visible=[true,true];expandedEvents=false;
  $('#birth-year').value=state.birthYear;$('#birth-error').hidden=true;$('#birth-year').removeAttribute('aria-invalid');
  renderYear();
});

async function load() {
  const attempt=++loadNumber;
  $('#load-status').hidden=false;$('#load-error').hidden=true;$('#main-content').hidden=true;
  $('#main-content').setAttribute('aria-busy','true');
  charts?.destroy();charts=null;
  try {
    const responses=await Promise.all(['history.json','editorial.json'].map(file=>fetch(new URL(`../data/${file}`,import.meta.url),{cache:'no-cache'})));
    if(responses.some(r=>!r.ok))throw new Error('History data response unavailable');
    const [received,copy]=await Promise.all(responses.map(r=>r.json()));validateDataset(received);
    if(copy.version!==1||received.events.some(e=>typeof copy.events?.[e.id]?.summary!=='string'||typeof copy.events[e.id].locator!=='string'))throw new Error('Event text unavailable');
    if(attempt!==loadNumber)return;
    data=received;editorial=copy;state=parseState(location.search,storedState());visible=[true,true];expandedEvents=false;
    $('#main-content').hidden=false;
    charts=createCharts({statisticsNode:$('#statistics-chart'),timelineNode:$('#record-timeline'),tooltipNode:$('#chart-tooltip'),onYear:changeYear,data});
    $('#birth-year').value=state.birthYear;
    const memories=getUndatedLiving(data);
    $('#memory-count').textContent=`${memories.length}つの記録`;
    $('#memory-records').innerHTML=memories.map(lifeHTML).join('');
    renderYear();
    $('#main-content').setAttribute('aria-busy','false');$('#load-status').hidden=true;
  }catch(error){
    if(attempt!==loadNumber)return;
    data=null;charts?.destroy();charts=null;
    $('#main-content').hidden=true;$('#load-status').hidden=true;$('#load-error').hidden=false;
    $('#main-content').setAttribute('aria-busy','false');
    console.error('History page could not be opened',error);
  }
}
$('#retry').addEventListener('click',()=>load());
load();
