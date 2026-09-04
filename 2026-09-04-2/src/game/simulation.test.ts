import { describe, expect, it } from "vitest";
import {
  createGame,
  createRoute,
  depart,
  parseSeed,
  retry,
  STEP,
  tick,
  totalScore,
  type Game,
} from "./simulation";
import { recordedInput } from "./recordings";
function run(seed: number, mode: string, all = false) {
  let g = depart(createGame(seed));
  for (let frame = 0; frame < 120 * 70; frame++) {
    if (g.status === "station" && all) g = depart(g);
    if (g.status !== "running") break;
    g = tick(g, recordedInput(g, mode));
  }
  return g;
}
describe("generated precision routes", () => {
  it("validates seed boundaries and reproduces courses", () => {
    for (const value of [null, "", "-1", "0", "2.1", "4294967296", "NaN"])
      expect(parseSeed(value)).toBeNull();
    expect(parseSeed("4294967295")).toBe(4294967295);
    expect(createRoute(1)).toEqual(createRoute(1));
    expect(createRoute(1)).not.toEqual(createRoute(2));
  });
  it("all 100 courses are completable with timed recovery", () => {
    for (let seed = 1; seed <= 100; seed++) {
      const g = run(seed, "catch", true);
      expect(g.status, `seed ${seed}: ${JSON.stringify(g)}`).toBe("won");
      expect(g.reports).toHaveLength(3);
      expect(g.reports.every((r) => r.recovery === 250)).toBe(true);
      expect(g.totalTime).toBeLessThan(35);
    }
  });
  it("holding the button cannot clear even the first station", () => {
    for (let seed = 1; seed <= 100; seed++) {
      const g = run(seed, "hold");
      expect(g.status).toBe("lost");
      expect(g.reason).toBe("overshoot");
      expect(totalScore(g)).toBe(0);
    }
  });
  it("a steady full-speed brake falls; timed countersteering recovers", () => {
    const failed = run(1, "brake"),
      saved = run(1, "catch");
    expect(failed.reason).toBe("fall");
    expect(Math.abs(failed.lean)).toBeGreaterThanOrEqual(1);
    expect(saved.status).toBe("station");
    expect(saved.caught).toBe(true);
    expect(saved.reports[0].recovery).toBe(250);
  });
  it("one human-sized pulse can save a stop without frame-by-frame steering", () => {
    for (const duration of [0.08, 0.12, 0.16]) {
      let g = depart(createGame(1)),
        braking = false,
        pulse = -1;
      while (g.status === "running") {
        if (
          !braking &&
          g.route[0].length - g.x <= (g.speed * g.speed) / 20 + 1.5
        )
          braking = true;
        if (braking && pulse < 0 && g.lean >= 0.8) pulse = g.elapsed;
        g = tick(g, !braking || (pulse >= 0 && g.elapsed - pulse < duration));
      }
      expect(g.status).toBe("station");
      expect(g.caught).toBe(true);
    }
  });
  it("safe driving is possible but scores below precision recovery", () => {
    const safe = run(1, "safe"),
      precise = run(1, "catch");
    expect(safe.status, JSON.stringify(safe)).toBe("station");
    expect(safe.reports[0].recovery).toBe(0);
    expect(totalScore(precise)).toBeGreaterThan(totalScore(safe));
  });
  it("early, precise and late inputs have distinct readable results", () => {
    const early = run(1, "early"),
      precise = run(1, "catch"),
      late = run(1, "late");
    expect(early.reason).toBe("timeout");
    expect(early.x).toBeLessThan(
      early.route[0].length - early.route[0].tolerance,
    );
    expect(precise.status).toBe("station");
    expect(Math.abs(precise.reports[0].offset)).toBeLessThan(0.5);
    expect(late.reason).toBe("overshoot");
  });
});
describe("fairness and recovery", () => {
  it("retries the same failed station, preserves completed scores, clears physical state", () => {
    let g = depart(run(1, "catch"));
    while (g.status === "running") g = tick(g, true);
    const again = retry(g);
    expect(again.seed).toBe(g.seed);
    expect(again.route).toEqual(g.route);
    expect(again.leg).toBe(1);
    expect(again.reports).toEqual(g.reports);
    expect(again.x).toBe(0);
    expect(again.lean).toBe(0);
    expect(again.caught).toBe(false);
    expect(again.totalTime).toBeCloseTo(g.totalTime - g.elapsed);
  });
  it("does not award points while wobbling or after crossing the boundary", () => {
    const g = depart(createGame(1));
    expect(
      tick({ ...g, x: g.route[0].length, lean: 0.9, angular: 0 }, false).status,
    ).toBe("running");
    const over = tick(
      { ...g, x: g.route[0].length + g.route[0].tolerance + 0.01 },
      false,
    );
    expect(over.status).toBe("lost");
    expect(totalScore(over)).toBe(0);
  });
  it("cannot farm recovery points without landing a stop", () => {
    const base = depart(createGame(1));
    const g = tick(
      { ...base, peak: 0.9, lean: 0.2, x: base.route[0].length + 5 },
      false,
    );
    expect(g.caught).toBe(true);
    expect(g.status).toBe("lost");
    expect(totalScore(g)).toBe(0);
  });
  it("pauses terminal states and uses fixed time without backward movement", () => {
    for (const status of ["ready", "station", "won", "lost"] as const) {
      const g = { ...createGame(1), status };
      expect(tick(g, true)).toBe(g);
    }
    let g: Game = depart(createGame(1));
    for (let i = 0; i < 120; i++) g = tick(g, false);
    expect(g.elapsed).toBeCloseTo(120 * STEP);
    expect(g.x).toBe(0);
    expect(g.speed).toBe(0);
  });
});
