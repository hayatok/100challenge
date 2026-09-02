import type { KeyboardEvent, MouseEvent } from 'react'
import { conv1CellBreakdown, conv1Kernel, conv2CellBreakdown, conv2Kernel, evidenceMap, featureChannel, maxPosition, poolCellBreakdown, type CnnTrace, type CnnTrainingTrace } from '../ml/cnn'

export type MapScale = 'local' | 'global'
export type MapPoint = { x: number; y: number }

type Props = {
  trace: CnnTrace
  occludedTrace: CnnTrace | null
  trainingTrace: CnnTrainingTrace | null
  phaseIndex: number
  selectedChannel: number
  selectedSourceChannel: number
  selectedOutput: number
  selectedPoint: MapPoint | null
  scaleMode: MapScale
  onSelectChannel: (value: number) => void
  onSelectSourceChannel: (value: number) => void
  onSelectOutput: (value: number) => void
  onSelectPoint: (value: MapPoint) => void
  onScaleMode: (value: MapScale) => void
  onOcclude: (box: { x: number; y: number; size: number }) => void
  onClearOcclusion: () => void
}

function Heatmap({ values, size, label, maximum, signed = false, box, point }: {
  values: Float32Array
  size: number
  label: string
  maximum?: number
  signed?: boolean
  box?: { x: number; y: number; size: number }
  point?: MapPoint
}) {
  const scale = maximum ?? Math.max(...Array.from(values, Math.abs), 0.000001)
  return (
    <span className="heatmap-wrap">
      <span className="heatmap" role="img" aria-label={label} style={{ gridTemplateColumns: `repeat(${size}, 1fr)` }}>
        {Array.from(values, (value, index) => {
          const level = Math.min(1, Math.abs(value) / scale)
          const color = signed
            ? value >= 0 ? `rgb(${18 + level * 30}, ${30 + level * 150}, ${34 + level * 155})` : `rgb(${45 + level * 155}, ${25 + level * 35}, ${42 + level * 80})`
            : `rgb(${10 + level * 20}, ${22 + level * 140}, ${26 + level * 153})`
          return <i key={index} aria-hidden="true" style={{ backgroundColor: color }} />
        })}
      </span>
      {box && <span className="receptive-box" style={{ left: `${box.x / 28 * 100}%`, top: `${box.y / 28 * 100}%`, width: `${box.size / 28 * 100}%`, height: `${box.size / 28 * 100}%` }} />}
      {point && <span className="map-point" style={{ left: `${point.x / size * 100}%`, top: `${point.y / size * 100}%`, width: `${100 / size}%`, height: `${100 / size}%` }} />}
    </span>
  )
}

function Kernel({ values }: { values: Float32Array }) {
  const maximum = Math.max(...Array.from(values, Math.abs), 0.000001)
  return <div className="kernel-grid" aria-label="選択した3×3カーネル">{Array.from(values, (value, index) => <span key={index} className={value >= 0 ? 'kernel-cell kernel-cell--positive' : 'kernel-cell kernel-cell--negative'} style={{ opacity: 0.25 + Math.abs(value) / maximum * 0.75 }}>{value.toFixed(2)}</span>)}</div>
}

function LocalCalculation({ values, weights, products, bias, sum, activated, sourceSubtotal }: { values: number[]; weights: number[]; products: number[]; bias: number; sum: number; activated: number; sourceSubtotal?: number }) {
  return <div className="local-calculation">
    <p className="section-number">LOCAL 3×3 CALCULATION</p>
    <div className="term-grid">{values.map((value, index) => <span key={index}><small>{value.toFixed(2)} × {weights[index].toFixed(2)}</small><strong>{products[index].toFixed(3)}</strong></span>)}</div>
    <div className="calculation-result">
      {sourceSubtotal !== undefined && <span>選択チャネル小計 <strong>{sourceSubtotal.toFixed(5)}</strong></span>}
      <span>bias <strong>{bias.toFixed(5)}</strong></span><span>全チャネル合計 <strong>{sum.toFixed(5)}</strong></span><span>ReLU後 <strong>{activated.toFixed(5)}</strong></span>
    </div>
  </div>
}

function pointFromEvent(event: MouseEvent<HTMLButtonElement>, size: number): MapPoint {
  const rect = event.currentTarget.getBoundingClientRect()
  return { x: Math.max(0, Math.min(size - 1, Math.floor((event.clientX - rect.left) / rect.width * size))), y: Math.max(0, Math.min(size - 1, Math.floor((event.clientY - rect.top) / rect.height * size))) }
}

export function CnnExplorer({ trace, occludedTrace, trainingTrace, phaseIndex, selectedChannel, selectedSourceChannel, selectedOutput, selectedPoint, scaleMode, onSelectChannel, onSelectSourceChannel, onSelectOutput, onSelectPoint, onScaleMode, onOcclude, onClearOcclusion }: Props) {
  if (phaseIndex === 0) return <section className="cnn-explorer cnn-explorer--input" aria-label="CNNへの空間入力"><div><p className="section-number">SPATIAL INPUT / 28×28×1</p><h3>画像をバラさず、位置関係ごと読む</h3><p>隣り合うピクセルを保ったまま、3×3の小さな窓で調べます。まだ特徴マップも予測結果も表示しません。</p></div><Heatmap values={trace.input} size={28} label="CNNへ渡す28×28入力" /></section>

  const stage = phaseIndex === 1 ? { name: 'CONV1', values: trace.conv1, size: 28, channels: 8 } : phaseIndex === 2 ? { name: 'POOL1', values: trace.pool1, size: 14, channels: 8 } : phaseIndex === 3 ? { name: 'CONV2', values: trace.conv2, size: 14, channels: 16 } : { name: 'POOL2', values: trace.pool2, size: 7, channels: 16 }
  const channel = Math.min(selectedChannel, stage.channels - 1)
  const selectedMap = featureChannel(stage.values, stage.size, stage.channels, channel)
  const maximumPoint = maxPosition(selectedMap)
  const point = { x: Math.min(stage.size - 1, selectedPoint?.x ?? maximumPoint.x), y: Math.min(stage.size - 1, selectedPoint?.y ?? maximumPoint.y) }
  const rawField = phaseIndex === 1 ? { x: point.x - 1, y: point.y - 1, size: 3 } : phaseIndex === 2 ? { x: point.x * 2 - 1, y: point.y * 2 - 1, size: 4 } : phaseIndex === 3 ? { x: point.x * 2 - 3, y: point.y * 2 - 3, size: 8 } : { x: point.x * 4 - 3, y: point.y * 4 - 3, size: 10 }
  const receptiveBox = { x: Math.max(0, rawField.x), y: Math.max(0, rawField.y), size: Math.max(1, Math.min(Math.min(28, rawField.x + rawField.size) - Math.max(0, rawField.x), Math.min(28, rawField.y + rawField.size) - Math.max(0, rawField.y))) }
  const displayMaximum = scaleMode === 'global' ? Math.max(...stage.values, 0.000001) : undefined
  const kernel = phaseIndex <= 2 ? conv1Kernel(trace.parameters, Math.min(channel, 7)) : conv2Kernel(trace.parameters, selectedSourceChannel, channel)
  const convolution = phaseIndex === 1 ? conv1CellBreakdown(trace, channel, point.x, point.y) : phaseIndex === 3 ? conv2CellBreakdown(trace, selectedSourceChannel, channel, point.x, point.y) : null
  const pooling = phaseIndex === 2 ? poolCellBreakdown(trace, 'pool1', channel, point.x, point.y) : null
  const evidence = evidenceMap(trace, selectedOutput)
  const evidenceSum = evidence.reduce((sum, value) => sum + value, trace.parameters.denseBias[selectedOutput])
  const movePoint = (event: KeyboardEvent<HTMLButtonElement>) => {
    const directions: Record<string, MapPoint> = { ArrowLeft: { x: point.x - 1, y: point.y }, ArrowRight: { x: point.x + 1, y: point.y }, ArrowUp: { x: point.x, y: point.y - 1 }, ArrowDown: { x: point.x, y: point.y + 1 } }
    const next = directions[event.key]
    if (!next) return
    event.preventDefault()
    onSelectPoint({ x: Math.max(0, Math.min(stage.size - 1, next.x)), y: Math.max(0, Math.min(stage.size - 1, next.y)) })
  }

  return <section className="cnn-explorer" aria-label="CNNの特徴マップ観察">
    <div className="feature-stage">
      <div className="stage-heading"><span>{stage.name} / {stage.size}×{stage.size}×{stage.channels}</span><div className="scale-switch" aria-label="特徴マップの明るさ基準"><button type="button" aria-pressed={scaleMode === 'local'} onClick={() => onScaleMode('local')}>各MAP</button><button type="button" aria-pressed={scaleMode === 'global'} onClick={() => onScaleMode('global')}>共通尺度</button></div></div>
      <p className="scale-note">{scaleMode === 'local' ? '形を見やすくするため、MAPごとに最大値を明るさ100%にしています。' : '全MAPで同じ明るさ基準。反応の強さを正しく比較できます。'}</p>
      <div className="feature-map-list">{Array.from({ length: stage.channels }, (_, index) => { const values = featureChannel(stage.values, stage.size, stage.channels, index); return <button type="button" key={index} className={index === channel ? 'feature-map feature-map--selected' : 'feature-map'} onClick={() => onSelectChannel(index)} aria-pressed={index === channel}><Heatmap values={values} size={stage.size} maximum={displayMaximum} label={`${stage.name} 特徴マップ${index + 1}`} /><span>MAP {String(index + 1).padStart(2, '0')}</span></button> })}</div>
    </div>
    <aside className="feature-inspector">
      <p className="section-number">SPATIAL PROBE</p><h3>MAP {channel + 1} の座標 x {point.x} / y {point.y}</h3>
      <button type="button" className="focused-heatmap" aria-label="特徴マップ上の調査位置を選ぶ" onClick={(event) => onSelectPoint(pointFromEvent(event, stage.size))} onKeyDown={movePoint}><Heatmap values={selectedMap} size={stage.size} maximum={displayMaximum} label="選択中の特徴マップ" point={point} /></button>
      <p>マップをクリック、または矢印キーで調べる座標を動かせます。</p>
      <div className="receptive-preview"><Heatmap values={trace.input} size={28} label="入力画像上の受容野" box={receptiveBox} /><div><strong>入力上のおよそ {receptiveBox.size}×{receptiveBox.size}</strong><span>黄色い枠が、この1点へ影響した入力範囲です。</span></div></div>
      {phaseIndex === 3 && <label className="source-channel">カーネルの入力チャネル<select value={selectedSourceChannel} onChange={(event) => onSelectSourceChannel(Number(event.target.value))}>{Array.from({ length: 8 }, (_, index) => <option value={index} key={index}>POOL1 MAP {index + 1}</option>)}</select></label>}
      {(phaseIndex === 1 || phaseIndex === 3) && <Kernel values={kernel} />}
    </aside>
    {convolution && <LocalCalculation values={convolution.terms.map((term) => term.value)} weights={convolution.terms.map((term) => term.weight)} products={convolution.terms.map((term) => term.product)} bias={convolution.bias} sum={convolution.sum} activated={convolution.activated} sourceSubtotal={phaseIndex === 3 ? (convolution as ReturnType<typeof conv2CellBreakdown>).sourceSubtotal : undefined} />}
    {pooling && <div className="pool-calculation"><p className="section-number">MAX POOL / REAL VALUES</p><div className="pool-values">{Array.from(pooling.values, (value, index) => <span className={index === pooling.winner ? 'pool-value pool-value--winner' : 'pool-value'} key={index}>{value.toFixed(5)}</span>)}</div><strong>最大値 {pooling.maximum.toFixed(5)} を次へ残す</strong></div>}
    {phaseIndex >= 4 && <div className="evidence-panel"><div className="evidence-copy"><p className="section-number">CLASS EVIDENCE / 7×7</p><h3>数字 {selectedOutput} だと思った場所</h3><p>シアンは数字 {selectedOutput} を支持し、ピンクは打ち消した位置です。49セルとbiasの合計が実際のlogitに一致します。</p><div className="digit-picker" aria-label="証拠を調べる数字">{Array.from({ length: 10 }, (_, digit) => <button type="button" key={digit} aria-pressed={digit === selectedOutput} onClick={() => onSelectOutput(digit)}>{digit}</button>)}</div></div><div className="evidence-map"><Heatmap values={evidence} size={7} signed label={`数字${selectedOutput}への位置別寄与`} /></div><dl><div><dt>49位置 + bias</dt><dd>{evidenceSum.toFixed(6)}</dd></div><div><dt>モデルのlogit</dt><dd>{trace.logits[selectedOutput].toFixed(6)}</dd></div><div><dt>差</dt><dd>{Math.abs(evidenceSum - trace.logits[selectedOutput]).toExponential(2)}</dd></div></dl></div>}
    {phaseIndex >= 5 && <div className="cnn-result"><div><p className="section-number">CNN ANSWER</p><h3>モデルの回答は {trace.predictedClass}</h3><p>表示値はCNN単体のSoftmax出力です。</p></div><div className="cnn-probabilities">{Array.from(trace.probabilities, (probability, digit) => <button type="button" key={digit} aria-pressed={digit === selectedOutput} onClick={() => onSelectOutput(digit)}><strong>{digit}</strong><span><i style={{ width: `${probability * 100}%` }} /></span><em>{(probability * 100).toFixed(1)}%</em></button>)}</div><div className="occlusion-lab"><p className="section-number">OCCLUSION TEST</p><strong>黄色い受容野を黒く塗って、もう一度読む</strong><button type="button" className="button button--update" onClick={() => onOcclude(receptiveBox)}>この範囲を隠して再推論</button>{occludedTrace && <div className="occlusion-result"><span>元: {trace.predictedClass} / {(trace.probabilities[selectedOutput] * 100).toFixed(1)}%</span><span>遮蔽後: {occludedTrace.predictedClass} / {(occludedTrace.probabilities[selectedOutput] * 100).toFixed(1)}%</span><button type="button" onClick={onClearOcclusion}>遮蔽結果を消す</button></div>}</div></div>}
    {trainingTrace && phaseIndex >= 6 && <div className="cnn-learning-trace">
      <div><p className="section-number">REAL CNN TRAINING</p><h3>正解 {trainingTrace.before.label} へ、誤差を戻す</h3></div>
      <dl>
        <div><dt>更新前</dt><dd>{trainingTrace.before.predictedClass} / {(trainingTrace.before.probabilities[trainingTrace.before.label ?? 0] * 100).toFixed(1)}%</dd></div>
        <div><dt>cross entropy</dt><dd>{trainingTrace.lossBefore.toFixed(6)}</dd></div>
        {phaseIndex >= 8 && <div><dt>平均 |gradient|</dt><dd>{trainingTrace.gradientMeanAbs.toExponential(3)}</dd></div>}
        {phaseIndex >= 9 && <div><dt>平均 |Δweight|</dt><dd>{trainingTrace.updateMeanAbs.toExponential(3)}</dd></div>}
        {phaseIndex >= 10 && <div><dt>更新後</dt><dd>{trainingTrace.after.predictedClass} / {(trainingTrace.after.probabilities[trainingTrace.after.label ?? 0] * 100).toFixed(1)}%</dd></div>}
      </dl>
    </div>}
  </section>
}
