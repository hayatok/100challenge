import { Vector3 } from 'three'
import type { CameraFacing } from './CameraFacing'
import type { HandState } from './HandState'

export interface SpatialPose {
  depth: number
  points: Vector3[] | null
  normal: Vector3
}

const palmIds = [0, 5, 9, 13, 17]

export class SpatialHand {
  private referenceSpan: number | null = null
  private depth = 0

  recenter(): void { this.referenceSpan = null; this.depth = 0 }

  sample(state: HandState, facing: CameraFacing, dt: number): SpatialPose {
    if (this.referenceSpan === null) this.referenceSpan = state.palmSpan
    // The apparent palm width supplies only relative depth, never camera distance in metres.
    const target = Math.max(-1.15, Math.min(1.15, Math.log(state.palmSpan / this.referenceSpan) * 1.8))
    this.depth += (target - this.depth) * (1 - Math.exp(-Math.max(0, dt) * 8))
    if (!state.worldPoints) return { depth: this.depth, points: null, normal: new Vector3(0, 0.35, 0.94) }
    const center = new Vector3()
    for (const id of palmIds) {
      const point = state.worldPoints[id]
      center.add(new Vector3(point.x, point.y, point.z))
    }
    center.multiplyScalar(1 / palmIds.length)
    const mirror = facing === 'user' ? -1 : 1
    const points = state.worldPoints.map(point => new Vector3(
      (point.x - center.x) * mirror * 8,
      -(point.y - center.y) * 8,
      -(point.z - center.z) * 8,
    ))
    const across = points[17].clone().sub(points[5])
    const along = points[9].clone().sub(points[0])
    const normal = new Vector3().crossVectors(across, along)
    if (normal.lengthSq() < 0.0001) normal.set(0, 0.35, 0.94)
    else normal.normalize()
    if (normal.z < 0) normal.negate()
    return { depth: this.depth, points, normal }
  }
}
