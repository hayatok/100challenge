import * as T from "three";

type Fleck = { mesh: T.Mesh; v: T.Vector3; age: number; life: number; size: number; streak: boolean };
type Pulse = { mesh: T.Mesh<T.RingGeometry, T.MeshBasicMaterial>; age: number; life: number; size: number };
const COLORS = [0xffc367, 0xffd876, 0xff814c, 0xe576ff, 0x72fff0];
/** Bounded, shared-geometry VFX. These advance on the visual clock, never the typing clock. */
export class CombatEffects {
  private bits: Fleck[] = [];
  private clouds: {sprite: T.Sprite; age: number; life: number; size: number; glow: boolean}[] = [];
  private glowTexture: T.CanvasTexture;
  private smokeTexture: T.CanvasTexture;
  private pulses: Pulse[] = [];
  private shard = new T.OctahedronGeometry(1, 0);
  private streak = new T.BoxGeometry(0.35, 0.35, 1);
  private ring = new T.RingGeometry(0.92, 1, 64);
  private materials = COLORS.map(color => new T.MeshBasicMaterial({color, toneMapped: false, blending: T.AdditiveBlending, transparent: true, depthWrite: false}));
  constructor(private scene: T.Scene) {
    const radial = (smoke: boolean) => {
      const canvas = document.createElement("canvas"); canvas.width = canvas.height = 128;
      const c = canvas.getContext("2d")!;
      const g = c.createRadialGradient(64,64,0,64,64,64);
      g.addColorStop(0, smoke ? "rgba(110,120,119,.38)" : "rgba(255,255,245,1)");
      g.addColorStop(.15, smoke ? "rgba(88,104,102,.28)" : "rgba(255,220,134,.8)");
      g.addColorStop(.5, smoke ? "rgba(70,88,90,.16)" : "rgba(255,147,54,.12)");
      g.addColorStop(1,"rgba(0,0,0,0)"); c.fillStyle=g; c.fillRect(0,0,128,128);
      return new T.CanvasTexture(canvas);
    };
    this.glowTexture=radial(false); this.smokeTexture=radial(true);
  }
  /** A short local flash and lingering dust mark the high-combo final key. */
  finisher(pos: T.Vector3, tier: number, reduced: boolean) {
    const add = (glow: boolean) => {
      if (this.clouds.length >= 16) {
        const old=this.clouds.shift()!; this.scene.remove(old.sprite); old.sprite.material.dispose();
      }
      const material = new T.SpriteMaterial({map:glow ? this.glowTexture : this.smokeTexture,
        color:glow ? 0xffedc4 : 0xb6c3c1, transparent:true, depthWrite:false,
        blending:glow ? T.AdditiveBlending : T.NormalBlending, toneMapped:!glow});
      const sprite=new T.Sprite(material); sprite.position.copy(pos); this.scene.add(sprite);
      this.clouds.push({sprite,age:0,life:glow ? .16 : .7,size:reduced ? .35 : glow ? .85 + tier*.08 : .6,glow});
    };
    add(true); if(!reduced) add(false);
    if(!reduced) this.pulse(pos,tier,.65+tier*.15,.28,false);
  }
  burst(pos: T.Vector3, tier: number, kill: boolean, reduced: boolean, strength = 1) {
    const level = Math.max(0, Math.min(4, tier));
    const n = Math.round((reduced ? (kill ? 10 : 2) : kill ? 28 + level * 11 : 5 + level * 2) * strength);
    for (let i = 0; i < n && this.bits.length < 300; i++) {
      const trail = i % 3 !== 0;
      const mesh = new T.Mesh(trail ? this.streak : this.shard, this.materials[i % 5 === 0 ? 0 : level]);
      mesh.position.copy(pos);
      const direction = new T.Vector3(Math.random() - .5, Math.random() - .3, Math.random() - .5).normalize();
      const speed = kill ? 2.5 + Math.random() * (4 + level) : 1.5 + Math.random() * 3;
      const size = (kill ? .025 + Math.random() * .05 : .012 + Math.random() * .025) * Math.min(1.3, strength);
      mesh.scale.set(size, size, size * (trail ? 6 : 1));
      mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 0, 1), direction);
      this.scene.add(mesh);
      this.bits.push({ mesh, v: direction.multiplyScalar(speed), age: 0, life: kill ? .5 + Math.random() * .55 : .16 + Math.random() * .23, size, streak: trail });
    }
    if (kill) {
      this.pulse(pos, level, reduced ? .8 : (1.3 + level * .3) * strength, .5, false);
      if (level >= 2 && !reduced && strength >= 1) this.pulse(new T.Vector3(pos.x, .06, pos.z), level, 3 + level, .7, true);
    }
  }
  private pulse(pos: T.Vector3, tier: number, size: number, life: number, floor: boolean) {
    if (this.pulses.length >= 10) return;
    const material = this.materials[tier].clone();
    material.side = T.DoubleSide;
    const mesh = new T.Mesh(this.ring, material);
    mesh.position.copy(pos);
    if (floor) mesh.rotation.x = -Math.PI / 2;
    mesh.scale.setScalar(.1);
    this.scene.add(mesh);
    this.pulses.push({mesh, age: 0, life, size});
  }
  tracer(from: T.Vector3, to: T.Vector3, level: number) {
    if (this.bits.length >= 300) return;
    const mesh = new T.Mesh(this.streak, this.materials[Math.min(4, level)]);
    mesh.position.copy(from).lerp(to, .5);
    const distance = from.distanceTo(to);
    mesh.scale.set(.008, .008, distance);
    mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 0, 1), to.clone().sub(from).normalize());
    this.scene.add(mesh);
    this.bits.push({mesh, v: new T.Vector3(), age: 0, life: .045, size: .012, streak: false});
  }
  update(dt: number) {
    for(let i=this.clouds.length-1;i>=0;i--) {
      const p=this.clouds[i]; p.age+=dt;
      const t=Math.min(1,p.age/p.life);
      p.sprite.material.opacity=p.glow ? (1-t)**2 : Math.sin(Math.PI*t)*.65;
      p.sprite.scale.setScalar(p.size*(p.glow ? 1+t*.3 : .5+t*2));
      if(!p.glow) p.sprite.position.y+=dt*.4;
      if(t===1){this.scene.remove(p.sprite);p.sprite.material.dispose();this.clouds.splice(i,1);}
    }
    for (let i = this.bits.length - 1; i >= 0; i--) {
      const p = this.bits[i];
      p.age += dt;
      if (p.age >= p.life) {this.scene.remove(p.mesh); this.bits.splice(i, 1); continue;}
      if (p.life > .05) {
        p.v.y -= dt * 5;
        p.mesh.position.addScaledVector(p.v, dt);
        const s = p.size * Math.min(1, (1 - p.age / p.life) * 3);
        p.mesh.scale.set(s, s, s * (p.streak ? 6 : 1));
      }
    }
    for (let i = this.pulses.length - 1; i >= 0; i--) {
      const p = this.pulses[i];
      p.age += dt;
      const t = Math.min(1, p.age / p.life);
      p.mesh.scale.setScalar(.15 + (1 - (1 - t) ** 3) * p.size);
      p.mesh.material.opacity = (1 - t) ** 2 * .72;
      if (t === 1) {this.scene.remove(p.mesh); p.mesh.material.dispose(); this.pulses.splice(i, 1);}
    }
  }
  reset() {
    for(const p of this.clouds){this.scene.remove(p.sprite);p.sprite.material.dispose();}
    this.clouds=[];
    for (const p of this.bits) this.scene.remove(p.mesh);
    for (const p of this.pulses) {this.scene.remove(p.mesh); p.mesh.material.dispose();}
    this.bits = []; this.pulses = [];
  }
}
