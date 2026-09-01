export type RandomSource = () => number

export function createSeededRandom(seed: number): RandomSource {
  let state = seed >>> 0 || 0x6d2b79f5
  return () => {
    state ^= state << 13
    state ^= state >>> 17
    state ^= state << 5
    return (state >>> 0) / 0x1_0000_0000
  }
}

export function nextRandom(seed: number) {
  let state = seed >>> 0 || 0x6d2b79f5
  state ^= state << 13
  state ^= state >>> 17
  state ^= state << 5
  return { state: state >>> 0, value: (state >>> 0) / 0x1_0000_0000 }
}

export function randomInt(random: RandomSource, min: number, max: number) {
  return Math.floor(random() * (max - min + 1)) + min
}

export function createRandomSeed() {
  if (typeof crypto !== 'undefined' && 'getRandomValues' in crypto) {
    return crypto.getRandomValues(new Uint32Array(1))[0]
  }
  return (Date.now() ^ Math.floor(Math.random() * 0xffff_ffff)) >>> 0
}
