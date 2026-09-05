import { describe, it, expect } from "vitest";
import {
  cleanAt,
  createFloor,
  paintFloor,
  connectedToStation,
  cleaningPercent,
  STATION,
  resolveScenery,
} from "./cleaning";
import {
  createGame,
  tick,
  STEP,
  spawnEnemy,
  updateStation,
  synergies,
} from "./simulation";
const running = () => {
  const g = createGame(42);
  g.status = "running";
  g.spawn = 1000;
  return g;
};
function connect(f: ReturnType<typeof createFloor>) {
  for (let i = 0; i <= 32; i++)
    paintFloor(f, { x: (STATION.x * i) / 32, z: (STATION.z * i) / 32 }, 1.1);
}
describe("cleaning terrain", () => {
  it("counts unique floor area and excludes scenery without farming percentage", () => {
    const f = createFloor();
    paintFloor(f, { x: 0, z: 0 }, 3);
    const n = f.cleaned;
    expect(n).toBeGreaterThan(20);
    paintFloor(f, { x: 0, z: 0 }, 3);
    expect(f.cleaned).toBe(n);
    paintFloor(f, { x: 0, z: 0 }, 3, false);
    expect(f.cleaned).toBe(0);
    expect(f.unique).toBe(n);
    paintFloor(f, { x: 0, z: 0 }, 3);
    expect(f.unique).toBe(n);
    paintFloor(f, { x: 0, z: 0 }, 100);
    expect(f.cleaned).toBe(f.total);
    expect(cleaningPercent(f)).toBe(100);
    expect(cleanAt(f, STATION)).toBe(false);
    expect(cleanAt(f, { x: 100, z: 0 })).toBe(false);
  });
  it("requires a continuous route which mud can cut", () => {
    const f = createFloor();
    paintFloor(f, { x: 0, z: 0 }, 1);
    paintFloor(f, STATION, 2);
    expect(connectedToStation(f)).toBe(false);
    connect(f);
    expect(connectedToStation(f)).toBe(true);
    paintFloor(f, { x: -3.5, z: -2.5 }, 2, false);
    expect(connectedToStation(f)).toBe(false);
  });
  it("boosts reused paths but not the ground just swept ahead", () => {
    const fresh = running(),
      reuse = running();
    paintFloor(reuse.floor, { x: 2, z: 0 }, 4);
    tick(fresh, { x: 1, z: 0 });
    tick(reuse, { x: 1, z: 0 });
    expect(fresh.routeBoost).toBe(false);
    expect(reuse.routeBoost).toBe(true);
    expect(reuse.player.x / fresh.player.x).toBeCloseTo(1.18);
    for (let i = 0; i < 90; i++) tick(fresh, { x: 1, z: 0 });
    expect(fresh.routeBoost).toBe(false);
    tick(fresh, { x: -1, z: 0 });
    expect(fresh.routeBoost).toBe(true);
  });
  it("recovers once after two seconds, and resets progress if disconnected", () => {
    const g = running();
    g.hp = 50;
    connect(g.floor);
    for (let i = 0; i < 60; i++) updateStation(g, STEP);
    expect(g.station.progress).toBeGreaterThan(0.9);
    paintFloor(g.floor, { x: -3.5, z: -2.5 }, 2, false);
    for (let i = 0; i < 15; i++) updateStation(g, STEP);
    expect(g.station.progress).toBe(0);
    connect(g.floor);
    for (let i = 0; i < 150; i++) updateStation(g, STEP);
    expect(g.station.active).toBe(true);
    expect(g.hp).toBe(70);
    expect(g.xp).toBe(5);
    const clean = g.floor.cleaned;
    for (let i = 0; i < 1800; i++) updateStation(g, STEP);
    expect(g.floor.cleaned).toBeGreaterThan(clean);
    expect(g.hp).toBe(70);
    expect(g.xp).toBe(5);
    paintFloor(g.floor, { x: -3.5, z: -2.5 }, 2, false);
    updateStation(g, STEP);
    expect(g.station.active).toBe(true);
  });
  it("mud removes the actual movement terrain", () => {
    const g = running();
    connect(g.floor);
    const e = spawnEnemy(g, "mud");
    e.x = -3.5;
    e.z = -2.5;
    e.clock = 0;
    expect(cleanAt(g.floor, e)).toBe(true);
    tick(g, { x: 0, z: 0 });
    expect(cleanAt(g.floor, e)).toBe(false);
  });
  it("resolves solid equipment and building collisions", () => {
    for (const p of [{ x: -7, z: -12 }, { ...STATION }]) {
      resolveScenery(p);
      expect(Number.isFinite(p.x + p.z)).toBe(true);
    }
    const g = running();
    g.player = { x: STATION.x, z: STATION.z + 1.2 };
    for (let i = 0; i < 60; i++) tick(g, { x: 0, z: -1 });
    expect(g.player.z).toBeGreaterThanOrEqual(STATION.z + 0.95 - 1e-8);
  });
});
describe("tool synergies", () => {
  it("vacuum and foam trigger splash damage with a visible effect", () => {
    const g = running();
    g.weapons = { nozzle: 1, mop: 0, spray: 1, disc: 0 };
    const target = spawnEnemy(g, "box");
    target.x = 0;
    target.z = 3;
    target.hp = 200;
    const nearby = spawnEnemy(g, "box");
    nearby.x = 0.8;
    nearby.z = 3;
    nearby.hp = 200;
    g.effects.push({
      id: 999,
      x: 0,
      z: 3,
      kind: "foam",
      radius: 2,
      life: 2,
      max: 2,
      angle: 0,
    });
    tick(g, { x: 0, z: 0 });
    expect(g.comboHits).toBeGreaterThan(0);
    expect(nearby.hp).toBeLessThan(190);
    expect(g.effects.some((f) => f.kind === "chain")).toBe(true);
    expect(synergies(g)).toContain("泡バキューム");
  });
  it("foam and mop sweep a wider route than the base mop", () => {
    const a = running(),
      b = running();
    a.weapons = { nozzle: 1, mop: 1, spray: 0, disc: 0 };
    b.weapons = { nozzle: 1, mop: 1, spray: 1, disc: 0 };
    for (let i = 0; i < 120; i++) {
      tick(a, { x: 1, z: 0 });
      tick(b, { x: 1, z: 0 });
    }
    expect(b.floor.cleaned).toBeGreaterThan(a.floor.cleaned * 1.2);
    expect(synergies(b)).toHaveLength(2);
  });
});

it("does not trigger an extra foam burst from an enemy already killed by splash", () => {
  const g = running();
  g.weapons = { nozzle: 1, mop: 0, spray: 1, disc: 0 };
  const a = spawnEnemy(g, "box");
  a.x = 0;
  a.z = 3;
  a.hp = 200;
  const b = spawnEnemy(g, "box");
  b.x = 0.8;
  b.z = 3;
  b.hp = 4;
  g.effects.push({
    id: 999,
    x: 0,
    z: 3,
    kind: "foam",
    radius: 2,
    life: 2,
    max: 2,
    angle: 0,
  });
  tick(g, { x: 0, z: 0 });
  expect(g.comboHits).toBe(1);
  expect(g.kills).toBe(1);
});
