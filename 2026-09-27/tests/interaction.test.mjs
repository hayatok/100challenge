import test from 'node:test'
import assert from 'node:assert/strict'
import { cameraVideoConstraints, imageXToScreen } from '../src/vision/CameraFacing.ts'
import { FlickDetector } from '../src/vision/FlickDetector.ts'
import { readPalm } from '../src/vision/HandState.ts'
import { HandTracker } from '../src/vision/HandTracker.ts'
import { PhysicsWorld } from '../src/physics/PhysicsWorld.ts'
import { ScreenContact } from '../src/vision/ScreenContact.ts'

const point = x => ({ x, y: 1, z: 0 })

test('front camera mirrors hand x and rear camera keeps natural x', () => {
  assert.equal(imageXToScreen(0.2, 'user'), 0.8)
  assert.equal(imageXToScreen(0.2, 'environment'), 0.2)
  assert.deepEqual(cameraVideoConstraints('environment').facingMode, { exact: 'environment' })
  assert.deepEqual(cameraVideoConstraints('user').facingMode, { ideal: 'user' })
})

test('palm swipe triggers once and ignores short jitter', () => {
  const detector = new FlickDetector()
  assert.equal(detector.sample(point(0), null, 100), null)
  const flick = detector.sample(point(0.5), null, 133)
  assert.equal(flick?.source, 'palm')
  assert.ok(flick && flick.speed > 6 && flick.speed <= 24)
  assert.equal(detector.sample(point(1), null, 166), null)
  detector.reset()
  detector.sample(point(0), null, 500)
  for (let n = 1; n < 8; n++) {
    assert.equal(detector.sample(point(n * 0.01), null, 500 + n * 33), null)
  }
})

test('finger motion relative to a still palm triggers an index flick', () => {
  const detector = new FlickDetector()
  detector.sample(point(0), point(0), 100)
  const flick = detector.sample(point(0), point(0.4), 133)
  assert.equal(flick?.source, 'finger')
  assert.ok(flick && flick.origin.x > 0)
})

test('hand state exposes an extended index tip but hides a curled one', () => {
  const landmarks = Array.from({ length: 21 }, () => ({ x: 0.5, y: 0.5, z: 0 }))
  landmarks[0] = { x: 0.5, y: 0.8, z: 0 }
  landmarks[6] = { x: 0.5, y: 0.5, z: 0 }
  landmarks[8] = { x: 0.5, y: 0.2, z: 0 }
  const result = { landmarks: [landmarks], handedness: [[{ categoryName: 'Right' }]] }
  assert.deepEqual(readPalm(result).indexTip, { x: 0.5, y: 0.2 })
  landmarks[8] = { x: 0.5, y: 0.65, z: 0 }
  assert.equal(readPalm(result).indexTip, null)
  assert.equal(readPalm({ landmarks: [], handedness: [] }).detected, false)
})

test('camera switch releases the old track and restores it when the new facing mode fails', async () => {
  const oldNavigator = Object.getOwnPropertyDescriptor(globalThis, 'navigator')
  const oldDocument = Object.getOwnPropertyDescriptor(globalThis, 'document')
  const stopped = []
  const requested = []
  let failFront = false
  const video = { srcObject: null, muted: false, playsInline: false, pause() {}, async play() {} }
  const streamFor = facing => {
    const track = { getSettings: () => ({ facingMode: facing }), stop: () => stopped.push(facing) }
    return { getVideoTracks: () => [track], getTracks: () => [track] }
  }
  Object.defineProperty(globalThis, 'document', { configurable: true, value: { createElement: () => video } })
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {
    mediaDevices: { getUserMedia: async constraints => {
      const facing = constraints.video.facingMode.exact ?? constraints.video.facingMode.ideal
      requested.push(facing)
      if (facing === 'user' && failFront) throw new DOMException('No front camera', 'NotFoundError')
      return streamFor(facing)
    } },
  } })
  try {
    const tracker = new HandTracker()
    assert.equal(await tracker.switchFacing('environment', () => {}), true)
    assert.equal(tracker.facing, 'environment')
    failFront = true
    assert.equal(await tracker.switchFacing('user', () => {}), false)
    assert.equal(tracker.facing, 'environment')
    assert.deepEqual(requested, ['environment', 'user', 'environment'])
    assert.deepEqual(stopped, ['environment'])
    tracker.stop()
    assert.deepEqual(stopped, ['environment', 'environment'])
  } finally {
    if (oldNavigator) Object.defineProperty(globalThis, 'navigator', oldNavigator)
    else Reflect.deleteProperty(globalThis, 'navigator')
    if (oldDocument) Object.defineProperty(globalThis, 'document', oldDocument)
    else Reflect.deleteProperty(globalThis, 'document')
  }
})

test('queued finger flick moves a nearby dynamic ball in the fixed physics step', async () => {
  const physics = new PhysicsWorld()
  await physics.init()
  physics.clearObjects()
  physics.addObject('ball')
  const before = physics.getObjects()[0]
  physics.queueFlick({
    source: 'finger',
    origin: { x: before.x, y: before.y, z: before.z },
    direction: { x: 1, y: 0, z: 0 },
    speed: 10,
  })
  physics.step()
  const after = physics.getObjects()[0]
  assert.ok(after.x > before.x + 0.01, `expected a flick to move the ball: ${before.x} -> ${after.x}`)
  assert.ok(after.x - before.x < 0.27, 'one fixed step stays within the velocity cap')
})

test('a hand sweep contacts a visually crossed object even when its endpoint has passed it', () => {
  const contact = new ScreenContact()
  const target = [{ id: 42, x: 150, y: 100, radius: 12 }]
  assert.equal(contact.sample({ x: 90, y: 100 }, null, target, 100).impact, null)
  const hit = contact.sample({ x: 210, y: 100 }, null, target, 133).impact
  assert.equal(hit?.id, 42)
  assert.equal(hit?.source, 'palm')
  assert.ok(hit && hit.direction.x > 0)
  assert.equal(contact.sample({ x: 90, y: 100 }, null, target, 166).impact, null, 'contact has a per-object cooldown')
  assert.equal(contact.sample({ x: 210, y: 100 }, null, target, 400).impact, null, 'stale tracking does not jump into an object')
  assert.equal(contact.sample({ x: 90, y: 100 }, null, target, 433).impact?.id, 42)
})

test('an aimed object is highlighted while stationary, but only moving the hand applies force', async () => {
  const contact = new ScreenContact()
  const target = [{ id: 1, x: 100, y: 100, radius: 15 }]
  assert.deepEqual(contact.sample({ x: 100, y: 100 }, null, target, 100), { aimedId: 1, impact: null })
  assert.equal(contact.sample({ x: 102, y: 100 }, null, target, 133).impact, null)

  const physics = new PhysicsWorld()
  await physics.init()
  physics.clearObjects()
  physics.addObject('ball')
  const before = physics.getObjects()[0]
  physics.queueScreenImpact({ id: before.id, source: 'palm', direction: { x: 1, y: 0, z: 0 }, speed: 700 })
  physics.step()
  assert.ok(physics.getObjects()[0].x > before.x + 0.01)
})
