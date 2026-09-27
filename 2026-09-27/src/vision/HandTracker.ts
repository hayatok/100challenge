import type { HandLandmarker } from '@mediapipe/tasks-vision'
import { cameraVideoConstraints, type CameraFacing } from './CameraFacing.ts'
import { readPalm, type HandState } from './HandState.ts'

export class HandTracker {
  private detector?: HandLandmarker
  private stream?: MediaStream
  private previousVideoTime = -1
  private previousDetectionAt = 0
  private cameraRequest = 0
  private facingValue: CameraFacing = 'user'
  readonly video = document.createElement('video')

  get facing(): CameraFacing { return this.facingValue }

  private releaseCamera(): void {
    this.video.pause()
    this.video.srcObject = null
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = undefined
    this.previousVideoTime = -1
    this.previousDetectionAt = 0
  }

  private async openCamera(facing: CameraFacing, onStage: (message: string) => void): Promise<void> {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error('Camera API is unavailable. Use HTTPS or localhost.')
    const requestId = ++this.cameraRequest
    onStage(facing === 'environment' ? 'Waiting for rear camera…' : 'Waiting for front camera…')
    const request = navigator.mediaDevices.getUserMedia({ audio: false, video: cameraVideoConstraints(facing) })
    let timer: ReturnType<typeof setTimeout> | undefined
    let expired = false
    let stream: MediaStream
    try {
      stream = await Promise.race([
        request,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => { expired = true; reject(new Error('Camera did not respond. Try Mouse Mode.')) }, 20_000)
        }),
      ])
    } finally {
      if (timer) clearTimeout(timer)
      if (expired) void request.then(lateStream => lateStream.getTracks().forEach(track => track.stop())).catch(() => {})
    }
    if (requestId !== this.cameraRequest) {
      stream.getTracks().forEach(track => track.stop())
      throw new DOMException('Camera request superseded', 'AbortError')
    }
    const actual = stream.getVideoTracks()[0]?.getSettings().facingMode
    if (facing === 'environment' && actual && actual !== 'environment') {
      stream.getTracks().forEach(track => track.stop())
      throw new Error('Rear camera is unavailable on this device.')
    }
    this.video.srcObject = stream
    this.video.muted = true
    this.video.playsInline = true
    try {
      await this.video.play()
    } catch (error) {
      stream.getTracks().forEach(track => track.stop())
      this.video.srcObject = null
      throw error
    }
    if (requestId !== this.cameraRequest) {
      stream.getTracks().forEach(track => track.stop())
      this.video.srcObject = null
      throw new DOMException('Camera request superseded', 'AbortError')
    }
    this.stream = stream
    this.facingValue = actual === 'environment' ? 'environment' : facing
  }

  async start(onStage: (message: string) => void, facing: CameraFacing = 'user'): Promise<void> {
    await this.openCamera(facing, onStage)
    const requestId = this.cameraRequest
    try {
      onStage('Loading vision model…')
      const { FilesetResolver, HandLandmarker } = await import('@mediapipe/tasks-vision')
      const root = `${import.meta.env.BASE_URL}vision`
      const vision = await FilesetResolver.forVisionTasks(`${root}/wasm`)
      const detector = await HandLandmarker.createFromOptions(vision, {
        baseOptions: { modelAssetPath: `${root}/hand_landmarker.task`, delegate: 'CPU' },
        runningMode: 'VIDEO',
        numHands: 1,
      })
      if (requestId !== this.cameraRequest) {
        detector.close()
        throw new DOMException('Camera request superseded', 'AbortError')
      }
      this.detector = detector
    } catch (error) {
      this.stop()
      throw error
    }
  }

  async switchFacing(facing: CameraFacing, onStage: (message: string) => void): Promise<boolean> {
    if (facing === this.facingValue) return true
    const previous = this.facingValue
    this.releaseCamera()
    try {
      await this.openCamera(facing, onStage)
      return true
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') throw error
      try {
        await this.openCamera(previous, onStage)
        return false
      } catch {
        this.stop()
        throw error
      }
    }
  }

  update(now: number): HandState | undefined {
    if (!this.detector || this.video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return
    if (now - this.previousDetectionAt < 32 || this.video.currentTime === this.previousVideoTime) return
    this.previousDetectionAt = now
    this.previousVideoTime = this.video.currentTime
    return readPalm(this.detector.detectForVideo(this.video, now), this.video.videoWidth / this.video.videoHeight)
  }

  stop(): void {
    this.cameraRequest++
    this.detector?.close()
    this.detector = undefined
    this.releaseCamera()
  }
}
