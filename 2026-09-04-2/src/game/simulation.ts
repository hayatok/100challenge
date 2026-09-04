export const STEP = 1 / 120;
export const MAX_SPEED = 18;
export const BRAKE = 10;
export const EDGE = 1;
export interface Stop {
  name: string;
  length: number;
  tolerance: number;
  deadline: number;
}
export interface Report {
  name: string;
  offset: number;
  accuracy: number;
  recovery: number;
  pace: number;
  score: number;
}
export interface Game {
  seed: number;
  route: Stop[];
  leg: number;
  status: "ready" | "running" | "station" | "won" | "lost";
  reason: "fall" | "overshoot" | "timeout" | null;
  x: number;
  speed: number;
  acceleration: number;
  lean: number;
  angular: number;
  peak: number;
  caught: boolean;
  catchAt: number;
  braking: boolean;
  elapsed: number;
  totalTime: number;
  stopTime: number;
  reports: Report[];
}
export function randomSeed() {
  return crypto.getRandomValues(new Uint32Array(1))[0] || 1;
}
export function parseSeed(value: string | null): number | null {
  if (!value || !/^\d{1,10}$/.test(value)) return null;
  const n = Number(value);
  return n > 0 && n <= 0xffffffff ? n : null;
}
export function createRoute(seed: number): Stop[] {
  let state = seed >>> 0;
  const random = () => {
    state += 0x6d2b79f5;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return ["住宅前", "川向こう", "会社前"].map((name, i) => ({
    name,
    length: Math.round(92 + random() * 22 + i * 9),
    tolerance: [2.4, 1.8, 1.3][i],
    deadline: 20,
  }));
}
export function createGame(seed: number): Game {
  return {
    seed,
    route: createRoute(seed),
    leg: 0,
    status: "ready",
    reason: null,
    x: 0,
    speed: 0,
    acceleration: 0,
    lean: 0,
    angular: 0,
    peak: 0,
    caught: false,
    catchAt: -10,
    braking: false,
    elapsed: 0,
    totalTime: 0,
    stopTime: 0,
    reports: [],
  };
}
export function depart(g: Game): Game {
  if (g.status === "ready") return { ...g, status: "running" };
  if (g.status !== "station") return g;
  return {
    ...createGame(g.seed),
    route: g.route,
    leg: g.leg + 1,
    reports: g.reports,
    totalTime: g.totalTime,
    status: "running",
  };
}
export function retry(g: Game): Game {
  // Retry the failed station immediately; completed stations and the route stay intact.
  return {
    ...createGame(g.seed),
    route: g.route,
    leg: g.leg,
    reports: g.reports,
    totalTime: g.totalTime - g.elapsed,
    status: "running",
  };
}
export function totalScore(g: Game) {
  return g.reports.reduce((n, r) => n + r.score, 0);
}
export function brakingDistance(speed: number) {
  return (speed * speed) / (2 * BRAKE);
}
export function tick(g: Game, pressed: boolean): Game {
  if (g.status !== "running") return g;
  const s = { ...g },
    stop = s.route[s.leg];
  const previousSpeed = s.speed;
  s.speed = Math.max(
    0,
    Math.min(MAX_SPEED, s.speed + (pressed ? 6 : -BRAKE) * STEP),
  );
  s.acceleration = (s.speed - previousSpeed) / STEP;
  s.x += (previousSpeed + s.speed) * 0.5 * STEP;
  s.elapsed += STEP;
  s.totalTime += STEP;
  s.braking ||= !pressed && previousSpeed > 6;
  // Signed center of mass, normalized to the plate rim. The scene uses this same value.
  s.angular += (-12 * s.lean - 2.8 * s.angular - s.acceleration * 1.0) * STEP;
  s.lean += s.angular * STEP;
  if (s.braking) s.peak = Math.max(s.peak, Math.abs(s.lean));
  if (!s.caught && s.peak >= 0.82 && Math.abs(s.lean) < 0.4) {
    s.caught = true;
    s.catchAt = s.elapsed;
  }
  if (Math.abs(s.lean) >= EDGE) return { ...s, status: "lost", reason: "fall" };
  if (s.x > stop.length + stop.tolerance)
    return { ...s, status: "lost", reason: "overshoot" };
  if (s.elapsed >= stop.deadline)
    return { ...s, status: "lost", reason: "timeout" };
  // Stopping does not award a result until the pudding has settled safely.
  if (
    s.speed === 0 &&
    Math.abs(s.x - stop.length) <= stop.tolerance &&
    Math.abs(s.lean) < 0.4
  )
    s.stopTime += STEP;
  else s.stopTime = 0;
  if (s.stopTime >= 0.25) {
    const offset = s.x - stop.length;
    const accuracy = Math.round(
      600 * Math.max(0, 1 - Math.abs(offset) / stop.tolerance),
    );
    const recovery = s.caught ? 250 : 0;
    const pace = Math.round(
      150 * Math.max(0, Math.min(1, (14 - s.elapsed) / 6)),
    );
    const report = {
      name: stop.name,
      offset,
      accuracy,
      recovery,
      pace,
      score: 100 + accuracy + recovery + pace,
    };
    return {
      ...s,
      status: s.leg === 2 ? "won" : "station",
      reports: [...s.reports, report],
    };
  }
  return s;
}
