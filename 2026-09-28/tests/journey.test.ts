import assert from 'node:assert/strict';
import test from 'node:test';
import { Game, type EnemyView } from '../src/game.ts';
import { TypingSession } from '../src/typing.ts';

function finishLeader(game: Game): void {
  const id = game.state.enemies.find(enemy => !enemy.support)?.id;
  assert.ok(id);
  while (game.state.enemies.some(enemy => enemy.id === id)) {
    const target: EnemyView = game.state.enemies.find(enemy => enemy.id === id)!;
    assert.equal(game.type(target.guide[0]),true);
  }
}

function reachStage(game: Game, stage: number): void {
  let guard = 0;
  while (game.state.stage < stage && guard++ < 1000) {
    if (game.state.mode === 'travel') game.update(5);
    else finishLeader(game);
  }
  assert.ok(guard < 1000);
}

test('each authored route reaches four grouped rushes, the boss, and a deliberate vista', () => {
  for (const route of ['store','service'] as const) {
    const game = new Game({journey:true,practice:true,seed:12});
    assert.equal(game.state.mode,'explore');
    assert.equal(game.state.enemies.length,0);
    assert.equal(game.state.journey?.route,null);
    assert.equal(game.continueVista(),false);
    assert.equal(game.chooseRoute(route),true);
    assert.equal(game.chooseRoute(route),false);
    assert.equal(game.state.journey?.travelProgress,0);
    game.update(1);
    assert.equal(game.state.journey?.travelProgress,0.5);
    game.update(1);
    assert.equal(game.state.stage,0);
    assert.equal(game.state.mode,'playing');
    assert.equal(game.state.enemies.length,1);
    assert.equal(game.state.journey?.area,'alley');
    finishLeader(game);
    assert.equal(game.state.mode,'travel');
    game.update(0.6);
    finishLeader(game);
    assert.equal(game.state.stage,1);
    assert.equal(game.state.journey?.area,route);
    assert.equal(game.state.mode,'travel');
    game.update(3.79);
    assert.equal(game.state.mode,'travel');
    game.update(0.01);
    assert.equal(game.state.enemies[0].kind,route === 'store' ? 'worker' : 'runner');
    reachStage(game,2);
    assert.equal(game.state.mode,'travel');
    assert.equal(game.state.journey?.area,'court');
    game.update(4);
    assert.equal(game.state.rushing,true);
    assert.equal(game.state.enemies.length,3);
    game.drainEvents();
    let sweeps = 0;
    while (game.state.rushing) {
      if (game.state.mode === 'travel') game.update(1);
      else {
        finishLeader(game);
        const fired=game.drainEvents();
        assert.ok(fired.filter(event=>event.type==='hit').every(event=>event.rush===true));
        sweeps += fired.filter(event => event.type === 'sweep').length;
      }
    }
    assert.equal(sweeps,4);
    assert.equal(game.state.chainKills,8);
    reachStage(game,3);
    assert.equal(game.state.mode,'travel');
    game.update(2);
    let guard = 0;
    while (game.state.mode !== 'vista' && guard++ < 1000) {
      if (game.state.mode === 'travel') game.update(2);
      else finishLeader(game);
    }
    assert.ok(guard < 1000);
    assert.equal(game.state.journey?.area,'roof');
    assert.deepEqual(game.state.enemies,[]);
    assert.equal(game.state.results,null);
    assert.equal(game.drainEvents().filter(event => event.type === 'vista').length,1);
    game.pause();
    game.update(50);
    game.resume();
    game.update(0.8);
    assert.equal(game.state.mode,'vista');
    game.update(50);
    assert.equal(game.continueVista(),true);
    assert.equal(game.state.mode,'clear');
    const ended = (() => game.state)();
    assert.ok(ended.results);
    assert.ok(ended.results.clearTime < 50);
    assert.equal(game.continueVista(),false);
    const restart = game.restart();
    assert.equal(restart.state.mode,'explore');
    assert.equal(restart.state.journey?.route,null);
  }
});

test('supports share the leader deadline, cannot lock, and add two collateral rewards to one word', () => {
  const game = new Game({journey:true,practice:true,seed:3});
  game.chooseRoute('store');
  reachStage(game,2);
  game.update(4);
  const group = game.state.enemies;
  const leader = group.find(enemy => !enemy.support)!;
  const supports = group.filter(enemy => enemy.support);
  assert.equal(supports.length,2);
  assert.equal(leader.lane,0);
  assert.deepEqual(supports.map(enemy => enemy.lane),[-1,1]);
  assert.ok(supports.every(enemy => enemy.keys.length === 0 && enemy.guide === '' && enemy.remaining === leader.remaining));
  assert.equal(game.state.lockedId,null);
  const beforeScore = game.state.score;
  game.drainEvents();
  assert.equal(game.type(leader.guide[0]),true);
  assert.equal(game.state.lockedId,leader.id);
  assert.ok(supports.every(enemy => game.state.lockedId !== enemy.id));
  finishLeader(game);
  const events = game.drainEvents();
  const kills = events.filter(event => event.type === 'kill');
  assert.equal(kills.filter(event => !event.collateral).length,1);
  assert.equal(kills.filter(event => event.collateral).length,2);
  assert.equal(events.find(event => event.type === 'sweep')?.count,3);
  assert.equal(game.state.score-beforeScore,(kills[0].scoreDelta ?? 0)+150);
  assert.equal(game.state.chainKills,2);
  assert.equal(game.state.enemies.length,0);
});

test('explore, travel, and vista freeze combat time through pause and resume', () => {
  const game = new Game({journey:true,seed:8});
  game.update(100);
  assert.equal(game.state.health,3);
  game.pause();
  game.update(100);
  game.resume();
  game.update(0.8);
  assert.equal(game.state.mode,'explore');
  game.chooseRoute('service');
  game.update(0.7);
  const progress = game.state.journey?.travelProgress;
  game.pause();
  game.update(100);
  assert.equal(game.state.journey?.travelProgress,progress);
  game.resume();
  game.update(0.8);
  assert.equal(game.state.journey?.travelProgress,progress);
  game.update(1.3);
  assert.equal(game.state.mode,'playing');
  assert.equal(game.state.health,3);
});

test('failed leader removes supports with one damage; retry replays rush without duplicate rewards', () => {
  const game = new Game({journey:true,seed:2});
  game.chooseRoute('store');
  reachStage(game,2);
  const checkpointScore = game.state.score;
  game.update(4);
  finishLeader(game);
  assert.ok(game.state.score > checkpointScore);
  game.update(0.18);
  const leader = game.state.enemies.find(enemy => !enemy.support)!;
  game.update(leader.remaining+0.01);
  const attacks = game.drainEvents().filter(event => event.type === 'attack');
  assert.equal(attacks.length,3);
  assert.equal(attacks.filter(event => event.collateral).length,2);
  assert.equal(game.state.health,2);
  for (let guard=0;game.state.mode !== 'defeat' && guard<5;guard++) {
    if (game.state.mode === 'travel') game.update(1);
    else game.update(game.state.enemies.find(enemy => !enemy.support)!.remaining+0.01);
  }
  assert.equal(game.state.mode,'defeat');
  game.retryCheckpoint();
  assert.equal(game.state.stage,2);
  assert.equal(game.state.journey?.area,'court');
  assert.equal(game.state.rushing,true);
  assert.equal(game.state.rushes,1);
  assert.equal(game.state.chainKills,0);
  assert.equal(game.state.score,checkpointScore);
  assert.equal(game.state.enemies.length,3);
  finishLeader(game);
  assert.equal(game.state.chainKills,2);
});

test('short authored calls stay role-sized, seed-stable, and unambiguous on both routes', () => {
  const limits = {runner:[5,10],office:[8,16],worker:[12,22]} as const;
  for (const route of ['store','service'] as const) for (let seed=0;seed<32;seed++) {
    const game = new Game({journey:true,practice:true,seed});
    game.chooseRoute(route);
    const seen = new Set<string>();
    let guard = 0;
    while (game.state.stage < 3 && guard++ < 100) {
      const state = game.state;
      if (state.mode === 'travel') { game.update(5); continue; }
      if (!state.rushing && !state.luckyActive) {
        const initialKeys = state.enemies.flatMap(enemy => enemy.keys);
        assert.equal(initialKeys.length,new Set(initialKeys).size,`${route} seed ${seed}`);
        for (const enemy of state.enemies) {
          if (seen.has(enemy.phrase)) continue;
          const [low,high] = limits[enemy.kind as keyof typeof limits];
          const length = new TypingSession(enemy.reading).standardLength;
          assert.ok(length >= low && length <= high,`${route} ${enemy.kind} ${enemy.phrase}: ${length}`);
          seen.add(enemy.phrase);
        }
      }
      finishLeader(game);
    }
    assert.ok(guard < 100,`${route} seed ${seed}`);
    assert.equal(seen.size,8);
  }
});

test('one optional lucky encounter settles before courtyard and its bonus survives stage retry once', () => {
  for (const seed of [0,1]) {
    const game = new Game({journey:true,seed,practice:seed === 1});
    game.chooseRoute('service');
    let guard = 0;
    while (!game.state.luckyActive && game.state.stage < 2 && guard++ < 100) {
      if (game.state.mode === 'travel') game.update(5);
      else finishLeader(game);
    }
    assert.equal(game.state.luckyActive,true);
    assert.equal(game.state.stage,1);
    assert.equal(game.state.rushing,false);
    assert.equal(game.state.luckyEncounters,1);
    const before = game.state.score;
    finishLeader(game);
    assert.equal(game.state.score,before+500);
    assert.equal(game.state.stage,2);
    assert.equal(game.state.mode,'travel');
    assert.equal(game.state.luckyClears,1);
    assert.equal(game.state.luckyBonus,500);
    if (game.practice) continue;
    game.update(4);
    for (let steps=0;steps<12;steps++) {
      const state = game.state;
      if (state.mode === 'defeat') break;
      if (state.mode === 'travel') game.update(1);
      else game.update(game.state.enemies.find(enemy => !enemy.support)!.remaining+0.01);
    }
    assert.equal(game.state.mode,'defeat');
    game.retryCheckpoint();
    assert.equal(game.state.score,before+500);
    assert.equal(game.state.luckyEncounters,1);
    assert.equal(game.state.luckyClears,1);
    assert.equal(game.state.luckyBonus,500);
    assert.equal(game.state.rushing,true);
  }
});
