import { createSeededRandom, randomInt } from './random'
import {
  DUNGEON_HEIGHT,
  DUNGEON_WIDTH,
  type Dungeon,
  type Enemy,
  type EnemyKind,
  type Point,
  type Treasure,
  type TreasureKind,
  tileIndex,
} from './types'

type Room = { x: number; y: number; width: number; height: number; center: Point }

const enemyNames: Record<EnemyKind, string> = {
  slime: 'ぬるいスライム',
  bat: 'せっかちコウモリ',
  skeleton: '経理スケルトン',
  goblin: '現場ゴブリン',
  ogre: '課長オーガ',
  boss: '迷宮事業部長',
}

function intersects(a: Room, b: Room) {
  return a.x - 1 < b.x + b.width && a.x + a.width + 1 > b.x && a.y - 1 < b.y + b.height && a.y + a.height + 1 > b.y
}

function carveRoom(tiles: Uint8Array, room: Room) {
  for (let y = room.y; y < room.y + room.height; y += 1) {
    for (let x = room.x; x < room.x + room.width; x += 1) tiles[tileIndex({ x, y })] = 1
  }
}

function carveCorridor(tiles: Uint8Array, from: Point, to: Point, horizontalFirst: boolean) {
  const carveHorizontal = (start: Point, endX: number) => {
    const direction = start.x <= endX ? 1 : -1
    for (let x = start.x; x !== endX + direction; x += direction) tiles[tileIndex({ x, y: start.y })] = 1
  }
  const carveVertical = (start: Point, endY: number) => {
    const direction = start.y <= endY ? 1 : -1
    for (let y = start.y; y !== endY + direction; y += direction) tiles[tileIndex({ x: start.x, y })] = 1
  }
  if (horizontalFirst) {
    carveHorizontal(from, to.x)
    carveVertical({ x: to.x, y: from.y }, to.y)
  } else {
    carveVertical(from, to.y)
    carveHorizontal({ x: from.x, y: to.y }, to.x)
  }
}

function enemyTemplate(kind: EnemyKind, floor: number, id: number, point: Point, elite = false): Enemy {
  const base = kind === 'slime' ? 1 : kind === 'bat' ? 2 : kind === 'skeleton' ? 3 : kind === 'goblin' ? 4 : kind === 'ogre' ? 6 : 9
  const level = floor + Math.floor(base / 3) + (elite ? 1 : 0)
  const boss = kind === 'boss'
  const scale = boss ? 3.2 : elite ? 1.65 : 1
  const maxHp = Math.round((7 + base * 2 + floor * 3) * scale)
  return {
    ...point,
    id,
    kind,
    name: enemyNames[kind],
    level,
    hp: maxHp,
    maxHp,
    attack: Math.round((2 + base + floor * 1.3) * (boss ? 1.45 : elite ? 1.18 : 1)),
    defense: Math.floor((base + floor) / 3) + (elite ? 1 : 0),
    xp: Math.round((4 + base * 2 + floor * 2) * (boss ? 3 : elite ? 1.7 : 1)),
    elite,
    boss,
  }
}

function pickEnemyKind(random: () => number, floor: number): EnemyKind {
  const pool: EnemyKind[] = floor === 1
    ? ['slime', 'slime', 'bat', 'goblin']
    : floor === 2
      ? ['slime', 'bat', 'skeleton', 'goblin']
      : floor <= 4
        ? ['bat', 'skeleton', 'goblin', 'ogre']
        : ['skeleton', 'goblin', 'ogre', 'ogre']
  return pool[Math.floor(random() * pool.length)]
}

export function createDungeon(seed: number, floor: number): Dungeon {
  const random = createSeededRandom((seed ^ Math.imul(floor, 0x9e3779b1)) >>> 0)
  const tiles = new Uint8Array(DUNGEON_WIDTH * DUNGEON_HEIGHT)
  const rooms: Room[] = []
  for (let attempt = 0; attempt < 180 && rooms.length < 11; attempt += 1) {
    const width = randomInt(random, 4, 8)
    const height = randomInt(random, 4, 7)
    const x = randomInt(random, 2, DUNGEON_WIDTH - width - 3)
    const y = randomInt(random, 2, DUNGEON_HEIGHT - height - 3)
    const room: Room = { x, y, width, height, center: { x: x + Math.floor(width / 2), y: y + Math.floor(height / 2) } }
    if (rooms.some((existing) => intersects(room, existing))) continue
    rooms.push(room)
    carveRoom(tiles, room)
  }

  if (rooms.length < 4) {
    const fallback: Room[] = [
      { x: 3, y: 3, width: 7, height: 6, center: { x: 6, y: 6 } },
      { x: 16, y: 5, width: 8, height: 6, center: { x: 20, y: 8 } },
      { x: 29, y: 16, width: 7, height: 7, center: { x: 32, y: 19 } },
    ]
    rooms.splice(0, rooms.length, ...fallback)
    tiles.fill(0)
    rooms.forEach((room) => carveRoom(tiles, room))
  }

  rooms.sort((a, b) => a.center.x + a.center.y - (b.center.x + b.center.y))
  for (let index = 1; index < rooms.length; index += 1) {
    carveCorridor(tiles, rooms[index - 1].center, rooms[index].center, random() > 0.5)
  }

  const start = rooms[0].center
  const stairs = rooms[rooms.length - 1].center
  tiles[tileIndex(stairs)] = 2
  if (rooms.length > 3) tiles[tileIndex(rooms[Math.floor(rooms.length / 2)].center)] = 3

  const occupied = new Set([tileIndex(start), tileIndex(stairs)])
  for (let index = 0; index < tiles.length; index += 1) {
    if (tiles[index] === 3) occupied.add(index)
  }
  const floorCells: Point[] = []
  for (let y = 1; y < DUNGEON_HEIGHT - 1; y += 1) {
    for (let x = 1; x < DUNGEON_WIDTH - 1; x += 1) {
      if (tiles[tileIndex({ x, y })] > 0 && Math.abs(x - start.x) + Math.abs(y - start.y) > 5) floorCells.push({ x, y })
    }
  }

  const enemies: Enemy[] = []
  const enemyCount = 7 + floor * 2
  for (let id = 0; id < enemyCount && floorCells.length > 0; id += 1) {
    let point = floorCells.splice(Math.floor(random() * floorCells.length), 1)[0]
    while (point && occupied.has(tileIndex(point))) point = floorCells.splice(Math.floor(random() * floorCells.length), 1)[0]
    if (!point) break
    occupied.add(tileIndex(point))
    const elite = random() < 0.13 + floor * 0.015
    enemies.push(enemyTemplate(pickEnemyKind(random, floor), floor, id, point, elite))
  }

  if (floor === 5) {
    const bossPoint = { ...stairs }
    enemies.push(enemyTemplate('boss', floor, 999, bossPoint))
  }

  const treasureKinds: TreasureKind[] = ['gold', 'gold', 'potion', 'weapon', 'armor', 'charm']
  const treasures: Treasure[] = []
  const treasureCount = 3 + floor
  for (let id = 0; id < treasureCount && floorCells.length > 0; id += 1) {
    let point = floorCells.splice(Math.floor(random() * floorCells.length), 1)[0]
    while (point && occupied.has(tileIndex(point))) point = floorCells.splice(Math.floor(random() * floorCells.length), 1)[0]
    if (!point) break
    occupied.add(tileIndex(point))
    const kind = treasureKinds[Math.floor(random() * treasureKinds.length)]
    treasures.push({ ...point, id, kind, opened: false })
  }

  return { width: DUNGEON_WIDTH, height: DUNGEON_HEIGHT, tiles, start, stairs, enemies, treasures }
}

export function isWalkable(dungeon: Dungeon, point: Point) {
  return point.x >= 0 && point.x < dungeon.width && point.y >= 0 && point.y < dungeon.height && dungeon.tiles[tileIndex(point, dungeon.width)] > 0
}
