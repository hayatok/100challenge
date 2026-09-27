import * as T from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { loadCharacterLibrary, type CharacterLibrary } from "./characters.ts";
import { CombatEffects } from "./effects.ts";
import { createWeapon } from "./weapon.ts";
import { createEnvironment } from "./environment.ts";
import type { EnemyView, GameEvent, GameState } from "./game.ts";

type Actor = {
  root: T.Group;
  model: T.Object3D;
  velocity: T.Vector3;
  hitstop: number;
  twist: number;
  mixer: T.AnimationMixer;
  clips: T.AnimationClip[];
  hit: number;
  dead: number;
  lane: number;
  progress: number;
  boss: boolean;
  height: number;
  attacking: boolean;
};
export class World {
  readonly renderer: T.WebGLRenderer;
  readonly camera = new T.PerspectiveCamera(55, 1, 0.08, 110);
  readonly scene = new T.Scene();
  private composer: EffectComposer;
  private bloom: UnrealBloomPass;
  private environment!: Awaited<ReturnType<typeof createEnvironment>>;
  private characters!: CharacterLibrary;
  private actors = new Map<number, Actor>();
  private gun = new T.Group();
  private muzzle: T.Mesh;
  private flash = new T.PointLight(0xffb85a, 0, 7);
  private recoil = 0;
  private impact = 0;
  private level = 0;
  private effects = new CombatEffects(this.scene);
  private cameraZ = 5;
  private elapsed = 0;
  private particles: { mesh: T.Mesh; velocity: T.Vector3; life: number }[] = [];
  private shadowGeo = new T.CircleGeometry(0.43, 24);
  private shadowMat = new T.MeshBasicMaterial({
    color: 0x000000,
    transparent: true,
    opacity: 0.3,
    depthWrite: false,
  });
  private shellGeo = new T.CylinderGeometry(0.012, 0.012, 0.045, 6);
  private shellMat = new T.MeshStandardMaterial({
    color: 0xcba64a,
    metalness: 0.7,
    roughness: 0.32,
  });
  motion = true;
  constructor(container: HTMLElement) {
    this.renderer = new T.WebGLRenderer({
      antialias: true,
      powerPreference: "high-performance",
    });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
    this.renderer.toneMapping = T.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.3;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = T.PCFSoftShadowMap;
    container.append(this.renderer.domElement);
    this.scene.background = new T.Color("#121d23");
    this.scene.fog = new T.FogExp2("#152129", 0.027);
    this.scene.add(new T.HemisphereLight(0xb5d4dd, 0x5b4c35, 2.1));
    const key = new T.DirectionalLight(0xbedaff, 3.2);
    key.position.set(-4, 8, 5);
    this.scene.add(key);
    this.scene.add(this.camera);
    this.camera.position.set(0, 1.65, 5);
    const fill = new T.PointLight(0xffcc9b, 28, 20, 2);
    fill.position.set(0, 2, -1);
    this.camera.add(fill);
    this.camera.add(this.gun);
    this.gun.position.set(0.48, -0.19, -0.65);
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 128;
    const ctx = canvas.getContext("2d")!;
    const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
    g.addColorStop(0, "#fff");
    g.addColorStop(0.12, "#ffffce");
    g.addColorStop(0.3, "#ffa32380");
    g.addColorStop(0.6, "#ff6b0010");
    g.addColorStop(1, "#ff6b0000");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 128, 128);
    ctx.translate(64, 64);
    ctx.beginPath();
    for (let i = 0; i < 16; i++) {
      const r = i % 2 ? 8 : (i % 4 ? 36 : 60);
      const angle = i * Math.PI / 8;
      const x = Math.cos(angle) * r, y = Math.sin(angle) * r;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath(); ctx.fillStyle = "#fff2bc"; ctx.fill();
    this.muzzle = new T.Mesh(
      new T.PlaneGeometry(0.3, 0.3),
      new T.MeshBasicMaterial({
        map: new T.CanvasTexture(canvas),
        transparent: true,
        blending: T.AdditiveBlending,
        depthWrite: false,
      }),
    );
    this.muzzle.position.set(0, 0.03, -0.28);
    this.muzzle.visible = false;
    this.gun.add(this.muzzle, this.flash);
    this.flash.position.copy(this.muzzle.position);
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new T.Vector2(1, 1), 0.35, 0.4, 1.05);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.resize();
    window.addEventListener("resize", () => this.resize());
  }
  async load(onProgress: (text: string) => void) {
    onProgress("商店街の灯りを点けています");
    this.environment = await createEnvironment(this.scene);
    onProgress("住人たちが出勤しています");
    this.characters = await loadCharacterLibrary();
    onProgress("装備を確認しています");
    this.gun.add(await createWeapon());
    const warm = ["office", "office", "runner", "worker", "boss"].map((kind, id) => this.characters.create(kind as EnemyView["kind"], id).model);
    for (const model of warm) this.scene.add(model);
    await this.renderer.compileAsync(this.scene, this.camera);
    this.renderer.render(this.scene, this.camera);
    for (const model of warm) {
      this.scene.remove(model);
      model.traverse(o => { if (o instanceof T.SkinnedMesh) o.skeleton.dispose(); });
    }
  }
  reset(stage = 0) {
    for (const a of this.actors.values()) {
      this.scene.remove(a.root);
      a.mixer.stopAllAction();
      a.root.traverse((o) => {
        if (o instanceof T.SkinnedMesh) o.skeleton.dispose();
      });
    }
    this.actors.clear();
    for (const p of this.particles) this.scene.remove(p.mesh);
    this.particles = [];
    this.recoil = 0;
    this.impact = 0;
    this.effects.reset();
    this.cameraZ = 5 - stage * 15;
  }
  private resize() {
    const w = window.innerWidth,
      h = window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
  }
  private actor(e: EnemyView) {
    const root = new T.Group();
    const character = this.characters.create(e.kind, e.id);
    const model = character.model;
    root.add(model);
    const height = e.kind === "boss" ? 2.7 : e.kind === "worker" ? 2.15 : 1.8;
    model.scale.multiplyScalar(height / character.height);
    const shadow = new T.Mesh(this.shadowGeo, this.shadowMat);
    if (e.kind === "boss") shadow.scale.setScalar(1.6);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.015;
    root.add(shadow);
    const mixer = new T.AnimationMixer(model);
    const clip = character.walk ?? character.clips[0];
    if (clip) {
      mixer.clipAction(clip).play();
      mixer.setTime(e.id * 0.417);
    }
    const a: Actor = {
      root,
      model,
      velocity: new T.Vector3(),
      hitstop: 0,
      twist: (e.id % 2 ? 1 : -1),
      mixer,
      clips: character.clips,
      hit: 0,
      dead: 0,
      lane: e.lane,
      progress: e.progress,
      boss: e.kind === "boss",
      height,
      attacking: false,
    };
    this.scene.add(root);
    this.actors.set(e.id, a);
    return a;
  }
  event(e: GameEvent) {
    this.level = e.effectsLevel ?? this.level;
    const a = e.enemyId ? this.actors.get(e.enemyId) : undefined;
    if (e.type === "hit") {
      this.recoil = 1;
      this.impact = Math.max(this.impact, .2);
      const shell = new T.Mesh(this.shellGeo, this.shellMat);
      this.gun.getWorldPosition(shell.position);
      shell.rotation.z = 1;
      this.scene.add(shell);
      if (this.particles.length >= 48) this.scene.remove(this.particles.shift()!.mesh);
      this.particles.push({
        mesh: shell,
        velocity: new T.Vector3(1.6, 1.5, 0.6),
        life: 0.7,
      });
      if (a) {
        a.hit = 1;
        if (a.hitstop <= 0) a.hitstop = .035;
        const hit = a.root.position.clone().add(new T.Vector3((Math.random() - .5) * .25, a.boss ? 2 : 1.35, .1));
        this.effects.burst(hit, this.level, false, !this.motion);
        this.effects.tracer(this.muzzle.getWorldPosition(new T.Vector3()), hit, this.level);
      }
    }
    if (e.type === "kill" && a) {
      a.dead = 0.001;
      a.hitstop = .04;
      this.impact = .65 + this.level * .15;
      a.velocity.set(a.twist * (.35 + this.level * .22), 1.6 + this.level * .35, -2.8 - this.level * .8);
      const death = a.clips.find((c) => /death|dead|dying/i.test(c.name));
      if (death) {
        a.mixer.stopAllAction();
        const action = a.mixer.clipAction(death);
        action.setLoop(T.LoopOnce, 1);
        action.clampWhenFinished = true;
        action.play();
      }
      this.effects.burst(a.root.position.clone().add(new T.Vector3(0, a.boss ? 1.9 : 1.3, 0)), this.level, true, !this.motion);
    }
    if (e.type === "attack" && a) a.dead = 2.2;
  }
  update(dt: number, state: GameState | null) {
    this.gun.visible = !!state;
    this.elapsed += dt;
    const running =
      !state ||
      !["paused", "countdown"].includes(state.mode);
    const delta = running ? dt : 0;
    this.level = state?.effectsLevel ?? 0;
    const stage = state?.stage ?? 0;
    const desired = 5 - stage * 15;
    this.cameraZ = T.MathUtils.damp(this.cameraZ, desired, 2, delta);
    this.camera.position.set(0, 1.65, this.cameraZ);
    this.camera.rotation.set(0, 0, 0);
    const active = new Set<number>();
    for (const e of state?.enemies ?? []) {
      active.add(e.id);
      const a = this.actors.get(e.id) ?? this.actor(e);
      if (e.telegraph && !a.attacking) {
        a.attacking = true;
        const clip = a.clips.find((c) => /attack/i.test(c.name));
        if (clip) {
          a.mixer.stopAllAction();
          a.mixer.clipAction(clip).setLoop(T.LoopOnce, 1).play();
        }
      }
      a.progress = e.progress;
      a.lane = e.lane;
    }
    for (const [id, a] of this.actors) {
      if (!active.has(id) && !a.dead) a.dead = 0.001;
      a.hitstop = Math.max(0, a.hitstop - delta);
      const actorDelta = a.hitstop > 0 ? 0 : delta;
      a.mixer.update(actorDelta);
      const threat = !a.dead && a.attacking ? Math.max(0, (a.progress - .75) / .25) : 0;
      a.model.position.z = threat * .35 - a.hit * (this.motion ? .24 : .08);
      a.model.rotation.x = threat * .12 - a.hit * (this.motion ? .16 : .04);
      a.model.rotation.z = a.twist * a.hit * (this.motion ? .1 : .02);
      a.hit = Math.max(0, a.hit - delta * 8);
      if (a.dead) {
        a.dead += actorDelta;
        a.velocity.y -= actorDelta * 6;
        a.root.position.addScaledVector(a.velocity, actorDelta);
        a.root.position.y = Math.max(-.2, a.root.position.y);
        a.root.rotation.z += actorDelta * a.twist * (.3 + this.level * .1);
        if (a.dead > 1.7) a.root.scale.setScalar(Math.max(.01, (2.4 - a.dead) / .7));
        if (a.dead > 2.4) {
          this.scene.remove(a.root);
          this.actors.delete(id);
          a.root.traverse((o) => {
            if (o instanceof T.SkinnedMesh) o.skeleton.dispose();
          });
          continue;
        }
        if (!a.clips.some((c) => /death|dead|dying/i.test(c.name)))
          a.root.rotation.x = -Math.min(1.5, a.dead * 2);
      } else {
        a.root.position.set(
          a.lane * 1.75,
          0,
          this.cameraZ - (7.8 - a.progress * 5.2),
        );
        a.root.rotation.z = Math.sin(this.elapsed * 31) * a.hit * 0.055;
      }
    }
    this.recoil = Math.max(0, this.recoil - delta * 13);
    this.gun.rotation.x = this.recoil * (this.motion ? .24 : .05);
    this.gun.rotation.z = -this.recoil * (this.motion ? .06 : .01);
    const target = state?.enemies.find((e) => e.id === state.lockedId);
    this.gun.rotation.y = T.MathUtils.damp(
      this.gun.rotation.y,
      T.MathUtils.clamp((0.48 - (target?.lane ?? 0) * 1.75) * 0.17, -0.24, 0.3),
      12,
      delta,
    );
    this.gun.position.z = -0.65 + this.recoil * (this.motion ? .06 : .015);
    this.gun.position.y =
      -0.19 + (this.motion ? Math.sin(this.elapsed * 1.4) * 0.003 : 0);
    this.muzzle.visible = this.recoil > 0.45;
    this.muzzle.rotation.z = Math.random() * Math.PI;
    this.muzzle.scale.setScalar(this.motion ? 1 + this.level * .16 : .45);
    this.flash.intensity = this.recoil > 0.45 ? (this.motion ? 22 + this.level * 5 : 5) : 0;
    this.impact = Math.max(0, this.impact - delta * 5);
    if (this.motion) {
      this.camera.position.x = Math.sin(this.elapsed * 87) * this.impact * .028;
      this.camera.rotation.z = Math.cos(this.elapsed * 63) * this.impact * .009;
    }
    this.camera.fov = T.MathUtils.damp(this.camera.fov, 55 + (this.motion ? this.impact * 2 : 0), 16, delta);
    this.camera.updateProjectionMatrix();
    this.effects.update(delta);
    if (this.motion && this.recoil > 0)
      this.camera.rotation.x = this.recoil * 0.008;
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life -= delta;
      p.velocity.y -= delta * 8;
      p.mesh.position.addScaledVector(p.velocity, delta);
      p.mesh.scale.setScalar(Math.max(0.1, p.life * 2));
      if (p.life <= 0) {
        this.scene.remove(p.mesh);
        this.particles.splice(i, 1);
      }
    }
    const level = state?.effectsLevel ?? 0;
    this.bloom.strength = this.motion ? 0.3 + level * 0.13 : 0.2;
    this.environment?.update(this.elapsed, level);
    this.composer.render();
  }
  project(id: number) {
    const a = this.actors.get(id);
    if (!a) return null;
    const v = a.root.position.clone();
    v.y = a.height + .25;
    v.project(this.camera);
    return {
      x: (v.x * 0.5 + 0.5) * innerWidth,
      y: (-0.5 * v.y + 0.5) * innerHeight,
    };
  }
}
