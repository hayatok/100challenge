import test from "node:test";
import assert from "node:assert/strict";
import { GameAudio, LUCKY_BPM } from "../src/audio.ts";

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
  gains: Node[] = []; filters: Node[] = []; sources: Source[] = []; oscillators: Source[] = [];
  createGain() { const node = new Node(); this.gains.push(node); return node; }
  createDynamicsCompressor() { return new Node(); }
  createBiquadFilter() { const node = new Node(); this.filters.push(node); return node; }
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
    const rushLayer = c.gains[3].gain;
    audio.setRush(true);
    audio.setRush(true);
    assert.equal(rushLayer.events.filter((e) => e.kind === "target" && e.value === 0.26).length, 1, "rush state is idempotent");
    assert.equal(c.sources.filter((s) => s.loop).length, 1, "rush does not restart the BGM");
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
    audio.shot({ finishing: true, level: 4 });
    assert.equal(c.sources.length - beforeMute, 4, "final shot layers a bounded attack and click over the gun and hit");
    const finalVoices = c.sources.slice(beforeMute);
    assert.ok(finalVoices.every((s) => s.stops[0] <= c.currentTime + 0.36), "final shot layers have short tails");
    assert.ok(c.gains.slice(-4).every((g) => g.gain.events[0].value! < 0.9), "final shot layer gains stay bounded");
    const beforeExplosion = c.sources.length;
    audio.rushStart(); audio.rushEnd();
    audio.explosion(999);
    assert.equal(c.sources.length - beforeExplosion, 6, "rush signals and explosion use a fixed number of sample voices");
    assert.ok(duck.events.some((e) => e.kind === "ramp" && e.value === 0.38), "explosion briefly ducks the BGM");
    for (let i = 0; i < 40; i++) audio.explosion(i + 1);
    assert.ok(c.sources.filter((s) => !s.loop && s.stops.length === 1).length <= 12, "explosion storms stay within the voice cap");
    assert.ok(c.oscillators.filter((osc) => osc.stops.length === 1).length <= 2, "subdrops stay within their oscillator cap");
    const beforePause = c.sources.length;
    c.state = "suspended";
    audio.explosion(4); audio.rushStart(); audio.shot({ rush: true });
    assert.equal(c.sources.length, beforePause, "suspended audio context produces no new voices");
    c.state = "running";
    audio.setVolumes(0.2, 0.3);
    assert.ok(c.gains[1].gain.events.some((e) => e.kind === "target" && e.value === 0.1), "music volume remains independently adjustable");
    assert.ok(c.gains[4].gain.events.some((e) => e.kind === "target" && e.value === 0.3), "effects volume remains independently adjustable");
    audio.bossPhase(3);
    assert.ok(c.oscillators.length > 0);
    audio.stop();
    assert.ok(c.oscillators.every((osc) => osc.stops.some((t) => t === 0)), "stop halts active oscillators");
    const oldMusic = c.sources.find((s) => s.loop)!;
    assert.ok(oldMusic.stops.length > 0);
    assert.ok(rushLayer.events.some((e) => e.kind === "target" && e.value === 0), "stop clears the musical rush layer");
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

test("lucky groove stays bounded across frame ticks, obeys controls, and cancels on pause", async () => {
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
    assert.equal(LUCKY_BPM, 120);
    const audio = new GameAudio();
    await audio.load(); audio.start();
    const c = context!;
    const duck = c.gains[2].gain, dance = c.gains[5].gain;
    audio.setLucky(true);
    const first = c.oscillators.length;
    for (let i = 0; i < 60; i++) audio.setLucky(true);
    assert.equal(c.oscillators.length, first, "frame ticks never duplicate a scheduled beat");
    assert.ok(duck.events.some((e) => e.kind === "target" && e.value === 0.2));
    assert.ok(dance.events.some((e) => e.kind === "target" && e.value === 0.45 * 0.43));
    const beforeShot = c.sources.length, beforeKey = c.oscillators.length;
    audio.shot({ lucky: true });
    assert.equal(c.sources.length - beforeShot, 2, "lucky keys retain gun and body impact samples");
    assert.equal(c.oscillators.length - beforeKey, 1, "a key adds one immediate musical reply");
    audio.luckyWord(1);
    assert.equal(c.oscillators.length - beforeKey, 3, "phrase completion has its own two-note cue");
    for (let i = 0; i < 160; i++) { c.currentTime += 0.025; audio.setLucky(true); }
    assert.ok(c.oscillators.filter((s) => s.stops.length === 1).length <= 32, "active synth nodes have a hard cap");
    audio.setVolumes(0.2, 0.7);
    assert.ok(dance.events.some((e) => e.kind === "target" && e.value === 0.2 * 0.43));
    assert.ok(c.gains[4].gain.events.some((e) => e.kind === "target" && e.value === 0.7));
    audio.setVolumes(0.2, 0.7, true);
    const beforeMute = c.oscillators.length;
    c.currentTime += 0.4; audio.setLucky(true); audio.shot({ lucky: true });
    assert.equal(c.oscillators.length, beforeMute, "mute silences new groove and key tones");
    audio.setVolumes(0.2, 0.7, false);
    c.currentTime += 0.3; audio.setLucky(true);
    assert.ok(c.oscillators.length > beforeMute, "unmute resumes the groove");
    audio.stop();
    assert.ok(c.oscillators.every((s) => s.stops.length > 1), "pause cancels every pending dance node");
    assert.ok(duck.events.some((e) => e.kind === "target" && e.value === 1));
    const afterStop = c.oscillators.length;
    for (let i = 0; i < 10; i++) { c.currentTime += 0.5; audio.setLucky(true); }
    assert.equal(c.oscillators.length, afterStop, "paused game ticks cannot schedule the lucky groove");
    audio.start();
    const afterResume = c.oscillators.length;
    assert.ok(afterResume > afterStop && afterResume - afterStop <= 6,
      "resume schedules one fresh short lookahead, not the paused backlog");
    audio.setLucky(true);
    assert.equal(c.oscillators.length, afterResume, "resumed frame tick does not double the groove");
    audio.luckyEnd(false);
    assert.ok(c.oscillators.length - afterStop <= 10 && c.oscillators.length - afterStop >= 2,
      "new groove and gentle escape have bounded separate cues");
    assert.ok(dance.events.some((e) => e.kind === "target" && e.value === 0));
    const beforeWinSources = c.sources.length, beforeWinTones = c.oscillators.length;
    audio.luckyStart(); audio.luckyEnd(true);
    assert.equal(c.sources.length - beforeWinSources, 1, "success adds one restrained bell sample");
    assert.ok(c.oscillators.length - beforeWinTones <= 13, "arrival and success stay within fixed synth voices");
    audio.dispose();
  } finally {
    globalThis.AudioContext = previousContext;
    globalThis.fetch = previousFetch;
    globalThis.document = previousDocument;
  }
});
