import type { Camera, Cell, Point, RenderOptions, Resident, World } from './types';

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
  { grass: ['#91b77a', '#94b97c', '#8eb478', '#98bb80'], tree: ['#4d977d', '#80bd8b', '#b8dca2'], flower: '#f2d3ba', crop: '#97b65f' },
  { grass: ['#88a972', '#8aad74', '#84a66d', '#8ead77'], tree: ['#468d75', '#6db784', '#a5d59b'], flower: '#f2dfa5', crop: '#a7b66a' },
  { grass: ['#a5ad76', '#a9af7a', '#a1a871', '#adb47d'], tree: ['#b08066', '#dfaa77', '#f2cb96'], flower: '#d9b276', crop: '#c3a369' },
  { grass: ['#b6c3ac', '#bac7b1', '#b2bfa8', '#bdc9b6'], tree: ['#759c93', '#a9c4b0', '#e1e9d7'], flower: '#e8e6d7', crop: '#a6ab83' },
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
  private palette = PALETTES[0]!;
  private windows: WindowLight[] = [];
  private shapes: HitShape[] = [];
  private depthPixels = new Float32Array(CANVAS_WIDTH * CANVAS_HEIGHT);
  private readonly sprite = document.createElement('canvas');
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
    const key = `${world.seed}:${world.tick}:${world.size}:${world.weather.kind}`;
    if (this.cachedWorld !== world || key !== this.cacheKey) {
      this.cacheKey = key;
      this.cachedWorld = world;
      this.buildScene(world);
    }
    const ctx = this.ctx;
    const { camera, selected } = options;
    // The day starts in morning light. Darkness is tied to the simulation clock,
    // so pausing also freezes this small observational day/night cycle.
    const phase = (world.clock % 150) / 150;
    const night = Math.max(0, -Math.cos((phase - .15) * Math.PI * 2)) * 0.49;
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
    this.drawLife(ctx, world, options);
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
    this.depthPixels.fill(-Infinity);
    this.windows = [];
    this.shapes = [];
    this.roads = [];
    this.waters = [];
    this.factories = [];
    const season = Math.floor(world.tick / 12) % 4;
    const amount = Math.min(1, (world.tick % 12) / 4);
    const from = PALETTES[(season + 3) % 4]!, to = PALETTES[season]!;
    const blend = (a: string, b: string): string => {
      const left = Number.parseInt(a.slice(1), 16), right = Number.parseInt(b.slice(1), 16);
      const channels = [16, 8, 0].map(shift => Math.round(((left >> shift) & 255) * (1 - amount) + ((right >> shift) & 255) * amount));
      return '#' + channels.map(value => value.toString(16).padStart(2, '0')).join('');
    };
    this.palette = { grass: from.grass.map((color, i) => blend(color, to.grass[i]!)), tree: from.tree.map((color, i) => blend(color, to.tree[i]!)), flower: blend(from.flower, to.flower), crop: blend(from.crop, to.crop) };
    const palette = this.palette;
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
      this.diamond(ctx, p.x, p.y, HALF_W, HALF_H, isWater ? world.weather.temperature < 0 ? '#bbd4d0' : world.weather.rainfall > 50 ? '#739daa' : ['#73b8c2', '#79bdc4', '#70b3be'][hash % 3]! : cell.vegetation < 22 ? '#c3b991' : cell.moisture > 70 ? '#87b799' : palette.grass[hash % 4]!);
      if (isWater) {
        this.waters.push(cell);
        this.shore(ctx, cell, world, p);
        if (hash % 5 === 0) this.rect(ctx, p.x - 3, p.y, 4, 1, world.weather.temperature < 0 ? '#e3e9db' : '#a1d1d1');
      } else {
        if (hash % 4 === 0) {
          this.rect(ctx, p.x - 4, p.y, 2, 1, season === 3 ? '#cdd5c4' : '#779968');
          this.rect(ctx, p.x - 3, p.y - 1, 1, 1, season === 3 ? '#cdd5c4' : '#779968');
        }
        if (cell.kind === 'grass' && cell.vegetation > 45 && hash % 11 === 0) {
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
        if ((cell.kind === 'grass' && cell.development <= 25) || ['water', 'road'].includes(cell.kind) || (cell.kind === 'farm' && cell.variant % 5 !== 0)) continue;
        this.sprite.width = 32;
        this.sprite.height = 48;
        const spriteCtx = this.sprite.getContext('2d')!;
        spriteCtx.translate(16 - p.x, 40 - p.y);
        switch (cell.kind) {
          case 'grass': if (cell.development > 25) this.construction(spriteCtx, cell, p); break;
          case 'tree': this.tree(spriteCtx, cell, p, season); break;
          case 'house': this.house(spriteCtx, cell, p, season); break;
          case 'shop': this.shop(spriteCtx, cell, p, season); break;
          case 'factory': this.factory(spriteCtx, cell, p); this.factories.push(cell); break;
          case 'ruin': this.ruin(spriteCtx, cell, p); break;
          case 'park': this.park(spriteCtx, cell, p, season); break;
          case 'farm': if (cell.variant % 5 === 0) this.shed(spriteCtx, cell, { x: p.x + 3, y: p.y - 1 }); break;
        }
        if (world.weather.kind === 'snow' && ['house', 'shop', 'factory'].includes(cell.kind)) {
          this.line(spriteCtx, p.x - 5, p.y - this.spriteHeight(cell) + 2, p.x + 3, p.y - this.spriteHeight(cell) + 7, '#f3eee2');
        }
        ctx.drawImage(this.sprite, p.x - 16, p.y - 40);
        const ink = spriteCtx.getImageData(0, 0, 32, 48).data;
        for (let sy = 0; sy < 48; sy++) for (let sx = 0; sx < 32; sx++) {
          if (!ink[(sy * 32 + sx) * 4 + 3]) continue;
          const px = p.x - 16 + sx, py = p.y - 40 + sy;
          if (px >= 0 && py >= 0 && px < this.width && py < this.height) this.depthPixels[py * this.width + px] = depth;
        }
        if (['tree', 'house', 'shop', 'factory', 'ruin', 'park'].includes(cell.kind) || (cell.kind === 'grass' && cell.development > 25)) {
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
    const colors = this.palette.tree;
    if (cell.age < 8 || cell.vegetation < 30) {
      this.rect(ctx, p.x, p.y - 5, 1, 6, '#9a8061');
      this.rect(ctx, p.x - 3, p.y - 7, 6, 3, colors[1]!);
      this.rect(ctx, p.x - 2, p.y - 8, 4, 1, colors[2]!);
      this.rect(ctx, p.x - 2, p.y - 5, 4, 1, colors[0]!);
      return;
    }
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
    const blossom = season === 0 && cell.variant % 4 === 1;
    const crown = blossom ? ['#c689a2', '#e5b0c0', '#f8d7dd'] : colors;
    // Three overlapping stepped lobes, with a short clear trunk below them.
    this.rect(ctx, p.x - 5, p.y - 15, 10, 7, crown[0]!);
    this.rect(ctx, p.x - 7, p.y - 13, 14, 4, crown[0]!);
    this.rect(ctx, p.x - 4, p.y - 18, 8, 10, crown[0]!);
    this.rect(ctx, p.x - 6, p.y - 15, 11, 5, crown[1]!);
    this.rect(ctx, p.x - 3, p.y - 19, 6, 8, crown[1]!);
    this.rect(ctx, p.x - 5, p.y - 16, 4, 3, crown[2]!);
    this.rect(ctx, p.x - 2, p.y - 19, 4, 2, crown[2]!);
    this.rect(ctx, p.x + 2, p.y - 15, 2, 2, crown[2]!);
    if (blossom) {
      this.rect(ctx, p.x - 3, p.y - 12, 1, 1, '#fff0dc');
      this.rect(ctx, p.x + 3, p.y - 16, 1, 1, '#fff0dc');
    }
  }

  private house(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    const level = Math.max(1, Math.min(3, cell.level));
    const height = 8 + level * 3;
    const roof = ['#d98e82', '#8baaba', '#aa9abd', '#d8b676'][Math.abs(cell.variant) % 4]!;
    const dark = ['#ad706b', '#657e98', '#7c7097', '#aa895c'][Math.abs(cell.variant) % 4]!;
    this.shadow(ctx, p);
    this.line(ctx, p.x - 9, p.y + 1, p.x - 2, p.y + 5, '#eee2c1');
    for (let i = 0; i < 3; i++) this.rect(ctx, p.x - 9 + i * 3, p.y + i, 1, 4, '#f0e6cd');
    this.box(ctx, p, 7, 4, height, ['#f4e5c6', '#eadbcf', '#e6ead5', '#f1d8c6'][cell.variant % 4]!, ['#d3bea9', '#c3b1ba', '#becbb2', '#d1b2a8'][cell.variant % 4]!);
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
    this.rect(ctx, p.x + 2, p.y - 1, 4, 1, '#c48c75');
    this.rect(ctx, p.x + 2, p.y - 2, 4, 1, '#7aab83');
    this.rect(ctx, p.x + 3, p.y - 3, 1, 1, '#f2b5aa');
    if (cell.vitality < 35) this.rect(ctx, p.x + 3, p.y - 4, 2, 3, '#968c70');
  }

  private shop(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    const h = 10 + Math.min(3, Math.max(1, cell.level)) * 2;
    this.shadow(ctx, p);
    this.box(ctx, p, 8, 4, h, '#f0dcbd', '#b4b194');
    this.gable(ctx, p, h, '#68858a', '#476970');
    this.window(ctx, p.x + 3, p.y - h + 5, 3, 3, cell.variant);
    this.window(ctx, p.x - 6, p.y - 4, 3, 4, cell.variant + 1);
    this.rect(ctx, p.x - 1, p.y - 3, 2, 5, '#526669');
    // A striped canvas awning and warm wooden shop sign.
    this.poly(ctx, [[p.x - 8, p.y - 8], [p.x, p.y - 3], [p.x, p.y], [p.x - 9, p.y - 5]], '#f1ddb1');
    for (let i = 0; i < 4; i++) this.line(ctx, p.x - 8 + i * 2, p.y - 7 + i, p.x - 8 + i * 2, p.y - 4 + i, cell.variant % 2 ? '#b77356' : '#678b73');
    this.rect(ctx, p.x + 3, p.y - h + 1, 3, 2, '#c6a468');
    this.rect(ctx, p.x + 4, p.y - h + 1, 1, 1, '#f2dfab');
    this.rect(ctx, p.x - 9, p.y + 2, 3, 4, '#647e83');
    this.rect(ctx, p.x - 8, p.y + 3, 1, 2, '#f5d69c');
    if (cell.customers > 0) this.rect(ctx, p.x + 5, p.y + 1, 2, 2, '#ecaa79');
    this.rect(ctx, p.x - 7, p.y + 1, 2, 2, '#8c7558');
    this.rect(ctx, p.x - 7, p.y, 2, 1, season === 2 ? '#d2ae65' : '#a4b46e');
  }

  private farm(ctx: CanvasRenderingContext2D, cell: Cell, p: Point, season: number): void {
    this.diamond(ctx, p.x, p.y, 8, 4, cell.moisture > 55 ? '#876d59' : '#b79973');
    const growth = Math.max(0, Math.min(100, cell.crop));
    const crop = cell.fertility < 25 ? '#b5a576' : growth > 75 ? '#dfc57e' : this.palette.crop;
    for (let i = -2; i <= 2; i++) {
      this.line(ctx, p.x - 5 + i * 2, p.y - 2 + i, p.x + i * 2, p.y + 1 + i, '#c1a271');
      if (growth > 8 && (season !== 3 || i % 2 === 0)) {
        for (let j = 0; j < 3; j++) {
          this.rect(ctx, p.x - 5 + i * 2 + j * 2, p.y - 2 - Math.floor(growth / 35) + i + j, growth > 40 ? 2 : 1, 1 + Math.floor(growth / 35), crop);
          if (growth > 75) this.rect(ctx, p.x - 5 + i * 2 + j * 2, p.y - 3 + i + j, 1, 1, '#d8c07b');
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

  private drawLife(ctx: CanvasRenderingContext2D, world: World, options: RenderOptions): void {
    const time = options.reducedMotion ? 0 : world.clock;
    const waveStep = Math.floor(time * 2);
    for (const cell of this.waters) {
      if (world.weather.temperature < 0 || this.hash(cell.x, cell.y, world.seed) % 29 !== 0 || cell.kind === 'road') continue;
      const p = this.project(cell, world);
      const offset = ((waveStep + cell.x) % 5) - 2;
      this.rect(ctx, p.x - 2 + offset, p.y, 3, 1, '#a3ced0');
      this.rect(ctx, p.x + 1 + offset, p.y + 1, 2, 1, '#88bec4');
    }
    for (const cell of this.factories) {
      if (cell.employed === 0 || options.reducedMotion) continue;
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
    const residents = world.residents.filter(r => r.state === 'travel' || r.state === 'park').sort((a, b) => a.x + a.y - b.x - b.y);
    const followed = world.residents.find(r => r.id === options.followedResident);
    if (options.showRoutes) {
      const home = options.selected ? options.selected.y * world.size + options.selected.x : null;
      const routes = followed ? [followed] : home !== null ? world.residents.filter(r => r.home === home).slice(0, 6) : residents.slice(0, 8);
      if (!followed && home === null) {
        for (const road of this.roads) {
          const p = this.project(road, world);
          this.rect(ctx, p.x, p.y, 1, 1, '#e5dab0');
        }
      }
      for (const resident of routes) for (let i = 1; i < resident.route.length; i++) {
        const a = world.cells[resident.route[i - 1]!]!, b = world.cells[resident.route[i]!]!;
        if (!a || !b) continue;
        const pa = this.project(a, world), pb = this.project(b, world);
        this.line(ctx, pa.x, pa.y, pb.x, pb.y, followed ? '#f4d584' : '#d5d5aa');
      }
    }
    for (const resident of residents) this.person(ctx, resident, world, options);
    if (world.weather.kind !== 'clear' && !options.reducedMotion) {
      for (let i = 0; i < 60; i++) {
        const x = this.hash(i, 21, world.seed) % this.width;
        const y = (this.hash(i, 35, world.seed) + Math.floor(world.clock * (world.weather.kind === 'snow' ? 9 : 40))) % this.height;
        if (world.weather.kind === 'snow') this.rect(ctx, x, y, 2, 2, '#f5f1e7');
        else this.line(ctx, x, y, x - 1, y + 3, '#a6cad1');
      }
    }
  }

  private person(ctx: CanvasRenderingContext2D, resident: Resident, world: World, options: RenderOptions): void {
    const p = this.project(resident, world);
    const x = Math.round(p.x), y = Math.round(p.y);
    // Pixel-level painter mask retains every foreground leaf/roof edge while
    // residents move continuously between tile centers. Only a 16x16 sprite is scanned.
    const sprite = this.sprite;
    sprite.width = 16; sprite.height = 16;
    const ink = sprite.getContext('2d')!;
    const step = options.reducedMotion ? 0 : Math.floor(world.clock * 7 + resident.id) % 2;
    const clothes = ['#e9998b', '#699eba', '#e2bb62', '#a397c4', '#73ad95'][resident.color % 5]!;
    const next = world.cells[resident.route[resident.routeIndex + 1] ?? -1];
    const facing = next ? Math.sign((next.x - resident.x) - (next.y - resident.y)) : 1;
    this.rect(ink, 6, 12, 5, 1, '#758d78');
    this.rect(ink, 6, 10 + step, 2, 2, '#545c70');
    this.rect(ink, 9, 11 - step, 2, 2, '#545c70');
    this.rect(ink, 6, 6, 5, 5, clothes);
    this.rect(ink, 5, 7 + step, 1, 3, '#efc5a2');
    this.rect(ink, 11, 7 - step, 1, 3, '#efc5a2');
    this.rect(ink, 6, 2, 5, 5, '#f3cfab');
    this.rect(ink, 6, 1, 5, 2, '#766452');
    this.rect(ink, facing < 0 ? 6 : 10, 4, 1, 1, '#5c5354');
    this.rect(ink, facing < 0 ? 5 : 11, 5, 1, 1, '#eba69a');
    if (resident.id % 3 === 0) {
      this.rect(ink, 6, 0, 5, 2, '#e9ce89');
      this.rect(ink, 5, 2, 7, 1, '#cda76d');
    }
    if (resident.purpose === 'shopping') {
      this.rect(ink, facing < 0 ? 4 : 11, 9, 3, 3, '#dfb879');
      this.rect(ink, facing < 0 ? 5 : 12, 8, 1, 1, '#8b705a');
    } else if (resident.purpose === 'commute') this.rect(ink, facing < 0 ? 10 : 5, 7, 2, 4, '#718192');
    const data = ink.getImageData(0, 0, 16, 16);
    for (let py = 0; py < 16; py++) for (let px = 0; px < 16; px++) {
      const wx = x - 8 + px, wy = y - 12 + py;
      if (wx >= 0 && wy >= 0 && wx < this.width && wy < this.height && this.depthPixels[wy * this.width + wx]! > resident.x + resident.y + 0.2) data.data[(py * 16 + px) * 4 + 3] = 0;
    }
    ink.putImageData(data, 0, 0);
    ctx.drawImage(sprite, x - 8, y - 12);
    if (options.followedResident === resident.id) {
      this.outlineDiamond(ctx, x, y + 2, 5, 2, '#fff0a7');
      this.rect(ctx, x - 1, y - 17, 3, 2, '#fff0a7');
      this.rect(ctx, x, y - 15, 1, 2, '#fff0a7');
    }
  }

  pickResident(clientX: number, clientY: number, world: World, camera: Camera): number | null {
    const bounds = this.canvas.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0 || clientX < bounds.left || clientY < bounds.top || clientX > bounds.right || clientY > bounds.bottom) return null;
    const x = ((clientX - bounds.left) * this.width / bounds.width - CENTER_X - camera.panX) / camera.zoom + CENTER_X;
    const y = ((clientY - bounds.top) * this.height / bounds.height - CENTER_Y - camera.panY) / camera.zoom + CENTER_Y;
    for (const resident of [...world.residents].reverse()) {
      if (resident.state !== 'travel' && resident.state !== 'park') continue;
      const p = this.project(resident, world);
      if (Math.abs(x - p.x) <= 6 && y >= p.y - 13 && y <= p.y + 2) {
        const px = Math.round(x), py = Math.round(y);
        if (px >= 0 && py >= 0 && px < this.width && py < this.height && this.depthPixels[py * this.width + px]! <= resident.x + resident.y + 0.2) return resident.id;
      }
    }
    return null;
  }

  private construction(ctx: CanvasRenderingContext2D, cell: Cell, p: Point): void {
    const h = 3 + Math.floor(cell.development / 8);
    this.diamond(ctx, p.x, p.y, 7, 4, '#d4bba0');
    this.box(ctx, p, 6, 3, h, '#edcfb0', '#c5aa91');
    for (const dx of [-7, 0, 7]) {
      this.rect(ctx, p.x + dx, p.y - h - 6, 1, h + 8, '#aa8c69');
    }
    this.line(ctx, p.x - 7, p.y - h - 5, p.x, p.y - h - 1, '#e8c9a2');
    this.line(ctx, p.x, p.y - h - 1, p.x + 7, p.y - h - 5, '#c5a37c');
    this.rect(ctx, p.x - 5, p.y + 1, 3, 2, '#c48e78');
  }

  private spriteHeight(cell: Cell): number {
    switch (cell.kind) {
      case 'grass': return cell.development > 25 ? 9 + Math.floor(cell.development / 8) : 0;
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
