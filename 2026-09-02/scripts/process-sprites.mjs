import { readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { PNG } from 'pngjs'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const appDirectory = resolve(scriptDirectory, '..')
const sourcePath = resolve(appDirectory, 'public/life-garden-sprites-v1.png')
const outputPath = resolve(appDirectory, 'public/life-garden-sprites-v1-alpha.png')
const columns = 5
const rows = 4
const frameSize = 32
const inset = 2

const source = PNG.sync.read(await readFile(sourcePath))
const atlas = new PNG({ width: columns * frameSize, height: rows * frameSize, colorType: 6 })
atlas.data.fill(0)

function isBackground(data, offset) {
  const red = data[offset]
  const green = data[offset + 1]
  const blue = data[offset + 2]
  const alpha = data[offset + 3]
  const maximum = Math.max(red, green, blue)
  const minimum = Math.min(red, green, blue)
  return alpha > 0 && minimum >= 228 && maximum - minimum <= 26
}

function extractTile(column, row) {
  const left = Math.round((column * source.width) / columns)
  const right = Math.round(((column + 1) * source.width) / columns)
  const top = Math.round((row * source.height) / rows)
  const bottom = Math.round(((row + 1) * source.height) / rows)
  const width = right - left
  const height = bottom - top
  const pixels = new Uint8Array(width * height * 4)

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const sourceOffset = ((top + y) * source.width + left + x) * 4
      const targetOffset = (y * width + x) * 4
      pixels.set(source.data.subarray(sourceOffset, sourceOffset + 4), targetOffset)
    }
  }

  const visited = new Uint8Array(width * height)
  const queue = []
  const enqueue = (x, y) => {
    const index = y * width + x
    if (visited[index] || !isBackground(pixels, index * 4)) return
    visited[index] = 1
    queue.push(index)
  }

  for (let x = 0; x < width; x += 1) {
    enqueue(x, 0)
    enqueue(x, height - 1)
  }
  for (let y = 0; y < height; y += 1) {
    enqueue(0, y)
    enqueue(width - 1, y)
  }

  for (let cursor = 0; cursor < queue.length; cursor += 1) {
    const index = queue[cursor]
    const x = index % width
    const y = Math.floor(index / width)
    pixels[index * 4 + 3] = 0
    for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
      for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
        if (offsetX === 0 && offsetY === 0) continue
        const nextX = x + offsetX
        const nextY = y + offsetY
        if (nextX >= 0 && nextX < width && nextY >= 0 && nextY < height) enqueue(nextX, nextY)
      }
    }
  }

  let minX = width
  let minY = height
  let maxX = -1
  let maxY = -1
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (pixels[(y * width + x) * 4 + 3] === 0) continue
      minX = Math.min(minX, x)
      minY = Math.min(minY, y)
      maxX = Math.max(maxX, x)
      maxY = Math.max(maxY, y)
    }
  }

  if (maxX < minX || maxY < minY) throw new Error(`Frame ${column},${row} is empty`)
  return { pixels, width, height, minX, minY, maxX, maxY }
}

function placeTile(tile, column, row) {
  const contentWidth = tile.maxX - tile.minX + 1
  const contentHeight = tile.maxY - tile.minY + 1
  const available = frameSize - inset * 2
  const scale = Math.min(available / contentWidth, available / contentHeight)
  const drawnWidth = Math.max(1, Math.round(contentWidth * scale))
  const drawnHeight = Math.max(1, Math.round(contentHeight * scale))
  const offsetX = column * frameSize + Math.floor((frameSize - drawnWidth) / 2)
  const offsetY = row * frameSize + Math.floor((frameSize - drawnHeight) / 2)

  for (let y = 0; y < drawnHeight; y += 1) {
    for (let x = 0; x < drawnWidth; x += 1) {
      const sourceX = tile.minX + Math.min(contentWidth - 1, Math.floor(x / scale))
      const sourceY = tile.minY + Math.min(contentHeight - 1, Math.floor(y / scale))
      const sourceOffset = (sourceY * tile.width + sourceX) * 4
      const targetOffset = ((offsetY + y) * atlas.width + offsetX + x) * 4
      atlas.data.set(tile.pixels.subarray(sourceOffset, sourceOffset + 4), targetOffset)
    }
  }
}

for (let row = 0; row < rows; row += 1) {
  for (let column = 0; column < columns; column += 1) {
    placeTile(extractTile(column, row), column, row)
  }
}

const opaqueCount = atlas.data.reduce((count, value, index) => index % 4 === 3 && value > 0 ? count + 1 : count, 0)
if (opaqueCount === 0) throw new Error('Generated atlas has no visible pixels')

await writeFile(outputPath, PNG.sync.write(atlas, { colorType: 6 }))
process.stdout.write(`Wrote ${outputPath} (${atlas.width}x${atlas.height}, ${opaqueCount} visible pixels)\n`)
