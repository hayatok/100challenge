import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import DungeonCanvas from './components/DungeonCanvas'
import LevelUpOverlay from './components/LevelUpOverlay'
import PolicyPanel from './components/PolicyPanel'
import {
  changePolicy,
  createGame,
  descend,
  policyLabel,
  setAutoMode,
  startGame,
  tickGame,
  togglePause,
} from './game/simulation'
import { createRandomSeed } from './game/random'
import type { GameSpeed, GameState, Policy } from './game/types'

const speedIntervals: Record<GameSpeed, number> = { 1: 360, 2: 180, 4: 90 }

function initialState() {
  const params = new URLSearchParams(window.location.search)
  const requestedSeed = Number(params.get('seed'))
  const seed = Number.isInteger(requestedSeed) && requestedSeed > 0 ? requestedSeed >>> 0 : createRandomSeed()
  const requestedPolicy = params.get('policy')
  const policy: Policy = requestedPolicy === 'xp' || requestedPolicy === 'deep' ? requestedPolicy : 'safe'
  let state = createGame(seed, policy)
  const demo = params.get('demo')
  if (demo === 'levelup') state = { ...startGame(state), phase: 'levelup', pendingPoints: 3, hero: { ...state.hero, xp: state.hero.xpToNext } }
  if (demo === 'checkpoint') state = { ...startGame(state), phase: 'checkpoint' }
  if (demo === 'dead') state = { ...startGame(state), phase: 'dead', hero: { ...state.hero, hp: 0 }, endedAt: Date.now() }
  if (demo === 'victory') state = { ...startGame(state), phase: 'victory', floor: 5, endedAt: Date.now() }
  return state
}

function formatTime(ticks: number) {
  const seconds = Math.floor(ticks * 0.36)
  const minutes = Math.floor(seconds / 60)
  const remainder = seconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`
}

function App() {
  const [game, setGame] = useState<GameState>(initialState)
  const [announcement, setAnnouncement] = useState('')
  const savedOutcomeRef = useRef<string | null>(null)
  const livingEnemies = useMemo(() => game.dungeon.enemies.filter((enemy) => enemy.hp > 0).length, [game.dungeon.enemies])
  const closedTreasures = useMemo(() => game.dungeon.treasures.filter((treasure) => !treasure.opened).length, [game.dungeon.treasures])
  const currentEnemy = game.combatEnemyId === null ? null : game.dungeon.enemies.find((enemy) => enemy.id === game.combatEnemyId)

  useEffect(() => {
    if (game.phase !== 'running') return
    const interval = window.setInterval(() => {
      if (!document.hidden) setGame((previous) => tickGame(previous))
    }, speedIntervals[game.speed])
    return () => window.clearInterval(interval)
  }, [game.phase, game.speed])

  useEffect(() => {
    if (game.phase !== 'dead' && game.phase !== 'victory') return
    const outcomeId = `${game.seed}-${game.startedAt}-${game.phase}`
    if (savedOutcomeRef.current === outcomeId) return
    savedOutcomeRef.current = outcomeId
    try {
      const key = 'hero-supervision-reports-v1'
      const reports = JSON.parse(localStorage.getItem(key) ?? '[]') as unknown[]
      reports.unshift({ seed: game.seed, result: game.phase, floor: game.floor, level: game.hero.level, kills: game.kills, loot: game.lootCount, gold: game.hero.gold, ticks: game.ticks, date: new Date().toISOString() })
      localStorage.setItem(key, JSON.stringify(reports.slice(0, 10)))
    } catch {
      setAnnouncement('冒険は完了しましたが、報告書を端末へ保存できませんでした。')
    }
  }, [game])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target
      if (target instanceof HTMLButtonElement || target instanceof HTMLInputElement) return
      if (event.key === ' ') {
        event.preventDefault()
        setGame((previous) => togglePause(previous))
      }
      if (event.key === '1' || event.key === '2' || event.key === '4') setGame((previous) => ({ ...previous, speed: Number(event.key) as GameSpeed }))
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [])

  const updateGame = useCallback((next: GameState) => setGame(next), [])
  const restart = useCallback((sameSeed: boolean) => {
    savedOutcomeRef.current = null
    const next = createGame(sameSeed ? game.seed : createRandomSeed(), game.policy)
    setGame(game.autoMode ? setAutoMode(next, true) : next)
  }, [game.autoMode, game.policy, game.seed])

  const hpPercent = Math.max(0, Math.round((game.hero.hp / game.hero.maxHp) * 100))
  const xpPercent = Math.min(100, Math.round((game.hero.xp / game.hero.xpToNext) * 100))
  const phaseText = game.phase === 'running'
    ? currentEnemy ? `${currentEnemy.name}と交戦中` : '自動探索中'
    : game.phase === 'paused' ? '監督官が時を止めています'
      : game.phase === 'levelup' ? 'のうりょく査定中'
        : game.phase === 'checkpoint' ? '階段前の方針確認'
          : game.phase === 'dead' ? '殉職報告を作成中'
            : game.phase === 'victory' ? '迷宮攻略完了' : '派遣前 briefing'

  return (
    <div className="app-shell">
      <header className="top-hud">
        <div className="floor-plate"><span>配属先</span><strong>第{game.floor}地下迷宮</strong></div>
        <div className="hero-id">
          <span className="hero-portrait" aria-hidden="true"><i /></span>
          <span><small>勇者</small><strong>{game.hero.name}</strong><b>Lv.{game.hero.level}</b></span>
        </div>
        <div className="meter-group">
          <div className="meter-row"><span>HP</span><div className="meter"><i className="hp-fill" style={{ width: `${hpPercent}%` }} /></div><strong>{game.hero.hp}/{game.hero.maxHp}</strong></div>
          <div className="meter-row"><span>EXP</span><div className="meter"><i className="xp-fill" style={{ width: `${xpPercent}%` }} /></div><strong>{game.hero.xp}/{game.hero.xpToNext}</strong></div>
        </div>
        <div className="time-plate"><span>経過時間</span><strong>{formatTime(game.ticks)}</strong><small>SEED {game.seed.toString(16).toUpperCase().padStart(8, '0')}</small></div>
      </header>

      <main className="bureau-frame">
        <section className="dungeon-zone" aria-labelledby="dungeon-title">
          <div className="dungeon-status">
            <div><p className="eyebrow">AUTOMATIC FIELD REPORT</p><h1 id="dungeon-title">勇者監督局</h1></div>
            <div className={`status-lamp status-${game.phase}`}><i />{phaseText}</div>
          </div>
          <div className="canvas-frame">
            <span className="map-label">MAP {String(game.floor).padStart(2, '0')} · 残敵 {String(livingEnemies).padStart(2, '0')} · 宝箱 {String(closedTreasures).padStart(2, '0')}</span>
            <DungeonCanvas state={game} />
          </div>
          <div className="field-controls" aria-label="観察操作">
            <button type="button" className="pause-button" disabled={game.phase !== 'running' && game.phase !== 'paused'} onClick={() => setGame((previous) => togglePause(previous))}>
              <span className="control-lamp" />{game.phase === 'paused' ? '監督を再開' : '時を止める'}
            </button>
            <fieldset className="speed-control">
              <legend>観察速度</legend>
              <div>{([1, 2, 4] as GameSpeed[]).map((speed) => <button key={speed} type="button" aria-pressed={game.speed === speed} onClick={() => setGame((previous) => ({ ...previous, speed }))}>{speed}倍</button>)}</div>
            </fieldset>
            <div className="next-event"><span>NEXT REVIEW</span><strong>{game.hero.xpToNext - game.hero.xp > 0 ? `あと${game.hero.xpToNext - game.hero.xp}EXP` : '査定待ち'}</strong></div>
          </div>
        </section>

        <aside className="supervision-zone" aria-label="勇者監督局の指示盤">
          <div className="bureau-sign"><span>王国直轄</span><strong>勇者監督局</strong><small>地下迷宮遠隔指導室</small></div>
          <section className={`auto-console${game.autoMode ? ' is-on' : ''}`} aria-labelledby="auto-title">
            <div><p className="eyebrow">HANDS-FREE DIRECTOR</p><h2 id="auto-title">全自動局長</h2><small>{game.autoMode ? '査定・方針・階段を代行中' : '節目では人間の承認を待ちます'}</small></div>
            <button type="button" role="switch" aria-label="完全オートモード" aria-checked={game.autoMode} disabled={game.phase === 'dead' || game.phase === 'victory'} onClick={() => setGame((previous) => setAutoMode(previous, !previous.autoMode))}>
              <span className="lever-track"><i /></span><strong>{game.autoMode ? 'ON' : 'OFF'}</strong>
            </button>
          </section>
          <section className="spoils-panel" aria-label="現在の戦果">
            <div><span>所持金</span><strong>{game.hero.gold}G</strong></div>
            <div><span>宝箱</span><strong>{game.lootCount}個</strong></div>
            <div className="gear-readout"><span>装備</span><strong>{game.hero.gear.at(-1) ?? '官給品のみ'}</strong></div>
          </section>
          <PolicyPanel state={game} onChange={updateGame} />
          <section className="log-panel" aria-labelledby="log-title">
            <div className="log-heading"><div><p className="eyebrow">LIVE TELEGRAM</p><h2 id="log-title">実況電報</h2></div><span>{String(game.kills).padStart(3, '0')} 体処理</span></div>
            <ol>{game.log.slice(0, 4).map((entry, index) => <li key={`${game.ticks}-${index}`}><time>{index === 0 ? 'NOW' : `-${index}`}</time><span>{entry}</span></li>)}</ol>
          </section>
          <details className="rules-panel">
            <summary>監督官むけ極秘要領</summary>
            <p>勇者の移動と攻撃は止められません。配点と方針だけで、なんとかしてください。</p>
            <p><kbd>Space</kbd> 停止・再開　<kbd>1</kbd><kbd>2</kbd><kbd>4</kbd> 速度</p>
          </details>
        </aside>
      </main>

      <footer><span>ROYAL HERO SUPERVISION BUREAU</span><span>殉職は仕様に含まれます</span></footer>

      {game.phase === 'briefing' && (
        <div className="overlay-backdrop">
          <section className="briefing-card" role="dialog" aria-modal="true" aria-labelledby="briefing-title">
            <p className="document-number">採用通知 第{String(game.seed % 1000).padStart(3, '0')}号</p>
            <p className="eyebrow">NEW HERO ASSIGNMENT</p>
            <h2 id="briefing-title">この勇者を派遣します</h2>
            <div className="hire-hero"><span className="large-portrait" aria-hidden="true" /><div><strong>{game.hero.name}</strong><p>性格: <b>{game.hero.trait}</b></p></div></div>
            <dl className="hire-stats"><div><dt>腕力</dt><dd>{game.hero.strength}</dd></div><div><dt>体力</dt><dd>{game.hero.vitality}</dd></div><div><dt>すばやさ</dt><dd>{game.hero.speed}</dd></div><div><dt>運</dt><dd>{game.hero.luck}</dd></div></dl>
            <p className="briefing-note">直接命令はできません。最初の攻略方針は<strong>{policyLabel(game.policy)}</strong>です。</p>
            <div className="briefing-policies">{(['safe', 'xp', 'deep'] as Policy[]).map((policy) => <button key={policy} type="button" aria-pressed={game.policy === policy} onClick={() => setGame((previous) => changePolicy(previous, policy))}>{policyLabel(policy)}</button>)}</div>
            <button type="button" className="dispatch-button" onClick={() => setGame((previous) => startGame(previous))}>第1地下迷宮へ派遣</button>
          </section>
        </div>
      )}

      {game.phase === 'levelup' && <LevelUpOverlay state={game} onChange={updateGame} />}

      {game.phase === 'checkpoint' && (
        <div className="overlay-backdrop">
          <section className="checkpoint-card" role="dialog" aria-modal="true" aria-labelledby="checkpoint-title">
            <p className="eyebrow">STAIRWAY RISK REVIEW</p>
            <h2 id="checkpoint-title">第{game.floor + 1}地下迷宮へ進みます</h2>
            <p>階段手当で最大HPの30%を回復します。現在の方針は<strong>{policyLabel(game.policy)}</strong>です。</p>
            <div className="checkpoint-policies">{(['safe', 'xp', 'deep'] as Policy[]).map((policy) => <button key={policy} type="button" aria-pressed={game.policy === policy} onClick={() => setGame((previous) => changePolicy(previous, policy))}>{policyLabel(policy)}</button>)}</div>
            <button type="button" className="dispatch-button" onClick={() => setGame((previous) => descend(previous))}>方針を承認して降りる</button>
          </section>
        </div>
      )}

      {(game.phase === 'dead' || game.phase === 'victory') && (
        <div className="overlay-backdrop">
          <section className={`outcome-sheet outcome-${game.phase}`} role="dialog" aria-modal="true" aria-labelledby="outcome-title">
            <p className="outcome-stamp">{game.phase === 'victory' ? '事業完了' : '殉職'}</p>
            <p className="eyebrow">FINAL FIELD REPORT</p>
            <h2 id="outcome-title">{game.phase === 'victory' ? '迷宮攻略報告書' : '勇者帰還不能報告書'}</h2>
            <p className="outcome-lead">勇者{game.hero.name}は、{game.phase === 'victory' ? '迷宮事業部長を倒して生還しました。' : `第${game.floor}地下迷宮で力尽きました。`}</p>
            <dl className="outcome-stats"><div><dt>到達</dt><dd>地下{game.floor}階</dd></div><div><dt>最終Lv</dt><dd>{game.hero.level}</dd></div><div><dt>討伐</dt><dd>{game.kills}体</dd></div><div><dt>戦利金</dt><dd>{game.hero.gold}G</dd></div></dl>
            <blockquote>{game.log[0]}</blockquote>
            <div className="outcome-actions"><button type="button" onClick={() => restart(true)}>同じ迷宮で再派遣</button><button type="button" className="dispatch-button" onClick={() => restart(false)}>新しい迷宮を発注</button></div>
          </section>
        </div>
      )}

      <p className="sr-only" role="status" aria-live="polite">{announcement || game.log[0]}</p>
    </div>
  )
}

export default App
