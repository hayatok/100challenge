/** Deterministic audible fixture: 0–2s A4, 2–4s A5, 4–8s A6; right = 1.5× left. */
export function toneWav(seconds = 8, channels = 2, sampleRate = 44100): Buffer {
  const length = Math.round(seconds * sampleRate)
  const buffer = Buffer.alloc(44 + length * channels * 2)
  buffer.write('RIFF'); buffer.writeUInt32LE(buffer.length - 8, 4); buffer.write('WAVEfmt ', 8)
  buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(channels, 22)
  buffer.writeUInt32LE(sampleRate, 24); buffer.writeUInt32LE(sampleRate * channels * 2, 28)
  buffer.writeUInt16LE(channels * 2, 32); buffer.writeUInt16LE(16, 34); buffer.write('data', 36)
  buffer.writeUInt32LE(length * channels * 2, 40)
  for (let i = 0; i < length; i++) {
    const t = i / sampleRate
    const f = t < 2 ? 440 : t < 4 ? 880 : 1760
    for (let c = 0; c < channels; c++) buffer.writeInt16LE(Math.round(Math.sin(2 * Math.PI * f * (c ? 1.5 : 1) * t) * 14000), 44 + (i * channels + c) * 2)
  }
  return buffer
}
