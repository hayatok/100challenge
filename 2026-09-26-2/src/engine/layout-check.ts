import type { Project } from '../domain/project'
import { displayLines } from './text'
export interface LayoutIssue { scene: number; message: string; blocking: boolean }
const japanese=(s:string)=>[...s].some(c=>(c.codePointAt(0)??0)>127)
export function layoutIssues(p:Project):LayoutIssue[]{
  const canvas=document.createElement('canvas'),g=canvas.getContext('2d')!,W=p.aspect==='portrait'?1080:1920,issues:LayoutIssue[]=[]
  const fit=(s:string,size:number,max:number)=>{g.font=`700 ${size}px ${japanese(s)?'MotionJapanese':'MotionLatin'}, sans-serif`;return Math.min(...s.split('\n').map(line=>max/Math.max(1,g.measureText(line).width)))}
  p.scenes.forEach((scene,i)=>{
    const kind=scene.motion.kind,headline=scene.content.headline,base=p.aspect==='portrait'?250:500
    const max=kind==='three-up'?(p.aspect==='portrait'?W*.84:W*.28):W*.88
    const words=kind==='three-up'||kind==='impact-type'?scene.content.items:[displayLines(headline,p.aspect).join('\n')]
    for(const word of words){const size=kind==='three-up'?(p.aspect==='portrait'?base*.85:150):base*scene.typography.scale;if(fit(word,size,max)<.48)issues.push({scene:i,message:'見出しが狭い範囲で大きく縮みます。改行か短い文にしてください',blocking:true})}
    if(scene.content.secondary&&fit(scene.content.secondary,p.aspect==='portrait'?24:29,W*.8)<.65)issues.push({scene:i,message:'補足文が長く読みにくくなります。改行か短い文にしてください',blocking:true})
    const seconds=scene.durationTicks/480*60/p.bpm
    if(seconds<.7+headline.length*.045)issues.push({scene:i,message:'読む時間が短い可能性があります。場面を長くしてください',blocking:false})
    if(kind==='impact-type'&&scene.content.items.length===0)issues.push({scene:i,message:'映像に出す言葉がありません',blocking:true})
  })
  return issues
}
