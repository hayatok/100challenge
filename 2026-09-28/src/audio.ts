/** Sample-led game sound. Provenance: docs/ALPHA_AUDIO.md; mix: docs/V04_WEAPON_AUDIO.md. */
const FILES = ["darkness-road.ogg", "shot-1.mp3", "shot-2.mp3", "shot-3.mp3", "hit.ogg", "body.ogg", "metal.ogg", "bell.ogg", "glass.ogg"] as const;
type AudioFile = (typeof FILES)[number];
type VoiceGroup = "gun" | "impact" | "accent";
type Voice = { source: AudioBufferSourceNode; gain: GainNode; group: VoiceGroup };
export type ShotOptions = { zone?: "body" | "head" | "limb"; finishing?: boolean; level?: number; rush?: boolean; lucky?: boolean };
export type SceneMood = "explore" | "combat" | "fever" | "vista";
export const LUCKY_BPM = 120;
const LUCKY_STEP = 60 / LUCKY_BPM / 2;
const clamp = (n: number, a: number, b: number) => Math.min(b, Math.max(a, Number.isFinite(n) ? n : a));

export class GameAudio {
  private context: AudioContext | null = null;
  private master!: GainNode;
  private music!: GainNode;
  private musicDuck!: GainNode;
  private effects!: GainNode;
  private luckyMusic!: GainNode;
  private gunBus!: BiquadFilterNode;
  private impactBus!: BiquadFilterNode;
  private accentBus!: BiquadFilterNode;
  private filter!: BiquadFilterNode;
  private rushFilter!: BiquadFilterNode;
  private rushLayer!: GainNode;
  private ambience!: GainNode;
  private ambienceFilter!: BiquadFilterNode;
  private ambienceSource: AudioBufferSourceNode | null = null;
  private ambienceBuffer: AudioBuffer | null = null;
  private sheltered = false;
  private sceneMood: SceneMood = "combat";
  private lastApproach = -1;
  private musicSource: AudioBufferSourceNode | null = null;
  private musicSourceGain: GainNode | null = null;
  private musicStartedAt = 0;
  private musicOffset = 0;
  private voices: Voice[] = [];
  private oscillators = new Set<OscillatorNode>();
  private luckyOscillators = new Set<OscillatorNode>();
  private cueOscillators = new Set<OscillatorNode>();
  private luckyActive = false;
  private luckyNextTime = 0;
  private luckyStep = 0;
  private buffers = new Map<AudioFile, AudioBuffer>();
  private loading: Promise<boolean> | null = null;
  private active = false;
  private level = 0;
  private shotIndex = 0;
  private lastShot = -1;
  private lastMiss = -1;
  private lastBossPhase = 0;
  private rushing = false;
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
    // The same looping recording supplies a quiet upper-mid pulse in a rush.
    // Its gain moves smoothly, so entering a rush cannot restart or desync BGM.
    this.rushFilter = c.createBiquadFilter(); this.rushFilter.type = "highpass";
    this.rushFilter.frequency.value = 1750; this.rushFilter.Q.value = 0.5;
    this.rushLayer = c.createGain(); this.rushLayer.gain.value = 0;
    this.rushFilter.connect(this.rushLayer).connect(this.musicDuck);
    this.effects = c.createGain(); this.effects.connect(this.master);
    this.gunBus = c.createBiquadFilter(); this.gunBus.type = "highpass"; this.gunBus.frequency.value = 105;
    this.gunBus.connect(this.effects);
    this.impactBus = c.createBiquadFilter(); this.impactBus.type = "lowpass"; this.impactBus.frequency.value = 5900;
    this.impactBus.connect(this.effects);
    this.accentBus = c.createBiquadFilter(); this.accentBus.type = "highpass"; this.accentBus.frequency.value = 330;
    this.accentBus.connect(this.effects);
    this.luckyMusic = c.createGain(); this.luckyMusic.gain.value = 0;
    this.luckyMusic.connect(this.master);
    this.ambienceFilter = c.createBiquadFilter(); this.ambienceFilter.type = "lowpass";
    this.ambienceFilter.frequency.value = 680;
    this.ambience = c.createGain(); this.ambience.gain.value = 0;
    this.ambienceFilter.connect(this.ambience).connect(this.effects);
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
      if (this.active) { this.beginMusic(); this.beginAmbience(); }
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
      if (this.active) { this.beginMusic(); this.beginAmbience(); }
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

  /** One accepted key. finishing adds a compact mechanical attack; kill() supplies the defeat sound. */
  shot(kill?: boolean): void;
  shot(options?: ShotOptions): void;
  shot(options: boolean | ShotOptions = false): void {
    const c = this.context;
    if (!c || c.state !== "running") return;
    const rapid = c.currentTime - this.lastShot < 0.095;
    this.lastShot = c.currentTime;
    const file = (`shot-${this.shotIndex++ % 3 + 1}.mp3`) as AudioFile;
    const finishing = typeof options === "boolean" ? options : !!options.finishing;
    const rush = typeof options === "boolean" ? this.rushing : (options.rush ?? this.rushing);
    const zone = typeof options === "boolean" ? "body" : options.zone ?? "body";
    const level = typeof options === "boolean" ? this.level : clamp(options.level ?? this.level, 0, 4);
    this.play(file, finishing ? (rapid ? 0.65 : 0.76) + level * 0.012 + (rush ? 0.035 : 0) : rapid ? 0.43 : 0.69,
      "gun", 0, 0.98 + this.shotIndex % 3 * 0.025, finishing ? 0.34 : 0.31);
    if (finishing) {
      // A second recording gives the final shot a denser attack without
      // extending its tail. The fast metal click marks the slide's movement.
      this.play("shot-3.mp3", 0.18 + level * 0.02 + (rush ? 0.035 : 0), "gun", 0.009, 0.84, 0.19);
      this.play("metal.ogg", 0.11 + level * 0.012, "accent", 0.011, 1.46, 0.12);
      this.subdrop(rush ? 0.19 : 0.12);
      if (level >= 2 || rush) {
        const note = [523.25, 587.33, 659.25, 783.99][clamp(level - 1, 0, 3)];
        this.synth(note, rush ? 0.105 : 0.07, c.currentTime + 0.018, 0.15, "triangle", false);
      }
    }
    if (zone === "head") {
      this.play("metal.ogg", rapid ? 0.09 : 0.15, "impact", 0.025, 1.24, 0.17);
    } else if (zone === "limb") {
      this.play("hit.ogg", rapid ? 0.085 : 0.13, "impact", 0.028, 1.2, 0.15);
    } else {
      this.play("hit.ogg", rapid ? 0.1 : 0.16, "impact", 0.027, 0.96 + this.shotIndex % 4 * 0.025, 0.17);
    }
    if (typeof options === "boolean" && options) this.kill(0); // legacy behavior
    if (typeof options !== "boolean" && options.lucky) this.luckyHit();
  }
  kill(combo = 0, kind: "normal" | "boss" = "normal"): void {
    const tier = combo >= 15 ? 4 : combo >= 10 ? 3 : combo >= 6 ? 2 : combo >= 3 ? 1 : 0;
    this.play("body.ogg", kind === "boss" ? 0.62 : 0.39 + tier * 0.035, "impact", 0, combo >= 10 ? 0.87 : 1, 0.32);
    this.play("metal.ogg", kind === "boss" ? 0.31 : 0.16 + tier * 0.025, "accent", 0.055, 0.95 + tier * 0.05, 0.27);
    if (tier >= 2) this.play("glass.ogg", 0.12 + tier * 0.025, "accent", 0.045, 1.05 + tier * 0.07, 0.32);
    if (tier >= 1) {
      const root = [0, 523.25, 587.33, 659.25, 783.99][tier];
      this.fanfare(tier >= 3 ? [root, root * 1.25, root * 1.5] : [root, root * 1.25],
        0.055 + tier * 0.01, 0.075, 0.19);
    }
    if (kind === "boss") {
      this.subdrop(0.23);
      this.play("bell.ogg", 0.37, "accent", 0.12, 0.74, 0.55);
    } else if (combo >= 10 && combo % 5 === 0) this.subdrop(0.14);
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
  /** Call on every game tick. The state also applies when BGM starts later. */
  setRush(active: boolean): void {
    if (this.rushing === active) return;
    this.rushing = active;
    const c = this.context;
    if (!c) return;
    const t = c.currentTime;
    this.rushLayer.gain.cancelScheduledValues(t);
    this.rushLayer.gain.setTargetAtTime(active ? 0.26 : 0, t, active ? 0.18 : 0.24);
    this.setFilterFrequency(t);
  }
  /** The caller may repeat this every frame. Only a short lookahead is scheduled. */
  setLucky(active: boolean): void {
    if (this.luckyActive === active) {
      if (active) this.scheduleLucky();
      return;
    }
    this.luckyActive = active;
    const c = this.context;
    if (!c) return;
    const t = c.currentTime;
    this.musicDuck.gain.cancelScheduledValues(t);
    this.musicDuck.gain.setTargetAtTime(active ? 0.2 : 1, t, active ? 0.09 : 0.22);
    this.luckyMusic.gain.cancelScheduledValues(t);
    this.luckyMusic.gain.setTargetAtTime(active && this.active && !this.muted ? this.musicVolume * 0.43 : 0, t, active ? 0.09 : 0.08);
    if (active) {
      this.luckyNextTime = t + 0.025;
      this.luckyStep = 0;
      this.scheduleLucky();
    } else {
      for (const osc of this.luckyOscillators) {
        try { osc.stop(t); } catch { /* already ended */ }
      }
      this.luckyOscillators.clear();
      this.luckyNextTime = 0;
    }
  }
  private synth(frequency: number, volume: number, at: number, duration: number,
    type: OscillatorType, musical = true, endFrequency?: number): void {
    const c = this.context;
    if (!c || c.state !== "running" || this.muted) return;
    const pool = musical ? this.luckyOscillators : this.cueOscillators;
    const limit = musical ? 32 : 24;
    if (pool.size >= limit) {
      const oldest = pool.values().next().value;
      if (oldest) { pool.delete(oldest); try { oldest.stop(c.currentTime); } catch { /* ended */ } }
    }
    const osc = c.createOscillator(), gain = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(frequency, at);
    if (endFrequency) osc.frequency.exponentialRampToValueAtTime(endFrequency, at + duration);
    gain.gain.setValueAtTime(0.0001, at);
    gain.gain.linearRampToValueAtTime(clamp(volume, 0, 0.22), at + Math.min(0.009, duration / 4));
    gain.gain.exponentialRampToValueAtTime(0.0001, at + duration);
    osc.connect(gain).connect(musical ? this.luckyMusic : this.accentBus);
    pool.add(osc);
    osc.onended = () => { pool.delete(osc); osc.disconnect(); gain.disconnect(); };
    osc.start(at); osc.stop(at + duration + 0.01);
  }
  /** A short bright answer to an earned event. All notes use the effects slider. */
  private fanfare(notes: readonly number[], volume: number, spacing = 0.095, duration = 0.25): void {
    const at = this.context?.currentTime;
    if (at === undefined) return;
    notes.forEach((note, i) => this.synth(note, volume, at + i * spacing, duration, "triangle", false));
  }
  private scheduleLucky(): void {
    const c = this.context;
    if (!this.luckyActive || !this.active || !c || c.state !== "running" || this.muted) return;
    // A hidden tab can skip many beats. Resume at the present; never queue a backlog.
    if (this.luckyNextTime < c.currentTime - LUCKY_STEP) this.luckyNextTime = c.currentTime + 0.02;
    while (this.luckyNextTime < c.currentTime + 0.3) {
      const at = this.luckyNextTime, step = this.luckyStep++ % 16;
      // Two-bar A-minor loop: alternating bass, backbeat, bright offbeat chords.
      if (step % 2 === 0) {
        const bass = step < 8 ? (step % 4 === 0 ? 110 : 164.81) : (step % 4 === 0 ? 130.81 : 196);
        this.synth(bass, 0.19, at, 0.19, "triangle");
        this.synth(step % 4 === 0 ? 88 : 220, step % 4 === 0 ? 0.18 : 0.085,
          at, 0.11, "sine", true, step % 4 === 0 ? 45 : 100);
      } else {
        const chord = step < 8 ? [261.63, 329.63] : [293.66, 349.23];
        this.synth(chord[0], 0.057, at, 0.16, "triangle");
        this.synth(chord[1], 0.046, at, 0.16, "triangle");
      }
      this.synth(step % 4 === 2 ? 860 : 1250, step % 4 === 2 ? 0.045 : 0.025,
        at, 0.045, "triangle", true, 490);
      this.luckyNextTime += LUCKY_STEP;
    }
  }
  /** Arrival flourish. It remains immediate and does not gate input. */
  luckyStart(): void {
    this.setLucky(true);
    const t = this.context?.currentTime;
    if (t === undefined) return;
    this.synth(523.25, 0.12, t, 0.15, "sine", false);
    this.synth(659.25, 0.12, t + 0.09, 0.2, "sine", false);
    this.synth(880, 0.1, t + 0.18, 0.26, "sine", false);
    this.play("glass.ogg", 0.21, "accent", 0.17, 1.28, 0.33);
  }
  /** Accepted lucky key: gun and impact samples remain the primary sound. */
  luckyHit(): void {
    const t = this.context?.currentTime;
    if (t === undefined || !this.luckyActive) return;
    this.synth([523.25, 587.33, 659.25, 783.99][this.shotIndex % 4], 0.055, t, 0.105, "sine", false);
  }
  /** A completed phrase earns a brief ascending reply. */
  luckyWord(step: number): void {
    const t = this.context?.currentTime;
    if (t === undefined) return;
    const base = [587.33, 659.25, 783.99][clamp(Math.floor(step) - 1, 0, 2)];
    this.synth(base, 0.12, t, 0.18, "sine", false);
    this.synth(base * 1.25, 0.09, t + 0.085, 0.22, "sine", false);
    this.play("bell.ogg", 0.17 + clamp(step, 1, 3) * 0.035, "accent", 0.08,
      1.08 + clamp(step, 1, 3) * 0.13, 0.35);
  }
  /** success=false is a gentle exit, with no error or damage association. */
  luckyEnd(success: boolean): void {
    this.setLucky(false);
    const t = this.context?.currentTime;
    if (t === undefined) return;
    if (success) {
      this.fanfare([659.25, 783.99, 1046.5, 1318.5, 1567.98], 0.15, 0.092, 0.34);
      this.play("bell.ogg", 0.32, "accent", 0.12, 1.28, 0.6);
      this.play("glass.ogg", 0.21, "accent", 0.32, 1.45, 0.42);
      this.subdrop(0.2);
    } else {
      this.synth(440, 0.065, t, 0.15, "sine", false);
      this.synth(349.23, 0.05, t + 0.11, 0.19, "sine", false);
    }
  }
  /** Brief upward signal at a four-word rush entrance. */
  rushStart(): void {
    this.play("metal.ogg", 0.27, "accent", 0, 1.12, 0.23);
    this.play("bell.ogg", 0.31, "accent", 0.085, 1.31, 0.42);
    this.fanfare([392, 523.25, 659.25, 783.99], 0.12, 0.07, 0.2);
    this.subdrop(0.19);
  }
  /** A completed four-kill rush pays out; an interrupted one exits gently. */
  rushEnd(success = true): void {
    if (!success) { this.play("metal.ogg", 0.12, "accent", 0, 0.68, 0.22); return; }
    this.play("bell.ogg", 0.38, "accent", 0, 1.16, 0.65);
    this.play("glass.ogg", 0.26, "accent", 0.2, 1.34, 0.46);
    this.fanfare([783.99, 987.77, 1174.66, 1567.98, 1975.53], 0.16, 0.09, 0.35);
    this.subdrop(0.22);
    this.duckMusic(0.42, 0.75);
  }
  /** One ascending, four-step payoff after each rush kill. Step is 1–4. */
  rushKill(step: number): void {
    const index = clamp(Math.floor(step), 1, 4) - 1;
    const roots = [523.25, 659.25, 783.99, 1046.5];
    const root = roots[index];
    this.fanfare(index === 3 ? [root, root * 1.25, root * 1.5] : [root, root * 1.25],
      0.09 + index * 0.018, 0.075, 0.24);
    this.play("bell.ogg", 0.18 + index * 0.055, "accent", 0.045, 1.1 + index * 0.13, 0.35);
  }
  /** One chain explosion cue; count changes weight, never the number of voices. */
  explosion(count: number): void {
    const weight = clamp(Math.floor(count), 1, 6);
    this.play("body.ogg", 0.36 + weight * 0.035, "impact", 0, 0.79, 0.46);
    this.play("metal.ogg", 0.18 + weight * 0.015, "accent", 0.025, 0.72, 0.38);
    this.play("glass.ogg", 0.13 + weight * 0.012, "accent", 0.065, 0.92, 0.43);
    this.subdrop(0.16 + weight * 0.012);
    this.duckMusic(0.38, 0.62);
  }
  /** Sparse warning for a nearby threat. The caller chooses when the threshold is crossed. */
  approach(intensity: number): void {
    const c = this.context;
    if (!this.active || !c || c.state !== "running" || c.currentTime - this.lastApproach < 0.45) return;
    this.lastApproach = c.currentTime;
    const weight = clamp(intensity, 0, 1);
    this.play("body.ogg", 0.07 + weight * 0.09, "impact", 0, 0.58 + weight * 0.1, 0.19);
    if (weight > 0.55) this.play("metal.ogg", 0.045 + weight * 0.045, "accent", 0.095, 0.55, 0.13);
    this.subdrop(0.035 + weight * 0.055);
  }
  /** A single bounded shotgun/shell and group impact cue for a FEVER sweep. */
  sweep(count: number): void {
    const c = this.context;
    if (!this.active || !c || c.state !== "running") return;
    const weight = clamp(Math.floor(count), 1, 8);
    this.play("shot-1.mp3", 0.72, "gun", 0, 0.78, 0.42);
    this.play("shot-3.mp3", 0.33, "gun", 0.014, 0.68, 0.36);
    this.play("metal.ogg", 0.22, "accent", 0.16, 0.94, 0.24);
    this.play("body.ogg", 0.32 + weight * 0.035, "impact", 0.035, 0.7, 0.39);
    this.play("glass.ogg", 0.11 + weight * 0.015, "accent", 0.085, 0.88, 0.34);
    this.subdrop(0.14 + weight * 0.012);
    this.duckMusic(0.42, 0.55);
  }
  miss(): void {
    const c = this.context;
    if (!c || c.currentTime - this.lastMiss < 0.09) return;
    this.lastMiss = c.currentTime;
    this.play("metal.ogg", 0.08, "accent", 0, 0.62, 0.13);
  }
  storefrontImpact(): void { this.play("metal.ogg",.2,"impact",.04,.72,.32);this.play("glass.ogg",.14,"accent",.07,1.12,.35); }
  hurt(): void { this.play("body.ogg", 0.37, "impact", 0, 0.7, 0.3); this.subdrop(0.19); }
  celebrate(): void { this.kill(0); }
  tier(level: number): void {
    const l = clamp(Math.floor(level), 0, 4);
    if (l === 0) return;
    this.play("bell.ogg", 0.17 + l * 0.025, "accent", 0, 0.9 + l * 0.07, 0.4);
    if (l === 4) this.play("bell.ogg", 0.2, "accent", 0.14, 1.32, 0.45);
    this.fanfare([523.25, 587.33, 659.25, 783.99].slice(0, l), 0.075 + l * 0.015, 0.09, 0.2);
  }
  /** Small variation for every fifth kill after the top tier has been reached. */
  streak(combo: number): void {
    if (combo < 20 || combo % 5 !== 0) return;
    this.play("bell.ogg", 0.23, "accent", 0.08, 1.3 + (combo / 5) % 2 * 0.09, 0.42);
    this.play("glass.ogg", 0.1, "accent", 0.16, 1.25, 0.29);
    this.fanfare([783.99, 987.77, 1174.66], 0.12, 0.075, 0.22);
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
    this.fanfare([523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98], 0.16, 0.095, 0.38);
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
    this.setFilterFrequency(next);
  }
  private setFilterFrequency(at: number): void {
    if (!this.context) return;
    this.filter.frequency.cancelScheduledValues(this.context.currentTime);
    this.filter.frequency.setTargetAtTime([1150, 1900, 3000, 5000, 10000][this.level] * (this.rushing ? 1.35 : 1), at, 0.12);
  }
  setVolumes(music: number, effects: number, muted = this.muted): void {
    this.musicVolume = clamp(music, 0, 1);
    this.effectsVolume = clamp(effects, 0, 1);
    this.muted = muted; this.applyVolumes();
  }
  private applyVolumes(): void {
    const c = this.context;
    if (!c) return;
    const musicScale = { explore: 0.18, combat: 1, fever: 0.95, vista: 0.08 }[this.sceneMood];
    this.music.gain.setTargetAtTime(this.muted ? 0 : this.musicVolume * 0.5 * musicScale, c.currentTime, 0.12);
    this.effects.gain.setTargetAtTime(this.muted ? 0 : this.effectsVolume, c.currentTime, 0.018);
    this.luckyMusic.gain.setTargetAtTime(this.muted || !this.luckyActive || !this.active ? 0 : this.musicVolume * 0.43, c.currentTime, 0.03);
    this.ambience.gain.setTargetAtTime(this.muted || !this.active ? 0 :
      (this.sceneMood === "explore" ? 0.11 : this.sceneMood === "vista" ? 0.16 : this.sceneMood === "combat" ? 0.035 : 0.018) * (this.sheltered ? .2 : 1),
      c.currentTime, 0.2);
  }
  setSheltered(sheltered: boolean): void {
    if (this.sheltered === sheltered) return;
    this.sheltered = sheltered;
    if (this.context) this.ambienceFilter.frequency.setTargetAtTime(sheltered ? 280 : 680, this.context.currentTime, .2);
    this.applyVolumes();
  }
  /** Changes the underlying bed without restarting the music or queuing future cues. */
  setSceneMood(mood: SceneMood): void {
    if (this.sceneMood === mood) return;
    this.sceneMood = mood;
    if (this.active) this.beginAmbience();
    this.applyVolumes();
  }
  private beginAmbience(): void {
    const c = this.context;
    if (!this.active || !c || c.state !== "running" || this.ambienceSource || typeof c.createBuffer !== "function") return;
    if (!this.ambienceBuffer) {
      // Fixed-seed, low-passed noise makes a continuous rain/wind bed without an asset.
      const length = c.sampleRate * 2;
      const buffer = c.createBuffer(1, length, c.sampleRate);
      const samples = buffer.getChannelData(0);
      let seed = 18721, drift = 0;
      for (let i = 0; i < length; i++) {
        seed = (1664525 * seed + 1013904223) >>> 0;
        const white = seed / 0xffffffff * 2 - 1;
        drift = drift * 0.992 + white * 0.008;
        samples[i] = white * 0.29 + drift * 0.71;
      }
      this.ambienceBuffer = buffer;
    }
    const source = c.createBufferSource(); source.buffer = this.ambienceBuffer; source.loop = true;
    source.connect(this.ambienceFilter);
    this.ambienceSource = source;
    source.onended = () => { source.disconnect(); if (this.ambienceSource === source) this.ambienceSource = null; };
    source.start();
  }
  start(): void { this.active = true; this.beginMusic(); this.beginAmbience(); this.applyVolumes(); this.scheduleLucky(); }
  private beginMusic(): void {
    const c = this.context, buffer = this.buffers.get("darkness-road.ogg");
    if (!this.active || !c || c.state !== "running" || !buffer || this.musicSource) return;
    const source = c.createBufferSource(), fade = c.createGain(); source.buffer = buffer; source.loop = true;
    fade.gain.setValueAtTime(0, c.currentTime);
    fade.gain.linearRampToValueAtTime(1, c.currentTime + 0.12);
    source.connect(fade);
    fade.connect(this.filter);
    fade.connect(this.rushFilter);
    const offset = this.musicOffset % buffer.duration;
    this.musicStartedAt = c.currentTime - offset;
    this.musicSource = source; this.musicSourceGain = fade; source.start(c.currentTime, offset);
    source.onended = () => {
      source.disconnect(); fade.disconnect();
      if (this.musicSource === source) { this.musicSource = null; this.musicSourceGain = null; }
    };
    this.setFilterFrequency(c.currentTime);
  }
  stop(immediate = true): void {
    this.active = false;
    const c = this.context;
    this.setLucky(false);
    if (this.ambienceSource) {
      const source = this.ambienceSource;
      this.ambienceSource = null;
      try { source.stop(); } catch { /* already stopped */ }
      source.disconnect();
    }
    this.applyVolumes();
    // Arrival and phrase cues are also scheduled nodes, even after the groove ends.
    for (const osc of this.luckyOscillators) {
      try { osc.stop(c?.currentTime); } catch { /* already ended */ }
    }
    this.luckyOscillators.clear();
    for (const osc of this.cueOscillators) {
      try { osc.stop(c?.currentTime); } catch { /* already ended */ }
    }
    this.cueOscillators.clear();
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
    for (const voice of this.voices.slice()) {
      try { voice.source.stop(); } catch { /* already finished */ }
    }
    for (const osc of this.oscillators) {
      try { osc.stop(); } catch { /* already finished */ }
    }
    this.voices = [];
    this.oscillators.clear();
    this.lastShot = -1; this.lastMiss = -1;
    this.lastApproach = -1;
    this.lastBossPhase = 0;
    if (c) { this.musicDuck.gain.cancelScheduledValues(c.currentTime); this.musicDuck.gain.setValueAtTime(1, c.currentTime); }
    this.setRush(false);
  }
  dispose(): void {
    this.stop(); void this.context?.close();
    this.context = null; this.loading = null; this.buffers.clear();
    this.ambienceBuffer = null;
  }
}
