import { describe, expect, it } from 'vitest'
import { appendBoard, board, explore, hashSeed, makeRecipe, mulberry32, refine } from '../../src/domain/generate'
import { canonical, emptyLocks, families, parseRecipe, validateBrief, type Domain, type Family, type Locks } from '../../src/domain/model'
const brief={title:'余白の、その先。',subtitle:''}
describe('入力と境界',()=>{
  it('書記素・改行を扱い、無効な入力を拒否する',()=>{
    expect(validateBrief(' 余白の、\r\nその先。 ','')).toEqual({title:'余白の、\nその先。',subtitle:''})
    expect(validateBrief('か\u3099','').title).toBe('か\u3099')
    for(const t of ['', ' ', 'あ'.repeat(33), 'a\nb\nc\nd', '😀'])expect(()=>validateBrief(t,'')).toThrow()
    expect(()=>validateBrief('あ','い'.repeat(49))).toThrow()
    expect(()=>validateBrief('a\u202eb','')).toThrow()
    expect(validateBrief('あ'.repeat(32),'い'.repeat(48))).toBeTruthy()
  })
  it('JSON schema は版・キー・構図を検証する',()=>{
    const r=makeRecipe(brief,'square','weave',0,1)
    expect(parseRecipe(JSON.parse(JSON.stringify(r)))).toEqual(r)
    expect(()=>parseRecipe({...r,schemaVersion:2})).toThrow()
    expect(()=>parseRecipe({...r,foo:'https://example.com'})).toThrow()
    expect(()=>parseRecipe({...r,shape:{...r.shape,composition:'fan'}})).toThrow()
    expect(()=>parseRecipe({...r,shape:{...r.shape,seed:-1}})).toThrow()
  })
})
describe('生成',()=>{
  it('PRNGと名前空間が再現可能',()=>{
    const seq=mulberry32(0);expect([seq(),seq(),seq()].map(n=>n.toFixed(8))).toEqual(['0.26642921','0.00032975','0.22327203'])
    expect(hashSeed(0,'shape')).toBe(hashSeed(0,'shape'));expect(hashSeed(0,'shape')).not.toBe(hashSeed(0,'motion'))
  })
  it('100 seed のおまかせは12表現を巡り、毎回異なる4表現を出す',()=>{
    const covered=new Set<Family>()
    for(let seed=0;seed<100;seed++)for(const format of ['square','portrait'] as const){const r=explore(brief,format,'all',seed)
      r.forEach(recipe=>covered.add(recipe.family))
      expect(new Set(r.map(v=>v.family)).size).toBe(4);expect(new Set(r.map(canonical)).size).toBe(4)
    }
    expect(covered).toEqual(new Set(families))
    const cycle=Array.from({length:12},(_,start)=>explore(brief,'square','all',start,start)).flat()
    expect(new Set(cycle.map(recipe=>recipe.family))).toEqual(new Set(families))
    for(let start=0;start<12;start++)expect(explore(brief,'square','all',start,start).filter(recipe=>['monolith','interference','scatter'].includes(recipe.family))).toHaveLength(2)
  })
  it('指定表現は2構図と2配色以上',()=>{for(const f of families){const r=explore(brief,'square',f,1);expect(new Set(r.map(v=>v.shape.composition)).size).toBeGreaterThanOrEqual(2);expect(new Set(r.map(v=>v.color.paletteId)).size).toBeGreaterThanOrEqual(2)}})
  it('16通りの固定で固定ドメインが同一、最大2項目を変える',()=>{
    for(const family of families){const parent=makeRecipe(brief,'square',family,0,10)
      for(let mask=0;mask<16;mask++){const locks=Object.fromEntries((['color','type','shape','motion'] as Domain[]).map((k,i)=>[k,!!(mask&(1<<i))])) as Locks
        const {recipes}=refine(parent,locks,33);expect(recipes.length).toBeGreaterThanOrEqual(mask===15?0:1);expect(recipes.length).toBeLessThanOrEqual(mask===15?0:4)
        for(const r of recipes){let changed=0;for(const key of ['color','type','shape','motion'] as Domain[]){if(locks[key])expect(r[key]).toEqual(parent[key]);else if(JSON.stringify(r[key])!==JSON.stringify(parent[key]))changed++}expect(changed).toBeGreaterThanOrEqual(1);expect(changed).toBeLessThanOrEqual(2);expect(r.brief).toEqual(parent.brief);expect(r.family).toBe(parent.family);expect(r.format).toBe(parent.format)}
      }
    }
  })
})
describe('履歴',()=>{it('A→B→A→CでBを残す',()=>{const a=board(explore(brief,'square','all',1),'initial',null,null,'all');const b=board(explore(brief,'square','all',2),'refine',a,a.selectedId,'all');const c=board(explore(brief,'square','all',3),'refine',a,a.selectedId,'all');let all=[a];all=appendBoard(all,b);all=appendBoard(all,c);expect(all.map(v=>v.id)).toEqual([a.id,b.id,c.id]);expect(b.parentBoardId).toBe(a.id);expect(c.parentBoardId).toBe(a.id);expect(a.locks).toEqual(emptyLocks())})})

describe('探索と履歴の上限',()=>{
  it('全固定なら候補0、単一domainでも重複なしで停止する',()=>{
    const parent=makeRecipe(brief,'portrait','fold',0,9)
    const locked={color:true,type:true,shape:true,motion:true}
    expect(refine(parent,locked,0)).toEqual({recipes:[],labels:[]})
    for(const free of ['color','type','shape','motion'] as Domain[]){
      const locks={...locked,[free]:false}
      const recipes=refine(parent,locks,0).recipes
      expect(recipes.length).toBeGreaterThan(0)
      expect(recipes.length).toBeLessThanOrEqual(4)
      expect(new Set(recipes.map(canonical)).size).toBe(recipes.length)
    }
  })
  it('履歴は50件までで直前の親を残す',()=>{
    let entries=[board(explore(brief,'square','all',0),'initial',null,null,'all')]
    for(let i=1;i<=52;i++)entries=appendBoard(entries,board(explore(brief,'square','all',i),'refine',entries.at(-1)!,null,'all'))
    expect(entries).toHaveLength(50)
    const last=entries.at(-1)!
    expect(entries.some(entry=>entry.id===last.parentBoardId)).toBe(true)
  })
})
