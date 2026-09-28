import * as T from 'three';
const PALETTE=[0xe5ad5a,0xffb83f,0xff58df,0x68eeff,0xffcf54];
/** Fixed stage fixtures follow the rail camera; no per-hit lights or meshes. */
export class OverdriveLights {
  readonly root=new T.Group();
  private fixtures:{group:T.Group;material:T.MeshBasicMaterial}[]=[];
  private lights=[new T.PointLight(0xffb534,0,13,2),new T.PointLight(0xe657ed,0,13,2)];
  constructor(){
    const arch=new T.TorusGeometry(4,.035,6,48,Math.PI),strip=new T.BoxGeometry(.055,.015,2.5);
    for(let i=0;i<6;i++){
      const group=new T.Group(),material=new T.MeshBasicMaterial({color:PALETTE[0],transparent:true,opacity:0,blending:T.AdditiveBlending,depthWrite:false,toneMapped:false});
      const hoop=new T.Mesh(arch,material);hoop.position.y=1.4;group.add(hoop);
      for(const side of [-1,1]){const lane=new T.Mesh(strip,material);lane.position.set(side*2.8,.035,0);group.add(lane);}
      group.position.z=-3-i*3.4;this.root.add(group);this.fixtures.push({group,material});
    }
    this.lights.forEach((light,i)=>{light.position.set(i?3:-3,2.7,-3);this.root.add(light);});
  }
  update(time:number,level:number,cameraZ:number,motion:boolean,rush:boolean,celebration:number){
    const tier=T.MathUtils.clamp(level,0,4),active=rush?4:tier;
    this.root.position.z=cameraZ;this.root.visible=active>0||celebration>0;
    const beat=motion?.78+.22*Math.sin(time*Math.PI*2*165/60):.55;
    this.fixtures.forEach(({group,material},i)=>{
      group.visible=i<active+2||celebration>0;
      material.color.setHex(PALETTE[active]).multiplyScalar(motion?2.4:1);
      const chase=motion?.72+.28*Math.sin(time*4-i*.8):.75;
      material.opacity=active===0?Math.min(.55,celebration*.5):Math.min(.94,(.25+active*.13)*chase+(motion?celebration*.2:0));
    });
    this.lights.forEach((light,i)=>{light.color.setHex(PALETTE[i&&active<4?2:active]);light.intensity=this.root.visible?(motion?active*3.2*beat+Math.min(1,celebration)*9:active*1.2):0;});
  }
  reset(){this.root.visible=false;this.lights.forEach(l=>l.intensity=0);this.fixtures.forEach(f=>f.material.opacity=0);}
}
