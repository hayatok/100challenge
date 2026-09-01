import { applySuggestion, changeAllocation, changePolicy, confirmLevelUp, policyLabel } from '../game/simulation'
import type { GameState, Policy, StatKey } from '../game/types'

type LevelUpOverlayProps = {
  state: GameState
  onChange: (next: GameState) => void
}

const stats: Array<{ key: StatKey; label: string; note: string }> = [
  { key: 'strength', label: '腕力', note: '与ダメージ' },
  { key: 'vitality', label: '体力', note: '最大HP・防御' },
  { key: 'speed', label: 'すばやさ', note: '回避・手数' },
  { key: 'luck', label: '運', note: '会心・番狂わせ' },
]

export default function LevelUpOverlay({ state, onChange }: LevelUpOverlayProps) {
  return (
    <div className="overlay-backdrop" role="presentation">
      <section className="review-sheet" role="dialog" aria-modal="true" aria-labelledby="review-title">
        <p className="level-stamp">LEVEL UP!</p>
        <p className="eyebrow">ROYAL PERSONNEL REVIEW</p>
        <h2 id="review-title">のうりょく査定</h2>
        <div className="remaining-points">のこり <strong>{state.pendingPoints}pt</strong></div>
        <div className="stat-list">
          {stats.map((stat) => {
            const base = state.hero[stat.key]
            const added = state.allocations[stat.key]
            return (
              <div className="stat-row" key={stat.key}>
                <span className="stat-copy"><strong>{stat.label}</strong><small>{stat.note}</small></span>
                <span className="stat-value">{base}{added > 0 && <b>+{added}</b>}</span>
                <button type="button" aria-label={`${stat.label}を1下げる`} disabled={added === 0} onClick={() => onChange(changeAllocation(state, stat.key, -1))}>−</button>
                <button type="button" aria-label={`${stat.label}を1上げる`} disabled={state.pendingPoints === 0} onClick={() => onChange(changeAllocation(state, stat.key, 1))}>＋</button>
              </div>
            )
          })}
        </div>
        <fieldset className="review-policy">
          <legend>次の攻略方針</legend>
          <div>{(['safe', 'xp', 'deep'] as Policy[]).map((policy) => (
            <button key={policy} type="button" aria-pressed={state.policy === policy} onClick={() => onChange(changePolicy(state, policy))}>{policyLabel(policy)}</button>
          ))}</div>
        </fieldset>
        <div className="review-actions">
          <button type="button" className="suggest-button" onClick={() => onChange(applySuggestion(state))}>局のおすすめ配分</button>
          <button type="button" className="confirm-button" disabled={state.pendingPoints !== 0} onClick={() => onChange(confirmLevelUp(state))}>査定を承認する</button>
        </div>
      </section>
    </div>
  )
}
