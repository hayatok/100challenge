import assert from 'node:assert/strict';
import test from 'node:test';
import { advanceDisasters, applyPendingPowers, cancelPendingPowers, isPassable, queuePower } from '../src/disasters.ts';
import type { Cell, PowerInput, Resident, World } from '../src/types.ts';

function fixture(size = 7): World {
  const cells: Cell[] = Array.from({ length: size * size }, (_, index) => ({
    x: index % size, y: Math.floor(index / size), terrain: 'land', kind: 'grass', level: 0,
    age: 0, population: 0, vitality: 80, environment: 80, traffic: 0, variant: 0,
    reason: 'fixture', changedAt: 0, moisture: 45, fertility: 60, vegetation: 40, crop: 0,
    condition: 100, development: 0, employed: 0, customers: 0, accessible: true,
    elevation: 1, waterDepth: 0, fire: 0, snow: 0, rubble: 0, crater: 0, stock: 0, materials: 0, work: 0, region: 0, closed: false, buildingPlan: null,
  }));
  return {
    version: 3, step: 0, remainder: 0, revision: 0, topologyVersion: 0, hazardRng: 17,
    nextCommandId: 0, pending: [], effects: [], shipments: [], nextShipmentId: 0,
    naturalPolicy: 'off', migrationGrace: 0, clock: 0, nextResidentId: 0, residents: [],
    weather: { kind: 'clear', temperature: 18, rainfall: 0, cloud: 0, windX: 0, windY: 0, remaining: 0, frontX: 0, frontY: 0, frontRadius: 2 },
    economy: { workers: 0, employed: 0, food: 0, harvest: 0, visits: 0, commutes: 0, materials: 0, starving: 0, evacuated: 0, deaths: 0, births: 0, arrivals: 0, departures: 0, failedPurchases: 0 },
    seed: 17, rng: 21, size, tick: 0, cells,
    stats: { population: 0, homes: 0, shops: 0, farms: 0, factories: 0, ruins: 0, roads: 0, environment: 80, jobs: 0, born: 0, retired: 0 }, events: [], history: [],
  };
}
function resident(world: World, x: number, y: number): Resident {
  return { id: world.nextResidentId++, role: 'worker', health: 100, hunger: 0, food: 5, shelter: null, displaced: false, home: y * world.size + x, workplace: null, shop: null, x, y, route: [], routeIndex: 0, progress: 0, state: 'home', purpose: 'stroll', destination: null, timer: 0, color: 0, trips: 0 };
}
const input = (kind: PowerInput['kind'], overrides: Partial<PowerInput> = {}): PowerInput => ({ kind, target: { x: 3, y: 3 }, radius: 2, intensity: 1, duration: 10, ...overrides });
function step(world: World, count = 1) { for (let index = 0; index < count; index++) { world.step++; world.clock += .25; applyPendingPowers(world); advanceDisasters(world, .25); } }

test('queue validates and normalizes, applies next step in stable ID order with unlimited overlapping commands', () => {
  const world = fixture(), twin = fixture();
  for (let index = 0; index < 100; index++) {
    const command = queuePower(world, input('rain', { target: { x: 2.4, y: 3.6 }, duration: 1.12 }));
    assert.deepEqual(command, queuePower(twin, input('rain', { target: { x: 2.4, y: 3.6 }, duration: 1.12 })));
    assert.equal(command.id, index); assert.equal(command.atStep, 1);
    assert.deepEqual(command.target, { x: 2, y: 4 }); assert.equal(command.duration, 1);
  }
  assert.equal(world.rng, 21); assert.equal(world.hazardRng, 17);
  assert.deepEqual(applyPendingPowers(world), []);
  world.pending.reverse(); world.step++;
  assert.deepEqual(applyPendingPowers(world).map(command => command.id), Array.from({ length: 100 }, (_, id) => id));
  assert.equal(world.effects.length, 100); assert.equal(world.pending.length, 0);
  for (const overrides of [{ radius: -1 }, { radius: 1000 }, { intensity: 0 }, { intensity: 5 }, { duration: Infinity }, { target: { x: -1, y: 3 } }]) assert.throws(() => queuePower(world, input('rain', overrides)));
  queuePower(world, input('rain')); cancelPendingPowers(world); assert.equal(world.pending.length, 0);
  assert.equal(world.effects.length, 100, 'cancel reservations does not undo applied effects');
});

test('rain moistens soil, stacks water, preserves terrain, and expires on shared time', () => {
  const wet = fixture(), dry = fixture();
  const center = 3 * wet.size + 3;
  wet.cells[center].kind = 'farm'; wet.cells[center].elevation = -1;
  wet.cells[center].crop = 20;
  queuePower(wet, input('rain', { intensity: 2, duration: 30 }));
  queuePower(wet, input('rain', { intensity: 2, duration: 30 }));
  step(wet, 120); step(dry, 120);
  assert.ok(wet.cells[center].moisture > dry.cells[center].moisture + 20);
  assert.ok(wet.cells[center].waterDepth > 1);
  assert.equal(wet.cells[center].terrain, 'land'); assert.equal(wet.cells[center].kind, 'farm');
  assert.equal(wet.effects.length, 0);
  assert.equal(wet.cells[center].stock, 0, 'rain cannot fabricate a worker harvest');
});

test('water flows toward low ground, infiltrates, and leaves through river outlets', () => {
  const world = fixture(3);
  world.cells.forEach(cell => { cell.moisture = 100; cell.elevation = 4; });
  const high = world.cells[4], low = world.cells[5]; high.waterDepth = 2; low.elevation = 0;
  const before = world.cells.reduce((sum, cell) => sum + cell.waterDepth, 0);
  advanceDisasters(world, .25);
  assert.ok(low.waterDepth > 0);
  assert.ok(world.cells.reduce((sum, cell) => sum + cell.waterDepth, 0) <= before);
  const river = fixture(3), land = fixture(3);
  for (const sample of [river, land]) sample.cells.forEach(cell => { cell.waterDepth = 2; cell.moisture = 100; cell.elevation = 0; });
  river.cells.forEach(cell => { cell.terrain = 'water'; cell.kind = 'water'; });
  for (let index = 0; index < 80; index++) { advanceDisasters(river, .25); advanceDisasters(land, .25); }
  assert.ok(river.cells[4].waterDepth < land.cells[4].waterDepth - .5);
});

test('natural policy off excludes hazards; gentle fronts migrate and never issue destructive commands', () => {
  const off = fixture(), offKinds = new Set<string>();
  for (let index = 0; index < 2000; index++) { step(off); offKinds.add(off.weather.kind); assert.equal(off.pending.length, 0); }
  assert.ok(offKinds.size > 1); assert.ok(!offKinds.has('storm'));
  const gentle = fixture(); gentle.naturalPolicy = 'gentle'; gentle.residents.push(resident(gentle, 3, 3));
  const kinds = new Set<string>();
  step(gentle); const startX = gentle.weather.frontX, startY = gentle.weather.frontY;
  step(gentle, 10);
  assert.ok(gentle.weather.frontX !== startX || gentle.weather.frontY !== startY);
  for (let index = 0; index < 2000; index++) { step(gentle); kinds.add(gentle.weather.kind); assert.equal(gentle.pending.length, 0); }
  assert.ok(kinds.size > 1); assert.ok(!kinds.has('storm')); assert.ok(gentle.residents[0].health > 95);
});

test('earthquake damages bridge closure and topology; quake never fabricates a replacement bridge', () => {
  const world = fixture(), bridge = world.cells[24]; bridge.terrain = 'water'; bridge.kind = 'road'; bridge.condition = 100;
  assert.equal(isPassable(bridge), true);
  queuePower(world, input('earthquake', { radius: 0, intensity: 3 })); step(world);
  assert.equal(bridge.kind, 'road'); assert.equal(bridge.terrain, 'water'); assert.equal(bridge.closed, true);
  assert.equal(isPassable(bridge), false); assert.ok(world.topologyVersion > 0); assert.ok(bridge.rubble > 0);
});

test('fire spreads on dry fueled land and rain/water extinguish it without clearing damage', () => {
  const dry = fixture(), wet = fixture();
  for (const world of [dry, wet]) { world.cells.forEach(cell => { cell.moisture = 10; cell.vegetation = 100; }); world.cells[24].fire = 100; world.cells[24].kind = 'house'; }
  queuePower(wet, input('rain', { intensity: 4, duration: 20 }));
  step(dry, 80); step(wet, 80);
  assert.equal(wet.cells[24].fire, 0); assert.ok(wet.cells[24].condition < 100);
  assert.ok(dry.cells.some((cell, index) => index !== 24 && cell.fire > 0), 'dry fire can spread to nearby fuel');
  assert.ok(dry.cells[24].condition < wet.cells[24].condition);
});

test('sun clears rain locally but leaves surrounding rain, water and broken infrastructure to recover', () => {
  const world = fixture(); queuePower(world, input('rain', { radius: 7, intensity: 4, duration: 120 })); step(world, 10);
  const oldDepth = world.cells[24].waterDepth;
  world.cells[24].kind = 'road'; world.cells[24].condition = 10; world.cells[24].closed = true;
  const outsideDepth = world.cells[0].waterDepth;
  queuePower(world, input('sun', { radius: 1 })); step(world);
  assert.ok(world.effects.some(effect => effect.kind === 'rain'));
  assert.ok(world.cells[0].waterDepth > outsideDepth, 'rain continues outside the sun circle');
  assert.ok(world.cells[24].waterDepth > 0); assert.ok(world.cells[24].waterDepth < oldDepth);
  assert.equal(isPassable(world.cells[24]), false);
});

test('meteor ending scale only destroys its explicit circle and mapwide radius sets all residents health to zero', () => {
  const local = fixture(), entire = fixture();
  for (const world of [local, entire]) {
    world.cells.forEach(cell => { cell.kind = 'house'; cell.level = 2; cell.population = 1; });
    world.residents.push(resident(world, 0, 0), resident(world, 3, 3), resident(world, 6, 6));
  }
  queuePower(local, input('meteor', { radius: 0, intensity: 4 })); step(local);
  assert.equal(local.residents[1].health, 0); assert.equal(local.residents[0].health, 100);
  queuePower(entire, input('meteor', { radius: Math.ceil(Math.hypot(entire.size, entire.size)), intensity: 4 })); step(entire);
  assert.ok(entire.residents.every(person => person.health === 0));
  assert.equal(entire.residents.length, 3, 'life engine alone accounts for casualties');
  assert.ok(entire.cells.every(cell => cell.kind === 'ruin' && cell.crater > 0));
  assert.equal(entire.economy.deaths, 0, 'casualty count is not duplicated here');
  const fires = entire.cells.reduce((sum, cell) => sum + cell.fire, 0); step(entire, 40);
  assert.ok(entire.cells.reduce((sum, cell) => sum + cell.fire, 0) < fires, 'nature keeps advancing after ending');
});

test('settle delegates population creation; growth never invents people or buildings', () => {
  const world = fixture(); queuePower(world, input('settle')); world.step++;
  assert.equal(applyPendingPowers(world)[0].kind, 'settle'); assert.equal(world.residents.length, 0);
  queuePower(world, input('growth', { duration: 30 })); step(world, 120);
  assert.ok(world.cells[24].vegetation > 75); assert.equal(world.cells[24].kind, 'tree'); assert.equal(world.residents.length, 0);
});

test('active effects, weather, hazard RNG and queue resume to an identical future across serialization', () => {
  const world = fixture(); world.naturalPolicy = 'wild';
  queuePower(world, input('storm', { intensity: 2, duration: 30 })); queuePower(world, input('lightning', { radius: 1 })); step(world, 11);
  queuePower(world, input('rain'));
  const restored: World = JSON.parse(JSON.stringify(world));
  step(world, 80); step(restored, 80);
  assert.deepEqual(restored, world);
  assert.ok(world.effects.every(effect => effect.elapsed > 0 && effect.remaining > 0));
  assert.equal(world.rng, 21, 'hazards do not alter life/appearance RNG');
});


test('switching a wild storm to no natural disasters stops future natural lightning', () => {
  const world = fixture();
  world.weather.kind = 'storm'; world.weather.rainfall = .16; world.weather.remaining = 100;
  world.weather.windX = 1.8; world.naturalPolicy = 'off';
  for (let n = 0; n < 400; n++) step(world);
  assert.ok(!world.pending.some(command => command.source === 'nature'));
  assert.notEqual(world.weather.kind, 'storm');
  queuePower(world, input('storm'));
  step(world);
  assert.ok(world.effects.some(effect => effect.kind === 'storm'), 'god commands remain usable with natural disasters disabled');
});
