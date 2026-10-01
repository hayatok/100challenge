import assert from 'node:assert/strict';
import test from 'node:test';
import { advanceResidents, createWorld, restoreWorld, serializeWorld, stepWorld } from '../src/simulation.ts';
import { findRoute, jobCapacity, neighbors, synchronizeResidents } from '../src/mobility.ts';
import type { World } from '../src/types.ts';

const advance = (world: World, weeks: number) => {
  for (let tick = 0; tick < weeks; tick++) { advanceResidents(world, 4); stepWorld(world); }
  return world;
};

function assertInvariants(world: World) {
  let population = 0;
  let jobs = 0;
  const counts: Record<string, number> = {};
  for (const [index, cell] of world.cells.entries()) {
    assert.equal(cell.x, index % world.size);
    assert.equal(cell.y, Math.floor(index / world.size));
    for (const key of ['level', 'age', 'population', 'vitality', 'environment', 'traffic', 'variant', 'changedAt', 'moisture', 'fertility', 'vegetation', 'crop', 'condition', 'development', 'employed', 'customers'] as const) {
      assert.ok(Number.isFinite(cell[key]) && cell[key] >= 0, `${key} must stay finite and nonnegative`);
    }
    assert.ok(cell.environment <= 100 && cell.vitality <= 100 && cell.traffic <= 100);
    assert.ok(cell.changedAt <= world.tick);
    assert.ok(cell.reason.length > 0);
    if (cell.terrain === 'water') assert.ok(cell.kind === 'water' || cell.kind === 'road');
    if (cell.kind !== 'house') assert.equal(cell.population, 0);
    population += cell.population;
    if (cell.kind === 'farm') jobs += 5 + cell.level * 3;
    if (cell.kind === 'factory') jobs += 12 + cell.level * 5;
    if (cell.kind === 'shop') jobs += 3 + cell.level * 2;
    counts[cell.kind] = (counts[cell.kind] ?? 0) + 1;
  }
  for (const key of ['moisture', 'fertility', 'vegetation', 'crop', 'condition', 'development'] as const) assert.ok(world.cells.every(cell => cell[key] <= 100));
  assert.equal(world.version, 2);
  assert.ok(Number.isFinite(world.clock) && world.clock >= 0);
  assert.ok(world.residents.every(person => person.id < world.nextResidentId));
  assert.equal(new Set(world.residents.map(person => person.id)).size, world.residents.length);
  assert.ok(Number.isFinite(world.economy.food) && world.economy.food >= 0 && world.economy.food <= 10000);
  assert.equal(world.stats.population, population);
  assert.equal(world.stats.jobs, jobs);
  for (const [stat, kind] of [['homes', 'house'], ['shops', 'shop'], ['farms', 'farm'], ['factories', 'factory'], ['ruins', 'ruin'], ['roads', 'road']] as const) assert.equal(world.stats[stat], counts[kind] ?? 0);
  assert.ok(world.events.length <= 18 && world.history.length <= 180);
  assert.deepEqual(world.history.at(-1), { tick: world.tick, population });
}

function assertConnectedRoads(world: World) {
  const roads = world.cells.flatMap((cell, index) => cell.kind === 'road' ? [index] : []);
  const seen = new Set([roads[0]]);
  const queue = [roads[0]];
  for (let current = 0; current < queue.length; current++) {
    const index = queue[current];
    const { x, y } = world.cells[index];
    const neighbors = [x > 0 ? index - 1 : -1, x + 1 < world.size ? index + 1 : -1, y > 0 ? index - world.size : -1, y + 1 < world.size ? index + world.size : -1];
    for (const neighbor of neighbors) {
      if (neighbor >= 0 && world.cells[neighbor].kind === 'road' && !seen.has(neighbor)) { seen.add(neighbor); queue.push(neighbor); }
    }
  }
  assert.equal(seen.size, roads.length, 'every road must connect through cardinal neighbors');
}

test('seed reproduces terrain, hamlets and future, including seed zero', () => {
  for (const seed of [0, 42, 0xffffffff]) {
    assert.equal(serializeWorld(advance(createWorld(seed), 80)), serializeWorld(advance(createWorld(seed), 80)));
  }
  assert.notEqual(serializeWorld(createWorld(42)), serializeWorld(createWorld(43)));
  for (const seed of [-1, 1.5, NaN, Infinity, 0x100000000]) assert.throws(() => createWorld(seed), /種/);
  for (const size of [23, 65, NaN, 48.5]) assert.throws(() => createWorld(1, size), /大きさ/);
});

test('initial river crossing connects two green hamlets and growth stays on land', () => {
  for (const size of [24, 48, 64]) {
    const world = createWorld(20260930, size);
    const terrain = world.cells.map(cell => cell.terrain);
    assert.ok(world.cells.some(cell => cell.kind === 'tree'));
    assert.ok(world.cells.some(cell => cell.terrain === 'water' && cell.kind === 'road'), 'river has a bridge');
    assert.ok(world.cells.some(cell => cell.kind === 'house' && cell.x < size / 2));
    assert.ok(world.cells.some(cell => cell.kind === 'house' && cell.x > size / 2));
    assertConnectedRoads(world);
    advance(world, 200);
    assert.deepEqual(world.cells.map(cell => cell.terrain), terrain);
    assertConnectedRoads(world);
    assertInvariants(world);
  }
});

test('updates use the previous neighborhood and newly built roads connect to an old road', () => {
  const world = createWorld(731);
  for (let week = 0; week < 100; week++) {
    const old = world.cells;
    advanceResidents(world, 4);
    stepWorld(world);
    for (const [index, cell] of world.cells.entries()) {
      if (cell.kind === 'road' && old[index].kind !== 'road') {
        const { x, y } = cell;
        assert.ok([x > 0 ? index - 1 : -1, x + 1 < world.size ? index + 1 : -1, y > 0 ? index - world.size : -1, y + 1 < world.size ? index + world.size : -1].some(neighbor => neighbor >= 0 && old[neighbor].kind === 'road'));
      }
      if (cell.kind === 'house' && old[index].kind === 'grass') {
        assert.ok(old.some(near => Math.abs(near.x - cell.x) <= 1 && Math.abs(near.y - cell.y) <= 1 && near.kind === 'road'));
        const previousWorld = { ...world, cells: old };
        assert.ok(old.some((workplace, destination) => jobCapacity(workplace) > 0 && findRoute(previousWorld, index, destination)), 'new homes require a road-reachable workplace');
      }
    }
  }
});

test('long observations retain finite diverse towns with real activity and accurate event counts', () => {
  for (const seed of [0, 1, 42, 20260930]) {
    const world = createWorld(seed);
    for (let week = 0; week < 384; week++) {
      const old = world.cells;
      const beforeBorn = world.stats.born, beforeRetired = world.stats.retired;
      advance(world, 1);
      const births = world.cells.filter((cell, index) => old[index].kind === 'grass' && ['house', 'shop', 'farm', 'factory'].includes(cell.kind)).length;
      const closures = world.cells.filter((cell, index) => old[index].kind !== 'ruin' && cell.kind === 'ruin').length;
      assert.equal(world.stats.born - beforeBorn, births);
      assert.equal(world.stats.retired - beforeRetired, closures);
      if (week % 48 === 0) assertInvariants(world);
    }
    assert.ok(world.stats.population > 0 && world.stats.homes > 0);
    assert.ok(world.stats.farms > 0 && world.stats.shops > 0);
    assert.ok(world.economy.commutes > 0 && world.economy.visits > 0, 'people must actually arrive');
    assert.ok(world.stats.factories < world.stats.homes, 'industry does not replace housing');
    assertConnectedRoads(world);
    assertInvariants(world);
  }
});

test('reachable jobs respect capacity and a disconnected road network supplies no employment', () => {
  const world = createWorld(42);
  const occupancy = new Map<number, number>();
  for (const person of world.residents) {
    if (person.workplace === null) continue;
    const route = findRoute(world, person.home, person.workplace);
    assert.ok(route && route.some(index => world.cells[index].kind === 'road'));
    assert.ok(route.every((index, n) => n === 0 || neighbors(world, route[n - 1]).includes(index)), 'paths take cardinal steps');
    occupancy.set(person.workplace, (occupancy.get(person.workplace) ?? 0) + 1);
    assert.ok(occupancy.get(person.workplace)! <= jobCapacity(world.cells[person.workplace]));
  }
  assert.ok(world.economy.employed > 0);
  for (const cell of world.cells) if (cell.kind === 'road') cell.kind = cell.terrain === 'water' ? 'water' : 'grass';
  synchronizeResidents(world);
  assert.equal(world.economy.employed, 0);
  assert.ok(world.residents.every(person => person.workplace === null && person.shop === null));
  advanceResidents(world, 4);
  assert.equal(world.economy.commutes, 0);
});

test('weekly updates preserve a continuous in-flight journey and save its exact position', () => {
  const world = createWorld(42);
  const person = world.residents.find(resident => resident.workplace !== null)!;
  person.timer = 0;
  advanceResidents(world, .5);
  assert.equal(person.state, 'travel');
  assert.ok(person.progress > 0 && person.progress < 1);
  const snapshot = { x: person.x, y: person.y, route: [...person.route], routeIndex: person.routeIndex, progress: person.progress, clock: world.clock };
  stepWorld(world);
  const current = world.residents.find(resident => resident.id === person.id)!;
  assert.deepEqual({ x: current.x, y: current.y, route: current.route, routeIndex: current.routeIndex, progress: current.progress, clock: world.clock }, snapshot);
  const restored = restoreWorld(serializeWorld(world));
  assert.deepEqual(restored, world);
  advanceResidents(world, .25);
  advanceResidents(restored, .25);
  assert.deepEqual(restored, world);
  assert.ok(Math.hypot(current.x - snapshot.x, current.y - snapshot.y) <= .27, 'motion continues from the saved fraction of a step');
});

test('standing crops require arriving workers to become harvested food', () => {
  const world = createWorld(42);
  world.residents = [];
  for (const cell of world.cells) if (cell.kind === 'farm') { cell.crop = 100; cell.employed = 0; }
  stepWorld(world);
  assert.equal(world.economy.harvest, 0);
  assert.ok(world.cells.filter(cell => cell.kind === 'farm').every(cell => cell.crop === 100));
  const farm = world.cells.find(cell => cell.kind === 'farm')!;
  farm.employed = 1;
  stepWorld(world);
  assert.ok(world.economy.harvest > 0);
  assert.ok(farm.crop !== world.cells[farm.y * world.size + farm.x].crop);
});

test('profitable old homes can repair instead of retiring solely because of age', () => {
  const world = createWorld(42);
  const home = world.residents.find(person => person.workplace !== null)!.home;
  const cell = world.cells[home];
  cell.age = 5000; cell.condition = 70; cell.vitality = 80;
  for (const person of world.residents.filter(person => person.home === home && person.workplace !== null)) world.cells[person.workplace!].employed = 3;
  stepWorld(world);
  assert.equal(world.cells[home].kind, 'house');
  assert.ok(world.cells[home].condition > 70);
});

test('v1 migration preserves the original town and validates it before adding residents', () => {
  const original = createWorld(20260930);
  const legacy = JSON.parse(serializeWorld(original));
  legacy.version = 1;
  for (const key of ['clock', 'nextResidentId', 'residents', 'weather', 'economy']) delete legacy[key];
  for (const cell of legacy.cells) for (const key of ['moisture', 'fertility', 'vegetation', 'crop', 'condition', 'development', 'employed', 'customers', 'accessible']) delete cell[key];
  const migrated = restoreWorld(JSON.stringify(legacy));
  assert.equal(migrated.version, 2);
  assert.equal(migrated.seed, original.seed);
  assert.equal(migrated.rng, original.rng);
  assert.deepEqual(migrated.cells.map(({ x, y, terrain, kind, age, population }) => ({ x, y, terrain, kind, age, population })), original.cells.map(({ x, y, terrain, kind, age, population }) => ({ x, y, terrain, kind, age, population })));
  assert.deepEqual(migrated.stats, original.stats);
  assert.ok(migrated.residents.length > 0 && migrated.nextResidentId > 0);
  assert.deepEqual(restoreWorld(serializeWorld(migrated)), migrated);
  legacy.cells[0].x = 100;
  assert.throws(() => restoreWorld(JSON.stringify(legacy)), /読み込めません/);
});

test('resident identifiers are not reused when a household gets a replacement worker', () => {
  const world = createWorld(42);
  const removed = world.residents.pop()!;
  const next = world.nextResidentId;
  synchronizeResidents(world);
  assert.ok(world.residents.some(person => person.home === removed.home && person.id === next));
  assert.ok(world.nextResidentId > next);
  assert.deepEqual(restoreWorld(serializeWorld(world)), world);
});

test('restoring a saved town reproduces the exact random continuation', () => {
  for (const tick of [0, 1, 250]) {
    const original = advance(createWorld(975), tick);
    const restored = restoreWorld(serializeWorld(original));
    assert.deepEqual(restored, original);
    advance(original, 50);
    advance(restored, 50);
    assert.equal(serializeWorld(restored), serializeWorld(original));
  }
});

test('bounded strict restore rejects corrupted, inconsistent and unsupported data', () => {
  assert.throws(() => restoreWorld('{bad'), /JSON/);
  assert.throws(() => restoreWorld('x'.repeat(4_000_001)), /大き/);
  const original = serializeWorld(advance(createWorld(7), 50));
  const corrupt = (mutate: (world: any) => void) => {
    const world = JSON.parse(original);
    mutate(world);
    assert.throws(() => restoreWorld(JSON.stringify(world)), /読み込めません/);
  };
  corrupt(world => { world.version = 3; });
  corrupt(world => { world.nextResidentId = world.residents[0].id; });
  corrupt(world => { world.residents[0].progress = null; });
  corrupt(world => { world.economy.employed++; });
  corrupt(world => { world.cells[0].moisture = null; });
  corrupt(world => { world.weather.kind = 'storm'; });
  corrupt(world => { world.size = 48.5; });
  corrupt(world => { world.tick = -1; });
  corrupt(world => { world.seed = -1; });
  corrupt(world => { world.rng = 0x100000000; });
  corrupt(world => { world.rng = null; });
  corrupt(world => { world.cells.pop(); });
  corrupt(world => { world.cells[0].x = 1; });
  corrupt(world => { world.cells[0].kind = 'castle'; });
  corrupt(world => { world.cells[0].environment = -1; });
  corrupt(world => { world.cells[0].environment = null; });
  corrupt(world => { world.cells[0].level = 4; });
  corrupt(world => { world.cells[0].changedAt = 51; });
  corrupt(world => { world.cells[0].reason = 'x'.repeat(501); });
  corrupt(world => { const cell = world.cells.find((cell: any) => cell.terrain === 'water'); cell.kind = 'house'; });
  corrupt(world => { world.stats.population++; });
  corrupt(world => { world.stats.born = -1; });
  corrupt(world => { world.stats.environment = '80'; });
  corrupt(world => { world.events = Array.from({ length: 19 }, () => world.events[0]); });
  corrupt(world => { world.events[0].kind = 'mystery'; });
  corrupt(world => { world.history = []; });
  corrupt(world => { world.history.at(-1).population++; });
  corrupt(world => { world.history[0].tick = 20; });
});
