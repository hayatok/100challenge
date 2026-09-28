import type { GameEvent } from './game.ts';

/** Presentation clock only; combat and typing never wait for these cues. */
export class FeverShow {
  active = false;
  hits = 0;
  phase: 'off' | 'enter' | 'run' | 'complete' | 'end' = 'off';
  remaining = 0;
  pulse = 0;
  revision = 0;

  event(event: GameEvent) {
    if (event.type === 'rushStart') {
      this.active = true;
      this.hits = 0;
      this.cue('enter', 1.25);
    } else if (event.type === 'kill' && this.active && !event.collateral) {
      this.hits = Math.min(4, this.hits + 1);
      this.pulse = .65;
      this.revision++;
    } else if (event.type === 'rushEnd') {
      this.active = false;
      this.cue(event.success ? 'complete' : 'end', event.success ? 2.5 : .7);
    } else if (event.type === 'clear' || event.type === 'defeat') this.reset();
  }

  private cue(phase: FeverShow['phase'], seconds: number) {
    this.phase = phase;
    this.remaining = seconds;
    this.pulse = .8;
    this.revision++;
  }

  update(dt: number) {
    const step = Number.isFinite(dt) ? Math.max(0, dt) : 0;
    this.pulse = Math.max(0, this.pulse - step);
    this.remaining = Math.max(0, this.remaining - step);
    if (this.remaining === 0) this.phase = this.active ? 'run' : 'off';
  }

  reset() {
    this.active = false;
    this.hits = 0;
    this.phase = 'off';
    this.remaining = this.pulse = 0;
    this.revision++;
  }
}
