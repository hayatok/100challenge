import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import GardenCanvas, { type AssetStatus } from './components/GardenCanvas'
import GardenControls from './components/GardenControls'
import GardenStatus from './components/GardenStatus'
import HelpPanel from './components/HelpPanel'
import {
  BOARD_SIZE,
  countAlive,
  createEmptyBoard,
  createMetadata,
  createRandomBoard,
  setCell,
  stepBoard,
  type Board,
  type CellMetadata,
} from './game/board'
import { canClear, canPlay, canStep, phaseAfterStep, type GardenPhase, type StepOrigin } from './game/machine'
import { readHelpDismissed, readSpeed, saveHelpDismissed, saveSpeed, speedIntervals, type GardenSpeed } from './game/preferences'
import { createRandomSeed } from './game/random'
import { decideTick } from './game/timing'

type GardenState = {
  board: Board
  metadata: CellMetadata
  bornAt: Float64Array
  diedAt: Float64Array
  generation: number
  phase: GardenPhase
  seed: number
}

function createGarden(seed = createRandomSeed(), phase: GardenPhase = 'running'): GardenState {
  const density = 0.26 + (seed % 7) / 100
  const board = phase === 'empty' || phase === 'reseeding' ? createEmptyBoard() : createRandomBoard(seed, density)
  const bornAt = new Float64Array(BOARD_SIZE)
  const now = performance.now()
  if (phase === 'running') {
    for (let index = 0; index < BOARD_SIZE; index += 1) {
      if (board[index]) bornAt[index] = now
    }
  }
  return {
    board,
    metadata: createMetadata(board),
    bornAt,
    diedAt: new Float64Array(BOARD_SIZE),
    generation: 0,
    phase,
    seed,
  }
}

function initialGarden() {
  const demo = new URLSearchParams(window.location.search).get('demo')
  if (demo === 'empty') return createGarden(createRandomSeed(), 'empty')
  if (demo === 'reseeding') return createGarden(createRandomSeed(), 'reseeding')
  return createGarden()
}

function advanceGarden(previous: GardenState, origin: StepOrigin, now: number): GardenState {
  const result = stepBoard(previous.board, previous.metadata)
  const bornAt = previous.bornAt.slice()
  const diedAt = previous.diedAt.slice()
  for (const index of result.born) {
    bornAt[index] = now
    diedAt[index] = 0
  }
  for (const index of result.died) diedAt[index] = now
  return {
    ...previous,
    board: result.board,
    metadata: result.metadata,
    bornAt,
    diedAt,
    generation: previous.generation + 1,
    phase: phaseAfterStep(origin, result.aliveCount),
  }
}

function App() {
  const [garden, setGarden] = useState<GardenState>(initialGarden)
  const [speed, setSpeed] = useState<GardenSpeed>(readSpeed)
  const [editing, setEditing] = useState(false)
  const [assetStatus, setAssetStatus] = useState<AssetStatus>('loading')
  const [announcement, setAnnouncement] = useState('')
  const [notice, setNotice] = useState('')
  const [helpOpen, setHelpOpen] = useState(() => !readHelpDismissed())
  const [switching, setSwitching] = useState(false)
  const clearDialogRef = useRef<HTMLDialogElement>(null)
  const switchingTimerRef = useRef<number | null>(null)

  const aliveCount = useMemo(() => countAlive(garden.board), [garden.board])
  const forceFallback = new URLSearchParams(window.location.search).has('fallback')
  const atlasUrl = forceFallback ? './missing-life-garden-atlas.png' : `${import.meta.env.BASE_URL}life-garden-sprites-v1-alpha.png`

  const startNewGarden = useCallback(() => {
    if (switchingTimerRef.current) window.clearTimeout(switchingTimerRef.current)
    setSwitching(false)
    window.requestAnimationFrame(() => {
      setSwitching(true)
      switchingTimerRef.current = window.setTimeout(() => setSwitching(false), 240)
    })
    setGarden(createGarden())
    setAnnouncement('新しい庭を世代0から観測します')
  }, [])

  const stepOnce = useCallback(() => {
    setGarden((previous) => canStep(previous.phase) ? advanceGarden(previous, 'manual', performance.now()) : previous)
  }, [])

  const togglePlay = useCallback(() => {
    setGarden((previous) => {
      if (!canPlay(previous.phase)) return previous
      return { ...previous, phase: previous.phase === 'running' ? 'paused' : 'running' }
    })
  }, [])

  const changeSpeed = useCallback((nextSpeed: GardenSpeed) => {
    setSpeed(nextSpeed)
    if (!saveSpeed(nextSpeed)) setNotice('観測装置は設定を忘れました。庭への影響はありません。')
  }, [])

  const clearGarden = useCallback(() => {
    setGarden((previous) => ({
      ...createGarden(previous.seed, 'empty'),
      seed: previous.seed,
    }))
    setAnnouncement('庭を空にしました。観測装置は待機しています')
  }, [])

  const editCell = useCallback((index: number, alive: boolean, now: number) => {
    setGarden((previous) => {
      const next = setCell(previous.board, previous.metadata, index, alive)
      const bornAt = previous.bornAt.slice()
      const diedAt = previous.diedAt.slice()
      if (alive) {
        bornAt[index] = now
        diedAt[index] = 0
      } else {
        bornAt[index] = 0
        diedAt[index] = now
      }
      const nextCount = countAlive(next.board)
      let phase = previous.phase
      if (nextCount === 0) phase = 'empty'
      else if (previous.phase === 'empty' || previous.phase === 'reseeding') phase = 'paused'
      return {
        ...previous,
        ...next,
        bornAt,
        diedAt,
        generation: previous.phase === 'empty' || previous.phase === 'reseeding' ? 0 : previous.generation,
        phase,
      }
    })
  }, [])

  const handleAssetStatus = useCallback((status: AssetStatus) => {
    setAssetStatus(status)
    if (status === 'error') setNotice('高性能表示装置の準備に失敗しました。簡易表示で観測を続けます。')
  }, [])

  const closeHelp = useCallback(() => {
    setHelpOpen(false)
    if (!saveHelpDismissed(true)) setNotice('観測装置は設定を忘れました。庭への影響はありません。')
  }, [])

  const toggleHelp = useCallback(() => {
    setHelpOpen((open) => {
      const next = !open
      if (!next) saveHelpDismissed(true)
      return next
    })
  }, [])

  useEffect(() => {
    if (garden.phase !== 'running' || editing) return
    let frame = 0
    let lastTick = performance.now()
    const resetClock = () => {
      lastTick = performance.now()
    }
    const tick = (now: number) => {
      const decision = decideTick(lastTick, now, speedIntervals[speed])
      if (!document.hidden && decision.shouldTick) {
        lastTick = decision.nextBaseline
        setGarden((previous) => previous.phase === 'running' ? advanceGarden(previous, 'automatic', now) : previous)
      }
      frame = window.requestAnimationFrame(tick)
    }
    document.addEventListener('visibilitychange', resetClock)
    frame = window.requestAnimationFrame(tick)
    return () => {
      document.removeEventListener('visibilitychange', resetClock)
      window.cancelAnimationFrame(frame)
    }
  }, [editing, garden.phase, speed])

  useEffect(() => {
    if (garden.phase !== 'reseeding') return
    const timer = window.setTimeout(startNewGarden, 1500)
    return () => window.clearTimeout(timer)
  }, [garden.phase, startNewGarden])

  useEffect(() => () => {
    if (switchingTimerRef.current) window.clearTimeout(switchingTimerRef.current)
  }, [])

  useEffect(() => {
    const handleShortcut = (event: globalThis.KeyboardEvent) => {
      const target = event.target
      if (target instanceof HTMLCanvasElement || target instanceof HTMLButtonElement || target instanceof HTMLInputElement || target instanceof HTMLSelectElement || target instanceof HTMLTextAreaElement || clearDialogRef.current?.open) return
      if (event.key === ' ') {
        event.preventDefault()
        togglePlay()
      } else if (event.key.toLowerCase() === 'n') {
        stepOnce()
      } else if (event.key.toLowerCase() === 'r') {
        startNewGarden()
      } else if (event.key.toLowerCase() === 'c') {
        if (canClear(garden.phase)) clearDialogRef.current?.showModal()
      } else if (event.key === '?') {
        toggleHelp()
      } else if (event.key === '1') changeSpeed('slow')
      else if (event.key === '2') changeSpeed('normal')
      else if (event.key === '3') changeSpeed('fast')
    }
    window.addEventListener('keydown', handleShortcut)
    return () => window.removeEventListener('keydown', handleShortcut)
  }, [changeSpeed, garden.phase, startNewGarden, stepOnce, toggleHelp, togglePlay])

  const phaseMessage = garden.phase === 'reseeding'
    ? '生命反応を見失いました。装置は深刻そうに再播種します。'
    : garden.phase === 'empty'
      ? '観測対象なし。装置だけが待機しています。種をまくか、別の宇宙を始めてください。'
      : assetStatus === 'loading'
        ? '観測装置を必要以上に準備しています'
        : ''

  const liveAnnouncement = garden.phase === 'reseeding'
    ? '生命数0。1.5秒後に新しい庭を開始します'
    : announcement

  return (
    <div className="app-shell">
      <header className="site-header">
        <div>
          <p className="machine-label desktop-only">LIFE OBSERVATION UNIT 01</p>
          <h1>いのちの庭</h1>
          <p className="lead desktop-only">768マスの大自然を、必要以上の設備で見守ります。</p>
        </div>
        <p className="header-note">勝敗なし・外部通信なし</p>
      </header>

      <main>
        <section className={`observation-unit${switching ? ' is-switching' : ''}`} aria-label="高度生命観測装置 一号機">
          <div className="unit-plate" aria-hidden="true">UNIT 01 · B3/S23 · 32×24</div>
          <GardenStatus generation={garden.generation} aliveCount={aliveCount} phase={garden.phase} />

          <div className="monitor-frame">
            <span className="bolt bolt-nw" aria-hidden="true" />
            <span className="bolt bolt-ne" aria-hidden="true" />
            <span className="bolt bolt-sw" aria-hidden="true" />
            <span className="bolt bolt-se" aria-hidden="true" />
            <GardenCanvas
              board={garden.board}
              metadata={garden.metadata}
              bornAt={garden.bornAt}
              diedAt={garden.diedAt}
              phase={garden.phase}
              atlasUrl={atlasUrl}
              onEdit={editCell}
              onEditingChange={setEditing}
              onAnnouncement={setAnnouncement}
              onAssetStatus={handleAssetStatus}
            />
            {phaseMessage && <div className={`monitor-message message-${garden.phase}`}>{phaseMessage}</div>}
          </div>

          <GardenControls
            phase={garden.phase}
            speed={speed}
            onTogglePlay={togglePlay}
            onStep={stepOnce}
            onSpeedChange={changeSpeed}
            onNewGarden={startNewGarden}
            onClear={() => clearDialogRef.current?.showModal()}
            onToggleHelp={toggleHelp}
          />
        </section>

        <HelpPanel open={helpOpen} onClose={closeHelp} />
        {notice && <p className="notice" role="status">{notice}</p>}
        <p className="sr-only" role="status" aria-live="polite">{liveAnnouncement}</p>
      </main>

      <footer>
        <span>CONWAY LIFE OBSERVATION SYSTEM</span>
        <span>宇宙への影響は確認されていません</span>
      </footer>

      <dialog ref={clearDialogRef} className="clear-dialog" aria-labelledby="clear-title">
        <form method="dialog">
          <p className="machine-label">CAUTION, PROBABLY</p>
          <h2 id="clear-title">観測盤を空にしますか？</h2>
          <p>庭の植物を取り除きます。観測装置は必要以上に慎重に待機します。</p>
          <div className="dialog-actions">
            <button type="submit" value="cancel">見守りを続ける</button>
            <button type="submit" value="confirm" className="danger-control" onClick={clearGarden}>空にする</button>
          </div>
        </form>
      </dialog>
    </div>
  )
}

export default App
