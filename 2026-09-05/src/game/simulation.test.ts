import { describe, it, expect } from "vitest";
import {
  ARENA,
  choose,
  createGame,
  LIMIT,
  options,
  spawnEnemy,
  STEP,
  tick,
  WEAPONS,
  xpNeeded,
  type Game,
  type Upgrade,
} from "./simulation";
const running = () => {
  const g = createGame(42);
  g.status = "running";
  return g;
};
describe("movement and state boundaries", () => {
  it("normalizes diagonal movement, clamps the arena and freezes menus", () => {
    const a = running(),
      b = running();
    tick(a, { x: 1, z: 0 });
    tick(b, { x: 1, z: 1 });
    expect(Math.hypot(b.player.x, b.player.z)).toBeCloseTo(a.player.x);
    a.player.x = ARENA;
    tick(a, { x: 1, z: 0 });
    expect(a.player.x).toBe(ARENA);
    for (const status of [
      "ready",
      "paused",
      "upgrade",
      "won",
      "lost",
    ] as const) {
      a.status = status;
      const before = JSON.stringify(a);
      tick(a, { x: 1, z: 1 });
      expect(JSON.stringify(a)).toBe(before);
    }
  });
  it("spawns outside landscape and portrait view even near boundaries", () => {
    for (const view of [
      { halfX: 22, halfZ: 13 },
      { halfX: 6, halfZ: 18 },
    ]) {
      const g = running();
      g.view = view;
      g.player = { x: 24, z: 10 };
      for (let i = 0; i < 100; i++) {
        const e = spawnEnemy(g, "dust");
        expect(
          Math.abs(e.x - 24) > view.halfX || Math.abs(e.z - 10) > view.halfZ,
        ).toBe(true);
      }
    }
  });
  it("spawns one boss and ends at the deadline", () => {
    const g = running();
    g.time = 300 - STEP / 2;
    tick(g, { x: 0, z: 0 });
    expect(g.enemies.filter((e) => e.kind === "boss")).toHaveLength(1);
    for (let i = 0; i < 10; i++) tick(g, { x: 0, z: 0 });
    expect(g.enemies.filter((e) => e.kind === "boss")).toHaveLength(1);
    g.time = LIMIT - STEP / 2;
    tick(g, { x: 0, z: 0 });
    expect(g.status).toBe("lost");
    expect(g.reason).toContain("時間切れ");
  });
  it("has contact invulnerability, healing cap and lethal failure", () => {
    const g = running();
    const e = spawnEnemy(g, "box");
    e.x = 0;
    e.z = 0;
    e.hp = 10000;
    tick(g, { x: 0, z: 0 });
    expect(g.hp).toBe(90);
    tick(g, { x: 0, z: 0 });
    expect(g.hp).toBe(90);
    g.pickups.push({ id: 99, x: 0, z: 0, value: 1000, heal: true });
    tick(g, { x: 0, z: 0 });
    expect(g.hp).toBe(100);
    g.hp = 1;
    g.invincible = 0;
    tick(g, { x: 0, z: 0 });
    expect(g.hp).toBe(0);
    expect(g.status).toBe("lost");
  });
});
describe("growth and weapons", () => {
  it("collects batteries, pauses at level-up, rejects invalid and double choices", () => {
    const g = running();
    g.pickups.push({ id: 99, x: 0, z: 0, value: xpNeeded(g), heal: false });
    tick(g, { x: 0, z: 0 });
    expect(g.status).toBe("upgrade");
    expect(g.level).toBe(2);
    expect(g.choices).toHaveLength(3);
    const before = JSON.stringify(g);
    choose(g, "repair");
    expect(JSON.stringify(g)).toBe(before);
    const choice = g.choices[0];
    choose(g, choice);
    expect(g.status).toBe("running");
    const after = JSON.stringify(g);
    choose(g, choice);
    expect(JSON.stringify(g)).toBe(after);
  });
  it("never exceeds three weapons or max levels across seeds", () => {
    for (let seed = 1; seed <= 50; seed++) {
      const g = createGame(seed);
      for (let n = 0; n < 60; n++) {
        g.status = "upgrade";
        g.choices = options(g);
        expect(new Set(g.choices).size).toBe(g.choices.length);
        choose(g, g.choices[n % g.choices.length]);
        expect(
          WEAPONS.filter((w) => g.weapons[w] > 0).length,
        ).toBeLessThanOrEqual(3);
        expect(Math.max(...Object.values(g.weapons))).toBeLessThanOrEqual(5);
        expect(Math.max(...Object.values(g.boosts))).toBeLessThanOrEqual(3);
      }
    }
  });
  it("all four weapons cause damage, and the boss kill wins immediately", () => {
    for (const weapon of WEAPONS) {
      const g = running();
      g.weapons = { nozzle: 0, mop: 0, spray: 0, disc: 0 };
      g.weapons[weapon] = 5;
      const e = spawnEnemy(g, "boss");
      e.x = 0;
      e.z = 2.7;
      e.hp = 2;
      for (let i = 0; i < 180 && g.status === "running"; i++)
        tick(g, { x: 0, z: 0 });
      expect(g.status, weapon).toBe("won");
      expect(g.kills).toBe(1);
    }
  });
  it("telegraphs a dash before moving along a locked direction", () => {
    const g = running();
    g.weapons.nozzle = 0;
    const e = spawnEnemy(g, "dash");
    e.x = 0;
    e.z = 7;
    e.clock = 0;
    tick(g, { x: 0, z: 0 });
    expect(e.phase).toBe(1);
    const z = e.z;
    for (let i = 0; i < 30; i++) tick(g, { x: 1, z: 0 });
    expect(e.z).toBe(z);
    for (let i = 0; i < 30; i++) tick(g, { x: 1, z: 0 });
    expect(e.phase).toBe(2);
    expect(Math.abs(e.x)).toBeLessThan(0.01);
  });
});
export function bot(g: Game) {
  // Greedy collecting plus local repulsion; no invulnerability or hidden buffs.
  let target = g.pickups
    .filter((p) => !p.heal || g.hp < g.maxHp - 15)
    .sort(
      (a, b) =>
        Math.hypot(a.x - g.player.x, a.z - g.player.z) -
        Math.hypot(b.x - g.player.x, b.z - g.player.z),
    )[0];
  const boss = g.enemies.find((e) => e.kind === "boss");
  let x = 0,
    z = 0;
  if (target) {
    const d = Math.hypot(target.x - g.player.x, target.z - g.player.z) || 1;
    x = (target.x - g.player.x) / d;
    z = (target.z - g.player.z) / d;
  } else if (boss) {
    const d = Math.hypot(boss.x - g.player.x, boss.z - g.player.z) || 1;
    const sign = d < 3 ? -1 : 1;
    x = ((boss.x - g.player.x) / d) * sign;
    z = ((boss.z - g.player.z) / d) * sign;
  } else {
    x = Math.sin(g.time * 0.15) * 0.6;
    z = Math.cos(g.time * 0.15) * 0.6;
  }
  for (const e of g.enemies) {
    const dx = g.player.x - e.x,
      dz = g.player.z - e.z,
      d = Math.hypot(dx, dz) || 0.01;
    if (d < 3.2) {
      const f = ((3.2 - d) * 1.8) / d;
      x += (dx / d) * f;
      z += (dz / d) * f;
    }
  }
  return { x, z };
}
it("deterministically simulates complete runs with finite bounded state", () => {
  let wins = 0;
  const reports = [];
  for (let seed = 1; seed <= 3; seed++) {
    const g = createGame(seed);
    g.status = "running";
    const priority: Upgrade[] = [
      "mop",
      "nozzle",
      "disc",
      "haste",
      "magnet",
      "health",
      "speed",
      "spray",
      "repair",
    ];
    for (let frame = 0; frame < 60 * 361; frame++) {
      while ((g.status as string) === "upgrade") {
        choose(
          g,
          [...g.choices].sort(
            (a, b) => priority.indexOf(a) - priority.indexOf(b),
          )[0],
        );
      }
      if (g.status !== "running") break;
      tick(g, bot(g));
      if (frame % 60 === 0) {
        expect(Number.isFinite(g.hp + g.player.x + g.player.z)).toBe(true);
        expect(g.hp).toBeGreaterThanOrEqual(0);
        expect(g.enemies.length).toBeLessThanOrEqual(204);
        expect(Math.hypot(g.player.x, g.player.z)).toBeLessThanOrEqual(
          ARENA + 0.00001,
        );
      }
    }
    expect(["won", "lost"]).toContain(g.status);
    if ((g.status as string) === "won") wins++;
    reports.push({
      seed,
      status: g.status,
      time: Math.round(g.time),
      kills: g.kills,
      level: g.level,
      hp: g.hp,
      weapons: g.weapons,
    });
  }
  console.log("BALANCE_RUNS", JSON.stringify(reports));
  expect(wins).toBeGreaterThan(0);
}, 30000);

it("supports both foam builds through full runs with no hidden boosts", () => {
  const reports = [];
  for (const build of ["vacuum", "runway"] as const) {
    let wins = 0;
    for (const seed of [11, 23, 42]) {
      const g = createGame(seed);
      g.status = "running";
      const order: Upgrade[] =
        build === "vacuum"
          ? [
              "spray",
              "nozzle",
              "disc",
              "haste",
              "magnet",
              "health",
              "speed",
              "mop",
              "repair",
            ]
          : [
              "spray",
              "mop",
              "nozzle",
              "haste",
              "magnet",
              "health",
              "speed",
              "disc",
              "repair",
            ];
      for (let frame = 0; frame < 60 * 361; frame++) {
        while ((g.status as string) === "upgrade")
          choose(
            g,
            [...g.choices].sort(
              (a, b) => order.indexOf(a) - order.indexOf(b),
            )[0],
          );
        if (g.status !== "running") break;
        tick(g, bot(g));
      }
      expect(["won", "lost"]).toContain(g.status);
      expect(g.floor.cleaned).toBeGreaterThan(0);
      expect(g.floor.cleaned).toBeLessThanOrEqual(g.floor.total);
      if ((g.status as string) === "won") wins++;
      reports.push({
        build,
        seed,
        status: g.status,
        time: Math.round(g.time),
        kills: g.kills,
        clean: Math.round((g.floor.cleaned / g.floor.total) * 100),
        combos: g.comboHits,
      });
    }
    expect(wins, build).toBeGreaterThan(0);
  }
  console.log("V2_BUILD_RUNS", JSON.stringify(reports));
}, 30000);
