import test from "node:test";
import assert from "node:assert/strict";
import { GameAudio } from "../src/audio.ts";

class Param {
  value = 1;
  events: { kind: string; value?: number; time: number }[] = [];
  setValueAtTime(value: number, time: number) { this.value = value; this.events.push({ kind: "set", value, time }); }
  linearRampToValueAtTime(value: number, time: number) { this.value = value; this.events.push({ kind: "ramp", value, time }); }
  exponentialRampToValueAtTime(value: number, time: number) { this.value = value; this.events.push({ kind: "exp", value, time }); }
  setTargetAtTime(value: number, time: number) { this.value = value; this.events.push({ kind: "target", value, time }); }
  cancelScheduledValues(time: number) { this.events.push({ kind: "cancel", time }); }
}
class Node {
  gain = new Param(); frequency = new Param(); Q = new Param(); threshold = new Param();
  knee = new Param(); ratio = new Param(); attack = new Param(); release = new Param();
  type = "";
  connect<T>(target: T): T { return target; }
  disconnect() { /* no-op */ }
}
class Source extends Node {
  buffer: { duration: number } | null = null;
  playbackRate = new Param(); loop = false;
  onended: (() => void) | null = null;
  starts: { time: number; offset: number }[] = [];
  stops: number[] = [];
  start(time: number, offset = 0) { this.starts.push({ time, offset }); }
  stop(time = 0) { this.stops.push(time); }
}
class FakeAudioContext {
  state = "running"; currentTime = 0; destination = new Node();
  gains: Node[] = []; sources: Source[] = []; oscillators: Source[] = [];
  createGain() { const node = new Node(); this.gains.push(node); return node; }
  createDynamicsCompressor() { return new Node(); }
  createBiquadFilter() { return new Node(); }
  createBufferSource() { const source = new Source(); this.sources.push(source); return source; }
  createOscillator() { const source = new Source(); this.oscillators.push(source); return source; }
  async decodeAudioData() { return { duration: 128 }; }
  async resume() { this.state = "running"; }
  async close() { this.state = "closed"; }
}

test("rapid shots stay bounded, kills alone duck music, and stop clears subdrops", async () => {
  const previousContext = globalThis.AudioContext;
  const previousFetch = globalThis.fetch;
  const previousDocument = globalThis.document;
  let context: FakeAudioContext | undefined;
  globalThis.AudioContext = class extends FakeAudioContext {
    constructor() { super(); context = this; }
  } as unknown as typeof AudioContext;
  globalThis.fetch = (async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) })) as unknown as typeof fetch;
  globalThis.document = { baseURI: "https://example.test/game/" } as Document;
  try {
    const audio = new GameAudio();
    assert.equal(await audio.load(), true);
    audio.start();
    const c = context!;
    assert.equal(c.sources.filter((s) => s.loop).length, 1);
    // The music duck is the gain immediately following the filter, created before effect buses.
    const duck = c.gains[2].gain;
    const baselineDucks = duck.events.length;
    for (let i = 0; i < 10; i++) { c.currentTime += 0.035; audio.shot({ zone: i % 2 ? "head" : "body" }); }
    assert.equal(duck.events.length, baselineDucks, "shots do not repeatedly duck the BGM");
    assert.ok(c.sources.filter((s) => !s.loop && s.stops.length > 1).length > 0, "oldest voices are stolen under rapid input");
    audio.kill(15);
    assert.ok(duck.events.some((e) => e.kind === "ramp" && e.value === 0.68));
    const beforeMute = c.sources.length;
    audio.setVolumes(0.4, 0.6, true);
    audio.shot({ finishing: true });
    assert.equal(c.sources.length, beforeMute, "muting suppresses new effects");
    audio.setVolumes(0.4, 0.6, false);
    audio.shot({ finishing: true });
    assert.ok(c.sources.length > beforeMute, "unmuting restores effects");
    audio.bossPhase(3);
    assert.ok(c.oscillators.length > 0);
    audio.stop();
    assert.ok(c.oscillators.every((osc) => osc.stops.some((t) => t === 0)), "stop halts active oscillators");
    const oldMusic = c.sources.find((s) => s.loop)!;
    assert.ok(oldMusic.stops.length > 0);
    c.currentTime += 2;
    audio.start();
    const music = c.sources.filter((s) => s.loop);
    assert.equal(music.length, 2);
    assert.ok(music[1].starts[0].offset > 0, "resume retains BGM position");
    audio.dispose();
  } finally {
    globalThis.AudioContext = previousContext;
    globalThis.fetch = previousFetch;
    globalThis.document = previousDocument;
  }
});
