export const BOARD_WIDTH = 680;
export const BOARD_HEIGHT = 520;
export const BONUS_OUTLETS = [67, 340, 613] as const;
export const DROP_Y = 44;
export const PIN_RADIUS = 12;
export const BALL_RADIUS = 8;
export const BALLS_PER_STAGE = 3;
export const REFILL_CHAIN = 6;
export const FIRST_BOARD_SEED = 20261323;
export const STEP = 1 / 120;

const WALL = 21;
export const MIN_DROP_X = WALL + BALL_RADIUS;
export const MAX_DROP_X = BOARD_WIDTH - MIN_DROP_X;
const GOALS = [85, 155] as const;
const GRAVITY = 640;
const CONTACT_RADIUS = BALL_RADIUS + PIN_RADIUS;

export type Kicker = { x: number; y: number; width: number; direction: 1 | -1 };

export type PinKind = 'normal' | 'split' | 'bonus';
export type Upgrade = 'split' | 'bonus';
export type Phase = 'ready' | 'dropping' | 'upgrade' | 'clear' | 'failed';
export type Stage = 1 | 2;
export type Pin = { id: number; x: number; y: number; kind: PinKind; alive: boolean };
export type Ball = { id: number; x: number; y: number; vx: number; vy: number; age: number; origin: 'drop' | 'split' | 'bonus'; shotId: number };
export type Impact = { pin: Pin; chain: number; points: number; addedBalls: number; shotId: number; earnedBall: boolean };

type Spawn = Omit<Ball, 'id' | 'age'> & { delay: number };
type PinRow = { y: number; x: readonly number[]; split?: readonly number[]; bonus?: readonly number[] };

// Deliberate islands leave open approaches and send kicked balls into deposits.
const BOARDS: Record<Stage, readonly PinRow[]> = {
  1: [
    { y: 100, x: [365, 415, 555], split: [0], bonus: [2] },
    { y: 185, x: [265, 310, 355, 530, 580], split: [1], bonus: [4] },
    { y: 225, x: [290, 340, 390, 505, 555, 605], split: [0, 4], bonus: [2] },
    { y: 280, x: [95, 140, 185, 360, 405, 450], split: [1, 3], bonus: [5] },
    { y: 330, x: [70, 120, 170, 310, 360, 410, 555], bonus: [1, 5] },
    { y: 390, x: [155, 200, 245, 460, 505, 550], split: [1, 4] },
    { y: 455, x: [70, 115, 280, 325, 370, 535, 580, 625], bonus: [3] },
  ],
  2: [
    { y: 97, x: [285, 335, 385, 570, 620], split: [0, 2], bonus: [3] },
    { y: 175, x: [235, 280, 325, 370, 595], split: [1], bonus: [3] },
    { y: 225, x: [80, 125, 170, 260, 305, 350], bonus: [1], split: [4] },
    { y: 300, x: [105, 150, 195, 400, 445, 490], split: [1, 3], bonus: [5] },
    { y: 345, x: [75, 120, 165, 350, 395, 440, 485, 530], split: [3], bonus: [1, 6] },
    { y: 410, x: [210, 255, 300, 345, 515, 560, 605], split: [1, 5], bonus: [3] },
    { y: 465, x: [70, 115, 160, 300, 345, 390, 435, 590], bonus: [4] },
  ],
};
const KICKERS: Record<Stage, readonly Kicker[]> = {
  1: [{ x: 160, y: 145, width: 110, direction: 1 }],
  2: [{ x: 140, y: 140, width: 110, direction: 1 }, { x: 520, y: 260, width: 110, direction: -1 }],
};
// Stage 1 introduces the long kick. Stage 2 opens on the lower route so both approaches matter.
const OPENING_AIM: Record<Stage, number> = { 1: 160, 2: 540 };

function isMirrored(seed: number, stage: Stage) {
  return randomSource(seed ^ Math.imul(stage, 0x9e3779b9))() < 0.5;
}
function buildKickers(seed: number, stage: Stage): Kicker[] {
  return KICKERS[stage].map((kicker) => isMirrored(seed, stage)
    ? { ...kicker, x: BOARD_WIDTH - kicker.x, direction: kicker.direction === 1 ? -1 : 1 }
    : { ...kicker });
}

function randomSource(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function buildBoard(seed: number, stage: Stage): Pin[] {
  const random = randomSource(seed ^ (Math.imul(stage, 0x9e3779b9)));
  const mirrored = random() < 0.5;
  return BOARDS[stage].flatMap((row, rowIndex) => row.x.map((columnX, columnIndex) => {
    const x = columnX + Math.round((random() - 0.5) * 18);
    const y = row.y + Math.round((random() - 0.5) * 10);
    const kind = row.split?.includes(columnIndex) ? 'split' : row.bonus?.includes(columnIndex) ? 'bonus' : 'normal';
    return { id: rowIndex * 10 + columnIndex, x: mirrored ? BOARD_WIDTH - x : x, y, kind, alive: true };
  }));
}

export function clampDropX(x: number) {
  return Math.round(Math.max(MIN_DROP_X, Math.min(MAX_DROP_X, x)));
}

export class PinboardRun {
  readonly seed: number;
  stage: Stage = 1;
  phase: Phase = 'ready';
  upgrade: Upgrade | null = null;
  stageScore = 0;
  totalScore = 0;
  bestChain = 0;
  pins: Pin[];
  kickers: Kicker[];
  balls: Ball[] = [];

  private random: () => number;
  private reserve = BALLS_PER_STAGE;
  private shotChains: number[] = [];
  private pending: Spawn[] = [];
  private nextId = 0;
  private settleTime = 0;

  constructor(seed: number) {
    this.seed = seed >>> 0;
    this.pins = buildBoard(this.seed, this.stage);
    this.kickers = buildKickers(this.seed, this.stage);
    this.random = randomSource(this.seed ^ 0xa5b729f1);
  }

  get goal() { return GOALS[this.stage - 1]; }
  get openingAim() {
    const x = OPENING_AIM[this.stage];
    return isMirrored(this.seed, this.stage) ? BOARD_WIDTH - x : x;
  }
  get remaining() { return this.reserve; }
  get shotsUsed() { return this.shotChains.length; }
  get chain() { return Math.max(0, ...this.shotChains); }
  get hasPins() { return this.pins.some((pin) => pin.alive); }
  get canDrop() {
    return this.remaining > 0 && (this.phase === 'ready' || this.phase === 'dropping') && this.hasPins;
  }

  drop(x: number) {
    if (!this.canDrop || !Number.isFinite(x)) return false;
    this.reserve--;
    this.shotChains.push(0);
    this.settleTime = 0;
    this.phase = 'dropping';
    this.addBall({ x: clampDropX(x), y: DROP_Y, vx: 0, vy: 45, origin: 'drop', shotId: this.shotsUsed });
    return true;
  }

  chooseUpgrade(upgrade: Upgrade) {
    if (this.phase !== 'upgrade') return false;
    this.upgrade = upgrade;
    this.stage = 2;
    this.phase = 'ready';
    this.reserve = BALLS_PER_STAGE;
    this.stageScore = 0;
    this.shotChains = [];
    this.pins = buildBoard(this.seed, this.stage);
    this.kickers = buildKickers(this.seed, this.stage);
    // Stage 2 starts from the same random sequence for either upgrade.
    this.random = randomSource(this.seed ^ 0xfb387dcc);
    return true;
  }

  step(delta: number, onKick?: (kicker: Kicker, x: number) => void): Impact[] {
    if (this.phase !== 'dropping') return [];
    const impacts: Impact[] = [];

    for (const spawn of this.pending) {
      spawn.delay -= delta;
      if (spawn.delay <= 0) this.addBall(spawn);
    }
    this.pending = this.pending.filter((spawn) => spawn.delay > 0);

    for (const ball of this.balls) {
      const previousX = ball.x;
      const previousY = ball.y;
      ball.age += delta;
      ball.vy = Math.min(650, ball.vy + GRAVITY * delta);
      ball.x += ball.vx * delta;
      ball.y += ball.vy * delta;
      if (ball.x < MIN_DROP_X || ball.x > MAX_DROP_X) {
        ball.x = Math.max(MIN_DROP_X, Math.min(MAX_DROP_X, ball.x));
        ball.vx *= -0.8;
      }

      if (ball.vy > 0) {
        for (const kicker of this.kickers) {
          const contactY = kicker.y - BALL_RADIUS;
          if (previousY >= contactY || ball.y < contactY) continue;
          const fraction = (contactY - previousY) / (ball.y - previousY);
          const contactX = previousX + (ball.x - previousX) * fraction;
          if (Math.abs(contactX - kicker.x) > kicker.width / 2) continue;
          ball.x = contactX;
          ball.y = contactY;
          ball.vx = kicker.direction * 340;
          ball.vy = -95;
          onKick?.(kicker, contactX);
          break;
        }
      }

      for (const pin of this.pins) {
        if (!pin.alive) continue;
        const dx = ball.x - pin.x;
        const dy = ball.y - pin.y;
        const distance = Math.hypot(dx, dy);
        if (distance >= CONTACT_RADIUS) continue;
        this.hit(ball, pin, dx, dy, distance, impacts);
        break;
      }
    }

    this.balls = this.balls.filter((ball) => ball.y < BOARD_HEIGHT + BALL_RADIUS && ball.age < 6);
    if (this.balls.length === 0 && this.pending.length === 0) {
      this.settleTime += delta;
      if (this.settleTime >= 0.4) this.finishDropSequence();
    }
    return impacts;
  }

  private addBall(ball: Omit<Ball, 'id' | 'age'>) {
    const { x, y, vx, vy, origin, shotId } = ball;
    this.balls.push({ id: this.nextId++, x, y, vx, vy, origin, shotId, age: 0 });
  }

  private hit(ball: Ball, pin: Pin, dx: number, dy: number, distance: number, impacts: Impact[]) {
    pin.alive = false;
    const shotId = ball.shotId;
    const chain = ++this.shotChains[shotId - 1];
    const earnedBall = chain % REFILL_CHAIN === 0;
    if (earnedBall) this.reserve++;
    this.stageScore += chain;
    this.totalScore += chain;
    this.bestChain = Math.max(this.bestChain, chain);

    const nx = distance > 0 ? dx / distance : 0;
    const ny = distance > 0 ? dy / distance : -1;
    const bounce = Math.min(0, ball.vx * nx + ball.vy * ny) * 1.46;
    const kick = dx !== 0 ? Math.sign(dx) : pin.id % 2 === 0 ? 1 : -1;
    ball.vx = Math.max(-265, Math.min(265, ball.vx - bounce * nx + kick * 43));
    ball.vy = Math.max(-145, ball.vy - bounce * ny);

    let addedBalls = 0;
    if (pin.kind === 'split') {
      const offsets = this.upgrade === 'split' ? [-1, 1] : [-kick];
      addedBalls = offsets.length;
      for (const side of offsets) {
        this.pending.push({ delay: 0.035, x: pin.x + side * 9, y: pin.y + 6, vx: side * 138, vy: 90, origin: 'split', shotId });
      }
    }
    if (pin.kind === 'bonus') {
      const outlets = this.upgrade === 'bonus' ? [BONUS_OUTLETS[0], BONUS_OUTLETS[2]] : [BONUS_OUTLETS[Math.floor(this.random() * BONUS_OUTLETS.length)]];
      addedBalls = outlets.length;
      for (const x of outlets) {
        this.pending.push({ delay: 0.19, x, y: DROP_Y, vx: 0, vy: 55, origin: 'bonus', shotId });
      }
    }
    impacts.push({ pin, chain, points: chain, addedBalls, shotId, earnedBall });
  }

  private finishDropSequence() {
    if (this.canDrop) this.phase = 'ready';
    else if (this.stageScore < this.goal) this.phase = 'failed';
    else this.phase = this.stage === 1 ? 'upgrade' : 'clear';
  }
}
