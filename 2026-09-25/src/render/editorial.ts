import { fontString, type Scene } from './layout'

const TAU=Math.PI*2
const strength={calm:.6,normal:1,bold:1.45}

function heading(ctx:CanvasRenderingContext2D,s:Scene,outline=0){
  const c=s.recipe.color
  ctx.save();ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.textBaseline='alphabetic';ctx.lineJoin='round'
  if(outline){ctx.strokeStyle=c.bg;ctx.lineWidth=outline;for(const line of s.title)ctx.strokeText(line.text,line.x,line.y)}
  ctx.fillStyle=c.ink;for(const line of s.title)ctx.fillText(line.text,line.x,line.y)
  ctx.restore()
  if(!s.subtitle.length)return
  ctx.save();ctx.font=`400 ${s.subtitleSize}px "Noto Sans JP"`;ctx.textAlign='left';ctx.textBaseline='alphabetic'
  for(const line of s.subtitle){ctx.fillStyle=c.bg;ctx.fillRect(line.x-12,line.y-s.subtitleSize-8,line.width+24,s.subtitleSize+24);ctx.fillStyle=c.ink;ctx.fillText(line.text,line.x,line.y)}
  ctx.restore()
}

export function monolith(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles,swing=Math.sin(phase)*strength[s.recipe.motion.amount]
  ctx.save();ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.textBaseline='alphabetic';ctx.lineJoin='round'
  if(comp==='extrude'){
    for(let i=13;i>=1;i--){
      const dx=i*(7+swing*4),dy=i*(9+swing*3)
      ctx.strokeStyle=i%3===0?c.accent:c.surface;ctx.lineWidth=5+i*.65;ctx.globalAlpha=.36+i*.025
      for(const line of s.title)ctx.strokeText(line.text,line.x+dx,line.y+dy)
    }
    ctx.globalAlpha=1
    ctx.fillStyle=c.accent;ctx.fillRect(w*.055,h*.91,w*.63,14)
  }else if(comp==='cascade'){
    ctx.save();ctx.translate(w*.51,h*.47);ctx.rotate(-.13);ctx.translate(-w*.51,-h*.47)
    for(let i=0;i<5;i++){
      const y=h*(-.21+i*.18)+swing*(i%2?1:-1)*w*.045
      ctx.fillStyle=i%2?c.surface:c.accent;ctx.globalAlpha=i===2?.7:.42
      ctx.fillRect(-w*.2,y,w*1.4,h*.078)
    }
    ctx.restore();ctx.globalAlpha=1
    for(let i=5;i>=1;i--){ctx.strokeStyle=i%2?c.accent:c.surface;ctx.lineWidth=10;ctx.globalAlpha=.4;for(const line of s.title)ctx.strokeText(line.text,line.x+i*(9+swing*5),line.y-i*17)}
  }else{
    const glyph=[...new Intl.Segmenter('ja',{granularity:'grapheme'}).segment(s.recipe.brief.title.replace(/\s/g,''))][0]?.segment??'A'
    ctx.save();ctx.translate(w*.92+swing*w*.035,h*.78);ctx.rotate(-Math.PI/2);ctx.font=`700 ${Math.round(w*.9)}px "Noto Sans JP"`;ctx.textAlign='center'
    ctx.fillStyle=c.surface;ctx.globalAlpha=.65;ctx.fillText(glyph,0,0)
    ctx.strokeStyle=c.accent;ctx.lineWidth=18;ctx.strokeText(glyph,0,0);ctx.restore()
    ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.globalAlpha=.42
    for(let i=3;i>=1;i--){ctx.strokeStyle=c.accent;ctx.lineWidth=9;for(const line of s.title)ctx.strokeText(line.text,line.x-i*(12+swing*5),line.y+i*17)}
  }
  ctx.restore();heading(ctx,s,Math.max(8,s.size*.035))
}

export function interference(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles,motion=strength[s.recipe.motion.amount],n={low:42,medium:59,high:76}[s.recipe.shape.density]
  ctx.save();ctx.strokeStyle=c.ink;ctx.lineWidth=3.6
  if(comp==='concentric'){
    const cx=w*.57+Math.sin(phase)*w*.07*motion,cy=h*.41+Math.cos(phase)*h*.045*motion
    for(let i=0;i<n;i++){
      const radius=26+i*w*.017,distortion=1+Math.sin(i*.21+phase)*.04*motion
      ctx.globalAlpha=i%9===0?.87:.4;ctx.strokeStyle=i%9===0?c.accent:c.ink
      ctx.beginPath();ctx.ellipse(cx,cy,radius*distortion,radius*(s.recipe.format==='portrait'?1.34:.9),-.18,0,TAU);ctx.stroke()
    }
  }else if(comp==='wavefield'){
    for(let i=0;i<n;i++){
      const y=h*(-.08+i*1.16/n);ctx.beginPath()
      for(let j=0;j<=48;j++){
        const x=w*(-.1+j*1.2/48),focus=Math.exp(-Math.pow((x/w-.51)*2.4,2))
        const bend=Math.sin(x/w*TAU*1.35+i*.14+phase)*h*.075*focus*motion
        if(j===0)ctx.moveTo(x,y+bend);else ctx.lineTo(x,y+bend)
      }
      ctx.strokeStyle=i%11===0?c.accent:c.ink;ctx.globalAlpha=i%11===0?.95:.47;ctx.stroke()
    }
  }else{
    const cx=w*.5+Math.sin(phase)*w*.055*motion,cy=h*.48
    for(let i=n;i>=1;i--){
      const t=i/n,size=w*(.1+t*1.2),lean=Math.sin(phase+i*.12)*w*.045*motion
      ctx.beginPath();ctx.moveTo(cx-size*.55+lean,cy-size*.58)
      ctx.lineTo(cx+size*.58+lean,cy-size*.48)
      ctx.lineTo(cx+size*.52-lean,cy+size*.57)
      ctx.lineTo(cx-size*.56-lean,cy+size*.47);ctx.closePath()
      ctx.strokeStyle=i%10===0?c.accent:c.ink;ctx.globalAlpha=i%10===0?.85:.36;ctx.stroke()
    }
  }
  ctx.restore();heading(ctx,s,Math.max(26,s.size*.27))
}

type Particle={x:number;y:number;phase:number;index:number}
const particleCache=new WeakMap<Scene,Particle[]>()
function particles(s:Scene){
  const found=particleCache.get(s);if(found)return found
  const w=s.width,h=s.height,scale=.5,canvas=document.createElement('canvas');canvas.width=w*scale;canvas.height=h*scale
  const ctx=canvas.getContext('2d',{willReadFrequently:true})!
  const glyph=[...new Intl.Segmenter('ja',{granularity:'grapheme'}).segment(s.recipe.brief.title.replace(/\s/g,''))].map(x=>x.segment).find(x=>/[^。、，．！？]/u.test(x))??'A'
  const size=Math.round(w*.75*scale)
  ctx.font=`700 ${size}px "Noto Sans JP"`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle='#fff'
  ctx.fillText(glyph,canvas.width*.5,canvas.height*(s.recipe.format==='portrait'?.32:.34))
  const data=ctx.getImageData(0,0,canvas.width,canvas.height).data,step={low:15,medium:12,high:10}[s.recipe.shape.density],result:Particle[]=[]
  for(let y=step;y<canvas.height*.63;y+=step)for(let x=step;x<canvas.width-step;x+=step){
    if(data[(Math.floor(y)*canvas.width+Math.floor(x))*4+3]<120)continue
    const index=result.length,phase=((Math.imul(x|0,73856093)^Math.imul(y|0,19349663)^s.recipe.shape.seed)>>>0)/4294967296*TAU
    result.push({x:x/scale,y:y/scale,phase,index})
  }
  particleCache.set(s,result);return result
}
export function scatter(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles,motion=strength[s.recipe.motion.amount],list=particles(s)
  const centerX=w*.5,centerY=h*(s.recipe.format==='portrait'?.32:.34)
  ctx.save()
  for(const p of list){
    const radial=Math.atan2(p.y-centerY,p.x-centerX)
    let dx=0,dy=0
    if(comp==='cloud'){const swell=Math.sin(phase+p.phase*.4)-Math.sin(p.phase*.4);dx=Math.cos(radial)*swell*w*.057*motion;dy=Math.sin(radial)*swell*w*.057*motion}
    else if(comp==='fracture'){const shift=Math.sin(phase)*w*.105*motion;dx=(p.x<centerX?-1:1)*shift;dy=Math.sin(p.phase)*shift*.42}
    else {const flow=(Math.sin(phase-p.y/h*TAU*2)-Math.sin(-p.y/h*TAU*2))*w*.065*motion;dx=flow;dy=Math.sin(phase+p.x/w*TAU)*w*.018*motion}
    const size=p.index%13===0?14:9
    ctx.fillStyle=p.index%13===0?c.accent:p.index%5===0?c.surface:c.ink
    ctx.globalAlpha=p.index%5===0?.76:.94
    ctx.fillRect(p.x+dx-size/2,p.y+dy-size/2,size,size)
  }
  ctx.restore();heading(ctx,s,Math.max(24,s.size*.21))
}
