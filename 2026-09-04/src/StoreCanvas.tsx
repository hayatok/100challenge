import { useEffect, useRef } from 'react'
import { products } from './game/data'
import type { Customer, CustomerKind, GameState, ProductId } from './game/types'

const width = 720
const height = 480
const tile = 36
type Context = CanvasRenderingContext2D
type Facing = 'front' | 'back' | 'left' | 'right'
const ink = '#18362f'
const deepInk = '#0b211c'
const cream = '#fff1c7'

function rect(context: Context, x: number, y: number, w: number, h: number, color: string) {
  context.fillStyle = color
  context.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h))
}

function outlineRect(context: Context, x: number, y: number, w: number, h: number, color: string, outline = ink, size = 3) {
  rect(context, x - size, y - size, w + size * 2, h + size * 2, outline)
  rect(context, x, y, w, h, color)
}

function pixelText(context: Context, text: string, x: number, y: number, size: number, color: string, align: CanvasTextAlign = 'left') {
  context.fillStyle = color
  context.font = `900 ${size}px ui-monospace, "Hiragino Sans", monospace`
  context.textAlign = align
  context.textBaseline = 'alphabetic'
  context.fillText(text, Math.round(x), Math.round(y))
}

function drawSky(context: Context, game: GameState) {
  const hour = game.minute / 60
  const night = hour < 6 || hour >= 18
  const evening = hour >= 16.5 && hour < 18
  rect(context, 0, 0, width, 57, night ? '#20324f' : evening ? '#d67955' : '#72b5d0')
  rect(context, 0, 49, width, 9, night ? '#14253c' : '#5e9cac')
  if (night) {
    for (let index = 0; index < 20; index += 1) {
      const x = (index * 79 + 23) % width
      const y = (index * 17 + 9) % 43
      rect(context, x, y, index % 4 === 0 ? 3 : 2, 2, index % 3 === 0 ? '#ffe278' : '#d9ebea')
    }
  } else {
    rect(context, 56, 17, 44, 7, '#dff0e9')
    rect(context, 67, 10, 26, 7, '#dff0e9')
    rect(context, 564, 27, 58, 6, '#dff0e9')
    rect(context, 580, 20, 27, 7, '#dff0e9')
  }
  if (game.event.id === 'rain') {
    context.strokeStyle = '#d6f3ff'
    context.lineWidth = 2
    for (let index = 0; index < 31; index += 1) {
      const x = (index * 67 + game.tick * 9) % (width + 30)
      const y = (index * 23 + game.tick * 5) % 58
      context.beginPath()
      context.moveTo(x, y)
      context.lineTo(x - 6, y + 14)
      context.stroke()
    }
  }
}

function drawBackWall(context: Context, game: GameState) {
  rect(context, 0, 57, width, 62, '#f1dca5')
  for (let x = 0; x < width; x += 24) rect(context, x, 57, 2, 62, '#dfc487')
  rect(context, 0, 57, width, 8, ink)
  rect(context, 0, 65, width, 18, '#337b63')
  rect(context, 0, 83, width, 21, '#ef8437')
  rect(context, 0, 104, width, 7, '#b94b34')
  rect(context, 0, 111, width, 8, ink)
  pixelText(context, 'ぼんやりマート', 22, 100, 18, '#fff8d7')
  rect(context, 190, 87, 32, 12, '#fff0bc')
  pixelText(context, '24', 206, 98, 14, '#b94b34', 'center')
  outlineRect(context, 530, 66, 60, 13, '#f6e27b', ink, 2)
  pixelText(context, 'OPEN', 560, 77, 10, ink, 'center')
  outlineRect(context, 640, 68, 42, 32, '#f9ebbe', ink, 3)
  pixelText(context, `${String(Math.floor(game.minute / 60)).padStart(2, '0')}:${String(game.minute % 60).padStart(2, '0')}`, 661, 89, 10, ink, 'center')

  if (game.event.id === 'festival') {
    for (let index = 0; index < 9; index += 1) {
      const x = 270 + index * 30
      rect(context, x, 67 + (index % 2) * 4, 12, 15, index % 2 === 0 ? '#e84d3d' : '#f5d55b')
      rect(context, x + 2, 64 + (index % 2) * 4, 8, 3, ink)
      rect(context, x + 5, 82 + (index % 2) * 4, 2, 5, ink)
    }
  }
  if (game.event.id === 'sports') {
    for (let index = 0; index < 8; index += 1) {
      const x = 290 + index * 31
      rect(context, x, 66, 2, 18, ink)
      rect(context, x + 2, 66, 16, 9, index % 2 === 0 ? '#f45e4d' : '#fff3cf')
    }
  }
}

function drawFloor(context: Context, game: GameState) {
  const night = game.minute < 6 * 60 || game.minute >= 18 * 60
  const light = night ? '#d8c188' : '#ead7a5'
  const dark = night ? '#ccb47b' : '#dfc994'
  rect(context, 0, 119, width, 337, light)
  for (let row = 0; row < 10; row += 1) {
    for (let column = 0; column < 20; column += 1) {
      rect(context, column * tile, 119 + row * tile, tile, tile, (column + row) % 2 === 0 ? light : dark)
      rect(context, column * tile, 119 + row * tile, tile, 1, '#f5e6be')
      rect(context, column * tile, 119 + row * tile, 1, tile, '#d2b980')
    }
  }
  for (let index = 0; index < 18; index += 1) {
    const x = (index * 97 + game.seed) % 690 + 12
    const y = 132 + ((index * 53 + game.seed) % 305)
    rect(context, x, y, index % 3 + 1, 2, 'rgba(125,94,54,.18)')
  }
  rect(context, 0, 452, width, 8, ink)
  rect(context, 0, 460, width, 20, '#5c9a8a')
  for (let x = 0; x < width; x += 36) rect(context, x, 461, 18, 3, '#83b9a9')
}

function drawCeilingLights(context: Context, game: GameState) {
  const night = game.minute < 6 * 60 || game.minute >= 18 * 60
  for (const x of [248, 420]) {
    rect(context, x - 58, 121, 116, 3, '#b69b65')
    rect(context, x - 48, 124, 96, 5, night ? '#fff6b5' : '#fff3ca')
    rect(context, x - 34, 129, 68, 2, 'rgba(255,245,181,.55)')
  }
}

function productPalette(productId: ProductId) {
  const palettes: Record<ProductId, [string, string, string]> = {
    onigiri: ['#f8f2d9', '#263f37', '#e9d7a5'],
    drink: ['#61b3d0', '#f1de61', '#d55a45'],
    bread: ['#d5944f', '#f1c46c', '#b56337'],
    snack: ['#e85f58', '#f0d65e', '#78a55e'],
    bento: ['#78a45a', '#e9d098', '#c85842'],
    hot: ['#e56a32', '#f2bd4c', '#9b372c'],
  }
  return palettes[productId]
}

function drawGoods(context: Context, productId: ProductId, x: number, y: number, stock: number, rows = 2) {
  const palette = productPalette(productId)
  const visible = Math.min(12, Math.max(0, stock))
  const columns = Math.ceil(visible / rows)
  for (let index = 0; index < visible; index += 1) {
    const column = index % Math.max(1, columns)
    const row = Math.floor(index / Math.max(1, columns))
    const itemX = x + column * 7
    const itemY = y + row * 12
    const color = palette[index % palette.length]
    if (productId === 'onigiri') {
      rect(context, itemX + 1, itemY + 1, 5, 7, color)
      rect(context, itemX + 2, itemY, 3, 1, color)
      rect(context, itemX + 2, itemY + 6, 3, 3, '#27463c')
    } else if (productId === 'drink') {
      rect(context, itemX + 1, itemY, 4, 9, color)
      rect(context, itemX + 2, itemY - 2, 2, 2, '#e8f0df')
      rect(context, itemX + 1, itemY + 4, 4, 2, '#eef2d3')
    } else {
      rect(context, itemX, itemY, 6, 9, color)
      rect(context, itemX + 1, itemY + 2, 4, 2, cream)
      rect(context, itemX + 2, itemY + 6, 2, 2, ink)
    }
  }
}

function drawAisleShelf(context: Context, x: number, y: number, productId: ProductId, name: string, stock: number) {
  const px = x * tile - 34
  const py = y * tile - 24
  rect(context, px + 7, py + 38, 66, 9, 'rgba(37,47,37,.24)')
  rect(context, px, py + 5, 66, 38, deepInk)
  rect(context, px + 4, py, 58, 37, '#c89154')
  rect(context, px + 4, py + 14, 58, 4, '#704b31')
  rect(context, px + 4, py + 31, 58, 6, '#8c5b39')
  rect(context, px + 8, py + 4, 50, 10, '#f1d48c')
  rect(context, px + 8, py + 19, 50, 11, '#e1bd72')
  drawGoods(context, productId, px + 10, py + 5, Math.ceil(stock / 2), 1)
  drawGoods(context, productId, px + 10, py + 20, Math.floor(stock / 2), 1)
  rect(context, px + 22, py + 33, 23, 8, '#fff0c4')
  pixelText(context, name.slice(0, 4), px + 34, py + 40, 7, ink, 'center')
  rect(context, px + 5, py + 43, 7, 6, ink)
  rect(context, px + 54, py + 43, 7, 6, ink)
}

function drawColdCase(context: Context, x: number, y: number, productId: ProductId, name: string, stock: number) {
  const px = x * tile - 35
  const py = y * tile - 31
  rect(context, px + 8, py + 52, 68, 8, 'rgba(37,47,37,.25)')
  rect(context, px, py, 70, 56, deepInk)
  rect(context, px + 4, py + 4, 62, 48, '#d7ece6')
  rect(context, px + 7, py + 7, 56, 17, '#9bcad0')
  rect(context, px + 7, py + 28, 56, 17, '#84b7c2')
  rect(context, px + 7, py + 24, 56, 4, '#e9f5e9')
  drawGoods(context, productId, px + 10, py + 10, Math.ceil(stock / 2), 1)
  drawGoods(context, productId, px + 10, py + 31, Math.floor(stock / 2), 1)
  rect(context, px + 53, py + 6, 3, 40, '#f4ffff')
  rect(context, px + 12, py + 48, 46, 10, '#eff1c5')
  pixelText(context, name.slice(0, 5), px + 35, py + 56, 7, ink, 'center')
}

function drawLockedFixture(context: Context, x: number, y: number, tier: number) {
  const px = x * tile - 34
  const py = y * tile - 26
  rect(context, px + 7, py + 41, 66, 8, 'rgba(37,47,37,.22)')
  rect(context, px, py, 66, 43, deepInk)
  rect(context, px + 4, py + 4, 58, 35, '#66766d')
  for (let index = -20; index < 80; index += 13) {
    context.strokeStyle = '#87948c'
    context.lineWidth = 4
    context.beginPath()
    context.moveTo(px + index, py + 39)
    context.lineTo(px + index + 32, py + 4)
    context.stroke()
  }
  outlineRect(context, px + 16, py + 13, 34, 17, '#f2d183', ink, 2)
  pixelText(context, `Lv.${tier}`, px + 33, py + 25, 9, ink, 'center')
}

function drawFixture(context: Context, game: GameState, productId: ProductId) {
  const product = products.find((item) => item.id === productId)!
  if (product.unlockTier > game.tier) {
    drawLockedFixture(context, product.shelf.x, product.shelf.y, product.unlockTier)
    return
  }
  if (productId === 'drink' || productId === 'bento') drawColdCase(context, product.shelf.x, product.shelf.y, productId, product.name, game.inventory[productId])
  else drawAisleShelf(context, product.shelf.x, product.shelf.y, productId, product.name, game.inventory[productId])
}

function drawCashier(context: Context, x: number, y: number, tickCount: number) {
  const blink = tickCount % 41 === 0
  rect(context, x - 13, y + 35, 29, 6, 'rgba(37,47,37,.22)')
  rect(context, x - 10, y + 12, 22, 24, deepInk)
  rect(context, x - 7, y + 11, 16, 22, '#4f9278')
  rect(context, x - 8, y - 6, 18, 18, deepInk)
  rect(context, x - 6, y - 4, 14, 15, '#efbd91')
  rect(context, x - 8, y - 8, 18, 7, '#283c35')
  rect(context, x - 5, y - 11, 13, 4, '#f0a14e')
  rect(context, x - 2, y + 2, 2, blink ? 1 : 2, ink)
  rect(context, x + 4, y + 2, 2, blink ? 1 : 2, ink)
  rect(context, x - 2, y + 23, 9, 4, '#fff0c4')
}

function drawRegister(context: Context, game: GameState) {
  const x = 58
  const y = 135
  rect(context, x + 8, y + 51, 132, 12, 'rgba(37,47,37,.25)')
  rect(context, x, y + 8, 128, 48, deepInk)
  rect(context, x + 5, y + 3, 118, 47, '#d66f36')
  rect(context, x + 5, y + 3, 118, 11, '#f0a14e')
  rect(context, x + 12, y + 18, 62, 25, '#ed8c3d')
  pixelText(context, 'レ ジ', x + 43, y + 37, 12, ink, 'center')
  outlineRect(context, x + 82, y - 12, 30, 26, '#52625c', deepInk, 3)
  rect(context, x + 87, y - 7, 20, 9, '#b9dc8b')
  pixelText(context, `${game.buyersToday}`, x + 97, y + 1, 7, ink, 'center')
  rect(context, x + 116, y + 19, 8, 24, '#9d4b35')
  rect(context, x + 118, y + 15, 4, 4, '#fff0bc')
  drawCashier(context, x + 93, y - 3, game.tick)
}

function customerFacing(customer: Customer): Facing {
  if (customer.state === 'paying') return 'back'
  const dx = customer.targetX - customer.x
  const dy = customer.targetY - customer.y
  if (Math.abs(dx) > Math.abs(dy)) return dx < 0 ? 'left' : 'right'
  return dy < 0 ? 'back' : 'front'
}

function hairColor(kind: CustomerKind, id: number) {
  const colors: Record<CustomerKind, string[]> = {
    worker: ['#263b37', '#473226'], student: ['#3b302b', '#6a3b2c'], neighbor: ['#5b3a2f', '#81705c'], nightowl: ['#242b3d', '#50345c'], collector: ['#5e342a', '#bd6d2f'],
  }
  const options = colors[kind]
  return options[id % options.length]
}

function drawThought(context: Context, customer: Customer) {
  const x = customer.x * tile + 10
  const y = customer.y * tile - 47
  outlineRect(context, x, y, 25, 20, '#fff4d1', ink, 2)
  rect(context, x - 4, y + 17, 5, 5, '#fff4d1')
  rect(context, x - 5, y + 16, 4, 4, ink)
  const palette = productPalette(customer.productId)
  rect(context, x + 8, y + 5, 9, 10, palette[customer.id % palette.length])
  rect(context, x + 10, y + 8, 5, 2, cream)
}

function drawCustomer(context: Context, customer: Customer, tickCount: number) {
  const x = customer.x * tile + tile / 2
  const y = customer.y * tile - 3
  const facing = customerFacing(customer)
  const moving = customer.x !== customer.targetX || customer.y !== customer.targetY
  const frame = moving && (tickCount + customer.id) % 4 >= 2 ? 1 : 0
  const bob = moving ? frame : 0
  const skin = customer.id % 4 === 0 ? '#c98b62' : customer.id % 3 === 0 ? '#e1aa7e' : '#f0c49b'
  const hair = hairColor(customer.kind, customer.id)
  const coat = customer.color
  const coatShade = customer.kind === 'student' ? '#923d3b' : customer.kind === 'worker' ? '#24466f' : '#704c69'

  context.save()
  context.translate(Math.round(x), Math.round(y - bob))
  rect(context, -12, 24, 25, 6, 'rgba(45,52,40,.24)')
  const leftLeg = frame === 0 ? -8 : -5
  const rightLeg = frame === 0 ? 3 : 6
  rect(context, leftLeg - 2, 11, 8, 16, deepInk)
  rect(context, rightLeg - 2, 11, 8, 16, deepInk)
  rect(context, leftLeg, 11, 5, 12, '#444b46')
  rect(context, rightLeg, 11, 5, 12, '#444b46')
  rect(context, leftLeg - 3, 23, 9, 4, '#1c2824')
  rect(context, rightLeg - 1, 23, 9, 4, '#1c2824')
  rect(context, -13, -8, 27, 24, deepInk)
  rect(context, -10, -7, 21, 22, coat)
  rect(context, -10, 10, 21, 5, coatShade)
  rect(context, -15, -5, 5, 15, deepInk)
  rect(context, 11, -5, 5, 15, deepInk)
  rect(context, -13, -4 + frame * 2, 3, 12, coat)
  rect(context, 11, -2 - frame * 2, 3, 12, coat)
  rect(context, -10, -25, 21, 19, deepInk)
  rect(context, -8, -23, 17, 16, skin)
  if (facing === 'back') {
    rect(context, -10, -27, 21, 17, hair)
    rect(context, -7, -11, 15, 4, hair)
  } else {
    rect(context, -10, -27, 21, 8, hair)
    rect(context, -10, -22, 4, 9, hair)
    rect(context, 7, -22, 4, 7, hair)
    if (facing === 'left') {
      rect(context, -5, -17, 3, 3, ink)
      rect(context, -8, -11, 3, 2, '#9e5944')
    } else if (facing === 'right') {
      rect(context, 3, -17, 3, 3, ink)
      rect(context, 6, -11, 3, 2, '#9e5944')
    } else {
      rect(context, -5, -17, 3, 3, ink)
      rect(context, 4, -17, 3, 3, ink)
      rect(context, -1, -11, 5, 2, '#9e5944')
    }
  }
  if (customer.kind === 'worker') {
    rect(context, -2, -5, 5, 12, '#eee7cf')
    rect(context, -1, -3, 3, 10, '#ad4638')
    outlineRect(context, facing === 'left' ? 11 : -19, 3, 9, 13, '#725139', deepInk, 2)
  } else if (customer.kind === 'student') {
    rect(context, -10, -7, 21, 4, '#f2e2b5')
    outlineRect(context, facing === 'left' ? 10 : -18, -3, 8, 16, '#556e85', deepInk, 2)
  } else if (customer.kind === 'collector') {
    rect(context, -8, -23, 18, 4, '#edaa3f')
    rect(context, -4, -18, 13, 3, '#6e3a2b')
  }
  if (customer.state === 'shopping') {
    outlineRect(context, 12, 1, 12, 12, '#f0d55e', deepInk, 2)
    rect(context, 15, -2, 6, 3, deepInk)
  }
  if (customer.state === 'paying') {
    rect(context, -19, -2, 6, 6, '#f2d05b')
    rect(context, -18, -1, 4, 4, '#ffec88')
  }
  context.restore()
  if ((customer.state === 'entering' || customer.state === 'shopping') && customer.timer % 9 < 6) drawThought(context, customer)
}

function drawAtm(context: Context) {
  const x = 603
  const y = 129
  rect(context, x + 5, y + 63, 75, 9, 'rgba(37,47,37,.25)')
  outlineRect(context, x, y, 70, 65, '#dceeed', deepInk, 4)
  rect(context, x + 7, y + 7, 56, 19, '#3f6a66')
  rect(context, x + 13, y + 11, 44, 11, '#a7d5b3')
  pixelText(context, 'ATM', x + 35, y + 43, 13, ink, 'center')
  rect(context, x + 14, y + 49, 42, 5, '#597871')
  rect(context, x + 24, y + 58, 22, 3, '#d15c3e')
}

function drawHotWarmer(context: Context) {
  const x = 602
  const y = 287
  rect(context, x + 4, y + 53, 76, 9, 'rgba(37,47,37,.24)')
  outlineRect(context, x, y, 72, 56, '#d96d34', deepInk, 4)
  rect(context, x + 7, y + 6, 58, 31, '#f8d58e')
  for (let row = 0; row < 2; row += 1) {
    for (let column = 0; column < 4; column += 1) {
      rect(context, x + 11 + column * 13, y + 10 + row * 13, 9, 8, row === 0 ? '#bd5a36' : '#e99a3f')
      rect(context, x + 13 + column * 13, y + 12 + row * 13, 5, 2, '#f4c36b')
    }
  }
  rect(context, x + 6, y + 40, 60, 9, '#a7422f')
  pixelText(context, 'あつあつ', x + 36, y + 48, 8, '#fff0bf', 'center')
}

function drawSmallProps(context: Context, game: GameState) {
  outlineRect(context, 18, 126, 25, 37, '#648b83', deepInk, 3)
  rect(context, 22, 130, 17, 5, '#d9ece6')
  pixelText(context, '傘', 30, 153, 8, cream, 'center')
  for (let index = 0; index < 3; index += 1) {
    rect(context, 21 + index * 6, 116 + index * 2, 2, 13, index === 0 ? '#4f7895' : '#b64c3b')
    rect(context, 19 + index * 6, 115 + index * 2, 6, 3, ink)
  }
  outlineRect(context, 668, 383, 28, 42, '#5d8870', deepInk, 3)
  rect(context, 672, 388, 20, 5, '#d6e8a8')
  rect(context, 676, 378, 4, 11, '#42694f')
  rect(context, 686, 375, 4, 14, '#42694f')
  rect(context, 671, 377, 10, 5, '#6ca85e')
  rect(context, 684, 373, 11, 6, '#78b765')
  outlineRect(context, 640, 431, 32, 23, '#5f746b', deepInk, 3)
  rect(context, 647, 427, 18, 5, '#344a44')

  if (game.event.id === 'quiet') {
    const x = 592
    const y = 423
    rect(context, x, y + 11, 32, 8, 'rgba(37,47,37,.2)')
    rect(context, x + 4, y, 21, 13, '#bd7a3e')
    rect(context, x + 23, y + 3, 9, 9, '#bd7a3e')
    rect(context, x + 24, y, 4, 5, '#bd7a3e')
    rect(context, x + 29, y, 4, 5, '#bd7a3e')
    rect(context, x + 28, y + 6, 2, 2, ink)
    pixelText(context, 'Z', x + 15, y - 5, 9, '#765b49')
  }
  if (game.event.id === 'buzz') {
    for (let index = 0; index < 5; index += 1) {
      const x = 414 + (index % 3) * 27
      const y = 246 + (index % 2) * 16
      rect(context, x, y, 3, 9, '#f2c64f')
      rect(context, x - 3, y + 3, 9, 3, '#f2c64f')
    }
  }
}

function drawEntrance(context: Context) {
  const x = 72
  const y = 404
  rect(context, x - 13, y + 43, 102, 8, 'rgba(37,47,37,.24)')
  outlineRect(context, x, y, 76, 52, '#8fd0de', deepInk, 4)
  rect(context, x + 36, y, 4, 52, deepInk)
  rect(context, x + 6, y + 5, 25, 35, '#bde4e8')
  rect(context, x + 45, y + 5, 25, 35, '#bde4e8')
  rect(context, x + 9, y + 8, 3, 24, 'rgba(255,255,255,.7)')
  rect(context, x + 48, y + 8, 3, 24, 'rgba(255,255,255,.7)')
  rect(context, x + 30, y + 23, 6, 3, '#bf5c3f')
  rect(context, x + 40, y + 23, 6, 3, '#bf5c3f')
  rect(context, x - 22, y + 47, 120, 9, '#436b60')
  for (let stripe = 0; stripe < 9; stripe += 1) rect(context, x - 18 + stripe * 13, y + 50, 7, 3, '#73998f')
}

function drawEffects(context: Context, game: GameState) {
  for (const effect of game.effects) {
    const divisor = effect.kind === 'sale' ? 100 : 10
    const age = Math.max(0, game.tick - Math.floor(effect.id / divisor))
    const x = effect.x * tile
    const y = effect.y * tile - 24 - age * 2
    const color = effect.kind === 'sale' ? '#297052' : effect.kind === 'event' ? '#b93d32' : '#315f93'
    context.font = '900 13px ui-monospace, monospace'
    const textWidth = Math.ceil(context.measureText(effect.text).width)
    rect(context, x - textWidth / 2 - 5, y - 14, textWidth + 10, 18, deepInk)
    rect(context, x - textWidth / 2 - 3, y - 12, textWidth + 6, 14, '#fff0bd')
    pixelText(context, effect.text, x, y - 1, 11, color, 'center')
  }
}

function drawStore(context: Context, game: GameState) {
  context.imageSmoothingEnabled = false
  drawSky(context, game)
  drawBackWall(context, game)
  drawFloor(context, game)
  drawCeilingLights(context, game)
  drawRegister(context, game)
  for (const product of products) drawFixture(context, game, product.id)
  if (game.tier >= 2) drawAtm(context)
  if (game.tier >= 3) drawHotWarmer(context)
  drawSmallProps(context, game)
  drawEntrance(context)
  for (const customer of [...game.customers].sort((a, b) => a.y - b.y || a.id - b.id)) drawCustomer(context, customer, game.tick)
  drawEffects(context, game)
  if (game.paused) {
    rect(context, 532, 423, 152, 37, 'rgba(11,33,28,.86)')
    rect(context, 541, 431, 134, 21, '#f2d27a')
    pixelText(context, 'PAUSED / 休憩中', 608, 447, 11, deepInk, 'center')
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
  const stockSummary = products.filter((product) => product.unlockTier <= game.tier).map((product) => `${product.name}${game.inventory[product.id]}個`).join('、')
  return <canvas ref={canvasRef} width={width} height={height} aria-label={`ぼんやりマート店内。${game.customers.length}人が店内にいます。在庫は${stockSummary}。`} />
}

export const productSymbol: Record<ProductId, string> = {
  onigiri: '米', drink: '飲', bread: '麦', snack: '菓', bento: '弁', hot: '熱',
}
