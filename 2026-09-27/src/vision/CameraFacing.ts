export type CameraFacing = 'user' | 'environment'

export function cameraVideoConstraints(facing: CameraFacing): MediaTrackConstraints {
  return {
    facingMode: facing === 'environment' ? { exact: 'environment' } : { ideal: 'user' },
    width: { ideal: 640 },
    height: { ideal: 480 },
    frameRate: { ideal: 30, max: 30 },
  }
}

export function imageXToScreen(x: number, facing: CameraFacing): number {
  return facing === 'user' ? 1 - x : x
}
