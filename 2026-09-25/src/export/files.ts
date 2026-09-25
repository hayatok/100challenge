import { parseRecipe, type Recipe } from '../domain/model'
import { compile } from '../render/layout'
import { loadFonts } from '../render/fonts'
import { RendererHost } from '../render/host'
export type VideoKind='mp4'|'webm-vp9'|'webm-vp8'
export async function capabilities(recipe:Recipe,size:720|1080) {
  const m=await import('mediabunny'),height=recipe.format==='square'?size:Math.round(size*16/9)
  const options={width:size,height,frameRate:30,bitrate:size===720?6000000:12000000}
  const result:VideoKind[]=[]
  if(await m.canEncodeVideo('avc',options))result.push('mp4')
  if(await m.canEncodeVideo('vp9',options))result.push('webm-vp9')
  if(await m.canEncodeVideo('vp8',options))result.push('webm-vp8')
  return result
}
export function saveBlob(blob:Blob,name:string){const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),30000)}
export async function png(recipe:Recipe,frame:number){await loadFonts(recipe);const host=new RendererHost();try {const canvas=await host.render(compile(recipe),frame/30,1080);return await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('PNGを作成できませんでした。')),'image/png'))}finally{host.remove()}}
export function projectJson(recipe:Recipe){return new Blob([JSON.stringify(parseRecipe(recipe),null,2)],{type:'application/json'})}
export async function importJson(file:File){if(file.size>262144)throw new Error('JSONは256KiB以下にしてください。');const recipe=parseRecipe(JSON.parse(await file.text()));return {...recipe,id:crypto.randomUUID()}}
export async function video(recipe:Recipe,size:720|1080,kind:VideoKind,onProgress:(n:number)=>void,isCancelled:()=>boolean){
  await loadFonts(recipe);const m=await import('mediabunny'),host=new RendererHost()
  let output:InstanceType<typeof m.Output>|null=null
  try {
    const scene=compile(recipe),canvas=await host.render(scene,0,size)
    const target=new m.BufferTarget(),codec=kind==='mp4'?'avc':kind==='webm-vp9'?'vp9':'vp8'
    const format=kind==='mp4'?new m.Mp4OutputFormat():new m.WebMOutputFormat()
    output=new m.Output({format,target})
    const source=new m.CanvasSource(canvas,{codec,bitrate:size===720?6000000:12000000})
    output.addVideoTrack(source,{frameRate:30})
    await output.start()
    for(let i=0;i<180;i++){
      while(document.hidden&&!isCancelled())await new Promise(resolve=>setTimeout(resolve,100))
      if(isCancelled()){await output.cancel();return null}
      await host.render(scene,i/30,size)
      await source.add(i/30,1/30)
      onProgress(i+1)
      if(i%3===0)await new Promise(resolve=>setTimeout(resolve,0))
    }
    if(isCancelled()){await output.cancel();return null}
    await output.finalize()
    if(isCancelled())return null
    if(!target.buffer)throw new Error('動画のデータが完成しませんでした。')
    return new Blob([target.buffer],{type:kind==='mp4'?'video/mp4':'video/webm'})
  }catch(error){if(output&&output.state!=='canceled'&&output.state!=='finalized')await output.cancel().catch(()=>{});throw error}
  finally{host.remove()}
}
