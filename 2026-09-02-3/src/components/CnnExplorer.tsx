import type { ComputationTrace } from '../ml/types'
import {
  channelContribution,
  conv1Kernel,
  conv2Kernel,
  featureChannel,
  maxPosition,
  type CnnTrace,
} from '../ml/cnn'

type Props = {
  trace: CnnTrace
  mlpTrace: ComputationTrace
  phaseIndex: number
  selectedChannel: number
  selectedSourceChannel: number
  selectedOutput: number
  onSelectChannel: (value: number) => void
  onSelectSourceChannel: (value: number) => void
  onSelectOutput: (value: number) => void
}

function Heatmap({ values, size, label, box }: { values: Float32Array; size: number; label: string; box?: { x: number; y: number; size: number } }) {
  const maximum = Math.max(...values, 0.000001)
  return (
    <span className="heatmap-wrap">
      <span className="heatmap" role="img" aria-label={label} style={{ gridTemplateColumns: `repeat(${size}, 1fr)` }}>
        {Array.from(values, (value, index) => {
          const level = Math.round(value / maximum * 255)
          return <i key={index} aria-hidden="true" style={{ backgroundColor: `rgb(${10 + level * 0.08}, ${22 + level * 0.55}, ${26 + level * 0.6})` }} />
        })}
      </span>
      {box && <span className="receptive-box" style={{ left: `${box.x / 28 * 100}%`, top: `${box.y / 28 * 100}%`, width: `${box.size / 28 * 100}%`, height: `${box.size / 28 * 100}%` }} />}
    </span>
  )
}

function Kernel({ values }: { values: Float32Array }) {
  const maximum = Math.max(...Array.from(values, Math.abs), 0.000001)
  return (
    <div className="kernel-grid" aria-label="選択した3×3カーネル">
      {Array.from(values, (value, index) => (
        <span key={index} className={value >= 0 ? 'kernel-cell kernel-cell--positive' : 'kernel-cell kernel-cell--negative'} style={{ opacity: 0.25 + Math.abs(value) / maximum * 0.75 }}>
          {value.toFixed(2)}
        </span>
      ))}
    </div>
  )
}

export function CnnExplorer({
  trace,
  mlpTrace,
  phaseIndex,
  selectedChannel,
  selectedSourceChannel,
  selectedOutput,
  onSelectChannel,
  onSelectSourceChannel,
  onSelectOutput,
}: Props) {
  if (phaseIndex === 0) {
    return (
      <section className="cnn-explorer cnn-explorer--input" aria-label="CNNへの空間入力">
        <div>
          <p className="section-number">SPATIAL INPUT / 28×28×1</p>
          <h3>784個へほどかず、隣り合うピクセルを保つ</h3>
          <p>この時点では特徴マップも予測結果もまだ表示しません。次の段階から3×3の窓が画像全体を走査します。</p>
        </div>
        <Heatmap values={trace.input} size={28} label="CNNへ渡す28×28入力" />
      </section>
    )
  }
  const stage = phaseIndex <= 1
    ? { name: 'CONV1', values: trace.conv1, size: 28, channels: 8 }
    : phaseIndex === 2
      ? { name: 'POOL1', values: trace.pool1, size: 14, channels: 8 }
      : phaseIndex === 3
        ? { name: 'CONV2', values: trace.conv2, size: 14, channels: 16 }
        : { name: 'POOL2', values: trace.pool2, size: 7, channels: 16 }
  const channel = Math.min(selectedChannel, stage.channels - 1)
  const selectedMap = featureChannel(stage.values, stage.size, stage.channels, channel)
  const maximum = maxPosition(selectedMap)
  const field = phaseIndex <= 1
    ? { x: maximum.x - 1, y: maximum.y - 1, size: 3 }
    : phaseIndex === 2
      ? { x: maximum.x * 2 - 1, y: maximum.y * 2 - 1, size: 4 }
      : phaseIndex === 3
        ? { x: maximum.x * 2 - 3, y: maximum.y * 2 - 3, size: 8 }
        : { x: maximum.x * 4 - 3, y: maximum.y * 4 - 3, size: 10 }
  const receptiveBox = {
    x: Math.max(0, Math.min(27, field.x)),
    y: Math.max(0, Math.min(27, field.y)),
    size: Math.min(
      Math.min(28, field.x + field.size) - Math.max(0, field.x),
      Math.min(28, field.y + field.size) - Math.max(0, field.y),
    ),
  }
  const kernel = phaseIndex <= 2
    ? conv1Kernel(trace.parameters, Math.min(channel, 7))
    : conv2Kernel(trace.parameters, selectedSourceChannel, channel)
  const contribution = channelContribution(trace, channel, selectedOutput)

  return (
    <section className="cnn-explorer" aria-label="CNNの特徴マップ観察">
      <div className="feature-stage">
        <div className="stage-heading">
          <span>{stage.name} / {stage.size}×{stage.size}×{stage.channels}</span>
          <small>各カードは別々の特徴検出器</small>
        </div>
        <div className="feature-map-list">
          {Array.from({ length: stage.channels }, (_, index) => {
            const values = featureChannel(stage.values, stage.size, stage.channels, index)
            return (
              <button type="button" key={index} className={index === channel ? 'feature-map feature-map--selected' : 'feature-map'} onClick={() => onSelectChannel(index)} aria-pressed={index === channel}>
                <Heatmap values={values} size={stage.size} label={`${stage.name} 特徴マップ${index + 1}`} />
                <span>MAP {String(index + 1).padStart(2, '0')}</span>
              </button>
            )
          })}
        </div>
      </div>

      <aside className="feature-inspector">
        <p className="section-number">ACTIVATION INSPECTOR</p>
        <h3>MAP {channel + 1} が最も反応した場所</h3>
        <div className="receptive-preview">
          <Heatmap values={trace.input} size={28} label="入力画像上の受容野" box={receptiveBox} />
          <div>
            <strong>x {maximum.x} / y {maximum.y}</strong>
            <span>活性値 {maximum.value.toFixed(5)}</span>
            <span>入力上のおよそ {receptiveBox.size}×{receptiveBox.size}</span>
          </div>
        </div>
        {phaseIndex >= 3 && (
          <label className="source-channel">
            カーネルの入力チャネル
            <select value={selectedSourceChannel} onChange={(event) => onSelectSourceChannel(Number(event.target.value))}>
              {Array.from({ length: 8 }, (_, index) => <option value={index} key={index}>POOL1 MAP {index + 1}</option>)}
            </select>
          </label>
        )}
        <Kernel values={kernel} />
        <p>明るさは各MAP内の最大値を基準にした相対表示です。枠はこの反応へ影響した入力範囲、3×3は実際のカーネル値です。</p>
        {phaseIndex >= 4 && <p className="contribution-readout">出力 {selectedOutput} へのMAP寄与 <strong>{contribution.toFixed(5)}</strong></p>}
      </aside>

      {phaseIndex >= 5 && <div className="model-comparison">
        <div className="comparison-heading">
          <div><span>SAME INPUT / TWO MODELS</span><strong>どちらが何%だと思ったか</strong></div>
          <small>両方とも実値。学習条件が違うため、精度競争ではありません</small>
        </div>
        <div className="comparison-table">
          {Array.from({ length: 10 }, (_, digit) => {
            const mlp = mlpTrace.forwardBefore.probabilities[digit]
            const cnn = trace.probabilities[digit]
            return (
              <button type="button" key={digit} aria-pressed={digit === selectedOutput} className={digit === selectedOutput ? 'comparison-row comparison-row--selected' : 'comparison-row'} onClick={() => onSelectOutput(digit)}>
                <strong>{digit}</strong>
                <span className="comparison-bar"><i style={{ width: `${mlp * 100}%` }} /></span><span>{(mlp * 100).toFixed(1)}%</span>
                <span className="comparison-bar comparison-bar--cnn"><i style={{ width: `${cnn * 100}%` }} /></span><span>{(cnn * 100).toFixed(1)}%</span>
              </button>
            )
          })}
        </div>
        <div className="comparison-legend"><span>全結合</span><span>CNN</span></div>
      </div>}
    </section>
  )
}
