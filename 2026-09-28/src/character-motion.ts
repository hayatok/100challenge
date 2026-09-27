import * as T from "three";
import type { EnemyKind } from "./game.ts";
import type { CharacterAsset, CharacterInstance } from "./characters.ts";

export type HitZone = "head" | "chest" | "shoulder";

export type CharacterPoseState = {
  hit: number;
  hitZone?: HitZone;
  threat: number;
  dead: number;
  reducedMotion: boolean;
  /** Boss phase, starting at zero. */
  phase?: number;
};

type RigNames = {
  hips: string;
  chest: string;
  upperChest: string;
  neck?: string;
  head: string;
  leftShoulder: string;
  rightShoulder: string;
  leftArm: string;
  rightArm: string;
};

// Names and anatomical roles are from the four shipped GLB skeletons. In
// particular, Creature's anonymous joint2/3/4 are torso/upper chest/head.
const rigs: Record<CharacterAsset, RigNames> = {
  city: {
    hips: "mixamorigHips", chest: "mixamorigSpine1", upperChest: "mixamorigSpine2",
    neck: "mixamorigNeck", head: "mixamorigHead",
    leftShoulder: "mixamorigLeftShoulder", rightShoulder: "mixamorigRightShoulder",
    leftArm: "mixamorigLeftArm", rightArm: "mixamorigRightArm",
  },
  granny: {
    hips: "mixamorigHips", chest: "mixamorigSpine1", upperChest: "mixamorigSpine2",
    neck: "mixamorigNeck", head: "mixamorigHead",
    leftShoulder: "mixamorigLeftShoulder", rightShoulder: "mixamorigRightShoulder",
    leftArm: "mixamorigLeftArm", rightArm: "mixamorigRightArm",
  },
  thin: {
    hips: "hips", chest: "spine", upperChest: "ribs", neck: "neck", head: "head",
    leftShoulder: "shoulderL", rightShoulder: "shoulderR",
    leftArm: "upper_armL", rightArm: "upper_armR",
  },
  creature: {
    hips: "joint1", chest: "joint2", upperChest: "joint3", head: "joint4",
    leftShoulder: "Clav_L", rightShoulder: "Clav_R",
    leftArm: "joint14", rightArm: "joint14001",
  },
};

const axisX = new T.Vector3(1, 0, 0);
const axisY = new T.Vector3(0, 1, 0);
const axisZ = new T.Vector3(0, 0, 1);

export class CharacterMotion {
  private readonly bones: Partial<Record<keyof RigNames, T.Bone>> = {};
  private readonly saved = new Map<T.Bone, T.Quaternion>();
  private readonly hasAttack: boolean;
  private readonly hasDeath: boolean;
  private readonly asset: CharacterAsset;
  private readonly boss: boolean;
  private readonly model: T.Group;
  private readonly localAxis = new T.Vector3();
  private readonly parentRotation = new T.Quaternion();
  private readonly additive = new T.Quaternion();

  constructor(character: CharacterInstance, kind: EnemyKind) {
    this.model = character.model;
    this.asset = character.asset;
    this.boss = kind === "boss";
    this.hasAttack = !!character.attack;
    this.hasDeath = !!character.death;
    const names = rigs[character.asset];
    for (const role of Object.keys(names) as (keyof RigNames)[]) {
      const found = this.model.getObjectByName(names[role]!);
      if (found instanceof T.Bone) this.bones[role] = found;
    }
  }

  /** Returns a fresh world point so tracers and bursts can share the pose's hit zone. */
  target(zone: HitZone): T.Vector3 | null {
    const role = zone === "head" ? "head" : zone === "shoulder" ? "leftShoulder" : "upperChest";
    const bone = this.bones[role];
    if (!bone) return null;
    const point = bone.getWorldPosition(new T.Vector3());
    if (zone === "head") point.y += (this.asset === "granny" ? 0.14 : 0.08) * this.model.scale.y;
    if (zone === "chest") point.y += 0.04 * this.model.scale.y;
    return point;
  }

  /** Removes last frame's additive pose before the mixer writes its new pose. */
  step(mixer: T.AnimationMixer, delta: number, state: CharacterPoseState): void {
    this.restore();
    mixer.update(delta);
    this.model.updateWorldMatrix(true, true);

    const hit = T.MathUtils.clamp(state.hit, 0, 1);
    const hitStrength = hit * hit * (3 - 2 * hit) * (state.reducedMotion ? 0.42 : 1);
    const threat = T.MathUtils.clamp(state.threat, 0, 1);
    const death = state.dead > 0 ? T.MathUtils.smoothstep(state.dead, 0, 0.62) : 0;
    const phase = this.boss ? T.MathUtils.clamp(state.phase ?? 0, 0, 2) : 0;

    // The shipped Granny walk folds at three upper-body joints. Straighten
    // them separately so the glasses and face remain above the hairline while
    // preserving the original stooped silhouette and step cycle.
    if (this.asset === "granny") {
      this.rotate("chest", axisX, -0.18);
      this.rotate("upperChest", axisX, -0.23);
      this.rotate("neck", axisX, -0.17);
      this.rotate("head", axisX, -0.16);
    }

    if (phase > 0 && death === 0) {
      this.rotate("chest", axisX, -0.035 * phase);
      this.rotate("leftShoulder", axisZ, 0.065 * phase);
      this.rotate("rightShoulder", axisZ, -0.065 * phase);
      this.rotate("head", axisY, Math.sin(phase * 1.8) * 0.065);
    }

    if (!this.hasAttack && threat > 0 && death === 0) {
      const reach = threat * threat * (3 - 2 * threat);
      this.rotate("chest", axisX, 0.14 * reach);
      this.rotate("upperChest", axisX, 0.11 * reach);
      this.rotate("leftArm", axisX, -0.66 * reach);
      this.rotate("rightArm", axisX, -0.81 * reach);
      this.rotate("leftShoulder", axisZ, -0.1 * reach);
      this.rotate("rightShoulder", axisZ, 0.1 * reach);
      this.rotate("head", axisX, -0.08 * reach);
    }

    if (hitStrength > 0 && death === 0) {
      const zone = state.hitZone ?? "chest";
      if (zone === "head") {
        this.rotate("neck", axisX, -0.23 * hitStrength);
        this.rotate("head", axisX, -0.21 * hitStrength);
        this.rotate("head", axisZ, 0.1 * hitStrength);
      } else if (zone === "shoulder") {
        this.rotate("leftShoulder", axisZ, 0.3 * hitStrength);
        this.rotate("leftArm", axisX, 0.2 * hitStrength);
        this.rotate("upperChest", axisZ, 0.09 * hitStrength);
      } else {
        this.rotate("chest", axisX, -0.14 * hitStrength);
        this.rotate("upperChest", axisX, -0.18 * hitStrength);
        this.rotate("head", axisX, 0.07 * hitStrength);
      }
    }

    if (!this.hasDeath && death > 0) {
      const jerk = Math.sin(Math.min(state.dead, 0.34) * 26) * (1 - death);
      this.rotate("chest", axisX, -0.22 * death - 0.08 * jerk);
      this.rotate("upperChest", axisZ, 0.2 * death);
      this.rotate("neck", axisX, -0.16 * death);
      this.rotate("head", axisX, 0.26 * death);
      this.rotate("leftArm", axisX, 0.38 * death);
      this.rotate("rightArm", axisX, 0.46 * death);
      this.rotate("leftShoulder", axisZ, 0.18 * death);
      this.rotate("rightShoulder", axisZ, -0.18 * death);
    }
  }

  dispose(): void {
    this.restore();
  }

  private restore(): void {
    for (const [bone, original] of this.saved) bone.quaternion.copy(original);
    this.saved.clear();
  }

  private rotate(role: keyof RigNames, axis: T.Vector3, angle: number): void {
    const bone = this.bones[role];
    if (!bone || Math.abs(angle) < 0.0001) return;
    if (!this.saved.has(bone)) this.saved.set(bone, bone.quaternion.clone());
    bone.parent?.getWorldQuaternion(this.parentRotation);
    this.localAxis.copy(axis).applyQuaternion(this.parentRotation.invert()).normalize();
    this.additive.setFromAxisAngle(this.localAxis, angle);
    bone.quaternion.premultiply(this.additive);
    bone.updateWorldMatrix(false, true);
  }
}

export function createCharacterMotion(character: CharacterInstance, kind: EnemyKind): CharacterMotion {
  return new CharacterMotion(character, kind);
}
