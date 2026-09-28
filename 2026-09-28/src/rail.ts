import type { GameState } from './game.ts';

export type DistrictArea = 'alley'|'store'|'service'|'court'|'roof';
export type RailPose = { x:number; y:number; z:number; yaw:number };
const mix = (a:number,b:number,t:number) => a+(b-a)*t;
const smooth = (t:number) => t*t*(3-2*t);
const pose = (x:number,y:number,z:number,yaw=0):RailPose => ({x,y,z,yaw});
export const STOPS = {
  entrance: pose(0,1.65,6), alley:pose(0,1.65,0),
  store:pose(10,1.65,-12,-Math.PI/2), service:pose(-6,1.65,-16),
  court:pose(24,1.65,-32), boss:pose(24,1.65,-36), roof:pose(24,8.65,-50),
};
/** Camera-only route clock. Never controls typing deadlines or combat. */
export class RailDirector {
  position:RailPose = {...STOPS.entrance};
  area:DistrictArea = 'alley';
  private key='';
  private elapsed=0;
  private duration=0;
  private points:RailPose[]=[];
  get moving(){ return this.elapsed < this.duration; }
  reset(){this.key='';this.elapsed=this.duration=0;this.position={...STOPS.entrance};this.area='alley';}
  update(dt:number,state:GameState|null){
    const j=state?.journey;
    const area = j?.area ?? 'alley';
    const atEntrance=!state || state.mode==='explore' || (j?.route===null);
    const key=atEntrance?'entrance':area==='court'&&state?.stage===3?'boss':area;
    const target=STOPS[key];
    if(key!==this.key){
      const previous=this.key;
      this.key=key; this.area=area;this.elapsed=0;
      this.duration=previous ? key==='roof'?5:key==='store'||key==='service'?3.8:key==='court'?4:key==='boss'?2:2 : 0;
      this.points=[{...this.position}];
      if(key==='store') this.points.push(pose(0,1.65,-10,-.2),pose(3,1.65,-12,-Math.PI/2));
      if(key==='service') this.points.push(pose(-4,1.65,-8,.3));
      if(key==='court') {
        if(previous==='service') this.points.push(pose(-6,1.65,-22,-Math.PI/2),pose(14,1.65,-22,-Math.PI/2));
        else this.points.push(pose(22,1.65,-12,-Math.PI/2));
        this.points.push(pose(24,1.65,-23,0));
      }
      if(key==='roof') this.points.push(pose(27.1,1.65,-39,-.4),pose(27.1,6.2,-45,0),pose(27.1,8.65,-48,0));
      this.points.push(target);
      if(!this.duration) this.position={...target};
    }
    if(!this.moving)return;
    if(state && ['paused','countdown'].includes(state.mode))return;
    // Combat and its camera arrival share the journey clock, even under slow rendering.
    this.elapsed=key!=='roof' && j ? Math.min(this.duration,j.travelProgress*this.duration) : Math.min(this.duration,this.elapsed+Math.max(0,dt));
    const along=smooth(this.elapsed/this.duration)*(this.points.length-1);
    const index=Math.min(this.points.length-2,Math.floor(along));
    const a=this.points[index],b=this.points[index+1],t=along-index;
    this.position={x:mix(a.x,b.x,t),y:mix(a.y,b.y,t),z:mix(a.z,b.z,t),yaw:mix(a.yaw,b.yaw,t)};
  }
}
/** Approach accelerates after recognition; the final step reaches arm's length. */
export function approachDistance(progress:number, kind:string, close:boolean){
  const p=Math.max(0,Math.min(1,progress));
  if(kind==='boss')return 7.2-4.8*p;
  const start=close?5.1:7.8;
  const end=kind==='worker'?1.65:1.35;
  const eased=p<.5 ? p*.65 : .325+(p-.5)*1.35;
  return start-(start-end)*eased;
}
