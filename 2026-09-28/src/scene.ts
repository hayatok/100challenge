import * as T from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { loadCharacterLibrary, type CharacterLibrary } from "./characters.ts";
import { createCharacterMotion, type CharacterMotion } from "./character-motion.ts";
import { CombatEffects } from "./effects.ts";
import { createWeapon, animateWeapon } from "./weapon.ts";
import { createEnvironment } from "./environment.ts";
import type { EnemyView, GameEvent, GameState } from "./game.ts";

type Actor = {
  root: T.Group;
  age: number;
  entrance: number;
  motion: CharacterMotion;
  kind: EnemyView["kind"];
  hitZone: "head" | "chest" | "shoulder";
  phase: number;
  recovering: boolean;
  walk: T.AnimationClip;
  shadow: T.Mesh;
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
  private weaponModel?: T.Group;
  private finishing = 0;
  private revealRemaining = 0;
  private impact = 0;
  private level = 0;
  private celebration = 0;
  private previousTier = 0;
  private bossLight = new T.PointLight(0xe84427, 0, 12, 2);
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
    this.scene.add(this.camera, this.bossLight);
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
    this.weaponModel = await createWeapon();
    this.gun.add(this.weaponModel);
    const warm = ["office", "office", "runner", "worker", "boss"].map((kind, id) => this.characters.create(kind as EnemyView["kind"], id).model);
    for (const [index, model] of warm.entries()) {
      model.position.set((index - 2) * .6, 0, -2);
      this.scene.add(model);
    }
    const warmShell = new T.Mesh(this.shellGeo, this.shellMat);
    const warmShadow = new T.Mesh(this.shadowGeo, this.shadowMat);
    warmShell.position.set(0, 1, -1);
    warmShadow.position.set(0, 0, -1);
    this.scene.add(warmShell, warmShadow);
    this.muzzle.visible = true;
    this.effects.burst(new T.Vector3(0, 1.2, -4), 4, true, false);
    this.effects.finisher(new T.Vector3(0, 1.2, -4), 4, false);
    await this.renderer.compileAsync(this.scene, this.camera);
    this.renderer.render(this.scene, this.camera);
    // Allocate the post-processing targets and shot-only materials during loading.
    this.composer.render();
    this.muzzle.visible = false;
    this.scene.remove(warmShell, warmShadow);
    this.effects.reset();
    for (const model of warm) {
      this.scene.remove(model);
      model.traverse(o => { if (o instanceof T.SkinnedMesh) o.skeleton.dispose(); });
    }
  }
  reset(stage = 0) {
    for (const a of this.actors.values()) {
      this.scene.remove(a.root, a.shadow);
      a.motion.dispose();
      a.mixer.stopAllAction();
      a.root.traverse((o) => {
        if (o instanceof T.SkinnedMesh) o.skeleton.dispose();
      });
    }
    this.actors.clear();
    for (const p of this.particles) this.scene.remove(p.mesh);
    this.particles = [];
    this.recoil = 0;
    this.finishing = 0;
    this.revealRemaining = 0;
    this.impact = 0;
    this.celebration = 0;
    this.previousTier = 0;
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
  private actor(e: Pick<EnemyView, "id" | "kind" | "lane" | "progress">) {
    if (e.kind === "boss") {
      const previous = [...this.actors].find(([,actor]) => actor.boss && actor.recovering && !actor.dead);
      if (previous) {
        const [id, actor] = previous;
        this.actors.delete(id);
        actor.recovering = false; actor.attacking = false; actor.progress = e.progress;
        actor.mixer.stopAllAction(); actor.mixer.clipAction(actor.walk).play();
        this.actors.set(e.id, actor);
        return actor;
      }
    }
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
    this.scene.add(shadow);
    const mixer = new T.AnimationMixer(model);
    const clip = character.walk ?? character.clips[0];
    if (clip) {
      mixer.clipAction(clip).play();
      mixer.setTime(e.id * 0.417);
    }
    const a: Actor = {
      root,
      age: 0,
      entrance: e.lane || (e.id % 2 ? 1 : -1),
      model,
      motion: createCharacterMotion(character, e.kind),
      kind: e.kind,
      hitZone: "chest",
      phase: 0,
      recovering: false,
      walk: character.walk,
      shadow,
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
    if (e.type === "stage" && e.stage === 3) {
      const preview = this.actor({id: -1, kind: "boss", lane: 0, progress: 0});
      preview.recovering = true;
      preview.root.position.set(0, 0, -51);
      this.revealRemaining = 2.2;
    }
    const a = e.enemyId ? this.actors.get(e.enemyId) : undefined;
    if (e.type === "hit") {
      this.recoil = 1;
      if (e.finisher && this.level >= 2) this.finishing = 1;
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
        a.hitZone = e.hitZone ?? "chest";
        if (a.hitstop <= 0) a.hitstop = .035;
        const hit = a.motion.target(a.hitZone) ?? a.root.position.clone().add(new T.Vector3(a.hitZone === "shoulder" ? .23 : 0, a.height * (a.hitZone === "head" ? .9 : .68), .1));
        hit.addScaledVector(this.camera.position.clone().sub(hit).normalize(), .12);
        // The body reads through sustained fire; the last key has its own larger flash.
        this.effects.burst(hit, this.level, false, !this.motion, e.finisher ? 1.5 : .65);
        if (e.finisher) {
          this.impact = Math.max(this.impact, .5);
          if (this.level >= 2) this.effects.finisher(hit, this.level, !this.motion);
        }
        this.effects.tracer(this.muzzle.getWorldPosition(new T.Vector3()), hit, this.level);
      }
    }
    if (e.type === "kill" && a) {
      const milestone = (e.effectsLevel ?? 0) > this.previousTier || ((e.combo ?? 0) >= 20 && (e.combo ?? 0) % 5 === 0);
      if (milestone) this.celebration = 1;
      this.previousTier = e.effectsLevel ?? this.level;
      if (a.boss && (e.phase ?? 0) < 2) {
        a.recovering = true; a.hit = 1; a.phase = (e.phase ?? 0) + 1;
        this.effects.burst(a.root.position.clone().add(new T.Vector3(0, 1.9, 0)), this.level, true, !this.motion, 1);
        this.impact = .6;
        return;
      }
      a.dead = 0.001;
      a.hitstop = .04;
      this.impact = a.boss ? 1.2 : .5 + this.level * .07;
      const weight = a.kind === "runner" ? 1.3 : a.kind === "worker" ? .48 : a.boss ? .12 : .9;
      a.velocity.set(a.twist * .3 * weight, a.boss ? 0 : .45 * weight, -(1.4 + this.level * .18) * weight);
      const death = a.clips.find((c) => /death|dead|dying/i.test(c.name));
      if (death) {
        a.velocity.y = 0;
        a.mixer.stopAllAction();
        const action = a.mixer.clipAction(death);
        action.setLoop(T.LoopOnce, 1);
        action.clampWhenFinished = true;
        action.play();
      }
      this.effects.burst(a.root.position.clone().add(new T.Vector3(0, a.boss ? 1.9 : 1.3, 0)), this.level, true, !this.motion, a.boss ? 1.8 : milestone ? 1.35 : .85);
    }
    if (e.type === "attack" && a) {
      if (a.boss) { a.recovering = true; a.attacking = false; }
      else a.dead = 2.2;
    }
    if (e.type === "bossPhase" && e.phase === 3) this.celebration = 1.6;
  }
  update(dt: number, state: GameState | null) {
    this.gun.visible = !!state;
    const running =
      !state ||
      !["paused", "countdown"].includes(state.mode);
    const delta = running ? dt : 0;
    this.elapsed += delta;
    this.revealRemaining = Math.max(0, this.revealRemaining - delta);
    this.finishing = Math.max(0, this.finishing - delta * 5.5);
    this.celebration = Math.max(0, this.celebration - delta * .65);
    this.level = state?.effectsLevel ?? 0;
    this.previousTier = Math.min(this.previousTier, this.level);
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
      a.phase = e.kind === "boss" ? (state?.bossPhase ?? 0) : 0;
      a.progress = e.progress;
      a.lane = e.lane;
    }
    for (const [id, a] of this.actors) {
      if (!active.has(id) && !a.dead && !a.recovering) a.dead = 0.001;
      a.age += delta;
      a.hitstop = Math.max(0, a.hitstop - delta);
      const actorDelta = a.hitstop > 0 ? 0 : delta;
      const threat = !a.dead && a.attacking ? Math.max(0, (a.progress - .75) / .25) : 0;
      a.motion.step(a.mixer, actorDelta, {hit: a.hit, hitZone: a.hitZone, threat, dead: a.dead, reducedMotion: !this.motion, phase: a.phase});
      const weight = a.kind === "worker" || a.boss ? .4 : 1;
      a.model.position.z = threat * .22 - a.hit * (this.motion ? .12 : .04) * weight;
      a.model.rotation.x = a.recovering && this.revealRemaining <= 0 ? -.12 : 0;
      a.model.rotation.z = 0;
      a.hit = Math.max(0, a.hit - delta * 8);
      if (a.dead) {
        a.dead += actorDelta;
        a.velocity.x *= Math.exp(-actorDelta * 6);
        a.velocity.z *= Math.exp(-actorDelta * 5);
        if (!a.boss) a.velocity.y -= actorDelta * 6;
        a.root.position.addScaledVector(a.velocity, actorDelta);
        a.root.position.y = Math.max(-.035, a.root.position.y);
        a.root.rotation.z += actorDelta * a.twist * (a.boss ? 0 : a.kind === "worker" ? .025 : .07);
        const hold = a.boss ? 2.8 : 1.7;
        if (a.dead > hold) a.root.scale.setScalar(Math.max(.01, 1 - (a.dead - hold) / .7));
        if (a.dead > hold + .7) {
          this.scene.remove(a.root, a.shadow);
          a.motion.dispose();
          this.actors.delete(id);
          a.root.traverse((o) => {
            if (o instanceof T.SkinnedMesh) o.skeleton.dispose();
          });
          continue;
        }
        if (!a.boss && !a.clips.some((c) => /death|dead|dying/i.test(c.name)))
          a.root.rotation.x = -Math.min(a.boss ? .65 : 1.45, a.dead * (a.boss ? .35 : 1.5));
      } else {
        const distance = a.boss ? 7.8 - (a.recovering ? .1 : a.progress) * 5.0 : 6.6 - a.progress * 3.8;
        const z = this.cameraZ - distance;
        const entry = this.motion ? 1 - T.MathUtils.smoothstep(a.age, 0, .85) : 0;
        const laneX = a.lane * Math.min(1.75, distance * .35);
        const x = laneX + (a.boss ? 0 : entry * a.entrance * (3.1 - Math.abs(laneX)));
        const bossZ = this.revealRemaining > 0 ? -47.8 - 3.2 * (this.revealRemaining / 2.2) : z;
        a.root.position.set(x, 0, a.boss ? T.MathUtils.damp(a.root.position.z || bossZ, bossZ, 5, delta) : z - entry * .8);
        a.root.rotation.y = a.boss ? 0 : -entry * a.entrance * .32;
        a.root.rotation.z = Math.sin(this.elapsed * 31) * a.hit * 0.055;
      }
      a.shadow.position.set(a.root.position.x, .015, a.root.position.z);
      a.shadow.visible = !a.dead || a.dead < (a.boss ? 2.8 : 1.7);
    }
    const boss = [...this.actors.values()].find(a => a.boss && !a.dead);
    this.bossLight.intensity = boss ? (this.motion ? 20 + boss.phase * 9 : 10) : 0;
    if (boss) this.bossLight.position.copy(boss.root.position).add(new T.Vector3(-1.2, 1.8, .9));
    this.recoil = Math.max(0, this.recoil - delta * 13);
    if (this.weaponModel) animateWeapon(this.weaponModel, this.recoil, this.finishing > .1, this.motion);
    this.gun.rotation.x = this.recoil * (this.motion ? .24 : .05);
    this.gun.rotation.z = -this.recoil * (this.motion ? .06 : .01);
    const target = state?.enemies.find((e) => e.id === state.lockedId);
    const targetX = target ? this.actors.get(target.id)?.root.position.x ?? 0 : 0;
    this.gun.rotation.y = T.MathUtils.damp(
      this.gun.rotation.y,
      T.MathUtils.clamp((0.48 - targetX) * 0.17, -0.24, 0.3),
      12,
      delta,
    );
    this.gun.position.z = -0.65 + this.recoil * (this.motion ? .06 : .015);
    this.gun.position.y =
      -0.19 + (this.motion ? Math.sin(this.elapsed * 1.4) * 0.003 : 0);
    this.muzzle.visible = this.recoil > 0.45;
    if (delta > 0) this.muzzle.rotation.z = Math.random() * Math.PI;
    this.muzzle.scale.setScalar(this.motion ? .75 + this.level * .04 + this.finishing * .45 : .4);
    this.flash.intensity = this.recoil > 0.45 ? (this.motion ? 15 + this.level * 2 : 4) : 0;
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
    this.bloom.strength = this.motion ? .25 + level * .055 + this.celebration * .22 : .18;
    this.environment?.update(this.elapsed, level, this.motion);
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
