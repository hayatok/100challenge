import { describe, expect, it } from 'vitest'
import { createDungeon, isWalkable } from './dungeon'
import { applySuggestion, changeAllocation, changePolicy, chooseObjective, confirmLevelUp, createGame, descend, setAutoMode, startGame, tickGame } from './simulation'
import type { GameState, Policy } from './types'
import { DUNGEON_HEIGHT, DUNGEON_WIDTH, samePoint, tileIndex } from './types'

function reachableTiles(seed: number, floor: number) {
  const dungeon = createDungeon(seed, floor)
  const visited = new Set<number>([tileIndex(dungeon.start)])
  const queue = [dungeon.start]
  while (queue.length > 0) {
    const point = queue.shift()!
    for (const next of [{ x: point.x + 1, y: point.y }, { x: point.x - 1, y: point.y }, { x: point.x, y: point.y + 1 }, { x: point.x, y: point.y - 1 }]) {
      const index = tileIndex(next)
      if (visited.has(index) || !isWalkable(dungeon, next)) continue
      visited.add(index)
      queue.push(next)
    }
  }
  return { dungeon, visited }
}

function expectValidState(state: GameState) {
  expect(isWalkable(state.dungeon, state.hero)).toBe(true)
  expect(Number.isFinite(state.hero.hp)).toBe(true)
  expect(state.hero.hp).toBeGreaterThanOrEqual(0)
  expect(state.hero.hp).toBeLessThanOrEqual(state.hero.maxHp)
  expect(state.hero.maxHp).toBeGreaterThan(0)
  expect(state.hero.xp).toBeGreaterThanOrEqual(0)
  expect(state.pendingPoints).toBeGreaterThanOrEqual(0)
  expect(state.dungeon.enemies.every((enemy) => enemy.hp >= 0 && enemy.hp <= enemy.maxHp && isWalkable(state.dungeon, enemy))).toBe(true)
}

describe('dungeon generation', () => {
  it('is deterministic and always connects start to stairs', () => {
    for (const seed of [1, 7, 42, 999, 0xfffffff]) {
      const first = createDungeon(seed, 3)
      const second = createDungeon(seed, 3)
      expect(Array.from(first.tiles)).toEqual(Array.from(second.tiles))
      expect(first.enemies).toEqual(second.enemies)
      const { dungeon, visited } = reachableTiles(seed, 3)
      expect(visited.has(tileIndex(dungeon.stairs))).toBe(true)
    }
  })

  it('keeps every generated enemy on a walkable tile and the boss on floor five', () => {
    const dungeon = createDungeon(20260902, 5)
    expect(dungeon.width).toBe(DUNGEON_WIDTH)
    expect(dungeon.height).toBe(DUNGEON_HEIGHT)
    expect(dungeon.enemies.every((enemy) => isWalkable(dungeon, enemy))).toBe(true)
    expect(dungeon.enemies.some((enemy) => enemy.boss && samePoint(enemy, dungeon.stairs))).toBe(true)
  })

  it('keeps stairs, enemies, and treasure reachable without duplicate placements across many seeds', () => {
    for (let seed = 1; seed <= 120; seed += 1) {
      for (let floor = 1; floor <= 5; floor += 1) {
        const { dungeon, visited } = reachableTiles(seed * 7919, floor)
        expect(visited.has(tileIndex(dungeon.stairs))).toBe(true)
        const occupied = new Set<number>()
        for (const enemy of dungeon.enemies.filter((item) => !item.boss)) {
          const index = tileIndex(enemy)
          expect(dungeon.tiles[index]).toBe(1)
          expect(occupied.has(index)).toBe(false)
          occupied.add(index)
        }
        for (const treasure of dungeon.treasures) {
          const index = tileIndex(treasure)
          expect(dungeon.tiles[index]).toBe(1)
          expect(visited.has(index)).toBe(true)
          expect(occupied.has(index)).toBe(false)
          occupied.add(index)
        }
      }
    }
  })
})

describe('hero supervision simulation', () => {
  function autoRun(seed: number, policy: Policy) {
    let state: GameState = startGame(createGame(seed, policy))
    for (let tick = 0; tick < 5_000 && state.phase !== 'dead' && state.phase !== 'victory'; tick += 1) {
      if (state.phase === 'levelup') state = confirmLevelUp(applySuggestion(state))
      else if (state.phase === 'checkpoint') state = descend(state)
      else state = tickGame(state)
    }
    return state
  }

  it('runs deterministically from the same seed and inputs', () => {
    let first = startGame(createGame(12345, 'xp'))
    let second = startGame(createGame(12345, 'xp'))
    for (let index = 0; index < 90; index += 1) {
      first = tickGame(first)
      second = tickGame(second)
      if (first.phase === 'levelup') {
        first = changeAllocation(changeAllocation(changeAllocation(first, 'strength', 1), 'strength', 1), 'speed', 1)
        first = confirmLevelUp(first)
      }
      if (second.phase === 'levelup') {
        second = changeAllocation(changeAllocation(changeAllocation(second, 'strength', 1), 'strength', 1), 'speed', 1)
        second = confirmLevelUp(second)
      }
    }
    expect(first.hero).toEqual(second.hero)
    expect(first.dungeon.enemies).toEqual(second.dungeon.enemies)
    expect(first.phase).toBe(second.phase)
  })

  it('changes objective selection when the policy changes', () => {
    const base = startGame(createGame(3344, 'safe'))
    const stairsPath = chooseObjective(changePolicy({ ...base, phase: 'levelup' }, 'deep'))
    expect(stairsPath.at(-1)).toEqual(base.dungeon.stairs)
  })

  it('requires all three points before confirming a level up', () => {
    const base = { ...startGame(createGame(77)), phase: 'levelup' as const, pendingPoints: 3 }
    expect(confirmLevelUp(base).hero.level).toBe(1)
    const allocated = changeAllocation(changeAllocation(changeAllocation(base, 'vitality', 1), 'strength', 1), 'speed', 1)
    const promoted = confirmLevelUp(allocated)
    expect(promoted.hero.level).toBe(2)
    expect(promoted.hero.maxHp).toBeGreaterThan(base.hero.maxHp)
    expect(promoted.phase).toBe('running')
  })

  it('finishes unattended runs without getting stuck', () => {
    const outcomes = new Set<string>()
    for (const policy of ['safe', 'xp', 'deep'] as Policy[]) {
      for (const seed of [3, 19, 77, 902]) {
        const phase = autoRun(seed, policy).phase
        outcomes.add(phase)
        expect(['dead', 'victory']).toContain(phase)
      }
    }
    expect(outcomes).toEqual(new Set(['dead', 'victory']))
  })

  it('fully automates level reviews and floor transitions', () => {
    const levelReview = { ...startGame(createGame(908)), phase: 'levelup' as const, pendingPoints: 3, hero: { ...createGame(908).hero, xp: 18 } }
    const afterReview = setAutoMode(levelReview, true)
    expect(afterReview.phase).toBe('running')
    expect(afterReview.hero.level).toBe(2)
    expect(afterReview.pendingPoints).toBe(0)

    const checkpoint = { ...startGame(createGame(908)), phase: 'checkpoint' as const }
    const afterStairs = setAutoMode(checkpoint, true)
    expect(afterStairs.phase).toBe('running')
    expect(afterStairs.floor).toBe(2)
  })

  it('keeps full-auto runs valid and never waits at a review or checkpoint', () => {
    const outcomes = new Set<string>()
    let totalLoot = 0
    for (let seed = 1; seed <= 75; seed += 1) {
      let state = setAutoMode(startGame(createGame(seed * 1013)), true)
      for (let tick = 0; tick < 5_000 && state.phase !== 'dead' && state.phase !== 'victory'; tick += 1) {
        state = tickGame(state)
        expect(state.phase).not.toBe('levelup')
        expect(state.phase).not.toBe('checkpoint')
        expectValidState(state)
      }
      outcomes.add(state.phase)
      totalLoot += state.lootCount
      expect(['dead', 'victory']).toContain(state.phase)
    }
    expect(outcomes).toEqual(new Set(['dead', 'victory']))
    expect(totalLoot).toBeGreaterThan(20)
  })

  it('survives deterministic mixed manual actions without corrupting state', () => {
    for (let seed = 30; seed < 50; seed += 1) {
      let state = startGame(createGame(seed, seed % 2 === 0 ? 'safe' : 'xp'))
      for (let tick = 0; tick < 1_200 && state.phase !== 'dead' && state.phase !== 'victory'; tick += 1) {
        if (state.phase === 'levelup') {
          if (tick % 3 === 0) state = changePolicy(state, 'deep')
          state = confirmLevelUp(applySuggestion(state))
        } else if (state.phase === 'checkpoint') {
          if (tick % 2 === 0) state = changePolicy(state, 'xp')
          state = descend(state)
        } else {
          state = tickGame(state)
        }
        expectValidState(state)
      }
      expect(['dead', 'victory']).toContain(state.phase)
    }
  })
})
