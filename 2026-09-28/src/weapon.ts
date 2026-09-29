import * as T from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

type Point = [number, number, number];

function rounded(parent: T.Group, name: string, size: Point, at: Point, radius: number, material: T.Material): T.Mesh {
  const mesh = new T.Mesh(new RoundedBoxGeometry(...size, 3, radius), material);
  mesh.name = name;
  mesh.position.set(...at);
  mesh.castShadow = true;
  parent.add(mesh);
  return mesh;
}

function cylinder(parent: T.Group, name: string, radius: number, length: number, at: Point, material: T.Material, radialSegments = 20): T.Mesh {
  const mesh = new T.Mesh(new T.CylinderGeometry(radius, radius, length, radialSegments), material);
  mesh.name = name;
  mesh.rotation.x = Math.PI / 2;
  mesh.position.set(...at);
  mesh.castShadow = true;
  parent.add(mesh);
  return mesh;
}

/** Oval sections make a tapered silhouette without square stock and fore-end corners. */
function loft(parent: T.Group, name: string, sections: Array<[number, number, number, number, number]>, material: T.Material): T.Mesh {
  const sides = 12;
  const points: number[] = [];
  const indices: number[] = [];
  for (const [z, centerY, radiusX, radiusY, centerX] of sections) {
    for (let side = 0; side < sides; side++) {
      const angle = side * Math.PI * 2 / sides;
      points.push(centerX + Math.cos(angle) * radiusX, centerY + Math.sin(angle) * radiusY, z);
    }
  }
  for (let ring = 0; ring < sections.length - 1; ring++) {
    for (let side = 0; side < sides; side++) {
      const a = ring * sides + side;
      const b = ring * sides + (side + 1) % sides;
      const c = (ring + 1) * sides + side;
      const d = (ring + 1) * sides + (side + 1) % sides;
      indices.push(a, b, c, b, d, c);
    }
  }
  for (let side = 1; side < sides - 1; side++) {
    indices.push(0, side + 1, side);
    const end = (sections.length - 1) * sides;
    indices.push(end, end + side, end + side + 1);
  }
  const geometry = new T.BufferGeometry();
  geometry.setAttribute('position', new T.Float32BufferAttribute(points, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  const mesh = new T.Mesh(geometry, material);
  mesh.name = name;
  mesh.castShadow = true;
  parent.add(mesh);
  return mesh;
}

function capsuleBetween(parent: T.Group, name: string, from: Point, to: Point, radius: number, material: T.Material): T.Mesh {
  const start = new T.Vector3(...from);
  const end = new T.Vector3(...to);
  const mid = start.clone().add(end).multiplyScalar(.5);
  const mesh = new T.Mesh(new T.CapsuleGeometry(radius, Math.max(.001, start.distanceTo(end) - radius * 2), 4, 8), material);
  mesh.name = name;
  mesh.position.copy(mid);
  mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 1, 0), end.sub(start).normalize());
  mesh.castShadow = true;
  parent.add(mesh);
  return mesh;
}

function makeGlove(parent: T.Group, name: string, side: 'right' | 'left', zOffset = 0): T.Group {
  const glove = new T.Group();
  glove.name = name;
  parent.add(glove);
  const shell = new T.MeshStandardMaterial({ color: 0x30383a, roughness: .92, metalness: 0 });
  const knuckle = new T.MeshStandardMaterial({ color: 0x485052, roughness: .88, metalness: 0 });
  const seam = new T.MeshStandardMaterial({ color: 0x171d1f, roughness: .96, metalness: 0 });
  const direction = side === 'right' ? 1 : -1;
  const palmX = direction * .092;
  const palmY = side === 'right' ? -.16 : -.105;
  const palmZ = (side === 'right' ? .19 : -.10) + zOffset;
  capsuleBetween(glove, `${name}-sleeve`, [direction * .27, -.39, palmZ + .22], [direction * .115, palmY - .04, palmZ + .045], .075, shell);
  cylinder(glove, `${name}-cuff`, .067, .035, [direction * .15, palmY - .105, palmZ + .08], seam).rotation.set(0, 0, direction * .65);
  const palm = rounded(glove, `${name}-palm`, [.13, .11, .068], [palmX, palmY, palmZ], .027, shell);
  palm.rotation.z = direction * -.17;
  for (let finger = 0; finger < 4; finger++) {
    const x = palmX + (finger - 1.5) * .026;
    const y = palmY + .037;
    capsuleBetween(glove, `${name}-finger-${finger}`, [x, y, palmZ + .018], [x - direction * .006, y + .015, palmZ - .065], .012, shell);
    rounded(glove, `${name}-knuckle-${finger}`, [.024, .014, .033], [x, y + .01, palmZ + .048], .006, knuckle);
  }
  capsuleBetween(glove, `${name}-thumb`, [palmX - direction * .065, palmY - .005, palmZ + .01], [palmX - direction * .08, palmY + .035, palmZ - .035], .018, shell);
  return glove;
}

function makePistolGripHand(parent: T.Group): T.Group {
  const hand = new T.Group();
  hand.name = 'pistol-visible-glove';
  parent.add(hand);
  const cloth = new T.MeshStandardMaterial({ color: 0x283235, roughness: .94, metalness: 0 });
  const seams = new T.MeshStandardMaterial({ color: 0x495255, roughness: .88, metalness: 0 });
  const cuff = new T.MeshStandardMaterial({ color: 0x1a2224, roughness: .96, metalness: 0 });
  // The palm follows the pistol's vertical grip. Fingers cross its front edge
  // in short bent segments instead of extending forward as an open hand.
  capsuleBetween(hand, 'pistol-sleeve', [.18, -.39, .31], [.065, -.24, .16], .049, cloth);
  capsuleBetween(hand, 'pistol-cuff', [.085, -.27, .18], [.065, -.225, .15], .05, cuff);
  const palm = rounded(hand, 'pistol-palm', [.063, .116, .049], [.057, -.174, .125], .022, cloth);
  palm.rotation.z = -.18;
  for (let finger = 0; finger < 4; finger++) {
    const y = -.115 - finger * .03;
    capsuleBetween(hand, `pistol-grip-finger-${finger}`, [.068, y, .148], [.026, y - .014, .118], .009, cloth);
    rounded(hand, `pistol-finger-seam-${finger}`, [.01, .005, .012], [.068, y, .167], .002, seams);
  }
  capsuleBetween(hand, 'pistol-grip-thumb', [.014, -.095, .16], [-.01, -.14, .13], .016, cloth);
  return hand;
}

/** Camera-local weapon. The scene owns aim/recoil; this group owns the moving slide. */
export async function createWeapon(): Promise<T.Group> {
  const loader = new GLTFLoader();
  const pistolAsset = await loader.loadAsync(`${import.meta.env.BASE_URL}assets/weapons/pistol.glb`);

  const weapon = new T.Group();
  weapon.name = 'first-person-weapon';

  // The author's barrel runs along +X. After this turn the barrel faces camera -Z.
  // The loose spare magazine in the source preview is not part of the held weapon.
  const pistol = pistolAsset.scene;
  pistol.name = 'pistol';
  const spareMagazine = pistol.getObjectByName('Pistol_Magazine');
  if (spareMagazine) spareMagazine.visible = false;
  pistol.rotation.y = Math.PI / 2;
  pistol.scale.setScalar(1.2);
  pistol.position.set(0, -0.15, -0.10);
  pistol.traverse((object) => {
    if (object instanceof T.Mesh) {
      const source=Array.isArray(object.material)?object.material:[object.material];
      const materials=source.map(m=>{
        const material=m.clone();
        if(material instanceof T.MeshStandardMaterial){
          material.color.multiplyScalar(.48);material.normalScale.set(.35,.35);
          material.roughnessMap=null;material.roughness=.4;material.metalness=.78;
          if(/Frame|Trigger|Magazine/.test(object.name)){material.roughness=.72;material.metalness=.22;}
        }
        return material;
      });
      object.material=Array.isArray(object.material)?materials:materials[0];
      object.castShadow = true;
      object.frustumCulled = false;
    }
  });
  weapon.add(pistol);

  // The barrel tip stays at the scene's camera-local flash position (0,.03,-.28).
  const shotgun = new T.Group();
  shotgun.name = 'shotgun';
  shotgun.scale.setScalar(.72);
  shotgun.rotation.set(.17, .18, 0);
  const flashAt = new T.Vector3(0, .03, -.28);
  shotgun.position.copy(flashAt.clone().sub(flashAt.clone().applyEuler(shotgun.rotation).multiplyScalar(.72)));
  shotgun.visible = false;
  const blued = new T.MeshStandardMaterial({ color: 0x252c2f, metalness: .76, roughness: .39 });
  const highlights = new T.MeshStandardMaterial({ color: 0x586366, metalness: .84, roughness: .34 });
  const recess = new T.MeshStandardMaterial({ color: 0x0c1112, metalness: .3, roughness: .79 });
  const walnut = new T.MeshStandardMaterial({ color: 0x30231c, metalness: .02, roughness: .74 });
  const gripColor = new T.MeshStandardMaterial({ color: 0x211c18, metalness: .02, roughness: .86 });
  const grain = new T.MeshStandardMaterial({ color: 0x473429, metalness: .02, roughness: .78 });

  // A continuous steel silhouette joins the barrel to the chamfered receiver.
  cylinder(shotgun, 'shotgun-barrel', .032, .40, [0, .03, -.08], blued, 24);
  cylinder(shotgun, 'shotgun-bore', .021, .002, [0, .03, -.281], recess, 24);
  cylinder(shotgun, 'shotgun-muzzle-collar', .038, .018, [0, .03, -.271], highlights, 24);
  cylinder(shotgun, 'shotgun-magazine-tube', .023, .34, [0, -.04, -.102], blued, 20);
  cylinder(shotgun, 'shotgun-magazine-cap', .028, .025, [0, -.04, -.257], highlights, 20);
  rounded(shotgun, 'shotgun-receiver', [.151, .111, .215], [0, -.014, .108], .016, blued);
  rounded(shotgun, 'shotgun-upper-receiver', [.134, .021, .185], [0, .047, .092], .009, highlights);
  rounded(shotgun, 'shotgun-ejection-port', [.005, .043, .087], [.078, .008, .092], .002, recess);
  rounded(shotgun, 'shotgun-ejection-lip', [.006, .006, .093], [.082, .033, .092], .002, highlights);
  rounded(shotgun, 'shotgun-loading-gate', [.09, .006, .07], [0, -.071, .086], .003, recess);
  rounded(shotgun, 'shotgun-rear-sight', [.047, .02, .016], [0, .07, .18], .004, recess);
  rounded(shotgun, 'shotgun-front-sight', [.019, .024, .018], [0, .078, -.245], .005, highlights);

  const pump = new T.Group();
  pump.name = 'shotgun-pump';
  shotgun.add(pump);
  loft(pump, 'shotgun-walnut-fore-end', [
    [-.213, -.051, .053, .044, 0],[-.199, -.051, .068, .051, 0],
    [-.122, -.052, .071, .054, 0],[-.035, -.052, .067, .052, 0],
    [-.021, -.052, .052, .041, 0],
  ], walnut);
  for (let i = 0; i < 7; i++) {
    const rib = rounded(pump, `shotgun-pump-groove-${i}`, [.002, .046, .005], [.069, -.052, -.18 + i * .019], .001, gripColor);
    rib.rotation.z = -.12;
  }
  cylinder(pump, 'shotgun-pump-front-band', .057, .011, [0, -.05, -.21], blued, 16);
  cylinder(pump, 'shotgun-pump-rear-band', .057, .009, [0, -.05, -.025], blued, 16);

  loft(shotgun, 'shotgun-shaped-stock', [
    [.193, -.039, .053, .045, 0],[.24, -.059, .053, .05, 0],
    [.37, -.092, .063, .067, 0],[.445, -.124, .076, .091, 0],
    [.465, -.124, .074, .091, 0],
  ], walnut);
  loft(shotgun, 'shotgun-stock-comb', [
    [.20, .005, .044, .01, 0],[.3, -.014, .051, .013, 0],
    [.43, -.042, .067, .013, 0],
  ], grain);
  rounded(shotgun, 'shotgun-butt-pad', [.15, .183, .018], [0, -.124, .47], .009, recess);
  capsuleBetween(shotgun, 'shotgun-slanted-grip', [0, -.075, .19], [0, -.22, .255], .044, gripColor);
  rounded(shotgun, 'shotgun-grip-inlay', [.009, .09, .047], [.043, -.155, .224], .005, walnut).rotation.x = -.32;
  const trigger = rounded(shotgun, 'shotgun-trigger', [.006, .038, .012], [0, -.10, .067], .002, highlights);
  trigger.rotation.x = -.24;
  rounded(shotgun, 'shotgun-trigger-guard', [.067, .009, .104], [0, -.143, .107], .004, blued);
  for (const side of [-1, 1]) {
    cylinder(shotgun, `shotgun-receiver-pin-${side}`, .008, .002, [side * .077, -.01, .146], highlights, 10).rotation.set(0, 0, Math.PI / 2);
  }
  makeGlove(shotgun, 'shotgun-right-glove', 'right');
  const supportHand = makeGlove(pump, 'shotgun-left-glove', 'left');
  supportHand.position.x = .045;
  weapon.add(shotgun);

  // Position the palm against the measured GLB grip, not beside empty space.
  const pistolGlove = makePistolGripHand(weapon);
  pistolGlove.position.set(-.018, .035, -.135);
  const support = new T.Group();
  support.name = 'pistol-support-hand';
  const leather = new T.MeshStandardMaterial({color:0x444943,roughness:.83});
  const sleeve = new T.MeshStandardMaterial({color:0x303c38,roughness:.96});
  capsuleBetween(support,'support forearm',[-.23,-.34,.26],[-.055,-.15,.015],.042,sleeve);
  const palm = rounded(support,'support palm',[.063,.092,.047],[-.045,-.13,.006],.021,leather);
  palm.rotation.z=.28;
  for(let i=0;i<3;i++) capsuleBetween(support,'support bent finger',[-.061,-.104-i*.023,-.008],[-.018,-.116-i*.023,-.047],.008,leather);
  capsuleBetween(support,'support thumb',[-.061,-.1,.008],[-.028,-.077,-.057],.011,leather);
  weapon.add(support);

  return weapon;
}

export function setWeaponMode(weapon: T.Group, mode: 'pistol' | 'shotgun'): void {
  const pistol = weapon.getObjectByName('pistol');
  const shotgun = weapon.getObjectByName('shotgun');
  const pistolGlove = weapon.getObjectByName('pistol-visible-glove');
  const support = weapon.getObjectByName('pistol-support-hand');
  if (pistol) pistol.visible = mode === 'pistol';
  if (shotgun) shotgun.visible = mode === 'shotgun';
  if (pistolGlove) pistolGlove.visible = mode === 'pistol';
  if (support) support.visible = mode === 'pistol';
}

/** Slide travels along source -X (toward the camera after the pistol's Y turn). */
export function animateWeapon(weapon: T.Group, recoil: number, finishing = false, motion = true): void {
  const pistol = weapon.getObjectByName('pistol');
  const amount = T.MathUtils.clamp(recoil, 0, 1);
  const pump = weapon.getObjectByName('shotgun-pump');
  if (pump) pump.position.z = amount * (motion ? finishing ? .092 : .061 : .014);
  if (!pistol) return;
  const travel = amount * (motion ? finishing ? 0.067 : 0.052 : 0.012);
  for (const name of ['Pistol_Slide', 'Pistol_Slide4']) {
    const slide = pistol.getObjectByName(name);
    if (!slide) continue;
    if (typeof slide.userData.restX !== 'number') slide.userData.restX = slide.position.x;
    slide.position.x = slide.userData.restX - travel;
  }
}
