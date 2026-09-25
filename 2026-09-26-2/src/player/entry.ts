import { parseProject } from '../domain/project'
import { Renderer, prepareFonts } from '../engine/render'
import { audioBuffer } from '../audio/score'
const data=document.querySelector('#project-data')?.textContent
if(!data)throw new Error('作品データがありません')
const project=parseProject(JSON.parse(data)),canvas=document.querySelector<HTMLCanvasElement>('#film')!,seek=document.querySelector<HTMLInputElement>('#seek')!,play=document.querySelector<HTMLButtonElement>('#play')!,sound=document.querySelector<HTMLButtonElement>('#sound')!,time=document.querySelector<HTMLOutputElement>('#time')!,status=document.querySelector<HTMLElement>('#status')!
const renderer=new Renderer(canvas,project),duration=renderer.timeline.total
canvas.width=project.aspect==='portrait'?720:1280;canvas.height=project.aspect==='portrait'?1280:720
let current=0,playing=false,audioOn=false,ctx:AudioContext|null=null,buffer:AudioBuffer|null=null,source:AudioBufferSourceNode|null=null,anchor=0,offset=0,raf=0
seek.max=String(duration)
function stopSound(){if(source){source.onended=null;try{source.stop()}catch{}source.disconnect();source=null}}
function show(){renderer.render(current);seek.value=String(current);time.textContent=`${current.toFixed(1)} / ${duration.toFixed(1)}秒`}
function pause(){playing=false;cancelAnimationFrame(raf);stopSound();play.textContent='再生'}
function beginSound(){stopSound();if(!audioOn||!ctx||!buffer||current>=duration)return;source=ctx.createBufferSource();source.buffer=buffer;source.connect(ctx.destination);source.start(0,current);anchor=ctx.currentTime-current}
function tick(now:number){if(!playing)return;current=Math.min(duration,audioOn&&ctx&&source?ctx.currentTime-anchor:offset+(now-anchor)/1000);show();if(current>=duration){pause();return}raf=requestAnimationFrame(tick)}
function start(){if(current>=duration)current=0;playing=true;offset=current;anchor=performance.now();beginSound();play.textContent='一時停止';raf=requestAnimationFrame(tick)}
function jump(value:number){current=Math.max(0,Math.min(duration,value));offset=current;anchor=performance.now();if(playing)beginSound();show()}
play.onclick=()=>playing?pause():start()
seek.oninput=()=>jump(Number(seek.value))
document.querySelector<HTMLButtonElement>('#replay')!.onclick=()=>{pause();jump(0);start()}
sound.onclick=async()=>{try{if(!ctx){ctx=new AudioContext();buffer=audioBuffer(project,ctx.sampleRate)}await ctx.resume();audioOn=!audioOn;sound.textContent=audioOn?'音 ON':'音 OFF';if(playing)beginSound();else stopSound()}catch{status.textContent='音を開始できません。映像は再生できます'}}
document.querySelector<HTMLButtonElement>('#fullscreen')!.onclick=()=>canvas.requestFullscreen()
document.addEventListener('visibilitychange',()=>{if(document.hidden)pause()})
prepareFonts(project).then(()=>{show();status.textContent='再生できます'}).catch(()=>{status.textContent='フォントを読み込めません'})
