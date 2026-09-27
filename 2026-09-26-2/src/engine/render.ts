import type { Project } from '../domain/project'
import { graphemes } from '../domain/project'
import { compile, sceneAt, type TimedScene, type Timeline } from './timeline'
import glyphs from './glyphs.json'
import { displayLines } from './text'
const TAU = Math.PI * 2
const clamp = (x: number) => Math.max(0, Math.min(1, x))
const mix = (a: number, b: number, u: number) => a + (b - a) * u
const ease = (x: number) => { const u = clamp(x); return u * u * (3 - 2 * u) }
const out = (x: number) => 1 - (1 - clamp(x)) ** 4
const spring = (x: number) => x <= 0 ? 0 : 1 - Math.exp(-8 * x) * Math.cos(10 * x)
const hash = (n: number) => { const v = Math.sin(n * 127.1 + 311.7) * 43758.5453; return v - Math.floor(v) }
const pointSeed = (s: string) => [...s].reduce((n,c) => (n * 31 + c.codePointAt(0)!) >>> 0, 0)
const hasJapanese = (s: string) => [...s].some(ch => (ch.codePointAt(0) ?? 0) > 127)
const colorMix=(a:string,b:string,u:number)=>{const aa=parseInt(a.slice(1),16),bb=parseInt(b.slice(1),16);return '#'+[16,8,0].map(shift=>Math.round(mix((aa>>shift)&255,(bb>>shift)&255,u)).toString(16).padStart(2,'0')).join('')}
export const fontCss = `@font-face{font-family:MotionLatin;src:url(__LATIN_FONT__) format('truetype');font-weight:300 700;font-display:block}@font-face{font-family:MotionJapanese;src:url(__JAPANESE_FONT__) format('woff2');font-weight:700;font-display:block}`
export function projectText(p: Project) { return p.name+' '+p.scenes.map(s => [s.content.headline, s.content.secondary, ...s.content.items].join(' ')).join(' ') }
export async function prepareFonts(p: Project): Promise<void> {
  const text = projectText(p)
  await Promise.all([document.fonts.load('700 100px MotionLatin', text), document.fonts.load('700 100px MotionJapanese', text)])
  await document.fonts.ready
}
const glyphSet = new Set<number>(glyphs)
export function unsupportedGlyphs(p: Project): string[] { return [...new Set([...projectText(p)].filter(c => c !== '\n' && !glyphSet.has(c.codePointAt(0)!)))] }
interface Pt { x: number; y: number }
export class Renderer {
  readonly timeline: Timeline
  private canvas: HTMLCanvasElement
  private g: CanvasRenderingContext2D
  private p: Project
  private W: number
  private H: number
  private clouds = new Map<string, Pt[]>()
  private stars: { a: number; r: number; z: number; x: number; y: number }[]
  constructor(canvas: HTMLCanvasElement, project: Project) {
    this.canvas = canvas; this.p = project; this.timeline = compile(project)
    this.W = project.aspect === 'portrait' ? 1080 : 1920
    this.H = project.aspect === 'portrait' ? 1920 : 1080
    const g = canvas.getContext('2d', { alpha: false })
    if (!g) throw new Error('Canvas 2Dが使えません')
    this.g = g
    this.stars = Array.from({ length: 650 }, (_, i) => ({ a: hash(i + project.seed) * TAU, r: 30 + hash(i + 41 + project.seed) * this.W, z: hash(i + 811 + project.seed), x: hash(i + 11 + project.seed) * this.W, y: hash(i + 401 + project.seed) * this.H }))
  }
  dispose() { this.clouds.clear() }
  private bg(c: string) { this.g.fillStyle = c; this.g.fillRect(0,0,this.W,this.H) }
  private disk(x: number,y: number,r: number,c: string) { if(r<=0)return;const g=this.g;g.fillStyle=c;g.beginPath();g.arc(x,y,r,0,TAU);g.fill() }
  private ring(x:number,y:number,r:number,c:string,w=2,a=1) { const g=this.g;g.save();g.globalAlpha*=a;g.strokeStyle=c;g.lineWidth=w;g.beginPath();g.arc(x,y,r,0,TAU);g.stroke();g.restore() }
  private line(x:number,y:number,x2:number,y2:number,c:string,w=2,a=1) { const g=this.g;g.save();g.globalAlpha*=a;g.strokeStyle=c;g.lineWidth=w;g.beginPath();g.moveTo(x,y);g.lineTo(x2,y2);g.stroke();g.restore() }
  private font(s:string,size:number) { return `700 ${size}px ${hasJapanese(s) ? 'MotionJapanese, sans-serif' : 'MotionLatin, sans-serif'}` }
  private txt(s:string,x:number,y:number,size:number,c:string,maxW=this.W*.88,align:CanvasTextAlign='center',stroke=false) {
    const g=this.g;g.save();g.font=this.font(s,size);g.textAlign=align;g.textBaseline='middle';g.fillStyle=c;g.strokeStyle=c;g.lineWidth=2
    const lines=s.split('\n');const lineH=size*1.18
    lines.forEach((line,i)=>{const width=g.measureText(line).width;const scale=Math.min(1,maxW/Math.max(1,width));g.save();g.translate(x,y+(i-(lines.length-1)/2)*lineH);g.scale(scale,1);if(stroke)g.strokeText(line,0,0);else g.fillText(line,0,0);g.restore()});g.restore()
  }
  private cloud(key:string,s:string,size:number,maxW:number): Pt[] {
    const cached=this.clouds.get(key);if(cached)return cached
    const canvas=document.createElement('canvas');canvas.width=Math.ceil(this.W/2);canvas.height=Math.ceil(this.H/2)
    const g=canvas.getContext('2d',{willReadFrequently:true})!;g.scale(.5,.5);g.font=this.font(s,size);g.textAlign='center';g.textBaseline='middle';const lines=displayLines(s,this.p.aspect),w=Math.max(...lines.map(line=>g.measureText(line).width));g.translate(this.W/2,this.H/2);g.scale(Math.min(1,maxW/w),1);lines.forEach((line,i)=>g.fillText(line,0,(i-(lines.length-1)/2)*size*1.05))
    const data=g.getImageData(0,0,canvas.width,canvas.height).data;const pts:Pt[]=[]
    for(let y=30;y<canvas.height-30;y+=5)for(let x=25;x<canvas.width-25;x+=5)if(data[(y*canvas.width+x)*4+3]>140)pts.push({x:x*2,y:y*2})
    this.clouds.set(key,pts);return pts
  }
  private particles(key:string,s:string,size:number,maxW:number,u:number,t:number,c:string,intensity=1,mode:'assemble'|'disperse'='assemble') {
    const g=this.g, pts=this.cloud(key,s,size,maxW),seed=pointSeed(key)+this.p.seed
    g.fillStyle=c
    const p=ease(u)
    const stride=intensity<.34?3:intensity<.67?2:1
    for(let i=0;i<pts.length;i+=stride){const pt=pts[i],a=hash(i+seed)*TAU,r=100+hash(i+seed+9)*this.W*(.28+.37*intensity);const sx=this.W/2+Math.cos(a+t*.4)*r,sy=this.H/2+Math.sin(a+t*.4)*r*.65;const k=mode==='assemble'?p:1-p;g.globalAlpha=.3+.7*k;g.fillRect(mix(sx,pt.x,k),mix(sy,pt.y,k),this.W/1920*3+1,this.W/1920*3+1)}g.globalAlpha=1
  }
  private kinetic(s:string,y:number,size:number,progress:number,c:string,focus=-1) {
    if(s.includes('\n')){const lines=s.split('\n');let offset=0;lines.forEach((line,i)=>{this.kinetic(line,y+(i-(lines.length-1)/2)*size*.62,size*.62,progress,c,focus-offset);offset+=graphemes(line).length});return}
    const gs=graphemes(s),g=this.g;g.save();g.font=this.font(s,size);const widths=gs.map(ch=>g.measureText(ch).width);const full=widths.reduce((n,w)=>n+w,0);g.translate(this.W/2,y);g.scale(Math.min(1,this.W*.88/Math.max(1,full)),1)
    let x=-full/2
    gs.forEach((ch,i)=>{const w=widths[i],p=i===focus?1:spring(Math.max(0,progress-i*.055)*1.7),d=1-p;g.save();g.translate(x+w/2,d*(i%2?-this.H*.38:this.H*.38));g.rotate(d*(i%2?.15:-.15));g.scale(1+Math.abs(d)*.65,Math.max(.05,1-d*.7));this.txt(ch,0,0,size,c,w*1.1);g.restore();x+=w});g.restore()
  }
  private field(t:number,a=.5) { const g=this.g;g.save();for(let i=0;i<this.stars.length;i+=2){const s=this.stars[i];g.globalAlpha=a*(.3+.7*s.z);this.disk((s.x+t*8*s.z)%this.W,s.y,1+s.z*1.8,this.p.palette.paper)}g.restore() }
  private star(x:number,y:number,r:number,rotation=0,c=this.p.palette.paper) { const g=this.g;g.save();g.translate(x,y);g.rotate(rotation);g.beginPath();for(let i=0;i<8;i++){const a=i*Math.PI/4,rr=i%2?r*.14:r;g.lineTo(Math.cos(a)*rr,Math.sin(a)*rr)}g.closePath();g.fillStyle=c;g.fill();g.restore() }
  private moon(x:number,y:number,r:number,phase:number,c:string,b:string){const g=this.g;this.disk(x,y,r,c);g.save();g.beginPath();g.arc(x,y,r,0,TAU);g.clip();this.disk(x+r*phase,y-r*.08,r*.99,b);g.restore()}
  private orbit(t:number,c:string,r:number,a=1){const g=this.g;g.save();g.strokeStyle=c;g.lineWidth=2;g.globalAlpha=a;for(let n=0;n<3;n++){g.beginPath();for(let i=0;i<=120;i++){const angle=i/120*TAU,tilt=n*Math.PI/3+t*.22,x=Math.cos(angle)*r,y=Math.sin(angle)*r,z=y*Math.sin(tilt),yy=y*Math.cos(tilt),xx=x*Math.cos(t*.18)-z*Math.sin(t*.18),zz=x*Math.sin(t*.18)+z*Math.cos(t*.18),p=1100/(1100+zz),px=this.W/2+xx*p,py=this.H/2+yy*p;if(i)g.lineTo(px,py);else g.moveTo(px,py)}g.stroke()}g.restore()}
  private meta(t:number,item:TimedScene,dark=false) { const c=dark?this.p.palette.ink:this.p.palette.paper;const W=this.W,H=this.H;this.txt(this.p.name,45,55,24,c,W*.55,'left');this.txt(`${String(item.index+1).padStart(2,'0')} / ${item.scene.motion.kind.toUpperCase()}`,W-45,55,20,c,W*.4,'right');this.line(45,H-88,W-45,H-88,c,2,.35);this.line(45,H-88,45+(W-90)*t/this.timeline.total,H-88,c,4,.9);this.txt(`${t.toFixed(1)} / ${this.timeline.total.toFixed(1)} SEC`,W-45,H-48,19,c,W*.4,'right') }
  private drawScene(item:TimedScene,t:number,skipSharedCircle=false) {
    const {scene}=item,p=this.p.palette,W=this.W,H=this.H,g=this.g,portrait=this.p.aspect==='portrait',q=clamp((t-item.start)/item.duration),headline=scene.content.headline,secondary=scene.content.secondary,intensity=scene.motion.intensity
    const size=portrait?Math.min(270,250*scene.typography.scale):Math.min(540,500*scene.typography.scale)
    const cx=W/2,cy=H/2
    switch(scene.motion.kind){
      case 'impact-type': {
        const words=scene.content.items
        if(q<.24){this.bg(p.paper);g.save();g.translate(cx,cy);g.scale(1,Math.max(.55,ease(q/.18)));this.txt(words[0],0,0,size,p.ink);g.restore();this.txt(secondary,cx,H*.78,24,p.ink);this.meta(t,item,true)}
        else if(q<.5){this.bg(p.accent);this.kinetic(words[1]??words[0],cy,size*.9,(q-.24)*4+.1,p.paper);this.line(W*.07,H*.76,W*(.07+.86*out((q-.24)*4)),H*.76,p.paper,5)}
        else {this.bg(p.ink);this.field(t,.22);const next=this.p.scenes[item.index+1];const word=scene.motion.anticipateNext&&next?next.content.headline:headline;this.particles(scene.id+'-next',word,size*.92,W*.88,(q-.5)*2,t,p.paper,intensity);if(q>.84)this.txt(word,cx,cy,size*.92,p.paper);this.txt(secondary,cx,H*.8,22,p.paper)}break
      }
      case 'particle-flight': {
        if(q<.52){this.bg(p.accent);const push=out((q-.32)/.2)*(2+2*scene.motion.depth);g.save();g.translate(cx,cy);g.scale(1+push,1+push);g.translate(-cx,-cy);this.particles(scene.id,headline,size,W*.87,q/.2,t,p.paper,intensity);if(q>.18)this.kinetic(displayLines(headline,this.p.aspect).join('\n'),cy,size,q*2,p.paper);g.restore();if(q<.35)this.txt(secondary,W*.08,H*.78,22,p.paper,W*.7,'left')}
        else {this.bg(p.ink);const travel=(q-.52)/.48;for(const s of this.stars){const z=.12+((s.z+travel*.9)%1)*2.4,r=1/z,a=s.a+travel*.1,x=cx+Math.cos(a)*s.r*r,y=cy+Math.sin(a)*s.r*r,stretch=1+.12/z;this.line(x,y,cx+(x-cx)*stretch,cy+(y-cy)*stretch,s.z>.9?p.secondary:p.paper,1+r*.7,clamp(1-z/2.6))}for(let i=0;i<7;i++){const u=(i/7+travel*.7)%1;this.ring(cx,cy,70+W*.8*u*u,p.accent,2,.5*(1-u))}const exit=out((travel-.78)/.22);this.disk(cx,cy,14+exit*W*.12,p.secondary);this.star(cx,cy,30+exit*W*.08,travel,p.secondary)}break
      }
      case 'radial-pulse': {
        const R=Math.min(W,H)*(portrait?.19:.23);const sunRays=(r:number,outer:number,a:number)=>{for(let i=0;i<80;i++){const angle=i/80*TAU+t*.16;this.line(cx+Math.cos(angle)*r,cy+Math.sin(angle)*r,cx+Math.cos(angle)*outer,cy+Math.sin(angle)*outer,p.ink,i%4?2:5,a)}}
        if(q<.34){this.bg(p.secondary);sunRays(R*1.1,R*3,.2);const enter=spring(q*5);g.save();g.translate(cx,cy);g.scale(1,Math.max(.1,enter));this.disk(0,0,R,p.ink);this.disk(0,0,R*.65,p.secondary);g.restore();const letters=graphemes(headline);if(!portrait&&scene.motion.focusGrapheme!==null&&letters[scene.motion.focusGrapheme]==='O'&&letters.length===3){this.txt(letters[0],cx-R*2.45,cy,size*.9,p.ink,R*1.8);this.txt(letters[2],cx+R*2.45,cy,size*.9,p.ink,R*1.8)}else this.txt(displayLines(headline,this.p.aspect).join('\n'),cx,portrait?cy+R*2.8:cy+R*2.15,size*.72,p.ink,W*.84);this.txt(secondary,cx,H*.83,22,p.ink)}
        else if(q<.68){this.bg(p.secondary);const zoom=out((q-.56)/.12);g.save();g.translate(cx,cy);g.scale(1+zoom*2.8,1+zoom*2.8);g.translate(-cx,-cy);for(let k=0;k<7;k++)this.ring(cx,cy,R*.8+k*R*.25+20*Math.sin(t*3-k*.65),k%2?p.ink:p.paper,k%2?17:5,.9);this.disk(cx,cy,R*.7,p.ink);this.star(cx,cy,R*.45,t*.35,p.paper);sunRays(R*2.4,R*3.4,.85);g.restore()}
        else {const u=(q-.68)/.32,change=ease((u-.7)/.3),back=colorMix(p.ink,p.accent,change);this.bg(back);if(!skipSharedCircle){this.disk(cx,cy,R*1.5,colorMix(p.secondary,p.paper,change));const move=ease(u);this.disk(mix(W*.9,cx-R*.87,move),mix(H*.3,cy-R*.13,move),R*1.48,back)}this.txt(secondary,cx,H*.83,22,p.paper)}break
      }
      case 'slice-orbit': {
        const R=Math.min(W,H)*(portrait?.18:.17)
        if(q<.48){this.bg(p.accent);if(!skipSharedCircle){if(scene.motion.motif==='celestial')this.moon(cx,cy,R*1.8,-.58,p.paper,p.accent);else {this.ring(cx,cy,R*1.8,p.paper,10,.45);this.line(cx-R*2.1,cy,cx+R*2.1,cy,p.paper,3,.45)}}const slices=scene.motion.slices;for(let i=0;i<slices;i++){const a=spring(Math.max(0,q*.9-.05-i*.012)*5);g.save();g.beginPath();g.rect(0,cy-size*.55+i*size*1.1/slices,W,size*1.2/slices);g.clip();g.translate((1-a)*(i%2?W*.7:-W*.7),0);g.globalAlpha=clamp(a);this.txt(displayLines(headline,this.p.aspect).join('\n'),cx,cy,size,p.paper);g.restore()}this.txt(secondary,cx,H*.79,22,p.paper)}
        else {this.bg(p.ink);this.field(t,.25);g.save();g.globalAlpha=.12;this.txt(displayLines(headline,this.p.aspect).join('\n'),cx,cy,size*1.35,p.paper);g.restore();this.orbit(t,p.muted,R*2.2,.7);if(scene.motion.motif==='celestial')this.moon(cx,cy,R,-.6-.4*Math.sin(t),p.paper,p.ink);else{this.ring(cx,cy,R,p.paper,16);this.disk(cx,cy,R*.35,p.secondary)}for(let i=0;i<3;i++){const a=t*1.8+i*TAU/3,x=cx+Math.cos(a)*R*2.5,y=cy+Math.sin(a)*R;if(i===0)this.star(x,y,30,t);if(i===1)this.disk(x,y,25,p.secondary);if(i===2)this.ring(x,y,28,p.paper,4)}this.txt(secondary,cx,H*.82,22,p.paper)}break
      }
      case 'three-up': {
        this.bg(p.ink);const colors=[p.accent,p.secondary,p.paper],items=scene.content.items
        for(let i=0;i<3;i++){const x=portrait?0:W*i/3,y=portrait?H*i/3:0,w=portrait?W:W/3,h=portrait?H/3:H,progress=out((q-i*.07)/.3);g.save();g.beginPath();g.rect(x,y,w,h);g.clip();g.translate(portrait?(1-progress)*(i%2?-W:W):0,portrait?0:(1-progress)*(i%2?-H:H));g.fillStyle=colors[i];g.fillRect(x,y,w,h);const ink=i===0?p.paper:p.ink;this.txt(String(i+1).padStart(2,'0'),x+38,y+65,25,ink,100,'left');this.txt(items[i],x+w/2,y+h*(portrait?.57:.7),portrait?size*.85:150,ink,w*.84);if(i===0){if(scene.motion.motif==='celestial')this.star(x+w/2,y+h*.39,Math.min(w,h)*.14,q,ink);else this.ring(x+w/2,y+h*.39,Math.min(w,h)*.13,ink,9)}if(i===1)this.disk(x+w/2,y+h*.39,Math.min(w,h)*.12,ink);if(i===2){if(scene.motion.motif==='celestial')this.moon(x+w/2,y+h*.39,Math.min(w,h)*.14,-.8,ink,colors[i]);else this.ring(x+w/2,y+h*.39,Math.min(w,h)*.13,ink,12)}g.restore()}
        if(q>.78){const u=out((q-.78)/.22);g.save();g.translate(cx,cy);g.rotate(u*Math.PI*.5);g.fillStyle=p.ink;g.fillRect(-W,-H*u,W*2,H*2*u);g.restore()}break
      }
      case 'particle-lockup': {
        this.bg(p.ink);const gs=graphemes(headline.replaceAll('\n','')),focus=gs[scene.motion.focusGrapheme]??gs[0]
        if(q<.5){const pull=out((q-.34)/.16);g.save();g.translate(cx,cy);g.scale(1-pull*.38,1-pull*.38);g.translate(-cx,-cy);this.particles(scene.id+'-focus',focus,size*1.45,W*.65,q*2.2,t,p.paper,intensity);if(q>.3)this.txt(focus,cx,cy,size*1.45,p.paper);g.restore()}
        else {this.orbit(t,p.muted,Math.min(W,H)*.42,.12);const displayed=displayLines(headline,this.p.aspect).join('\n'),multiline=displayed.includes('\n');this.kinetic(displayed,multiline&&!portrait?H*.46:cy,size,(q-.5)*2+.12,p.paper,scene.motion.focusGrapheme);const a=out((q-.53)*5);this.line(W*.08,multiline?H*.82:H*.74,W*(.08+.84*a),multiline?H*.82:H*.74,p.paper,2);this.txt(secondary,cx,multiline?H*.89:H*.81,portrait?24:29,p.paper)}break
      }
    }
    if(scene.motion.kind!=='impact-type')this.meta(t,item,scene.motion.kind==='radial-pulse'&&q<.68)
  }
  render(time:number,width=this.canvas.width,height=this.canvas.height) {
    if(this.canvas.width!==width)this.canvas.width=width;if(this.canvas.height!==height)this.canvas.height=height
    const g=this.g;g.setTransform(width/this.W,0,0,height/this.H,0,0);g.globalAlpha=1;g.globalCompositeOperation='source-over'
    const t=Math.max(0,Math.min(this.timeline.total,time));const item=sceneAt(this.timeline,t)
    const prev=this.timeline.scenes[item.index-1]
    if(prev?.scene.outgoing.kind==='circle-match' && t<item.start+item.incoming){
      const u=ease((t-item.start)/item.incoming),p=this.p.palette,W=this.W,H=this.H,portrait=this.p.aspect==='portrait'
      this.drawScene(prev,t,true)
      g.save();g.globalAlpha=u;this.drawScene(item,t,true);g.restore()
      const r0=Math.min(W,H)*(portrait?.19:.23)*1.5,r1=Math.min(W,H)*(portrait?.18:.17)*1.8,r=mix(r0,r1,u)
      const qPrev=clamp((t-prev.start)/prev.duration),phase=clamp((qPrev-.68)/.32),colorShift=ease((phase-.7)/.3)
      const back=colorMix(colorMix(p.ink,p.accent,colorShift),p.accent,u)
      this.disk(W/2,H/2,r,colorMix(colorMix(p.secondary,p.paper,colorShift),p.paper,u))
      const shadowX=mix(W*.9,W/2-r0*.58,ease(phase)),shadowY=mix(H*.3,H/2-r0*.09,ease(phase))
      this.disk(mix(shadowX,W/2-r1*.58,u),mix(shadowY,H/2-r1*.09,u),r*.99,back)
    }else this.drawScene(item,t)
    g.setTransform(1,0,0,1,0,0)
  }
}
