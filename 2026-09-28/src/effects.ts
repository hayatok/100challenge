import * as T from "three";

const FLECK_CAPACITY = 600;
const COLORS = [0xffc367, 0xffd876, 0xff814c, 0xe576ff, 0x72fff0].map(color => new T.Color(color));
const GOLD = [0xffd05a, 0xffe598, 0xffb847, 0xfff6cb].map(color => new T.Color(color));
const WHITE = new T.Color(0xffffff);
const AXIS = new T.Vector3(0, 0, 1);

type Fleck = {
  pose: T.Object3D;
  v: T.Vector3;
  color: T.Color;
  age: number;
  life: number;
  size: number;
  trail: boolean;
  tracer: boolean;
  confetti: boolean;
};
type Pulse = { mesh: T.Mesh<T.RingGeometry, T.MeshBasicMaterial>; age: number; life: number; size: number };
type Cloud = { sprite: T.Sprite; age: number; life: number; size: number; glow: boolean };

/** Two instanced draws share a fixed particle budget. New effects recycle the oldest slots. */
export class CombatEffects {
  private readonly bits: Fleck[] = [];
  private readonly pulses: Pulse[] = [];
  private readonly clouds: Cloud[] = [];
  private readonly shard: T.InstancedMesh;
  private readonly streak: T.InstancedMesh;
  private nextBit = 0;
  private readonly direction = new T.Vector3();
  private readonly point = new T.Vector3();

  constructor(scene: T.Scene) {
    const material = new T.MeshBasicMaterial({ color: 0xffffff, toneMapped: false, blending: T.AdditiveBlending, transparent: true, depthWrite: false });
    this.shard = new T.InstancedMesh(new T.OctahedronGeometry(1, 0), material, FLECK_CAPACITY);
    this.streak = new T.InstancedMesh(new T.BoxGeometry(1, 1, 1), material, FLECK_CAPACITY);
    for (const mesh of [this.shard, this.streak]) {
      mesh.instanceMatrix.setUsage(T.DynamicDrawUsage);
      mesh.setColorAt(0, COLORS[0]);
      mesh.instanceColor!.setUsage(T.DynamicDrawUsage);
      mesh.frustumCulled = false;
      mesh.count = 0;
      scene.add(mesh);
    }
    for (let i = 0; i < FLECK_CAPACITY; i++) {
      this.bits.push({ pose: new T.Object3D(), v: new T.Vector3(), color: new T.Color(), age: 0, life: 0, size: 0, trail: false, tracer: false, confetti: false });
    }
    const radial = (smoke: boolean) => {
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = 128;
      const c = canvas.getContext("2d")!;
      const g = c.createRadialGradient(64, 64, 0, 64, 64, 64);
      g.addColorStop(0, smoke ? "rgba(110,120,119,.38)" : "rgba(255,255,245,1)");
      g.addColorStop(.15, smoke ? "rgba(88,104,102,.28)" : "rgba(255,220,134,.8)");
      g.addColorStop(.5, smoke ? "rgba(70,88,90,.16)" : "rgba(255,147,54,.12)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      c.fillStyle = g;
      c.fillRect(0, 0, 128, 128);
      return new T.CanvasTexture(canvas);
    };
    const glowTexture = radial(false), smokeTexture = radial(true);
    for (let i = 0; i < 24; i++) {
      const glow = i % 3 !== 2;
      const sprite = new T.Sprite(new T.SpriteMaterial({ map: glow ? glowTexture : smokeTexture, color: glow ? 0xffedc4 : 0xb6c3c1, transparent: true, depthWrite: false, blending: glow ? T.AdditiveBlending : T.NormalBlending, toneMapped: !glow }));
      sprite.visible = false;
      scene.add(sprite);
      this.clouds.push({ sprite, age: 0, life: 0, size: 0, glow });
    }
    const ring = new T.RingGeometry(.91, 1, 48);
    for (let i = 0; i < 18; i++) {
      const mesh = new T.Mesh(ring, new T.MeshBasicMaterial({ color: COLORS[0], side: T.DoubleSide, toneMapped: false, transparent: true, depthWrite: false, blending: T.AdditiveBlending }));
      mesh.visible = false;
      scene.add(mesh);
      this.pulses.push({ mesh, age: 0, life: 0, size: 0 });
    }
  }

  private bit(): Fleck {
    const p = this.bits[this.nextBit];
    this.nextBit = (this.nextBit + 1) % FLECK_CAPACITY;
    p.age = 0;
    p.confetti = false;
    p.tracer = false;
    p.pose.rotation.set(0, 0, 0);
    p.pose.quaternion.identity();
    return p;
  }

  private cloud(pos: T.Vector3, glow: boolean, size: number) {
    let selected: Cloud | undefined;
    let oldest = -1;
    for (const p of this.clouds) {
      if (p.glow !== glow) continue;
      if (!p.sprite.visible) { selected = p; break; }
      const progress = p.age / p.life;
      if (progress > oldest) { selected = p; oldest = progress; }
    }
    if (!selected) return;
    selected.sprite.position.copy(pos);
    selected.sprite.visible = true;
    selected.sprite.material.opacity = glow ? 1 : 0;
    selected.age = 0;
    selected.life = glow ? .2 : .7;
    selected.size = size;
    selected.sprite.scale.setScalar(size * .5);
  }

  finisher(pos: T.Vector3, tier: number, reduced: boolean, focused = false) {
    const level = Math.max(0, Math.min(4, tier | 0));
    this.cloud(pos, true, reduced || focused ? .38 : 1.05 + level * .2);
    if(focused){this.cloud(pos,false,.6);return;}
    if (reduced) return;
    this.cloud(pos, false, .7 + level * .1);
    this.pulse(pos, level, .85 + level * .25, .34, false);
    if (level >= 2) this.pulse(pos, 1, 1.45 + level * .28, .46, false);
  }

  explosion(pos: T.Vector3, reduced: boolean) {
    this.finisher(pos, 2, reduced);
    this.burst(pos, 2, true, reduced, reduced ? .8 : 2.1);
    if (reduced) return;
    this.cloud(pos, false, 2.2);
    this.point.set(pos.x, .07, pos.z);
    this.pulse(this.point, 1, 4.5, .65, true);
    this.pulse(this.point, 0, 6, .85, true);
  }

  confetti(pos: T.Vector3, reduced: boolean, strength = 1) {
    const count = Math.min(180, Math.round((reduced ? 12 : 94) * Math.max(0, strength)));
    for (let i = 0; i < count; i++) {
      const p = this.bit();
      p.pose.position.copy(pos);
      p.pose.rotation.set(Math.random() * 3, Math.random() * 3, Math.random() * 3);
      p.size = .04 + Math.random() * .035;
      p.pose.scale.set(p.size, p.size * 2.2, .009);
      p.v.set((Math.random() - .5) * 5, 2.3 + Math.random() * 3.4, (Math.random() - .5) * 3.3);
      p.life = 1.8 + Math.random() * 1.1;
      p.trail = true;
      p.confetti = true;
      p.color.copy(GOLD[i % GOLD.length]);
    }
  }

  burst(pos: T.Vector3, tier: number, kill: boolean, reduced: boolean, strength = 1, grounded = false) {
    const level = Math.max(0, Math.min(4, tier | 0));
    const power = Math.max(0, Math.min(2.5, strength));
    const count = Math.min(180, Math.round((reduced ? (kill ? 12 : 3) : kill ? 38 + level * 16 : 8 + level * 3) * power));
    for (let i = 0; i < count; i++) {
      const p = this.bit();
      p.pose.position.copy(pos);
      this.direction.set(Math.random() - .5, Math.random() - .2, Math.random() - .5).normalize();
      const speed = kill ? 3 + Math.random() * (5 + level * .8) : 1.8 + Math.random() * 3;
      p.v.copy(this.direction).multiplyScalar(speed);
      p.size = (kill ? .027 + Math.random() * .055 : .016 + Math.random() * .03) * Math.min(1.6, power);
      p.trail = i % 4 !== 0;
      p.pose.scale.set(p.size, p.size, p.size * (p.trail ? 8 : 1));
      p.pose.quaternion.setFromUnitVectors(AXIS, this.direction);
      p.life = kill ? .58 + Math.random() * .58 : .2 + Math.random() * .24;
      p.color.copy(i % 7 === 0 ? WHITE : COLORS[i % 5 === 0 ? 0 : level]);
    }
    if (!kill) return;
    if(grounded){this.point.set(pos.x,.05,pos.z);this.pulse(this.point,level,reduced?.6:1.8,.3,true);return;}
    this.pulse(pos, level, reduced ? .7 : (1.5 + level * .38) * power, reduced ? .2 : .52, false);
    if (reduced) return;
    this.pulse(pos, 1, (2 + level * .45) * power, .64, false);
    if (level >= 2 && power >= 1) {
      this.point.set(pos.x, .06, pos.z);
      this.pulse(this.point, level, 3 + level * .9, .76, true);
    }
  }

  /** Fixed-budget fireworks for rush completion, jackpots, and combo milestones. */
  finale(pos: T.Vector3, tier: number, reduced: boolean) {
    const level = Math.max(0, Math.min(4, tier | 0));
    this.cloud(pos, true, reduced ? .48 : 2 + level * .27);
    this.pulse(pos, level, reduced ? 1 : 2.6 + level * .4, reduced ? .23 : .55, false);
    if (reduced) return;
    this.burst(pos, level, true, false, 1.8);
    this.confetti(pos, false, 1.25);
    this.point.set(pos.x - .75, pos.y + .45, pos.z);
    this.cloud(this.point, true, 1.25);
    this.pulse(this.point, 1, 2.1, .55, false);
    this.point.set(pos.x + .8, pos.y + .7, pos.z);
    this.cloud(this.point, true, 1.35);
    this.pulse(this.point, 0, 2.25, .6, false);
    this.point.set(pos.x, .05, pos.z);
    this.pulse(this.point, level, 7 + level, .9, true);
    this.pulse(this.point, 1, 9 + level, 1.1, true);
  }

  private pulse(pos: T.Vector3, tier: number, size: number, life: number, floor: boolean) {
    const p = this.pulses.find(p => !p.mesh.visible);
    if (!p) return;
    p.mesh.visible = true;
    p.mesh.position.copy(pos);
    p.mesh.rotation.set(floor ? -Math.PI / 2 : 0, 0, 0);
    p.mesh.scale.setScalar(.1);
    p.mesh.material.color.copy(COLORS[tier]);
    p.mesh.material.opacity = .8;
    p.age = 0;
    p.life = life;
    p.size = size;
  }

  tracer(from: T.Vector3, to: T.Vector3, level: number) {
    const length = from.distanceTo(to);
    if (length < 1e-5) return;
    const p = this.bit();
    p.pose.position.copy(from).lerp(to, .5);
    const width = .022 + Math.max(0, Math.min(4, level | 0)) * .009;
    p.pose.scale.set(width, width, length);
    this.direction.copy(to).sub(from).normalize();
    p.pose.quaternion.setFromUnitVectors(AXIS, this.direction);
    p.v.set(0, 0, 0);
    p.life = .075;
    p.size = width;
    p.trail = true;
    p.tracer = true;
    p.color.copy(COLORS[Math.max(0, Math.min(4, level | 0))]);
  }

  update(dt: number) {
    if (dt <= 0 || !Number.isFinite(dt)) return;
    for (const p of this.clouds) {
      if (!p.sprite.visible) continue;
      p.age += dt;
      const t = Math.min(1, p.age / p.life);
      p.sprite.material.opacity = p.glow ? (1 - t) ** 2 : Math.sin(Math.PI * t) * .65;
      p.sprite.scale.setScalar(p.size * (p.glow ? 1 + t * .3 : .5 + t * 2));
      if (!p.glow) p.sprite.position.y += dt * .4;
      if (t === 1) p.sprite.visible = false;
    }
    let shards = 0, streaks = 0;
    for (const p of this.bits) {
      if (p.life <= 0) continue;
      p.age += dt;
      if (p.age >= p.life) { p.life = 0; continue; }
      if (!p.tracer) {
        p.v.y -= dt * (p.confetti ? 2 : 5);
        p.pose.position.addScaledVector(p.v, dt);
        const size = p.size * Math.min(1, (1 - p.age / p.life) * 3);
        if (p.confetti) {
          p.v.multiplyScalar(Math.exp(-dt * .6));
          p.pose.rotation.x += dt * 3;
          p.pose.rotation.y += dt * 2;
          p.pose.scale.set(size, size * 2.2, .009);
        } else p.pose.scale.set(size, size, size * (p.trail ? 8 : 1));
      }
      p.pose.updateMatrix();
      const mesh = p.trail ? this.streak : this.shard;
      const index = p.trail ? streaks++ : shards++;
      mesh.setMatrixAt(index, p.pose.matrix);
      mesh.setColorAt(index, p.color);
    }
    this.shard.count = shards;
    this.streak.count = streaks;
    for (const mesh of [this.shard, this.streak]) {
      mesh.instanceMatrix.needsUpdate = true;
      mesh.instanceColor!.needsUpdate = true;
    }
    for (const p of this.pulses) {
      if (!p.mesh.visible) continue;
      p.age += dt;
      const t = Math.min(1, p.age / p.life);
      p.mesh.scale.setScalar(.15 + (1 - (1 - t) ** 3) * p.size);
      p.mesh.material.opacity = (1 - t) ** 2 * .8;
      if (t === 1) p.mesh.visible = false;
    }
  }

  reset() {
    for (const p of this.bits) p.life = 0;
    this.nextBit = 0;
    this.shard.count = 0;
    this.streak.count = 0;
    for (const p of this.clouds) p.sprite.visible = false;
    for (const p of this.pulses) p.mesh.visible = false;
  }
}
