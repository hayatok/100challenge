export const STEP = 1 / 120;
export const MAX_SPEED = 34;
export const BRAKE = 12;
export interface Stop {
  name: string;
  length: number;
  tolerance: number;
  deadline: number;
  bumps: number[];
  scenery: "residential" | "bridge";
}
export interface Report {
  name: string;
  accuracy: number;
  time: number;
  care: number;
  score: number;
  offset: number;
  late: number;
  passed: boolean;
}
export interface Game {
  seed: number;
  route: Stop[];
  leg: number;
  status: "ready" | "running" | "station" | "won" | "lost";
  x: number;
  speed: number;
  acceleration: number;
  lean: number;
  angular: number;
  slip: number;
  peak: number;
  elapsed: number;
  totalTime: number;
  stopTime: number;
  bumpIndex: number;
  reports: Report[];
  message: string;
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
  const names = [
    "カラメル坂",
    "ぷるぷる町",
    "たまご台",
    "牛乳橋",
    "おやつ前",
    "なめらか丘",
    "砂糖ヶ谷",
    "喫茶通り",
    "定時中央",
  ];
  const pool = [...names];
  return Array.from({ length: 3 }, (_, i) => {
    const length = Math.round(330 + random() * 100 + i * 20);
    const bumps = i === 0 ? [] : [Math.round(110 + random() * 30)];
    if (i === 2) bumps.push(Math.round(210 + random() * 25));
    return {
      name: pool.splice(Math.floor(random() * pool.length), 1)[0],
      length,
      tolerance: 16 - i * 3 + Math.round(random() * 3),
      deadline: Math.ceil(length / 27 + 6 - i * 0.5),
      bumps,
      scenery: random() > 0.5 ? "bridge" : "residential",
    };
  });
}
export function createGame(seed: number): Game {
  return {
    seed,
    route: createRoute(seed),
    leg: 0,
    status: "ready",
    x: 0,
    speed: 0,
    acceleration: 0,
    lean: 0,
    angular: 0,
    slip: 0,
    peak: 0,
    elapsed: 0,
    totalTime: 0,
    stopTime: 0,
    bumpIndex: 0,
    reports: [],
    message: "プリンを乗せて、出発進行。",
  };
}
export function depart(g: Game): Game {
  if (g.status === "ready") return { ...g, status: "running" };
  if (g.status !== "station") return g;
  return {
    ...g,
    leg: g.leg + 1,
    status: "running",
    x: 0,
    speed: 0,
    acceleration: 0,
    lean: 0,
    angular: 0,
    slip: 0,
    peak: 0,
    elapsed: 0,
    stopTime: 0,
    bumpIndex: 0,
    message: "次の駅へ、出発進行。",
  };
}
export function totalScore(g: Game) {
  return g.reports.reduce((n, r) => n + r.score, 0);
}
function arrive(g: Game, passed: boolean): Game {
  const stop = g.route[g.leg],
    offset = g.x - stop.length;
  const accuracy = passed
    ? 0
    : Math.round(400 * Math.max(0, 1 - Math.abs(offset) / stop.tolerance));
  const late = Math.max(0, g.elapsed - stop.deadline);
  const time = Math.round(Math.max(0, 300 - late * 25));
  const care = Math.round(300 * Math.max(0, 1 - g.peak));
  const report = {
    name: stop.name,
    accuracy,
    time,
    care,
    score: accuracy + time + care,
    offset,
    late,
    passed,
  };
  return {
    ...g,
    status: g.leg === 2 ? "won" : "station",
    reports: [...g.reports, report],
    message: passed
      ? "駅を通過。プリンは無事です。"
      : accuracy > 320
        ? "ぷるっと、ぴったり停車！"
        : "到着。プリン、おつかれさま。",
  };
}
/** Deterministic fixed-step simulation. Rendering frame rate never changes route/physics. */
export function tick(g: Game, pressed: boolean): Game {
  if (g.status !== "running") return g;
  const s = { ...g },
    dt = STEP,
    stop = s.route[s.leg];
  const target = pressed
    ? s.speed < MAX_SPEED
      ? 9
      : 0
    : s.speed > 0
      ? -BRAKE
      : 0;
  s.acceleration += (target - s.acceleration) * Math.min(1, dt * 7);
  const previousSpeed = s.speed;
  s.speed = Math.max(0, Math.min(MAX_SPEED, s.speed + s.acceleration * dt));
  const effectiveAcceleration = (s.speed - previousSpeed) / dt;
  s.x += (s.speed + previousSpeed) * 0.5 * dt;
  s.elapsed += dt;
  s.totalTime += dt;
  if (s.bumpIndex < stop.bumps.length && s.x >= stop.bumps[s.bumpIndex]) {
    s.angular += (s.bumpIndex % 2 ? -1 : 1) * (s.speed / MAX_SPEED) * 2.6;
    s.bumpIndex++;
    s.message = "ガタン！ プリンを立て直して。";
  }
  s.angular +=
    (-16 * s.lean - 2.4 * s.angular - effectiveAcceleration * 0.6) * dt;
  s.lean += s.angular * dt;
  const danger = Math.abs(s.lean);
  s.slip = Math.max(
    0,
    Math.min(
      1,
      s.slip +
        (danger > 0.55 ? (danger - 0.55) * 2.5 : danger < 0.3 ? -0.18 : 0) * dt,
    ),
  );
  s.peak = Math.max(s.peak, s.slip);
  if (s.slip >= 1 || danger > 1.5)
    return { ...s, status: "lost", message: "お客様だけ、先に到着。" };
  if (Math.abs(s.x - stop.length) <= stop.tolerance && s.speed < 0.4)
    s.stopTime += dt;
  else s.stopTime = 0;
  if (s.stopTime > 0.4) return arrive(s, false);
  if (
    s.x > stop.length + stop.tolerance &&
    (s.speed < 0.4 || s.x > stop.length + 75)
  )
    return arrive(s, true);
  return s;
}
export function brakingDistance(speed: number) {
  return (speed * speed) / (2 * BRAKE) + speed * 0.24;
}
