import { useEffect, useMemo, useState } from 'react'
import StoreCanvas, { productSymbol } from './StoreCanvas'
import { products } from './game/data'
import { createRandomSeed } from './game/random'
import { createGame, operatingReserve, setPolicy, tickGame, upgradeCost } from './game/simulation'
import type { GameSpeed, GameState, Policy } from './game/types'

const intervals: Record<GameSpeed, number> = { 1: 165, 2: 82, 4: 41 }
const policyLabels: Record<Policy, { name: string; detail: string }> = {
  steady: { name: '堅実営業', detail: '在庫13個、現金を厚めに残す' },
  profit: { name: '利益優先', detail: '在庫9個、仕入れを絞る' },
  popular: { name: '人気優先', detail: '在庫17個、品切れを減らす' },
}

function loadInitialState() {
  const params = new URLSearchParams(window.location.search)
  const seedValue = Number(params.get('seed'))
  const seed = Number.isInteger(seedValue) && seedValue > 0 ? seedValue >>> 0 : createRandomSeed()
  const policy = params.get('policy')
  return createGame(seed, policy === 'profit' || policy === 'popular' ? policy : 'steady')
}

function formatMoney(value: number) {
  return `¥${Math.round(value).toLocaleString('ja-JP')}`
}

function formatClock(minute: number) {
  const hour = Math.floor(minute / 60) % 24
  const minutes = minute % 60
  return `${String(hour).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}

function App() {
  const [game, setGame] = useState<GameState>(loadInitialState)
  const [showHelp, setShowHelp] = useState(false)

  useEffect(() => {
    if (game.paused) return
    const id = window.setInterval(() => {
      if (!document.hidden) setGame((previous) => tickGame(previous))
    }, intervals[game.speed])
    return () => window.clearInterval(id)
  }, [game.paused, game.speed])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.target instanceof HTMLButtonElement) return
      if (event.key === ' ') {
        event.preventDefault()
        setGame((previous) => ({ ...previous, paused: !previous.paused }))
      }
      if (event.key === '1' || event.key === '2' || event.key === '4') setGame((previous) => ({ ...previous, speed: Number(event.key) as GameSpeed }))
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [])

  const availableProducts = useMemo(() => products.filter((product) => product.unlockTier <= game.tier), [game.tier])
  const investment = game.tier < 4 ? { cost: upgradeCost(game.tier), reserve: operatingReserve({ tier: game.tier + 1 }) } : null
  const canAfford = investment ? game.cash - investment.cost >= investment.reserve : false
  const progress = investment ? Math.min(100, Math.max(0, ((game.cash - investment.reserve) / investment.cost) * 100)) : 100
  const report = game.report

  return (
    <div className="app-shell">
      <header className="store-header">
        <div className="brand-block">
          <span className="brand-mark" aria-hidden="true">B</span>
          <div><small>年中だいたい営業</small><strong>ぼんやりマート<span>24</span></strong></div>
        </div>
        <dl className="headline-stats">
          <div><dt>営業日</dt><dd>{game.day}日目</dd></div>
          <div><dt>時刻</dt><dd>{formatClock(game.minute)}</dd></div>
          <div><dt>所持金</dt><dd className={game.cash < operatingReserve(game) ? 'danger' : ''}>{formatMoney(game.cash)}</dd></div>
          <div><dt>評判</dt><dd>{game.reputation.toFixed(1)}</dd></div>
        </dl>
      </header>

      <main className="game-layout">
        <section className="store-zone" aria-labelledby="store-title">
          <div className="store-titlebar">
            <div><p className="eyebrow">AUTOMATIC CONVENIENCE STORE</p><h1 id="store-title">店長は見ているだけ</h1></div>
            <div className={`open-sign${game.paused ? ' is-paused' : ''}`}><i />{game.paused ? '休憩中' : '営業中'}</div>
          </div>
          <div className="canvas-frame">
            <span className="map-tag">STORE Lv.{game.tier} · 店内 {game.customers.length}名 · 本日 {game.buyersToday}会計</span>
            <StoreCanvas game={game} />
            <div className="event-banner"><span>本日の気配</span><strong>{game.event.name}</strong><small>{game.event.detail}</small></div>
          </div>
          <div className="observation-controls">
            <button type="button" className="pause-button" onClick={() => setGame((previous) => ({ ...previous, paused: !previous.paused }))}>
              <span className="control-light" />{game.paused ? '営業を再開' : 'ちょっと止める'}
            </button>
            <fieldset>
              <legend>観察速度</legend>
              <div>{([1, 2, 4] as GameSpeed[]).map((speed) => <button key={speed} type="button" aria-pressed={game.speed === speed} onClick={() => setGame((previous) => ({ ...previous, speed }))}>{speed}倍</button>)}</div>
            </fieldset>
            <div className="today-sales"><span>本日の売上</span><strong>{formatMoney(game.salesToday)}</strong></div>
          </div>
        </section>

        <aside className="management-zone" aria-label="経営管理盤">
          <section className="manager-card">
            <div className="manager-face" aria-hidden="true"><i /><b /></div>
            <div><p className="eyebrow">AUTONOMOUS MANAGER</p><h2>店長 キノシタ</h2><p>{game.log[0]}</p></div>
          </section>

          <section className="cashflow-panel" aria-labelledby="cashflow-title">
            <div className="panel-heading"><div><p className="eyebrow">TODAY'S CASHFLOW</p><h2 id="cashflow-title">本日の収支</h2></div><span>{game.salesToday - game.purchasesToday >= 0 ? '暫定黒字' : '仕入先行'}</span></div>
            <dl>
              <div><dt>売上</dt><dd>{formatMoney(game.salesToday)}</dd></div>
              <div><dt>仕入</dt><dd>−{formatMoney(game.purchasesToday)}</dd></div>
              <div className="cashflow-total"><dt>営業差額</dt><dd>{formatMoney(game.salesToday - game.purchasesToday)}</dd></div>
            </dl>
            {report && <p className={`last-report${report.profit < 0 ? ' is-loss' : ''}`}>前日: {report.profit >= 0 ? '黒字' : '赤字'} {formatMoney(Math.abs(report.profit))}／来客{report.visitors}人</p>}
          </section>

          <section className="investment-panel" aria-labelledby="investment-title">
            <div className="panel-heading"><div><p className="eyebrow">STORE DEVELOPMENT</p><h2 id="investment-title">次の発展</h2></div><span>自動審査</span></div>
            {investment ? <>
              <div className="investment-line"><strong>第{game.tier + 1}形態へ増築</strong><b>{formatMoney(investment.cost)}</b></div>
              <div className="progress-track" aria-label={`増築資金 ${Math.round(progress)}パーセント`}><i style={{ width: `${progress}%` }} /></div>
              <p className={canAfford ? 'ready' : ''}>{canAfford ? '資金条件クリア。評判と店長の決断待ち。' : `増築後も${formatMoney(investment.reserve)}を残すまで保留。`}</p>
            </> : <p className="ready">最終形態です。店長は物件情報を見ています。</p>}
          </section>

          <section className="inventory-panel" aria-labelledby="inventory-title">
            <div className="panel-heading"><div><p className="eyebrow">LIVE INVENTORY</p><h2 id="inventory-title">棚のようす</h2></div><span>自動発注</span></div>
            <ul>{availableProducts.map((product) => <li key={product.id} className={game.inventory[product.id] <= 4 ? 'low-stock' : ''}><i style={{ background: product.color }}>{productSymbol[product.id]}</i><span>{product.name}</span><strong>{game.inventory[product.id]}</strong><small>{game.inventory[product.id] <= 4 ? '発注対象' : '在庫'}</small></li>)}</ul>
          </section>

          <section className="policy-panel" aria-labelledby="policy-title">
            <div className="panel-heading"><div><p className="eyebrow">OWNER'S POLICY</p><h2 id="policy-title">経営方針</h2></div><span>いつでも変更</span></div>
            <div className="policy-options">{(Object.keys(policyLabels) as Policy[]).map((policy) => <button key={policy} type="button" aria-pressed={game.policy === policy} onClick={() => setGame((previous) => setPolicy(previous, policy))}><strong>{policyLabels[policy].name}</strong><small>{policyLabels[policy].detail}</small></button>)}</div>
          </section>

          <section className="log-panel" aria-labelledby="log-title">
            <div className="panel-heading"><div><p className="eyebrow">MANAGER'S MUMBLE</p><h2 id="log-title">店長のひとりごと</h2></div><span>来客 {game.totalVisitors}</span></div>
            <ol>{game.log.slice(0, 5).map((entry, index) => <li key={`${game.tick}-${index}`}><time>{index === 0 ? 'NOW' : `−${index}`}</time><span>{entry}</span></li>)}</ol>
          </section>

          <button type="button" className="help-button" onClick={() => setShowHelp(true)}>店長向け営業要領</button>
        </aside>
      </main>

      <footer><span>BONNYARI MART OPERATIONS</span><span>発展しない日は、だいたい資金不足です</span></footer>

      {showHelp && <div className="modal-backdrop" onMouseDown={() => setShowHelp(false)}>
        <section className="help-sheet" role="dialog" aria-modal="true" aria-labelledby="help-title" onMouseDown={(event) => event.stopPropagation()}>
          <p className="document-number">営業要領 第24号</p>
          <p className="eyebrow">HOW TO WATCH A STORE</p>
          <h2 id="help-title">この店は勝手に働きます</h2>
          <p>お客さんは商品を選び、レジで会計し、店員が在庫を自動発注します。売上から仕入・人件費・家賃・電気代・廃棄を支払い、十分な運転資金と評判があると店長が増築します。</p>
          <ul><li>堅実営業: 標準的な在庫を保ちます</li><li>利益優先: 仕入れを抑えますが品切れが増えます</li><li>人気優先: 在庫を厚くして評判を守ります</li></ul>
          <p><kbd>Space</kbd> 停止・再開　<kbd>1</kbd><kbd>2</kbd><kbd>4</kbd> 観察速度</p>
          <div className="help-actions"><button type="button" onClick={() => setGame(createGame(game.seed, game.policy))}>同じ街で開店し直す</button><button type="button" className="primary" onClick={() => setShowHelp(false)}>営業へ戻る</button></div>
        </section>
      </div>}

      <p className="sr-only" role="status" aria-live="polite">{game.log[0]}</p>
    </div>
  )
}

export default App
