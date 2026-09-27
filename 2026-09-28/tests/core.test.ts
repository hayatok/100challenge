import assert from 'node:assert/strict';
import test from 'node:test';
import { BOSS_PHRASES, OFFICE_PHRASES, PHRASES, RUNNER_PHRASES, WORKER_PHRASES } from '../src/content.ts';
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

test('all authored content is distinct, typeable, and divided by enemy workload', () => {
  assert.ok(PHRASES.length >= 300);
  assert.ok(BOSS_PHRASES.length >= 12);
  assert.equal(PHRASES.length,RUNNER_PHRASES.length+OFFICE_PHRASES.length+WORKER_PHRASES.length);
  assert.equal(new Set([...PHRASES,...BOSS_PHRASES].map(phrase => phrase.text)).size,PHRASES.length+BOSS_PHRASES.length);
  assert.equal(new Set([...PHRASES,...BOSS_PHRASES].map(phrase => phrase.reading)).size,PHRASES.length+BOSS_PHRASES.length);
  for (const phrase of [...PHRASES,...BOSS_PHRASES]) {
    assert.equal(validateReading(phrase.reading),true,phrase.text);
    const session = new TypingSession(phrase.reading);
    typeAll(session,session.guide);
  }
  const lengths = (phrases: typeof PHRASES) => phrases.map(phrase => new TypingSession(phrase.reading).standardLength);
  const runner = lengths(RUNNER_PHRASES);
  const office = lengths(OFFICE_PHRASES);
  const worker = lengths(WORKER_PHRASES);
  assert.ok(Math.max(...runner) < Math.min(...worker));
  assert.ok(runner.reduce((a,b) => a+b,0)/runner.length < office.reduce((a,b) => a+b,0)/office.length);
  assert.ok(office.reduce((a,b) => a+b,0)/office.length < worker.reduce((a,b) => a+b,0)/worker.length);
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

test('seeded phrase assignment remains kind-correct and never blocks a planned spawn', () => {
  const pools = {runner:new Set(RUNNER_PHRASES.map(item => item.text)),office:new Set(OFFICE_PHRASES.map(item => item.text)),worker:new Set(WORKER_PHRASES.map(item => item.text)),boss:new Set(BOSS_PHRASES.map(item => item.text))};
  const seenBoss = new Set<string>();
  for (let seed=0;seed<128;seed++) {
    const game = new Game({seed});
    let guard = 0;
    while (game.state.mode !== 'clear' && guard++ < 10000) {
      const state = game.state;
      if (state.mode === 'travel') { game.update(0.7); continue; }
      if (state.lockedId === null) {
        const initials = state.enemies.flatMap(enemy => enemy.keys);
        assert.equal(initials.length,new Set(initials).size,`seed ${seed}`);
      }
      for (const candidate of state.enemies) {
        assert.ok(pools[candidate.kind].has(candidate.phrase),`seed ${seed}: ${candidate.kind} ${candidate.phrase}`);
        if (candidate.kind === 'boss') seenBoss.add(candidate.phrase);
      }
      const enemy = state.enemies[0];
      assert.ok(enemy,`seed ${seed}`);
      assert.equal(game.type(enemy.guide[0]),true,`seed ${seed}`);
    }
    assert.equal(game.state.mode,'clear',`seed ${seed}`);
  }
  assert.equal(seenBoss.size,BOSS_PHRASES.length);
});

test('a feasible typing order clears timed waves at each difficulty', () => {
  const cps = {relaxed:2,normal:3.5,fierce:5} as const;
  for (const difficulty of ['relaxed','normal','fierce'] as const) for (let seed=0;seed<16;seed++) {
    const game = new Game({difficulty,seed});
    let guard = 0;
    let target: number|null = null;
    while (game.state.mode !== 'clear' && guard++ < 10000) {
      const state = game.state;
      if (state.mode === 'travel') { game.update(1); target = null; continue; }
      assert.equal(state.mode,'playing',`${difficulty} seed ${seed}`);
      if (state.lockedId === null) {
        target = [...state.enemies].sort((a,b) => a.remaining-b.remaining)[0]?.id ?? null;
        game.update(0.25);
      }
      const enemy = game.state.enemies.find(item => item.id === target);
      assert.ok(enemy,`${difficulty} seed ${seed}`);
      game.update(1/cps[difficulty]);
      assert.equal(game.type(enemy.guide[0]),true,`${difficulty} seed ${seed}`);
    }
    assert.ok(guard < 10000,`${difficulty} seed ${seed}`);
    assert.equal(game.state.mode,'clear',`${difficulty} seed ${seed}`);
    assert.equal(game.state.health,3,`${difficulty} seed ${seed}`);
  }
});

test('combat events expose score and combo changes for presentation', () => {
  const game = new Game({seed:2});
  game.drainEvents();
  const enemy = game.state.enemies[0];
  while (game.state.enemies.some(item => item.id === enemy.id)) {
    assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  }
  const events = game.drainEvents();
  assert.equal(events.find(event => event.type === 'lock')?.combo,0);
  assert.ok(events.some(event => event.type === 'hit' && event.enemyId === enemy.id));
  const kill = events.find(event => event.type === 'kill');
  assert.equal(kill?.clean,true);
  assert.equal(kill?.combo,1);
  assert.equal(kill?.scoreDelta,160);
  assert.equal(kill?.effectsLevel,0);
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

test('later waves change the first threat and report a deadline order', () => {
  const game = new Game({seed:42});
  const firstKinds = new Set<string>();
  const layouts = new Set<string>();
  let guard = 0;
  while (game.state.mode !== 'clear' && guard++ < 10000) {
    const state = game.state;
    if (state.mode === 'travel') { game.update(2.2); continue; }
    if (state.enemies.length > 1 && state.lockedId === null) {
      firstKinds.add(state.enemies[0].kind);
      layouts.add(state.enemies.map(e => `${e.kind}:${e.lane}`).join(','));
      assert.deepEqual(state.enemies.map(e => e.threatRank),state.enemies.map((_,i) => i+1));
      const remaining = state.enemies.map(e => e.remaining);
      assert.deepEqual(remaining,[...remaining].sort((a,b) => a-b));
    }
    assert.equal(game.type(state.enemies[0].guide[0]),true);
  }
  assert.equal(game.state.mode,'clear');
  assert.ok(firstKinds.has('runner'));
  assert.ok(firstKinds.has('worker'));
  assert.ok(firstKinds.has('office'));
  assert.ok(layouts.size >= 4);
});

test('hit events use deterministic zones and the final shot is a head finisher', () => {
  const game = new Game({seed:9});
  game.drainEvents();
  const first = game.state.enemies[0];
  while (game.state.enemies.some(e => e.id === first.id))
    assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  const hits = game.drainEvents().filter(e => e.type === 'hit');
  assert.ok(hits.length > 3);
  assert.equal(hits[0].hitZone,'chest');
  assert.equal(hits[2].hitZone,'shoulder');
  assert.equal(hits.at(-1)?.hitZone,'head');
  assert.equal(hits.at(-1)?.finisher,true);
  assert.equal(hits.filter(e => e.finisher).length,1);
});

test('boss introduction and phase recoveries freeze combat, with increasing warning windows', () => {
  const game = new Game({seed:5});
  let guard = 0;
  while (game.state.stage < 3 && guard++ < 10000) {
    if (game.state.mode === 'travel') { game.update(2.2); continue; }
    assert.equal(game.type(game.state.enemies[0].guide[0]),true);
  }
  assert.equal(game.state.mode,'travel');
  game.update(2.19);
  assert.equal(game.state.mode,'travel');
  game.update(0.01);
  assert.equal(game.state.mode,'playing');
  const initial = game.state.enemies[0];
  assert.equal(initial.kind,'boss');
  for (let phase=0;phase<3;phase++) {
    assert.equal(game.state.bossPhase,phase);
    const remaining = game.state.enemies[0].remaining;
    game.update(remaining-(phase === 0 ? 1.0 : phase === 1 ? 1.1 : 1.2)+0.001);
    assert.equal(game.state.enemies[0].telegraph,true);
    while (game.state.mode === 'playing')
      assert.equal(game.type(game.state.enemies[0].guide[0]),true);
    if (phase < 2) {
      assert.equal(game.state.mode,'travel');
      game.update(phase === 0 ? 0.75 : 1.2);
      assert.equal(game.state.mode,'playing');
    }
  }
  assert.equal(game.state.mode,'clear');
  assert.equal(game.state.results?.attempts,1);
});
