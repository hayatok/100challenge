import { useEffect, useMemo, useRef, useState } from 'react'
import * as tf from '@tensorflow/tfjs'
import { DrawingPad, type DrawingPadHandle } from './components/DrawingPad'
import { CnnExplorer } from './components/CnnExplorer'
import { MetricsChart } from './components/MetricsChart'
import { NetworkDiagram } from './components/NetworkDiagram'
import { PixelGrid } from './components/PixelGrid'
import { PlaybackControls } from './components/PlaybackControls'
import { loadCnnModel, loadManifest, loadSplit, loadWeights, type DataManifest } from './ml/dataset'
import { CnnVisualModel, type CnnModelDefinition, type CnnTrace } from './ml/cnn'
import { preprocessDrawing } from './ml/drawing'
import { VisualModel } from './ml/model'
import type { ComputationTrace, MnistSample, TrainingMetric } from './ml/types'

type Mode = 'guided' | 'inference' | 'cnn' | 'bulk' | 'draw'
type AppStatus = 'loading' | 'ready' | 'computing' | 'training' | 'error'

const INFERENCE_PHASES = [
  ['input', '画像を784個の数値として受け取る', '28×28の明るさを0〜1の値にしました。'],
  ['hidden-sum', '入力を重み付きで足し合わせる', '各入力×重みとbiasを足し、隠れ層の採点値 z₁ を求めました。'],
  ['relu', '負の値を0にする', 'ReLUが負の値を閉じ、正の活性値だけを次へ渡します。'],
  ['logits', '0〜9をそれぞれ採点する', '隠れ層の値から、10個のlogitを計算しました。'],
  ['softmax', '10個の採点値を確率へ変える', 'Softmaxで合計1になる確率へ変換しました。'],
  ['prediction', '最も大きな確率を回答にする', 'これは正解の保証ではなく、モデルが最も強く選んだ数字です。'],
] as const

const TRAINING_PHASES = [
  ...INFERENCE_PHASES,
  ['compare', 'モデルの回答と正解を比べる', '予測と教師ラベルを並べ、どれだけ外したかを測ります。'],
  ['loss', '間違いを1つの数にする', 'Cross entropy lossは、正解へ低い確率を付けるほど大きくなります。'],
  ['output-gradient', '出力側の責任を求める', '各重みがlossへ与えた影響を、実際の勾配として取得しました。'],
  ['hidden-gradient', '影響を隠れ層まで戻す', '連鎖律によって、前の層のパラメータにも勾配が届きます。'],
  ['parameter-update', '重みを少しだけ更新する', '重み − 学習率×勾配。正解へ直接置き換えてはいません。'],
  ['after-inference', '同じ数字をもう一度読む', '更新後の実モデルで再推論し、確率の変化を確かめます。'],
] as const

const CNN_PHASES = [
  ['input', '同じ28×28画像を2つのモデルへ渡す', '全結合は784個の値として、CNNは位置を保った28×28として受け取ります。'],
  ['conv1', '8個の小さな形の検出器で走査する', '3×3カーネルを画像全体へ適用し、線や曲がりへ反応する8枚の特徴マップを作ります。'],
  ['pool1', '強い反応を残して14×14へ縮める', '2×2領域ごとの最大値を残し、小さな位置ずれへ強くします。'],
  ['conv2', '特徴どうしを組み合わせる', '8枚を入力として16枚を作り、より複雑な形の組み合わせへ反応します。'],
  ['pool2', '16枚の証拠を7×7へまとめる', '分類器へ渡す784個の特徴を作り、各MAPが数字候補へ与えた寄与を計算します。'],
  ['compare', '同じ数字への見方を比較する', '全結合とCNNのSoftmax出力を並べます。どちらも実際のモデルが計算した値です。'],
] as const

function App() {
  const [status, setStatus] = useState<AppStatus>('loading')
  const [error, setError] = useState('')
  const [manifest, setManifest] = useState<DataManifest | null>(null)
  const [samples, setSamples] = useState<MnistSample[]>([])
  const [sampleIndex, setSampleIndex] = useState(0)
  const [drawnSample, setDrawnSample] = useState<MnistSample | null>(null)
  const [mode, setMode] = useState<Mode>('guided')
  const [trace, setTrace] = useState<ComputationTrace | null>(null)
  const [cnnTrace, setCnnTrace] = useState<CnnTrace | null>(null)
  const [cnnDefinition, setCnnDefinition] = useState<CnnModelDefinition | null>(null)
  const [phaseIndex, setPhaseIndex] = useState(0)
  const [playing, setPlaying] = useState(false)
  const [speed, setSpeed] = useState(1)
  const [selectedHidden, setSelectedHidden] = useState(0)
  const [selectedOutput, setSelectedOutput] = useState(3)
  const [selectedChannel, setSelectedChannel] = useState(0)
  const [selectedSourceChannel, setSelectedSourceChannel] = useState(0)
  const [metrics, setMetrics] = useState<TrainingMetric[]>([])
  const [trainingOffset, setTrainingOffset] = useState(0)
  const [modelTick, setModelTick] = useState(0)
  const learningModel = useRef<VisualModel | null>(null)
  const pretrainedModel = useRef<VisualModel | null>(null)
  const cnnModel = useRef<CnnVisualModel | null>(null)
  const splitCache = useRef<Partial<Record<'train' | 'test', MnistSample[]>>>({})
  const stopTraining = useRef(false)
  const drawingPad = useRef<DrawingPadHandle>(null)

  useEffect(() => {
    let disposed = false
    async function initialize() {
      try {
        const query = new URLSearchParams(window.location.search)
        if (query.get('data-error') === '1') throw new Error('検証用: MNISTデータを読み込めませんでした')
        await tf.ready()
        const nextManifest = await loadManifest()
        const [guided, weights, cnn] = await Promise.all([
          loadSplit(nextManifest, 'guided'),
          loadWeights(nextManifest),
          loadCnnModel(),
        ])
        if (query.get('model-error') === '1') throw new Error('検証用: 学習済みモデルを読み込めませんでした')
        if (disposed) return
        const firstThree = guided.findIndex((sample) => sample.label === 3)
        setManifest(nextManifest)
        setSamples(guided)
        setSampleIndex(Math.max(0, firstThree))
        learningModel.current = VisualModel.learning()
        pretrainedModel.current = VisualModel.pretrained(weights)
        cnnModel.current = new CnnVisualModel(cnn.weights)
        setCnnDefinition(cnn.definition)
        setStatus('ready')
      } catch (caught) {
        if (disposed) return
        setError(caught instanceof Error ? caught.message : '初期化できませんでした')
        setStatus('error')
      }
    }
    void initialize()
    return () => {
      disposed = true
      learningModel.current?.dispose()
      pretrainedModel.current?.dispose()
      cnnModel.current?.dispose()
    }
  }, [])

  const sample = mode === 'draw' ? drawnSample : samples[sampleIndex] ?? null
  const phases = mode === 'cnn' ? CNN_PHASES : trace?.kind === 'guided-training' ? TRAINING_PHASES : INFERENCE_PHASES
  const hasTrace = mode === 'cnn' ? Boolean(trace && cnnTrace) : Boolean(trace)
  const phase = phases[Math.min(phaseIndex, phases.length - 1)]
  const busy = status === 'computing' || status === 'training'

  useEffect(() => {
    if (!playing || !hasTrace || phaseIndex >= phases.length - 1) return
    const timer = window.setTimeout(() => {
      setPhaseIndex((current) => current + 1)
    }, 1100 / speed)
    return () => window.clearTimeout(timer)
  }, [playing, hasTrace, phaseIndex, phases.length, speed])

  useEffect(() => {
    if (phaseIndex >= phases.length - 1) setPlaying(false)
  }, [phaseIndex, phases.length])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null
      if (target?.closest('input, select, textarea, button, canvas')) return
      if (!hasTrace || busy) return
      if (event.key === ' ') {
        event.preventDefault()
        setPlaying((current) => !current)
      } else if (event.key === 'ArrowLeft') {
        setPlaying(false)
        setPhaseIndex((current) => Math.max(0, current - 1))
      } else if (event.key === 'ArrowRight') {
        setPlaying(false)
        setPhaseIndex((current) => Math.min(phases.length - 1, current + 1))
      } else if (event.key === 'Home') {
        setPlaying(false)
        setPhaseIndex(0)
      } else if (event.key === 'End') {
        setPlaying(false)
        setPhaseIndex(phases.length - 1)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [hasTrace, busy, phases.length])

  const highlightedPixels = useMemo(() => {
    if (!trace) return new Set<number>()
    const scored = Array.from(trace.input, (value, index) => ({
      index,
      value: Math.abs(value * trace.parametersBefore.w1[index * 16 + selectedHidden]),
    }))
    scored.sort((left, right) => right.value - left.value)
    return new Set(scored.slice(0, 12).map((item) => item.index))
  }, [trace, selectedHidden])

  const runInference = async () => {
    if (!sample) {
      setError('数字を書いてから読ませてください')
      return
    }
    const model = mode === 'guided' ? learningModel.current : pretrainedModel.current
    if (!model) {
      setError('モデルの準備が完了していません。再読み込みしてください')
      return
    }
    setError('')
    setStatus('computing')
    try {
      const nextTrace = await model.infer(sample.pixels, sample.id, sample.label)
      setTrace(nextTrace)
      setCnnTrace(null)
      setSelectedOutput(sample.label ?? 0)
      setSelectedHidden(0)
      setPhaseIndex(0)
      setPlaying(true)
      setStatus('ready')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '推論できませんでした')
      setStatus('error')
    }
  }

  const runCnnComparison = async () => {
    if (!sample || !pretrainedModel.current || !cnnModel.current) {
      setError('比較モデルの準備が完了していません。再読み込みしてください')
      return
    }
    setError('')
    setStatus('computing')
    try {
      const [mlp, cnn] = await Promise.all([
        pretrainedModel.current.infer(sample.pixels, sample.id, sample.label),
        cnnModel.current.infer(sample.pixels, sample.id, sample.label),
      ])
      setTrace(mlp)
      setCnnTrace(cnn)
      setSelectedOutput(sample.label ?? cnn.predictedClass)
      setSelectedChannel(0)
      setSelectedSourceChannel(0)
      setPhaseIndex(0)
      setPlaying(true)
      setStatus('ready')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'CNN比較を計算できませんでした')
      setStatus('error')
    }
  }

  const runGuidedTraining = async () => {
    if (!sample || sample.label === null || !learningModel.current) return
    setError('')
    setStatus('computing')
    try {
      const nextTrace = await learningModel.current.guidedTrain(sample.pixels, sample.id, sample.label)
      setTrace(nextTrace)
      setCnnTrace(null)
      setSelectedOutput(sample.label)
      setSelectedHidden(0)
      setPhaseIndex(0)
      setPlaying(true)
      setModelTick((current) => current + 1)
      setStatus('ready')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : '学習できませんでした')
      setStatus('error')
    }
  }

  const undoGuided = async () => {
    if (!learningModel.current) return
    if (await learningModel.current.undoGuided()) {
      setTrace(null)
      setCnnTrace(null)
      setModelTick((current) => current + 1)
    }
  }

  const resetLearning = () => {
    learningModel.current?.dispose()
    learningModel.current = VisualModel.learning()
    splitCache.current = {}
    setTrace(null)
    setCnnTrace(null)
    setMetrics([])
    setTrainingOffset(0)
    setModelTick((current) => current + 1)
    setStatus('ready')
  }

  const runBulkTraining = async () => {
    if (!manifest || !learningModel.current) return
    setError('')
    setStatus('training')
    setMode('bulk')
    setTrace(null)
    setCnnTrace(null)
    stopTraining.current = false
    try {
      const train = splitCache.current.train ?? await loadSplit(manifest, 'train')
      const test = splitCache.current.test ?? await loadSplit(manifest, 'test')
      splitCache.current = { train, test }
      const batch = train.slice(trainingOffset, trainingOffset + 500)
      const epoch = Math.floor(trainingOffset / train.length) + 1
      const currentMetrics: TrainingMetric[] = []
      const result = await learningModel.current.bulkTrain(batch, (processed, batchLoss) => {
        currentMetrics.push({ processed, epoch, batchLoss, testAccuracy: null })
        setMetrics([...currentMetrics])
      }, () => stopTraining.current)
      const testAccuracy = await learningModel.current.evaluate(test)
      setMetrics((current) => {
        if (current.length === 0) return [{ processed: result.processed, epoch, batchLoss: result.lastLoss, testAccuracy }]
        return current.map((metric, index) => index === current.length - 1 ? { ...metric, testAccuracy } : metric)
      })
      setTrainingOffset((current) => (current + result.processed) % train.length)
      setModelTick((current) => current + 1)
      setStatus('ready')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'まとめ学習を完了できませんでした')
      setStatus('error')
    }
  }

  const selectNextSample = () => {
    setTrace(null)
    setCnnTrace(null)
    setSampleIndex((current) => (current + 1) % samples.length)
  }

  const onDrawingChanged = () => {
    const canvas = drawingPad.current?.canvas()
    if (!canvas) return
    const pixels = preprocessDrawing(canvas)
    setDrawnSample(pixels ? { id: 'user-drawn', split: 'drawn', label: null, pixels } : null)
    setTrace(null)
    setCnnTrace(null)
    setError('')
  }

  const clearDrawing = () => {
    drawingPad.current?.clear()
    setDrawnSample(null)
    setTrace(null)
    setCnnTrace(null)
  }

  const activeForward = trace?.kind === 'guided-training' && phaseIndex >= 11 && trace.forwardAfter
    ? trace.forwardAfter
    : trace?.forwardBefore
  const activeParameters = trace?.kind === 'guided-training' && phaseIndex >= 11 && trace.parametersAfter
    ? trace.parametersAfter
    : trace?.parametersBefore
  const inspectedHiddenValue = trace && activeForward && phaseIndex >= 1
    ? phaseIndex === 1 ? activeForward.z1[selectedHidden] : activeForward.a1[selectedHidden]
    : null
  const selectedContribution = trace && activeForward && phaseIndex >= 3
    ? activeForward.a1[selectedHidden] * (activeParameters?.w2[selectedHidden * 10 + selectedOutput] ?? 0)
    : null
  const selectedGradient = trace?.kind === 'guided-training' && phaseIndex >= 8
    ? trace.gradients?.w2[selectedHidden * 10 + selectedOutput] ?? null
    : null
  const selectedUpdate = trace?.kind === 'guided-training' && phaseIndex >= 10
    ? trace.updates?.w2[selectedHidden * 10 + selectedOutput] ?? null
    : null
  const learningRevision = learningModel.current?.revision ?? 0
  void modelTick

  return (
    <main
      className="app-shell"
      data-status={status}
      data-learning-ready={learningModel.current ? 'true' : 'false'}
      data-pretrained-ready={pretrainedModel.current ? 'true' : 'false'}
    >
      <header className="app-header">
        <div>
          <p className="eyebrow">NEURAL NETWORK OBSERVATION / MNIST</p>
          <h1>数字がわかるまで</h1>
          <p>本当に動いているモデルの、考える途中と学ぶ瞬間を観察します。</p>
        </div>
        <div className="model-plate" aria-label="現在のモデル">
          <span>{mode === 'cnn' ? '2つの学習済みモデル' : mode === 'guided' || mode === 'bulk' ? 'いま学習中のモデル' : '学習済みモデル'}</span>
          <strong>{mode === 'cnn' ? 'MLP ⇄ CNN' : '784 → 16 → 10'}</strong>
          <small>revision {mode === 'guided' || mode === 'bulk' ? String(learningRevision).padStart(4, '0') : 'fixed'}</small>
        </div>
      </header>

      <nav className="mode-tabs" aria-label="観察モード">
        {([
          ['guided', '1件を学ぶ'],
          ['inference', '推論を見る'],
          ['cnn', 'CNNと比較'],
          ['bulk', 'まとめて学ぶ'],
          ['draw', '自分で書く'],
        ] as Array<[Mode, string]>).map(([value, label]) => (
          <button
            type="button"
            key={value}
            className={mode === value ? 'mode-tab mode-tab--active' : 'mode-tab'}
            aria-pressed={mode === value}
            onClick={() => {
              setMode(value)
              setTrace(null)
              setCnnTrace(null)
              setPlaying(false)
              setError('')
            }}
            disabled={busy}
          >{label}</button>
        ))}
      </nav>

      {status === 'loading' && (
        <section className="loading-panel" aria-live="polite">
          <strong>観察装置を準備しています</strong>
          <span>MNISTサンプルと学習済み重みを端末へ読み込み中</span>
        </section>
      )}

      {error && (
        <section className="error-panel" role="alert">
          <strong>計算を続けられません</strong>
          <span>{error}</span>
          {status === 'error' && <button type="button" onClick={() => window.location.reload()}>再読み込み</button>}
        </section>
      )}

      {status !== 'loading' && samples.length > 0 && (
        <>
          <section className="experiment-bar" aria-label="実験条件">
            <div>
              <span>INPUT</span>
              <strong>{sample?.split === 'drawn' ? 'あなたの手書き' : `MNIST ${sample?.split ?? ''} / 正解 ${sample?.label ?? '—'}`}</strong>
            </div>
            <div>
              <span>ENGINE</span>
              <strong>TensorFlow.js / {tf.getBackend() || '準備中'}</strong>
            </div>
            <div>
              <span>MEASURED</span>
              <strong>{mode === 'cnn' && cnnTrace ? `${(trace!.computeDurationMs + cnnTrace.computeDurationMs).toFixed(1)}msで2モデル` : trace ? `${trace.computeDurationMs.toFixed(1)}msで計算 / ${speed}x再生` : '計算前'}</strong>
            </div>
          </section>

          {mode === 'bulk' ? (
            <section className="bulk-panel">
              <div className="bulk-intro">
                <p className="section-number">EXPERIMENT B</p>
                <h2>500件まとめて学ぶ</h2>
                <p>詳細アニメーションは作らず、実際のbatch境界でlossを記録します。評価には学習に使っていないtest subset 1,000件を使います。</p>
                <div className="button-row">
                  <button type="button" className="button button--primary" onClick={() => void runBulkTraining()} disabled={busy}>
                    {status === 'training' ? '学習中…' : '500件学習する'}
                  </button>
                  {status === 'training' && <button type="button" onClick={() => { stopTraining.current = true }}>batch完了後に停止</button>}
                  <button type="button" onClick={resetLearning} disabled={busy}>未学習へ戻す</button>
                </div>
              </div>
              <MetricsChart metrics={metrics} />
            </section>
          ) : (
            <>
              <section className={mode === 'cnn' ? 'observation observation--cnn' : 'observation'} aria-label="ニューラルネットワークの計算過程">
                <div className="input-stage">
                  <div className="stage-heading">
                    <span>INPUT / 784</span>
                    {mode !== 'draw' && <button type="button" onClick={selectNextSample} disabled={busy}>別の数字</button>}
                  </div>
                  {mode === 'draw' ? (
                    <div className="drawing-area">
                      <DrawingPad ref={drawingPad} onStrokeEnd={onDrawingChanged} />
                      <div>
                        <span className="drawing-label">モデルへ渡す28×28</span>
                        <PixelGrid pixels={drawnSample?.pixels ?? new Float32Array(784)} label="前処理後の手書き数字" />
                      </div>
                      <button type="button" onClick={clearDrawing}>消す</button>
                    </div>
                  ) : sample ? (
                    <PixelGrid pixels={sample.pixels} highlighted={mode === 'cnn' ? undefined : highlightedPixels} label={`MNISTの数字${sample.label}`} />
                  ) : null}
                  <p className="input-note">明るさ＝モデルへ入る0〜1の実値</p>
                </div>

                {mode === 'cnn' ? (
                  <div className="cnn-placeholder">
                    <span>SPATIAL INPUT</span>
                    <strong>28×28の位置を保つ</strong>
                    <p>開始すると、1枚の画像から複数の特徴マップが生まれます。</p>
                  </div>
                ) : (
                  <NetworkDiagram
                    trace={trace}
                    phaseIndex={phaseIndex}
                    selectedHidden={selectedHidden}
                    selectedOutput={selectedOutput}
                    onSelectHidden={setSelectedHidden}
                    onSelectOutput={setSelectedOutput}
                  />
                )}
              </section>

              {mode === 'cnn' && trace && cnnTrace && (
                <CnnExplorer
                  trace={cnnTrace}
                  mlpTrace={trace}
                  phaseIndex={phaseIndex}
                  selectedChannel={selectedChannel}
                  selectedSourceChannel={selectedSourceChannel}
                  selectedOutput={selectedOutput}
                  onSelectChannel={setSelectedChannel}
                  onSelectSourceChannel={setSelectedSourceChannel}
                  onSelectOutput={setSelectedOutput}
                />
              )}

              <section className="phase-panel" aria-live="polite">
                <div className="phase-count">STEP {hasTrace ? phaseIndex + 1 : 0} / {phases.length}</div>
                <div>
                  <h2>{hasTrace ? phase[1] : mode === 'guided' ? 'まず、このモデルの予想を見る' : mode === 'cnn' ? '全結合とCNNへ同じ数字を渡す' : '数字をモデルへ読ませる'}</h2>
                  <p>{hasTrace ? phase[2] : '開始すると実モデルが先に計算し、その記録を段階的に再生します。'}</p>
                </div>
                {!hasTrace && (
                  <button type="button" className="button button--primary" onClick={() => void (mode === 'cnn' ? runCnnComparison() : runInference())} disabled={busy || !sample}>
                    {busy ? '計算中…' : mode === 'guided' ? 'まず予想を見る' : mode === 'cnn' ? '2モデルで比べる' : 'この数字を読ませる'}
                  </button>
                )}
              </section>

              {hasTrace && (
                <PlaybackControls
                  phase={phaseIndex}
                  total={phases.length}
                  playing={playing}
                  speed={speed}
                  disabled={busy}
                  onPhase={(next) => { setPlaying(false); setPhaseIndex(next) }}
                  onPlaying={setPlaying}
                  onSpeed={setSpeed}
                />
              )}

              {trace && mode !== 'cnn' && (
                <section className="inspector" aria-label="選択した実値の詳細">
                  <div>
                    <span>選択中</span>
                    <strong>隠れ {selectedHidden + 1} → 出力 {selectedOutput}</strong>
                  </div>
                  <dl>
                    <div><dt>{phaseIndex === 1 ? '隠れ層の合計 z₁' : '隠れ層の活性値'}</dt><dd>{inspectedHiddenValue === null ? '—' : inspectedHiddenValue.toFixed(6)}</dd></div>
                    <div><dt>接続の重み</dt><dd>{activeParameters?.w2[selectedHidden * 10 + selectedOutput].toFixed(6)}</dd></div>
                    <div><dt>実際の寄与</dt><dd>{selectedContribution === null ? '—' : selectedContribution.toFixed(6)}</dd></div>
                    {selectedGradient !== null && <div><dt>∂loss / ∂weight</dt><dd>{selectedGradient.toFixed(6)}</dd></div>}
                    {selectedUpdate !== null && <div><dt>更新量 Δweight</dt><dd>{selectedUpdate.toFixed(6)}</dd></div>}
                  </dl>
                  <p>寄与 = 活性値 × 重み。表示は丸めていますが、計算には丸め前のfloat32値を使用しています。</p>
                </section>
              )}

              {mode === 'guided' && (
                <section className="learning-actions">
                  <div>
                    <span>GUIDED TRAINING / BATCH SIZE 1</span>
                    <strong>正解ラベル {sample?.label ?? '—'} を教師として、実際に1回更新します。</strong>
                  </div>
                  <div className="button-row">
                    <button type="button" className="button button--update" onClick={() => void runGuidedTraining()} disabled={busy || !sample}>
                      この1件を学習する
                    </button>
                    <button type="button" onClick={() => void undoGuided()} disabled={busy || !learningModel.current?.canUndoGuided()}>
                      学習前へ戻す
                    </button>
                    <button type="button" onClick={resetLearning} disabled={busy}>未学習へ戻す</button>
                  </div>
                </section>
              )}
            </>
          )}

          <details className="method-note">
            <summary>モデルとデータの条件</summary>
            <div>
              <p><strong>構造:</strong> 784入力 → ReLU 16 → Softmax 10、SGD、学習率0.05</p>
              <p><strong>学習済み:</strong> MNIST train 60,000件、test 10,000件で実測 {(manifest?.model.testAccuracy ?? 0) * 100 > 0 ? `${((manifest?.model.testAccuracy ?? 0) * 100).toFixed(2)}%` : '—'}</p>
              <p><strong>CNN比較:</strong> Conv 8 → Pool → Conv 16 → Pool → Dense 10。subset 5,000件で学習し、分離test 1,000件で実測 {cnnDefinition ? `${(cnnDefinition.testAccuracy * 100).toFixed(1)}%` : '—'}</p>
              <p><strong>ブラウザ学習:</strong> train subset 5,000件。評価は分離したtest subset 1,000件</p>
              <p><strong>出典:</strong> {manifest?.source.attribution} / {manifest?.source.license}</p>
            </div>
          </details>
        </>
      )}
    </main>
  )
}

export default App
