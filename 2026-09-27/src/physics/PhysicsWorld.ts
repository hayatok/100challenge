import RAPIER from '@dimforge/rapier3d-compat'
import { Vector3 } from 'three'

export type ObjectKind = 'ball' | 'box' | 'domino'

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
  private objects: PhysicsObject[] = []
  private nextId = 1
  private spawnIndex = 0
  private target = new Vector3(0, -10, 0)
  private active = false
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
    this.resetObjects()
  }

  private createObject(kind: ObjectKind, x: number, y: number, z: number): boolean {
    if (this.objects.length >= this.maxObjects) return false
    const size = kind === 'ball' ? { x: 0.54, y: 0.54, z: 0.54 }
      : kind === 'box' ? { x: 0.56, y: 0.56, z: 0.56 }
      : { x: 0.18, y: 0.8, z: 0.42 }
    const body = this.world.createRigidBody(
      RAPIER.RigidBodyDesc.dynamic().setTranslation(x, y, z).setCcdEnabled(true).setLinearDamping(0.18),
    )
    const collider = kind === 'ball'
      ? RAPIER.ColliderDesc.ball(size.x / 2).setRestitution(0.62).setFriction(0.52)
      : RAPIER.ColliderDesc.cuboid(size.x / 2, size.y / 2, size.z / 2).setRestitution(0.18).setFriction(0.78)
    this.world.createCollider(collider, body)
    this.objects.push({ id: this.nextId++, kind, body, size })
    return true
  }

  addObject(kind: ObjectKind): boolean {
    const index = this.spawnIndex++
    const x = ((index % 7) - 3) * 0.78
    const y = 2.7 + (Math.floor(index / 7) % 3) * 0.85
    const z = ((Math.floor(index / 21) % 3) - 1) * 0.65
    return this.createObject(kind, x, y, z)
  }

  clearObjects(): void {
    for (const object of this.objects) this.world.removeRigidBody(object.body)
    this.objects = []
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

  step(): number {
    const start = performance.now()
    const current = this.hand.translation()
    const delta = this.target.clone().sub(new Vector3(current.x, current.y, current.z))
    delta.clampLength(0, 0.28)
    this.hand.setNextKinematicTranslation({ x: current.x + delta.x, y: current.y + delta.y, z: current.z + delta.z })
    this.world.step()
    return performance.now() - start
  }

  getHandPosition(): Vector3 | null {
    if (!this.active) return null
    const point = this.hand.translation()
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
