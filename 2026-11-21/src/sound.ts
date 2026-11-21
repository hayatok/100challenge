import type { Pin } from './game.ts';

const MASTER_LEVEL = 0.38;
const MAX_VOICES = 12;
const PIN_VOICE_LIMIT = 8;
const CHAIN_NOTES = [0, 2, 4, 7, 9, 12, 14, 16];

interface Tone {
  hz: number;
  endHz?: number;
  seconds: number;
  volume: number;
  delay?: number;
  wave?: OscillatorType;
}

export class GameSound {
  private enabled = true;
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private resumeAttempt = -Infinity;
  private pending: { tones: Tone[]; limit: number; requestedAt: number } | null = null;
  private readonly voices = new Set<OscillatorNode>();

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (!enabled) {
      this.pending = null;
      for (const voice of this.voices) voice.stop();
      this.voices.clear();
    }
    if (this.master) this.master.gain.value = enabled ? MASTER_LEVEL : 0;
  }

  activate(): void {
    if (!this.enabled) return;
    const AudioConstructor = window.AudioContext ?? (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    try {
      if (!this.context && AudioConstructor) {
        const context = new AudioConstructor();
        const master = context.createGain();
        master.gain.value = MASTER_LEVEL;
        master.connect(context.destination);
        this.context = context;
        this.master = master;
      }
      const context = this.context;
      const now = performance.now();
      if (!context || context.state === 'running' || now - this.resumeAttempt < 300) return;
      this.resumeAttempt = now;
      void context.resume().then(() => {
        const pending = this.pending;
        this.pending = null;
        if (pending && performance.now() - pending.requestedAt < 300) this.play(pending.tones, pending.limit);
      }).catch(() => { this.pending = null; });
    } catch {
      // The board remains playable when the browser has no usable audio device.
    }
  }

  launch(): void {
    this.play([
      { hz: 280, endHz: 435, seconds: 0.075, volume: 0.135, wave: 'triangle' },
      { hz: 155, endHz: 92, seconds: 0.052, volume: 0.10 },
    ]);
  }

  hit(kind: Pin['kind'], chain: number): void {
    const note = Math.min(Math.max(0, chain - 1), CHAIN_NOTES.length - 1);
    const hz = 329.63 * 2 ** (CHAIN_NOTES[note] / 12);
    if (kind === 'split') {
      this.play([
        { hz, seconds: 0.104, volume: 0.12, wave: 'triangle' },
        { hz: hz * 1.502, seconds: 0.104, volume: 0.097, delay: 0.035 },
      ], PIN_VOICE_LIMIT);
    } else if (kind === 'bonus') {
      this.play([
        { hz, seconds: 0.18, volume: 0.15 },
        { hz: hz * 1.26, seconds: 0.16, volume: 0.104, delay: 0.044 },
        { hz: hz * 2, seconds: 0.133, volume: 0.075, delay: 0.079 },
      ], PIN_VOICE_LIMIT);
    } else {
      this.play([
        { hz, endHz: hz * 0.98, seconds: 0.093, volume: 0.13, wave: 'triangle' },
      ], PIN_VOICE_LIMIT);
    }
  }

  clear(): void {
    this.play([
      { hz: 392, seconds: 0.18, volume: 0.15, wave: 'triangle' },
      { hz: 493.88, seconds: 0.19, volume: 0.145, wave: 'triangle', delay: 0.079 },
      { hz: 587.33, seconds: 0.22, volume: 0.14, wave: 'triangle', delay: 0.158 },
      { hz: 783.99, seconds: 0.36, volume: 0.15, delay: 0.248 },
    ]);
  }

  fail(): void {
    this.play([
      { hz: 246.94, seconds: 0.17, volume: 0.13, wave: 'triangle' },
      { hz: 196, seconds: 0.27, volume: 0.14, delay: 0.126 },
    ]);
  }

  private play(tones: Tone[], limit = MAX_VOICES) {
    const { context, master } = this;
    if (!this.enabled || !context || !master) return;
    if (context.state !== 'running') {
      const requestedAt = performance.now();
      if (requestedAt - this.resumeAttempt < 300) this.pending = { tones, limit, requestedAt };
      return;
    }

    const baseTime = context.currentTime + 0.008;
    for (const tone of tones) {
      if (this.voices.size >= limit) break;
      const start = baseTime + (tone.delay ?? 0);
      const end = start + tone.seconds;
      const oscillator = context.createOscillator();
      const envelope = context.createGain();
      oscillator.type = tone.wave ?? 'sine';
      oscillator.frequency.setValueAtTime(tone.hz, start);
      if (tone.endHz !== undefined) oscillator.frequency.exponentialRampToValueAtTime(tone.endHz, end);
      envelope.gain.setValueAtTime(0.0001, start);
      envelope.gain.exponentialRampToValueAtTime(tone.volume, start + 0.008);
      envelope.gain.exponentialRampToValueAtTime(0.0001, end);
      oscillator.connect(envelope);
      envelope.connect(master);
      this.voices.add(oscillator);
      oscillator.onended = () => {
        oscillator.disconnect();
        envelope.disconnect();
        this.voices.delete(oscillator);
      };
      oscillator.start(start);
      oscillator.stop(end);
    }
  }
}
