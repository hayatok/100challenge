import { findRoute, jobCapacity, neighbors, synchronizeResidents } from './mobility.ts';
export { advanceResidents } from './mobility.ts';
import type { Cell, CellKind, Resident, TownEvent, TownStats, World } from './types.ts';

const KINDS: CellKind[] = ['grass', 'tree', 'water', 'road', 'house', 'shop', 'farm', 'factory', 'ruin', 'park'];
const BUILDINGS = new Set<CellKind>(['house', 'shop', 'farm', 'factory']);
const EVENT_LIMIT = 18;
const HISTORY_LIMIT = 180;
const MAX_TICK = 100_000_000;
const clamp = (value: number, low = 0, high = 100) => Math.max(low, Math.min(high, value));

/** Mulberry32 keeps its complete continuation state in World.rng. */
function random(world: World): number {
  world.rng = (world.rng + 0x6d2b79f5) >>> 0;
  let value = world.rng;
  value = Math.imul(value ^ (value >>> 15), value | 1);
  value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
  return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
}

function emptyStats(): TownStats {
  return { population: 0, homes: 0, shops: 0, farms: 0, factories: 0, ruins: 0, roads: 0, environment: 0, jobs: 0, born: 0, retired: 0 };
}

const jobs = jobCapacity;

function statistics(cells: Cell[], born: number, retired: number): TownStats {
  const result = emptyStats();
  let environment = 0;
  let land = 0;
  for (const cell of cells) {
    result.population += cell.population;
    result.jobs += jobs(cell);
    if (cell.kind === 'house') result.homes++;
    else if (cell.kind === 'shop') result.shops++;
    else if (cell.kind === 'farm') result.farms++;
    else if (cell.kind === 'factory') result.factories++;
    else if (cell.kind === 'ruin') result.ruins++;
    else if (cell.kind === 'road') result.roads++;
    if (cell.terrain === 'land') { environment += cell.environment; land++; }
  }
  result.environment = Math.round(environment / Math.max(1, land));
  result.born = born;
  result.retired = retired;
  return result;
}

function setKind(cell: Cell, kind: CellKind, tick: number, reason: string): void {
  cell.kind = kind;
  cell.age = 0;
  cell.level = BUILDINGS.has(kind) ? 1 : 0;
  cell.population = kind === 'house' ? 6 : 0;
  cell.vitality = BUILDINGS.has(kind) ? 72 : 0;
  cell.reason = reason;
  cell.changedAt = tick;
  cell.condition = BUILDINGS.has(kind) ? 88 : 0; cell.development = 0; cell.employed = 0; cell.customers = 0;
  cell.crop = kind === 'farm' ? 10 : 0;
}

export function createWorld(seed: number, size = 48): World {
  if (!Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw new Error('街の種は0〜4294967295の整数で指定してください。');
  if (!Number.isInteger(size) || size < 24 || size > 64) throw new Error('街の大きさは24〜64の整数で指定してください。');
  const world: World = { version: 2, clock: 0, nextResidentId: 0, residents: [], weather: { kind: 'clear', temperature: 18, rainfall: 0 }, economy: { workers: 0, employed: 0, food: 60, harvest: 0, visits: 0, commutes: 0 }, seed, rng: seed, size, tick: 0, cells: [], stats: emptyStats(), events: [], history: [] };
  const phase = random(world) * Math.PI * 2;
  const riverOffset = (random(world) - .5) * size * .06;
  for (let y = 0; y < size; y++) {
    const river = size * .5 + riverOffset + Math.sin(y / size * Math.PI * 2 + phase) * size * .07;
    for (let x = 0; x < size; x++) {
      const water = Math.abs(x - river) < 1.4;
      const woods = Math.sin(x * .21 + phase) * Math.cos(y * .17 - phase) > .28;
      const tree = !water && random(world) < (woods ? .72 : .07);
      world.cells.push({ x, y, terrain: water ? 'water' : 'land', kind: water ? 'water' : tree ? 'tree' : 'grass', level: 0, age: tree ? 48 : 0, population: 0, vitality: 0, environment: water ? 90 : tree ? 94 : 78, traffic: 0, variant: Math.floor(random(world) * 8), reason: water ? '川の流れが、この土地をうるおしています。' : tree ? '林が空気を整え、生きものの居場所を守っています。' : '水と緑に囲まれた、まだ静かな草地です。', changedAt: 0, moisture: water ? 100 : 55, fertility: tree ? 85 : 72, vegetation: tree ? 90 : 35, crop: 0, condition: 0, development: 0, employed: 0, customers: 0, accessible: false });
    }
  }
  const roadAt = (x: number, y: number) => {
    const cell = world.cells[y * size + x];
    setKind(cell, 'road', 0, cell.terrain === 'water' ? '二つの集落を結ぶ橋。川の向こうへ仕事と暮らしを運びます。' : '集落をつなぐ道。沿道に人と仕事が集まります。');
  };
  const trunkY = Math.floor(size * .52);
  const centers = [Math.floor(size * .25), Math.floor(size * .74)];
  for (let x = centers[0] - 4; x <= centers[1] + 4; x++) roadAt(x, trunkY);
  for (const centerX of centers) {
    for (let y = trunkY - 5; y <= trunkY + 5; y++) roadAt(centerX, y);
    for (let x = centerX - 4; x <= centerX + 4; x++) roadAt(x, trunkY - 3);
    const lots: [number, number, CellKind][] = [
      [-1, -1, 'house'], [1, -1, 'house'], [-1, 1, 'house'], [1, 1, 'house'],
      [-2, -2, 'house'], [2, -2, 'house'], [-3, 1, 'house'], [3, 1, 'house'],
      [-1, -4, 'farm'], [1, -4, 'farm'], [-3, -4, 'farm'], [3, -4, 'farm'],
      [-2, 1, 'shop'], [2, 1, 'shop'], [-1, 4, 'factory'], [1, 4, 'farm'],
    ];
    for (const [dx, dy, kind] of lots) {
      const cell = world.cells[(trunkY + dy) * size + centerX + dx];
      if (cell.terrain === 'water') continue;
      setKind(cell, kind, 0, kind === 'house' ? '道と畑のそばに、小さな集落ができました。' : kind === 'farm' ? '川に近い土地を耕し、集落の食と仕事を支えています。' : kind === 'shop' ? '集落の住民が通う、道沿いの小さな商店です。' : '集落の端で、暮らしを支える仕事が生まれました。');
      cell.age = Math.floor(random(world) * 24);
    }
  }
  world.stats = statistics(world.cells, 0, 0);
  world.events.push({ tick: 0, x: centers[0], y: trunkY, kind: 'birth', text: '川をはさんだ二つの集落から、町の時間が始まります。' });
  world.history.push({ tick: 0, population: world.stats.population });
  synchronizeResidents(world);
  return world;
}

/** Integral grids make each neighborhood query constant time, always from the previous tick. */
function neighborhoods(world: World) {
  const width = world.size + 1;
  const names = ['population', 'jobs', 'house', 'shop', 'farm', 'factory', 'green', 'water', 'road'] as const;
  const grids = Object.fromEntries(names.map(name => [name, new Float64Array(width * width)])) as Record<typeof names[number], Float64Array>;
  for (let y = 0; y < world.size; y++) {
    for (let x = 0; x < world.size; x++) {
      const cell = world.cells[y * world.size + x];
      const values = [cell.population, cell.accessible ? jobs(cell) : 0, +(cell.kind === 'house'), +(cell.kind === 'shop'), +(cell.kind === 'farm'), +(cell.kind === 'factory'), +(cell.kind === 'tree') + +(cell.kind === 'park') * 2, +(cell.terrain === 'water'), +(cell.kind === 'road')];
      const index = (y + 1) * width + x + 1;
      for (let channel = 0; channel < names.length; channel++) {
        const grid = grids[names[channel]];
        grid[index] = values[channel] + grid[index - 1] + grid[index - width] - grid[index - width - 1];
      }
    }
  }
  return (name: typeof names[number], x: number, y: number, radius: number) => {
    const left = Math.max(0, x - radius), right = Math.min(world.size, x + radius + 1);
    const top = Math.max(0, y - radius), bottom = Math.min(world.size, y + radius + 1);
    const grid = grids[name];
    return grid[bottom * width + right] - grid[top * width + right] - grid[bottom * width + left] + grid[top * width + left];
  };
}

export function stepWorld(world: World): World {
  if (world.tick >= MAX_TICK) return world;
  const assigned = new Map<number, number>();
  for (const resident of world.residents) if (resident.workplace !== null) assigned.set(resident.workplace, (assigned.get(resident.workplace) ?? 0) + 1);
  const driveways = new Set<number>();
  for (const resident of world.residents) if (resident.state !== 'home') { for (const index of [...resident.route.slice(0, 3), ...resident.route.slice(-3)]) driveways.add(index); }
  const previous = world.cells;
  const near = neighborhoods(world);
  const tick = world.tick + 1;
  const season = Math.floor(tick / 12) % 4;
  const temperature = 15 + Math.sin(tick / 48 * Math.PI * 2 - Math.PI / 4) * 12;
  if (tick % 4 === 1) {
    const wet = random(world) < [ .32, .24, .38, .25 ][season];
    world.weather = { kind: wet ? temperature < 4 ? 'snow' : 'rain' : 'clear', temperature, rainfall: wet ? 9 + random(world) * 14 : 0 };
  } else world.weather.temperature = temperature;
  world.economy.harvest = 0;
  world.economy.food = Math.max(0, world.economy.food - world.stats.population * .015);
  const next: Cell[] = [];
  let born = world.stats.born, retired = world.stats.retired;
  const event = (cell: Cell, kind: TownEvent['kind'], text: string) => {
    world.events.push({ tick, x: cell.x, y: cell.y, kind, text });
    if (world.events.length > EVENT_LIMIT) world.events.shift();
  };
  for (let index = 0; index < previous.length; index++) {
    const old = previous[index];
    const cell = { ...old };
    next.push(cell);
    cell.age++;
    const { x, y } = old;
    const population = near('population', x, y, 3);
    const employment = near('jobs', x, y, 3);
    const homes = near('house', x, y, 3);
    const shops = near('shop', x, y, 3);
    const farms = near('farm', x, y, 3);
    const factories = near('factory', x, y, 3);
    const green = near('green', x, y, 3);
    const water = near('water', x, y, 3);
    const roads = near('road', x, y, 1);
    const density = homes + shops + farms + factories;
    const targetEnvironment = clamp(78 + green * 1.7 + water * .4 - factories * 7 - density * .85);
    cell.environment = Math.round(clamp(old.environment * .82 + targetEnvironment * .18));
    cell.traffic = clamp(old.traffic * .72);
    cell.moisture = clamp(old.moisture + world.weather.rainfall * .55 + Math.min(7, water * .7) - (season === 1 ? 6 : season === 3 ? 1 : 3));
    const dormant = !BUILDINGS.has(old.kind) && old.kind !== 'road';
    cell.fertility = clamp(old.fertility + (dormant ? .3 + old.vegetation * .004 : old.kind === 'farm' ? -.18 : -.03) - factories * .05);
    cell.vegetation = clamp(old.vegetation + (dormant ? (cell.moisture > 25 ? .7 : -.6) : -1));
    if (old.terrain === 'water') {
      cell.environment = 90; cell.moisture = 100;
      continue;
    }
    if (BUILDINGS.has(old.kind)) {
      const staffing = Math.min(1, old.employed / Math.max(1, jobs(old) * .3));
      const residentWorkers = world.residents.filter(person => person.home === index);
      const householdEmployment = residentWorkers.length ? residentWorkers.filter(person => person.workplace !== null && previous[person.workplace].employed > .2).length / residentWorkers.length : 0;
      let appeal: number;
      let reason: string;
      if (old.kind === 'house') {
        appeal = 45 + householdEmployment * 27 + (cell.environment - 60) * .4 + (world.economy.food > 5 ? 6 : -12) - Math.max(0, homes - 11) * 2;
        reason = !old.accessible ? '道路へ出られず、通勤や買い物が難しくなっています。' : householdEmployment < .4 ? '届く仕事場の空きが少なく、家計の活力が弱まっています。' : '道で仕事場へ通える住民が、家と庭を手入れしています。';
      } else if (old.kind === 'shop') {
        appeal = 34 + Math.min(42, old.customers * 12) + staffing * 12;
        reason = old.customers < 1 ? '今週は来店がなく、次のお客さんを待っています。' : '道路を歩いて来たお客さんの買い物が、店の維持を支えています。';
      } else if (old.kind === 'farm') {
        appeal = 40 + staffing * 20 + (cell.fertility - 50) * .35 + (cell.moisture > 20 && cell.moisture < 90 ? 9 : -10);
        cell.crop = clamp(old.crop + (season === 3 ? 0 : 3 + staffing * 6) * Math.min(1, cell.moisture / 45) * Math.min(1, cell.fertility / 65));
        if (cell.crop >= 95 && season !== 3 && (old.employed >= .5 || world.residents.some(person => person.state === 'work' && person.destination === index))) { const harvest = 14 + old.level * 8; world.economy.harvest += harvest; world.economy.food = Math.min(10000, world.economy.food + harvest); cell.crop = 5; cell.fertility = clamp(cell.fertility - 2); }
        reason = cell.crop >= 95 && old.employed < .5 ? '作物は育っていますが、収穫に来る働き手を待っています。' : season === 3 ? '冬の畑は生育を休み、土が養分を取り戻しています。' : staffing === 0 ? '働き手がまだ到着せず、作物はゆっくり育っています。' : cell.moisture < 25 ? '土が乾き、作物の生育が遅れています。' : '畑へ来た働き手と土の水分が作物を育て、収穫は町の食になります。';
        if (season === 3) cell.fertility = clamp(cell.fertility + .5);
      } else {
        appeal = 36 + staffing * 43 - Math.max(0, factories - 2) * 6;
        reason = staffing < .2 ? '道で届く働き手が少なく、設備を動かす力が弱まっています。' : '通勤して来た働き手が設備を動かし、修繕を支えています。';
      }
      if (!old.accessible) appeal -= 22;
      // Successful activity pays for repair; age alone never condemns a profitable building.
      cell.condition = clamp(old.condition + (appeal > 54 ? .8 : -.65) - (old.age > 300 ? .12 : 0));
      if (cell.condition < 30) appeal -= (30 - cell.condition) * .65;
      cell.vitality = Math.round(clamp(old.vitality * .90 + clamp(appeal) * .10));
      cell.reason = reason;
      if (cell.vitality < 25 && cell.condition < 20 && old.age > 80) {
        setKind(cell, 'ruin', tick, `${reason}使われなくなり、空き家になりました。`);
        retired++;
        event(cell, 'decline', old.kind === 'house' ? '古い家が空き家に。暮らしの中心が移っています。' : old.kind === 'farm' ? '畑が休耕地になり、土地が休む時間に入りました。' : old.kind === 'shop' ? '商店が店を閉じ、次の暮らしを待っています。' : '工場が役目を終え、静かな土地になりました。');
      } else {
        const desiredLevel = cell.vitality > 76 ? 3 : cell.vitality > 58 ? 2 : 1;
        if (desiredLevel > old.level && old.age > old.level * 12) cell.development = clamp(old.development + 6);
        else cell.development = Math.max(0, old.development - 3);
        if (desiredLevel > old.level && cell.development >= 100) {
          cell.development = 0;
          cell.level++;
          cell.changedAt = tick;
          cell.reason = `${reason}需要に応えて建物が育ちました。`;
          event(cell, 'growth', old.kind === 'house' ? '暮らしが安定し、家に新しい住民を迎えました。' : '近くの需要を受けて、仕事場が育ちました。');
        } else if (desiredLevel < old.level && old.age > 30 && random(world) < .055) {
          cell.level--;
          cell.changedAt = tick;
          cell.reason = `${reason}規模を小さくして暮らしを続けています。`;
          event(cell, 'decline', '活力が下がり、建物の規模が小さくなりました。');
        }
        cell.population = cell.kind === 'house' ? clamp(Math.round((3 + cell.level * 3) * (.6 + cell.vitality / 200)), 2, 12) : 0;
      }
      cell.employed = old.employed * .9; cell.customers = old.customers * .9;
      continue;
    }
    if (old.kind === 'ruin') {
      if (old.age >= 16 + old.variant * 2) {
        setKind(cell, 'grass', tick, '空き家が土へ戻り、緑が土地の環境を回復させています。');
        event(cell, 'nature', '空き家の跡に草が戻りました。次の暮らしへの休息です。');
      }
      continue;
    }
    if (old.kind === 'tree' && cell.moisture < 10 && cell.fertility < 35 && old.age > 80) { setKind(cell, 'grass', tick, '乾燥と土の疲れで木が弱り、低い草地に戻りました。'); cell.vegetation = 35; }
    if (old.kind !== 'grass') continue;
    if (driveways.has(index)) { cell.development = Math.max(0, old.development - 3); continue; }
    const cardinalRoad = (x > 0 && previous[index - 1].kind === 'road') || (x < world.size - 1 && previous[index + 1].kind === 'road') || (y > 0 && previous[index - world.size].kind === 'road') || (y < world.size - 1 && previous[index + world.size].kind === 'road');
    if (cardinalRoad && population >= 12 && near('road', x, y, 2) < 9 && world.stats.roads < world.size * world.size * .13 && random(world) < .0035) {
      setKind(cell, 'road', tick, '近くの住民と仕事場が増え、既存の道から新しい道が伸びました。');
      event(cell, 'road', '集落から道が伸び、新しい暮らしの入口ができました。');
      continue;
    }
    if (roads && old.age >= 8 && cell.environment >= 43 && density < 17) {
      let kind: CellKind | null = null;
      let chance = 0;
      let reason = '';
      const housingPressure = clamp((employment * 1.2 + 20 - population) / 28, .15, 1.5);
      if (homes < 9 && employment >= 5 && world.stats.homes < world.size * world.size * .18 && previous.some((workplace, destination) => jobs(workplace) > (assigned.get(destination) ?? 0) && Math.abs(workplace.x - x) <= 6 && Math.abs(workplace.y - y) <= 6 && findRoute(world, index, destination))) {
        kind = 'house'; chance = .023 * housingPressure;
        reason = '道と近くの仕事、回復した緑に引かれて、新しい家が生まれました。';
      }
      if (population >= 18 && shops < Math.min(3, population / 24) && (shops === 0 || previous.some(existing => existing.kind === 'shop' && Math.abs(existing.x - x) <= 3 && Math.abs(existing.y - y) <= 3 && existing.customers >= 2)) && random(world) < .35) {
        kind = 'shop'; chance = .022;
        reason = '沿道の住民が増え、日々の買い物を支える店が開きました。';
      }
      if (farms < 3 && cell.environment > 62 && (employment < population * .8 + 16) && random(world) < .4) {
        kind = 'farm'; chance = .018 * (water > 0 ? 1.4 : 1);
        reason = '道に届く緑の土地で、食と仕事を支える新しい畑が開かれました。';
      }
      if (population > 24 && factories < 1 && employment < population * .75 && cell.environment > 66 && world.stats.factories < Math.max(2, world.stats.homes / 10) && random(world) < .3) {
        kind = 'factory'; chance = .015;
        reason = '沿道の働き手と仕事の需要を受けて、小さな工場ができました。';
      }
      if (kind) cell.development = clamp(old.development + chance * 180);
      else cell.development = Math.max(0, old.development - 3);
      if (kind && cell.development >= 100) {
        setKind(cell, kind, tick, reason);
        born++;
        event(cell, 'birth', kind === 'house' ? '道と仕事のそばに、新しい家が生まれました。' : kind === 'shop' ? '住民の暮らしに応えて、商店が開きました。' : kind === 'farm' ? '緑の土地に畑ができ、食と仕事を支えます。' : '働き手が集まり、小さな工場が生まれました。');
        continue;
      }
    }
    if (old.age > 60 && !roads && green >= 3 && cell.vegetation > 82 && cell.fertility > 55 && random(world) < .004) {
      setKind(cell, 'tree', tick, '近くの林から木々が広がり、土地に緑が戻りました。');
      event(cell, 'nature', '林のそばに若い木が芽吹きました。');
    }
  }
  world.cells = next;
  world.tick = tick;
  world.stats = statistics(next, born, retired);
  synchronizeResidents(world);
  world.history.push({ tick, population: world.stats.population });
  if (world.history.length > HISTORY_LIMIT) world.history.shift();
  return world;
}

export function serializeWorld(world: World): string {
  return JSON.stringify(world);
}

function invalid(detail: string): never { throw new Error(`保存した街を読み込めません: ${detail}`); }
function record(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalid(`${label}の形式が不正です。`);
  return value as Record<string, unknown>;
}
function number(value: unknown, label: string, low: number, high: number, integer = true): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < low || value > high || (integer && !Number.isInteger(value))) invalid(`${label}の数値が不正です。`);
  return value;
}
function boolean(value: unknown, label: string): boolean {
  if (typeof value !== 'boolean') invalid(`${label}の値が不正です。`);
  return value;
}
function string(value: unknown, label: string, limit: number): string {
  if (typeof value !== 'string' || value.length > limit) invalid(`${label}の文字列が不正です。`);
  return value;
}

/** Validate bounded data and rebuild plain objects; never trust saved derived statistics. */
export function restoreWorld(json: string): World {
  if (typeof json !== 'string' || json.length > 4_000_000) invalid('保存データが大きすぎます。');
  let parsed: unknown;
  try { parsed = JSON.parse(json); } catch { invalid('JSONが壊れています。'); }
  const data = record(parsed, '街');
  if (data.version !== 1 && data.version !== 2) invalid('対応していない保存形式です。');
  const legacy = data.version === 1;
  const size = number(data.size, '大きさ', 24, 64);
  const tick = number(data.tick, '週', 0, MAX_TICK);
  const seed = number(data.seed, '種', 0, 0xffffffff);
  const rng = number(data.rng, '乱数状態', 0, 0xffffffff);
  if (!Array.isArray(data.cells) || data.cells.length !== size * size) invalid('土地の数が一致しません。');
  const cells = data.cells.map((value, index): Cell => {
    const cell = record(value, '土地');
    const x = number(cell.x, '土地の横位置', 0, size - 1);
    const y = number(cell.y, '土地の縦位置', 0, size - 1);
    if (x !== index % size || y !== Math.floor(index / size)) invalid('土地の並びが不正です。');
    if (cell.terrain !== 'land' && cell.terrain !== 'water') invalid('地形が不正です。');
    if (!KINDS.includes(cell.kind as CellKind)) invalid('土地の種類が不正です。');
    const kind = cell.kind as CellKind;
    if ((cell.terrain === 'water' && kind !== 'water' && kind !== 'road') || (cell.terrain === 'land' && kind === 'water')) invalid('水と建物の組み合わせが不正です。');
    const level = number(cell.level, '建物の段階', 0, 3);
    const population = number(cell.population, '土地の人口', 0, 12);
    const vitality = number(cell.vitality, '活力', 0, 100);
    if ((BUILDINGS.has(kind) && level < 1) || (!BUILDINGS.has(kind) && (level !== 0 || vitality !== 0)) || (kind !== 'house' && population !== 0) || (kind === 'house' && population < 1)) invalid('建物と人口・段階の組み合わせが不正です。');
    return { x, y, terrain: cell.terrain, kind, level, age: number(cell.age, '築週', 0, MAX_TICK + 64), population, vitality, environment: number(cell.environment, '環境', 0, 100), traffic: number(cell.traffic, '通行', 0, 100, false), variant: number(cell.variant, '外観', 0, 7), reason: string(cell.reason, '理由', 500), changedAt: number(cell.changedAt, '変化した週', 0, tick),
      moisture: legacy ? cell.terrain === 'water' ? 100 : 55 : number(cell.moisture, '水分', 0, 100, false),
      fertility: legacy ? kind === 'tree' ? 85 : 72 : number(cell.fertility, '肥沃度', 0, 100, false),
      vegetation: legacy ? kind === 'tree' ? 90 : kind === 'grass' ? 35 : 0 : number(cell.vegetation, '植生', 0, 100, false),
      crop: legacy ? kind === 'farm' ? 10 : 0 : number(cell.crop, '作物', 0, 100, false),
      condition: legacy ? BUILDINGS.has(kind) ? 80 : 0 : number(cell.condition, '建物状態', 0, 100, false),
      development: legacy ? 0 : number(cell.development, '工事', 0, 100, false),
      employed: legacy ? 0 : number(cell.employed, '到着した働き手', 0, 10000, false),
      customers: legacy ? 0 : number(cell.customers, '来店', 0, 10000, false),
      accessible: legacy ? false : boolean(cell.accessible, '到達性') };
  });
  const savedStats = record(data.stats, '統計');
  const born = number(savedStats.born, '誕生数', 0, size * size * tick);
  const retired = number(savedStats.retired, '閉鎖数', 0, size * size * tick);
  const stats = statistics(cells, born, retired);
  for (const key of Object.keys(stats) as (keyof TownStats)[]) {
    if (number(savedStats[key], `統計の${key}`, 0, Math.max(size * size * 100, size * size * tick)) !== stats[key]) invalid(`統計の${key}が土地と一致しません。`);
  }
  if (!Array.isArray(data.events) || data.events.length > EVENT_LIMIT) invalid('街の記録が多すぎます。');
  const events = data.events.map((value): TownEvent => {
    const entry = record(value, '記録');
    if (!['birth', 'growth', 'decline', 'nature', 'road'].includes(entry.kind as string)) invalid('記録の種類が不正です。');
    return { tick: number(entry.tick, '記録の週', 0, tick), x: number(entry.x, '記録の横位置', 0, size - 1), y: number(entry.y, '記録の縦位置', 0, size - 1), kind: entry.kind as TownEvent['kind'], text: string(entry.text, '記録の文章', 500) };
  });
  if (events.some((entry, index) => index > 0 && entry.tick < events[index - 1].tick)) invalid('街の記録の順序が不正です。');
  if (!Array.isArray(data.history) || data.history.length < 1 || data.history.length > HISTORY_LIMIT) invalid('人口の履歴が不正です。');
  const history = data.history.map(value => {
    const point = record(value, '人口履歴');
    return { tick: number(point.tick, '履歴の週', 0, tick), population: number(point.population, '履歴の人口', 0, size * size * 12) };
  });
  if (history.some((point, index) => index > 0 && point.tick !== history[index - 1].tick + 1) || history.at(-1)!.tick !== tick || history.at(-1)!.population !== stats.population) invalid('人口の履歴が現在の街と一致しません。');
  const world: World = { version: 2, clock: legacy ? tick * 4 : number(data.clock, '時計', 0, 1e12, false), nextResidentId: legacy ? 0 : number(data.nextResidentId, '次の住民番号', 0, 1e12), seed, rng, size, tick, cells, stats, events, history, residents: [], weather: { kind: 'clear', temperature: 18, rainfall: 0 }, economy: { workers: 0, employed: 0, food: Math.max(30, stats.population * .6), harvest: 0, visits: 0, commutes: 0 } };
  if (legacy) { synchronizeResidents(world); return world; }
  const weather = record(data.weather, '天候');
  if (!['clear', 'rain', 'snow'].includes(weather.kind as string)) invalid('天候の種類が不正です。');
  world.weather = { kind: weather.kind as World['weather']['kind'], temperature: number(weather.temperature, '気温', -30, 50, false), rainfall: number(weather.rainfall, '雨量', 0, 100, false) };
  const economy = record(data.economy, '経済');
  world.economy = { workers: number(economy.workers, '働き手', 0, cells.length * 6), employed: number(economy.employed, '雇用', 0, cells.length * 6), food: number(economy.food, '食の蓄え', 0, 10000, false), harvest: number(economy.harvest, '収穫', 0, cells.length * 100, false), visits: number(economy.visits, '来店累計', 0, 100000), commutes: number(economy.commutes, '通勤累計', 0, 100000) };
  if (!Array.isArray(data.residents) || data.residents.length > cells.length * 6) invalid('住民の人数が不正です。');
  const ids = new Set<number>(), occupancy = new Map<number, number>();
  const destinationIndex = (value: unknown, label: string) => value === null ? null : number(value, label, 0, cells.length - 1);
  world.residents = data.residents.map((value): Resident => {
    const person = record(value, '住民');
    const id = number(person.id, '住民番号', 0, 1e12);
    if (id >= world.nextResidentId) invalid('住民番号が採番状態と一致しません。');
    if (ids.has(id)) invalid('住民番号が重複しています。'); ids.add(id);
    const home = number(person.home, '住まい', 0, cells.length - 1);
    if (cells[home].terrain !== 'land') invalid('住まいの土地が不正です。');
    const workplace = destinationIndex(person.workplace, '仕事場'), shop = destinationIndex(person.shop, '買い物先'), destination = destinationIndex(person.destination, '行き先');
    if (workplace !== null) {
      if (!jobCapacity(cells[workplace]) || !findRoute(world, home, workplace)) invalid('仕事場へ道路で到達できません。');
      occupancy.set(workplace, (occupancy.get(workplace) ?? 0) + 1);
      if (occupancy.get(workplace)! > jobCapacity(cells[workplace])) invalid('仕事場の定員を超えています。');
    }
    if (shop !== null && (cells[shop].kind !== 'shop' || !findRoute(world, home, shop))) invalid('買い物先に到達できません。');
    if (!['home', 'travel', 'work', 'shop', 'park'].includes(person.state as string) || !['commute', 'shopping', 'stroll', 'return'].includes(person.purpose as string)) invalid('住民の行動が不正です。');
    if (!Array.isArray(person.route) || person.route.length > cells.length + 6) invalid('住民の経路が不正です。');
    const route = person.route.map(index => number(index, '経路の土地', 0, cells.length - 1));
    if (route.some((index, n) => n > 0 && !neighbors(world, route[n - 1]).includes(index))) invalid('経路がつながっていません。');
    if (route.length && (!route.some(index => cells[index].kind === 'road') || route.some((index, n) => n > 2 && n < route.length - 3 && cells[index].kind !== 'road'))) invalid('経路が道路から外れています。');
    const routeIndex = number(person.routeIndex, '経路の現在位置', 0, Math.max(0, route.length - 1));
    const progress = number(person.progress, '歩行の進み', 0, 1, false);
    const state = person.state as Resident['state'];
    if ((state === 'travel' && (destination === null || route.length < 2 || routeIndex >= route.length - 1 || route.at(-1) !== destination)) || (state !== 'home' && destination === null) || (state === 'home' && destination !== null) || (state !== 'travel' && (progress !== 0 || routeIndex !== Math.max(0, route.length - 1)))) invalid('行動と経路の組み合わせが不正です。');
    if ((state === 'home' && cells[home].kind !== 'house' && (workplace !== null || shop !== null)) || (cells[home].kind !== 'house' && (workplace !== null || shop !== null)) || (route.length > 0 && state === 'home' && route.at(-1) !== home) || (state !== 'home' && route.at(-1) !== destination) || (state === 'travel' && person.purpose === 'return' && destination !== home) || (state !== 'home' && person.purpose !== 'return' && route[0] !== home)) invalid('住まいと経路が一致しません。');
    const x = number(person.x, '住民の横位置', 0, size - 1, false), y = number(person.y, '住民の縦位置', 0, size - 1, false);
    const origin = cells[state === 'home' ? home : state === 'travel' ? route[routeIndex] : destination!];
    const next = state === 'travel' ? cells[route[routeIndex + 1]] : origin;
    if (Math.abs(x - (origin.x + (next.x - origin.x) * progress)) > 1e-6 || Math.abs(y - (origin.y + (next.y - origin.y) * progress)) > 1e-6) invalid('住民の位置と経路が一致しません。');
    return { id, home, workplace, shop, x, y, route, routeIndex, progress, state, purpose: person.purpose as Resident['purpose'], destination, timer: number(person.timer, '滞在時間', 0, 300, false), color: number(person.color, '服の色', 0, 5), trips: number(person.trips, '旅の回数', 0, 1e12) };
  });
  if (world.economy.workers !== world.residents.filter(person => cells[person.home].kind === 'house').length || world.economy.employed !== world.residents.filter(person => person.workplace !== null).length) invalid('雇用と住民が一致しません。');
  return world;
}
