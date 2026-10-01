import type { Cell, Resident, TripPurpose, World } from './types.ts';

export function jobCapacity(cell: Cell): number {
  return cell.kind === 'farm' ? 5 + cell.level * 3 : cell.kind === 'factory' ? 12 + cell.level * 5 : cell.kind === 'shop' ? 3 + cell.level * 2 : 0;
}
export function neighbors(world: World, index: number): number[] {
  const x = index % world.size, y = Math.floor(index / world.size);
  return [x > 0 ? index - 1 : -1, x + 1 < world.size ? index + 1 : -1, y > 0 ? index - world.size : -1, y + 1 < world.size ? index + world.size : -1].filter(i => i >= 0);
}
const routingCache = new WeakMap<World, { topology: string; routes: Map<string, number[] | null> }>();
const open = (cell: Cell) => cell.terrain === 'land' && ['grass', 'park', 'ruin'].includes(cell.kind);
/** Driveways stop after two clear ground cells; water and neighboring buildings are barriers. */
export function roadEntrances(world: World, index: number): number[][] {
  if (world.cells[index].kind === 'road') return [[index]];
  const found: number[][] = [], queue = [[index]], seen = new Set([index]);
  for (let q = 0; q < queue.length; q++) {
    const route = queue[q];
    for (const next of neighbors(world, route.at(-1)!)) {
      if (seen.has(next)) continue;
      seen.add(next);
      if (world.cells[next].kind === 'road') found.push([...route, next]);
      else if (route.length <= 2 && open(world.cells[next])) queue.push([...route, next]);
    }
  }
  return found;
}
/** Cardinal road-only BFS between short entrances. No Euclidean employment shortcut. */
export function findRoute(world: World, from: number, to: number): number[] | null {
  if (from === to) return [from];
  const starts = roadEntrances(world, from), ends = roadEntrances(world, to);
  if (!starts.length || !ends.length) return null;
  const endpoint = new Map(ends.map(route => [route.at(-1)!, route]));
  const queue: number[] = [], previous = new Int32Array(world.cells.length).fill(-2);
  const origin = new Map<number, number[]>();
  for (const route of starts) { const end = route.at(-1)!; if (previous[end] !== -2) continue; queue.push(end); previous[end] = -1; origin.set(end, route); }
  for (let q = 0; q < queue.length; q++) {
    const current = queue[q];
    if (endpoint.has(current)) {
      const middle = [current]; let node = current;
      while (previous[node] !== -1) { node = previous[node]; middle.push(node); }
      middle.reverse();
      return [...origin.get(node)!, ...middle.slice(1), ...endpoint.get(current)!.slice(0, -1).reverse()];
    }
    for (const next of neighbors(world, current)) if (world.cells[next].kind === 'road' && previous[next] === -2) { previous[next] = current; queue.push(next); }
  }
  return null;
}

/** Keep identities and in-flight paths. Only reconcile household headcount and future assignments. */
export function synchronizeResidents(world: World): void {
  const counts = new Map<number, number>();
  world.residents = world.residents.filter(resident => {
    const count = counts.get(resident.home) ?? 0;
    const target = world.cells[resident.home].kind === 'house' ? Math.max(1, Math.floor(world.cells[resident.home].population / 2)) : 0;
    if (count >= target && resident.state === 'home') return false;
    counts.set(resident.home, count + 1); return true;
  });
  world.cells.forEach((cell, home) => {
    if (cell.kind !== 'house') return;
    const target = Math.max(1, Math.floor(cell.population / 2));
    for (let count = counts.get(home) ?? 0; count < target; count++) {
      world.residents.push({ id: world.nextResidentId++, home, workplace: null, shop: null, x: cell.x, y: cell.y, route: [], routeIndex: 0, progress: 0, state: 'home', purpose: 'commute', destination: null, timer: (home + count * 7) % 12 * .35, color: (home + count) % 6, trips: 0 });
    }
  });
  const workplaces = world.cells.flatMap((cell, index) => jobCapacity(cell) ? [index] : []);
  const shops = workplaces.filter(index => world.cells[index].kind === 'shop');
  const topology = world.cells.map(cell => cell.kind).join(',');
  let cached = routingCache.get(world);
  if (!cached || cached.topology !== topology) { cached = { topology, routes: new Map() }; routingCache.set(world, cached); }
  const routes = cached.routes;
  const route = (home: number, destination: number) => { const key = `${home}:${destination}`; if (!routes.has(key)) routes.set(key, findRoute(world, home, destination)); return routes.get(key); };
  const used = new Map<number, number>();
  const candidates = new Map<number, number[]>();
  for (const resident of world.residents) {
    if (world.cells[resident.home].kind !== 'house') { resident.workplace = null; resident.shop = null; continue; }
    if (!candidates.has(resident.home)) candidates.set(resident.home, workplaces.filter(index => route(resident.home, index)).sort((a, b) => route(resident.home, a)!.length - route(resident.home, b)!.length || a - b));
    const available = candidates.get(resident.home)!;
    const previous = resident.workplace;
    resident.workplace = previous !== null && available.includes(previous) && (used.get(previous) ?? 0) < jobCapacity(world.cells[previous]) ? previous : available.find(index => (used.get(index) ?? 0) < jobCapacity(world.cells[index])) ?? null;
    if (resident.workplace !== null) used.set(resident.workplace, (used.get(resident.workplace) ?? 0) + 1);
    const reachableShops = shops.filter(index => route(resident.home, index)).sort((a, b) => route(resident.home, a)!.length - route(resident.home, b)!.length || a - b).slice(0, 3);
    resident.shop = reachableShops[resident.id % Math.max(1, reachableShops.length)] ?? null;
  }
  for (const cell of world.cells) cell.accessible = roadEntrances(world, cell.y * world.size + cell.x).length > 0;
  world.economy.workers = world.residents.filter(resident => world.cells[resident.home].kind === 'house').length;
  world.economy.employed = world.residents.filter(resident => resident.workplace !== null).length;
}

function depart(world: World, resident: Resident, destination: number, purpose: TripPurpose): boolean {
  const from = resident.destination ?? resident.home;
  const route = findRoute(world, from, destination);
  if (!route || route.length < 2) return false;
  resident.route = route; resident.routeIndex = 0; resident.progress = 0; resident.destination = destination; resident.purpose = purpose; resident.state = 'travel';
  return true;
}
function arrive(world: World, resident: Resident): void {
  const cell = world.cells[resident.destination!];
  resident.trips++;
  if (resident.purpose === 'return') { resident.state = 'home'; resident.destination = null; resident.timer = resident.trips % 4 === 0 ? Math.max(3, 150 - world.clock % 150 + resident.id % 12) : Math.max(3, 65 - world.clock % 150 + resident.id % 10); return; }
  if (resident.purpose === 'commute' && jobCapacity(cell)) { resident.state = 'work'; resident.timer = 6 + resident.id % 5; cell.employed = Math.min(10000, cell.employed + 1); world.economy.commutes = Math.min(100000, world.economy.commutes + 1); }
  else if (resident.purpose === 'shopping' && cell.kind === 'shop') { resident.state = 'shop'; resident.timer = 2 + resident.id % 3; cell.customers = Math.min(10000, cell.customers + 1); world.economy.visits = Math.min(100000, world.economy.visits + 1); world.economy.food = Math.max(0, world.economy.food - .2); }
  else { resident.state = 'park'; resident.timer = 2; }
}
/** Persistent time-based journeys; a changed building does not teleport an existing pedestrian. */
export function advanceResidents(world: World, deltaSeconds: number): void {
  if (!Number.isFinite(deltaSeconds) || deltaSeconds <= 0) return;
  const elapsed = Math.min(deltaSeconds, 10);
  world.clock = Math.min(1e12, world.clock + elapsed);
  for (const resident of world.residents) {
    let remaining = elapsed;
    for (let iteration = 0; remaining > 0 && iteration < 64; iteration++) {
      if (resident.state !== 'travel') {
        const consumed = Math.min(remaining, resident.timer); resident.timer -= consumed; remaining -= consumed;
        if (resident.timer > 0) break;
        if (resident.state === 'home') {
          let destination = resident.trips % 4 === 2 ? resident.shop : resident.workplace;
          let purpose: TripPurpose = resident.trips % 4 === 2 ? 'shopping' : 'commute';
          if (destination === null) { destination = resident.shop; purpose = 'shopping'; }
          if (destination === null) { destination = world.cells.findIndex(cell => cell.kind === 'park' && findRoute(world, resident.home, cell.y * world.size + cell.x)); purpose = 'stroll'; }
          if (destination === null || destination < 0 || !depart(world, resident, destination, purpose)) { resident.timer = 5; break; }
        } else if (!depart(world, resident, resident.home, 'return')) {
          // Retrace a previously valid journey if a driveway changed during the visit.
          const reversed = [...resident.route].reverse();
          if (reversed.length < 2) { resident.timer = 5; break; }
          resident.route = reversed; resident.routeIndex = 0; resident.progress = 0; resident.destination = resident.home; resident.purpose = 'return'; resident.state = 'travel';
        }
      }
      const speed = world.weather.kind === 'snow' ? .68 : world.weather.kind === 'rain' ? .85 : 1.05;
      const time = (1 - resident.progress) / speed, consumed = Math.min(remaining, time);
      resident.progress += consumed * speed; remaining -= consumed;
      const a = world.cells[resident.route[resident.routeIndex]], b = world.cells[resident.route[resident.routeIndex + 1]];
      if (!a || !b) break;
      resident.x = a.x + (b.x - a.x) * Math.min(1, resident.progress); resident.y = a.y + (b.y - a.y) * Math.min(1, resident.progress);
      if (resident.progress >= 1 - 1e-9) {
        if (b.kind === 'road') b.traffic = Math.min(100, b.traffic + 2);
        resident.routeIndex++; resident.progress = 0;
        if (resident.routeIndex === resident.route.length - 1) arrive(world, resident);
      }
    }
  }
}
