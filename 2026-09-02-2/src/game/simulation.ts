import { createDungeon, isWalkable } from './dungeon'
import { createSeededRandom, nextRandom } from './random'
import {
  DUNGEON_HEIGHT,
  DUNGEON_WIDTH,
  emptyAllocations,
  type Allocations,
  type CombatEffect,
  type Dungeon,
  type Enemy,
  type GameState,
  type Hero,
  type Point,
  type Policy,
  type StatKey,
  samePoint,
  tileIndex,
} from './types'

const heroNames = ['アルト', 'ポルカ', 'ゴンザ', 'ミミ', 'レオ', 'ノノ']
const traits = ['慎重', '強がり', '拾い魔', '方向音痴']
const directions: Point[] = [{ x: 1, y: 0 }, { x: -1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: -1 }]

function addLog(log: string[], message: string) {
  return [message, ...log].slice(0, 6)
}

function revealAround(revealed: Uint8Array, point: Point, radius = 6) {
  const next = revealed.slice()
  for (let y = Math.max(0, point.y - radius); y <= Math.min(DUNGEON_HEIGHT - 1, point.y + radius); y += 1) {
    for (let x = Math.max(0, point.x - radius); x <= Math.min(DUNGEON_WIDTH - 1, point.x + radius); x += 1) {
      if (Math.abs(x - point.x) + Math.abs(y - point.y) <= radius + 2) next[tileIndex({ x, y })] = 1
    }
  }
  return next
}

function createHero(seed: number, start: Point): Hero {
  const random = createSeededRandom(seed ^ 0x71f4a7c3)
  const vitality = 4
  return {
    ...start,
    name: heroNames[Math.floor(random() * heroNames.length)],
    trait: traits[Math.floor(random() * traits.length)],
    level: 1,
    xp: 0,
    xpToNext: 18,
    hp: 34 + vitality * 4,
    maxHp: 34 + vitality * 4,
    strength: 4,
    vitality,
    speed: 4,
    luck: 3,
    gold: 0,
    gear: [],
  }
}

export function createGame(seed: number, policy: Policy = 'safe'): GameState {
  const dungeon = createDungeon(seed, 1)
  const hero = createHero(seed, dungeon.start)
  return {
    seed,
    rngState: seed ^ 0xa511e9b3,
    floor: 1,
    dungeon,
    revealed: revealAround(new Uint8Array(DUNGEON_WIDTH * DUNGEON_HEIGHT), hero),
    hero,
    phase: 'briefing',
    policy,
    autoMode: false,
    speed: 1,
    path: [],
    combatEnemyId: null,
    pendingPoints: 0,
    allocations: emptyAllocations(),
    log: [`勇者${hero.name}を採用。性格は「${hero.trait}」です。`],
    ticks: 0,
    kills: 0,
    lootCount: 0,
    effects: [],
    startedAt: null,
    endedAt: null,
  }
}

export function startGame(state: GameState): GameState {
  if (state.phase !== 'briefing') return state
  return { ...state, phase: 'running', startedAt: Date.now(), log: addLog(state.log, `第1地下迷宮へ派遣しました。方針は「${policyLabel(state.policy)}」。`) }
}

export function policyLabel(policy: Policy) {
  if (policy === 'safe') return '安全第一'
  if (policy === 'xp') return '経験値優先'
  return '奥へ進む'
}

export function canChangePolicy(state: GameState) {
  return state.phase === 'briefing' || state.phase === 'levelup' || state.phase === 'checkpoint'
}

export function changePolicy(state: GameState, policy: Policy): GameState {
  if (!canChangePolicy(state) || state.policy === policy) return state
  return { ...state, policy, path: [], log: addLog(state.log, `攻略方針を「${policyLabel(policy)}」に変更。`) }
}

export function togglePause(state: GameState): GameState {
  if (state.phase === 'running') return { ...state, phase: 'paused' }
  if (state.phase === 'paused') return { ...state, phase: 'running' }
  return state
}

function findPath(dungeon: Dungeon, start: Point, goal: Point) {
  if (samePoint(start, goal)) return []
  const size = dungeon.width * dungeon.height
  const previous = new Int32Array(size).fill(-1)
  const queue = new Int32Array(size)
  const startIndex = tileIndex(start, dungeon.width)
  const goalIndex = tileIndex(goal, dungeon.width)
  let head = 0
  let tail = 0
  queue[tail++] = startIndex
  previous[startIndex] = startIndex
  while (head < tail) {
    const current = queue[head++]
    const point = { x: current % dungeon.width, y: Math.floor(current / dungeon.width) }
    for (const direction of directions) {
      const next = { x: point.x + direction.x, y: point.y + direction.y }
      if (!isWalkable(dungeon, next)) continue
      const nextIndex = tileIndex(next, dungeon.width)
      if (previous[nextIndex] !== -1) continue
      previous[nextIndex] = current
      if (nextIndex === goalIndex) {
        head = tail
        break
      }
      queue[tail++] = nextIndex
    }
  }
  if (previous[goalIndex] === -1) return []
  const reversed: Point[] = []
  let current = goalIndex
  while (current !== startIndex) {
    reversed.push({ x: current % dungeon.width, y: Math.floor(current / dungeon.width) })
    current = previous[current]
  }
  return reversed.reverse()
}

function enemyScore(state: GameState, enemy: Enemy, distance: number) {
  const risk = enemy.level - state.hero.level
  const traitRisk = state.hero.trait === '慎重' ? 5 : state.hero.trait === '強がり' ? -3 : 0
  if (state.policy === 'safe') return 80 - distance * 2 - risk * (25 + traitRisk) + (risk <= 0 ? 28 : -45) + (enemy.elite ? -25 : 0)
  if (state.policy === 'xp') return enemy.xp * 7 - distance * 1.4 - Math.max(0, risk) * 14 + (enemy.elite ? 18 : 0)
  return 24 - distance * 1.5 - Math.max(0, risk) * 22
}

function treasureScore(state: GameState, kind: GameState['dungeon']['treasures'][number]['kind'], distance: number) {
  const base = kind === 'potion' && state.hero.hp / state.hero.maxHp < 0.7 ? 150 : kind === 'weapon' || kind === 'armor' ? 92 : kind === 'charm' ? 76 : 62
  const traitBonus = state.hero.trait === '拾い魔' ? 38 : 0
  const policyPenalty = state.policy === 'deep' ? 90 : state.policy === 'xp' ? 8 : 0
  return base + traitBonus - distance * 1.6 - policyPenalty
}

export function chooseObjective(state: GameState) {
  const living = state.dungeon.enemies.filter((enemy) => enemy.hp > 0)
  const candidates = living.map((enemy) => {
    const path = findPath(state.dungeon, state.hero, enemy)
    return { point: { x: enemy.x, y: enemy.y }, path, score: enemyScore(state, enemy, path.length) }
  }).filter((candidate) => candidate.path.length > 0)
  for (const treasure of state.dungeon.treasures.filter((item) => !item.opened)) {
    const path = findPath(state.dungeon, state.hero, treasure)
    if (path.length > 0) candidates.push({ point: { x: treasure.x, y: treasure.y }, path, score: treasureScore(state, treasure.kind, path.length) })
  }
  const stairsPath = findPath(state.dungeon, state.hero, state.dungeon.stairs)
  const stairsScore = state.policy === 'deep'
    ? 160
    : state.policy === 'xp'
      ? (state.hero.level >= state.floor + 2 || living.length === 0 ? 75 : -80)
      : (living.length === 0 ? 100 : -160)
  if (stairsPath.length > 0) candidates.push({ point: state.dungeon.stairs, path: stairsPath, score: stairsScore })
  candidates.sort((a, b) => b.score - a.score || a.path.length - b.path.length)
  return candidates[0]?.path ?? []
}

function finishCombat(state: GameState, enemy: Enemy, enemies: Enemy[], xp: number, critical: boolean): GameState {
  const bounty = Math.max(1, Math.floor(enemy.xp / 3))
  const hero = { ...state.hero, xp, gold: state.hero.gold + bounty }
  const defeatedBoss = enemy.boss
  const leveled = !defeatedBoss && xp >= hero.xpToNext
  return {
    ...state,
    dungeon: { ...state.dungeon, enemies },
    hero,
    phase: defeatedBoss ? 'victory' : leveled ? 'levelup' : 'running',
    pendingPoints: leveled ? 3 : 0,
    allocations: leveled ? emptyAllocations() : state.allocations,
    combatEnemyId: null,
    path: [],
    kills: state.kills + 1,
    effects: addEffect(state, enemy, `+${bounty}G`, 'loot'),
    endedAt: defeatedBoss ? Date.now() : state.endedAt,
    log: addLog(state.log, defeatedBoss
      ? `迷宮事業部長を撃破。第${state.floor}地下迷宮を攻略しました！`
      : `${enemy.name}を撃破。${enemy.xp}EXPを獲得${critical ? '（決裁会心）' : ''}。`),
  }
}

function addEffect(state: GameState, point: Point, text: string, tone: CombatEffect['tone']) {
  const effect: CombatEffect = { ...point, id: state.ticks * 10 + state.effects.length, tick: state.ticks, text, tone }
  return [...state.effects.filter((item) => state.ticks - item.tick < 8), effect].slice(-8)
}

function combatTick(state: GameState, enemy: Enemy): GameState {
  const firstRandom = nextRandom(state.rngState)
  const retreatThreshold = state.policy === 'safe' ? 0.45 : state.policy === 'xp' ? 0.3 : 0.2
  if (!enemy.boss && state.hero.hp / state.hero.maxHp < retreatThreshold) {
    const retreatChance = Math.min(0.88, 0.34 + state.hero.speed * 0.045)
    if (firstRandom.value < retreatChance) {
      const recovered = Math.ceil(state.hero.maxHp * 0.18)
      return {
        ...state,
        rngState: firstRandom.state,
        hero: { ...state.hero, hp: Math.min(state.hero.maxHp, state.hero.hp + recovered) },
        combatEnemyId: null,
        path: findPath(state.dungeon, state.hero, state.dungeon.start),
        log: addLog(state.log, `退却基準に到達。応急処置で${recovered}HP回復し、安全区画へ戻ります。`),
      }
    }
  }
  const secondRandom = nextRandom(firstRandom.state)
  const critical = firstRandom.value < Math.min(0.38, state.hero.luck * 0.025)
  const spread = Math.floor(secondRandom.value * 3) - 1
  const speedBonus = Math.floor(state.hero.speed / 4)
  const heroDamage = Math.max(1, state.hero.strength + Math.floor(state.hero.level / 2) + speedBonus + spread - enemy.defense) * (critical ? 2 : 1)
  const enemyHp = Math.max(0, enemy.hp - heroDamage)
  const enemies = state.dungeon.enemies.map((candidate) => candidate.id === enemy.id ? { ...candidate, hp: enemyHp } : candidate)
  if (enemyHp === 0) return finishCombat({ ...state, rngState: secondRandom.state }, enemy, enemies, state.hero.xp + enemy.xp, critical)

  const evade = secondRandom.value < Math.min(0.34, state.hero.speed * 0.018)
  const enemyDamage = evade ? 0 : Math.max(1, enemy.attack - state.hero.vitality - Math.floor(state.hero.level / 3))
  const heroHp = Math.max(0, state.hero.hp - enemyDamage)
  if (heroHp === 0) {
    return {
      ...state,
      rngState: secondRandom.state,
      dungeon: { ...state.dungeon, enemies },
      hero: { ...state.hero, hp: 0 },
      phase: 'dead',
      endedAt: Date.now(),
      log: addLog(state.log, `${enemy.name}との戦闘で殉職。書類上は「勇敢」でした。`),
    }
  }
  return {
    ...state,
    rngState: secondRandom.state,
    dungeon: { ...state.dungeon, enemies },
    hero: { ...state.hero, hp: heroHp },
    effects: addEffect(state, enemy, `${critical ? '★' : ''}${heroDamage}`, critical ? 'critical' : 'damage'),
    log: critical ? addLog(state.log, `${heroDamage}ダメージの決裁会心！`) : evade ? addLog(state.log, `${enemy.name}の攻撃を回避。`) : state.log,
  }
}

function collectTreasure(state: GameState, point: Point): GameState {
  const treasure = state.dungeon.treasures.find((item) => !item.opened && samePoint(item, point))
  if (!treasure) return state
  const random = nextRandom(state.rngState)
  const treasures = state.dungeon.treasures.map((item) => item.id === treasure.id ? { ...item, opened: true } : item)
  let hero = state.hero
  let message = ''
  let effect = ''
  if (treasure.kind === 'gold') {
    const amount = 8 + state.floor * 4 + Math.floor(random.value * 13)
    hero = { ...hero, gold: hero.gold + amount }
    message = `宝箱から${amount}Gを回収。予算外収入です。`
    effect = `+${amount}G`
  } else if (treasure.kind === 'potion') {
    const amount = Math.ceil(hero.maxHp * 0.35)
    hero = { ...hero, hp: Math.min(hero.maxHp, hero.hp + amount) }
    message = `支給外ポーションで${amount}HP回復。成分表示は読めません。`
    effect = `+${amount}HP`
  } else if (treasure.kind === 'weapon') {
    const name = state.floor >= 4 ? '残業破りの剣' : 'よく切れる支給剣'
    hero = { ...hero, strength: hero.strength + 1, gear: [...hero.gear, name].slice(-3) }
    message = `${name}を装備。腕力が1上がりました。`
    effect = '腕力+1'
  } else if (treasure.kind === 'armor') {
    const name = state.floor >= 4 ? '課長代理の鎧' : 'へこまない官給鎧'
    hero = { ...hero, vitality: hero.vitality + 1, maxHp: hero.maxHp + 4, hp: hero.hp + 4, gear: [...hero.gear, name].slice(-3) }
    message = `${name}を装備。体力が1上がりました。`
    effect = '体力+1'
  } else {
    const name = '稟議の護符'
    hero = { ...hero, luck: hero.luck + 1, gear: [...hero.gear, name].slice(-3) }
    message = `${name}を装備。運が1上がりました。`
    effect = '運+1'
  }
  return {
    ...state,
    rngState: random.state,
    dungeon: { ...state.dungeon, treasures },
    hero,
    lootCount: state.lootCount + 1,
    effects: addEffect(state, point, effect, treasure.kind === 'potion' ? 'heal' : 'loot'),
    log: addLog(state.log, message),
  }
}

function moveTick(state: GameState): GameState {
  const path = state.path.length > 0 ? state.path : chooseObjective(state)
  const next = path[0]
  if (!next) return state
  const enemy = state.dungeon.enemies.find((candidate) => candidate.hp > 0 && samePoint(candidate, next))
  if (enemy) {
    return {
      ...state,
      path,
      combatEnemyId: enemy.id,
      log: addLog(state.log, `${enemy.elite ? '危険指定 ' : ''}${enemy.name}と交戦開始。`),
    }
  }

  let dungeon = state.dungeon
  let hero = { ...state.hero, ...next }
  let log = state.log
  if (dungeon.tiles[tileIndex(next)] === 3) {
    const tiles = dungeon.tiles.slice()
    tiles[tileIndex(next)] = 1
    dungeon = { ...dungeon, tiles }
    const recovered = Math.ceil(hero.maxHp * 0.28)
    hero = { ...hero, hp: Math.min(hero.maxHp, hero.hp + recovered) }
    log = addLog(log, `地下休憩所で${recovered}HP回復。休憩届は事後提出。`)
  }
  const collected = collectTreasure({ ...state, dungeon, hero, log }, next)
  dungeon = collected.dungeon
  hero = collected.hero
  log = collected.log
  if (samePoint(next, dungeon.stairs) && state.floor < 5) {
    return {
      ...collected,
      dungeon,
      hero,
      revealed: revealAround(state.revealed, next),
      phase: 'checkpoint',
      path: [],
      log: addLog(log, `第${state.floor + 1}地下迷宮への階段に到着。危険予報を確認してください。`),
    }
  }
  return { ...collected, dungeon, hero, revealed: revealAround(state.revealed, next), path: path.slice(1), log }
}

function autoPolicy(state: GameState): Policy {
  if (state.hero.hp / state.hero.maxHp < 0.58) return 'safe'
  if (state.hero.level < state.floor + 1) return 'xp'
  return 'deep'
}

export function resolveAutomation(state: GameState): GameState {
  if (!state.autoMode) return state
  if (state.phase === 'levelup') {
    const policy = autoPolicy(state)
    const directed = policy === state.policy ? state : { ...state, policy, log: addLog(state.log, `全自動局長が方針を「${policyLabel(policy)}」へ変更。`) }
    const promoted = confirmLevelUp(applySuggestion(directed))
    return { ...promoted, log: addLog(promoted.log, `全自動局長がLv.${promoted.hero.level}の査定を代行。`) }
  }
  if (state.phase === 'checkpoint') {
    const policy = autoPolicy(state)
    const directed = policy === state.policy ? state : { ...state, policy, log: addLog(state.log, `全自動局長が次階を「${policyLabel(policy)}」と判定。`) }
    return descend(directed)
  }
  return state
}

export function setAutoMode(state: GameState, enabled: boolean): GameState {
  if (state.phase === 'dead' || state.phase === 'victory' || state.autoMode === enabled) return state
  const toggled = { ...state, autoMode: enabled, log: addLog(state.log, enabled ? '全自動局長を起動。査定と階段判断を委任します。' : '全自動局長を停止。人間の承認へ戻します。') }
  return resolveAutomation(toggled)
}

export function tickGame(state: GameState): GameState {
  if (state.phase !== 'running') return state
  const withTick = { ...state, ticks: state.ticks + 1 }
  if (state.combatEnemyId !== null) {
    const enemy = state.dungeon.enemies.find((candidate) => candidate.id === state.combatEnemyId && candidate.hp > 0)
    return resolveAutomation(enemy ? combatTick(withTick, enemy) : { ...withTick, combatEnemyId: null, path: [] })
  }
  return resolveAutomation(moveTick(withTick))
}

export function changeAllocation(state: GameState, stat: StatKey, delta: 1 | -1): GameState {
  if (state.phase !== 'levelup') return state
  if (delta === 1 && state.pendingPoints <= 0) return state
  if (delta === -1 && state.allocations[stat] <= 0) return state
  return {
    ...state,
    pendingPoints: state.pendingPoints - delta,
    allocations: { ...state.allocations, [stat]: state.allocations[stat] + delta },
  }
}

export function suggestedAllocations(state: GameState): Allocations {
  const result = emptyAllocations()
  const hpRatio = state.hero.hp / state.hero.maxHp
  if (hpRatio < 0.45) {
    result.vitality = 2
    result.speed = 1
  } else if (state.policy === 'safe') {
    result.vitality = 2
    result.strength = 1
  } else if (state.policy === 'xp') {
    result.strength = 2
    result.speed = 1
  } else {
    result.speed = 2
    result.luck = 1
  }
  return result
}

export function applySuggestion(state: GameState): GameState {
  if (state.phase !== 'levelup') return state
  return { ...state, allocations: suggestedAllocations(state), pendingPoints: 0 }
}

export function confirmLevelUp(state: GameState): GameState {
  if (state.phase !== 'levelup' || state.pendingPoints !== 0) return state
  const allocation = state.allocations
  const nextLevel = state.hero.level + 1
  const maxHpGain = 2 + allocation.vitality * 4
  const maxHp = state.hero.maxHp + maxHpGain
  const hero: Hero = {
    ...state.hero,
    level: nextLevel,
    xp: Math.max(0, state.hero.xp - state.hero.xpToNext),
    xpToNext: 18 + nextLevel * 9,
    maxHp,
    hp: Math.min(maxHp, state.hero.hp + maxHpGain + 4),
    strength: state.hero.strength + allocation.strength,
    vitality: state.hero.vitality + allocation.vitality,
    speed: state.hero.speed + allocation.speed,
    luck: state.hero.luck + allocation.luck,
  }
  return {
    ...state,
    hero,
    phase: 'running',
    pendingPoints: 0,
    allocations: emptyAllocations(),
    log: addLog(state.log, `Lv.${nextLevel}へ昇格。査定結果を現場へ即時反映。`),
  }
}

export function descend(state: GameState): GameState {
  if (state.phase !== 'checkpoint' || state.floor >= 5) return state
  const floor = state.floor + 1
  const dungeon = createDungeon(state.seed, floor)
  const recovered = Math.ceil(state.hero.maxHp * 0.3)
  const hero = { ...state.hero, ...dungeon.start, hp: Math.min(state.hero.maxHp, state.hero.hp + recovered) }
  return {
    ...state,
    floor,
    dungeon,
    hero,
    revealed: revealAround(new Uint8Array(DUNGEON_WIDTH * DUNGEON_HEIGHT), hero),
    phase: 'running',
    path: [],
    combatEnemyId: null,
    effects: [],
    log: addLog(state.log, `第${floor}地下迷宮へ進入。階段手当として${recovered}HP回復。`),
  }
}

export function threatEstimate(state: GameState, policy: Policy) {
  const averageEnemy = state.dungeon.enemies.filter((enemy) => enemy.hp > 0).reduce((sum, enemy) => sum + enemy.level, 0) / Math.max(1, state.dungeon.enemies.filter((enemy) => enemy.hp > 0).length)
  const heroPower = state.hero.level + (state.hero.strength + state.hero.vitality + state.hero.speed) / 10
  const base = 68 + (heroPower - averageEnemy) * 7
  const modifier = policy === 'safe' ? 14 : policy === 'xp' ? 1 : -11
  return Math.max(18, Math.min(96, Math.round(base + modifier)))
}

export function allocationTotal(allocation: Allocations) {
  return Object.values(allocation).reduce((sum, value) => sum + value, 0)
}
