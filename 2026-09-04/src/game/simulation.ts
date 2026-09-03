import { customerProfiles, events, products } from './data'
import { randomValue } from './random'
import type { Customer, CustomerKind, GameState, Policy, ProductId } from './types'

const door = { x: 2, y: 11 }
const register = { x: 3, y: 4 }
const initialInventory: Record<ProductId, number> = { onigiri: 14, drink: 14, bread: 12, snack: 12, bento: 0, hot: 0 }
const customerKinds: CustomerKind[] = ['worker', 'student', 'neighbor', 'nightowl', 'collector']

function addLog(log: string[], message: string) {
  return [message, ...log].slice(0, 7)
}

function draw(state: GameState) {
  const result = randomValue(state.rngState)
  return { state: { ...state, rngState: result.state }, value: result.value }
}

function enabledProducts(state: GameState) {
  return products.filter((product) => product.unlockTier <= state.tier)
}

function chooseProduct(state: GameState, kind: CustomerKind) {
  let next = state
  const candidates = enabledProducts(state)
  const favorites = customerProfiles[kind].favorites.filter((id) => candidates.some((product) => product.id === id))
  const drawResult = draw(next)
  next = drawResult.state
  let pool = drawResult.value < 0.72 && favorites.length > 0 ? favorites : candidates.map((product) => product.id)
  if (state.event.productBoost && state.inventory[state.event.productBoost] >= 0 && candidates.some((item) => item.id === state.event.productBoost)) {
    const boostDraw = draw(next)
    next = boostDraw.state
    if (boostDraw.value < 0.48) pool = [state.event.productBoost]
  }
  const pickDraw = draw(next)
  next = pickDraw.state
  return { state: next, productId: pool[Math.floor(pickDraw.value * pool.length)] ?? 'onigiri' }
}

function customerDemand(state: GameState) {
  const hour = state.minute / 60
  const timeMultiplier = hour >= 11 && hour < 14 ? 2.35 : hour >= 7 && hour < 10 ? 1.55 : hour >= 17 && hour < 21 ? 1.8 : hour < 5 ? 0.34 : 0.82
  const tierMultiplier = 0.82 + state.tier * 0.2
  const reputationMultiplier = 0.85 + Math.min(0.65, state.reputation / 100)
  return 0.105 * timeMultiplier * tierMultiplier * reputationMultiplier * state.event.demandMultiplier
}

function chooseKind(state: GameState) {
  const hour = state.minute / 60
  let pool: CustomerKind[] = hour < 5 ? ['nightowl', 'nightowl', 'worker'] : hour < 10 ? ['worker', 'worker', 'neighbor'] : hour < 16 ? ['worker', 'student', 'neighbor', 'collector'] : ['student', 'worker', 'neighbor', 'nightowl']
  if (state.event.id === 'buzz') pool = [...pool, 'collector', 'collector']
  const result = draw(state)
  return { state: result.state, kind: pool[Math.floor(result.value * pool.length)] ?? customerKinds[0] }
}

function spawnCustomer(state: GameState) {
  if (state.customers.length >= 12) return state
  const spawnDraw = draw(state)
  let next = spawnDraw.state
  if (spawnDraw.value >= customerDemand(next)) return next
  const kindResult = chooseKind(next)
  next = kindResult.state
  const productResult = chooseProduct(next, kindResult.kind)
  next = productResult.state
  const product = products.find((item) => item.id === productResult.productId)!
  const basketDraw = draw(next)
  next = basketDraw.state
  const basket = basketDraw.value > 0.82 ? 3 : basketDraw.value > 0.42 ? 2 : 1
  const customer: Customer = {
    id: next.nextCustomerId,
    kind: kindResult.kind,
    x: door.x,
    y: door.y,
    targetX: product.shelf.x,
    targetY: product.shelf.y + 1,
    state: 'entering',
    productId: product.id,
    basket,
    timer: 0,
    patience: 42,
    color: customerProfiles[kindResult.kind].color,
  }
  return { ...next, nextCustomerId: next.nextCustomerId + 1, visitorsToday: next.visitorsToday + 1, totalVisitors: next.totalVisitors + 1, customers: [...next.customers, customer] }
}

function stepToward(customer: Customer) {
  if (customer.x !== customer.targetX) return { ...customer, x: customer.x + Math.sign(customer.targetX - customer.x) }
  if (customer.y !== customer.targetY) return { ...customer, y: customer.y + Math.sign(customer.targetY - customer.y) }
  return customer
}

function updateCustomers(state: GameState) {
  let next = state
  const updated: Customer[] = []
  for (const original of state.customers) {
    let customer = { ...original, timer: original.timer + 1, patience: original.patience - 1 }
    if (customer.state === 'entering') {
      customer = stepToward(customer)
      if (customer.x === customer.targetX && customer.y === customer.targetY) customer = { ...customer, state: 'shopping', timer: 0 }
    } else if (customer.state === 'shopping' && customer.timer >= 3) {
      const available = next.inventory[customer.productId]
      const amount = Math.min(customer.basket, available)
      if (amount > 0) {
        customer = { ...customer, basket: amount, state: 'queueing', targetX: register.x, targetY: register.y + 1, timer: 0 }
        next = { ...next, inventory: { ...next.inventory, [customer.productId]: available - amount } }
      } else {
        customer = { ...customer, state: 'leaving', targetX: door.x, targetY: door.y, timer: 0 }
        next = { ...next, reputation: Math.max(0, next.reputation - 0.25), log: addLog(next.log, `${customerProfiles[customer.kind].name}は品切れ棚を見つめ、静かに帰りました。`) }
      }
    } else if (customer.state === 'queueing') {
      const paying = updated.some((item) => item.state === 'paying')
      customer = stepToward(customer)
      if (customer.x === customer.targetX && customer.y === customer.targetY && !paying) customer = { ...customer, state: 'paying', timer: 0 }
      if (customer.patience <= 0) {
        customer = { ...customer, state: 'leaving', targetX: door.x, targetY: door.y }
        next = { ...next, reputation: Math.max(0, next.reputation - 0.4), log: addLog(next.log, 'レジ待ちのお客さんが時計を見て帰りました。') }
      }
    } else if (customer.state === 'paying' && customer.timer >= 4) {
      const product = products.find((item) => item.id === customer.productId)!
      const sale = product.price * customer.basket
      customer = { ...customer, state: 'leaving', targetX: door.x, targetY: door.y, timer: 0 }
      next = {
        ...next,
        cash: next.cash + sale,
        salesToday: next.salesToday + sale,
        totalSales: next.totalSales + sale,
        buyersToday: next.buyersToday + 1,
        reputation: Math.min(100, next.reputation + 0.14 * customer.basket),
        log: addLog(next.log, `${customerProfiles[customer.kind].name}が${product.name}を${customer.basket}個購入。`),
        effects: [...next.effects, { id: next.tick * 100 + customer.id, x: register.x, y: register.y, text: `¥${sale}`, kind: 'sale' as const }].slice(-8),
      }
    } else if (customer.state === 'leaving') {
      customer = stepToward(customer)
      if (customer.x === door.x && customer.y === door.y) continue
    }
    updated.push(customer)
  }
  return { ...next, customers: updated }
}

function restock(state: GameState) {
  if (state.tick % 12 !== 0) return state
  let next = state
  for (const product of enabledProducts(next)) {
    if (next.inventory[product.id] > 4) continue
    const target = next.policy === 'steady' ? 13 : next.policy === 'profit' ? 9 : 17
    const amount = target - next.inventory[product.id]
    const cost = amount * product.cost
    const reserve = operatingReserve(next)
    if (next.cash - cost < reserve * 0.4) continue
    next = {
      ...next,
      cash: next.cash - cost,
      purchasesToday: next.purchasesToday + cost,
      inventory: { ...next.inventory, [product.id]: target },
      effects: [...next.effects, { id: next.tick * 10 + product.unlockTier, x: product.shelf.x, y: product.shelf.y, text: `+${amount}`, kind: 'stock' as const }].slice(-8),
    }
  }
  return next
}

export function operatingReserve(state: Pick<GameState, 'tier'>) {
  return 18_000 + state.tier * 6_000
}

export function upgradeCost(tier: number) {
  return tier === 1 ? 48_000 : tier === 2 ? 92_000 : 160_000
}

function maybeUpgrade(state: GameState) {
  if (state.tier >= 4) return state
  const requiredReputation = state.tier === 1 ? 9 : state.tier === 2 ? 25 : 48
  const cost = upgradeCost(state.tier)
  const reserve = operatingReserve({ tier: state.tier + 1 })
  if (state.reputation < requiredReputation) return { ...state, log: addLog(state.log, `増築審査は評判不足で保留。あと${Math.ceil(requiredReputation - state.reputation)}評判。`) }
  if (state.cash - cost < reserve) return { ...state, log: addLog(state.log, `増築費¥${cost.toLocaleString()}は運転資金を守るため見送り。`) }
  const decision = draw(state)
  if (decision.value > 0.72) return { ...decision.state, log: addLog(decision.state.log, '店長は増築図面を一度しまいました。明日また考えます。') }
  const nextTier = state.tier + 1
  const unlocked = products.filter((product) => product.unlockTier === nextTier).map((product) => product.name).join('・') || '売り場'
  return {
    ...decision.state,
    tier: nextTier,
    cash: decision.state.cash - cost,
    reputation: Math.min(100, decision.state.reputation + 3),
    log: addLog(decision.state.log, `第${nextTier}形態へ増築！ ${unlocked}が使えるようになりました。`),
    effects: [...decision.state.effects, { id: decision.state.tick * 10, x: 10, y: 2, text: '増築!', kind: 'event' as const }].slice(-8),
  }
}

function chooseDailyEvent(state: GameState) {
  const result = draw(state)
  const index = result.value < 0.32 ? 0 : 1 + Math.floor(((result.value - 0.32) / 0.68) * (events.length - 1))
  return { ...result.state, event: events[Math.min(events.length - 1, index)], log: addLog(result.state.log, `本日の気配「${events[Math.min(events.length - 1, index)].name}」`) }
}

function closeDay(state: GameState) {
  const wages = 3_500 + state.tier * 1_200
  const rent = 2_600 + state.tier * 900
  const electricity = 900 + state.tier * 650
  const fixedCosts = wages + rent + electricity
  let waste = 0
  const inventory = { ...state.inventory }
  for (const product of enabledProducts(state)) {
    const perishable = product.id === 'onigiri' || product.id === 'bread' || product.id === 'bento' || product.id === 'hot'
    if (!perishable) continue
    const amount = Math.floor(inventory[product.id] * 0.12)
    inventory[product.id] -= amount
    waste += amount * product.cost
  }
  const profit = state.salesToday - state.purchasesToday - fixedCosts - waste
  const report = { day: state.day, sales: state.salesToday, purchases: state.purchasesToday, fixedCosts, waste, profit, visitors: state.visitorsToday, buyers: state.buyersToday }
  let next: GameState = {
    ...state,
    cash: state.cash - fixedCosts - waste,
    inventory,
    report,
    day: state.day + 1,
    salesToday: 0,
    purchasesToday: 0,
    wasteToday: 0,
    visitorsToday: 0,
    buyersToday: 0,
    log: addLog(state.log, `${state.day}日目は${profit >= 0 ? '黒字' : '赤字'} ¥${Math.abs(profit).toLocaleString()}。来客${state.visitorsToday}人。`),
  }
  next = maybeUpgrade(next)
  return chooseDailyEvent(next)
}

export function createGame(seed = 20260904, policy: Policy = 'steady'): GameState {
  const base: GameState = {
    seed,
    rngState: seed ^ 0x9e3779b9,
    tick: 0,
    day: 1,
    minute: 6 * 60,
    cash: 96_000,
    reputation: 7,
    tier: 1,
    policy,
    speed: 1,
    paused: false,
    nextCustomerId: 1,
    customers: [],
    inventory: { ...initialInventory },
    salesToday: 0,
    purchasesToday: 0,
    wasteToday: 0,
    visitorsToday: 0,
    buyersToday: 0,
    totalVisitors: 0,
    totalSales: 0,
    event: events[0],
    report: null,
    log: ['ぼんやりマート24、午前6時に開店しました。'],
    effects: [],
  }
  return chooseDailyEvent(base)
}

export function tickGame(state: GameState): GameState {
  if (state.paused) return state
  let next = {
    ...state,
    tick: state.tick + 1,
    minute: state.minute + 3,
    effects: state.effects.filter((effect) => state.tick - Math.floor(effect.id / (effect.kind === 'sale' ? 100 : 10)) < 7),
  }
  next = updateCustomers(next)
  next = spawnCustomer(next)
  next = restock(next)
  if (next.minute >= 24 * 60) next = closeDay({ ...next, minute: next.minute - 24 * 60 })
  return next
}

export function setPolicy(state: GameState, policy: Policy) {
  if (state.policy === policy) return state
  const labels: Record<Policy, string> = { steady: '堅実営業', profit: '利益優先', popular: '人気優先' }
  return { ...state, policy, log: addLog(state.log, `経営方針を「${labels[policy]}」へ変更。`) }
}

export function runTicks(state: GameState, count: number) {
  let next = state
  for (let index = 0; index < count; index += 1) next = tickGame(next)
  return next
}
