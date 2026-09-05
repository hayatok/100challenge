import * as T from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { type Game, type Point } from "./game/simulation";
import { GRID, EDGE, STATION, DOCK, SCENERY, pointAt } from "./game/cleaning";
const NAMES = [
  "robot",
  "dust",
  "dash",
  "box",
  "boss",
  "nozzle",
  "mop",
  "spray",
  "disc",
  "battery",
  "heal",
  "tile",
  "pallet",
  "crate",
  "fence",
  "mud",
  "station",
  "storefront",
] as const;
type Name = (typeof NAMES)[number];
type Batch = {
  meshes: T.InstancedMesh[];
  local: T.Matrix4[];
  count: number;
  capacity: number;
};
export class GameScene {
  renderer: T.WebGLRenderer;
  scene = new T.Scene();
  camera = new T.OrthographicCamera();
  batches = new Map<Name, Batch>();
  dummy = new T.Object3D();
  matrix = new T.Matrix4();
  shadows = new T.InstancedMesh(
    new T.CircleGeometry(1, 16),
    new T.MeshBasicMaterial({
      color: "#292d31",
      transparent: true,
      opacity: 0.2,
      depthWrite: false,
    }),
    600,
  );
  shadowCount = 0;
  dirtData = new Uint8Array(GRID * GRID * 4);
  dirtTexture = new T.DataTexture(this.dirtData, GRID, GRID);
  dirt = new T.Mesh(
    new T.PlaneGeometry(EDGE * 2, EDGE * 2),
    new T.MeshStandardMaterial({
      map: this.dirtTexture,
      transparent: true,
      roughness: 1,
      depthWrite: false,
    }),
  );
  floorVersion = -1;
  floorIdentity?: Game["floor"];
  lastFloorUpdate = -1;
  stationRing = new T.Mesh(
    new T.RingGeometry(1.3, 1.45, 48),
    new T.MeshBasicMaterial({ color: "#ed713b", side: T.DoubleSide }),
  );
  dockRing = new T.Mesh(
    new T.RingGeometry(1, 1.1, 32),
    new T.MeshBasicMaterial({ color: "#68bcb1", side: T.DoubleSide }),
  );
  stationLight = new T.Mesh(
    new T.CircleGeometry(0.2, 20),
    new T.MeshBasicMaterial({ color: "#68bcb1" }),
  );
  ringGeometry = new T.RingGeometry(0.55, 1, 24);
  foamGeometry = new T.CircleGeometry(1, 32);
  suctionGeometry = Array.from({ length: 5 }, (_, i) => {
    const half = 0.45 + (i + 1) * 0.09;
    return new T.RingGeometry(0.05, 1, 24, 1, Math.PI / 2 - half, half * 2);
  });
  effects: T.Mesh[] = [];
  arrows: T.Mesh[] = [];
  observer: ResizeObserver;
  disposed = false;
  halfX = 17;
  halfZ = 12;
  constructor(
    private host: HTMLElement,
    private fail: (message: string) => void,
  ) {
    this.renderer = new T.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
    this.renderer.setClearColor("#e4dfd0");
    this.renderer.outputColorSpace = T.SRGBColorSpace;
    host.append(this.renderer.domElement);
    this.renderer.domElement.setAttribute("aria-label", "倉庫の3Dゲーム画面");
    this.renderer.domElement.addEventListener("webglcontextlost", this.onLost);
    this.dirtTexture.colorSpace = T.SRGBColorSpace;
    this.dirtTexture.magFilter = T.LinearFilter;
    this.dirt.rotation.x = -Math.PI / 2;
    this.dirt.position.y = 0.015;
    this.dirt.renderOrder = 1;
    this.scene.add(this.dirt);
    this.stationRing.rotation.x = this.dockRing.rotation.x = -Math.PI / 2;
    this.stationRing.position.set(STATION.x, 0.035, STATION.z);
    this.dockRing.position.set(DOCK.x, 0.036, DOCK.z);
    this.stationLight.rotation.x = -Math.PI / 2;
    this.stationLight.position.set(STATION.x, 0.04, STATION.z + 1.0);
    this.scene.add(this.stationRing, this.dockRing, this.stationLight);
    this.shadows.renderOrder = 2;
    this.shadows.frustumCulled = false;
    this.scene.add(this.shadows);
    this.scene.add(new T.HemisphereLight(0xffffff, 0x75718a, 1.8));
    const sun = new T.DirectionalLight(0xfff5e7, 2.0);
    sun.position.set(-6, 15, 10);
    this.scene.add(sun);
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(host);
    this.resize();
  }
  onLost = (event: Event) => {
    event.preventDefault();
    this.fail("3D描画が中断されました。再読み込みして再開してください。");
  };
  resize() {
    const w = this.host.clientWidth,
      h = this.host.clientHeight;
    if (!w || !h) return;
    const aspect = w / h;
    const halfH = aspect < 0.8 ? 11 : 9;
    this.halfX = halfH * aspect;
    this.halfZ = halfH / 0.8 + 2;
    this.camera.left = -this.halfX;
    this.camera.right = this.halfX;
    this.camera.top = halfH;
    this.camera.bottom = -halfH;
    this.camera.near = 0.1;
    this.camera.far = 120;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
  }
  async load(progress: (n: number) => void) {
    let done = 0;
    const loader = new GLTFLoader();
    await Promise.all(
      NAMES.map(async (name) => {
        const gltf = await loader.loadAsync(
          `${import.meta.env.BASE_URL}models/${name}.glb`,
        );
        if (this.disposed) {
          gltf.scene.traverse((o) => {
            if (o instanceof T.Mesh) {
              o.geometry.dispose();
              const ms = Array.isArray(o.material) ? o.material : [o.material];
              ms.forEach((m) => m.dispose());
            }
          });
          return;
        }
        gltf.scene.updateMatrixWorld(true);
        const batch: Batch = {
          meshes: [],
          local: [],
          count: 0,
          capacity: name === "tile" ? 1000 : 300,
        };
        gltf.scene.traverse((o) => {
          if (o instanceof T.Mesh) {
            const src = o.material as T.MeshStandardMaterial;
            // Preserve the reviewed Blender material, including roughness and authored normals.
            const mat = src.clone();
            mat.envMapIntensity = 0.4;
            const mesh = new T.InstancedMesh(o.geometry, mat, batch.capacity);
            mesh.count = 0;
            mesh.frustumCulled = false;
            mesh.instanceMatrix.setUsage(T.DynamicDrawUsage);
            this.scene.add(mesh);
            batch.meshes.push(mesh);
            batch.local.push(o.matrixWorld.clone());
            src.dispose();
          }
        });
        this.batches.set(name, batch);
        progress(++done / NAMES.length);
      }),
    );
    if (this.disposed) return;
    for (let i = 0; i < 180; i++) {
      const mesh = new T.Mesh(
        this.ringGeometry,
        new T.MeshBasicMaterial({
          color: "#68bcb1",
          transparent: true,
          opacity: 0.5,
          depthWrite: false,
          side: T.DoubleSide,
        }),
      );
      mesh.rotation.x = -Math.PI / 2;
      // Draw ground effects above dirt (1) and contact shadows (2), retaining depth testing against models.
      mesh.renderOrder = 3;
      mesh.visible = false;
      this.scene.add(mesh);
      this.effects.push(mesh);
    }
    for (let i = 0; i < 50; i++) {
      const m = new T.Mesh(
        new T.ConeGeometry(0.22, 1, 3),
        new T.MeshBasicMaterial({ color: "#ed713b" }),
      );
      m.visible = false;
      this.scene.add(m);
      this.arrows.push(m);
    }
  }
  put(name: Name, p: Point, angle = 0, scale = 1, y = 0, color?: T.Color) {
    const b = this.batches.get(name);
    if (!b || b.count >= b.capacity) return;
    this.dummy.position.set(p.x, y, p.z);
    this.dummy.rotation.set(0, angle, 0);
    this.dummy.scale.setScalar(scale);
    this.dummy.updateMatrix();
    b.meshes.forEach((m, i) => {
      this.matrix.multiplyMatrices(this.dummy.matrix, b.local[i]);
      m.setMatrixAt(b.count, this.matrix);
      m.setColorAt(b.count, color ?? WHITE);
    });
    b.count++;
  }
  render(g: Game, reduced: boolean) {
    if (this.disposed) return;
    g.view = { halfX: this.halfX, halfZ: this.halfZ };
    for (const b of this.batches.values()) b.count = 0;
    this.shadowCount = 0;
    const shadow = (p: Point, r: number, depth = r) => {
      this.dummy.position.set(p.x, 0.025, p.z);
      this.dummy.rotation.set(-Math.PI / 2, 0, 0);
      this.dummy.scale.set(r, depth, 1);
      this.dummy.updateMatrix();
      this.shadows.setMatrixAt(this.shadowCount++, this.dummy.matrix);
    };
    shadow(g.player, 0.8);
    shadow(STATION, 1.0);
    shadow({ x: -7, z: -11 }, 4.2, 1.65);
    for (const e of g.enemies) shadow(e, e.kind === "boss" ? 1.6 : 0.6);
    this.shadows.count = this.shadowCount;
    this.shadows.instanceMatrix.needsUpdate = true;
    const p = g.player;
    if (
      this.floorIdentity !== g.floor ||
      (this.floorVersion !== g.floor.version &&
        Math.abs(g.time - this.lastFloorUpdate) > 0.09)
    ) {
      this.floorIdentity = g.floor;
      this.floorVersion = g.floor.version;
      this.lastFloorUpdate = g.time;
      for (let i = 0; i < g.floor.cells.length; i++) {
        const q = pointAt(i),
          noise = ((i * 37) % 11) - 5;
        // Texture bottom row maps to +Z after plane rotation: reverse the simulation rows.
        const j = ((GRID - 1 - Math.floor(i / GRID)) * GRID + (i % GRID)) * 4;
        this.dirtData[j] = 125 + noise;
        this.dirtData[j + 1] = 118 + noise;
        this.dirtData[j + 2] = 139 + noise;
        this.dirtData[j + 3] =
          Math.hypot(q.x, q.z) > EDGE || g.floor.cells[i] ? 0 : 245;
      }
      this.dirtTexture.needsUpdate = true;
    }
    (this.stationRing.material as T.MeshBasicMaterial).color.set(
      g.station.active
        ? "#68bcb1"
        : g.station.connected
          ? "#f5eddc"
          : "#ed713b",
    );
    this.stationLight.visible = g.station.active;
    this.put("station", STATION, 0, 1, 0, g.station.active ? WHITE : INACTIVE);
    this.put(
      "storefront",
      SCENERY[0],
      0,
      1,
      0,
      g.station.active ? WHITE : SHOP_CLOSED,
    );
    this.camera.position.set(p.x, 24, p.z + 15.5);
    this.camera.lookAt(p.x, 0, p.z - 2.5);
    // All scenery geometry comes from the Blender library. Checker tint gives the floor scale.
    for (let x = -8; x <= 8; x++)
      for (let z = -8; z <= 8; z++)
        this.put(
          "tile",
          { x: x * 4, z: z * 4 },
          0,
          1,
          0,
          (x + z) % 2 ? FLOOR_A : FLOOR_B,
        );
    for (let i = 0; i < 44; i++) {
      const a = (i * Math.PI * 2) / 44;
      this.put("fence", { x: Math.sin(a) * 30, z: Math.cos(a) * 30 }, a);
    }
    for (let i = 0; i < 20; i++) {
      const a = (i * Math.PI * 2) / 20;
      const pp = { x: Math.sin(a) * 32, z: Math.cos(a) * 32 };
      this.put("pallet", pp, a);
      this.put("crate", pp, a, 1.3, 0.32);
    }
    this.put(
      "robot",
      p,
      g.angle,
      1,
      !reduced && g.status === "running" ? Math.sin(g.time * 12) * 0.025 : 0,
      g.invincible > 0 ? HURT : WHITE,
    );
    const n = g.weapons.nozzle;
    for (let i = 0; i < (n >= 5 ? 2 : 1); i++)
      this.put(
        "nozzle",
        {
          x:
            p.x +
            Math.sin(g.angle) * 0.8 +
            Math.cos(g.angle) * (i ? 0.3 : -0.15),
          z:
            p.z +
            Math.cos(g.angle) * 0.8 -
            Math.sin(g.angle) * (i ? 0.3 : -0.15),
        },
        g.angle,
        1 + n * 0.06,
      );
    const m = g.weapons.mop;
    if (m)
      for (let i = 0; i < 1 + Math.floor(m / 2); i++) {
        const a = g.time * 2.8 + (i * Math.PI * 2) / (1 + Math.floor(m / 2));
        this.put(
          "mop",
          {
            x: p.x + Math.sin(a) * (1.6 + m * 0.2),
            z: p.z + Math.cos(a) * (1.6 + m * 0.2),
          },
          a,
          m >= 5 ? 1.4 : 1,
        );
      }
    if (g.weapons.spray)
      this.put(
        "spray",
        { x: p.x - 0.7, z: p.z + 0.3 },
        g.angle,
        1 + g.weapons.spray * 0.1,
        0.5,
      );
    if (g.weapons.disc)
      this.put("disc", { x: p.x + 0.7, z: p.z + 0.3 }, g.time, 1, 0.6);
    for (const e of g.enemies)
      this.put(
        e.kind,
        e,
        e.angle,
        1,
        !reduced && e.phase !== 1
          ? Math.abs(Math.sin(g.time * 5 + e.id)) * 0.08
          : 0,
        e.hit > 0 ? HURT : e.phase === 1 ? WARNING : WHITE,
      );
    for (const b of g.pickups)
      this.put(
        b.heal ? "heal" : "battery",
        b,
        reduced ? 0 : g.time * 1.5,
        Math.min(1.7, 1 + b.value * 0.025),
      );
    for (const b of g.shots) this.put("disc", b, g.time * 12, 1, 0.5);
    this.effects.forEach((mesh, i) => {
      const e = g.effects[i];
      mesh.visible = !!e;
      if (!e) return;
      const material = mesh.material as T.MeshBasicMaterial;
      const t = 1 - e.life / e.max;
      mesh.position.set(e.x, 0.06, e.z);
      mesh.scale.setScalar(e.radius * (e.kind === "foam" ? 1 : 0.5 + t * 0.5));
      material.color.set(
        e.kind === "hit" ? "#ed713b" : e.kind === "pop" ? "#9282ae" : "#68bcb1",
      );
      material.opacity =
        e.kind === "foam"
          ? 0.35
          : e.kind === "trail"
            ? (1 - t) * 0.18
            : (1 - t) * 0.6;
      if (e.kind === "chain") material.color.set("#f5eddc");
      mesh.rotation.set(-Math.PI / 2, 0, 0);
      mesh.geometry = e.kind === "foam" ? this.foamGeometry : this.ringGeometry;
      if (e.kind === "suck") {
        mesh.geometry = this.suctionGeometry[Math.max(0, g.weapons.nozzle - 1)];
        mesh.rotation.z = Math.PI + e.angle;
        mesh.scale.setScalar(e.radius);
      }
    });
    const charging = g.enemies.filter((e) => e.phase === 1);
    this.arrows.forEach((mesh, i) => {
      const e = charging[Math.floor(i / 3)];
      mesh.visible = !!e;
      if (e) {
        const d = 1.4 + (i % 3);
        mesh.position.set(
          e.x + Math.sin(e.angle) * d,
          0.1,
          e.z + Math.cos(e.angle) * d,
        );
        mesh.rotation.set(Math.PI / 2, 0, -e.angle);
      }
    });
    for (const b of this.batches.values())
      for (const mesh of b.meshes) {
        mesh.count = b.count;
        mesh.instanceMatrix.needsUpdate = true;
        if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
      }
    this.renderer.render(this.scene, this.camera);
  }
  dispose() {
    this.disposed = true;
    this.observer.disconnect();
    this.renderer.domElement.removeEventListener(
      "webglcontextlost",
      this.onLost,
    );
    const geometries = new Set<T.BufferGeometry>(),
      materials = new Set<T.Material>();
    this.scene.traverse((o) => {
      if (o instanceof T.Mesh) {
        geometries.add(o.geometry);
        (Array.isArray(o.material) ? o.material : [o.material]).forEach((m) =>
          materials.add(m),
        );
        if (o instanceof T.InstancedMesh) o.dispose();
      }
    });
    [this.ringGeometry, this.foamGeometry, ...this.suctionGeometry].forEach(
      (g) => geometries.add(g),
    );
    geometries.forEach((g) => g.dispose());
    materials.forEach((m) => m.dispose());
    this.dirtTexture.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
const WHITE = new T.Color("white"),
  HURT = new T.Color("#ffb599"),
  WARNING = new T.Color("#ffd39a"),
  INACTIVE = new T.Color("#b5a6b1"),
  SHOP_CLOSED = new T.Color("#bfc0c6"),
  FLOOR_A = new T.Color("#e2e7dc"),
  FLOOR_B = new T.Color("#fff4dc");
