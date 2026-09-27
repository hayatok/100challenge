import RAPIER from '@dimforge/rapier3d-compat'
import { Vector3 } from 'three'
import type { Flick } from '../vision/FlickDetector'
import type { ScreenImpact } from '../vision/ScreenContact'

export type ObjectKind = 'ball' | 'box' | 'domino' | 'catch'

export interface ObjectSnapshot {
  id: number
  kind: ObjectKind
  x: number
  y: number
  z: number
  rotation: { x: number; y: number; z: number; w: number }
  size: { x: number; y: number; z: number }
}

interface PhysicsObject {
  id: number
  kind: ObjectKind
  body: RAPIER.RigidBody
  size: ObjectSnapshot['size']
}

export class PhysicsWorld {
  private world!: RAPIER.World
  private hand!: RAPIER.RigidBody
  private fingertip!: RAPIER.RigidBody
  private objects: PhysicsObject[] = []
  private nextId = 1
  private spawnIndex = 0
  private target = new Vector3(0, -10, 0)
  private fingertipTarget = new Vector3(0, -10, 0)
  private active = false
  private fingertipActive = false
  private queuedFlicks: Flick[] = []
  private queuedScreenImpacts: ScreenImpact[] = []
  readonly timestep = 1 / 60
  readonly maxObjects = 100

  async init(): Promise<void> {
    await RAPIER.init()
    this.world = new RAPIER.World({ x: 0, y: -9.81, z: 0 })
    this.world.timestep = this.timestep
    const floor = this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed().setTranslation(0, -0.35, 0))
    this.world.createCollider(RAPIER.ColliderDesc.cuboid(6, 0.3, 3).setFriction(0.7), floor)
    for (const side of [-1, 1]) {
      const wall = this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed().setTranslation(side * 5.8, 1.6, 0))
      this.world.createCollider(RAPIER.ColliderDesc.cuboid(0.2, 2, 3), wall)
      const depthWall = this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed().setTranslation(0, 1.6, side * 2.8))
      this.world.createCollider(RAPIER.ColliderDesc.cuboid(6, 2, 0.2), depthWall)
    }
    this.hand = this.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased().setTranslation(0, -10, 0))
    this.world.createCollider(RAPIER.ColliderDesc.ball(0.48).setFriction(0.2), this.hand)
    this.fingertip = this.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased().setTranslation(0, -10, 0))
    this.world.createCollider(RAPIER.ColliderDesc.ball(0.17).setFriction(0.15), this.fingertip)
    this.resetObjects()
  }

  private createObject(kind: ObjectKind, x: number, y: number, z: number): number | null {
    if (this.objects.length >= this.maxObjects) return null
    const size = kind === 'ball' || kind === 'catch' ? { x: 0.54, y: 0.54, z: 0.54 }
      : kind === 'box' ? { x: 0.56, y: 0.56, z: 0.56 }
      : { x: 0.18, y: 0.8, z: 0.42 }
    const description = RAPIER.RigidBodyDesc.dynamic().setTranslation(x, y, z)
      .setCcdEnabled(true).setLinearDamping(kind === 'catch' ? 0 : 0.18)
    if (kind === 'catch') description.setGravityScale(0).setLinvel(0, 0, 2.65)
    const body = this.world.createRigidBody(description)
    const collider = kind === 'ball' || kind === 'catch'
      ? RAPIER.ColliderDesc.ball(size.x / 2).setRestitution(0.62).setFriction(0.52)
      : RAPIER.ColliderDesc.cuboid(size.x / 2, size.y / 2, size.z / 2).setRestitution(0.18).setFriction(0.78)
    this.world.createCollider(collider, body)
    const id = this.nextId++
    this.objects.push({ id, kind, body, size })
    return id
  }

  addObject(kind: ObjectKind): boolean {
    const index = this.spawnIndex++
    const x = ((index % 7) - 3) * 0.78
    const y = 2.7 + (Math.floor(index / 7) % 3) * 0.85
    const z = ((Math.floor(index / 21) % 3) - 1) * 0.65
    return this.createObject(kind, x, y, z) !== null
  }

  spawnCatchBall(x: number): number | null { return this.createObject('catch', x, 1.55, -2.2) }

  removeObject(id: number): void {
    const index = this.objects.findIndex(object => object.id === id)
    if (index < 0) return
    this.world.removeRigidBody(this.objects[index].body)
    this.objects.splice(index, 1)
  }

  clearObjects(): void {
    for (const object of this.objects) this.world.removeRigidBody(object.body)
    this.objects = []
    this.queuedFlicks = []
    this.queuedScreenImpacts = []
    this.spawnIndex = 0
  }

  resetObjects(): void {
    this.clearObjects()
    const radius = 0.27
    for (let row = 0; row < 4; row++) {
      for (let column = 0; column < 5; column++) {
        this.createObject('ball', (column - 2) * 0.62 + (row % 2) * 0.08,
          radius + row * 0.62 + 0.04, ((column + row) % 3 - 1) * 0.17)
      }
    }
  }

  loadHundred(): void {
    this.clearObjects()
    for (let index = 0; index < this.maxObjects; index++) {
      const kind: ObjectKind = index % 5 === 0 ? 'domino' : index % 3 === 0 ? 'box' : 'ball'
      const x = ((index % 10) - 4.5) * 0.72
      const z = ((Math.floor(index / 10) % 5) - 2) * 0.82
      const y = 0.8 + Math.floor(index / 50) * 1.05
      this.createObject(kind, x, y, z)
    }
  }

  setHandTarget(position: Vector3 | null): void {
    if (!position) {
      this.active = false
      this.target.set(0, -10, 0)
      this.hand.setTranslation({ x: 0, y: -10, z: 0 }, true)
      return
    }
    this.target.copy(position)
    if (!this.active) {
      this.hand.setTranslation(position, true)
      this.active = true
    }
  }

  setFingertipTarget(position: Vector3 | null): void {
    if (!position) {
      this.fingertipActive = false
      this.fingertipTarget.set(0, -10, 0)
      this.fingertip.setTranslation({ x: 0, y: -10, z: 0 }, true)
      return
    }
    this.fingertipTarget.copy(position)
    if (!this.fingertipActive) {
      this.fingertip.setTranslation(position, true)
      this.fingertipActive = true
    }
  }

  queueFlick(flick: Flick): void {
    if (this.queuedFlicks.length < 2) this.queuedFlicks.push(flick)
  }

  queueScreenImpact(impact: ScreenImpact): void {
    if (this.queuedScreenImpacts.length < 3) this.queuedScreenImpacts.push(impact)
  }

  private applyScreenImpact(impact: ScreenImpact): void {
    const object = this.objects.find(candidate => candidate.id === impact.id)
    if (!object) return
    const current = object.body.linvel()
    const direction = new Vector3(impact.direction.x, impact.direction.y + 0.1, 0).normalize()
    const gain = Math.min(10, 2.5 + impact.speed * 0.004)
    const next = new Vector3(current.x, current.y, current.z).addScaledVector(direction, gain)
    if (next.length() > 16) next.setLength(16)
    const mass = object.body.mass()
    object.body.applyImpulse({
      x: (next.x - current.x) * mass,
      y: (next.y - current.y) * mass,
      z: (next.z - current.z) * mass,
    }, true)
  }

  private applyFlick(flick: Flick): void {
    const reach = flick.source === 'finger' ? 0.72 : 0.95
    for (const object of this.objects) {
      const point = object.body.translation()
      const distance = Math.hypot(point.x - flick.origin.x, point.y - flick.origin.y, point.z - flick.origin.z)
      const range = reach + Math.max(object.size.x, object.size.y, object.size.z) / 2
      if (distance > range) continue
      const falloff = Math.max(0.15, 1 - distance / range)
      const gain = flick.source === 'finger' ? 4 : 3
      const speed = Math.min(11, gain + flick.speed * 0.45) * falloff
      const direction = new Vector3(flick.direction.x, flick.direction.y + 0.08, flick.direction.z).normalize()
      const current = object.body.linvel()
      const next = new Vector3(current.x, current.y, current.z).addScaledVector(direction, speed)
      if (next.length() > 16) next.setLength(16)
      const mass = object.body.mass()
      object.body.applyImpulse({
        x: (next.x - current.x) * mass,
        y: (next.y - current.y) * mass,
        z: (next.z - current.z) * mass,
      }, true)
    }
  }

  step(): number {
    const start = performance.now()
    const current = this.hand.translation()
    const delta = this.target.clone().sub(new Vector3(current.x, current.y, current.z))
    delta.clampLength(0, 0.28)
    this.hand.setNextKinematicTranslation({ x: current.x + delta.x, y: current.y + delta.y, z: current.z + delta.z })
    const fingertip = this.fingertip.translation()
    const fingertipDelta = this.fingertipTarget.clone().sub(new Vector3(fingertip.x, fingertip.y, fingertip.z))
    fingertipDelta.clampLength(0, 0.3)
    this.fingertip.setNextKinematicTranslation({
      x: fingertip.x + fingertipDelta.x,
      y: fingertip.y + fingertipDelta.y,
      z: fingertip.z + fingertipDelta.z,
    })
    for (const flick of this.queuedFlicks) this.applyFlick(flick)
    this.queuedFlicks = []
    for (const impact of this.queuedScreenImpacts) this.applyScreenImpact(impact)
    this.queuedScreenImpacts = []
    this.world.step()
    return performance.now() - start
  }

  getHandPosition(): Vector3 | null {
    if (!this.active) return null
    const point = this.hand.translation()
    return new Vector3(point.x, point.y, point.z)
  }

  getFingertipPosition(): Vector3 | null {
    if (!this.fingertipActive) return null
    const point = this.fingertip.translation()
    return new Vector3(point.x, point.y, point.z)
  }

  getObjects(): ObjectSnapshot[] {
    return this.objects.map(({ id, kind, body, size }) => {
      const point = body.translation()
      return { id, kind, x: point.x, y: point.y, z: point.z, rotation: body.rotation(), size }
    })
  }

  get objectCount(): number { return this.objects.length }
}
