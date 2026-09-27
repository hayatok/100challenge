import assert from 'node:assert/strict';
import test from 'node:test';
import { BOSS_PHRASES, PHRASES } from '../src/content.ts';
import { Game } from '../src/game.ts';
import { TypingSession, validateReading } from '../src/typing.ts';

function typeAll(session: TypingSession, keys: string): void {
  for (const key of keys) assert.equal(session.type(key), true, `${keys}: ${key}`);
  assert.equal(session.complete, true, keys);
}

test('romaji graph keeps alternatives and branches the guide after actual keys', () => {
  for (const variant of ['si','shi']) typeAll(new TypingSession('し'),variant);
  for (const variant of ['ti','chi']) typeAll(new TypingSession('ち'),variant);
  for (const variant of ['tu','tsu']) typeAll(new TypingSession('つ'),variant);
  for (const variant of ['hu','fu']) typeAll(new TypingSession('ふ'),variant);
  for (const variant of ['sya','sha','silya','shilya','sixya','shixya']) typeAll(new TypingSession('しゃ'),variant);
  for (const variant of ['tti','cchi','ltuchi','xtuchi']) typeAll(new TypingSession('っち'),variant);
  const session = new TypingSession('しゃ');
  assert.deepEqual(session.keys,['s']);
  assert.equal(session.type('s'),true);
  assert.deepEqual(session.keys,['h','i','y']);
  assert.equal(session.type('h'),true);
  assert.equal(session.guide.startsWith('a') || session.guide.startsWith('i'),true);
  const prior = session.progress;
  assert.equal(session.type('z'),false);
  assert.equal(session.progress,prior);
});

test('n, terminal n and punctuation follow the explicit contract', () => {
  typeAll(new TypingSession('かんじ'),'kanji');
  typeAll(new TypingSession('んあ'),'nna');
  typeAll(new TypingSession('んあ'),"n'a");
  typeAll(new TypingSession('んや'),'nnya');
  typeAll(new TypingSession('ほん'),'honn');
  typeAll(new TypingSession('ほん'),"hon'");
  const bad = new TypingSession('ほん');
  assert.equal(bad.type('h'),true);
  assert.equal(bad.type('o'),true);
  assert.equal(bad.type('n'),true);
  assert.equal(bad.complete,false);
  assert.equal(validateReading('漢字'),false);
  typeAll(new TypingSession('し、ふ。'),'sihu');
});

test('all original content is valid, distinct and large enough', () => {
  assert.ok(PHRASES.length >= 80);
  assert.equal(new Set(PHRASES.map(phrase => phrase.text)).size,PHRASES.length);
  for (const phrase of [...PHRASES,...BOSS_PHRASES]) {
    assert.equal(validateReading(phrase.reading),true,phrase.text);
  }
});

test('first keys in every simultaneous wave are disjoint and a full run clears 24 enemies plus three boss phases', () => {
  const game = new Game({seed:42});
  let normalKills = 0;
  let bossKills = 0;
  let guard = 0;
  while (game.state.mode !== 'clear' && guard++ < 10000) {
    const state = game.state;
    if (state.mode === 'travel') { game.update(0.7); continue; }
    assert.equal(state.mode,'playing');
    if (state.lockedId === null) {
      const initials = state.enemies.flatMap(enemy => enemy.keys);
      assert.equal(initials.length,new Set(initials).size);
    }
    const enemy = [...state.enemies].sort((a,b) => a.remaining-b.remaining)[0];
    assert.ok(enemy);
    assert.equal(game.type(enemy.guide[0]),true);
    for (const event of game.drainEvents()) if (event.type === 'kill') {
      if (event.kind === 'boss') bossKills++; else normalKills++;
    }
  }
  assert.ok(guard < 10000);
  assert.equal(normalKills,24);
  assert.equal(bossKills,3);
  assert.equal(game.state.results?.accuracy,1);
  assert.equal(game.state.results?.attempts,1);
  assert.ok(game.state.score > 27*100);
});

test('seeded phrase assignment never blocks a planned spawn', () => {
  for (let seed=0;seed<32;seed++) {
    const game = new Game({seed});
    let guard = 0;
    while (game.state.mode !== 'clear' && guard++ < 10000) {
      const state = game.state;
      if (state.mode === 'travel') { game.update(0.7); continue; }
      const enemy = state.enemies[0];
      assert.ok(enemy,`seed ${seed}`);
      assert.equal(game.type(enemy.guide[0]),true,`seed ${seed}`);
    }
    assert.equal(game.state.mode,'clear',`seed ${seed}`);
  }
});

test('wrong key preserves graph progress, breaks clean kill and has fixed score', () => {
  const game = new Game({seed:3});
  const enemy = game.state.enemies[0];
  assert.equal(game.type(enemy.guide[0]),true);
  const typed = game.state.enemies[0].typed;
  assert.equal(game.type('0'),false); // unsupported key is ignored
  assert.equal(game.type('q'),false);
  assert.equal(game.state.enemies[0].typed,typed);
  while (game.state.enemies.length) assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.equal(game.state.score,100);
  assert.equal(game.state.combo,0);
  assert.equal(game.state.results,null);
});

test('exact deadline still accepts the final key, while a later frame attacks once', () => {
  const game = new Game({seed:4});
  while (game.state.enemies[0].guide.length > 1) game.type(game.state.enemies[0].guide[0]);
  const remaining = game.state.enemies[0].remaining;
  game.update(remaining);
  assert.equal(game.state.health,3);
  assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.equal(game.state.health,3);

  const late = new Game({seed:4});
  late.update(late.state.enemies[0].remaining+0.001);
  assert.equal(late.state.health,2);
  late.update(0);
  assert.equal(late.state.health,2);
});

test('pause and countdown freeze time; defeat retries current stage at checkpoint', () => {
  const game = new Game({seed:9});
  const before = game.state.enemies[0].remaining;
  game.pause();
  game.update(100);
  assert.equal(game.state.enemies[0].remaining,before);
  assert.equal(game.type(game.state.enemies[0].guide[0]),false);
  game.resume();
  game.update(0.5);
  assert.equal(game.state.mode,'countdown');
  assert.equal(game.state.enemies[0].remaining,before);
  game.update(0.300001);
  assert.equal(game.state.mode,'playing');
  for (let i=0;i<3 && game.state.mode !== 'defeat';i++) {
    game.update(game.state.enemies[0].remaining+0.01);
    if (game.state.mode === 'travel') game.update(0.6);
  }
  assert.equal(game.state.mode,'defeat');
  game.retryCheckpoint();
  assert.equal(game.state.mode,'playing');
  assert.equal(game.state.health,3);
  assert.equal(game.state.stage,0);
  assert.equal(game.state.score,0);
  assert.equal(game.state.combo,0);
  assert.equal(game.state.attempts,2);
});

test('checkpoint retry restores the score from before the current section', () => {
  const game = new Game({seed:17});
  let guard = 0;
  while (game.state.stage === 0 && guard++ < 1000) {
    if (game.state.mode === 'travel') { game.update(0.6); continue; }
    assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  }
  assert.equal(game.state.stage,1);
  const checkpointScore = game.state.score;
  const checkpointMaxCombo = game.state.maxCombo;
  game.update(1);
  while (game.state.enemies.length > 1) assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  assert.ok(game.state.score > checkpointScore);
  while (game.state.mode !== 'defeat' && guard++ < 1000) {
    if (game.state.mode === 'travel') { game.update(1); continue; }
    const remaining = Math.max(...game.state.enemies.map(enemy => enemy.remaining));
    game.update(remaining+0.001);
  }
  assert.equal(game.state.mode,'defeat');
  game.retryCheckpoint();
  assert.equal(game.state.stage,1);
  assert.equal(game.state.score,checkpointScore);
  assert.equal(game.state.maxCombo,checkpointMaxCombo);
  assert.equal(game.state.health,3);
});

test('practice enemies never attack', () => {
  const game = new Game({practice:true});
  game.update(100);
  assert.equal(game.state.health,3);
  assert.equal(game.state.enemies.length,1);
  assert.equal(game.state.enemies[0].telegraph,false);
});

function reachCleanCombo(game: Game, target: number): void {
  let guard = 0;
  while (game.state.combo < target && guard++ < 10000) {
    if (game.state.mode === 'travel') { game.update(1); continue; }
    const enemy = game.state.enemies[0];
    assert.ok(enemy);
    assert.equal(game.type(enemy.guide[0]),true);
  }
  assert.equal(game.state.combo,target);
}

test('visual effects hold after a miss, step down every 0.8 seconds, and repeated misses do not extend the hold', () => {
  const game = new Game({practice:true,seed:42});
  reachCleanCombo(game,15);
  assert.equal(game.state.effectsLevel,4);
  const score = game.state.score;
  const visual = game.state.visualCombo;
  assert.equal(game.type('q'),false);
  assert.equal(game.state.combo,0);
  assert.equal(game.state.score,score);
  assert.equal(game.state.effectsLevel,4);
  game.update(1.49);
  assert.equal(game.state.effectsLevel,4);
  assert.equal(game.state.visualCombo,visual);
  assert.equal(game.type('q'),false);
  game.update(0.02);
  assert.equal(game.state.effectsLevel,3);
  game.update(0.78);
  assert.equal(game.state.effectsLevel,3);
  assert.ok(game.state.visualCombo >= 10);
  game.update(0.02);
  assert.equal(game.state.effectsLevel,2);
  game.update(0.8);
  assert.equal(game.state.effectsLevel,1);
  game.update(0.8);
  assert.equal(game.state.effectsLevel,0);
});

test('recovered clean combo is a floor for decay and starts a new hold after a later break', () => {
  const game = new Game({practice:true,seed:42});
  reachCleanCombo(game,15);
  assert.equal(game.type('q'),false);
  game.update(1.51);
  assert.equal(game.state.effectsLevel,3);
  reachCleanCombo(game,3);
  assert.equal(game.state.effectsLevel,3);
  game.update(10);
  assert.equal(game.state.effectsLevel,1);
  assert.equal(game.state.combo,3);
  reachCleanCombo(game,6);
  assert.equal(game.state.effectsLevel,2);
  if (game.state.mode === 'travel') game.update(1);
  assert.equal(game.state.mode,'playing');
  assert.equal(game.type('q'),false);
  assert.equal(game.state.effectsLevel,2);
  game.update(1.49);
  assert.equal(game.state.effectsLevel,2);
  game.update(0.02);
  assert.equal(game.state.effectsLevel,1);
});

test('pause, countdown, and camera travel do not advance visual decay', () => {
  const game = new Game({practice:true,seed:42});
  reachCleanCombo(game,3);
  assert.equal(game.state.mode,'travel');
  game.update(0.6);
  assert.equal(game.state.mode,'playing');
  assert.equal(game.type('q'),false);
  game.update(1);
  assert.equal(game.state.effectsLevel,1);
  game.pause();
  game.update(100);
  assert.equal(game.state.effectsLevel,1);
  game.resume();
  game.update(0.8);
  assert.equal(game.state.effectsLevel,1);
  game.update(0.49);
  assert.equal(game.state.effectsLevel,1);
  game.update(0.02);
  assert.equal(game.state.effectsLevel,0);
});
