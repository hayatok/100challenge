import assert from 'node:assert/strict';
import test from 'node:test';
import { Game } from '../src/game.ts';
import { BOSS_COUNTER_PHRASES, RUSH_PHRASES } from '../src/content.ts';

function finishVisible(game: Game): void {
  const id = game.state.enemies[0]?.id;
  assert.ok(id);
  while (game.state.enemies.some(enemy => enemy.id === id)) {
    const target = game.state.enemies.find(enemy => enemy.id === id)!;
    assert.equal(game.type(target.guide[0]),true);
  }
}

function advanceTravel(game: Game): void {
  if (game.state.mode === 'travel') game.update(3);
}

function advancePreciseTravel(game: Game): void {
  let guard = 0;
  while (game.state.mode === 'travel' && guard++ < 100) game.update(0.05);
  assert.ok(guard < 100);
}

test('rush waits for a cleared wave, has four sequential words, and stops at two per run', () => {
  const game = new Game({seed:42,practice:true});
  let rushStarts = 0;
  let rushEnds = 0;
  let rushKills = 0;
  let guard = 0;
  while (game.state.stage < 3 && guard++ < 10000) {
    advanceTravel(game);
    const before = game.state;
    if (before.stage >= 3) break;
    if (before.rushing) {
      assert.equal(before.enemies.length,1);
      assert.equal(before.enemies[0].rush,true);
      assert.ok(RUSH_PHRASES.some(item => item.text === before.enemies[0].phrase));
      rushKills++;
    }
    finishVisible(game);
    for (const event of game.drainEvents()) {
      if (event.type === 'rushStart') rushStarts++;
      if (event.type === 'rushEnd') { rushEnds++; assert.equal(event.success,true); }
    }
  }
  assert.equal(rushStarts,2);
  assert.equal(rushEnds,2);
  assert.equal(rushKills,8);
  assert.equal(game.state.rushing,false);
  assert.equal(game.state.rushes,2);
  assert.equal(game.state.rushCharge,0);
  assert.equal(game.state.results,null);
});

test('rush charge survives mistakes, starts only after wave completion, and freezes through pause and travel', () => {
  const game = new Game({seed:4,practice:true});
  let guard = 0;
  while (game.state.rushCharge < 75 && guard++ < 10000) {
    advanceTravel(game);
    finishVisible(game);
  }
  assert.equal(game.state.rushCharge,75);
  advanceTravel(game);
  const id = game.state.enemies[0].id;
  assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.equal(game.type('q'),false);
  assert.equal(game.state.rushCharge,75);
  while (game.state.enemies.some(enemy => enemy.id === id)) {
    const enemy = game.state.enemies.find(item => item.id === id)!;
    game.type(enemy.guide[0]);
  }
  assert.equal(game.state.rushCharge,93);
  assert.equal(game.state.rushing,false);
  game.pause();
  game.update(100);
  assert.equal(game.state.rushCharge,93);
  game.resume();
  game.update(0.8);
  while (!game.state.rushing) {
    advanceTravel(game);
    finishVisible(game);
  }
  assert.equal(game.state.mode,'travel');
  assert.equal(game.state.rushCharge,0);
  game.pause();
  game.update(100);
  assert.equal(game.state.mode,'paused');
  game.resume();
  game.update(0.8);
  assert.equal(game.state.mode,'travel');
  advanceTravel(game);
  assert.equal(game.state.enemies[0].rush,true);
});

test('an explosive worker previews adjacent targets and collateral gives fixed points without combo or charge', () => {
  const game = new Game({seed:9,practice:true});
  let guard = 0;
  while (!game.state.enemies.some(enemy => enemy.explosive) && guard++ < 10000) {
    advanceTravel(game);
    if (game.state.enemies.some(enemy => enemy.explosive)) break;
    finishVisible(game);
  }
  assert.ok(guard < 10000);
  const carrier = game.state.enemies.find(enemy => enemy.explosive)!;
  assert.equal(carrier.kind,'worker');
  assert.ok(carrier.blastTargets.length >= 1);
  const targets = [...carrier.blastTargets];
  const before = game.state;
  while (game.state.enemies.some(enemy => enemy.id === carrier.id)) {
    const active = game.state.enemies.find(enemy => enemy.id === carrier.id)!;
    assert.equal(game.type(active.guide[0]),true);
  }
  const events = game.drainEvents();
  const collateral = events.filter(event => event.type === 'kill' && event.collateral);
  assert.deepEqual(collateral.map(event => event.enemyId),targets);
  assert.ok(collateral.every(event => event.scoreDelta === 75 && event.clean === false));
  assert.equal(events.find(event => event.type === 'explosion')?.count,targets.length);
  assert.equal(game.state.score-before.score,150+Math.min(before.combo+1,15)*10+targets.length*75);
  assert.equal(game.state.combo,before.combo+1);
  assert.equal(game.state.rushCharge,before.rushes < 2 ? Math.min(100,before.rushCharge+25) : before.rushCharge);
});

test('boss counter phase completes three short phrases before advancing and preserves time through pause', () => {
  const game = new Game({seed:6,practice:true});
  let guard = 0;
  while (game.state.stage < 3 && guard++ < 10000) {
    advanceTravel(game);
    finishVisible(game);
  }
  advanceTravel(game);
  assert.equal(game.state.bossPhase,0);
  finishVisible(game);
  advanceTravel(game);
  game.drainEvents();
  const counts: number[] = [];
  for (let i=1;i<=3;i++) {
    assert.equal(game.state.bossPhase,1);
    assert.equal(game.state.bossCounter,i);
    assert.ok(BOSS_COUNTER_PHRASES.some(item => item.text === game.state.enemies[0].phrase));
    const remaining = game.state.enemies[0].remaining;
    game.pause(); game.update(100); game.resume(); game.update(0.8);
    assert.equal(game.state.enemies[0].remaining,remaining);
    finishVisible(game);
    counts.push(...game.drainEvents().filter(event => event.type === 'bossPhase' && event.phase === 1).map(event => event.count!));
    advanceTravel(game);
  }
  assert.deepEqual(counts,[1,2]);
  assert.equal(game.state.bossPhase,2);
  assert.equal(game.state.bossCounter,0);
  finishVisible(game);
  assert.equal(game.state.mode,'clear');
  assert.equal(game.state.results?.seed,6);
  assert.equal(game.state.results?.rushes,2);
});

test('seeded replay reproduces events and checkpoint restores charge and rush counters', () => {
  const script = (seed:number) => {
    const game = new Game({seed});
    const record:string[] = [];
    let guard = 0;
    while (game.state.stage < 2 && guard++ < 10000) {
      advanceTravel(game);
      if (game.state.stage >= 2) break;
      record.push(game.state.enemies.map(enemy => `${enemy.phrase}:${enemy.lane}:${enemy.explosive}`).join('|'));
      finishVisible(game);
    }
    assert.ok(guard < 10000);
    return {game,record};
  };
  assert.deepEqual(script(13).record,script(13).record);
  const {game} = script(13);
  const checkpoint = {...game.state};
  advanceTravel(game);
  while (game.state.mode !== 'defeat') {
    if (game.state.mode === 'travel') { advanceTravel(game); continue; }
    game.update(Math.max(...game.state.enemies.map(enemy => enemy.remaining))+0.001);
  }
  game.retryCheckpoint();
  assert.equal(game.state.stage,2);
  assert.equal(game.state.rushCharge,checkpoint.rushCharge);
  assert.equal(game.state.score,checkpoint.score);
  let guard = 0;
  const mode = () => game.state.mode;
  while (mode() !== 'clear' && guard++ < 10000) {
    advanceTravel(game);
    if (mode() === 'clear') break;
    finishVisible(game);
  }
  assert.ok(guard < 10000);
  const result = (() => game.state.results)();
  assert.ok(result);
  assert.equal(result.rushes,2);
  assert.equal(result.seed,13);
});

test('a rush final key wins exactly at its deadline and a later key cannot undo an attack', () => {
  const game = new Game({seed:2});
  let guard = 0;
  while (!game.state.rushing && guard++ < 10000) {
    advanceTravel(game);
    finishVisible(game);
  }
  game.update(0.35);
  const first = game.state.enemies[0].id;
  while (game.state.enemies[0].guide.length > 1) game.type(game.state.enemies[0].guide[0]);
  game.update(game.state.enemies[0].remaining);
  assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.ok(!game.state.enemies.some(enemy => enemy.id === first));
  game.update(0.18);
  const second = game.state.enemies[0];
  game.update(second.remaining+0.001);
  assert.equal(game.state.health,2);
  assert.equal(game.type(second.guide[0]),false);
  assert.ok(!game.state.enemies.some(enemy => enemy.id === second.id));
});

test('replay seeds must be unsigned 32-bit integers', () => {
  for (const seed of [-1,0.5,Number.NaN,0x1_0000_0000])
    assert.throws(() => new Game({seed}),/Invalid seed/);
});

test('a timed-out rush encounter ends the sequence without a success event', () => {
  const game = new Game({seed:3});
  let guard = 0;
  while (!game.state.rushing && guard++ < 10000) {
    advancePreciseTravel(game);
    finishVisible(game);
  }
  assert.ok(guard < 10000);
  advancePreciseTravel(game);
  game.drainEvents();
  const first = game.state.enemies[0];
  game.update(first.remaining+0.001);
  assert.equal(game.state.health,2);
  assert.equal(game.state.rushRemaining,3);
  while (game.state.rushing && guard++ < 10000) {
    advancePreciseTravel(game);
    finishVisible(game);
  }
  const end = game.drainEvents().find(event => event.type === 'rushEnd');
  assert.equal(end?.count,1);
  assert.equal(end?.success,false);
  assert.equal(game.state.rushes,1);
});

test('explosive waves use separate lanes and preview every neighbour', () => {
  const game = new Game({seed:11,practice:true});
  let carriers = 0;
  let triple = false;
  let guard = 0;
  while (game.state.stage < 3 && guard++ < 10000) {
    advanceTravel(game);
    if (game.state.stage >= 3) break;
    const state = game.state;
    const carrier = state.enemies.find(enemy => enemy.explosive);
    if (carrier) {
      carriers++;
      assert.equal(carrier.lane,0);
      assert.equal(new Set(state.enemies.map(enemy => enemy.lane)).size,state.enemies.length);
      assert.deepEqual(new Set(carrier.blastTargets),new Set(state.enemies.filter(enemy => enemy.id !== carrier.id).map(enemy => enemy.id)));
      if (state.enemies.length === 3) triple = true;
    }
    finishVisible(game);
  }
  assert.equal(carriers,3);
  assert.equal(triple,true);
});

test('boss counter retries the identical word after a failed deadline', () => {
  const game = new Game({seed:18});
  let guard = 0;
  while (game.state.stage < 3 && guard++ < 10000) {
    advancePreciseTravel(game);
    if (game.state.stage >= 3) break;
    finishVisible(game);
  }
  advancePreciseTravel(game);
  finishVisible(game); // phase 0
  advancePreciseTravel(game);
  assert.equal(game.state.bossPhase,1);
  assert.equal(game.state.bossCounter,1);
  const first = game.state.enemies[0].phrase;
  game.update(game.state.enemies[0].remaining+0.001);
  assert.equal(game.state.health,2);
  advancePreciseTravel(game);
  assert.equal(game.state.enemies[0].phrase,first);
  assert.equal(game.state.bossCounter,1);
  finishVisible(game);
  advancePreciseTravel(game);
  assert.equal(game.state.bossCounter,2);
  assert.notEqual(game.state.enemies[0].phrase,first);
});
