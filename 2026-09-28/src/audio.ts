/** Sample-led alpha sound. Provenance: docs/ALPHA_AUDIO.md. */
const FILES = ["darkness-road.ogg", "shot-1.mp3", "shot-2.mp3", "shot-3.mp3", "hit.ogg", "body.ogg", "metal.ogg", "bell.ogg", "glass.ogg"] as const;
type AudioFile = (typeof FILES)[number];
const clamp = (n: number, a: number, b: number) => Math.min(b, Math.max(a, Number.isFinite(n) ? n : a));

export class GameAudio {
  private context: AudioContext | null = null;
  private master!: GainNode;
  private music!: GainNode;
  private effects!: GainNode;
  private filter!: BiquadFilterNode;
  private musicSource: AudioBufferSourceNode | null = null;
  private musicStartedAt = 0;
  private musicOffset = 0;
  private voices: AudioBufferSourceNode[] = [];
  private buffers = new Map<AudioFile, AudioBuffer>();
  private loading: Promise<boolean> | null = null;
  private active = false;
  private level = 0;
  private scheduledLevel: number | null = null;
  private shotIndex = 0;
  private lastShot = -1;
  private lastMiss = -1;
  muted = false;
  musicVolume = 0.45;
  effectsVolume = 0.75;

  private init(): AudioContext {
    if (this.context) return this.context;
    const c = new AudioContext({ latencyHint: "interactive" });
    const limiter = c.createDynamicsCompressor();
    limiter.threshold.value = -12; limiter.knee.value = 6; limiter.ratio.value = 12;
    limiter.attack.value = 0.002; limiter.release.value = 0.16;
    this.master = c.createGain(); this.master.gain.value = 0.7;
    this.master.connect(limiter).connect(c.destination);
    this.music = c.createGain(); this.music.gain.value = 0;
    this.filter = c.createBiquadFilter(); this.filter.type = "lowpass";
    this.filter.Q.value = 0.6; this.filter.frequency.value = 1300;
    this.filter.connect(this.music).connect(this.master);
    this.effects = c.createGain(); this.effects.connect(this.master);
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

  private play(file: AudioFile, volume: number, delay = 0, rate = 1): void {
    const c = this.context, buffer = this.buffers.get(file);
    if (!c || c.state !== "running" || !buffer || this.muted) return;
    const source = c.createBufferSource(), gain = c.createGain();
    source.buffer = buffer; source.playbackRate.value = rate;
    gain.gain.value = clamp(volume, 0, 1);
    source.connect(gain).connect(this.effects);
    source.onended = () => {
      const index = this.voices.indexOf(source);
      if (index >= 0) this.voices.splice(index, 1);
      source.disconnect(); gain.disconnect();
    };
    if (this.voices.length >= 20) this.voices.shift()?.stop();
    this.voices.push(source); source.start(c.currentTime + delay);
  }

  private subdrop(intensity = 0.18): void {
    const c = this.context;
    if (!c || c.state !== "running" || this.muted) return;
    const t = c.currentTime, osc = c.createOscillator(), gain = c.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(84, t);
    osc.frequency.exponentialRampToValueAtTime(38, t + 0.24);
    gain.gain.setValueAtTime(clamp(intensity, 0, 0.3), t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.32);
    osc.connect(gain).connect(this.effects);
    osc.start(t); osc.stop(t + 0.33);
    osc.onended = () => { osc.disconnect(); gain.disconnect(); };
  }

  shot(kill = false): void {
    const c = this.context;
    if (!c || c.state !== "running") return;
    const rapid = c.currentTime - this.lastShot < 0.075;
    this.lastShot = c.currentTime;
    const file = (`shot-${this.shotIndex++ % 3 + 1}.mp3`) as AudioFile;
    this.play(file, rapid ? 0.47 : 0.82, 0, 0.96 + this.shotIndex % 3 * 0.035);
    this.play("hit.ogg", rapid ? 0.09 : 0.18, 0.027, 0.94 + this.shotIndex % 4 * 0.04);
    if (kill) this.kill(0);
  }
  kill(combo = 0, kind: "normal" | "boss" = "normal"): void {
    this.play("body.ogg", 0.5, 0, combo >= 10 ? 0.83 : 1);
    this.play("metal.ogg", 0.22, 0.065);
    if (combo >= 3) this.play("glass.ogg", 0.12 + Math.min(combo, 15) * 0.009, 0.035);
    if (combo >= 6 || kind === "boss") this.subdrop(kind === "boss" ? 0.28 : 0.16);
    if (kind === "boss") this.play("bell.ogg", 0.46, 0.12, 0.72);
  }
  miss(): void {
    const c = this.context;
    if (!c || c.currentTime - this.lastMiss < 0.09) return;
    this.lastMiss = c.currentTime;
    this.play("metal.ogg", 0.08, 0, 0.62);
  }
  hurt(): void { this.play("body.ogg", 0.42, 0, 0.7); this.subdrop(0.24); }
  celebrate(): void { this.kill(0); }
  tier(level: number): void {
    const l = clamp(Math.floor(level), 0, 4);
    if (l === 0) return;
    this.play("bell.ogg", 0.22 + l * 0.035, 0, 0.84 + l * 0.07);
    if (l >= 3) this.subdrop(0.15);
  }
  transition(stage: number): void {
    this.play("metal.ogg", 0.32, 0, 0.74);
    if (stage >= 3) this.boss();
  }
  boss(): void { this.play("glass.ogg", 0.42, 0, 0.65); this.subdrop(0.28); }
  victory(): void {
    this.play("bell.ogg", 0.48);
    this.play("bell.ogg", 0.3, 0.16, 1.26);
    this.play("bell.ogg", 0.32, 0.34, 1.5);
    this.subdrop(0.2);
  }

  setLevel(level: number): void {
    const nextLevel = clamp(Math.floor(level), 0, 4);
    if (nextLevel === this.level && this.scheduledLevel === nextLevel) return;
    this.level = nextLevel;
    const c = this.context;
    if (!c) return;
    const beat = 60 / 165;
    const next = this.musicSource ? c.currentTime + (beat - (c.currentTime - this.musicStartedAt) % beat) % beat : c.currentTime;
    this.filter.frequency.cancelScheduledValues(c.currentTime);
    this.filter.frequency.setTargetAtTime([1150, 1900, 3000, 5000, 10000][this.level], next, 0.12);
    this.scheduledLevel = nextLevel;
  }
  setVolumes(music: number, effects: number, muted = this.muted): void {
    this.musicVolume = clamp(music, 0, 1);
    this.effectsVolume = clamp(effects, 0, 1);
    this.muted = muted; this.applyVolumes();
  }
  private applyVolumes(): void {
    const c = this.context;
    if (!c) return;
    this.music.gain.setTargetAtTime(this.muted ? 0 : this.musicVolume * 0.55, c.currentTime, 0.035);
    this.effects.gain.setTargetAtTime(this.muted ? 0 : this.effectsVolume, c.currentTime, 0.02);
  }
  start(): void { this.active = true; this.beginMusic(); }
  private beginMusic(): void {
    const c = this.context, buffer = this.buffers.get("darkness-road.ogg");
    if (!this.active || !c || c.state !== "running" || !buffer || this.musicSource) return;
    const source = c.createBufferSource(); source.buffer = buffer; source.loop = true;
    source.connect(this.filter);
    const offset = this.musicOffset % buffer.duration;
    this.musicStartedAt = c.currentTime - offset;
    this.musicSource = source; source.start(c.currentTime, offset);
    source.onended = () => { source.disconnect(); if (this.musicSource === source) this.musicSource = null; };
    this.setLevel(this.level);
  }
  stop(immediate = true): void {
    this.active = false;
    const c = this.context;
    if (c && this.musicSource) {
      const duration = this.musicSource.buffer?.duration ?? 128;
      this.musicOffset = ((c.currentTime - this.musicStartedAt) % duration + duration) % duration;
      this.musicSource.stop(); this.musicSource = null;
    }
    if (immediate) {
      for (const source of this.voices.slice()) {
        try { source.stop(); } catch { /* already finished */ }
      }
      this.voices = [];
    }
  }
  dispose(): void {
    this.stop(); void this.context?.close();
    this.context = null; this.loading = null; this.buffers.clear();
  }
}
