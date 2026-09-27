import { Vector3 } from 'three'
import type { PhysicsWorld, ObjectSnapshot } from '../physics/PhysicsWorld'

export type CatchPhase = 'ready' | 'countdown' | 'running' | 'finished'
export type CatchEvent = 'caught' | 'missed' | 'finished' | null

const lanes = [0, -0.32, 0.32, 0.58, -0.58, 0, 0.42, -0.42, 0.7, -0.7, 0.18, -0.18]

export class CatchGame {
  readonly total = lanes.length
  phase: CatchPhase = 'ready'
  catches = 0
  misses = 0
  spawned = 0
  private countdown = 2.2
  private spawnClock = 0
  private active = new Map<number, { x: number, age: number }>()
  private laneReach = 2.2
  private physics: PhysicsWorld

  constructor(physics: PhysicsWorld) { this.physics = physics }

  reset(laneReach: number): void {
    this.physics.clearObjects()
    this.phase = 'ready'
    this.catches = 0
    this.misses = 0
    this.spawned = 0
    this.countdown = 2.2
    this.spawnClock = 0
    this.active.clear()
    this.laneReach = Math.min(2.2, Math.max(0.8, laneReach))
  }

  get nextX(): number | null {
    return this.spawned < this.total ? lanes[this.spawned] * this.laneReach : null
  }
  get cueX(): number | null { return this.active.values().next().value?.x ?? this.nextX }

  get remaining(): number { return this.total - this.catches - this.misses }
  get countdownSeconds(): number { return Math.max(1, Math.ceil(this.countdown)) }

  update(dt: number, hand: Vector3 | null, normal: Vector3, objects: ObjectSnapshot[]): CatchEvent {
    if (this.phase === 'finished' || !hand) return null
    if (this.phase === 'ready') this.phase = 'countdown'
    if (this.phase === 'countdown') {
      this.countdown -= dt
      if (this.countdown <= 0) { this.phase = 'running'; this.spawnClock = 0.2 }
      return null
    }
    this.spawnClock += dt
    if (this.spawned < this.total && this.spawnClock >= 1.45) {
      this.spawnClock -= 1.45
      const x = lanes[this.spawned] * this.laneReach
      const id = this.physics.spawnCatchBall(x)
      if (id !== null) { this.active.set(id, { x, age: 0 }); this.spawned++ }
    }

    let event: CatchEvent = null
    for (const ball of this.active.values()) ball.age += dt
    for (const object of objects) {
      const ball = this.active.get(object.id)
      if (!ball) continue
      const dx = Math.abs(object.x - hand.x)
      const dy = Math.abs(object.y - hand.y)
      const dz = Math.abs(object.z - hand.z)
      // A broad target keeps the catch responsive; a palm facing the camera has more reach.
      const reach = normal.z < 0.4 ? 0.62 : 0.82
      if (dx < reach && dy < reach && dz < 0.88) {
        this.catches++
        this.active.delete(object.id)
        this.physics.removeObject(object.id)
        event = 'caught'
      } else if (object.z > 2.15 || ball.age > 3.5) {
        this.misses++
        this.active.delete(object.id)
        this.physics.removeObject(object.id)
        event = 'missed'
      }
    }
    if (this.spawned === this.total && this.active.size === 0) {
      this.phase = 'finished'
      return 'finished'
    }
    return event
  }
}
