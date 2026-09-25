import { execFileSync } from 'node:child_process'
import { join } from 'node:path'

const files=process.argv.slice(2)
const targets=files.length?files:Array.from({length:6},(_,i)=>join('docs','verification','artifacts',`h${i+1}-square.mp4`))
const width=180,height=180,frameBytes=width*height*3
for(const file of targets){
  const frames=execFileSync('ffmpeg',['-hide_banner','-loglevel','error','-i',file,'-vf',`scale=${width}:${height}`,'-pix_fmt','rgb24','-f','rawvideo','-'],{maxBuffer:frameBytes*181})
  const count=frames.length/frameBytes
  if(!Number.isInteger(count)||count!==180)throw new Error(`${file}: expected 180 decoded frames, got ${count}`)
  const difference=(a,b)=>{let sum=0;const startA=a*frameBytes,startB=b*frameBytes;for(let i=0;i<frameBytes;i++)sum+=Math.abs(frames[startA+i]-frames[startB+i]);return sum/frameBytes}
  const adjacent=Array.from({length:count-1},(_,i)=>difference(i,i+1)).sort((a,b)=>a-b)
  const p95=adjacent[Math.floor(adjacent.length*.95)],seam=difference(count-1,0),ratio=seam/p95
  const limit=Math.max(p95*2,2) // Software AVC can add ~1/255 at the loop I-frame; 2/255 remains visually negligible.
  console.log(`${file}: seam=${seam.toFixed(3)} p95=${p95.toFixed(3)} ratio=${ratio.toFixed(2)} limit=${limit.toFixed(3)}`)
  if(seam>=limit)throw new Error(`${file}: visible loop discontinuity (seam=${seam.toFixed(3)}, limit=${limit.toFixed(3)})`)
}
