import { DAY_SECONDS } from './constants.ts';
import { isPassable } from './disasters.ts';
import type { Cell, Resident, TripPurpose, World } from './types.ts';

export function jobCapacity(cell: Cell): number {
  if (cell.closed || !isPassable(cell)) return 0;
  return cell.kind === 'farm' ? 5 + cell.level * 3 : cell.kind === 'factory' ? 12 + cell.level * 5 : cell.kind === 'shop' ? 3 + cell.level * 2 : 0;
}
export function neighbors(world: World, index: number): number[] {
  const x = index % world.size, y = Math.floor(index / world.size);
  return [x > 0 ? index - 1 : -1, x + 1 < world.size ? index + 1 : -1, y > 0 ? index - world.size : -1, y + 1 < world.size ? index + world.size : -1].filter(i => i >= 0);
}
const cache = new WeakMap<World, { version: number; routes: Map<string, number[] | null> }>();
const open = (cell: Cell) => isPassable(cell) && cell.terrain === 'land' && ['grass', 'park', 'ruin'].includes(cell.kind);
export function roadEntrances(world: World, index: number): number[][] {
  if (!world.cells[index] || !isPassable(world.cells[index])) return [];
  if (world.cells[index].kind === 'road') return [[index]];
  const found: number[][] = [], queue = [[index]], seen = new Set([index]);
  for (let q = 0; q < queue.length; q++) for (const next of neighbors(world, queue[q].at(-1)!)) {
    if (seen.has(next)) continue;
    seen.add(next);
    if (world.cells[next].kind === 'road' && isPassable(world.cells[next])) found.push([...queue[q], next]);
    else if (queue[q].length <= 2 && open(world.cells[next])) queue.push([...queue[q], next]);
  }
  return found;
}
/** Short driveways and passable roads only. Cache invalidates when hazard/repair changes topology. */
export function findRoute(world: World, from: number, to: number): number[] | null {
  let memo = cache.get(world);
  if (!memo || memo.version !== world.topologyVersion) { memo = { version: world.topologyVersion, routes: new Map() }; cache.set(world, memo); }
  const key = `${from}:${to}`;
  if (memo.routes.has(key)) return memo.routes.get(key)!;
  const result = routeUncached(world, from, to); memo.routes.set(key, result); return result;
}
function routeUncached(world: World, from: number, to: number): number[] | null {
  if (!world.cells[from] || !world.cells[to] || !isPassable(world.cells[to])) return null;
  if (from === to) return [from];
  // A person trapped on a newly damaged cell may step out onto a safe cardinal neighbor.
  const starts = isPassable(world.cells[from]) ? roadEntrances(world, from) : neighbors(world, from).flatMap(index => roadEntrances(world, index).map(route => [from, ...route]));
  const ends = roadEntrances(world, to);
  if (!starts.length || !ends.length) return null;
  const endpoint = new Map(ends.map(route => [route.at(-1)!, route]));
  const queue: number[] = [], previous = new Int32Array(world.cells.length).fill(-2), origin = new Map<number, number[]>();
  for (const route of starts) { const end = route.at(-1)!; if (previous[end] !== -2) continue; queue.push(end); previous[end] = -1; origin.set(end, route); }
  for (let q = 0; q < queue.length; q++) {
    const current = queue[q];
    if (endpoint.has(current)) {
      const middle = [current]; let node = current;
      while (previous[node] !== -1) { node = previous[node]; middle.push(node); }
      middle.reverse();
      return [...origin.get(node)!, ...middle.slice(1), ...endpoint.get(current)!.slice(0, -1).reverse()];
    }
    for (const next of neighbors(world, current)) if (world.cells[next].kind === 'road' && isPassable(world.cells[next]) && previous[next] === -2) { previous[next] = current; queue.push(next); }
  }
  return null;
}
export function residentCell(_world: World, person: Resident): number {
  if (person.route.length) return person.route[Math.min(person.routeIndex, person.route.length - 1)];
  return person.destination ?? person.shelter ?? person.home;
}
export function newResident(world: World, home: number, role: Resident['role'] = 'worker'): Resident {
  const cell = world.cells[home], id = world.nextResidentId++;
  return { id, role, health: 100, hunger: 0, food: 4, shelter: null, displaced: false, home, workplace: null, shop: null, x: cell.x, y: cell.y, route: [], routeIndex: 0, progress: 0, state: 'home', purpose: 'commute', destination: null, timer: id % 12 * .4, color: id % 6, trips: 0 };
}
/** Reassign future work and shops; never invent/remove residents from housing capacity. */
export function synchronizeResidents(world: World): void {
  cache.delete(world);
  const workplaces = world.cells.flatMap((cell, index) => jobCapacity(cell) ? [index] : []);
  const stores = workplaces.filter(index => world.cells[index].kind === 'shop');
  const used = new Map<number, number>(), candidates = new Map<number, number[]>(), shops = new Map<number, number[]>();
  for (const person of [...world.residents].sort((a, b) => a.id - b.id)) {
    const base = person.displaced ? person.shelter ?? residentCell(world, person) : person.home;
    if (!candidates.has(base)) candidates.set(base, workplaces.filter(index => findRoute(world, base, index)).sort((a, b) => {
      const priority = (i: number) => world.cells[i].kind === 'farm' ? 0 : world.cells[i].kind === 'factory' ? 1 : 2;
      return priority(a) - priority(b) || findRoute(world, base, a)!.length - findRoute(world, base, b)!.length || a - b;
    }));
    const available = candidates.get(base)!;
    person.workplace = person.role !== 'worker' ? null : person.workplace !== null && available.includes(person.workplace) && (used.get(person.workplace) ?? 0) < jobCapacity(world.cells[person.workplace]) ? person.workplace : available.find(index => world.cells[index].kind === (person.id % 5 === 0 ? 'factory' : person.id % 5 === 1 ? 'shop' : 'farm') && (used.get(index) ?? 0) < jobCapacity(world.cells[index])) ?? available.find(index => (used.get(index) ?? 0) < jobCapacity(world.cells[index])) ?? null;
    if (person.workplace !== null) used.set(person.workplace, (used.get(person.workplace) ?? 0) + 1);
    if (!shops.has(base)) shops.set(base, stores.filter(index => findRoute(world, base, index)).sort((a, b) => findRoute(world, base, a)!.length - findRoute(world, base, b)!.length || a - b));
    person.shop = shops.get(base)![0] ?? null;
  }
  world.cells.forEach((cell, index) => { cell.accessible = roadEntrances(world, index).length > 0; });
  world.economy.workers = world.residents.filter(person => person.role === 'worker').length;
  world.economy.employed = world.residents.filter(person => person.workplace !== null).length;
}
export function depart(world: World, person: Resident, destination: number, purpose: TripPurpose): boolean {
  const route = findRoute(world, residentCell(world, person), destination);
  if (!route) return false;
  person.route = [...route]; person.routeIndex = 0; person.progress = 0; person.destination = destination; person.purpose = purpose; person.timer = 0;
  person.state = 'travel';
  if (route.length === 1) arrive(world, person);
  return true;
}
function arrive(world: World, person: Resident): void {
  const cell = world.cells[person.destination!]; person.trips++;
  if (person.purpose === 'return') { if(person.displaced&&person.destination===person.home&&world.cells[person.home].kind==='house'&&isPassable(world.cells[person.home])){person.displaced=false;person.shelter=null;} person.state = person.displaced ? 'shelter' : 'home'; person.destination = null; person.timer = 2 + person.id % 5; return; }
  if (person.purpose === 'refuge') { person.state = 'shelter'; person.shelter = person.destination; person.timer = 2; return; }
  if (person.purpose === 'repair') { person.state = 'repair'; person.timer = 7; return; }
  if (person.purpose === 'commute' && jobCapacity(cell)) { person.state = 'work'; person.timer = DAY_SECONDS * .28; world.economy.commutes++; }
  else if (person.purpose === 'shopping' && cell.kind === 'shop') { person.state = 'shop'; person.timer = 1; }
  else { person.state = 'park'; person.timer = 2; }
}
function refuge(world: World, person: Resident): boolean {
  const from = residentCell(world, person);
  const choices = world.cells.flatMap((cell, i) => isPassable(cell) && ((cell.kind === 'house' && cell.population < 3 + cell.level * 3) || cell.kind === 'park' || (cell.kind === 'grass' && cell.accessible)) ? [i] : []).sort((a, b) => (world.cells[a].kind==='grass'?1:0)-(world.cells[b].kind==='grass'?1:0) || Math.abs(world.cells[a].x - person.x) + Math.abs(world.cells[a].y - person.y) - Math.abs(world.cells[b].x - person.x) - Math.abs(world.cells[b].y - person.y) || a - b);
  for (const choice of choices) if (choice !== from && depart(world, person, choice, 'refuge')) return true;
  return false;
}
export function walkingSpeed(world: World, person: Resident): number {
  return (world.weather.kind === 'snow' ? .8 : world.weather.kind === 'rain' ? 1.05 : 1.3) * (.5 + person.health / 200);
}
/** Walk only checked segments; a broken segment freezes its exact fractional position. */
export function advanceResidents(world: World, elapsed: number): void {
  if (!Number.isFinite(elapsed) || elapsed <= 0) return;
  for (const person of world.residents) {
    if (person.health <= 0) continue;
    const homeLost = world.cells[person.home].kind !== 'house' || !isPassable(world.cells[person.home]);
    if (homeLost && !person.displaced) { person.displaced = true; person.shelter = null; }
    if (person.state === 'travel' || (person.state === 'wait' && person.progress > 0)) {
      let remaining = elapsed;
      const speed = walkingSpeed(world, person);
      while (remaining > 1e-10 && (person.state === 'travel' || person.state === 'wait')) {
        const a = world.cells[person.route[person.routeIndex]], b = world.cells[person.route[person.routeIndex + 1]];
        if (!a || !b || !isPassable(b)) { person.state = 'wait'; person.timer += remaining; break; }
        person.state = 'travel';
        const consumed = Math.min(remaining, (1 - person.progress) / speed);
        person.progress = Math.min(1, person.progress + consumed * speed);
        remaining -= consumed;
        person.x = a.x + (b.x - a.x) * person.progress;
        person.y = a.y + (b.y - a.y) * person.progress;
        if (person.progress >= 1 - 1e-10) {
          person.x = b.x; person.y = b.y;
          if (b.kind === 'road') b.traffic = Math.min(100, b.traffic + 1);
          person.routeIndex++; person.progress = 0;
          if (person.routeIndex === person.route.length - 1) {
            arrive(world, person);
            person.timer = Math.max(0, person.timer - remaining);
            break;
          }
        }
      }
      continue;
    }
    person.timer = Math.max(0, person.timer - elapsed);
    if (person.timer > 0 || person.state === 'shop') continue;
    if(person.displaced&&!homeLost&&depart(world,person,person.home,'return'))continue;
    if (person.displaced && person.shelter === null) { if (!refuge(world, person)) { person.state = 'wait'; person.timer = 2; } continue; }
    if (person.state === 'work' || person.state === 'repair' || person.state === 'park') {
      if (!depart(world, person, person.shelter ?? person.home, 'return')) { person.state = 'wait'; person.timer = 2; } continue;
    }
    if (person.state === 'wait' && person.destination !== null && !person.displaced) {
      if (depart(world, person, person.destination, person.purpose)) continue;
    }
    if (person.food < 2 && person.shop !== null && depart(world, person, person.shop, 'shopping')) continue;
    // A worker at a safe road can repair the neighboring closed bridge without entering it.
    if (person.role === 'worker' && (person.trips % 6 === 4 || person.workplace === null || (person.id % 4 === 0 && world.cells.some(c=>c.buildingPlan!==null) && person.trips % 2 === 0))) {
      const current = residentCell(world, person);
      const approach = world.cells.flatMap((cell, index) => isPassable(cell) && cell.kind === 'road' && neighbors(world, index).some(i => (world.cells[i].kind === 'road' && world.cells[i].condition < 70) || world.cells[i].buildingPlan !== null) ? [index] : []).sort((a, b) => Math.abs(a % world.size - current % world.size) + Math.abs(Math.floor(a / world.size) - Math.floor(current / world.size)) - Math.abs(b % world.size - current % world.size) - Math.abs(Math.floor(b / world.size) - Math.floor(current / world.size)) || a - b);
      if (approach.some(index => depart(world, person, index, 'repair'))) continue;
    }
    if (person.role === 'worker' && person.workplace !== null && depart(world, person, person.workplace, 'commute')) continue;
    const park = world.cells.findIndex((cell, i) => cell.kind === 'park' && i!==residentCell(world,person) && findRoute(world, residentCell(world, person), i));
    if (park >= 0 && depart(world, person, park, 'stroll')) continue;
    person.timer = 3;
  }
}
