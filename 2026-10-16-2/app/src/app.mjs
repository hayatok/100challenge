import {WIDTH, HEIGHT, TYPES, PHASES, createGame, analyze, previewBuild, build, remove, advance, validateSave, terrainAt, costOf} from './model.mjs';
import {terrainSVG, buildingSVG, residentSVG, toolIconSVG} from './art.mjs';

const $ = id => document.getElementById(id);
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const clone = value => JSON.parse(JSON.stringify(value));
const SAVE_KEY = 'town-continuation-v1';
const toolOrder = ['shop','home','road','workshop','bridge','clinic','park','erase'];
const kindLabels = {shop:'買物',work:'仕事',clinic:'通院',park:'公園'};
const toolDescription = {shop:'道を4マスまで歩いて買物へ。',home:'3人の住まい。増やせる家は1戸。',road:'建物の隣から、ほかの道へつなぎます。',workshop:'道を7マスまで。6人が働けます。',bridge:'川の上に置くと、道として渡れます。',clinic:'道を3マスまで歩いて通院へ。',park:'道を2マスまで歩いて憩いの場へ。',erase:'建てたときの予算が戻ります。もともとの家と仕事場は残します。'};
let state = createGame(), chapterStart = clone(state), undoStack = [], history = [];
let screen = 'title', tool = 'shop', selected = null, focused = {x:2,y:1}, lastBuilt = null;
let sourceData = null, sourceError = false, saved = null, saveError = false;
let audio = null, sound = false, motion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let restartKind = 'chapter';
let announcementTimer;
const hasSavedProgress = () => Boolean(saved&&(saved.state.phase>0||saved.state.completed||saved.undo.length>0));

function notify(message, error = false) {
  $('notice').textContent = message;
  $('notice').classList.toggle('error', error);
  clearTimeout(announcementTimer);
  $('announcement').textContent = '';
  announcementTimer = setTimeout(() => { $('announcement').textContent = message; }, 30);
}

function loadSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const save = JSON.parse(raw), current = validateSave(save.state), start = validateSave(save.chapterStart);
    if (save.version !== 1 || !current.ok || !start.ok || start.state.phase !== current.state.phase || !Array.isArray(save.undo) || save.undo.length > 100 || !Array.isArray(save.history) || save.history.length > 3) throw new Error('Invalid saved town');
    if (!save.undo.every(s => validateSave(s).ok && s.phase === current.state.phase) || !save.history.every((s,i) => validateSave(s).ok && s.phase === i)) throw new Error('Invalid saved history');
    return {state:current.state,chapterStart:start.state,undo:save.undo,history:save.history,sound:save.sound===true,motion:save.motion===true};
  } catch {
    $('save-note').textContent = '前の町を読み込めませんでした。新しい町から始められます。';
    return null;
  }
}

function persist() {
  const save = {version:1,state,chapterStart,undo:undoStack,history,sound,motion};
  saved = clone(save);
  try { localStorage.setItem(SAVE_KEY,JSON.stringify(save)); saveError = false; }
  catch { if (!saveError) notify('このブラウザでは続きが保存できません。今の町はこのまま遊べます。',true); saveError = true; }
  $('resume-game').hidden = !hasSavedProgress();
}

function showScreen(next) {
  screen = next;
  for (const name of ['title','game','result']) $(`${name}-screen`).hidden = next !== name;
  $('app').classList.remove('is-paused');
  if (next === 'game') render();
  if (next === 'result') renderResult();
  if (next === 'title') $('resume-game').hidden = !hasSavedProgress();
  document.title = next === 'game' ? `${PHASES[state.phase].year}年 — まちの続き` : 'まちの続き — 時代をつなぐ、小さなまちづくり';
  window.scrollTo({top:0,behavior:'instant'});
}

function newGame() {
  state = createGame(); chapterStart = clone(state); undoStack = []; history = [];
  tool = 'shop'; selected = null; lastBuilt = null;focused={x:2,y:1};
  showScreen('game'); persist(); notify('まずは商店。道のそばの、光る空き地を選ぼう。');
}

function point({x,y}) { return {x:340+(x-y)*40,y:100+(x+y)*20}; }
function roadConnections(tiles,x,y) {
  return [[0,-1],[1,0],[0,1],[-1,0]].map(([dx,dy])=>tiles.some(t=>t.x===x+dx&&t.y===y+dy&&['road','bridge'].includes(t.type)));
}
function futureLot(x,y,phase) { return phase===1 && x===7 && y===4; }
function isHintCell(x,y) { return state.phase===0&&tool==='shop'&&!state.tiles.some(t=>t.type==='shop')&&[[2,1],[3,2]].some(p=>p[0]===x&&p[1]===y); }
function mapSVG(game, interactive = false) {
  const stats = analyze(game), byCell = new Map(game.tiles.map(t=>[`${t.x},${t.y}`,t]));
  let svg = '<ellipse cx="358" cy="422" rx="298" ry="30" fill="#6a73501a"/>';
  for (let diagonal=0;diagonal<WIDTH+HEIGHT-1;diagonal++) {
    for (let y=0;y<HEIGHT;y++) {
      const x=diagonal-y; if(x<0||x>=WIDTH)continue;
      const p=point({x,y}), tile=byCell.get(`${x},${y}`), terrain=terrainAt(x,y), reserved=futureLot(x,y,game.phase);
      const locked=game.phase===0&&x>=5;
      const selectedHere=interactive&&selected?.x===x&&selected?.y===y;
      const ghost=selectedHere&&!tile&&tool!=='erase'&&previewBuild(game,tool,x,y).ok;
      const kind=tile&&['road','bridge'].includes(tile.type)?tile.type:terrain;
      const label=`${x+1}列${y+1}行、${tile?TYPES[tile.type].label:reserved?'住宅予定地':terrain==='river'?'川':terrain==='mountain'?'山':'空き地'}${locked?'、1973年から':''}`;
      const attrs=interactive?`class="map-cell ${locked?'locked':''} ${selectedHere?'selected':''} ${isHintCell(x,y)?'hint-cell':''}" role="button" tabindex="${focused.x===x&&focused.y===y?0:-1}" aria-label="${label}" aria-pressed="${Boolean(selectedHere)}" data-x="${x}" data-y="${y}"`:'';
      svg+=`<g transform="translate(${p.x} ${p.y})" ${attrs}>${terrainSVG(kind,roadConnections(game.tiles,x,y))}`;
      if(reserved)svg+='<path d="M-24 0 0-12 24 0 0 12Z" fill="none" stroke="#6d7761" stroke-dasharray="3 3"/><text x="0" y="5" font-size="10" text-anchor="middle" fill="#465744">住宅予定</text>';
      if(tile&&!['road','bridge'].includes(tile.type))svg+=`<g class="${interactive&&lastBuilt?.x===x&&lastBuilt?.y===y?'placed-object':''}">${buildingSVG(tile.type,game.phase)}</g>`;
      if(ghost)svg+=`<g class="preview-building">${['road','bridge'].includes(tool)?terrainSVG(tool,roadConnections(game.tiles,x,y)):buildingSVG(tool,game.phase)}</g>`;
      if(interactive) {
        if(isHintCell(x,y)&&!tile)svg+='<path class="hint-ring" d="M-29 0 0-14 29 0 0 14Z" fill="#fff2b766" stroke="#b37c2a" stroke-width="2"/>';
        svg+='<path class="cell-highlight" d="M-39 0 0-19 39 0 0 19Z"/>';
      }
      svg+='</g>';
    }
  }
  if(interactive&&selected) {
    const home=stats.perHome.find(h=>h.x===selected.x&&h.y===selected.y);
    if(home)for(const kind of Object.keys(kindLabels))if(home[kind]) {
      const route=[home,...home[kind].path,home[kind].target].map(point);
      svg+=`<polyline class="map-route" points="${route.map(p=>`${p.x},${p.y}`).join(' ')}"/>`;
    }
  }
  // People follow the very same paths that satisfy the goals; no decorative wandering.
  const routes=stats.perHome.flatMap(home=>{
    const priority=game.phase>=2?['clinic','park','shop','work']:['shop','work'];
    return stats.routes.filter(r=>r.from.x===home.x&&r.from.y===home.y&&priority.includes(r.kind)).sort((a,b)=>priority.indexOf(a.kind)-priority.indexOf(b.kind)).slice(0,3);
  });
  routes.forEach((route,i)=>{
    const path=[route.from,...route.path,route.target].map(point), first=path[0];
    const d=`M${path.map(p=>`${p.x},${p.y-5}`).join(' L')}`;
    const duration=4+route.distance*.8;
    if(interactive&&!motion)svg+=`<g class="resident">${residentSVG(i)}<animateMotion dur="${duration}s" begin="${-(i*.63)}s" repeatCount="indefinite" path="${d}"/></g>`;
    else { const resting=path[Math.floor(path.length/2)]??first;svg+=`<g class="resident stop" transform="translate(${resting.x+3} ${resting.y-4})">${residentSVG(i)}</g>`; }
  });
  if(interactive)for(const home of stats.perHome.filter(h=>!h.shop)) {
    const p=point(home);svg+=`<g pointer-events="none" transform="translate(${p.x} ${p.y-76})"><path d="M-12-10 h24 v18 h-9 l-3 4-3-4 h-9Z" fill="#fffdf8" stroke="#7d613e"/><text y="3" text-anchor="middle" font-size="12" fill="#8a4a2a">店?</text></g>`;
  }
  return svg;
}

function cover() {
  const town={...createGame(),phase:2,tiles:[
    ...createGame().tiles,{x:1,y:3,type:'home'},{x:2,y:1,type:'shop'},
    {x:4,y:3,type:'road'},{x:5,y:3,type:'bridge'},{x:6,y:3,type:'road'},{x:7,y:3,type:'road'},
    {x:7,y:2,type:'home'},{x:7,y:4,type:'home'},{x:6,y:2,type:'shop'},{x:6,y:4,type:'workshop'},
    {x:3,y:2,type:'clinic'},{x:2,y:4,type:'park'},{x:8,y:3,type:'road'},{x:8,y:2,type:'clinic'},{x:8,y:4,type:'park'}
  ]};
  $('cover-town').innerHTML=mapSVG(town);
}

function nextHint(stats) {
  if(state.completed)return '完成した町です。家を選ぶと、つながった道を見られます。';
  if(stats.allDone)return 'この時代の願いがかないました。次の時代へ進めます。';
  if(stats.served.shop<stats.residents)return '店の届かない家があります。家を選ぶと、道のつながりを確かめられます。';
  if(stats.residents<PHASES[state.phase].target)return '買物の道ができました。もう1戸、道のそばに家を建てよう。';
  if(stats.served.work<stats.residents)return '仕事場には6人まで。道をつなぐか、もう一つの仕事場を考えよう。';
  if(state.phase===1&&!stats.bridgeConnected)return '川に橋を架けて、両岸の道をつなごう。';
  if(state.phase===2&&stats.served.clinic<stats.residents)return '診療所は道を3マス以内。すべての家から近くなる場所を探そう。';
  return '公園は道を2マス以内。両岸の家から歩ける憩いの場をつくろう。';
}

function render() {
  const phase=PHASES[state.phase], stats=analyze(state);
  $('year-label').textContent=phase.year; $('chapter-label').textContent=`第${state.phase+1}景 ／ 三つの時代`;
  $('chapter-title').textContent=phase.title; $('budget-value').textContent=state.budget;
  $('budget-change').textContent=state.phase>0?'前の時代から最大3を引継ぎ':'';
  $('era-steps').innerHTML=PHASES.map((p,i)=>`<li class="${i===state.phase?'current':i<state.phase?'done':''}" ${i===state.phase?'aria-current="step"':''}>${p.year}</li>`).join('');
  $('mission-title').textContent=['6人の暮らしをつなぐ','川の向こうも、ご近所に','12人の近くに、安心を'][state.phase];
  $('goals').innerHTML=stats.goals.map(g=>`<li class="goal ${g.done?'done':''}"><span class="mark" aria-hidden="true">${g.done?'✓':''}</span><span>${escape(g.label)}</span><strong>${g.id==='bridge'?(g.done?'つながった':'まだ'):`${g.current} / ${g.target}人`}</strong><progress class="goal-bar" aria-hidden="true" value="${Math.min(g.target,g.current)}" max="${g.target}"></progress></li>`).join('');
  $('next-hint').textContent=nextHint(stats);
  $('finish-era').disabled=!stats.allDone||state.completed;
  $('finish-era').textContent=state.completed?'三つの時代を達成':stats.allDone?(state.phase===2?'町の記録を見る →':`${phase.year}年を終える →`):'願いをかなえよう';
  $('town-instruction').textContent=stats.allDone?'願いがかなった。次の時代へ。':state.phase===0&&!state.tiles.some(t=>t.type==='shop')?'まずは商店。光る空き地を選ぼう。':state.phase===0?(stats.residents<6?'道のそばに、もう1戸の家を。':'店と仕事場へ、道をつなごう。'):state.phase===1?'橋と道で、川の向こうへ。':'家の近くに、診療所と公園を。';
  $('population-label').textContent=`この町の住民 ${stats.residents}人`;
  $('town-map').innerHTML=mapSVG(state,true);
  const activeTool=document.activeElement?.dataset.tool;
  $('toolbox').innerHTML=toolOrder.map(type=>{
    const spec=TYPES[type], locked=spec&&spec.unlockPhase>state.phase;
    return `<button class="tool" data-tool="${type}" aria-pressed="${tool===type}" ${locked||state.completed?'disabled':''} aria-label="${type==='erase'?'建物を返す':`${spec.label}を選ぶ、予算${costOf(type,state.phase)}`}" title="${escape(toolDescription[type])}">${toolIconSVG(type)}<strong>${type==='erase'?'返す':spec.label}</strong><small>${locked?`${PHASES[spec.unlockPhase].year}年〜`:type==='erase'?'予算が戻る':`予算 ${costOf(type,state.phase)}`}</small></button>`;
  }).join('');
  if(activeTool)$('toolbox').querySelector(`[data-tool="${activeTool}"]`)?.focus({preventScroll:true});
  $('undo-button').disabled=undoStack.length===0||state.completed;
  $('restart-chapter').disabled=state.completed;
  $('history-teaser').textContent=sourceData?.phases[state.phase]?.events[0]?.title??'史実・数字・この町のこと';
  renderPlan(stats); updateSettings(); syncMotion();
}

function renderPlan(stats=analyze(state)) {
  if(!selected) {
    $('plan-panel').innerHTML=`<p class="eyebrow">建てるもの</p><h3>${tool==='erase'?'建物を返す':escape(TYPES[tool].label)}</h3><p>${escape(toolDescription[tool])}</p><p class="small spaced">町の土地を選ぶと、建てる前に変化を確かめられます。</p>`;
    return;
  }
  const tile=state.tiles.find(t=>t.x===selected.x&&t.y===selected.y);
  const location=`${selected.x+1}列${selected.y+1}行`;
  if(tile&&tool!=='erase') {
    const home=stats.perHome.find(h=>h.x===tile.x&&h.y===tile.y);
    $('plan-panel').innerHTML=`<p class="eyebrow">${location}</p><h3>${escape(TYPES[tile.type].label)}${tile.type==='home'?' ／ 3人の暮らし':''}</h3>${home?`<ul class="route-list">${Object.entries(kindLabels).filter(([k])=>state.phase===2||['shop','work'].includes(k)).map(([kind,label])=>`<li><span>${label}</span><strong>${home[kind]?`道 ${home[kind].distance}マス`:'届いていない'}</strong></li>`).join('')}</ul>`:`<p>${escape(toolDescription[tile.type])}</p>`}<p class="small spaced">${tile.fixed?'もともとこの町にある建物です。':'「返す」を選ぶと、建てたときの予算が戻ります。'}</p>`;
    return;
  }
  const preview=tool==='erase'?(()=>{const r=remove(state,selected.x,selected.y);return {...r,analysis:analyze(r.state),budgetAfter:r.state.budget,cost:tile?-tile.paid:0};})():previewBuild(state,tool,selected.x,selected.y);
  const changes=[['shop','買物'],['work','仕事'],['clinic','通院'],['park','公園']].filter(([k])=>state.phase===2||['shop','work'].includes(k)).map(([k,label])=>{const before=stats.served[k],after=preview.analysis.served[k];return `<span class="${after>before?'gain':''}">${label} ${before}${after!==before?` → ${after}`:''}人</span>`;}).join('');
  $('plan-panel').innerHTML=`<p class="eyebrow">${location}に</p><h3>${tool==='erase'?'建物を返す':`${escape(TYPES[tool].label)}を建てる`}</h3>${preview.ok?`<p>工事予算 <strong>${state.budget} → ${preview.budgetAfter}</strong></p><div class="plan-effects">${changes}</div><button class="primary" id="confirm-build">${tool==='erase'?'この建物を返す':`${escape(TYPES[tool].label)}を建てる`}</button>`:`<p class="plan-error">${escape(preview.message)}</p><button disabled>別の場所を選ぼう</button>`}`;
}

function selectCell(x,y,keyboard=false) {
  focused={x,y};selected={x,y};lastBuilt=null;render();
  if(keyboard)$('town-map').querySelector(`[data-x="${x}"][data-y="${y}"]`)?.focus({preventScroll:true});
  else if(matchMedia('(max-width:520px)').matches)$('plan-panel').scrollIntoView({block:'nearest',behavior:motion?'instant':'smooth'});
}

function commitBuild() {
  if(!selected)return;
  const before=analyze(state), result=tool==='erase'?remove(state,selected.x,selected.y):build(state,tool,selected.x,selected.y);
  if(!result.ok){notify(result.message,true);return;}
  undoStack.push(clone(state)); if(undoStack.length>100)undoStack.shift();
  state=result.state;lastBuilt={...selected};selected=null;
  const after=analyze(state);render();persist();
  const changed=Object.entries(kindLabels).filter(([k])=>after.served[k]>before.served[k]).map(([k,label])=>`${label}が${after.served[k]}人に届きました`);
  notify(after.allDone?'この時代の願いが、すべてかないました。':`${result.message}${changed.length?' '+changed.join('。')+'。':''}`);
  playTone(after.allDone?'clear':changed.length?'connect':'build');
  if(matchMedia('(max-width:520px)').matches)$('map-scroll').closest('.town-stage').scrollIntoView({block:'start',behavior:motion?'instant':'smooth'});
}

function syncMotion() { const svg=$('town-map'); if(document.hidden||document.querySelector('dialog[open]'))svg.pauseAnimations?.();else svg.unpauseAnimations?.(); }
function openDialog(id) { $('app').classList.add('is-paused'); $(id).showModal();syncMotion(); }
function closeDialog(dialog) { dialog.close(); if(!document.querySelector('dialog[open]'))$('app').classList.remove('is-paused');syncMotion(); }
function finishEra() {
  if(!analyze(state).allDone||state.completed)return;
  const p=PHASES[state.phase], next=PHASES[state.phase+1];
  $('era-result-title').textContent=`${p.year}年、願いがかなった。`;
  $('era-result-copy').textContent=next?(state.phase===0?'町に新しい隣人がやってきます。次は、川の向こうへ。':'時代が変わっても、家はここにある。次は、近くで暮らせる安心を。'):'買物、仕事、通院、憩い。12人の暮らしに、道がつながりました。';
  $('era-summary').innerHTML=`<span>住民 <strong>${analyze(state).residents}人</strong></span><span>工事予算の残り <strong>${state.budget}</strong></span>${next?`<span>次の予算 <strong>${next.budget}+${Math.min(3,state.budget)}</strong></span>`:''}`;
  $('advance-era').textContent=next?`${next.year}年へ進む →`:'町の記録を見る →';
  openDialog('era-dialog');playTone('clear');
}
function advanceEra() {
  const result=advance(state);if(!result.ok)return;
  history.push(clone(state));state=result.state;chapterStart=clone(state);undoStack=[];selected=null;lastBuilt=null;
  tool=state.phase===1?'bridge':'clinic';
  focused=state.phase===1?{x:5,y:3}:{x:3,y:2};
  closeDialog($('era-dialog'));persist();showScreen(state.completed?'result':'game');
  if(!state.completed)notify(result.message);
}

function renderResult() {
  $('result-town').innerHTML=mapSVG(state);
  $('town-history').innerHTML=history.map((s,i)=>`<article><h3>${PHASES[i].year}<small>年</small></h3><p>${['6人の買物と仕事がつながった。','川を越え、9人の暮らしがつながった。','12人の近くに、診療所と公園ができた。'][i]}</p><small>${s.tiles.filter(t=>!['road','bridge'].includes(t.type)).length}棟の町 ／ ${s.tiles.filter(t=>['road','bridge'].includes(t.type)).length}マスの道</small></article>`).join('');
}

function updateSettings() {
  $('app').classList.toggle('reduce-motion',motion);
  $('sound-setting').textContent=`音：${sound?'入':'切'}`;$('sound-setting').setAttribute('aria-pressed',sound);
  $('motion-setting').textContent=`動きを減らす：${motion?'入':'切'}`;$('motion-setting').setAttribute('aria-pressed',motion);
}
function playTone(kind) {
  if(!sound)return;
  try {
    audio??=new (window.AudioContext||window.webkitAudioContext)();audio.resume();
    const notes=kind==='clear'?[392,494,587]:kind==='connect'?[440,554]:[330];
    notes.forEach((f,i)=>{const oscillator=audio.createOscillator(),gain=audio.createGain(),t=audio.currentTime+i*.09;oscillator.type='sine';oscillator.frequency.value=f;gain.gain.setValueAtTime(.0001,t);gain.gain.exponentialRampToValueAtTime(.07,t+.015);gain.gain.exponentialRampToValueAtTime(.0001,t+.18);oscillator.connect(gain);gain.connect(audio.destination);oscillator.start(t);oscillator.stop(t+.19);});
  } catch { sound=false;updateSettings(); }
}

function sourceLink(url,label) {
  try {const parsed=new URL(url);if(parsed.protocol!=='https:'||parsed.username||parsed.password)return '';return `<a href="${escape(parsed.href)}" target="_blank" rel="noopener noreferrer">${escape(label)} ↗</a>`;}catch{return '';}
}
async function loadHistory() {
  try {
    const response=await fetch('./data/history.json');if(!response.ok)throw new Error('History unavailable');
    const data=await response.json();
    if(data.version!==1||!Array.isArray(data.phases)||data.phases.length!==3||data.phases.some((p,i)=>p.year!==PHASES[i].year||!Array.isArray(p.statistics)||!Array.isArray(p.events)||typeof p.gameNote!=='string'))throw new Error('History incomplete');
    for(const phase of data.phases){
      if(phase.statistics.some(s=>s.year!==phase.year||!Number.isFinite(s.value)||Number(s.raw)!==s.value||!/^\d{10}$/.test(s.tableId)||!Array.isArray(s.notes)||!s.notes.every(n=>typeof n==='string')||['title','scope','unit','url','checkedAt'].some(k=>typeof s[k]!=='string')))throw new Error('Statistics incomplete');
      if(phase.events.some(e=>['title','description','date','url','institution','locator'].some(k=>typeof e[k]!=='string')))throw new Error('Event incomplete');
    }
    sourceData=data;sourceError=false;if(screen==='game')$('history-teaser').textContent=data.phases[state.phase].events[0]?.title??'史実と数字から';
  }catch{sourceError=true;}
  if($('history-dialog').open)renderHistory();
}
function renderHistory() {
  const p=sourceData?.phases[state.phase];
  $('history-title').textContent=p?`${p.year}年 — ${p.title}`:'この町と時代について';
  if(!p) {$('history-body').innerHTML=`<p>${sourceError?'時代の資料をひらけませんでした。町はこのまま遊べます。':'時代の資料をひらいています…'}</p>${sourceError?'<button id="retry-history">もう一度ひらく</button>':''}`;return;}
  $('history-body').innerHTML=`<p>${escape(p.summary)}</p><div class="history-rule"><strong>この町のこと</strong><p>${escape(p.gameNote)}</p></div><h3>そのころの日本</h3>${p.events.map(e=>`<article><h4>${escape(e.title)}</h4><p>${escape(e.date)} ／ ${escape(e.description)}</p><p class="source-meta">${escape(e.institution)}・${escape(e.locator)}</p><p class="source-meta">${escape(e.qualification)}</p>${sourceLink(e.url,'出典をひらく')}</article>`).join('')}<h3>社会の数字</h3>${p.statistics.length?p.statistics.map(s=>`<article><div class="stat-fact"><span>${escape(s.title)}</span><strong>${escape(s.raw)}</strong><small>${escape(s.unit)}</small></div><p class="source-meta">${escape(s.year)}年 ／ ${escape(s.scope)}</p><p class="source-meta">${escape(s.institution)}・表 ${escape(s.tableId)} ／ 確認 ${escape(String(s.checkedAt).slice(0,10))}</p><ul>${(s.notes??[]).map(n=>`<li>${escape(n)}</li>`).join('')}</ul>${sourceLink(s.url,'e-Statの統計表をひらく')}</article>`).join(''):'<p>この場面で使う全国値は、ここでは紹介していません。</p>'}<p class="source-meta spaced">全国の数字と、この町の住民は別のものです。現実の町の将来を予測するゲームではありません。</p>`;
}

document.addEventListener('click',event=>{
  const button=event.target.closest('button');
  if(button?.dataset.close!==undefined){closeDialog(button.closest('dialog'));return;}
  if(button?.dataset.action==='history'){renderHistory();openDialog('history-dialog');return;}
  if(button?.dataset.action==='title'){persist();showScreen('title');return;}
  if(button?.dataset.tool){tool=button.dataset.tool;lastBuilt=null;render();return;}
  if(button?.id==='confirm-build'){commitBuild();return;}
  if(button?.id==='retry-history'){sourceError=false;renderHistory();loadHistory();return;}
  const cell=event.target.closest('.map-cell');
  if(cell)selectCell(Number(cell.dataset.x),Number(cell.dataset.y));
});
$('new-game').addEventListener('click',()=>{if(hasSavedProgress()){restartKind='new';$('restart-title').textContent='新しい町をつくりますか。';$('restart-copy').textContent='保存してある町の続きは、新しい町に置き換わります。';openDialog('restart-dialog');}else newGame();});
$('resume-game').addEventListener('click',()=>{if(!saved)return;state=clone(saved.state);chapterStart=clone(saved.chapterStart);undoStack=clone(saved.undo);history=clone(saved.history);sound=saved.sound;motion=saved.motion;selected=null;tool=state.phase===0?'shop':state.phase===1?'bridge':'clinic';showScreen(state.completed?'result':'game');});
$('undo-button').addEventListener('click',()=>{if(!undoStack.length)return;state=undoStack.pop();selected=null;lastBuilt=null;render();persist();notify('一手戻しました。別の場所も試せます。');});
$('restart-chapter').addEventListener('click',()=>{restartKind='chapter';$('restart-title').textContent=`${PHASES[state.phase].year}年をやり直しますか。`;$('restart-copy').textContent='この年代で建てたものを戻します。前の年代の町は残ります。';openDialog('restart-dialog');});
$('confirm-restart').addEventListener('click',()=>{closeDialog($('restart-dialog'));if(restartKind==='new')newGame();else{state=clone(chapterStart);undoStack=[];selected=null;lastBuilt=null;tool=state.phase===0?'shop':state.phase===1?'bridge':'clinic';focused=state.phase===0?{x:2,y:1}:state.phase===1?{x:5,y:3}:{x:3,y:2};render();persist();notify('この年代のはじめに戻りました。');}});
$('finish-era').addEventListener('click',finishEra);$('advance-era').addEventListener('click',advanceEra);
$('pause-button').addEventListener('click',()=>openDialog('pause-dialog'));
$('continue-game').addEventListener('click',()=>closeDialog($('pause-dialog')));
$('return-title').addEventListener('click',()=>{closeDialog($('pause-dialog'));persist();showScreen('title');});
$('sound-setting').addEventListener('click',()=>{sound=!sound;updateSettings();persist();playTone('build');});
$('motion-setting').addEventListener('click',()=>{motion=!motion;updateSettings();persist();if(screen==='game')render();});
$('play-again').addEventListener('click',()=>{restartKind='new';$('restart-title').textContent='別の町をつくりますか。';$('restart-copy').textContent='完成した町の保存を、新しい町に置き換えます。';openDialog('restart-dialog');});
$('view-town').addEventListener('click',()=>showScreen('game'));
document.querySelectorAll('dialog').forEach(dialog=>dialog.addEventListener('close',()=>{if(!document.querySelector('dialog[open]'))$('app').classList.remove('is-paused');syncMotion();}));
$('zoom-map').addEventListener('click',()=>{const zoomed=$('map-scroll').classList.toggle('zoomed');$('zoom-map').setAttribute('aria-pressed',zoomed);$('zoom-map').textContent=zoomed?'－ 全体を見る':'＋ 拡大';if(zoomed)$('map-scroll').scrollLeft=120;});
$('town-map').addEventListener('keydown',event=>{
  const dirs={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]};
  if(dirs[event.key]){event.preventDefault();const [dx,dy]=dirs[event.key];focused={x:Math.max(0,Math.min(WIDTH-1,focused.x+dx)),y:Math.max(0,Math.min(HEIGHT-1,focused.y+dy))};const cell=$('town-map').querySelector(`[data-x="${focused.x}"][data-y="${focused.y}"]`);$('town-map').querySelectorAll('[tabindex]').forEach(el=>el.setAttribute('tabindex',el===cell?'0':'-1'));cell?.focus({preventScroll:true});}
  if(event.key==='Enter'||event.key===' '){
    event.preventDefault();
    if(selected?.x===focused.x&&selected?.y===focused.y&&(tool==='erase'||!state.tiles.some(t=>t.x===focused.x&&t.y===focused.y))){commitBuild();$('town-map').querySelector(`[data-x="${focused.x}"][data-y="${focused.y}"]`)?.focus({preventScroll:true});}
    else selectCell(focused.x,focused.y,true);
  }
});
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!document.querySelector('dialog[open]')&&screen==='game'){event.preventDefault();openDialog('pause-dialog');}});
document.addEventListener('visibilitychange',()=>{if(document.hidden){$('app').classList.add('is-paused');audio?.suspend();}else if(!document.querySelector('dialog[open]')){$('app').classList.remove('is-paused');}syncMotion();});
window.addEventListener('blur',()=>{if(screen==='game'&&!document.querySelector('dialog[open]'))openDialog('pause-dialog');});

saved=loadSave();if(saved){sound=saved.sound;motion=saved.motion;}
cover();updateSettings();$('boot').hidden=true;$('app').hidden=false;showScreen('title');loadHistory();
