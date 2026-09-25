import type { Scene } from './layout'
import { fontString } from './layout'
import { current, lattice, glyph } from './expressive'
import { monolith, interference, scatter } from './editorial'
const TAU=Math.PI*2
const level={calm:.55,normal:1,bold:1.45}
function title(ctx:CanvasRenderingContext2D,s:Scene,color:string,shift=0) {
  ctx.fillStyle=color;ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.textBaseline='alphabetic'
  s.title.forEach((line,i)=>ctx.fillText(line.text,line.x,line.y+shift*Math.sin(i+1)))
}
function subtitle(ctx:CanvasRenderingContext2D,s:Scene) {
  ctx.fillStyle=s.recipe.color.ink;ctx.font=`400 ${s.subtitleSize}px "Noto Sans JP"`;ctx.textAlign='left';ctx.textBaseline='alphabetic'
  s.subtitle.forEach(line=>ctx.fillText(line.text,line.x,line.y))
}
function pathBand(s:Scene,index:number,n:number,u:number):Path2D {
  const p=new Path2D(), w=s.width,h=s.height, comp=s.recipe.shape.composition
  const motion=level[s.recipe.motion.amount],phase=(index/n)*TAU+(s.recipe.motion.seed%67)/67
  const drift=Math.sin(TAU*u*s.recipe.motion.cycles+phase)*w*.035*motion
  const pts:[number,number][]=[]
  for(let j=0;j<=48;j++) {
    const t=j/48, wave=Math.sin(t*TAU*1.5+TAU*u+phase)*w*.012*motion
    if(comp==='sweep')pts.push([-w*.15+t*w*1.3,h*.82-t*h*.6+(index-(n-1)/2)*w*.026+wave+drift])
    else if(comp==='arch') { const x=w*.07+t*w*.86;pts.push([x,h*.52-(Math.sin(t*Math.PI)*h*.28)+(index-(n-1)/2)*w*.025+wave+drift]) }
    else { const side=index<n/2?-.1:1.1;const k=index<n/2?index:index-n/2;pts.push([w*(side+(side<0?1:-1)*k*.035)+wave+drift,t*h*1.2-h*.1]) }
  }
  const half=4+(s.recipe.shape.density==='high'?3:s.recipe.shape.density==='medium'?2:0)
  const sides=pts.map(([x,y],i)=>{const before=pts[Math.max(0,i-1)],after=pts[Math.min(pts.length-1,i+1)],dx=after[0]-before[0],dy=after[1]-before[1],length=Math.hypot(dx,dy)||1;return{x,y,nx:-dy/length*half,ny:dx/length*half}})
  p.moveTo(sides[0].x+sides[0].nx,sides[0].y+sides[0].ny)
  for(const point of sides)p.lineTo(point.x+point.nx,point.y+point.ny)
  for(const point of sides.reverse())p.lineTo(point.x-point.nx,point.y-point.ny)
  p.closePath();return p
}
function weave(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const n={low:8,medium:14,high:20}[s.recipe.shape.density], c=s.recipe.color
  for(let i=0;i<n;i++){const p=pathBand(s,i,n,u);ctx.fillStyle=i%3===0?c.accent:c.surface;ctx.fill(p)}
  title(ctx,s,c.ink,Math.sin(u*TAU)*s.size*.025)
  for(let i=0;i<n;i+=3) {ctx.save();ctx.clip(pathBand(s,i,n,u));title(ctx,s,c.bg,Math.sin(u*TAU)*s.size*.025);ctx.restore()}
  subtitle(ctx,s)
}
function panel(ctx:CanvasRenderingContext2D,x:number,y:number,w:number,h:number,color:string,angle=0) {
  ctx.save();ctx.translate(x+w/2,y+h/2);ctx.rotate(angle);ctx.fillStyle=color;ctx.fillRect(-w/2,-h/2,w,h);ctx.restore()
}
function fold(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const q=(1-Math.cos(TAU*u*s.recipe.motion.cycles))/2*level[s.recipe.motion.amount]
  const n={low:3,medium:4,high:5}[s.recipe.shape.density]
  const x=w*.08,y=comp==='stack'?h*.18:comp==='gate'?h*.24:h*.22,pw=w*.84,ph=h*.57
  if(comp==='fan')for(let i=n-1;i>=0;i--)panel(ctx,x+i*24,y-i*18,pw*.91,ph,i%2?c.accent:c.surface,-.12+i*.045+q*Math.min((i+1)*.07,.35))
  if(comp==='gate'){panel(ctx,-w*.04,y-h*.04,w*.42,ph+h*.07,c.accent,-.09-q*.22);panel(ctx,w*.63,y-h*.04,w*.42,ph+h*.07,c.surface,.09+q*.22)}
  if(comp==='stack')for(let i=n-1;i>=0;i--)panel(ctx,x+i*28,y+i*27,pw,ph,i%2?c.accent:c.surface,q*Math.min((i+1)*.05,.35)+(s.recipe.shape.tilt*Math.PI/180)*.2)
  ctx.fillStyle=c.ink;ctx.fillRect(x+10,y+14,pw,ph)
  const angle=(q*.035)*(comp==='gate'?-1:1)
  ctx.save();ctx.translate(w/2,h*.5);ctx.rotate(angle);ctx.scale(1-q*.04,1);ctx.translate(-w/2,-h*.5)
  ctx.fillStyle=c.ink;ctx.fillRect(x,y,pw,ph)
  title(ctx,s,c.bg);ctx.restore();subtitle(ctx,s)
}
function tile(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const c=s.recipe.color,w=s.width,rows=s.recipe.format==='square'?6:10,cell=w/6
  const count={low:8,medium:12,high:16}[s.recipe.shape.density],comp=s.recipe.shape.composition
  const cells:[number,number][]=[]
  if(comp==='frame'){for(let col=0;col<6;col++)cells.push([0,col]);for(let col=0;col<6;col++)cells.push([rows-1,col]);for(let row=1;row<rows-1;row++){cells.push([row,0],[row,5])}}
  if(comp==='corner'){for(let row=0;row<3;row++)for(let col=0;col<3;col++)cells.push([row,col]);for(let row=rows-3;row<rows;row++)for(let col=3;col<6;col++)cells.push([row,col])}
  if(comp==='columns'){for(let row=0;row<rows;row++){cells.push([row,0],[row,5])}for(let row=0;row<rows;row++){cells.push([row,1],[row,4])}}
  let used=0
  for(const [row,col] of cells){if(used>=count)break
    const x=col*cell,y=row*cell; if(x<s.titleBox.x+s.titleBox.width+20&&x+cell>s.titleBox.x-20&&y<s.titleBox.y+s.titleBox.height+30&&y+cell>s.titleBox.y-20)continue
    const k=used%3,phase=(row+col+(s.recipe.shape.seed%7))/4
    const shift=Math.sin(TAU*u*s.recipe.motion.cycles+phase)*cell*.2*level[s.recipe.motion.amount]
    ctx.save();ctx.beginPath();ctx.rect(x+5,y+5,cell-10,cell-10);ctx.clip()
    ctx.fillStyle=(row+col)%2?c.surface:c.accent;ctx.fillRect(x+5,y+5,cell-10,cell-10)
    ctx.fillStyle=c.bg
    if(k===0){ctx.beginPath();ctx.arc(x+cell*.5+shift,y+cell*.5,cell*.31,0,TAU);ctx.fill()}
    else if(k===1){ctx.fillRect(x+cell*.24+shift,y+cell*.23,cell*.52,cell*.52)}
    else {const chars=[...s.recipe.brief.title.replace(/\n/g,'')];ctx.font=fontString(s.recipe,cell*.95);ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(chars[used%chars.length],x+cell*.5+shift,y+cell*.52)}
    ctx.restore();used++
  }
  title(ctx,s,c.ink,Math.sin(TAU*u)*s.size*.015);subtitle(ctx,s)
}
function slice(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const c=s.recipe.color,w=s.width,h=s.height,b=s.titleBox,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles, amplitude=level[s.recipe.motion.amount]
  const travel=(1-Math.cos(phase))/2
  ctx.fillStyle=c.surface
  if(comp==='slit'){ctx.fillRect(0,h*.14,w*.62,18);ctx.fillRect(w*.42,h*.74,w*.58,24)}
  if(comp==='steps'){for(let i=0;i<4;i++)ctx.fillRect(w*(.07+i*.11),h*(.16+i*.055),w*.37,18)}
  if(comp==='split'){ctx.fillRect(w*.69,0,w*.09,h*.82);ctx.fillStyle=c.accent;ctx.fillRect(w*.79,h*.14,w*.025,h*.68)}
  ctx.fillStyle=c.accent
  ctx.fillRect(w*.08,h*.12,Math.max(7,w*.012),h*.14)
  ctx.fillRect(w*.08,h*.79,w*.84,Math.max(5,w*.008))
  title(ctx,s,c.ink)
  const count={low:2,medium:3,high:4}[s.recipe.shape.density]
  for(let i=0;i<count;i++){
    const gap=(i-(count-1)/2),move=(gap*w*.006+(i%2?1:-1)*travel*w*.12)*amplitude
    let x:number,y:number,bw:number,bh:number
    if(comp==='split'){x=w*(.29+i*.115);y=b.y-18;bw=w*.085;bh=b.height+36}
    else if(comp==='steps'){x=w*(.09+i*.16);y=b.y+b.height*(i+.25)/(count+1)+Math.sin(phase+i*.85)*s.size*.16*amplitude;bw=w*.55;bh=s.size*.28}
    else{x=w*.06;y=b.y+b.height*(i+.7)/(count+1)+Math.sin(phase+i*.85)*s.size*.16*amplitude;bw=w*.88;bh=s.size*.27}
    ctx.save();ctx.beginPath();ctx.rect(x,y,bw,bh);ctx.clip()
    ctx.globalAlpha=.18;ctx.fillStyle=c.surface;ctx.fillRect(x,y,bw,bh)
    ctx.translate(comp==='split'?move*.55:move,comp==='split'?0:gap*3)
    ctx.globalAlpha=.92;title(ctx,s,c.accent)
    ctx.restore()
    ctx.fillStyle=i%2===0?c.accent:c.ink
    if(comp==='split')ctx.fillRect(x,y,7,bh)
    else ctx.fillRect(x,y+bh-7,Math.min(bw*.23,w*.13),7)
  }
  subtitle(ctx,s)
}
function orbit(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles,amount=level[s.recipe.motion.amount],travel=(1-Math.cos(phase))/2
  const discs=comp==='halo'?[[w*.51,h*.45,w*.34]]:comp==='eclipse'?[[w*.81,h*.34,w*.39]]:[[w*.24,h*.25,w*.25],[w*.78,h*.68,w*.29]]
  ctx.lineWidth=13;ctx.strokeStyle=c.surface
  for(let i=0;i<discs.length;i++){
    const [baseX,baseY,radius]=discs[i],x=baseX+(i%2?1:-1)*travel*w*.026*amount,y=baseY+travel*w*.018*amount
    ctx.fillStyle=i%2===0?c.surface:c.accent;ctx.beginPath();ctx.arc(x,y,radius,0,TAU);ctx.fill()
    ctx.strokeStyle=c.accent;ctx.lineWidth=10
    for(let ring=0;ring<2;ring++){const angle=phase*(ring%2?-1:1)+ring*1.7;ctx.beginPath();ctx.arc(x,y,radius+w*(.055+ring*.06),angle,angle+Math.PI*1.25);ctx.stroke()}
    ctx.save();ctx.beginPath();ctx.arc(x,y,radius,0,TAU);ctx.clip();title(ctx,s,i%2===0?c.ink:c.bg);ctx.restore()
  }
  title(ctx,s,c.ink)
  for(let i=0;i<discs.length;i++){
    const [baseX,baseY,radius]=discs[i],x=baseX+(i%2?1:-1)*travel*w*.026*amount,y=baseY+travel*w*.018*amount
    ctx.save();ctx.beginPath();ctx.arc(x,y,radius,0,TAU);ctx.clip();title(ctx,s,i%2===0?c.ink:c.bg);ctx.restore()
  }
  ctx.fillStyle=c.accent;ctx.fillRect(w*.1,h*.82,w*.24,10)
  subtitle(ctx,s)
}
function echo(ctx:CanvasRenderingContext2D,s:Scene,u:number) {
  const c=s.recipe.color,w=s.width,h=s.height,comp=s.recipe.shape.composition
  const phase=TAU*u*s.recipe.motion.cycles,amount=level[s.recipe.motion.amount]
  ctx.font=fontString(s.recipe,s.size);ctx.textAlign=s.recipe.type.align;ctx.textBaseline='alphabetic';ctx.lineJoin='round'
  if(comp==='mirror'){
    const axis=s.titleBox.y+s.titleBox.height+26
    ctx.save();ctx.translate(Math.sin(phase)*w*.055*amount,axis*2+(1-Math.cos(phase))*h*.04*amount);ctx.scale(1,-1)
    ctx.globalAlpha=.34;title(ctx,s,c.accent)
    ctx.globalAlpha=.22;ctx.strokeStyle=c.ink;ctx.lineWidth=6
    for(const line of s.title)ctx.strokeText(line.text,line.x,line.y)
    ctx.restore()
    ctx.fillStyle=c.accent;ctx.fillRect(w*.1,axis,w*.8,8)
    title(ctx,s,c.ink);subtitle(ctx,s);return
  }
  const count={low:3,medium:5,high:7}[s.recipe.shape.density]
  const breathe=(1-Math.cos(phase))/2
  for(let layer=count;layer>=1;layer--){
    const spread=layer*w*(.01+.025*breathe)*amount,drift=Math.sin(phase+layer*.42)*w*.02*amount
    ctx.strokeStyle=layer%2?c.accent:c.surface;ctx.globalAlpha=(.23+breathe*.29)*(1-layer/count*.23);ctx.lineWidth=Math.max(2,8-layer*.6)
    for(const line of s.title){
      if(comp==='burst'){
        const theta=layer*2.4+(s.recipe.shape.seed%11)*.12+Math.sin(phase)*.22
        ctx.strokeText(line.text,line.x+Math.cos(theta)*spread+drift,line.y+Math.sin(theta)*spread)
      }else ctx.strokeText(line.text,line.x+spread*.75+drift,line.y+spread*.55)
    }
  }
  ctx.globalAlpha=1
  if(comp==='burst'){ctx.fillStyle=c.accent;ctx.fillRect(w*.72,h*.12,w*.14,16)}
  else {ctx.fillStyle=c.accent;ctx.fillRect(w*.1,h*.13,w*.23,12)}
  title(ctx,s,c.ink)
  subtitle(ctx,s)
}
export function drawScene(ctx:CanvasRenderingContext2D,s:Scene,timeSeconds:number,outputWidth:number) {
  const outputHeight=Math.round(outputWidth*s.height/s.width)
  ctx.save();ctx.setTransform(outputWidth/s.width,0,0,outputHeight/s.height,0,0)
  ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.fillStyle=s.recipe.color.bg;ctx.fillRect(0,0,s.width,s.height)
  const u=((timeSeconds/6)%1+1)%1
  if(s.recipe.family==='weave')weave(ctx,s,u)
  else if(s.recipe.family==='fold')fold(ctx,s,u)
  else if(s.recipe.family==='tile')tile(ctx,s,u)
  else if(s.recipe.family==='slice')slice(ctx,s,u)
  else if(s.recipe.family==='orbit')orbit(ctx,s,u)
  else if(s.recipe.family==='echo')echo(ctx,s,u)
  else if(s.recipe.family==='current')current(ctx,s,u)
  else if(s.recipe.family==='lattice')lattice(ctx,s,u)
  else if(s.recipe.family==='glyph')glyph(ctx,s,u)
  else if(s.recipe.family==='monolith')monolith(ctx,s,u)
  else if(s.recipe.family==='interference')interference(ctx,s,u)
  else scatter(ctx,s,u)
  ctx.restore()
}
