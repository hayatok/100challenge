import type { SavedResult } from './storage.ts';

export type NextGoal = { title: string; detail: string };

/** One observable objective for the next run, based only on recorded facts. */
export function nextGoal(result: SavedResult): NextGoal {
  if (!result.cleared) {
    return {title:'次は勤務を完走',detail:'同じ難易度で最後までたどり着こう。'};
  }
  if (result.rushes === 0) {
    return {title:'ラッシュを1回決める',detail:'敵を撃破してゲージをため、短文ラッシュへ進もう。'};
  }
  if (result.chainKills === 0) {
    return {title:'連鎖撃破を1回',detail:'爆発する敵を、隣の敵がいるときに倒そう。'};
  }
  const nextCombo = [3,6,10,15].find(boundary => result.combo < boundary);
  if (nextCombo !== undefined) {
    return {title:`最大コンボ${nextCombo}へ`,detail:`次は${nextCombo}体を続けて、きれいに撃破しよう。`};
  }
  const nextAccuracy = [0.9,0.95,0.98,1].find(boundary => result.accuracy < boundary);
  if (nextAccuracy !== undefined) {
    const percentage = Math.round(nextAccuracy * 100);
    return {title:`正確率${percentage}%へ`,detail:'落ち着いて、入力ミスを少し減らそう。'};
  }
  if (result.retries > 0) {
    return {title:'リトライなしで完走',detail:'同じ難易度を、一度も倒れずに抜けよう。'};
  }
  return {title:'次も正確に完走',detail:'今夜の調子を、もう一度続けよう。'};
}
