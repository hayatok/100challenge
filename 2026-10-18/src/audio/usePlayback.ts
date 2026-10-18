import { useCallback, useEffect, useRef, useState } from 'react'

export function usePlayback(buffer: AudioBuffer | null, selection: { start: number; end: number }, loop: boolean) {
  const [playing, setPlaying] = useState(false)
  const [position, setPosition] = useState(selection.start)
  const [error, setError] = useState<string | null>(null)
  const contextRef = useRef<AudioContext | null>(null)
  const sourceRef = useRef<AudioBufferSourceNode | null>(null)
  const frameRef = useRef(0)
  const generation = useRef(0)

  const stop = useCallback(() => {
    generation.current++
    cancelAnimationFrame(frameRef.current)
    const source = sourceRef.current
    sourceRef.current = null
    if (source) { source.onended = null; source.stop(); source.disconnect() }
    setPlaying(false)
  }, [])

  useEffect(() => {
    stop()
    setPosition(selection.start)
  }, [buffer, selection.start, selection.end, loop, stop])

  useEffect(() => () => {
    stop()
    const context = contextRef.current
    contextRef.current = null
    if (context && context.state !== 'closed') void context.close()
  }, [buffer, stop])

  useEffect(() => {
    const hidden = () => { if (document.hidden) stop() }
    document.addEventListener('visibilitychange', hidden)
    return () => document.removeEventListener('visibilitychange', hidden)
  }, [stop])

  const toggle = useCallback(async () => {
    if (sourceRef.current) { stop(); return }
    if (!buffer || !(selection.end > selection.start)) return
    const token = ++generation.current
    try {
      setError(null)
      const context = contextRef.current ?? new AudioContext()
      contextRef.current = context
      await context.resume()
      if (token !== generation.current) return
      const source = context.createBufferSource()
      source.buffer = buffer
      source.loop = loop
      source.loopStart = selection.start
      source.loopEnd = selection.end
      source.connect(context.destination)
      sourceRef.current = source
      const began = context.currentTime
      const length = selection.end - selection.start
      const tick = () => {
        if (sourceRef.current !== source) return
        const elapsed = context.currentTime - began
        setPosition(selection.start + (loop ? elapsed % length : Math.min(elapsed, length)))
        frameRef.current = requestAnimationFrame(tick)
      }
      source.onended = () => {
        if (sourceRef.current !== source) return
        sourceRef.current = null
        source.disconnect()
        cancelAnimationFrame(frameRef.current)
        setPlaying(false)
        setPosition(selection.end)
      }
      if (loop) source.start(0, selection.start)
      else source.start(0, selection.start, length)
      setPosition(selection.start)
      setPlaying(true)
      tick()
    } catch {
      if (token === generation.current) setError('試聴を開始できませんでした。もう一度再生ボタンを押してください。')
      stop()
    }
  }, [buffer, selection.start, selection.end, loop, stop])

  return { playing, position, error, toggle, stop }
}
