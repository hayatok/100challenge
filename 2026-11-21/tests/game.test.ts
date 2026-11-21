import assert from 'node:assert/strict';
import { test } from 'node:test';
import { FIRST_BOARD_SEED, MAX_DROP_X, MIN_DROP_X, PinboardRun, REFILL_CHAIN, STEP } from '../src/game.ts';
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

function spendUnusedBallStock(run: PinboardRun) {
  const unused = run.remaining;
  for (let i = 0; i < unused && run.canDrop; i++) dropFrom(run, MIN_DROP_X);
}

test('three immediate drops overlap and each group of balls scores its own chain', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const x of [520, 250, 340]) assert.ok(run.drop(x));
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
  assert.equal(run.phase, 'ready');
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
  assert.equal(run.remaining, hits.filter(({ earnedBall }) => earnedBall).length);
  spendUnusedBallStock(run);
  assert.equal(run.phase, 'upgrade');
  assert.ok(run.chooseUpgrade('split'));
  assert.equal(run.remaining, 3);
  assert.equal(run.chain, 0);
  assert.equal(run.canDrop, true);
});

test('a chain unlocks the fourth drop before the first three balls finish', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const x of [520, 250, 340]) assert.ok(run.drop(x));
  assert.equal(run.remaining, 0);
  assert.equal(run.drop(431), false);
  let refill: Impact | undefined;
  for (let tick = 0; tick < 1200 && !refill; tick++) {
    refill = run.step(STEP).find(({ earnedBall }) => earnedBall);
  }
  assert.ok(refill);
  assert.equal(refill.chain, REFILL_CHAIN);
  assert.equal(run.remaining, 1);
  assert.equal(run.phase, 'dropping');
  assert.ok(run.balls.some(({ shotId }) => shotId < 4));
  assert.ok(run.drop(431));
  assert.equal(run.remaining, 0);
  assert.ok(run.balls.some(({ shotId }) => shotId === 4));
});

test('an empty board resolves even if two unused balls remain', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  run.pins = [{ id: 0, x: 431, y: 100, kind: 'normal', alive: true }];
  dropFrom(run, 431);
  assert.equal(run.remaining, 2);
  assert.equal(run.canDrop, false);
  assert.equal(run.phase, 'failed');
});

function reachUpgrade() {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const x of [520, 250, 340]) dropFrom(run, x);
  spendUnusedBallStock(run);
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
  const refillHits = impacts.filter(({ earnedBall }) => earnedBall).map(({ chain }) => chain);
  assert.deepEqual(refillHits, Array.from({ length: Math.floor(impacts.length / REFILL_CHAIN) }, (_, i) => (i + 1) * REFILL_CHAIN));
  assert.equal(run.remaining, 2 + refillHits.length);
});

test('failure uses all three shots and retrying the seed reproduces the board', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  const opening = structuredClone(run.pins);
  for (const x of [MIN_DROP_X, MIN_DROP_X, MIN_DROP_X]) dropFrom(run, x);
  assert.equal(run.phase, 'failed');
  assert.equal(run.remaining, 0);
  assert.equal(run.chooseUpgrade('split'), false);
  assert.equal(run.drop(0), false);
  assert.deepEqual(new PinboardRun(FIRST_BOARD_SEED).pins, opening);
  assert.notDeepEqual(new PinboardRun(FIRST_BOARD_SEED + 1).pins, opening);
});

test('the two upgrades clear the same second board with different opening shots', () => {
  const routes: Record<Upgrade, readonly number[]> = { split: [80, 380, 520], bonus: [340, 520, 570] };
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
    spendUnusedBallStock(run);
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
  assert.ok(openingScore('split', 440) > openingScore('split', 520));
  assert.ok(openingScore('bonus', 520) > openingScore('bonus', 440));
});

test('the second board asks for a new approach after its opening kick', () => {
  for (const upgrade of ['split', 'bonus'] as const) {
    const run = reachUpgrade();
    assert.ok(run.chooseUpgrade(upgrade));
    let kicked = false;
    assert.ok(run.drop(run.openingAim));
    for (let tick = 0; tick < 2400 && run.phase === 'dropping'; tick++) {
      run.step(STEP, (kicker) => { kicked ||= kicker === run.kickers[1]; });
    }
    assert.ok(kicked);
    assert.ok(run.stageScore < run.goal);
    dropFrom(run, upgrade === 'split' ? 440 : 520);
    assert.ok(run.stageScore >= run.goal);

    const repeat = reachUpgrade();
    assert.ok(repeat.chooseUpgrade(upgrade));
    for (let i = 0; i < 3; i++) dropFrom(repeat, repeat.openingAim);
    assert.equal(repeat.phase, 'failed');
  }
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


test('a copper kicker sweeps descending contact into a real directional route without scoring', () => {
  for (const direction of [-1, 1] as const) {
    const run = new PinboardRun(FIRST_BOARD_SEED);
    run.pins = [{ id: 0, x: 340 + direction * 200, y: 190, kind: 'normal', alive: true }];
    run.kickers = [{ x: 340, y: 145, width: 110, direction }];
    run.drop(340);
    let kicks = 0;
    let hit = false;
    for (let tick = 0; tick < 800 && run.phase === 'dropping'; tick++) {
      const impacts = run.step(STEP, (kicker, x) => {
        kicks++;
        assert.equal(x, 340);
        assert.equal(run.balls[0].shotId, 1);
        assert.equal(run.balls[0].origin, 'drop');
        assert.equal(Math.sign(run.balls[0].vx), kicker.direction);
        assert.equal(run.stageScore, 0);
        assert.equal(run.remaining, 2);
      });
      hit ||= impacts.length > 0;
    }
    assert.equal(kicks, 1, 'the ball leaves the plate rather than repeatedly triggering it');
    assert.ok(hit, 'the kicked ball reaches a pin 200 units to its launch side');
    // The launch changes the ball's spatial route, without creating a ball or score event.
    assert.equal(run.shotsUsed, 1);
    assert.equal(run.remaining, 2);
  }
});

test('kickers share seeded board mirroring and ignore rising or out-of-width balls', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  assert.deepEqual(run.kickers, new PinboardRun(FIRST_BOARD_SEED).kickers);
  assert.deepEqual(run.kickers, [{ x: 520, y: 145, width: 110, direction: -1 }]);
  for (const [x, y, vy] of [[340, 140, -100], [410, 120, 400]]) {
    run.phase = 'dropping';
    run.kickers = [{ x: 340, y: 145, width: 110, direction: 1 }];
    run.balls = [{ id: 0, x, y, vx: 0, vy, age: 0, origin: 'drop', shotId: 1 }];
    let kicks = 0;
    run.step(0.05, () => kicks++);
    assert.equal(kicks, 0);
  }
});
