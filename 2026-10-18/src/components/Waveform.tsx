import { useMemo, useRef, useState, type KeyboardEvent, type PointerEvent } from 'react';
import { buildPeaks } from '../audio/waveform';
import { formatTime } from '../audio/time';

type Range = { start: number; end: number };
type Props = {
  buffer: AudioBuffer;
  selection: Range;
  position: number;
  disabled: boolean;
  onChange: (range: Range) => void;
};
const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

export function Waveform({ buffer, selection, position, disabled, onChange }: Props) {
  const [zoom, setZoom] = useState(1);
  const track = useRef<HTMLDivElement>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const drag = useRef<{ mode: 'start' | 'end' | 'new'; origin: number; pointer: number } | null>(null);
  const duration = buffer.duration;
  const peaks = useMemo(() => buildPeaks(
    Array.from({ length: buffer.numberOfChannels }, (_, index) => buffer.getChannelData(index)),
    Math.min(24000, Math.max(1600, Math.ceil(buffer.duration * 40))),
  ), [buffer]);
  const path = useMemo(() => Array.from(peaks, (peak, index) => {
    const x = (index / Math.max(1, peaks.length - 1)) * 1000;
    const height = Math.max(0.35, peak * 69);
    return `M${x.toFixed(3)} ${(80 - height).toFixed(2)}V${(80 + height).toFixed(2)}`;
  }).join(''), [peaks]);

  function timeAt(event: PointerEvent) {
    const rect = track.current!.getBoundingClientRect();
    return clamp(((event.clientX - rect.left) / rect.width) * duration, 0, duration);
  }
  function pointerDown(event: PointerEvent<HTMLDivElement>) {
    if (disabled || event.button !== 0) return;
    const handle = (event.target as HTMLElement).closest<HTMLElement>('[data-handle]');
    const mode = handle?.dataset.handle as 'start' | 'end' | undefined;
    drag.current = { mode: mode || 'new', origin: timeAt(event), pointer: event.pointerId };
    event.currentTarget.setPointerCapture(event.pointerId);
    event.preventDefault();
    if (handle) handle.focus();
  }
  function pointerMove(event: PointerEvent<HTMLDivElement>) {
    const current = drag.current;
    if (!current || current.pointer !== event.pointerId || disabled) return;
    const time = timeAt(event);
    if (current.mode === 'start') onChange({ start: clamp(time, 0, selection.end - 0.02), end: selection.end });
    else if (current.mode === 'end') onChange({ start: selection.start, end: clamp(time, selection.start + 0.02, duration) });
    else {
      const start = Math.min(time, current.origin);
      const end = Math.max(time, current.origin);
      if (end - start >= 0.02) onChange({ start, end });
    }
  }
  function handleKey(event: KeyboardEvent<HTMLButtonElement>, which: 'start' | 'end') {
    if (disabled) return;
    const direction = ['ArrowLeft', 'ArrowDown'].includes(event.key) ? -1 : ['ArrowRight', 'ArrowUp'].includes(event.key) ? 1 : 0;
    if (!direction && event.key !== 'Home' && event.key !== 'End') return;
    event.preventDefault();
    const step = event.shiftKey ? 1 : event.altKey ? 0.001 : 0.01;
    let time = selection[which] + direction * step;
    if (event.key === 'Home') time = which === 'start' ? 0 : selection.start + 0.02;
    if (event.key === 'End') time = which === 'start' ? selection.end - 0.02 : duration;
    const next = which === 'start'
      ? { start: clamp(time, 0, selection.end - 0.02), end: selection.end }
      : { start: selection.start, end: clamp(time, selection.start + 0.02, duration) };
    onChange(next);
  }
  const percent = (time: number) => `${time / duration * 100}%`;
  return <div className="waveform-block">
    <div className="wave-toolbar">
      <p id="wave-instructions" className="hint">波形をドラッグして選択。両端のつまみで調整できます。</p>
      <div className="zoom-controls" aria-label="波形の拡大">
        <button type="button" disabled={disabled || zoom === 1} onClick={() => setZoom(value => Math.max(1, value / 2))} aria-label="波形を縮小">−</button>
        <span className="mono" aria-live="polite">{zoom}×</span>
        <button type="button" disabled={disabled || zoom === 16} onClick={() => setZoom(value => Math.min(16, value * 2))} aria-label="波形を拡大">＋</button>
        <button type="button" className="small-button" disabled={disabled} onClick={() => { setZoom(1); scroller.current?.scrollTo({ left: 0 }); }}>全体表示</button>
      </div>
    </div>
    <div ref={scroller} className="wave-scroll" aria-label="音声波形。拡大時は横にスクロールできます" tabIndex={0}>
      <div className="wave-content" style={{ width: `${zoom * 100}%` }}>
        <div ref={track} className={`wave-track${disabled ? ' is-disabled' : ''}`} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }}>
          <div className="wave-selection" style={{ left: percent(selection.start), width: percent(selection.end - selection.start) }} />
          <svg viewBox="0 0 1000 160" preserveAspectRatio="none" className="wave-svg" role="img" aria-label="読み込んだ音声の振幅波形">
            <path d="M0 80H1000" className="wave-center" />
            <path d={path} className="wave-peaks" />
          </svg>
          <div className="playhead" style={{ left: percent(position) }} aria-hidden="true" />
          {(['start', 'end'] as const).map(which => <button
            key={which} type="button" className={`wave-handle wave-handle-${which}`} data-handle={which}
            style={{ left: percent(selection[which]) }} disabled={disabled}
            role="slider" aria-label={which === 'start' ? '選択開始' : '選択終了'}
            aria-valuemin={which === 'start' ? 0 : selection.start + 0.02}
            aria-valuemax={which === 'end' ? duration : selection.end - 0.02}
            aria-valuenow={selection[which]} aria-valuetext={formatTime(selection[which])}
            aria-describedby="wave-instructions handle-instructions" onKeyDown={event => handleKey(event, which)}
          ><span>{which === 'start' ? '始' : '終'}</span></button>)}
        </div>
        <div className="wave-axis" aria-hidden="true">{Array.from({ length: 5 }, (_, index) => <span key={index}>{formatTime(duration * index / 4)}</span>)}</div>
      </div>
    </div>
    <p className="hint keyboard-hint" id="handle-instructions">つまみにフォーカスして ← →：0.01秒 ／ Shift：1秒 ／ Alt：0.001秒。拡大後は横スクロール。</p>
  </div>;
}
