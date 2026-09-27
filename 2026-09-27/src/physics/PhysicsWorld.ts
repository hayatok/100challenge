import RAPIER from '@dimforge/rapier3d-compat'
import { Vector3 } from 'three'

export interface BallSnapshot {
  x: number
  y: number
  z: number
  radius: number
}

export class PhysicsWorld {
  private world!: RAPIER.World
  private hand!: RAPIER.RigidBody
  private balls: Array<{ body: RAPIER.RigidBody; radius: number }> = []
  private target = new Vector3(0, -10, 0)
  private active = false
  readonly timestep = 1 / 60

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
    this.resetBalls()
  }

  resetBalls(): void {
    for (const ball of this.balls) this.world.removeRigidBody(ball.body)
    this.balls = []
    const radius = 0.27
    for (let row = 0; row < 4; row++) {
      for (let column = 0; column < 5; column++) {
        const x = (column - 2) * 0.62 + (row % 2) * 0.08
        const y = radius + row * 0.62 + 0.04
        const z = ((column + row) % 3 - 1) * 0.17
        const body = this.world.createRigidBody(
          RAPIER.RigidBodyDesc.dynamic().setTranslation(x, y, z).setCcdEnabled(true).setLinearDamping(0.18),
        )
        this.world.createCollider(RAPIER.ColliderDesc.ball(radius).setRestitution(0.62).setFriction(0.52), body)
        this.balls.push({ body, radius })
      }
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

  getBalls(): BallSnapshot[] {
    return this.balls.map(({ body, radius }) => {
      const point = body.translation()
      return { x: point.x, y: point.y, z: point.z, radius }
    })
  }

  get ballCount(): number { return this.balls.length }
}
