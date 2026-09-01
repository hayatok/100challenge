import type { GardenPhase } from '../game/machine'

type GardenStatusProps = {
  generation: number
  aliveCount: number
  phase: GardenPhase
}

export default function GardenStatus({ generation, aliveCount, phase }: GardenStatusProps) {
  return (
    <div className="instrument-strip" aria-label="庭の観測値">
      <div className="instrument-reading">
        <span>観測世代</span>
        <strong>{String(generation).padStart(6, '0')}</strong>
      </div>
      <div className="instrument-reading">
        <span>現在の命</span>
        <strong>{String(aliveCount).padStart(4, '0')}</strong>
      </div>
      <div className="impact-reading">
        <span className={`phase-lamp phase-${phase}`} aria-hidden="true" />
        宇宙への影響：ほぼなし
      </div>
    </div>
  )
}
