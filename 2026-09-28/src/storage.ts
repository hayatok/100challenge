export type Preferences = {
  difficulty: "relaxed" | "normal" | "fierce";
  music: number;
  effects: number;
  motion: boolean;
  practice: boolean;
};
export type SavedResult = {
  score: number;
  combo: number;
  accuracy: number;
  seconds: number;
  cleared: boolean;
  difficulty: string;
  practice: boolean;
  retries: number;
  date: string;
};
export const defaultPreferences = (): Preferences => ({
  difficulty: "normal",
  music: 0.45,
  effects: 0.75,
  motion: !matchMedia("(prefers-reduced-motion: reduce)").matches,
  practice: false,
});
const KEY = "nightshift-typing:v1";
export function readSave(): {
  preferences: Preferences;
  results: SavedResult[];
} {
  const defaults = defaultPreferences();
  try {
    const data = JSON.parse(localStorage.getItem(KEY) ?? "{}");
    const p = data.preferences ?? {};
    return {
      preferences: {
        difficulty: ["relaxed", "normal", "fierce"].includes(p.difficulty)
          ? p.difficulty
          : defaults.difficulty,
        music: finiteVolume(p.music, defaults.music),
        effects: finiteVolume(p.effects, defaults.effects),
        motion: typeof p.motion === "boolean" ? p.motion : defaults.motion,
        practice: typeof p.practice === "boolean" ? p.practice : false,
      },
      results: Array.isArray(data.results)
        ? data.results
            .filter(
              (r: SavedResult) =>
                r && Number.isFinite(r.score) && typeof r.date === "string",
            )
            .slice(-10)
        : [],
    };
  } catch {
    return { preferences: defaults, results: [] };
  }
}
function finiteVolume(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.min(1, value))
    : fallback;
}
export function writeSave(preferences: Preferences, results: SavedResult[]) {
  try {
    localStorage.setItem(
      KEY,
      JSON.stringify({ version: 1, preferences, results: results.slice(-10) }),
    );
    return true;
  } catch {
    return false;
  }
}
