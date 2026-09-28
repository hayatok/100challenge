import * as T from "three";

type Fleck = { pose: T.Object3D; v: T.Vector3; age: number; life: number; size: number; trail: boolean; tracer: boolean; color: T.Color };
type Pulse = { mesh: T.Mesh<T.RingGeometry, T.MeshBasicMaterial>; age: number; life: number; size: number };
type Cloud = { sprite: T.Sprite; age: number; life: number; size: number; glow: boolean };
const COLORS = [0xffc367, 0xffd876, 0xff814c, 0xe576ff, 0x72fff0].map(c => new T.Color(c));
/** Fixed VFX pools keep shader programs alive; up to 300 flecks use two draws. */
export class CombatEffects {
  private bits: Fleck[] = [];
  private pulses: Pulse[] = [];
  private clouds: Cloud[] = [];
  private readonly shard: T.InstancedMesh;
  private readonly streak: T.InstancedMesh;
  constructor(scene: T.Scene) {
    const material = new T.MeshBasicMaterial({color:0xffffff, toneMapped:false, blending:T.AdditiveBlending, transparent:true, depthWrite:false});
    this.shard = new T.InstancedMesh(new T.OctahedronGeometry(1,0), material, 300);
    this.streak = new T.InstancedMesh(new T.BoxGeometry(.35,.35,1), material, 300);
    for (const mesh of [this.shard,this.streak]) {
      mesh.instanceMatrix.setUsage(T.DynamicDrawUsage);
      mesh.setColorAt(0,COLORS[0]); mesh.instanceColor!.setUsage(T.DynamicDrawUsage);
      mesh.frustumCulled=false; mesh.count=0; scene.add(mesh);
    }
    const radial = (smoke:boolean) => {
      const canvas=document.createElement('canvas'); canvas.width=canvas.height=128;
      const c=canvas.getContext('2d')!;
      const g=c.createRadialGradient(64,64,0,64,64,64);
      g.addColorStop(0,smoke?'rgba(110,120,119,.38)':'rgba(255,255,245,1)');
      g.addColorStop(.15,smoke?'rgba(88,104,102,.28)':'rgba(255,220,134,.8)');
      g.addColorStop(.5,smoke?'rgba(70,88,90,.16)':'rgba(255,147,54,.12)');
      g.addColorStop(1,'rgba(0,0,0,0)'); c.fillStyle=g;c.fillRect(0,0,128,128);
      return new T.CanvasTexture(canvas);
    };
    const glowTexture=radial(false), smokeTexture=radial(true);
    for(let i=0;i<16;i++) {
      const glow=i%2===0;
      const sprite=new T.Sprite(new T.SpriteMaterial({map:glow?glowTexture:smokeTexture,color:glow?0xffedc4:0xb6c3c1,transparent:true,depthWrite:false,blending:glow?T.AdditiveBlending:T.NormalBlending,toneMapped:!glow}));
      sprite.visible=false;scene.add(sprite);
      this.clouds.push({sprite,age:0,life:0,size:0,glow});
    }
    const ring=new T.RingGeometry(.92,1,48);
    for(let i=0;i<10;i++) {
      const mesh=new T.Mesh(ring,new T.MeshBasicMaterial({color:COLORS[0],side:T.DoubleSide,toneMapped:false,transparent:true,depthWrite:false,blending:T.AdditiveBlending}));
      mesh.visible=false;scene.add(mesh);this.pulses.push({mesh,age:0,life:0,size:0});
    }
  }
  private cloud(pos:T.Vector3,glow:boolean,size:number) {
    const matching=this.clouds.filter(p=>p.glow===glow);
    const p=matching.find(p=>!p.sprite.visible) ?? matching.reduce((a,b)=>a.age/a.life>b.age/b.life?a:b);
    p.sprite.position.copy(pos);p.sprite.visible=true;p.sprite.material.opacity=glow?1:0;
    p.age=0;p.life=glow?.16:.7;p.size=size;p.sprite.scale.setScalar(size*.5);
  }
  finisher(pos:T.Vector3,tier:number,reduced:boolean) {
    this.cloud(pos,true,reduced?.35:.85+tier*.08);
    if(!reduced){this.cloud(pos,false,.6);this.pulse(pos,tier,.65+tier*.15,.28,false);}
  }
  explosion(pos:T.Vector3,reduced:boolean) {
    this.finisher(pos,2,reduced);
    this.burst(pos,2,true,reduced,reduced?.8:1.7);
    if(!reduced){this.cloud(pos,false,2.2);this.pulse(new T.Vector3(pos.x,.07,pos.z),1,4.5,.65,true);}
  }
  burst(pos:T.Vector3,tier:number,kill:boolean,reduced:boolean,strength=1) {
    const level=Math.max(0,Math.min(4,tier));
    const n=Math.round((reduced?(kill?10:2):kill?28+level*11:5+level*2)*strength);
    for(let i=0;i<n&&this.bits.length<300;i++) {
      const trail=i%3!==0,pose=new T.Object3D();pose.position.copy(pos);
      const direction=new T.Vector3(Math.random()-.5,Math.random()-.3,Math.random()-.5).normalize();
      const speed=kill?2.5+Math.random()*(4+level):1.5+Math.random()*3;
      const size=(kill?.025+Math.random()*.05:.012+Math.random()*.025)*Math.min(1.3,strength);
      pose.scale.set(size,size,size*(trail?6:1));pose.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),direction);
      this.bits.push({pose,v:direction.multiplyScalar(speed),age:0,life:kill?.5+Math.random()*.55:.16+Math.random()*.23,size,trail,tracer:false,color:COLORS[i%5===0?0:level]});
    }
    if(kill){this.pulse(pos,level,reduced?.8:(1.3+level*.3)*strength,.5,false);if(level>=2&&!reduced&&strength>=1)this.pulse(new T.Vector3(pos.x,.06,pos.z),level,3+level,.7,true);}
  }
  private pulse(pos:T.Vector3,tier:number,size:number,life:number,floor:boolean) {
    const p=this.pulses.find(p=>!p.mesh.visible);if(!p)return;
    p.mesh.visible=true;p.mesh.position.copy(pos);p.mesh.rotation.set(floor?-Math.PI/2:0,0,0);p.mesh.scale.setScalar(.1);
    p.mesh.material.color.copy(COLORS[tier]);p.mesh.material.opacity=.72;p.age=0;p.life=life;p.size=size;
  }
  tracer(from:T.Vector3,to:T.Vector3,level:number) {
    if(this.bits.length>=300)return;
    const pose=new T.Object3D();pose.position.copy(from).lerp(to,.5);pose.scale.set(.008,.008,from.distanceTo(to));
    pose.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),to.clone().sub(from).normalize());
    this.bits.push({pose,v:new T.Vector3(),age:0,life:.045,size:.012,trail:true,tracer:true,color:COLORS[Math.min(4,level)]});
  }
  update(dt:number) {
    for(const p of this.clouds) {
      if(!p.sprite.visible)continue;p.age+=dt;const t=Math.min(1,p.age/p.life);
      p.sprite.material.opacity=p.glow?(1-t)**2:Math.sin(Math.PI*t)*.65;
      p.sprite.scale.setScalar(p.size*(p.glow?1+t*.3:.5+t*2));if(!p.glow)p.sprite.position.y+=dt*.4;
      if(t===1)p.sprite.visible=false;
    }
    for(let i=this.bits.length-1;i>=0;i--) {
      const p=this.bits[i];p.age+=dt;if(p.age>=p.life){this.bits.splice(i,1);continue;}
      if(!p.tracer){p.v.y-=dt*5;p.pose.position.addScaledVector(p.v,dt);const s=p.size*Math.min(1,(1-p.age/p.life)*3);p.pose.scale.set(s,s,s*(p.trail?6:1));}
    }
    let shards=0,streaks=0;
    for(const p of this.bits){const mesh=p.trail?this.streak:this.shard;const i=p.trail?streaks++:shards++;p.pose.updateMatrix();mesh.setMatrixAt(i,p.pose.matrix);mesh.setColorAt(i,p.color);}
    this.shard.count=shards;this.streak.count=streaks;
    for(const mesh of [this.shard,this.streak]){mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor!.needsUpdate=true;}
    for(const p of this.pulses){if(!p.mesh.visible)continue;p.age+=dt;const t=Math.min(1,p.age/p.life);p.mesh.scale.setScalar(.15+(1-(1-t)**3)*p.size);p.mesh.material.opacity=(1-t)**2*.72;if(t===1)p.mesh.visible=false;}
  }
  reset(){this.bits=[];this.shard.count=0;this.streak.count=0;for(const p of this.clouds)p.sprite.visible=false;for(const p of this.pulses)p.mesh.visible=false;}
}
