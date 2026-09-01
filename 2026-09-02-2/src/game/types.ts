export const DUNGEON_WIDTH = 40
export const DUNGEON_HEIGHT = 28
export const FINAL_FLOOR = 5

export type Point = { x: number; y: number }
export type Tile = 0 | 1 | 2 | 3
export type Policy = 'safe' | 'xp' | 'deep'
export type GameSpeed = 1 | 2 | 4
export type GamePhase = 'briefing' | 'running' | 'paused' | 'levelup' | 'checkpoint' | 'dead' | 'victory'
export type EnemyKind = 'slime' | 'bat' | 'skeleton' | 'goblin' | 'ogre' | 'boss'
export type TreasureKind = 'gold' | 'potion' | 'weapon' | 'armor' | 'charm'
export type EffectTone = 'damage' | 'critical' | 'heal' | 'loot'

export type Enemy = Point & {
  id: number
  kind: EnemyKind
  name: string
  level: number
  hp: number
  maxHp: number
  attack: number
  defense: number
  xp: number
  elite: boolean
  boss: boolean
}

export type Treasure = Point & {
  id: number
  kind: TreasureKind
  opened: boolean
}

export type CombatEffect = Point & {
  id: number
  tick: number
  text: string
  tone: EffectTone
}

export type Dungeon = {
  width: number
  height: number
  tiles: Uint8Array
  start: Point
  stairs: Point
  enemies: Enemy[]
  treasures: Treasure[]
}

export type Hero = Point & {
  name: string
  trait: string
  level: number
  xp: number
  xpToNext: number
  hp: number
  maxHp: number
  strength: number
  vitality: number
  speed: number
  luck: number
  gold: number
  gear: string[]
}

export type StatKey = 'strength' | 'vitality' | 'speed' | 'luck'
export type Allocations = Record<StatKey, number>

export type GameState = {
  seed: number
  rngState: number
  floor: number
  dungeon: Dungeon
  revealed: Uint8Array
  hero: Hero
  phase: GamePhase
  policy: Policy
  autoMode: boolean
  speed: GameSpeed
  path: Point[]
  combatEnemyId: number | null
  pendingPoints: number
  allocations: Allocations
  log: string[]
  ticks: number
  kills: number
  lootCount: number
  effects: CombatEffect[]
  startedAt: number | null
  endedAt: number | null
}

export const emptyAllocations = (): Allocations => ({ strength: 0, vitality: 0, speed: 0, luck: 0 })

export function tileIndex(point: Point, width = DUNGEON_WIDTH) {
  return point.y * width + point.x
}

export function samePoint(a: Point, b: Point) {
  return a.x === b.x && a.y === b.y
}
