import * as THREE from 'three';

/** The camera travels along -Z. The clear combat lane is approximately x=-2.8…2.8. */
export interface ArcadeEnvironment {
  update(time: number, level: number): void;
  dispose(): void;
}

const TAU = Math.PI * 2;
const BAY = 6.4;
const BAY_COUNT = 12;
const START_Z = 6.5;
const END_Z = START_Z - BAY * BAY_COUNT;

function random(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function canvasTexture(canvas: HTMLCanvasElement, repeatX = 1, repeatY = 1): THREE.CanvasTexture {
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(repeatX, repeatY);
  texture.anisotropy = 4;
  return texture;
}

function makeCanvas(width: number, height: number): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('商店街のテクスチャを作成できません');
  return [canvas, context];
}

function noiseTexture(kind: 'asphalt' | 'wall' | 'metal' | 'roof'): THREE.CanvasTexture {
  const size = 512;
  const [canvas, ctx] = makeCanvas(size, size);
  const image = ctx.createImageData(size, size);
  const next = random(kind === 'asphalt' ? 778 : kind === 'wall' ? 191 : kind === 'metal' ? 48 : 81);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      const grain = (next() - .5) * (kind === 'asphalt' ? 42 : 31);
      const streak = kind === 'metal' ? Math.sin(y * .14) * 7 : 0;
      const blotch = Math.sin(x * .031 + y * .017) * Math.sin(y * .051) * 7;
      let base: [number, number, number];
      if (kind === 'asphalt') base = [34, 43, 48];
      else if (kind === 'wall') base = [91, 87, 77];
      else if (kind === 'metal') base = [65, 73, 76];
      else base = [38, 67, 76];
      const value = grain + blotch + streak;
      image.data[i] = Math.max(0, base[0] + value);
      image.data[i + 1] = Math.max(0, base[1] + value);
      image.data[i + 2] = Math.max(0, base[2] + value);
      image.data[i + 3] = 255;
    }
  }
  ctx.putImageData(image, 0, 0);
  if (kind === 'asphalt') {
    const grit = random(291);
    for (let i = 0; i < 14000; i++) {
      ctx.fillStyle = grit() > .66 ? 'rgba(137,150,148,.2)' : 'rgba(2,8,12,.29)';
      ctx.fillRect(grit() * size, grit() * size, 1 + grit() * 2, 1 + grit() * 2);
    }
    ctx.strokeStyle = 'rgba(12,19,22,.36)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(181, 0); ctx.lineTo(184, 122); ctx.lineTo(218, 204); ctx.lineTo(202, 304);
    ctx.moveTo(397, 312); ctx.lineTo(382, 401); ctx.lineTo(418, 512);
    ctx.stroke();
  }
  if (kind === 'metal') {
    for (let y = 0; y < size; y += 24) {
      ctx.fillStyle = 'rgba(9,16,20,.72)'; ctx.fillRect(0, y, size, 3);
      ctx.fillStyle = 'rgba(186,194,189,.17)'; ctx.fillRect(0, y + 4, size, 2);
      ctx.fillStyle = 'rgba(9,12,14,.24)'; ctx.fillRect(0, y + 20, size, 3);
    }
  }
  if (kind === 'wall') {
    const stains = random(317);
    for (let i = 0; i < 160; i++) {
      ctx.fillStyle = stains() > .7 ? 'rgba(204,188,151,.07)' : 'rgba(9,17,20,.08)';
      ctx.fillRect(stains() * size, stains() * size, stains() * 11 + 2, stains() * 95 + 9);
    }
  }
  return canvasTexture(canvas);
}

function signTexture(lines: string[], tone: 'cream' | 'red' | 'blue' | 'dark', vertical = false): THREE.CanvasTexture {
  const [canvas, ctx] = makeCanvas(vertical ? 256 : 1024, vertical ? 768 : 256);
  const w = canvas.width, h = canvas.height;
  const palette = {
    cream: ['#d4bd8d', '#292927', '#5c3c27'],
    red: ['#6b2324', '#f5e7c5', '#f0b96a'],
    blue: ['#193946', '#e7e1c8', '#92dce8'],
    dark: ['#23252a', '#e2c99c', '#b17749'],
  }[tone];
  ctx.fillStyle = palette[0]; ctx.fillRect(0, 0, w, h);
  const grime = random(lines.join('').length * 71 + tone.length);
  for (let i = 0; i < 1200; i++) {
    ctx.fillStyle = grime() > .55 ? 'rgba(0,0,0,.07)' : 'rgba(255,245,220,.045)';
    ctx.fillRect(grime() * w, grime() * h, grime() * 25 + 2, grime() * 8 + 1);
  }
  ctx.strokeStyle = palette[2]; ctx.lineWidth = vertical ? 7 : 6;
  ctx.strokeRect(13, 13, w - 26, h - 26);
  ctx.strokeStyle = 'rgba(0,0,0,.2)'; ctx.lineWidth = 2;
  ctx.strokeRect(23, 23, w - 46, h - 46);
  ctx.fillStyle = palette[1];
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  if (vertical) {
    const chars = [...lines.join('')];
    ctx.font = 'bold 62px "Yu Mincho", "Hiragino Mincho ProN", serif';
    chars.forEach((letter, index) => ctx.fillText(letter, w / 2, 91 + index * Math.min(82, 570 / Math.max(1, chars.length - 1))));
  } else {
    ctx.font = `bold ${lines[0].length > 8 ? 62 : 79}px "Yu Mincho", "Hiragino Mincho ProN", serif`;
    ctx.fillText(lines[0], w / 2, lines.length > 1 ? 108 : 128, w - 70);
    if (lines.length > 1) {
      ctx.font = '35px "Yu Gothic", "Hiragino Kaku Gothic ProN", sans-serif';
      ctx.fillText(lines[1], w / 2, 192, w - 80);
    }
  }
  return canvasTexture(canvas);
}

function posterTexture(seed: number): THREE.CanvasTexture {
  const [canvas, ctx] = makeCanvas(256, 384);
  const next = random(seed);
  ctx.fillStyle = seed % 2 ? '#a9a691' : '#57727b'; ctx.fillRect(0, 0, 256, 384);
  ctx.fillStyle = seed % 2 ? '#41302a' : '#f3e7cc';
  ctx.font = 'bold 36px "Yu Mincho", serif'; ctx.textAlign = 'center';
  ctx.fillText(seed % 2 ? '歳末大売出し' : '商店街案内', 128, 64, 230);
  ctx.fillStyle = seed % 2 ? '#9a3b32' : '#d6b874';
  ctx.beginPath(); ctx.arc(128, 182, 74, 0, TAU); ctx.fill();
  ctx.fillStyle = '#eee2ca'; ctx.font = 'bold 58px serif';
  ctx.fillText(seed % 2 ? '半額' : '夜市', 128, 197);
  for (let i = 0; i < 65; i++) {
    ctx.fillStyle = `rgba(25,24,22,${next() * .15})`;
    ctx.fillRect(next() * 256, next() * 384, next() * 19 + 1, next() * 25 + 1);
  }
  ctx.strokeStyle = '#4c4c46'; ctx.lineWidth = 4; ctx.strokeRect(8, 8, 240, 368);
  return canvasTexture(canvas);
}

export async function createEnvironment(scene: THREE.Scene): Promise<ArcadeEnvironment> {
  const root = new THREE.Group();
  root.name = 'Midnight shopping arcade';
  scene.add(root);
  const ownedTextures = new Set<THREE.Texture>();
  const ownedMaterials = new Set<THREE.Material>();
  const ownedGeometries = new Set<THREE.BufferGeometry>();
  const ownTexture = <T extends THREE.Texture>(texture: T): T => { ownedTextures.add(texture); return texture; };
  const ownMaterial = <T extends THREE.Material>(material: T): T => { ownedMaterials.add(material); return material; };
  const ownGeometry = <T extends THREE.BufferGeometry>(geometry: T): T => { ownedGeometries.add(geometry); return geometry; };
  const unitBox = ownGeometry(new THREE.BoxGeometry(1, 1, 1));
  const unitPlane = ownGeometry(new THREE.PlaneGeometry(1, 1));
  const cylinder = ownGeometry(new THREE.CylinderGeometry(1, 1, 1, 10));
  const asphalt = ownTexture(noiseTexture('asphalt'));
  asphalt.repeat.set(2.2, 18);
  const wallTexture = ownTexture(noiseTexture('wall'));
  const shutterTexture = ownTexture(noiseTexture('metal'));
  const roofTexture = ownTexture(noiseTexture('roof'));
  const mat = {
    road: ownMaterial(new THREE.MeshStandardMaterial({ map: asphalt, color: 0xb9c6ca, roughness: .55, metalness: .08 })),
    wall: ownMaterial(new THREE.MeshStandardMaterial({ map: wallTexture, color: 0xb6b2a8, roughness: .91 })),
    shutter: ownMaterial(new THREE.MeshStandardMaterial({ map: shutterTexture, color: 0x9caaa9, roughness: .61, metalness: .48, side: THREE.DoubleSide })),
    steel: ownMaterial(new THREE.MeshStandardMaterial({ color: 0x33424a, metalness: .72, roughness: .4 })),
    darkSteel: ownMaterial(new THREE.MeshStandardMaterial({ color: 0x18242a, metalness: .64, roughness: .46 })),
    rusty: ownMaterial(new THREE.MeshStandardMaterial({ color: 0x655249, metalness: .52, roughness: .76 })),
    concrete: ownMaterial(new THREE.MeshStandardMaterial({ color: 0x555e5b, roughness: .89 })),
    warm: ownMaterial(new THREE.MeshStandardMaterial({ color: 0xffd391, emissive: 0xffa532, emissiveIntensity: 1.65, roughness: .38 })),
    cold: ownMaterial(new THREE.MeshStandardMaterial({ color: 0xbeeaff, emissive: 0x3eabec, emissiveIntensity: 1.7, roughness: .38 })),
    black: ownMaterial(new THREE.MeshStandardMaterial({ color: 0x11191b, roughness: .84 })),
    puddle: ownMaterial(new THREE.MeshPhysicalMaterial({ color: 0x172025, metalness: .06, roughness: .27, clearcoat: .9, clearcoatRoughness: .14, transparent: true, opacity: .24, depthWrite: false, side: THREE.DoubleSide })),
  };

  function box(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, material: THREE.Material, rotationY = 0): THREE.Mesh {
    const mesh = new THREE.Mesh(unitBox, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(sx, sy, sz);
    mesh.rotation.y = rotationY;
    mesh.castShadow = false;
    mesh.receiveShadow = true;
    root.add(mesh);
    return mesh;
  }
  function plane(name: string, x: number, y: number, z: number, width: number, height: number, material: THREE.Material, rotationY = 0): THREE.Mesh {
    const mesh = new THREE.Mesh(unitPlane, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(width, height, 1);
    mesh.rotation.y = rotationY;
    root.add(mesh);
    return mesh;
  }
  function tube(name: string, points: THREE.Vector3[], radius: number, material: THREE.Material, segments = 18): THREE.Mesh {
    const geometry = ownGeometry(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), segments, radius, 5, false));
    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = name;
    root.add(mesh);
    return mesh;
  }
  function cylinderAt(name: string, x: number, y: number, z: number, radius: number, height: number, material: THREE.Material): THREE.Mesh {
    const mesh = new THREE.Mesh(cylinder, material);
    mesh.name = name;
    mesh.position.set(x, y, z);
    mesh.scale.set(radius, height, radius);
    root.add(mesh);
    return mesh;
  }

  // Rough mineral road, inset gutter and repeated curb stones. Wet areas stay
  // close to the asphalt tone; broken narrow glints carry the reflected light.
  const road = new THREE.Mesh(ownGeometry(new THREE.PlaneGeometry(9.4, 83)), mat.road);
  road.name = 'Wet asphalt'; road.rotation.x = -Math.PI / 2;
  road.position.set(0, -.02, (START_Z + END_Z) / 2);
  road.receiveShadow = true; root.add(road);
  for (const side of [-1, 1]) {
    box('Raised sidewalk', side * 4.17, .045, (START_Z + END_Z) / 2, 1.1, .17, 83, mat.concrete);
    box('Granite gutter', side * 3.47, .024, (START_Z + END_Z) / 2, .11, .07, 83, mat.darkSteel);
    for (let i = 0; i < 40; i++) {
      const z = START_Z + 1 - i * 2;
      box('Curb stone seam', side * 3.78, .144, z, .02, .012, 1.92, mat.rusty);
    }
  }
  const puddleRng = random(4127);
  const wetWarm = ownMaterial(new THREE.MeshBasicMaterial({ color: 0xae8e66, transparent: true, opacity: .19, depthWrite: false }));
  const wetCold = ownMaterial(new THREE.MeshBasicMaterial({ color: 0x6c9fac, transparent: true, opacity: .13, depthWrite: false }));
  for (let i = 0; i < 43; i++) {
    const x = (puddleRng() - .5) * 6.8;
    const z = START_Z - puddleRng() * 74;
    const rx = .06 + puddleRng() * .23;
    const rz = .32 + puddleRng() * 1.2;
    const shape = new THREE.Shape();
    const sides = 9;
    for (let j = 0; j < sides; j++) {
      const angle = (j / sides) * TAU;
      const wobble = .38 + puddleRng() * .87;
      const px = Math.cos(angle) * rx * wobble;
      const py = Math.sin(angle) * rz * wobble;
      if (j === 0) shape.moveTo(px, py); else shape.lineTo(px, py);
    }
    shape.closePath();
    const mesh = new THREE.Mesh(ownGeometry(new THREE.ShapeGeometry(shape)), mat.puddle);
    mesh.name = 'Thin wet asphalt patch';
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, -.015 + i * .00001, z);
    root.add(mesh);
    if (i < 36) {
      const tint = i % 4 === 1 ? wetCold : wetWarm;
      for (let piece = 0; piece < 2; piece++) {
        box('Broken shop-light reflection', x + (puddleRng() - .5) * rx,
          -.011 + i * .00001, z + (puddleRng() - .5) * rz,
          .009 + puddleRng() * .025, .0015, .12 + puddleRng() * rz * .55, tint);
      }
    }
  }
  for (const z of [1.7, -10.8, -23.6, -37.3, -52.6]) {
    box('Recessed drainage grate', -3.35, .025, z, .39, .014, .82, mat.black);
    for (let slot = 0; slot < 7; slot++) {
      box('Drain grille bar', -3.35, .035, z - .32 + slot * .106, .36, .014, .019, mat.rusty);
    }
  }
  for (const [x, z] of [[.9, -6.4], [-1.5, -32.1], [1.3, -56.9]] as const) {
    cylinderAt('Circular road manhole', x, .014, z, .36, .014, mat.rusty);
    for (let spoke = 0; spoke < 4; spoke++) {
      const a = spoke * Math.PI / 4;
      box('Manhole crosshatch', x, .024, z, .016, .005, .56, mat.darkSteel, a);
    }
  }

  // Steel-and-translucent-glass canopy. Each rib has two vertical columns,
  // sloping knees and a true arched tube at the top.
  const roofMaterial = ownMaterial(new THREE.MeshPhysicalMaterial({ map: roofTexture, color: 0x87a8aa, metalness: .18, roughness: .38, transparent: true, opacity: .67, side: THREE.DoubleSide, depthWrite: false }));
  const roofArc = (z: number) => {
    const points: THREE.Vector3[] = [];
    for (let i = 0; i <= 16; i++) {
      const x = -4.55 + i * (9.1 / 16);
      const t = x / 4.55;
      points.push(new THREE.Vector3(x, 5.55 + 1.72 * (1 - t * t), z));
    }
    return points;
  };
  for (let i = 0; i <= 15; i++) {
    const z = START_Z - i * 5.1;
    for (const side of [-1, 1]) {
      box('Arcade steel column', side * 4.5, 2.95, z, .16, 5.9, .19, mat.darkSteel);
      tube('Canopy knee bracket', [
        new THREE.Vector3(side * 4.55, 4.58, z),
        new THREE.Vector3(side * 4.04, 5.58, z),
        new THREE.Vector3(side * 3.16, 6.42, z),
      ], .05, mat.steel, 9);
      cylinderAt('Column footing', side * 4.5, .18, z, .17, .36, mat.rusty);
    }
    tube('Curved transverse roof truss', roofArc(z), .075, mat.steel, 32);
    if (i < 15) {
      // Panels are individually modelled, so light and silhouettes change with depth.
      for (let j = 0; j < 8; j++) {
        const x0 = -4.55 + j * 1.1375;
        const x1 = x0 + 1.1375;
        const y0 = 5.55 + 1.72 * (1 - (x0 / 4.55) ** 2);
        const y1 = 5.55 + 1.72 * (1 - (x1 / 4.55) ** 2);
        const geometry = ownGeometry(new THREE.BufferGeometry());
        geometry.setAttribute('position', new THREE.Float32BufferAttribute([
          x0, y0, z - .08, x1, y1, z - .08, x0, y0, z - 5.02,
          x1, y1, z - .08, x1, y1, z - 5.02, x0, y0, z - 5.02,
        ], 3));
        geometry.setAttribute('uv', new THREE.Float32BufferAttribute([
          0, 0, 1, 0, 0, 1,
          1, 0, 1, 1, 0, 1,
        ], 2));
        geometry.computeVertexNormals();
        const panel = new THREE.Mesh(geometry, roofMaterial);
        panel.name = 'Weathered translucent roof panel'; root.add(panel);
      }
    }
  }
  for (const x of [-4.4, -3.1, 0, 3.1, 4.4]) {
    tube('Longitudinal roof purlin', [
      new THREE.Vector3(x, 5.55 + 1.72 * (1 - (x / 4.55) ** 2), START_Z),
      new THREE.Vector3(x, 5.55 + 1.72 * (1 - (x / 4.55) ** 2), END_Z),
    ], x === 0 ? .055 : .038, mat.darkSteel, 40);
  }

  const shopNames = [
    ['まごころの でんき屋', '家電・修理'], ['山田電器', '街の電気屋'],
    ['古本 月灯', '本と雑誌'], ['喫茶 アケボノ', '珈琲・軽食'],
    ['日暮商店', '青果・雑貨'], ['きもの ときわ', '和装小物'],
    ['二丁目写真館', '現像・証明写真'], ['洋品 オリオン', '衣料品'],
    ['金物 のぞみ', '道具と鍵'], ['時計 はるか', '修理承ります'],
    ['おかし 天の川', '菓子・駄菓子'], ['魚屋 まつ波', '鮮魚'],
  ];
  const signTones: ('cream' | 'red' | 'blue' | 'dark')[] = ['cream', 'blue', 'dark', 'red'];
  const signs = shopNames.map((name, index) => ownTexture(signTexture(name, signTones[index % 4])));
  const posterA = ownTexture(posterTexture(3));
  const posterB = ownTexture(posterTexture(8));
  const hangingSign = ownTexture(signTexture(['みやこ通り商店街', 'また、あしたも'], 'cream'));
  const fabricBanner = ownTexture(signTexture(['生きてるかまだ。'], 'red', true));
  const verticalSign = ownTexture(signTexture(['営業中'], 'blue', true));
  const signMaterials = signs.map((map, index) => ownMaterial(new THREE.MeshStandardMaterial({
    map, emissiveMap: map, emissive: index % 4 === 1 ? 0x1a9ac7 : 0xd09955,
    emissiveIntensity: index % 4 === 1 ? .7 : .37,
    metalness: .1, roughness: .63, side: THREE.DoubleSide,
  })));
  const posterMaterials = [posterA, posterB].map(map => ownMaterial(new THREE.MeshStandardMaterial({ map, roughness: .96, side: THREE.DoubleSide })));

  for (let bay = 0; bay < BAY_COUNT; bay++) {
    const z = START_Z - (bay + .5) * BAY;
    for (const side of [-1, 1]) {
      const inward = side === -1 ? Math.PI / 2 : -Math.PI / 2;
      const n = (bay + (side === 1 ? 3 : 0)) % signs.length;
      box('Stained plaster building facade', side * 4.75, 3.15, z, .46, 6.3, BAY - .04, mat.wall);
      box('Shop dark recess', side * 4.47, 1.52, z, .06, 2.86, 5.64, mat.black);
      plane('Corrugated steel shop shutter', side * 4.431, 1.51, z, 5.53, 2.75, mat.shutter, inward);
      box('Rolled shutter housing', side * 4.39, 3.04, z, .29, .32, 5.72, mat.rusty);
      for (const dz of [-2.85, 2.85]) {
        box('Shop jamb', side * 4.38, 1.68, z + dz, .29, 3.34, .14, mat.darkSteel);
      }
      box('Marquee frame', side * 4.35, 3.77, z, .22, .82, 5.82, mat.darkSteel);
      plane('Aged Japanese shop sign', side * 4.215, 3.78, z, 5.43, .66, signMaterials[n], inward);
      box('Marquee rain gutter', side * 4.25, 4.25, z, .62, .1, 5.9, mat.rusty);
      box('Store awning lip', side * 3.99, 3.38, z, .56, .08, 5.7, mat.steel);
      if (bay % 2 === 0) box('Light grazing the shop sign', side * 4.065, 4.16, z, .045, .035, 4.66, bay % 4 ? mat.cold : mat.warm);
      // Sill lamps and shop notices set their own rhythm in the near and mid ground.
      if (bay % 2 === 0) {
        box('Warm wall lamp bracket', side * 4.16, 3.03, z + 2.31, .45, .06, .08, mat.darkSteel);
        box('Warm wall lamp', side * 3.91, 3.03, z + 2.31, .12, .36, .12, mat.warm);
      }
      if (bay < 8) {
        plane('Worn street poster', side * 4.271, 2.15, z - 2.94, .53, .79, posterMaterials[(bay + (side + 1) / 2) % 2], inward);
        for (const dy of [-.42, .42]) box('Poster frame top and bottom', side * 4.267, 2.15 + dy, z - 2.94, .036, .027, .61, mat.rusty);
        for (const dz of [-.29, .29]) box('Poster frame sides', side * 4.267, 2.15, z - 2.94 + dz, .036, .87, .027, mat.rusty);
      }
      if (bay % 3 === 1) {
        box('External air conditioner housing', side * 4.28, 4.77, z - 1.64, .62, .48, .94, mat.concrete);
        plane('AC fan grille', side * 3.94, 4.77, z - 1.64, .68, .31,
          ownMaterial(new THREE.MeshBasicMaterial({ color: 0x18252a, side: THREE.DoubleSide })), inward);
        tube('AC drain hose', [
          new THREE.Vector3(side * 4.18, 4.58, z - 2.06),
          new THREE.Vector3(side * 4.18, 3.92, z - 2.1),
          new THREE.Vector3(side * 4.27, 3.61, z - 2.42),
        ], .025, mat.black, 10);
      }
      if (bay < 6) {
        // Raised shutter ribs cast a small alternating highlight even without shadows.
        for (let y = .32; y < 2.9; y += .17) {
          box('Shutter extrusion', side * 4.399, y, z, .018, .016, 5.5, y % .34 < .17 ? mat.steel : mat.rusty);
        }
      }
      if (bay % 4 === 0) {
        tube('Surface wiring', [
          new THREE.Vector3(side * 4.36, 4.39, z + 2.6),
          new THREE.Vector3(side * 4.24, 4.26, z),
          new THREE.Vector3(side * 4.38, 4.51, z - 2.6),
        ], .018, mat.black, 20);
      }
      if (bay % 3 === 2) {
        cylinderAt('Shop downspout collar', side * 4.38, 3.74, z + 2.74, .064, .15, mat.rusty);
        tube('Shop rain downspout', [
          new THREE.Vector3(side * 4.38, 4.65, z + 2.74),
          new THREE.Vector3(side * 4.38, 1.2, z + 2.74),
          new THREE.Vector3(side * 4.32, .18, z + 2.74),
        ], .053, mat.steel, 12);
      }
    }
  }

  // Cross-street identity sign hangs below the roof, supported by visible steel.
  for (const z of [-11.5, -37.1, -56.3]) {
    box('Arcade sign box', 0, 4.61, z, 5.7, 1.23, .27, mat.darkSteel);
    plane('Arcade name', 0, 4.61, z + .151, 5.44, 1.04,
      ownMaterial(new THREE.MeshStandardMaterial({ map: hangingSign, emissiveMap: hangingSign, emissive: 0x9c8155, emissiveIntensity: .57, roughness: .67, side: THREE.DoubleSide })));
    box('Arcade sign overhead light', 0, 5.245, z + .21, 5.32, .034, .035, mat.warm);
    for (const x of [-2.5, 2.5]) box('Hanging sign rod', x, 5.43, z, .045, .63, .045, mat.steel);
  }
  // Cloth banners add asymmetric red silhouettes from the approved composition.
  for (const [x, z] of [[3.89, -4.8], [-3.91, -29.5], [3.89, -43.7]] as const) {
    box('Banner hanging arm', x, 5.18, z, .6, .04, .04, mat.darkSteel);
    plane('Weathered vertical festival banner', x - Math.sign(x) * .28, 4.02, z + .07, .78, 2.17,
      ownMaterial(new THREE.MeshStandardMaterial({ map: fabricBanner, side: THREE.DoubleSide, roughness: .95 })), .05);
  }
  for (const [x, z] of [[-3.94, -8.5], [3.94, -21.5], [-3.94, -47]] as const) {
    box('Projecting lightbox', x, 4.65, z, .5, 1.44, .29, mat.darkSteel);
    plane('Vertical shop lightbox', x, 4.65, z + .165, .38, 1.29,
      ownMaterial(new THREE.MeshStandardMaterial({ map: verticalSign, emissiveMap: verticalSign, emissive: 0x65b3c9, emissiveIntensity: .57, side: THREE.DoubleSide })));
  }

  function vendingMachine(x: number, z: number): void {
    box('Blue drink vending machine cabinet', x, 1.16, z, 1.23, 2.32, .78,
      ownMaterial(new THREE.MeshStandardMaterial({ color: 0x1b4261, metalness: .49, roughness: .37 })));
    box('Vending canopy', x, 2.32, z + .09, 1.27, .08, .86, mat.darkSteel);
    box('Vending illuminated glass', x, 1.56, z + .405, 1.03, 1.1, .015, mat.cold);
    box('Vending display dark inset', x, 1.58, z + .426, .96, .95, .018, mat.black);
    const drinkColors = [0x4894bc, 0xd97047, 0xc0b978, 0x639282, 0xc2d5d7, 0xe0a876];
    for (let row = 0; row < 3; row++) for (let col = 0; col < 6; col++) {
      const color = drinkColors[(row * 2 + col) % drinkColors.length];
      const drinkMat = ownMaterial(new THREE.MeshStandardMaterial({ color, metalness: .6, roughness: .31 }));
      cylinderAt('Vending drink can', x - .39 + col * .155, 1.83 - row * .27, z + .449, .047, .145, drinkMat);
      box('Vending shelf', x, 1.715 - row * .27, z + .47, .99, .015, .035, mat.steel);
    }
    box('Vending side panel', x + .46, 1.1, z + .416, .14, .8, .015, mat.concrete);
    box('Vending coin slot', x + .46, 1.22, z + .429, .066, .016, .012, mat.warm);
    box('Vending retrieval flap', x, .38, z + .417, .74, .27, .012, mat.black);
    box('Vending light header', x, 2.17, z + .44, 1.04, .12, .02, mat.cold);
  }
  vendingMachine(3.85, 1.25);
  vendingMachine(-3.85, -24.1);

  // Human scale street clutter. These props remain out of the encounter lane.
  function crate(x: number, z: number, rotation: number): void {
    const wood = ownMaterial(new THREE.MeshStandardMaterial({ color: 0x655340, roughness: .91 }));
    const group = new THREE.Group(); group.position.set(x, .29, z); group.rotation.y = rotation; root.add(group);
    for (const side of [-1, 1]) {
      const slat = new THREE.Mesh(unitBox, wood); slat.position.set(side * .28, 0, 0); slat.scale.set(.045, .55, .65); group.add(slat);
      const edge = new THREE.Mesh(unitBox, wood); edge.position.set(0, 0, side * .31); edge.scale.set(.62, .55, .045); group.add(edge);
    }
    for (const y of [-.25, .25]) {
      const slat = new THREE.Mesh(unitBox, wood); slat.position.y = y; slat.scale.set(.65, .045, .65); group.add(slat);
    }
  }
  [[-3.76, 2.2, .18], [-4.02, 1.58, -.24], [3.81, -8.8, .3], [-3.94, -18, -.3], [3.87, -34, .2]].forEach(([x, z, a]) => crate(x, z, a));
  function bin(x: number, z: number): void {
    const body = ownMaterial(new THREE.MeshStandardMaterial({ color: 0x515c59, metalness: .42, roughness: .58 }));
    cylinderAt('Street waste bin', x, .46, z, .3, .86, body);
    cylinderAt('Waste bin lid', x, .9, z, .35, .055, mat.darkSteel);
    cylinderAt('Waste bin handle', x, .96, z, .08, .1, mat.rusty);
  }
  bin(-3.96, -3.5); bin(3.96, -16.1);
  function bicycle(x: number, z: number): void {
    const wheelGeometry = ownGeometry(new THREE.TorusGeometry(.43, .027, 6, 22));
    const frame = ownMaterial(new THREE.MeshStandardMaterial({ color: 0x43565b, metalness: .7, roughness: .38 }));
    for (const dx of [-.63, .63]) {
      const wheel = new THREE.Mesh(wheelGeometry, mat.black);
      wheel.name = 'Bicycle wheel'; wheel.position.set(x + dx, .43, z); root.add(wheel);
      tube('Bicycle spokes', [new THREE.Vector3(x + dx, .02, z), new THREE.Vector3(x + dx, .85, z)], .008, mat.steel, 4);
    }
    const p = (dx: number, y: number) => new THREE.Vector3(x + dx, y, z);
    for (const [a, b] of [[p(-.63, .43), p(-.1, .48)], [p(-.1, .48), p(.62, .43)], [p(.62, .43), p(.08, 1.03)], [p(.08, 1.03), p(-.63, .43)], [p(-.1, .48), p(.08, 1.03)], [p(.08, 1.03), p(.04, 1.19)]]) {
      tube('Bicycle tubular frame', [a, b], .025, frame, 4);
    }
    box('Bicycle saddle', x - .11, 1.22, z, .34, .07, .17, mat.black);
    box('Bicycle handlebar', x + .24, 1.25, z, .48, .03, .04, mat.steel);
  }
  bicycle(3.68, -10.7); bicycle(-3.7, -44.9);
  for (const [x, z] of [[-3.9, -13], [3.92, -33.6], [-3.9, -55.2]] as const) {
    box('Utility electrical box', x, .83, z, .42, 1.2, .55, mat.concrete);
    box('Utility box door', x - Math.sign(x) * .23, .83, z, .015, 1.07, .46, mat.steel);
    box('Electrical warning label', x - Math.sign(x) * .243, 1.15, z, .016, .18, .24, mat.warm);
  }
  // Scattered delivery parcels and damp folded cardboard.
  const cardboard = ownMaterial(new THREE.MeshStandardMaterial({ color: 0x78664e, roughness: .96 }));
  for (const [x, z, sx, sy] of [[-3.72, -1.5, .4, .37], [3.63, -6.7, .38, .29], [-3.74, -31.1, .55, .19], [3.77, -50.8, .31, .42]] as const) {
    box('Abandoned cardboard parcel', x, sy / 2 + .14, z, sx, sy, .45, cardboard, .12);
  }

  // Electrical conduits are spatial, not painted on the façade.
  for (const side of [-1, 1]) {
    for (const y of [4.93, 5.18]) {
      tube('Continuous overhead conduit', [
        new THREE.Vector3(side * 4.45, y, START_Z),
        new THREE.Vector3(side * 4.45, y - .09, -22),
        new THREE.Vector3(side * 4.45, y + .04, END_Z),
      ], .019, mat.black, 60);
    }
  }

  // A limited practical light budget; the other lanterns glow with emissive maps.
  const practicalLights: THREE.PointLight[] = [];
  for (const [x, z, color, power] of [[-3.85, 1.5, 0xffbd75, 42], [3.75, -11.4, 0x6cbbdb, 29], [-3.75, -25.4, 0xffba6f, 38], [3.8, -43.5, 0x71b9dd, 30]] as const) {
    const light = new THREE.PointLight(color, power, 9.8, 2);
    light.position.set(x, 3.48, z);
    light.castShadow = false;
    root.add(light); practicalLights.push(light);
  }
  for (let i = 0; i < 13; i++) {
    const z = 3.8 - i * 5.6;
    box('Hanging lamp dark mount', 0, 6.58, z, .04, .43, .04, mat.darkSteel);
    box('Arcade lamp brass case', 0, 6.23, z, .38, .43, .34, mat.rusty);
    box('Arcade lamp warm diffuser', 0, 6.16, z, .3, .28, .28, i % 4 === 1 ? mat.cold : mat.warm);
  }

  // Sparse dust in the side light, outside the main line of fire and labels.
  const moteCount = 58;
  const moteRng = random(905);
  const motePositions = new Float32Array(moteCount * 3);
  const moteBase = new Float32Array(moteCount * 3);
  const moteColors = new Float32Array(moteCount * 3);
  for (let i = 0; i < moteCount; i++) {
    const side = i % 2 ? 1 : -1;
    const j = i * 3;
    moteBase[j] = side * (2.75 + moteRng() * 1.3);
    moteBase[j + 1] = 1.3 + moteRng() * 3.9;
    moteBase[j + 2] = 2 - moteRng() * 64;
    motePositions.set(moteBase.subarray(j, j + 3), j);
    const cool = i % 4 === 1;
    moteColors[j] = cool ? .55 : .75;
    moteColors[j + 1] = cool ? .73 : .62;
    moteColors[j + 2] = cool ? .78 : .43;
  }
  const moteGeometry = ownGeometry(new THREE.BufferGeometry());
  moteGeometry.setAttribute('position', new THREE.BufferAttribute(motePositions, 3));
  moteGeometry.setAttribute('color', new THREE.BufferAttribute(moteColors, 3));
  const motes = new THREE.Points(moteGeometry, ownMaterial(new THREE.PointsMaterial({
    size: .045, sizeAttenuation: true, vertexColors: true,
    transparent: true, opacity: .29, depthWrite: false,
  })));
  motes.name = 'Sparse airborne dust';
  motes.frustumCulled = false;
  root.add(motes);

  // The final alley fades into a cold solid backing rather than showing void.
  box('Arcade distant closure', 0, 3.28, END_Z - 1.2, 9.4, 6.6, .24, mat.wall);
  const previousFog = scene.fog;
  if (!previousFog) scene.fog = new THREE.FogExp2(0x101e26, .022);
  const previousBackground = scene.background;
  if (!previousBackground) scene.background = new THREE.Color(0x101e26);

  return {
    update(time: number, level: number): void {
      const tier = THREE.MathUtils.clamp(level, 0, 4);
      // Rare, gentle light breathing supports the combo escalation without flashing.
      for (let i = 0; i < practicalLights.length; i++) {
        practicalLights[i].intensity = ([42, 29, 38, 30][i] + tier * 1.6) * (1 + Math.sin(time * .8 + i * 1.7) * .025);
      }
      mat.warm.emissiveIntensity = 1.65 + tier * .1;
      mat.cold.emissiveIntensity = 1.7 + tier * .07;
      for (let i = 0; i < moteCount; i++) {
        const j = i * 3;
        motePositions[j] = moteBase[j] + Math.sin(time * .31 + i * 2.2) * .09;
        motePositions[j + 1] = moteBase[j + 1] + Math.sin(time * .43 + i * 1.7) * .065;
      }
      moteGeometry.attributes.position.needsUpdate = true;
    },
    dispose(): void {
      scene.remove(root);
      for (const texture of ownedTextures) texture.dispose();
      for (const material of ownedMaterials) material.dispose();
      for (const geometry of ownedGeometries) geometry.dispose();
      if (scene.fog !== previousFog) scene.fog = previousFog;
      if (scene.background !== previousBackground) scene.background = previousBackground;
    },
  };
}
