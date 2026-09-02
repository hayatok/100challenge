import type { ComputationTrace, ForwardSnapshot } from '../ml/types'

type Props = {
  trace: ComputationTrace | null
  phaseIndex: number
  selectedHidden: number
  selectedOutput: number
  onSelectHidden: (index: number) => void
  onSelectOutput: (index: number) => void
}

function maxAbs(values: Float32Array) {
  return Math.max(...Array.from(values, Math.abs), 0.000001)
}

function activeForward(trace: ComputationTrace, phaseIndex: number): ForwardSnapshot {
  if (trace.kind === 'guided-training' && phaseIndex >= 11 && trace.forwardAfter) {
    return trace.forwardAfter
  }
  return trace.forwardBefore
}

export function NetworkDiagram({
  trace,
  phaseIndex,
  selectedHidden,
  selectedOutput,
  onSelectHidden,
  onSelectOutput,
}: Props) {
  const forward = trace ? activeForward(trace, phaseIndex) : null
  const parameters = trace?.kind === 'guided-training' && phaseIndex >= 11 && trace.parametersAfter
    ? trace.parametersAfter
    : trace?.parametersBefore
  const activations = trace && phaseIndex >= 2 ? forward?.a1 ?? new Float32Array(16) : new Float32Array(16)
  const outputMode = trace && phaseIndex === 3 ? 'logits' : trace && phaseIndex >= 4 ? 'probabilities' : 'waiting'
  const outputs = outputMode === 'logits'
    ? forward?.logits ?? new Float32Array(10)
    : outputMode === 'probabilities'
      ? forward?.probabilities ?? new Float32Array(10)
      : new Float32Array(10)
  const activationMax = maxAbs(activations)
  const contributions = trace
    ? Float32Array.from({ length: 16 }, (_, hidden) =>
        activations[hidden] * (parameters?.w2[hidden * 10 + selectedOutput] ?? 0))
    : new Float32Array(16)
  const connectionMode = trace?.kind === 'guided-training' && (phaseIndex === 8 || phaseIndex === 9)
    ? 'gradient'
    : trace?.kind === 'guided-training' && phaseIndex === 10
      ? 'update'
      : 'contribution'
  const connectionValues = connectionMode === 'gradient'
    ? trace?.gradients?.w2.filter((_, index) => index % 10 === selectedOutput) ?? new Float32Array(16)
    : connectionMode === 'update'
      ? trace?.updates?.w2.filter((_, index) => index % 10 === selectedOutput) ?? new Float32Array(16)
      : contributions
  const connectionMax = maxAbs(connectionValues)
  const showConnections = Boolean(trace && phaseIndex >= 3)
  const outputMax = maxAbs(outputs)

  return (
    <div className="network-diagram" aria-label="隠れ層から出力層までの実計算">
      <div className="network-canvas">
        <svg viewBox="0 0 360 270" role="img" aria-label={`隠れ層16個と出力10個。出力${selectedOutput}を選択中`}>
          {showConnections && Array.from(connectionValues, (value, index) => {
            const hiddenY = 14 + index * 16.2
            const outputY = 18 + selectedOutput * 25.5
            return (
              <line
                key={`connection-${index}`}
                x1="86"
                y1={hiddenY}
                x2="205"
                y2={outputY}
                className={value >= 0 ? 'connection connection--positive' : 'connection connection--negative'}
                strokeWidth={0.7 + Math.abs(value) / connectionMax * 4}
              />
            )
          })}
          {Array.from(activations, (value, index) => {
            const y = 14 + index * 16.2
            const selected = index === selectedHidden
            return (
              <g
                key={`hidden-${index}`}
                role="button"
                tabIndex={0}
                aria-label={`隠れニューロン${index + 1} 活性値${value.toFixed(4)}`}
                aria-pressed={selected}
                onClick={() => onSelectHidden(index)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault()
                    onSelectHidden(index)
                  }
                }}
                className={selected ? 'hidden-node hidden-node--selected' : 'hidden-node'}
              >
                <circle cx="72" cy={y} r="6.5" />
                <circle cx="72" cy={y} r={Math.max(1, value / activationMax * 5)} className="hidden-node__fill" />
                <text x="58" y={y + 3.5}>{index + 1}</text>
              </g>
            )
          })}
        </svg>
        <span className="network-label network-label--hidden">HIDDEN 16</span>
        <span className="network-label network-label--output">OUTPUT 0–9</span>
        <div className="output-list" aria-label={outputMode === 'logits' ? '数字ごとのlogit' : '数字ごとのSoftmax確率'}>
          {Array.from(outputs, (value, digit) => (
            <button
              type="button"
              key={digit}
              className={digit === selectedOutput ? 'output-row output-row--selected' : 'output-row'}
              onClick={() => onSelectOutput(digit)}
              aria-pressed={digit === selectedOutput}
            >
              <strong>{digit}</strong>
              <span className="output-meter" aria-hidden="true">
                <span
                  className={outputMode === 'logits' && value < 0 ? 'output-meter__negative' : undefined}
                  style={{ width: `${outputMode === 'probabilities' ? Math.max(1, value * 100) : Math.max(1, Math.abs(value) / outputMax * 100)}%` }}
                />
              </span>
              <span>{outputMode === 'probabilities' ? `${(value * 100).toFixed(1)}%` : outputMode === 'logits' ? value.toFixed(2) : '—'}</span>
            </button>
          ))}
        </div>
      </div>
      <p className="network-legend">
        <span><i className="legend-line legend-line--positive" />正の寄与</span>
        <span><i className="legend-line legend-line--negative" />負の寄与</span>
        <small>線幅は選択した出力への{connectionMode === 'gradient' ? '勾配' : connectionMode === 'update' ? '更新量' : '寄与'}を、この層内で相対表示</small>
      </p>
    </div>
  )
}
