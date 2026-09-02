export function preprocessDrawing(canvas: HTMLCanvasElement) {
  const context = canvas.getContext('2d', { willReadFrequently: true })
  if (!context) throw new Error('描画Canvasを読み取れません')
  const { width, height } = canvas
  const rgba = context.getImageData(0, 0, width, height).data
  let minX = width
  let minY = height
  let maxX = -1
  let maxY = -1
  let active = 0
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const index = (y * width + x) * 4
      const intensity = 1 - (rgba[index] + rgba[index + 1] + rgba[index + 2]) / (3 * 255)
      if (intensity > 0.08) {
        minX = Math.min(minX, x)
        maxX = Math.max(maxX, x)
        minY = Math.min(minY, y)
        maxY = Math.max(maxY, y)
        active += 1
      }
    }
  }
  if (active < 24 || maxX < minX || maxY < minY) return null

  const sourceWidth = maxX - minX + 1
  const sourceHeight = maxY - minY + 1
  const scale = Math.min(20 / sourceWidth, 20 / sourceHeight)
  const targetWidth = Math.max(1, Math.round(sourceWidth * scale))
  const targetHeight = Math.max(1, Math.round(sourceHeight * scale))
  const offsetX = Math.floor((28 - targetWidth) / 2)
  const offsetY = Math.floor((28 - targetHeight) / 2)
  const result = new Float32Array(784)

  for (let ty = 0; ty < targetHeight; ty += 1) {
    for (let tx = 0; tx < targetWidth; tx += 1) {
      const sourceX = Math.min(maxX, Math.round(minX + (tx + 0.5) / scale))
      const sourceY = Math.min(maxY, Math.round(minY + (ty + 0.5) / scale))
      const index = (sourceY * width + sourceX) * 4
      const intensity = 1 - (rgba[index] + rgba[index + 1] + rgba[index + 2]) / (3 * 255)
      result[(offsetY + ty) * 28 + offsetX + tx] = Math.max(0, Math.min(1, intensity))
    }
  }
  return result
}
