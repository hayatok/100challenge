export type GardenPhase = 'running' | 'paused' | 'reseeding' | 'empty'
export type StepOrigin = 'automatic' | 'manual'

export function phaseAfterStep(origin: StepOrigin, aliveCount: number): GardenPhase {
  if (aliveCount > 0) return origin === 'automatic' ? 'running' : 'paused'
  return origin === 'automatic' ? 'reseeding' : 'empty'
}

export function canPlay(phase: GardenPhase) {
  return phase === 'running' || phase === 'paused'
}

export function canStep(phase: GardenPhase) {
  return phase === 'paused'
}

export function canClear(phase: GardenPhase) {
  return phase === 'running' || phase === 'paused'
}
