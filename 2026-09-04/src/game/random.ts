export function nextRandom(state: number) {
  let next = state >>> 0
  next ^= next << 13
  next ^= next >>> 17
  next ^= next << 5
  return next >>> 0
}

export function randomValue(state: number) {
  const next = nextRandom(state)
  return { state: next, value: next / 0x1_0000_0000 }
}

export function createRandomSeed() {
  return (Date.now() ^ Math.floor(Math.random() * 0xffff_ffff)) >>> 0 || 1
}
