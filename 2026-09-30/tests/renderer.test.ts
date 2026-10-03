import assert from 'node:assert/strict';
import test from 'node:test';
import { TownRenderer, CANVAS_WIDTH, CANVAS_HEIGHT } from '../src/renderer.ts';
import { createWorld } from '../src/simulation.ts';
import { DAY_SECONDS } from '../src/constants.ts';
import { walkingSpeed } from '../src/mobility.ts';
import type { Camera, Point, RenderOptions } from '../src/types.ts';

interface PixelCall { surface: string; color: string; alpha: number; x: number; y: number; width: number; height: number }
interface ImageCall { surface: string; width: number; height: number; x: number; y: number }

function setup() {
  const box = { left: 40, top: 80, width: 720, height: 480 };
  const pixels: PixelCall[] = [], clears: string[] = [];
  const images: ImageCall[] = [];
  const makeContext = (surface: string) => ({
    fillStyle: '', globalAlpha: 1,
    clearRect() { clears.push(surface); },
    fillRect(x: number, y: number, width: number, height: number) { pixels.push({ surface, color: this.fillStyle, alpha: this.globalAlpha, x, y, width, height }); },
    save() {}, restore() {}, translate() {}, scale() {},
    drawImage(source: { width?: number; height?: number }, x: number, y: number) { images.push({ surface, width: source.width ?? 0, height: source.height ?? 0, x, y }); },
    setTransform() {}, putImageData() {},
    getImageData: (_x: number, _y: number, width: number, height: number) => ({ data: new Uint8ClampedArray(width * height * 4) }),
  });
  const context = makeContext('main');
  const canvas = { style: {}, getContext: () => context, getBoundingClientRect: () => box };
  let surface = 0;
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'document');
  Object.defineProperty(globalThis, 'document', { configurable: true, value: { createElement: () => { const context = makeContext(`offscreen-${surface++}`); return { getContext: () => context }; } } });
  const renderer = new TownRenderer(canvas as unknown as HTMLCanvasElement);
  if (previous) Object.defineProperty(globalThis, 'document', previous);
  else Reflect.deleteProperty(globalThis, 'document');
  const world = createWorld(42);
  const screen = (point: Point, camera: Camera, lift = 0) => {
    const logicalX = 480 + (point.x - point.y) * 9;
    const logicalY = 82 + (point.x + point.y) * 5 - lift;
    return {
      x: box.left + (480 + camera.panX + (logicalX - 480) * camera.zoom) * box.width / CANVAS_WIDTH,
      y: box.top + (320 + camera.panY + (logicalY - 320) * camera.zoom) * box.height / CANVAS_HEIGHT,
    };
  };
  const options: RenderOptions = { camera: { zoom: 1, panX: 0, panY: 0 }, selected: null, time: 0, reducedMotion: true };
  return { renderer, world, screen, pixels, clears, options, images };
}

test('tile picking converts CSS size, viewport offset, pan and zoom', () => {
  const { renderer, world, screen } = setup();
  for (const camera of [{ zoom: 1, panX: 0, panY: 0 }, { zoom: .75, panX: 13, panY: -25 }, { zoom: 3, panX: -80, panY: 20 }]) {
    for (const point of [{ x: 24, y: 24 }, { x: 20, y: 26 }, { x: 25, y: 20 }]) {
      const p = screen(point, camera);
      assert.deepEqual(renderer.pick(p.x, p.y, world, camera), point);
    }
  }
});

test('margin and coordinates outside the canvas do not select land', () => {
  const { renderer, world } = setup();
  const camera = { zoom: 1, panX: 0, panY: 0 };
  assert.equal(renderer.pick(41, 81, world, camera), null);
  assert.equal(renderer.pick(0, 0, world, camera), null);
  assert.equal(renderer.pick(800, 600, world, camera), null);
});

test('focus centers the chosen location at every supported zoom', () => {
  const { renderer, world, screen } = setup();
  for (const zoom of [.75, 1, 3]) {
    const point = { x: 10, y: 34 };
    const camera = renderer.focus(point, world, { zoom, panX: 17, panY: 23 });
    const p = screen(point, camera);
    assert.equal(camera.zoom, zoom);
    assert.equal(p.x, 400);
    assert.equal(p.y, 320 + 10 * zoom * .75);
    assert.deepEqual(renderer.pick(p.x, p.y, world, camera), point);
  }
});

test('an elevated roof click selects its building rather than the tile behind', () => {
  const { renderer, world, screen } = setup();
  for (const cell of world.cells) { cell.kind = 'grass'; cell.terrain = 'land'; }
  const point = { x: 24, y: 24 };
  const house = world.cells[point.y * world.size + point.x]!;
  house.kind = 'house';
  house.level = 3;
  const camera = { zoom: 1.5, panX: 0, panY: 0 };
  renderer.render(world, { camera, selected: null, time: 0, reducedMotion: true });
  const p = screen(point, camera, 19);
  assert.deepEqual(renderer.pick(p.x, p.y, world, camera), point);
});

test('same-tick interventions invalidate the cached base while observational frames reuse it', () => {
  const { renderer, world, options, clears } = setup();
  renderer.render(world, options);
  assert.equal(clears.length, 1);
  world.clock += .25;
  renderer.render(world, options);
  assert.equal(clears.length, 1, 'animation alone must not rasterize every building again');
  world.cells[24 * world.size + 24]!.waterDepth = 2;
  world.revision++;
  renderer.render(world, options);
  assert.equal(clears.length, 2, 'a change with no calendar tick must be visible');
  world.cells[24 * world.size + 24]!.fire = 40;
  world.revision++;
  renderer.render(world, options);
  assert.equal(clears.length, 2, 'dynamic flames do not require rasterizing unchanged building pixels');
  world.cells[24 * world.size + 24]!.waterDepth = 2.01;
  world.revision++;
  renderer.render(world, options);
  assert.equal(clears.length, 2, 'subpixel flood changes reuse the integer-pixel base');
});

test('day and seasonal visuals use the shared clock instead of the legacy tick', () => {
  const { renderer, world, options, pixels, clears } = setup();
  world.clock = DAY_SECONDS * .65;
  renderer.render(world, options);
  const night = pixels.find(pixel => pixel.surface === 'main' && pixel.color.startsWith('rgba(22, 40, 60'));
  assert.ok(night, 'the middle of the common clock night darkens the scene');
  world.tick += 12;
  renderer.render(world, options);
  assert.equal(clears.length, 1, 'legacy ticks cannot independently change the season');
  world.clock = DAY_SECONDS * 12;
  renderer.render(world, options);
  assert.equal(clears.length, 2, 'a shared-clock seasonal transition refreshes land');
});

test('persistent flood, fire, rubble, snow, supplies and damage are drawn without erasing a house', () => {
  const { renderer, world, options, pixels, screen } = setup();
  const point = { x: 24, y: 24 }, cell = world.cells[point.y * world.size + point.x]!;
  cell.kind = 'house'; cell.terrain = 'land'; cell.level = 3; cell.condition = 20;
  cell.waterDepth = 2; cell.fire = 60; cell.snow = 1; cell.rubble = 50; cell.stock = 30; cell.materials = 30; cell.work = 10;
  renderer.render(world, options);
  for (const color of ['#659fb8', '#eeeede', '#c0b39a', '#706653', '#a77951', '#879397', '#e9a268']) assert.ok(pixels.some(pixel => pixel.color === color), color);
  const p = screen(point, options.camera, 19);
  assert.deepEqual(renderer.pick(p.x, p.y, world, options.camera), point);
});

test('local rain stays near the front and reduced motion keeps readable rain marks', () => {
  const { renderer, world, options, pixels } = setup();
  world.weather.kind = 'rain'; world.weather.rainfall = .03; world.weather.frontX = 24; world.weather.frontY = 24; world.weather.frontRadius = 2; world.weather.cloud = 70;
  renderer.render(world, options);
  const rain = pixels.filter(pixel => pixel.surface === 'main' && pixel.color === '#a6cad1');
  assert.ok(rain.length > 0);
  assert.ok(rain.every(pixel => pixel.x >= 440 && pixel.x <= 520 && pixel.y >= 275 && pixel.y <= 348), 'precipitation must not fill the entire canvas');
});

test('sheltering, waiting and repairing residents stay visible and selectable with their belongings', () => {
  const { renderer, world, options, pixels, screen } = setup();
  for (const cell of world.cells) { cell.kind = 'grass'; cell.terrain = 'land'; cell.development = 0; }
  world.residents = world.residents.slice(0, 3);
  const states = ['shelter', 'wait', 'repair'] as const;
  for (const [index, resident] of world.residents.entries()) {
    resident.state = states[index]!; resident.x = 20 + index * 3; resident.y = 24;
    resident.displaced = index === 0; resident.purpose = index === 2 ? 'repair' : 'refuge'; resident.role = index === 1 ? 'dependent' : 'worker';
  }
  renderer.render(world, options);
  assert.equal(world.residents.length, 3);
  for (const resident of world.residents) {
    const p = screen(resident, options.camera, 5);
    assert.equal(renderer.pickResident(p.x, p.y, world, options.camera), resident.id);
  }
  for (const color of ['#bc917b', '#aebbb1', '#947964']) assert.ok(pixels.some(pixel => pixel.color === color), color);
});

test('preview boundary, danger layers, effects and blocked carts remain visible without motion', () => {
  const { renderer, world, options, pixels } = setup();
  const point = { x: 24, y: 24 }, index = point.y * world.size + point.x;
  world.cells[index]!.fire = 40;
  world.effects = [{ id: 1, atStep: world.step, kind: 'meteor', target: point, radius: 4, intensity: 2, duration: 5, source: 'god', seed: 3, remaining: 5, elapsed: 0 }];
  world.shipments = [{ id: 1, from: index, to: index + 1, route: [index, index + 1], routeIndex: 0, progress: .5, food: 10, materials: 5, blocked: true }];
  renderer.render(world, { ...options, preview: { kind: 'meteor', center: point, radius: 4, intensity: 2 }, layer: 'fire' });
  for (const color of ['#e7b39a', '#b8755b', '#a06e5d']) assert.ok(pixels.some(pixel => pixel.surface === 'main' && pixel.color === color), color);
  for (const color of ['#ad8963', '#b76c58']) assert.ok(pixels.some(pixel => pixel.color === color), color);
  const dots = pixels.filter(pixel => pixel.color === '#e7b39a' && pixel.width === 2 && pixel.height === 2);
  assert.equal(dots.length, 40);
  assert.ok(dots.some(pixel => pixel.x < 440) && dots.some(pixel => pixel.x > 520), 'the dotted radius surrounds the target');
});

test('rendering is pure, deterministic and all emitted drawing rectangles use integer pixels', () => {
  const { renderer, world, options, pixels } = setup();
  world.weather.kind = 'storm'; world.weather.frontX = 24; world.weather.frontY = 24; world.weather.frontRadius = 6;
  const before = JSON.stringify(world);
  renderer.render(world, { ...options, reducedMotion: false });
  const first = pixels.filter(pixel => pixel.surface === 'main');
  pixels.length = 0;
  renderer.render(world, { ...options, reducedMotion: false });
  assert.deepEqual(pixels.filter(pixel => pixel.surface === 'main'), first);
  assert.equal(JSON.stringify(world), before, 'drawing must never consume simulation randomness or mutate the world');
  assert.ok(pixels.every(pixel => [pixel.x, pixel.y, pixel.width, pixel.height].every(Number.isInteger)));
});

test('all queued targets retain their own dotted footprints without a current preview', () => {
  const { renderer, world, options, pixels } = setup();
  world.pending = [
    { id: 1, atStep: world.step, kind: 'rain', target: { x: 20, y: 24 }, radius: 2, intensity: 1, duration: 5, source: 'god', seed: 3 },
    { id: 2, atStep: world.step, kind: 'meteor', target: { x: 28, y: 24 }, radius: 3, intensity: 1, duration: 5, source: 'god', seed: 4 },
  ];
  renderer.render(world, options);
  const centers = pixels.filter(pixel => pixel.surface === 'main' && pixel.color === '#dbc9a4' && pixel.width === 4 && pixel.height === 4);
  assert.deepEqual(centers.map(pixel => [pixel.x, pixel.y]), [[442, 300], [514, 340]]);
  assert.equal(pixels.filter(pixel => pixel.color === '#dbc9a4' && pixel.width === 2 && pixel.height === 2).length, 34);
});

test('greenfield and ruin building plans show staged scaffolds, materials and tools', () => {
  const { renderer, world, options, pixels, screen } = setup();
  for (const cell of world.cells) { cell.kind = 'grass'; cell.terrain = 'land'; cell.development = 0; cell.buildingPlan = null; }
  const point = { x: 24, y: 24 }, cell = world.cells[point.y * world.size + point.x]!;
  cell.buildingPlan = 'house'; cell.development = 16; cell.materials = 10;
  renderer.render(world, options);
  for (const color of ['#eee0b8', '#aeb9af', '#879397']) assert.ok(pixels.some(pixel => pixel.color === color), color);
  const p = screen(point, options.camera, 8);
  assert.deepEqual(renderer.pick(p.x, p.y, world, options.camera), point);
  cell.kind = 'ruin'; cell.development = 64; world.revision++;
  renderer.render(world, options);
  const roof = screen(point, options.camera, 15);
  assert.deepEqual(renderer.pick(roof.x, roof.y, world, options.camera), point);
});

test('local sunlight clears earlier rain marks while later rain restores them', () => {
  const { renderer, world, options, pixels } = setup();
  const target = { x: 24, y: 24 };
  world.weather.kind = 'clear'; world.weather.rainfall = 0;
  const effect = { id: 1, atStep: world.step, kind: 'rain' as const, target, radius: 2, intensity: 1, duration: 5, source: 'god' as const, seed: 3, remaining: 5, elapsed: 0 };
  world.effects = [effect];
  renderer.render(world, options);
  assert.ok(pixels.some(pixel => pixel.color === '#a6cad1'), 'rain commands render during otherwise clear weather');
  pixels.length = 0;
  world.effects.push({ ...effect, id: 2, kind: 'sun', radius: 3 });
  renderer.render(world, options);
  assert.equal(pixels.filter(pixel => pixel.color === '#a6cad1').length, 0, 'the sun circle cancels earlier local rain');
  pixels.length = 0;
  world.effects.push({ ...effect, id: 3 });
  renderer.render(world, options);
  assert.ok(pixels.some(pixel => pixel.color === '#a6cad1'), 'a later rain command takes effect in command order');
});

function walkingSetup() {
  const setupResult = setup(), { world } = setupResult;
  for (const cell of world.cells) { cell.kind = 'grass'; cell.terrain = 'land'; cell.development = 0; cell.buildingPlan = null; }
  world.residents = world.residents.slice(0, 1); world.shipments = [];
  const resident = world.residents[0]!;
  resident.state = 'travel'; resident.health = 100; resident.progress = .8; resident.routeIndex = 0;
  resident.x = 20.8; resident.y = 24;
  resident.route = [20, 21, 22].map(x => 24 * world.size + x);
  for (const index of resident.route) {
    const cell = world.cells[index]!;
    cell.kind = 'road'; cell.condition = 100; cell.waterDepth = 0; cell.fire = 0; cell.closed = false;
  }
  world.weather.kind = 'clear'; world.remainder = .2;
  return { ...setupResult, resident };
}

test('substep walking predicts across safe segment boundaries and picking follows the displayed position', () => {
  const { renderer, world, resident, options, images, screen } = walkingSetup();
  const before = JSON.stringify(world);
  const predicted = { x: 20.8 + walkingSpeed(world, resident) * world.remainder, y: 24 };
  renderer.render(world, { ...options, reducedMotion: false });
  const person = images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16)!;
  assert.equal(person.x, Math.round(480 + (predicted.x - predicted.y) * 9) - 8);
  assert.equal(person.y, Math.round(82 + (predicted.x + predicted.y) * 5) - 12);
  const p = screen(predicted, options.camera, 5);
  assert.equal(renderer.pickResident(p.x, p.y, world, options.camera), resident.id);
  assert.equal(JSON.stringify(world), before, 'prediction must not perform simulation arrivals or traffic updates');
  images.length = 0;
  renderer.render(world, { ...options, reducedMotion: false });
  assert.deepEqual(images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16), person, 'a paused remainder freezes the exact drawn location');
});

test('position prediction stops before closed roads and rejects disconnected route segments', () => {
  const { renderer, world, resident, options, images } = walkingSetup();
  world.cells[resident.route[2]!]!.closed = true;
  renderer.render(world, { ...options, reducedMotion: false });
  const person = images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16)!;
  assert.equal(person.x, Math.round(480 + (21 - 24) * 9) - 8, 'the second closed segment cannot be entered');
  images.length = 0;
  world.cells[resident.route[1]!]!.closed = true;
  renderer.render(world, { ...options, reducedMotion: false });
  const stopped = images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16)!;
  assert.equal(stopped.x, Math.round(480 + (resident.x - resident.y) * 9) - 8, 'a blocked current segment freezes its fractional position');
  images.length = 0;
  resident.route = [resident.route[0]!, 24 * world.size + 27];
  renderer.render(world, { ...options, reducedMotion: false });
  assert.deepEqual(images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16), stopped, 'a malformed jump route cannot teleport a resident');
});

test('reduced motion uses stored resident coordinates even with a nonzero remainder', () => {
  const { renderer, world, resident, options, images, screen } = walkingSetup();
  renderer.render(world, options);
  const person = images.find(image => image.surface === 'main' && image.width === 16 && image.height === 16)!;
  assert.equal(person.x, Math.round(480 + (resident.x - resident.y) * 9) - 8);
  const p = screen(resident, options.camera, 5);
  assert.equal(renderer.pickResident(p.x, p.y, world, options.camera), resident.id);
});
