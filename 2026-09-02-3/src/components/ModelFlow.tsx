import { useEffect, useRef } from 'react'
import type { CnnTrace } from '../ml/cnn'
import { flowActiveIndex } from '../ml/flow'
import type { ComputationTrace, ForwardSnapshot } from '../ml/types'

type ModelFamily = 'mlp' | 'cnn'

type Props = {
  model: ModelFamily
  phaseIndex: number
  mlpTrace: ComputationTrace | null
  cnnTrace: CnnTrace | null
  onSelectPhase: (phase: number) => void
}

type FlowLayer = {
  name: string
  operation: string
  shape: string
  value: string
  phase: number
  glyph: 'image' | 'vector' | 'nodes' | 'maps' | 'pool' | 'answer'
}

function maximum(values?: Float32Array) {
  return values?.length ? Math.max(...values) : 0
}

function activeCount(values?: Float32Array) {
  if (!values) return 0
  return values.reduce((count, value) => count + (value > 0 ? 1 : 0), 0)
}

function mlpForward(trace: ComputationTrace | null, phaseIndex: number): ForwardSnapshot | null {
  if (!trace) return null
  return trace.kind === 'guided-training' && phaseIndex >= 11 && trace.forwardAfter
    ? trace.forwardAfter
    : trace.forwardBefore
}

function layersForMlp(trace: ComputationTrace | null, phaseIndex: number): FlowLayer[] {
  const forward = mlpForward(trace, phaseIndex)
  const predicted = trace?.kind === 'guided-training' && phaseIndex >= 11
    ? trace.predictedClassAfter
    : trace?.predictedClassBefore
  return [
    { name: '入力画像', operation: '読む', shape: '28×28', value: trace ? `${activeCount(trace.input)} pixels ON` : '0〜1の明るさ', phase: 0, glyph: 'image' },
    { name: 'Flatten', operation: '1列に並べる', shape: '784', value: '28×28 → 784', phase: 0, glyph: 'vector' },
    { name: '全結合', operation: 'Σ 重み付き和', shape: '16', value: forward ? `最大 z ${maximum(forward.z1).toFixed(2)}` : '784本を集約', phase: 1, glyph: 'nodes' },
    { name: 'ReLU', operation: '負を0にする', shape: '16', value: forward ? `${activeCount(forward.a1)} / 16 active` : 'max(0, z)', phase: 2, glyph: 'nodes' },
    { name: 'Logits', operation: '10候補を採点', shape: '10', value: forward ? `最高 ${maximum(forward.logits).toFixed(2)}` : '数字0〜9', phase: 3, glyph: 'vector' },
    { name: 'Softmax', operation: '確率に変換', shape: '10', value: forward ? `最大 ${(maximum(forward.probabilities) * 100).toFixed(1)}%` : '合計100%', phase: 4, glyph: 'vector' },
    { name: '回答', operation: '最大を選ぶ', shape: '1', value: predicted === null || predicted === undefined ? '—' : `数字 ${predicted}`, phase: 5, glyph: 'answer' },
  ]
}

function layersForCnn(trace: CnnTrace | null): FlowLayer[] {
  return [
    { name: '入力画像', operation: '位置を保つ', shape: '28×28×1', value: trace ? `${activeCount(trace.input)} pixels ON` : '0〜1の明るさ', phase: 0, glyph: 'image' },
    { name: 'Conv1', operation: '3×3で走査', shape: '28×28×8', value: trace ? `${activeCount(trace.conv1)} active` : '8種類の検出器', phase: 1, glyph: 'maps' },
    { name: 'Pool1', operation: '2×2の最大', shape: '14×14×8', value: trace ? `${trace.pool1.length} values` : '面積を1/4へ', phase: 2, glyph: 'pool' },
    { name: 'Conv2', operation: '特徴を合成', shape: '14×14×16', value: trace ? `${activeCount(trace.conv2)} active` : '16種類の特徴', phase: 3, glyph: 'maps' },
    { name: 'Pool2', operation: '2×2の最大', shape: '7×7×16', value: trace ? `${trace.pool2.length} values` : '位置別の証拠', phase: 4, glyph: 'pool' },
    { name: 'Flatten', operation: '1列に並べる', shape: '784', value: '7×7×16 → 784', phase: 4, glyph: 'vector' },
    { name: 'Dense', operation: '10候補を採点', shape: '10', value: trace ? `最高 ${maximum(trace.logits).toFixed(2)}` : '数字0〜9', phase: 4, glyph: 'nodes' },
    { name: 'Softmax / 回答', operation: '確率→最大', shape: '10 → 1', value: trace ? `数字 ${trace.predictedClass} / ${(maximum(trace.probabilities) * 100).toFixed(1)}%` : '合計100%', phase: 5, glyph: 'answer' },
  ]
}

function LayerGlyph({ kind }: { kind: FlowLayer['glyph'] }) {
  return <span className={`flow-glyph flow-glyph--${kind}`} aria-hidden="true">
    {Array.from({ length: kind === 'maps' ? 3 : kind === 'nodes' ? 5 : kind === 'vector' ? 6 : kind === 'pool' ? 4 : 1 }, (_, index) => <i key={index} />)}
  </span>
}

export function ModelFlow({ model, phaseIndex, mlpTrace, cnnTrace, onSelectPhase }: Props) {
  const activeLayer = useRef<HTMLButtonElement | null>(null)
  const traceReady = model === 'mlp' ? Boolean(mlpTrace) : Boolean(cnnTrace)
  const layers = model === 'mlp' ? layersForMlp(mlpTrace, phaseIndex) : layersForCnn(cnnTrace)
  const activeIndex = flowActiveIndex(model, phaseIndex)
  const backward = model === 'mlp' ? phaseIndex >= 8 && phaseIndex <= 10 : phaseIndex >= 8 && phaseIndex <= 9

  useEffect(() => {
    if (!traceReady) return
    activeLayer.current?.scrollIntoView({
      behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
      block: 'nearest',
      inline: 'center',
    })
  }, [activeIndex, traceReady])

  return <section className="model-flow" aria-label={`${model.toUpperCase()}のデータと演算の流れ`}>
    <header className="model-flow__heading">
      <div><span>LIVE NETWORK MAP</span><strong>{model === 'mlp' ? '784個の値を、16個の考えへ集める' : '画像の位置を保ったまま、特徴を絞り込む'}</strong></div>
      <p><b>{backward ? 'BACKPROP ←' : 'FORWARD →'}</b>{traceReady ? '実traceの現在位置。層を選ぶと、その計算まで移動します。' : '開始前の回路図。計算すると実値が流れます。'}</p>
    </header>
    <div className="model-topology" aria-label="入力から回答までの接続構造">
      {layers.map((layer, index) => <div className="topology-step" key={`topology-${layer.name}`}>
        <div className={`topology-layer${index === activeIndex && traceReady ? ' topology-layer--active' : ''}`}>
          <LayerGlyph kind={layer.glyph} />
          {model === 'cnn' && index === 0 && <i className="topology-receptive-field" />}
          <strong>{layer.name}</strong><small>{layer.shape}</small>
        </div>
        {index < layers.length - 1 && <span className="topology-links" aria-hidden="true"><i /><i /><i /></span>}
      </div>)}
    </div>
    {model === 'cnn' && <p className="receptive-legend"><i /> <strong>黄色い枠 = 受容野</strong>　次の層の「選んだ1点」を計算するために使われた、元画像の範囲です。層が深くなるほど範囲が広がります。</p>}
    <div className={`model-flow__rail${backward ? ' model-flow__rail--backward' : ''}`}>
      {layers.map((layer, index) => {
        const state = !traceReady ? 'waiting' : index === activeIndex ? 'active' : index < activeIndex || backward ? 'passed' : 'waiting'
        return <div className="flow-step" key={`${model}-${layer.name}`}>
          <button ref={state === 'active' ? activeLayer : undefined} type="button" className={`flow-layer flow-layer--${state}`} onClick={() => onSelectPhase(layer.phase)} disabled={!traceReady} aria-current={state === 'active' ? 'step' : undefined}>
            <span className="flow-layer__state">{state === 'active' ? 'いま計算中' : state === 'passed' ? '通過済み' : 'この先'}</span>
            <LayerGlyph kind={layer.glyph} />
            <strong>{layer.name}</strong>
            <small>{layer.operation}</small>
            <code>{layer.shape}</code>
            <em>{layer.value}</em>
          </button>
          {index < layers.length - 1 && <span className={`flow-connector flow-connector--${state}`} aria-hidden="true"><i /></span>}
        </div>
      })}
    </div>
    <span className="model-flow__swipe">← 横へスワイプして全レイヤーを見る →</span>
  </section>
}
