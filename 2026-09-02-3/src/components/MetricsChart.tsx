import type { TrainingMetric } from '../ml/types'

export function MetricsChart({ metrics }: { metrics: TrainingMetric[] }) {
  if (metrics.length === 0) return null
  const width = 560
  const height = 100
  const maxLoss = Math.max(...metrics.map((metric) => metric.batchLoss), 0.1)
  const points = metrics.map((metric, index) => {
    const x = metrics.length === 1 ? 0 : index / (metrics.length - 1) * width
    const y = height - metric.batchLoss / maxLoss * (height - 8)
    return `${x},${y}`
  }).join(' ')
  const latest = metrics.at(-1)!
  return (
    <section className="metrics" aria-label="まとめ学習の実測値">
      <div className="metrics__heading">
        <div><span>処理済み</span><strong>{latest.processed} / 500件</strong></div>
        <div><span>直近batch loss</span><strong>{latest.batchLoss.toFixed(4)}</strong></div>
        <div><span>test subset正答率</span><strong>{latest.testAccuracy === null ? '評価待ち' : `${(latest.testAccuracy * 100).toFixed(1)}%`}</strong></div>
      </div>
      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="実測したbatch lossの推移">
        <line x1="0" y1={height - 1} x2={width} y2={height - 1} />
        <polyline points={points} />
      </svg>
      <p>LOSS / 実測したbatch境界だけを接続</p>
    </section>
  )
}
