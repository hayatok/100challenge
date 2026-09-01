import { useEffect, useRef, useState } from 'react'
import './App.css'
import {
  generateReport,
  progressStates,
  tones,
  validateAiReport,
  type ProgressState,
  type ReportInput,
  type Tone,
} from './generator'

type AiStatus = 'idle' | 'consent' | 'loading' | 'ready' | 'generating' | 'error' | 'unsupported'
type ResultSource = 'template' | 'ai'
type GenerationIntent = 'generate' | 'alternate' | 'adjust'
type VisualEffect = 'idle' | 'printing' | 'stamped' | 'alternate' | 'copied'

type WorkerMessage =
  | { type: 'progress'; progress: number; text: string }
  | { type: 'ready' }
  | { type: 'result'; report: string }
  | { type: 'error'; message: string }

const initialReport = 'ログイン画面については、現時点では、着手に向けた前提条件の整理を中心に進めています。'

function loadSetting<T>(key: string, fallback: T): T {
  try {
    const value = localStorage.getItem(key)
    return value ? (JSON.parse(value) as T) : fallback
  } catch {
    return fallback
  }
}

function ambiguityLabel(value: number) {
  if (value === 0) return 'かなり正直'
  if (value === 25) return '少しぼかす'
  if (value === 50) return 'それっぽい'
  if (value === 75) return 'だいぶ曖昧'
  return '情報量：ほぼゼロ'
}

function App() {
  const [subject, setSubject] = useState('ログイン画面')
  const [progressState, setProgressState] = useState<ProgressState>(() => loadSetting('yatterukan:state', 'working'))
  const [tone, setTone] = useState<Tone>(() => loadSetting('yatterukan:tone', 'safe'))
  const [ambiguity, setAmbiguity] = useState(() => loadSetting('yatterukan:ambiguity', 50))
  const [report, setReport] = useState(initialReport)
  const [resultSource, setResultSource] = useState<ResultSource>('template')
  const [recent, setRecent] = useState<string[]>(() => loadSetting('yatterukan:recent', []))
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [aiEnabled, setAiEnabled] = useState(false)
  const [aiStatus, setAiStatus] = useState<AiStatus>('idle')
  const [aiProgress, setAiProgress] = useState(0)
  const [aiDetail, setAiDetail] = useState('')
  const [visualEffect, setVisualEffect] = useState<VisualEffect>('idle')
  const workerRef = useRef<Worker | null>(null)
  const pendingInputRef = useRef<ReportInput | null>(null)
  const pendingIntentRef = useRef<GenerationIntent>('generate')
  const generationTimerRef = useRef<number | null>(null)
  const visualTimerRef = useRef<number | null>(null)
  const visualFrameRef = useRef<number | null>(null)

  useEffect(() => {
    localStorage.setItem('yatterukan:state', JSON.stringify(progressState))
    localStorage.setItem('yatterukan:tone', JSON.stringify(tone))
    localStorage.setItem('yatterukan:ambiguity', JSON.stringify(ambiguity))
    localStorage.setItem('yatterukan:recent', JSON.stringify(recent.slice(0, 5)))
  }, [ambiguity, progressState, recent, tone])

  useEffect(() => () => {
    workerRef.current?.terminate()
    if (generationTimerRef.current) window.clearTimeout(generationTimerRef.current)
    if (visualTimerRef.current) window.clearTimeout(visualTimerRef.current)
    if (visualFrameRef.current) window.cancelAnimationFrame(visualFrameRef.current)
  }, [])

  const currentInput = (): ReportInput => ({ subject, state: progressState, tone, ambiguity })

  const showVisualEffect = (effect: VisualEffect, duration = 720) => {
    if (visualTimerRef.current) window.clearTimeout(visualTimerRef.current)
    if (visualFrameRef.current) window.cancelAnimationFrame(visualFrameRef.current)
    setVisualEffect('idle')
    visualFrameRef.current = window.requestAnimationFrame(() => {
      setVisualEffect(effect)
      visualTimerRef.current = window.setTimeout(() => setVisualEffect('idle'), duration)
    })
  }

  const commitReport = (nextReport: string, source: ResultSource) => {
    setReport(nextReport)
    setResultSource(source)
    setRecent((items) => [nextReport, ...items.filter((item) => item !== nextReport)].slice(0, 5))
    setError('')
    showVisualEffect(pendingIntentRef.current === 'alternate' ? 'alternate' : 'stamped')
  }

  const generateTemplate = (input = currentInput(), fallbackMessage = '') => {
    try {
      commitReport(generateReport(input, recent), 'template')
      if (fallbackMessage) setNotice(fallbackMessage)
    } catch (generationError) {
      setError(generationError instanceof Error ? generationError.message : '文章を生成できませんでした')
    }
  }

  const cancelAi = () => {
    workerRef.current?.terminate()
    workerRef.current = null
    pendingInputRef.current = null
    setAiEnabled(false)
    setAiStatus('idle')
    setAiProgress(0)
    if (generationTimerRef.current) window.clearTimeout(generationTimerRef.current)
    if (visualTimerRef.current) window.clearTimeout(visualTimerRef.current)
    setVisualEffect('idle')
  }

  const requestGeneration = (input: ReportInput, intent: GenerationIntent = 'generate') => {
    setNotice('')
    if (!input.subject.trim()) {
      setError('まず、何についての進捗か入力してください。')
      return
    }
    pendingIntentRef.current = intent
    showVisualEffect('printing', aiEnabled && aiStatus === 'ready' ? 30_000 : 720)
    if (!aiEnabled || aiStatus !== 'ready') {
      generateTemplate(input)
      return
    }
    pendingInputRef.current = input
    setAiStatus('generating')
    workerRef.current?.postMessage({ type: 'generate', input })
    generationTimerRef.current = window.setTimeout(() => {
      cancelAi()
      generateTemplate(input, 'AIが考えすぎたため、従来型の言い訳を採用しました。')
    }, 30_000)
  }

  const generate = () => requestGeneration(currentInput(), 'generate')
  const generateAlternative = () => requestGeneration(currentInput(), 'alternate')

  const setupWorker = () => {
    const aiWorker = new Worker(new URL('./ai.worker.ts', import.meta.url), { type: 'module' })
    workerRef.current = aiWorker
    aiWorker.onmessage = (event: MessageEvent<WorkerMessage>) => {
      const message = event.data
      if (message.type === 'progress') {
        setAiProgress(Math.round(message.progress * 100))
        setAiDetail(message.text)
      }
      if (message.type === 'ready') {
        setAiStatus('ready')
        setAiProgress(100)
        setNotice('高度な言い訳の準備ができました。')
      }
      if (message.type === 'result') {
        if (generationTimerRef.current) window.clearTimeout(generationTimerRef.current)
        const input = pendingInputRef.current
        const validated = input ? validateAiReport(message.report, input.subject) : null
        if (validated) {
          commitReport(validated, 'ai')
          setAiStatus('ready')
          setNotice('この文章は端末内のAIが慎重に曖昧化しました。')
        } else if (input) {
          setAiStatus('ready')
          generateTemplate(input, 'AIの発言が具体的すぎたため、人間の知恵でぼかしました。')
        }
      }
      if (message.type === 'error') {
        const input = pendingInputRef.current
        setAiStatus('error')
        if (input) generateTemplate(input, '高度な言い訳に失敗したため、従来型へ戻しました。')
        else setNotice('AIの準備に失敗しました。通常モードはそのまま使えます。')
      }
    }
  }

  const enableAi = (enabled: boolean) => {
    setAiEnabled(enabled)
    setNotice('')
    if (!enabled) {
      cancelAi()
      return
    }
    if (!('gpu' in navigator)) {
      setAiStatus('unsupported')
      return
    }
    setAiStatus('consent')
  }

  const loadAi = () => {
    setupWorker()
    setAiStatus('loading')
    setAiProgress(0)
    workerRef.current?.postMessage({ type: 'load' })
  }

  const copyReport = async () => {
    try {
      await navigator.clipboard.writeText(report)
      setNotice('進捗が発生したことになりました。')
      showVisualEffect('copied')
    } catch {
      setNotice('コピーできませんでした。文章を選択してコピーしてください。')
    }
  }

  const changeAmbiguity = (delta: number) => {
    const nextAmbiguity = Math.max(0, Math.min(100, ambiguity + delta))
    setAmbiguity(nextAmbiguity)
    requestGeneration({ ...currentInput(), ambiguity: nextAmbiguity }, 'adjust')
  }

  const clearHistory = () => {
    localStorage.removeItem('yatterukan:recent')
    setRecent([])
    setNotice('このアプリの生成履歴を消去しました。')
  }

  const loadingJoke = aiProgress < 34
    ? 'モデルが社内用語を確認しています'
    : aiProgress < 67
      ? '責任の所在を曖昧にしています'
      : '具体性を慎重に取り除いています'

  return (
    <div className={`app-shell effect-${visualEffect}`}>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="やってる感 ホーム">
          <span className="brand-mark" aria-hidden="true">進</span>
          <span>やってる感</span>
        </a>
        <div className="header-status"><span aria-hidden="true" /> サーバーには何もしていません</div>
      </header>

      <main id="top">
        <section className="intro" aria-labelledby="page-title">
          <p className="eyebrow">PROGRESS REPORT OPTIMIZER 1.0</p>
          <h1 id="page-title">
            <span className="title-line"><span>具体的なことを</span><span>言わずに、</span></span>
            <span className="title-line"><span>進んでいる感じを</span><span>出す。</span></span>
          </h1>
          <p className="lead">事実を入力してください。事実は増やさず、文字数だけ増やします。</p>
        </section>

        <div className="generator-grid">
          <section className="input-panel" aria-labelledby="input-title">
            <div className="section-heading">
              <span>01</span>
              <div><h2 id="input-title">実情を報告</h2><p>ここだけは正直にお願いします</p></div>
            </div>

            <div className="field-group">
              <label htmlFor="subject">何について？</label>
              <input id="subject" value={subject} onChange={(event) => setSubject(event.target.value)} maxLength={60} placeholder="例：ログイン画面" aria-describedby="subject-count" />
              <span id="subject-count" className="character-count">{subject.length}/60</span>
            </div>

            <fieldset className="field-group">
              <legend>実際の状況</legend>
              <div className="state-grid">
                {progressStates.map((state) => (
                  <label className="state-option" key={state.value}>
                    <input type="radio" name="progress-state" value={state.value} checked={progressState === state.value} onChange={() => setProgressState(state.value)} />
                    <span className="radio-dot" aria-hidden="true" />
                    <span><strong>{state.label}</strong><small>{state.hint}</small></span>
                  </label>
                ))}
              </div>
            </fieldset>

            <div className="compact-fields">
              <div className="field-group">
                <label htmlFor="tone">文体</label>
                <select id="tone" value={tone} onChange={(event) => setTone(event.target.value as Tone)}>
                  {tones.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
                </select>
              </div>
              <div className="field-group ambiguity-field">
                <div className="range-heading"><label htmlFor="ambiguity">曖昧さ</label><output>{ambiguityLabel(ambiguity)}</output></div>
                <input id="ambiguity" type="range" min="0" max="100" step="25" value={ambiguity} onChange={(event) => setAmbiguity(Number(event.target.value))} />
                <div className="range-scale" aria-hidden="true"><span>正直</span><span>無内容</span></div>
              </div>
            </div>

            {error && <p className="error-message" role="alert">{error}</p>}
            <button className="generate-button" type="button" onClick={generate} disabled={aiStatus === 'generating'}>
              <span>{aiStatus === 'generating' ? 'AIが言い回しを調整中…' : 'それっぽく報告する'}</span><span aria-hidden="true">→</span>
            </button>
          </section>

          <section className="result-panel" aria-labelledby="result-title">
            <div className="printer-slot" aria-hidden="true" />
            <span className="approval-burst" aria-hidden="true" />
            <div className="section-heading result-heading">
              <span>02</span>
              <div>
                <h2 id="result-title">生成された進捗</h2>
                <p>{aiStatus === 'generating' ? 'ローカルAI処理中' : resultSource === 'ai' ? 'ローカルAI製' : '企業努力製'}</p>
              </div>
              <span className="confidential-stamp">社外秘っぽい</span>
            </div>

            <div className="mascot-frame">
              <img src={`${import.meta.env.BASE_URL}progress-manager-v2.png`} alt="白紙の進捗報告を自信満々に掲げる会社員" />
              <p>資料だけは増えました</p>
            </div>

            <label className="sr-only" htmlFor="report">生成された進捗報告</label>
            <textarea id="report" value={report} onChange={(event) => setReport(event.target.value)} rows={6} />
            <div className="result-actions">
              <button className="primary-copy" type="button" onClick={copyReport}>コピーする</button>
              <button type="button" onClick={generateAlternative} disabled={aiStatus === 'generating'}>別案</button>
            </div>
            <div className="fine-tune-actions" aria-label="曖昧さを調整して再生成">
              <button type="button" onClick={() => changeAmbiguity(-25)} disabled={ambiguity === 0 || aiStatus === 'generating'}>少し正直に</button><span aria-hidden="true">／</span><button type="button" onClick={() => changeAmbiguity(25)} disabled={ambiguity === 100 || aiStatus === 'generating'}>さらに曖昧に</button>
            </div>
            <p className="notice" aria-live="polite">{notice}</p>
          </section>
        </div>

        <section className="ai-panel" aria-labelledby="ai-title">
          <div className="ai-copy">
            <p className="eyebrow">OPTIONAL LOCAL AI</p>
            <h2 id="ai-title">もっと高度に、何も言わない。</h2>
            <p>端末内の小型AIが、入力した事実を外部へ送らずに曖昧化します。</p>
          </div>
          <label className="switch-control">
            <input type="checkbox" checked={aiEnabled} onChange={(event) => enableAi(event.target.checked)} />
            <span className="switch" aria-hidden="true" /><span>ローカルAIモード</span>
          </label>

          {aiStatus === 'consent' && (
            <div className="ai-message consent-message">
              <div><strong>約290MBのモデルを読み込みます</strong><p>初回のみ時間がかかります。入力内容は端末から出ません。</p></div>
              <div className="inline-actions"><button type="button" onClick={loadAi}>読み込む</button><button type="button" onClick={cancelAi}>やめる</button></div>
            </div>
          )}
          {aiStatus === 'loading' && (
            <div className="ai-message loading-message" role="status">
              <div className="progress-copy"><strong>{loadingJoke}</strong><span>{aiProgress}%</span></div>
              <div className="progress-track"><span style={{ width: `${aiProgress}%` }} /></div>
              <p>{aiDetail || '準備を始めています…'}</p>
              <button type="button" onClick={cancelAi}>通常モードへ戻る</button>
            </div>
          )}
          {aiStatus === 'ready' && <p className="ai-ready" role="status"><span aria-hidden="true" /> 高度な言い訳が利用できます</p>}
          {aiStatus === 'unsupported' && <div className="ai-message"><strong>この端末では高度な言い訳を生成できません</strong><p>通常モードは引き続き、元気に稼働しています。</p><button type="button" onClick={cancelAi}>了解</button></div>}
          {aiStatus === 'error' && <div className="ai-message"><strong>AIは責任を取らずに退席しました</strong><p>通常モードで生成を続けられます。</p><button type="button" onClick={cancelAi}>通常モードへ戻る</button></div>}
        </section>
      </main>

      <footer>
        <p>本アプリは進捗そのものを生成するものではありません。</p>
        <button type="button" onClick={clearHistory}>履歴を消去</button>
      </footer>
    </div>
  )
}

export default App
