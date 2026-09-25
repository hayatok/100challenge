import P5 from 'p5'
import type { Scene } from './layout'
import { drawScene } from './draw'

export class RendererHost {
  private p!:P5; private holder=document.createElement('div'); private ready:Promise<void>; private job:{scene:Scene;time:number;width:number;resolve:(canvas:HTMLCanvasElement)=>void}|null=null
  constructor(){ this.holder.style.display='none';document.body.append(this.holder)
    this.ready=new Promise(resolve=>{this.p=new P5(p=>{p.setup=()=>{p.createCanvas(1,1);p.pixelDensity(1);p.noLoop();resolve()};p.draw=()=>{const j=this.job;if(!j)return;this.job=null;drawScene(p.drawingContext,j.scene,j.time,j.width);j.resolve(p.canvas)}},this.holder)}) }
  async render(scene:Scene,time:number,width:number){await this.ready;const height=Math.round(width*scene.height/scene.width);if(this.p.canvas.width!==width||this.p.canvas.height!==height)this.p.resizeCanvas(width,height,true);return new Promise<HTMLCanvasElement>(resolve=>{this.job={scene,time,width,resolve};this.p.redraw()})}
  remove(){this.p?.remove();this.holder.remove()}
}
