export function createRandom(seed: number) {
  let state = seed >>> 0
  return () => {
    state ^= state << 13
    state ^= state >>> 17
    state ^= state << 5
    return (state >>> 0) / 4294967296
  }
}

export function glorot(size: number, fanIn: number, fanOut: number, random: () => number) {
  const limit = Math.sqrt(6 / (fanIn + fanOut))
  return Float32Array.from({ length: size }, () => (random() * 2 - 1) * limit)
}

export function shuffledIndices(length: number, seed: number) {
  const values = Array.from({ length }, (_, index) => index)
  const random = createRandom(seed)
  for (let index = values.length - 1; index > 0; index -= 1) {
    const target = Math.floor(random() * (index + 1))
    ;[values[index], values[target]] = [values[target], values[index]]
  }
  return values
}
