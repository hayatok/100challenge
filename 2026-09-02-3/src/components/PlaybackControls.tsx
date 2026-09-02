type Props = {
  phase: number
  total: number
  playing: boolean
  speed: number
  disabled: boolean
  onPhase: (phase: number) => void
  onPlaying: (playing: boolean) => void
  onSpeed: (speed: number) => void
}

export function PlaybackControls({ phase, total, playing, speed, disabled, onPhase, onPlaying, onSpeed }: Props) {
  return (
    <div className="playback" aria-label="計算過程の再生操作">
      <div className="playback__primary">
        <button type="button" onClick={() => onPhase(Math.max(0, phase - 1))} disabled={disabled || phase === 0}>← 戻る</button>
        <button type="button" className="button button--primary" onClick={() => onPlaying(!playing)} disabled={disabled}>
          {playing ? '一時停止' : '再生する'}
        </button>
        <button type="button" onClick={() => onPhase(Math.min(total - 1, phase + 1))} disabled={disabled || phase === total - 1}>進む →</button>
      </div>
      <div className="playback__secondary">
        <button type="button" onClick={() => onPhase(0)} disabled={disabled || phase === 0}>最初</button>
        <button type="button" onClick={() => onPhase(total - 1)} disabled={disabled || phase === total - 1}>最後</button>
        <label>再生速度
          <select value={speed} onChange={(event) => onSpeed(Number(event.target.value))} disabled={disabled}>
            <option value={0.5}>0.5x</option>
            <option value={1}>1x</option>
            <option value={2}>2x</option>
          </select>
        </label>
      </div>
    </div>
  )
}
