import type { HandLandmarker } from '@mediapipe/tasks-vision'
import { readPalm, type HandState } from './HandState'

export class HandTracker {
  private detector?: HandLandmarker
  private stream?: MediaStream
  private previousVideoTime = -1
  private previousDetectionAt = 0
  readonly video = document.createElement('video')

  async start(onStage: (message: string) => void): Promise<void> {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error('Camera API is unavailable. Use a recent browser on HTTPS or localhost.')
    onStage('Waiting for camera permission…')
    const request = navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 } },
    })
    let timer: ReturnType<typeof setTimeout> | undefined
    let expired = false
    try {
      this.stream = await Promise.race([
        request,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => { expired = true; reject(new Error('Camera did not respond. Try Mouse Mode.')) }, 12_000)
        }),
      ])
    } finally {
      if (timer) clearTimeout(timer)
      if (expired) void request.then(stream => stream.getTracks().forEach(track => track.stop())).catch(() => {})
    }
    this.video.srcObject = this.stream
    this.video.muted = true
    this.video.playsInline = true
    await this.video.play()

    try {
      onStage('Loading vision model…')
      const { FilesetResolver, HandLandmarker } = await import('@mediapipe/tasks-vision')
      const root = `${import.meta.env.BASE_URL}vision`
      const vision = await FilesetResolver.forVisionTasks(`${root}/wasm`)
      this.detector = await HandLandmarker.createFromOptions(vision, {
        baseOptions: { modelAssetPath: `${root}/hand_landmarker.task`, delegate: 'CPU' },
        runningMode: 'VIDEO',
        numHands: 1,
      })
    } catch (error) {
      this.stop()
      throw error
    }
  }

  update(now: number): HandState | undefined {
    if (!this.detector || this.video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return
    if (now - this.previousDetectionAt < 32 || this.video.currentTime === this.previousVideoTime) return
    this.previousDetectionAt = now
    this.previousVideoTime = this.video.currentTime
    return readPalm(this.detector.detectForVideo(this.video, now))
  }

  stop(): void {
    this.detector?.close()
    this.detector = undefined
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = undefined
    this.video.srcObject = null
  }
}
