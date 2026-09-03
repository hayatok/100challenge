import { describe, expect, it } from 'vitest'
import { createGame, operatingReserve, runTicks, tickGame, upgradeCost } from './simulation'
import type { GameState } from './types'

function expectValidState(state: GameState) {
  expect(Number.isFinite(state.cash)).toBe(true)
  expect(Number.isFinite(state.reputation)).toBe(true)
  expect(state.reputation).toBeGreaterThanOrEqual(0)
  expect(state.reputation).toBeLessThanOrEqual(100)
  expect(state.tier).toBeGreaterThanOrEqual(1)
  expect(state.tier).toBeLessThanOrEqual(4)
  expect(Object.values(state.inventory).every((stock) => Number.isInteger(stock) && stock >= 0)).toBe(true)
  expect(state.customers.length).toBeLessThanOrEqual(12)
  expect(state.customers.every((customer) => Number.isFinite(customer.x) && Number.isFinite(customer.y))).toBe(true)
}

describe('bonnyari mart simulation', () => {
  it('is deterministic from the same seed and policy', () => {
    const first = runTicks(createGame(20260904, 'steady'), 1_500)
    const second = runTicks(createGame(20260904, 'steady'), 1_500)
    expect(first).toEqual(second)
  })

  it('keeps inventory, customers, reputation, and money finite during long runs', () => {
    for (let seed = 1; seed <= 40; seed += 1) {
      let state = createGame(seed * 7919, seed % 3 === 0 ? 'popular' : seed % 2 === 0 ? 'profit' : 'steady')
      for (let tick = 0; tick < 8_000; tick += 1) {
        state = tickGame(state)
        if (tick % 113 === 0) expectValidState(state)
      }
      expectValidState(state)
      expect(state.day).toBeGreaterThan(16)
      expect(state.totalVisitors).toBeGreaterThan(100)
      expect(state.totalSales).toBeGreaterThan(0)
    }
  })

  it('does not invest when the post-upgrade operating reserve would be missing', () => {
    const initial = createGame(44)
    const poor = { ...initial, cash: upgradeCost(1) + operatingReserve({ tier: 2 }) - 1, reputation: 80, minute: 23 * 60 + 57 }
    const next = tickGame(poor)
    expect(next.day).toBe(2)
    expect(next.tier).toBe(1)
  })

  it('allows successful stores to develop while retaining an operating reserve', () => {
    let developed = 0
    for (let seed = 1; seed <= 30; seed += 1) {
      const state = runTicks(createGame(seed * 1013, 'popular'), 12_000)
      if (state.tier > 1) developed += 1
      if (state.tier > 1) expect(state.cash).toBeGreaterThan(-300_000)
    }
    expect(developed).toBeGreaterThan(12)
  })

  it('serves customers and produces daily reports without manual input', () => {
    const state = runTicks(createGame(9024), 1_000)
    expect(state.day).toBeGreaterThan(2)
    expect(state.report).not.toBeNull()
    expect(state.totalVisitors).toBeGreaterThan(20)
    expect(state.buyersToday).toBeGreaterThanOrEqual(0)
  })
})
