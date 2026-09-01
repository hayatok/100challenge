import { useEffect, useRef } from 'react'
import { type Enemy, type GameState, type Treasure, tileIndex } from '../game/types'

type DungeonCanvasProps = { state: GameState }

const enemyColors: Record<Enemy['kind'], string> = {
  slime: '#76a84f',
  bat: '#76547c',
  skeleton: '#d8cfaa',
  goblin: '#5c8c47',
  ogre: '#9b6541',
  boss: '#a53b2f',
}

function drawHero(context: CanvasRenderingContext2D, x: number, y: number, size: number, tick: number, fighting: boolean) {
  const unit = Math.max(1, Math.floor(size / 8))
  const left = Math.round(x + (size - unit * 7) / 2)
  const bob = tick % 2 === 0 ? 0 : unit
  const top = Math.round(y + (size - unit * 8) / 2 - bob)
  context.fillStyle = 'rgba(0,0,0,.42)'
  context.fillRect(left + unit, y + size - unit * 2, unit * 6, unit)
  context.fillStyle = '#171a17'
  context.fillRect(left + unit, top, unit * 5, unit * 7)
  context.fillStyle = '#5b361f'
  context.fillRect(left + unit, top, unit * 5, unit * 2)
  context.fillRect(left, top + unit, unit * 2, unit * 2)
  context.fillStyle = '#d6a05b'
  context.fillRect(left + unit * 2, top + unit * 2, unit * 3, unit * 2)
  context.fillStyle = '#171a17'
  context.fillRect(left + unit * 4, top + unit * 2, unit, unit)
  context.fillStyle = '#315f78'
  context.fillRect(left + unit * 2, top + unit * 4, unit * 4, unit * 2)
  context.fillStyle = '#244355'
  context.fillRect(left + unit * 2, top + unit * 6, unit * 2, unit)
  context.fillStyle = '#c58a22'
  context.fillRect(left + unit, top + unit * 4, unit * 2, unit * 3)
  context.fillStyle = '#e8d6a8'
  const swordX = fighting ? left + unit * 6 : left + unit * 5
  const swordY = fighting ? top + unit : top + unit * 3
  context.fillRect(swordX, swordY, unit, unit * 4)
  context.fillStyle = '#8d7549'
  context.fillRect(swordX - unit, swordY + unit * 3, unit * 3, unit)
}

function drawEnemy(context: CanvasRenderingContext2D, enemy: Enemy, x: number, y: number, size: number) {
  const unit = Math.max(1, Math.floor(size / 8))
  const scale = enemy.boss ? 8 : enemy.elite ? 7 : 6
  const width = unit * scale
  const left = Math.round(x + (size - width) / 2)
  const top = Math.round(y + (size - width) / 2)
  context.fillStyle = 'rgba(0,0,0,.4)'
  context.fillRect(left, y + size - unit * 2, width, unit)
  context.fillStyle = '#171a17'
  if (enemy.kind === 'bat') {
    context.fillRect(left, top + unit * 2, width, unit * 3)
    context.fillStyle = enemyColors[enemy.kind]
    context.fillRect(left, top + unit * 2, unit * 2, unit * 2)
    context.fillRect(left + width - unit * 2, top + unit * 2, unit * 2, unit * 2)
    context.fillRect(left + unit * 2, top + unit, width - unit * 4, unit * 4)
  } else if (enemy.kind === 'skeleton') {
    context.fillRect(left + unit, top, width - unit * 2, width)
    context.fillStyle = enemyColors[enemy.kind]
    context.fillRect(left + unit * 2, top + unit, width - unit * 4, unit * 3)
    context.fillRect(left + unit * 2, top + unit * 5, unit, unit * 2)
    context.fillRect(left + width - unit * 3, top + unit * 5, unit, unit * 2)
  } else if (enemy.kind === 'slime') {
    context.fillRect(left, top + unit * 2, width, width - unit * 2)
    context.fillStyle = enemyColors[enemy.kind]
    context.fillRect(left + unit, top + unit * 2, width - unit * 2, width - unit * 3)
    context.fillStyle = '#9acb6a'
    context.fillRect(left + unit * 2, top + unit, width - unit * 4, unit)
  } else {
    context.fillRect(left, top, width, width)
    context.fillStyle = enemyColors[enemy.kind]
    context.fillRect(left + unit, top + unit, width - unit * 2, width - unit * 2)
    context.fillStyle = enemy.kind === 'boss' ? '#6e2420' : '#31482a'
    context.fillRect(left + unit, top + width - unit * 3, width - unit * 2, unit * 2)
  }
  const eye = Math.max(1, unit)
  context.fillStyle = '#fff3cf'
  context.fillRect(Math.round(left + width * 0.28), Math.round(top + width * 0.36), eye, eye)
  context.fillRect(Math.round(left + width * 0.64), Math.round(top + width * 0.36), eye, eye)
  if (enemy.elite || enemy.boss) {
    context.fillStyle = '#c58a22'
    context.fillRect(left, top - unit * 2, width, unit)
    context.fillRect(left + unit, top - unit * 3, unit, unit * 2)
    context.fillRect(left + width - unit * 2, top - unit * 3, unit, unit * 2)
  }
}

function drawTreasure(context: CanvasRenderingContext2D, treasure: Treasure, x: number, y: number, size: number, tick: number) {
  const unit = Math.max(1, Math.floor(size / 8))
  const left = Math.round(x + (size - unit * 6) / 2)
  const top = Math.round(y + (size - unit * 5) / 2)
  context.fillStyle = '#171a17'
  context.fillRect(left, top, unit * 6, unit * 5)
  context.fillStyle = '#8b4f27'
  context.fillRect(left + unit, top + unit, unit * 4, unit * 3)
  context.fillStyle = treasure.kind === 'potion' ? '#77a45c' : treasure.kind === 'weapon' || treasure.kind === 'armor' ? '#d1c8ac' : treasure.kind === 'charm' ? '#8d6ca0' : '#c58a22'
  context.fillRect(left + unit, top + unit * 2, unit * 4, unit)
  context.fillRect(left + unit * 3, top + unit * 2, unit, unit * 2)
  if (tick % 4 === 0) {
    context.fillStyle = '#fff3cf'
    context.fillRect(left + unit * 5, top - unit, unit, unit)
    context.fillRect(left + unit * 4, top, unit, unit)
  }
}

export default function DungeonCanvas({ state }: DungeonCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const draw = () => {
      const context = canvas.getContext('2d')
      if (!context) return
      const rect = canvas.getBoundingClientRect()
      const ratio = Math.max(1, window.devicePixelRatio || 1)
      canvas.width = Math.max(1, Math.round(rect.width * ratio))
      canvas.height = Math.max(1, Math.round(rect.height * ratio))
      context.setTransform(ratio, 0, 0, ratio, 0, 0)
      context.imageSmoothingEnabled = false

      const mobile = rect.width < 600
      const columns = mobile ? 20 : 30
      const rows = mobile ? 16 : 21
      const startX = Math.max(0, Math.min(state.dungeon.width - columns, state.hero.x - Math.floor(columns / 2)))
      const startY = Math.max(0, Math.min(state.dungeon.height - rows, state.hero.y - Math.floor(rows / 2)))
      const cellWidth = rect.width / columns
      const cellHeight = rect.height / rows

      context.fillStyle = '#090b0a'
      context.fillRect(0, 0, rect.width, rect.height)
      for (let viewY = 0; viewY < rows; viewY += 1) {
        for (let viewX = 0; viewX < columns; viewX += 1) {
          const worldX = startX + viewX
          const worldY = startY + viewY
          const index = tileIndex({ x: worldX, y: worldY }, state.dungeon.width)
          const x = viewX * cellWidth
          const y = viewY * cellHeight
          if (!state.revealed[index]) {
            context.fillStyle = (worldX + worldY) % 9 === 0 ? '#111512' : '#090b0a'
            context.fillRect(Math.floor(x), Math.floor(y), Math.ceil(cellWidth), Math.ceil(cellHeight))
            continue
          }
          const tile = state.dungeon.tiles[index]
          if (tile === 0) {
            context.fillStyle = (worldX + worldY) % 2 ? '#242824' : '#2d302b'
            context.fillRect(Math.floor(x), Math.floor(y), Math.ceil(cellWidth), Math.ceil(cellHeight))
            context.fillStyle = '#151815'
            context.fillRect(Math.floor(x), Math.floor(y + cellHeight - 2), Math.ceil(cellWidth), 2)
            if ((worldX * 7 + worldY * 11) % 19 === 0) {
              context.fillStyle = '#3f4139'
              context.fillRect(x + cellWidth * .2, y + cellHeight * .35, Math.max(1, cellWidth * .35), 1)
              context.fillRect(x + cellWidth * .5, y + cellHeight * .35, 1, Math.max(1, cellHeight * .25))
            }
            continue
          }
          context.fillStyle = (worldX + worldY) % 2 ? '#55493b' : '#5d5040'
          context.fillRect(Math.floor(x), Math.floor(y), Math.ceil(cellWidth), Math.ceil(cellHeight))
          context.fillStyle = 'rgba(23,26,23,.22)'
          context.fillRect(Math.floor(x), Math.floor(y), Math.ceil(cellWidth), 1)
          if ((worldX * 13 + worldY * 17) % 23 === 0) {
            context.fillStyle = '#7d6a51'
            context.fillRect(x + cellWidth * .2, y + cellHeight * .56, Math.max(1, cellWidth * .18), Math.max(1, cellHeight * .12))
          }

          if (tile === 2) {
            context.fillStyle = '#171a17'
            for (let step = 0; step < 3; step += 1) context.fillRect(x + cellWidth * (0.18 + step * 0.12), y + cellHeight * (0.25 + step * 0.2), cellWidth * 0.56, Math.max(2, cellHeight * 0.12))
          } else if (tile === 3) {
            context.fillStyle = '#e8d6a8'
            context.fillRect(x + cellWidth * 0.18, y + cellHeight * 0.42, cellWidth * 0.64, cellHeight * 0.18)
            context.fillRect(x + cellWidth * 0.42, y + cellHeight * 0.18, cellWidth * 0.18, cellHeight * 0.64)
          }
        }
      }

      for (const treasure of state.dungeon.treasures) {
        if (treasure.opened || treasure.x < startX || treasure.x >= startX + columns || treasure.y < startY || treasure.y >= startY + rows) continue
        if (!state.revealed[tileIndex(treasure, state.dungeon.width)]) continue
        drawTreasure(context, treasure, (treasure.x - startX) * cellWidth, (treasure.y - startY) * cellHeight, Math.min(cellWidth, cellHeight), state.ticks)
      }

      context.fillStyle = 'rgba(197,138,34,.58)'
      for (const point of state.path.slice(0, 20)) {
        if (point.x < startX || point.x >= startX + columns || point.y < startY || point.y >= startY + rows) continue
        const x = (point.x - startX + 0.42) * cellWidth
        const y = (point.y - startY + 0.42) * cellHeight
        context.fillRect(x, y, Math.max(2, cellWidth * 0.16), Math.max(2, cellHeight * 0.16))
      }

      for (const enemy of state.dungeon.enemies) {
        if (enemy.hp <= 0 || enemy.x < startX || enemy.x >= startX + columns || enemy.y < startY || enemy.y >= startY + rows) continue
        if (!state.revealed[tileIndex(enemy, state.dungeon.width)]) continue
        const x = (enemy.x - startX) * cellWidth
        const y = (enemy.y - startY) * cellHeight
        drawEnemy(context, enemy, x, y, Math.min(cellWidth, cellHeight))
        if (enemy.id === state.combatEnemyId) {
          const ratio = enemy.hp / enemy.maxHp
          context.fillStyle = '#171a17'
          context.fillRect(x, y - 4, cellWidth, 3)
          context.fillStyle = '#a53b2f'
          context.fillRect(x + 1, y - 3, Math.max(0, (cellWidth - 2) * ratio), 1)
        }
      }

      const heroX = (state.hero.x - startX) * cellWidth
      const heroY = (state.hero.y - startY) * cellHeight
      drawHero(context, heroX, heroY, Math.min(cellWidth, cellHeight), state.ticks, state.combatEnemyId !== null)
      if (state.combatEnemyId !== null && state.ticks % 2 === 0) {
        context.fillStyle = '#fff3cf'
        context.fillRect(heroX + cellWidth * .72, heroY + cellHeight * .12, Math.max(2, cellWidth * .18), Math.max(2, cellHeight * .08))
        context.fillRect(heroX + cellWidth * .82, heroY + cellHeight * .2, Math.max(2, cellWidth * .08), Math.max(2, cellHeight * .18))
      }
      if (state.hero.hp / state.hero.maxHp < 0.35) {
        context.strokeStyle = '#c94b3d'
        context.lineWidth = 2
        context.strokeRect(heroX + 1, heroY + 1, cellWidth - 2, cellHeight - 2)
      }

      context.font = `900 ${Math.max(9, Math.min(14, cellWidth * .72))}px ui-monospace, monospace`
      context.textAlign = 'center'
      for (const effect of state.effects) {
        const age = state.ticks - effect.tick
        if (age < 0 || age > 6 || effect.x < startX || effect.x >= startX + columns || effect.y < startY || effect.y >= startY + rows) continue
        const x = (effect.x - startX + .5) * cellWidth
        const y = (effect.y - startY + .15) * cellHeight - age * 2
        context.fillStyle = '#171a17'
        context.fillText(effect.text, x + 1, y + 2)
        context.fillStyle = effect.tone === 'critical' ? '#ffe36e' : effect.tone === 'heal' ? '#88c46d' : effect.tone === 'loot' ? '#e9b94f' : '#fff3cf'
        context.fillText(effect.text, x, y)
      }
    }
    draw()
    window.addEventListener('resize', draw)
    return () => window.removeEventListener('resize', draw)
  }, [state])

  const living = state.dungeon.enemies.filter((enemy) => enemy.hp > 0).length
  return (
    <canvas
      ref={canvasRef}
      className="dungeon-canvas"
      role="img"
      aria-label={`第${state.floor}地下迷宮。勇者${state.hero.name}は列${state.hero.x + 1}、行${state.hero.y + 1}。残る敵${living}体。${state.combatEnemyId === null ? '自動探索中' : '戦闘中'}`}
    />
  )
}
