export const FRAME_SIZE = 32
export const ATLAS_COLUMNS = 5

export const sprites = {
  seed: 0,
  crackedSeed: 1,
  sprout: 2,
  twoLeaf: 3,
  plant: 4,
  lushPlant: 5,
  yellowFlower: 6,
  whiteFlower: 7,
  pinkFlower: 8,
  blueFlower: 9,
  newborn: 10,
  fading: 11,
  firefly: 12,
  fireflies: 13,
  raindrop: 14,
  splash: 15,
  driftingSeed: 16,
  restingSoil: 17,
  moss: 18,
  sparkle: 19,
} as const

export function spriteCoordinates(frame: number) {
  return {
    sourceX: (frame % ATLAS_COLUMNS) * FRAME_SIZE,
    sourceY: Math.floor(frame / ATLAS_COLUMNS) * FRAME_SIZE,
  }
}
