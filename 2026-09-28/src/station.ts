import * as THREE from 'three';
import type { DistrictArea } from './stages.ts';

export type StationFixture = { position: THREE.Vector3; color: number; power: number; range: number };

/** Built at world x=100. All fight floors are y=0, and the branch crossings stay open. */
export function buildStation(): {
  root: THREE.Group;
  fixtures: Partial<Record<DistrictArea, StationFixture[]>>;
  dispose(): void;
} {
  const root = new THREE.Group();
  root.name = 'Black Cat Station';
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  const textures = new Set<THREE.Texture>();
  const geo = <T extends THREE.BufferGeometry>(value: T): T => { geometries.add(value); return value; };
  const mat = <T extends THREE.Material>(value: T): T => { materials.add(value); return value; };
  const boxGeo = geo(new THREE.BoxGeometry(1, 1, 1));
  const planeGeo = geo(new THREE.PlaneGeometry(1, 1));
  const wheelGeo = geo(new THREE.CylinderGeometry(1, 1, 1, 12));
  function surfaceTexture(kind: 'tile' | 'wall'): THREE.CanvasTexture {
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 512;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('Station surface canvas is unavailable');
    ctx.fillStyle = kind === 'tile' ? '#b4bcb6' : '#c5c9bd';
    ctx.fillRect(0, 0, 512, 512);
    for (let row = 0; row < 8; row++) for (let column = 0; column < 8; column++) {
      const value = (row * 19 + column * 37) % 7;
      ctx.fillStyle = kind === 'tile'
        ? ['#a7b2ad', '#b7beb7', '#aeb8b3', '#c0c5bc', '#9eaca9', '#b5bdb5', '#a9b5af'][value]
        : ['#c7c9bd', '#b9c0b7', '#bfc5bb', '#cbd0c3', '#bbc2b8', '#c4c7bb', '#b8c0b7'][value];
      ctx.fillRect(column * 64 + 2, row * 64 + 2, 60, 60);
      ctx.fillStyle = kind === 'tile' ? 'rgba(34,52,51,.13)' : 'rgba(51,57,47,.08)';
      ctx.fillRect(column * 64, row * 64, 64, 2);
      ctx.fillRect(column * 64, row * 64, 2, 64);
    }
    for (let i = 0; i < 850; i++) {
      const x = (i * 173 + i * i * 7) % 512, y = (i * 89 + i * i * 11) % 512;
      ctx.fillStyle = i % 3 ? 'rgba(23,47,48,.055)' : 'rgba(239,230,201,.11)';
      ctx.fillRect(x, y, 1 + i % 3, 1 + i % 5);
    }
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = 4;
    textures.add(texture); return texture;
  }
  const tileMap = surfaceTexture('tile');
  const wallMap = surfaceTexture('wall');
  tileMap.wrapS = tileMap.wrapT = THREE.RepeatWrapping;
  tileMap.repeat.set(4, 4);
  const m = {
    stone: mat(new THREE.MeshStandardMaterial({ map: tileMap, color: 0x647d80, roughness: .81, metalness: .03 })),
    stoneLight: mat(new THREE.MeshStandardMaterial({ map: tileMap, color: 0x9baea9, roughness: .86 })),
    wall: mat(new THREE.MeshStandardMaterial({ map: wallMap, color: 0x819a99, roughness: .9 })),
    dark: mat(new THREE.MeshStandardMaterial({ color: 0x24363c, roughness: .56, metalness: .48 })),
    iron: mat(new THREE.MeshStandardMaterial({ color: 0x4b5b60, roughness: .48, metalness: .59 })),
    teal: mat(new THREE.MeshStandardMaterial({ color: 0x2d716e, roughness: .58, metalness: .21 })),
    seaGlass: mat(new THREE.MeshPhysicalMaterial({ color: 0x659f9a, roughness: .19, metalness: .18,
      transparent: true, opacity: .43, depthWrite: false, side: THREE.DoubleSide })),
    blackGlass: mat(new THREE.MeshStandardMaterial({ color: 0x182d33, roughness: .22, metalness: .34 })),
    cream: mat(new THREE.MeshStandardMaterial({ color: 0xd3d6ca, roughness: .71 })),
    amber: mat(new THREE.MeshStandardMaterial({ color: 0xf4d29c, emissive: 0xd59452, emissiveIntensity: .7, roughness: .4 })),
    cold: mat(new THREE.MeshStandardMaterial({ color: 0xd1f0e9, emissive: 0x93c6bc, emissiveIntensity: .85, roughness: .4 })),
    yellow: mat(new THREE.MeshStandardMaterial({ color: 0xc4ad5b, roughness: .81 })),
    rust: mat(new THREE.MeshStandardMaterial({ color: 0x71594b, roughness: .8, metalness: .19 })),
    red: mat(new THREE.MeshStandardMaterial({ color: 0xaa5948, roughness: .68 })),
    track: mat(new THREE.MeshStandardMaterial({ color: 0x202e33, roughness: .97 })),
    ground: mat(new THREE.MeshStandardMaterial({ color: 0x37474c, roughness: .98 })),
    inlay: mat(new THREE.MeshStandardMaterial({ color: 0x406d69, roughness: .77, metalness: .05 })),
  };
  function box(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number,
    material: THREE.Material, parent: THREE.Object3D = root): THREE.Mesh {
    const mesh = new THREE.Mesh(boxGeo, material);
    mesh.name = name;
    mesh.position.set(x, y, z); mesh.scale.set(sx, sy, sz);
    mesh.castShadow = /post|beam|awning|bench|cabinet|canopy|train|rail/i.test(name);
    mesh.receiveShadow = true;
    parent.add(mesh); return mesh;
  }
  function floor(name: string, x: number, z: number, sx: number, sz: number, material: THREE.Material,
    y = -.027): THREE.Mesh {
    const mesh = new THREE.Mesh(planeGeo, material);
    mesh.name = name; mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, y, z); mesh.scale.set(sx, sz, 1); mesh.receiveShadow = true;
    root.add(mesh); return mesh;
  }
  function sign(name: string, lines: string[], x: number, y: number, z: number, w: number, h: number,
    face: 'front' | 'left' = 'front', luminous = false): void {
    const canvas = document.createElement('canvas'); canvas.width = 768; canvas.height = 256;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('Station sign canvas is unavailable');
    ctx.fillStyle = luminous ? '#174944' : '#e2e3d7'; ctx.fillRect(0, 0, 768, 256);
    ctx.fillStyle = luminous ? '#d8ede3' : '#173b3e';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = `bold ${lines.length === 1 ? 88 : 65}px "Yu Gothic", "Hiragino Kaku Gothic ProN", sans-serif`;
    lines.forEach((line, i) => ctx.fillText(line, 384, lines.length === 1 ? 128 : 73 + i * 112, 720));
    const texture = new THREE.CanvasTexture(canvas); texture.colorSpace = THREE.SRGBColorSpace; textures.add(texture);
    const signMat = mat(new THREE.MeshStandardMaterial({ map: texture, emissiveMap: texture,
      emissive: luminous ? 0x8dbbb0 : 0x323632, emissiveIntensity: luminous ? .4 : .08,
      roughness: .66, side: THREE.DoubleSide }));
    box(`${name} solid frame`, x, y, z, face === 'front' ? w + .2 : .19, h + .2,
      face === 'front' ? .19 : w + .2, m.dark);
    const mesh = new THREE.Mesh(planeGeo, signMat);
    mesh.name = name; mesh.position.set(x, y, face === 'front' ? z + .107 : z);
    mesh.scale.set(w, h, 1); if (face === 'left') { mesh.position.x += .107; mesh.rotation.y = Math.PI / 2; }
    root.add(mesh);
  }
  const fixtures: Partial<Record<DistrictArea, StationFixture[]>> = {};
  function lamp(area: DistrictArea, x: number, y: number, z: number, color: number, power: number, range = 12): void {
    (fixtures[area] ??= []).push({ position: new THREE.Vector3(x, y, z), color, power, range });
  }

  // An underlay beyond the visible station footprint meets the camera's far
  // plane, so the dawn horizon is grounded instead of revealing a sky void.
  floor('Station surrounding ground to horizon', 100, -105, 210, 260, m.ground, -.73);

  // Station forecourt: worn tile, freestanding canopy, recessed ticket machines.
  floor('Forecourt wet stone', 100, 12.1, 25, 25, m.stone);
  for (const x of [94.1, 105.9]) floor('Forecourt teal drainage inlay', x, 12, .18, 23, m.inlay, -.012);
  for (let i = 0; i < 22; i++) {
    const z = 23 - i * 1.04;
    box('Forecourt stone joint', 100, -.011, z, 23.7, .008, .018, m.dark);
  }
  for (const x of [88.1, 111.9]) for (const z of [11.5, 20]) {
    box('Forecourt drain cast frame', x, .004, z, .78, .025, 1.3, m.iron);
    for (let i = 0; i < 6; i++) box('Forecourt drain slot', x, .019, z - .5 + i * .2,
      .63, .008, .065, m.track);
  }
  for (const x of [88.5, 111.5]) for (const z of [19, 5.2]) {
    box('Forecourt canopy post', x, 2.26, z, .34, 4.52, .34, m.dark);
    box('Canopy bronze foot', x, .18, z, .62, .36, .62, m.rust);
  }
  box('Forecourt canopy roof', 100, 4.56, 12, 24.3, .32, 17.1, m.dark);
  box('Canopy illuminated soffit', 100, 4.34, 12, 22.7, .09, 15.5, m.cream);
  for (const z of [5, 8.5, 12, 15.5, 19]) {
    box('Canopy transverse rib', 100, 4.25, z, 22.8, .12, .16, m.iron);
    for (const x of [95, 105]) box('Canopy ceiling light cassette', x, 4.19, z + 1.1,
      3.7, .04, .22, m.cold);
  }
  box('Canopy deep teal front fascia', 100, 4.5, 20.49, 24.3, .28, .1, m.teal);
  for (const x of [93.5, 106.5]) {
    box('Canopy edge light', x, 4.27, 13, .16, .045, 12, m.cold);
    box('Forecourt poster case', x + (x < 100 ? -1 : 1), 1.88, 7.8, .18, 2.4, 1.45, m.iron);
  }
  box('Station entrance upper lintel', 100, 5.14, 1.3, 18.2, 1.14, .65, m.wall);
  for (const x of [91, 109]) box('Entrance masonry pier', x, 2.45, 1.3, .7, 4.9, .8, m.wall);
  sign('黒猫駅 illuminated station name', ['黒猫駅', 'KURO-NEKO'], 100, 5.45, 2.1, 8.8, 1.52, 'front', true);
  sign('黒猫駅 near-canopy station name', ['黒猫駅', 'KURO-NEKO'], 100, 3.61, 9.6, 7.5, 1.05, 'front', true);
  for (const x of [91.9, 108.1]) {
    box('Ticket machine cabinet', x, 1.18, .5, 1.48, 2.36, .84, m.teal);
    box('Ticket machine recess', x, 1.56, 1.01, 1.15, .86, .06, m.blackGlass);
    box('Ticket machine lit display', x, 1.66, 1.05, .83, .42, .025, m.cold);
    box('Ticket machine ticket slot', x, .95, 1.05, .55, .06, .04, m.amber);
    box('Ticket machine side seam', x + .74, 1.25, .5, .02, 2.2, .7, m.iron);
  }
  lamp('forecourt', 94, 4.3, 8, 0xb4ded7, 27);
  lamp('forecourt', 106, 4.3, 7, 0xd0e4c9, 25);

  // Concourse shell is interrupted at z=-12 so both lateral openings are real.
  floor('Concourse slate tiles', 100, -8, 16.5, 17, m.stoneLight);
  floor('Side branch tiles', 100, -12, 31, 6.4, m.stoneLight);
  for (const x of [92.5, 107.5]) floor('Concourse dark teal tile border', x, -7.8, .22, 15.2, m.inlay, -.011);
  for (const side of [-1, 1]) {
    const x = 100 + side * 8.3;
    box('Concourse exterior wall before turn', x, 2.15, -4.2, .45, 4.3, 8.4, m.wall);
    box('Concourse side opening lintel', x, 3.79, -12, .45, .73, 7.2, m.wall);
    box('Concourse exterior wall after turn', x, 2.15, -16.7, .45, 4.3, 2.6, m.wall);
    box('Concourse kickplate before turn', x - side * .25, .32, -4.2, .055, .64, 8.4, m.inlay);
    box('Concourse kickplate after turn', x - side * .25, .32, -16.7, .055, .64, 2.6, m.inlay);
    for (const z of [-3.5, -7]) {
      box('Concourse high glazed bay', x - side * .24, 2.52, z, .07, 1.25, 1.35, m.seaGlass);
      box('Concourse window mullion', x - side * .3, 2.52, z, .08, 1.42, .07, m.dark);
    }
  }
  box('Concourse ceiling', 100, 3.58, -6.25, 16.7, .42, 12.5, m.dark);
  for (const z of [-2, -6, -10]) {
    box('Concourse ceiling beam', 100, 3.26, z, 16.7, .13, .22, m.iron);
    for (const x of [97.5, 102.5]) box('Concourse fluorescent fixture', x, 3.12, z, 2.9, .09, .28, m.cold);
  }
  // Gate bodies are pushed to the side bands; x=96.4..103.6 stays unobstructed.
  for (const x of [94.6, 105.4]) for (const z of [-5.1, -7.3]) {
    box('Ticket gate solid housing', x, .59, z, 1.05, 1.18, 1.46, m.iron);
    box('Ticket gate white top', x, 1.2, z, 1.08, .08, 1.48, m.cream);
    box('Ticket gate reader', x, 1.25, z + .45, .37, .035, .33, m.teal);
    box('Ticket gate access light', x, 1.28, z - .36, .38, .025, .16, m.cold);
  }
  sign('Last departure board', ['最終列車 終了', 'LAST SERVICE'], 100, 3.18, -10.55, 4.65, .5, 'front', true);
  sign('Waiting passage wayfinding', ['待合通路 →'], 106.2, 3.17, -11.4, 2.9, .42, 'front', true);
  sign('Maintenance passage wayfinding', ['← 保守通路'], 93.8, 3.17, -11.4, 2.9, .42, 'front', true);
  lamp('concourse', 97, 3.14, -4, 0xd1e9e1, 29, 11);
  lamp('concourse', 103, 3.14, -10, 0xc5e8de, 27, 11);

  // Parallel routes retain the 5.2m-wide, 5.7m-deep enemy lane.
  for (const [area, x, outer, inner] of [
    ['waiting', 112, 115.55, 108.45], ['maintenance', 88, 84.45, 91.55],
  ] as const) {
    floor(`${area} continuous floor`, x, -21, 7.1, 13, area === 'waiting' ? m.stoneLight : m.stone);
    box(`${area} outer wall`, outer, 2.35, -20.8, .31, 4.7, 12.6, area === 'waiting' ? m.wall : m.rust);
    box(`${area} inner partition`, inner, 2.35, -20.8, .2, 4.7, 12.6, area === 'waiting' ? m.seaGlass : m.wall);
    box(`${area} roof slab`, x, 4.17, -20.8, 7.2, .28, 12.6, m.dark);
    for (const z of [-16.6, -21, -25.2]) {
      box(`${area} roof crossbeam`, x, 3.68, z, 7.2, .22, .27, m.iron);
      box(`${area} ceiling light`, x, 3.52, z, 1.9, .06, .22, area === 'waiting' ? m.cold : m.amber);
    }
  }
  // Waiting: framed blue-green glazing, handrail benches and abandoned bag.
  for (const z of [-17.5, -21.3, -25.1]) {
    box('Waiting glass window recess', 108.7, 2.0, z, .13, 2.22, 2.2, m.blackGlass);
    box('Waiting blue-green window glass', 108.62, 2.0, z, .07, 2.13, 2.11, m.seaGlass);
    box('Waiting window vertical frame', 108.56, 2.0, z, .09, 2.3, .08, m.iron);
    box('Waiting bench white seat', 114.65, .66, z, .64, .13, 1.6, m.cream);
    box('Waiting bench back', 115.04, 1.11, z, .13, .92, 1.6, m.cream);
    for (const dz of [-.65, .65]) {
      box('Waiting bench tubular leg', 114.65, .35, z + dz, .07, .7, .07, m.iron);
      box('Waiting bench side rail', 114.62, .89, z + dz, .65, .08, .07, m.iron);
    }
  }
  box('Abandoned waiting bag', 114.6, .24, -19.7, .48, .45, .65, m.rust);
  box('Waiting bag handle', 114.6, .52, -19.7, .34, .08, .09, m.dark);
  sign('Waiting room destination', ['待合通路', 'ホーム 1番線'], 115.26, 3.16, -22.9, 2.55, .5, 'left');
  lamp('waiting', 112, 3.55, -18, 0xb9ddd6, 28, 9);
  lamp('waiting', 112, 3.55, -24, 0xb1d1cc, 23, 8);

  // Maintenance: warm work lamps, inset cabinet doors, exposed conduit.
  for (const z of [-17.2, -22.8, -25.5]) {
    box('Maintenance electrical cabinet', 85.35, 1.33, z, .54, 2.26, 1.16, m.iron);
    box('Maintenance cabinet inset door', 85.67, 1.31, z, .035, 2.04, 1.0, m.rust);
    box('Maintenance cabinet handle', 85.71, 1.3, z + .34, .045, .42, .065, m.cream);
    box('Maintenance cabinet warning', 85.73, 1.98, z, .045, .21, .43, m.yellow);
  }
  for (const y of [2.8, 3.17]) box('Maintenance exposed pipe', 85.1, y, -21, .11, .11, 11.7, m.rust);
  for (const z of [-16, -20, -24]) {
    box('Maintenance pipe fixing strap', 85.1, 3, z, .19, .46, .07, m.dark);
    box('Maintenance floor warning border', 85.15, .004, z, .34, .015, .48, m.yellow);
    box('Maintenance floor warning black', 85.15, .013, z + .14, .34, .017, .1, m.track);
  }
  box('Maintenance tool chest', 85.5, .43, -19.9, .76, .84, 1.25, m.red);
  box('Maintenance chest upper lip', 85.5, .87, -19.9, .85, .08, 1.31, m.iron);
  sign('Maintenance staff-only sign', ['保守通路', '関係者のみ'], 85.65, 3.16, -23.9, 2.45, .5, 'left');
  lamp('maintenance', 88, 3.5, -18, 0xe8b479, 25, 8);
  lamp('maintenance', 88, 3.5, -24, 0xddae77, 22, 8);

  // The cross-connection at z=-28 spans both exits without a rear wall.
  // The two routes surround a real station hall, rather than an open void.
  floor('Central connecting hall', 100, -21, 16.5, 13, m.stone);
  floor('Branch return crossing', 100, -28, 31, 4.2, m.stoneLight);
  box('Branch return overhead direction beam', 100, 4.18, -28, 31, .34, .24, m.iron);
  sign('Platform direction board', ['1番線  ホーム ↓'], 100, 3.3, -29.4, 5.2, .68, 'front', true);
  floor('Long platform walkable floor', 100, -49, 12, 40, m.stoneLight);
  box('Platform solid foundation', 100, -.38, -48, 12.1, .7, 40, m.stone);
  floor('Platform west teal tile border', 94.58, -48, .18, 39, m.inlay, -.01);
  floor('Platform east edge dark strip', 105.64, -48, .55, 40, m.dark, -.004);
  floor('Platform tactile paving base', 104.92, -48, .54, 39, m.yellow, .006);
  const tactile = new THREE.InstancedMesh(boxGeo, m.yellow, 158);
  tactile.name = 'Raised tactile paving studs';
  const placement = new THREE.Object3D();
  for (let i = 0; i < 79; i++) for (let column = 0; column < 2; column++) {
    placement.position.set(104.77 + column * .3, .025, -29.4 - i * .48);
    placement.scale.set(.095, .025, .095); placement.updateMatrix();
    tactile.setMatrixAt(i * 2 + column, placement.matrix);
  }
  tactile.instanceMatrix.needsUpdate = true; root.add(tactile);
  // Platform columns stay at x<=95 or x>=105; signs and clock are above eye level.
  for (const z of [-31, -39, -47, -55, -63]) {
    for (const x of [94.75, 105.25]) {
      box('Platform canopy post', x, 2.72, z, .29, 5.44, .32, m.iron);
      box('Platform column ceramic foot', x, .53, z, .43, 1.06, .46, m.teal);
    }
    box('Platform roof truss', 100, 5.17, z, 11.8, .29, .3, m.iron);
    box('Platform luminous tube', 100, 4.96, z, 3.7, .075, .24, m.cold);
  }
  box('Platform shelter roof', 100, 5.54, -48, 11.9, .29, 40, m.dark);
  for (const z of [-35, -51]) {
    box('Platform wall bench seat', 95, .66, z, .62, .12, 2.1, m.cream);
    box('Platform wall bench back', 94.65, 1.07, z, .12, .83, 2.1, m.cream);
    for (const dz of [-.85, .85]) box('Platform bench leg', 95, .34, z + dz, .07, .68, .07, m.iron);
  }
  sign('Black Cat Station platform name', ['黒猫駅', 'KURO-NEKO'], 95.08, 3.25, -40, 3.15, .82, 'left');
  sign('Platform way-out board', ['出口  ↑'], 94.95, 3.22, -58, 2.3, .66, 'left', true);
  // A single signal at the far side keeps the boss silhouette and central sightline clear.
  box('Distant signal mast', 105.72, 2.25, -65.8, .15, 4.5, .15, m.iron);
  box('Distant signal black case', 105.72, 4.1, -65.8, .47, .87, .45, m.dark);
  box('Distant signal amber lens', 105.72, 4.1, -65.55, .19, .19, .035, m.amber);
  lamp('platform', 98, 4.95, -35, 0xb6e0d7, 33, 17);
  lamp('platform', 102, 4.95, -48, 0xb6d9d4, 32, 18);
  lamp('platform', 100, 4.95, -62, 0xe5ba99, 24, 18);
  lamp('dawn', 101, 4.95, -62, 0xeabf9b, 28, 19);

  // Tracks sit 0.65m below the platform. Train runs alongside, never across the lane.
  floor('Track ballast', 109.8, -49, 6.25, 45, m.track, -.65);
  floor('Continuous dawn track ballast', 109.8, -117, 6.25, 91, m.track, -.65);
  const sleepers = new THREE.InstancedMesh(boxGeo, m.rust, 39);
  sleepers.name = 'Individual timber sleepers';
  for (let i = 0; i < 39; i++) {
    placement.position.set(109.8, -.54, -27 - i * 1.15);
    placement.scale.set(5.45, .17, .25); placement.updateMatrix();
    sleepers.setMatrixAt(i, placement.matrix);
  }
  sleepers.instanceMatrix.needsUpdate = true; root.add(sleepers);
  const farSleepers = new THREE.InstancedMesh(boxGeo, m.rust, 79);
  farSleepers.name = 'Dawn receding timber sleepers';
  for (let i = 0; i < 79; i++) {
    placement.position.set(109.8, -.54, -71.8 - i * 1.13);
    placement.scale.set(5.45, .17, .25); placement.updateMatrix();
    farSleepers.setMatrixAt(i, placement.matrix);
  }
  farSleepers.instanceMatrix.needsUpdate = true; root.add(farSleepers);
  for (const x of [108.18, 111.35]) {
    box('Steel running rail', x, -.32, -49, .13, .19, 44, m.iron);
    box('Rail head bright edge', x, -.215, -49, .15, .025, 44, m.cream);
  }
  const train = new THREE.Group(); train.name = 'Stationary last train'; root.add(train);
  box('Train volumetric body', 109.75, 1.78, -47.5, 3.52, 3.18, 25, m.cream, train);
  box('Train teal lower skirt', 109.75, .5, -47.5, 3.56, .67, 25, m.teal, train);
  box('Train waist line', 107.957, 1.44, -47.5, .03, .21, 24.8, m.teal, train);
  box('Train dark roof plinth', 109.75, 3.43, -47.5, 3.6, .2, 25.15, m.dark, train);
  const roofProfile = new THREE.Shape();
  roofProfile.moveTo(-1.78, 0);
  roofProfile.quadraticCurveTo(-1.55, .48, 0, .52);
  roofProfile.quadraticCurveTo(1.55, .48, 1.78, 0);
  roofProfile.lineTo(-1.78, 0);
  const roof = new THREE.Mesh(geo(new THREE.ExtrudeGeometry(roofProfile, {
    depth: 25.2, bevelEnabled: false, curveSegments: 12,
  })), m.iron);
  roof.name = 'Train continuous shallow arched roof';
  roof.position.set(109.75, 3.45, -60.1);
  roof.castShadow = true;
  train.add(roof);
  box('Train front roof edge', 109.75, 3.48, -34.88, 3.43, .13, .16, m.dark, train);
  // The near end faces the waiting corridor. Recessed glazing, destination
  // panel, band and headlamps give it the same construction as the side.
  box('Train front windscreen recess', 109.75, 2.39, -34.94, 2.78, 1.08, .075, m.dark, train);
  box('Train front windscreen glass', 109.75, 2.39, -34.887, 2.56, .88, .025, m.blackGlass, train);
  box('Train front windscreen centre mullion', 109.75, 2.39, -34.861, .07, .92, .055, m.iron, train);
  box('Train front windscreen reflection', 109.75, 2.73, -34.859, 2.34, .035, .025, m.seaGlass, train);
  box('Train front destination panel casing', 109.75, 3.08, -34.875, 1.65, .36, .13, m.dark, train);
  box('Train front destination light', 109.75, 3.08, -34.79, 1.43, .19, .035, m.amber, train);
  box('Train front teal waist stripe', 109.75, 1.44, -34.87, 3.5, .22, .075, m.teal, train);
  for (const x of [108.48, 111.02]) {
    box('Train front headlamp dark socket', x, 1.1, -34.851, .42, .33, .09, m.dark, train);
    box('Train front emissive headlamp', x, 1.1, -34.786, .28, .2, .035, m.cold, train);
  }
  box('Train front cab number plaque', 109.75, .91, -34.85, .77, .18, .035, m.iron, train);
  box('Train front coupler', 109.75, .27, -34.7, .7, .23, .42, m.dark, train);
  for (const z of [-57.4, -52.4, -47.4, -42.4, -37.4]) {
    box('Train recessed window shadow', 107.954, 2.28, z, .045, .92, 2.2, m.dark, train);
    box('Train inset blue-green glazing', 107.927, 2.28, z, .012, .79, 1.98, m.blackGlass, train);
    box('Train window upper glint', 107.915, 2.59, z, .012, .035, 1.72, m.seaGlass, train);
    box('Train window vertical mullion', 107.908, 2.28, z, .03, .85, .06, m.iron, train);
  }
  for (const z of [-55.1, -45.1, -35.4]) {
    box('Train sliding door recess', 107.944, 1.61, z, .055, 2.78, 1.45, m.dark, train);
    for (const dz of [-.36, .36]) {
      box('Train sliding door leaf', 107.902, 1.61, z + dz, .04, 2.68, .7, m.cream, train);
      box('Train door glass inset', 107.876, 2.03, z + dz, .015, .78, .45, m.blackGlass, train);
    }
    box('Train door central seam', 107.871, 1.6, z, .03, 2.76, .026, m.iron, train);
  }
  for (const z of [-59.2, -50.8, -44, -35.8]) {
    box('Train undercarriage bogie', 109.75, -.19, z, 2.85, .36, 2.0, m.dark, train);
    for (const dz of [-.65, .65]) for (const x of [108.65, 110.85]) {
      const wheel = new THREE.Mesh(wheelGeo, m.iron);
      wheel.name = 'Train metal wheel'; wheel.rotation.z = Math.PI / 2;
      wheel.position.set(x, -.42, z + dz); wheel.scale.set(.46, .19, .46); train.add(wheel);
    }
  }
  box('Train rear three-dimensional end', 109.75, 1.8, -60.05, 3.3, 3.05, .22, m.teal, train);
  box('Train rear marker lamps', 108.57, 2.23, -60.18, .24, .18, .06, m.red, train);
  box('Train rear marker lamps', 110.91, 2.23, -60.18, .24, .18, .06, m.red, train);
  // Receding track and distant warm city remain visible from the ground-level dawn stop.
  for (const [x, z, h] of [[85, -90, 11], [91, -103, 16], [120, -97, 14], [128, -113, 20]] as const) {
    box('Dawn distant station building', x, h / 2 - .73, z, 7, h, 8, m.dark);
    box('Dawn distant building foot', x, -.58, z, 8.2, .3, 9.3, m.iron);
    for (const y of [3, 6, 9]) if (y < h) box('Dawn distant lit window', x, y, z + 4.05, 2, .34, .04, m.amber);
  }
  for (const x of [108.18, 111.35]) {
    box('Dawn receding rail', x, -.32, -116.5, .12, .18, 91, m.iron);
    box('Dawn rail head glint', x, -.215, -116.5, .15, .025, 91, m.cream);
  }
  lamp('dawn', 100, 7, -78, 0xf3b18a, 15, 30);

  // Every static box uses one unit geometry. Grouping by material and shadow
  // state keeps the station's small architectural pieces to a fixed draw budget.
  for (const parent of [root, train]) {
    const buckets = new Map<string, THREE.Mesh[]>();
    for (const child of parent.children) {
      if (!(child instanceof THREE.Mesh) || child.geometry !== boxGeo ||
          Array.isArray(child.material) || child.material.transparent) continue;
      const key = `${child.material.uuid}:${child.castShadow}`;
      const list = buckets.get(key) ?? [];
      list.push(child); buckets.set(key, list);
    }
    for (const list of buckets.values()) {
      if (list.length < 3) continue;
      const sharedMaterial = list[0].material as THREE.Material;
      const batch = new THREE.InstancedMesh(boxGeo, sharedMaterial, list.length);
      batch.name = `Static station architecture (${sharedMaterial.name || 'shared material'})`;
      batch.castShadow = list[0].castShadow;
      batch.receiveShadow = true;
      batch.userData.parts = list.map(mesh => mesh.name);
      list.forEach((mesh, index) => {
        mesh.updateMatrix(); batch.setMatrixAt(index, mesh.matrix);
        parent.remove(mesh);
      });
      batch.instanceMatrix.needsUpdate = true;
      parent.add(batch);
    }
  }

  return {
    root, fixtures,
    dispose(): void {
      for (const texture of textures) texture.dispose();
      for (const material of materials) material.dispose();
      for (const geometry of geometries) geometry.dispose();
    },
  };
}
