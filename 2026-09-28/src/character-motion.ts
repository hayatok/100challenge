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
  /** Lucky-only authored performance. Time is elapsed seconds, excluding pause. */
  lucky?: boolean;
  danceStyle?: 0 | 1;
  danceTime?: number;
  luckyStep?: number;
  sentencePose?: number;
  danceFinish?: boolean;
  /** Increments for every projectile impact, including rapid consecutive shots. */
  hitSerial?: number;
  deathVariant?: number;
};

type RigNames = {
  hips: string;
  leftThigh: string;
  rightThigh: string;
  leftShin: string;
  rightShin: string;
  leftFoot: string;
  rightFoot: string;
  chest: string;
  upperChest: string;
  neck?: string;
  head: string;
  leftShoulder: string;
  rightShoulder: string;
  leftArm: string;
  rightArm: string;
  leftForearm: string;
  rightForearm: string;
};

// Names and anatomical roles are from the two rigged GLBs used in v0.4.
const rigs: Record<CharacterAsset, RigNames> = {
  city: {
    hips: "mixamorigHips", leftThigh: "mixamorigLeftUpLeg", rightThigh: "mixamorigRightUpLeg",
    leftShin: "mixamorigLeftLeg", rightShin: "mixamorigRightLeg",
    leftFoot: "mixamorigLeftFoot", rightFoot: "mixamorigRightFoot",
    chest: "mixamorigSpine1", upperChest: "mixamorigSpine2",
    neck: "mixamorigNeck", head: "mixamorigHead",
    leftShoulder: "mixamorigLeftShoulder", rightShoulder: "mixamorigRightShoulder",
    leftArm: "mixamorigLeftArm", rightArm: "mixamorigRightArm",
    leftForearm: "mixamorigLeftForeArm", rightForearm: "mixamorigRightForeArm",
  },
  thin: {
    hips: "hips", leftThigh: "thighL", rightThigh: "thighR", leftShin: "shinL", rightShin: "shinR",
    leftFoot: "footL", rightFoot: "footR",
    chest: "spine", upperChest: "ribs", neck: "neck", head: "head",
    leftShoulder: "shoulderL", rightShoulder: "shoulderR",
    leftArm: "upper_armL", rightArm: "upper_armR",
    leftForearm: "forearmL", rightForearm: "forearmR",
  },
};

const axisX = new T.Vector3(1, 0, 0);
const axisY = new T.Vector3(0, 1, 0);
const axisZ = new T.Vector3(0, 0, 1);

// [hip side, hip lift, hip turn, left/right thigh, left/right shin,
//  left/right arm, torso roll, head turn]. One cycle has eight deliberate
//  contact/recovery poses at 120 BPM. Sampling is eased between authored poses.
type DanceKey = readonly [number, number, number, number, number, number, number, number, number, number, number];
const SIDE_STEP: readonly DanceKey[] = [
  [0, 0, 0, 0, 0, 0, 0, -0.16, 0.26, 0, 0],
  [-0.09, -0.035, -0.17, -0.1, 0.74, 0.08, -0.85, -0.38, 0.65, -0.15, -0.12],
  [-0.14, -0.065, -0.23, 0.08, 0.15, -0.1, -0.2, -0.55, 0.83, -0.2, -0.1],
  [-0.06, 0.035, -0.08, 0.68, -0.04, -0.82, 0.05, 0.23, -0.18, 0.09, 0.1],
  [0, 0, 0, 0, 0, 0, 0, 0.28, -0.13, 0, 0],
  [0.09, -0.035, 0.17, 0.74, -0.1, -0.85, 0.08, 0.65, -0.38, 0.15, 0.12],
  [0.14, -0.065, 0.23, 0.15, 0.08, -0.2, -0.1, 0.83, -0.55, 0.2, 0.1],
  [0.06, 0.035, 0.08, -0.04, 0.68, 0.05, -0.82, -0.18, 0.23, -0.09, -0.1],
];
const HEEL_TURN: readonly DanceKey[] = [
  [0, -0.055, -0.17, 0.24, 0.05, -0.29, -0.08, -0.55, 0.1, -0.12, 0.17],
  [-0.04, 0.035, -0.28, 0.06, 0.75, -0.1, -0.82, -0.72, 0.34, -0.17, 0.2],
  [-0.08, -0.08, -0.36, 0.34, 0.07, -0.43, -0.12, -0.35, 0.65, -0.22, 0.27],
  [-0.03, 0.025, -0.1, -0.06, 0.63, 0.07, -0.7, 0.18, -0.52, 0.08, 0.05],
  [0, -0.055, 0.17, 0.05, 0.24, -0.08, -0.29, 0.1, -0.55, 0.12, -0.17],
  [0.04, 0.035, 0.28, 0.75, 0.06, -0.82, -0.1, 0.34, -0.72, 0.17, -0.2],
  [0.08, -0.08, 0.36, 0.07, 0.34, -0.12, -0.43, 0.65, -0.35, 0.22, -0.27],
  [0.03, 0.025, 0.1, 0.63, -0.06, -0.7, 0.07, -0.52, 0.18, -0.08, -0.05],
];

export function sampleDance(style: 0 | 1, seconds: number): DanceKey {
  const keys = style === 0 ? SIDE_STEP : HEEL_TURN;
  const phase = ((Math.max(0, seconds) * 4) % keys.length + keys.length) % keys.length;
  const index = Math.floor(phase);
  const fraction = phase - index;
  const eased = fraction * fraction * (3 - 2 * fraction);
  return keys[index].map((value, part) => T.MathUtils.lerp(value, keys[(index + 1) % keys.length][part], eased)) as unknown as DanceKey;
}

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
  private readonly unitsPerMeter: number;
  private hitEnergy = 0;
  private lastHit = 0;
  private lastHitSerial = -1;
  private hitDirection = 1;

  constructor(character: CharacterInstance, kind: EnemyKind) {
    this.model = character.model;
    this.boss = kind === "boss";
    this.hasAttack = !!character.attack;
    this.hasDeath = !!character.death;
    this.unitsPerMeter = character.asset === "city" ? 100 : 1 / 0.88;
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
    mixer.update((this.boss && state.dead > 0) || state.lucky ? 0 : delta);
    this.model.updateWorldMatrix(true, true);

    const hit = T.MathUtils.clamp(state.hit, 0, 1);
    const freshHit = state.hitSerial !== undefined
      ? state.hitSerial !== this.lastHitSerial
      : hit > this.lastHit + 0.35;
    if (freshHit && hit > 0) {
      this.hitDirection = ((state.hitSerial ?? Math.round(state.danceTime ?? 0)) % 2) ? -1 : 1;
      this.hitEnergy = Math.min(1.25, this.hitEnergy + 0.58);
    }
    this.lastHit = hit;
    if (state.hitSerial !== undefined) this.lastHitSerial = state.hitSerial;
    this.hitEnergy = Math.max(hit * 0.45, this.hitEnergy * Math.exp(-Math.max(0, delta) * 10));
    const hitStrength = T.MathUtils.clamp(this.hitEnergy, 0, 1) * (state.reducedMotion ? 0.42 : 1);
    const threat = T.MathUtils.clamp(state.threat, 0, 1);
    const death = state.dead > 0 ? T.MathUtils.smoothstep(state.dead, 0, 0.62) : 0;
    const phase = this.boss ? T.MathUtils.clamp(state.phase ?? 0, 0, 2) : 0;

    if (state.lucky && state.dead <= 0) {
      this.dance(state);
      return;
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
        this.rotate("head", axisZ, this.hitDirection * 0.13 * hitStrength);
      } else if (zone === "shoulder") {
        this.rotate(this.hitDirection > 0 ? "leftShoulder" : "rightShoulder", axisZ, this.hitDirection * 0.3 * hitStrength);
        this.rotate(this.hitDirection > 0 ? "leftArm" : "rightArm", axisX, 0.2 * hitStrength);
        this.rotate("upperChest", axisZ, this.hitDirection * 0.13 * hitStrength);
      } else {
        this.rotate("chest", axisX, -0.14 * hitStrength);
        this.rotate("upperChest", axisX, -0.18 * hitStrength);
        this.rotate("upperChest", axisZ, this.hitDirection * 0.11 * hitStrength);
        this.rotate("head", axisX, 0.07 * hitStrength);
      }
    }

    if (this.boss && state.dead > 0) {
      // One knee buckles, the other follows, then the upper body falls forward.
      // Root motion is controlled by the scene, so this remains visible through
      // the full three-second boss resolution instead of flying away.
      const kneel = T.MathUtils.smoothstep(state.dead, 0.1, 0.95);
      const collapse = T.MathUtils.smoothstep(state.dead, 1.05, 2.45);
      this.translate("hips", 0, (-0.32 * kneel - 0.13 * collapse) * this.unitsPerMeter, 0);
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
    } else if (death > 0) {
      const variant = ((state.deathVariant ?? 0) % 3 + 3) % 3;
      const jerk = Math.sin(Math.min(state.dead, 0.34) * 26) * (1 - death);
      const sign = variant === 1 ? -1 : 1;
      const bend = variant === 2 ? 0.28 : -0.22;
      this.rotate("chest", axisX, bend * death - 0.08 * jerk);
      this.rotate("upperChest", axisZ, sign * (variant === 2 ? 0.08 : 0.2) * death);
      this.rotate("neck", axisX, -0.16 * death);
      this.rotate("head", axisX, (variant === 2 ? -0.19 : 0.26) * death);
      this.rotate("leftArm", axisX, 0.38 * death);
      this.rotate("rightArm", axisX, (variant === 2 ? -0.22 : 0.46) * death);
      this.rotate("leftShoulder", axisZ, sign * 0.18 * death);
      this.rotate("rightShoulder", axisZ, -sign * 0.18 * death);
      if (!this.hasDeath) {
        const buckle = T.MathUtils.smoothstep(state.dead, 0.22, 0.9);
        this.translate("hips", 0, -0.28 * buckle * this.unitsPerMeter, 0);
        this.rotate("leftThigh", axisX, 0.6 * buckle);
        this.rotate("leftShin", axisX, -0.8 * buckle);
      }
    }
  }

  dispose(): void {
    this.restore();
  }

  private dance(state: CharacterPoseState): void {
    const style = state.danceStyle ?? 0;
    const key = sampleDance(style, state.danceFinish ? 0.75 : state.danceTime ?? 0);
    const power = state.reducedMotion ? 0.42 : 1;
    const leftFoot = this.bones.leftFoot;
    const rightFoot = this.bones.rightFoot;
    // The planted foot alternates on each half-beat. We restore its world
    // point after posing both legs, so pelvis sway cannot make it skate.
    const beat = Math.floor(Math.max(0, state.danceTime ?? 0) * 2) % 4;
    const plantRight = style === 0 ? beat === 1 || beat === 2 : beat >= 2;
    const planted = plantRight ? rightFoot : leftFoot;
    const groundPoint = planted?.getWorldPosition(new T.Vector3());
    const sentence = T.MathUtils.clamp(state.sentencePose ?? 0, 0, 1);
    const pulse = Math.sin(sentence * Math.PI);
    const finish = state.danceFinish ? 1 : 0;
    const keyPop = T.MathUtils.clamp(this.hitEnergy, 0, 1) * power;

    this.translate("hips", key[0] * power * this.unitsPerMeter, key[1] * power * this.unitsPerMeter, 0);
    this.rotate("hips", axisY, (key[2] + pulse * 0.42 + finish * 0.36) * power);
    this.rotate("leftThigh", axisX, (key[3] - finish * 0.12) * power);
    this.rotate("rightThigh", axisX, (key[4] + finish * 0.34) * power);
    // A small side lean through the stance leg offsets the translated pelvis;
    // contact correction then preserves visible hip travel instead of erasing it.
    this.rotate("leftThigh", axisZ, -key[0] * 1.2 * power);
    this.rotate("rightThigh", axisZ, -key[0] * 1.2 * power);
    this.rotate("leftThigh", axisZ, Math.max(0, key[3] - 0.2) * 0.36 * power);
    this.rotate("rightThigh", axisZ, -Math.max(0, key[4] - 0.2) * 0.36 * power);
    this.rotate("leftShin", axisX, key[5] * power);
    this.rotate("rightShin", axisX, (key[6] - finish * 0.45) * power);
    this.rotate("chest", axisZ, (-key[0] * 1.8 + key[9] * 0.4 + pulse * 0.13) * power);
    this.rotate("chest", axisX, -0.14 * keyPop);
    this.rotate("upperChest", axisY, (key[2] * 0.45 + pulse * 0.38 + finish * 0.22) * power);
    this.rotate("upperChest", axisZ, this.hitDirection * 0.12 * keyPop);
    this.rotate("leftArm", axisX, (key[7] - pulse * 0.4 - finish * 1.42) * power);
    this.rotate("rightArm", axisX, (key[8] - pulse * 0.4 - finish * 1.15) * power);
    // Opposing shoulders give two immediately readable motifs: alternating
    // fist pumps over the side step, and a straight disco point over the turn.
    const leftLift = style === 0
      ? T.MathUtils.clamp(key[0] / 0.1, 0, 1)
      : T.MathUtils.clamp(-key[2] * 3.6, 0, 1);
    const rightLift = style === 0
      ? T.MathUtils.clamp(-key[0] / 0.1, 0, 1)
      : T.MathUtils.clamp(key[2] * 3.6, 0, 1);
    this.rotate("leftShoulder", axisZ, T.MathUtils.lerp(-0.82, 1.12, Math.max(leftLift, finish)) * power);
    this.rotate("rightShoulder", axisZ, T.MathUtils.lerp(0.82, -1.12, Math.max(rightLift, finish)) * power);
    this.rotate("leftForearm", axisZ, (T.MathUtils.lerp(1.22, style === 1 ? 0.14 : 0.72, leftLift) + pulse * 0.2) * power);
    this.rotate("rightForearm", axisZ, (-T.MathUtils.lerp(1.22, style === 1 ? 0.14 : 0.72, rightLift) - pulse * 0.2) * power);
    this.rotate("head", axisY, (key[10] - pulse * 0.25 - finish * 0.21) * power);
    this.rotate("head", axisX, (-0.06 + finish * 0.19) * power);
    this.rotate("head", axisX, -0.11 * keyPop);
    if (groundPoint && planted) {
      this.model.updateWorldMatrix(true, true);
      const now = planted.getWorldPosition(new T.Vector3());
      const correction = groundPoint.sub(now);
      correction.y = Math.min(0.13, Math.max(-0.13, correction.y));
      correction.x = Math.min(0.16, Math.max(-0.16, correction.x));
      correction.z = Math.min(0.16, Math.max(-0.16, correction.z));
      this.translateWorld("hips", correction);
    }
  }

  private translateWorld(role: keyof RigNames, worldDelta: T.Vector3): void {
    const bone = this.bones[role];
    if (!bone || !bone.parent) return;
    bone.parent.updateWorldMatrix(true, false);
    const origin = bone.getWorldPosition(new T.Vector3());
    const from = bone.parent.worldToLocal(origin.clone());
    const to = bone.parent.worldToLocal(origin.add(worldDelta));
    const delta = to.sub(from);
    this.translate(role, delta.x, delta.y, delta.z);
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
