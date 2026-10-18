/** Max amplitude across all channels preserves brief peaks and antiphase stereo. */
export function buildPeaks(channels: Float32Array[], bins: number): Float32Array {
  const count = Math.max(1, Math.min(32768, Math.floor(bins) || 1))
  const peaks = new Float32Array(count)
  const length = channels[0]?.length ?? 0
  if (!length) return peaks
  for (let b = 0; b < count; b++) {
    const first = Math.floor(b * length / count)
    const last = Math.max(first + 1, Math.floor((b + 1) * length / count))
    let max = 0
    for (const channel of channels) {
      for (let f = first; f < Math.min(last, channel.length); f++) {
        const value = Math.abs(channel[f])
        if (Number.isFinite(value) && value > max) max = value
      }
    }
    peaks[b] = Math.min(1, max)
  }
  return peaks
}
