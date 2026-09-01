import { describe, expect, it } from 'vitest'
import {
  BOARD_SIZE,
  boardFromCells,
  cellIndex,
  countAlive,
  countNeighbors,
  createMetadata,
  createRandomBoard,
  stepBoard,
} from './board'
import { phaseAfterStep } from './machine'
import { decideTick } from './timing'

describe('Conway B3/S23', () => {
  it('births a dead cell with exactly three neighbors', () => {
    const board = boardFromCells([[0, 1], [1, 0], [1, 1]])
    expect(stepBoard(board, createMetadata(board)).board[cellIndex(0, 0)]).toBe(1)
  })

  it('keeps cells with two or three neighbors and removes under/overpopulation', () => {
    const block = boardFromCells([[4, 4], [5, 4], [4, 5], [5, 5]])
    const result = stepBoard(block, createMetadata(block))
    expect(Array.from(result.board)).toEqual(Array.from(block))

    const isolated = boardFromCells([[10, 10]])
    expect(countAlive(stepBoard(isolated, createMetadata(isolated)).board)).toBe(0)
  })

  it('wraps neighbors across every board edge', () => {
    const board = boardFromCells([[31, 23], [0, 23], [31, 0]])
    expect(countNeighbors(board, 0, 0)).toBe(3)
    expect(stepBoard(board, createMetadata(board)).board[cellIndex(0, 0)]).toBe(1)
  })

  it('returns a blinker to its original shape after two generations', () => {
    const board = boardFromCells([[15, 11], [15, 12], [15, 13]])
    const first = stepBoard(board, createMetadata(board))
    const second = stepBoard(first.board, first.metadata)
    expect(Array.from(second.board)).toEqual(Array.from(board))
  })
})

describe('garden metadata and random source', () => {
  it('tracks age, stability, births, and deaths', () => {
    const board = boardFromCells([[4, 4], [5, 4], [4, 5], [5, 5]])
    let result = stepBoard(board, createMetadata(board))
    expect(result.metadata.age[cellIndex(4, 4)]).toBe(2)
    expect(result.metadata.stableAge[cellIndex(4, 4)]).toBe(1)
    for (let generation = 0; generation < 7; generation += 1) result = stepBoard(result.board, result.metadata)
    expect(result.metadata.stableAge[cellIndex(4, 4)]).toBe(8)

    const isolated = boardFromCells([[8, 8]])
    const death = stepBoard(isolated, createMetadata(isolated))
    expect(death.died).toEqual([cellIndex(8, 8)])
  })

  it('creates the same board from the same seed', () => {
    const first = createRandomBoard(12345)
    const second = createRandomBoard(12345)
    expect(first).toHaveLength(BOARD_SIZE)
    expect(Array.from(first)).toEqual(Array.from(second))
  })

  it('distinguishes automatic extinction from manual emptying', () => {
    expect(phaseAfterStep('automatic', 0)).toBe('reseeding')
    expect(phaseAfterStep('manual', 0)).toBe('empty')
    expect(phaseAfterStep('automatic', 2)).toBe('running')
    expect(phaseAfterStep('manual', 2)).toBe('paused')
  })

  it('drops elapsed surplus instead of catching up after a stall', () => {
    const afterStall = decideTick(100, 5_100, 450)
    expect(afterStall).toEqual({ shouldTick: true, nextBaseline: 5_100 })
    expect(decideTick(afterStall.nextBaseline, 5_200, 450).shouldTick).toBe(false)
    expect(decideTick(afterStall.nextBaseline, 5_550, 450).shouldTick).toBe(true)
  })
})
