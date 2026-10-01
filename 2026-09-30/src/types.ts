export type CellKind = 'grass' | 'tree' | 'water' | 'road' | 'house' | 'shop' | 'farm' | 'factory' | 'ruin' | 'park';
export type Terrain = 'land' | 'water';

export interface Cell {
  x: number;
  y: number;
  terrain: Terrain;
  kind: CellKind;
  level: number;
  age: number;
  population: number;
  vitality: number;
  environment: number;
  traffic: number;
  variant: number;
  reason: string;
  changedAt: number;
  moisture: number;
  fertility: number;
  vegetation: number;
  crop: number;
  condition: number;
  development: number;
  employed: number;
  customers: number;
  accessible: boolean;
}

export interface TownEvent {
  tick: number;
  x: number;
  y: number;
  kind: 'birth' | 'growth' | 'decline' | 'nature' | 'road';
  text: string;
}

export interface TownStats {
  population: number;
  homes: number;
  shops: number;
  farms: number;
  factories: number;
  ruins: number;
  roads: number;
  environment: number;
  jobs: number;
  born: number;
  retired: number;
}

export interface HistoryPoint {
  tick: number;
  population: number;
}

export type TripPurpose = 'commute' | 'shopping' | 'stroll' | 'return';
export interface Resident {
  id: number;
  home: number;
  workplace: number | null;
  shop: number | null;
  x: number;
  y: number;
  route: number[];
  routeIndex: number;
  progress: number;
  state: 'home' | 'travel' | 'work' | 'shop' | 'park';
  purpose: TripPurpose;
  destination: number | null;
  timer: number;
  color: number;
  trips: number;
}
export interface Weather {
  kind: 'clear' | 'rain' | 'snow';
  temperature: number;
  rainfall: number;
}
export interface Economy {
  workers: number;
  employed: number;
  food: number;
  harvest: number;
  visits: number;
  commutes: number;
}
export interface World {
  version: 2;
  clock: number;
  nextResidentId: number;
  residents: Resident[];
  weather: Weather;
  economy: Economy;
  seed: number;
  rng: number;
  size: number;
  tick: number;
  cells: Cell[];
  stats: TownStats;
  events: TownEvent[];
  history: HistoryPoint[];
}

export interface Point {
  x: number;
  y: number;
}

export interface Camera {
  zoom: number;
  panX: number;
  panY: number;
}

export interface RenderOptions {
  camera: Camera;
  selected: Point | null;
  time: number;
  reducedMotion: boolean;
  followedResident?: number | null;
  showRoutes?: boolean;
}
