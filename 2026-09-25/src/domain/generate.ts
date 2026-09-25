import { canonical, compositions, emptyLocks, families, palettes, type Board, type Domain, type Family, type Format, type Locks, type PaletteId, type Recipe } from './model'

export function mulberry32(seed: number) { let s = seed >>> 0; return () => { s = (s + 0x6D2B79F5) >>> 0; let t = Math.imul(s ^ (s >>> 15), 1 | s); t ^= t + Math.imul(t ^ (t >>> 7), 61 | t); return ((t ^ (t >>> 14)) >>> 0) / 4294967296 } }
export function hashSeed(seed: number, namespace: string) { let h = 2166136261; for (const b of new TextEncoder().encode(`${seed}:${namespace}`)) h = Math.imul(h ^ b, 16777619); return h >>> 0 }
export function randomSeed() { return crypto.getRandomValues(new Uint32Array(1))[0] }
const paletteIds = Object.keys(palettes) as PaletteId[]
const palettePool=(family:Family):readonly PaletteId[]=>family==='current'?['royal','cinder','acid','forest']:family==='lattice'?['cinder','carbon','night','mono']:family==='glyph'?['carbon','royal','paper','acid']:family==='monolith'?['obsidian','ultramarine','carbon','acid']:family==='interference'?['volt','obsidian','carbon','royal']:family==='scatter'?['obsidian','ultramarine','volt','cinder']:paletteIds
const densities = ['low','medium','high'] as const
const amounts = ['calm','normal','bold'] as const
const sizes = ['small','medium','large'] as const
export const familyNames: Record<Family,string> = { weave: '織る', fold: 'めくる', tile: '組む', slice:'切る', orbit:'巡る', echo:'響く', current:'流れる', lattice:'張る', glyph:'増殖', monolith:'迫る', interference:'干渉', scatter:'散る' }
export const compositionNames: Record<string,string> = { sweep:'斜め',arch:'弧',margin:'余白',fan:'扇',gate:'門',stack:'積層',frame:'外周',corner:'対角',columns:'列',slit:'横断',steps:'階段',split:'縦割り',halo:'光輪',eclipse:'食',duo:'双円',trail:'余韻',mirror:'鏡面',burst:'放射',tide:'潮流',crossflow:'交差',columnflow:'縦流',stringfan:'扇糸',lens:'レンズ',twist:'ねじれ',matrix:'密集',rift:'裂け目',corona:'環状',extrude:'押し出し',cascade:'連なり',vertical:'縦の圧力',concentric:'同心',wavefield:'波面',tunnel:'奥行き',cloud:'粒像',fracture:'分裂',scan:'走査' }
function pick<T>(items: readonly T[], n: number): T { return items[n % items.length] }
export function makeRecipe(brief: Recipe['brief'], format: Format, family: Family, variant: number, seed: number): Recipe {
  const r = mulberry32(hashSeed(seed, `${family}:${variant}`))
  const pool=palettePool(family),paletteId = pick(pool, variant + Math.floor(r()*pool.length))
  const shapeSeed = hashSeed(seed, `shape:${variant}`), motionSeed = hashSeed(seed, `motion:${variant}`)
  const comp = pick(compositions[family], variant + Math.floor(r()*3))
  return { schemaVersion:1, rendererVersion:'1', id:crypto.randomUUID(), brief, format, family,
    color:{ paletteId, ...palettes[paletteId] },
    type:{ fontId: family==='weave'||family==='orbit'?'noto-serif-jp-600':'noto-sans-jp-700', align:family==='fold'||family==='orbit'||family==='lattice'||family==='interference'?'center':'left', size:pick(sizes, Math.floor(r()*3)), lineHeight:1.15, letterSpacing:0 },
    shape:{ composition:comp, density:pick(densities,Math.floor(r()*3)), tilt:family==='tile'?0:Math.round((r()-.5)*10), seed:shapeSeed },
    motion:{ amount:pick(amounts,Math.floor(r()*3)), cycles:1, seed:motionSeed } }
}
export function explore(brief: Recipe['brief'], format: Format, filter: 'all'|Family, seed: number, familyStart=seed%families.length): Recipe[] {
  const modern:readonly Family[]=['monolith','interference','scatter'],previous=families.slice(0,9)
  const fs: Family[] = filter==='all' ? [modern[familyStart%modern.length],modern[(familyStart+1)%modern.length],previous[(familyStart*2)%previous.length],previous[(familyStart*2+1)%previous.length]] : [filter,filter,filter,filter]
  const result:Recipe[]=[]
  fs.forEach((f,i) => {
    const recipe = makeRecipe(brief,format,f,i,hashSeed(seed,`candidate:${i}`))
    if (filter!=='all') { recipe.shape.composition=compositions[f][i%3]; const pool=palettePool(f),paletteId=pool[(seed+i)%pool.length]; recipe.color={paletteId,...palettes[paletteId]} }
    result.push(recipe)
  })
  return result
}
export function refine(parent: Recipe, locks: Locks, seed: number): {recipes:Recipe[];labels:string[]} {
  const free = (Object.keys(locks) as Domain[]).filter(k=>!locks[k]); if (!free.length) return {recipes:[],labels:[]}
  const seen = new Set([canonical(parent)]), recipes:Recipe[] = [], labels:string[] = []
  const labelsMap:Record<Domain,string>={color:'色',type:'文字組み',shape:'形',motion:'動き'}
  for(let attempt=0;attempt<32&&recipes.length<4;attempt++) {
    const first=free[attempt%free.length], second=free.length>1&&attempt%3===2?free[(attempt+1)%free.length]:null
    const changes=[first,...(second&&second!==first?[second]:[])]
    const offset=Math.floor(mulberry32(hashSeed(seed,`refine:${attempt}`))()*3)
    const next:Recipe={...parent,id:crypto.randomUUID(), color:{...parent.color},type:{...parent.type},shape:{...parent.shape},motion:{...parent.motion}}
    for(const key of changes) {
      if(key==='color') { const ix=paletteIds.indexOf(parent.color.paletteId as PaletteId); const id=paletteIds[(ix+1+(attempt+offset)%(paletteIds.length-1))%paletteIds.length]; next.color={paletteId:id,...palettes[id]} }
      if(key==='type') { if(attempt%2) next.type.fontId=parent.type.fontId==='noto-sans-jp-700'?'noto-serif-jp-600':'noto-sans-jp-700'; else next.type.size=sizes[(sizes.indexOf(parent.type.size)+1)%3] }
      if(key==='shape') { const list=compositions[parent.family] as readonly string[]; next.shape.composition=list[(list.indexOf(parent.shape.composition)+1+attempt%2)%3]; next.shape.density=densities[(densities.indexOf(parent.shape.density)+1)%3]; next.shape.seed=hashSeed(parent.shape.seed,`near:${attempt}`) }
      if(key==='motion') { next.motion.amount=amounts[(amounts.indexOf(parent.motion.amount)+1+attempt%2)%3]; next.motion.seed=hashSeed(parent.motion.seed,`near:${attempt}`) }
    }
    const key=canonical(next); if(seen.has(key))continue; seen.add(key); recipes.push(next); labels.push(`${changes.map(k=>labelsMap[k]).join('と')}を変更`)
  }
  return {recipes,labels}
}
export function board(candidates:Recipe[], operation:Board['operation'], parent:Board|null, sourceRecipeId:string|null, filter:Board['filter'], labels?:string[]):Board { return {id:crypto.randomUUID(),parentBoardId:parent?.id??null,sourceRecipeId,candidates,selectedId:candidates[0].id,locks:parent?{...parent.locks}:emptyLocks(),filter,operation,createdAt:new Date().toISOString(),labels} }
export function appendBoard(boards:Board[], next:Board) { const all=[...boards,next]; if(all.length<=50)return all; const protectedIds=new Set([next.id,next.parentBoardId]); const remove=all.findIndex(b=>!protectedIds.has(b.id)); if(remove>=0) all.splice(remove,1); return all }
