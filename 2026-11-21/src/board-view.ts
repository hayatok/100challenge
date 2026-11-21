import * as THREE from 'three';
import {
  BALL_RADIUS, BOARD_HEIGHT, BOARD_WIDTH, BONUS_OUTLETS, DROP_Y, MAX_DROP_X, MIN_DROP_X, PIN_RADIUS,
  type Ball, type Impact, type Kicker, type Pin,
} from './game.ts';

const PIN_KINDS = ['normal', 'split', 'bonus'] as const;
const PIN_COLOR = { normal: 0xca8e63, split: 0x67cdee, bonus: 0xf3c365 };
const IMPACT_COLOR = { normal: 0xf5bf8c, split: 0x90e6ff, bonus: 0xffd680 };
const RAIL_WIDTH = 21;
const DROP_TRACK_START = MIN_DROP_X - BALL_RADIUS;
const DROP_TRACK_WIDTH = MAX_DROP_X - MIN_DROP_X + BALL_RADIUS * 2;
const REFILL_PULSE_SECONDS = 0.48;
const IMPACT_DURATION = 0.26;
const IMPACT_POOL = 8;

function makeSurface(stage: number): THREE.CanvasTexture | null {
  const canvas = document.createElement('canvas');
  canvas.width = BOARD_WIDTH * 2;
  canvas.height = BOARD_HEIGHT * 2;
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;
  ctx.scale(2, 2);

  const field = ctx.createRadialGradient(245, 128, 24, 344, 290, 450);
  field.addColorStop(0, stage === 1 ? '#25443f' : '#263a55');
  field.addColorStop(0.56, stage === 1 ? '#193631' : '#202b43');
  field.addColorStop(1, stage === 1 ? '#0c201f' : '#111725');
  ctx.fillStyle = field;
  ctx.fillRect(0, 0, BOARD_WIDTH, BOARD_HEIGHT);

  // A fine, deterministic grain keeps the enamel from looking like flat UI paint.
  let noise = 92742;
  for (let i = 0; i < 14000; i++) {
    noise = (Math.imul(noise, 1664525) + 1013904223) >>> 0;
    const x = (noise / 2 ** 32) * BOARD_WIDTH;
    noise = (Math.imul(noise, 1664525) + 1013904223) >>> 0;
    const y = (noise / 2 ** 32) * BOARD_HEIGHT;
    ctx.fillStyle = (noise & 256) ? '#f3e0af13' : '#061a1930';
    ctx.fillRect(x, y, 0.85, 0.6);
  }

  const head = ctx.createLinearGradient(0, 5, 0, 73);
  head.addColorStop(0, '#1a2a27');
  head.addColorStop(0.3, '#243b34');
  head.addColorStop(0.84, '#17302b');
  head.addColorStop(1, '#0b1c19');
  ctx.fillStyle = head;
  ctx.fillRect(RAIL_WIDTH, 0, BOARD_WIDTH - RAIL_WIDTH * 2, 72);
  ctx.fillStyle = '#9a7f56';
  ctx.fillRect(RAIL_WIDTH, 3, BOARD_WIDTH - RAIL_WIDTH * 2, 1);
  ctx.fillStyle = '#748776';
  ctx.fillRect(RAIL_WIDTH, 71, BOARD_WIDTH - RAIL_WIDTH * 2, 1);

  const track = ctx.createLinearGradient(0, DROP_Y - 12, 0, DROP_Y + 12);
  track.addColorStop(0, '#a1926b');
  track.addColorStop(0.09, '#5b6250');
  track.addColorStop(0.19, '#0b211d');
  track.addColorStop(0.72, '#172b24');
  track.addColorStop(0.90, '#3c4b3f');
  track.addColorStop(1, '#7c7d5e');
  ctx.fillStyle = track;
  ctx.fillRect(DROP_TRACK_START, DROP_Y - 12, DROP_TRACK_WIDTH, 24);

  for (const x of BONUS_OUTLETS) {
    ctx.fillStyle = '#d1a658';
    ctx.fillRect(x - 6, DROP_Y - 12, 12, 2);
    ctx.fillRect(x - 1.5, DROP_Y - 10, 3, 4);
  }

  for (const direction of [1, -1]) {
    ctx.save();
    if (direction === -1) {
      ctx.translate(BOARD_WIDTH, 0);
      ctx.scale(-1, 1);
    }
    const rail = ctx.createLinearGradient(0, 0, RAIL_WIDTH + 8, 0);
    rail.addColorStop(0, '#0d1818');
    rail.addColorStop(0.15, '#25352e');
    rail.addColorStop(0.21, '#978052');
    rail.addColorStop(0.49, '#4d543d');
    rail.addColorStop(0.61, '#bab080');
    rail.addColorStop(0.67, '#4b6051');
    rail.addColorStop(0.74, '#0d201d');
    rail.addColorStop(1, '#142a2500');
    ctx.fillStyle = rail;
    ctx.fillRect(0, 0, RAIL_WIDTH + 8, BOARD_HEIGHT);
    for (const y of [20, 167, 353, BOARD_HEIGHT - 20]) {
      ctx.beginPath();
      ctx.arc(11, y, 3.4, 0, Math.PI * 2);
      ctx.fillStyle = '#202b24';
      ctx.fill();
      ctx.fillStyle = '#b5ab87';
      ctx.fillRect(9, y - 0.5, 4, 1);
    }
    ctx.restore();
  }

  // The catcher sits under the pin field and gives falling balls a clear exit.
  const grate = ctx.createLinearGradient(0, BOARD_HEIGHT - 31, 0, BOARD_HEIGHT);
  grate.addColorStop(0, '#0f2421');
  grate.addColorStop(0.25, '#101f1b');
  grate.addColorStop(0.3, '#445146');
  grate.addColorStop(0.43, '#101e1c');
  grate.addColorStop(1, '#203832');
  ctx.fillStyle = grate;
  ctx.fillRect(RAIL_WIDTH, BOARD_HEIGHT - 31, BOARD_WIDTH - RAIL_WIDTH * 2, 31);
  for (let x = 32; x < BOARD_WIDTH - 30; x += 12) {
    ctx.fillStyle = '#091916';
    ctx.fillRect(x, BOARD_HEIGHT - 17, 7, 9);
    ctx.fillStyle = '#55685a';
    ctx.fillRect(x, BOARD_HEIGHT - 8, 7, 1);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function turnedProfile(profile: Array<[number, number]>) {
  const geometry = new THREE.LatheGeometry(profile.map(([r, z]) => new THREE.Vector2(r, z)), 28);
  return geometry.rotateX(Math.PI / 2);
}

function metal(color: number, roughness: number, metalness: number) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness });
}

function kickerMaterial(direction: Kicker['direction']) {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 64;
  const ctx = canvas.getContext('2d');
  if (!ctx) return new THREE.MeshBasicMaterial({ color: 0xca543c });
  ctx.scale(2, 2);
  ctx.fillStyle = '#061710b8';
  ctx.beginPath();
  ctx.roundRect(0, 4, 128, 28, 9);
  ctx.fill();

  const housing = ctx.createLinearGradient(0, 0, 0, 29);
  housing.addColorStop(0, '#ffe1a0');
  housing.addColorStop(0.13, '#cb925a');
  housing.addColorStop(0.51, '#522a24');
  housing.addColorStop(1, '#1f241b');
  ctx.fillStyle = housing;
  ctx.beginPath();
  ctx.roundRect(0, 0, 128, 28, 8);
  ctx.fill();

  const face = ctx.createLinearGradient(0, 3, 0, 23);
  face.addColorStop(0, '#d75d42');
  face.addColorStop(1, '#753226');
  ctx.fillStyle = face;
  ctx.beginPath();
  ctx.roundRect(7, 4, 114, 19, 5);
  ctx.fill();
  for (const x of [9, 119]) {
    ctx.fillStyle = '#241c14';
    ctx.beginPath();
    ctx.arc(x, 14, 2.7, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#e0ad74';
    ctx.fillRect(x - 1.25, 13.25, 2.5, 1);
  }

  ctx.translate(64, 14);
  ctx.scale(direction, 1);
  ctx.strokeStyle = '#fff1b4';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (const x of [-23, -9, 5, 19]) {
    ctx.beginPath();
    ctx.moveTo(x - 3, -5);
    ctx.lineTo(x + 2, 0);
    ctx.lineTo(x - 3, 5);
    ctx.stroke();
  }
  const map = new THREE.CanvasTexture(canvas);
  map.colorSpace = THREE.SRGBColorSpace;
  return new THREE.MeshBasicMaterial({ map, transparent: true, depthWrite: false });
}

interface PinInstance {
  mesh: THREE.InstancedMesh;
  index: number;
}

interface BallSprite {
  group: THREE.Group;
  sphere: THREE.Mesh<THREE.SphereGeometry, THREE.MeshStandardMaterial>;
  glow: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial>;
  trail: THREE.Mesh<THREE.CircleGeometry, THREE.MeshBasicMaterial>;
}

interface ImpactRing {
  mesh: THREE.Mesh<THREE.RingGeometry, THREE.MeshBasicMaterial>;
  age: number;
  strength: number;
}

export class BoardView {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.OrthographicCamera(0, BOARD_WIDTH, 0, -BOARD_HEIGHT, 1, 180);
  private readonly pinMeshes: THREE.InstancedMesh[] = [];
  private readonly pinInstances = new Map<number, PinInstance[]>();
  private readonly surfaces = [makeSurface(1), makeSurface(2)];
  private readonly floorMaterial = new THREE.MeshBasicMaterial({ color: 0xffffff });
  private readonly marker = new THREE.Group();
  private readonly markerMetal = new THREE.MeshBasicMaterial({ color: 0xf1bd7e });
  private readonly markerInk = new THREE.MeshBasicMaterial({ color: 0xf1bd7e, transparent: true, opacity: 0.62 });
  private readonly markerBall: BallSprite;
  private readonly emptyMarker = new THREE.Mesh(
    new THREE.RingGeometry(BALL_RADIUS - 1.7, BALL_RADIUS, 24),
    this.markerMetal,
  );
  private readonly rails = new THREE.Group();
  private readonly railLight = new THREE.MeshBasicMaterial({ color: 0xffc787, transparent: true, opacity: 0.44 });
  private readonly kickerDeck = new THREE.Group();
  private readonly kickerFace = new THREE.PlaneGeometry(1, 25);
  private readonly kickerFaces = { 1: kickerMaterial(1), '-1': kickerMaterial(-1) };
  private readonly pinSocket = turnedProfile([[0, 0], [PIN_RADIUS + 3, 0], [PIN_RADIUS + 3, 1], [PIN_RADIUS + 1.5, 2], [0, 2]]);
  private readonly pinCap = turnedProfile([[0, 1.6], [PIN_RADIUS, 1.6], [PIN_RADIUS, 4], [PIN_RADIUS - 1.1, 6.3], [PIN_RADIUS - 3.1, 7.5], [0, 7.5]]);
  private readonly socketMaterial = metal(0x39554a, 0.62, 0.32);
  private readonly capMaterials = {
    normal: metal(PIN_COLOR.normal, 0.34, 0.47),
    split: metal(PIN_COLOR.split, 0.32, 0.26),
    bonus: metal(PIN_COLOR.bonus, 0.29, 0.37),
  };
  private readonly symbolGeometry = new THREE.BoxGeometry(11.9, 2.9, 0.8);
  private readonly symbolMaterial = new THREE.MeshBasicMaterial({ color: 0xffffff });
  private readonly ballGeometry = new THREE.SphereGeometry(BALL_RADIUS, 20, 12);
  private readonly ballMaterials = {
    drop: metal(0xfff0cf, 0.28, 0.16),
    split: new THREE.MeshStandardMaterial({ color: 0x72dcff, emissive: 0x1276a5, emissiveIntensity: 0.55, roughness: 0.25, metalness: 0.16 }),
    bonus: new THREE.MeshStandardMaterial({ color: 0xffd365, emissive: 0xa96810, emissiveIntensity: 0.55, roughness: 0.25, metalness: 0.16 }),
  };
  private readonly birthGeometry = new THREE.RingGeometry(BALL_RADIUS + 1.5, BALL_RADIUS + 4.5, 24);
  private readonly shadowGeometry = new THREE.CircleGeometry(BALL_RADIUS + 1, 22);
  private readonly shadowMaterial = new THREE.MeshBasicMaterial({ color: 0x061614, transparent: true, opacity: 0.68 });
  private readonly trailGeometry = new THREE.CircleGeometry(1, 16);
  private readonly trailMaterial = new THREE.MeshBasicMaterial({ color: 0xc7ead1, transparent: true, opacity: 0.34 });
  private readonly ballSprites: BallSprite[] = [];
  private readonly impactRings: ImpactRing[] = [];
  private readonly transform = new THREE.Matrix4();
  private readonly hidden = new THREE.Matrix4().makeTranslation(-200, 200, 0);
  private readonly stageColor = new THREE.Color();
  private reducedMotion: boolean;
  private chainPulse = 0;
  private refillPulse = 0;
  private lastAimX: number | null = null;
  private lastBallCount = 0;
  private dirty = true;

  constructor(container: HTMLElement, reducedMotion: boolean) {
    this.reducedMotion = reducedMotion;
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.domElement.setAttribute('aria-hidden', 'true');
    container.appendChild(this.renderer.domElement);
    this.camera.position.z = 100;

    const floor = new THREE.Mesh(new THREE.PlaneGeometry(BOARD_WIDTH, BOARD_HEIGHT), this.floorMaterial);
    floor.position.set(BOARD_WIDTH / 2, -BOARD_HEIGHT / 2, -2);
    this.scene.add(floor, new THREE.HemisphereLight(0xf2fff4, 0x77839a, 1.14));
    const key = new THREE.DirectionalLight(0xffe4bc, 2.8);
    key.position.set(-208, 160, 285);
    const rim = new THREE.DirectionalLight(0xa2d9ff, 0.95);
    rim.position.set(180, -175, 115);
    this.scene.add(key, rim);

    const arrow = new THREE.Shape();
    arrow.moveTo(5, -5);
    arrow.lineTo(2, -5);
    arrow.lineTo(-3, 0);
    arrow.lineTo(2, 5);
    arrow.lineTo(5, 5);
    arrow.lineTo(0, 0);
    arrow.closePath();
    const arrowGeometry = new THREE.ShapeGeometry(arrow);
    for (const direction of [-1, 1]) {
      const grip = new THREE.Mesh(arrowGeometry, this.markerMetal);
      grip.rotation.z = direction === 1 ? Math.PI : 0;
      grip.position.set(direction * 13, 0, 0.4);
      this.marker.add(grip);
    }
    this.markerBall = this.createBallSprite();
    this.emptyMarker.position.z = 9.5;
    this.emptyMarker.visible = false;
    this.marker.add(this.markerBall.group, this.emptyMarker);
    const dashGeometry = new THREE.PlaneGeometry(2, 5);
    for (let i = 0; i < 3; i++) {
      const dash = new THREE.Mesh(dashGeometry, this.markerInk);
      dash.position.set(0, -18 - i * 9, 0);
      this.marker.add(dash);
    }
    this.marker.visible = false;
    this.scene.add(this.marker);

    const railGeometry = new THREE.PlaneGeometry(2, BOARD_HEIGHT - 108);
    for (const x of [RAIL_WIDTH - 1, BOARD_WIDTH - RAIL_WIDTH + 1]) {
      const highlight = new THREE.Mesh(railGeometry, this.railLight);
      highlight.position.set(x, -BOARD_HEIGHT / 2 - 19, -0.5);
      this.rails.add(highlight);
    }
    this.scene.add(this.rails, this.kickerDeck);

    const impactGeometry = new THREE.RingGeometry(PIN_RADIUS, PIN_RADIUS + 2.3, 28);
    for (let i = 0; i < IMPACT_POOL; i++) {
      const mesh = new THREE.Mesh(impactGeometry, new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false }));
      mesh.visible = false;
      this.scene.add(mesh);
      this.impactRings.push({ mesh, age: IMPACT_DURATION, strength: 0 });
    }

    const resize = () => {
      const width = container.clientWidth;
      const height = container.clientHeight;
      if (width === 0 || height === 0) return;
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      this.renderer.setSize(width, height, false);
      this.dirty = true;
    };
    new ResizeObserver(resize).observe(container);
    resize();
    this.renderer.domElement.addEventListener('webglcontextrestored', () => { this.dirty = true; });
  }

  reset(pins: readonly Pin[], stage: number, kickers: readonly Kicker[]): void {
    for (const mesh of this.pinMeshes) {
      mesh.removeFromParent();
      mesh.dispose();
    }
    this.pinMeshes.length = 0;
    this.pinInstances.clear();
    this.floorMaterial.map = this.surfaces[stage - 1];
    this.floorMaterial.color.setHex(this.floorMaterial.map ? 0xffffff : 0x193631);
    this.floorMaterial.needsUpdate = true;

    this.kickerDeck.clear();
    for (const kicker of kickers) {
      const plate = new THREE.Mesh(this.kickerFace, this.kickerFaces[kicker.direction]);
      plate.position.set(kicker.x, -kicker.y - 12.5, 2);
      plate.scale.x = kicker.width;
      this.kickerDeck.add(plate);
    }

    const sockets = this.makePinMesh(this.pinSocket, this.socketMaterial, pins.length);
    pins.forEach((pin, i) => sockets.setMatrixAt(i, this.transform.makeTranslation(pin.x + 0.8, -pin.y - 1.4, 0)));
    sockets.instanceMatrix.needsUpdate = true;

    for (const kind of PIN_KINDS) {
      const group = pins.filter((pin) => pin.kind === kind && pin.alive);
      if (group.length === 0) continue;
      const caps = this.makePinMesh(this.pinCap, this.capMaterials[kind], group.length);
      group.forEach((pin, index) => {
        caps.setMatrixAt(index, this.transform.makeTranslation(pin.x, -pin.y, 0));
        this.pinInstances.set(pin.id, [{ mesh: caps, index }]);
      });
      caps.instanceMatrix.needsUpdate = true;
      if (kind !== 'normal') this.addSymbols(group, kind);
    }

    this.stageColor.setHex(stage >= 2 ? 0x99dbd7 : 0xf1bd7e);
    this.markerMetal.color.copy(this.stageColor);
    this.markerInk.color.copy(this.stageColor);
    this.railLight.color.copy(this.stageColor);
    this.railLight.opacity = 0.43;
    this.chainPulse = 0;
    this.refillPulse = 0;
    for (const sprite of this.ballSprites) sprite.group.visible = false;
    this.lastBallCount = 0;
    for (const ring of this.impactRings) {
      ring.mesh.visible = false;
      ring.age = IMPACT_DURATION;
    }
    this.dirty = true;
  }

  hit({ pin, chain }: Impact): void {
    for (const { mesh, index } of this.pinInstances.get(pin.id) ?? []) {
      mesh.setMatrixAt(index, this.hidden);
      mesh.instanceMatrix.needsUpdate = true;
    }
    this.pinInstances.delete(pin.id);
    this.dirty = true;
    if (this.reducedMotion) return;

    let ring = this.impactRings[0];
    for (const candidate of this.impactRings) {
      if (candidate.age > ring.age) ring = candidate;
    }
    ring.age = 0;
    ring.strength = Math.min(chain / 7, 1);
    ring.mesh.position.set(pin.x, -pin.y, 10);
    ring.mesh.material.color.setHex(IMPACT_COLOR[pin.kind]);
    ring.mesh.scale.setScalar(1);
    ring.mesh.visible = true;
    if (chain >= 4) this.chainPulse = Math.max(this.chainPulse, Math.min(1, chain / 7));
  }

  refillAim(): void {
    if (!this.reducedMotion) this.refillPulse = REFILL_PULSE_SECONDS;
  }

  draw(balls: readonly Ball[], aimX: number | null, loaded: boolean, delta: number): void {
    if (aimX !== this.lastAimX) {
      this.lastAimX = aimX;
      this.marker.visible = aimX !== null;
      if (aimX !== null) this.marker.position.set(aimX, -DROP_Y, 0);
      this.dirty = true;
    }
    if (this.markerBall.group.visible !== loaded) {
      this.markerBall.group.visible = loaded;
      this.emptyMarker.visible = !loaded;
      this.markerInk.opacity = loaded ? 0.62 : 0.35;
      this.dirty = true;
    }
    const glow = this.markerBall.glow;
    if (this.refillPulse > 0 || glow.visible) {
      this.refillPulse = aimX !== null && loaded ? Math.max(0, this.refillPulse - delta) : 0;
      const strength = this.refillPulse / REFILL_PULSE_SECONDS;
      glow.visible = strength > 0;
      glow.material.color.setHex(0xc9ffc0);
      glow.material.opacity = strength;
      glow.scale.setScalar(1 + (1 - strength) * 1.2);
      this.dirty = true;
    }

    if (balls.length > 0 || this.lastBallCount > 0) {
      this.drawBalls(balls);
      this.dirty = true;
    }
    this.lastBallCount = balls.length;

    for (const ring of this.impactRings) {
      if (!ring.mesh.visible) continue;
      this.dirty = true;
      ring.age += delta;
      const progress = Math.min(1, ring.age / IMPACT_DURATION);
      ring.mesh.visible = progress < 1;
      ring.mesh.scale.setScalar(1 + (1 - (1 - progress) ** 2) * (0.62 + ring.strength * 0.72));
      ring.mesh.material.opacity = (1 - progress) * (0.65 + 0.28 * ring.strength);
    }
    if (this.chainPulse > 0) {
      this.railLight.opacity = 0.43 + this.chainPulse * 0.5;
      this.chainPulse = Math.max(0, this.chainPulse - delta * 2.9);
      if (this.chainPulse === 0) this.railLight.opacity = 0.43;
      this.dirty = true;
    }

    if (this.dirty) {
      this.renderer.render(this.scene, this.camera);
      this.dirty = false;
    }
  }

  animate(callback: (now: number) => void): void {
    this.renderer.setAnimationLoop(callback);
  }

  setReducedMotion(value: boolean): void {
    this.reducedMotion = value;
    this.dirty = true;
    if (!value) return;
    for (const ring of this.impactRings) {
      ring.mesh.visible = false;
      ring.age = IMPACT_DURATION;
    }
    this.chainPulse = 0;
    this.refillPulse = 0;
    this.railLight.opacity = 0.43;
  }

  private makePinMesh(geometry: THREE.BufferGeometry, material: THREE.Material, count: number) {
    const mesh = new THREE.InstancedMesh(geometry, material, count);
    mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.pinMeshes.push(mesh);
    this.scene.add(mesh);
    return mesh;
  }

  private addSymbols(pins: Pin[], kind: 'split' | 'bonus') {
    const symbols = this.makePinMesh(this.symbolGeometry, this.symbolMaterial, pins.length * 2);
    const ink = new THREE.Color(kind === 'split' ? 0x113747 : 0x54310d);
    pins.forEach((pin, i) => {
      if (kind === 'split') {
        symbols.setMatrixAt(i * 2, this.transform.makeTranslation(pin.x, -pin.y + 2.7, 8));
        symbols.setMatrixAt(i * 2 + 1, this.transform.makeTranslation(pin.x, -pin.y - 2.7, 8));
      } else {
        symbols.setMatrixAt(i * 2, this.transform.makeTranslation(pin.x, -pin.y, 8));
        symbols.setMatrixAt(i * 2 + 1, this.transform.makeRotationZ(Math.PI / 2).setPosition(pin.x, -pin.y, 8.03));
      }
      symbols.setColorAt(i * 2, ink);
      symbols.setColorAt(i * 2 + 1, ink);
      this.pinInstances.get(pin.id)?.push({ mesh: symbols, index: i * 2 }, { mesh: symbols, index: i * 2 + 1 });
    });
    symbols.instanceMatrix.needsUpdate = true;
    if (symbols.instanceColor) symbols.instanceColor.needsUpdate = true;
  }

  private createBallSprite(): BallSprite {
    const group = new THREE.Group();
    const shadow = new THREE.Mesh(this.shadowGeometry, this.shadowMaterial);
    shadow.position.set(2.8, -3.7, 0.3);
    const sphere = new THREE.Mesh(this.ballGeometry, this.ballMaterials.drop);
    sphere.position.z = 9.5;
    const glow = new THREE.Mesh(this.birthGeometry, new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false }));
    glow.position.z = 9;
    glow.visible = false;
    const trail = new THREE.Mesh(this.trailGeometry, this.trailMaterial);
    trail.visible = false;
    group.add(shadow, sphere, glow, trail);
    return { group, sphere, glow, trail };
  }

  private drawBalls(balls: readonly Ball[]) {
    // Instance order can change as balls drain. Position and trail use only the current simulation sample.
    balls.forEach((ball, i) => {
      if (i === this.ballSprites.length) {
        const sprite = this.createBallSprite();
        this.ballSprites.push(sprite);
        this.scene.add(sprite.group);
      }
      const sprite = this.ballSprites[i];
      sprite.group.visible = true;
      sprite.group.position.set(ball.x, -ball.y, 0);
      sprite.sphere.material = this.ballMaterials[ball.origin];
      // Birth rings surround the true ball position; physics and the sphere radius stay unchanged.
      const birth = Math.max(0, 1 - ball.age / 0.55);
      sprite.glow.visible = !this.reducedMotion && ball.origin !== 'drop' && birth > 0;
      if (sprite.glow.visible) {
        sprite.glow.material.color.setHex(ball.origin === 'split' ? 0x8be7ff : 0xffdb70);
        sprite.glow.material.opacity = birth * 0.85;
        sprite.glow.scale.setScalar(1 + (1 - birth) * 0.65);
      }
      const trail = sprite.trail;
      const speed = Math.hypot(ball.vx, ball.vy);
      trail.visible = !this.reducedMotion && speed > 160 && ball.age > 0.033;
      if (trail.visible) {
        const length = Math.min(27, speed * 0.026 + Math.abs(ball.vx) * 0.035);
        trail.position.set(-ball.vx * length / speed, ball.vy * length / speed, 1);
        trail.rotation.z = Math.atan2(-ball.vy, ball.vx);
        trail.scale.set(length, 2.25, 1);
      }
    });
    for (let i = balls.length; i < this.ballSprites.length; i++) this.ballSprites[i].group.visible = false;
  }
}
