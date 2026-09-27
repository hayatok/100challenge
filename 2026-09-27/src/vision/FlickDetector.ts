export interface Point3 { x: number; y: number; z: number }
export interface Flick {
  source: 'palm' | 'finger'
  origin: Point3
  direction: Point3
  speed: number
}

const blend = (a: Point3, b: Point3): Point3 => ({
  x: a.x + (b.x - a.x) * 0.55,
  y: a.y + (b.y - a.y) * 0.55,
  z: a.z + (b.z - a.z) * 0.55,
})
const subtract = (a: Point3, b: Point3): Point3 => ({ x: a.x - b.x, y: a.y - b.y, z: a.z - b.z })
const length = (point: Point3): number => Math.hypot(point.x, point.y, point.z)

export class FlickDetector {
  private palm: Point3 | null = null
  private finger: Point3 | null = null
  private sampledAt = 0
  private lastFlickAt = -Infinity

  reset(): void {
    this.palm = null
    this.finger = null
    this.sampledAt = 0
    this.lastFlickAt = -Infinity
  }

  sample(palm: Point3, finger: Point3 | null, now: number): Flick | null {
    if (!Number.isFinite(palm.x) || !Number.isFinite(palm.y) || !Number.isFinite(now)) return null
    if (!this.palm || now - this.sampledAt > 180) {
      this.palm = { ...palm }
      this.finger = finger ? { ...finger } : null
      this.sampledAt = now
      return null
    }
    const elapsed = now - this.sampledAt
    if (elapsed < 16) return null
    const dt = elapsed / 1000
    const nextPalm = blend(this.palm, palm)
    const palmDelta = subtract(nextPalm, this.palm)
    const nextFinger = finger && this.finger ? blend(this.finger, finger) : finger ? { ...finger } : null
    const fingerDelta = nextFinger && this.finger ? subtract(nextFinger, this.finger) : null
    this.palm = nextPalm
    this.finger = nextFinger
    this.sampledAt = now

    if (now - this.lastFlickAt < 210) return null
    let source: Flick['source'] = 'palm'
    let origin = nextPalm
    let delta = palmDelta
    if (nextFinger && fingerDelta) {
      const relative = subtract(fingerDelta, palmDelta)
      if (length(relative) / dt > 3.2 && length(fingerDelta) / dt > 5.2 && length(fingerDelta) > 0.14) {
        source = 'finger'
        origin = nextFinger
        delta = fingerDelta
      }
    }
    const speed = length(delta) / dt
    if (source === 'palm' && (speed < 6 || length(delta) < 0.18)) return null
    const distance = length(delta)
    if (distance < 0.001) return null
    this.lastFlickAt = now
    return {
      source,
      origin: { ...origin },
      direction: { x: delta.x / distance, y: delta.y / distance, z: delta.z / distance },
      speed: Math.min(speed, 24),
    }
  }
}
