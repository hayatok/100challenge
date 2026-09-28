import test from 'node:test';
import assert from 'node:assert/strict';
import { FeverShow } from '../src/fever.ts';

test('fever remains a full-screen mode after its entrance and counts only direct rush kills', () => {
  const show = new FeverShow();
  show.event({ id: 1, type: 'kill' });
  assert.equal(show.hits, 0);
  show.event({ id: 2, type: 'rushStart' });
  show.update(2);
  assert.equal(show.phase, 'run');
  assert.equal(show.active, true);
  show.event({ id: 3, type: 'kill', collateral: true });
  assert.equal(show.hits, 0);
  for (let n = 0; n < 4; n++) show.event({ id: n + 4, type: 'kill' });
  assert.equal(show.hits, 4);
  show.event({ id: 8, type: 'rushEnd', success: true });
  assert.equal(show.phase, 'complete');
  show.event({ id: 9, type: 'kill' });
  assert.equal(show.hits, 4);
  show.update(3);
  assert.equal(show.phase, 'off');
});

test('failure never displays completion and paused presentation retains its exact lifetime', () => {
  const show = new FeverShow();
  show.event({ id: 1, type: 'rushStart' });
  show.update(.4);
  const remaining = show.remaining;
  show.update(0); show.update(-1); show.update(NaN);
  assert.equal(show.remaining, remaining);
  show.event({ id: 2, type: 'rushEnd', success: false });
  assert.equal(show.phase, 'end');
  show.update(1);
  assert.equal(show.phase, 'off');
  show.event({ id: 3, type: 'rushStart' });
  assert.equal(show.hits, 0);
  show.event({ id: 4, type: 'defeat' });
  assert.equal(show.phase, 'off');
  assert.equal(show.active, false);
  assert.equal(show.pulse, 0);
});
