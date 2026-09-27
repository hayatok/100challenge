/** Original synthesized score and effects. No third-party audio samples. */
export class GameAudio {
  private context: AudioContext | null = null;
  private master!: GainNode;
  private music!: GainNode;
  private effects!: GainNode;
  private noise!: AudioBuffer;
  private timer: ReturnType<typeof setInterval> | null = null;
  private nextBeat = 0;
  private beat = 0;
  private level = 0;
  private active = false;
  private voices: AudioScheduledSourceNode[] = [];
  private lastShot = 0;
  muted = false;
  musicVolume = 0.45;
  effectsVolume = 0.75;

  async unlock(): Promise<boolean> {
    try {
      if (!this.context) {
        this.context = new AudioContext({ latencyHint: "interactive" });
        const c = this.context;
        this.master = c.createGain();
        this.master.gain.value = 0.72;
        const limiter = c.createDynamicsCompressor();
        limiter.threshold.value = -8;
        limiter.knee.value = 5;
        limiter.ratio.value = 10;
        limiter.attack.value = 0.003;
        limiter.release.value = 0.12;
        this.master.connect(limiter).connect(c.destination);
        this.music = c.createGain();
        this.music.connect(this.master);
        this.effects = c.createGain();
        this.effects.connect(this.master);
        this.noise = c.createBuffer(1, c.sampleRate * 2, c.sampleRate);
        const data = this.noise.getChannelData(0);
        let seed = 1979;
        for (let i = 0; i < data.length; i++) {
          seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
          data[i] = ((seed >>> 0) / 4294967295) * 2 - 1;
        }
        this.applyVolumes();
      }
      await this.context.resume();
      return this.context.state === "running";
    } catch {
      return false;
    }
  }

  private track(node: AudioScheduledSourceNode, cleanup: () => void) {
    this.voices.push(node);
    node.onended = () => {
      this.voices = this.voices.filter((n) => n !== node);
      node.disconnect();
      cleanup();
    };
    if (this.voices.length > 48) {
      try {
        this.voices.shift()?.stop();
      } catch {
        /* ended */
      }
    }
  }

  private tone(
    freq: number,
    when: number,
    duration: number,
    volume: number,
    type: OscillatorType,
    bus: AudioNode,
    endFreq?: number,
  ) {
    const c = this.context!;
    const osc = c.createOscillator();
    const gain = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, when);
    if (endFreq)
      osc.frequency.exponentialRampToValueAtTime(endFreq, when + duration);
    gain.gain.setValueAtTime(0, when);
    gain.gain.linearRampToValueAtTime(volume, when + 0.006);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + duration);
    osc.connect(gain).connect(bus);
    osc.start(when);
    osc.stop(when + duration + 0.02);
    this.track(osc, () => gain.disconnect());
  }

  private burst(
    when: number,
    duration: number,
    volume: number,
    frequency: number,
    bus: AudioNode,
    type: BiquadFilterType = "lowpass",
  ) {
    const c = this.context!;
    const source = c.createBufferSource();
    source.buffer = this.noise;
    const filter = c.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = frequency;
    const gain = c.createGain();
    gain.gain.setValueAtTime(volume, when);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + duration);
    source.connect(filter).connect(gain).connect(bus);
    source.start(when);
    source.stop(when + duration + 0.02);
    this.track(source, () => {
      filter.disconnect();
      gain.disconnect();
    });
  }

  shot(kill = false) {
    if (!this.context || this.context.state !== "running") return;
    const t = this.context.currentTime;
    const density = t - this.lastShot < 0.065 ? 0.45 : 1;
    this.lastShot = t;
    this.burst(t, 0.11, 0.6 * density, 6800, this.effects);
    this.tone(155, t, 0.15, 0.35 * density, "triangle", this.effects, 43);
    this.burst(t + 0.035, 0.17, 0.08, 1600, this.effects);
    this.tone(2300, t + 0.09, 0.03, 0.04, "sine", this.effects, 1700);
    if (kill) {
      this.tone(78, t, 0.34, 0.32, "sine", this.effects, 30);
      this.burst(t + 0.035, 0.32, 0.13, 900, this.effects);
    }
  }
  miss() {
    if (this.context)
      this.tone(
        135,
        this.context.currentTime,
        0.045,
        0.07,
        "triangle",
        this.effects,
        95,
      );
  }
  hurt() {
    if (!this.context) return;
    const t = this.context.currentTime;
    this.tone(62, t, 0.48, 0.4, "sawtooth", this.effects, 28);
    this.burst(t, 0.24, 0.25, 500, this.effects);
  }
  celebrate() {
    if (!this.context) return;
    const t = this.context.currentTime;
    [293.66, 349.23, 440, 587.33].forEach((f, i) =>
      this.tone(f, t + i * 0.07, 0.38, 0.09, "triangle", this.effects),
    );
  }
  setLevel(level: number) {
    this.level = Math.max(0, Math.min(4, Math.floor(level)));
  }
  setVolumes(music: number, effects: number, muted = this.muted) {
    this.musicVolume = music;
    this.effectsVolume = effects;
    this.muted = muted;
    this.applyVolumes();
  }
  private applyVolumes() {
    if (!this.context) return;
    this.music.gain.setTargetAtTime(
      this.muted ? 0 : this.musicVolume,
      this.context.currentTime,
      0.04,
    );
    this.effects.gain.setTargetAtTime(
      this.muted ? 0 : this.effectsVolume,
      this.context.currentTime,
      0.04,
    );
  }
  start() {
    if (!this.context || this.active) return;
    this.active = true;
    this.nextBeat = this.context.currentTime + 0.06;
    this.timer = setInterval(() => this.schedule(), 35);
  }
  stop(immediate = true) {
    this.active = false;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    if (!immediate) return;
    for (const voice of this.voices.slice()) {
      try {
        voice.stop();
      } catch {
        /* ended */
      }
    }
    this.voices = [];
  }
  private schedule() {
    if (!this.context || this.context.state !== "running" || !this.active)
      return;
    const c = this.context;
    const tick = 60 / 124 / 2;
    if (this.nextBeat < c.currentTime - 0.2)
      this.nextBeat = c.currentTime + 0.02;
    while (this.nextBeat < c.currentTime + 0.12) {
      const t = this.nextBeat;
      const b = this.beat % 32;
      const bass = [73.416, 73.416, 65.406, 69.296][Math.floor(b / 8)];
      if (b % 4 === 0) this.tone(110, t, 0.22, 0.25, "sine", this.music, 38);
      if (b % 4 === 2) this.burst(t, 0.105, 0.11, 3200, this.music, "highpass");
      if (b % 2 === 0)
        this.tone(
          bass * (b % 8 === 6 ? 1.5 : 1),
          t,
          0.35,
          0.18,
          "triangle",
          this.music,
        );
      if (this.level >= 1)
        this.burst(
          t,
          0.035,
          b % 2 ? 0.035 : 0.065,
          7600,
          this.music,
          "highpass",
        );
      if (this.level >= 2 && b % 4 === 1)
        [1, 1.2, 1.5].forEach((r) =>
          this.tone(bass * 4 * r, t, 0.22, 0.033, "triangle", this.music),
        );
      if (this.level >= 3 && b % 2 === 1) {
        const melody = [4, 4.8, 6, 5.333, 4.8, 4, 3, 3.6][
          Math.floor(b / 2) % 8
        ];
        this.tone(bass * melody, t, 0.17, 0.045, "sawtooth", this.music);
      }
      if (this.level >= 4 && b % 8 === 0)
        [2, 2.4, 3].forEach((r) =>
          this.tone(bass * r, t, 0.8, 0.055, "sine", this.music),
        );
      this.nextBeat += tick;
      this.beat++;
    }
  }
  dispose() {
    this.stop();
    void this.context?.close();
  }
}
