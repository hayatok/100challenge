import type { Project } from '../domain/project'
import { compile } from '../engine/timeline'
const TAU=Math.PI*2
export function synthesize(p:Project,sampleRate=48000,seconds=compile(p).frames/30) {
  const length=Math.ceil(seconds*sampleRate), dry=new Float32Array(length),left=new Float32Array(length),right=new Float32Array(length),tl=compile(p),beatLength=60/p.bpm
  const add=(at:number,duration:number,fn:(t:number,i:number)=>number)=>{const start=Math.round(at*sampleRate),count=Math.ceil(duration*sampleRate);for(let i=0;i<count&&start+i<length;i++)if(start+i>=0)dry[start+i]+=fn(i/sampleRate,i)}
  const tone=(at:number,f:number,amp:number,len:number)=>add(at,len,t=>{const env=Math.min(1,t/.006)*Math.exp(-t/(len*.25));return amp*env*(Math.sin(TAU*f*t)+.2*Math.sin(TAU*f*2.003*t))})
  const bass=[82.4069,65.4064,73.4162,55]
  for(let beat=0;beat<Math.ceil(seconds/beatLength);beat++){
    const at=beat*beatLength;if(at>=seconds-.2)break
    const scene=tl.scenes.findLast(s=>at>=s.start)??tl.scenes[0]
    const soft=scene.scene.motion.kind==='slice-orbit'
    if(at>beatLength*2){add(at,.25,t=>.16*Math.exp(-t*19)*Math.sin(TAU*(48*t+2.5*(1-Math.exp(-t*28)))));tone(at,bass[Math.floor(at/5)%4],soft?.035:.07,.42)}
    if(scene.scene.motion.kind==='particle-flight'||scene.scene.motion.kind==='three-up')for(const offset of [0,beatLength/2])add(at+offset,.05,(t,i)=>{const n=Math.sin((i+beat*831)*78.233)*43758.5453;return((n-Math.floor(n))*2-1)*Math.exp(-t*95)*.022})
    if(beat%2===0||scene.scene.motion.kind==='particle-flight'){const notes=[329.628,493.883,659.255,739.989,493.883,440];tone(at,notes[beat%notes.length],soft?.026:.04,soft?1.5:1.05)}
    if(beat%2===1&&!soft)add(at,.13,(t,i)=>{const n=Math.sin((i+beat*13)*39.17)*12345.67;return((n-Math.floor(n))*2-1)*.037*Math.exp(-t*35)})
  }
  for(let index=0;index<tl.scenes.length;index++){
    const s=tl.scenes[index],at=s.start,notes=index%2?[164.814,246.942,369.994]:[130.813,196,329.628]
    for(const f of notes)add(at,Math.min(s.duration+1,6),t=>{const len=Math.min(s.duration+1,6),env=Math.min(1,t/1.1)*Math.min(1,(len-t)/1.1);return .016*env*(Math.sin(TAU*f*t)+.35*Math.sin(TAU*f*1.003*t))})
    tone(at,82.4069,.10,1.4);tone(at,1318.51,.016,2)
    if(s.scene.motion.kind==='radial-pulse'||s.scene.motion.kind==='particle-lockup')add(at+s.duration*.72,.5,(t,i)=>{const n=Math.sin((i+index*1000)*91.19)*43758.5453,env=Math.sin(Math.PI*t/.5)**2;return((n-Math.floor(n))*2-1)*.024*env+Math.sin(TAU*(160*t+700*t*t))*.015*env})
  }
  let peak=0
  for(let i=0;i<length;i++){const t=i/sampleRate,fade=Math.min(1,t/.03,Math.max(0,(seconds-t)/.8)),l=i>sampleRate*.1875?dry[i-Math.floor(sampleRate*.1875)]*.24:0,r=i>sampleRate*.3125?dry[i-Math.floor(sampleRate*.3125)]*.22:0;left[i]=Math.tanh((dry[i]+l)*1.25)*.72*fade*p.audio.gain;right[i]=Math.tanh((dry[i]+r)*1.25)*.72*fade*p.audio.gain;peak=Math.max(peak,Math.abs(left[i]),Math.abs(right[i]))}
  return {left,right,sampleRate,seconds,peak}
}
export function audioBuffer(p:Project,sampleRate=48000,seconds?:number){const pcm=synthesize(p,sampleRate,seconds),buffer=new AudioBuffer({length:pcm.left.length,numberOfChannels:2,sampleRate});buffer.copyToChannel(pcm.left,0);buffer.copyToChannel(pcm.right,1);return buffer}
