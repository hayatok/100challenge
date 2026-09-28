export type Preferences = {
  difficulty: "relaxed" | "normal" | "fierce";
  music: number;
  effects: number;
  motion: boolean;
  practice: boolean;
};
export const RESULT_RULES_VERSION = 3;
export type SavedResult = {
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
  return {
    score:r.score,combo:r.combo,accuracy:r.accuracy,seconds:r.seconds,
    cleared:r.cleared,difficulty:r.difficulty as Preferences['difficulty'],
    practice:r.practice,retries:r.retries,date:r.date,rulesVersion:rulesVersion as number,
  };
}

export function resultKey(result: Pick<SavedResult,'difficulty'|'practice'|'rulesVersion'>): string {
  return `${result.rulesVersion}:${result.difficulty}:${result.practice ? 'practice' : 'standard'}`;
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
    const fallbackVersion = data.version === 2 ? RESULT_RULES_VERSION : 2;
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
