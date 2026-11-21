import assert from 'node:assert/strict';
import { test } from 'node:test';
import { FIRST_BOARD_SEED, LANES, PinboardRun, STEP } from '../src/game.ts';
import type { Impact, Upgrade } from '../src/game.ts';

function dropFrom(run: PinboardRun, lane: number) {
  assert.ok(run.drop(lane - 1));
  assert.equal(run.drop(lane - 1), false, 'only one player shot may be active');
  const impacts: Impact[] = [];
  for (let tick = 0; tick < 2400 && run.phase === 'dropping'; tick++) {
    impacts.push(...run.step(STEP));
  }
  assert.notEqual(run.phase, 'dropping', 'the original and any extra balls settle');
  return impacts;
}

function reachUpgrade() {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  for (const lane of [3, 6, 4]) dropFrom(run, lane);
  assert.equal(run.phase, 'upgrade');
  return run;
}

test('a chain scores once per pin and all extra balls belong to the same shot', () => {
  const run = new PinboardRun(FIRST_BOARD_SEED);
  const impacts = dropFrom(run, 5);
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
  for (const lane of [1, 1, 1]) dropFrom(run, lane);
  assert.equal(run.phase, 'failed');
  assert.equal(run.remaining, 0);
  assert.equal(run.chooseUpgrade('split'), false);
  assert.equal(run.drop(0), false);
  assert.deepEqual(new PinboardRun(FIRST_BOARD_SEED).pins, opening);
  assert.notDeepEqual(new PinboardRun(FIRST_BOARD_SEED + 1).pins, opening);
});

test('the two upgrades clear the same second board with different opening shots', () => {
  const routes: Record<Upgrade, readonly number[]> = { split: [6, 2, 3], bonus: [2, 4, 6] };
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
    for (const lane of routes[upgrade]) dropFrom(run, lane);
    assert.equal(run.phase, 'clear');
    assert.equal(run.remaining, 0);
  }
});

test('the two upgrades favor different opening lanes on the same board', () => {
  function openingScore(upgrade: Upgrade, lane: number) {
    const run = reachUpgrade();
    assert.ok(run.chooseUpgrade(upgrade));
    dropFrom(run, lane);
    return run.stageScore;
  }
  for (const [upgrade, preferredLane] of [['split', 6], ['bonus', 2]] as const) {
    const preferred = openingScore(upgrade, preferredLane);
    for (let lane = 1; lane <= LANES.length; lane++) {
      if (lane === preferredLane) continue;
      assert.ok(preferred > openingScore(upgrade, lane), `${upgrade} should favor lane ${preferredLane} over lane ${lane}`);
    }
  }
});
