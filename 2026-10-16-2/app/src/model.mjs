// Author rules for a fictional town. National statistics do not drive this model.
export const WIDTH = 9;
export const HEIGHT = 7;
export const TYPES = Object.freeze({
  road: Object.freeze({ label: '道', cost: 1, unlockPhase: 0 }),
  bridge: Object.freeze({ label: '橋', cost: 3, unlockPhase: 1 }),
  home: Object.freeze({ label: '家', cost: 3, unlockPhase: 0, residents: 3 }),
  shop: Object.freeze({ label: '商店', cost: 4, unlockPhase: 0, range: 4 }),
  workshop: Object.freeze({ label: '仕事場', cost: 5, unlockPhase: 0, range: 7, capacity: 6 }),
  clinic: Object.freeze({ label: '診療所', cost: 5, unlockPhase: 2, range: 3 }),
  park: Object.freeze({ label: '公園', cost: 3, unlockPhase: 2, range: 2 }),
});
export const PHASES = Object.freeze([
  Object.freeze({ year: 1955, title: '暮らしの土台', budget: 12, target: 6, tip: '商店を置いて買物を届け、家を1戸増やそう。' }),
  Object.freeze({ year: 1973, title: '川の向こうへ', budget: 17, target: 9, tip: '橋で両岸をつなぎ、新しい家にも買物と仕事を届けよう。' }),
  Object.freeze({ year: 2000, title: '近くにある安心', budget: 18, target: 12, tip: '家の近くに診療所と公園をつくろう。' }),
]);

const VERSION = 1;
const dirs = [[1, 0], [0, 1], [-1, 0], [0, -1]];
const key = ({ x, y }) => `${x},${y}`;
const isRoad = tile => tile.type === 'road' || tile.type === 'bridge';
const inside = (x, y) => Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT;
const copyTiles = tiles => tiles.map(tile => ({ ...tile }));
const fixedTiles = phase => [
  { x: 1, y: 2, type: 'home', paid: 0, fixed: true },
  { x: 3, y: 4, type: 'workshop', paid: 0, fixed: true },
  ...(phase >= 1 ? [{ x: 7, y: 2, type: 'home', paid: 0, fixed: true }] : []),
  ...(phase >= 2 ? [{ x: 7, y: 4, type: 'home', paid: 0, fixed: true }] : []),
];
const seedRoads = [{ x: 2, y: 2 }, { x: 2, y: 3 }, { x: 3, y: 3 }];

export function terrainAt(x, y) {
  if (!inside(x, y)) return 'outside';
  if (x === 5) return 'river';
  if (y === 0 && [0, 1, 8].includes(x)) return 'mountain';
  return 'land';
}

export function costOf(type, phase = 0) {
  if (!Object.hasOwn(TYPES, type)) return null;
  return type === 'shop' && phase >= 1 ? 5 : TYPES[type].cost;
}

export function createGame() {
  return {
    version: VERSION, phase: 0, budget: 12, completed: false, discarded: 0,
    tiles: [...fixedTiles(0), ...seedRoads.map(p => ({ ...p, type: 'road', paid: 0, fixed: false }))],
  };
}

// Buildings never act as shortcuts. Distance counts the road cells walked on,
// including the departure and arrival cells (one shared road has distance 1).
function roadPath(roads, from, target, maxDistance = WIDTH * HEIGHT) {
  const ends = new Set(dirs.map(([dx, dy]) => `${target.x + dx},${target.y + dy}`));
  const queue = [];
  const visited = new Set();
  for (const [dx, dy] of dirs) {
    const point = { x: from.x + dx, y: from.y + dy };
    if (roads.has(key(point))) { queue.push([point]); visited.add(key(point)); }
  }
  for (let i = 0; i < queue.length; i++) {
    const path = queue[i];
    const point = path.at(-1);
    if (path.length > maxDistance) continue;
    if (ends.has(key(point))) return { distance: path.length, path, target: { x: target.x, y: target.y } };
    if (path.length === maxDistance) continue;
    for (const [dx, dy] of dirs) {
      const next = { x: point.x + dx, y: point.y + dy };
      if (roads.has(key(next)) && !visited.has(key(next))) {
        visited.add(key(next)); queue.push([...path, next]);
      }
    }
  }
  return null;
}

export function analyze(state) {
  const roads = new Set(state.tiles.filter(isRoad).map(key));
  const homes = state.tiles.filter(tile => tile.type === 'home');
  const perHome = homes.map(home => ({ x: home.x, y: home.y, shop: null, work: null, clinic: null, park: null }));
  const served = { shop: 0, work: 0, clinic: 0, park: 0 };
  for (const type of ['shop', 'clinic', 'park']) {
    const targets = state.tiles.filter(tile => tile.type === type);
    homes.forEach((home, index) => {
      const routes = targets.map(target => roadPath(roads, home, target, TYPES[type].range)).filter(Boolean);
      routes.sort((a, b) => a.distance - b.distance || a.target.x - b.target.x || a.target.y - b.target.y);
      perHome[index][type] = routes[0] ?? null;
      if (routes.length) served[type] += TYPES.home.residents;
    });
  }
  const workshops = state.tiles.filter(tile => tile.type === 'workshop');
  const options = homes.map(home => workshops.map(target => roadPath(roads, home, target, TYPES.workshop.range)));
  // Each family has 3 residents; each workshop has two 3-person slots. An
  // augmenting path can move an earlier family instead of losing a valid job.
  const slots = workshops.flatMap((_, index) => [index, index]);
  const assigned = Array(slots.length).fill(-1);
  const match = (homeIndex, seen) => {
    const ordered = slots.map((workshop, slot) => ({ workshop, slot }))
      .filter(({ workshop }) => options[homeIndex][workshop])
      .sort((a, b) => options[homeIndex][a.workshop].distance - options[homeIndex][b.workshop].distance || a.slot - b.slot);
    for (const { slot } of ordered) {
      if (seen.has(slot)) continue;
      seen.add(slot);
      if (assigned[slot] === -1 || match(assigned[slot], seen)) { assigned[slot] = homeIndex; return true; }
    }
    return false;
  };
  homes.forEach((_, index) => match(index, new Set()));
  assigned.forEach((homeIndex, slot) => {
    if (homeIndex !== -1) { perHome[homeIndex].work = options[homeIndex][slots[slot]]; served.work += TYPES.home.residents; }
  });
  const residents = homes.length * TYPES.home.residents;
  const west = homes.find(home => home.x === 1 && home.y === 2);
  const east = homes.find(home => home.x === 7 && home.y === 2);
  const bridgeConnected = Boolean(west && east && roadPath(roads, west, east));
  const target = PHASES[state.phase].target;
  const goal = (id, label, current, amount = target) => ({ id, label, current, target: amount, done: current >= amount });
  const goals = [goal('residents', '住まい', residents), goal('shop', '買物が届く', served.shop), goal('work', '仕事に通える', served.work)];
  if (state.phase === 1) goals.push(goal('bridge', '橋で両岸をつなぐ', Number(bridgeConnected), 1));
  if (state.phase === 2) goals.push(goal('clinic', '近くで通院できる', served.clinic), goal('park', '公園で憩える', served.park));
  const routes = perHome.flatMap(home => ['shop', 'work', 'clinic', 'park'].filter(kind => home[kind]).map(kind => ({ kind, from: { x: home.x, y: home.y }, ...home[kind] })));
  return { residents, served, perHome, routes, bridgeConnected, goals, allDone: goals.every(item => item.done) };
}

function placementError(state, type, x, y) {
  if (state.completed) return 'この町は完成しました。再挑戦から新しい町をつくれます。';
  if (!Object.hasOwn(TYPES, type)) return '建てるものを選んでください。';
  if (!inside(x, y)) return '町の中のマスを選んでください。';
  if (TYPES[type].unlockPhase > state.phase) return 'この建物は次の時代に使えます。';
  if (state.phase === 0 && x >= 5) return '川の向こうは1973年から開きます。';
  if (state.tiles.some(tile => tile.x === x && tile.y === y)) return 'ここにはすでに建物か道があります。';
  if (state.phase < 2 && x === 7 && y === 4) return 'ここは2000年に住民が来る家の予定地です。';
  const terrain = terrainAt(x, y);
  if (terrain === 'mountain') return '山には建てられません。';
  if (type === 'bridge' && terrain !== 'river') return '橋は川の上に架けます。';
  if (type !== 'bridge' && terrain === 'river') return '川には橋を架けてください。';
  if (type === 'home' && state.tiles.some(tile => tile.type === 'home' && !tile.fixed)) return '増やせる家は1戸です。次の時代には新しい住民が来ます。';
  if (state.budget < costOf(type, state.phase)) return '工事予算が足りません。戻すか、建物を返して組み直せます。';
  return null;
}

export function previewBuild(state, type, x, y) {
  const message = placementError(state, type, x, y);
  const cost = costOf(type, state.phase);
  if (message) return { ok: false, cost, message, analysis: analyze(state), budgetAfter: state.budget };
  const next = { ...state, budget: state.budget - cost, tiles: [...copyTiles(state.tiles), { x, y, type, paid: cost, fixed: false }] };
  return { ok: true, cost, budgetAfter: next.budget, analysis: analyze(next), message: `${TYPES[type].label}を建てると予算は${next.budget}になります。` };
}

export function build(state, type, x, y) {
  const preview = previewBuild(state, type, x, y);
  if (!preview.ok) return { ok: false, state, message: preview.message };
  return { ok: true, state: { ...state, budget: preview.budgetAfter, tiles: [...copyTiles(state.tiles), { x, y, type, paid: preview.cost, fixed: false }] }, message: `${TYPES[type].label}ができました。` };
}

export function remove(state, x, y) {
  if (state.completed) return { ok: false, state, message: 'この町は完成しました。' };
  const tile = state.tiles.find(item => item.x === x && item.y === y);
  if (!tile) return { ok: false, state, message: '返せる建物がありません。' };
  if (tile.fixed) return { ok: false, state, message: 'もともとの家と仕事場は残して町を育てましょう。' };
  return { ok: true, state: { ...state, budget: state.budget + tile.paid, tiles: copyTiles(state.tiles.filter(item => item !== tile)) }, message: `${TYPES[tile.type].label}を返し、予算${tile.paid}が戻りました。` };
}

export function advance(state) {
  if (state.completed) return { ok: false, state, message: 'すべての時代を達成しています。' };
  if (!analyze(state).allDone) return { ok: false, state, message: 'まだ願いが残っています。目標と道のつながりを確かめましょう。' };
  if (state.phase === PHASES.length - 1) return { ok: true, state: { ...state, tiles: copyTiles(state.tiles), completed: true }, message: '3つの時代をつなぎ、町が完成しました。' };
  const phase = state.phase + 1;
  const added = fixedTiles(phase).filter(tile => !state.tiles.some(old => old.x === tile.x && old.y === tile.y));
  // The future home lots are reserved: these cells are unavailable before arrival.
  return { ok: true, state: { ...state, phase, budget: PHASES[phase].budget + Math.min(3, state.budget), discarded: state.discarded + Math.max(0, state.budget - 3), tiles: [...copyTiles(state.tiles), ...added] }, message: `${PHASES[phase].year}年。新しい住民が町に来ました。` };
}

const exactKeys = (value, keys) => value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === keys.length && keys.every(k => Object.hasOwn(value, k));
export function validateSave(raw) {
  const invalid = () => ({ ok: false, state: null, message: '保存データを読み込めませんでした。新しい町から始められます。' });
  let state;
  try { state = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return invalid(); }
  if (!exactKeys(state, ['version', 'phase', 'budget', 'completed', 'discarded', 'tiles'])) return invalid();
  if (state.version !== VERSION || !Number.isInteger(state.phase) || state.phase < 0 || state.phase >= PHASES.length || typeof state.completed !== 'boolean') return invalid();
  if (!Number.isInteger(state.budget) || state.budget < 0 || !Number.isInteger(state.discarded) || state.discarded < 0 || state.discarded > PHASES.slice(0, state.phase).reduce((n, phase) => n + phase.budget, 0)) return invalid();
  if (!Array.isArray(state.tiles) || state.tiles.length > WIDTH * HEIGHT) return invalid();
  const cells = new Set();
  const expectedFixed = fixedTiles(state.phase);
  for (const tile of state.tiles) {
    if (!exactKeys(tile, ['x', 'y', 'type', 'paid', 'fixed']) || !inside(tile.x, tile.y) || !Object.hasOwn(TYPES, tile.type) || !Number.isInteger(tile.paid) || tile.paid < 0 || typeof tile.fixed !== 'boolean') return invalid();
    if (cells.has(key(tile)) || TYPES[tile.type].unlockPhase > state.phase || (state.phase === 0 && tile.x >= 5)) return invalid();
    if (state.phase < 2 && tile.x === 7 && tile.y === 4) return invalid();
    cells.add(key(tile));
    const terrain = terrainAt(tile.x, tile.y);
    if (terrain === 'mountain' || (tile.type === 'bridge') !== (terrain === 'river')) return invalid();
    const expected = expectedFixed.find(item => key(item) === key(tile));
    if (tile.fixed) { if (!expected || expected.type !== tile.type || tile.paid !== 0) return invalid(); }
    else {
      if (expected) return invalid();
      const freeRoad = tile.type === 'road' && seedRoads.some(item => key(item) === key(tile)) && tile.paid === 0;
      const oldShop = tile.type === 'shop' && tile.paid === 4;
      if (!freeRoad && !oldShop && tile.paid !== costOf(tile.type, state.phase)) return invalid();
    }
  }
  if (expectedFixed.some(expected => !state.tiles.some(tile => key(tile) === key(expected) && tile.fixed))) return invalid();
  if (state.tiles.filter(tile => tile.type === 'home' && !tile.fixed).length > 1) return invalid();
  const granted = PHASES.slice(0, state.phase + 1).reduce((sum, phase) => sum + phase.budget, 0);
  if (state.budget + state.discarded + state.tiles.reduce((sum, tile) => sum + tile.paid, 0) !== granted) return invalid();
  if (state.completed && (state.phase !== 2 || !analyze(state).allDone)) return invalid();
  return { ok: true, state: { ...state, tiles: copyTiles(state.tiles) }, message: '保存した町を読み込みました。' };
}

export function serialize(state) { return JSON.stringify(state); }
