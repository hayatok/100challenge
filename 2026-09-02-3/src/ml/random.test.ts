import { describe, expect, it } from 'vitest'
import { createRandom, glorot, shuffledIndices } from './random'

describe('deterministic random helpers', () => {
  it('repeats the same sequence for the same seed', () => {
    const left = createRandom(20260902)
    const right = createRandom(20260902)
    expect(Array.from({ length: 20 }, left)).toEqual(Array.from({ length: 20 }, right))
  })

  it('creates a complete deterministic permutation', () => {
    const values = shuffledIndices(100, 42)
    expect(new Set(values).size).toBe(100)
    expect([...values].sort((a, b) => a - b)).toEqual(Array.from({ length: 100 }, (_, index) => index))
    expect(values).toEqual(shuffledIndices(100, 42))
  })

  it('keeps Glorot values inside the expected limit', () => {
    const values = glorot(200, 784, 16, createRandom(1))
    const limit = Math.sqrt(6 / 800)
    expect(Math.max(...values)).toBeLessThanOrEqual(limit)
    expect(Math.min(...values)).toBeGreaterThanOrEqual(-limit)
  })
})
