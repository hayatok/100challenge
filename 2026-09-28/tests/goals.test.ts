import test from 'node:test';
import assert from 'node:assert/strict';
import { nextGoal } from '../src/goals.ts';
import { RESULT_RULES_VERSION, type SavedResult } from '../src/storage.ts';

const run = (overrides: Partial<SavedResult> = {}): SavedResult => ({
  score:1500,combo:15,accuracy:0.98,seconds:120,cleared:true,
  difficulty:'normal',practice:false,retries:0,date:'2026-09-28T00:00:00.000Z',
  rulesVersion:RESULT_RULES_VERSION,rushes:1,chainKills:1,...overrides,
});

test('a defeat receives one achievable completion objective',()=>{
  const goal = nextGoal(run({cleared:false,rushes:0,combo:0}));
  assert.match(goal.title,/完走/);
  assert.equal(Object.keys(goal).length,2);
});

test('new mechanics are suggested only when their zero count is known',()=>{
  assert.match(nextGoal(run({rushes:0,chainKills:0})).title,/ラッシュを1回/);
  assert.match(nextGoal(run({chainKills:0})).title,/連鎖撃破を1回/);
  assert.match(nextGoal(run({rushes:undefined,chainKills:undefined,combo:2})).title,/コンボ3/);
});

test('combo target advances only to the next useful boundary and stops at its cap',()=>{
  assert.match(nextGoal(run({combo:3})).title,/コンボ6/);
  assert.match(nextGoal(run({combo:6})).title,/コンボ10/);
  assert.match(nextGoal(run({combo:10})).title,/コンボ15/);
  assert.doesNotMatch(nextGoal(run({combo:15,accuracy:0.93})).title,/コンボ/);
});

test('accuracy and retry objectives remain observable without invented score promises',()=>{
  assert.match(nextGoal(run({accuracy:0.93})).title,/95%/);
  assert.match(nextGoal(run({accuracy:0.98})).title,/100%/);
  assert.match(nextGoal(run({accuracy:1,retries:1})).title,/リトライなし/);
  const mastered = nextGoal(run({accuracy:1}));
  assert.match(mastered.title,/正確に完走/);
  assert.doesNotMatch(`${mastered.title}${mastered.detail}`,/スコア|自己ベスト/);
});
