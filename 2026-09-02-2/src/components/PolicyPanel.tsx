import { canChangePolicy, changePolicy, policyLabel, threatEstimate } from '../game/simulation'
import type { GameState, Policy } from '../game/types'

type PolicyPanelProps = {
  state: GameState
  onChange: (next: GameState) => void
}

const policyDetails: Record<Policy, { short: string; detail: string; mark: string }> = {
  safe: { short: '格下と回復を優先', detail: '危険な敵を避け、HP45%で退却', mark: '盾' },
  xp: { short: '経験値効率を優先', detail: 'エリートも狙い、HP30%で退却', mark: 'EXP' },
  deep: { short: '階段へ直行', detail: '不要戦闘を避け、HP20%まで前進', mark: '階' },
}

export default function PolicyPanel({ state, onChange }: PolicyPanelProps) {
  const changeable = canChangePolicy(state) && !state.autoMode
  return (
    <section className="policy-panel" aria-labelledby="policy-title">
      <div className="panel-title-row">
        <div>
          <p className="eyebrow">FIELD DIRECTIVE</p>
          <h2 id="policy-title">攻略方針</h2>
        </div>
        <span className="approval-stamp">局認</span>
      </div>
      <p className="policy-timing">{state.autoMode ? '全自動局長が状況に応じて変更します' : changeable ? 'いま変更できます' : '次の査定・階段前で変更できます'}</p>
      <div className="policy-options">
        {(Object.keys(policyDetails) as Policy[]).map((policy) => {
          const detail = policyDetails[policy]
          const selected = state.policy === policy
          return (
            <button
              key={policy}
              type="button"
              className={`policy-button policy-${policy}${selected ? ' selected' : ''}`}
              aria-pressed={selected}
              disabled={!changeable}
              onClick={() => onChange(changePolicy(state, policy))}
            >
              <span className="policy-mark">{detail.mark}</span>
              <span className="policy-copy">
                <strong>{policyLabel(policy)}</strong>
                <small>{detail.short}</small>
              </span>
              <span className="survival-rate"><b>{threatEstimate(state, policy)}%</b> 生還見込</span>
            </button>
          )
        })}
      </div>
      <p className="policy-detail">現在: <strong>{policyLabel(state.policy)}</strong> — {policyDetails[state.policy].detail}</p>
    </section>
  )
}
