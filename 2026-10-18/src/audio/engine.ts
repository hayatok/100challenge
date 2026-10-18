import { ALL_FORMATS, AudioBufferSource, BlobSource, BufferTarget, Input, Mp3OutputFormat, Mp4OutputFormat, Output, Quality } from 'mediabunny'
import { registerMp3Encoder } from '@mediabunny/mp3-encoder'
import { registerAacEncoder } from '@mediabunny/aac-encoder'
import { rangeToFrames } from './time'

export type ExportFormat = 'mp3' | 'm4a'
export type AudioAsset = {
  fileName: string
  fileSize: number
  buffer: AudioBuffer
  duration: number
  sampleRate: number
  channels: number
}
export const MAX_FILE_BYTES = 64 * 1024 * 1024
export const MAX_DURATION = 600
const SAMPLE_RATE = 48000
let registered = false
let preparation: Promise<void> | null = null

function checkAbort(signal?: AbortSignal) {
  if (signal?.aborted) throw new DOMException('キャンセルしました。', 'AbortError')
}

function registerEncoders() {
  if (registered) return
  registerMp3Encoder()
  registerAacEncoder()
  registered = true
}

/** Warm both real encoders before showing ready; all WASM is embedded in the imported bundles. */
export function prepareEncoders(): Promise<void> {
  if (!preparation) {
    preparation = (async () => {
      registerEncoders()
      const buffer = new AudioBuffer({ length: 4800, numberOfChannels: 1, sampleRate: SAMPLE_RATE })
      for (const format of ['mp3', 'm4a'] as const) {
        await exportClip(buffer, { start: 0, end: 0.1, format, bitrate: 192, signal: new AbortController().signal, onProgress: () => {} })
      }
    })().catch(error => {
      preparation = null
      throw error
    })
  }
  return preparation
}

/** Check duration before decoding a compressed file to avoid unbounded PCM allocations. */
function readDuration(file: File, signal?: AbortSignal): Promise<number> {
  return new Promise((resolve, reject) => {
    checkAbort(signal)
    const element = document.createElement('audio')
    const url = URL.createObjectURL(file)
    const finish = (duration?: number, error?: Error) => {
      clearTimeout(timeout)
      signal?.removeEventListener('abort', abort)
      element.onloadedmetadata = null
      element.onerror = null
      element.removeAttribute('src')
      element.load()
      URL.revokeObjectURL(url)
      if (error) reject(error)
      else resolve(duration!)
    }
    const abort = () => finish(undefined, new DOMException('キャンセルしました。', 'AbortError'))
    const timeout = setTimeout(() => finish(undefined, new Error('音声の長さを確認できませんでした。MP3・M4A・WAVなど、別の音声ファイルを選んでください。')), 15000)
    element.onloadedmetadata = () => {
      const duration = element.duration
      if (!Number.isFinite(duration) || duration <= 0) finish(undefined, new Error('音声の長さを読み取れません。別の音声ファイルを選んでください。'))
      else finish(duration)
    }
    element.onerror = () => finish(undefined, new Error('この音声を読み込めません。形式が未対応か、ファイルが壊れている可能性があります。'))
    signal?.addEventListener('abort', abort, { once: true })
    element.preload = 'metadata'
    element.src = url
  })
}

export async function loadAudioFile(file: File, signal?: AbortSignal): Promise<AudioAsset> {
  checkAbort(signal)
  if (!file.size) throw new Error('空のファイルです。音声が入ったファイルを選んでください。')
  if (file.size > MAX_FILE_BYTES) throw new Error('64MBを超えています。64MB以下の音声ファイルを選んでください。')
  const duration = await readDuration(file, signal)
  checkAbort(signal)
  if (duration > MAX_DURATION) throw new Error('10分を超えています。10分以下の音声ファイルを選んでください。')
  // Inspect channel count before allocating the full decoded PCM (e.g. a 5.1 recording).
  const input = new Input({ source: new BlobSource(file), formats: ALL_FORMATS })
  try {
    const track = await input.getPrimaryAudioTrack()
    if (!track) throw new Error('音声トラックが見つかりませんでした。別の音声ファイルを選んでください。')
    const channels = await track.getNumberOfChannels()
    if (channels < 1 || channels > 2) throw new Error('モノラルまたはステレオの音声を選んでください。')
  } catch (error) {
    if (error instanceof Error && /モノラル|音声トラック/.test(error.message)) throw error
    throw new Error('この形式を確認できませんでした。MP3・M4A・WAVなど、別の音声ファイルを選んでください。')
  } finally {
    input.dispose()
  }
  checkAbort(signal)
  let buffer: AudioBuffer
  try {
    const context = new OfflineAudioContext(2, 1, SAMPLE_RATE)
    buffer = await context.decodeAudioData(await file.arrayBuffer())
  } catch {
    checkAbort(signal)
    throw new Error('音声を読み取れませんでした。このブラウザが対応するMP3・M4A・WAVなどを選んでください。')
  }
  checkAbort(signal)
  if (buffer.duration > MAX_DURATION + 0.1) throw new Error('10分を超える音声は読み込めません。')
  if (buffer.numberOfChannels < 1 || buffer.numberOfChannels > 2) throw new Error('モノラルまたはステレオの音声を選んでください。')
  if (buffer.length < SAMPLE_RATE * 0.02) throw new Error('0.020秒以上の音声を選んでください。')
  return { fileName: file.name, fileSize: file.size, buffer, duration: buffer.duration, sampleRate: buffer.sampleRate, channels: buffer.numberOfChannels }
}

export async function exportClip(buffer: AudioBuffer, options: {
  start: number
  end: number
  format: ExportFormat
  bitrate: number
  signal: AbortSignal
  onProgress: (progress: number) => void
}): Promise<Blob> {
  registerEncoders()
  checkAbort(options.signal)
  const { first, last } = rangeToFrames(options.start, options.end, buffer.sampleRate, buffer.length)
  if (buffer.numberOfChannels > 2 || ![128, 192, 256].includes(options.bitrate)) throw new Error('書き出し設定を確認してください。')
  const target = new BufferTarget()
  const output = new Output({ format: options.format === 'mp3' ? new Mp3OutputFormat() : new Mp4OutputFormat(), target })
  const source = new AudioBufferSource({ codec: options.format === 'mp3' ? 'mp3' : 'aac', quality: new Quality({ bitrate: options.bitrate * 1000 }) })
  output.addAudioTrack(source)
  let cancelling: Promise<void> | null = null
  const cancel = () => { cancelling ??= output.cancel().catch(() => {}) }
  options.signal.addEventListener('abort', cancel, { once: true })
  try {
    await output.start()
    checkAbort(options.signal)
    options.onProgress(0)
    // Feed one second at a time to bound extra PCM memory and report actual processed frames.
    for (let frame = first; frame < last; frame += buffer.sampleRate) {
      checkAbort(options.signal)
      const length = Math.min(buffer.sampleRate, last - frame)
      const chunk = new AudioBuffer({ length, numberOfChannels: buffer.numberOfChannels, sampleRate: buffer.sampleRate })
      for (let c = 0; c < buffer.numberOfChannels; c++) chunk.copyToChannel(buffer.getChannelData(c).subarray(frame, frame + length), c)
      await source.add(chunk)
      checkAbort(options.signal)
      options.onProgress(Math.min(0.98, (frame + length - first) / (last - first) * 0.98))
      // Yield so cancel and UI updates remain responsive even for short, fast encodes.
      await new Promise(resolve => setTimeout(resolve, 0))
    }
    source.close()
    await output.finalize()
    checkAbort(options.signal)
    if (!target.buffer?.byteLength) throw new Error('音声を書き出せませんでした。もう一度試してください。')
    options.onProgress(1)
    return new Blob([target.buffer], { type: options.format === 'mp3' ? 'audio/mpeg' : 'audio/mp4' })
  } catch (error) {
    cancel()
    await cancelling
    checkAbort(options.signal)
    throw error
  } finally {
    options.signal.removeEventListener('abort', cancel)
  }
}

/** Explicitly synthetic demo, decoded through exactly the same file path as user audio. */
export function createDemoFile(): File {
  const duration = 8
  const sampleRate = 44100
  const length = sampleRate * duration
  const array = new ArrayBuffer(44 + length * 2)
  const view = new DataView(array)
  const ascii = (offset: number, text: string) => { for (let i = 0; i < text.length; i++) view.setUint8(offset + i, text.charCodeAt(i)) }
  ascii(0, 'RIFF'); view.setUint32(4, array.byteLength - 8, true); ascii(8, 'WAVEfmt ')
  view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true)
  view.setUint32(24, sampleRate, true); view.setUint32(28, sampleRate * 2, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true)
  ascii(36, 'data'); view.setUint32(40, length * 2, true)
  for (let i = 0; i < length; i++) {
    const t = i / sampleRate
    const beat = t % 0.5
    const envelope = Math.min(1, beat * 100) * Math.exp(-beat * 7)
    const freq = [262, 330, 392, 523][Math.floor(t) % 4]
    const value = 0.5 * Math.sin(2 * Math.PI * freq * t) * envelope
    view.setInt16(44 + i * 2, Math.round(value * 32767), true)
  }
  return new File([array], 'サンプル音声（生成した8秒の音）.wav', { type: 'audio/wav' })
}
