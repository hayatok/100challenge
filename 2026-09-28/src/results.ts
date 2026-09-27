import { resultKey, type SavedResult } from './storage.ts';

export type Grade = 'S'|'A'|'B'|'C'|'D';

/** Grades the quality of a run separately from its score. Retries limit S/A. */
export function gradeResult(result: Pick<SavedResult,'cleared'|'accuracy'|'combo'|'retries'>): Grade {
  if (!result.cleared) return 'D';
  if (result.accuracy >= 0.98 && result.combo >= 15 && result.retries === 0) return 'S';
  if (result.accuracy >= 0.94 && result.combo >= 9 && result.retries <= 1) return 'A';
  if (result.accuracy >= 0.85 && result.combo >= 5) return 'B';
  return 'C';
}

/** Pass the history before adding current, so the previous run is unambiguous. */
export function previousComparable(history: readonly SavedResult[], current: SavedResult): SavedResult|null {
  const key = resultKey(current);
  for (let i=history.length-1;i>=0;i--) {
    if (resultKey(history[i]) === key) return history[i];
  }
  return null;
}

export type ResultComparison = {
  previous: SavedResult;
  scoreDelta: number;
  comboDelta: number;
  accuracyDelta: number;
  secondsDelta: number;
};
export function compareResults(current: SavedResult, previous: SavedResult|null): ResultComparison|null {
  if (!previous || resultKey(current) !== resultKey(previous)) return null;
  return {
    previous,
    scoreDelta:current.score-previous.score,
    comboDelta:current.combo-previous.combo,
    accuracyDelta:current.accuracy-previous.accuracy,
    secondsDelta:current.seconds-previous.seconds,
  };
}
