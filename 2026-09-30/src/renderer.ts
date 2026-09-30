import type { Camera, Cell, Point, RenderOptions, World } from './types';

export const CANVAS_WIDTH = 960;
export const CANVAS_HEIGHT = 640;
const HALF_W = 9;
const HALF_H = 5;
const CENTER_X = CANVAS_WIDTH / 2;
const CENTER_Y = CANVAS_HEIGHT / 2;
const MAP_TOP = 82;

type Vertex = readonly [number, number];
interface WindowLight { x: number; y: number; width: number; height: number; seed: number }
interface HitShape { cell: Cell; x: number; y: number; height: number; width: number }

const PALETTES = [
  { grass: ['#91b77a', '#94b97c', '#8eb478', '#98bb80'], tree: ['#446e4d', '#5a8753', '#78a360'], flower: '#f2d3ba', crop: '#97b65f' },
  { grass: ['#88a972', '#8aad74', '#84a66d', '#8ead77'], tree: ['#385f48', '#507a4a', '#72944f'], flower: '#f2dfa5', crop: '#a7b66a' },
  { grass: ['#a5ad76', '#a9af7a', '#a1a871', '#adb47d'], tree: ['#745c40', '#b3804e', '#d4a866'], flower: '#d9b276', crop: '#c3a369' },
  { grass: ['#b6c3ac', '#bac7b1', '#b2bfa8', '#bdc9b6'], tree: ['#607568', '#7b9380', '#b3c4ad'], flower: '#e8e6d7', crop: '#a6ab83' },
];

/** Original, integer-rasterized artwork: the browser never antialiases sprite edges. */
export class TownRenderer {
  readonly width = CANVAS_WIDTH;
  readonly height = CANVAS_HEIGHT;
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private readonly scene: HTMLCanvasElement;
  private readonly paint: CanvasRenderingContext2D;
  private cacheKey = '';
  private cachedWorld: World | null = null;
  private windows: WindowLight[] = [];
  private shapes: HitShape[] = [];
  private roads: Cell[] = [];
  private waters: Cell[] = [];
  private factories: Cell[] = [];

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;
    canvas.style.imageRendering = 'pixelated';
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('Canvas 2D is unavailable');
    this.ctx = ctx;
    this.scene = document.createElement('canvas');
    this.scene.width = CANVAS_WIDTH;
    this.scene.height = CANVAS_HEIGHT;
    const paint = this.scene.getContext('2d', { willReadFrequently: true });
    if (!paint) throw new Error('Canvas 2D is unavailable');
    this.paint = paint;
    ctx.imageSmoothingEnabled = false;
    paint.imageSmoothingEnabled = false;
  }

  render(world: World, options: RenderOptions): void {
    const key = `${world.seed}:${world.tick}:${world.size}`;
    if (this.cachedWorld !== world || key !== this.cacheKey) {
      this.cacheKey = key;
      this.cachedWorld = world;
      this.buildScene(world);
    }
    const ctx = this.ctx;
    const { camera, selected } = options;
    // The day starts in morning light. Darkness is tied to the simulation clock,
    // so pausing also freezes this small observational day/night cycle.
    const phase = (options.time % 150) / 150;
    const night = Math.max(0, -Math.cos(phase * Math.PI * 2)) * 0.49;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#e5ebe0';
    ctx.fillRect(0, 0, this.width, this.height);
    this.drawBackground(ctx, world);
    ctx.save();
    ctx.translate(CENTER_X + camera.panX, CENTER_Y + camera.panY);
    ctx.scale(camera.zoom, camera.zoom);
    ctx.translate(-CENTER_X, -CENTER_Y);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(this.scene, 0, 0);
    if (!options.reducedMotion) this.drawLife(ctx, world, options.time);
    ctx.restore();
    if (night > 0) {
      ctx.fillStyle = `rgba(22, 40, 60, ${night})`;
      ctx.fillRect(0, 0, this.width, this.height);
      ctx.save();
      ctx.translate(CENTER_X + camera.panX, CENTER_Y + camera.panY);
      ctx.scale(camera.zoom, camera.zoom);
      ctx.translate(-CENTER_X, -CENTER_Y);
      ctx.globalAlpha = Math.min(1, night * 3);
      for (const light of this.windows) {
        if (light.seed % 7 === 0) continue;
        this.rect(ctx, light.x, light.y, light.width, light.height, '#f4d895');
      }
      ctx.globalAlpha = 1;
      ctx.restore();
    }
    if (selected) {
      ctx.save();
      ctx.translate(CENTER_X + camera.panX, CENTER_Y + camera.panY);
      ctx.scale(camera.zoom, camera.zoom);
      ctx.translate(-CENTER_X, -CENTER_Y);
      const p = this.project(selected, world);
      this.outlineDiamond(ctx, p.x, p.y, HALF_W + 1, HALF_H + 1, '#364b3c');
      this.outlineDiamond(ctx, p.x, p.y - 1, HALF_W, HALF_H, '#fff1bd');
      // A tiny marker above the roof remains legible in a dense neighborhood.
      const cell = world.cells[selected.y * world.size + selected.x];
      const h = cell ? this.spriteHeight(cell) : 0;
      this.poly(ctx, [[p.x - 3, p.y - h - 8], [p.x + 3, p.y - h - 8], [p.x, p.y - h - 4]], '#fff1bd');
      ctx.restore();
    }
  }

  pick(clientX: number, clientY: number, world: World, camera: Camera): Point | null {
    const box = this.canvas.getBoundingClientRect();
    if (box.width <= 0 || box.height <= 0) return null;
    const px = (clientX - box.left) * this.width / box.width;
    const py = (clientY - box.top) * this.height / box.height;
    if (px < 0 || py < 0 || px > this.width || py > this.height) return null;
    const x = (px - CENTER_X - camera.panX) / camera.zoom + CENTER_X;
    const y = (py - CENTER_Y - camera.panY) / camera.zoom + CENTER_Y;
    // Respect painter order: the closest visible roof/tree wins over land behind it.
    if (this.cachedWorld === world) {
      for (let i = this.shapes.length - 1; i >= 0; i--) {
        const shape = this.shapes[i]!;
        const dx = Math.abs(x - shape.x);
        if (dx <= shape.width && y >= shape.y - shape.height && y <= shape.y + 3 - dx * 0.4) {
          return { x: shape.cell.x, y: shape.cell.y };
        }
      }
    }
    const horizontal = (x - CENTER_X) / HALF_W;
    const vertical = (y - this.mapTop(world)) / HALF_H;
    const tx = Math.floor((vertical + horizontal) / 2 + 0.5);
    const ty = Math.floor((vertical - horizontal) / 2 + 0.5);
    if (tx < 0 || ty < 0 || tx >= world.size || ty >= world.size) return null;
    return { x: tx, y: ty };
  }

  focus(point: Point, world: World, camera: Camera): Camera {
    const p = this.project(point, world);
    return {
      zoom: camera.zoom,
      panX: (CENTER_X - p.x) * camera.zoom,
      panY: (CENTER_Y - p.y + 10) * camera.zoom,
    };
  }

  private mapTop(world: World): number { return MAP_TOP + (48 - world.size) * HALF_H; }
  private project(point: Point, world: World): Point {
    return { x: CENTER_X + (point.x - point.y) * HALF_W, y: this.mapTop(world) + (point.x + point.y) * HALF_H };
  }

  private buildScene(world: World): void {
    const ctx = this.paint;
    ctx.clearRect(0, 0, this.width, this.height);
    this.windows = [];
    this.shapes = [];
    this.roads = [];
    this.waters = [];
    this.factories = [];
    const season = Math.floor(world.tick / 12) % 4;
    const palette = PALETTES[season]!;
    const span = (world.size - 1) * HALF_W;
    const top = this.mapTop(world) - HALF_H;
    const middle = top + world.size * HALF_H;
    const bottom = top + world.size * HALF_H * 2;
    // The exposed earth at the two near banks makes the town a little diorama.
    this.poly(ctx, [[CENTER_X - span - HALF_W + 9, middle + 16], [CENTER_X, bottom + 17], [CENTER_X + span + HALF_W + 9, middle + 16], [CENTER_X, top + 20]], '#d3dacb');
    this.poly(ctx, [[CENTER_X - span - HALF_W, middle], [CENTER_X, bottom], [CENTER_X, bottom + 7], [CENTER_X - span - HALF_W, middle + 7]], '#8b9470');
    this.poly(ctx, [[CENTER_X, bottom], [CENTER_X + span + HALF_W, middle], [CENTER_X + span + HALF_W, middle + 7], [CENTER_X, bottom + 7]], '#6e8065');
    for (const cell of world.cells) {
      const p = this.project(cell, world);
      const hash = this.hash(cell.x, cell.y, world.seed);
      const isWater = cell.terrain === 'water' || cell.kind === 'water';
      this.diamond(ctx, p.x, p.y, HALF_W, HALF_H, isWater ? ['#6cabb4', '#70afb8', '#6aa8b2'][hash % 3]! : palette.grass[hash % 4]!);
      if (isWater) {
        this.waters.push(cell);
        this.shore(ctx, cell, world, p);
        if (hash % 5 === 0) this.rect(ctx, p.x - 3, p.y, 4, 1, '#8abcc0');
      } else {
        if (hash % 4 === 0) {
          this.rect(ctx, p.x - 4, p.y, 2, 1, season === 3 ? '#cdd5c4' : '#779968');
          this.rect(ctx, p.x - 3, p.y - 1, 1, 1, season === 3 ? '#cdd5c4' : '#779968');
        }
        if (cell.kind === 'grass' && hash % 11 === 0) {
          this.rect(ctx, p.x + 3, p.y, 1, 1, palette.flower);
          this.rect(ctx, p.x + 5, p.y + 1, 1, 1, palette.flower);
        }
        if (cell.kind === 'grass' && hash % 47 === 0) {
          this.rect(ctx, p.x - 1, p.y, 3, 2, '#99a18a');
          this.rect(ctx, p.x, p.y, 2, 1, '#c1c7a8');
        }
      }
      if (cell.kind === 'road') {
        this.roads.push(cell);
        this.road(ctx, cell, world, p);
      }
      if (cell.kind === 'farm') this.farm(ctx, cell, p, season);
    }
    // Diagonal painter order prevents tall trees/buildings from being cut by a later row.
    for (let depth = 0; depth <= (world.size - 1) * 2; depth++) {
      for (let x = Math.max(0, depth - world.size + 1); x <= Math.min(world.size - 1, depth); x++) {
        const y = depth - x;
        const cell = world.cells[y * world.size + x];
        if (!cell) continue;
        const p = this.project(cell, world);
        switch (cell.kind) {
          case 'tree': this.tree(ctx, cell, p, season); break;
          case 'house': this.house(ctx, cell, p, season); break;
          case 'shop': this.shop(ctx, cell, p, season); break;
          case 'factory': this.factory(ctx, cell, p); this.factories.push(cell); break;
          case 'ruin': this.ruin(ctx, cell, p); break;
          case 'park': this.park(ctx, cell, p, season); break;
          case 'farm': if (cell.variant % 5 === 0) this.shed(ctx, cell, { x: p.x + 3, y: p.y - 1 }); break;
        }
        if (['tree', 'house', 'shop', 'factory', 'ruin', 'park'].includes(cell.kind)) {
          this.shapes.push({ cell, x: p.x, y: p.y, height: this.spriteHeight(cell), width: cell.kind === 'tree' ? 6 : 8 });
        }
      }
    }
    // Keep only window pixels left visible by the final painter order. A tree
    // in front of a house must hide its light as faithfully as it hides its wall.
    const pixels = ctx.getImageData(0, 0, this.width, this.height).data;
    const visibleLights: WindowLight[] = [];
    for (const light of this.windows) {
      for (let dy = 0; dy < light.height; dy++) {
        for (let dx = 0; dx < light.width; dx++) {
          const x = light.x + dx;
          const y = light.y + dy;
          const index = (y * this.width + x) * 4;
          const glass = pixels[index] === 110 && pixels[index + 1] === 138 && pixels[index + 2] === 135;
          const reflection = pixels[index] === 174 && pixels[index + 1] === 192 && pixels[index + 2] === 169;
          if (glass || reflection) visibleLights.push({ x, y, width: 1, height: 1, seed: light.seed });
        }
      }
    }
    this.windows = visibleLights;
  }

  private drawBackground(ctx: CanvasRenderingContext2D, world: World): void {
    // Sparse pixel speckles in the paper-colored margin keep a soft, quiet frame.
    for (let i = 0; i < 65; i++) {
      const x = this.hash(i, 81, world.seed) % this.width;
      const y = this.hash(i, 97, world.seed) % this.height;
      this.rect(ctx, x, y, 1, 1, '#dbe2d4');
    }
  }

  private shore(ctx: CanvasRenderingContext2D, cell: Cell, world: World, p: Point): void {
    const neighbors = [[-1, 0, -9, 0, 0, -5], [0, -1, 0, -5, 9, 0], [1, 0, 9, 0, 0, 5], [0, 1, 0, 5, -9, 0]];
    for (const n of neighbors) {
      const other = this.at(world, cell.x + n[0]!, cell.y + n[1]!);
      if (!other || other.terrain === 'water') continue;
      this.line(ctx, p.x + n[2]!, p.y + n[3]!, p.x + n[4]!, p.y + n[5]!, '#b5bf86');
      this.line(ctx, p.x + n[2]!, p.y + n[3]! + 1, p.x + n[4]!, p.y + n[5]! + 1, '#8da386');
    }
  }

  private road(ctx: CanvasRenderingContext2D, cell: Cell, world: World, p: Point): void {
    const bridge = cell.terrain === 'water';
    const surface = bridge ? '#c6aa78' : '#c3bd98';
    this.diamond(ctx, p.x, p.y, 9, 5, bridge ? '#786e57' : '#9aab78');
    this.diamond(ctx, p.x, p.y - (bridge ? 1 : 0), 7, 4, surface);
    for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      const neighbor = this.at(world, cell.x + dx!, cell.y + dy!);
      if (neighbor?.kind !== 'road') continue;
      const ex = p.x + (dx! - dy!) * HALF_W;
      const ey = p.y + (dx! + dy!) * HALF_H - (bridge ? 1 : 0);
      this.poly(ctx, [[p.x - 3, p.y - 1], [p.x + 3, p.y + 2], [ex + 3, ey + 2], [ex - 3, ey - 1]], surface);
    }
    if (bridge) {
      for (let i = -2; i <= 2; i++) this.line(ctx, p.x - 5 + i, p.y + 1 + i, p.x + 5 + i, p.y - 4 + i, '#aa9169');
      this.line(ctx, p.x - 8, p.y - 3, p.x, p.y + 2, '#ede1b5');
      this.line(ctx, p.x, p.y + 2, p.x + 8, p.y - 3, '#786b52');
      this.rect(ctx, p.x - 7, p.y - 4, 1, 5, '#7e7359');
      this.rect(ctx, p.x + 6, p.y - 4, 1, 5, '#7e7359');
    } else if ((cell.x + cell.y) % 3 === 0) {
      this.rect(ctx, p.x - 2, p.y, 2, 1, '#d8cfac');
    }
  }

  private tree(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    const colors = PALETTES[season]!.tree;
    const evergreen = cell.variant % 4 === 0;
    this.diamond(ctx, p.x + 3, p.y + 2, 7, 3, '#738965');
    this.rect(ctx, p.x - 1, p.y - 8, 2, 9, '#6b6246');
    this.rect(ctx, p.x, p.y - 6, 1, 5, '#93815a');
    if (evergreen) {
      this.poly(ctx, [[p.x, p.y - 24], [p.x - 3, p.y - 18], [p.x - 2, p.y - 18], [p.x - 6, p.y - 11], [p.x - 4, p.y - 11], [p.x - 7, p.y - 6], [p.x + 6, p.y - 6], [p.x + 4, p.y - 11], [p.x + 5, p.y - 11], [p.x + 2, p.y - 18]], season === 3 ? '#688677' : '#426c53');
      this.line(ctx, p.x, p.y - 22, p.x - 4, p.y - 12, season === 3 ? '#c2cfc1' : '#739167');
      this.rect(ctx, p.x - 4, p.y - 9, 4, 1, season === 3 ? '#aabbac' : '#66895e');
      return;
    }
    this.poly(ctx, [[p.x - 4, p.y - 19], [p.x + 3, p.y - 20], [p.x + 3, p.y - 18], [p.x + 6, p.y - 18], [p.x + 7, p.y - 13], [p.x + 6, p.y - 9], [p.x + 3, p.y - 7], [p.x - 3, p.y - 7], [p.x - 6, p.y - 10], [p.x - 7, p.y - 14], [p.x - 6, p.y - 17], [p.x - 4, p.y - 17]], colors[0]!);
    this.poly(ctx, [[p.x - 5, p.y - 17], [p.x - 3, p.y - 20], [p.x + 2, p.y - 20], [p.x + 2, p.y - 18], [p.x + 4, p.y - 18], [p.x + 5, p.y - 14], [p.x + 2, p.y - 11], [p.x - 3, p.y - 11], [p.x - 5, p.y - 13]], colors[1]!);
    this.rect(ctx, p.x - 3, p.y - 19, 4, 2, colors[2]!);
    this.rect(ctx, p.x - 5, p.y - 16, 3, 2, colors[2]!);
    this.rect(ctx, p.x + 1, p.y - 16, 2, 1, colors[2]!);
    if (season === 0 && cell.variant % 7 === 0) {
      this.rect(ctx, p.x - 3, p.y - 17, 2, 1, '#eac5b0');
      this.rect(ctx, p.x + 2, p.y - 14, 1, 1, '#f4d9c2');
    }
  }

  private house(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    const level = Math.max(1, Math.min(3, cell.level));
    const height = 8 + level * 3;
    const roof = ['#b97453', '#a75b49', '#747d78', '#b59861'][Math.abs(cell.variant) % 4]!;
    const dark = ['#8e5742', '#824637', '#57635d', '#8b734e'][Math.abs(cell.variant) % 4]!;
    this.shadow(ctx, p);
    this.box(ctx, p, 7, 4, height, '#eddfb7', '#c2b698');
    this.gable(ctx, p, height, roof, dark);
    if (level > 1) {
      this.window(ctx, p.x - 5, p.y - height + 5, 2, 3, cell.variant);
      this.window(ctx, p.x + 3, p.y - height + 4, 2, 3, cell.variant + 1);
    }
    this.window(ctx, p.x - 5, p.y - 4, 2, 3, cell.variant + 2);
    this.rect(ctx, p.x - 1, p.y - 3, 2, 5, '#826e54');
    this.rect(ctx, p.x, p.y - 2, 1, 1, '#d4bc89');
    this.window(ctx, p.x + 3, p.y - 4, 2, 3, cell.variant + 3);
    this.rect(ctx, p.x + 3, p.y - height - 6, 2, 5, '#796c56');
    this.rect(ctx, p.x + 2, p.y - height - 7, 4, 1, '#a99b7d');
    if (level === 1 || cell.variant % 3 === 0) {
      this.rect(ctx, p.x - 7, p.y + 1, 3, 2, season === 3 ? '#adb7a0' : '#577e4c');
      this.rect(ctx, p.x - 6, p.y, 2, 1, season === 2 ? '#caab6d' : '#8fa968');
      this.rect(ctx, p.x - 5, p.y + 1, 1, 1, season === 0 ? '#e9bc98' : '#b9bd7b');
    }
    if (cell.vitality < 35) this.rect(ctx, p.x + 3, p.y - 4, 2, 3, '#968c70');
  }

  private shop(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    const h = 10 + Math.min(3, Math.max(1, cell.level)) * 2;
    this.shadow(ctx, p);
    this.box(ctx, p, 8, 4, h, '#e2d5ad', '#b4b194');
    this.gable(ctx, p, h, '#68858a', '#476970');
    this.window(ctx, p.x + 3, p.y - h + 5, 3, 3, cell.variant);
    this.window(ctx, p.x - 6, p.y - 4, 3, 4, cell.variant + 1);
    this.rect(ctx, p.x - 1, p.y - 3, 2, 5, '#526669');
    // A striped canvas awning and warm wooden shop sign.
    this.poly(ctx, [[p.x - 8, p.y - 8], [p.x, p.y - 3], [p.x, p.y], [p.x - 9, p.y - 5]], '#f1ddb1');
    for (let i = 0; i < 4; i++) this.line(ctx, p.x - 8 + i * 2, p.y - 7 + i, p.x - 8 + i * 2, p.y - 4 + i, cell.variant % 2 ? '#b77356' : '#678b73');
    this.rect(ctx, p.x + 3, p.y - h + 1, 3, 2, '#c6a468');
    this.rect(ctx, p.x + 4, p.y - h + 1, 1, 1, '#f2dfab');
    this.rect(ctx, p.x - 7, p.y + 1, 2, 2, '#8c7558');
    this.rect(ctx, p.x - 7, p.y, 2, 1, season === 2 ? '#d2ae65' : '#a4b46e');
  }

  private farm(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    this.diamond(ctx, p.x, p.y, 8, 4, '#977d57');
    const crop = cell.vitality < 35 ? '#ab9a6e' : PALETTES[season]!.crop;
    for (let i = -2; i <= 2; i++) {
      this.line(ctx, p.x - 5 + i * 2, p.y - 2 + i, p.x + i * 2, p.y + 1 + i, '#c1a271');
      if (season !== 3 || i % 2 === 0) {
        for (let j = 0; j < 3; j++) {
          this.rect(ctx, p.x - 5 + i * 2 + j * 2, p.y - 3 + i + j, 1, 2, crop);
          if (season === 1 || season === 2) this.rect(ctx, p.x - 5 + i * 2 + j * 2, p.y - 3 + i + j, 1, 1, '#d8c07b');
        }
      }
    }
    this.line(ctx, p.x - 8, p.y, p.x, p.y + 5, '#d5c79f');
    this.rect(ctx, p.x - 7, p.y - 1, 1, 3, '#a09069');
    this.rect(ctx, p.x - 1, p.y + 2, 1, 3, '#a09069');
  }

  private factory(ctx: CanvasRenderingContext2D, cell: Cell, p: Point): void {
    const h = 10 + Math.min(3, Math.max(1, cell.level)) * 2;
    this.shadow(ctx, p);
    this.box(ctx, p, 8, 4, h, '#baae91', '#928b7a');
    this.diamond(ctx, p.x, p.y - h, 9, 5, '#718382');
    this.line(ctx, p.x - 7, p.y - h, p.x, p.y - h + 4, '#93a09a');
    this.window(ctx, p.x - 6, p.y - 6, 2, 3, cell.variant);
    this.window(ctx, p.x - 3, p.y - 4, 2, 3, cell.variant + 1);
    this.rect(ctx, p.x + 2, p.y - 6, 4, 7, '#636d66');
    this.line(ctx, p.x + 2, p.y - 3, p.x + 5, p.y - 4, '#9a9d82');
    this.rect(ctx, p.x + 3, p.y - h - 11, 3, 13, '#957f6c');
    this.rect(ctx, p.x + 5, p.y - h - 11, 1, 13, '#766a5d');
    this.rect(ctx, p.x + 2, p.y - h - 12, 5, 2, '#b4a28a');
    this.rect(ctx, p.x - 7, p.y + 1, 3, 2, '#8b8065');
    this.rect(ctx, p.x - 7, p.y, 2, 1, '#c1ae86');
  }

  private ruin(ctx: CanvasRenderingContext2D, cell: Cell, p: Point): void {
    this.shadow(ctx, p);
    this.diamond(ctx, p.x, p.y, 7, 4, '#b2ad88');
    this.poly(ctx, [[p.x - 6, p.y - 9], [p.x - 3, p.y - 7], [p.x - 3, p.y - 4], [p.x - 1, p.y - 4], [p.x - 1, p.y + 3], [p.x - 6, p.y]], '#bdb492');
    this.poly(ctx, [[p.x + 2, p.y - 5], [p.x + 6, p.y - 8], [p.x + 6, p.y], [p.x + 2, p.y + 2]], '#938e74');
    this.rect(ctx, p.x - 5, p.y - 6, 2, 3, '#6a7462');
    this.rect(ctx, p.x + 1, p.y, 3, 2, '#92866c');
    this.rect(ctx, p.x - 2, p.y - 1, 3, 1, '#a07556');
    this.rect(ctx, p.x - 7, p.y, 2, 3, '#66804d');
    this.rect(ctx, p.x + 4, p.y - 3, 2, 2, '#7b935d');
    if (cell.age > 10) this.rect(ctx, p.x, p.y + 2, 3, 1, '#73945d');
  }

  private park(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    this.diamond(ctx, p.x, p.y, 8, 4, '#a8b784');
    this.line(ctx, p.x - 6, p.y, p.x + 5, p.y, '#d4c9a0');
    this.tree(ctx, { ...cell, variant: cell.variant + 1 }, { x: p.x - 3, y: p.y - 1 }, season);
    this.rect(ctx, p.x + 3, p.y, 4, 1, '#a58a61');
    this.rect(ctx, p.x + 3, p.y - 2, 4, 1, '#c3a97e');
    this.rect(ctx, p.x + 3, p.y + 1, 1, 2, '#6c7155');
    this.rect(ctx, p.x + 6, p.y + 1, 1, 2, '#6c7155');
    this.rect(ctx, p.x - 5, p.y + 2, 1, 1, '#e2c9a2');
  }

  private shed(ctx: CanvasRenderingContext2D, cell: Cell, p: Point): void {
    this.box(ctx, p, 3, 2, 4, '#b29567', '#8e7b55');
    this.diamond(ctx, p.x, p.y - 4, 4, 2, '#88715b');
    this.rect(ctx, p.x, p.y - 2, 1, 3, '#716a4d');
    if (cell.level > 1) this.rect(ctx, p.x + 2, p.y, 1, 1, '#bdb27b');
  }

  private drawLife(ctx: CanvasRenderingContext2D, world: World, time: number): void {
    const waveStep = Math.floor(time * 2);
    for (const cell of this.waters) {
      if (this.hash(cell.x, cell.y, world.seed) % 29 !== 0 || cell.kind === 'road') continue;
      const p = this.project(cell, world);
      const offset = ((waveStep + cell.x) % 5) - 2;
      this.rect(ctx, p.x - 2 + offset, p.y, 3, 1, '#a3ced0');
      this.rect(ctx, p.x + 1 + offset, p.y + 1, 2, 1, '#88bec4');
    }
    for (const cell of this.factories) {
      const p = this.project(cell, world);
      const h = 10 + Math.min(3, Math.max(1, cell.level)) * 2;
      for (let i = 0; i < 3; i++) {
        const drift = (time * 2.3 + i * 5 + cell.variant % 7) % 16;
        const x = Math.round(p.x + 4 + drift * 0.35);
        const y = Math.round(p.y - h - 13 - drift);
        ctx.globalAlpha = (1 - drift / 18) * 0.65;
        this.rect(ctx, x, y, 3 + Math.floor(drift / 5), 2, '#e0ded0');
        this.rect(ctx, x + 1, y - 1, 2, 1, '#d2d5c6');
      }
    }
    ctx.globalAlpha = 1;
    // Each pedestrian traverses one existing road edge, then turns back. Every
    // intermediate position is inside those two connected road diamonds.
    const stride = Math.max(1, Math.floor(this.roads.length / 20));
    for (let index = 0; index < this.roads.length; index += stride) {
      const cell = this.roads[index]!;
      const directions = [[1, 0], [0, 1], [-1, 0], [0, -1]];
      let neighbor: Cell | undefined;
      for (let d = 0; d < 4; d++) {
        const dir = directions[(d + index) % 4]!;
        const candidate = this.at(world, cell.x + dir[0]!, cell.y + dir[1]!);
        if (candidate?.kind === 'road') { neighbor = candidate; break; }
      }
      if (!neighbor) continue;
      const a = this.project(cell, world);
      const b = this.project(neighbor, world);
      const phase = ((time / 5 + index * 0.137) % 2);
      const t = phase <= 1 ? phase : 2 - phase;
      const x = Math.round(a.x + (b.x - a.x) * t);
      const y = Math.round(a.y + (b.y - a.y) * t) - (cell.terrain === 'water' ? 1 : 0);
      this.rect(ctx, x, y - 4, 1, 1, '#e7c79a');
      this.rect(ctx, x - 1, y - 3, 2, 2, ['#a25b48', '#eee1b4', '#486c79', '#70617d'][index % 4]!);
      this.rect(ctx, x - 1, y - 1, 1, 1, '#535d51');
      this.rect(ctx, x + (Math.floor(time * 4) % 2), y, 1, 1, '#535d51');
    }
  }

  private spriteHeight(cell: Cell): number {
    switch (cell.kind) {
      case 'tree': case 'park': return 24;
      case 'house': return 17 + Math.max(1, Math.min(3, cell.level)) * 3;
      case 'shop': return 17 + Math.max(1, Math.min(3, cell.level)) * 2;
      case 'factory': return 22 + Math.max(1, Math.min(3, cell.level)) * 2;
      case 'ruin': return 10;
      default: return 0;
    }
  }

  private at(world: World, x: number, y: number): Cell | undefined {
    if (x < 0 || y < 0 || x >= world.size || y >= world.size) return undefined;
    return world.cells[y * world.size + x];
  }
  private hash(x: number, y: number, seed: number): number {
    let n = Math.imul(x + 37, 374761393) ^ Math.imul(y + 19, 668265263) ^ seed;
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return (n ^ (n >>> 16)) >>> 0;
  }
  private shadow(ctx: CanvasRenderingContext2D, p: Point): void {
    this.diamond(ctx, p.x + 3, p.y + 2, 9, 4, '#74886b');
  }
  private box(ctx: CanvasRenderingContext2D, p: Point, w: number, d: number, h: number, left: string, right: string): void {
    this.poly(ctx, [[p.x - w, p.y - h], [p.x, p.y + d - h], [p.x, p.y + d], [p.x - w, p.y]], left);
    this.poly(ctx, [[p.x, p.y + d - h], [p.x + w, p.y - h], [p.x + w, p.y], [p.x, p.y + d]], right);
    this.line(ctx, p.x - w, p.y, p.x, p.y + d, '#a29c7f');
    this.line(ctx, p.x, p.y + d, p.x + w, p.y, '#7b826b');
  }
  private gable(ctx: CanvasRenderingContext2D, p: Point, h: number, color: string, dark: string): void {
    this.poly(ctx, [[p.x - 8, p.y - h], [p.x - 4, p.y - h - 7], [p.x + 4, p.y - h - 2], [p.x, p.y - h + 5]], color);
    this.poly(ctx, [[p.x - 4, p.y - h - 7], [p.x, p.y - h - 5], [p.x + 8, p.y - h], [p.x + 4, p.y - h - 2]], dark);
    this.poly(ctx, [[p.x, p.y - h + 5], [p.x + 4, p.y - h - 2], [p.x + 8, p.y - h]], '#d7cba7');
    this.line(ctx, p.x - 4, p.y - h - 7, p.x + 4, p.y - h - 2, '#d7ac7c');
    this.line(ctx, p.x - 8, p.y - h, p.x, p.y - h + 5, dark);
    this.line(ctx, p.x + 4, p.y - h - 2, p.x + 8, p.y - h, dark);
    this.rect(ctx, p.x + 4, p.y - h + 1, 1, 2, '#867c66');
    this.line(ctx, p.x - 6, p.y - h - 1, p.x + 1, p.y - h + 3, color === '#68858a' ? '#7d9695' : '#ca9169');
  }
  private window(ctx: CanvasRenderingContext2D, x: number, y: number, width: number, height: number, seed: number): void {
    this.rect(ctx, x - 1, y - 1, width + 2, height + 2, '#a59778');
    this.rect(ctx, x, y, width, height, '#6e8a87');
    this.rect(ctx, x, y, width, 1, '#aec0a9');
    this.windows.push({ x, y, width, height, seed });
  }
  private rect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string): void {
    ctx.fillStyle = color;
    ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
  }
  private diamond(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string): void {
    this.poly(ctx, [[x, y - h], [x + w, y], [x, y + h], [x - w, y]], color);
  }
  private outlineDiamond(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string): void {
    this.line(ctx, x, y - h, x + w, y, color);
    this.line(ctx, x + w, y, x, y + h, color);
    this.line(ctx, x, y + h, x - w, y, color);
    this.line(ctx, x - w, y, x, y - h, color);
  }
  private poly(ctx: CanvasRenderingContext2D, points: readonly Vertex[], color: string): void {
    ctx.fillStyle = color;
    let minY = Infinity;
    let maxY = -Infinity;
    for (const p of points) { minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]); }
    for (let y = Math.floor(minY); y < Math.ceil(maxY); y++) {
      const xs: number[] = [];
      const scan = y + 0.5;
      for (let i = 0; i < points.length; i++) {
        const a = points[i]!;
        const b = points[(i + 1) % points.length]!;
        if ((a[1] <= scan && b[1] > scan) || (b[1] <= scan && a[1] > scan)) {
          xs.push(a[0] + (scan - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
        }
      }
      xs.sort((a, b) => a - b);
      for (let i = 0; i + 1 < xs.length; i += 2) {
        const start = Math.round(xs[i]!);
        const end = Math.round(xs[i + 1]!);
        if (end > start) ctx.fillRect(start, y, end - start, 1);
      }
    }
  }
  private line(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, color: string): void {
    ctx.fillStyle = color;
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0);
    const sx = x0 < x1 ? 1 : -1;
    const dy = -Math.abs(y1 - y0);
    const sy = y0 < y1 ? 1 : -1;
    let error = dx + dy;
    for (;;) {
      ctx.fillRect(x0, y0, 1, 1);
      if (x0 === x1 && y0 === y1) break;
      const twice = error * 2;
      if (twice >= dy) { error += dy; x0 += sx; }
      if (twice <= dx) { error += dx; y0 += sy; }
    }
  }
}
