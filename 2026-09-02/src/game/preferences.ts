export type GardenSpeed = 'slow' | 'normal' | 'fast'

export const speedIntervals: Record<GardenSpeed, number> = {
  slow: 900,
  normal: 450,
  fast: 180,
}

const speeds = new Set<GardenSpeed>(['slow', 'normal', 'fast'])

export function readSpeed(): GardenSpeed {
  try {
    const value = localStorage.getItem('inochi-no-niwa:v1:speed')
    return speeds.has(value as GardenSpeed) ? value as GardenSpeed : 'normal'
  } catch {
    return 'normal'
  }
}

export function saveSpeed(speed: GardenSpeed) {
  try {
    localStorage.setItem('inochi-no-niwa:v1:speed', speed)
    return true
  } catch {
    return false
  }
}

export function readHelpDismissed() {
  try {
    return localStorage.getItem('inochi-no-niwa:v1:help-dismissed') === 'true'
  } catch {
    return false
  }
}

export function saveHelpDismissed(dismissed: boolean) {
  try {
    localStorage.setItem('inochi-no-niwa:v1:help-dismissed', String(dismissed))
    return true
  } catch {
    return false
  }
}
