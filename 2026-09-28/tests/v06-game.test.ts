import assert from 'node:assert/strict';
import test from 'node:test';
import { Game } from '../src/game.ts';
import { LUCKY_PHRASES } from '../src/content.ts';

function finishNormalEnemy(game: Game): void {
  const id = game.state.enemies[0]?.id;
  assert.ok(id);
  while (game.state.enemies.some(enemy => enemy.id === id)) {
    const enemy = game.state.enemies.find(item => item.id === id)!;
    assert.equal(game.type(enemy.guide[0]),true);
  }
}

function reachLucky(game: Game): void {
  let guard = 0;
  while (!game.state.luckyActive && game.state.mode !== 'clear' && guard++ < 10000) {
    if (game.state.mode === 'travel') game.update(3);
    else finishNormalEnemy(game);
  }
  assert.ok(guard < 10000);
}

function finishLucky(game: Game): string[] {
  const id = game.state.enemies[0].id;
  const phrases: string[] = [];
  for (let step=1;step<=3;step++) {
    assert.equal(game.state.luckyStep,step);
    const enemy = game.state.enemies[0];
    assert.equal(enemy.id,id);
    phrases.push(enemy.phrase);
    while (game.state.luckyActive && game.state.luckyStep === step)
      assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  }
  return phrases;
}

test('seed fixes one safe encounter in about half of normal runs; practice always previews it', () => {
  for (let seed=0;seed<8;seed++) {
    const game = new Game({seed});
    reachLucky(game);
    assert.equal(game.state.luckyActive,seed%2 === 0,`seed ${seed}`);
    if (game.state.luckyActive) {
      assert.equal(game.state.enemies.length,1);
      assert.equal(game.state.enemies[0].lucky,true);
      assert.equal(game.state.enemies[0].kind,'office');
      assert.equal(game.state.enemies[0].rush,false);
      assert.equal(game.state.enemies[0].explosive,false);
      assert.ok(game.state.stage <= 1);
    }
  }
  const practice = new Game({seed:1,practice:true});
  reachLucky(practice);
  assert.equal(practice.state.luckyActive,true);
});

test('a pending FEVER sequence ends before the lucky actor enters', () => {
  const game = new Game({seed:4,practice:true});
  const types: string[] = [];
  let guard = 0;
  while (!game.state.luckyActive && guard++ < 10000) {
    if (game.state.mode === 'travel') game.update(3);
    else finishNormalEnemy(game);
    types.push(...game.drainEvents().map(event => event.type));
  }
  assert.ok(guard < 10000);
  assert.equal(types.filter(type => type === 'luckyStart').length,1);
  assert.equal(types.at(-2),'rushEnd');
  assert.equal(types.at(-1),'luckyStart');
  assert.equal(game.state.rushing,false);
});

test('three lucky phrases keep one actor and award fixed bonus without normal stats', () => {
  const game = new Game({seed:0});
  reachLucky(game);
  const start = game.drainEvents().filter(event => event.type === 'luckyStart');
  assert.equal(start.length,1);
  const before = game.state;
  const beforeResults = {score:before.score,combo:before.combo,charge:before.rushCharge};
  const missKey = game.state.enemies[0].keys.includes('q') ? 'z' : 'q';
  assert.equal(game.type(missKey),false);
  game.update(1);
  const phrases = finishLucky(game);
  assert.deepEqual(phrases,LUCKY_PHRASES[0].map(item => item.text));
  const events = game.drainEvents();
  assert.deepEqual(events.filter(event => event.type === 'luckyStep').map(event => event.step),[1,2]);
  assert.equal(events.filter(event => event.type === 'kill').length,0);
  assert.ok(events.some(event => event.type === 'miss' && event.lucky));
  assert.ok(events.filter(event => event.type === 'hit').every(event => event.lucky));
  const end = events.find(event => event.type === 'luckyEnd');
  assert.equal(end?.enemyId,start[0].enemyId);
  assert.equal(end?.success,true);
  assert.equal(end?.scoreDelta,500);
  assert.equal(end?.healing,0);
  assert.equal(game.state.score,beforeResults.score+500);
  assert.equal(game.state.combo,beforeResults.combo);
  assert.equal(game.state.rushCharge,beforeResults.charge);
  assert.equal(game.state.luckyEncounters,1);
  assert.equal(game.state.luckyClears,1);
  assert.equal(game.state.luckyBonus,500);
});

test('success heals one point up to three; timeout causes no damage or combo break', () => {
  const game = new Game({seed:0});
  game.update(game.state.enemies[0].remaining+0.01);
  assert.equal(game.state.health,2);
  reachLucky(game);
  const before = game.state;
  finishLucky(game);
  assert.equal(game.state.health,3);
  assert.equal(game.drainEvents().find(event => event.type === 'luckyEnd')?.healing,1);
  assert.equal(game.state.combo,before.combo);

  const missed = new Game({seed:0,practice:true});
  reachLucky(missed);
  const active = missed.state;
  missed.update(active.luckyRemaining+0.01);
  const events = missed.drainEvents();
  assert.equal(events.find(event => event.type === 'luckyEnd')?.success,false);
  assert.equal(events.find(event => event.type === 'luckyEnd')?.scoreDelta,0);
  assert.equal(events.filter(event => event.type === 'attack').length,0);
  assert.equal(missed.state.health,active.health);
  assert.equal(missed.state.combo,active.combo);
  assert.equal(missed.state.luckyEncounters,1);
  assert.equal(missed.state.luckyClears,0);
});

test('lucky deadline accepts an exact final key, and pause freezes the timer', () => {
  const game = new Game({seed:0,practice:true});
  reachLucky(game);
  const before = game.state.luckyRemaining;
  assert.equal(game.state.enemies[0].progress,0);
  game.update(before/4);
  assert.ok(Math.abs(game.state.enemies[0].progress-0.25) < 1e-9);
  const progress = game.state.enemies[0].progress;
  const pausedRemaining = game.state.luckyRemaining;
  game.pause(); game.update(100); game.resume(); game.update(0.8);
  assert.equal(game.state.luckyRemaining,pausedRemaining);
  assert.equal(game.state.enemies[0].progress,progress);
  game.update(before/4);
  assert.ok(Math.abs(game.state.enemies[0].progress-0.5) < 1e-9);
  for (let step=1;step<=3;step++) {
    while (game.state.luckyStep === step && game.state.enemies[0].guide.length > 1)
      game.type(game.state.enemies[0].guide[0]);
    if (step < 3) game.type(game.state.enemies[0].guide[0]);
  }
  game.update(game.state.luckyRemaining);
  assert.equal(game.state.luckyActive,true);
  assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.equal(game.state.luckyClears,1);
});

test('checkpoint retry preserves earned lucky reward and deterministic replay', () => {
  const run = () => {
    const game = new Game({seed:0});
    reachLucky(game);
    const phrases = finishLucky(game);
    let guard = 0;
    while (game.state.stage < 1 && guard++ < 10000) {
      if (game.state.mode === 'travel') game.update(3);
      else finishNormalEnemy(game);
    }
    assert.ok(guard < 10000);
    return {game,phrases};
  };
  const first = run();
  assert.deepEqual(first.phrases,run().phrases);
  const {game} = first;
  const checkpointScore = game.state.score;
  let guard = 0;
  while (game.state.mode !== 'defeat' && guard++ < 10000) {
    if (game.state.mode === 'travel') game.update(3);
    else game.update(Math.max(...game.state.enemies.map(enemy => enemy.remaining))+0.01);
  }
  assert.ok(guard < 10000);
  game.retryCheckpoint();
  assert.equal(game.state.score,checkpointScore);
  assert.equal(game.state.luckyEncounters,1);
  assert.equal(game.state.luckyClears,1);
  assert.equal(game.state.luckyBonus,500);
  while (game.state.stage < 2 && guard++ < 20000) {
    if (game.state.mode === 'travel') game.update(3);
    else finishNormalEnemy(game);
  }
  assert.equal(game.state.luckyEncounters,1);
});

test('lucky keys, misses, and timer do not enter clear accuracy or KPM', () => {
  const game = new Game({seed:0,practice:true});
  let normalHits = 0;
  let guard = 0;
  while (game.state.mode !== 'clear' && guard++ < 20000) {
    if (game.state.mode === 'travel') { game.update(3); continue; }
    if (game.state.luckyActive) {
      game.type('q');
      game.update(4);
    }
    if (game.state.mode !== 'playing') continue;
    game.type(game.state.enemies[0].guide[0]);
    for (const event of game.drainEvents()) if (event.type === 'hit' && !event.lucky) normalHits++;
  }
  assert.ok(guard < 20000);
  const result = game.state.results!;
  assert.equal(result.correct,normalHits);
  assert.equal(result.mistakes,0);
  assert.equal(result.accuracy,1);
  assert.equal(result.keysPerMinute,result.correct*60/result.clearTime);
  assert.equal(result.luckyEncounters,1);
  assert.equal(result.luckyClears,0);
  assert.equal(result.luckyBonus,0);
});
