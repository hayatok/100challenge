import assert from 'node:assert/strict';
import test from 'node:test';
import { createWorld, restoreWorld, serializeWorld, stepWorld } from '../src/simulation.ts';
import type { World } from '../src/types.ts';

const advance = (world: World, weeks: number) => {
  for (let tick = 0; tick < weeks; tick++) stepWorld(world);
  return world;
};

function assertInvariants(world: World) {
  let population = 0;
  let jobs = 0;
  const counts: Record<string, number> = {};
  for (const [index, cell] of world.cells.entries()) {
    assert.equal(cell.x, index % world.size);
    assert.equal(cell.y, Math.floor(index / world.size));
    for (const key of ['level', 'age', 'population', 'vitality', 'environment', 'traffic', 'variant', 'changedAt'] as const) {
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
    stepWorld(world);
    for (const [index, cell] of world.cells.entries()) {
      if (cell.kind === 'road' && old[index].kind !== 'road') {
        const { x, y } = cell;
        assert.ok([x > 0 ? index - 1 : -1, x + 1 < world.size ? index + 1 : -1, y > 0 ? index - world.size : -1, y + 1 < world.size ? index + world.size : -1].some(neighbor => neighbor >= 0 && old[neighbor].kind === 'road'));
      }
      if (cell.kind === 'house' && old[index].kind === 'grass') {
        assert.ok(old.some(near => Math.abs(near.x - cell.x) <= 1 && Math.abs(near.y - cell.y) <= 1 && near.kind === 'road'));
        assert.ok(old.some(near => Math.abs(near.x - cell.x) <= 3 && Math.abs(near.y - cell.y) <= 3 && ['farm', 'shop', 'factory'].includes(near.kind)));
      }
    }
  }
});

test('many generations keep finite diverse towns and observable turnover, including rebirth', () => {
  for (const seed of [0, 1, 42, 20260930]) {
    const world = createWorld(seed);
    let minPopulation = world.stats.population;
    let growth = 0, birth = 0, decay = 0, returnToGrass = 0, rebirth = 0, roads = 0;
    const retiredSites = new Set<number>();
    let bornAt30 = 0;
    let bornAt1500 = 0;
    for (let tick = 1; tick <= 2000; tick++) {
      const old = world.cells;
      const beforeBorn = world.stats.born, beforeRetired = world.stats.retired;
      stepWorld(world);
      let newBuildings = 0, closures = 0;
      for (let index = 0; index < old.length; index++) {
        const cell = world.cells[index];
        if (old[index].level < cell.level && old[index].kind === cell.kind) growth++;
        if (old[index].kind === 'grass' && ['house', 'shop', 'farm', 'factory'].includes(cell.kind)) {
          birth++; newBuildings++;
          if (retiredSites.has(index)) rebirth++;
        }
        if (old[index].kind !== 'ruin' && cell.kind === 'ruin') { decay++; closures++; retiredSites.add(index); }
        if (old[index].kind === 'ruin' && cell.kind === 'grass') returnToGrass++;
        if (old[index].kind !== 'road' && cell.kind === 'road') roads++;
      }
      assert.equal(world.stats.born - beforeBorn, newBuildings);
      assert.equal(world.stats.retired - beforeRetired, closures);
      minPopulation = Math.min(minPopulation, world.stats.population);
      if (tick === 30) bornAt30 = world.stats.born;
      if (tick === 1500) bornAt1500 = world.stats.born;
      if (tick % 100 === 0) assertInvariants(world);
    }
    assert.ok(bornAt30 > 2, `seed ${seed}: visible births during first minute`);
    assert.ok(minPopulation > 0, `seed ${seed}: no extinction`);
    assert.ok(growth > 10 && birth > 30 && decay > 20 && returnToGrass > 20 && rebirth > 10 && roads > 0, `seed ${seed}: complete local lifecycle`);
    assert.ok(world.stats.born > bornAt1500 + 10, 'late generations are still active');
    assert.ok(world.stats.homes > 0 && world.stats.farms > 0 && world.stats.shops > 0);
    assert.ok(world.stats.factories < world.stats.homes / 3, 'factories cannot replace the entire town');
    assertConnectedRoads(world);
  }
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
  corrupt(world => { world.version = 2; });
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
