import './style.css';
import { createWorld, restoreWorld, serializeWorld, advanceWorld } from './simulation.ts';
import { TownRenderer } from './renderer.ts';
import { queuePower, cancelPendingPowers } from './disasters.ts';
import { DAY_SECONDS, SIM_STEP } from './constants.ts';
import type { Camera, CellKind, Point, World, PowerKind, NaturalPolicy, RenderOptions } from './types.ts';

const STORAGE_KEY = 'machi-no-kokyu:v1';
const CHECKPOINT_KEY = 'machi-no-kokyu:intervention-backup';
const POWER_NAMES: Record<PowerKind,string> = {rain:'恵みの雨',sun:'日差し',storm:'嵐',lightning:'雷',earthquake:'地震',meteor:'隕石',growth:'芽吹き',settle:'入植'};
const POWER_DESCRIPTIONS: Record<PowerKind,string> = {rain:'土を潤し、火を消します。降らせすぎると低い土地が浸水します。',sun:'雨雲を払い、地面を乾かします。長い日照りは作物を弱らせます。',storm:'風と豪雨で木や屋根を傷めます。増水した橋が暮らしを分断することも。',lightning:'選んだ場所に雷を落とします。乾いた木や建物には火が残ります。',earthquake:'建物と橋が傷み、避難や修繕が必要になります。',meteor:'着弾した土地をえぐり、周囲へ火と損傷が広がります。終末では町全体が対象です。',growth:'土と緑の再生を助けます。人や建物は自動では復活しません。',settle:'食と道具を持った入植者を迎えます。危険な土地では定住できません。'};
const SEASONS = ['春', '夏', '秋', '冬'];
const KIND_NAMES: Record<CellKind, string> = { grass: '草の広場', tree: '木々のある場所', water: '町を流れる川', road: '暮らしをつなぐ道', house: '住まい', shop: 'ご近所のお店', farm: '小さな農地', factory: '町の工場', ruin: '空き家', park: '緑の公園' };
const KIND_ICONS: Record<CellKind, string> = { grass: '♧', tree: '♧', water: '≈', road: '╋', house: '⌂', shop: '▤', farm: '▥', factory: '▥', ruin: '⌂', park: '♧' };

function element<T extends HTMLElement = HTMLElement>(id: string): T {
  const node = document.getElementById(id);
  if (!node) throw new Error(`Missing interface element: ${id}`);
  return node as T;
}

const canvas = element<HTMLCanvasElement>('town');
const pauseButton = element<HTMLButtonElement>('pause');
const photoButton = element<HTMLButtonElement>('photo');
const undoButton = element<HTMLButtonElement>('undo');
const status = element('save-status');
const notification = element('notification');
const chartLine = document.getElementById('chart-line')!;
const chartFill = document.getElementById('chart-fill')!;
const chart = document.getElementById('population-chart')!;
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const speedButtons = [...document.querySelectorAll<HTMLButtonElement>('[data-speed]')];

let world: World;
let restoreMessage = '';
let storageError = false;
let preserveOriginal = false;
try {
  const saved = localStorage.getItem(STORAGE_KEY);
  if (saved) {
    try {
      world = restoreWorld(saved);
      if (JSON.parse(saved).version < 3 && !localStorage.getItem('machi-no-kokyu:pre-v02')) {
        try { localStorage.setItem('machi-no-kokyu:pre-v02', saved); }
        catch { preserveOriginal = true; }
      }
      restoreMessage = world.legacyCalendar ? '前の町をv0.2へ引き継ぎました。人口と地形を保ち、食の備蓄と移行猶予を補っています。' : '前に眺めていた町の続きをひらきました。';
    } catch {
      try { localStorage.setItem('machi-no-kokyu:unreadable-backup', saved); } catch { preserveOriginal = true; }
      world = createWorld(4821);
      restoreMessage = '以前の記録は退避しました。読み込めなかったため、新しい町をひらきました。';
    }
  } else {
    world = createWorld(4821);
  }
} catch {
  world = createWorld(4821);
  storageError = true;
  restoreMessage = 'このブラウザでは町を保存できません。このまま観察は続けられます。';
}

let camera: Camera = { zoom: 1, panX: 0, panY: 0 };
let selected: Point | null = null;
let paused = reducedMotion.matches;
let speed = 1;

let visualTime = world.clock + world.remainder;
let lastFrame = 0;
let lastRender = 0;
let lastSavedClock = -1;
let lastSavedAt = 0;
let previousTown: string | null = null;
let previousInterventionBackup: string | null = null;
let previousVisualTime = 0;
let previousPaused = false;
let renderer: TownRenderer;
let fatal = false;
let followedResident: number | null = null;
let followCamera = false;
let showRoutes = false;
let lastLifeUpdate = 0;

let chosenPower: PowerKind | null = null;
let mapLayer: RenderOptions['layer'] = 'none';
let interventionBackup: string | null = null;
try {
  const candidate = localStorage.getItem(CHECKPOINT_KEY);
  if (candidate) {
    const saved = JSON.parse(candidate);
    if (saved.seed === world.seed && saved.size === world.size) interventionBackup = candidate;
  }
} catch { /* saving has its own visible state */ }
const radiusControl = element<HTMLSelectElement>('power-radius');
const intensityControl = element<HTMLSelectElement>('power-intensity');
const durationControl = element<HTMLSelectElement>('power-duration');
const policyControl = element<HTMLSelectElement>('natural-policy');
policyControl.value = world.naturalPolicy;
function powerIntensity(): number { return Number(intensityControl.value); }
function powerRadius(): number {
  return chosenPower === 'meteor' && powerIntensity() === 4 || Number(radiusControl.value) === 96
    ? Math.ceil(Math.hypot(world.size, world.size)) : Number(radiusControl.value);
}
function setText(id: string, value: string): void {
  const node = element(id);
  if (node.textContent !== value) node.textContent = value;
}
function updateGodUI(): void {
  element('power-settings').hidden = chosenPower === null;
  intensityControl.parentElement!.hidden = chosenPower === 'settle';
  durationControl.parentElement!.hidden = chosenPower !== null && ['lightning','earthquake','meteor','settle'].includes(chosenPower);
  element<HTMLSelectElement>('power-picker').value = chosenPower ?? 'observe';
  element('observe').setAttribute('aria-pressed', String(chosenPower === null));
  for (const button of document.querySelectorAll<HTMLButtonElement>('[data-power]')) button.setAttribute('aria-pressed', String(button.dataset.power === chosenPower));
  intensityControl.options[3].textContent = chosenPower === 'meteor' ? '終末（町全体）' : '最大';
  element('power-description').textContent = chosenPower ? POWER_DESCRIPTIONS[chosenPower] : '';
  element<HTMLButtonElement>('apply-power').disabled = !chosenPower || !selected;
  const total = world.pending.length;
  setText('pending-count', total ? `${total}件の力を予約中 · ${paused ? '一歩進めるか、時間を再開すると適用します' : '次の一歩で適用します'}` : '予約はありません');
  element<HTMLButtonElement>('cancel-powers').disabled = !total;
  element<HTMLButtonElement>('restore-intervention').disabled = !interventionBackup;
  element('extinction-note').hidden = world.residents.length > 0;
  const active = world.effects.filter(e => ['rain','sun','storm','growth'].includes(e.kind));
  element('active-powers').hidden = active.length === 0;
  const names = [...new Set(active.map(e=>e.kind))].map(kind=>{ const group=active.filter(e=>e.kind===kind); return `${POWER_NAMES[kind]}${group.length>1 ? ` ×${group.length}` : ''}（最長${Math.ceil(Math.max(...group.map(e=>e.remaining)))}秒）`; });
  setText('active-powers', `町の時間で続く力：${names.join('、')}`);
  if (chosenPower && selected) {
    const radius = powerRadius();
    const affected = world.cells.filter(c => Math.hypot(c.x-selected!.x,c.y-selected!.y) <= radius);
    const homes = affected.filter(c=>c.kind==='house').length;
    const farms = affected.filter(c=>c.kind==='farm').length;
    const bridges = affected.filter(c=>c.kind==='road' && c.terrain==='water').length;
    setText('power-target', `${selected.x+1}, ${selected.y+1} · 直接の範囲: 住まい${homes}軒 / 畑${farms}枚 / 橋${bridges}本。${chosenPower==='meteor' && powerIntensity()===4 ? '終末規模。町の全人口・建物を失う力です。' : chosenPower==='settle' && (world.cells[selected.y*world.size+selected.x].fire > 0 || world.cells[selected.y*world.size+selected.x].waterDepth >= 1.6) ? '危険な場所です。安全な土地を選び直してください。' : '地図上の範囲を確かめてください。二次被害はその後の暮らしで変わります。'}`);
  } else setText('power-target', '地図で場所を選んでください。矢印キーでも選べます。');
}
function checkpointIntervention(before: World): void {
  // All commands applied at this boundary share one undo point. No replay after restore.
  const snapshot = serializeWorld({...before, pending:[], remainder:0});
  interventionBackup = snapshot;
  try { localStorage.setItem(CHECKPOINT_KEY, snapshot); }
  catch { notify('介入前の町はこの画面に保持していますが、再読み込み後の復元点を保存できませんでした。', true); }
}
function choosePower(nextPower: PowerKind | null): void {
  if (nextPower === 'meteor' && chosenPower !== 'meteor' && intensityControl.value === '4') intensityControl.value = '1';
  chosenPower = nextPower;
  if (nextPower) { followedResident = null; followCamera = false; }
  updateLife(); updateGodUI(); draw();
}
for (const button of document.querySelectorAll<HTMLButtonElement>('[data-power]')) button.addEventListener('click',()=>choosePower(button.dataset.power as PowerKind));
element('observe').addEventListener('click',()=>choosePower(null));
element<HTMLSelectElement>('power-picker').addEventListener('change',event=>{
  const value = (event.target as HTMLSelectElement).value;
  choosePower(value === 'observe' ? null : value as PowerKind);
});
for (const control of [radiusControl,intensityControl,durationControl]) control.addEventListener('change',()=>{updateGodUI();draw();});
element('apply-power').addEventListener('click',()=>{
  if (!chosenPower || !selected) return;
  try {
    queuePower(world,{kind:chosenPower,target:{...selected},radius:powerRadius(),intensity:powerIntensity(),duration:Number(durationControl.value)});
    notify(`${POWER_NAMES[chosenPower]}を予約しました。${paused ? '「一歩進める」か時間の再開で適用します。' : '次の一歩で町に届きます。'}`);
    updateGodUI();saveTown();draw();
  } catch { notify('その場所には力を使えません。設定や場所を選び直してください。',true); }
});
element('cancel-powers').addEventListener('click',()=>{cancelPendingPowers(world);updateGodUI();saveTown();draw();notify('まだ適用していない予約を取り消しました。');});
element('step-once').addEventListener('click',()=>{
  paused=true;lastFrame=0;
  try {
    advanceWorld(world,SIM_STEP,checkpointIntervention);visualTime=world.clock + world.remainder;
    updateUI();saveTown();draw();
  } catch { notify('町の時間を進められませんでした。現在の記録を保ったまま停止しています。',true); }
});
element('restore-intervention').addEventListener('click',()=>{
  if(!interventionBackup) return;
  try {
    world=restoreWorld(interventionBackup);paused=true;lastFrame=0;visualTime=world.clock + world.remainder;
    policyControl.value=world.naturalPolicy;followedResident=null;followCamera=false;selected=null;
    updateUI();saveTown();draw();notify('前の介入の適用前へ戻りました。その後の未来も巻き戻しています。');
  } catch {notify('復元点を読み込めませんでした。現在の町は保っています。',true);}
});
policyControl.addEventListener('change',()=>{world.naturalPolicy=policyControl.value as NaturalPolicy;saveTown();updateGodUI();});
element<HTMLSelectElement>('map-layer').addEventListener('change',event=>{mapLayer=(event.target as HTMLSelectElement).value as RenderOptions['layer'];draw();});

function notify(message: string, error = false): void {
  notification.textContent = message;
  notification.classList.toggle('error', error);
  notification.hidden = false;
}

function saveTown(): void {
  lastSavedAt = performance.now();
  try {
    if (preserveOriginal) throw new Error('Original record must be preserved');
    localStorage.setItem(STORAGE_KEY, serializeWorld(world));
    status.textContent = `このブラウザに記録済み · ${Math.floor(world.tick / 48) + 1}年目`;
    status.parentElement!.classList.remove('error');
    storageError = false;
    lastSavedClock = world.clock;
  } catch {
    storageError = true;
    status.textContent = preserveOriginal ? '元の記録を保護しています · 今の町は保存されません' : '保存できません · このまま観察は続けられます';
    status.parentElement!.classList.add('error');
  }
}

function dateText(tick: number): string {
  return `${Math.floor(tick / 48) + 1}年目 ${SEASONS[Math.floor(tick / 12) % 4]} ${tick % 12 + 1}日`;
}

function updateInspection(): void {
  const details = element('cell-details');
  if (!selected) {
    element('cell-connections').hidden = true;
    element('cell-coordinates').textContent = '観察ノート';
    element('cell-name').textContent = '小さな暮らしを、見つける。';
    element('cell-subtitle').textContent = '建物や土地を選んでみてください';
    element('building-icon').textContent = '⌂';
    element('cell-reason').textContent = '家が増えるのにも、店が閉まるのにも、理由があります。近所とのつながりをのぞいてみましょう。';
    element('inspection-footnote').textContent = '道がつながると、暮らしもつながります。';
    details.hidden = true;
    return;
  }
  const cell = world.cells[selected.y * world.size + selected.x];
  const bridge = cell.kind === 'road' && cell.terrain === 'water';
  element('cell-coordinates').textContent = `${cell.x + 1}, ${cell.y + 1}`;
  element('cell-name').textContent = bridge ? '川を渡る橋' : KIND_NAMES[cell.kind];
  element('building-icon').textContent = KIND_ICONS[cell.kind];
  const natural = ['grass', 'tree', 'water', 'road', 'park'].includes(cell.kind);
  element('cell-subtitle').textContent = natural ? (bridge ? '川の向こうの暮らしへ' : 'この場所も、町の一部です') : cell.kind === 'ruin' ? '次の暮らしを待つ場所' : `成長段階 ${cell.level} · ${cell.vitality >= 60 ? '元気に育っています' : cell.vitality >= 30 ? 'ゆっくり暮らしています' : '少し元気をなくしています'}`;
  element('cell-reason').textContent = cell.reason;
  const connections = element('cell-connections');
  connections.hidden = false;
  const inhabitants = world.residents.filter(resident => resident.home === selected!.y * world.size + selected!.x);
  const assignedWorkers = world.residents.filter(resident => resident.workplace === selected!.y * world.size + selected!.x).length;
  connections.textContent = cell.kind === 'house'
    ? `${cell.accessible ? '道につながっています' : '道への出口がありません'} · 働き先のある人 ${inhabitants.filter(resident => resident.workplace !== null).length} / ${inhabitants.length}人`
    : cell.kind === 'shop' ? `働き先にする人 ${assignedWorkers}人 · 最近の買い物 ${Math.round(cell.customers)}回（時間とともに減衰）`
    : cell.kind === 'factory' ? `働き先にする人 ${assignedWorkers}人 · 建物の状態 ${Math.round(cell.condition)} / 100`
    : cell.kind === 'farm' ? `水分 ${Math.round(cell.moisture)} · 土の力 ${Math.round(cell.fertility)} · 作物の生育 ${Math.round(cell.crop)} / 100`
    : cell.kind === 'grass' || cell.kind === 'tree' || cell.kind === 'park' ? `水分 ${Math.round(cell.moisture)} · 土の力 ${Math.round(cell.fertility)} · 緑の回復 ${Math.round(cell.vegetation)} / 100`
    : cell.kind === 'road' ? `最近の人通り ${Math.round(cell.traffic)} / 100` : cell.kind === 'ruin' ? '草が育ち、土と緑が回復するのを待っています。' : '雨が川と岸辺の土をうるおします。';
  element('detail-label').textContent = cell.kind === 'house' ? '暮らす人' : '成長段階';
  element('cell-population').textContent = cell.kind === 'house' ? `${cell.population}人` : natural || cell.kind === 'ruin' ? '—' : `${cell.level}`;
  element('cell-age').textContent = natural ? '—' : cell.age < 48 ? `${Math.floor(cell.age)}日` : `${(cell.age / 48).toFixed(1)}年`;
  element('cell-vitality').textContent = natural || cell.kind === 'ruin' ? '—' : `${Math.round(cell.vitality)} / 100`;
  element('cell-environment').textContent = `${Math.round(cell.environment)} / 100`;
  element('inspection-footnote').textContent = `この場所の変化 · ${dateText(cell.changedAt)}`;
  connections.textContent += ` · 食 ${Math.round(cell.stock)} / 資材 ${Math.round(cell.materials)} · 状態 ${Math.round(cell.condition)} · 浸水 ${cell.waterDepth.toFixed(1)}${cell.closed ? ' · 通行止め・休業' : ''}`;
  details.hidden = false;
}

function updateChart(): void {
  const points = world.history;
  if (!points.length) return;
  const max = Math.max(20, ...points.map(point => point.population)) * 1.15;
  const coordinates = points.map((point, index) => `${(index / Math.max(1, points.length - 1) * 296 + 2).toFixed(1)},${(65 - point.population / max * 56).toFixed(1)}`);
  const line = coordinates.length === 1 ? `M${coordinates[0]} L298,${coordinates[0].split(',')[1]}` : `M${coordinates.join(' L')}`;
  chartLine.setAttribute('d', line);
  chartFill.setAttribute('d', `${line} L298,65 L2,65 Z`);
  const first = points[0];
  const last = points[points.length - 1];
  chart.setAttribute('aria-label', `人口の推移。${dateText(first.tick)}の${first.population}人から、現在${last.population}人。`);
  element('history-range').textContent = points.length < 2 ? 'はじまり' : `${first.tick === 0 ? 'はじまり' : `${Math.floor(first.tick / 48) + 1}年目`} → ${Math.floor(last.tick / 48) + 1}年目`;
}

function selectCell(point: Point | null, focus = false): void {
  followCamera = false;
  selected = point;
  if (point && focus && camera.zoom > 1) camera = renderer.focus(point, world, camera);
  updateInspection();
  updateGodUI();
  draw();
}

function updateJournal(): void {
  const list = element<HTMLOListElement>('events');
  const entries = world.events.slice(-4).reverse();
  list.replaceChildren();
  if (!entries.length) {
    const row = document.createElement('li');
    row.className = 'empty-event';
    row.textContent = 'この町の物語が、ここから始まります。';
    list.append(row);
  }
  for (const entry of entries) {
    const row = document.createElement('li');
    const time = document.createElement('time');
    time.textContent = dateText(entry.tick);
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = entry.text;
    button.setAttribute('aria-label', `${entry.text}。場所を観察する`);
    button.addEventListener('click', () => selectCell({ x: entry.x, y: entry.y }, true));
    row.append(time, button);
    list.append(row);
  }
}

function updateControls(): void {
  pauseButton.setAttribute('aria-pressed', String(paused));
  element('pause-label').textContent = paused ? '時間を進める' : '一時停止';
  element('pause-icon').textContent = paused ? '▷' : 'Ⅱ';
  element('view-state').textContent = paused ? '時間をとめています' : `時間が流れています${speed === 1 ? '' : ` · ${speed}×`}`;
  element('live-dot').classList.toggle('paused', paused);
  for (const button of speedButtons) button.setAttribute('aria-pressed', String(Number(button.dataset.speed) === speed));
  element('zoom-label').textContent = `${Math.round(camera.zoom * 100)}%`;
  element<HTMLButtonElement>('zoom-out').disabled = camera.zoom <= .75;
  element<HTMLButtonElement>('zoom-in').disabled = camera.zoom >= 3;
}

function updateUI(): void {
  element('calendar').textContent = `${Math.floor(world.tick / 48) + 1}年目・${SEASONS[Math.floor(world.tick / 12) % 4]}`;
  element('week').textContent = `${world.tick % 12 + 1}日`;
  element('population').textContent = world.stats.population.toLocaleString('ja-JP');
  element('homes').textContent = `${world.stats.homes}`;
  element('shops').textContent = `${world.stats.shops}`;
  element('environment').textContent = `${Math.round(world.stats.environment)}`;
  element('seed-label').textContent = `町の種 ${world.seed}`;
  policyControl.value=world.naturalPolicy;
  updateInspection();
  updateChart();
  updateJournal();
  updateControls();
  updateLife();
  updateGodUI();
}

function locationName(index: number | null): string {
  if (index === null) return 'まだ決まっていません';
  const cell = world.cells[index];
  return `${KIND_NAMES[cell.kind]}（${cell.x + 1}, ${cell.y + 1}）`;
}

function updateLife(): void {
  const moving = world.residents.filter(resident => resident.state === 'travel').length;
  element('activity-label').textContent = `${moving}人が道を歩いています`;
  element('employment').textContent = `${world.economy.employed} / ${world.economy.workers}人`;
  element('food').textContent = `${Math.round(world.economy.food)}食`;
  element('visits').textContent = `${world.economy.visits}回`;
  element('weather-label').textContent = `${{clear:'晴れ',cloudy:'曇り',rain:'雨',storm:'嵐',snow:'雪'}[world.weather.kind]} · ${Math.round(world.weather.temperature)}℃`;
  element('life-summary').textContent = `食が足りない人 ${world.economy.starving}人 · 避難中 ${world.economy.evacuated}人 · 修繕資材 ${Math.round(world.economy.materials)} · 移り住んだ人 ${world.economy.arrivals}人 / 転出 ${world.economy.departures}人 / 失われた暮らし ${world.economy.deaths}人`;
  const resident = world.residents.find(person => person.id === followedResident);
  element('resident-note').hidden = !resident;
  if (!resident) { followedResident = null; followCamera = false; return; }
  element('resident-name').textContent = `住民 ${resident.id + 1} の一日`;
  const purpose = { commute: '仕事へ', shopping: '買い物へ', stroll: '散歩へ', return: '家へ', refuge:'避難先へ', repair:'修繕へ' }[resident.purpose];
  element('resident-status').textContent = resident.state === 'wait' ? '道が通れず、安全な場所で待っています。' : resident.state === 'shelter' ? '避難先で、生活を立て直しています。' : resident.state === 'repair' ? '資材を使い、町を修繕しています。' : resident.state === 'travel' ? `${purpose}、道を歩いています。`
    : resident.state === 'work' ? '仕事場で、町の暮らしを支えています。'
    : resident.state === 'shop' ? 'お店で、今日の買い物をしています。'
    : resident.state === 'park' ? '緑のそばで、ひと休み。' : '家で次の外出を待っています。';
  element('resident-route').textContent = `住まい: ${locationName(resident.home)}。働き先: ${locationName(resident.workplace)}。${resident.state === 'travel' ? `行き先: ${locationName(resident.destination)}。` : ''}健康 ${Math.round(resident.health)} / 100。${resident.role === 'dependent' ? '暮らしを支えてもらう人。' : '働く人。'}到着した旅 ${resident.trips}回。`;
  element<HTMLButtonElement>('resident-destination').disabled = resident.destination === null;
}

function watchResident(id: number): void {
  followedResident = id;
  followCamera = true;
  showRoutes = true;
  element('routes').setAttribute('aria-pressed', 'true');
  const resident = world.residents.find(person => person.id === id);
  if (resident) {
    camera.zoom = Math.max(2, camera.zoom);
    camera = renderer.focus(resident, world, camera);
    selected = null;
  }
  updateInspection();
  updateControls();
  updateLife();
  draw();
}

function draw(): void {
  if (!renderer || fatal) return;
  const resident = world.residents.find(person => person.id === followedResident);
  if (followCamera && resident && !drag) camera = renderer.focus(resident, world, camera);
  renderer.render(world, { camera, selected, time: visualTime, reducedMotion: reducedMotion.matches, followedResident, showRoutes, layer: mapLayer, preview: chosenPower && selected ? {kind:chosenPower,center:selected,radius:powerRadius(),intensity:powerIntensity()} : null });
  const phase = visualTime % DAY_SECONDS / DAY_SECONDS;
  element('time-of-day').textContent = phase < .1 || phase >= .88 ? '朝の景色' : phase < .45 ? '昼の景色' : phase < .58 ? '夕方の景色' : '夜の景色';
}

function togglePause(): void {
  paused = !paused;
  lastFrame = 0;
  updateControls();
  updateGodUI();
  saveTown();
  draw();
}

function zoomTo(value: number, anchor?: Point): void {
  const zoom = Math.max(.75, Math.min(3, value));
  const ratio = zoom / camera.zoom;
  const center = anchor ?? { x: canvas.width / 2, y: canvas.height / 2 };
  camera.panX = (camera.panX - center.x + canvas.width / 2) * ratio + center.x - canvas.width / 2;
  camera.panY = (camera.panY - center.y + canvas.height / 2) * ratio + center.y - canvas.height / 2;
  camera.zoom = zoom;
  updateControls();
  draw();
}

pauseButton.addEventListener('click', togglePause);
for (const button of speedButtons) button.addEventListener('click', () => {
  speed = Number(button.dataset.speed);
  updateControls();
});
element('zoom-in').addEventListener('click', () => zoomTo(camera.zoom + .25));
element('zoom-out').addEventListener('click', () => zoomTo(camera.zoom - .25));
element('fit').addEventListener('click', () => {
  followCamera = false;
  camera = { zoom: 1, panX: 0, panY: 0 };
  updateControls();
  draw();
});
element('watch-resident').addEventListener('click', () => {
  const moving = world.residents.filter(person => person.state === 'travel');
  const candidates = moving.length ? moving : world.residents;
  if (!candidates.length) { notify('今は町に外へ出る住民がいません。時間を進めてみてください。'); return; }
  const index = candidates.findIndex(person => person.id === followedResident);
  watchResident(candidates[(index + 1) % candidates.length].id);
});
element('routes').addEventListener('click', () => {
  showRoutes = !showRoutes;
  element('routes').setAttribute('aria-pressed', String(showRoutes));
  draw();
});
element('stop-follow').addEventListener('click', () => {
  followedResident = null;
  followCamera = false;
  updateLife();
  draw();
});
element('resident-home').addEventListener('click', () => {
  const resident = world.residents.find(person => person.id === followedResident);
  if (resident) selectCell(world.cells[resident.home], true);
});
element('resident-destination').addEventListener('click', () => {
  const resident = world.residents.find(person => person.id === followedResident);
  if (resident?.destination !== null && resident?.destination !== undefined) selectCell(world.cells[resident.destination], true);
});

let drag: { id: number; x: number; y: number; panX: number; panY: number; moved: boolean } | null = null;
canvas.addEventListener('pointerdown', event => {
  if (!event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0)) return;
  canvas.focus({ preventScroll: true });
  canvas.setPointerCapture(event.pointerId);
  drag = { id: event.pointerId, x: event.clientX, y: event.clientY, panX: camera.panX, panY: camera.panY, moved: false };
});
canvas.addEventListener('pointermove', event => {
  if (!drag || drag.id !== event.pointerId) return;
  if (Math.hypot(event.clientX - drag.x, event.clientY - drag.y) > 6) drag.moved = true;
  if (!drag.moved) return;
  followCamera = false;
  const rect = canvas.getBoundingClientRect();
  camera.panX = Math.max(-canvas.width * camera.zoom, Math.min(canvas.width * camera.zoom, drag.panX + (event.clientX - drag.x) * canvas.width / rect.width));
  camera.panY = Math.max(-canvas.height * camera.zoom, Math.min(canvas.height * camera.zoom, drag.panY + (event.clientY - drag.y) * canvas.height / rect.height));
  canvas.classList.add('dragging');
  draw();
});
canvas.addEventListener('pointerup', event => {
  if (!drag || drag.id !== event.pointerId) return;
  if (!drag.moved) {
    const resident = chosenPower ? null : renderer.pickResident(event.clientX, event.clientY, world, camera);
    if (resident !== null) watchResident(resident);
    else selectCell(renderer.pick(event.clientX, event.clientY, world, camera));
  }
  drag = null;
  canvas.classList.remove('dragging');
});
canvas.addEventListener('pointercancel', () => { drag = null; canvas.classList.remove('dragging'); });
canvas.addEventListener('lostpointercapture', () => { drag = null; canvas.classList.remove('dragging'); });
canvas.addEventListener('wheel', event => {
  event.preventDefault();
  const rect = canvas.getBoundingClientRect();
  zoomTo(camera.zoom + (event.deltaY > 0 ? -.15 : .15), { x: (event.clientX - rect.left) / rect.width * canvas.width, y: (event.clientY - rect.top) / rect.height * canvas.height });
}, { passive: false });
canvas.addEventListener('keydown', event => {
  if (event.key === ' ') { event.preventDefault(); togglePause(); }
  else if (event.key === '+' || event.key === '=') { event.preventDefault(); zoomTo(camera.zoom + .25); }
  else if (event.key === '-') { event.preventDefault(); zoomTo(camera.zoom - .25); }
  else if (event.key === 'Escape') { followedResident = null; chosenPower = null; selectCell(null); updateLife(); updateGodUI(); }
  else if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.key)) {
    event.preventDefault();
    const point = selected ?? { x: Math.floor(world.size / 2), y: Math.floor(world.size / 2) };
    const dx = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
    const dy = event.key === 'ArrowDown' ? 1 : event.key === 'ArrowUp' ? -1 : 0;
    selectCell({ x: Math.max(0, Math.min(world.size - 1, point.x + dx)), y: Math.max(0, Math.min(world.size - 1, point.y + dy)) }, true);
  }
});

element('regenerate').addEventListener('click', () => {
  try {
    const seed = crypto.getRandomValues(new Uint32Array(1))[0];
    const next = createWorld(seed);
    previousTown = serializeWorld(world);
    previousInterventionBackup = interventionBackup;
    previousVisualTime = visualTime;
    previousPaused = paused;
    world = next;
    followedResident = null;
    followCamera = false;
    selected = null;
    camera = { zoom: 1, panX: 0, panY: 0 };
    visualTime = world.clock + world.remainder;
    lastSavedClock = -1;
    interventionBackup = null;
    undoButton.hidden = false;
    updateUI();
    saveTown();
    draw();
    notify('別の小さな町をひらきました。「前の町に戻る」で直前の町へ戻れます。');
  } catch {
    notify('町をひらけませんでした。現在の町をそのまま眺められます。', true);
  }
});
undoButton.addEventListener('click', () => {
  if (!previousTown) return;
  try {
    world = restoreWorld(previousTown);
    followedResident = null;
    followCamera = false;
    visualTime = previousVisualTime;
    paused = previousPaused;
    selected = null;
    camera = { zoom: 1, panX: 0, panY: 0 };
    previousTown = null;
    interventionBackup = previousInterventionBackup;
    previousInterventionBackup = null;
    if (interventionBackup) { try {localStorage.setItem(CHECKPOINT_KEY,interventionBackup);} catch {notify('復元点は画面内に保持しています。',true);} }
    undoButton.hidden = true;
    lastSavedClock = -1;
    updateUI();
    saveTown();
    draw();
    notify('前の町に戻りました。');
  } catch {
    notify('前の町を読み込めませんでした。現在の町はそのままです。', true);
  }
});
photoButton.addEventListener('click', () => {
  photoButton.disabled = true;
  draw();
  canvas.toBlob(blob => {
    photoButton.disabled = false;
    if (!blob) { notify('写真を保存できませんでした。もう一度お試しください。', true); return; }
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `machi-${world.seed}-year-${Math.floor(world.tick / 48) + 1}.png`;
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
    notify('今の町の写真をPNGで保存しました。');
  }, 'image/png');
});

document.addEventListener('visibilitychange', () => {
  lastFrame = 0;
  if (document.hidden) saveTown();
});
document.addEventListener('freeze', () => { lastFrame = 0; saveTown(); });
document.addEventListener('resume', () => { lastFrame = 0; });
window.addEventListener('pagehide', saveTown);
reducedMotion.addEventListener('change', () => { draw(); });

function frame(timestamp: number): void {
  const delta = lastFrame ? Math.min(.25, Math.max(0, (timestamp - lastFrame) / 1000)) : 0;
  lastFrame = timestamp;
  if (!paused && !document.hidden && !fatal) {
    let changed = false;
    try {
      const oldDay = world.tick;
      const oldPending = world.pending.length;
      advanceWorld(world, delta * speed, checkpointIntervention);
      visualTime = world.clock + world.remainder;
      changed = oldDay !== world.tick || oldPending !== world.pending.length;
      if (changed) updateUI();
      if (timestamp - lastSavedAt >= 5000 && world.clock !== lastSavedClock) saveTown();
      if (timestamp - lastLifeUpdate > 500) { updateLife(); updateGodUI(); updateInspection(); lastLifeUpdate = timestamp; }
    } catch {
      paused = true;
      updateControls();
      notify('町の時間を進められなかったため停止しました。別の町をひらくと再開できます。', true);
    }
  }
  if (!document.hidden && timestamp - lastRender >= (reducedMotion.matches ? 100 : 33)) {
    try { draw(); } catch {
      fatal = true;
      paused = true;
      updateControls();
      notify('景色を描画できませんでした。ページを再読み込みしてください。', true);
    }
    lastRender = timestamp;
  }
  requestAnimationFrame(frame);
}

try {
  renderer = new TownRenderer(canvas);
  camera = renderer.focus({ x: Math.floor(world.size * .25), y: Math.floor(world.size * .52) - 1 }, world, { zoom: 1.5, panX: 0, panY: 0 });
  updateUI();
  draw();
  element('loading').hidden = true;
  saveTown();
  if (restoreMessage) notify(restoreMessage, storageError);
  requestAnimationFrame(frame);
} catch {
  fatal = true;
  element('loading').textContent = '景色をひらけませんでした。ページを再読み込みしてください。';
  notify('このブラウザでCanvasを利用できませんでした。別のブラウザでもお試しください。', true);
  for (const button of document.querySelectorAll<HTMLButtonElement>('button')) button.disabled = true;
}
