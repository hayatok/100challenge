import { describe, expect, it } from "vitest";
import {
  BRAKE,
  STEP,
  brakingDistance,
  createGame,
  createRoute,
  depart,
  parseSeed,
  tick,
  totalScore,
} from "./simulation";
describe("random railway", () => {
  it("reproduces a route, varies seeds, and validates shared seed input", () => {
    expect(createRoute(56)).toEqual(createRoute(56));
    expect(createRoute(56)).not.toEqual(createRoute(57));
    for (const value of [null, "", "-1", "0", "2.1", "4294967296", "NaN"])
      expect(parseSeed(value)).toBeNull();
    expect(parseSeed("4294967295")).toBe(4294967295);
  });
  it("keeps 500 courses within warning, recovery and stopping bounds", () => {
    for (let seed = 1; seed <= 500; seed++) {
      const route = createRoute(seed);
      expect(new Set(route.map((s) => s.name)).size).toBe(3);
      expect(route[0].bumps).toHaveLength(0);
      for (const stop of route) {
        expect(stop.length).toBeGreaterThan(300);
        expect(stop.deadline).toBeGreaterThan(stop.length / 34 + 3);
        expect(stop.tolerance).toBeGreaterThanOrEqual(10);
        for (let i = 0; i < stop.bumps.length; i++) {
          expect(stop.bumps[i]).toBeGreaterThanOrEqual(100);
          expect(stop.length - stop.bumps[i]).toBeGreaterThan(
            brakingDistance(34) + 30,
          );
          if (i)
            expect(stop.bumps[i] - stop.bumps[i - 1]).toBeGreaterThanOrEqual(
              70,
            );
        }
      }
    }
  });
});
describe("driving", () => {
  it("does not advance ready, stopped reports or terminal games", () => {
    const g = createGame(1);
    expect(tick(g, true)).toBe(g);
    for (const status of ["station", "won", "lost"] as const) {
      const end = { ...g, status };
      expect(tick(end, true)).toBe(end);
    }
  });
  it("accelerates, brakes to zero and never travels backward", () => {
    let g = depart(createGame(1));
    for (let i = 0; i < 240; i++) g = tick(g, true);
    expect(g.speed).toBeGreaterThan(15);
    const x = g.x;
    for (let i = 0; i < 500; i++) g = tick(g, false);
    expect(g.speed).toBe(0);
    expect(g.x).toBeGreaterThan(x);
    const stopped = g.x;
    for (let i = 0; i < 100; i++) g = tick(g, false);
    expect(g.x).toBe(stopped);
  });
  it("scores accurate stops, lateness and passed stations separately", () => {
    const base = depart(createGame(4)),
      stop = base.route[0];
    let g = { ...base, x: stop.length, elapsed: stop.deadline + 2 };
    for (let i = 0; i < 60; i++) g = tick(g, false);
    expect(g.status).toBe("station");
    expect(g.reports[0].accuracy).toBe(400);
    expect(g.reports[0].time).toBeLessThan(300);
    expect(totalScore(g)).toBeGreaterThan(600);
    const passed = tick({ ...base, x: stop.length + 90 }, false);
    expect(passed.reports[0].accuracy).toBe(0);
    expect(passed.reports[0].passed).toBe(true);
  });
  it("can recover a sliding pudding and loses when it falls", () => {
    const base = depart(createGame(2));
    const recovered = tick({ ...base, slip: 0.5 }, false);
    expect(recovered.slip).toBeLessThan(0.5);
    expect(tick({ ...base, slip: 0.9999, lean: 1 }, true).status).toBe("lost");
  });
  it("a cautious driver can finish 100 generated routes without a fall", () => {
    for (let seed = 1; seed <= 100; seed++) {
      let g = depart(createGame(seed)),
        hold = false;
      for (
        let i = 0;
        i < 120 * 180 && g.status !== "won" && g.status !== "lost";
        i++
      ) {
        if (g.status === "station") {
          g = depart(g);
          hold = false;
        }
        const d = g.route[g.leg].length - g.x;
        const desired = Math.min(
          23,
          Math.sqrt(Math.max(0, 2 * BRAKE * (d - 1))) * 0.8,
        );
        if (g.speed < desired - 1) hold = true;
        if (g.speed > desired + 1 || d < 2) hold = false;
        g = tick(g, hold);
      }
      expect(g.status, `seed ${seed}: ${JSON.stringify(g)}`).toBe("won");
      expect(g.reports.every((r) => !r.passed)).toBe(true);
      expect(g.totalTime).toBeLessThan(100);
    }
  });
  it("uses fixed seconds", () => {
    let g = depart(createGame(1));
    for (let i = 0; i < 120; i++) g = tick(g, false);
    expect(g.elapsed).toBeCloseTo(120 * STEP);
  });
});
