import {
  createFloor,
  cleanAt,
  paintFloor,
  connectedToStation,
  STATION,
  resolveScenery,
  type Floor,
} from "./cleaning";
export const STEP = 1 / 60;
export const LIMIT = 360;
export const ARENA = 28;
export type Weapon = "nozzle" | "mop" | "spray" | "disc";
export type Upgrade =
  Weapon | "speed" | "magnet" | "health" | "haste" | "repair";
export type EnemyKind = "dust" | "dash" | "box" | "mud" | "boss";
export type Status =
  "ready" | "running" | "upgrade" | "paused" | "won" | "lost";
export type Point = { x: number; z: number };
export type Enemy = Point & {
  id: number;
  kind: EnemyKind;
  hp: number;
  maxHp: number;
  angle: number;
  phase: number;
  clock: number;
  hit: number;
};
export type Pickup = Point & { id: number; value: number; heal: boolean };
export type Shot = Point & {
  id: number;
  vx: number;
  vz: number;
  life: number;
  damage: number;
  hops: number;
  hit: number[];
};
export type Effect = Point & {
  id: number;
  kind: "hit" | "suck" | "foam" | "pop" | "chain" | "trail";
  life: number;
  max: number;
  radius: number;
  angle: number;
};
export type Game = {
  status: Status;
  seed: number;
  time: number;
  player: Point;
  angle: number;
  hp: number;
  maxHp: number;
  invincible: number;
  level: number;
  xp: number;
  kills: number;
  weapons: Record<Weapon, number>;
  boosts: Record<"speed" | "magnet" | "health" | "haste", number>;
  enemies: Enemy[];
  pickups: Pickup[];
  shots: Shot[];
  effects: Effect[];
  choices: Upgrade[];
  cooldown: Record<Weapon, number>;
  spawn: number;
  bossSpawned: boolean;
  id: number;
  reason: string;
  view: { halfX: number; halfZ: number };
  cap: number;
  floor: Floor;
  routeBoost: boolean;
  station: {
    active: boolean;
    connected: boolean;
    progress: number;
    clock: number;
    age: number;
  };
  comboHits: number;
};
export const INFO: Record<Upgrade, { name: string; desc: string }> = {
  nozzle: {
    name: "吸引ノズル",
    desc: "扇形にまとめて吸引。威力・幅・貫通数UP",
  },
  mop: { name: "回転モップ", desc: "周囲をぐるぐる掃除。本数と半径UP" },
  spray: { name: "泡スプレー", desc: "敵の足元に泡。広がる範囲攻撃＋減速" },
  disc: { name: "お掃除ディスク", desc: "敵を跳ね返る円盤。発射数と反射数UP" },
  speed: { name: "快速ホイール", desc: "移動速度 ＋12%" },
  magnet: { name: "回収アンテナ", desc: "電池の回収半径 ＋0.8m" },
  health: { name: "大容量バッテリー", desc: "最大HP ＋20、その場で20回復" },
  haste: { name: "高速モーター", desc: "攻撃間隔を基本値の10%分短縮" },
  repair: { name: "応急修理", desc: "HPを30回復" },
};
export const WEAPONS: Weapon[] = ["nozzle", "mop", "spray", "disc"];
export function createGame(seed = 20260905): Game {
  return {
    status: "ready",
    seed: seed >>> 0 || 1,
    time: 0,
    player: { x: 0, z: 0 },
    angle: 0,
    hp: 100,
    maxHp: 100,
    invincible: 0,
    level: 1,
    xp: 0,
    kills: 0,
    weapons: { nozzle: 1, mop: 0, spray: 0, disc: 0 },
    boosts: { speed: 0, magnet: 0, health: 0, haste: 0 },
    enemies: [],
    pickups: [],
    shots: [],
    effects: [],
    choices: [],
    cooldown: { nozzle: 0, mop: 0, spray: 0, disc: 0 },
    spawn: 0,
    bossSpawned: false,
    id: 1,
    reason: "",
    view: { halfX: 17, halfZ: 12 },
    cap: 200,
    floor: createFloor(),
    routeBoost: false,
    station: { active: false, connected: false, progress: 0, clock: 0, age: 0 },
    comboHits: 0,
  };
}
export function random(g: Game) {
  g.seed = (Math.imul(g.seed, 1664525) + 1013904223) >>> 0;
  return g.seed / 4294967296;
}
export function xpNeeded(g: Game) {
  return 5 + (g.level - 1) * 3;
}
export function options(g: Game): Upgrade[] {
  const slots = WEAPONS.filter((w) => g.weapons[w] > 0).length;
  const all: Upgrade[] = WEAPONS.filter(
    (w) => g.weapons[w] < 5 && (g.weapons[w] > 0 || slots < 3),
  );
  for (const b of ["speed", "magnet", "health", "haste"] as const)
    if (g.boosts[b] < 3) all.push(b);
  if (!all.length) return ["repair"];
  for (let i = all.length - 1; i > 0; i--) {
    const j = Math.floor(random(g) * (i + 1));
    [all[i], all[j]] = [all[j], all[i]];
  }
  return all.slice(0, 3);
}
function levelUp(g: Game) {
  if (g.status !== "running" || g.xp < xpNeeded(g)) return;
  g.xp -= xpNeeded(g);
  g.level++;
  g.status = "upgrade";
  g.choices = options(g);
}
export function choose(g: Game, choice: Upgrade) {
  if (g.status !== "upgrade" || !g.choices.includes(choice)) return;
  if (WEAPONS.includes(choice as Weapon)) g.weapons[choice as Weapon]++;
  else if (choice === "repair") g.hp = Math.min(g.maxHp, g.hp + 30);
  else {
    g.boosts[choice as keyof Game["boosts"]]++;
    if (choice === "health") {
      g.maxHp += 20;
      g.hp = Math.min(g.maxHp, g.hp + 20);
    }
  }
  g.choices = [];
  g.status = "running";
  levelUp(g);
}
export function spawnEnemy(g: Game, kind: EnemyKind): Enemy {
  // Spawn outside the full visible rectangle, including portrait view, then approach the arena.
  const a = random(g) * Math.PI * 2,
    dx = Math.sin(a),
    dz = Math.cos(a);
  const r = Math.min(
    (g.view.halfX + 3) / Math.max(0.001, Math.abs(dx)),
    (g.view.halfZ + 3) / Math.max(0.001, Math.abs(dz)),
  );
  const hp =
    (kind === "boss"
      ? 950
      : kind === "box"
        ? 36
        : kind === "mud"
          ? 24
          : kind === "dash"
            ? 13
            : 8) * (kind === "boss" ? 1 : 1 + g.time / 300);
  const e: Enemy = {
    id: g.id++,
    kind,
    x: g.player.x + dx * r,
    z: g.player.z + dz * r,
    hp,
    maxHp: hp,
    angle: 0,
    phase: 0,
    clock: 1 + random(g) * 2,
    hit: 0,
  };
  g.enemies.push(e);
  return e;
}
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.z - b.z);
function effect(
  g: Game,
  kind: Effect["kind"],
  p: Point,
  radius = 1,
  life = 0.25,
  angle = 0,
) {
  if (g.effects.length >= 180) g.effects.shift();
  g.effects.push({ ...p, id: g.id++, kind, radius, life, max: life, angle });
}
function damage(g: Game, e: Enemy, n: number, knock = 0.08) {
  if (e.hp <= 0) return;
  e.hp -= n;
  e.hit = 0.12;
  const d = dist(e, g.player) || 1;
  e.x += ((e.x - g.player.x) / d) * knock;
  e.z += ((e.z - g.player.z) / d) * knock;
  if (e.hp <= 0) {
    g.kills++;
    effect(g, "pop", e, e.kind === "boss" ? 2 : 0.6, 0.35);
    if (e.kind === "boss") {
      g.status = "won";
      g.reason = "夜勤完了。朝を迎えよう。";
      return;
    }
    // Merge overflow into an existing battery so XP is never silently discarded.
    const value =
      e.kind === "box" ? 4 : e.kind === "mud" ? 3 : e.kind === "dash" ? 2 : 1;
    if (g.pickups.length < 240)
      g.pickups.push({ id: g.id++, x: e.x, z: e.z, value, heal: false });
    else {
      const p = g.pickups.find((p) => !p.heal);
      if (p) p.value += value;
    }
    if (g.kills % 35 === 0)
      g.pickups.push({
        id: g.id++,
        x: e.x + 0.3,
        z: e.z,
        value: 20,
        heal: true,
      });
  }
}
function attack(g: Game, dt: number) {
  const p = g.player,
    nearest = g.enemies
      .filter((e) => e.hp > 0)
      .sort((a, b) => dist(a, p) - dist(b, p));
  const target = nearest[0];
  if (target) g.angle = Math.atan2(target.x - p.x, target.z - p.z);
  for (const w of WEAPONS) g.cooldown[w] -= dt;
  const h = 1 - g.boosts.haste * 0.1;
  const n = g.weapons.nozzle;
  const vacuumFoam = n > 0 && g.weapons.spray > 0;
  if (n && target && dist(target, p) < 4 + n * 0.45 && g.cooldown.nozzle <= 0) {
    g.cooldown.nozzle = 0.55 * h;
    effect(g, "suck", p, 4 + n * 0.45, 0.2, g.angle);
    let count = 0;
    for (const e of nearest) {
      if (e.hp <= 0) continue;
      if (dist(e, p) > 4 + n * 0.45) break;
      const da = Math.atan2(
        Math.sin(Math.atan2(e.x - p.x, e.z - p.z) - g.angle),
        Math.cos(Math.atan2(e.x - p.x, e.z - p.z) - g.angle),
      );
      if (Math.abs(da) < 0.45 + n * 0.09 && count++ < 2 + n * 2) {
        const foamed =
          vacuumFoam &&
          g.effects.some((f) => f.kind === "foam" && dist(f, e) < f.radius);
        damage(g, e, 6 + n * 3, foamed ? -0.65 : 0.18);
        if (foamed) {
          g.comboHits++;
          effect(g, "chain", e, 1.3, 0.35);
          paintFloor(g.floor, e, 1.3);
          for (const other of nearest)
            if (other.hp > 0 && dist(other, e) < 1.3)
              damage(g, other, 4 + n, 0);
        }
      }
    }
  }
  const m = g.weapons.mop;
  if (m && g.cooldown.mop <= 0) {
    g.cooldown.mop = 0.12 * h;
    for (let i = 0; i < 1 + Math.floor(m / 2); i++) {
      const a = g.time * 2.8 + (i * Math.PI * 2) / (1 + Math.floor(m / 2));
      const mp = {
        x: p.x + Math.sin(a) * (1.6 + m * 0.2),
        z: p.z + Math.cos(a) * (1.6 + m * 0.2),
      };
      paintFloor(g.floor, mp, g.weapons.spray ? 1.65 : 0.65);
      if (g.weapons.spray) effect(g, "trail", mp, 1.65, 0.35);
      for (const e of nearest)
        if (dist(e, mp) < 1) damage(g, e, 3 + m * 1.2, 0.14);
    }
  }
  const s = g.weapons.spray;
  if (s && target && g.cooldown.spray <= 0) {
    g.cooldown.spray = 2.2 * h;
    for (const t of nearest.slice(0, 1 + Math.floor(s / 3)))
      effect(g, "foam", t, 1.4 + s * 0.3, 2.5);
  }
  for (const f of g.effects)
    if (f.kind === "foam")
      for (const e of nearest)
        if (dist(e, f) < f.radius) damage(g, e, (5 + s * 3) * dt, 0);
  const d = g.weapons.disc;
  if (d && target && g.cooldown.disc <= 0) {
    g.cooldown.disc = 1.5 * h;
    for (let i = 0; i < 1 + Math.floor(d / 2); i++) {
      const a = g.angle + (i - Math.floor(d / 2) / 2) * 0.22;
      g.shots.push({
        ...p,
        id: g.id++,
        vx: Math.sin(a) * 11,
        vz: Math.cos(a) * 11,
        life: 3,
        damage: 10 + d * 3,
        hops: 2 + d,
        hit: [],
      });
    }
  }
  for (const b of g.shots) {
    b.x += b.vx * dt;
    b.z += b.vz * dt;
    b.life -= dt;
    const e = nearest.find(
      (e) =>
        e.hp > 0 &&
        !b.hit.includes(e.id) &&
        dist(e, b) < (e.kind === "boss" ? 1.6 : 0.75),
    );
    if (e) {
      damage(g, e, b.damage);
      b.hit.push(e.id);
      b.hops--;
      if (b.hops <= 0) {
        b.life = 0;
        continue;
      }
      const next = nearest
        .filter((e) => e.hp > 0 && !b.hit.includes(e.id))
        .sort((a, c) => dist(a, b) - dist(c, b))[0];
      if (next) {
        const r = dist(next, b) || 1;
        b.vx = ((next.x - b.x) / r) * 11;
        b.vz = ((next.z - b.z) / r) * 11;
      }
    }
  }
  g.shots = g.shots.filter((b) => b.life > 0).slice(-60);
}
export function tick(g: Game, input: Point, dt = STEP) {
  if (g.status !== "running") return;
  g.time = Math.min(LIMIT, g.time + dt);
  if (g.time >= LIMIT) {
    g.status = "lost";
    g.reason = "夜明けです。時間切れ！";
    return;
  }
  g.invincible = Math.max(0, g.invincible - dt);
  const length = Math.hypot(input.x, input.z);
  g.routeBoost =
    length > 0 &&
    cleanAt(g.floor, g.player) &&
    cleanAt(g.floor, {
      x: g.player.x + (input.x / length) * 1.8,
      z: g.player.z + (input.z / length) * 1.8,
    });
  const speed = 4.2 * (1 + g.boosts.speed * 0.12) * (g.routeBoost ? 1.18 : 1);
  if (length) {
    g.player.x += (input.x / Math.max(1, length)) * speed * dt;
    g.player.z += (input.z / Math.max(1, length)) * speed * dt;
  }
  resolveScenery(g.player);
  paintFloor(g.floor, g.player, 0.95);
  const radius = Math.hypot(g.player.x, g.player.z);
  if (radius > ARENA) {
    g.player.x *= ARENA / radius;
    g.player.z *= ARENA / radius;
  }
  g.spawn -= dt;
  if (g.spawn <= 0 && g.enemies.length < g.cap) {
    g.spawn = g.bossSpawned ? 0.8 : Math.max(0.085, 0.7 - g.time * 0.0023);
    const r = random(g);
    spawnEnemy(
      g,
      g.time > 45 && r < 0.14
        ? "mud"
        : g.time > 100 && r < 0.3
          ? "box"
          : g.time > 45 && r < 0.4
            ? "dash"
            : "dust",
    );
  }
  if (g.time >= 300 && !g.bossSpawned) {
    g.bossSpawned = true;
    spawnEnemy(g, "boss");
  }
  for (const e of g.enemies) {
    if (e.hp <= 0) continue;
    e.hit = Math.max(0, e.hit - dt);
    e.clock -= dt;
    const d = Math.max(0.0001, dist(e, g.player));
    let v =
      e.kind === "mud"
        ? 1.6
        : e.kind === "box"
          ? 0.8
          : e.kind === "dash"
            ? 1.8
            : e.kind === "boss"
              ? 1.2
              : 1.15 + g.time * 0.001;
    if (e.kind === "dash" || e.kind === "boss") {
      if (e.phase === 0 && e.clock <= 0) {
        e.phase = 1;
        e.clock = e.kind === "boss" ? 1.1 : 0.75;
        e.angle = Math.atan2(g.player.x - e.x, g.player.z - e.z);
      } else if (e.phase === 1 && e.clock <= 0) {
        e.phase = 2;
        e.clock = 0.75;
      } else if (e.phase === 2 && e.clock <= 0) {
        e.phase = 0;
        e.clock = e.kind === "boss" ? 3 : 2.5;
        if (e.kind === "boss")
          for (let i = 0; i < 4 && g.enemies.length < g.cap; i++)
            spawnEnemy(g, "dust");
      }
      if (e.phase === 1) v = 0;
      else if (e.phase === 2) v = e.kind === "boss" ? 9 : 7;
    }
    if (g.effects.some((f) => f.kind === "foam" && dist(f, e) < f.radius))
      v *= 0.45;
    if (e.phase !== 2 && e.phase !== 1)
      e.angle = Math.atan2(g.player.x - e.x, g.player.z - e.z);
    e.x += Math.sin(e.angle) * v * dt;
    e.z += Math.cos(e.angle) * v * dt;
    resolveScenery(e);
    if (e.kind === "mud" && e.clock <= 0) {
      paintFloor(g.floor, e, 1.0, false);
      e.clock = 0.45;
    }
    if (d < (e.kind === "boss" ? 1.8 : 1) && g.invincible <= 0) {
      g.hp = Math.max(0, g.hp - (e.kind === "boss" ? 25 : 10));
      g.invincible = 1;
      effect(g, "hit", g.player, 1.2);
    }
  }
  if (g.hp <= 0) {
    g.status = "lost";
    g.reason = "バッテリー切れ。おつかれさま！";
    return;
  }
  attack(g, dt);
  updateStation(g, dt);
  g.enemies = g.enemies.filter((e) => e.hp > 0);
  g.effects = g.effects.filter((f) => (f.life -= dt) > 0);
  if (g.status !== "running") return;
  g.pickups = g.pickups.filter((p) => {
    const d = dist(p, g.player),
      r = 2.2 + g.boosts.magnet * 0.8;
    if (d < r) {
      p.x += (g.player.x - p.x) * Math.min(1, dt * 10);
      p.z += (g.player.z - p.z) * Math.min(1, dt * 10);
    }
    if (d < 0.65) {
      if (p.heal) g.hp = Math.min(g.maxHp, g.hp + p.value);
      else g.xp += p.value;
      return false;
    }
    return true;
  });
  levelUp(g);
}

export function updateStation(g: Game, dt: number) {
  if (g.status !== "running") return;
  const s = g.station;
  s.clock -= dt;
  if (s.clock <= 0) {
    s.clock = 0.2;
    if (!s.active) s.connected = connectedToStation(g.floor);
    if (s.active) paintFloor(g.floor, STATION, Math.min(7, 2 + s.age * 0.15));
  }
  if (s.active) s.age += dt;
  else {
    s.progress = s.connected ? Math.min(2, s.progress + dt) : 0;
    if (s.progress >= 2) {
      s.active = true;
      s.age = 0;
      g.hp = Math.min(g.maxHp, g.hp + 20);
      g.xp += 5;
      paintFloor(g.floor, STATION, 2);
      effect(g, "chain", STATION, 3, 0.6);
    }
  }
}
export function synergies(g: Game) {
  return [
    ...(g.weapons.nozzle && g.weapons.spray ? ["泡バキューム"] : []),
    ...(g.weapons.mop && g.weapons.spray ? ["泡の滑走路"] : []),
  ];
}
export function synergyHint(g: Game, choice: Upgrade) {
  if (choice === "spray")
    return g.weapons.mop
      ? "連携：モップが幅広い清掃帯を作る"
      : "連携：吸引で泡の敵を引き込み、周囲も攻撃";
  if (choice === "mop" && g.weapons.spray)
    return "連携：泡とモップで幅広い清掃帯";
  if (choice === "nozzle" && g.weapons.spray)
    return "連携：泡の敵を引き込み、周囲も攻撃";
  return "";
}
