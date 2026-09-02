import { describe, expect, it } from 'vitest'
import { flowActiveIndex } from '../ml/flow'

describe('live network map phase mapping', () => {
  it('moves forward through the MLP inference route', () => {
    expect([0, 1, 2, 3, 4, 5].map((phase) => flowActiveIndex('mlp', phase))).toEqual([0, 2, 3, 4, 5, 6])
  })

  it('returns through output and hidden layers during backpropagation', () => {
    expect(flowActiveIndex('mlp', 8)).toBe(4)
    expect(flowActiveIndex('mlp', 9)).toBe(2)
    expect(flowActiveIndex('mlp', 10)).toBe(2)
    expect(flowActiveIndex('mlp', 11)).toBe(6)
  })

  it('maps CNN phases to their expanded architecture', () => {
    expect([0, 1, 2, 3, 4, 5].map((phase) => flowActiveIndex('cnn', phase))).toEqual([0, 1, 2, 3, 6, 7])
  })
})
