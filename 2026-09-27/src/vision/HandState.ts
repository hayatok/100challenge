import type { HandLandmarkerResult } from '@mediapipe/tasks-vision'

export interface HandState {
  detected: boolean
  x: number
  y: number
  handedness: string
}

const landmarkIds = [0, 5, 9, 13, 17] // wrist and four knuckles: stable palm center

export function readPalm(result: HandLandmarkerResult): HandState {
  const landmarks = result.landmarks[0]
  if (!landmarks || landmarks.length < 21) return { detected: false, x: 0, y: 0, handedness: '' }
  const x = landmarkIds.reduce((sum, index) => sum + landmarks[index].x, 0) / landmarkIds.length
  const y = landmarkIds.reduce((sum, index) => sum + landmarks[index].y, 0) / landmarkIds.length
  if (!Number.isFinite(x) || !Number.isFinite(y)) return { detected: false, x: 0, y: 0, handedness: '' }
  return {
    detected: true,
    x: Math.max(0, Math.min(1, x)),
    y: Math.max(0, Math.min(1, y)),
    handedness: result.handedness[0]?.[0]?.categoryName ?? '',
  }
}
