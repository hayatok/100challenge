import { z } from 'zod'
import celestial from '../celestial.project.json'
const count = (s: string) => [...new Intl.Segmenter('ja', { granularity: 'grapheme' }).segment(s)].length
const text = (max: number, min = 0) => z.string().refine(s => count(s) >= min && count(s) <= max, `文字数は${min}〜${max}文字です`)
const hex = z.string().regex(/^#[0-9a-fA-F]{6}$/)
const common = { intensity: z.number().min(0).max(1), motif: z.enum(['celestial', 'geometric']) }
const motion = z.discriminatedUnion('kind', [
  z.strictObject({ ...common, kind: z.literal('impact-type'), direction: z.enum(['up', 'left']), anticipateNext: z.boolean() }),
  z.strictObject({ ...common, kind: z.literal('particle-flight'), depth: z.number().min(0).max(1) }),
  z.strictObject({ ...common, kind: z.literal('radial-pulse'), focusGrapheme: z.number().int().min(0).nullable() }),
  z.strictObject({ ...common, kind: z.literal('slice-orbit'), slices: z.number().int().min(4).max(12) }),
  z.strictObject({ ...common, kind: z.literal('three-up'), layout: z.literal('adaptive') }),
  z.strictObject({ ...common, kind: z.literal('particle-lockup'), focusGrapheme: z.number().int().min(0) })
])
const scene = z.strictObject({
  id: z.string().min(1).max(80), role: z.enum(['hook', 'feature', 'summary', 'outro']),
  content: z.strictObject({ headline: text(40, 1).refine(s => s.split('\n').length <= 2), secondary: text(100).refine(s => s.split('\n').length <= 3), items: z.array(text(12, 1)).max(3) }),
  durationTicks: z.number().int().min(960).max(15360).refine(n => n % 240 === 0),
  motion, typography: z.strictObject({ scale: z.number().min(.75).max(1.2), align: z.enum(['left', 'center']) }),
  outgoing: z.strictObject({ kind: z.enum(['cut', 'circle-match']), durationTicks: z.number().int().min(0).max(960) })
})
export const projectSchema = z.strictObject({
  schemaVersion: z.literal(1), rendererVersion: z.literal('1'), id: z.string().uuid(), name: text(80, 1),
  seed: z.number().int().min(0).max(4294967295), aspect: z.enum(['landscape', 'portrait']), bpm: z.number().int().min(60).max(180),
  palette: z.strictObject({ paper: hex, ink: hex, accent: hex, secondary: hex, muted: hex }), fontSet: z.literal('space-noto-v1'),
  audio: z.strictObject({ mode: z.enum(['none', 'synth-v1']), gain: z.number().min(0).max(1) }), scenes: z.array(scene).min(2).max(12)
}).superRefine((p, ctx) => {
  if (new Set(p.scenes.map(s => s.id)).size !== p.scenes.length) ctx.addIssue({ code: 'custom', path: ['scenes'], message: '場面IDが重複しています' })
  let ticks = 0
  p.scenes.forEach((s, i) => {
    ticks += s.durationTicks - s.outgoing.durationTicks
    const next = p.scenes[i + 1]
    if (s.motion.kind === 'impact-type' && (s.content.items.length < 1 || s.content.items.length > 3)) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'content', 'items'], message: '導入は1〜3語です' })
    if (s.motion.kind === 'three-up' && s.content.items.length !== 3) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'content', 'items'], message: '三分割は3語です' })
    if (s.motion.kind === 'impact-type' && s.motion.anticipateNext && !next) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'motion'], message: '最後の場面は次場面を予告できません' })
    if (s.motion.kind === 'particle-lockup' || s.motion.kind === 'radial-pulse') {
      const n = s.motion.focusGrapheme
      if (n !== null && n >= count(s.content.headline.replaceAll('\n', ''))) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'motion', 'focusGrapheme'], message: '強調文字が見出しの外です' })
    }
    const o = s.outgoing.durationTicks
    if (s.outgoing.kind === 'cut' && o !== 0 || s.outgoing.kind === 'circle-match' && (!next || s.motion.kind !== 'radial-pulse' || next.motion.kind !== 'slice-orbit' || o < 240 || o % 240 !== 0 || o > Math.min(s.durationTicks, next.durationTicks) / 3)) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'outgoing'], message: 'つなぎの組み合わせまたは尺が不正です' })
    if (i === p.scenes.length - 1 && (s.outgoing.kind !== 'cut' || o !== 0)) ctx.addIssue({ code: 'custom', path: ['scenes', i, 'outgoing'], message: '最後はカット/0です' })
    if (o + (p.scenes[i - 1]?.outgoing.durationTicks ?? 0) >= s.durationTicks) ctx.addIssue({ code: 'custom', path: ['scenes', i], message: '重なりが場面より長いです' })
  })
  const seconds = ticks / 480 * 60 / p.bpm
  if (seconds < 4 || seconds > 60) ctx.addIssue({ code: 'custom', path: ['scenes'], message: '全体は4〜60秒です' })
})
export type Project = z.infer<typeof projectSchema>
export type Scene = Project['scenes'][number]
export function parseProject(input: unknown): Project { return projectSchema.parse(input) }
export function cloneProject(p: Project): Project { return structuredClone(p) }
export function makeCelestial(): Project { return parseProject({ ...celestial, id: crypto.randomUUID() }) }
export function graphemes(s: string): string[] { return [...new Intl.Segmenter('ja', { granularity: 'grapheme' }).segment(s)].map(x => x.segment) }
