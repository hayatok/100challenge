import { BOSS_PHRASES, OFFICE_PHRASES, PHRASES, RUNNER_PHRASES, WORKER_PHRASES, type Phrase } from './content.ts';
import { TypingSession } from './typing.ts';

export type Difficulty = 'relaxed' | 'normal' | 'fierce';
export type EnemyKind = 'office' | 'runner' | 'worker' | 'boss';
export type GameMode = 'playing' | 'travel' | 'paused' | 'countdown' | 'defeat' | 'clear';
export type GameOptions = { difficulty?: Difficulty; practice?: boolean; seed?: number };
export type GameEvent = {
  id: number; type: 'spawn'|'lock'|'hit'|'miss'|'kill'|'attack'|'travel'|'stage'|'bossPhase'|'pause'|'resume'|'defeat'|'clear';
  enemyId?: number; kind?: EnemyKind; stage?: number; phase?: number; key?: string; reason?: string;
  combo?: number; clean?: boolean; scoreDelta?: number; effectsLevel?: number;
};
export type EnemyView = {
  id: number; kind: EnemyKind; lane: -1|0|1; progress: number; remaining: number;
  phrase: string; reading: string; typed: string; guide: string; keys: string[];
  typingProgress: number; telegraph: boolean; locked: boolean;
};
export type GameResults = {
  score: number; maxCombo: number; accuracy: number; correct: number; mistakes: number;
  clearTime: number; keysPerMinute: number; attempts: number; practice: boolean; difficulty: Difficulty;
};
export type GameState = {
  mode: GameMode; stage: number; bossPhase: number; health: number; score: number;
  combo: number; maxCombo: number; effectsLevel: number; visualCombo: number;
  lockedId: number|null; enemies: EnemyView[]; practice: boolean; difficulty: Difficulty;
  countdown: number; results: GameResults|null; attempts: number;
};

type Enemy = {
  id: number; kind: EnemyKind; lane: -1|0|1; phrase: Phrase; typing: TypingSession;
  spawned: number; deadline: number; clean: boolean;
};
type Checkpoint = { score:number; maxCombo:number; correct:number; mistakes:number; battleTime:number; used:Set<number>; elapsed:number };
const CPS: Record<Difficulty, number> = { relaxed:2, normal:3.5, fierce:5 };
const STAGE_WAVES: readonly (readonly (readonly EnemyKind[])[])[] = [
  [['office'],['office'],['office'],['runner'],['office'],['worker']],
  [['office','runner'],['runner','worker'],['office','worker'],['runner','office']],
  [['runner','office'],['worker','runner'],['runner','office','worker'],['office','runner','worker']],
];
const LEVELS = [3,6,10,15];
const effectLevel = (combo: number): number => LEVELS.filter(level => combo >= level).length;

export class Game {
  readonly difficulty: Difficulty;
  readonly practice: boolean;
  readonly seed: number;
  private modeValue: GameMode = 'playing';
  private beforePause: GameMode = 'playing';
  private time = 0;
  private elapsed = 0;
  private battleTime = 0;
  private countdown = 0;
  private travelTime = 0;
  private stageValue = 0;
  private wave = 0;
  private phase = 0;
  private bossFailures = 0;
  private healthValue = 3;
  private scoreValue = 0;
  private comboValue = 0;
  private maxComboValue = 0;
  private visualComboValue = 0;
  private effectsLevelValue = 0;
  private decayFirstAt: number|null = null;
  private decayNextAt: number|null = null;
  private correct = 0;
  private mistakes = 0;
  private attemptsValue = 1;
  private locked: number|null = null;
  private enemiesValue: Enemy[] = [];
  private used = new Set<number>();
  private checkpoint: Checkpoint = {score:0,maxCombo:0,correct:0,mistakes:0,battleTime:0,elapsed:0,used:new Set()};
  private events: GameEvent[] = [];
  private nextEventId = 1;
  private nextEnemyId = 1;
  private finalResults: GameResults|null = null;

  constructor(options: GameOptions = {}) {
    this.difficulty = options.difficulty ?? 'normal';
    if (!(this.difficulty in CPS)) throw new Error('Invalid difficulty');
    this.practice = options.practice ?? false;
    this.seed = options.seed ?? 1;
    this.spawnWave();
  }

  private emit(type: GameEvent['type'], data: Omit<GameEvent,'id'|'type'> = {}): void {
    this.events.push({id:this.nextEventId++, type, ...data});
  }
  drainEvents(): GameEvent[] { return this.events.splice(0); }

  private phraseOrder(kind: Exclude<EnemyKind,'boss'>): number[] {
    const start = kind === 'runner' ? 0 : kind === 'office' ? RUNNER_PHRASES.length : RUNNER_PHRASES.length + OFFICE_PHRASES.length;
    const count = kind === 'runner' ? RUNNER_PHRASES.length : kind === 'office' ? OFFICE_PHRASES.length : WORKER_PHRASES.length;
    return Array.from({length:count},(_,index) => start + index).sort((a,b) => {
      const hash = (n:number) => { let x = (n+1) ^ this.seed; x = Math.imul(x ^ (x>>>16), 0x7feb352d); x = Math.imul(x ^ (x>>>15), 0x846ca68b); return (x^(x>>>16))>>>0; };
      return hash(a)-hash(b);
    });
  }

  private pickPhrase(kind: Exclude<EnemyKind,'boss'>, occupied: Set<string>): Phrase {
    const order = this.phraseOrder(kind);
    for (const allowUsed of [false,true]) for (const index of order) {
      if (!allowUsed && this.used.has(index)) continue;
      const phrase = PHRASES[index];
      const keys = new TypingSession(phrase.reading).keys;
      if (keys.some(key => occupied.has(key))) continue;
      keys.forEach(key => occupied.add(key));
      this.used.add(index);
      return phrase;
    }
    throw new Error('No distinct initial-key phrase for this wave');
  }

  private spawnWave(): void {
    if (this.stageValue === 3) { this.spawnBoss(); return; }
    const kinds = STAGE_WAVES[this.stageValue]?.[this.wave];
    if (!kinds) throw new Error('Invalid wave');
    const occupied = new Set<string>();
    const sorted = [...kinds].sort((a,b) => ({runner:0,office:1,worker:2,boss:3})[a]-({runner:0,office:1,worker:2,boss:3})[b]);
    let workload = 0;
    this.enemiesValue = sorted.map((kind,index) => {
      const phrase = this.pickPhrase(kind as Exclude<EnemyKind,'boss'>, occupied);
      const typing = new TypingSession(phrase.reading);
      const length = typing.standardLength;
      workload += length / CPS[this.difficulty];
      // Cumulative work leaves at least one feasible order for every wave.
      const base = kind === 'runner' ? 1.0 : kind === 'worker' ? 1.6 : 1.3;
      const deadline = this.time + base + workload * 1.6 + index * 0.5;
      const lane = (sorted.length === 1 ? 0 : [-1,1,0][index]) as -1|0|1;
      const enemy: Enemy = {id:this.nextEnemyId++,kind,lane,phrase,typing,spawned:this.time,deadline,clean:true};
      this.emit('spawn',{enemyId:enemy.id,kind,stage:this.stageValue});
      return enemy;
    });
  }

  private spawnBoss(): void {
    const phrase = BOSS_PHRASES[this.phase * 4 + ((this.seed >>> 0) + this.bossFailures) % 4];
    const typing = new TypingSession(phrase.reading);
    const deadline = this.time + 1.2 + typing.standardLength / CPS[this.difficulty] * 1.6;
    const enemy: Enemy = {id:this.nextEnemyId++,kind:'boss',lane:0,phrase,typing,spawned:this.time,deadline,clean:true};
    this.enemiesValue = [enemy];
    this.emit('spawn',{enemyId:enemy.id,kind:'boss',stage:3,phase:this.phase});
  }

  private beginTravel(seconds: number): void {
    this.modeValue = 'travel';
    this.travelTime = seconds;
    this.emit('travel',{stage:this.stageValue});
  }

  private waveFinished(): void {
    this.locked = null;
    if (this.stageValue === 3) {
      if (this.phase >= 3) { this.finish('clear'); return; }
      this.beginTravel(0.7);
      return;
    }
    this.wave++;
    if (this.wave >= STAGE_WAVES[this.stageValue].length) {
      this.stageValue++;
      this.wave = 0;
      this.checkpoint = {score:this.scoreValue,maxCombo:this.maxComboValue,correct:this.correct,mistakes:this.mistakes,battleTime:this.battleTime,elapsed:this.elapsed,used:new Set(this.used)};
      this.emit('stage',{stage:this.stageValue});
      this.beginTravel(1);
    } else this.beginTravel(0.6);
  }

  private finish(mode: 'clear'|'defeat'): void {
    this.modeValue = mode;
    this.finalResults = {
      score:this.scoreValue,maxCombo:this.maxComboValue,
      accuracy:this.correct+this.mistakes ? this.correct/(this.correct+this.mistakes) : 1,
      correct:this.correct,mistakes:this.mistakes,clearTime:this.elapsed,
      keysPerMinute:this.battleTime ? this.correct*60/this.battleTime : 0,
      attempts:this.attemptsValue,practice:this.practice,difficulty:this.difficulty,
    };
    this.emit(mode,{stage:this.stageValue});
  }

  private breakCombo(): void {
    if (this.comboValue > 0 && this.effectsLevelValue > 0 && this.decayNextAt === null) {
      this.decayFirstAt = this.time + 1.5;
      this.decayNextAt = this.decayFirstAt;
    }
    this.comboValue = 0;
  }

  private updateEffects(dt: number): void {
    const required = effectLevel(this.comboValue);
    while (this.decayNextAt !== null && this.time + 1e-9 >= this.decayNextAt && this.effectsLevelValue > required) {
      this.effectsLevelValue--;
      this.decayNextAt += 0.8;
    }
    if (this.effectsLevelValue <= required) {
      this.effectsLevelValue = required;
      this.decayFirstAt = null;
      this.decayNextAt = null;
    }
    if (this.decayFirstAt === null || this.time + 1e-9 >= this.decayFirstAt) {
      const stagedCombo = this.decayNextAt === null ? this.comboValue
        : this.effectsLevelValue === 4 ? 15
        : this.effectsLevelValue > 0 ? LEVELS[this.effectsLevelValue]-1 : 0;
      this.visualComboValue += (Math.max(this.comboValue,stagedCombo)-this.visualComboValue) * (1-Math.exp(-dt*5));
    }
  }

  /** Advances active combat time. The caller pauses on focus or visibility loss. */
  update(dt: number): void {
    if (!Number.isFinite(dt) || dt < 0) throw new Error('dt must be nonnegative seconds');
    if (this.modeValue === 'paused' || this.modeValue === 'clear' || this.modeValue === 'defeat') return;
    if (this.modeValue === 'countdown') {
      this.countdown -= dt;
      if (this.countdown <= 1e-9) {
        const surplus = Math.max(0,-this.countdown);
        this.countdown = 0;
        this.modeValue = this.beforePause;
        this.emit('resume');
        if (surplus) this.update(surplus);
      }
      return;
    }
    if (this.modeValue === 'travel') {
      this.travelTime -= dt;
      if (this.travelTime <= 1e-9) {
        const surplus = Math.max(0,-this.travelTime);
        this.travelTime = 0;
        this.modeValue = 'playing';
        this.spawnWave();
        if (surplus) this.update(surplus);
      }
      return;
    }
    this.time += dt;
    this.elapsed += dt;
    this.battleTime += dt;
    this.updateEffects(dt);
    if (this.practice) return;
    for (const enemy of [...this.enemiesValue].sort((a,b) => a.id-b.id)) {
      // At the exact deadline an arriving final key wins the tie.
      if (this.time <= enemy.deadline) continue;
      this.enemiesValue = this.enemiesValue.filter(item => item.id !== enemy.id);
      this.emit('attack',{enemyId:enemy.id,kind:enemy.kind,combo:0});
      this.healthValue--;
      this.breakCombo();
      if (this.locked === enemy.id) this.locked = null;
      else if (this.locked !== null) {
        const target = this.enemiesValue.find(item => item.id === this.locked);
        if (target) target.clean = false;
      }
      if (this.healthValue <= 0) { this.finish('defeat'); return; }
      if (enemy.kind === 'boss') {
        this.bossFailures++;
        this.beginTravel(0.5);
        return;
      }
    }
    if (!this.enemiesValue.length) this.waveFinished();
  }

  /** A single KeyboardEvent.key character. UI filters repeat, IME and shortcuts. */
  type(key: string): boolean {
    if (this.modeValue !== 'playing' || !/^[a-z'-]$/i.test(key)) return false;
    // If time passed a deadline, resolve attacks before assigning this key.
    if (!this.practice && this.enemiesValue.some(enemy => this.time > enemy.deadline)) this.update(0);
    if (this.modeValue !== 'playing' || !this.enemiesValue.length) return false;
    const normalized = key.toLowerCase();
    let enemy = this.enemiesValue.find(item => item.id === this.locked);
    if (!enemy) enemy = this.enemiesValue.find(item => item.typing.keys.includes(normalized));
    if (!enemy || !enemy.typing.type(normalized)) {
      this.mistakes++;
      this.breakCombo();
      const locked = this.enemiesValue.find(item => item.id === this.locked);
      if (locked) locked.clean = false;
      this.emit('miss',{key:normalized,enemyId:locked?.id,combo:0});
      return false;
    }
    if (this.locked === null) {
      this.locked = enemy.id;
      this.emit('lock',{enemyId:enemy.id,kind:enemy.kind,combo:this.comboValue,effectsLevel:this.effectsLevelValue});
    }
    this.correct++;
    this.emit('hit',{enemyId:enemy.id,kind:enemy.kind,key:normalized,combo:this.comboValue,effectsLevel:this.effectsLevelValue});
    if (enemy.typing.complete) {
      this.enemiesValue = this.enemiesValue.filter(item => item.id !== enemy.id);
      this.locked = null;
      if (enemy.clean) {
        this.comboValue++;
        this.maxComboValue = Math.max(this.maxComboValue,this.comboValue);
        this.visualComboValue = Math.max(this.visualComboValue,this.comboValue);
        this.effectsLevelValue = Math.max(this.effectsLevelValue,effectLevel(this.comboValue));
        if (effectLevel(this.comboValue) >= this.effectsLevelValue) {
          this.decayFirstAt = null;
          this.decayNextAt = null;
        }
      }
      const scoreDelta = 100 + (enemy.clean ? 50+Math.min(this.comboValue,15)*10 : 0);
      this.scoreValue += scoreDelta;
      this.emit('kill',{enemyId:enemy.id,kind:enemy.kind,phase:enemy.kind === 'boss' ? this.phase : undefined,
        combo:this.comboValue,clean:enemy.clean,scoreDelta,effectsLevel:this.effectsLevelValue});
      if (enemy.kind === 'boss') {
        this.phase++;
        this.bossFailures = 0;
        this.emit('bossPhase',{phase:this.phase});
      }
      if (!this.enemiesValue.length) this.waveFinished();
    }
    return true;
  }

  pause(reason = 'manual'): void {
    if (this.modeValue === 'paused' || this.modeValue === 'defeat' || this.modeValue === 'clear') return;
    this.beforePause = this.modeValue === 'countdown' ? this.beforePause : this.modeValue;
    this.modeValue = 'paused';
    this.emit('pause',{reason});
  }
  resume(): void {
    if (this.modeValue !== 'paused') return;
    this.countdown = 0.8;
    this.modeValue = 'countdown';
  }
  retryCheckpoint(): void {
    if (this.modeValue !== 'defeat') return;
    this.attemptsValue++;
    this.healthValue = 3;
    this.scoreValue = this.checkpoint.score;
    this.maxComboValue = this.checkpoint.maxCombo;
    this.correct = this.checkpoint.correct;
    this.mistakes = this.checkpoint.mistakes;
    this.battleTime = this.checkpoint.battleTime;
    this.elapsed = this.checkpoint.elapsed;
    this.used = new Set(this.checkpoint.used);
    this.comboValue = 0;
    this.visualComboValue = 0;
    this.effectsLevelValue = 0;
    this.decayFirstAt = null;
    this.decayNextAt = null;
    this.locked = null;
    this.enemiesValue = [];
    this.wave = 0;
    this.phase = 0;
    this.bossFailures = 0;
    this.finalResults = null;
    this.modeValue = 'playing';
    this.spawnWave();
  }
  restart(): Game { return new Game({difficulty:this.difficulty,practice:this.practice,seed:this.seed}); }

  get state(): GameState {
    return {
      mode:this.modeValue,stage:this.stageValue,bossPhase:this.phase,health:this.healthValue,
      score:this.scoreValue,combo:this.comboValue,maxCombo:this.maxComboValue,
      effectsLevel:this.effectsLevelValue,
      visualCombo:this.visualComboValue,lockedId:this.locked,practice:this.practice,
      difficulty:this.difficulty,countdown:this.countdown,results:this.finalResults,
      attempts:this.attemptsValue,
      enemies:this.enemiesValue.map(enemy => {
        const duration = enemy.deadline-enemy.spawned;
        const progress = this.practice
          ? Math.min(0.9,(this.time-enemy.spawned)/duration)
          : Math.min(1,Math.max(0,(this.time-enemy.spawned)/duration));
        const remaining = this.practice ? Infinity : Math.max(0,enemy.deadline-this.time);
        return {
          id:enemy.id,kind:enemy.kind,lane:enemy.lane,progress,remaining,
          phrase:enemy.phrase.text,reading:enemy.phrase.reading,
          typed:enemy.typing.typed,guide:enemy.typing.guide,keys:enemy.typing.keys,
          typingProgress:enemy.typing.progress,telegraph:!this.practice && remaining <= 0.8,
          locked:this.locked === enemy.id,
        };
      }),
    };
  }
}
