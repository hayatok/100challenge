import { BOSS_COUNTER_PHRASES, BOSS_PHRASES, LUCKY_PHRASES, OFFICE_PHRASES, PHRASES, RUNNER_PHRASES, RUSH_PHRASES, WORKER_PHRASES, type Phrase } from './content.ts';
import { TypingSession } from './typing.ts';
import { STAGE_PHRASES } from './stage-content.ts';
import { STAGE_DEFINITIONS, isStageId, type DistrictArea, type JourneyRoute, type NormalEnemyKind, type StageId } from './stages.ts';

export type Difficulty = 'relaxed' | 'normal' | 'fierce';
export type EnemyKind = 'office' | 'runner' | 'worker' | 'boss';
export type GameMode = 'playing' | 'travel' | 'paused' | 'countdown' | 'defeat' | 'clear' | 'explore' | 'vista' | 'rest';
export type GameOptions = { difficulty?: Difficulty; practice?: boolean; seed?: number; journey?: boolean; stageId?: StageId };
export type GameEvent = {
  id: number; type: 'spawn'|'lock'|'hit'|'miss'|'kill'|'attack'|'travel'|'stage'|'bossPhase'|'pause'|'resume'|'defeat'|'clear'|'rushStart'|'rushEnd'|'explosion'|'sweep'|'vista'|'luckyStart'|'luckyStep'|'luckyEnd';
  enemyId?: number; kind?: EnemyKind; stage?: number; phase?: number; key?: string; reason?: string;
  combo?: number; clean?: boolean; scoreDelta?: number; effectsLevel?: number;
  hitZone?: 'head'|'chest'|'shoulder'; finisher?: boolean; rush?: boolean;
  collateral?: boolean; count?: number; success?: boolean; lucky?: boolean; step?: number; healing?: number;
};
export type EnemyView = {
  id: number; kind: EnemyKind; lane: -1|0|1; progress: number; remaining: number;
  phrase: string; reading: string; typed: string; guide: string; keys: string[];
  typingProgress: number; telegraph: boolean; locked: boolean; threatRank: number;
  explosive: boolean; blastTargets: number[]; rush: boolean; lucky: boolean;
  support?: boolean;
};
export type GameResults = {
  stageId: StageId;
  score: number; maxCombo: number; accuracy: number; correct: number; mistakes: number;
  clearTime: number; keysPerMinute: number; attempts: number; practice: boolean; difficulty: Difficulty;
  seed: number; rushes: number; chainKills: number;
  luckyEncounters: number; luckyClears: number; luckyBonus: number;
};
export type GameState = {
  mode: GameMode; stageId: StageId; stage: number; bossPhase: number; health: number; score: number;
  combo: number; maxCombo: number; effectsLevel: number; visualCombo: number;
  lockedId: number|null; enemies: EnemyView[]; practice: boolean; difficulty: Difficulty;
  countdown: number; results: GameResults|null; attempts: number;
  rushCharge: number; rushing: boolean; rushRemaining: number; rushes: number; chainKills: number; bossCounter: number;
  luckyActive: boolean; luckyStep: number; luckyRemaining: number;
  luckyEncounters: number; luckyClears: number; luckyBonus: number;
  journey?: {route:JourneyRoute|null; wave:number; travelProgress:number; area:DistrictArea; completedPrompts:number; totalPrompts:number; rest:'midpoint'|'beforeBoss'|null};
};

type Enemy = {
  id: number; kind: EnemyKind; lane: -1|0|1; phrase: Phrase; typing: TypingSession;
  spawned: number; deadline: number; clean: boolean; explosive: boolean; rush: boolean; lucky: boolean;
  support?: boolean;
};
type Checkpoint = { score:number; maxCombo:number; correct:number; mistakes:number; time:number; battleTime:number; used:Set<number>; elapsed:number; completedPrompts:number; rushCharge:number; rushes:number; chainKills:number; luckyEncounters:number; luckyClears:number; luckyBonus:number; luckyDone:boolean };
const CPS: Record<Difficulty, number> = { relaxed:2, normal:3.5, fierce:5 };
const STAGE_WAVES: readonly (readonly (readonly EnemyKind[])[])[] = [
  [['office'],['office'],['office'],['runner'],['office'],['worker']],
  [['office','runner'],['runner','worker'],['office','worker'],['runner','office']],
  [['runner','office'],['worker','runner'],['runner','office','worker'],['office','runner','worker']],
];
const JOURNEY_WAVES: readonly (readonly (readonly NormalEnemyKind[])[])[] = [
  [['office'],['runner'],['office','runner'],['worker','office'],['office'],['runner'],['office','runner'],['worker','office']],
  [['worker','office'],['runner','office'],['worker','runner'],['office','runner'],['worker','office'],['runner','office']],
  [['office','runner'],['worker','office'],['runner','worker'],['runner','office','worker'],['office']],
];
const SERVICE_WAVES: readonly (readonly NormalEnemyKind[])[] = [
  ['runner','office'],['runner','office'],['office','worker'],['runner','office'],['runner','worker'],['office','runner'],
];
const hashPhrase = (n:number,seed:number):number => {
  let x=(n+1)^seed; x=Math.imul(x^(x>>>16),0x7feb352d);x=Math.imul(x^(x>>>15),0x846ca68b);
  return (x^(x>>>16))>>>0;
};
const LEVELS = [3,6,10,15];
const effectLevel = (combo: number): number => LEVELS.filter(level => combo >= level).length;
// The listed order is the safe deadline order, not the only possible choice.
// Different waves put the short runner, long worker, or regular office target first.
const WAVE_ORDERS = [
  [[0],[0],[0],[0],[0],[0]],
  [[1,0],[0,1],[1,0],[1,0]],
  [[1,0],[0,1],[2,0,1],[1,2,0]],
] as const;
const BOSS_TIMING = [
  {read:1.4,work:1.7,recovery:0.75,telegraph:1.0},
  {read:1.15,work:1.55,recovery:1.2,telegraph:1.1},
  {read:1.0,work:1.5,recovery:1.2,telegraph:1.2},
] as const;

export class Game {
  readonly stageId: StageId;
  readonly difficulty: Difficulty;
  readonly practice: boolean;
  readonly seed: number;
  readonly journey: boolean;
  private modeValue: GameMode = 'playing';
  private beforePause: GameMode = 'playing';
  private time = 0;
  private elapsed = 0;
  private battleTime = 0;
  private countdown = 0;
  private travelTime = 0;
  private travelDuration = 0;
  private routeValue: JourneyRoute|null = null;
  private areaValue: DistrictArea = 'market';
  private restValue: 'midpoint'|'beforeBoss'|null = null;
  private pendingRest: 'midpoint'|'beforeBoss'|null = null;
  private completedPromptsValue = 0;
  private stageValue = 0;
  private wave = 0;
  private phase = 0;
  private bossFailures = 0;
  private bossCounterValue = 0;
  private rushChargeValue = 0;
  private rushingValue = false;
  private rushRemainingValue = 0;
  private rushesValue = 0;
  private rushKillsValue = 0;
  private chainKillsValue = 0;
  private luckyActiveValue = false;
  private luckyPending = false;
  private luckyDone = false;
  private luckyStepValue = 0;
  private luckyRemainingValue = 0;
  private luckyDurationValue = 0;
  private luckyEncountersValue = 0;
  private luckyClearsValue = 0;
  private luckyBonusValue = 0;
  private luckyPhrases: readonly Phrase[] = [];
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
  private checkpoint: Checkpoint = {score:0,maxCombo:0,correct:0,mistakes:0,time:0,battleTime:0,elapsed:0,completedPrompts:0,used:new Set(),rushCharge:0,rushes:0,chainKills:0,luckyEncounters:0,luckyClears:0,luckyBonus:0,luckyDone:false};
  private events: GameEvent[] = [];
  private nextEventId = 1;
  private nextEnemyId = 1;
  private finalResults: GameResults|null = null;

  constructor(options: GameOptions = {}) {
    if (!isStageId(options.stageId ?? 'shopping')) throw new Error('Invalid stageId');
    this.stageId = options.stageId ?? 'shopping';
    this.difficulty = options.difficulty ?? 'normal';
    if (!(this.difficulty in CPS)) throw new Error('Invalid difficulty');
    this.practice = options.practice ?? false;
    this.journey = options.journey ?? false;
    this.seed = options.seed ?? 1;
    if (!Number.isInteger(this.seed) || this.seed < 0 || this.seed > 0xffffffff) throw new Error('Invalid seed');
    this.areaValue=this.firstArea();
    if (this.journey) this.modeValue = 'explore';
    else this.spawnWave();
  }

  private firstArea(): DistrictArea { return this.stageId==='shopping'?'market':'forecourt'; }
  private secondArea(): DistrictArea { return this.stageId==='shopping'?'alley':'concourse'; }
  private finalArea(): DistrictArea { return this.stageId==='shopping'?'court':'platform'; }
  private vistaArea(): DistrictArea { return this.stageId==='shopping'?'roof':'dawn'; }

  chooseRoute(route: JourneyRoute): boolean {
    if (!this.journey || this.modeValue !== 'explore' || !STAGE_DEFINITIONS[this.stageId].routes.some(item=>item.id===route)) return false;
    this.routeValue = route;
    this.beginTravel(2);
    return true;
  }

  continueRest(): boolean {
    if (!this.journey || this.modeValue!=='rest' || !this.restValue) return false;
    const kind=this.restValue;
    this.restValue=null;
    this.modeValue='playing';
    if(kind==='midpoint') this.startCourtyardRush();
    else this.spawnBoss();
    return true;
  }

  continueVista(): boolean {
    if (!this.journey || this.modeValue !== 'vista') return false;
    this.finish('clear');
    return true;
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
    if (this.journey) {
      const area = this.areaValue;
      const pool = STAGE_PHRASES[this.stageId].areas[area]?.[kind];
      if (!pool?.length) throw new Error('No journey phrases for this area and role');
      const areas: DistrictArea[]=['market','alley','store','service','court','forecourt','concourse','waiting','maintenance','platform'];
      const roles: NormalEnemyKind[]=['runner','office','worker'];
      const offset=(this.stageId==='station'?5000:0)+areas.indexOf(area)*300+roles.indexOf(kind)*100;
      const order = pool.map((phrase,index) => ({phrase,index:offset+index}))
        .sort((a,b) => hashPhrase(a.index,this.seed)-hashPhrase(b.index,this.seed));
      for (const allowUsed of [false,true]) for (const {phrase,index} of order) {
        if (!allowUsed && this.used.has(index)) continue;
        const keys = new TypingSession(phrase.reading).keys;
        if (keys.some(key => occupied.has(key))) continue;
        keys.forEach(key => occupied.add(key));
        this.used.add(index);
        return phrase;
      }
      throw new Error('No distinct initial-key journey phrase for this wave');
    }
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
    if (this.rushingValue) { this.spawnRush(); return; }
    if (this.stageValue === 3) { this.spawnBoss(); return; }
    const kinds = this.journey && this.stageValue === 1 && (this.routeValue === 'service'||this.routeValue==='maintenance')
      ? SERVICE_WAVES[this.wave]
      : (this.journey ? JOURNEY_WAVES : STAGE_WAVES)[this.stageValue]?.[this.wave];
    if (!kinds) throw new Error('Invalid wave');
    const occupied = new Set<string>();
    const order: readonly number[] = this.journey ? kinds.map((_,index) => index) : WAVE_ORDERS[this.stageValue][this.wave];
    const laneOrder = (this.wave + this.stageValue) % 2 ? [1,-1,0] : [-1,1,0];
    const explosiveWave = !this.journey && ((this.stageValue === 1 && this.wave === 2) || (this.stageValue === 2 && (this.wave === 1 || this.wave === 2)));
    const carrierIndex = explosiveWave ? kinds.indexOf('worker') : -1;
    const otherIndices = kinds.map((_,index) => index).filter(index => index !== carrierIndex);
    let workload = 0;
    this.enemiesValue = order.map((sourceIndex,index) => {
      const kind = kinds[sourceIndex];
      const phrase = this.pickPhrase(kind as Exclude<EnemyKind,'boss'>, occupied);
      const typing = new TypingSession(phrase.reading);
      const length = typing.standardLength;
      workload += length / CPS[this.difficulty];
      // Read time and accumulated work guarantee this advertised order is feasible.
      const deadline = this.time + 1.2 + workload * (this.journey && this.stageValue === 1 && (this.routeValue === 'service'||this.routeValue==='maintenance') ? 1.45 : 1.6) + (index + 1) * 0.55;
      // These authored carriers stand in the middle so the preview always has a reachable neighbour.
      const explosive = sourceIndex === carrierIndex;
      const lane = (kinds.length === 1 ? 0 : explosiveWave
        ? explosive ? 0 : otherIndices.indexOf(sourceIndex) === 0 ? -1 : 1
        : laneOrder[sourceIndex]) as -1|0|1;
      const enemy: Enemy = {id:this.nextEnemyId++,kind,lane,phrase,typing,spawned:this.time,deadline,clean:true,explosive,rush:false,lucky:false};
      this.emit('spawn',{enemyId:enemy.id,kind,stage:this.stageValue});
      return enemy;
    });
  }

  private spawnRush(): void {
    const pool=this.journey?STAGE_PHRASES[this.stageId].rush:RUSH_PHRASES;
    const index = ((this.seed >>> 0) + this.rushesValue * 7 + (4-this.rushRemainingValue)) % pool.length;
    const phrase = pool[index];
    const typing = new TypingSession(phrase.reading);
    const deadline = this.time + 0.8 + typing.standardLength / CPS[this.difficulty] * 1.45;
    const enemy: Enemy = {id:this.nextEnemyId++,kind:'runner',lane:this.journey ? 0 : ([-1,0,1,0] as const)[4-this.rushRemainingValue],phrase,typing,spawned:this.time,deadline,clean:true,explosive:false,rush:true,lucky:false};
    this.enemiesValue = [enemy];
    this.emit('spawn',{enemyId:enemy.id,kind:enemy.kind,stage:this.stageValue});
    if (this.journey && this.stageValue === 2) {
      for (const lane of [-1,1] as const) {
        const support: Enemy = {id:this.nextEnemyId++,kind:lane === -1 ? 'office' : 'worker',lane,phrase,typing:new TypingSession(phrase.reading),spawned:enemy.spawned,deadline:enemy.deadline,clean:false,explosive:false,rush:true,lucky:false,support:true};
        this.enemiesValue.push(support);
        this.emit('spawn',{enemyId:support.id,kind:support.kind,stage:this.stageValue});
      }
    }
  }

  private spawnBoss(): void {
    if (this.phase === 1 && this.bossCounterValue === 0) this.bossCounterValue = 1;
    const bossPool=this.journey?STAGE_PHRASES[this.stageId].boss:BOSS_PHRASES;
    const counterPool=this.journey?STAGE_PHRASES[this.stageId].counters:BOSS_COUNTER_PHRASES;
    const phrase = this.phase === 1
      ? counterPool[((this.seed >>> 0) + this.bossCounterValue-1) % counterPool.length]
      : bossPool[this.phase * 4 + ((this.seed >>> 0) + this.bossFailures) % 4];
    const typing = new TypingSession(phrase.reading);
    const timing = BOSS_TIMING[this.phase];
    const deadline = this.time + timing.read + typing.standardLength / CPS[this.difficulty] * timing.work;
    const enemy: Enemy = {id:this.nextEnemyId++,kind:'boss',lane:0,phrase,typing,spawned:this.time,deadline,clean:true,explosive:false,rush:false,lucky:false};
    this.enemiesValue = [enemy];
    this.emit('spawn',{enemyId:enemy.id,kind:'boss',stage:3,phase:this.phase,count:this.bossCounterValue});
  }

  private luckyScheduledHere(): boolean {
    if (this.journey) return !this.luckyDone && this.stageValue === 1 && this.wave === JOURNEY_WAVES[1].length-1 && (this.practice || (this.seed & 1) === 0);
    if (this.luckyDone || (!this.practice && (this.seed & 1) !== 0)) return false;
    const stage = (this.seed >>> 1) & 1;
    const wave = stage === 0 ? 2 + ((this.seed >>> 2) % 3) : 1 + ((this.seed >>> 2) % 2);
    return this.stageValue === stage && this.wave === wave;
  }

  private startLucky(): void {
    this.luckyPending = false;
    this.luckyDone = true;
    this.luckyActiveValue = true;
    this.luckyStepValue = 1;
    const sets=this.journey?STAGE_PHRASES[this.stageId].lucky:LUCKY_PHRASES;
    this.luckyPhrases = sets[(this.seed >>> 3) % sets.length];
    const workload = this.luckyPhrases.reduce((sum,phrase) => sum + new TypingSession(phrase.reading).standardLength,0);
    this.luckyRemainingValue = 6 + workload / CPS[this.difficulty] * 2;
    this.luckyDurationValue = this.luckyRemainingValue;
    this.luckyEncountersValue++;
    const phrase = this.luckyPhrases[0];
    const enemy: Enemy = {id:this.nextEnemyId++,kind:'office',lane:0,phrase,typing:new TypingSession(phrase.reading),spawned:this.time,deadline:Infinity,clean:true,explosive:false,rush:false,lucky:true};
    this.enemiesValue = [enemy];
    this.emit('luckyStart',{enemyId:enemy.id,kind:'office',lucky:true,stage:this.stageValue,step:1});
  }

  private finishLucky(success: boolean): void {
    const enemy = this.enemiesValue[0];
    if (!this.luckyActiveValue || !enemy) return;
    const scoreDelta = success ? 500 : 0;
    const healing = success && this.healthValue < 3 ? 1 : 0;
    this.scoreValue += scoreDelta;
    this.healthValue += healing;
    if (success) { this.luckyClearsValue++; this.luckyBonusValue += scoreDelta; }
    this.emit('luckyEnd',{enemyId:enemy.id,kind:'office',lucky:true,success,scoreDelta,healing,step:this.luckyStepValue});
    this.luckyActiveValue = false;
    this.luckyStepValue = 0;
    this.luckyRemainingValue = 0;
    this.luckyDurationValue = 0;
    this.enemiesValue = [];
    this.locked = null;
    this.advanceWave(success ? 2 : 0.8);
  }

  private beginTravel(seconds: number): void {
    this.modeValue = 'travel';
    this.travelTime = seconds;
    this.travelDuration = seconds;
    this.emit('travel',{stage:this.stageValue});
  }

  private startCourtyardRush(): void {
    this.rushingValue = true;
    this.rushRemainingValue = 4;
    this.rushKillsValue = 0;
    this.rushChargeValue = 0;
    this.rushesValue++;
    this.emit('rushStart',{count:this.rushesValue});
    this.spawnRush();
  }

  private waveFinished(): void {
    this.locked = null;
    if (this.stageValue === 3) {
      if (this.phase >= 3) {
        if (this.journey) {
          this.areaValue = this.vistaArea();
          this.modeValue = 'vista';
          this.emit('vista',{stage:3});
        } else this.finish('clear');
        return;
      }
      this.beginTravel(this.phase === 1 && this.bossCounterValue > 1 ? 0.35 : BOSS_TIMING[this.phase-1].recovery);
      return;
    }
    if (this.rushingValue) {
      this.rushRemainingValue--;
      if (this.rushRemainingValue > 0) { this.beginTravel(0.18); return; }
      this.rushingValue = false;
      this.emit('rushEnd',{count:this.rushesValue,success:this.rushKillsValue === 4});
      if (this.journey) { this.beginTravel(0.35); return; }
    } else {
      if (this.luckyScheduledHere()) this.luckyPending = true;
      if (!this.journey && this.rushChargeValue >= 100 && this.rushesValue < 2) {
        this.rushingValue = true;
        this.rushRemainingValue = 4;
        this.rushKillsValue = 0;
        this.rushChargeValue = 0;
        this.rushesValue++;
        this.emit('rushStart',{count:this.rushesValue});
        this.beginTravel(0.35);
        return;
      }
    }
    if (this.luckyPending) { this.startLucky(); return; }
    this.advanceWave();
  }

  private advanceWave(travelSeconds?: number): void {
    this.wave++;
    if (this.journey && this.stageValue===0 && this.wave===4) {
      this.areaValue=this.secondArea();
      this.beginTravel(3);
      return;
    }
    if (this.wave >= (this.journey ? JOURNEY_WAVES : STAGE_WAVES)[this.stageValue].length) {
      this.stageValue++;
      this.wave = 0;
      this.checkpoint = {score:this.scoreValue,maxCombo:this.maxComboValue,correct:this.correct,mistakes:this.mistakes,time:this.time,battleTime:this.battleTime,elapsed:this.elapsed,completedPrompts:this.completedPromptsValue,used:new Set(this.used),rushCharge:this.rushChargeValue,rushes:this.rushesValue,chainKills:this.chainKillsValue,luckyEncounters:this.luckyEncountersValue,luckyClears:this.luckyClearsValue,luckyBonus:this.luckyBonusValue,luckyDone:this.luckyDone};
      this.emit('stage',{stage:this.stageValue});
      if (this.journey) {
        this.areaValue = this.stageValue === 1 ? this.routeValue! : this.finalArea();
        this.pendingRest=this.stageValue===2?'midpoint':this.stageValue===3?'beforeBoss':null;
        this.beginTravel(this.stageValue === 1 ? 3.8 : this.stageValue === 2 ? 4 : 2);
      } else this.beginTravel(this.stageValue === 3 ? 2.2 : travelSeconds ?? 1);
    } else this.beginTravel(travelSeconds ?? 0.6);
  }

  private finish(mode: 'clear'|'defeat'): void {
    this.modeValue = mode;
    this.finalResults = {
      stageId:this.stageId,
      score:this.scoreValue,maxCombo:this.maxComboValue,
      accuracy:this.correct+this.mistakes ? this.correct/(this.correct+this.mistakes) : 1,
      correct:this.correct,mistakes:this.mistakes,clearTime:this.elapsed,
      keysPerMinute:this.battleTime ? this.correct*60/this.battleTime : 0,
      attempts:this.attemptsValue,practice:this.practice,difficulty:this.difficulty,
      seed:this.seed,rushes:this.rushesValue,chainKills:this.chainKillsValue,
      luckyEncounters:this.luckyEncountersValue,luckyClears:this.luckyClearsValue,luckyBonus:this.luckyBonusValue,
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
    if (this.modeValue === 'paused' || this.modeValue === 'clear' || this.modeValue === 'defeat' || this.modeValue === 'explore' || this.modeValue === 'vista' || this.modeValue === 'rest') return;
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
        if (this.journey && this.pendingRest) {
          this.modeValue='rest';
          this.restValue=this.pendingRest;
          this.pendingRest=null;
        } else {
          this.modeValue = 'playing';
          if (this.journey && this.stageValue === 2 && this.rushesValue === this.checkpoint.rushes && this.wave === 0) this.startCourtyardRush();
          else this.spawnWave();
        }
        if (surplus) this.update(surplus);
      }
      return;
    }
    if (this.luckyActiveValue) {
      const overdue = dt > this.luckyRemainingValue + 1e-9;
      this.luckyRemainingValue = Math.max(0,this.luckyRemainingValue-dt);
      if (overdue) this.finishLucky(false);
      return;
    }
    this.time += dt;
    this.elapsed += dt;
    this.battleTime += dt;
    this.updateEffects(dt);
    if (this.practice) return;
    for (const enemy of [...this.enemiesValue].sort((a,b) => a.id-b.id)) {
      if (enemy.support || !this.enemiesValue.some(item => item.id === enemy.id)) continue;
      // At the exact deadline an arriving final key wins the tie.
      if (this.time <= enemy.deadline) continue;
      const supports = enemy.rush && this.journey ? this.enemiesValue.filter(item => item.support) : [];
      this.enemiesValue = this.enemiesValue.filter(item => item.id !== enemy.id);
      this.emit('attack',{enemyId:enemy.id,kind:enemy.kind,combo:0});
      for (const support of supports) {
        this.enemiesValue = this.enemiesValue.filter(item => item.id !== support.id);
        this.emit('attack',{enemyId:support.id,kind:support.kind,collateral:true,combo:0});
      }
      this.healthValue--;
      this.breakCombo();
      if (this.locked === enemy.id) this.locked = null;
      else if (this.locked !== null) {
        const target = this.enemiesValue.find(item => item.id === this.locked);
        if (target) target.clean = false;
      }
      if (this.journey && enemy.kind !== 'boss' && !enemy.rush && !enemy.lucky) this.completedPromptsValue++;
      if (this.journey && enemy.rush) this.completedPromptsValue++;
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
    if (this.luckyActiveValue) {
      const enemy = this.enemiesValue[0];
      if (!enemy) return false;
      const normalized = key.toLowerCase();
      if (!enemy.typing.type(normalized)) {
        this.emit('miss',{enemyId:enemy.id,kind:'office',key:normalized,lucky:true});
        return false;
      }
      if (this.locked === null) {
        this.locked = enemy.id;
        this.emit('lock',{enemyId:enemy.id,kind:'office',lucky:true});
      }
      const finisher = enemy.typing.complete;
      this.emit('hit',{enemyId:enemy.id,kind:'office',key:normalized,lucky:true,finisher,hitZone:finisher ? 'head' : 'chest'});
      if (finisher) {
        if (this.luckyStepValue === 3) this.finishLucky(true);
        else {
          this.emit('luckyStep',{enemyId:enemy.id,kind:'office',lucky:true,step:this.luckyStepValue});
          this.luckyStepValue++;
          enemy.phrase = this.luckyPhrases[this.luckyStepValue-1];
          enemy.typing = new TypingSession(enemy.phrase.reading);
        }
      }
      return true;
    }
    // If time passed a deadline, resolve attacks before assigning this key.
    if (!this.practice && this.enemiesValue.some(enemy => this.time > enemy.deadline)) this.update(0);
    if (this.modeValue !== 'playing' || !this.enemiesValue.length) return false;
    const normalized = key.toLowerCase();
    let enemy = this.enemiesValue.find(item => item.id === this.locked);
    if (!enemy) enemy = this.enemiesValue.find(item => !item.support && item.typing.keys.includes(normalized));
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
    const finisher = enemy.typing.complete;
    const hitZone = finisher ? 'head' : enemy.typing.typed.length % 3 === 0 ? 'shoulder' : 'chest';
    this.emit('hit',{enemyId:enemy.id,kind:enemy.kind,key:normalized,combo:this.comboValue,effectsLevel:this.effectsLevelValue,hitZone,finisher,rush:this.rushingValue});
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
      if (this.journey) this.completedPromptsValue++;
      if (enemy.rush) this.rushKillsValue++;
      else if (enemy.kind !== 'boss' && this.rushesValue < 2) this.rushChargeValue = Math.min(100,this.rushChargeValue + 18 + (enemy.clean ? 7 : 0));
      this.emit('kill',{enemyId:enemy.id,kind:enemy.kind,phase:enemy.kind === 'boss' ? this.phase : undefined,
        combo:this.comboValue,clean:enemy.clean,scoreDelta,effectsLevel:this.effectsLevelValue,hitZone:'head',finisher:true});
      if (enemy.rush && this.journey) {
        const supports = this.enemiesValue.filter(item => item.support);
        for (const support of supports) {
          this.enemiesValue = this.enemiesValue.filter(item => item.id !== support.id);
          this.chainKillsValue++;
          this.scoreValue += 75;
          this.emit('kill',{enemyId:support.id,kind:support.kind,combo:this.comboValue,clean:false,collateral:true,scoreDelta:75,effectsLevel:this.effectsLevelValue});
        }
        this.emit('sweep',{enemyId:enemy.id,kind:enemy.kind,count:1+supports.length});
      }
      if (enemy.explosive) {
        const collateral = this.enemiesValue.filter(target => target.kind !== 'boss' && target.id !== this.locked && Math.abs(target.lane-enemy.lane) <= 1);
        for (const target of collateral) {
          this.enemiesValue = this.enemiesValue.filter(item => item.id !== target.id);
          this.chainKillsValue++;
          const bonus = 75;
          this.scoreValue += bonus;
          this.emit('kill',{enemyId:target.id,kind:target.kind,combo:this.comboValue,clean:false,collateral:true,scoreDelta:bonus,effectsLevel:this.effectsLevelValue});
        }
        this.emit('explosion',{enemyId:enemy.id,kind:enemy.kind,count:collateral.length});
      }
      if (enemy.kind === 'boss') {
        if (this.phase === 1 && this.bossCounterValue < 3) {
          this.emit('bossPhase',{phase:1,count:this.bossCounterValue});
          this.bossCounterValue++;
        } else {
          this.phase++;
          this.emit('bossPhase',{phase:this.phase,count:this.phase === 2 ? 3 : undefined});
        }
        this.bossFailures = 0;
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
    this.time=this.checkpoint.time;
    this.maxComboValue = this.checkpoint.maxCombo;
    this.correct = this.checkpoint.correct;
    this.mistakes = this.checkpoint.mistakes;
    this.battleTime = this.checkpoint.battleTime;
    this.elapsed = this.checkpoint.elapsed;
    this.completedPromptsValue=this.checkpoint.completedPrompts;
    this.used = new Set(this.checkpoint.used);
    this.rushChargeValue = this.checkpoint.rushCharge;
    this.rushesValue = this.checkpoint.rushes;
    this.rushKillsValue = 0;
    this.chainKillsValue = this.checkpoint.chainKills;
    this.luckyEncountersValue = this.checkpoint.luckyEncounters;
    this.luckyClearsValue = this.checkpoint.luckyClears;
    this.luckyBonusValue = this.checkpoint.luckyBonus;
    this.luckyDone = this.checkpoint.luckyDone;
    this.luckyPending = false;
    this.luckyActiveValue = false;
    this.luckyStepValue = 0;
    this.luckyRemainingValue = 0;
    this.luckyDurationValue = 0;
    this.luckyPhrases = [];
    this.restValue=null;
    this.pendingRest=null;
    this.rushingValue = false;
    this.rushRemainingValue = 0;
    this.bossCounterValue = 0;
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
    this.travelTime=0;
    this.travelDuration=1;
    if (this.journey) this.areaValue = this.stageValue === 0 ? this.firstArea() : this.stageValue === 1 ? this.routeValue! : this.finalArea();
    if (this.journey && this.stageValue >= 2) {
      this.restValue=this.stageValue===2?'midpoint':'beforeBoss';
      this.modeValue='rest';
    } else this.spawnWave();
  }
  restart(): Game { return new Game({difficulty:this.difficulty,practice:this.practice,seed:this.seed,journey:this.journey,stageId:this.stageId}); }

  get state(): GameState {
    return {
      mode:this.modeValue,stageId:this.stageId,stage:this.stageValue,bossPhase:this.phase,health:this.healthValue,
      score:this.scoreValue,combo:this.comboValue,maxCombo:this.maxComboValue,
      effectsLevel:this.effectsLevelValue,
      visualCombo:this.visualComboValue,lockedId:this.locked,practice:this.practice,
      difficulty:this.difficulty,countdown:this.countdown,results:this.finalResults,
      attempts:this.attemptsValue,
      rushCharge:this.rushChargeValue,rushing:this.rushingValue,rushRemaining:this.rushRemainingValue,rushes:this.rushesValue,chainKills:this.chainKillsValue,bossCounter:this.phase === 1 ? this.bossCounterValue : 0,
      luckyActive:this.luckyActiveValue,luckyStep:this.luckyStepValue,luckyRemaining:this.luckyRemainingValue,
      luckyEncounters:this.luckyEncountersValue,luckyClears:this.luckyClearsValue,luckyBonus:this.luckyBonusValue,
      ...(this.journey ? {journey:{route:this.routeValue,wave:this.wave,travelProgress:this.modeValue === 'travel' || this.modeValue === 'paused' && this.beforePause === 'travel' || this.modeValue === 'countdown' && this.beforePause === 'travel'
        ? Math.min(1,Math.max(0,1-this.travelTime/this.travelDuration)) : this.travelDuration ? 1 : 0,
        area:this.areaValue,completedPrompts:this.completedPromptsValue,totalPrompts:STAGE_DEFINITIONS[this.stageId].requiredPrompts,rest:this.restValue}} : {}),
      enemies:this.enemiesValue.map((enemy,index) => {
        const duration = enemy.deadline-enemy.spawned;
        const progress = enemy.lucky ? Math.min(1,Math.max(0,1-this.luckyRemainingValue/this.luckyDurationValue)) : this.practice
          ? Math.min(0.9,(this.time-enemy.spawned)/duration)
          : Math.min(1,Math.max(0,(this.time-enemy.spawned)/duration));
        const remaining = enemy.lucky ? this.luckyRemainingValue : this.practice ? Infinity : Math.max(0,enemy.deadline-this.time);
        return {
          id:enemy.id,kind:enemy.kind,lane:enemy.lane,progress,remaining,
          phrase:enemy.support ? '' : enemy.phrase.text,reading:enemy.support ? '' : enemy.phrase.reading,
          typed:enemy.support ? '' : enemy.typing.typed,guide:enemy.support ? '' : enemy.typing.guide,keys:enemy.support ? [] : enemy.typing.keys,
          typingProgress:enemy.support ? 0 : enemy.typing.progress,telegraph:!enemy.lucky && !this.practice && remaining <= (enemy.kind === 'boss' ? BOSS_TIMING[this.phase].telegraph : 0.8),
          locked:this.locked === enemy.id,threatRank:index+1,
          explosive:enemy.explosive,blastTargets:enemy.explosive ? this.enemiesValue.filter(target => target.id !== enemy.id && target.kind !== 'boss' && Math.abs(target.lane-enemy.lane) <= 1).map(target => target.id) : [],rush:enemy.rush,lucky:enemy.lucky,support:enemy.support,
        };
      }),
    };
  }
}
