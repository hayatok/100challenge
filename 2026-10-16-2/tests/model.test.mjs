import test from 'node:test';
import assert from 'node:assert/strict';
import { createGame, analyze, build, remove, advance, previewBuild, serialize, validateSave } from '../app/src/model.mjs';

// A complete, reproducible route through all chapters. This proves solvability,
// not that these placements are the only solution or that players find it fun.
const witness = [
  [['home', 1, 3], ['shop', 2, 1]],
  [['road', 4, 3], ['bridge', 5, 3], ['road', 6, 3], ['road', 7, 3], ['shop', 6, 2], ['workshop', 6, 4]],
  [['clinic', 3, 2], ['park', 2, 4], ['road', 8, 3], ['clinic', 8, 2], ['park', 8, 4]],
];
const construct = (state, steps) => steps.reduce((current, [type, x, y]) => {
  const result = build(current, type, x, y);
  assert.equal(result.ok, true, `${type} (${x},${y}): ${result.message}`);
  return result.state;
}, state);
const phaseOne = () => advance(construct(createGame(), witness[0])).state;
const phaseTwo = () => advance(construct(phaseOne(), witness[1])).state;
const tile = (x, y, type) => ({ x, y, type, paid: 0, fixed: false });

test('three chapters are solvable within their budgets, with visible routes and a final gate', () => {
  let state = createGame();
  assert.equal(analyze(state).residents, 3);
  assert.deepEqual(analyze(state).served, { shop: 0, work: 3, clinic: 0, park: 0 });
  assert.equal(advance(state).state, state);
  for (let phase = 0; phase < 3; phase++) {
    state = construct(state, witness[phase]);
    const result = analyze(state);
    assert.equal(result.residents, 6 + phase * 3);
    assert.equal(result.allDone, true);
    assert.ok(result.routes.length > 0);
    assert.equal(state.budget, [5, 4, 4][phase]);
    assert.equal(validateSave(serialize(state)).ok, true);
    const next = advance(state);
    assert.equal(next.ok, true);
    assert.equal(state.completed, false, 'advance preserves the previous undo snapshot');
    state = next.state;
    assert.equal(state.phase, Math.min(phase + 1, 2));
    assert.equal(validateSave(serialize(state)).ok, true);
  }
  assert.equal(state.completed, true);
  assert.equal(advance(state).ok, false);
  assert.equal(build(state, 'road', 0, 3).state, state);
  assert.equal(remove(state, 2, 1).state, state);
});

test('preview reports the exact effect and cost without modifying state; snapshots support undo', () => {
  const state = createGame();
  const before = serialize(state);
  const preview = previewBuild(state, 'shop', 2, 1);
  assert.equal(preview.ok, true);
  assert.equal(preview.cost, 4);
  assert.equal(preview.budgetAfter, 8);
  assert.equal(preview.analysis.served.shop, 3);
  const built = build(state, 'shop', 2, 1).state;
  assert.equal(serialize(state), before);
  assert.deepEqual(analyze(built), preview.analysis);
  assert.notEqual(built.tiles, state.tiles);
  assert.notEqual(built.tiles[0], state.tiles[0]);
  const removed = remove(built, 2, 1).state;
  assert.deepEqual(removed, state);
  assert.equal(built.budget, 8);
});

test('walking counts road cells, takes the shortest path and cannot cross a building', () => {
  const state = createGame();
  const linked = build(state, 'shop', 2, 1).state;
  const route = analyze(linked).perHome[0].shop;
  assert.deepEqual(route, { distance: 1, path: [{ x: 2, y: 2 }], target: { x: 2, y: 1 } });
  const isolated = build(state, 'shop', 0, 1).state;
  assert.equal(analyze(isolated).served.shop, 0, 'diagonal proximity does not create access');
  const adjacent = { ...state, tiles: [tile(0, 2, 'home'), tile(1, 2, 'shop')] };
  assert.equal(analyze(adjacent).served.shop, 0, 'adjacent buildings still need a road');
  const branching = { ...state, tiles: [tile(0, 2, 'home'), tile(3, 2, 'shop'),
    ...[0, 1, 2, 3].flatMap(x => [tile(x, 3, 'road'), tile(x, 4, 'road')])] };
  assert.equal(analyze(branching).perHome[0].shop.distance, 4, 'a longer alternative does not replace the shortest path');
  const detour = { ...branching, tiles: branching.tiles.filter(item => !(item.x === 2 && item.y === 3)).concat(tile(2, 3, 'workshop')) };
  assert.equal(analyze(detour).served.shop, 0, 'a building blocks the short road; the remaining detour is too far');
});

test('service range has an inclusive boundary and does not use straight-line distance', () => {
  const make = (length, type) => ({ ...createGame(), tiles: [tile(0, 2, 'home'), tile(length - 1, 4, type), ...Array.from({ length }, (_, x) => tile(x, 3, 'road'))] });
  for (const [type, range] of [['shop', 4], ['clinic', 3], ['park', 2]]) {
    assert.equal(analyze(make(range, type)).served[type], 3, `${type} reaches its limit`);
    assert.equal(analyze(make(range + 1, type)).served[type], 0, `${type} does not reach beyond its limit`);
  }
});

test('job assignment reroutes earlier families to avoid a greedy capacity failure', () => {
  const state = { ...createGame(), tiles: [tile(4, 2, 'home'), tile(0, 2, 'home'), tile(0, 4, 'home'),
    tile(1, 4, 'workshop'), tile(8, 4, 'workshop'),
    ...Array.from({ length: 9 }, (_, x) => tile(x, 3, x === 5 ? 'bridge' : 'road'))] };
  const result = analyze(state);
  assert.equal(result.served.work, 9);
  assert.deepEqual(result.perHome[0].work.target, { x: 8, y: 4 });
  assert.deepEqual(result.perHome[1].work.target, { x: 1, y: 4 });
  assert.deepEqual(result.perHome[2].work.target, { x: 1, y: 4 });
  const oneWorkshop = { ...state, tiles: state.tiles.filter(item => !(item.type === 'workshop' && item.x === 8)) };
  assert.equal(analyze(oneWorkshop).served.work, 6);
});

test('invalid construction and insufficient money leave the state unchanged', () => {
  const initial = createGame();
  for (const args of [['shop', 1, 2], ['road', 0, 0], ['road', 5, 3], ['bridge', 4, 3], ['clinic', 4, 2], ['road', -1, 3], ['road', 2.5, 3], ['toString', 0, 3]]) {
    const result = build(initial, ...args);
    assert.equal(result.ok, false, args.join(' '));
    assert.equal(result.state, initial);
  }
  const withHouse = build(initial, 'home', 1, 3).state;
  assert.equal(build(withHouse, 'home', 0, 3).ok, false);
  const poor = construct(initial, [['shop', 2, 1], ['workshop', 4, 4], ['home', 1, 3]]);
  assert.equal(poor.budget, 0);
  assert.equal(build(poor, 'road', 0, 3).state, poor);
  assert.equal(remove(initial, 1, 2).state, initial);
  assert.equal(remove(initial, 3, 4).state, initial);
  assert.equal(remove(initial, 0, 3).state, initial);
});

test('refund uses the actual purchase cost after shop prices rise, and carry is capped', () => {
  const first = construct(createGame(), witness[0]);
  const next = advance(first).state;
  assert.equal(next.budget, 20);
  assert.equal(next.discarded, 2);
  const returned = remove(next, 2, 1).state;
  assert.equal(returned.budget, 24, 'old shop returns 4 rather than the new price 5');
  const rebuilt = build(returned, 'shop', 2, 1).state;
  assert.equal(rebuilt.budget, 19);
  assert.equal(rebuilt.tiles.find(item => item.type === 'shop').paid, 5);
  assert.equal(validateSave(serialize(rebuilt)).ok, true);
  assert.equal(remove(createGame(), 2, 2).state.budget, 12, 'free seed road returns zero');
});

test('a bridge must connect both towns; future home land is reserved', () => {
  const state = phaseOne();
  assert.equal(build(state, 'road', 7, 4).ok, false);
  const bridgeOnly = build(state, 'bridge', 5, 3).state;
  assert.equal(analyze(bridgeOnly).bridgeConnected, false);
  const connected = construct(state, witness[1]);
  assert.equal(analyze(connected).bridgeConnected, true);
  const cut = remove(connected, 4, 3).state;
  assert.equal(analyze(cut).bridgeConnected, false);
  assert.equal(advance(cut).ok, false);
  const next = advance(connected).state;
  assert.equal(next.tiles.find(item => item.x === 7 && item.y === 4).fixed, true);
});

test('save validation rejects malformed, inconsistent, unsupported and impossible data', () => {
  const original = phaseTwo();
  const loaded = validateSave(serialize(original));
  assert.equal(loaded.ok, true);
  assert.deepEqual(loaded.state, original);
  assert.notEqual(loaded.state.tiles, original.tiles);
  const mutate = change => { const copy = JSON.parse(serialize(original)); change(copy); return copy; };
  const invalid = ['{', null, [], {}, mutate(s => { s.version = 2; }), mutate(s => { s.phase = 3; }),
    mutate(s => { s.budget += 1; }), mutate(s => { s.tiles[0].fixed = false; }),
    mutate(s => { s.tiles.push({ ...s.tiles[0] }); }), mutate(s => { s.tiles[0].x = 0.5; }),
    mutate(s => { s.tiles[0].type = 'mall'; }), mutate(s => { s.tiles[0].paid = 10; }),
    mutate(s => { s.tiles[0].secret = true; }), mutate(s => { s.future = true; }),
    mutate(s => { s.completed = true; }), mutate(s => { s.discarded = -1; })];
  for (const raw of invalid) assert.equal(validateSave(raw).ok, false, JSON.stringify(raw));
  const noGate = { ...createGame(), completed: true };
  assert.equal(validateSave(noGate).ok, false);
  const earlyClinic = { ...createGame(), budget: 7, tiles: [...createGame().tiles, { x: 3, y: 2, type: 'clinic', paid: 5, fixed: false }] };
  assert.equal(validateSave(earlyClinic).ok, false);
});
