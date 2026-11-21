export const BOARD_WIDTH = 680;
export const BOARD_HEIGHT = 520;
export const BONUS_OUTLETS = [67, 340, 613] as const;
export const DROP_Y = 44;
export const PIN_RADIUS = 12;
export const BALL_RADIUS = 8;
export const BALLS_PER_STAGE = 3;
export const FIRST_BOARD_SEED = 20261323;
export const DEFAULT_DROP_X = 249;
export const STEP = 1 / 120;

const WALL = 21;
export const MIN_DROP_X = WALL + BALL_RADIUS;
export const MAX_DROP_X = BOARD_WIDTH - MIN_DROP_X;
const GOALS = [85, 155] as const;
const GRAVITY = 640;
const CONTACT_RADIUS = BALL_RADIUS + PIN_RADIUS;

export type PinKind = 'normal' | 'split' | 'bonus';
export type Upgrade = 'split' | 'bonus';
export type Phase = 'ready' | 'dropping' | 'upgrade' | 'clear' | 'failed';
export type Stage = 1 | 2;
export type Pin = { id: number; x: number; y: number; kind: PinKind; alive: boolean };
export type Ball = { id: number; x: number; y: number; vx: number; vy: number; age: number };
export type Impact = { pin: Pin; chain: number; points: number };

type Spawn = Omit<Ball, 'id' | 'age'> & { delay: number };
type PinRow = { y: number; x: readonly number[]; split?: readonly number[]; bonus?: readonly number[] };

const BOARDS: Record<Stage, readonly PinRow[]> = {
  1: [
    { y: 108, x: [67, 158, 249, 340, 431, 522, 613], split: [2], bonus: [5] },
    { y: 166, x: [110, 200, 289, 383, 469, 565], split: [1], bonus: [4] },
    { y: 226, x: [62, 151, 241, 335, 426, 519, 620], split: [3, 6] },
    { y: 286, x: [107, 198, 288, 380, 475, 564], bonus: [0, 3] },
    { y: 349, x: [72, 157, 248, 342, 425, 520, 607], split: [2, 5] },
    { y: 415, x: [113, 202, 293, 386, 472, 564], bonus: [4] },
    { y: 469, x: [68, 157, 252, 338, 428, 526, 616] },
  ],
  2: [
    { y: 99, x: [67, 158, 249, 340, 431, 522, 613], split: [1], bonus: [5] },
    { y: 155, x: [100, 190, 275, 370, 460, 560], split: [0, 2], bonus: [4] },
    { y: 213, x: [64, 145, 228, 320, 410, 509, 613], split: [2], bonus: [5, 6] },
    { y: 272, x: [107, 188, 269, 363, 453, 555], split: [1], bonus: [4] },
    { y: 332, x: [66, 148, 234, 321, 414, 507, 607], split: [0, 3], bonus: [6] },
    { y: 394, x: [107, 188, 275, 364, 458, 555], split: [2], bonus: [5] },
    { y: 463, x: [65, 152, 239, 329, 421, 517, 615] },
  ],
};

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
    return { id: rowIndex * 7 + columnIndex, x: mirrored ? BOARD_WIDTH - x : x, y, kind, alive: true };
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
  shotsUsed = 0;
  stageScore = 0;
  totalScore = 0;
  chain = 0;
  bestChain = 0;
  pins: Pin[];
  balls: Ball[] = [];

  private random: () => number;
  private pending: Spawn[] = [];
  private nextId = 0;
  private settleTime = 0;

  constructor(seed: number) {
    this.seed = seed >>> 0;
    this.pins = buildBoard(this.seed, this.stage);
    this.random = randomSource(this.seed ^ 0xa5b729f1);
  }

  get goal() { return GOALS[this.stage - 1]; }
  get remaining() { return BALLS_PER_STAGE - this.shotsUsed; }

  drop(x: number) {
    if (this.phase !== 'ready' || this.remaining === 0 || !Number.isFinite(x)) return false;
    this.shotsUsed++;
    this.chain = 0;
    this.settleTime = 0;
    this.phase = 'dropping';
    this.addBall({ x: clampDropX(x), y: DROP_Y, vx: 0, vy: 45 });
    return true;
  }

  chooseUpgrade(upgrade: Upgrade) {
    if (this.phase !== 'upgrade') return false;
    this.upgrade = upgrade;
    this.stage = 2;
    this.phase = 'ready';
    this.shotsUsed = 0;
    this.stageScore = 0;
    this.chain = 0;
    this.pins = buildBoard(this.seed, this.stage);
    // Stage 2 starts from the same random sequence for either upgrade.
    this.random = randomSource(this.seed ^ 0xfb387dcc);
    return true;
  }

  step(delta: number): Impact[] {
    if (this.phase !== 'dropping') return [];
    const impacts: Impact[] = [];

    for (const spawn of this.pending) {
      spawn.delay -= delta;
      if (spawn.delay <= 0) this.addBall(spawn);
    }
    this.pending = this.pending.filter((spawn) => spawn.delay > 0);

    for (const ball of this.balls) {
      ball.age += delta;
      ball.vy = Math.min(650, ball.vy + GRAVITY * delta);
      ball.x += ball.vx * delta;
      ball.y += ball.vy * delta;
      if (ball.x < MIN_DROP_X || ball.x > MAX_DROP_X) {
        ball.x = Math.max(MIN_DROP_X, Math.min(MAX_DROP_X, ball.x));
        ball.vx *= -0.8;
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
      if (this.settleTime >= 0.4) this.finishShot();
    }
    return impacts;
  }

  private addBall(ball: Omit<Ball, 'id' | 'age'>) {
    const { x, y, vx, vy } = ball;
    this.balls.push({ id: this.nextId++, x, y, vx, vy, age: 0 });
  }

  private hit(ball: Ball, pin: Pin, dx: number, dy: number, distance: number, impacts: Impact[]) {
    pin.alive = false;
    this.chain++;
    this.stageScore += this.chain;
    this.totalScore += this.chain;
    this.bestChain = Math.max(this.bestChain, this.chain);
    impacts.push({ pin, chain: this.chain, points: this.chain });

    const nx = distance > 0 ? dx / distance : 0;
    const ny = distance > 0 ? dy / distance : -1;
    const bounce = Math.min(0, ball.vx * nx + ball.vy * ny) * 1.46;
    const kick = dx !== 0 ? Math.sign(dx) : pin.id % 2 === 0 ? 1 : -1;
    ball.vx = Math.max(-265, Math.min(265, ball.vx - bounce * nx + kick * 43));
    ball.vy = Math.max(-145, ball.vy - bounce * ny);

    if (pin.kind === 'split') {
      const offsets = this.upgrade === 'split' ? [-1, 1] : [-kick];
      for (const side of offsets) {
        this.pending.push({ delay: 0.035, x: pin.x + side * 9, y: pin.y + 6, vx: side * 138, vy: 90 });
      }
    }
    if (pin.kind === 'bonus') {
      const outlets = this.upgrade === 'bonus' ? [BONUS_OUTLETS[0], BONUS_OUTLETS[2]] : [BONUS_OUTLETS[Math.floor(this.random() * BONUS_OUTLETS.length)]];
      for (const x of outlets) {
        this.pending.push({ delay: 0.19, x, y: DROP_Y, vx: 0, vy: 55 });
      }
    }
  }

  private finishShot() {
    if (this.remaining > 0) this.phase = 'ready';
    else if (this.stageScore < this.goal) this.phase = 'failed';
    else this.phase = this.stage === 1 ? 'upgrade' : 'clear';
  }
}
