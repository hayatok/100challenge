import test from "node:test";
import assert from "node:assert/strict";
import * as T from "three";
import { CombatEffects } from "../src/effects.ts";

function withCanvas(run: () => void) {
  const previous = globalThis.document;
  const gradient = { addColorStop() { /* drawing is not needed for pool tests */ } };
  const context = { createRadialGradient: () => gradient, fillRect() { /* no-op */ }, fillStyle: "" };
  globalThis.document = { createElement: () => ({ width: 0, height: 0, getContext: () => context }) } as unknown as Document;
  try { run(); } finally { globalThis.document = previous; }
}

function pools(scene: T.Scene) {
  const instances = scene.children.filter((o): o is T.InstancedMesh => o instanceof T.InstancedMesh);
  const sprites = scene.children.filter((o): o is T.Sprite => o instanceof T.Sprite);
  const rings = scene.children.filter((o): o is T.Mesh => o instanceof T.Mesh && o.geometry instanceof T.RingGeometry);
  return { instances, sprites, rings };
}

test("heavy combat and finales stay in fixed draw and fleck pools", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const { instances, sprites, rings } = pools(scene);
  assert.equal(instances.length, 2);
  assert.ok(instances.every((mesh) => mesh.instanceMatrix.count === 600));
  assert.equal(sprites.length, 24);
  assert.equal(rings.length, 18);
  assert.equal(scene.children.length, 44);
  const initialObjects = [...scene.children];
  const materials = [instances[0].material, ...sprites.map((s) => s.material), ...rings.map((r) => r.material)]
    .flatMap((material) => Array.isArray(material) ? material : [material]);
  let disposed = 0;
  for (const material of materials) material.dispose = () => { disposed++; };

  for (let i = 0; i < 150; i++) {
    const pos = new T.Vector3(i % 9, 1, i % 5);
    effects.burst(pos, 4, true, false, 1.7);
    effects.explosion(pos, false);
    effects.confetti(pos, false);
    effects.finisher(pos, 4, false);
    effects.finale(pos, 4, false);
    effects.tracer(pos, pos.clone().add(new T.Vector3(3, 0, -2)), 4);
  }
  effects.update(.016);
  assert.ok(instances.every((mesh) => mesh.count <= 600));
  assert.ok(instances.reduce((sum, mesh) => sum + mesh.count, 0) <= 600);
  assert.ok(sprites.filter((s) => s.visible).length <= 24);
  assert.ok(rings.filter((r) => r.visible).length <= 18);
  assert.deepEqual(scene.children, initialObjects, "events create no scene draw objects");

  effects.update(3);
  assert.equal(instances.reduce((sum, mesh) => sum + mesh.count, 0), 0);
  assert.ok(sprites.every((s) => !s.visible));
  assert.ok(rings.every((r) => !r.visible));
  effects.burst(new T.Vector3(0, 1, 0), 3, true, false);
  effects.update(.001);
  assert.ok(instances.some((mesh) => mesh.count > 0), "expired slots can be reused");
  effects.reset();
  assert.ok(instances.every((mesh) => mesh.count === 0));
  assert.ok(sprites.every((s) => !s.visible));
  assert.ok(rings.every((r) => !r.visible));
  assert.deepEqual(scene.children, initialObjects);
  assert.equal(disposed, 0, "pooled materials survive reuse and reset");
}));

test("paused updates do no simulation or upload work, including with a queued effect", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const { instances, sprites, rings } = pools(scene);
  const pos = new T.Vector3(0, 1, 0);
  effects.finale(pos, 4, false);
  effects.update(.01);
  const counts = instances.map(mesh => mesh.count);
  const positions = sprites.map(sprite => sprite.position.y);
  const opacity = [...sprites.map(sprite => sprite.material.opacity), ...rings.map(ring => (ring.material as T.MeshBasicMaterial).opacity)];
  const scales = rings.map(ring => ring.scale.x);
  const uploadVersions = instances.map(mesh => [mesh.instanceMatrix.version, mesh.instanceColor!.version]);
  effects.confetti(pos, false);
  effects.update(0);
  assert.deepEqual(instances.map(mesh => mesh.count), counts);
  assert.deepEqual(sprites.map(sprite => sprite.position.y), positions);
  assert.deepEqual([...sprites.map(sprite => sprite.material.opacity), ...rings.map(ring => (ring.material as T.MeshBasicMaterial).opacity)], opacity);
  assert.deepEqual(rings.map(ring => ring.scale.x), scales);
  assert.deepEqual(instances.map(mesh => [mesh.instanceMatrix.version, mesh.instanceColor!.version]), uploadVersions);
  effects.update(.01);
  assert.ok(instances.some((mesh, i) => mesh.instanceMatrix.version > uploadVersions[i][0]));
}));

test("tracer spans its endpoints and stress transforms remain finite", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const [shard, streak] = pools(scene).instances;
  const from = new T.Vector3(-2, 1.5, 3);
  const to = new T.Vector3(5, 1.5, -1);
  effects.tracer(from, to, 4);
  effects.update(.001);
  assert.equal(streak.count, 1);
  const matrix = new T.Matrix4();
  streak.getMatrixAt(0, matrix);
  const near = new T.Vector3(0, 0, -.5).applyMatrix4(matrix);
  const far = new T.Vector3(0, 0, .5).applyMatrix4(matrix);
  assert.ok(near.distanceTo(from) < 1e-5);
  assert.ok(far.distanceTo(to) < 1e-5);
  const width = new T.Vector3(.5, 0, 0).applyMatrix4(matrix).distanceTo(new T.Vector3(-.5, 0, 0).applyMatrix4(matrix));
  assert.ok(width > .05, "high-tier tracer is visibly thicker");

  for (let i = 0; i < 10; i++) {
    effects.burst(new T.Vector3(i, 1, -i), i % 5, true, false, 1.7);
    effects.update(.013);
  }
  for (const mesh of [shard, streak]) {
    for (let i = 0; i < mesh.count; i++) {
      mesh.getMatrixAt(i, matrix);
      assert.ok(matrix.elements.every(Number.isFinite));
      const color = new T.Color();
      mesh.getColorAt(i, color);
      assert.ok([color.r, color.g, color.b].every(Number.isFinite));
    }
  }
}));

test("reduced finale keeps a compact flash and one ring", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const { instances, sprites, rings } = pools(scene);
  effects.finale(new T.Vector3(0, 1, -3), 4, true);
  effects.update(.01);
  assert.equal(instances.reduce((sum, mesh) => sum + mesh.count, 0), 0);
  assert.equal(sprites.filter(sprite => sprite.visible).length, 1);
  assert.equal(rings.filter(ring => ring.visible).length, 1);
}));
