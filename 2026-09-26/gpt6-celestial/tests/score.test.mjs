import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const scope={};vm.createContext(scope);vm.runInContext(readFileSync(new URL('../src/score.js',import.meta.url),'utf8'),scope);
test('24-second stereo score has finite, unclipped, non-silent samples and fades to silence',()=>{
  const score=scope.CelestialScore.synthesize(44100);
  assert.equal(score.left.length,24*44100);assert.equal(score.right.length,score.left.length);
  let peak=0,energy=0,difference=0;
  for(let i=0;i<score.left.length;i++){const l=score.left[i],r=score.right[i];assert.ok(Number.isFinite(l)&&Number.isFinite(r));peak=Math.max(peak,Math.abs(l),Math.abs(r));energy+=l*l;difference+=Math.abs(l-r)}
  assert.ok(peak>.1&&peak<.95,`peak ${peak}`);assert.ok(Math.sqrt(energy/score.left.length)>.02);assert.ok(difference>1);
  assert.ok(Math.abs(score.left.at(-1))<.0001);assert.equal(score.left[0],0);
});
test('score generation is repeatable at the same sample rate',()=>{
  const a=scope.CelestialScore.synthesize(8000),b=scope.CelestialScore.synthesize(8000);
  assert.deepEqual(a.left,b.left);assert.deepEqual(a.right,b.right);
});
