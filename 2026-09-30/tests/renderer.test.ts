import assert from 'node:assert/strict';
import test from 'node:test';
import { TownRenderer, CANVAS_WIDTH, CANVAS_HEIGHT } from '../src/renderer.ts';
import { createWorld } from '../src/simulation.ts';
import type { Camera, Point } from '../src/types.ts';

function setup() {
  const box = { left: 40, top: 80, width: 720, height: 480 };
  const context = { clearRect() {}, fillRect() {}, save() {}, restore() {}, translate() {}, scale() {}, drawImage() {}, setTransform() {}, getImageData: () => ({ data: new Uint8ClampedArray(CANVAS_WIDTH * CANVAS_HEIGHT * 4) }) };
  const canvas = { style: {}, getContext: () => context, getBoundingClientRect: () => box };
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'document');
  Object.defineProperty(globalThis, 'document', { configurable: true, value: { createElement: () => ({ getContext: () => context }) } });
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
  return { renderer, world, screen };
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
