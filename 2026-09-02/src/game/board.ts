import { createSeededRandom } from './random'

export const BOARD_WIDTH = 32
export const BOARD_HEIGHT = 24
export const BOARD_SIZE = BOARD_WIDTH * BOARD_HEIGHT

export type Board = Uint8Array

export type CellMetadata = {
  age: Uint16Array
  stableAge: Uint16Array
}

export type StepResult = {
  board: Board
  metadata: CellMetadata
  born: number[]
  died: number[]
  aliveCount: number
}

export function cellIndex(x: number, y: number) {
  const wrappedX = (x + BOARD_WIDTH) % BOARD_WIDTH
  const wrappedY = (y + BOARD_HEIGHT) % BOARD_HEIGHT
  return wrappedY * BOARD_WIDTH + wrappedX
}

export function createEmptyBoard(): Board {
  return new Uint8Array(BOARD_SIZE)
}

export function createMetadata(board: Board): CellMetadata {
  const age = new Uint16Array(BOARD_SIZE)
  for (let index = 0; index < BOARD_SIZE; index += 1) {
    if (board[index]) age[index] = 1
  }
  return { age, stableAge: new Uint16Array(BOARD_SIZE) }
}

export function boardFromCells(cells: Array<[number, number]>): Board {
  const board = createEmptyBoard()
  for (const [x, y] of cells) board[cellIndex(x, y)] = 1
  return board
}

export function createRandomBoard(seed: number, density = 0.29): Board {
  const random = createSeededRandom(seed)
  const board = createEmptyBoard()
  for (let index = 0; index < BOARD_SIZE; index += 1) {
    board[index] = random() < density ? 1 : 0
  }
  return board
}

export function countNeighbors(board: Board, x: number, y: number) {
  let count = 0
  for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
    for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
      if (offsetX === 0 && offsetY === 0) continue
      count += board[cellIndex(x + offsetX, y + offsetY)]
    }
  }
  return count
}

export function countAlive(board: Board) {
  let count = 0
  for (const value of board) count += value
  return count
}

function neighborhoodPattern(board: Board, x: number, y: number) {
  let pattern = 0
  let bit = 0
  for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
    for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
      if (board[cellIndex(x + offsetX, y + offsetY)]) pattern |= 1 << bit
      bit += 1
    }
  }
  return pattern
}

export function stepBoard(board: Board, metadata: CellMetadata): StepResult {
  const nextBoard = createEmptyBoard()
  const born: number[] = []
  const died: number[] = []

  for (let y = 0; y < BOARD_HEIGHT; y += 1) {
    for (let x = 0; x < BOARD_WIDTH; x += 1) {
      const index = cellIndex(x, y)
      const neighbors = countNeighbors(board, x, y)
      const alive = board[index] === 1
      const survives = alive ? neighbors === 2 || neighbors === 3 : neighbors === 3
      nextBoard[index] = survives ? 1 : 0
      if (!alive && survives) born.push(index)
      if (alive && !survives) died.push(index)
    }
  }

  const nextAge = new Uint16Array(BOARD_SIZE)
  const nextStableAge = new Uint16Array(BOARD_SIZE)
  for (let y = 0; y < BOARD_HEIGHT; y += 1) {
    for (let x = 0; x < BOARD_WIDTH; x += 1) {
      const index = cellIndex(x, y)
      if (!nextBoard[index]) continue
      const continued = board[index] === 1
      nextAge[index] = continued ? Math.min(0xffff, metadata.age[index] + 1) : 1
      const stable = continued && neighborhoodPattern(board, x, y) === neighborhoodPattern(nextBoard, x, y)
      nextStableAge[index] = stable ? Math.min(0xffff, metadata.stableAge[index] + 1) : 0
    }
  }

  return {
    board: nextBoard,
    metadata: { age: nextAge, stableAge: nextStableAge },
    born,
    died,
    aliveCount: countAlive(nextBoard),
  }
}

export function setCell(board: Board, metadata: CellMetadata, index: number, alive: boolean) {
  const nextBoard = board.slice()
  const nextAge = metadata.age.slice()
  const nextStableAge = metadata.stableAge.slice()
  nextBoard[index] = alive ? 1 : 0
  nextAge[index] = alive ? 1 : 0
  nextStableAge[index] = 0
  return { board: nextBoard, metadata: { age: nextAge, stableAge: nextStableAge } }
}
