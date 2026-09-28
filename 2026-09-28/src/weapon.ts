import * as T from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

/** Camera-local weapon. The scene owns aim/recoil; this group owns the moving slide. */
export async function createWeapon(): Promise<T.Group> {
  const loader = new GLTFLoader();
  const [pistolAsset, armsAsset] = await Promise.all([
    loader.loadAsync(`${import.meta.env.BASE_URL}assets/weapons/pistol.glb`),
    loader.loadAsync(`${import.meta.env.BASE_URL}assets/weapons/fps-arms.glb`),
  ]);

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

  // Built from primitives on the existing camera-local axis. The muzzle stays
  // at (0, .03, -.28), the flash coordinate owned by scene.ts.
  const shotgun = new T.Group();
  shotgun.name = 'shotgun';
  shotgun.scale.setScalar(.68);
  shotgun.position.y=-.07;
  shotgun.visible = false;
  const blued = new T.MeshStandardMaterial({ color: 0x252b2d, metalness: .82, roughness: .36 });
  const edge = new T.MeshStandardMaterial({ color: 0x707779, metalness: .9, roughness: .29 });
  const recess = new T.MeshStandardMaterial({ color: 0x101617, metalness: .34, roughness: .8 });
  const wood = new T.MeshStandardMaterial({ color: 0x4b3023, metalness: .03, roughness: .7 });
  const grain = new T.MeshStandardMaterial({ color: 0x6e4932, metalness: .02, roughness: .67 });
  function box(name: string, size: [number, number, number], position: [number, number, number], material: T.Material, parent = shotgun): T.Mesh {
    const mesh = new T.Mesh(new T.BoxGeometry(...size), material);
    mesh.name = name; mesh.position.set(...position); mesh.castShadow = true;
    parent.add(mesh); return mesh;
  }
  function tube(name: string, radius: number, length: number, position: [number, number, number], material: T.Material, parent = shotgun): T.Mesh {
    const mesh = new T.Mesh(new T.CylinderGeometry(radius, radius, length, 12), material);
    mesh.name = name; mesh.rotation.x = Math.PI / 2; mesh.position.set(...position); mesh.castShadow = true;
    parent.add(mesh); return mesh;
  }
  box('shotgun-receiver', [.155, .115, .17], [0, -.015, .035], blued);
  box('shotgun-ejection-port', [.01, .044, .085], [.081, .008, .027], recess);
  box('shotgun-port-lip', [.012, .007, .088], [.088, .033, .027], edge);
  tube('shotgun-barrel', .034, .38, [0, .035, -.08], blued);
  tube('shotgun-muzzle-ring', .039, .022, [0, .035, -.269], edge);
  tube('shotgun-magazine-tube', .025, .32, [0, -.031, -.105], blued);
  tube('shotgun-magazine-cap', .029, .018, [0, -.031, -.262], edge);
  const pump = new T.Group(); pump.name = 'shotgun-pump'; shotgun.add(pump);
  box('shotgun-pump-fore-end', [.125, .085, .12], [0, -.035, -.135], wood, pump);
  for (let i = -2; i <= 2; i++) {
    box(`shotgun-pump-rib-${i}`, [.128, .003, .004], [0, -.077, -.135 + i * .018], grain, pump);
  }
  box('shotgun-pump-band', [.13, .09, .012], [0, -.035, -.196], blued, pump);
  const stock=box('shotgun-stock', [.09, .075, .18], [0, -.06, .203], wood);
  stock.rotation.x=-.23;
  box('shotgun-stock-comb', [.085, .025, .12], [0, -.025, .205], grain);
  box('shotgun-butt-pad', [.10, .095, .018], [0, -.08, .3], recess);
  const grip = box('shotgun-pistol-grip', [.077, .125, .07], [0, -.116, .10], wood);
  grip.rotation.x = -.31;
  const trigger = box('shotgun-trigger', [.009, .046, .012], [0, -.104, .008], edge);
  trigger.rotation.x = -.2;
  box('shotgun-trigger-guard-bottom', [.07, .008, .105], [0, -.147, .044], blued);
  box('shotgun-front-sight', [.024, .019, .018], [0, .084, -.247], edge);
  weapon.add(shotgun);

  // Keep the detailed right arm and hand from the FPS rig. Its source mesh has
  // both arms in one symmetric skin; left-half triangles belong to the right arm.
  const arms = armsAsset.scene;
  arms.name = 'right-gloved-arm';
  const armMesh = arms.getObjectByName('caucasian_male_1Body');
  if (armMesh instanceof T.SkinnedMesh) {
    const geometry = armMesh.geometry.clone();
    const index = geometry.getIndex();
    const positions = geometry.getAttribute('position');
    if (index && positions) {
      const rightTriangles: number[] = [];
      for (let i = 0; i < index.count; i += 3) {
        const a = index.getX(i);
        const b = index.getX(i + 1);
        const c = index.getX(i + 2);
        if (positions.getX(a) + positions.getX(b) + positions.getX(c) < 0) {
          rightTriangles.push(a, b, c);
        }
      }
      geometry.setIndex(rightTriangles);
      geometry.computeBoundingSphere();
    }
    armMesh.geometry = geometry;
    const sourceMaterial = armMesh.material;
    if (sourceMaterial instanceof T.MeshStandardMaterial) {
      const glove = sourceMaterial.clone();
      glove.name = 'worn-dark-glove-and-sleeve';
      glove.color.set(0x485356);
      if(glove instanceof T.MeshPhysicalMaterial){glove.specularIntensity=.3;glove.specularColor.set(0xffffff);}
      glove.roughness = 0.9;
      glove.metalness = 0;
      armMesh.material = glove;
    }
    armMesh.castShadow = true;
    armMesh.frustumCulled = false;
  }

  // The source rig has straight, spread fingers. Curl its existing phalanges
  // around the grip; all skin stays bound to the original hand and forearm.
  for (const [name, baseCurl, middleCurl] of [
    ['index', 0.62, 0.2],
    ['middle', 1.02, 0.38],
    ['ring', 1.08, 0.42],
    ['pinky', 1.12, 0.43],
  ] as const) {
    const base = arms.getObjectByName(`f_${name}.01.R`);
    const middle = arms.getObjectByName(`f_${name}.02.R`);
    if (base) base.rotation.z -= baseCurl;
    if (middle) middle.rotation.z -= middleCurl;
  }

  // Bring the palm below the slide and beside the grip, so the curled fingers
  // sit behind the trigger guard instead of reaching over the barrel.
  const lowerRight = new T.Group();
  lowerRight.position.set(0.415, -0.32, 0.11);
  lowerRight.rotation.z = Math.PI;
  const faceCamera = new T.Group();
  faceCamera.rotation.y = Math.PI;
  arms.scale.setScalar(0.75);
  faceCamera.add(arms);
  lowerRight.add(faceCamera);
  weapon.add(lowerRight);

  return weapon;
}

export function setWeaponMode(weapon: T.Group, mode: 'pistol' | 'shotgun'): void {
  const pistol = weapon.getObjectByName('pistol');
  const shotgun = weapon.getObjectByName('shotgun');
  if (pistol) pistol.visible = mode === 'pistol';
  if (shotgun) shotgun.visible = mode === 'shotgun';
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
