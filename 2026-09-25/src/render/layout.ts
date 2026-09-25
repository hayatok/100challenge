import type { Recipe } from '../domain/model'
export type Line = { text: string; x: number; y: number; width: number }
export type Scene = { recipe: Recipe; width: number; height: number; title: Line[]; subtitle: Line[]; size: number; subtitleSize: number; titleBox: {x:number;y:number;width:number;height:number} }
const segment = (text:string) => [...new Intl.Segmenter('ja',{granularity:'grapheme'}).segment(text)].map(x=>x.segment)
const close = /^[。、，．！？）」』】〉》]/u
const open = /[（「『【〈《]$/u
function fontFamily(recipe:Recipe) { return recipe.type.fontId==='noto-serif-jp-600' ? '"Noto Serif JP"' : '"Noto Sans JP"' }
export function fontString(recipe:Recipe,size:number) { return `${recipe.type.fontId==='noto-serif-jp-600'?600:700} ${size}px ${fontFamily(recipe)}` }
function breakPart(ctx:CanvasRenderingContext2D, part:string,maxWidth:number) {
  const tokens:string[]=[]
  for(const char of segment(part)){const previous=tokens.at(-1);if(previous&&/^[A-Za-z0-9]+$/.test(previous)&&/^[A-Za-z0-9]$/.test(char))tokens[tokens.length-1]+=char;else tokens.push(char)}
  const lines:string[]=[];let line=''
  const put=(token:string)=>{
    if(!line){line=token.trimStart();return}
    if(ctx.measureText(line+token).width<=maxWidth){line+=token;return}
    if(close.test(token)){const chars=segment(line);const last=chars.pop()!;lines.push(chars.join('').trimEnd());line=last+token;return}
    lines.push(line.trimEnd());line=token.trimStart()
  }
  for(const token of tokens){if(ctx.measureText(token).width<=maxWidth)put(token);else for(const char of segment(token))put(char)}
  if(line)lines.push(line.trimEnd())
  for(let i=0;i<lines.length-1;i++)if(open.test(lines[i])){const chars=segment(lines[i]);const last=chars.pop()!;lines[i]=chars.join('');lines[i+1]=last+lines[i+1]}
  return lines.filter(Boolean)
}
function wrap(ctx:CanvasRenderingContext2D,text:string,maxWidth:number) { return text.split('\n').flatMap(part=>breakPart(ctx,part,maxWidth)) }
export function compile(recipe:Recipe): Scene {
  const width=1080,height=recipe.format==='square'?1080:1920
  const canvas=document.createElement('canvas'), ctx=canvas.getContext('2d')!
  const expressive=recipe.family==='current'||recipe.family==='lattice'||recipe.family==='glyph'||recipe.family==='monolith'||recipe.family==='interference'||recipe.family==='scatter'
  const target=(recipe.family==='monolith'?{small:258,medium:338,large:430}:recipe.family==='scatter'?{small:128,medium:172,large:218}:expressive?{small:170,medium:226,large:294}:{small:128,medium:176,large:220})[recipe.type.size]
  const maxWidth=width*(recipe.family==='monolith'?.9:expressive?.84:.8),maxHeight=height*(recipe.family==='monolith'?.75:recipe.family==='scatter'?.39:expressive?.56:.5)
  const fitsSubtitle=(lineCount:number,fontSize:number)=>!recipe.brief.subtitle||height*(expressive?.1:.12)+lineCount*fontSize*1.15+fontSize*.01<=height*.88-48
  let size=target, words:string[]=[]
  const explicit=recipe.brief.title.split('\n')
  if(explicit.length>1)for(;size>=48;size-=2){ctx.font=fontString(recipe,size);if(explicit.length<=3&&explicit.length*size*1.15<=maxHeight&&fitsSubtitle(explicit.length,size)&&explicit.every(w=>ctx.measureText(w).width<=maxWidth)){words=explicit;break}}
  if(!words.length){size=target;for(;size>=48;size-=2) { ctx.font=fontString(recipe,size); words=wrap(ctx,recipe.brief.title,maxWidth); if(words.length<=3&&words.length*size*1.15<=maxHeight&&fitsSubtitle(words.length,size)&&words.every(w=>ctx.measureText(w).width<=maxWidth)) break }}
  if(size<48) throw new Error('このタイトルは表紙に収まりません。短くするか改行を調整してください。')
  const familyY={weave:.35,fold:.49,tile:.47,slice:.43,orbit:.49,echo:.43,current:.51,lattice:.54,glyph:.51,monolith:.48,interference:.52,scatter:.73}
  const expressiveY:Record<string,number>={tide:.51,crossflow:.41,columnflow:.61,stringfan:.65,lens:.38,twist:.54,matrix:.46,rift:.53,corona:.51}
  const baseY=(expressive?expressiveY[recipe.shape.composition]??familyY[recipe.family]:familyY[recipe.family])*height
  const total=words.length*size*1.15
  const bottomLimit=expressive?(recipe.brief.subtitle?.76:.84):.69
  const startY=Math.max(height*(expressive ? .1 : .12),Math.min(baseY-total/2,height*bottomLimit-total))
  ctx.font=fontString(recipe,size)
  const title=words.map((text,i)=>({text,x:recipe.type.align==='center'?width/2:width*(recipe.family==='monolith'?.055:expressive?.08:.1),y:startY+i*size*1.15+size,width:ctx.measureText(text).width}))
  const titleBox={x:width*(recipe.family==='monolith'?.055:expressive?.08:.1),y:startY,width:maxWidth,height:total}
  let subtitleSize=30, subwords:string[]=[]
  for(;subtitleSize>=24;subtitleSize-=1){ctx.font=`400 ${subtitleSize}px "Noto Sans JP"`;subwords=recipe.brief.subtitle?wrap(ctx,recipe.brief.subtitle,maxWidth):[];if(subwords.length<=2)break}
  if(subwords.length>2)throw new Error('補助テキストが表紙に収まりません。')
  ctx.font=`400 ${subtitleSize}px "Noto Sans JP"`
  const subtitle=subwords.map((text,i)=>({text,x:width*.1,y:height*.88+i*subtitleSize*1.3,width:ctx.measureText(text).width}))
  if(title.length&&subtitle.length&&title.at(-1)!.y+size*.16>subtitle[0].y-48)throw new Error('タイトルと補助テキストが重なります。')
  return {recipe,width,height,title,subtitle,size,subtitleSize,titleBox}
}
