import * as T from "three";

type Fleck = { mesh: T.Mesh; v: T.Vector3; age: number; life: number; size: number; streak: boolean };
type Pulse = { mesh: T.Mesh<T.RingGeometry, T.MeshBasicMaterial>; age: number; life: number; size: number };
const COLORS = [0xffc367, 0xffd876, 0xff814c, 0xe576ff, 0x72fff0];
/** Bounded, shared-geometry VFX. These advance on the visual clock, never the typing clock. */
export class CombatEffects {
  private bits: Fleck[] = [];
  private pulses: Pulse[] = [];
  private shard = new T.OctahedronGeometry(1, 0);
  private streak = new T.BoxGeometry(0.35, 0.35, 1);
  private ring = new T.RingGeometry(0.92, 1, 64);
  private materials = COLORS.map(color => new T.MeshBasicMaterial({color, toneMapped: false, blending: T.AdditiveBlending, transparent: true, depthWrite: false}));
  constructor(private scene: T.Scene) {}
  burst(pos: T.Vector3, tier: number, kill: boolean, reduced: boolean) {
    const level = Math.max(0, Math.min(4, tier));
    const n = reduced ? (kill ? 12 : 3) : kill ? 36 + level * 17 : 7 + level * 3;
    for (let i = 0; i < n && this.bits.length < 300; i++) {
      const trail = i % 3 !== 0;
      const mesh = new T.Mesh(trail ? this.streak : this.shard, this.materials[i % 5 === 0 ? 0 : level]);
      mesh.position.copy(pos);
      const direction = new T.Vector3(Math.random() - .5, Math.random() - .3, Math.random() - .5).normalize();
      const speed = kill ? 2.5 + Math.random() * (4 + level) : 1.5 + Math.random() * 3;
      const size = kill ? .035 + Math.random() * .07 : .018 + Math.random() * .035;
      mesh.scale.set(size, size, size * (trail ? 6 : 1));
      mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 0, 1), direction);
      this.scene.add(mesh);
      this.bits.push({ mesh, v: direction.multiplyScalar(speed), age: 0, life: kill ? .5 + Math.random() * .55 : .16 + Math.random() * .23, size, streak: trail });
    }
    if (kill) {
      this.pulse(pos, level, reduced ? 1.2 : 2.1 + level * .45, .5, false);
      if (level >= 2 && !reduced) this.pulse(new T.Vector3(pos.x, .06, pos.z), level, 3 + level, .7, true);
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
    mesh.scale.set(.012, .012, distance);
    mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 0, 1), to.clone().sub(from).normalize());
    this.scene.add(mesh);
    this.bits.push({mesh, v: new T.Vector3(), age: 0, life: .045, size: .012, streak: false});
  }
  update(dt: number) {
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
    for (const p of this.bits) this.scene.remove(p.mesh);
    for (const p of this.pulses) {this.scene.remove(p.mesh); p.mesh.material.dispose();}
    this.bits = []; this.pulses = [];
  }
}
