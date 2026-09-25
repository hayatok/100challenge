import type { Project } from '../domain/project'
import { parseProject } from '../domain/project'
import { Renderer, prepareFonts } from '../engine/render'
import { compile } from '../engine/timeline'
import { audioBuffer } from '../audio/score'
import { AudioBufferSource, BufferTarget, CanvasSource, Mp4OutputFormat, Output, WebMOutputFormat, canEncodeAudio, canEncodeVideo } from 'mediabunny'
export type VideoKind='mp4'|'webm'
export const dimensions=(p:Project,quality:720|1080)=>p.aspect==='landscape'?{width:quality===720?1280:1920,height:quality}:{width:quality,height:quality===720?1280:1920}
export function saveBlob(blob:Blob,name:string){const a=document.createElement('a'),url=URL.createObjectURL(blob);a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),30000)}
export function jsonBlob(p:Project){return new Blob([JSON.stringify(parseProject(p),null,2)],{type:'application/json'})}
export async function importJson(file:File){if(file.size>1048576)throw new Error('JSONは1MiB以下にしてください');return parseProject({...JSON.parse(await file.text()),id:crypto.randomUUID()})}
export async function png(p:Project,time:number){await prepareFonts(p);const dims=dimensions(p,1080),canvas=document.createElement('canvas'),renderer=new Renderer(canvas,p);try{renderer.render(time,dims.width,dims.height);return await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('PNGを作成できません')),'image/png'))}finally{renderer.dispose()}}
export async function capabilities(p:Project,quality:720|1080){const {width,height}=dimensions(p,quality),opts={width,height,frameRate:30};return {mp4:await canEncodeVideo('avc',opts),aac:await canEncodeAudio('aac',{numberOfChannels:2,sampleRate:48000}),webm:await canEncodeVideo('vp9',opts),opus:await canEncodeAudio('opus',{numberOfChannels:2,sampleRate:48000})}}
export async function video(p:Project,quality:720|1080,kind:VideoKind,onProgress:(done:number,total:number)=>void,signal:AbortSignal){
  p=parseProject(structuredClone(p));await prepareFonts(p);if(signal.aborted)throw new DOMException('中止しました','AbortError')
  const support=await capabilities(p,quality),withAudio=p.audio.mode==='synth-v1'
  if(kind==='mp4'&&(!support.mp4||withAudio&&!support.aac))throw new Error('この環境では音声付きMP4を書き出せません。音付きWebMまたはHTMLを選んでください')
  if(kind==='webm'&&(!support.webm||withAudio&&!support.opus))throw new Error('この環境では音声付きWebMを書き出せません。HTMLを選んでください')
  const dims=dimensions(p,quality),canvas=document.createElement('canvas'),renderer=new Renderer(canvas,p),target=new BufferTarget(),output=new Output({format:kind==='mp4'?new Mp4OutputFormat():new WebMOutputFormat(),target}),source=new CanvasSource(canvas,{codec:kind==='mp4'?'avc':'vp9',bitrate:quality===720?6000000:12000000})
  output.addVideoTrack(source,{frameRate:30});let audioTask:Promise<void>|undefined
  const audioSource=withAudio?new AudioBufferSource({codec:kind==='mp4'?'aac':'opus',bitrate:192000}):null
  if(audioSource)output.addAudioTrack(audioSource)
  let finalized=false,audioError:unknown=null
  try{await output.start();if(audioSource)audioTask=(async()=>{const buffer=audioBuffer(p,48000,compile(p).frames/30);for(let at=0;at<buffer.length;at+=48000){if(signal.aborted)throw new DOMException('中止しました','AbortError');const count=Math.min(48000,buffer.length-at),chunk=new AudioBuffer({length:count,numberOfChannels:2,sampleRate:48000});for(let c=0;c<2;c++)chunk.copyToChannel(buffer.getChannelData(c).subarray(at,at+count),c);await audioSource.add(chunk)}})().catch(e=>{audioError=e});const frames=renderer.timeline.frames;for(let i=0;i<frames;i++){if(signal.aborted)throw new DOMException('中止しました','AbortError');renderer.render(i/30,dims.width,dims.height);await source.add(i/30,1/30);onProgress(i+1,frames);if(i%3===0)await new Promise(resolve=>setTimeout(resolve,0))}await audioTask;if(audioError)throw audioError;if(signal.aborted)throw new DOMException('中止しました','AbortError');await output.finalize();finalized=true;if(!target.buffer)throw new Error('動画が完成しませんでした');return new Blob([target.buffer],{type:kind==='mp4'?'video/mp4':'video/webm'})}
  finally{if(!finalized&&output.state!=='canceled'&&output.state!=='finalized')await output.cancel().catch(()=>{});await audioTask?.catch(()=>{});renderer.dispose()}
}
