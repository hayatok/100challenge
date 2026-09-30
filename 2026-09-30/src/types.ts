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

export interface World {
  version: 1;
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
}
