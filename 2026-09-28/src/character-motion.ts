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
  leftThigh: string;
  rightThigh: string;
  leftShin: string;
  rightShin: string;
  chest: string;
  upperChest: string;
  neck?: string;
  head: string;
  leftShoulder: string;
  rightShoulder: string;
  leftArm: string;
  rightArm: string;
};

// Names and anatomical roles are from the two rigged GLBs used in v0.4.
const rigs: Record<CharacterAsset, RigNames> = {
  city: {
    hips: "mixamorigHips", leftThigh: "mixamorigLeftUpLeg", rightThigh: "mixamorigRightUpLeg",
    leftShin: "mixamorigLeftLeg", rightShin: "mixamorigRightLeg",
    chest: "mixamorigSpine1", upperChest: "mixamorigSpine2",
    neck: "mixamorigNeck", head: "mixamorigHead",
    leftShoulder: "mixamorigLeftShoulder", rightShoulder: "mixamorigRightShoulder",
    leftArm: "mixamorigLeftArm", rightArm: "mixamorigRightArm",
  },
  thin: {
    hips: "hips", leftThigh: "thighL", rightThigh: "thighR", leftShin: "shinL", rightShin: "shinR",
    chest: "spine", upperChest: "ribs", neck: "neck", head: "head",
    leftShoulder: "shoulderL", rightShoulder: "shoulderR",
    leftArm: "upper_armL", rightArm: "upper_armR",
  },
};

const axisX = new T.Vector3(1, 0, 0);
const axisY = new T.Vector3(0, 1, 0);
const axisZ = new T.Vector3(0, 0, 1);

export class CharacterMotion {
  private readonly bones: Partial<Record<keyof RigNames, T.Bone>> = {};
  private readonly saved = new Map<T.Bone, T.Quaternion>();
  private readonly savedPositions = new Map<T.Bone, T.Vector3>();
  private readonly hasAttack: boolean;
  private readonly hasDeath: boolean;
  private readonly boss: boolean;
  private readonly model: T.Group;
  private readonly localAxis = new T.Vector3();
  private readonly parentRotation = new T.Quaternion();
  private readonly additive = new T.Quaternion();

  constructor(character: CharacterInstance, kind: EnemyKind) {
    this.model = character.model;
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
    if (zone === "head") point.y += 0.08 * this.model.scale.y;
    if (zone === "chest") point.y += 0.04 * this.model.scale.y;
    return point;
  }

  /** Removes last frame's additive pose before the mixer writes its new pose. */
  step(mixer: T.AnimationMixer, delta: number, state: CharacterPoseState): void {
    this.restore();
    // Freeze the last living stance during the boss's staged kneel. Keeping
    // the walk cycle running would make the feet paddle through the ground.
    mixer.update(this.boss && state.dead > 0 ? 0 : delta);
    this.model.updateWorldMatrix(true, true);

    const hit = T.MathUtils.clamp(state.hit, 0, 1);
    const hitStrength = hit * hit * (3 - 2 * hit) * (state.reducedMotion ? 0.42 : 1);
    const threat = T.MathUtils.clamp(state.threat, 0, 1);
    const death = state.dead > 0 ? T.MathUtils.smoothstep(state.dead, 0, 0.62) : 0;
    const phase = this.boss ? T.MathUtils.clamp(state.phase ?? 0, 0, 2) : 0;

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

    if (this.boss && state.dead > 0) {
      // One knee buckles, the other follows, then the upper body falls forward.
      // Root motion is controlled by the scene, so this remains visible through
      // the full three-second boss resolution instead of flying away.
      const kneel = T.MathUtils.smoothstep(state.dead, 0.1, 0.95);
      const collapse = T.MathUtils.smoothstep(state.dead, 1.05, 2.45);
      this.translate("hips", 0, -0.32 * kneel - 0.13 * collapse, 0);
      this.rotate("leftThigh", axisX, 0.84 * kneel);
      this.rotate("leftShin", axisX, -1.18 * kneel);
      this.rotate("rightThigh", axisX, 0.38 * kneel + 0.25 * collapse);
      this.rotate("rightShin", axisX, -0.86 * kneel);
      this.rotate("chest", axisX, 0.18 * kneel + 0.62 * collapse);
      this.rotate("upperChest", axisX, 0.13 * kneel + 0.43 * collapse);
      this.rotate("head", axisX, -0.18 * kneel + 0.28 * collapse);
      this.rotate("leftArm", axisX, -0.28 * kneel + 0.72 * collapse);
      this.rotate("rightArm", axisX, -0.36 * kneel + 0.64 * collapse);
      this.rotate("leftShoulder", axisZ, -0.18 * collapse);
      this.rotate("rightShoulder", axisZ, 0.18 * collapse);
    } else if (!this.hasDeath && death > 0) {
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
    for (const [bone, original] of this.savedPositions) bone.position.copy(original);
    this.saved.clear();
    this.savedPositions.clear();
  }

  private translate(role: keyof RigNames, x: number, y: number, z: number): void {
    const bone = this.bones[role];
    if (!bone) return;
    if (!this.savedPositions.has(bone)) this.savedPositions.set(bone, bone.position.clone());
    bone.position.add(new T.Vector3(x, y, z));
    bone.updateWorldMatrix(false, true);
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
