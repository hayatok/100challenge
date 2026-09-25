declare module 'p5' {
  export default class P5 {
    constructor(sketch:(p:P5)=>void, node?:HTMLElement)
    setup:()=>void; draw:()=>void; canvas:HTMLCanvasElement; drawingContext:CanvasRenderingContext2D
    createCanvas(width:number,height:number,renderer?:unknown):unknown
    resizeCanvas(width:number,height:number,noRedraw?:boolean):void
    pixelDensity(value:number):void; noLoop():void; redraw():void; remove():void
  }
}
