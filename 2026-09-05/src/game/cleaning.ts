/** Simulation-owned floor; rendering consumes the same cells and never mutates them. */
export const CELL = 0.5;
export const EDGE = 28;
export const GRID = 112;
export const DOCK = { x: 0, z: 0 };
export const STATION = { x: -7, z: -5 };
export const SCENERY = [
  { x: -7, z: -11, halfX: 4.1, halfZ: 1.5 },
  { ...STATION, halfX: 0.65, halfZ: 0.5 },
];
export type Floor = {
  cells: Uint8Array;
  ever: Uint8Array;
  cleaned: number;
  unique: number;
  total: number;
  version: number;
};
export function pointAt(i: number) {
  return {
    x: ((i % GRID) + 0.5) * CELL - EDGE,
    z: (Math.floor(i / GRID) + 0.5) * CELL - EDGE,
  };
}
export function floorIndex(p: { x: number; z: number }) {
  const x = Math.floor((p.x + EDGE) / CELL),
    z = Math.floor((p.z + EDGE) / CELL);
  return x < 0 || z < 0 || x >= GRID || z >= GRID ? -1 : z * GRID + x;
}
export function walkable(p: { x: number; z: number }) {
  return (
    Math.hypot(p.x, p.z) <= EDGE &&
    !SCENERY.some(
      (b) => Math.abs(p.x - b.x) < b.halfX && Math.abs(p.z - b.z) < b.halfZ,
    )
  );
}
export function createFloor(): Floor {
  const cells = new Uint8Array(GRID * GRID);
  let total = 0;
  for (let i = 0; i < cells.length; i++) if (walkable(pointAt(i))) total++;
  return {
    cells,
    ever: new Uint8Array(cells.length),
    cleaned: 0,
    unique: 0,
    total,
    version: 0,
  };
}
export function cleanAt(f: Floor, p: { x: number; z: number }) {
  const i = floorIndex(p);
  return i >= 0 && f.cells[i] === 1;
}
export function paintFloor(
  f: Floor,
  p: { x: number; z: number },
  radius: number,
  clean = true,
) {
  const minX = Math.max(0, Math.floor((p.x - radius + EDGE) / CELL)),
    maxX = Math.min(GRID - 1, Math.floor((p.x + radius + EDGE) / CELL));
  const minZ = Math.max(0, Math.floor((p.z - radius + EDGE) / CELL)),
    maxZ = Math.min(GRID - 1, Math.floor((p.z + radius + EDGE) / CELL));
  let changed = 0;
  for (let z = minZ; z <= maxZ; z++)
    for (let x = minX; x <= maxX; x++) {
      const i = z * GRID + x,
        q = pointAt(i);
      if (Math.hypot(q.x - p.x, q.z - p.z) > radius || !walkable(q)) continue;
      const value = clean ? 1 : 0;
      if (f.cells[i] === value) continue;
      f.cells[i] = value;
      f.cleaned += clean ? 1 : -1;
      changed++;
      if (clean && !f.ever[i]) {
        f.ever[i] = 1;
        f.unique++;
      }
    }
  if (changed) f.version++;
  return changed;
}
export function connectedToStation(f: Floor) {
  const start = floorIndex(DOCK),
    seen = new Uint8Array(f.cells.length),
    queue = new Int32Array(f.cells.length);
  if (!f.cells[start]) return false;
  let head = 0,
    tail = 1;
  queue[0] = start;
  seen[start] = 1;
  while (head < tail) {
    const i = queue[head++],
      p = pointAt(i);
    if (Math.hypot(p.x - STATION.x, p.z - STATION.z) < 1.5) return true;
    const x = i % GRID,
      z = Math.floor(i / GRID);
    const next = [
      x > 0 ? i - 1 : -1,
      x < GRID - 1 ? i + 1 : -1,
      z > 0 ? i - GRID : -1,
      z < GRID - 1 ? i + GRID : -1,
    ];
    for (const n of next)
      if (n >= 0 && f.cells[n] && !seen[n]) {
        seen[n] = 1;
        queue[tail++] = n;
      }
  }
  return false;
}
export function cleaningPercent(f: Floor) {
  return Math.round((f.cleaned / f.total) * 1000) / 10;
}
export function resolveScenery(p: { x: number; z: number }) {
  for (const b of SCENERY) {
    const dx = p.x - b.x,
      dz = p.z - b.z,
      ex = b.halfX + 0.45,
      ez = b.halfZ + 0.45;
    if (Math.abs(dx) < ex && Math.abs(dz) < ez) {
      if (ex - Math.abs(dx) < ez - Math.abs(dz))
        p.x = b.x + (dx < 0 ? -ex : ex);
      else p.z = b.z + (dz < 0 ? -ez : ez);
    }
  }
}
