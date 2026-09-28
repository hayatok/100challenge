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

test("a heavy burst cannot grow draw objects, and expired pools can be reused without disposing materials", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const { instances, sprites, rings } = pools(scene);
  assert.equal(instances.length, 2, "flecks require two instanced draw objects");
  assert.equal(sprites.length, 16);
  assert.equal(rings.length, 10);
  assert.equal(scene.children.length, 28);
  const initialObjects = [...scene.children];
  const materials = [instances[0].material, ...sprites.map((s) => s.material), ...rings.map((r) => r.material)]
    .flatMap((material) => Array.isArray(material) ? material : [material]);
  let disposed = 0;
  for (const material of materials) material.dispose = () => { disposed++; };

  for (let i = 0; i < 150; i++) {
    const pos = new T.Vector3(i % 9, 1, i % 5);
    effects.burst(pos, 4, true, false, 1.7);
    effects.explosion(pos, false);
    effects.finisher(pos, 4, false);
    effects.tracer(pos, pos.clone().add(new T.Vector3(3, 0, -2)), 4);
  }
  effects.update(0.016);
  assert.ok(instances.every((mesh) => mesh.count <= 300));
  assert.ok(instances.reduce((sum, mesh) => sum + mesh.count, 0) <= 300, "all flecks share one 300-instance budget");
  assert.ok(sprites.filter((s) => s.visible).length <= 16);
  assert.ok(rings.filter((r) => r.visible).length <= 10);
  assert.deepEqual(scene.children, initialObjects, "bursts create no new scene draw objects");

  effects.update(2);
  assert.equal(instances.reduce((sum, mesh) => sum + mesh.count, 0), 0, "spent flecks leave no draw instances");
  assert.ok(sprites.every((s) => !s.visible));
  assert.ok(rings.every((r) => !r.visible));
  effects.burst(new T.Vector3(0, 1, 0), 3, true, false);
  effects.update(0);
  assert.ok(instances.some((mesh) => mesh.count > 0), "expired pool accepts another burst");
  effects.reset();
  assert.ok(instances.every((mesh) => mesh.count === 0));
  assert.ok(sprites.every((s) => !s.visible));
  assert.ok(rings.every((r) => !r.visible));
  assert.deepEqual(scene.children, initialObjects);
  assert.equal(disposed, 0, "pooled materials remain allocated across reuse and reset");
}));

test("stress updates leave finite instance transforms and colors, and tracer spans its endpoints", () => withCanvas(() => {
  const scene = new T.Scene();
  const effects = new CombatEffects(scene);
  const [shard, streak] = pools(scene).instances;
  const from = new T.Vector3(-2, 1.5, 3);
  const to = new T.Vector3(5, 1.5, -1);
  effects.tracer(from, to, 4);
  effects.update(0);
  assert.equal(streak.count, 1);
  const matrix = new T.Matrix4();
  streak.getMatrixAt(0, matrix);
  const near = new T.Vector3(0, 0, -0.5).applyMatrix4(matrix);
  const far = new T.Vector3(0, 0, 0.5).applyMatrix4(matrix);
  assert.ok(near.distanceTo(from) < 1e-5, "tracer starts at the muzzle");
  assert.ok(far.distanceTo(to) < 1e-5, "tracer reaches its target");

  for (let i = 0; i < 10; i++) {
    effects.burst(new T.Vector3(i, 1, -i), i % 5, true, false, 1.7);
    effects.update(0.013);
  }
  for (const mesh of [shard, streak]) {
    for (let i = 0; i < mesh.count; i++) {
      mesh.getMatrixAt(i, matrix);
      assert.ok(matrix.elements.every(Number.isFinite), "each live fleck has a finite transform");
      const color = new T.Color();
      mesh.getColorAt(i, color);
      assert.ok([color.r, color.g, color.b].every(Number.isFinite), "each live fleck has a finite color");
    }
  }
}));
