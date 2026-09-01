import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from 'react'
import { FRAME_SIZE, spriteCoordinates, sprites } from '../assets/sprites'
import { BOARD_HEIGHT, BOARD_WIDTH, type Board, type CellMetadata } from '../game/board'
import type { GardenPhase } from '../game/machine'

type AssetStatus = 'loading' | 'ready' | 'error'

type GardenCanvasProps = {
  board: Board
  metadata: CellMetadata
  bornAt: Float64Array
  diedAt: Float64Array
  phase: GardenPhase
  atlasUrl: string
  onEdit: (index: number, alive: boolean, now: number) => void
  onEditingChange: (editing: boolean) => void
  onAnnouncement: (message: string) => void
  onAssetStatus: (status: AssetStatus) => void
}

const flowerFrames = [sprites.yellowFlower, sprites.whiteFlower, sprites.pinkFlower, sprites.blueFlower]

function frameForCell(index: number, age: number, stableAge: number) {
  if (stableAge >= 8) return flowerFrames[index % flowerFrames.length]
  if (age <= 2) return sprites.sprout
  if (age <= 5) return sprites.twoLeaf
  return index % 3 === 0 ? sprites.lushPlant : sprites.plant
}

function drawFallback(
  context: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  color: string,
  flower: boolean,
) {
  const unit = Math.max(1, Math.floor(Math.min(width, height) / 6))
  const centerX = x + width / 2
  const bottom = y + height * 0.8
  context.fillStyle = '#1c2b20'
  context.fillRect(Math.round(centerX - unit / 2), Math.round(bottom - unit * 3), unit, unit * 3)
  context.fillStyle = color
  context.fillRect(Math.round(centerX - unit * 2), Math.round(bottom - unit * 3), unit * 2, unit)
  context.fillRect(Math.round(centerX), Math.round(bottom - unit * 2), unit * 2, unit)
  if (flower) {
    context.fillStyle = '#f2c94c'
    context.fillRect(Math.round(centerX - unit * 1.5), Math.round(bottom - unit * 5), unit * 3, unit * 2)
  }
}

export default function GardenCanvas({
  board,
  metadata,
  bornAt,
  diedAt,
  phase,
  atlasUrl,
  onEdit,
  onEditingChange,
  onAnnouncement,
  onAssetStatus,
}: GardenCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const imageRef = useRef<HTMLImageElement | null>(null)
  const editingRef = useRef(false)
  const paintAliveRef = useRef(true)
  const visitedRef = useRef(new Set<number>())
  const [cursorIndex, setCursorIndex] = useState(0)

  useEffect(() => {
    let active = true
    const image = new Image()
    image.onload = () => {
      if (!active) return
      imageRef.current = image
      onAssetStatus('ready')
    }
    image.onerror = () => {
      if (!active) return
      imageRef.current = null
      onAssetStatus('error')
    }
    onAssetStatus('loading')
    image.src = atlasUrl
    return () => {
      active = false
    }
  }, [atlasUrl, onAssetStatus])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d')
    if (!context) return
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let animationFrame = 0

    const draw = (now: number) => {
      const rect = canvas.getBoundingClientRect()
      const ratio = Math.max(1, window.devicePixelRatio || 1)
      const displayWidth = Math.max(1, Math.round(rect.width * ratio))
      const displayHeight = Math.max(1, Math.round(rect.height * ratio))
      if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
        canvas.width = displayWidth
        canvas.height = displayHeight
      }
      context.setTransform(ratio, 0, 0, ratio, 0, 0)
      context.imageSmoothingEnabled = false
      const cellWidth = rect.width / BOARD_WIDTH
      const cellHeight = rect.height / BOARD_HEIGHT
      context.clearRect(0, 0, rect.width, rect.height)

      for (let y = 0; y < BOARD_HEIGHT; y += 1) {
        for (let x = 0; x < BOARD_WIDTH; x += 1) {
          const index = y * BOARD_WIDTH + x
          const cellX = x * cellWidth
          const cellY = y * cellHeight
          context.fillStyle = (x + y) % 2 === 0 ? '#745035' : '#6b482f'
          context.fillRect(Math.floor(cellX), Math.floor(cellY), Math.ceil(cellWidth + 0.5), Math.ceil(cellHeight + 0.5))

          const bornProgress = bornAt[index] ? Math.min(1, Math.max(0, (now - bornAt[index]) / 220)) : 1
          const deathProgress = diedAt[index] ? Math.min(1, Math.max(0, (now - diedAt[index]) / 300)) : 1
          const dying = diedAt[index] > 0 && deathProgress < 1 && board[index] === 0
          const alive = board[index] === 1
          if (!alive && !dying) continue

          const frame = dying ? sprites.fading : bornProgress < 1 ? sprites.newborn : frameForCell(index, metadata.age[index], metadata.stableAge[index])
          const scale = reducedMotion ? 1 : dying ? 1 - deathProgress * 0.55 : 0.72 + bornProgress * 0.28
          const drawnWidth = cellWidth * scale
          const drawnHeight = cellHeight * scale
          const drawnX = cellX + (cellWidth - drawnWidth) / 2
          const drawnY = cellY + (cellHeight - drawnHeight) / 2
          const image = imageRef.current
          if (image) {
            const { sourceX, sourceY } = spriteCoordinates(frame)
            context.drawImage(image, sourceX, sourceY, FRAME_SIZE, FRAME_SIZE, drawnX, drawnY, drawnWidth, drawnHeight)
          } else {
            drawFallback(context, drawnX, drawnY, drawnWidth, drawnHeight, dying ? '#8a6b4c' : '#79ad43', metadata.stableAge[index] >= 8)
          }
        }
      }

      if (document.activeElement === canvas) {
        const cursorX = cursorIndex % BOARD_WIDTH
        const cursorY = Math.floor(cursorIndex / BOARD_WIDTH)
        context.strokeStyle = '#f2c94c'
        context.lineWidth = Math.max(2, Math.floor(Math.min(cellWidth, cellHeight) * 0.16))
        context.strokeRect(cursorX * cellWidth + 1, cursorY * cellHeight + 1, cellWidth - 2, cellHeight - 2)
      }

      animationFrame = window.requestAnimationFrame(draw)
    }
    animationFrame = window.requestAnimationFrame(draw)
    return () => window.cancelAnimationFrame(animationFrame)
  }, [board, bornAt, cursorIndex, diedAt, metadata])

  const indexFromPointer = (event: PointerEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect()
    const x = Math.min(BOARD_WIDTH - 1, Math.max(0, Math.floor(((event.clientX - rect.left) / rect.width) * BOARD_WIDTH)))
    const y = Math.min(BOARD_HEIGHT - 1, Math.max(0, Math.floor(((event.clientY - rect.top) / rect.height) * BOARD_HEIGHT)))
    return y * BOARD_WIDTH + x
  }

  const editFromPointer = (event: PointerEvent<HTMLCanvasElement>) => {
    const index = indexFromPointer(event)
    if (visitedRef.current.has(index)) return
    visitedRef.current.add(index)
    onEdit(index, paintAliveRef.current, performance.now())
  }

  const finishEditing = (event: PointerEvent<HTMLCanvasElement>) => {
    if (!editingRef.current) return
    editingRef.current = false
    visitedRef.current.clear()
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
    onEditingChange(false)
  }

  const announceCursor = (index: number, nextAlive = board[index] === 1) => {
    const column = index % BOARD_WIDTH + 1
    const row = Math.floor(index / BOARD_WIDTH) + 1
    onAnnouncement(`列${column}、行${row}、${nextAlive ? '芽あり' : '空'}`)
  }

  const handleKeyDown = (event: KeyboardEvent<HTMLCanvasElement>) => {
    const x = cursorIndex % BOARD_WIDTH
    const y = Math.floor(cursorIndex / BOARD_WIDTH)
    let nextIndex = cursorIndex
    if (event.key === 'ArrowLeft') nextIndex = y * BOARD_WIDTH + (x + BOARD_WIDTH - 1) % BOARD_WIDTH
    if (event.key === 'ArrowRight') nextIndex = y * BOARD_WIDTH + (x + 1) % BOARD_WIDTH
    if (event.key === 'ArrowUp') nextIndex = ((y + BOARD_HEIGHT - 1) % BOARD_HEIGHT) * BOARD_WIDTH + x
    if (event.key === 'ArrowDown') nextIndex = ((y + 1) % BOARD_HEIGHT) * BOARD_WIDTH + x
    if (nextIndex !== cursorIndex) {
      event.preventDefault()
      event.stopPropagation()
      setCursorIndex(nextIndex)
      announceCursor(nextIndex)
      return
    }
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      event.stopPropagation()
      const nextAlive = board[cursorIndex] === 0
      onEdit(cursorIndex, nextAlive, performance.now())
      announceCursor(cursorIndex, nextAlive)
    }
  }

  return (
    <canvas
      ref={canvasRef}
      className="garden-canvas"
      tabIndex={0}
      aria-label={`32かける24のいのちの庭。現在${board.reduce((sum, value) => sum + value, 0)}個の植物。${phase === 'running' ? '観測中' : '停止中'}`}
      onFocus={() => announceCursor(cursorIndex)}
      onKeyDown={handleKeyDown}
      onPointerDown={(event) => {
        if (event.button !== 0) return
        editingRef.current = true
        visitedRef.current.clear()
        const index = indexFromPointer(event)
        paintAliveRef.current = board[index] === 0
        event.currentTarget.setPointerCapture(event.pointerId)
        onEditingChange(true)
        editFromPointer(event)
      }}
      onPointerMove={(event) => {
        if (editingRef.current) editFromPointer(event)
      }}
      onPointerUp={finishEditing}
      onPointerCancel={finishEditing}
    />
  )
}

export type { AssetStatus }
