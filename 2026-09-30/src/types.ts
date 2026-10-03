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
  elevation: number;
  waterDepth: number;
  fire: number;
  snow: number;
  rubble: number;
  crater: number;
  stock: number;
  materials: number;
  work: number;
  region: number;
  closed: boolean;
  buildingPlan: 'house' | 'shop' | 'farm' | 'factory' | null;
}

export interface TownEvent {
  tick: number;
  x: number;
  y: number;
  kind: 'birth' | 'growth' | 'decline' | 'nature' | 'road' | 'god' | 'disaster' | 'supply' | 'refuge';
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

export type TripPurpose = 'commute' | 'shopping' | 'stroll' | 'return' | 'refuge' | 'repair';
export interface Resident {
  id: number;
  role: 'worker' | 'dependent';
  health: number;
  hunger: number;
  food: number;
  shelter: number | null;
  displaced: boolean;
  home: number;
  workplace: number | null;
  shop: number | null;
  x: number;
  y: number;
  route: number[];
  routeIndex: number;
  progress: number;
  state: 'home' | 'travel' | 'work' | 'shop' | 'park' | 'shelter' | 'wait' | 'repair';
  purpose: TripPurpose;
  destination: number | null;
  timer: number;
  color: number;
  trips: number;
}
export interface Weather {
  kind: 'clear' | 'cloudy' | 'rain' | 'storm' | 'snow';
  temperature: number;
  rainfall: number;
  cloud: number;
  windX: number;
  windY: number;
  remaining: number;
  frontX: number;
  frontY: number;
  frontRadius: number;
}
export interface Economy {
  workers: number;
  employed: number;
  food: number;
  harvest: number;
  visits: number;
  commutes: number;
  materials: number;
  starving: number;
  evacuated: number;
  deaths: number;
  births: number;
  arrivals: number;
  departures: number;
  failedPurchases: number;
}
export interface World {
  version: 3;
  step: number;
  remainder: number;
  revision: number;
  topologyVersion: number;
  hazardRng: number;
  nextCommandId: number;
  pending: PowerCommand[];
  effects: ActiveEffect[];
  shipments: Shipment[];
  nextShipmentId: number;
  naturalPolicy: NaturalPolicy;
  migrationGrace: number;
  legacyCalendar?: { tick: number; history: HistoryPoint[] };
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
  preview?: PowerPreview | null;
  layer?: 'none' | 'water' | 'fire' | 'supply';
}

export type PowerKind = 'rain' | 'sun' | 'storm' | 'lightning' | 'earthquake' | 'meteor' | 'growth' | 'settle';
export type NaturalPolicy = 'off' | 'gentle' | 'wild' | 'apocalyptic';
export interface PowerPreview { kind: PowerKind; center: Point; radius: number; intensity: number }
export interface PowerInput { kind: PowerKind; target: Point; radius: number; intensity: number; duration: number; source?: 'god' | 'nature' }
export interface PowerCommand extends PowerInput { id: number; atStep: number; source: 'god' | 'nature'; seed: number }
export interface ActiveEffect extends PowerCommand { remaining: number; elapsed: number }
export interface Shipment { id: number; from: number; to: number; food: number; materials: number; route: number[]; routeIndex: number; progress: number; blocked: boolean }
