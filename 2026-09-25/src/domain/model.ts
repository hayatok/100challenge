import { z } from 'zod'

export const families = ['weave', 'fold', 'tile', 'slice', 'orbit', 'echo', 'current', 'lattice', 'glyph', 'monolith', 'interference', 'scatter'] as const
export const palettes = {
  paper: { bg: '#F4F0E8', ink: '#20201E', surface: '#E0D8C7', accent: '#C94332' },
  night: { bg: '#171B27', ink: '#F7F0DF', surface: '#2D3548', accent: '#FF826C' },
  blue: { bg: '#F2F3EE', ink: '#152E63', surface: '#D9E2F3', accent: '#275ADC' },
  forest: { bg: '#193B32', ink: '#F4F0D8', surface: '#285447', accent: '#E5C451' },
  plum: { bg: '#3D233B', ink: '#FFF1E8', surface: '#5C3750', accent: '#F3A899' },
  mono: { bg: '#F5F5EF', ink: '#1D1D1B', surface: '#D8D8D0', accent: '#6B6B64' },
  acid: { bg: '#17211F', ink: '#F4F6EB', surface: '#34453D', accent: '#C8F45A' },
  lilac: { bg: '#EEEAF3', ink: '#292039', surface: '#D1C6E1', accent: '#6C49C9' },
  cinder: { bg: '#111714', ink: '#F6F2E8', surface: '#627368', accent: '#F16544' },
  royal: { bg: '#2044C6', ink: '#F8F3E7', surface: '#132D90', accent: '#D4F75B' },
  carbon: { bg: '#EEEDE7', ink: '#151714', surface: '#B9C1B7', accent: '#E95037' },
  obsidian: { bg: '#10110F', ink: '#F5F1E8', surface: '#565A52', accent: '#F84A32' },
  volt: { bg: '#D8FA38', ink: '#111511', surface: '#83A129', accent: '#1745DB' },
  ultramarine: { bg: '#172BD4', ink: '#FBF4E6', surface: '#8A95EF', accent: '#F54C2F' },
} as const
export type PaletteId = keyof typeof palettes
export const compositions = { weave: ['sweep', 'arch', 'margin'], fold: ['fan', 'gate', 'stack'], tile: ['frame', 'corner', 'columns'], slice: ['slit', 'steps', 'split'], orbit: ['halo', 'eclipse', 'duo'], echo: ['trail', 'mirror', 'burst'], current: ['tide', 'crossflow', 'columnflow'], lattice: ['stringfan', 'lens', 'twist'], glyph: ['matrix', 'rift', 'corona'], monolith:['extrude','cascade','vertical'], interference:['concentric','wavefield','tunnel'], scatter:['cloud','fracture','scan'] } as const
export type Family = typeof families[number]
export type Format = 'square' | 'portrait'
export type Domain = 'color' | 'type' | 'shape' | 'motion'
export type Locks = Record<Domain, boolean>
export const emptyLocks = (): Locks => ({ color: false, type: false, shape: false, motion: false })

const hex = z.string().regex(/^#[0-9A-Fa-f]{6}$/)
const unit = z.number().int().min(0).max(4294967295)
const cleanText = (value: string) => value.replace(/\r\n?/g, '\n').split('\n').map(x => x.trim()).join('\n').replace(/^\n+|\n+$/g, '')
const count = (value: string) => [...new Intl.Segmenter('ja', { granularity: 'grapheme' }).segment(value.replace(/\n/g, ''))].length
const forbidden = /[\p{Extended_Pictographic}\p{C}\u202A-\u202E\u2066-\u2069]/u
export function validateBrief(titleInput: string, subtitleInput: string) {
  const title = cleanText(titleInput)
  const subtitle = subtitleInput.trim()
  if (!title || count(title) > 32 || title.split('\n').length > 3) throw new Error('タイトルは1〜32文字、3行以内にしてください。')
  if (count(subtitle) > 48 || /[\r\n]/.test(subtitle)) throw new Error('補助テキストは48文字以内の1行にしてください。')
  if (forbidden.test(title.replace(/\n/g,'')) || forbidden.test(subtitle)) throw new Error('絵文字・制御文字は使えません。')
  return { title, subtitle }
}

export const recipeSchema = z.strictObject({
  schemaVersion: z.literal(1), rendererVersion: z.literal('1'), id: z.string().uuid(),
  brief: z.strictObject({ title: z.string().min(1).max(128), subtitle: z.string().max(192) }),
  format: z.enum(['square', 'portrait']), family: z.enum(families),
  color: z.strictObject({ paletteId: z.enum(Object.keys(palettes) as [PaletteId, ...PaletteId[]]), bg: hex, ink: hex, surface: hex, accent: hex }),
  type: z.strictObject({ fontId: z.enum(['noto-sans-jp-700', 'noto-serif-jp-600']), align: z.enum(['left', 'center']), size: z.enum(['small', 'medium', 'large']), lineHeight: z.literal(1.15), letterSpacing: z.literal(0) }),
  shape: z.strictObject({ composition: z.string(), density: z.enum(['low', 'medium', 'high']), tilt: z.number().min(-12).max(12), seed: unit }),
  motion: z.strictObject({ amount: z.enum(['calm', 'normal', 'bold']), cycles: z.union([z.literal(1), z.literal(2)]), seed: unit }),
}).superRefine((r, ctx) => {
  if (!(compositions[r.family] as readonly string[]).includes(r.shape.composition)) ctx.addIssue({ code: 'custom', path: ['shape','composition'], message: '表現に合わない構図です' })
  if (r.family === 'tile' && r.shape.tilt !== 0) ctx.addIssue({ code: 'custom', path: ['shape','tilt'], message: '組むでは傾きを使いません' })
  try { validateBrief(r.brief.title, r.brief.subtitle) } catch { ctx.addIssue({ code: 'custom', path: ['brief'], message: '文字の条件を満たしません' }) }
})
export type Recipe = z.infer<typeof recipeSchema>
export type Board = { id: string; parentBoardId: string | null; sourceRecipeId: string | null; candidates: Recipe[]; selectedId: string; locks: Locks; filter: 'all' | Family; operation: 'initial' | 'explore' | 'refine' | 'edit' | 'import' | 'favorite'; createdAt: string; labels?: string[] }
export type SavedState = { version: 1; revision: number; boards: Board[]; favorites: Recipe[]; activeBoardId: string; exploreCounter: number }
export function parseRecipe(input: unknown): Recipe { return recipeSchema.parse(input) }
export function canonical(recipe: Recipe) { const { id: _id, ...rest } = recipe; void _id; return JSON.stringify(rest) }
