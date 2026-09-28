import assert from "node:assert/strict";
import test from "node:test";
import * as T from "three";
import { CharacterMotion, sampleDance } from "../src/character-motion.ts";
import type { CharacterInstance } from "../src/characters.ts";
import { reverseClip } from "../src/characters.ts";

function cityRig(): { character: CharacterInstance; bones: Record<string, T.Bone> } {
  const model = new T.Group();
  const armature = new T.Group();
  armature.scale.setScalar(0.01);
  model.add(armature);
  const bones: Record<string, T.Bone> = {};
  const add = (name: string, parent: T.Object3D, x = 0, y = 0) => {
    const bone = new T.Bone();
    bone.name = `mixamorig${name}`;
    bone.position.set(x, y, 0);
    parent.add(bone);
    bones[name] = bone;
    return bone;
  };
  const hips = add("Hips", armature, 0, 91.9);
  const spine = add("Spine1", hips, 0, 12);
  const upper = add("Spine2", spine, 0, 14);
  const neck = add("Neck", upper, 0, 16);
  add("Head", neck, 0, 9);
  for (const side of ["Left", "Right"]) {
    const thigh = add(`${side}UpLeg`, hips, side === "Left" ? 9 : -9, -6);
    const shin = add(`${side}Leg`, thigh, 0, -42);
    add(`${side}Foot`, shin, 0, -43);
    const shoulder = add(`${side}Shoulder`, upper, side === "Left" ? 7 : -7, 13);
    add(`${side}Arm`, shoulder, 0, 14);
  }
  const walk = new T.AnimationClip("walk", 1, []);
  return {
    character: {
      asset: "city", model, clips: [walk], walk, height: 1.795, name: "test",
      attacks: [], hits: [], deaths: [],
    },
    bones,
  };
}

test("two authored dances move both legs, pelvis and arms on the beat", () => {
  const left = sampleDance(0, 0.25);
  const right = sampleDance(0, 1.25);
  const turn = sampleDance(1, 0.25);
  assert.notDeepEqual(left, right);
  assert.notDeepEqual(left, turn);
  assert.ok(Math.abs(left[0]) > 0.05 && Math.abs(left[4]) > 0.3 && Math.abs(left[8]) > 0.3);
  assert.ok(Math.abs(turn[4]) > 0.3 && Math.abs(turn[7]) > 0.3);
});

test("city dance keeps planted foot in place and does not accumulate pose", () => {
  const { character, bones } = cityRig();
  const motion = new CharacterMotion(character, "office");
  const mixer = new T.AnimationMixer(character.model);
  character.model.updateWorldMatrix(true, true);
  const restingFoot = bones.LeftFoot.getWorldPosition(new T.Vector3());
  const state = { lucky: true, danceStyle: 0 as const, danceTime: 0.125, hit: 0, threat: 0, dead: 0, reducedMotion: false };
  motion.step(mixer, 0.016, state);
  const first = bones.LeftFoot.getWorldPosition(new T.Vector3());
  assert.ok(first.distanceTo(restingFoot) < 0.025, `planted foot slipped ${first.distanceTo(restingFoot)}`);
  const hip = bones.Hips.getWorldPosition(new T.Vector3());
  assert.ok(Math.abs(hip.x) > 0.02 && Math.abs(hip.x) < 0.25);
  motion.step(mixer, 0.016, state);
  const again = bones.Hips.getWorldPosition(new T.Vector3());
  assert.ok(hip.distanceTo(again) < 1e-6, `additive dance accumulated ${hip.distanceTo(again)}`);
  motion.dispose();
  assert.ok(bones.Hips.getWorldPosition(new T.Vector3()).distanceTo(new T.Vector3(0, 0.919, 0)) < 1e-6);
});

test("boss kneel translates city pelvis by meters through the scaled rig", () => {
  const { character, bones } = cityRig();
  const motion = new CharacterMotion(character, "boss");
  motion.step(new T.AnimationMixer(character.model), 0.016, { hit: 0, threat: 0, dead: 1, reducedMotion: false });
  const hipY = bones.Hips.getWorldPosition(new T.Vector3()).y;
  assert.ok(hipY < 0.7 && hipY > 0.45, `kneel hips were ${hipY}`);
});

test("reversed city death clip starts standing and ends prone", () => {
  const original = new T.AnimationClip("Zombie_Dying", 2, [
    new T.VectorKeyframeTrack("mixamorigHips.position", [0, 1, 2], [0, -29, 0, 0, 35, 0, 0, 92, 0]),
  ]);
  const fall = reverseClip(original, "Zombie_Dying_Fall");
  assert.deepEqual(Array.from(fall.tracks[0].times), [0, 1, 2]);
  assert.deepEqual(Array.from(fall.tracks[0].values), [0, 92, 0, 0, 35, 0, 0, -29, 0]);
  assert.equal(original.tracks[0].values[1], -29);
});

test("rapid impacts retain energy and death poses diverge", () => {
  const { character, bones } = cityRig();
  const motion = new CharacterMotion(character, "office");
  const mixer = new T.AnimationMixer(character.model);
  motion.step(mixer, 0.016, { hit: 1, hitSerial: 1, threat: 0, dead: 0, reducedMotion: false });
  const first = bones.Spine2.quaternion.clone();
  motion.step(mixer, 0.016, { hit: 1, hitSerial: 2, threat: 0, dead: 0, reducedMotion: false });
  const second = bones.Spine2.quaternion.clone();
  assert.ok(first.angleTo(second) > 0.05, "a second hit changes recoil direction");
  const poses: T.Quaternion[] = [];
  for (const deathVariant of [0, 1, 2]) {
    motion.step(mixer, 0.016, { hit: 0, threat: 0, dead: 0.8, reducedMotion: false, deathVariant });
    poses.push(bones.Spine2.quaternion.clone());
  }
  assert.ok(poses[0].angleTo(poses[1]) > 0.05);
  assert.ok(poses[1].angleTo(poses[2]) > 0.05);
});

test("side step trades a raised arm with a lifted opposite leg while the stance foot stays", () => {
  const { character, bones } = cityRig();
  const motion = new CharacterMotion(character, "office");
  const mixer = new T.AnimationMixer(character.model);
  character.model.updateWorldMatrix(true, true);
  const restLeft = bones.LeftFoot.getWorldPosition(new T.Vector3());
  const restRight = bones.RightFoot.getWorldPosition(new T.Vector3());
  const base = { lucky: true, danceStyle: 0 as const, hit: 0, threat: 0, dead: 0, reducedMotion: false };
  motion.step(mixer, 0.016, { ...base, danceTime: 0.25 });
  const rightPump = bones.RightShoulder.quaternion.clone();
  const rightSwing = bones.RightUpLeg.quaternion.clone();
  assert.ok(bones.LeftFoot.getWorldPosition(new T.Vector3()).distanceTo(restLeft) < 0.025);
  motion.step(mixer, 0.016, { ...base, danceTime: 1.25 });
  assert.ok(bones.RightFoot.getWorldPosition(new T.Vector3()).distanceTo(restRight) < 0.025);
  assert.ok(rightPump.angleTo(bones.RightShoulder.quaternion) > 0.8);
  assert.ok(rightSwing.angleTo(bones.RightUpLeg.quaternion) > 0.5);
});
