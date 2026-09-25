import type { Project, Scene } from '../domain/project'
export interface TimedScene { scene: Scene; index: number; start: number; end: number; duration: number; incoming: number; outgoing: number }
export interface Timeline { scenes: TimedScene[]; total: number; frames: number }
export function compile(p: Project): Timeline {
  let start = 0
  const scenes = p.scenes.map((scene, index) => {
    const duration = scene.durationTicks / 480 * 60 / p.bpm
    const outgoing = scene.outgoing.durationTicks / 480 * 60 / p.bpm
    const incoming = (p.scenes[index - 1]?.outgoing.durationTicks ?? 0) / 480 * 60 / p.bpm
    const item = { scene, index, start, end: start + duration, duration, incoming, outgoing }
    start += duration - outgoing
    return item
  })
  return { scenes, total: start, frames: Math.ceil(start * 30) }
}
export function sceneAt(tl: Timeline, time: number): TimedScene {
  return [...tl.scenes].reverse().find(s => time >= s.start) ?? tl.scenes[0]
}
