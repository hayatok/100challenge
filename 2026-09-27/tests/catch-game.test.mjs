import test from 'node:test'
import assert from 'node:assert/strict'
import { Vector3 } from 'three'
import { CatchGame } from '../src/game/CatchGame.ts'
import { SpatialHand } from '../src/vision/SpatialHand.ts'

test('catch round pauses without a hand, awards a palm catch, and finishes after 12 balls', () => {
  let id = 0
  const balls = new Map()
  const physics = {
    clearObjects: () => balls.clear(),
    spawnCatchBall: x => { balls.set(++id, x); return id },
    removeObject: ballId => balls.delete(ballId),
  }
  const game = new CatchGame(physics)
  const palm = new Vector3(0, 1.4, 0)
  const normal = new Vector3(0, 0.4, 0.9)
  game.reset(2)
  for (let i = 0; i < 120; i++) game.update(1 / 60, null, normal, [])
  assert.equal(game.phase, 'ready')
  for (let i = 0; i < 300 && game.spawned === 0; i++) game.update(1 / 60, palm, normal, [])
  assert.equal(game.spawned, 1)
  const first = [...balls.entries()][0]
  const caught = { id: first[0], x: first[1], y: palm.y + 0.15, z: 0 }
  assert.equal(game.update(1 / 60, palm, normal, [caught]), 'caught')
  assert.equal(game.catches, 1)
  assert.equal(game.remaining, 11)

  let finish = null
  for (let i = 0; i < 1600 && game.phase !== 'finished'; i++) {
    const objects = [...balls].map(([ballId, x]) => ({ id: ballId, x, y: 0.27, z: 0 }))
    finish = game.update(1 / 60, palm, normal, objects)
  }
  assert.equal(finish, 'finished')
  assert.equal(game.phase, 'finished')
  assert.equal(game.misses, 11)
  assert.equal(game.remaining, 0)
  game.reset(1)
  assert.equal(game.phase, 'ready')
  assert.equal(game.catches, 0)
})

test('relative hand depth recenters and 3D pose mirrors with front camera', () => {
  const points = Array.from({ length: 21 }, () => ({ x: 0, y: 0, z: 0 }))
  points[0] = { x: 0, y: 0.08, z: 0 }
  points[5] = { x: -0.04, y: 0, z: 0 }
  points[9] = { x: 0, y: -0.04, z: 0 }
  points[17] = { x: 0.04, y: 0, z: 0 }
  const hand = new SpatialHand()
  const state = { detected: true, x: 0.5, y: 0.5, handedness: 'Right', indexTip: null, palmSpan: 0.2, worldPoints: points }
  const rear = hand.sample(state, 'environment', 1)
  assert.ok(Math.abs(rear.depth) < 0.01)
  assert.ok(rear.points[5].x < rear.points[17].x)
  const closer = hand.sample({ ...state, palmSpan: 0.4 }, 'user', 1)
  assert.ok(closer.depth > 0.9, 'larger apparent hand moves toward the viewer')
  assert.ok(closer.points[5].x > closer.points[17].x)
  hand.recenter()
  assert.ok(Math.abs(hand.sample({ ...state, palmSpan: 0.4 }, 'user', 1).depth) < 0.01)
})
