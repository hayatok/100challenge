import * as THREE from 'three';
import { installSurface } from './surface-materials.ts';

export type DistrictArea = 'alley' | 'store' | 'service' | 'court' | 'roof';

export interface District {
  update(time: number, area: DistrictArea, motion: boolean): void;
  strike(origin: THREE.Vector3, direction: THREE.Vector3): boolean;
  reset(): void;
  dispose(): void;
}

/** A connected district. The five sight lines are deliberately kept free of tall props. */
export async function createDistrict(scene: THREE.Scene): Promise<District> {
  const root = new THREE.Group();
  root.name = 'Rain district';
  scene.add(root);
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  const textures = new Set<THREE.Texture>();
  const ownGeo = <T extends THREE.BufferGeometry>(value: T): T => { geometries.add(value); return value; };
  const ownMat = <T extends THREE.Material>(value: T): T => { materials.add(value); return value; };
  const ownTex = <T extends THREE.Texture>(value: T): T => { textures.add(value); return value; };
  const cube = ownGeo(new THREE.BoxGeometry(1, 1, 1));
  const plane = ownGeo(new THREE.PlaneGeometry(1, 1));
  const cylinder = ownGeo(new THREE.CylinderGeometry(1, 1, 1, 12));
  const disc = ownGeo(new THREE.CircleGeometry(1, 32));
  const fruitShape = ownGeo(new THREE.IcosahedronGeometry(1, 1));
  const areas: Record<DistrictArea, THREE.Group> = {
    alley: new THREE.Group(), store: new THREE.Group(), service: new THREE.Group(),
    court: new THREE.Group(), roof: new THREE.Group(),
  };
  for (const [name, group] of Object.entries(areas)) {
    group.name = name;
    root.add(group);
  }
  const landmark = new THREE.Group();
  landmark.name = 'Red clocktower and skyline';
  root.add(landmark);

  let seed = 61727;
  const random = (): number => {
    seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
    return (seed >>> 0) / 4294967296;
  };
  function masonryTexture(bricks: boolean): THREE.CanvasTexture {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 512;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('District wall canvas is unavailable');
    const pixels = ctx.createImageData(512, 512);
    for (let y = 0; y < 512; y++) {
      for (let x = 0; x < 512; x++) {
        const p = (y * 512 + x) * 4;
        const grain = (random() - .5) * 37;
        const rain = Math.sin(x * .047 + Math.sin(y * .02) * 2) * 8;
        const age = Math.sin(x * .014 + y * .009) * 10;
        const value = 206 + grain + rain + age - y / 512 * 22;
        pixels.data[p] = Math.max(0, value);
        pixels.data[p + 1] = Math.max(0, value - (bricks ? 18 : 3));
        pixels.data[p + 2] = Math.max(0, value - (bricks ? 23 : 4));
        pixels.data[p + 3] = 255;
      }
    }
    ctx.putImageData(pixels, 0, 0);
    if (bricks) {
      ctx.strokeStyle = 'rgba(25,21,20,.35)'; ctx.lineWidth = 3;
      for (let row = 0; row < 13; row++) {
        const y = row * 40;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(512, y); ctx.stroke();
        const offset = row % 2 ? 40 : 0;
        for (let x = offset; x < 512; x += 80) {
          ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + 40); ctx.stroke();
        }
      }
    } else {
      ctx.strokeStyle = 'rgba(23,29,28,.22)'; ctx.lineWidth = 2;
      for (let i = 0; i < 19; i++) {
        const x = random() * 512, y = random() * 512;
        ctx.beginPath(); ctx.moveTo(x, y);
        ctx.lineTo(x + random() * 26 - 13, y + 17);
        ctx.lineTo(x + random() * 34 - 17, y + 34 + random() * 38);
        ctx.stroke();
      }
    }
    for (let i = 0; i < 155; i++) {
      const x = random() * 512, y = random() * 512;
      ctx.fillStyle = random() > .48 ? 'rgba(12,20,21,.12)' : 'rgba(247,230,199,.11)';
      ctx.fillRect(x, y, 2 + random() * 16, 4 + random() * 44);
    }
    const texture = ownTex(new THREE.CanvasTexture(canvas));
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(3, 1.5);
    texture.anisotropy = 4;
    return texture;
  }
  function puddleTexture(): THREE.CanvasTexture {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 256;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('District puddle canvas is unavailable');
    ctx.translate(128, 128);
    ctx.beginPath();
    for (let i = 0; i <= 48; i++) {
      const angle = i / 48 * Math.PI * 2;
      const r = 96 + Math.sin(angle * 5) * 9 + Math.sin(angle * 11 + 2) * 7 + Math.sin(angle * 19) * 3;
      const x = Math.cos(angle) * r, y = Math.sin(angle) * r * .75;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.clip();
    const gradient = ctx.createRadialGradient(-17, -12, 8, 0, 0, 110);
    gradient.addColorStop(0, 'rgba(161,188,192,.53)');
    gradient.addColorStop(.6, 'rgba(81,106,114,.33)');
    gradient.addColorStop(1, 'rgba(31,47,52,0)');
    ctx.fillStyle = gradient; ctx.fillRect(-128, -128, 256, 256);
    for (let i = 0; i < 26; i++) {
      const x = -78 + random() * 156;
      const y = -67 + random() * 134;
      ctx.fillStyle = i % 3 ? 'rgba(255,208,143,.09)' : 'rgba(133,226,188,.08)';
      ctx.fillRect(x, y, 9 + random() * 46, .5 + random() * 2);
    }
    const texture = ownTex(new THREE.CanvasTexture(canvas));
    texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
  }
  const plasterMap = masonryTexture(false);
  const brickMap = masonryTexture(true);
  const waterMap = puddleTexture();

  const m = {
    asphalt: ownMat(new THREE.MeshStandardMaterial({ color: 0x657078, roughness: .79, metalness: .05 })),
    shutter: ownMat(new THREE.MeshStandardMaterial({ color: 0x87918d, roughness: .65, metalness: .42 })),
    concrete: ownMat(new THREE.MeshStandardMaterial({ map: plasterMap, color: 0x8a9490, roughness: .94 })),
    pale: ownMat(new THREE.MeshStandardMaterial({ map: plasterMap, color: 0xc1beb0, roughness: .9 })),
    brick: ownMat(new THREE.MeshStandardMaterial({ map: brickMap, color: 0x9b6357, roughness: .91 })),
    blue: ownMat(new THREE.MeshStandardMaterial({ map: plasterMap, color: 0x526f6b, roughness: .79, metalness: .08 })),
    steel: ownMat(new THREE.MeshStandardMaterial({ color: 0x283338, roughness: .51, metalness: .62 })),
    rusty: ownMat(new THREE.MeshStandardMaterial({ color: 0x684a3d, roughness: .76, metalness: .35 })),
    wood: ownMat(new THREE.MeshStandardMaterial({ color: 0x584a36, roughness: .91 })),
    paper: ownMat(new THREE.MeshStandardMaterial({ color: 0xbcb9a0, roughness: .98 })),
    glass: ownMat(new THREE.MeshPhysicalMaterial({ color: 0x6b9a96, roughness: .24, metalness: .18, transparent: true, opacity: .43, depthWrite: false, side: THREE.DoubleSide })),
    puddle: ownMat(new THREE.MeshBasicMaterial({ map: waterMap, transparent: true, opacity: .7, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -1, side: THREE.DoubleSide })),
    red: ownMat(new THREE.MeshStandardMaterial({ color: 0x9b3328, emissive: 0x4b100e, emissiveIntensity: .45, roughness: .76, metalness: .16 })),
    redGlow: ownMat(new THREE.MeshStandardMaterial({ color: 0xf18d68, emissive: 0xc3311d, emissiveIntensity: 1.5, roughness: .3 })),
    clockFace: ownMat(new THREE.MeshStandardMaterial({ color: 0xf4dfbd, emissive: 0xd79b68, emissiveIntensity: 1.5, roughness: .56 })),
    amber: ownMat(new THREE.MeshStandardMaterial({ color: 0xffd49b, emissive: 0xd47638, emissiveIntensity: 1.25, roughness: .31 })),
    green: ownMat(new THREE.MeshStandardMaterial({ color: 0xa9ecc6, emissive: 0x6fd6a2, emissiveIntensity: 1.5, roughness: .32 })),
    dawn: ownMat(new THREE.MeshStandardMaterial({ color: 0xf2b18a, emissive: 0x8f453c, emissiveIntensity: .75, roughness: .52 })),
    can: ownMat(new THREE.MeshStandardMaterial({ color: 0xa5b0a9, roughness: .32, metalness: .66 })),
    fruitOrange: ownMat(new THREE.MeshStandardMaterial({ color: 0xb57b42, roughness: .83 })),
    fruitGreen: ownMat(new THREE.MeshStandardMaterial({ color: 0x658151, roughness: .86 })),
    fruitPale: ownMat(new THREE.MeshStandardMaterial({ color: 0xd2b274, roughness: .85 })),
  };
  await Promise.all([
    installSurface(m.asphalt, 'worn_asphalt', new THREE.Vector2(2.5, 9), ownTex),
    installSurface(m.shutter, 'worn_shutter', new THREE.Vector2(2, 1.3), ownTex),
  ]);

  function box(parent: THREE.Object3D, name: string, x: number, y: number, z: number,
    sx: number, sy: number, sz: number, material: THREE.Material): THREE.Mesh {
    const mesh = new THREE.Mesh(cube, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(sx, sy, sz);
    mesh.receiveShadow = true;
    mesh.castShadow = /frame|post|crate|tower|stair|shelf|awning/i.test(name);
    parent.add(mesh);
    return mesh;
  }
  function flat(parent: THREE.Object3D, name: string, x: number, y: number, z: number,
    sx: number, sz: number, material: THREE.Material): THREE.Mesh {
    const mesh = new THREE.Mesh(plane, material);
    mesh.name = name;
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, y, z);
    mesh.scale.set(sx, sz, 1);
    parent.add(mesh);
    return mesh;
  }
  function round(parent: THREE.Object3D, name: string, x: number, y: number, z: number,
    radius: number, height: number, material: THREE.Material): THREE.Mesh {
    const mesh = new THREE.Mesh(cylinder, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(radius, height, radius);
    mesh.castShadow = true;
    parent.add(mesh);
    return mesh;
  }
  function sign(parent: THREE.Object3D, name: string, words: string, x: number, y: number, z: number,
    width: number, height: number, face: 'front' | 'left' | 'right', background: string, ink: string): void {
    const canvas = document.createElement('canvas');
    canvas.width = 512; canvas.height = 192;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('District sign canvas is unavailable');
    ctx.fillStyle = background; ctx.fillRect(0, 0, 512, 192);
    ctx.strokeStyle = ink; ctx.lineWidth = 6; ctx.strokeRect(12, 12, 488, 168);
    ctx.fillStyle = ink; ctx.font = 'bold 68px "Yu Gothic", "Hiragino Kaku Gothic ProN", sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(words, 256, 96, 462);
    const texture = ownTex(new THREE.CanvasTexture(canvas));
    texture.colorSpace = THREE.SRGBColorSpace;
    const material = ownMat(new THREE.MeshStandardMaterial({ map: texture, emissiveMap: texture,
      emissive: 0xffffff, emissiveIntensity: .22, roughness: .72, side: THREE.DoubleSide }));
    const mesh = new THREE.Mesh(plane, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(width, height, 1);
    if (face === 'left') mesh.rotation.y = -Math.PI / 2;
    if (face === 'right') mesh.rotation.y = Math.PI / 2;
    parent.add(mesh);
  }
  type Fixture = { position: THREE.Vector3; color: number; power: number; range: number; area: DistrictArea };
  const practical: Record<DistrictArea, Fixture[]> = {
    alley: [], store: [], service: [], court: [], roof: [],
  };
  // Four stable lights keep the shader variant unchanged across camera areas.
  const lightPool = Array.from({ length: 4 }, () => {
    const light = new THREE.PointLight(0xffffff, 0, 1, 2);
    light.castShadow = false;
    root.add(light);
    return light;
  });
  function lamp(area: DistrictArea, x: number, y: number, z: number, color: number,
    power: number, range = 11): void {
    practical[area].push({ area, position: new THREE.Vector3(x, y, z), color, power, range });
  }

  // The alley is narrow and quiet. Open ends preserve the turning route and tower sightline.
  flat(landmark,'Connected district ground',12,-.06,-35,100,140,m.asphalt);
  flat(areas.alley, 'Alley wet asphalt', 0, -.025, -5, 8, 30, m.asphalt);
  for (const side of [-1, 1]) {
    const x = side * 5.3;
    box(areas.alley, 'Tall tenement facade', x, 4.4, -.8, 2.7, 8.8, 19, side < 0 ? m.brick : m.concrete);
    box(areas.alley, 'Eave', side * 4.1, 5.7, -.8, .9, .24, 19, m.steel);
    box(areas.alley, 'Weathered facade plinth', side * 3.79, .26, -.8, .17, .52, 19, m.rusty);
    for (const y of [3.76, 5.24, 7.46]) {
      box(areas.alley, 'Facade horizontal seam', side * 3.78, y, -.8, .055, .06, 19, m.steel);
    }
    for (const z of [5.8, .15, -5.5]) {
      box(areas.alley, 'Facade vertical seam', side * 3.78, 4.52, z, .055, 1.46, .06, m.steel);
    }
    for (let i = 0; i < 3; i++) {
      const z = 3 - i * 5.8;
      box(areas.alley, 'Shutter frame', side * 3.91, 2.05, z, .14, 3.9, 3.6, m.steel);
      box(areas.alley, 'Closed metal shutter', side * 3.82, 1.8, z, .055, 3.3, 3.25, m.shutter);
      box(areas.alley, 'Upper window', side * 3.8, 6.1, z, .07, 1.28, 1.3, m.glass);
      box(areas.alley, 'Window crossbar', side * 3.73, 6.1, z, .1, .07, 1.36, m.steel);
      box(areas.alley, 'Window vertical mullion', side * 3.72, 6.1, z, .1, 1.34, .06, m.steel);
      box(areas.alley, 'Window sill', side * 3.65, 5.4, z, .3, .12, 1.57, m.concrete);
      for (const edge of [-.68, .68]) {
        box(areas.alley, 'Window steel frame', side * 3.72, 6.1, z + edge, .1, 1.45, .08, m.steel);
      }
      box(areas.alley, 'Shop shutter sign bracket', side * 3.56, 4.2, z, .48, .09, 2.6, m.steel);
      box(areas.alley, 'Shop shutter sign fascia', side * 3.52, 4.55, z, .4, .62, 2.54,
        i === 1 ? m.red : m.blue);
    }
    box(areas.alley, 'Rain downpipe', side * 3.72, 3.4, -8, .12, 6.8, .12, m.rusty);
    box(areas.alley, 'Overhead utility conduit', side * 3.69, 6.82, -.8, .07, .07, 19, m.steel);
    box(areas.alley, 'Eye-level utility conduit', side * 3.66, 3.54, -.8, .065, .06, 19, m.rusty);
    for (const z of [1.7, -4.1]) {
      box(areas.alley, 'Air conditioner housing', side * 3.41, 4.9, z, .59, .67, 1.08, m.pale);
      box(areas.alley, 'Air conditioner grille', side * 3.07, 4.88, z, .05, .45, .78, m.steel);
      for (let j = -1; j <= 1; j++) {
        box(areas.alley, 'Air conditioner grille slat', side * 3.02, 4.88 + j * .13,
          z, .045, .025, .77, m.can);
      }
    }
    sign(areas.alley, 'Weathered alley wall poster', side < 0 ? '夜間作業中' : 'まもなく閉店',
      side * 3.7, 2.02, .15, 1.03, 1.45, side < 0 ? 'right' : 'left',
      side < 0 ? '#b9b199' : '#315963', side < 0 ? '#363a39' : '#e1d7b6');
    sign(areas.alley, 'Second alley wall poster', side < 0 ? '急がず安全' : '朝市予告',
      side * 3.7, 2.1, -5.65, .98, 1.25, side < 0 ? 'right' : 'left',
      '#b6a68b', '#563b35');
  }
  // Break the eastern facade at the store turn. The last bay stops before the opening.
  box(areas.alley, 'Store approach awning', 6.5, 3.5, -12, 7.5, .18, 2.1, m.red);
  box(areas.alley, 'Store approach illuminated edge', 6.5, 3.31, -11, 7.5, .07, .08, m.green);
  flat(areas.alley, 'Store approach pavement', 6.4, -.018, -12, 13.3, 5.3, m.asphalt);
  sign(areas.alley, 'Grocery wayfinding', '青果・食料品 →', 3.75, 3.08, -10.86, 2.8, .72, 'front', '#153b32', '#b9e8c1');
  box(areas.alley, 'Warm open store jamb', 3.72, 1.45, -10.37, .2, 2.9, .24, m.amber);
  box(areas.alley, 'Warm open store window', 3.64, 1.65, -9.7, .08, 2.5, .88, m.glass);
  box(areas.alley, 'Warm open store back glow', 3.87, 1.65, -9.7, .07, 2.5, .85, m.amber);
  sign(areas.alley, 'Service branch sign', '← 搬入口', -3.45, 3.02, -10.85, 2.25, .66,
    'front', '#e0d6ba', '#373d40');
  for (let i = 0; i < 7; i++) {
    box(areas.service, 'Visible side service stair', -8.2, .12 + i * .21,
      -11.5 - i * .56, 1.7, .24 + i * .42, .57, m.concrete);
  }
  box(areas.service, 'Visible side stair rail', -7.2, 1.5, -13.5, .08, .08, 4.7, m.rusty).rotation.x = -.35;
  for (let i = 0; i < 10; i++) {
    const x = (i % 3 - 1) * 1.1 + .25;
    const z = 3.4 - i * 2.0;
    const wet = flat(areas.alley, 'Irregular rain puddle', x, .004, z, .42 + (i % 3) * .19, 1.15 + (i % 4) * .32, m.puddle);
    wet.rotation.z = i * .53;
  }
  for (const side of [-1, 1]) {
    box(areas.alley, 'Alley curb lip', side * 3.55, .075, -3.1, .16, .14, 18.6, m.concrete);
    for (const z of [1.8, -4.7, -9.2]) {
      box(areas.alley, 'Street drain frame', side * 3.15, .008, z, .52, .016, .72, m.steel);
      for (let j = -2; j <= 2; j++) {
        box(areas.alley, 'Street drain slot', side * 3.15 + j * .082, .02, z,
          .033, .009, .62, m.blue);
      }
    }
  }
  box(areas.alley, 'Left wall lamp shell', -3.55, 3.25, -3, .45, .28, .55, m.steel);
  box(areas.alley, 'Left wall lamp diffuser', -3.48, 3.18, -3, .25, .09, .35, m.amber);
  box(areas.alley, 'Right wall lamp shell', 3.55, 3.3, -8, .45, .28, .55, m.steel);
  box(areas.alley, 'Right wall lamp diffuser', 3.48, 3.23, -8, .25, .09, .35, m.green);
  lamp('alley', -2.8, 3.3, -3, 0xffc587, 24);
  lamp('alley', 3, 3.4, -9, 0x8dcbb3, 19);
  lamp('alley', 8.5, 3, -12, 0x8bdcaa, 15);

  // The grocery's local -Z axis is world +X. Its full-width entrance is open.
  const shop = areas.store;
  shop.position.set(10, 0, -12);
  shop.rotation.y = -Math.PI / 2;
  flat(shop, 'Grocery tile floor', 0, -.012, -6.5, 8.7, 15, m.pale);
  for (let i = 0; i < 15; i++) {
    box(shop, 'Tile grout line', 0, .004, -.4 - i, 8.5, .008, .018, m.concrete);
  }
  for (const side of [-1, 1]) {
    box(shop, 'Grocery wall', side * 4.35, 3.15, -7, .28, 6.3, 14, m.blue);
    box(shop, 'Grocery ceiling rim', side * 4.05, 5.8, -7, .3, .2, 14, m.steel);
    for (let i = 0; i < 3; i++) {
      const z = -2.8 - i * 3.5;
      box(shop, 'Produce shelf', side * 3.4, .62, z, 1.08, 1.05, 2.5, m.wood);
      box(shop, 'Shelf steel toe', side * 3.4, .14, z, 1.12, .16, 2.55, m.steel);
      box(shop, 'Produce crate front', side * 2.85, 1.3, z, .1, .3, 2.5, m.wood);
      box(shop, 'Grocery shelving back', side * 4.09, 2.1, z, .1, 2.2, 2.54, m.steel);
      for (const level of [1.76, 2.5]) {
        box(shop, 'Grocery shelving tier', side * 3.5, level, z, 1.18, .075, 2.55, m.steel);
        for (let j = 0; j < 5; j++) {
          const zz = z - .85 + j * .42;
          box(shop, 'Grocery carton with label', side * 3.45, level + .26, zz,
            .3, .43, .28, (i + j) % 3 === 0 ? m.paper : m.blue);
          box(shop, 'Carton printed label', side * 3.23, level + .28, zz,
            .035, .16, .2, (i + j) % 3 === 0 ? m.red : m.paper);
        }
      }
      for (let j = 0; j < 5; j++) {
        const produce = new THREE.Mesh(fruitShape,
          [m.fruitOrange, m.fruitGreen, m.fruitPale][(i + j) % 3]);
        produce.name = 'Uneven fresh produce pile';
        produce.position.set(side * (3.05 + (j % 2) * .32), 1.15,
          z - .8 + j * .38);
        produce.scale.set(.23, .16, .2);
        shop.add(produce);
      }
      box(shop, 'Shelf price strip', side * 2.81, 1.14, z, .06, .11, 2.5, m.paper);
    }
  }
  // Entrance posts are at the edges, never across the player's line of travel.
  for (const side of [-1, 1]) {
    box(shop, 'Open entrance frame post', side * 4.15, 2.55, .12, .25, 5.1, .28, m.steel);
  }
  box(shop, 'Grocery ceiling', 0, 5.96, -7, 8.5, .18, 14, m.blue);
  box(shop, 'Open entrance header', 0, 5.15, .12, 8.5, .25, .28, m.steel);
  box(shop, 'Grocery green header light', 0, 4.8, .18, 7.7, .12, .08, m.green);
  sign(shop, 'Fictional grocery sign', 'みどり市場', 0, 4.12, .2, 4.5, .98, 'front', '#225044', '#dbefbd');
  for (const z of [-1.5, -5.7, -10]) {
    box(shop, 'Fluorescent housing', 0, 5.6, z, 5.2, .13, .5, m.steel);
    box(shop, 'Fluorescent diffuser', 0, 5.48, z, 4.9, .06, .27, m.green);
  }
  box(shop, 'Cash register counter', -3.1, .78, -12.4, 1.75, 1.35, 1.2, m.wood);
  box(shop, 'Register body', -3.1, 1.6, -12.2, .72, .46, .68, m.steel);
  sign(shop, 'Grocery closing notice', '本日営業中', -4.15, 2.05, -5.8, 1.6, .54, 'left', '#ebe3b9', '#344b39');
  lamp('store', 0, 4.85, -2, 0xb0ffc9, 21, 13);
  lamp('store', 0, 4.85, -8, 0x92e7c1, 22, 13);
  lamp('store', 0, 4.85, -12, 0x8adfbd, 17, 10);

  // A side service route continues straight from the alley into the same open district.
  flat(areas.service, 'Service passage asphalt', -6, -.025, -18, 7, 15, m.asphalt);
  box(areas.service, 'Service west wall', -10.2, 3, -18, .45, 6, 15, m.brick);
  box(areas.service, 'Service east low wall', -2.6, 1.2, -25.5, .35, 2.4, 3, m.concrete);
  flat(areas.service, 'Service rear link pavement', 8.6, -.019, -22, 27, 3.6, m.asphalt);
  for (const x of [0, 7, 14]) {
    box(areas.service, 'Service rear link bollard', x, .49, -23.58, .16, .98, .16, m.rusty);
  }
  for (const z of [-16, -21]) {
    box(areas.service, 'Service loading shutter', -10, 1.8, z, .09, 3.3, 3.2, m.shutter);
    box(areas.service, 'Service shutter frame', -9.9, 2, z, .16, 3.8, 3.5, m.steel);
  }
  box(areas.service, 'Service utility cabinet', -8.9, .95, -24, 1.45, 1.9, .85, m.blue);
  box(areas.service, 'Service lamp hood', -9.4, 3.55, -18, 1.0, .14, .58, m.steel);
  box(areas.service, 'Service lamp glass', -9.35, 3.44, -18, .8, .06, .42, m.amber);
  sign(areas.service, 'Service direction sign', '搬入口', -9.8, 3.1, -20.1, 1.85, .72, 'left', '#333f3d', '#d7d3b6');
  lamp('service', -8.8, 3.6, -18, 0xe5b681, 21);
  lamp('service', -3.5, 3.2, -24, 0x8ab1c7, 14);

  // The grocery exit bends south to an exposed delivery court; no wall closes this route.
  flat(areas.court, 'Grocery-to-court passage', 24, -.02, -21.5, 7.4, 20, m.asphalt);
  flat(areas.court, 'Delivery courtyard asphalt', 24, -.03, -36, 17, 18, m.asphalt);
  for (const x of [16.2, 31.8]) {
    box(areas.court, 'Warehouse side wall', x, 3.6, -34.5, .45, 7.2, 21, x < 20 ? m.brick : m.concrete);
    for (let i = 0; i < 3; i++) {
      const z = -27 - i * 6.4;
      box(areas.court, 'Warehouse loading door', x + (x < 20 ? .3 : -.3), 1.7, z, .09, 3.3, 3.5, m.shutter);
      box(areas.court, 'Warehouse awning', x + (x < 20 ? .9 : -.9), 3.5, z, 1.4, .16, 4, m.steel);
      box(areas.court, 'High warehouse window', x + (x < 20 ? .3 : -.3), 5.4, z, .07, 1.08, 1.5, m.glass);
    }
  }
  box(areas.court, 'Court loading dock', 18.2, .38, -38.5, 2.1, .75, 4.7, m.concrete);
  box(areas.court, 'Court forklift silhouette chassis', 19, .55, -42.4, 1.9, .8, 2.3, m.rusty);
  box(areas.court, 'Court forklift silhouette mast', 18.3, 1.45, -42.4, .16, 2.1, 1.6, m.steel);
  for (const z of [-41.6, -43.2]) round(areas.court, 'Forklift tire', 19.6, .36, z, .38, .3, m.steel);
  sign(areas.court, 'Fictional delivery marker', '朝便 集荷場', 31.49, 4.2, -31, 2.6, .78, 'left', '#6e3a2e', '#f2d1a0');
  for (let i = 0; i < 7; i++) {
    const x = 17.5 + (i % 2) * 12.8;
    const z = -29 + i * -1.8;
    flat(areas.court, 'Courtyard pooled rain', x, .008, z, 1.1 + (i % 3) * .4, 1.3, m.puddle);
  }
  box(areas.court, 'Court lamp crossbar', 18, 5.8, -32, 1.8, .12, .15, m.steel);
  box(areas.court, 'Court amber light', 18.8, 5.67, -32, .55, .07, .34, m.amber);
  box(areas.court, 'Court lamp crossbar', 30, 5.8, -39, 1.8, .12, .15, m.steel);
  box(areas.court, 'Court cold light', 29.2, 5.67, -39, .55, .07, .34, m.green);
  lamp('court', 18.7, 5.6, -31.5, 0xf6b47e, 28, 14);
  lamp('court', 29.2, 5.6, -39, 0x89ccb6, 25, 14);
  lamp('court', 24, 7.8, -45, 0xe6a48a, 11, 15);

  // Reusable, local rigid props react to a kill ray; they never block the combat lane.
  type LooseProp = { mesh: THREE.Mesh; home: THREE.Vector3; velocity: THREE.Vector3;
    spin: THREE.Vector3; active: boolean; age: number; radius: number };
  const loose: LooseProp[] = [];
  for (let i = 0; i < 8; i++) {
    const side = i % 2 ? 1 : -1;
    const x = i === 7 ? 30.3 : 24 + side * (4.5 + (i % 3) * .72);
    const z = i === 7 ? -35.8 : -29 - Math.floor(i / 2) * 3.2;
    const isCan = i % 3 === 0;
    const mesh = isCan
      ? round(areas.court, 'Loose delivery can', x, .28, z, .2, .46, m.can)
      : box(areas.court, 'Loose delivery crate', x, .38, z, .82, .75, .78, i % 2 ? m.wood : m.blue);
    if (!isCan) {
      box(mesh, 'Crate side slat', 0, .2, .505, .85, .1, .045, m.rusty);
      box(mesh, 'Crate side slat', 0, -.2, .505, .85, .1, .045, m.rusty);
    }
    loose.push({ mesh, home: mesh.position.clone(), velocity: new THREE.Vector3(),
      spin: new THREE.Vector3(), active: false, age: 0, radius: isCan ? .5 : .83 });
  }

  // Exposed stairs climb the eastern edge. The roof deck starts at y=7.
  for (const z of [-46.5, -49.3]) {
    box(areas.roof, 'Stair landing support post', 29.8, 3.5, z, .45, 7, .45, m.concrete);
  }
  for (let i = 0; i < 14; i++) {
    const z = -39.2 - i * .65;
    const height = (i + 1) * .5;
    box(areas.roof, 'Visible service stair tread', 27.1, height, z, 2.65, .19, .66, m.steel);
    box(areas.roof, 'Stair right baluster', 28.55, height + .65, z, .08, 1.3, .08, m.rusty);
  }
  for(const x of [25.72,28.48]) {
    const beam=box(areas.roof,'Stair diagonal stringer',x,3.53,-43.425,.18,.28,10.7,m.steel);
    beam.rotation.x=.655;
  }
  box(areas.roof, 'Stair handrail', 28.55, 4.35, -43.5, .1, .11, 9.5, m.rusty).rotation.x = -.63;
  flat(areas.roof, 'Rooftop deck', 24, 7.01, -59.5, 16.5, 26, m.concrete);
  flat(areas.roof, 'Rooftop damp patch', 24, 7.027, -56, 4, 2.1, m.puddle);
  box(areas.roof, 'Rooftop left parapet', 15.7, 7.65, -59.5, .5, 1.3, 26, m.brick);
  box(areas.roof, 'Rooftop right parapet', 32.3, 7.65, -59.5, .5, 1.3, 26, m.brick);
  // The forward edge has a low rail so the clocktower remains visible.
  for (const x of [17, 20.5, 24, 27.5, 31]) {
    box(areas.roof, 'Rooftop forward rail post', x, 7.78, -72.2, .09, 1.55, .09, m.steel);
  }
  box(areas.roof, 'Rooftop forward handrail', 24, 8.5, -72.2, 15, .09, .09, m.steel);
  box(areas.roof, 'Rooftop water tank stand', 30, 7.9, -61, 2.1, 1.6, 2.1, m.steel);
  round(areas.roof, 'Rooftop water tank', 30, 9.4, -61, 1.16, 1.7, m.blue);
  box(areas.roof, 'Rooftop stairwell house', 18.2, 8.55, -55.7, 3.3, 3.1, 3.2, m.brick);
  box(areas.roof, 'Rooftop stairwell door frame', 18.2, 8.2, -53.99, 1.45, 2.3, .12, m.steel);
  box(areas.roof, 'Rooftop stairwell door', 18.2, 8.18, -53.9, 1.23, 2.13, .08, m.blue);
  round(areas.roof, 'Stairwell door handle', 18.69, 8.12, -53.82, .05, .1, m.can);
  for (let i = 0; i < 3; i++) {
    box(areas.roof, 'Rooftop access stair', 18.2, 7.12 + i * .11, -52.8 - i * .38,
      1.8, .22 + i * .22, .38, m.concrete);
  }
  for (const z of [-63, -68]) {
    box(areas.roof, 'Roof ventilation housing', 17.6, 7.65, z, 1.1, 1.25, 1.3, m.steel);
    box(areas.roof, 'Roof vent cowl', 17.6, 8.32, z, 1.4, .22, 1.4, m.rusty);
  }
  lamp('roof', 30, 9.6, -60, 0xe6ac8b, 12, 11);
  lamp('roof', 18, 8.7, -68, 0xe8ac8c, 10, 12);

  // A red silhouette and legible clock face repeat from street level to the dawn vista.
  box(landmark, 'Clocktower main red shaft', 15, 10, -85, 4.6, 20, 4.6, m.red);
  for (const x of [12.85, 17.15]) {
    box(landmark, 'Clocktower vertical red rib', x, 10.2, -82.64, .13, 19.5, .1, m.redGlow);
  }
  for (const y of [5.5, 10.5, 15.5]) {
    box(landmark, 'Clocktower lit shaft window', 15, y, -82.64, 1.2, 1.25, .09, m.amber);
  }
  for (const y of [5, 10, 15, 19]) box(landmark, 'Clocktower cornice', 15, y, -85, 5.1, .22, 5.1, m.rusty);
  box(landmark, 'Clocktower clock head', 15, 22, -85, 5.7, 4.4, 5.7, m.red);
  box(landmark, 'Clocktower clock surround', 15, 22, -82.12, 4.15, 4.08, .14, m.redGlow);
  box(landmark, 'Clocktower roof', 15, 24.5, -85, 6.4, .8, 6.4, m.steel);
  box(landmark, 'Clocktower beacon base', 15, 25.35, -85, 1.6, .9, 1.6, m.red);
  round(landmark, 'Clocktower red beacon', 15, 26.1, -85, .35, .55, m.redGlow);
  const face = new THREE.Mesh(disc, m.clockFace);
  face.name = 'Clocktower illuminated dial';
  face.position.set(15, 22, -82.1);
  face.scale.set(1.66, 1.66, 1);
  landmark.add(face);
  for (let i = 0; i < 12; i++) {
    const theta = i / 12 * Math.PI * 2;
    const tick = box(landmark, 'Clock hour index', 15 + Math.sin(theta) * 1.36,
      22 + Math.cos(theta) * 1.36, -82.02, .09, .23, .07, m.red);
    tick.rotation.z = -theta;
  }
  const hour = box(landmark, 'Clock short hand', 15.25, 22.35, -81.98, .09, .9, .07, m.steel);
  hour.rotation.z = -.58;
  const minute = box(landmark, 'Clock long hand', 14.7, 22.46, -81.94, .075, 1.2, .07, m.steel);
  minute.rotation.z = .57;
  for (let i = 0; i < 12; i++) {
    const x = -21 + i * 6.9;
    const h = 7 + (i * 7 % 8);
    const z = -102 - (i % 3) * 5;
    box(landmark, 'Dawn distant skyline building', x, h / 2 + 1, z, 5.3, h, 5.8, i % 3 ? m.blue : m.brick);
    for (let j = 0; j < 2; j++) {
      box(landmark, 'Sparse skyline lit window', x - 1.3 + j * 2.6,
        3 + (i % 3) * 1.3, z + 2.94, .5, .72, .07, i % 4 ? m.amber : m.green);
    }
  }

  const previousFog = scene.fog;
  const previousBackground = scene.background;
  const fog = new THREE.FogExp2(0x17252a, .018);
  const background = new THREE.Color(0x17252a);
  scene.fog = fog;
  const skyCanvas=document.createElement('canvas');skyCanvas.width=2;skyCanvas.height=128;
  const skyContext=skyCanvas.getContext('2d')!;
  const sky=new THREE.CanvasTexture(skyCanvas);sky.colorSpace=THREE.SRGBColorSpace;textures.add(sky);
  scene.background=sky;
  let skyArea='';
  let lastTime = 0;
  let lastArea: DistrictArea = 'alley';
  const ray = new THREE.Ray();
  const nearest = new THREE.Vector3();
  function reset(): void {
    lastTime = 0;
    lastArea = 'alley';
    for (const prop of loose) {
      prop.mesh.position.copy(prop.home);
      prop.mesh.rotation.set(0, 0, 0);
      prop.velocity.set(0, 0, 0);
      prop.spin.set(0, 0, 0);
      prop.active = false;
      prop.age = 0;
    }
  }
  function update(time: number, area: DistrictArea, motion: boolean): void {
    const dt = Math.max(0, Math.min(.05, time - lastTime));
    lastTime = time;
    lastArea = area;
    const palette: Record<DistrictArea, [number, number]> = {
      alley: [0x16252c, .015], store: [0x132920, .012], service: [0x1b252a, .016],
      court: [0x263039, .013], roof: [0x60494a, .008],
    };
    background.setHex(palette[area][0]);
    fog.color.copy(background);
    if(skyArea!==area){
      skyArea=area;const gradient=skyContext.createLinearGradient(0,0,0,128);
      gradient.addColorStop(0,area==='roof'?'#293b57':'#071117');
      gradient.addColorStop(.65,area==='roof'?'#a07683':'#192b32');
      gradient.addColorStop(1,area==='roof'?'#e7b48a':'#354047');
      skyContext.fillStyle=gradient;skyContext.fillRect(0,0,2,128);sky.needsUpdate=true;
    }
    fog.density = palette[area][1];
    const selected = area === 'alley'
      ? [...practical.alley, practical.store[0]]
      : practical[area];
    for (let index = 0; index < lightPool.length; index++) {
      const light = lightPool[index];
      const fixture = selected[index];
      if (!fixture) {
        light.intensity = 0;
        continue;
      }
      light.position.copy(areas[fixture.area].localToWorld(fixture.position.clone()));
      light.color.setHex(fixture.color);
      light.distance = fixture.range;
      light.intensity = fixture.power * (motion ? 1 + Math.sin(time * .67 + index * 1.7) * .018 : 1);
    }
    // Slow, bounded travel after impact. Reduced motion holds props at rest.
    if (motion) {
      for (const prop of loose) {
        if (!prop.active) continue;
        prop.age += dt;
        prop.velocity.y -= 13 * dt;
        prop.mesh.position.addScaledVector(prop.velocity, dt);
        prop.mesh.rotation.x += prop.spin.x * dt;
        prop.mesh.rotation.z += prop.spin.z * dt;
        const floorY = prop.home.y;
        if (prop.mesh.position.y < floorY) {
          prop.mesh.position.y = floorY;
          prop.velocity.y = Math.abs(prop.velocity.y) > .7 ? -prop.velocity.y * .25 : 0;
          prop.velocity.x *= .78;
          prop.velocity.z *= .78;
          prop.spin.multiplyScalar(.76);
        }
        if (prop.age > 3.8) prop.active = false;
      }
    }
  }
  function strike(origin: THREE.Vector3, direction: THREE.Vector3): boolean {
    if (lastArea !== 'court' || direction.lengthSq() < .000001) return false;
    ray.set(origin, direction.clone().normalize());
    let hit: LooseProp | undefined;
    let bestDistance = Infinity;
    for (const prop of loose) {
      ray.closestPointToPoint(prop.mesh.position, nearest);
      const distance = origin.distanceTo(nearest);
      if (distance > 13 || distance >= bestDistance) continue;
      if (nearest.distanceTo(prop.mesh.position) > prop.radius + .45) continue;
      bestDistance = distance;
      hit = prop;
    }
    if (!hit) return false;
    const outward = hit.mesh.position.clone().sub(origin).setY(0).normalize();
    hit.velocity.set(outward.x * 2.4 + direction.x, 3.5, outward.z * 2.4 + direction.z);
    hit.spin.set(1.4 + bestDistance * .08, 0, -1.8);
    hit.active = true;
    hit.age = 0;
    return true;
  }
  update(0, 'alley', false);
  return {
    update,
    strike,
    reset,
    dispose(): void {
      scene.remove(root);
      for (const texture of textures) texture.dispose();
      for (const material of materials) material.dispose();
      for (const geometry of geometries) geometry.dispose();
      if (scene.fog === fog) scene.fog = previousFog;
      if (scene.background === sky) scene.background = previousBackground;
    },
  };
}
