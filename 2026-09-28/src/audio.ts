/** Sample-led game sound. Provenance: docs/ALPHA_AUDIO.md; mix: docs/V03_AUDIO.md. */
const FILES = ["darkness-road.ogg", "shot-1.mp3", "shot-2.mp3", "shot-3.mp3", "hit.ogg", "body.ogg", "metal.ogg", "bell.ogg", "glass.ogg"] as const;
type AudioFile = (typeof FILES)[number];
type VoiceGroup = "gun" | "impact" | "accent";
type Voice = { source: AudioBufferSourceNode; gain: GainNode; group: VoiceGroup };
export type ShotOptions = { zone?: "body" | "head" | "limb"; finishing?: boolean };
const clamp = (n: number, a: number, b: number) => Math.min(b, Math.max(a, Number.isFinite(n) ? n : a));

export class GameAudio {
  private context: AudioContext | null = null;
  private master!: GainNode;
  private music!: GainNode;
  private musicDuck!: GainNode;
  private effects!: GainNode;
  private gunBus!: BiquadFilterNode;
  private impactBus!: BiquadFilterNode;
  private accentBus!: BiquadFilterNode;
  private filter!: BiquadFilterNode;
  private musicSource: AudioBufferSourceNode | null = null;
  private musicSourceGain: GainNode | null = null;
  private musicStartedAt = 0;
  private musicOffset = 0;
  private voices: Voice[] = [];
  private oscillators = new Set<OscillatorNode>();
  private buffers = new Map<AudioFile, AudioBuffer>();
  private loading: Promise<boolean> | null = null;
  private active = false;
  private level = 0;
  private shotIndex = 0;
  private lastShot = -1;
  private lastMiss = -1;
  private lastBossPhase = 0;
  muted = false;
  musicVolume = 0.45;
  effectsVolume = 0.75;

  private init(): AudioContext {
    if (this.context) return this.context;
    const c = new AudioContext({ latencyHint: "interactive" });
    const limiter = c.createDynamicsCompressor();
    limiter.threshold.value = -14; limiter.knee.value = 5; limiter.ratio.value = 10;
    limiter.attack.value = 0.003; limiter.release.value = 0.14;
    this.master = c.createGain(); this.master.gain.value = 0.64;
    this.master.connect(limiter).connect(c.destination);
    this.music = c.createGain(); this.music.gain.value = 0;
    this.musicDuck = c.createGain(); this.musicDuck.gain.value = 1;
    this.filter = c.createBiquadFilter(); this.filter.type = "lowpass";
    this.filter.Q.value = 0.6; this.filter.frequency.value = 1300;
    this.filter.connect(this.musicDuck).connect(this.music).connect(this.master);
    this.effects = c.createGain(); this.effects.connect(this.master);
    this.gunBus = c.createBiquadFilter(); this.gunBus.type = "highpass"; this.gunBus.frequency.value = 105;
    this.gunBus.connect(this.effects);
    this.impactBus = c.createBiquadFilter(); this.impactBus.type = "lowpass"; this.impactBus.frequency.value = 5900;
    this.impactBus.connect(this.effects);
    this.accentBus = c.createBiquadFilter(); this.accentBus.type = "highpass"; this.accentBus.frequency.value = 330;
    this.accentBus.connect(this.effects);
    this.context = c; this.applyVolumes();
    return c;
  }

  /** Progress callback receives completed and total file counts. */
  load(onProgress?: (completed: number, total: number) => void): Promise<boolean> {
    if (this.loading) return this.loading;
    const c = this.init();
    const missing = FILES.filter((file) => !this.buffers.has(file));
    if (missing.length === 0) return Promise.resolve(true);
    let done = 0;
    this.loading = Promise.all(missing.map(async (file) => {
      try {
        const response = await fetch(new URL(`assets/audio/${file}`, document.baseURI));
        if (!response.ok) throw new Error(`${response.status}: ${file}`);
        this.buffers.set(file, await c.decodeAudioData(await response.arrayBuffer()));
      } catch (error) { console.warn(`Audio unavailable: ${file}`, error); }
      finally { onProgress?.(++done, missing.length); }
    })).then(() => {
      if (this.active) this.beginMusic();
      const complete = FILES.every((file) => this.buffers.has(file));
      if (!complete) this.loading = null; // a later user gesture may retry failed downloads
      return complete;
    });
    return this.loading;
  }

  async unlock(): Promise<boolean> {
    try {
      const c = this.init();
      await c.resume();
      void this.load();
      if (this.active) this.beginMusic();
      return c.state === "running";
    } catch { return false; }
  }

  private play(file: AudioFile, volume: number, group: VoiceGroup, delay = 0, rate = 1, tail = 0): void {
    const c = this.context, buffer = this.buffers.get(file);
    if (!c || c.state !== "running" || !buffer || this.muted) return;
    const limits: Record<VoiceGroup, number> = { gun: 4, impact: 5, accent: 3 };
    const inGroup = this.voices.filter((voice) => voice.group === group);
    if (inGroup.length >= limits[group]) this.retireVoice(inGroup[0]);
    if (this.voices.length >= 12) this.retireVoice(this.voices[0]);
    const source = c.createBufferSource(), gain = c.createGain();
    source.buffer = buffer; source.playbackRate.value = rate;
    const at = c.currentTime + delay;
    gain.gain.setValueAtTime(clamp(volume, 0, 1), at);
    if (tail > 0) {
      gain.gain.setValueAtTime(clamp(volume, 0, 1), at + Math.max(0, tail - 0.11));
      gain.gain.linearRampToValueAtTime(0, at + tail);
    }
    source.connect(gain).connect(group === "gun" ? this.gunBus : group === "impact" ? this.impactBus : this.accentBus);
    const voice = { source, gain, group };
    source.onended = () => {
      const index = this.voices.indexOf(voice);
      if (index >= 0) this.voices.splice(index, 1);
      source.disconnect(); gain.disconnect();
    };
    this.voices.push(voice); source.start(at);
    if (tail > 0) source.stop(at + tail + 0.015);
  }

  private retireVoice(voice: Voice): void {
    const index = this.voices.indexOf(voice);
    if (index >= 0) this.voices.splice(index, 1);
    try { voice.source.stop(); } catch { /* already ended */ }
  }

  private subdrop(intensity = 0.18): void {
    const c = this.context;
    if (!c || c.state !== "running" || this.muted) return;
    if (this.oscillators.size >= 2) {
      const oldest = this.oscillators.values().next().value;
      if (oldest) {
        this.oscillators.delete(oldest);
        try { oldest.stop(); } catch { /* already ended */ }
      }
    }
    const t = c.currentTime, osc = c.createOscillator(), gain = c.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(82, t);
    osc.frequency.exponentialRampToValueAtTime(42, t + 0.2);
    gain.gain.setValueAtTime(clamp(intensity, 0, 0.25), t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.28);
    osc.connect(gain).connect(this.impactBus);
    this.oscillators.add(osc);
    osc.start(t); osc.stop(t + 0.29);
    osc.onended = () => { this.oscillators.delete(osc); osc.disconnect(); gain.disconnect(); };
  }

  /** One accepted key. finishing strengthens the gun transient; kill() supplies the defeat sound. */
  shot(kill?: boolean): void;
  shot(options?: ShotOptions): void;
  shot(options: boolean | ShotOptions = false): void {
    const c = this.context;
    if (!c || c.state !== "running") return;
    const rapid = c.currentTime - this.lastShot < 0.095;
    this.lastShot = c.currentTime;
    const file = (`shot-${this.shotIndex++ % 3 + 1}.mp3`) as AudioFile;
    const finishing = typeof options === "boolean" ? options : !!options.finishing;
    const zone = typeof options === "boolean" ? "body" : options.zone ?? "body";
    this.play(file, rapid ? 0.43 : finishing ? 0.76 : 0.69, "gun", 0, 0.98 + this.shotIndex % 3 * 0.025, 0.31);
    if (zone === "head") {
      this.play("metal.ogg", rapid ? 0.09 : 0.15, "impact", 0.025, 1.24, 0.17);
    } else if (zone === "limb") {
      this.play("hit.ogg", rapid ? 0.085 : 0.13, "impact", 0.028, 1.2, 0.15);
    } else {
      this.play("hit.ogg", rapid ? 0.1 : 0.16, "impact", 0.027, 0.96 + this.shotIndex % 4 * 0.025, 0.17);
    }
    if (typeof options === "boolean" && options) this.kill(0); // legacy behavior
  }
  kill(combo = 0, kind: "normal" | "boss" = "normal"): void {
    this.play("body.ogg", kind === "boss" ? 0.56 : 0.38, "impact", 0, combo >= 10 ? 0.87 : 1, 0.29);
    this.play("metal.ogg", kind === "boss" ? 0.27 : 0.15, "accent", 0.07, 0.95, 0.25);
    if (combo >= 6) this.play("glass.ogg", 0.08 + Math.min(combo, 15) * 0.005, "accent", 0.045, 1.05, 0.28);
    if (kind === "boss") {
      this.subdrop(0.23);
      this.play("bell.ogg", 0.37, "accent", 0.12, 0.74, 0.55);
    } else if (combo >= 10 && combo % 5 === 0) this.subdrop(0.12);
    this.duckMusic(kind === "boss" ? 0.48 : 0.68, kind === "boss" ? 0.55 : 0.23);
  }
  private duckMusic(depth: number, recovery: number): void {
    const c = this.context;
    if (!c || !this.musicSource) return;
    const t = c.currentTime;
    this.musicDuck.gain.cancelScheduledValues(t);
    this.musicDuck.gain.setValueAtTime(this.musicDuck.gain.value, t);
    this.musicDuck.gain.linearRampToValueAtTime(depth, t + 0.012);
    this.musicDuck.gain.setTargetAtTime(1, t + 0.035, recovery / 3);
  }
  miss(): void {
    const c = this.context;
    if (!c || c.currentTime - this.lastMiss < 0.09) return;
    this.lastMiss = c.currentTime;
    this.play("metal.ogg", 0.08, "accent", 0, 0.62, 0.13);
  }
  hurt(): void { this.play("body.ogg", 0.37, "impact", 0, 0.7, 0.3); this.subdrop(0.19); }
  celebrate(): void { this.kill(0); }
  tier(level: number): void {
    const l = clamp(Math.floor(level), 0, 4);
    if (l === 0) return;
    this.play("bell.ogg", 0.17 + l * 0.025, "accent", 0, 0.9 + l * 0.07, 0.4);
    if (l === 4) this.play("bell.ogg", 0.2, "accent", 0.14, 1.32, 0.45);
  }
  /** Small variation for every fifth kill after the top tier has been reached. */
  streak(combo: number): void {
    if (combo < 20 || combo % 5 !== 0) return;
    this.play("bell.ogg", 0.23, "accent", 0.08, 1.3 + (combo / 5) % 2 * 0.09, 0.42);
    this.play("glass.ogg", 0.1, "accent", 0.16, 1.25, 0.29);
  }
  transition(stage: number): void {
    this.play("metal.ogg", 0.25, "accent", 0, 0.74, 0.33);
    if (stage >= 3) this.boss();
  }
  boss(): void { this.play("glass.ogg", 0.34, "accent", 0, 0.66, 0.4); this.subdrop(0.21); }
  /** Distinct entry, escalation and final phase cues. */
  bossPhase(phase: 1 | 2 | 3): void {
    if (phase === this.lastBossPhase) return;
    this.lastBossPhase = phase;
    if (phase === 1) {
      this.play("metal.ogg", 0.29, "accent", 0, 0.67, 0.38);
      this.play("bell.ogg", 0.18, "accent", 0.17, 0.63, 0.44);
    } else if (phase === 2) {
      this.play("glass.ogg", 0.27, "accent", 0, 0.8, 0.4);
      this.play("metal.ogg", 0.23, "accent", 0.13, 1.1, 0.3);
    } else {
      this.play("bell.ogg", 0.32, "accent", 0, 0.62, 0.5);
      this.play("glass.ogg", 0.21, "accent", 0.19, 1.1, 0.34);
    }
    this.subdrop(phase === 3 ? 0.23 : 0.16);
    this.duckMusic(0.62, 0.43);
  }
  victory(): void {
    this.play("bell.ogg", 0.39, "accent", 0, 1, 0.65);
    this.play("bell.ogg", 0.28, "accent", 0.17, 1.25, 0.56);
    this.play("bell.ogg", 0.3, "accent", 0.37, 1.5, 0.65);
    this.subdrop(0.18);
    this.duckMusic(0.4, 0.85);
  }

  setLevel(level: number): void {
    const nextLevel = clamp(Math.floor(level), 0, 4);
    if (nextLevel === this.level) return;
    this.level = nextLevel;
    const c = this.context;
    if (!c) return;
    const beat = 60 / 165;
    const next = this.musicSource ? c.currentTime + (beat - (c.currentTime - this.musicStartedAt) % beat) % beat : c.currentTime;
    this.filter.frequency.cancelScheduledValues(c.currentTime);
    this.filter.frequency.setTargetAtTime([1150, 1900, 3000, 5000, 10000][this.level], next, 0.12);
  }
  setVolumes(music: number, effects: number, muted = this.muted): void {
    this.musicVolume = clamp(music, 0, 1);
    this.effectsVolume = clamp(effects, 0, 1);
    this.muted = muted; this.applyVolumes();
  }
  private applyVolumes(): void {
    const c = this.context;
    if (!c) return;
    this.music.gain.setTargetAtTime(this.muted ? 0 : this.musicVolume * 0.5, c.currentTime, 0.03);
    this.effects.gain.setTargetAtTime(this.muted ? 0 : this.effectsVolume, c.currentTime, 0.018);
  }
  start(): void { this.active = true; this.beginMusic(); }
  private beginMusic(): void {
    const c = this.context, buffer = this.buffers.get("darkness-road.ogg");
    if (!this.active || !c || c.state !== "running" || !buffer || this.musicSource) return;
    const source = c.createBufferSource(), fade = c.createGain(); source.buffer = buffer; source.loop = true;
    fade.gain.setValueAtTime(0, c.currentTime);
    fade.gain.linearRampToValueAtTime(1, c.currentTime + 0.12);
    source.connect(fade).connect(this.filter);
    const offset = this.musicOffset % buffer.duration;
    this.musicStartedAt = c.currentTime - offset;
    this.musicSource = source; this.musicSourceGain = fade; source.start(c.currentTime, offset);
    source.onended = () => {
      source.disconnect(); fade.disconnect();
      if (this.musicSource === source) { this.musicSource = null; this.musicSourceGain = null; }
    };
    this.filter.frequency.setTargetAtTime([1150, 1900, 3000, 5000, 10000][this.level], c.currentTime, 0.12);
  }
  stop(immediate = true): void {
    this.active = false;
    const c = this.context;
    if (c && this.musicSource) {
      const source = this.musicSource, fade = this.musicSourceGain;
      const duration = source.buffer?.duration ?? 128;
      this.musicOffset = ((c.currentTime - this.musicStartedAt) % duration + duration) % duration;
      if (fade) {
        fade.gain.cancelScheduledValues(c.currentTime);
        fade.gain.setValueAtTime(fade.gain.value, c.currentTime);
        fade.gain.linearRampToValueAtTime(0, c.currentTime + (immediate ? 0.025 : 0.16));
      }
      try { source.stop(c.currentTime + (immediate ? 0.03 : 0.17)); } catch { /* already stopped */ }
      this.musicSource = null; this.musicSourceGain = null;
    }
    if (immediate) {
      for (const voice of this.voices.slice()) {
        try { voice.source.stop(); } catch { /* already finished */ }
      }
      for (const osc of this.oscillators) {
        try { osc.stop(); } catch { /* already finished */ }
      }
      this.voices = [];
      this.oscillators.clear();
    }
    this.lastShot = -1; this.lastMiss = -1;
    this.lastBossPhase = 0;
    if (c) { this.musicDuck.gain.cancelScheduledValues(c.currentTime); this.musicDuck.gain.setValueAtTime(1, c.currentTime); }
  }
  dispose(): void {
    this.stop(); void this.context?.close();
    this.context = null; this.loading = null; this.buffers.clear();
  }
}
