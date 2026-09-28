import test from 'node:test';
import assert from 'node:assert/strict';
import { gradeResult, previousComparable, compareResults } from '../src/results.ts';
import { RESULT_RULES_VERSION, type SavedResult } from '../src/storage.ts';

const result = (overrides: Partial<SavedResult> = {}): SavedResult => ({
  score:4500,combo:10,accuracy:0.95,seconds:180,cleared:true,
  difficulty:'normal',practice:false,retries:0,date:'2026-09-28T00:00:00.000Z',
  rulesVersion:RESULT_RULES_VERSION,...overrides,
});

test('grades reward a clean clear while retries and defeat have explicit limits',()=>{
  assert.equal(gradeResult(result({combo:20,accuracy:0.99})), 'S');
  assert.equal(gradeResult(result({combo:20,accuracy:0.99,retries:1})), 'A');
  assert.equal(gradeResult(result({combo:8,accuracy:0.9})), 'B');
  assert.equal(gradeResult(result({combo:2,accuracy:0.7})), 'C');
  assert.equal(gradeResult(result({cleared:false,combo:27,accuracy:1})), 'D');
});

test('previous comparison uses the same difficulty, practice, and rules',()=>{
  const legacy = result({score:9999,rulesVersion:2});
  const practice = result({score:8888,practice:true});
  const fierce = result({score:7777,difficulty:'fierce'});
  const previous = result({score:4000,combo:7,accuracy:0.9,seconds:200});
  const current = result({score:4500,combo:10,accuracy:0.95,seconds:180});
  assert.equal(previousComparable([previous,legacy,practice,fierce],current),previous);
  const comparison = compareResults(current,previous);
  assert.equal(comparison?.previous,previous);
  assert.equal(comparison?.scoreDelta,500);
  assert.equal(comparison?.comboDelta,3);
  assert.ok(Math.abs((comparison?.accuracyDelta ?? 0)-0.05) < 1e-9);
  assert.equal(comparison?.secondsDelta,-20);
  assert.equal(compareResults(current,legacy),null);
  assert.equal(previousComparable([legacy,practice,fierce],current),null);
});
