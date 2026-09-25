import { fontString, type Scene } from './layout'

const TAU=Math.PI*2
const amount={calm:.55,normal:1,bold:1.45}
const density={low:.72,medium:1,high:1.24}
const wave=(u:number,phase=0)=>Math.sin(TAU*u+phase)

function text(ctx:CanvasRenderingContext2D,s:Scene,stroke=0){
  const c=s.recipe.color
  ctx.save();ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.textBaseline='alphabetic';ctx.lineJoin='round'
  if(stroke){ctx.strokeStyle=c.bg;ctx.lineWidth=stroke;for(const line of s.title)ctx.strokeText(line.text,line.x,line.y)}
  ctx.fillStyle=c.ink;for(const line of s.title)ctx.fillText(line.text,line.x,line.y)
  ctx.restore()
  if(!s.subtitle.length)return
  ctx.save();ctx.font=`400 ${s.subtitleSize}px "Noto Sans JP"`;ctx.textAlign='left';ctx.textBaseline='alphabetic'
  for(const line of s.subtitle){ctx.fillStyle=c.bg;ctx.fillRect(line.x-12,line.y-s.subtitleSize-7,line.width+24,s.subtitleSize+21);ctx.fillStyle=c.ink;ctx.fillText(line.text,line.x,line.y)}
  ctx.restore()
}

function ribbon(ctx:CanvasRenderingContext2D,w:number,y:number,thickness:number,amp:number,phase:number,color:string){
  const p=new Path2D(),steps=36
  for(let i=0;i<=steps;i++){
    const x=-w*.18+i/steps*w*1.36
    const bend=Math.sin(x/w*TAU*1.1+phase)*amp+Math.sin(x/w*TAU*.53-phase)*amp*.43
    const py=y+bend
    if(i===0)p.moveTo(x,py);else p.lineTo(x,py)
  }
  for(let i=steps;i>=0;i--){
    const x=-w*.18+i/steps*w*1.36
    const bend=Math.sin(x/w*TAU*1.1+phase)*amp+Math.sin(x/w*TAU*.53-phase)*amp*.43
    p.lineTo(x,y+thickness+bend)
  }
  p.closePath();ctx.fillStyle=color;ctx.fill(p)
}

export function current(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const cycle=s.recipe.motion.cycles,shift=wave(u*cycle)*w*.018*amount[s.recipe.motion.amount]
  const count=Math.round(7*density[s.recipe.shape.density])
  ctx.save()
  if(comp==='crossflow'){
    ctx.translate(w*.5,h*.5);ctx.rotate(-.29);ctx.translate(-w*.5,-h*.5)
    for(let i=0;i<count+3;i++){
      const y=h*(-.15+i*.125),amp=h*(.045+(i%3)*.006)
      ribbon(ctx,w,y+shift*.6,h*.073,amp,i*.29+u*TAU*cycle*(i%2?1:-1),i%5===2?c.accent:i%3===0?c.ink:c.surface)
    }
  }else if(comp==='columnflow'){
    ctx.translate(w*.5,h*.5);ctx.rotate(Math.PI/2);ctx.translate(-h*.5,-w*.5)
    for(let i=0;i<count+2;i++)ribbon(ctx,h,w*(.37+i*.092)+shift,w*.064,w*.045,i*.34+u*TAU*cycle*(i%2?1:-1),i%4===1?c.accent:i%5===0?c.ink:c.surface)
  }else{
    for(let i=0;i<count;i++){
      const top=i<count/2,y=top?h*(-.08+i*.105):h*(.68+(i-Math.floor(count/2))*.103)
      ribbon(ctx,w,y+shift*(top?1:-1),h*.073,h*.046,i*.37+u*TAU*cycle*(top?1:-1),i%4===2?c.accent:i%5===0?c.ink:c.surface)
    }
  }
  ctx.restore()
  text(ctx,s,Math.max(14,s.size*.085))
}

export function lattice(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const count=Math.round(68*density[s.recipe.shape.density])
  const phase=TAU*u*s.recipe.motion.cycles,extent=amount[s.recipe.motion.amount]
  ctx.save();ctx.lineWidth=2.6
  for(let i=0;i<count;i++){
    const t=i/(count-1),jitter=Math.sin(phase+t*TAU*.7)*w*.075*extent
    ctx.beginPath()
    if(comp==='stringfan'){
      ctx.moveTo(-w*.12,h*(.08+t*.83))
      ctx.bezierCurveTo(w*(.26+t*.38),h*(.09+t*.1)+jitter,w*(.72-t*.28),h*(.9-t*.1)-jitter,w*1.12,h*(.88-t*.82))
    }else if(comp==='lens'){
      const y=h*(-.04+t*1.08),focus=Math.sin(t*Math.PI)
      ctx.moveTo(-w*.12,y)
      ctx.bezierCurveTo(w*.31,y-h*.25*focus+jitter,w*.69,y+h*.25*focus-jitter,w*1.12,y)
    }else{
      const x=w*(-.05+t*1.1)
      ctx.moveTo(x,-h*.1)
      ctx.bezierCurveTo(x+w*(.33-t*.38)+jitter,h*.24,x-w*(.28-t*.33)-jitter,h*.74,x,h*1.1)
    }
    ctx.strokeStyle=i%11===0?c.accent:i%5===0?c.ink:c.surface
    ctx.globalAlpha=i%11===0?.9:i%5===0?.42:.75
    ctx.stroke()
  }
  ctx.restore()
  text(ctx,s,Math.max(14,s.size*.075))
}

function graphemes(title:string){return [...new Intl.Segmenter('ja',{granularity:'grapheme'}).segment(title.replace(/\s/g,''))].map(x=>x.segment)}
export function glyph(ctx:CanvasRenderingContext2D,s:Scene,u:number){
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const chars=graphemes(s.recipe.brief.title),step=w/(s.recipe.shape.density==='high'?16:s.recipe.shape.density==='low'?12:14)
  const columns=Math.ceil(w/step),rows=Math.ceil(h/step),drift=(1-Math.cos(TAU*u*s.recipe.motion.cycles))*.18*step*amount[s.recipe.motion.amount]
  ctx.save();ctx.font=`700 ${Math.round(step*.66)}px "Noto Sans JP"`;ctx.textAlign='center';ctx.textBaseline='middle'
  if(comp==='corona'){
    const rings=s.recipe.shape.density==='high'?5:s.recipe.shape.density==='low'?3:4
    const swing=Math.sin(TAU*u*s.recipe.motion.cycles)*amount[s.recipe.motion.amount]
    for(let ring=0;ring<rings;ring++){
      const slots=28+ring*12,rx=w*(.23+ring*.085),ry=h*(.2+ring*.075)
      for(let i=0;i<slots;i++){
        const a=TAU*i/slots+swing*(.28+ring*.04)*(ring%2?1:-1),x=w*.5+Math.cos(a)*rx,y=h*.48+Math.sin(a)*ry
        ctx.save();ctx.translate(x,y);ctx.rotate(a+Math.PI/2);ctx.globalAlpha=ring===rings-1?.7:.5;ctx.fillStyle=i%13===0?c.accent:c.surface;ctx.fillText(chars[(i+ring*7+s.recipe.shape.seed%chars.length)%chars.length],0,0);ctx.restore()
      }
    }
  }else for(let row=0;row<rows;row++)for(let col=0;col<columns;col++){
    const x=(col+.5)*step+drift*(row%2?1:-1),y=(row+.5)*step
    if(comp==='rift'&&y>s.titleBox.y-step*.52&&y<s.titleBox.y+s.titleBox.height+step*.32)continue
    const index=(row*7+col*11+s.recipe.shape.seed)%chars.length
    ctx.fillStyle=(row*13+col*3)%17===0?c.accent:c.surface
    ctx.globalAlpha=comp==='matrix'?.65:.86
    ctx.fillText(chars[index],x,y)
  }
  ctx.restore()
  text(ctx,s,Math.max(16,s.size*.095))
}
