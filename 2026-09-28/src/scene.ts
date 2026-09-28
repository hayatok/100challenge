import * as T from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { GTAOPass } from 'three/addons/postprocessing/GTAOPass.js';
import { StreetAtmosphere } from './atmosphere.ts';
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { loadCharacterLibrary, chooseDeathClip, type CharacterInstance, type CharacterLibrary } from "./characters.ts";
import { createCharacterMotion, type CharacterMotion } from "./character-motion.ts";
import { CombatEffects } from "./effects.ts";
import { createWeapon, animateWeapon, setWeaponMode } from "./weapon.ts";
import { createDistrict } from "./district.ts";
import { RailDirector, approachDistance } from "./rail.ts";
import type { EnemyView, GameEvent, GameState } from "./game.ts";

type Actor = {
  root: T.Group;
  character: CharacterInstance;
  lucky: boolean;
  danceTime: number;
  danceStep: number;
  sentencePose: number;
  luckyExit: number;
  luckySuccess: boolean;
  hitSerial: number;
  deathVariant: number;
  currentAction?: T.AnimationAction;
  introRemaining: number;
  tank?: T.Group;
  blastTargets: number[];
  rush: boolean;
  age: number;
  support: boolean;
  landed: boolean;
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
class ContactShade extends GTAOPass {
  override setSize(width:number,height:number){super.setSize(Math.max(1,Math.round(width*.55)),Math.max(1,Math.round(height*.55)));}
}
export class World {
  readonly renderer: T.WebGLRenderer;
  readonly camera = new T.PerspectiveCamera(55, 1, 0.08, 110);
  readonly scene = new T.Scene();
  private composer: EffectComposer;
  private bloom: UnrealBloomPass;
  private atmosphere:StreetAtmosphere;
  private ambience=new T.HemisphereLight(0x99bed1,0x302920,.42);
  private playerFill=new T.PointLight(0xf2c39c,3.5,12,2);
  private environment!: Awaited<ReturnType<typeof createDistrict>>;
  private characters!: CharacterLibrary;
  private actors = new Map<number, Actor>();
  private gun = new T.Group();
  private muzzle: T.Mesh;
  private flash = new T.PointLight(0xffb85a, 0, 7);
  private recoil = 0;
  private weaponModel?: T.Group;
  private finishing = 0;
  private rushing = false;
  private tankTemplate = this.createTank();
  private revealRemaining = 0;
  private impact = 0;
  private level = 0;
  private celebration = 0;
  private previousTier = 0;
  private bossLight = new T.PointLight(0xe84427, 0, 12, 2);
  private luckyLight = new T.PointLight(0xff89d5,0,10,2);
  private luckyFill = new T.PointLight(0xffd373,0,10,2);
  private luckyFloor = new T.Mesh(new T.RingGeometry(.95,1,64),new T.MeshBasicMaterial({color:0xffa6d7,transparent:true,opacity:.45,side:T.DoubleSide,depthWrite:false}));
  private effects = new CombatEffects(this.scene);
  private rail = new RailDirector();
  get moving() { return this.rail.moving; }
  get area() { return this.rail.area; }
  private keyLight = new T.DirectionalLight(0xbedaff,2.6);
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
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = T.PCFShadowMap;
    container.append(this.renderer.domElement);
    const studio=new RoomEnvironment();
    const pmrem=new T.PMREMGenerator(this.renderer);
    this.scene.environment=pmrem.fromScene(studio,.04).texture;
    this.scene.environmentIntensity=.32;
    studio.dispose();pmrem.dispose();
    this.scene.background = new T.Color("#121d23");
    this.scene.fog = new T.FogExp2("#152129", 0.027);
    this.scene.add(this.ambience);
    const key = this.keyLight;
    key.castShadow=true;key.shadow.mapSize.set(2048,2048);
    Object.assign(key.shadow.camera,{left:-8,right:8,top:8,bottom:-8,near:1,far:32});
    key.shadow.bias=-.0003;key.shadow.normalBias=.035;
    key.position.set(-4, 8, 5);
    this.scene.add(key,key.target);
    this.scene.add(this.camera, this.bossLight,this.luckyLight,this.luckyFill,this.luckyFloor);
    this.luckyFloor.rotation.x=-Math.PI/2;this.luckyFloor.visible=false;
    this.camera.position.set(0, 1.65, 5);
    const fill = this.playerFill;
    fill.position.set(0, 2, -1);
    this.camera.add(fill);
    this.camera.add(this.gun);
    this.gun.position.set(0.48, -0.10, -0.65);
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
    const shade=new ContactShade(this.scene,this.camera,1,1);
    shade.updateGtaoMaterial({radius:.45,thickness:.7,distanceFallOff:.7,samples:8});
    shade.updatePdMaterial({samples:8,rings:2,radius:4});
    shade.blendIntensity=.55;this.composer.addPass(shade);
    this.atmosphere=new StreetAtmosphere(this.scene);
    this.bloom = new UnrealBloomPass(new T.Vector2(1, 1), 0.35, 0.4, 1.05);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.resize();
    window.addEventListener("resize", () => { this.resize(); this.composer.render(); });
  }
  async load(onProgress: (text: string) => void) {
    onProgress("商店街の灯りを点けています");
    this.environment = await createDistrict(this.scene);
    onProgress("住人たちが出勤しています");
    this.characters = await loadCharacterLibrary();
    onProgress("装備を確認しています");
    this.weaponModel = await createWeapon();
    this.gun.add(this.weaponModel);
    const warm = ["office", "office", "runner", "worker", "boss"].map((kind, id) => this.characters.create(kind as EnemyView["kind"], id).model);
    warm.push(this.characters.create("office",100,true).model);
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
    this.effects.confetti(new T.Vector3(0,1.5,-4),false);
    this.luckyFloor.visible=true;
    this.effects.update(.0001);
    const warmTank = this.tankTemplate.clone();
    warmTank.position.set(0, 1, -2);
    this.scene.add(warmTank);
    setWeaponMode(this.weaponModel,'shotgun');
    await this.renderer.compileAsync(this.scene, this.camera);
    this.renderer.render(this.scene,this.camera);
    setWeaponMode(this.weaponModel,'pistol');
    await this.renderer.compileAsync(this.scene, this.camera);
    this.renderer.render(this.scene, this.camera);
    // Allocate the post-processing targets and shot-only materials during loading.
    this.composer.render();
    this.muzzle.visible = false;
    this.luckyFloor.visible=false;
    this.scene.remove(warmShell, warmShadow, warmTank);
    this.effects.reset();
    for (const model of warm) {
      this.scene.remove(model);
      model.traverse(o => { if (o instanceof T.SkinnedMesh) o.skeleton.dispose(); });
    }
  }
  reset(_stage = 0) {
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
    this.rushing = false;
    this.luckyFloor.visible=false;this.luckyLight.intensity=0;this.luckyFill.intensity=0;
    this.revealRemaining = 0;
    this.impact = 0;
    this.celebration = 0;
    this.previousTier = 0;
    this.effects.reset();
    this.environment?.reset();
    this.rail.reset();
    this.cameraZ = 6;
  }
  private resize() {
    const w = window.innerWidth,
      h = window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
  }
  private createTank() {
    const pack = new T.Group();
    const red = new T.MeshStandardMaterial({color:0xa82317,roughness:.62,metalness:.25});
    const steel = new T.MeshStandardMaterial({color:0x303332,roughness:.65,metalness:.5});
    const warning = new T.MeshStandardMaterial({color:0xf9bd39,roughness:.68,emissive:0x8f3906,emissiveIntensity:.25});
    const cylinder = new T.CylinderGeometry(.12,.12,.6,12);
    const band = new T.CylinderGeometry(.127,.127,.09,12);
    const valve = new T.BoxGeometry(.13,.055,.08);
    for (const side of [-1,1]) {
      const body = new T.Mesh(cylinder,red);body.position.set(side*.29,0,-.1);pack.add(body);
      for(const y of [-.16,.17]){const belt=new T.Mesh(band,warning);belt.position.set(side*.29,y,-.1);pack.add(belt);}
      const top=new T.Mesh(valve,steel);top.position.set(side*.29,.335,-.1);pack.add(top);
      const strap=new T.Mesh(new T.BoxGeometry(.045,.52,.035),steel);strap.position.set(side*.19,0,.15);pack.add(strap);
    }
    const badge=new T.Mesh(new T.BoxGeometry(.2,.15,.035),warning);badge.position.set(0,.1,.19);pack.add(badge);
    return pack;
  }
  private actor(e: Pick<EnemyView, "id" | "kind" | "lane" | "progress"> & Partial<Pick<EnemyView,"explosive"|"blastTargets"|"rush"|"lucky"|"support">>) {
    if (e.kind === "boss") {
      const previous = [...this.actors].find(([,actor]) => actor.boss && actor.recovering && !actor.dead);
      if (previous) {
        const [id, actor] = previous;
        this.actors.delete(id);
        actor.recovering = false; actor.attacking = false; actor.progress = e.progress;
        this.playAction(actor,actor.walk,true);
        this.actors.set(e.id, actor);
        return actor;
      }
    }
    const root = new T.Group();
    const character = this.characters.create(e.kind, e.id, e.lucky);
    const model = character.model;
    root.add(model);
    const height = e.lucky ? 2.0 : e.kind === "boss" ? 2.7 : e.kind === "worker" ? 2.15 : 1.8;
    model.scale.multiplyScalar(height / character.height);
    const shadow = new T.Mesh(this.shadowGeo, this.shadowMat);
    if (e.kind === "boss") shadow.scale.setScalar(1.6);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.015;
    this.scene.add(shadow);
    const mixer = new T.AnimationMixer(model);
    const intro = !e.lucky && !e.rush && e.kind !== "boss" && e.id%4===0 ? character.clips.find(c=>/scream/i.test(c.name)) ?? character.idle : undefined;
    const clip = e.lucky ? character.idle : intro ?? character.walk;
    const currentAction = clip ? mixer.clipAction(clip).play() : undefined;
    if(currentAction) mixer.setTime(e.lucky ? .35 : intro ? 0 : e.id*.417);
    const a: Actor = {
      root, character, lucky:!!e.lucky, danceTime:0, danceStep:0, sentencePose:0,
      luckyExit:0,luckySuccess:false,hitSerial:0,deathVariant:e.id%3,currentAction,introRemaining:intro?.55:0,
      blastTargets: e.blastTargets ?? [],
      rush: !!e.rush,
      age: 0, support:!!e.support, landed:false,
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
    if (e.explosive) {a.tank = this.tankTemplate.clone(); root.add(a.tank);}
    this.scene.add(root);
    this.actors.set(e.id, a);
    return a;
  }
  private playAction(a:Actor,clip:T.AnimationClip,loop=false) {
    const next=a.mixer.clipAction(clip);next.reset();next.enabled=true;next.setEffectiveWeight(1);next.setEffectiveTimeScale(1);
    next.setLoop(loop?T.LoopRepeat:T.LoopOnce,loop?Infinity:1);next.clampWhenFinished=!loop;next.play();
    if(a.currentAction && a.currentAction!==next) next.crossFadeFrom(a.currentAction,.14,false);
    a.currentAction=next;
  }
  event(e: GameEvent) {
    this.level = e.effectsLevel ?? this.level;
    if (e.type === "rushStart") {this.rushing = true;this.celebration = 1.2;}
    if (e.type === "rushEnd") {this.rushing = false;this.celebration = e.success ? 2 : 0;if(e.success)this.effects.confetti(new T.Vector3(this.rail.position.x,2,this.cameraZ-5),!this.motion,.7);}
    if(e.type === "luckyStart" && e.enemyId && !this.actors.has(e.enemyId)) this.actor({id:e.enemyId,kind:"office",lane:0,progress:0,lucky:true});
    const a = e.enemyId ? this.actors.get(e.enemyId) : undefined;
    if(e.type === "luckyStep" && a){
      a.danceStep=e.step ?? a.danceStep+1;a.sentencePose=1;
      this.effects.confetti(a.root.position.clone().add(new T.Vector3(0,1.7,0)),!this.motion,.4);
    }
    if(e.type === "luckyEnd" && a){
      a.luckyExit=.001;a.luckySuccess=!!e.success;a.danceStep=e.success?3:a.danceStep;a.sentencePose=e.success?1:0;
      if(e.success){this.effects.confetti(a.root.position.clone().add(new T.Vector3(0,1.6,0)),!this.motion);this.effects.finale(a.root.position.clone().add(new T.Vector3(0,2,0)),4,!this.motion);this.celebration=2;}
    }
    if (e.type === "explosion" && a) {
      const origin = a.root.position.clone().add(new T.Vector3(0,1.35,0));
      this.effects.explosion(origin,!this.motion);this.impact = .8;this.celebration = 1.1;
      if(a.tank)a.tank.visible=false;
      for(const id of a.blastTargets){const other=this.actors.get(id);if(other)this.effects.tracer(origin,other.root.position.clone().add(new T.Vector3(0,1.2,0)),2);}
    }
    if (e.type === "hit") {
      this.recoil = 1;
      if (e.finisher) this.finishing = 1;
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
        a.hitSerial++;
        a.hitZone = e.hitZone ?? "chest";
        if (!a.lucky && a.hitstop <= 0) a.hitstop = .035;
        const hit = a.motion.target(a.hitZone) ?? a.root.position.clone().add(new T.Vector3(a.hitZone === "shoulder" ? .23 : 0, a.height * (a.hitZone === "head" ? .9 : .68), .1));
        hit.addScaledVector(this.camera.position.clone().sub(hit).normalize(), .12);
        // The body reads through sustained fire; the last key has its own larger flash.
        this.effects.burst(hit, a.lucky ? 3 : this.level, false, !this.motion, a.lucky ? .45 : e.finisher ? .8 : .35);
        if (e.finisher) {
          this.impact = Math.max(this.impact, .5);
          this.effects.finisher(hit, this.level, !this.motion, true);
        }
        this.effects.tracer(this.muzzle.getWorldPosition(new T.Vector3()), hit, this.level);
      }
    }
    if (e.type === "kill" && a) {
      const milestone = !e.collateral && ((e.effectsLevel ?? 0) > this.previousTier || ((e.combo ?? 0) >= 20 && (e.combo ?? 0) % 5 === 0));
      if (milestone) {this.celebration = 1.5;this.effects.confetti(a.root.position.clone().add(new T.Vector3(0,2,0)),!this.motion,.45);}
      this.previousTier = e.effectsLevel ?? this.level;
      if (a.boss && (e.phase ?? 0) < 2) {
        a.recovering = true; a.hit = 1; a.phase = Math.min(2, e.phase ?? 0);
        this.effects.burst(a.root.position.clone().add(new T.Vector3(0, 1.9, 0)), this.level, true, !this.motion, 1);
        this.impact = .6;
        return;
      }
      a.dead = 0.001;
      a.hitstop = this.motion ? .075 : .04;
      this.impact = a.boss ? 1.2 : .5 + this.level * .07;
      const weight = a.kind === "runner" ? 1.3 : a.kind === "worker" ? .48 : a.boss ? .12 : .9;
      a.velocity.set((a.rush ? (a.lane||a.twist)*4.5 : a.twist*.8) * weight, a.boss ? 0 : (a.rush ? 2.1 : .55) * weight, -(a.rush ? 8.5 : 4.8) * weight).applyAxisAngle(new T.Vector3(0,1,0),this.rail.position.yaw);
      const death = chooseDeathClip(a.character,a.hitSerial,a.deathVariant);
      if (death) {
        if (!a.rush) a.velocity.y = 0;
        this.playAction(a,death);
      }
      this.effects.burst(a.root.position.clone().add(new T.Vector3(0, a.boss ? 1.9 : 1.3, 0)), this.level, true, !this.motion, a.boss ? 1.1 : e.collateral ? .4 : a.rush ? .6 : .5,true);
      if(!a.boss && this.rail.area==='court') {
        const origin=a.root.position.clone().add(new T.Vector3(0,1.1,0));
        if(this.environment.strike(origin,a.velocity))return true;
      }
    }
    if (e.type === "attack" && a) {
      if (a.boss) { a.recovering = true; a.attacking = false; }
      else a.dead = 2.2;
    }
    if (e.type === "clear") {this.celebration = 2.4;this.effects.confetti(new T.Vector3(this.rail.position.x,2,this.cameraZ-5),!this.motion,.7);}
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
    this.rushing = state?.rushing ?? false;
    this.previousTier = Math.min(this.previousTier, this.level);
    this.rail.update(delta,state);
    const view=this.rail.position;
    this.cameraZ=view.z;
    this.camera.position.set(view.x,view.y,view.z);
    this.camera.rotation.set(0,view.yaw,0);
    const indoor=this.rail.area==='store';
    const side=indoor?-2.2:-4,back=indoor?-.5:2;
    this.keyLight.position.set(view.x+Math.cos(view.yaw)*side+Math.sin(view.yaw)*back,view.y+(indoor?1.35:6),view.z-Math.sin(view.yaw)*side+Math.cos(view.yaw)*back);
    this.keyLight.target.position.set(view.x-Math.sin(view.yaw)*5,view.y-1.65,view.z-Math.cos(view.yaw)*5);
    this.keyLight.target.updateMatrixWorld();
    const quiet=!state || ['explore','vista','clear'].includes(state.mode) || this.rail.moving;
    this.keyLight.intensity=this.rail.area==='store'?1.15:this.rail.area==='roof'?1.4:1.05;
    this.keyLight.color.setHex(this.rail.area==='roof'?0xffccaa:0xb6cfe1);
    this.ambience.intensity=this.rail.area==='store'?.18:this.rail.area==='roof'?.7:.4;
    this.playerFill.intensity=this.rail.area==='store'?1.6:4.5;
    this.scene.environmentIntensity=indoor?.16:.3;
    this.atmosphere.update(delta,this.rail.area,view,this.motion);
    if(this.weaponModel)setWeaponMode(this.weaponModel,this.rushing?'shotgun':'pistol');
    const active = new Set<number>();
    for (const e of state?.enemies ?? []) {
      active.add(e.id);
      const a = this.actors.get(e.id) ?? this.actor(e);
      if (e.telegraph && !a.attacking) {
        a.attacking = true;
        const clip = a.character.attack;
        if (clip) this.playAction(a,clip);
      }
      if(e.lucky) a.danceStep=(state?.luckyStep ?? 1)-1;
      a.phase = e.kind === "boss" ? (state?.bossPhase ?? 0) : 0;
      a.blastTargets = e.blastTargets;
      a.rush = e.rush;
      a.progress = e.progress;
      a.lane = e.lane;
    }
    for (const [id, a] of this.actors) {
      // Timer events are dispatched after this update; luckyEnd owns the exit.
      if (!active.has(id) && !a.lucky && !a.dead && !a.recovering) a.dead = 0.001;
      a.age += delta;
      if(a.introRemaining>0){a.introRemaining-=delta;if(a.introRemaining<=0&&!a.attacking&&!a.dead)this.playAction(a,a.walk,true);}
      if(a.lucky) a.danceTime+=delta;
      a.sentencePose=Math.max(0,a.sentencePose-delta*1.3);
      if(a.luckyExit) {
        a.luckyExit+=delta;
        if(a.luckyExit>(a.luckySuccess?2:.8)){this.scene.remove(a.root,a.shadow);a.motion.dispose();a.mixer.stopAllAction();a.root.traverse(o=>{if(o instanceof T.SkinnedMesh)o.skeleton.dispose();});this.actors.delete(id);continue;}
      }
      a.hitstop = Math.max(0, a.hitstop - delta);
      const actorDelta = a.hitstop > 0 ? 0 : delta;
      const threat = !a.dead && a.attacking ? Math.max(0, (a.progress - .75) / .25) : 0;
      a.motion.step(a.mixer, actorDelta, {hit: a.hit, hitZone: a.hitZone, threat, dead: a.dead, reducedMotion: !this.motion, phase: a.phase, lucky:a.lucky,danceStyle:(id%2) as 0|1,danceTime:a.danceTime,luckyStep:a.danceStep,sentencePose:a.sentencePose,danceFinish:a.luckySuccess,hitSerial:a.hitSerial,deathVariant:a.deathVariant});
      const weight = a.kind === "worker" || a.boss ? .4 : 1;
      a.model.position.z = a.lucky ? 0 : threat * .22 - a.hit * (this.motion ? .12 : .04) * weight;
      a.model.rotation.x = a.recovering && this.revealRemaining <= 0 ? -.12 : 0;
      a.model.rotation.z = 0;
      a.hit = Math.max(0, a.hit - delta * 8);
      if(a.lucky && !a.dead) {
        const entry=1-T.MathUtils.smoothstep(a.age,0,.75);
        const exit=a.luckyExit ? T.MathUtils.smoothstep(a.luckyExit,a.luckySuccess?1.25:0,a.luckySuccess?2:.8) : 0;
        const sway=this.motion ? Math.sin(a.danceTime*.6)*.28 : 0;
        const lp=new T.Vector3(entry*-3.8+sway+exit*4.5,0,-6).applyAxisAngle(new T.Vector3(0,1,0),view.yaw);a.root.position.set(view.x+lp.x,0,view.z+lp.z);
        a.root.rotation.set(0,view.yaw,0);a.shadow.position.set(a.root.position.x,.015,a.root.position.z);a.shadow.visible=true;
        continue;
      }
      if (a.dead) {
        a.dead += actorDelta;
        a.velocity.x *= Math.exp(-actorDelta * 2.3);
        a.velocity.z *= Math.exp(-actorDelta * (a.rush ? 1.1 : 2.3));
        if (!a.boss) a.velocity.y -= actorDelta * 6;
        a.root.position.addScaledVector(a.velocity, actorDelta);
        if(a.root.position.y<0 && !a.landed){
          a.landed=true;
          if(a.rush)this.effects.burst(a.root.position.clone().setY(.15),1,true,!this.motion,.4);
        }
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
        if (!a.boss && !a.character.death)
          a.root.rotation.x = -Math.min(a.boss ? .65 : 1.45, a.dead * (a.boss ? .35 : 1.5));
      } else {
        const distance = approachDistance(a.recovering?0:a.progress,a.kind,this.rail.area==='store')+(a.support?1.1:0);
        const entry = this.motion ? 1 - T.MathUtils.smoothstep(a.age, 0, a.rush ? .2 : .7) : 0;
        const laneX = a.lane * Math.min(a.rush?1.65:1.3, distance * .36);
        const x = laneX + (a.boss || a.rush ? 0 : entry * a.entrance * (this.rail.area==='store'?1.2:2.1));
        const local=new T.Vector3(x,0,-distance-entry*.4).applyAxisAngle(new T.Vector3(0,1,0),view.yaw);
        a.root.position.set(view.x+local.x,0,view.z+local.z);
        a.root.rotation.y = view.yaw-(a.boss ? 0 : entry * a.entrance * .25);
        a.root.rotation.z = Math.sin(this.elapsed * 31) * a.hit * 0.04;
      }
      if (a.tank && a.tank.visible) {
        const chest = a.motion.target("chest");
        if(chest){a.tank.position.copy(a.root.worldToLocal(chest));a.tank.rotation.x=a.model.rotation.x;}
      }
      a.shadow.position.set(a.root.position.x, .015, a.root.position.z);
      a.shadow.visible = !a.dead || a.dead < (a.boss ? 2.8 : 1.7);
    }
    const lucky=[...this.actors.values()].find(a=>a.lucky&&!a.dead);
    this.luckyFloor.visible=!!lucky;
    this.luckyLight.intensity=lucky?(this.motion?17+Math.sin(lucky.danceTime*Math.PI*4)*3:12):0;
    this.luckyFill.intensity=lucky?16:0;
    if(lucky){
      this.luckyLight.position.copy(lucky.root.position).add(new T.Vector3(-1.3,2.4,1));this.luckyFill.position.copy(lucky.root.position).add(new T.Vector3(1.3,1.8,1));
      this.luckyFloor.position.set(lucky.root.position.x,.025,lucky.root.position.z);this.luckyFloor.scale.setScalar(1.2);
    }
    const boss = [...this.actors.values()].find(a => a.boss && !a.dead);
    this.bossLight.intensity = boss ? (this.motion ? 20 + boss.phase * 9 : 10) : 0;
    if (boss) this.bossLight.position.copy(boss.root.position).add(new T.Vector3(-1.2, 1.8, .9));
    this.recoil = Math.max(0, this.recoil - delta * 13);
    if (this.weaponModel) animateWeapon(this.weaponModel, this.recoil, this.finishing > .1, this.motion);
    this.gun.rotation.x = this.recoil * (this.motion ? .24 : .05);
    this.gun.rotation.z = -this.recoil * (this.motion ? .06 : .01);
    const target = state?.enemies.find((e) => e.id === state.lockedId);
    const targetActor=target?this.actors.get(target.id):undefined;
    const targetX=targetActor?targetActor.root.position.clone().sub(this.camera.position).applyAxisAngle(new T.Vector3(0,1,0),-view.yaw).x:0;
    this.gun.rotation.y = T.MathUtils.damp(
      this.gun.rotation.y,
      T.MathUtils.clamp((0.4 - targetX) * 0.4, -0.24, 0.3),
      12,
      delta,
    );
    this.gun.position.x=this.rushing?.22:.4;
    this.gun.position.z = (this.rushing?-.82:-.65) + this.recoil * (this.motion ? .06 : .015);
    this.gun.position.y =
      T.MathUtils.damp(this.gun.position.y,quiet?-.62:-.025,8,delta) + (this.motion ? Math.sin(this.elapsed * 1.4) * 0.001 : 0);
    this.muzzle.visible = this.recoil > 0.45;
    if (delta > 0) this.muzzle.rotation.z = Math.random() * Math.PI;
    this.muzzle.scale.setScalar(this.motion ? 1.05 + this.level * .12 + this.finishing * .95 : .4);
    this.flash.intensity = this.recoil > 0.45 ? (this.motion ? 20 + this.level * 3 + this.finishing*12 : 4) : 0;
    this.impact = Math.max(0, this.impact - delta * 5);
    if (this.motion) {
      this.camera.position.x += Math.sin(this.elapsed * 87) * this.impact * .028;
      this.camera.rotation.z = Math.cos(this.elapsed * 63) * this.impact * .009;
    }
    this.camera.fov = T.MathUtils.damp(this.camera.fov, 55 + (this.motion ? this.impact * 2 + (this.rushing ? 1.5 : 0) : 0), 16, delta);
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
    this.bloom.strength = this.motion ? .2 + level * .025 + this.celebration * .06 : .15;
    this.environment?.update(this.elapsed, this.rail.area, this.motion);
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
