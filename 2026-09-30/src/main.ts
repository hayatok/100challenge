import './style.css';
import { createWorld, restoreWorld, serializeWorld, stepWorld } from './simulation.ts';
import { TownRenderer } from './renderer.ts';
import type { Camera, CellKind, Point, World } from './types.ts';

const STORAGE_KEY = 'machi-no-kokyu:v1';
const STEP_SECONDS = 2;
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
try {
  const saved = localStorage.getItem(STORAGE_KEY);
  if (saved) {
    try {
      world = restoreWorld(saved);
      restoreMessage = '前に眺めていた町の続きをひらきました。';
    } catch {
      world = createWorld(4821);
      restoreMessage = '記録を読み込めなかったため、新しい町をひらきました。';
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
let accumulator = 0;
let visualTime = world.tick * STEP_SECONDS;
let lastFrame = 0;
let lastRender = 0;
let lastSavedTick = -1;
let previousTown: string | null = null;
let previousVisualTime = 0;
let previousPaused = false;
let renderer: TownRenderer;
let fatal = false;

function notify(message: string, error = false): void {
  notification.textContent = message;
  notification.classList.toggle('error', error);
  notification.hidden = false;
}

function saveTown(): void {
  if (lastSavedTick === world.tick && !storageError) return;
  try {
    localStorage.setItem(STORAGE_KEY, serializeWorld(world));
    status.textContent = `このブラウザに記録済み · ${Math.floor(world.tick / 48) + 1}年目`;
    status.parentElement!.classList.remove('error');
    storageError = false;
    lastSavedTick = world.tick;
  } catch {
    storageError = true;
    status.textContent = '保存できません · このまま観察は続けられます';
    status.parentElement!.classList.add('error');
  }
}

function dateText(tick: number): string {
  return `${Math.floor(tick / 48) + 1}年目 ${SEASONS[Math.floor(tick / 12) % 4]} ${tick % 12 + 1}週`;
}

function updateInspection(): void {
  const details = element('cell-details');
  if (!selected) {
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
  element('detail-label').textContent = cell.kind === 'house' ? '暮らす人' : '成長段階';
  element('cell-population').textContent = cell.kind === 'house' ? `${cell.population}人` : natural || cell.kind === 'ruin' ? '—' : `${cell.level}`;
  element('cell-age').textContent = natural ? '—' : cell.age < 48 ? `${cell.age}週` : `${(cell.age / 48).toFixed(1)}年`;
  element('cell-vitality').textContent = natural || cell.kind === 'ruin' ? '—' : `${Math.round(cell.vitality)} / 100`;
  element('cell-environment').textContent = `${Math.round(cell.environment)} / 100`;
  element('inspection-footnote').textContent = `この場所の変化 · ${dateText(cell.changedAt)}`;
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
  selected = point;
  if (point && focus && camera.zoom > 1) camera = renderer.focus(point, world, camera);
  updateInspection();
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
  element('week').textContent = `${world.tick % 12 + 1}週`;
  element('population').textContent = world.stats.population.toLocaleString('ja-JP');
  element('homes').textContent = `${world.stats.homes}`;
  element('shops').textContent = `${world.stats.shops}`;
  element('environment').textContent = `${Math.round(world.stats.environment)}`;
  element('seed-label').textContent = `町の種 ${world.seed}`;
  updateInspection();
  updateChart();
  updateJournal();
  updateControls();
}

function draw(): void {
  if (!renderer || fatal) return;
  renderer.render(world, { camera, selected, time: visualTime, reducedMotion: reducedMotion.matches });
  const phase = visualTime % 150 / 150;
  element('time-of-day').textContent = phase < .2 || phase >= .8 ? '昼の景色' : phase < .3 ? '夕方の景色' : phase < .7 ? '夜の景色' : '朝の景色';
}

function togglePause(): void {
  paused = !paused;
  lastFrame = 0;
  updateControls();
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
  camera = { zoom: 1, panX: 0, panY: 0 };
  updateControls();
  draw();
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
  const rect = canvas.getBoundingClientRect();
  camera.panX = Math.max(-canvas.width * camera.zoom, Math.min(canvas.width * camera.zoom, drag.panX + (event.clientX - drag.x) * canvas.width / rect.width));
  camera.panY = Math.max(-canvas.height * camera.zoom, Math.min(canvas.height * camera.zoom, drag.panY + (event.clientY - drag.y) * canvas.height / rect.height));
  canvas.classList.add('dragging');
  draw();
});
canvas.addEventListener('pointerup', event => {
  if (!drag || drag.id !== event.pointerId) return;
  if (!drag.moved) selectCell(renderer.pick(event.clientX, event.clientY, world, camera));
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
  else if (event.key === 'Escape') selectCell(null);
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
    previousVisualTime = visualTime;
    previousPaused = paused;
    world = next;
    selected = null;
    camera = { zoom: 1, panX: 0, panY: 0 };
    accumulator = 0;
    visualTime = 0;
    lastSavedTick = -1;
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
    visualTime = previousVisualTime;
    paused = previousPaused;
    accumulator = 0;
    selected = null;
    camera = { zoom: 1, panX: 0, panY: 0 };
    previousTown = null;
    undoButton.hidden = true;
    lastSavedTick = -1;
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
    visualTime += delta * speed;
    accumulator += delta * speed;
    let changed = false;
    try {
      while (accumulator >= STEP_SECONDS) {
        world = stepWorld(world);
        accumulator -= STEP_SECONDS;
        changed = true;
      }
      if (changed) {
        updateUI();
        if (world.tick - lastSavedTick >= 5) saveTown();
      }
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
