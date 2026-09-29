import { STAGE_DEFINITIONS, isStageId, type JourneyRoute, type StageId } from './stages.ts';

export type Preferences = {
  difficulty: "relaxed" | "normal" | "fierce";
  music: number;
  effects: number;
  motion: boolean;
  practice: boolean;
};
export const RESULT_RULES_VERSION = 7;
export type SavedResult = {
  /** Absent on older records. Invalid v7 values are isolated under a legacy key. */
  stageId?: StageId;
  route?: JourneyRoute;
  score: number;
  combo: number;
  accuracy: number;
  seconds: number;
  cleared: boolean;
  difficulty: Preferences["difficulty"];
  practice: boolean;
  retries: number;
  date: string;
  rulesVersion: number;
  /** Original run seed, when recorded. A missing seed means replay is unavailable. */
  seed?: number;
  rushes?: number;
  chainKills?: number;
  luckyEncounters?: number;
  luckyClears?: number;
  luckyBonus?: number;
};
export type SavedData = {
  preferences: Preferences;
  results: SavedResult[];
  personalBests: Record<string,SavedResult>;
};
export const defaultPreferences = (): Preferences => ({
  difficulty: "normal",
  music: 0.45,
  effects: 0.75,
  motion: !matchMedia("(prefers-reduced-motion: reduce)").matches,
  practice: false,
});
const KEY = "nightshift-typing:v1";
const DIFFICULTIES = ["relaxed", "normal", "fierce"] as const;
const record = (value: unknown): Record<string,unknown> => value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string,unknown> : {};
const finiteNonnegative = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value) && value >= 0;
const integerNonnegative = (value: unknown): value is number => finiteNonnegative(value) && Number.isInteger(value);
const validSeed = (value: unknown): value is number => integerNonnegative(value) && value <= 0xffffffff;
const validCount = (value: unknown): value is number => integerNonnegative(value) && value <= 10_000;
function finiteVolume(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.min(1, value)) : fallback;
}

function validResult(value: unknown, fallbackVersion: number): SavedResult|null {
  const r = record(value);
  if (!finiteNonnegative(r.score) || !integerNonnegative(r.combo) ||
      typeof r.accuracy !== 'number' || !Number.isFinite(r.accuracy) || r.accuracy < 0 || r.accuracy > 1 ||
      !finiteNonnegative(r.seconds) || typeof r.cleared !== 'boolean' ||
      !DIFFICULTIES.includes(r.difficulty as Preferences['difficulty']) ||
      typeof r.practice !== 'boolean' || !integerNonnegative(r.retries) ||
      typeof r.date !== 'string' || !Number.isFinite(Date.parse(r.date))) return null;
  const rulesVersion = r.rulesVersion ?? fallbackVersion;
  if (!Number.isInteger(rulesVersion) || (rulesVersion as number) < 1) return null;
  const result: SavedResult = {
    score:r.score,combo:r.combo,accuracy:r.accuracy,seconds:r.seconds,
    cleared:r.cleared,difficulty:r.difficulty as Preferences['difficulty'],
    practice:r.practice,retries:r.retries,date:r.date,rulesVersion:rulesVersion as number,
  };
  if (isStageId(r.stageId)) result.stageId=r.stageId;
  if (result.stageId && STAGE_DEFINITIONS[result.stageId].routes.some(route=>route.id===r.route)) {
    result.route=r.route as JourneyRoute;
  }
  // Optional v0.5 fields must never make older runs disappear. Invalid fields
  // are omitted so an untrusted seed cannot become a replay control.
  if (validSeed(r.seed)) result.seed = r.seed;
  if (validCount(r.rushes)) result.rushes = r.rushes;
  if (validCount(r.chainKills)) result.chainKills = r.chainKills;
  if (r.luckyEncounters === 0 || r.luckyEncounters === 1) {
    result.luckyEncounters=r.luckyEncounters;
    if ((r.luckyClears===0 || r.luckyClears===1) && r.luckyClears <= r.luckyEncounters) {
      result.luckyClears=r.luckyClears;
      if(r.luckyBonus === r.luckyClears*500) result.luckyBonus=r.luckyBonus;
    }
  }
  return result;
}

export function resultKey(result: Pick<SavedResult,'difficulty'|'practice'|'rulesVersion'|'stageId'>): string {
  const prefix=result.rulesVersion>=7 ? `${result.rulesVersion}:${isStageId(result.stageId)?result.stageId:'legacy'}` : result.rulesVersion;
  return `${prefix}:${result.difficulty}:${result.practice ? 'practice' : 'standard'}`;
}

/** Only a current, fully identified journey result can reproduce its phrase sequence. */
export function replayOptions(result: SavedResult): {seed:number;stageId:StageId;route:JourneyRoute;difficulty:Preferences['difficulty'];practice:boolean}|null {
  if (result.rulesVersion!==RESULT_RULES_VERSION || !isStageId(result.stageId) ||
      !STAGE_DEFINITIONS[result.stageId].routes.some(route=>route.id===result.route) ||
      !validSeed(result.seed)) return null;
  return {seed:result.seed,stageId:result.stageId,route:result.route!,difficulty:result.difficulty,practice:result.practice};
}
export function betterResult(candidate: SavedResult, current: SavedResult|null|undefined): boolean {
  if (!candidate.cleared) return false;
  if (!current) return true;
  return candidate.score > current.score ||
    (candidate.score === current.score && (candidate.accuracy > current.accuracy ||
      (candidate.accuracy === current.accuracy && (candidate.seconds < current.seconds ||
        (candidate.seconds === current.seconds && candidate.retries < current.retries)))));
}
function addBest(bests: Record<string,SavedResult>, result: SavedResult): void {
  const key = resultKey(result);
  if (betterResult(result,bests[key])) bests[key] = result;
}

export function readSave(): SavedData {
  const defaults = defaultPreferences();
  try {
    const data = record(JSON.parse(localStorage.getItem(KEY) ?? "{}"));
    const p = record(data.preferences);
    // Save container version 2 predates v0.5. Missing rulesVersion in that
    // container belongs to v0.4 rules even after the current rules change.
    const fallbackVersion = data.version === 2 ? 3 : 2;
    const results = Array.isArray(data.results)
      ? data.results.map(value => validResult(value,fallbackVersion)).filter((value): value is SavedResult => value !== null).slice(-10)
      : [];
    const personalBests: Record<string,SavedResult> = {};
    for (const value of Object.values(record(data.personalBests))) {
      const result = validResult(value,fallbackVersion);
      if (result) addBest(personalBests,result);
    }
    for (const result of results) addBest(personalBests,result);
    return {
      preferences: {
        difficulty: DIFFICULTIES.includes(p.difficulty as Preferences['difficulty'])
          ? p.difficulty as Preferences['difficulty'] : defaults.difficulty,
        music: finiteVolume(p.music, defaults.music),
        effects: finiteVolume(p.effects, defaults.effects),
        motion: typeof p.motion === "boolean" ? p.motion : defaults.motion,
        practice: typeof p.practice === "boolean" ? p.practice : false,
      }, results, personalBests,
    };
  } catch {
    return {preferences:defaults,results:[],personalBests:{}};
  }
}

/** Adds a run without mutating the caller's history; a best survives the ten-row limit. */
export function recordResult(save: SavedData, result: SavedResult): SavedData {
  const valid = validResult(result,RESULT_RULES_VERSION);
  if (!valid) throw new Error('Invalid result');
  const personalBests = {...save.personalBests};
  addBest(personalBests,valid);
  return {...save,results:[...save.results,valid].slice(-10),personalBests};
}

export function writeSave(preferences: Preferences, results: SavedResult[], personalBests?: Record<string,SavedResult>): boolean {
  try {
    const previous = readSave();
    const bests: Record<string,SavedResult> = {};
    for (const value of [...Object.values(previous.personalBests),...Object.values(personalBests ?? {})]) {
      const result = validResult(value,RESULT_RULES_VERSION);
      if (result) addBest(bests,result);
    }
    const cleanResults = results.map(value => validResult(value,RESULT_RULES_VERSION)).filter((value): value is SavedResult => value !== null).slice(-10);
    for (const result of cleanResults) addBest(bests,result);
    localStorage.setItem(KEY,JSON.stringify({version:2,preferences,results:cleanResults,personalBests:bests}));
    return true;
  } catch {
    return false;
  }
}
