import assert from 'node:assert/strict';
import test from 'node:test';
import { parseSaved, serializeSaved, safeURL } from '../app/src/storage.js';
test('a local saved world survives serialization; corrupt or future states do not enter the simulation', () => {
  const state = { seed: 12345, year: 1935, month: 4 };
  const preferences = { placeId: 'tohoku', personId: 'person-4', speed: 4, reducedMotion: true };
  assert.deepEqual(parseSaved(serializeSaved(state, preferences)), { ...state, ...preferences });
  for (const raw of ['null', '{', '{}', JSON.stringify({ version: 1, seed: 1, year: 2026, month: 12 }), JSON.stringify({ version: 1, seed: 0, year: 1900, month: 1 }), JSON.stringify({ version: 1, seed: 1, year: 1899, month: 1 })]) assert.equal(parseSaved(raw), null);
});
test('external sources can only open http URLs', () => {
  assert.equal(safeURL('javascript:alert(1)'), null);
  assert.equal(safeURL('file:///etc/passwd'), null);
  assert.equal(safeURL('https://www.e-stat.go.jp/'), 'https://www.e-stat.go.jp/');
});
