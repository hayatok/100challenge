export const MIN_SELECTION = 0.02

export function formatTime(seconds: number): string {
  const ms = Math.round(Math.max(0, Number.isFinite(seconds) ? seconds : 0) * 1000)
  const minutes = Math.floor(ms / 60000)
  return `${String(minutes).padStart(2, '0')}:${String(Math.floor(ms / 1000) % 60).padStart(2, '0')}.${String(ms % 1000).padStart(3, '0')}`
}

export function parseTime(text: string): number | null {
  const value = text.trim()
  if (/^\d+(?:\.\d{1,3})?$/.test(value)) return Number.isFinite(Number(value)) ? Number(value) : null
  const match = /^(\d+):([0-5]\d)(?:\.(\d{1,3}))?$/.exec(value)
  if (!match) return null
  const seconds = Number(match[1]) * 60 + Number(match[2]) + Number(`0.${match[3] ?? '0'}`)
  return Number.isFinite(seconds) ? seconds : null
}

export function selectionError(start: number | null, end: number | null, duration: number): string | null {
  if (start === null || end === null || !Number.isFinite(start) || !Number.isFinite(end)) {
    return '開始・終了を「00:12.345」または秒数で入力してください。'
  }
  if (start < 0 || end < 0 || start > duration + 0.00051 || end > duration + 0.00051) {
    return '開始・終了は音声の長さの範囲内にしてください。'
  }
  if (end - start < MIN_SELECTION - 1e-9) return '終了を開始より後にし、0.020秒以上選択してください。'
  return null
}

export function rangeToFrames(start: number, end: number, sampleRate: number, length: number) {
  const error = selectionError(start, end, length / sampleRate)
  if (error) throw new Error(error)
  return {
    first: Math.max(0, Math.min(length, Math.round(start * sampleRate))),
    last: Math.max(0, Math.min(length, Math.round(end * sampleRate))),
  }
}

export function makeOutputFileName(fileName: string, start: number, end: number, format: 'mp3' | 'm4a'): string {
  // eslint-disable-next-line no-control-regex -- Remove control characters that cannot be used in downloaded filenames.
  const stem = fileName.replace(/\.[^.]+$/, '').replace(/[<>:"/\\|?*\u0000-\u001f\u007f]/g, '_').trim().slice(0, 100) || 'audio'
  const stamp = (n: number) => formatTime(n).replace(':', '-')
  return `${stem}_${stamp(start)}_${stamp(end)}.${format}`
}
