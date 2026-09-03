import { useEffect, useRef } from 'react'
import { products } from './game/data'
import type { Customer, GameState, ProductId } from './game/types'

const width = 720
const height = 480
const tile = 36

function pixelRect(context: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string) {
  context.fillStyle = color
  context.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h))
}

function drawCustomer(context: CanvasRenderingContext2D, customer: Customer, tickCount: number) {
  const x = customer.x * tile + tile / 2
  const y = customer.y * tile - 2
  const bob = customer.state === 'paying' ? 0 : tickCount % 2
  context.save()
  context.translate(x, y - bob)
  pixelRect(context, -8, -15, 16, 13, '#f2c69d')
  pixelRect(context, -10, -19, 20, 7, customer.kind === 'nightowl' ? '#1b2431' : '#3d3027')
  pixelRect(context, -10, -2, 20, 17, customer.color)
  pixelRect(context, -8, 15, 6, 10, '#27322e')
  pixelRect(context, 2, 15, 6, 10, '#27322e')
  pixelRect(context, -5, -10, 3, 3, '#17241f')
  pixelRect(context, 3, -10, 3, 3, '#17241f')
  if (customer.state === 'shopping') {
    pixelRect(context, 10, 1, 9, 10, '#f0d76e')
    pixelRect(context, 12, -1, 5, 3, '#17241f')
  }
  context.restore()
}

function drawShelf(context: CanvasRenderingContext2D, x: number, y: number, label: string, color: string, stock: number, locked: boolean) {
  const px = x * tile - 26
  const py = y * tile - 16
  pixelRect(context, px - 3, py - 3, 58, 35, '#17342f')
  pixelRect(context, px, py, 52, 29, locked ? '#57645e' : '#e2c282')
  pixelRect(context, px + 4, py + 5, 44, 8, locked ? '#75827b' : color)
  pixelRect(context, px + 4, py + 17, 44, 7, locked ? '#75827b' : color)
  context.fillStyle = '#fff4d0'
  context.font = 'bold 10px monospace'
  context.textAlign = 'center'
  context.fillText(locked ? '準備中' : `${label} ${stock}`, px + 26, py - 7)
}

function drawStore(context: CanvasRenderingContext2D, game: GameState) {
  context.imageSmoothingEnabled = false
  pixelRect(context, 0, 0, width, height, '#87b9c2')
  pixelRect(context, 0, 0, width, 64, game.minute >= 18 * 60 || game.minute < 6 * 60 ? '#233b5a' : '#78b2d0')
  pixelRect(context, 0, 54, width, 18, '#4f7d54')

  for (let x = 0; x < 20; x += 1) {
    for (let y = 2; y < 13; y += 1) {
      const color = (x + y) % 2 === 0 ? '#f0dfb5' : '#e9d5a6'
      pixelRect(context, x * tile, y * tile, tile, tile, color)
    }
  }

  pixelRect(context, 0, 65, width, 13, '#17342f')
  pixelRect(context, 0, 78, width, 16, '#f08a36')
  context.fillStyle = '#fff7d9'
  context.font = '900 17px sans-serif'
  context.textAlign = 'left'
  context.fillText('ぼんやりマート 24', 18, 91)

  pixelRect(context, 0, 92, 13, 388, '#17342f')
  pixelRect(context, 707, 92, 13, 388, '#17342f')
  pixelRect(context, 72, 444, 72, 36, '#8fd3e2')
  pixelRect(context, 77, 444, 4, 36, '#17342f')
  pixelRect(context, 135, 444, 4, 36, '#17342f')

  pixelRect(context, 50, 126, 116, 44, '#17342f')
  pixelRect(context, 56, 132, 104, 32, '#f39a42')
  context.fillStyle = '#17342f'
  context.font = '900 12px sans-serif'
  context.textAlign = 'center'
  context.fillText('レ ジ', 108, 153)
  pixelRect(context, 88, 104, 22, 22, '#5f746b')
  pixelRect(context, 92, 107, 14, 8, '#d6f28d')

  context.save()
  context.translate(128, 126)
  pixelRect(context, -8, -16, 16, 13, '#eec29b')
  pixelRect(context, -10, -20, 20, 7, '#284b42')
  pixelRect(context, -10, -3, 20, 18, '#4c9279')
  pixelRect(context, -5, -10, 3, 3, '#17342f')
  pixelRect(context, 3, -10, 3, 3, '#17342f')
  context.restore()

  for (const product of products) {
    drawShelf(context, product.shelf.x, product.shelf.y, product.name, product.color, game.inventory[product.id], product.unlockTier > game.tier)
  }

  if (game.tier >= 2) {
    pixelRect(context, 600, 116, 70, 80, '#17342f')
    pixelRect(context, 606, 122, 58, 68, '#d7eef3')
    context.fillStyle = '#17342f'
    context.font = '900 11px sans-serif'
    context.fillText('ATM', 635, 159)
  }
  if (game.tier >= 3) {
    pixelRect(context, 582, 310, 82, 58, '#17342f')
    pixelRect(context, 588, 316, 70, 46, '#d97738')
    context.fillStyle = '#fff4d0'
    context.font = '900 10px sans-serif'
    context.fillText('あつあつ', 623, 343)
  }

  for (const customer of game.customers) drawCustomer(context, customer, game.tick)

  for (const effect of game.effects) {
    const age = game.tick - Math.floor(effect.id / (effect.kind === 'sale' ? 100 : 10))
    const y = effect.y * tile - 16 - Math.max(0, age) * 2
    context.fillStyle = effect.kind === 'sale' ? '#1b5f42' : effect.kind === 'event' ? '#bd3b2d' : '#315f93'
    context.font = '900 14px monospace'
    context.textAlign = 'center'
    context.fillText(effect.text, effect.x * tile, y)
  }

  if (game.event.id === 'rain') {
    context.strokeStyle = 'rgba(216,244,255,.8)'
    context.lineWidth = 2
    for (let index = 0; index < 24; index += 1) {
      const x = ((index * 83 + game.tick * 7) % width)
      context.beginPath()
      context.moveTo(x, 3)
      context.lineTo(x - 6, 20)
      context.stroke()
    }
  }
}

export default function StoreCanvas({ game }: { game: GameState }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d')
    if (!context) return
    drawStore(context, game)
  }, [game])

  const stockSummary = products
    .filter((product) => product.unlockTier <= game.tier)
    .map((product) => `${product.name}${game.inventory[product.id]}個`)
    .join('、')

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      aria-label={`ぼんやりマート店内。${game.customers.length}人が店内にいます。在庫は${stockSummary}。`}
    />
  )
}

export const productSymbol: Record<ProductId, string> = {
  onigiri: '米', drink: '飲', bread: '麦', snack: '菓', bento: '弁', hot: '熱',
}
