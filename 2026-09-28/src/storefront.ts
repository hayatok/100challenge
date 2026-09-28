import * as T from 'three';

/** Two reusable shop displays. Their reaction never changes enemy deadlines or score. */
export class StorefrontProps {
  readonly root = new T.Group();
  private displays: { side: number; hit: boolean; tilt: number; board: T.Mesh; origin: T.Vector3 }[] = [];
  private cans: { mesh:T.Mesh; home:T.Vector3; velocity:T.Vector3; side:number; moving:boolean; spin:number }[] = [];
  private geometries = [new T.BoxGeometry(1,1,1), new T.CylinderGeometry(.065,.065,.2,12)];
  private materials = [new T.MeshStandardMaterial({color:0x493a2a,roughness:.82}),new T.MeshStandardMaterial({color:0x253333,metalness:.65,roughness:.48}),... [0x97814a,0x326879,0x864936].map(color=>new T.MeshStandardMaterial({color,roughness:.48,metalness:.45}))];
  constructor() {
    this.root.name='Breakable midnight shop displays';
    for(const side of [-1,1]) {
      const origin=new T.Vector3(side*3.12,.91,-2.7);
      const board=new T.Mesh(this.geometries[0],this.materials[0]);board.position.copy(origin);board.scale.set(.76,.07,1.62);board.receiveShadow=true;this.root.add(board);
      for(const z of [-3.34,-2.06])for(const x of [-.29,.29]) {
        const leg=new T.Mesh(this.geometries[0],this.materials[1]);leg.position.set(origin.x+x,.47,z);leg.scale.set(.045,.88,.045);this.root.add(leg);
      }
      this.displays.push({side,hit:false,tilt:0,board,origin});
      for(let i=0;i<12;i++) {
        const mesh=new T.Mesh(this.geometries[1],this.materials[2+i%3]);
        mesh.position.set(origin.x+(i%3-1)*.2,1.045,-3.25+Math.floor(i/3)*.36);mesh.castShadow=true;this.root.add(mesh);
        this.cans.push({mesh,home:mesh.position.clone(),velocity:new T.Vector3(),side,moving:false,spin:(i%2?1:-1)*(2+i%3)});
      }
    }
  }
  strike(origin:T.Vector3,reduced=false):T.Vector3|null {
    const display=this.displays.filter(d=>!d.hit && d.origin.distanceTo(origin)<7).sort((a,b)=>a.origin.distanceToSquared(origin)-b.origin.distanceToSquared(origin))[0];
    if(!display)return null;
    display.hit=true;display.tilt=1;
    this.cans.filter(c=>c.side===display.side).forEach((c,i)=>{
      c.moving=true;c.velocity.set(-display.side*(.45+(i%3)*.25),.85+(i%4)*.3,((i%5)-2)*.42).multiplyScalar(reduced?.35:1);
    });
    return display.origin.clone().add(new T.Vector3(0,.16,0));
  }
  update(dt:number,reduced=false) {
    const step=Math.max(0,Math.min(.05,dt));
    for(const d of this.displays){d.tilt=Math.max(0,d.tilt-step*1.4);d.board.rotation.z=d.hit?d.side*(.13+d.tilt*(reduced?.02:.1)):0;}
    for(const c of this.cans)if(c.moving){
      c.velocity.y-=step*5.5;c.mesh.position.addScaledVector(c.velocity,step);c.mesh.rotation.z+=step*c.spin*(reduced?.3:1);
      if(c.mesh.position.y<.1){c.mesh.position.y=.1;c.velocity.multiplyScalar(.54);c.velocity.y=Math.abs(c.velocity.y)*.22;
        if(c.velocity.length()<.32){c.moving=false;c.mesh.rotation.z=Math.PI/2;}}
      c.mesh.position.x=T.MathUtils.clamp(c.mesh.position.x,-3.9,3.9);
    }
  }
  reset(){for(const d of this.displays){d.hit=false;d.tilt=0;d.board.rotation.z=0;}for(const c of this.cans){c.mesh.position.copy(c.home);c.mesh.rotation.set(0,0,0);c.velocity.set(0,0,0);c.moving=false;}}
  dispose(){this.root.removeFromParent();this.geometries.forEach(g=>g.dispose());this.materials.forEach(m=>m.dispose());}
}
