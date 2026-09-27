import { cloneProject, makeCelestial, parseProject, graphemes, type Project, type Scene } from '../domain/project'
export type Recipe = 'celestial' | 'manifesto' | 'rhythm'
const kinds = { celestial: ['impact-type','particle-flight','radial-pulse','slice-orbit','three-up','particle-lockup'], manifesto: ['impact-type','slice-orbit','particle-flight','radial-pulse','three-up','particle-lockup'], rhythm: ['impact-type','three-up','radial-pulse','particle-flight','slice-orbit','particle-lockup'] } as const
function motion(kind: string, recipe: Recipe): Scene['motion'] {
  const base = { intensity: .72, motif: recipe === 'celestial' ? 'celestial' as const : 'geometric' as const }
  switch (kind) {
    case 'impact-type': return { ...base, kind, direction: 'up', anticipateNext: true }
    case 'particle-flight': return { ...base, kind, depth: .75 }
    case 'radial-pulse': return { ...base, kind, focusGrapheme: null }
    case 'slice-orbit': return { ...base, kind, slices: 8 }
    case 'three-up': return { ...base, kind, layout: 'adaptive' }
    default: return { ...base, kind: 'particle-lockup', focusGrapheme: 0 }
  }
}
export function direct(headlines: string[], recipe: Recipe, previous?: Project): Project {
  const lines = headlines.map(s => s.trim()).filter(Boolean)
  if (lines.length < 2 || lines.length > 12) throw new Error('文章は2〜12場面で入力してください')
  const base = previous ? cloneProject(previous) : makeCelestial()
  const order = kinds[recipe]
  const scenes = lines.map((headline, index): Scene => {
    const kind = order[index % order.length]
    const isLast = index === lines.length - 1
    let actualKind: string = isLast ? 'particle-lockup' : kind === 'particle-lockup' ? 'particle-flight' : kind
    const words = headline.split(/[\s　/]+/).filter(Boolean)
    if(actualKind==='impact-type'&&words.some(word=>graphemes(word).length>12))actualKind='particle-flight'
    if(actualKind==='three-up'&&(words.length!==3||words.some(word=>graphemes(word).length>12)))actualKind='slice-orbit'
    const items = actualKind === 'three-up' ? [words[0] ?? headline, words[1] ?? words[0] ?? headline, words[2] ?? words[1] ?? headline] : actualKind === 'impact-type' ? words.slice(0,3) : []
    const m = motion(actualKind,recipe)
    if (m.kind === 'impact-type') m.anticipateNext = !isLast
    if (m.kind === 'particle-lockup') m.focusGrapheme = Math.max(0, graphemes(headline).length - 1)
    return { id: crypto.randomUUID(), role: index === 0 ? 'hook' : isLast ? 'outro' : index === lines.length - 2 ? 'summary' : 'feature', content: { headline, secondary: '', items }, durationTicks: actualKind === 'radial-pulse' ? 5760 : actualKind === 'three-up' ? 1920 : 3840, motion: m, typography: { scale: 1, align: 'center' }, outgoing: { kind: 'cut', durationTicks: 0 } }
  })
  const duration = scenes.reduce((n,s) => n+s.durationTicks,0) / 480 * 60 / base.bpm
  if (duration > 60) for (const scene of scenes) scene.durationTicks = Math.max(960, Math.floor(scene.durationTicks * 60 / duration / 240)*240)
  return parseProject({ ...base, id: crypto.randomUUID(), name: lines[0], seed: base.seed, scenes })
}
