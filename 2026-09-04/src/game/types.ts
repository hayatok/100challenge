export type ProductId = 'onigiri' | 'drink' | 'bread' | 'snack' | 'bento' | 'hot'
export type CustomerKind = 'worker' | 'student' | 'neighbor' | 'nightowl' | 'collector'
export type Policy = 'steady' | 'profit' | 'popular'
export type GameSpeed = 1 | 2 | 4

export interface ProductDefinition {
  id: ProductId
  name: string
  price: number
  cost: number
  unlockTier: number
  color: string
  shelf: { x: number; y: number }
}

export interface Customer {
  id: number
  kind: CustomerKind
  x: number
  y: number
  targetX: number
  targetY: number
  state: 'entering' | 'shopping' | 'queueing' | 'paying' | 'leaving'
  productId: ProductId
  basket: number
  timer: number
  patience: number
  color: string
}

export interface DailyReport {
  day: number
  sales: number
  purchases: number
  fixedCosts: number
  waste: number
  profit: number
  visitors: number
  buyers: number
}

export interface StoreEvent {
  id: string
  name: string
  detail: string
  demandMultiplier: number
  productBoost?: ProductId
}

export interface GameState {
  seed: number
  rngState: number
  tick: number
  day: number
  minute: number
  cash: number
  reputation: number
  tier: number
  policy: Policy
  speed: GameSpeed
  paused: boolean
  nextCustomerId: number
  customers: Customer[]
  inventory: Record<ProductId, number>
  salesToday: number
  purchasesToday: number
  wasteToday: number
  visitorsToday: number
  buyersToday: number
  totalVisitors: number
  totalSales: number
  event: StoreEvent
  report: DailyReport | null
  log: string[]
  effects: Array<{ id: number; x: number; y: number; text: string; kind: 'sale' | 'stock' | 'event' }>
}
