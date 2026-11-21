import assert from 'node:assert/strict';
import { test } from 'node:test';
import { FIRST_BOARD_SEED, MAX_DROP_X, MIN_DROP_X, PinboardRun, STEP } from '../src/game.ts';
import type { Impact, Upgrade } from '../src/game.ts';

function dropFrom(run: PinboardRun, x: number) {
  assert.ok(run.drop(x));
  const impacts: Impact[] = [];
  for (let tick = 0; tick < 2400 && run.phase === 'dropping'; tick++) {
    impacts.push(...run.step(STEP));
  }
  assert.notEqual(run.phase, 'dropping', 'the original and any extra balls settle');
  return impacts;
}

test('three immediate drops overlap and each group of balls scores its own chain', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const x of [431, 158, 522]) assert.ok(run.drop(x));
  assert.deepEqual(run.balls.map(({ shotId, origin }) => [shotId, origin]), [[1, 'drop'], [2, 'drop'], [3, 'drop']]);
  assert.equal(run.remaining, 0);
  assert.equal(run.canDrop, false);
  assert.equal(run.drop(340), false);
  assert.equal(run.chooseUpgrade('split'), false, 'remaining ball motion must resolve before choosing an upgrade');

  const hits: Impact[] = [];
  const addedBalls = new Map<number, { shotId: number; origin: 'split' | 'bonus' }>();
  for (let tick = 0; tick < 2400 && run.phase === 'dropping'; tick++) {
    hits.push(...run.step(STEP));
    for (const { id, origin, shotId } of run.balls) {
      if (origin !== 'drop') addedBalls.set(id, { origin, shotId });
    }
  }
  assert.equal(run.phase, 'upgrade');
  assert.equal(run.balls.length, 0);
  for (const shotId of [1, 2, 3]) {
    const shotHits = hits.filter((hit) => hit.shotId === shotId);
    assert.ok(shotHits.length > 0);
    assert.deepEqual(shotHits.map(({ points }) => points), shotHits.map((_, index) => index + 1));
    for (const origin of ['split', 'bonus']) {
      const expected = shotHits.filter(({ pin }) => pin.kind === origin).reduce((sum, hit) => sum + hit.addedBalls, 0);
      assert.equal([...addedBalls.values()].filter((ball) => ball.shotId === shotId && ball.origin === origin).length, expected);
    }
  }
  assert.ok([...addedBalls.values()].some((ball) => ball.origin === 'split'));
  assert.ok([...addedBalls.values()].some((ball) => ball.origin === 'bonus'));
  assert.equal(new Set(hits.map(({ pin }) => pin.id)).size, hits.length);
  assert.equal(run.stageScore, hits.reduce((sum, hit) => sum + hit.points, 0));
  assert.equal(run.chain, Math.max(...hits.map(({ chain }) => chain)));
  assert.ok(run.chooseUpgrade('split'));
  assert.equal(run.remaining, 3);
  assert.equal(run.chain, 0);
  assert.equal(run.canDrop, true);
});

function reachUpgrade() {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const x of [249, 522, 340]) dropFrom(run, x);
  assert.equal(run.phase, 'upgrade');
  return run;
}

test('a chain scores once per pin and all extra balls belong to the same shot', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  const impacts = dropFrom(run, 431);
  assert.ok(impacts.some(({ pin }) => pin.kind === 'split'));
  assert.ok(impacts.some(({ pin }) => pin.kind === 'bonus'));
  assert.ok(impacts.length > 2);
  assert.deepEqual(impacts.map(({ points }) => points), impacts.map((_, index) => index + 1));
  assert.equal(new Set(impacts.map(({ pin }) => pin.id)).size, impacts.length);
  assert.equal(run.stageScore, impacts.reduce((sum, hit) => sum + hit.points, 0));
  assert.equal(run.remaining, 2);
});

test('failure uses all three shots and retrying the seed reproduces the board', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  const opening = structuredClone(run.pins);
  for (const x of [67, 67, 67]) dropFrom(run, x);
  assert.equal(run.phase, 'failed');
  assert.equal(run.remaining, 0);
  assert.equal(run.chooseUpgrade('split'), false);
  assert.equal(run.drop(0), false);
  assert.deepEqual(new PinboardRun(FIRST_BOARD_SEED).pins, opening);
  assert.notDeepEqual(new PinboardRun(FIRST_BOARD_SEED + 1).pins, opening);
});

test('the two upgrades clear the same second board with different opening shots', () => {
  const routes: Record<Upgrade, readonly number[]> = { split: [522, 158, 249], bonus: [158, 340, 522] };
  const board = reachUpgrade();
  assert.ok(board.chooseUpgrade('split'));
  for (const upgrade of ['split', 'bonus'] as const) {
    const run = reachUpgrade();
    assert.equal(run.drop(0), false);
    assert.ok(run.chooseUpgrade(upgrade));
    assert.equal(run.chooseUpgrade(upgrade === 'split' ? 'bonus' : 'split'), false);
    assert.equal(run.stage, 2);
    assert.equal(run.remaining, 3);
    assert.equal(run.stageScore, 0);
    assert.deepEqual(run.pins, board.pins);
    for (const x of routes[upgrade]) dropFrom(run, x);
    assert.equal(run.phase, 'clear');
    assert.equal(run.remaining, 0);
  }
});

test('the same two targets rank differently after the upgrade', () => {
  function openingScore(upgrade: Upgrade, x: number) {
    const run = reachUpgrade();
    assert.ok(run.chooseUpgrade(upgrade));
    dropFrom(run, x);
    return run.stageScore;
  }
  assert.ok(openingScore('split', 522) > openingScore('split', 158));
  assert.ok(openingScore('bonus', 158) > openingScore('bonus', 522));
});

test('the launch uses the chosen rail position without snapping and clamps to the walls', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  assert.equal(run.drop(NaN), false);
  assert.equal(run.remaining, 3);
  assert.ok(run.drop(287));
  assert.equal(run.balls[0].x, 287);
  for (const [input, expected] of [[-20, MIN_DROP_X], [860, MAX_DROP_X]]) {
    const edge = new PinboardRun(FIRST_BOARD_SEED);
    assert.ok(edge.drop(input));
    assert.equal(edge.balls[0].x, expected);
  }
});
