import type { HandLandmarkerResult } from '@mediapipe/tasks-vision'

export interface HandState {
  detected: boolean
  x: number
  y: number
  handedness: string
  indexTip: { x: number; y: number } | null
  palmSpan: number
  worldPoints: { x: number; y: number; z: number }[] | null
}

const landmarkIds = [0, 5, 9, 13, 17] // wrist and four knuckles: stable palm center

export function readPalm(result: HandLandmarkerResult, aspect = 1): HandState {
  const landmarks = result.landmarks[0]
  const empty = (): HandState => ({ detected: false, x: 0, y: 0, handedness: '', indexTip: null, palmSpan: 0, worldPoints: null })
  if (!landmarks || landmarks.length < 21) return empty()
  const x = landmarkIds.reduce((sum, index) => sum + landmarks[index].x, 0) / landmarkIds.length
  const y = landmarkIds.reduce((sum, index) => sum + landmarks[index].y, 0) / landmarkIds.length
  if (!Number.isFinite(x) || !Number.isFinite(y)) return empty()
  const cameraAspect = Number.isFinite(aspect) && aspect > 0 ? aspect : 1
  const width = Math.hypot((landmarks[5].x - landmarks[17].x) * cameraAspect, landmarks[5].y - landmarks[17].y)
  const height = Math.hypot((landmarks[0].x - landmarks[9].x) * cameraAspect, landmarks[0].y - landmarks[9].y)
  // The larger palm axis is less sensitive to a single foreshortened axis during rotation.
  const palmSpan = Math.max(width, height * 0.85)
  if (!Number.isFinite(palmSpan) || palmSpan < 0.012) return empty()
  const world = result.worldLandmarks?.[0]
  const worldPoints = world?.length === 21 && world.every(point =>
    Number.isFinite(point.x) && Number.isFinite(point.y) && Number.isFinite(point.z))
    ? world.map(point => ({ x: point.x, y: point.y, z: point.z })) : null
  const wrist = landmarks[0]
  const pip = landmarks[6]
  const tip = landmarks[8]
  const wristTo = (point: { x: number; y: number }) => Math.hypot(point.x - wrist.x, point.y - wrist.y)
  const extended = Number.isFinite(tip.x) && Number.isFinite(tip.y) && wristTo(tip) > wristTo(pip) * 1.15
  return {
    detected: true,
    x: Math.max(0, Math.min(1, x)),
    y: Math.max(0, Math.min(1, y)),
    handedness: result.handedness[0]?.[0]?.categoryName ?? '',
    indexTip: extended ? { x: Math.max(0, Math.min(1, tip.x)), y: Math.max(0, Math.min(1, tip.y)) } : null,
    palmSpan,
    worldPoints,
  }
}
