import test from 'node:test';
import assert from 'node:assert/strict';
import { GameAudio } from '../src/audio.ts';

class Param {
  value = 1;
  targets: number[] = [];
  setValueAtTime(value: number) { this.value = value; }
  linearRampToValueAtTime(value: number) { this.value = value; }
  exponentialRampToValueAtTime(value: number) { this.value = value; }
  setTargetAtTime(value: number) { this.value = value; this.targets.push(value); }
  cancelScheduledValues() { /* no-op */ }
}
class Node {
  gain = new Param(); frequency = new Param(); Q = new Param();
  threshold = new Param(); knee = new Param(); ratio = new Param();
  attack = new Param(); release = new Param(); type = '';
  connect<T>(target: T): T { return target; }
  disconnect() { /* no-op */ }
}
class Source extends Node {
  buffer: { duration: number } | null = null;
  playbackRate = new Param(); loop = false;
  onended: (() => void) | null = null;
  stops: number[] = [];
  start() { /* no-op */ }
  stop(time = 0) { this.stops.push(time); }
}
class Context {
  state = 'running'; currentTime = 0; sampleRate = 8000; destination = new Node();
  gains: Node[] = []; sources: Source[] = []; oscillators: Source[] = [];
  createGain() { const node = new Node(); this.gains.push(node); return node; }
  createDynamicsCompressor() { return new Node(); }
  createBiquadFilter() { return new Node(); }
  createBufferSource() { const source = new Source(); this.sources.push(source); return source; }
  createOscillator() { const source = new Source(); this.oscillators.push(source); return source; }
  createBuffer(_channels: number, length: number) { return { duration: 2, getChannelData: () => new Float32Array(length) }; }
  async decodeAudioData() { return { duration: 128 }; }
  async resume() { this.state = 'running'; }
  async close() { this.state = 'closed'; }
}

test('scene beds are idempotent, quiet states attenuate music, and new cues stop with play', async () => {
  const oldContext = globalThis.AudioContext, oldFetch = globalThis.fetch, oldDocument = globalThis.document;
  let context!: Context;
  globalThis.AudioContext = class extends Context { constructor() { super(); context = this; } } as unknown as typeof AudioContext;
  globalThis.fetch = (async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) })) as unknown as typeof fetch;
  globalThis.document = { baseURI: 'https://example.test/game/' } as Document;
  try {
    const audio = new GameAudio();
    audio.setSceneMood('explore');
    await audio.load(); audio.start();
    assert.equal(context.sources.filter(s => s.loop).length, 2, 'music and noise each loop once');
    assert.ok(context.gains[1].gain.targets.includes(.45 * .5 * .18));
    audio.setSceneMood('explore'); audio.setSceneMood('vista'); audio.setSceneMood('combat');
    assert.equal(context.sources.filter(s => s.loop).length, 2, 'mood changes reuse both loops');
    assert.ok(context.gains[1].gain.targets.includes(.45 * .5 * .08));
    const before = context.sources.length;
    audio.approach(.8); audio.approach(.8);
    assert.equal(context.sources.length - before, 2, 'threshold cue is sparse');
    audio.sweep(50);
    assert.equal(context.sources.length - before, 7, 'group count does not spawn more voices');
    audio.setVolumes(.2, .3, true);
    const muted = context.sources.length;
    audio.sweep(8);
    assert.equal(context.sources.length, muted);
    audio.stop();
    assert.ok(context.sources.filter(s => s.loop).every(s => s.stops.length > 0));
    audio.sweep(4);
    assert.equal(context.sources.length, muted, 'pause blocks a new sweep');
    audio.dispose();
  } finally {
    globalThis.AudioContext = oldContext; globalThis.fetch = oldFetch; globalThis.document = oldDocument;
  }
});
