export type TickDecision = {
  shouldTick: boolean
  nextBaseline: number
}

export function decideTick(baseline: number, now: number, interval: number): TickDecision {
  if (now - baseline < interval) return { shouldTick: false, nextBaseline: baseline }
  return { shouldTick: true, nextBaseline: now }
}
