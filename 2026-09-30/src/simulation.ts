import type { Cell, CellKind, TownEvent, TownStats, World } from './types.ts';

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

function jobs(cell: Cell): number {
  if (cell.kind === 'farm') return 5 + cell.level * 3;
  if (cell.kind === 'factory') return 12 + cell.level * 5;
  if (cell.kind === 'shop') return 3 + cell.level * 2;
  return 0;
}

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
}

export function createWorld(seed: number, size = 48): World {
  if (!Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw new Error('街の種は0〜4294967295の整数で指定してください。');
  if (!Number.isInteger(size) || size < 24 || size > 64) throw new Error('街の大きさは24〜64の整数で指定してください。');
  const world: World = { version: 1, seed, rng: seed, size, tick: 0, cells: [], stats: emptyStats(), events: [], history: [] };
  const phase = random(world) * Math.PI * 2;
  const riverOffset = (random(world) - .5) * size * .06;
  for (let y = 0; y < size; y++) {
    const river = size * .5 + riverOffset + Math.sin(y / size * Math.PI * 2 + phase) * size * .07;
    for (let x = 0; x < size; x++) {
      const water = Math.abs(x - river) < 1.4;
      const woods = Math.sin(x * .21 + phase) * Math.cos(y * .17 - phase) > .28;
      const tree = !water && random(world) < (woods ? .72 : .07);
      world.cells.push({ x, y, terrain: water ? 'water' : 'land', kind: water ? 'water' : tree ? 'tree' : 'grass', level: 0, age: 0, population: 0, vitality: 0, environment: water ? 90 : tree ? 94 : 78, traffic: 0, variant: Math.floor(random(world) * 8), reason: water ? '川の流れが、この土地をうるおしています。' : tree ? '林が空気を整え、生きものの居場所を守っています。' : '水と緑に囲まれた、まだ静かな草地です。', changedAt: 0 });
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
      const values = [cell.population, jobs(cell), +(cell.kind === 'house'), +(cell.kind === 'shop'), +(cell.kind === 'farm'), +(cell.kind === 'factory'), +(cell.kind === 'tree') + +(cell.kind === 'park') * 2, +(cell.terrain === 'water'), +(cell.kind === 'road')];
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
  const previous = world.cells;
  const near = neighborhoods(world);
  const tick = world.tick + 1;
  const season = Math.floor(tick / 12) % 4;
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
    cell.traffic = Math.round(clamp(population * .9 + employment * .4));
    if (old.terrain === 'water') {
      cell.environment = 90;
      continue;
    }
    if (BUILDINGS.has(old.kind)) {
      const lifespan = (old.kind === 'house' ? 160 : old.kind === 'farm' ? 220 : 130) + old.variant * 14;
      const aging = Math.max(0, old.age - lifespan) * .75;
      let appeal: number;
      let reason: string;
      if (old.kind === 'house') {
        appeal = 49 + Math.min(22, employment * .7) + Math.min(10, shops * 4) + (cell.environment - 60) * .65 - Math.max(0, homes - 9) * 4 - aging;
        reason = aging > 16 ? '築年が重なり、建物を保つ負担が増えています。' : cell.environment < 50 ? '近くの工場と密集で環境が悪くなり、住民が離れています。' : employment < 8 ? '近くの仕事が減り、暮らしの活力が落ちています。' : '道沿いの仕事と緑が、住民の暮らしを支えています。';
      } else if (old.kind === 'shop') {
        appeal = 35 + Math.min(48, population * .8 / Math.max(1, shops)) - aging - Math.max(0, shops - 3) * 8;
        reason = aging > 16 ? '古い店の維持負担が増え、にぎわいが弱まっています。' : population / Math.max(1, shops) < 20 ? '周囲の住民に対して店が増え、客足が分かれています。' : '近くの住民が通い、店ににぎわいが生まれています。';
      } else if (old.kind === 'farm') {
        appeal = 58 + Math.min(10, water * 2) + (cell.environment - 60) * .45 + (season === 2 ? 9 : season === 3 ? -8 : 0) - farms * 2.2 - aging;
        reason = aging > 16 ? '農地の設備が古くなり、手入れの負担が増えています。' : season === 3 ? '冬の畑は休みの季節。春に向けて力を蓄えています。' : '水と緑に恵まれた畑が、町の食と仕事を支えています。';
      } else {
        appeal = 48 + Math.min(26, population * .5) - factories * 12 + (cell.environment - 60) * .2 - aging;
        reason = aging > 16 ? '工場設備が古くなり、維持の負担が増えています。' : factories > 2 ? '周囲に工場が集まり、働き手と環境への負担が増えています。' : '近くの住民が働き、工場が町の雇用を支えています。';
      }
      if (!roads) appeal -= 15;
      cell.vitality = Math.round(clamp(old.vitality * .90 + clamp(appeal) * .10));
      cell.reason = reason;
      if (cell.vitality < 27 && old.age > 40) {
        setKind(cell, 'ruin', tick, `${reason}使われなくなり、空き家になりました。`);
        retired++;
        event(cell, 'decline', old.kind === 'house' ? '古い家が空き家に。暮らしの中心が移っています。' : old.kind === 'farm' ? '畑が休耕地になり、土地が休む時間に入りました。' : old.kind === 'shop' ? '商店が店を閉じ、次の暮らしを待っています。' : '工場が役目を終え、静かな土地になりました。');
      } else {
        const desiredLevel = cell.vitality > 76 ? 3 : cell.vitality > 58 ? 2 : 1;
        if (desiredLevel > old.level && old.age > old.level * 12 && random(world) < .045) {
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
      continue;
    }
    if (old.kind === 'ruin') {
      if (old.age >= 16 + old.variant * 2) {
        setKind(cell, 'grass', tick, '空き家が土へ戻り、緑が土地の環境を回復させています。');
        event(cell, 'nature', '空き家の跡に草が戻りました。次の暮らしへの休息です。');
      }
      continue;
    }
    if (old.kind !== 'grass') continue;
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
      if (homes < 9 && employment >= 5 && world.stats.homes < world.size * world.size * .18) {
        kind = 'house'; chance = .023 * housingPressure;
        reason = '道と近くの仕事、回復した緑に引かれて、新しい家が生まれました。';
      }
      if (population >= 18 && shops < Math.min(3, population / 24) && random(world) < .35) {
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
      if (kind && random(world) < chance) {
        setKind(cell, kind, tick, reason);
        born++;
        event(cell, 'birth', kind === 'house' ? '道と仕事のそばに、新しい家が生まれました。' : kind === 'shop' ? '住民の暮らしに応えて、商店が開きました。' : kind === 'farm' ? '緑の土地に畑ができ、食と仕事を支えます。' : '働き手が集まり、小さな工場が生まれました。');
        continue;
      }
    }
    if (old.age > 60 && !roads && green >= 3 && random(world) < .0008) {
      setKind(cell, 'tree', tick, '近くの林から木々が広がり、土地に緑が戻りました。');
      event(cell, 'nature', '林のそばに若い木が芽吹きました。');
    }
  }
  world.cells = next;
  world.tick = tick;
  world.stats = statistics(next, born, retired);
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
  if (data.version !== 1) invalid('対応していない保存形式です。');
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
    return { x, y, terrain: cell.terrain, kind, level, age: number(cell.age, '築週', 0, MAX_TICK + 24), population, vitality, environment: number(cell.environment, '環境', 0, 100), traffic: number(cell.traffic, '通行', 0, 100), variant: number(cell.variant, '外観', 0, 7), reason: string(cell.reason, '理由', 500), changedAt: number(cell.changedAt, '変化した週', 0, tick) };
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
  return { version: 1, seed, rng, size, tick, cells, stats, events, history };
}
