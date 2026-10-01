import { DAY_SECONDS, YEAR_DAYS, EVENT_LIMIT, FIRE_BLOCK, FLOOD_BLOCK, MIN_ROAD_CONDITION, SIM_STEP } from './constants.ts';
import type { Cell, PowerCommand, PowerInput, PowerKind, World } from './types.ts';

const POWER_KINDS: PowerKind[] = ['rain', 'sun', 'storm', 'lightning', 'earthquake', 'meteor', 'growth', 'settle'];
const clamp = (value: number, high = 100) => Math.max(0, Math.min(high, value));
const buildings = new Set(['house', 'shop', 'farm', 'factory']);
const names: Record<PowerKind, string> = { rain: '恵みの雨', sun: '日差し', storm: '嵐', lightning: '雷', earthquake: '地震', meteor: '隕石', growth: '芽吹き', settle: '入植' };

export function isPassable(cell: Cell): boolean {
  return !cell.closed && cell.waterDepth < FLOOD_BLOCK && cell.fire < FIRE_BLOCK
    && (cell.terrain !== 'water' || cell.kind === 'road')
    && cell.kind !== 'water' && (cell.kind !== 'road' || cell.condition >= MIN_ROAD_CONDITION);
}

function event(world: World, command: Pick<PowerCommand, 'target' | 'kind' | 'source'>, text: string) {
  world.events.push({ tick: world.tick, x: command.target.x, y: command.target.y, kind: command.source === 'god' ? 'god' : 'disaster', text });
  if (world.events.length > EVENT_LIMIT) world.events.splice(0, world.events.length - EVENT_LIMIT);
}

function nextSeed(value: number): number { return (Math.imul(value >>> 0, 1664525) + 1013904223) >>> 0; }
function hazardRandom(world: World): number { world.hazardRng = nextSeed(world.hazardRng); return world.hazardRng / 0x100000000; }

/** Commands consume no simulation/hazard randomness until their fixed application step. */
export function queuePower(world: World, input: PowerInput): PowerCommand {
  if (!input || !POWER_KINDS.includes(input.kind)) throw new Error('神の力の種類が不正です。');
  if (!input.target || !Number.isFinite(input.target.x) || !Number.isFinite(input.target.y)
    || input.target.x < 0 || input.target.y < 0 || input.target.x > world.size - 1 || input.target.y > world.size - 1) throw new Error('対象地点は地図の中を選んでください。');
  for (const key of ['radius', 'intensity', 'duration'] as const) if (!Number.isFinite(input[key])) throw new Error('範囲・強さ・期間は有限の数で指定してください。');
  if (input.radius < 0 || input.radius > Math.ceil(Math.hypot(world.size, world.size))) throw new Error('範囲が不正です。');
  if (input.intensity < 1 || input.intensity > 4) throw new Error('強さは1から4で指定してください。');
  if (input.duration < 0 || input.duration > 3600) throw new Error('期間は0から3600秒で指定してください。');
  if (input.source !== undefined && input.source !== 'god' && input.source !== 'nature') throw new Error('命令の発生元が不正です。');
  const id = world.nextCommandId++;
  const command: PowerCommand = {
    kind: input.kind, target: { x: Math.round(input.target.x), y: Math.round(input.target.y) },
    radius: Math.round(input.radius * 100) / 100, intensity: input.intensity,
    duration: Math.round(input.duration / SIM_STEP) * SIM_STEP,
    id, atStep: world.step + 1, source: input.source ?? 'god',
    seed: nextSeed((world.seed ^ Math.imul(id + 1, 2654435761) ^ Math.imul(world.step + 1, 2246822519)) >>> 0),
  };
  world.pending.push(command);
  world.revision++;
  return command;
}

export function cancelPendingPowers(world: World): void {
  if (world.pending.length) { world.pending = []; world.revision++; }
}

function distance(cell: { x: number; y: number }, command: Pick<PowerCommand, 'target'>) { return Math.hypot(cell.x - command.target.x, cell.y - command.target.y); }
function inside(cell: { x: number; y: number }, command: Pick<PowerCommand, 'target' | 'radius'>) { return distance(cell, command) <= command.radius + .001; }
function touch(world: World, cell: Cell, oldKind: Cell['kind'], oldPassable: boolean) {
  if (oldKind !== cell.kind || oldPassable !== isPassable(cell)) world.topologyVersion++;
  cell.changedAt = world.tick;
  world.revision++;
}

function damage(cell: Cell, amount: number, reason: string) {
  if (!buildings.has(cell.kind) && cell.kind !== 'road') return;
  cell.condition = clamp(cell.condition - amount);
  cell.reason = reason;
  if (cell.kind === 'road') {
    if (cell.condition < MIN_ROAD_CONDITION) { cell.closed = true; cell.rubble = clamp(cell.rubble + amount * .35); }
  } else if (cell.condition <= 0) {
    cell.kind = 'ruin'; cell.level = 0; cell.population = 0; cell.vitality = 0; cell.employed = 0; cell.customers = 0;
    cell.buildingPlan = null;
    cell.stock = 0; cell.materials = 0; cell.work = 0; cell.rubble = clamp(cell.rubble + 70); cell.closed = true;
  }
}

function applyInstant(world: World, command: PowerCommand) {
  let rng = command.seed;
  for (const cell of world.cells) {
    if (!inside(cell, command)) continue;
    const oldKind = cell.kind, oldPassable = isPassable(cell);
    const falloff = Math.max(.15, 1 - distance(cell, command) / Math.max(1, command.radius + 1));
    rng = nextSeed(rng);
    const variation = .8 + rng / 0x100000000 * .4;
    if (command.kind === 'earthquake') {
      damage(cell, (command.intensity * 26 + cell.rubble * .12) * falloff * variation, '地震で損傷しました。資材と修繕が必要です。');
      if (cell.kind === 'road' && cell.terrain === 'water') damage(cell, command.intensity * 22, '橋が揺れで傷み、通行の安全を確認できません。');
      cell.rubble = clamp(cell.rubble + command.intensity * 5 * falloff);
    } else if (command.kind === 'lightning') {
      damage(cell, 38 * command.intensity * falloff, '雷で損傷し、周囲の火に注意が必要です。');
      cell.fire = clamp(cell.fire + 40 * command.intensity * falloff * (1 - cell.moisture / 115) - cell.waterDepth * 70);
      cell.vegetation = clamp(cell.vegetation - 12 * command.intensity * falloff);
    } else if (command.kind === 'meteor') {
      const ending = command.intensity === 4;
      const force = ending ? 1000 : 90 * command.intensity * falloff;
      damage(cell, force, '隕石の衝撃で損壊しました。住民は安全な場所を探します。');
      cell.crater = clamp(cell.crater + (ending ? 100 : 35 * command.intensity * falloff));
      cell.elevation = Math.max(-10, cell.elevation - command.intensity * .35 * falloff);
      cell.rubble = clamp(cell.rubble + command.intensity * 18 * falloff);
      cell.buildingPlan = null;
      cell.vegetation = clamp(cell.vegetation - force); cell.crop = clamp(cell.crop - force);
      cell.fire = cell.terrain === 'water' ? 0 : clamp(cell.fire + 70 * command.intensity * falloff - cell.waterDepth * 50);
      cell.fertility = clamp(cell.fertility - command.intensity * 12 * falloff);
      if (cell.kind === 'grass' || cell.kind === 'tree' || cell.kind === 'park') { cell.kind = 'grass'; cell.level = 0; }
      cell.reason = ending ? '終末規模の隕石が通り、深いクレーターと瓦礫が残っています。' : '隕石の跡にクレーターが残っています。';
    }
    touch(world, cell, oldKind, oldPassable);
  }
  if (command.kind === 'lightning' || command.kind === 'meteor' || command.kind === 'earthquake') {
    for (const person of world.residents) {
      if (!inside(person, command)) continue;
      const falloff = Math.max(.15, 1 - distance(person, command) / Math.max(1, command.radius + 1));
      const loss = command.kind === 'meteor' ? command.intensity === 4 ? 1000 : 110 * command.intensity * falloff
        : command.kind === 'lightning' ? 22 * command.intensity * falloff : 10 * command.intensity * falloff;
      person.health = clamp(person.health - loss);
    }
  }
}

export function applyPendingPowers(world: World): PowerCommand[] {
  const due = world.pending.filter(command => command.atStep <= world.step).sort((a, b) => a.atStep - b.atStep || a.id - b.id);
  world.pending = world.pending.filter(command => command.atStep > world.step);
  for (const command of due) {
    event(world, command, `${command.source === 'god' ? 'あなたが' : '自然の力で'}${names[command.kind]}を${command.target.x + 1},${command.target.y + 1}に与えました。`);
    if (command.kind === 'settle' || command.kind === 'earthquake' || command.kind === 'lightning' || command.kind === 'meteor') {
      if (command.kind !== 'settle') applyInstant(world, command);
      // The physical strike occurs exactly once; its saveable marker lasts for drawing only.
      const remaining = command.kind === 'lightning' ? .75 : command.kind === 'meteor' ? 1.75 : 2;
      world.effects.push({ ...command, target: { ...command.target }, elapsed: 0, remaining });
    } else world.effects.push({ ...command, target: { ...command.target }, elapsed: 0, remaining: Math.max(SIM_STEP, command.duration) });
  }
  if (due.length) world.revision++;
  return due;
}

function weatherStep(world: World, dt: number) {
  const weather = world.weather;
  if (weather.kind === 'storm' && (world.naturalPolicy === 'off' || world.naturalPolicy === 'gentle')) {
    weather.kind = 'rain'; weather.rainfall = .018; weather.windX *= .25; weather.windY *= .25;
  }
  weather.temperature = 14 + Math.sin(world.clock / (DAY_SECONDS * YEAR_DAYS) * Math.PI * 2) * 12;
  weather.remaining -= dt;
  if (weather.remaining <= 0) {
    const roll = hazardRandom(world), wild = world.naturalPolicy === 'wild' || world.naturalPolicy === 'apocalyptic';
    weather.kind = roll < .35 ? 'clear' : roll < .65 ? 'cloudy' : roll < (wild ? .87 : 1) ? weather.temperature < 5 ? 'snow' : 'rain' : 'storm';
    weather.rainfall = weather.kind === 'storm' ? .16 : weather.kind === 'rain' ? .018 : weather.kind === 'snow' ? .006 : 0;
    weather.cloud = weather.kind === 'clear' ? 10 : weather.kind === 'cloudy' ? 55 : 90;
    weather.windX = (hazardRandom(world) - .5) * (weather.kind === 'storm' ? 1.8 : .5);
    weather.windY = (hazardRandom(world) - .5) * (weather.kind === 'storm' ? 1.8 : .5);
    weather.remaining = 35 + hazardRandom(world) * 65;
    weather.frontX = hazardRandom(world) * world.size; weather.frontY = hazardRandom(world) * world.size;
    weather.frontRadius = world.size * (wild ? .18 + hazardRandom(world) * .2 : .32 + hazardRandom(world) * .2);
    if (world.naturalPolicy === 'apocalyptic' && hazardRandom(world) < .035) {
      queuePower(world, { kind: 'meteor', target: { x: Math.floor(world.size / 2), y: Math.floor(world.size / 2) }, radius: Math.ceil(Math.hypot(world.size, world.size)), intensity: 4, duration: 0, source: 'nature' });
    } else if (wild && hazardRandom(world) < .035) {
      queuePower(world, { kind: 'earthquake', target: { x: Math.floor(hazardRandom(world) * world.size), y: Math.floor(hazardRandom(world) * world.size) }, radius: 3, intensity: 1, duration: 0, source: 'nature' });
    }
  }
  weather.frontX += weather.windX * dt * .18; weather.frontY += weather.windY * dt * .18;
  if (weather.frontX < -weather.frontRadius) weather.frontX = world.size + weather.frontRadius;
  if (weather.frontX > world.size + weather.frontRadius) weather.frontX = -weather.frontRadius;
  if (weather.frontY < -weather.frontRadius) weather.frontY = world.size + weather.frontRadius;
  if (weather.frontY > world.size + weather.frontRadius) weather.frontY = -weather.frontRadius;
  if ((world.naturalPolicy === 'wild' || world.naturalPolicy === 'apocalyptic') && weather.kind === 'storm' && hazardRandom(world) < dt * .006) {
    const x = Math.round(Math.max(0, Math.min(world.size - 1, weather.frontX))), y = Math.round(Math.max(0, Math.min(world.size - 1, weather.frontY)));
    queuePower(world, { kind: 'lightning', target: { x, y }, radius: 1, intensity: 1, duration: 0, source: 'nature' });
  }
}

function cardinals(index: number, size: number): number[] {
  const x = index % size, y = Math.floor(index / size);
  return [x > 0 ? index - 1 : -1, x + 1 < size ? index + 1 : -1, y > 0 ? index - size : -1, y + 1 < size ? index + size : -1].filter(index => index >= 0);
}

/** All land overlays advance on the caller's shared fixed clock, including after extinction. */
export function advanceDisasters(world: World, dt: number): void {
  if (!Number.isFinite(dt) || dt <= 0) return;
  weatherStep(world, dt);
  const oldPassable = world.cells.map(isPassable), oldKinds = world.cells.map(cell => cell.kind);
  const fires = world.cells.map(cell => cell.fire);
  const incoming = new Float64Array(world.cells.length);
  const effects = world.effects;
  const weather = world.weather;
  for (const [index, cell] of world.cells.entries()) {
    const localWeather = Math.hypot(cell.x - weather.frontX, cell.y - weather.frontY) <= weather.frontRadius;
    let rain = localWeather ? weather.rainfall : 0, sunlight = weather.kind === 'clear' ? 1 : .35, wind = localWeather && weather.kind === 'storm' ? 1 : 0;
    for (const effect of effects) {
      if (!inside(cell, effect)) continue;
      const seconds = Math.min(dt, effect.remaining);
      const scale = seconds / dt;
      if (effect.kind === 'rain') rain += .032 * effect.intensity * scale;
      if (effect.kind === 'storm') { rain += .11 * effect.intensity * scale; wind += effect.intensity * scale; }
      if (effect.kind === 'sun') { rain = 0; sunlight += effect.intensity * 2 * scale; }
      if (effect.kind === 'growth' && cell.terrain === 'land') {
        cell.fertility = clamp(cell.fertility + .8 * effect.intensity * seconds);
        cell.vegetation = clamp(cell.vegetation + 1.7 * effect.intensity * seconds);
        cell.rubble = clamp(cell.rubble - .35 * effect.intensity * seconds);
        if (cell.kind === 'grass' && cell.vegetation > 75 && cell.fire < 1 && cell.waterDepth < .5) { cell.kind = 'tree'; cell.reason = '芽吹きが若い木を育てています。人や家は自然には戻りません。'; }
      }
    }
    const snowing = localWeather && weather.kind === 'snow' && rain > 0;
    if (snowing) { cell.snow = clamp(cell.snow + rain * dt * 30); rain = 0; }
    const melt = Math.min(cell.snow, Math.max(0, weather.temperature) * .012 * dt);
    cell.snow -= melt;
    cell.waterDepth = clamp(cell.waterDepth + rain * dt + melt * .025, 40);
    // A narrow riverbank keeps groundwater; high inland plots still dry between fronts.
    const bank = cell.terrain === 'land' && cardinals(index, world.size).some(n => world.cells[n].terrain === 'water') ? .12 : 0;
    cell.moisture = clamp(cell.moisture + bank * dt + (rain * 150 + cell.waterDepth * 1.4 - sunlight * .07) * dt);
    const infiltration = cell.terrain === 'land' ? (.008 + (100 - cell.moisture) * .00015) * dt : 0;
    cell.waterDepth = Math.max(0, cell.waterDepth - infiltration - .002 * sunlight * dt);
    if (cell.terrain === 'water') cell.waterDepth = Math.max(0, cell.waterDepth - .055 * dt);
    cell.fire = clamp(cell.fire - (rain * 220 + cell.waterDepth * 85 + cell.moisture * .035 + (cell.vegetation < 2 ? 8 : .5)) * dt);
    if (cell.fire > 0) {
      cell.vegetation = clamp(cell.vegetation - cell.fire * .09 * dt);
      cell.crop = clamp(cell.crop - cell.fire * .1 * dt);
      damage(cell, cell.fire * .055 * dt, '火災で傷み、住民は避難が必要です。');
      for (const neighbor of cardinals(index, world.size)) {
        const target = world.cells[neighbor];
        if (fires[index] > 30 && target.terrain !== 'water' && target.waterDepth < .12 && target.moisture < 70 && (target.vegetation > 8 || buildings.has(target.kind))
          && hazardRandom(world) < dt * .045 * (1 + wind) * (1 - target.moisture / 100)) incoming[neighbor] += 10 + wind * 5;
      }
    }
    if (cell.waterDepth > .8) {
      damage(cell, Math.max(0, cell.waterDepth - .8) * .28 * dt, '増水で損傷しています。水が引いても修繕が必要です。');
      cell.crop = clamp(cell.crop - Math.max(0, cell.waterDepth - 1) * dt * 2);
    }
    if (wind > 0) damage(cell, wind * .06 * dt, '嵐の風で建物や橋が傷んでいます。');
  }
  // Use a frozen water surface and simultaneous flux; scan order cannot create or lose water.
  const surfaces = world.cells.map(cell => cell.elevation + cell.waterDepth);
  const flux = new Float64Array(world.cells.length);
  for (const [index, cell] of world.cells.entries()) {
    if (cell.waterDepth <= .001) continue;
    const lower = cardinals(index, world.size).filter(neighbor => surfaces[neighbor] + .01 < surfaces[index]);
    let total = 0;
    const flows = lower.map(neighbor => { const value = (surfaces[index] - surfaces[neighbor]) * .22 * dt; total += value; return value; });
    const factor = total > cell.waterDepth ? cell.waterDepth / total : 1;
    for (let slot = 0; slot < lower.length; slot++) { const amount = flows[slot] * factor; flux[index] -= amount; flux[lower[slot]] += amount; }
  }
  for (const [index, cell] of world.cells.entries()) {
    cell.waterDepth = clamp(cell.waterDepth + flux[index], 40);
    cell.fire = clamp(cell.fire + incoming[index] - cell.waterDepth * 50 * dt);
    if (oldPassable[index] !== isPassable(cell) || oldKinds[index] !== cell.kind) { world.topologyVersion++; cell.changedAt = world.tick; }
  }
  for (const person of world.residents) {
    const cell = world.cells[Math.round(person.y) * world.size + Math.round(person.x)];
    if (cell) person.health = clamp(person.health - (Math.max(0, cell.fire - 20) * .035 + Math.max(0, cell.waterDepth - 2) * .55) * dt);
  }
  for (const effect of effects) { effect.elapsed += Math.min(dt, effect.remaining); effect.remaining = Math.max(0, effect.remaining - dt); }
  world.effects = effects.filter(effect => effect.remaining > 0);
  world.revision++;
}
