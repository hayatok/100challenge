import '@fontsource/noto-sans-jp/japanese-400.css'
import '@fontsource/noto-sans-jp/japanese-700.css'
import '@fontsource/noto-serif-jp/japanese-600.css'
import type { Recipe } from '../domain/model'

const loadedGlyphs=new Map<string,Set<string>>()

async function ensureFont(font:string,text:string){
  let known=loadedGlyphs.get(font)
  if(!known){known=new Set<string>();loadedGlyphs.set(font,known)}
  const missing=[...new Set(text)].filter(character=>character!=='\n'&&!known.has(character)).join('')
  if(!missing)return
  const result=await document.fonts.load(font,missing).catch(()=>{throw new Error('フォントを読み込めませんでした。通信状態を確認して再試行してください。')})
  if(!result.length)throw new Error('フォントを読み込めませんでした。通信状態を確認して再試行してください。')
  for(const character of missing)known.add(character)
}

export async function loadFonts(recipe:Recipe){
  const text=recipe.brief.title+recipe.brief.subtitle
  const title=recipe.type.fontId==='noto-serif-jp-600'?'600 48px "Noto Serif JP"':'700 48px "Noto Sans JP"'
  let timer:ReturnType<typeof setTimeout>|undefined
  try{
    await Promise.race([
      Promise.all([ensureFont(title,text),ensureFont('400 30px "Noto Sans JP"',text)]),
      new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(new Error('フォントの読み込みに時間がかかっています。再試行してください。')),15000)})
    ])
  }finally{clearTimeout(timer)}
}
