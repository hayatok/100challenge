import type { GardenPhase } from '../game/machine'
import type { GardenSpeed } from '../game/preferences'

type GardenControlsProps = {
  phase: GardenPhase
  speed: GardenSpeed
  onTogglePlay: () => void
  onStep: () => void
  onSpeedChange: (speed: GardenSpeed) => void
  onNewGarden: () => void
  onClear: () => void
  onToggleHelp: () => void
}

const speedOptions: Array<{ value: GardenSpeed; long: string; short: string }> = [
  { value: 'slow', long: 'じっくり見守る', short: 'じっくり' },
  { value: 'normal', long: 'ふつうに見守る', short: 'ふつう' },
  { value: 'fast', long: 'せっかちに見守る', short: 'せっかち' },
]

export default function GardenControls({
  phase,
  speed,
  onTogglePlay,
  onStep,
  onSpeedChange,
  onNewGarden,
  onClear,
  onToggleHelp,
}: GardenControlsProps) {
  const playDisabled = phase === 'empty' || phase === 'reseeding'
  const stepDisabled = phase !== 'paused'
  const clearDisabled = phase === 'empty' || phase === 'reseeding'

  return (
    <div className="control-deck" aria-label="生命観測装置の操作">
      <button className="primary-control" type="button" disabled={playDisabled} onClick={onTogglePlay}>
        <span className="control-light" aria-hidden="true" />
        {phase === 'running' ? '時を止める' : '観測を再開'}
      </button>

      <fieldset className="speed-control">
        <legend>見守る速度</legend>
        <div className="speed-options">
          {speedOptions.map((option) => (
            <button
              key={option.value}
              type="button"
              className={speed === option.value ? 'selected' : ''}
              aria-pressed={speed === option.value}
              aria-label={`見守る速度：${option.short}`}
              onClick={() => onSpeedChange(option.value)}
            >
              <span className="speed-long">{option.long}</span>
              <span className="speed-short">{option.short}</span>
            </button>
          ))}
        </div>
      </fieldset>

      <div className="secondary-controls">
        <button type="button" disabled={stepDisabled} onClick={onStep}>生命を1回だけ進める</button>
        <button type="button" className="new-garden" onClick={onNewGarden}>
          <span>別の宇宙にする</span>
          <small>新しい庭</small>
        </button>
        <button type="button" disabled={clearDisabled} onClick={onClear}>庭を空にする</button>
        <button type="button" onClick={onToggleHelp}>庭のルール</button>
      </div>
    </div>
  )
}
