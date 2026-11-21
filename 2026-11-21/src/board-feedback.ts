import { BOARD_HEIGHT, BOARD_WIDTH, type Impact } from './game.ts';
import './board-feedback.css';

/** Transient presentation only: never pauses or changes the simulation. */
export class BoardFeedback {
  private reducedMotion: boolean;
  private shake: Animation | null = null;
  private shakeStrength = 0;
  private counterPulse: Animation | null = null;
  private refillCounter: HTMLElement | null = null;
  private readonly expiry = new Map<HTMLElement, ReturnType<typeof setTimeout>>();

  constructor(private readonly board: HTMLElement, private readonly layer: HTMLElement, reducedMotion: boolean) {
    this.reducedMotion = reducedMotion;
    this.layer.setAttribute('aria-hidden', 'true');
  }

  hit(impact: Impact): void {
    if (this.reducedMotion) return;
    const points = document.createElement('span');
    points.className = 'point-pop';
    points.dataset.kind = impact.pin.kind;
    points.style.left = `${Math.max(7, Math.min(93, impact.pin.x / BOARD_WIDTH * 100))}%`;
    points.style.top = `${Math.max(21, impact.pin.y / BOARD_HEIGHT * 100)}%`;
    points.textContent = `+${impact.points}`;
    this.show(points, 500);

    if (impact.addedBalls > 0) {
      const extra = document.createElement('span');
      extra.className = 'extra-ball-pop';
      extra.dataset.kind = impact.pin.kind;
      extra.style.left = points.style.left;
      extra.style.top = `${Math.max(24, Math.min(87, impact.pin.y / BOARD_HEIGHT * 100 + 5))}%`;
      extra.textContent = `＋${impact.addedBalls}球`;
      this.show(extra, 720);
      this.shakeBoard(2.4, 180);
    }

    if (![5, 10, 20, 30].includes(impact.chain)) return;
    if (!this.layer.querySelector('.goal-pop')) {
      this.layer.querySelectorAll<HTMLElement>('.chain-pop').forEach((node) => this.remove(node));
      const chain = document.createElement('span');
      chain.className = 'chain-pop';
      chain.textContent = `${impact.chain} 連鎖`;
      this.show(chain, 700);
    }
    if (impact.chain >= 10) {
      this.shakeBoard(impact.chain >= 20 ? 4 : 3, 230);
      this.confetti(20);
    }
  }

  refill(count: number, counter: HTMLElement): void {
    if (this.reducedMotion) return;
    const previous = counter.nextElementSibling;
    if (previous instanceof HTMLElement && previous.matches('.refill-pop')) this.remove(previous);
    const notice = document.createElement('small');
    notice.className = 'refill-pop';
    notice.textContent = `＋${count}`;
    notice.setAttribute('aria-hidden', 'true');
    counter.after(notice);
    this.expiry.set(notice, setTimeout(() => this.remove(notice), 1000));

    this.clearCounterPulse();
    this.refillCounter = counter;
    counter.classList.add('stock-refill-active');
    const pulse = counter.animate([
      { transform: 'scale(1)', color: '#fff2d7', textShadow: '0 0 0 transparent' },
      { transform: 'scale(1.28)', color: '#d6ffd1', textShadow: '0 0 10px #bce7b8' },
      { transform: 'scale(1)', color: '#fff2d7', textShadow: '0 0 0 transparent' },
    ], { duration: 480, easing: 'ease-out' });
    this.counterPulse = pulse;
    pulse.onfinish = () => {
      if (this.counterPulse === pulse) this.clearCounterPulse();
    };
  }

  goal(): void {
    if (this.reducedMotion) return;
    this.shakeBoard(5, 300);
    this.confetti(34);
    this.layer.querySelectorAll<HTMLElement>('.chain-pop').forEach((node) => this.remove(node));
    const label = document.createElement('span');
    label.className = 'chain-pop goal-pop';
    label.textContent = 'ノルマ達成！';
    this.show(label, 950);
  }

  reset(): void {
    this.clearCounterPulse();
    this.shake?.cancel();
    this.shake = null;
    this.shakeStrength = 0;
    for (const [node, timer] of this.expiry) {
      clearTimeout(timer);
      node.remove();
    }
    this.expiry.clear();
  }

  setReducedMotion(value: boolean): void {
    this.reducedMotion = value;
    if (value) this.reset();
  }

  private clearCounterPulse(): void {
    this.counterPulse?.cancel();
    this.counterPulse = null;
    this.refillCounter?.classList.remove('stock-refill-active');
    this.refillCounter = null;
  }

  private remove(node: HTMLElement): void {
    const timer = this.expiry.get(node);
    if (timer !== undefined) clearTimeout(timer);
    this.expiry.delete(node);
    node.remove();
  }

  private show(node: HTMLElement, lifetime: number): void {
    // Keep rapid impacts from growing the DOM or covering the board in numbers.
    const isConfetti = node.classList.contains('confetti-piece');
    const selector = isConfetti ? '.confetti-piece' : ':scope > :not(.confetti-piece):not(.goal-pop)';
    const limit = isConfetti ? 40 : 12;
    const peers = this.layer.querySelectorAll<HTMLElement>(selector);
    for (let i = 0; i <= peers.length - limit; i++) this.remove(peers[i]);
    this.layer.append(node);
    this.expiry.set(node, setTimeout(() => this.remove(node), lifetime));
  }

  private shakeBoard(strength: number, duration: number): void {
    if (this.shake?.playState === 'running' && this.shakeStrength >= strength) return;
    this.shake?.cancel();
    this.shakeStrength = strength;
    // A short visual translation moves canvas and controls together. Pointer mapping uses the live board rect.
    this.shake = this.board.animate([
      { transform: 'translate(0, 0)' },
      { transform: `translate(${-strength}px, ${strength * 0.4}px)` },
      { transform: `translate(${strength * 0.8}px, ${-strength * 0.45}px)` },
      { transform: `translate(${-strength * 0.4}px, ${strength * 0.2}px)` },
      { transform: `translate(${strength * 0.16}px, 0)` },
      { transform: 'translate(0, 0)' },
    ], { duration, easing: 'ease-out' });
  }

  private confetti(count: number): void {
    const colors = ['#ffd776', '#82e1ff', '#f18e72', '#bce7b8', '#fff0cd'];
    for (let i = 0; i < count; i++) {
      const piece = document.createElement('i');
      piece.className = 'confetti-piece';
      const side = i % 2;
      const spread = (i * 0.61803398875) % 1;
      piece.style.left = `${side ? 94 : 6}%`;
      piece.style.top = `${42 + (i % 4) * 7}%`;
      piece.style.background = colors[i % colors.length];
      piece.style.setProperty('--burst-x', `${(side ? -1 : 1) * (38 + spread * 100)}px`);
      piece.style.setProperty('--burst-y', `${-24 - spread * 58}px`);
      piece.style.setProperty('--fall-y', `${28 + spread * 62}px`);
      piece.style.setProperty('--spin', `${(side ? -1 : 1) * (150 + spread * 270)}deg`);
      this.show(piece, 850);
    }
  }
}
