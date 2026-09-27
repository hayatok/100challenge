export interface ScreenPoint { x: number; y: number }
export interface ScreenTarget extends ScreenPoint { id: number; radius: number }
export interface ScreenImpact {
  id: number
  source: 'palm' | 'finger'
  direction: { x: number; y: number; z: number }
  speed: number
}
export interface ScreenContactState { aimedId: number | null; impact: ScreenImpact | null }

function distanceToSegment(point: ScreenPoint, from: ScreenPoint, to: ScreenPoint): number {
  const dx = to.x - from.x
  const dy = to.y - from.y
  const lengthSquared = dx * dx + dy * dy
  const t = lengthSquared ? Math.max(0, Math.min(1, ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared)) : 0
  return Math.hypot(point.x - from.x - t * dx, point.y - from.y - t * dy)
}

export class ScreenContact {
  private previousPalm: ScreenPoint | null = null
  private previousFinger: ScreenPoint | null = null
  private sampledAt = 0
  private lastImpact = new Map<number, number>()

  reset(): void {
    this.previousPalm = null
    this.previousFinger = null
    this.sampledAt = 0
    this.lastImpact.clear()
  }

  sample(palm: ScreenPoint, finger: ScreenPoint | null, targets: ScreenTarget[], now: number): ScreenContactState {
    const cursors = finger ? [{ point: finger, reach: 11 }, { point: palm, reach: 20 }] : [{ point: palm, reach: 20 }]
    let aimedId: number | null = null
    let closest = Infinity
    for (const cursor of cursors) {
      for (const target of targets) {
        const distance = Math.hypot(target.x - cursor.point.x, target.y - cursor.point.y)
        if (distance < closest && distance <= target.radius + cursor.reach + 7) {
          closest = distance
          aimedId = target.id
        }
      }
    }

    let impact: ScreenImpact | null = null
    const dt = (now - this.sampledAt) / 1000
    if (this.previousPalm && dt >= 0.016 && dt <= 0.18) {
      const motions: { source: ScreenImpact['source']; from: ScreenPoint; to: ScreenPoint; reach: number }[] = []
      if (finger && this.previousFinger) motions.push({ source: 'finger', from: this.previousFinger, to: finger, reach: 11 })
      motions.push({ source: 'palm', from: this.previousPalm, to: palm, reach: 20 })
      for (const motion of motions) {
        const dx = motion.to.x - motion.from.x
        const dy = motion.to.y - motion.from.y
        const distance = Math.hypot(dx, dy)
        if (distance < 5 || distance / dt < 110) continue
        const target = targets
          .filter(item => now - (this.lastImpact.get(item.id) ?? -Infinity) >= 180)
          .map(item => ({ item, miss: distanceToSegment(item, motion.from, motion.to) }))
          .filter(candidate => candidate.miss <= candidate.item.radius + motion.reach)
          .sort((a, b) => a.miss - b.miss)[0]
        if (!target) continue
        impact = {
          id: target.item.id,
          source: motion.source,
          direction: { x: dx / distance, y: -dy / distance, z: 0 },
          speed: Math.min(distance / dt, 1800),
        }
        this.lastImpact.set(impact.id, now)
        aimedId = impact.id
        break
      }
    }
    if (dt >= 0.016 || !this.previousPalm) {
      this.previousPalm = { ...palm }
      this.previousFinger = finger ? { ...finger } : null
      this.sampledAt = now
    }
    return { aimedId, impact }
  }
}
