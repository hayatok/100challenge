import * as T from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { clone } from "three/addons/utils/SkeletonUtils.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { createWeapon } from "./weapon.ts";
import { createEnvironment } from "./environment.ts";
import type { EnemyView, GameEvent, GameState } from "./game.ts";

type Actor = {
  root: T.Group;
  mixer: T.AnimationMixer;
  clips: T.AnimationClip[];
  hit: number;
  dead: number;
  lane: number;
  progress: number;
  boss: boolean;
  attacking: boolean;
};
export class World {
  readonly renderer: T.WebGLRenderer;
  readonly camera = new T.PerspectiveCamera(55, 1, 0.08, 110);
  readonly scene = new T.Scene();
  private composer: EffectComposer;
  private bloom: UnrealBloomPass;
  private environment!: Awaited<ReturnType<typeof createEnvironment>>;
  private zombie!: T.Group;
  private clips: T.AnimationClip[] = [];
  private actors = new Map<number, Actor>();
  private gun = new T.Group();
  private muzzle: T.Mesh;
  private flash = new T.PointLight(0xffb85a, 0, 7);
  private recoil = 0;
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
  private sparkGeo = new T.SphereGeometry(0.035, 4, 3);
  private sparkMat = new T.MeshBasicMaterial({ color: 0xffbf52 });
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
    g.addColorStop(0.2, "#ffffce");
    g.addColorStop(0.45, "#ffa323");
    g.addColorStop(1, "#ff6b0000");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 128, 128);
    this.muzzle = new T.Mesh(
      new T.PlaneGeometry(0.45, 0.45),
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
    const loader = new GLTFLoader();
    onProgress("住人たちが出勤しています");
    const z = await loader.loadAsync(
      `${import.meta.env.BASE_URL}assets/characters/zombie.glb`,
    );
    this.zombie = z.scene;
    this.clips = z.animations;
    this.zombie.traverse((o) => {
      if (o instanceof T.Mesh) {
        o.castShadow = true;
        o.frustumCulled = false;
        for (const mat of Array.isArray(o.material)
          ? o.material
          : [o.material]) {
          if (mat instanceof T.MeshStandardMaterial) {
            mat.metalness = 0;
            mat.roughness = 0.8;
            if (/Body/i.test(mat.name)) {
              mat.onBeforeCompile = (shader) => {
                shader.fragmentShader = shader.fragmentShader.replace(
                  "#include <color_fragment>",
                  "#include <color_fragment>\nfloat pallor=dot(diffuseColor.rgb,vec3(.299,.587,.114)); diffuseColor.rgb=mix(diffuseColor.rgb,vec3(pallor*1.15,pallor*1.28,pallor*1.17),.78);",
                );
              };
              mat.customProgramCacheKey = () => "infected-skin-pallor-v1";
            }
          }
        }
      }
    });
    onProgress("装備を確認しています");
    this.gun.add(await createWeapon());
    const warm = clone(this.zombie);
    this.scene.add(warm);
    await this.renderer.compileAsync(this.scene, this.camera);
    this.renderer.render(this.scene, this.camera);
    this.scene.remove(warm);
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
    const model = clone(this.zombie);
    root.add(model);
    model.scale.setScalar((e.kind === "boss" ? 2.7 : 1.8) / 1.795);
    if (e.kind === "worker") model.scale.x *= 1.22;
    if (e.kind === "runner") model.scale.x *= 0.88;
    const shadow = new T.Mesh(this.shadowGeo, this.shadowMat);
    if (e.kind === "boss") shadow.scale.setScalar(1.6);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.015;
    root.add(shadow);
    const mixer = new T.AnimationMixer(model);
    const clip =
      this.clips.find((c) => c.name === "Zombie_Walk") ?? this.clips[0];
    if (clip) {
      mixer.clipAction(clip).play();
      mixer.setTime(e.id * 0.417);
    }
    const a: Actor = {
      root,
      mixer,
      clips: this.clips,
      hit: 0,
      dead: 0,
      lane: e.lane,
      progress: e.progress,
      boss: e.kind === "boss",
      attacking: false,
    };
    this.scene.add(root);
    this.actors.set(e.id, a);
    return a;
  }
  event(e: GameEvent) {
    const a = e.enemyId ? this.actors.get(e.enemyId) : undefined;
    if (e.type === "hit") {
      this.recoil = 1;
      const shell = new T.Mesh(this.shellGeo, this.shellMat);
      this.gun.getWorldPosition(shell.position);
      shell.rotation.z = 1;
      this.scene.add(shell);
      this.particles.push({
        mesh: shell,
        velocity: new T.Vector3(1.6, 1.5, 0.6),
        life: 0.7,
      });
      if (a) {
        a.hit = 1;
        this.sparks(
          a.root.position.clone().add(new T.Vector3(0, a.boss ? 2 : 1.35, 0)),
          6,
        );
      }
    }
    if (e.type === "kill" && a) {
      a.dead = 0.001;
      const death = a.clips.find((c) => /death|dead|dying/i.test(c.name));
      if (death) {
        a.mixer.stopAllAction();
        const action = a.mixer.clipAction(death);
        action.setLoop(T.LoopOnce, 1);
        action.clampWhenFinished = true;
        action.play();
      }
      this.sparks(a.root.position.clone().add(new T.Vector3(0, 1.2, 0)), 26);
    }
    if (e.type === "attack" && a) a.dead = 2.2;
  }
  private sparks(pos: T.Vector3, n: number) {
    for (let i = 0; i < n; i++) {
      const mesh = new T.Mesh(this.sparkGeo, this.sparkMat);
      mesh.position.copy(pos);
      this.scene.add(mesh);
      this.particles.push({
        mesh,
        velocity: new T.Vector3(
          (Math.random() - 0.5) * 4,
          Math.random() * 3,
          (Math.random() - 0.3) * 3,
        ),
        life: 0.3 + Math.random() * 0.4,
      });
    }
  }
  update(dt: number, state: GameState | null) {
    this.gun.visible = !!state;
    this.elapsed += dt;
    const running =
      !state ||
      !["paused", "countdown", "defeat", "clear"].includes(state.mode);
    const delta = running ? dt : 0;
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
        const clip = a.clips.find((c) => c.name === "Zombie_Attack");
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
      a.mixer.update(delta);
      a.hit = Math.max(0, a.hit - delta * 8);
      if (a.dead) {
        a.dead += delta;
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
    this.gun.rotation.x = this.recoil * 0.16;
    const target = state?.enemies.find((e) => e.id === state.lockedId);
    this.gun.rotation.y = T.MathUtils.damp(
      this.gun.rotation.y,
      T.MathUtils.clamp((0.48 - (target?.lane ?? 0) * 1.75) * 0.17, -0.24, 0.3),
      12,
      delta,
    );
    this.gun.position.z = -0.65 + this.recoil * 0.06;
    this.gun.position.y =
      -0.19 + (this.motion ? Math.sin(this.elapsed * 1.4) * 0.003 : 0);
    this.muzzle.visible = this.recoil > 0.45;
    this.muzzle.rotation.z = Math.random() * Math.PI;
    this.flash.intensity = this.recoil > 0.45 ? 12 : 0;
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
    this.bloom.strength = this.motion ? 0.26 + level * 0.075 : 0.2;
    this.environment?.update(this.elapsed, level);
    this.composer.render();
  }
  project(id: number) {
    const a = this.actors.get(id);
    if (!a) return null;
    const v = a.root.position.clone();
    v.y = a.boss ? 2.95 : 2.05;
    v.project(this.camera);
    return {
      x: (v.x * 0.5 + 0.5) * innerWidth,
      y: (-0.5 * v.y + 0.5) * innerHeight,
    };
  }
}
